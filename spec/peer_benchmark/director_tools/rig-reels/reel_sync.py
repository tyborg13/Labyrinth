#!/usr/bin/env python3
"""Movie-frame offset of a reel capture. The movie writer's frame index runs ahead of Engine.get_frames_drawn() by a
constant (31 frames on the first Lamplighter run). Measure it from the in-game caption: each segment's caption is set
on a logged frame, and its first movie frame is a sharp change in the caption box."""
import json, re, subprocess
from pathlib import Path
import numpy as np

BOX = (560, 10, 800, 50)  # x, y, w, h of the top-centre caption (1920x1080 movie)


def segments(work):
    log = (Path(work) / "capture.log").read_text()
    return [json.loads(m) for m in re.findall(r"^REEL SEG (\{.*\})$", log, re.M)]


def offset(work):
    work = Path(work)
    cache = work / "offset.json"
    if cache.exists(): return json.loads(cache.read_text())["offset"]
    x, y, w, h = BOX
    raw = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-threads", "2", "-i", str(work / "capture.avi"),
                          "-vf", f"crop={w}:{h}:{x}:{y},scale={w // 4}:{h // 4},format=gray", "-f", "rawvideo", "-threads", "2", "-"],
                         capture_output=True, check=True).stdout
    frames = np.frombuffer(raw, dtype=np.uint8)
    n = frames.size // ((w // 4) * (h // 4))
    frames = frames[:n * (w // 4) * (h // 4)].reshape(n, h // 4, w // 4).astype(np.int16)
    diff = np.abs(np.diff(frames, axis=0)).mean(axis=(1, 2))
    changes = {i + 1 for i in range(len(diff)) if diff[i] > 3}
    marks = [s["caption_frame"] for s in segments(work)]
    # A caption set while frames_drawn == m is first visible in drawn frame m, movie frame m + offset.
    best = max(range(0, 150), key=lambda k: sum(1 for m in marks if (m + k) in changes))
    result = {"offset": best, "matched": sum(1 for m in marks if (m + best) in changes), "segments": len(marks), "movie_frames": int(n)}
    cache.write_text(json.dumps(result))
    print("SYNC", work.name, result)
    return result["offset"]
