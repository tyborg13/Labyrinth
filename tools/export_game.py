#!/usr/bin/env python3
"""Release/playtest exports: refresh cel variants, fail closed, export, verify pack."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import zipfile

from cel_look import build, settings
from cel_look_inventory import inventory
from cel_look_state import OUTPUT_DIRECTORY, status
from cel_look_export import verify_pack

PROJECT = Path(__file__).resolve().parents[1]
EXPORT_TIMEOUT_SECONDS = 1800  # A fresh platform export imports the complete asset tree.


def expose_templates(home_root):
    """Keep saves/logs isolated while reading the host's installed templates."""
    host = Path.home()
    candidates = [host / 'Library/Application Support/Godot/export_templates',
                  Path(os.environ.get('XDG_DATA_HOME', host / '.local/share')) / 'godot/export_templates',
                  Path(os.environ.get('APPDATA', host / 'AppData/Roaming')) / 'Godot/export_templates']
    source = next((p for p in candidates if p.is_dir()), None)
    if source is not None:
        # The host editor reads its native directory even for cross-platform
        # exports. Copy just that directory when Windows denies symlinks (1314).
        relative = ('AppData/Roaming/Godot/export_templates' if sys.platform == 'win32' else
                    'Library/Application Support/Godot/export_templates' if sys.platform == 'darwin' else
                    'xdg/data/godot/export_templates')
        target = home_root / 'export' / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        try:
            target.symlink_to(source, target_is_directory=True)
        except OSError:
            shutil.copytree(source, target)


def validate_copy(project):
    source = PROJECT / OUTPUT_DIRECTORY
    copied = project / OUTPUT_DIRECTORY
    if (copied / 'manifest.json').read_bytes() != (source / 'manifest.json').read_bytes():
        raise ValueError('Sanitized export has a stale cel manifest')
    manifest = json.loads((source / 'manifest.json').read_text())
    for relative, expected in manifest['sha256'].items():
        path = copied / relative
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise ValueError('Sanitized export missing/damaged cel variant: ' + relative)


def export(preset, output, task_id, godot='godot', pack_only=False, project=PROJECT):
    build(PROJECT, if_stale=True)
    entries, _ = inventory(PROJECT)
    current, reason = status(PROJECT, PROJECT / OUTPUT_DIRECTORY, entries, settings())
    if not current:
        raise ValueError('Refusing export with stale cel variants: ' + reason)
    project = project.resolve()
    if project != PROJECT:
        validate_copy(project)
    output = output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    command = [sys.executable, str(PROJECT / 'tools/godot_task_runner.py'),
               '--task-id', task_id, '--stream', '--', godot, '--headless', '--path', str(project),
               '--export-pack' if pack_only else '--export-release', preset, str(output)]
    with tempfile.TemporaryDirectory(prefix='cel-export-home-') as directory:
        home_root = Path(directory)
        expose_templates(home_root)
        command[2:2] = ['--run-id', 'export', '--godot-home-root', str(home_root),
                        '--timeout', str(EXPORT_TIMEOUT_SECONDS)]
        code = subprocess.run(command, cwd=PROJECT).returncode
    if code:
        return code
    if pack_only:
        return verify_pack(output, task_id, godot)
    if output.suffix.lower() == '.zip':
        with tempfile.TemporaryDirectory(prefix='cel-macos-pack-') as directory, zipfile.ZipFile(output) as archive:
            packs = [name for name in archive.namelist() if name.endswith('.pck')]
            if len(packs) != 1:
                raise ValueError('Expected one macOS pack in ' + str(output))
            pack = Path(archive.extract(packs[0], directory))
            return verify_pack(pack, task_id, godot)
    pack = output / 'Contents/Resources/Escape the Umbra.pck' if output.suffix == '.app' else output.with_suffix('.pck')
    if output.suffix == '.app':
        packs = list((output / 'Contents/Resources').glob('*.pck'))
        if len(packs) != 1:
            raise ValueError('Expected one macOS app pack')
        pack = packs[0]
    # Embedded Windows/Linux packs are mountable by Godot as executable files.
    return verify_pack(pack if pack.exists() else output, task_id, godot)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--preset', required=True, choices=[
        'Steam macOS', 'Steam Windows', 'Steam Linux',
        'Steam Demo macOS', 'Steam Demo Windows', 'Steam Demo Linux'])
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--task-id', required=True)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--project', type=Path, default=PROJECT, help='Optional sanitized copy of this project.')
    parser.add_argument('--pack-only', action='store_true')
    args = parser.parse_args(argv)
    return export(args.preset, args.output, args.task_id, args.godot, args.pack_only, args.project)


if __name__ == '__main__':
    raise SystemExit(main())
