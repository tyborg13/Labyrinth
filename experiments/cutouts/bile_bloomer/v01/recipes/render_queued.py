"""Use maintained cutout render unchanged except a longer shared-lease wait.

Many enemy workers share this host. The observed 180-second lease wait expired
before launch. Only lease acquisition gets 1800 seconds; native startup,
execution, frames, packing and verification retain the maintained contract.
"""
from pathlib import Path
import json
import sys

CASE = Path(__file__).resolve().parents[1]
REPO = CASE.parents[3]
sys.path.insert(0, str(REPO / "tools"))
from cutout_pipeline import proof

original_run = proof.subprocess.run


def run(command, *args, **kwargs):
    if isinstance(command, list) and any(str(item).endswith("tools/visual_probe_runner.py") for item in command):
        separator = command.index("--") if "--" in command else len(command)
        command = command[:separator] + ["--gui-lease-timeout", "1800"] + command[separator:]
    return original_run(command, *args, **kwargs)


proof.subprocess.run = run
output = CASE / (sys.argv[1] if len(sys.argv) > 1 else "proof")
print(json.dumps(proof.render(CASE, output, "shale-bloomer-editable-cutout-and-gameplay-animation", "godot", "metal", "ffmpeg"), indent=2))
