#!/usr/bin/env python3
"""Only focused checks requested by the area-01 brief; no full suite."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import subprocess
import sys
ROOT=Path(__file__).resolve().parents[3]
OUT=Path('/private/tmp/labyrinth_codex/area-01/checks')
CHECKS=('tools/atk13/area01/rules_tests.gd','tools/atk13/area01/focused_suites.gd',
        'tests/dragon_committed_patterns_test.gd','tests/dragon_feedback_mechanics_test.gd',
        'tests/dragon_rewards_test.gd','tests/dragon_reward_feedback_test.gd',
        'tests/dragon_trophy_feedback_test.gd','tests/dragon_wallet_ack_test.gd',
        'tests/guardian_rules_test.gd','tests/threats_at_rest_test.gd',
        'tools/atk03/focused_tests.gd','tools/atk04/focused_tests.gd')
def run(script):
    stem=script.replace('/','-').removesuffix('.gd')
    command=[sys.executable,'tools/godot_task_runner.py','--task-id','area-01','--stream','--','godot','--headless','--path','.', '--script',script]
    with (OUT/f'{stem}.log').open('w') as log:r=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
    print(f'AREA01 CHECK {script}: exit={r.returncode}',flush=True)
    return {'script':script,'exit':r.returncode,'log':str(OUT/f'{stem}.log')}
def main():
    import argparse
    import json
    global OUT
    parser=argparse.ArgumentParser(__doc__)
    parser.add_argument('--output-dir',type=Path,default=OUT)
    parser.add_argument('--workers',type=int,default=3)
    args=parser.parse_args()
    OUT=args.output_dir.resolve()
    OUT.mkdir(parents=True,exist_ok=True)
    with ThreadPoolExecutor(max_workers=args.workers) as pool:rows=list(pool.map(run,CHECKS))
    (OUT/'results.json').write_text(json.dumps(rows,indent=2)+'\n')
    print('AREA01 FOCUSED CHECKS COMPLETE')
if __name__=='__main__':main()
