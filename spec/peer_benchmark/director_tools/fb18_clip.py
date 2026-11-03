#!/usr/bin/env python3
"""usage: fb18_clip.py <name> <out.mp4> -- probe args"""
import json, os, re, subprocess, sys
from pathlib import Path
WT = Path("/Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark")
name = sys.argv[1]; mp4 = Path(sys.argv[2]); extra = sys.argv[4:]
sys.path.insert(0, str(WT / "tools"))
import visual_probe_runner as visual
HOME = Path("/private/tmp/labyrinth-godot-home")
movie = mp4.with_suffix(".avi")
original = visual.build_command
def command(args, driver, log_file):
    c = original(args, driver, log_file)
    c[1:1] = ["--disable-vsync", "--fixed-fps", "60", "--write-movie", str(movie), "--resolution", "1920x1080"]
    return c
visual.build_command = command
manifest = mp4.with_suffix(".json")
manifest.unlink(missing_ok=True)
os.environ["LABYRINTH_CEL_LOOK"] = "all"
rc = visual.main(["spec/peer_benchmark/director_tools/fb18_clip_probe.gd", "--project", str(WT), "--task-id", f"fb18-{name}", "--no-headless",
    "--display-driver", "macos", "--audio-driver", "Dummy", "--timeout", "240", "--min-images", "0",
    "--godot-home-root", str(HOME), "--result-manifest", str(manifest), "--"] + extra)
info = json.loads(manifest.read_text())
log = (HOME / info["attempts"][-1]["namespace"] / "godot.log").read_text()
for line in re.findall(r"^(?:FB18 CLIP.*|SCRIPT ERROR.*|ERROR: .*|.*frames at 60 FPS.*)$", log, re.M)[:12]: print(line[:150])
start = int(re.findall(r"^FB18 CLIP START_FRAME=(\d+)$", log, re.M)[0]); end = int(re.findall(r"^FB18 CLIP END_FRAME=(\d+)$", log, re.M)[0])
subprocess.run(["ffmpeg","-y","-hide_banner","-loglevel","error","-threads","2","-i",str(movie),"-an","-vf",f"trim=start_frame={start}:end_frame={end},setpts=PTS-STARTPTS,scale=1920:1080,format=yuv420p","-r","60","-c:v","libx264","-crf","20","-preset","medium","-movflags","+faststart",str(mp4)],check=True)
movie.unlink(); print("CLIP",name,"rc",rc,"frames",start,end)
