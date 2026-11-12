"""Matched sequential A/B, B/A, A/B hover measurements via the task runner."""
from pathlib import Path
import json
import subprocess
import sys
ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path('/private/tmp/labyrinth_codex/ptf-08')
BASELINE = OUTPUT / 'feedback3-baseline'
subprocess.run([sys.executable, str(ROOT / 'tools/ptf08/prepare_feedback3_baseline.py')], check=True, cwd=ROOT)
pairs = []
for pair_index, order in enumerate(('AB', 'BA', 'AB'), 1):
    for arm in order:
        stem = f'feedback3-{arm}{pair_index}'
        project = BASELINE if arm == 'A' else ROOT
        (OUTPUT / f'{stem}.json').unlink(missing_ok=True)
        command = [sys.executable, str(ROOT / 'tools/godot_task_runner.py'), '--task-id', 'ptf-08', '--stream', '--', 'godot', '--headless', '--path', str(project), '--script', 'tools/ptf08/attack_benchmark.gd', '--', '--output', stem]
        with (OUTPUT / f'{stem}.log').open('w') as log:
            subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)
    before = json.loads((OUTPUT / f'feedback3-A{pair_index}.json').read_text())
    after = json.loads((OUTPUT / f'feedback3-B{pair_index}.json').read_text())
    if before['geometry'] != after['geometry']:
        raise RuntimeError('PASS or its parent moved')
    row = {'pair': pair_index, 'order': '/'.join(order), 'A': before, 'B': after,
           'median_delta_usec': after['median_usec'] - before['median_usec'],
           'p99_delta_usec': after['p99_usec'] - before['p99_usec']}
    pairs.append(row)
    print(f"PTF08 HOVER PAIR {pair_index} {'/'.join(order)}: A median={before['median_usec']}us p99={before['p99_usec']}us; B median={after['median_usec']}us p99={after['p99_usec']}us", flush=True)
(OUTPUT / 'feedback3-hover-pairs.json').write_text(json.dumps({'baseline': json.loads((BASELINE / 'baseline.json').read_text()), 'pairs': pairs}, indent=2)+'\n')
print('PTF08 PASS GEOMETRY: UNCHANGED', flush=True)
