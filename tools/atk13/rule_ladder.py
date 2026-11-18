#!/usr/bin/env python3
"""Run area-02's matched N=64 natural-room difficulty cells, through the runner."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import subprocess
import sys
import time

INSTANCES = ('storm_cantor','zekarion','dynamo','snare_lightning','ashen_reaver','rimejaw','gallows_roc','vyraketh','iskaldra','vaeloryx')
PROJECT = Path(__file__).resolve().parents[2]
PROOF_CELL_TIMEOUT_SECONDS = 14400  # 64 full policy searches, checkpointed each fight.
PROOF_WORKERS = 3

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--label',required=True)
    p.add_argument('--root',type=Path,default=Path('/private/tmp/labyrinth_codex/area-02/ladder'))
    p.add_argument('--project',type=Path,default=PROJECT)
    p.add_argument('--runs',type=int,default=64)
    p.add_argument('--instances',nargs='+',default=list(INSTANCES))
    p.add_argument('--report',action='store_true')
    p.add_argument('--workers',type=int,default=PROOF_WORKERS)
    p.add_argument('--resume',action='store_true')
    a=p.parse_args(); out=a.root/a.label; out.mkdir(parents=True,exist_ok=True)
    def run(id):
        dest=out/f'{id}.json'
        cmd=[sys.executable,str(a.project/'tools/godot_task_runner.py'),'--task-id','area-02','--timeout',str(PROOF_CELL_TIMEOUT_SECONDS),'--stream','--','godot','--headless','--path',str(a.project),'--script','tools/atk13/rule_ladder.gd','--','--instance',id,'--runs',str(a.runs),'--output',str(dest)]
        if a.resume: cmd.append('--resume')
        start=time.monotonic()
        with (out/f'{id}.log').open('w') as log: result=subprocess.run(cmd,cwd=a.project,stdout=log,stderr=subprocess.STDOUT)
        meta={'command':cmd,'exit':result.returncode,'seconds':time.monotonic()-start}
        (out/f'{id}.cost.json').write_text(json.dumps(meta,indent=2)+'\n')
        print(f'AREA02 LADDER CELL {a.label}/{id}: exit={result.returncode}',flush=True)
        if result.returncode: raise RuntimeError((out/f'{id}.log').read_text()[-5000:])
    if not a.report:
        with ThreadPoolExecutor(max_workers=a.workers) as pool: list(pool.map(run,a.instances))
    rows=[]
    for id in a.instances:
        records=json.loads((out/f'{id}.json').read_text())['results']
        assert len(records)==a.runs
        rows.append({'instance':id,'n':len(records),'wins':sum(r['won'] for r in records),'mean_turns':sum(r['turns'] for r in records)/len(records),'mean_hp_lost':sum(r['hp_lost'] for r in records)/len(records)})
    (out/'summary.json').write_text(json.dumps(rows,indent=2)+'\n')
    print(f'AREA02 LADDER {a.label}: PASS ({len(rows)} instances; N={a.runs} each)',flush=True)
if __name__=='__main__': main()
