#!/usr/bin/env python3
"""Stage caller instrumentation outside the checkout and replay the real demo.

The cold/warm labels describe process/OS-cache order, not an OS cache purge.
Every invocation uses a fresh progression profile. Never starts a native run.
"""
from pathlib import Path
import argparse
import os
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
SPY = 'preload("res://tools/perf126/load_spy.gd")'
RUNNER_TIMEOUT_SECONDS = 85
PROCESS_TIMEOUT_SECONDS = 95


def stage(project):
    project.mkdir(parents=True)
    for source in ROOT.iterdir():
        if source.name in {'.git', '.codex', '.agents'}:
            continue
        target = project / source.name
        if source.name in {'scripts', 'tools'}:
            shutil.copytree(source, target, ignore=shutil.ignore_patterns('__pycache__'))
        else:
            target.symlink_to(source, target_is_directory=source.is_dir())
    for folder in ('scripts', 'tools/hitch_census'):
        for path in (project / folder).rglob('*.gd'):
            source = path.read_text()
            # Preserve line numbers for all original call sites.
            source = source.replace('ResourceLoader.load(', SPY + '.load_resource(')
            source = '\n'.join(line if re.search(r'func load\(', line) else re.sub(r'(?<![\w.])load\(', SPY + '.load_resource(', line) for line in source.split('\n'))
            if path.name == 'asset_loader.gd':
                source = source.replace('static func _load_source_image(', 'static func _perf126_source_image(')
                source += '''\nstatic func _load_source_image(path: String, allow_cel: bool = true) -> Image:
\tvar started: int = Time.get_ticks_usec()
\tvar result: Image = _perf126_source_image(path, allow_cel)
\tpreload("res://tools/perf126/load_spy.gd").record(path, started, "source_image_decode")
\treturn result
'''
            path.write_text(source)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--project', type=Path, help='reuse an already instrumented snapshot')
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        parser.error('choose a fresh output directory')
    project = args.project.resolve() if args.project else output / 'project'
    if args.project:
        output.mkdir(parents=True)
    else:
        stage(project)
    env = dict(os.environ, LABYRINTH_HITCH_TRACE='1', LABYRINTH_CEL_LOOK='all',
               SteamDeck='1', LABYRINTH_DEMO='1', LABYRINTH_PROBE_WINDOW='1')
    command = [sys.executable, str(ROOT / 'tools/godot_task_runner.py'), '--task-id', 'perf-126',
               '--project', str(project), '--timeout', str(RUNNER_TIMEOUT_SECONDS), '--stream', '--', 'godot',
               '--headless', '--path', str(project), '--script', 'tools/hitch_census/driver.gd',
               '--', '--driver=demo', '--seed=7', '--seconds=60', '--headless-smoke',
               '--output=' + str(output / 'trace')]
    (output / 'command.txt').write_text(' '.join(command) + '\n')
    with (output / 'godot.log').open('w') as log:
        result = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=PROCESS_TIMEOUT_SECONDS)
    print(f'PERF126 REPLAY: exit={result.returncode} output={output}', flush=True)
    return result.returncode


if __name__ == '__main__':
    raise SystemExit(main())
