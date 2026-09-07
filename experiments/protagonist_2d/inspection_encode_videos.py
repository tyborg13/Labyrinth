#!/usr/bin/env python3
"""Encode the proof's actual 1920x1080 Godot frames into per-action loop videos."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess

from PIL import Image


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("proof_directory", type=Path)
    parser.add_argument("--cycles", type=int, default=3)
    args = parser.parse_args()
    if args.cycles < 1:
        parser.error("Cycles must be positive")
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise SystemExit("ffmpeg is required to encode the captured frames")
    proof = args.proof_directory.expanduser().resolve()
    evidence = json.loads((proof / "validation.json").read_text())
    clips = evidence.get("video_clips", [])
    if not evidence.get("motion_frames_captured") or not clips:
        raise SystemExit("Run inspection_probe.gd with --capture-motion first")
    output = proof / "videos"
    output.mkdir(exist_ok=True)
    videos = []
    for clip in clips:
        name = clip["name"]
        if not re.fullmatch(r"[a-z_]+", name):
            raise ValueError("Unexpected clip name")
        count = int(clip["frame_count"])
        fps = float(clip["fps"])
        frames = Path(clip["frames_path"]).resolve()
        frames.relative_to(proof)
        extension = clip.get("frame_extension", "png")
        if extension not in {"png", "webp"}:
            raise ValueError(f"Unsupported capture format: {extension}")
        if count <= 0 or fps <= 0:
            raise ValueError(f"Invalid captured clip timing: {name}")
        for index in range(count):
            frame = frames / f"frame_{index:04d}.{extension}"
            if not frame.is_file():
                raise ValueError(f"Incomplete captured clip: {frame}")
            with Image.open(frame) as rendered:
                rendered.load()
                if rendered.size != (1920, 1080):
                    raise ValueError(f"Unexpected rendered frame size: {frame}")
        destination = output / f"{name}.mp4"
        command = [ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-framerate", str(fps), "-i", str(frames / f"frame_%04d.{extension}"), "-vf", f"loop=loop={args.cycles-1}:size={count}:start=0,setpts=N/({fps}*TB),fps=24,format=yuv420p", "-an", "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-movflags", "+faststart", str(destination)]
        subprocess.run(command, check=True)
        videos.append(destination)
    playlist = output / "showcase.txt"
    playlist.write_text("".join("file '" + str(path).replace("'", "'\\''") + "'\n" for path in videos))
    showcase = output / "protagonist_2d_showcase.mp4"
    subprocess.run([ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(playlist), "-c", "copy", "-movflags", "+faststart", str(showcase)], check=True)
    report = {"proof_kind": "actual Godot board capture", "cycles_per_action": args.cycles, "videos": [str(path) for path in videos], "showcase": str(showcase)}
    walking_clips = [path for path in videos if path.stem in {"front_walk", "rear_walk"}]
    if len(walking_clips) == 2:
        walking_playlist = output / "walking.txt"
        walking_playlist.write_text("".join("file '" + str(path).replace("'", "'\\''") + "'\n" for path in walking_clips))
        walking_video = output / "walking_front_rear.mp4"
        subprocess.run([ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(walking_playlist), "-c", "copy", "-movflags", "+faststart", str(walking_video)], check=True)
        report["walking_front_rear"] = str(walking_video)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
