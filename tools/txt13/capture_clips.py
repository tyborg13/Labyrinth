#!/usr/bin/env python3
"""Capture the three pinned txt-13 combat tooltips on the native renderer."""

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))
from tooltip_loops.record import FPS, ROOT, movie_clock

OUT = Path("/private/tmp/labyrinth_codex/txt-13/clips")
PROBE = "tools/txt13/capture.gd"
NAMES = (
    "fade_gloam_stalker_combat_tooltip",
    "lob_slagmaster_barrage_combat_tooltip",
    "marked_burrow_grub_combat_tooltip",
)
SECONDS = 5
CRF = 22
TIMEOUT = 240
SIZE = (1920, 1080)


def encode_clip(raw: Path, video: Path, metadata: dict) -> None:
    x, y, width, height = metadata["crop"]
    frames = FPS * SECONDS
    if not (0 <= x < x + width <= SIZE[0] and 0 <= y < y + height <= SIZE[1] and width * 9 == height * 16):
        raise ValueError(f"Invalid 16:9 capture crop for {video.name}: {metadata['crop']}")
    if metadata["fps"] != FPS or metadata["frames"] != frames or raw.stat().st_size != width * height * 3 * frames:
        raise ValueError(f"Incomplete capture footage for {video.name}")
    subprocess.run([
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-nostdin", "-y",
        "-f", "rawvideo", "-pixel_format", "rgb24", "-video_size", f"{width}x{height}",
        "-framerate", str(FPS), "-i", str(raw), "-an", "-c:v", "libx264", "-crf", str(CRF),
        "-vf", f"scale={SIZE[0]}:{SIZE[1]}:flags=lanczos", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(video),
    ], check=True)
    entries = "stream=codec_name,width,height,pix_fmt,r_frame_rate,nb_frames,duration"
    stream = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", entries, "-of", "json", str(video),
    ]))["streams"][0]
    if (stream["codec_name"], stream["width"], stream["height"], stream["pix_fmt"], stream["r_frame_rate"],
        int(stream["nb_frames"]), float(stream["duration"])) != ("h264", *SIZE, "yuv420p", f"{FPS}/1", frames, SECONDS):
        raise ValueError(f"Unexpected MP4 stream for {video.name}: {stream}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--output-dir", type=Path, default=OUT)
    parser.add_argument("--check-only", action="store_true", help="Check fixture, tooltip and crop geometry headlessly")
    args = parser.parse_args()
    if args.check_only:
        return subprocess.call([
            "python3", "tools/godot_task_runner.py", "--task-id", "txt-13", "--stream", "--", args.godot,
            "--headless", "--path", ".", "--script", PROBE, "--", "--semantics-only", "--clips",
        ], cwd=ROOT)

    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".capture-", dir=output) as directory:
        scratch = Path(directory)
        wrapper = movie_clock(scratch, args.godot)
        env = dict(os.environ, TXT13_CLIP_RAW=str(scratch), TXT13_CLIP_OUT=str(output), LABYRINTH_CEL_LOOK="all")
        result = subprocess.call([
            "python3", "tools/visual_probe_runner.py", PROBE, "--task-id", "txt-13", "--godot", str(wrapper),
            "--no-headless", "--display-driver", "macos", "--audio-driver", "Dummy", "--timeout", str(TIMEOUT),
            "--expect-size", "1920x1080", "--min-images", str(len(NAMES)),
            "--result-manifest", str(output / "manifest.json"), "--overwrite-result-manifest",
        ], cwd=ROOT, env=env)
        if result:
            return result
        report = []
        for name in NAMES:
            metadata = json.loads((scratch / f"{name}.json").read_text())
            video = scratch / f"{name}.mp4"
            encode_clip(scratch / f"{name}.rgb", video, metadata)
            report.append(dict(metadata, video=video.name, still=f"{name}_1920x1080.png", crf=CRF))
        for entry in report:
            video = output / entry["video"]
            (scratch / video.name).replace(video)
            print(video)
        (output / "clips.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"TXT-13 CLIPS RESULT: PASS ({len(NAMES)} clips, 1920x1080, {FPS} fps, {SECONDS} s, H.264 CRF {CRF})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
