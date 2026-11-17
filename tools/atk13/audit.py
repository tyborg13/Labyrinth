#!/usr/bin/env python3
"""Opt-in atk06 subclass: targeted Cantor census and status-inclusive receipts.

Does not modify atk06, game data, game code, saves or tests. Outputs are isolated.
"""
from __future__ import annotations
import argparse
import collections
import json
import os
from pathlib import Path
import subprocess
import sys
import time

PROJECT = Path(__file__).resolve().parents[2]
ROOT = Path('/private/tmp/labyrinth_codex/atk-13/audit')
PROOF_RUN_TIMEOUT_SECONDS = 900
# Natural guardian rooms, established with discover.gd. No forced room tiers.
SEEDS = {1: [1305,1306,1308,1310,1313,1316,1323,1327,1328],
         2: [1301,1302,1303,1304,1305,1307,1308,1314,1315],
         3: [1302,1303,1307,1309,1311,1312,1313,1314,1315]}
SOURCES = ['peal_direct','peal_chain','capacitor_shock','capacitor_damage','static_lash','spark_dart','broken_rhythm','new_wisp','reaimed','other']

def run(args):
    for tier in args.tiers:
        for seed in args.seeds or SEEDS[tier][:args.count]:
            dest = args.root / args.label / f'tier-{tier}-seed-{seed}-hp{args.health}'
            if (dest / 'completed.json').exists() and not args.force:
                print(f'SKIP {dest.name}', flush=True)
                continue
            dest.mkdir(parents=True, exist_ok=True)
            env = dict(os.environ, ATK13_TIER=str(tier), ATK13_TURNS=str(args.turns))
            cmd = [sys.executable,'tools/godot_task_runner.py','--task-id',os.environ.get('LABYRINTH_TASK_ID', 'atk-13'),'--timeout',str(PROOF_RUN_TIMEOUT_SECONDS),'--stream','--','godot','--headless','--path','.','--script','tools/atk13/audit.gd','--','--seed',str(seed),'--output-dir',str(dest),'--health',str(args.health),'--no-embrace','true']
            start = time.monotonic()
            with (dest / 'godot.log').open('w') as log:
                result = subprocess.run(cmd, cwd=PROJECT, env=env, stdout=log, stderr=subprocess.STDOUT)
            elapsed = time.monotonic() - start
            meta = dict(command=cmd, env={k:env[k] for k in ['ATK13_TIER','ATK13_TURNS']}, seconds=elapsed, exit=result.returncode)
            (dest / 'cost.json').write_text(json.dumps(meta, indent=2)+'\n')
            print(f'ATK13 RUN {dest.name}: exit={result.returncode} wall={elapsed:.3f}s',flush=True)
            if result.returncode:
                print((dest/'godot.log').read_text()[-6000:])
                raise SystemExit(result.returncode)
            totals = [r for r in read_rows(dest/'samples.jsonl') if r['kind']=='audit_totals']
            if not totals or totals[-1]['decision_points']==0:
                raise SystemExit(f'No audited decisions: {dest}')
            (dest/'completed.json').write_text(json.dumps(meta,indent=2)+'\n')

from reporting import rows as read_rows, report

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command',choices=['run','report'])
    parser.add_argument('--root',type=Path,default=ROOT)
    parser.add_argument('--label',required=True)
    parser.add_argument('--include-label',nargs='*',default=[])
    parser.add_argument('--tiers',type=int,nargs='+',default=[1,2,3])
    parser.add_argument('--seeds',type=int,nargs='+')
    parser.add_argument('--count',type=int,default=5)
    parser.add_argument('--health',type=int,default=9999)
    parser.add_argument('--turns',type=int,default=36)
    parser.add_argument('--force',action='store_true')
    args=parser.parse_args()
    (run if args.command=='run' else report)(args)
if __name__=='__main__':main()
