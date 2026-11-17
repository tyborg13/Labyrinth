#!/usr/bin/env python3
"""Headless component/semantic checks for the owner's native capture commands.

Does not produce PNGs or claim real-pointer or renderer verification.
"""
import json
from pathlib import Path
import subprocess
import sys
from capture_plan import PROJECT, ROOT, commands

OUTPUT=Path('/private/tmp/labyrinth_codex/atk-13/headless')

def main():
    OUTPUT.mkdir(parents=True,exist_ok=True)
    count=0
    for save,view,name,*extra in commands(ROOT,'census'):
        if view=='playback':continue # its purpose is native timed presentation
        out=OUTPUT/(name+'.json')
        command=[sys.executable,'tools/godot_task_runner.py','--task-id','atk-13','--stream','--','godot','--headless','--path','.','--script','tools/atk13/capture.gd','--','--save-dir',save,'--view',view,'--out',str(out),*extra]
        with (OUTPUT/(name+'.log')).open('w') as log:
            result=subprocess.run(command,cwd=PROJECT,stdout=log,stderr=subprocess.STDOUT)
        report=json.loads(out.read_text()) if out.exists() else {}
        good=result.returncode==0 and report.get('headless_semantics_only') and report.get('failures')==[]
        print(f'ATK13 HEADLESS {name}: '+('PASS' if good else 'FAIL'),flush=True)
        if not good:
            print((OUTPUT/(name+'.log')).read_text()[-5000:]);raise SystemExit(1)
        count+=1
    print(f'ATK13 CAPTURE SEMANTICS: PASS ({count} views; no renderer claims)',flush=True)
if __name__=='__main__':main()
