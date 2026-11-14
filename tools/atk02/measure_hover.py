"""atk-02 interleaved A/B, B/A, A/B hover pairs (A = pre-atk-02 scripts, B = this tree).

A is a read-only snapshot: every path symlinks to this tree except the five
scripts atk-02 changes, which come from BASE_REF. One headless Godot at a time.

  python3 tools/atk02/measure_hover.py --save-dir <dir> --move x,y --card id --targets "x,y;x,y"
"""
from pathlib import Path
import argparse
import json
import statistics
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path('/private/tmp/labyrinth_codex/atk-02/hover')
BASELINE = OUTPUT / 'baseline'
BASE_REF = 'fd97dd02f'
OWNED = ('run_scene.gd', 'pass_forecast_presentation.gd', 'pass_forecast_focus_tooltip.gd',
         'pass_preview_prewarm.gd', 'pass_forecast_action_source.gd')


def prepare() -> None:
    (BASELINE / 'scripts').mkdir(parents=True, exist_ok=True)
    for child in ROOT.iterdir():
        target = BASELINE / child.name
        if child.name in ('.git', 'scripts') or target.exists() or target.is_symlink():
            continue
        target.symlink_to(child, target_is_directory=child.is_dir())
    for child in (ROOT / 'scripts').iterdir():
        target = BASELINE / 'scripts' / child.name
        if child.name not in OWNED and not target.exists() and not target.is_symlink():
            target.symlink_to(child, target_is_directory=child.is_dir())
    for name in OWNED:
        target = BASELINE / 'scripts' / name
        if target.is_symlink():
            target.unlink()
        target.write_bytes(subprocess.check_output(['git', 'show', f'{BASE_REF}:scripts/{name}'], cwd=ROOT))


def main() -> None:
    parser = argparse.ArgumentParser()
    for name in ('--save-dir', '--move', '--card', '--targets'):
        parser.add_argument(name, required=True)
    args = parser.parse_args()
    prepare()
    pairs = []
    for index, order in enumerate(('AB', 'BA', 'AB'), 1):
        results = {}
        for arm in order:
            stem = OUTPUT / f'{arm}{index}'
            project = BASELINE if arm == 'A' else ROOT
            command = [sys.executable, str(ROOT / 'tools/godot_task_runner.py'), '--project', str(project), '--task-id', f'atk-02-hover-{arm}{index}', '--', 'godot', '--headless', '--path', str(project),
                       '--script', 'res://tools/atk02/hover_benchmark.gd', '--', '--save-dir', args.save_dir, '--move', args.move, '--card', args.card, '--targets', args.targets, '--output', f'{stem}.json']
            with open(f'{stem}.log', 'w') as log:
                subprocess.run(command, cwd=project, stdout=log, stderr=subprocess.STDOUT, check=True)
            results[arm] = json.loads(Path(f'{stem}.json').read_text())
        row = {'pair': index, 'order': '/'.join(order), 'A': results['A'], 'B': results['B'],
               'median_delta_usec': results['B']['median_usec'] - results['A']['median_usec'],
               'p99_delta_usec': results['B']['p99_usec'] - results['A']['p99_usec']}
        pairs.append(row)
        print(f"ATK02 HOVER PAIR {index} {row['order']}: A median {results['A']['median_usec']} us p99 {results['A']['p99_usec']} us"
              f" | B median {results['B']['median_usec']} us p99 {results['B']['p99_usec']} us"
              f" | delta median {row['median_delta_usec']:+d} p99 {row['p99_delta_usec']:+d}"
              f" | sims during samples A {results['A']['simulations_during_samples']} B {results['B']['simulations_during_samples']}", flush=True)
    summary = {'base_ref': BASE_REF, 'pairs': pairs,
               'median_delta_median_usec': statistics.median(p['median_delta_usec'] for p in pairs),
               'rows_A': pairs[0]['A']['rows'], 'rows_B': pairs[0]['B']['rows']}
    (OUTPUT / 'pairs.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(f"ATK02 HOVER rows A {summary['rows_A']} | rows B {summary['rows_B']}")
    print(OUTPUT / 'pairs.json')


if __name__ == '__main__':
    main()
