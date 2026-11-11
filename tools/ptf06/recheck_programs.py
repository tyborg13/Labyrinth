"""Run only the combined-gate failures through the task-local Godot runner."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
PROGRAMS = [
    'tests/warband_test.gd', 'tests/snare_test.gd',
    'tests/save_resume_boundary_test.gd', 'tests/departed_run_cleanup_test.gd',
    'tests/event_feedback_test.gd', 'tests/flurry_retirement_test.gd',
    'tests/glossary_test.gd', 'tests/board_tile_tooltip_test.gd',
    'tests/suites/full_scene_choices_program.gd',
    'tests/suites/full_scene_clock_program.gd',
    'tools/ptf06/enemy_intent_test.gd',
]
WORKERS = 2

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--program', action='append', choices=PROGRAMS)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    def run(program):
        log = args.output_dir / (Path(program).stem + '.log')
        command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', 'ptf-06',
                   '--stream', '--', 'godot', '--headless', '--path', '.', '--script', program]
        with log.open('w') as output:
            result = subprocess.run(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT)
        row = dict(program=program, returncode=result.returncode, log=str(log.resolve()))
        print(json.dumps(row), flush=True)
        return row
    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        rows = list(pool.map(run, args.program or PROGRAMS))
    (args.output_dir / 'results.json').write_text(json.dumps(rows, indent=2) + '\n')
    return int(any(row['returncode'] for row in rows))

if __name__ == '__main__':
    raise SystemExit(main())
