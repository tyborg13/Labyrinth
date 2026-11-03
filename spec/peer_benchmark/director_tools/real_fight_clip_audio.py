#!/usr/bin/env python3
"""real_fight_clip.py with the movie writer's mixed sound kept, a card played first, and a cue trace.
usage: clip.py <worktree> <out.mp4> -- <fixture flags>"""
import json, os, re, shutil, subprocess, sys
from pathlib import Path
TOOLS = Path("/Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark/spec/peer_benchmark/director_tools")
HERE = Path(__file__).resolve().parent
WT = Path(sys.argv[1]).resolve(); mp4 = Path(sys.argv[2]); split = sys.argv.index("--"); extra = sys.argv[split + 1:]
if subprocess.run(["sh", str(TOOLS / "owner_game_open.sh")], capture_output=True).returncode == 0:
    sys.exit("HOLD: a game is open")
sys.path.insert(0, str(WT / "tools"))
import visual_probe_runner as visual
HOME = Path("/private/tmp/labyrinth-godot-home")
probe = WT / "tests/fix18/_pol05_clip_probe.gd"
shutil.copyfile(HERE / "clip_probe.gd", probe)
movie = mp4.with_suffix(".avi"); manifest = mp4.with_suffix(".json"); manifest.unlink(missing_ok=True)
original = visual.build_command
def command(args, driver, log_file):
    c = original(args, driver, log_file)
    c[1:1] = ["--disable-vsync", "--fixed-fps", "60", "--write-movie", str(movie), "--resolution", "1920x1080"]
    return c
visual.build_command = command
name = mp4.stem
out = mp4.parent / (name + "_frames")
shutil.rmtree(out, ignore_errors=True)
os.environ.update({"LABYRINTH_CEL_LOOK": "all", "LABYRINTH_REAL_FIGHT_CAPTURE_OUTPUT": str(out)})
try:
    rc = visual.main(["tests/fix18/_pol05_clip_probe.gd", "--project", str(WT), "--task-id", "clip-" + name, "--no-headless",
        "--display-driver", "macos", "--audio-driver", "Dummy", "--timeout", "280", "--min-images", "0",
        "--godot-home-root", str(HOME), "--result-manifest", str(manifest), "--"] + extra)
finally:
    probe.unlink(missing_ok=True); Path(str(probe) + ".uid").unlink(missing_ok=True)
info = json.loads(manifest.read_text())
log = (HOME / info["attempts"][-1]["namespace"] / "godot.log").read_text()
(mp4.with_suffix(".log")).write_text(log)
for line in re.findall(r"^(?:REAL FIGHT CLIP.*|CLIP .*|CUE .*|SCRIPT ERROR.*|ERROR: .*)$", log, re.M)[:70]: print(line[:150])
start = re.findall(r"^REAL FIGHT CLIP START_FRAME=(\d+)$", log, re.M); end = re.findall(r"^REAL FIGHT CLIP END_FRAME=(\d+)$", log, re.M)
if not start or not end: sys.exit("no clip markers; rc=%s" % rc)
s, e = int(start[0]), int(end[0])
subprocess.run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-threads", "2", "-i", str(movie),
    "-vf", f"trim=start_frame={s}:end_frame={e},setpts=PTS-STARTPTS", "-af", f"atrim=start={s/60:.4f}:end={e/60:.4f},asetpts=PTS-STARTPTS",
    "-c:v", "libx264", "-crf", "24", "-preset", "medium", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", str(mp4)], check=True)
movie.unlink(); print("CLIP", mp4, "rc", rc, "frames", s, e, "MB %.1f" % (mp4.stat().st_size / 1e6))
