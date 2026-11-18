#!/usr/bin/env python3
"""Recover the first natural ladder route containing the missing Cantor entry."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import subprocess
import sys
from measure import ROOT, run
PROOF_FIRST_SEED=10
PROOF_LAST_SEED=30
PROOF_WORKERS=3
OUT=Path('/private/tmp/labyrinth_codex/area-01/difficulty')
def capture(seed):
    dest=OUT/'inputs'/f'cantor-ladder-{seed}.bin'
    if not dest.exists():run(OUT/'baseline-project','tools/atk13/area01/ladder_capture.gd',['--seed',seed,'--output',dest],OUT/f'capture-cantor-{seed}.log')
    command=[sys.executable,'tools/godot_task_runner.py','--task-id','area-01','--stream','--','godot','--headless','--path',str(ROOT),'--script','tools/atk13/area01/inspect_inputs.gd','--',str(dest)]
    result=subprocess.check_output(command,cwd=ROOT,text=True)
    return '"storm_cantor":' in result
if __name__=='__main__':
    for first in range(PROOF_FIRST_SEED,PROOF_LAST_SEED+1,PROOF_WORKERS):
        seeds=list(range(first,min(first+PROOF_WORKERS,PROOF_LAST_SEED+1)))
        with ThreadPoolExecutor(max_workers=PROOF_WORKERS) as pool:found=list(pool.map(capture,seeds))
        print(f'AREA01 CANTOR DISCOVERY seeds={seeds} found={found}',flush=True)
        if any(found):
            (OUT/'inputs'/'cantor_ready').write_text(str(seeds)+'\n')
            print('AREA01 CANTOR ENTRY PASS')
            break
    else:
        (OUT/'inputs'/'cantor_failed').write_text('No natural Cantor entry before the explicit seed bound\n')
        raise RuntimeError('No natural Cantor entry before the explicit seed bound')
