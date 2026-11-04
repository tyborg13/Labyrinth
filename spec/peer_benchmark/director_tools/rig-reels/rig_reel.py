#!/usr/bin/env python3
"""Rig animation reel from a real fixture fight (director evidence, 2026-11-02).

usage: rig_reel.py <worktree> <work_dir> <plan.json> [--headless] -- <fixture flags>
  e.g. -- --scenario guardian --guardian-id last_lamplighter --guardian-case encounter --seed 83

Copies rig_reel_probe.gd into <worktree>/tests/fix18/ for one run and deletes it afterwards.
Windowed runs write a 1920x1080 60 fps movie (with sound) to <work_dir>/capture.avi; compose with rig_reel_compose.py.
Run windowed runs under `codex_unit.py locked`. Refuses to start if the owner may be playing.
"""
import json, os, re, shutil, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OWNER = Path("/Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark/spec/peer_benchmark/director_tools/owner_game_open.sh")
WT = Path(sys.argv[1]).resolve()
WORK = Path(sys.argv[2]).resolve()
PLAN = Path(sys.argv[3]).resolve()
split = sys.argv.index("--")
flags = sys.argv[4:split]
extra = sys.argv[split + 1:]
headless = "--headless" in flags
if not headless and subprocess.run(["sh", str(OWNER)], capture_output=True).returncode == 0:
    sys.exit("BLOCKED: owner playing (owner_game_open.sh exit 0)")
sys.path.insert(0, str(WT / "tools"))
import visual_probe_runner as visual

HOME = Path("/private/tmp/labyrinth-godot-home")
WORK.mkdir(parents=True, exist_ok=True)
probe = WT / "tests/fix18/_rig_reel_probe.gd"
shutil.copyfile(HERE / "rig_reel_probe.gd", probe)
movie = WORK / "capture.avi"
manifest = WORK / ("headless.json" if headless else "capture.json")
manifest.unlink(missing_ok=True)
out = WORK / ("headless_out" if headless else "capture_out")
shutil.rmtree(out, ignore_errors=True)
if not headless:
    movie.unlink(missing_ok=True)
    original = visual.build_command
    def command(args, driver, log_file):
        c = original(args, driver, log_file)
        c[1:1] = ["--disable-vsync", "--fixed-fps", "60", "--max-fps", "60", "--write-movie", str(movie), "--resolution", "1920x1080"]
        return c
    visual.build_command = command
os.environ.update({"LABYRINTH_CEL_LOOK": "all", "LABYRINTH_REAL_FIGHT_CAPTURE_OUTPUT": str(out), "REEL_PLAN": str(PLAN)})
if not headless:
    # The cel variants are a per-worktree build product (gitignored). Without them the game silently draws
    # the original art, so owner evidence would not match the shipped look (2026-11-03).
    cel = subprocess.run([sys.executable, "tools/cel_look.py", "build", "--if-stale"], cwd=str(WT), capture_output=True, text=True)
    if cel.returncode != 0:
        probe.unlink(missing_ok=True)
        sys.exit("BLOCKED: cel_look build failed in %s\n%s" % (WT, (cel.stdout + cel.stderr)[-2000:]))
name = "reel-" + WORK.name
if headless:
    try:
        run = subprocess.run([sys.executable, "tools/godot_task_runner.py", "--project", str(WT), "--task-id", name, "--timeout", "900", "--",
            "godot", "--headless", "--path", str(WT), "--script", "tests/fix18/_rig_reel_probe.gd", "--"] + extra + ["--validate-only"],
            cwd=str(WT), capture_output=True, text=True)
    finally:
        probe.unlink(missing_ok=True)
        Path(str(probe) + ".uid").unlink(missing_ok=True)
    log = run.stdout + "\n" + run.stderr
    (WORK / "headless.log").write_text(log)
    for line in re.findall(r"^(?:REEL (?:SEG|STEPS|BEGIN|FINISH).*|REAL FIGHT CAPTURE.*|SCRIPT ERROR.*|ERROR: .*|\s+at: .*)$", log, re.M)[:80]:
        print(line[:220])
    print("rc", run.returncode, "log", WORK / "headless.log")
    sys.exit(0)
args = ["tests/fix18/_rig_reel_probe.gd", "--project", str(WT), "--task-id", name, "--timeout", "1500", "--min-images", "0",
        "--godot-home-root", str(HOME), "--result-manifest", str(manifest)]
args += ["--headless"] if headless else ["--no-headless", "--display-driver", "macos", "--audio-driver", "Dummy"]
args += ["--"] + extra + (["--validate-only"] if headless else [])
try:
    rc = visual.main(args)
finally:
    probe.unlink(missing_ok=True)
    Path(str(probe) + ".uid").unlink(missing_ok=True)
info = json.loads(manifest.read_text())
log = (HOME / info["attempts"][-1]["namespace"] / "godot.log").read_text()
(WORK / ("headless.log" if headless else "capture.log")).write_text(log)
for line in re.findall(r"^(?:REEL (?:SEG|STEPS|BEGIN|FINISH).*|REAL FIGHT CAPTURE.*|SCRIPT ERROR.*|ERROR: .*|\s+at: .*)$", log, re.M)[:80]:
    print(line[:220])
print("rc", rc, "log", WORK / ("headless.log" if headless else "capture.log"))
if not headless and "Cel look variant unavailable" in log:
    sys.exit("CEL FALLBACK: the capture drew original art, not the shipped cel look; do not post it")
