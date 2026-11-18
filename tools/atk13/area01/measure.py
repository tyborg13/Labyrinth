#!/usr/bin/env python3
"""Matched N=64 boss ladder repeats; production ladder and policy v2 unchanged."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
BOSSES = ('tharokh', 'vyraketh', 'vaeloryx', 'iskaldra', 'zekarion', 'noctyrax',
          'ashen_reaver', 'rimejaw', 'storm_cantor', 'gallows_roc', 'craghide', 'last_lamplighter')

def run(project, script, args, log):
    command = [sys.executable, str(ROOT/'tools/godot_task_runner.py'), '--task-id', 'area-01', '--timeout', '0', '--stream', '--', 'godot', '--headless', '--path', str(project), '--script', script, '--', *map(str, args)]
    log.with_suffix('.command.json').write_text(json.dumps(command))
    with log.open('w') as stream:
        result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
    if result.returncode or ' PASS ' not in log.read_text():
        raise RuntimeError(f'Worker failed: {log}')

def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('phase', choices=['before', 'after', 'report'])
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--workers', type=int, default=3)
    parser.add_argument('--bosses', nargs='+', choices=BOSSES, default=BOSSES)
    parser.add_argument('--result-suffix', default='')
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=True)
    baseline = out/'baseline-project'
    inputs = out/'inputs'
    inputs.mkdir(exist_ok=True)
    if args.phase == 'report':
        rows = []
        for boss in BOSSES:
            records = [[json.loads(line) for line in (out/phase/(f'{boss}-final.jsonl' if phase == 'after' and (out/phase/f'{boss}-final.jsonl').exists() else f'{boss}.jsonl')).read_text().splitlines()] for phase in ['before', 'after']]
            assert all(len(r) == 64 for r in records)
            assert [[{k:v for k,v in r.items() if k not in ['won','turns','turn_cap_reached','search_capped']} for r in rr] for rr in records][0] == [{k:v for k,v in r.items() if k not in ['won','turns','turn_cap_reached','search_capped']} for r in records[1]]
            wins = [sum(r['won'] for r in rr) for rr in records]
            rows.append({'boss': boss, 'N':64, 'before_wins':wins[0], 'after_wins':wins[1], 'delta_pp': (wins[1]-wins[0])*100/64})
        (out/'comparison.json').write_text(json.dumps(rows, indent=2)+'\n')
        for r in rows: print(f"{r['boss']}: {r['before_wins']}/64 -> {r['after_wins']}/64 ({r['delta_pp']:+.4f} pp)")
        print('AREA01 MATCHED DIFFICULTY PASS bosses=12 N=64')
        return
    if args.phase == 'before' and not baseline.exists():
        baseline.mkdir()
        # Immutable source snapshot: the implementation may proceed while baseline workers run.
        for child in ROOT.iterdir():
            if child.name == '.git': continue
            target = baseline/child.name
            if child.name in ['scripts', 'tools']:
                shutil.copytree(child, target, ignore=shutil.ignore_patterns('__pycache__', 'results'))
            else: target.symlink_to(child, target_is_directory=child.is_dir())
        (out/'before-source.json').write_text(json.dumps({str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'scripts').rglob('*.gd')}, indent=2))
    project = baseline if args.phase == 'before' else ROOT
    def capture(seed):
        dest = inputs/f'ladder-{seed}.bin'
        if dest.exists(): return
        run(baseline, 'tools/atk13/area01/ladder_capture.gd', ['--seed',seed,'--output',dest], out/f'capture-{seed}.log')
    if args.phase == 'before':
        with ThreadPoolExecutor(max_workers=args.workers) as pool: list(pool.map(capture, range(1,10)))
    phase = out/args.phase
    phase.mkdir(exist_ok=True)
    (phase/'source.json').write_text(json.dumps({str(p.relative_to(project)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (project/'scripts').rglob('*.gd')}, indent=2))
    def measure(boss):
        dest = phase/f'{boss}{args.result_suffix}.jsonl'
        if dest.exists() and len(dest.read_text().splitlines()) == 64: return
        run(project,'tools/atk13/area01/measure.gd',['--boss',boss,'--inputs',inputs,'--output',dest],phase/f'{boss}{args.result_suffix}.log')
    with ThreadPoolExecutor(max_workers=args.workers) as pool: list(pool.map(measure, args.bosses))
    print(f'AREA01 DIFFICULTY PASS phase={args.phase} bosses={len(args.bosses)} N=64')

if __name__ == '__main__': main()
