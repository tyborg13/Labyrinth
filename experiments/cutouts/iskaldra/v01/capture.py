"""Fresh native case proof with an explicit wait for the shared GPU lease.

Uses the maintained runner, validator, packer and verifier unchanged. This
case-owned wrapper only exposes the lease timeout that the generic `render`
command currently fixes at 30 seconds. It never bypasses the shared lease.
"""
from pathlib import Path
import argparse
import json
import shutil
import subprocess
import sys
import tempfile

CASE = Path(__file__).resolve().parent
PROJECT = CASE.parents[3]
sys.path.insert(0, str(PROJECT))
from tools.cutout_pipeline.cases import digest, fresh_directory, write_json
from tools.cutout_pipeline.proof import input_hashes, pack, verify_render
from tools.cutout_pipeline.validation import validate


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--task-id', default='animate-iskaldra-cutout')
    parser.add_argument('--gui-lease-timeout', type=int, default=1200)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        raise SystemExit('Choose a fresh proof output.')
    validation = validate(CASE)
    if not validation['ok']:
        raise SystemExit(validation)
    before = input_hashes(CASE)
    with tempfile.TemporaryDirectory(prefix='iskaldra-native-') as scratch:
        result_path = Path(scratch) / 'result.json'
        command = [sys.executable, str(PROJECT/'tools/visual_probe_runner.py'),
                   'tools/cutout_pipeline/preview.gd', '--project', str(PROJECT),
                   '--task-id', args.task_id, '--no-headless', '--expect-size',
                   '1920x1080', '--expect-size', '512x512', '--timeout', '180',
                   '--gui-lease-timeout', str(args.gui_lease_timeout),
                   '--result-manifest', str(result_path), '--', '--case',
                   str(CASE/'cutout.json')]
        run = subprocess.run(command, cwd=PROJECT, text=True, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT)
        if run.returncode:
            raise SystemExit(run.stdout[-12000:])
        result = json.loads(result_path.read_text())
        if not result.get('ok') or before != input_hashes(CASE):
            raise SystemExit('Native proof failed or capture inputs changed.')
        raw = next(Path(i['path']).parent for i in result['images']
                   if Path(i['path']).name == 'keyboard_focus.png')
        fresh_directory(output)
        shutil.copytree(raw, output, dirs_exist_ok=True)
        (output/'native_probe.log').write_text(run.stdout)
        for record in [result] + result['attempts']:
            for item in record.get('images', []):
                item['path'] = str(Path(item['path']).relative_to(raw))
        write_json(output/'visual_probe_result.json', result)
        write_json(output/'capture_input_sha256.json', before)
        write_json(output/'case_validation.json', validation)
    encoding = pack(output)
    write_json(output/'proof_sha256.json', {
        str(p.relative_to(output)): digest(p) for p in sorted(output.rglob('*'))
        if p.is_file() and p.name != 'proof_sha256.json'})
    verified = verify_render(CASE, output)
    print(json.dumps({'verification':verified,'preview':str(output/encoding['reel'])},indent=2))
    if not verified['ok']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
