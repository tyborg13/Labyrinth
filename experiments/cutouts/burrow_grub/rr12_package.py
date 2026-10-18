"""Headless production-only PCK proof with the official unmodified macOS runtime."""
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile
from rr12_inputs import PROJECT, digest, write_json

TEMPLATE = Path.home() / 'Library/Application Support/Godot/export_templates/4.6.1.stable/macos.zip'
TEMPLATE_MEMBER = 'macos_template.app/Contents/MacOS/godot_macos_debug.universal'
PROOF_DEFAULTS = {'package_timeout_seconds': 120}


def run():
    proof = PROJECT / 'experiments/cutouts/burrow_grub/mq5/proof'
    with tempfile.TemporaryDirectory(prefix='rr12-package-', dir=proof) as temporary:
        work = Path(temporary)
        pack = work / 'godot_runtime.pck'
        binary = work / 'godot_runtime'
        with zipfile.ZipFile(TEMPLATE) as archive:
            binary.write_bytes(archive.read(TEMPLATE_MEMBER))
        binary.chmod(0o755)
        empty = work / 'empty'
        empty.mkdir()
        commands = [
            ['godot', '--headless', '--path', '.', '--script',
             'experiments/cutouts/burrow_grub/rr12_pack_build.gd', '--', str(pack)],
            [str(binary), '--headless']
        ]
        results = []
        for stage, command in zip(('build', 'runtime'), commands):
            invocation = [sys.executable, str(PROJECT / 'tools/godot_task_runner.py'),
                '--project', str(PROJECT if stage == 'build' else empty), '--task-id', 'rr-12',
                '--timeout', str(PROOF_DEFAULTS['package_timeout_seconds']), '--stream', '--', *command]
            process = subprocess.run(invocation, cwd=PROJECT, capture_output=True, text=True)
            (proof / ('package_' + stage + '.log')).write_text(process.stdout + process.stderr)
            print(process.stdout + process.stderr, end='')
            results.append({'stage': stage, 'exit_code': process.returncode})
            if process.returncode:
                raise RuntimeError('Package ' + stage + ' failed')
        write_json(proof / 'package.json', {'ok': True, 'results': results,
            'template_archive_sha256': digest(TEMPLATE), 'unchanged_runtime_sha256': digest(binary),
            'pack_sha256': digest(pack), 'native_pixels': False, 'proof_defaults': PROOF_DEFAULTS})


if __name__ == '__main__':
    run()
