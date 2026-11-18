#!/usr/bin/env python3
"""Opt-in per-instance rule truth audit; every Godot invocation uses its runner."""
import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import subprocess
import sys
import time

PROJECT = Path(__file__).resolve().parents[2]
PROOF_WORKERS = 3
PROOF_INSTANCE_TIMEOUT_SECONDS = 1800

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--root',type=Path,default=Path('/private/tmp/labyrinth_codex/area-02/f2/truth'))
    p.add_argument('--instances',nargs='+')
    p.add_argument('--task-id',default='area-02')
    p.add_argument('--report-only',action='store_true')
    a=p.parse_args();a.root.mkdir(parents=True,exist_ok=True)
    ids=a.instances or list(json.loads((PROJECT/'data/battlefield_rules.json').read_text())['instances'])
    def run(id):
        cmd=[sys.executable,'tools/godot_task_runner.py','--task-id',a.task_id,'--timeout',str(PROOF_INSTANCE_TIMEOUT_SECONDS),'--stream','--','godot','--headless','--path','.','--script','tools/atk13/rule_audit.gd','--','--instance',id,'--output',str(a.root/f'{id}.json')]
        start=time.monotonic()
        with (a.root/f'{id}.log').open('w') as log: result=subprocess.run(cmd,cwd=PROJECT,stdout=log,stderr=subprocess.STDOUT)
        meta={'command':cmd,'exit':result.returncode,'seconds':time.monotonic()-start}
        (a.root/f'{id}.cost.json').write_text(json.dumps(meta,indent=2)+'\n')
        if not (a.root/f'{id}.json').exists(): raise RuntimeError((a.root/f'{id}.log').read_text()[-4000:])
        print(f'AREA02 TRUTH CELL {id}: exit={result.returncode}',flush=True)
    if not a.report_only:
        with ThreadPoolExecutor(max_workers=PROOF_WORKERS) as pool: list(pool.map(run,ids))
    coverage = {}
    failures = []
    beats = []
    passes = []
    cantor = 0
    for instance in ids:
        raw = json.loads((a.root / f'{instance}.json').read_text())
        meta = json.loads((a.root / f'{instance}.cost.json').read_text())
        cell = raw['coverage'][instance]
        assert cell['fights'] == 3 and cell['beats'] > 0
        assert cell['passes'] == cell['forecast_known'] + cell['forecast_hidden']
        coverage.update(raw['coverage'])
        failures.extend(raw['failures'])
        if meta['exit'] and not raw['failures']:
            failures.append(f"{instance} runner exit {meta['exit']}")
        beats.extend(raw['beats'])
        passes.extend(raw['passes'])
        cantor += raw['cantor_new_tiles_included']
    if 'storm_cantor' in ids and not cantor:
        failures.append('No natural Bell Tender post-Pass inclusion witness')
    fields = ('drawn_but_not_red', 'impassable', 'occupied_raise', 'trap', 'brazier',
              'forecast_known', 'forecast_hidden', 'forecast_mismatches', 'forecast_safe')
    categories = {field: sum(cell.get(field, 0) for cell in coverage.values()) for field in fields}
    hidden = [entry for entry in passes if entry['hidden']]
    hidden_reasons = Counter(reason for entry in hidden for reason in entry['hidden'])
    hidden_loss_differences = sum(entry['shown_loss'] != entry['realized_loss'] for entry in hidden)
    result = {
        'categories': categories,
        'coverage': coverage,
        'cantor_new_tiles_included': cantor,
        'hidden_reasons': hidden_reasons,
        'hidden_loss_differences': hidden_loss_differences,
        'failures': failures,
        'beats': beats,
        'passes': passes,
    }
    (a.root / 'summary.json').write_text(json.dumps(result, indent=2) + '\n')
    beat_mismatches = sum(cell['mismatches'] for cell in coverage.values())
    print(f'AREA02 TRUTH: {"PASS" if not failures else "FAIL"} ({len(coverage)} instances; '
          f'{len(beats)} beats; {beat_mismatches} beat mismatches; '
          f'{categories["drawn_but_not_red"]} drawn but not red; {cantor} Cantor/Bell Tender tiles)', flush=True)
    print(f'AREA02 PASS FORECAST: {categories["forecast_known"]} visible; '
          f'{categories["forecast_hidden"]} hidden; {categories["forecast_mismatches"]} mismatches; '
          f'{categories["forecast_safe"]} Safe claims', flush=True)
    print('AREA02 TRUTH CATEGORIES: ' + json.dumps(categories, sort_keys=True), flush=True)
    return bool(failures)
if __name__=='__main__': sys.exit(main())
