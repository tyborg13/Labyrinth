#!/usr/bin/env python3
"""Run only the reported combined-branch failures through the task runner."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from program_suite_runner import write_child_bootstrap

OUTPUT = Path('/private/tmp/labyrinth_codex/ptf-01/combined-feedback')
WORKERS = 3
PROGRAMS = [
    'warband_test', 'snare_test', 'save_resume_boundary_test',
    'departed_run_cleanup_test', 'event_feedback_test', 'flurry_retirement_test',
    'glossary_test', 'board_tile_tooltip_test',
    'suites/full_scene_choices_program', 'suites/full_scene_clock_program',
    'enemy_intent_continuity',
]


def worker(name, directory):
    label = name.replace('/', '-')
    log_path = directory / f'{label}.log'
    bootstrap = directory / f'{label}.gd'
    target = ('res://tools/ptf01/enemy_intent_continuity_check.gd' if name == 'enemy_intent_continuity'
              else f'res://tests/{name}.gd')
    write_child_bootstrap(bootstrap, name, target=target)
    started = time.monotonic()
    with log_path.open('w') as stream:
        result = subprocess.run([
            sys.executable, 'tools/godot_task_runner.py', '--task-id', 'ptf-01',
            '--stream', '--', 'godot', '--headless', '--path', '.', '--script', str(bootstrap),
        ], cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
    text = log_path.read_text()
    details = [line for line in text.splitlines() if line.startswith(('FAIL:', 'ERROR:', 'SCRIPT ERROR:',
               'TEST RESULT:', 'Warband suite:', 'Snare suite:', 'PTF01 ENEMY', 'GLOSSARY',
               'BOARD TILE', 'Event feedback', 'DEPARTED', 'FLURRY'))]
    return {'program': name, 'exit_code': result.returncode,
            'elapsed_seconds': round(time.monotonic() - started, 3),
            'log': str(log_path), 'details': details}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--round', required=True)
    parser.add_argument('--programs', nargs='*', choices=PROGRAMS, default=PROGRAMS)
    args = parser.parse_args()
    # Standalone programs use AssetLoader's source-file paths. The headless
    # bootstrap supplies script class names without invoking a full suite.
    if not (ROOT / '.godot/global_script_class_cache.cfg').is_file():
        parser.error('Run the documented headless import bootstrap to build the script class registry first')
    directory = OUTPUT / args.round
    directory.mkdir(parents=True, exist_ok=True)
    rows = []
    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        futures = [pool.submit(worker, name, directory) for name in args.programs]
        for future in as_completed(futures):
            row = future.result()
            rows.append(row)
            print(f"PTF01 PROGRAM {row['program']}: exit={row['exit_code']} elapsed={row['elapsed_seconds']}s", flush=True)
    rows.sort(key=lambda row: PROGRAMS.index(row['program']))
    (directory / 'results.json').write_text(json.dumps(rows, indent=2) + '\n')
    print('PTF01 PROGRAMS:', json.dumps({row['program']: row['exit_code'] for row in rows}), flush=True)
    return 0 if all(row['exit_code'] == 0 for row in rows) else 1


if __name__ == '__main__':
    raise SystemExit(main())
