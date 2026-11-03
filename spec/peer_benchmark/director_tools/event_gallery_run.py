#!/usr/bin/env python3
"""usage: run.py <out dir> [--only=a,b]"""
import json, os, re, sys
from pathlib import Path
WT = Path("/Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark")
out = Path(sys.argv[1]); extra = sys.argv[2:]
sys.path.insert(0, str(WT / "tools"))
import visual_probe_runner as visual
HOME = Path("/private/tmp/labyrinth-godot-home")
original = visual.build_command
def command(args, driver, log_file):
    c = original(args, driver, log_file)
    c[1:1] = ["--resolution", "1920x1080"]
    return c
visual.build_command = command
manifest = out / "manifest.json"
manifest.unlink(missing_ok=True)
os.environ["LABYRINTH_CEL_LOOK"] = "all"
rc = visual.main(["spec/peer_benchmark/director_tools/event_gallery_probe.gd", "--project", str(WT), "--task-id", "event-gallery", "--no-headless",
    "--display-driver", "macos", "--audio-driver", "Dummy", "--timeout", "560", "--min-images", "0",
    "--godot-home-root", str(HOME), "--result-manifest", str(manifest), "--", f"--out={out}"] + extra)
info = json.loads(manifest.read_text())
log = (HOME / info["attempts"][-1]["namespace"] / "godot.log").read_text()
for line in re.findall(r"^(?:SCRIPT ERROR.*|ERROR: .*)$", log, re.M)[:12]: print(line[:170])
print("rc", rc, "events", log.count("EVENT GALLERY"))
