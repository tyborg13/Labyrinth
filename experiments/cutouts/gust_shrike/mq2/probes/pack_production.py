#!/usr/bin/env python3
"""Encode the real board capture at its measured presentation timestamps."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
from production_coverage import verify

REQUIRED_CLIPS = {"idle", "move", "dive", "talon_rake", "hover", "hit", "death"}
LAST_FRAME_SECONDS = 1 / 30  # Capture-only terminal-frame duration.


def pack(capture):
    manifest_path = capture / "frames.json"
    manifest = json.loads(manifest_path.read_text())
    verify(capture, manifest)
    if not manifest["ok"] or not REQUIRED_CLIPS.issubset(set(manifest["clips"])):
        raise ValueError("A successful seven-clip production capture is required")
    frames = manifest["frames"]
    if not frames or manifest["size"] != [1920, 1080] or manifest["ui_scale"] != 1.0:
        raise ValueError("Production proof must be 1920x1080 at 100%")
    concat = capture / "production.ffconcat"
    video = capture / "production_reel.mp4"
    if video.exists(): raise ValueError("Refusing to replace a production reel")
    lines = ["ffconcat version 1.0"]
    hashes = {}
    for index, frame in enumerate(frames):
        path = capture / frame["file"]
        if path.parent != capture or not path.name.startswith("frame_") or path.suffix != ".png":
            raise ValueError("Unexpected capture filename")
        hashes[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
        duration = frames[index + 1]["seconds"] - frame["seconds"] if index + 1 < len(frames) else LAST_FRAME_SECONDS
        if duration <= 0: raise ValueError("Nonmonotonic capture timestamps")
        lines += ["file '" + path.name + "'", "duration %.9f" % duration]
    lines.append("file '" + frames[-1]["file"] + "'")
    concat.write_text("\n".join(lines) + "\n")
    subprocess.run(["ffmpeg", "-v", "error", "-f", "concat", "-safe", "1", "-i", str(concat),
        "-an", "-vf", "fps=60", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(video)], check=True)
    subprocess.run(["ffmpeg", "-v", "error", "-i", str(video), "-f", "null", "-"], check=True)
    (capture / "production_reel_proof.json").write_text(json.dumps({"ok": True,
        "frames_sha256": hashes, "manifest_sha256": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
        "video_sha256": hashlib.sha256(video.read_bytes()).hexdigest(), "full_decode": "PASS"}, indent=2) + "\n")
    print("SHRIKE PRODUCTION REEL: PASS " + str(video))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    args = parser.parse_args()
    pack(args.capture.resolve())
