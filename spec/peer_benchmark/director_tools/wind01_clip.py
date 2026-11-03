#!/usr/bin/env python3
"""Director: record one gameplay clip (1920x1080, 60 fps, game audio) from a worktree.
usage: clip.py <worktree> <probe.gd> <biome> <out.mp4>"""
import json, re, subprocess, sys
from pathlib import Path
WT = Path(sys.argv[1]); probe = sys.argv[2]; biome = sys.argv[3]; mp4 = Path(sys.argv[4])
sys.path.insert(0, str(WT / "tools"))
import visual_probe_runner as visual  # noqa: E402
HOME = Path("/private/tmp/labyrinth-godot-home")
mp4.parent.mkdir(parents=True, exist_ok=True)
movie = mp4.with_suffix(".avi")
original = visual.build_command
def command(args, driver, log_file):
    c = original(args, driver, log_file)
    c[1:1] = ["--disable-vsync", "--fixed-fps", "60", "--write-movie", str(movie), "--resolution", "1920x1080"]
    return c
visual.build_command = command
manifest = mp4.with_suffix(".json")
rc = visual.main([probe, "--project", str(WT), "--task-id", f"wind01-clip-{biome}", "--no-headless",
    "--display-driver", "macos", "--audio-driver", "Dummy", "--timeout", "400", "--min-images", "0",
    "--godot-home-root", str(HOME), "--result-manifest", str(manifest), "--", f"--biome={biome}"])
info = json.loads(manifest.read_text())
home = HOME / info["namespace"]
log = (home / "godot.log").read_text()
start = int(re.findall(r"^ORDERS CLIP START_FRAME=(\d+)$", log, re.M)[0]); end = int(re.findall(r"^ORDERS CLIP END_FRAME=(\d+)$", log, re.M)[0])
for line in re.findall(r"^(?:SNARE CLIP|ORDERS CLIP ROUND).*$", log, re.M): print(line)
spf = 48000 // 60
subprocess.run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-threads", "2", "-i", str(movie), "-map", "0:v:0", "-map", "0:a:0",
    "-vf", f"trim=start_frame={start}:end_frame={end},setpts=PTS-STARTPTS,scale=1920:1080,format=yuv420p",
    "-af", f"atrim=start_sample={start*spf}:end_sample={end*spf},asetpts=PTS-STARTPTS",
    "-r", "60", "-c:v", "libx264", "-crf", "20", "-preset", "medium", "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", str(mp4)], check=True)
movie.unlink(); manifest.unlink()
subprocess.run(["rm", "-rf", str(home)])
print(f"CLIP {biome} rc={rc} frames {start}-{end} -> {mp4}")
