"""Headless validation of owner launch/capture plumbing; no native execution."""
from pathlib import Path
import ast
import json
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path('/private/tmp/labyrinth_codex/rd-08')


def main():
    for path in (ROOT / 'tools/rd08').glob('*.py'):
        ast.parse(path.read_text(), filename=str(path))
    for path in (ROOT / 'tools/rd08').glob('*.sh'):
        subprocess.run(['sh', '-n', str(path)], check=True)
    for case, count in [('overlap', 9), ('zekarion', 2), ('vyraketh', 1), ('movie', 120), ('performance', 1), ('enemy_hover', 1), ('zekarion_hover', 1)]:
        contract = json.loads((ROOT / f'tools/rd08/{case}_contract.json').read_text())
        assert contract['min_images'] == count and contract['expected_sizes'] == ['1920x1080']
    with tempfile.TemporaryDirectory(prefix='rd08-launch-', dir=OUTPUT) as temp:
        fixture_home = Path(temp)
        source = fixture_home / 'Library/Application Support/Escape the Umbra/steam/76561198007239340'
        profile = fixture_home / 'Library/Application Support/Escape the Umbra Playtest rd-08'
        source.mkdir(parents=True)
        originals = {name: ('fixture-' + name).encode() for name in ['progression.json', 'settings.json', 'current_run.save']}
        for name, content in originals.items():
            (source / name).write_bytes(content)
        fake_bin = fixture_home / 'bin'
        fake_bin.mkdir()
        fake_godot = fake_bin / 'godot'
        fake_godot.write_text('#!/bin/sh\ntest "$LABYRINTH_USER_DIR_NAME" = "Escape the Umbra Playtest rd-08"\ntest -z "${LABYRINTH_TASK_ID:-}"\n')
        fake_godot.chmod(0o755)
        env = {**os.environ, 'RD08_PROFILE_HOME': temp, 'PATH': str(fake_bin) + ':' + os.environ['PATH']}
        command = ['python3', 'tools/godot_task_runner.py', '--task-id', 'rd-08', '--stream', '--', 'tools/rd08/play_profile.sh']
        subprocess.run(command, cwd=ROOT, env=env, check=True)
        assert all((profile / name).read_bytes() == data for name, data in originals.items())
        (profile / 'progression.json').write_text('existing-profile')
        subprocess.run(command, cwd=ROOT, env=env, check=True)
        assert (profile / 'progression.json').read_text() == 'existing-profile'
        assert all((source / name).read_bytes() == data for name, data in originals.items())
    print('RD08 OWNER TOOLS: PASS (syntax, contracts, profile seeds once; Steam source unchanged)')


if __name__ == '__main__':
    main()
