#!/usr/bin/env python3
"""Round-trip the wrapper's stamp through Godot using a disposable project."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from unittest.mock import patch

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))
sys.dont_write_bytecode = True
import export_game

PROJECT = TOOLS.parent
TASK_ID = 'bld-01'
DEMO_PRESET = 'Steam Demo Linux'
FULL_PRESET = 'Steam Linux'
PROBE = 'stamp_probe.gd'


def git(*args):
    return subprocess.check_output(['git', *args], cwd=PROJECT, text=True,
                                   env=dict(os.environ, GIT_OPTIONAL_LOCKS='0'))


def run_probe(project, expected, pack=None):
    command = [sys.executable, str(TOOLS / 'godot_task_runner.py'), '--project', str(project),
               '--task-id', TASK_ID, '--stream', '--', 'godot', '--headless', '--path', str(project)]
    if pack is not None:
        command.extend(['--main-pack', str(pack)])
    subprocess.run(command + ['--script', 'res://' + PROBE, '--', expected], check=True)


def snapshot(project):
    return {path.relative_to(project): path.read_bytes() for path in project.rglob('*') if path.is_file()}


def prove(root, demo_destination):
    fixture = root / 'source'
    fixture.mkdir()
    (fixture / 'project.godot').write_text('config_version=5\n', encoding='utf-8')
    shutil.copyfile(PROJECT / 'export_presets.cfg', fixture / 'export_presets.cfg')
    (fixture / 'scripts').mkdir()
    shutil.copyfile(PROJECT / 'scripts/build_info.gd', fixture / 'scripts/build_info.gd')
    shutil.copyfile(Path(__file__).with_name(PROBE), fixture / PROBE)

    revision = git('rev-parse', '--short=9', 'HEAD').strip().upper()
    date = git('log', '-1', '--format=%cs', revision.lower()).strip()
    status_before = git('status', '--porcelain')
    fixture_before = snapshot(fixture)
    run_probe(fixture, 'DEV BUILD')

    def check_source(case):
        assert git('status', '--porcelain') == status_before, case
        assert snapshot(fixture) == fixture_before, case
        assert not (PROJECT / export_game.BUILD_STAMP).exists(), case
        print(f'BLD01 SOURCE UNCHANGED: {case} (Git porcelain and fixture bytes)', flush=True)

    # This fixture has no art. Keep the actual export/staging/packing path and
    # replace the two cel-specific steps, which require the entire game.
    with patch.object(export_game, 'prepare_cel_variants'), patch.object(export_game, 'verify_export', return_value=0):
        for preset, prefix, filename in [(DEMO_PRESET, 'DEMO BUILD', 'demo.pck'), (FULL_PRESET, 'BUILD', 'full.pck')]:
            pack = root / filename
            assert export_game.export(preset, pack, TASK_ID, pack_only=True, project=fixture) == 0, preset
            check_source(preset)
            run_probe(fixture, f'{prefix} {date} · {revision}', pack)

        failure = root / 'failure.pck'
        missing_godot = root / 'missing-engine' / 'godot'
        assert export_game.export(FULL_PRESET, failure, TASK_ID, godot=str(missing_godot),
                                  pack_only=True, project=fixture) != 0
        assert not failure.exists()
        check_source('forced exporter failure')

        with patch.dict(os.environ, {'PATH': ''}):
            try:
                export_game.export(FULL_PRESET, failure, TASK_ID, pack_only=True, project=fixture)
            except ValueError as exc:
                assert str(exc).startswith('Cannot stamp export from Git:'), exc
                print(f'BLD01 MISSING GIT REJECTED: {exc}', flush=True)
            else:
                raise AssertionError('Export proceeded without Git')
        assert not failure.exists()
        check_source('missing Git')

    if demo_destination:
        demo_destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(root / 'demo.pck', demo_destination)
        print(f'BLD01 DEMO STAMP PACK: {demo_destination}', flush=True)
    print('BLD01 STAMP ROUND-TRIP: PASS', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--demo-pack', type=Path, help='Retain the demo stamp fixture pack for the visual probe.')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='bld01-stamp-') as directory:
        prove(Path(directory), args.demo_pack)
