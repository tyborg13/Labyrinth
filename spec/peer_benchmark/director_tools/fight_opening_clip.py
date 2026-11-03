#!/usr/bin/env python3
"""Fight-opening clip with sound: <worktree> <out.mp4> [--probe=res/path.gd] [probe args]."""
import json, os, re, subprocess, sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
WT = Path(sys.argv[1]).resolve(); mp4 = Path(sys.argv[2]); extra = sys.argv[3:]
if subprocess.run(["sh", str(HERE / "owner_game_open.sh")], capture_output=True).returncode == 0:
    sys.exit("HOLD: a game is open")
sys.path.insert(0, str(WT / "tools"))
import visual_probe_runner as visual
HOME = Path("/private/tmp/labyrinth-godot-home")
probe_name = "spec/peer_benchmark/director_tools/fight_opening_clip_probe.gd"
contract = ""
for option in extra[:]:
    if option.startswith("--probe="):
        probe_name = option.removeprefix("--probe="); extra.remove(option)
    elif option.startswith("--proof-contract="):
        contract = option.removeprefix("--proof-contract="); extra.remove(option)
probe = WT / probe_name
if not probe.is_file() or not probe.resolve().is_relative_to(WT):
    sys.exit("probe must exist inside the requested worktree")
mp4.parent.mkdir(parents=True, exist_ok=True)
movie = mp4.with_suffix(".avi"); manifest = mp4.with_suffix(".json"); manifest.unlink(missing_ok=True)
original = visual.build_command
def command(args, driver, log_file):
    c = original(args, driver, log_file)
    c[1:1] = ["--disable-vsync", "--fixed-fps", "60", "--max-fps", "60", "--write-movie", str(movie), "--resolution", "1920x1080"]
    return c
visual.build_command = command
os.environ.setdefault("LABYRINTH_CEL_LOOK", "off")
rc = visual.main([probe_name, "--project", str(WT), "--task-id", "roar-01", "--no-headless",
    "--display-driver", "macos", "--audio-driver", "Dummy", "--timeout", "280", "--min-images", "0",
    "--godot-home-root", str(HOME), "--result-manifest", str(manifest)] +
    (["--proof-contract", contract] if contract else []) + ["--"] + extra)
if rc or not manifest.is_file():
    sys.exit("fight-opening probe failed; rc=%s; see %s" % (rc, manifest))
info = json.loads(manifest.read_text())
log = (HOME / info["attempts"][-1]["namespace"] / "godot.log").read_text()
mp4.with_suffix(".log").write_text(log)
for line in re.findall(r"^(?:POL27.*|CUE .*|SCRIPT ERROR.*|ERROR: .*)$", log, re.M)[:80]: print(line[:160])
start = re.findall(r"^POL27 CLIP START_FRAME=(\d+)", log, re.M); end = re.findall(r"^POL27 CLIP END_FRAME=(\d+)$", log, re.M)
if not start or not end: sys.exit("no clip markers; rc=%s" % rc)
s, e = int(start[0]), int(end[0])
subprocess.run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-threads", "2", "-i", str(movie),
    "-vf", f"trim=start_frame={s}:end_frame={e},setpts=PTS-STARTPTS,scale=1920:1080:flags=lanczos", "-af", f"atrim=start={s/60:.4f}:end={e/60:.4f},asetpts=PTS-STARTPTS",
    "-c:v", "libx264", "-crf", "24", "-preset", "medium", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", str(mp4)], check=True)
movie.unlink(); print("CLIP", mp4, "rc", rc, "frames", s, e, "MB %.1f" % (mp4.stat().st_size / 1e6))
