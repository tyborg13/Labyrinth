#!/usr/bin/env python3
"""Render/verify a prepared cohort with two workers and shared native GUI lease."""
from __future__ import annotations
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[4]

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cases', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--task-id', required=True)
    args = parser.parse_args()
    cases = sorted(p for p in args.cases.resolve().glob('*/cutout.json') if not p.parent.name.endswith('_baseline'))
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    logs = output / 'logs'
    logs.mkdir(exist_ok=True)
    tool = ROOT / 'tools/cutout_workflow.py'
    def run(case: Path) -> dict:
        name = case.parent.name
        start = time.monotonic()
        proof = output / name
        print('START ' + name, flush=True)
        with (logs / (name + '.render.log')).open('w') as log:
            code = subprocess.call([sys.executable, str(tool), 'render', str(case), '--output', str(proof), '--task-id', args.task_id, '--gui-lease-timeout', '1200'], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        verified = False
        if code == 0:
            with (logs / (name + '.verify.json')).open('w') as log:
                verified = subprocess.call([sys.executable, str(tool), 'verify-render', str(case), '--output', str(proof)], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT) == 0
        result = {'actor': name, 'case': str(case), 'proof': str(proof), 'render_exit': code, 'verified': verified, 'elapsed_seconds': round(time.monotonic()-start, 2)}
        print(('PASS ' if verified else 'FAIL ') + name, flush=True)
        return result
    results = []
    with ThreadPoolExecutor(max_workers=2) as pool:
        futures = [pool.submit(run, case) for case in cases]
        for future in as_completed(futures):
            results.append(future.result())
            (output / 'results.json').write_text(json.dumps(sorted(results, key=lambda item: item['actor']), indent=2) + '\n')
    return 0 if all(item['verified'] for item in results) else 1

if __name__ == '__main__':
    raise SystemExit(main())
