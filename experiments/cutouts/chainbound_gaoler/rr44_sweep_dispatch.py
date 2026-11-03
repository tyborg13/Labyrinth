"""Supervise bounded CPU shards, preserving every failure rather than retrying."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import shlex
import subprocess
from rr44_case import PROJECT, DEFAULTS

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--plan',required=True,type=Path);a=p.parse_args()
    commands=a.plan.read_text().splitlines()
    def run(line):
        try:
            result=subprocess.run(shlex.split(line),cwd=PROJECT,capture_output=True,text=True,timeout=DEFAULTS['sweep_shard_timeout_s'])
            return result.returncode,result.stdout+result.stderr
        except subprocess.TimeoutExpired as error:
            return 124,'RR44 SHARD TIMEOUT: '+line+'\n'+str(error)
    failures=0
    with ThreadPoolExecutor(max_workers=DEFAULTS['sweep_workers']) as pool:
        for index,(code,output) in enumerate(pool.map(run,commands)):
            print(output,flush=True);failures+=bool(code)
            if index%20==0:print(f'RR44 SHARDS COMPLETE: {index+1}/{len(commands)}',flush=True)
    print(f'RR44 SHARD EXECUTION: {len(commands)} shards; {failures} process failures',flush=True)
    raise SystemExit(bool(failures))
