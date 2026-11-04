#!/usr/bin/env python3
"""pol-40: real-time clip of a real fight's hand, driven by CLIP_PLAN, with a per-frame hand log.

usage: pol39_clip.py <worktree> <out.mp4> -- <fixture flags>
Run under `codex_unit.py locked`. Holds if the owner may be playing.
Writes <out>.log (HANDLOG/CLIP lines). KEEP_AVI=1 keeps the lossless movie for frame strips.
"""
import json, os, re, shutil, subprocess, sys
from pathlib import Path
HERE = Path("/Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark/spec/peer_benchmark/director_tools")
WT = Path(sys.argv[1]).resolve(); mp4 = Path(sys.argv[2]); split = sys.argv.index("--")
extra = sys.argv[split + 1:]
if subprocess.run(["sh", str(HERE / "owner_game_open.sh")], capture_output=True).returncode == 0:
    sys.exit("HOLD: a game is open")
sys.path.insert(0, str(WT / "tools"))
import visual_probe_runner as visual
HOME = Path("/private/tmp/labyrinth-godot-home")
probe = WT / "tests/fix18/_pol40_clip_probe.gd"
shutil.copyfile(Path(__file__).resolve().parent / "pol40_clip_probe.gd", probe)
movie = mp4.with_suffix(".avi"); manifest = mp4.with_suffix(".json"); manifest.unlink(missing_ok=True)
original = visual.build_command
def command(args, driver, log_file):
    c = original(args, driver, log_file)
    c[1:1] = ["--disable-vsync", "--fixed-fps", "60", "--write-movie", str(movie), "--resolution", "1920x1080"]
    return c
visual.build_command = command
name = mp4.stem
out = mp4.parent / (name + "_frames")
os.environ.update({"LABYRINTH_CEL_LOOK": "all", "LABYRINTH_REAL_FIGHT_CAPTURE_OUTPUT": str(out)})
try:
    rc = visual.main(["tests/fix18/_pol40_clip_probe.gd", "--project", str(WT), "--task-id", "clip-" + name, "--no-headless",
        "--display-driver", "macos", "--audio-driver", "Dummy", "--timeout", "280", "--min-images", "0",
        "--godot-home-root", str(HOME), "--result-manifest", str(manifest), "--"] + extra)
finally:
    probe.unlink(missing_ok=True); Path(str(probe) + ".uid").unlink(missing_ok=True)
info = json.loads(manifest.read_text())
log = (HOME / info["attempts"][-1]["namespace"] / "godot.log").read_text()
keep = re.findall(r"^(?:REAL FIGHT CLIP.*|SCRIPT ERROR.*|ERROR: .*|HANDLOG.*|CLIP .*|\s+at: .*)$", log, re.M)
mp4.with_suffix(".log").write_text("\n".join(keep) + "\n")
for line in keep:
    if not line.startswith("HANDLOG"): print(line[:300])
start = re.findall(r"^REAL FIGHT CLIP START_FRAME=(\d+)$", log, re.M); end = re.findall(r"^REAL FIGHT CLIP END_FRAME=(\d+)$", log, re.M)
if not start or not end: sys.exit("no clip markers; rc=%s" % rc)
subprocess.run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-threads", "2", "-i", str(movie), "-an", "-vf",
    f"trim=start_frame={start[0]}:end_frame={end[0]},setpts=PTS-STARTPTS", "-c:v", "libx264", "-crf", os.environ.get("CLIP_CRF", "20"), "-preset", "medium", "-pix_fmt", "yuv420p", str(mp4)], check=True)
(None if os.environ.get("KEEP_AVI") else movie.unlink()); print("CLIP", mp4, "rc", rc, "frames", start[0], end[0], "MB %.1f" % (mp4.stat().st_size / 1e6))
