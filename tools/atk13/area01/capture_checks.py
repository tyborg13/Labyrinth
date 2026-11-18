#!/usr/bin/env python3
"""Headless component checks only: no window, pixels, pointer or native claim."""
import argparse
import json
from pathlib import Path
import shlex
import subprocess
import sys
ROOT=Path(__file__).resolve().parents[3]
def main():
    p=argparse.ArgumentParser(__doc__)
    p.add_argument('--audit-dir',type=Path,required=True)
    p.add_argument('--output-dir',type=Path,required=True)
    a=p.parse_args();a.output_dir.mkdir(parents=True,exist_ok=True)
    plan=subprocess.check_output([sys.executable,'tools/atk13/area01/capture_plan.py','--audit-dir',str(a.audit_dir),'--output-dir',str(a.output_dir)],cwd=ROOT,text=True)
    for line in plan.splitlines():
        if line.startswith('#'):continue
        argv=shlex.split(line);tail=argv[argv.index('--')+1:]
        enemy=tail[tail.index('--enemy')+1];intent=tail[tail.index('--intent')+1]
        log=a.output_dir/f'{enemy}-{intent}.log'
        command=[sys.executable,'tools/godot_task_runner.py','--task-id','area-01','--stream','--','godot','--headless','--path','.', '--script','tools/atk13/area01/capture.gd','--',*tail,'--semantic','true']
        with log.open('w') as stream:r=subprocess.run(command,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT)
        if r.returncode:raise RuntimeError(f'Component check failed: {log}')
        print(f'AREA01 CAPTURE COMPONENT PASS {enemy}/{intent}',flush=True)
    print('AREA01 CAPTURE COMPONENTS PASS (2 cases; headless semantics only)')
if __name__=='__main__':main()
