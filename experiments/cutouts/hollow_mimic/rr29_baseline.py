"""Measure the preserved rr-20 slide with the maintained real-bone sampler."""
import subprocess
import sys
from rr29_build import ROOT, BASE, read_json

PROOF_TIMEOUT_SECONDS = 180


def sample(output):
    output.parent.mkdir(parents=True,exist_ok=True)
    result=subprocess.run([sys.executable,'tools/godot_task_runner.py','--task-id','rr-29','--stream','--',
        'godot','--headless','--path','.','--script','tests/rr20/samples.gd','--',
        '--case',str(BASE),'--output',str(output)],cwd=ROOT,capture_output=True,text=True,
        timeout=PROOF_TIMEOUT_SECONDS)
    if result.returncode:raise ValueError(result.stdout+result.stderr)
    return read_json(output)
