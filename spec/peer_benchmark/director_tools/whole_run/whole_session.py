"""Sequential interleaved perf55 timings, then separate perf57 identity replays."""
from pathlib import Path
import argparse
import json
import os
import subprocess
import time

ROOT = Path('/Users/borgerding/workspace/Labyrinth.worktrees/perf-65')
BASE = Path('/private/tmp/labyrinth_codex/perf-65')
ORDER = [('before',83,False),('after',83,False),('after',84217,False),('before',84217,False),
         ('before',83,True),('after',83,True),('before',84217,True),('after',84217,True)]


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--stop-after',type=int,default=0)
    parser.add_argument('--smoke',action='store_true');parser.add_argument('--label',default='');args=parser.parse_args()
    label=args.label or ('smoke' if args.smoke else 'whole')
    records=[]
    for side,seed,identity in (ORDER if not args.smoke else [('before',83,True),('after',83,True)]):
        out=BASE/f'{label}-{side}-{seed}{"-identity" if identity else ""}'
        out.mkdir(exist_ok=False)
        project=BASE/f'whole-{"identity-" if identity else ""}{side}'
        command=['python3','tools/godot_task_runner.py','--task-id','perf-65','--timeout','1800','--stream','--',
                 'godot','--headless','--path',str(project),'--fixed-fps','120','--script',
                 str(BASE/'tools'/('hunt_identity.gd' if identity else 'hunt.gd')),'--','--seed',str(seed),
                 '--no-embrace','true','--output-dir',str(out)]
        if args.stop_after:command.extend(['--stop-after',str(args.stop_after)])
        env=dict(os.environ,LABYRINTH_CEL_LOOK='off',PERF65_SIDE=side,PERF65_IDENTITY='1' if identity else '0',
                 PERF65_OUTPUT=str(out),PERF65_REFERENCE=str(BASE/f'{label}-before-{seed}-identity'))
        row={'side':side,'seed':seed,'identity':identity,'command':command,'started':time.time()}
        print('PERF65 WHOLE START',side,seed,'identity='+str(identity),flush=True)
        with (out/'run.log').open('w') as log:
            result=subprocess.run(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT)
        row.update(exit_code=result.returncode,ended=time.time());records.append(row)
        (BASE/(label+'-session.json')).write_text(json.dumps(records,indent=2))
        print('PERF65 WHOLE END',side,seed,'exit='+str(result.returncode),'seconds=%.1f'%(row['ended']-row['started']),flush=True)
        if result.returncode:
            print((out/'run.log').read_text()[-6000:]);raise SystemExit(result.returncode)
        if identity:
            oracle=json.loads((out/'save-boundaries.json').read_text())
            if oracle['byte_failures'] or oracle['write_failures']:
                print('ORACLE FAILURE',json.dumps([r for r in oracle['rows'] if r.get('byte_equal') is False][:5]),flush=True)
                raise SystemExit(1)
    print('PERF65 WHOLE SESSION: PASS (%d matched runs)'%len(records),flush=True)


if __name__=='__main__':main()
