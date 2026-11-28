#!/usr/bin/env python3
"""Measure uncompressed reveal frames and assemble paired native takes."""

import argparse
import json
import math
from pathlib import Path
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "fel20"))
from report import RGBA_BYTES, convert_capture  # noqa: E402


# Mean RGB luminance is reported on the 0–255 scale of the RGBA capture.
LUMINANCE_TOLERANCE = 6.0
MAX_FRAME_MS = 50.0
PRESS_OFFSET_MS = 800.0
STRIP_FPS = 30
STRIP_COLUMNS = 6
THUMBNAIL_WIDTH = 320
THUMBNAIL_HEIGHT = 180
MOVIE = "00001-title.reveal.mp4"


def mean_luminance(pixels):
    return (0.2126 * sum(pixels[0::4]) + 0.7152 * sum(pixels[1::4])
            + 0.0722 * sum(pixels[2::4])) / (RGBA_BYTES // 4)


def measure(path, build):
    spool = path / "spool" / "00001"
    record = spool / "record.json"
    row = json.loads(record.read_text())
    frames = row["frames"]
    if min(row["ready_ms"], row["steady_ms"], row["reveal_ms"]) < 0:
        raise ValueError(f"{build}/{row['case']} did not reach its first screen")
    reveal = next(index for index, frame in enumerate(frames)
                  if frame["phase"] in ("revealing", "complete") and frame["alpha"] < 1.0)
    steady = next(index for index, frame in enumerate(frames)
                  if frame["ms"] >= row["steady_ms"])
    if not 0 < reveal <= steady:
        raise ValueError(f"{build}/{row['case']} has no paired reveal endpoints")

    with (spool / "frames.rgba").open("rb") as raw:
        raw.seek((reveal - 1) * RGBA_BYTES)
        means = []
        for _ in range(reveal - 1, steady + 1):
            pixels = raw.read(RGBA_BYTES)
            if len(pixels) != RGBA_BYTES:
                raise ValueError("truncated framebuffer spool")
            means.append(mean_luminance(pixels))
    limit = min(means[0], means[-1]) - LUMINANCE_TOLERANCE
    row["dark_frames"] = sum(mean < limit for mean in means[1:-1])
    row["cover_luminance"] = means[0]
    row["steady_luminance"] = means[-1]
    row["minimum_reveal_luminance"] = min(means[1:])
    row.update(id="title.reveal", action=1, flags=[])
    record.write_text(json.dumps(row) + "\n")
    convert_capture(record, path)

    run_ffmpeg = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-nostdin", "-y"]
    strip_ms = max(1000.0 / STRIP_FPS, row["ready_ms"] - PRESS_OFFSET_MS)
    start_ms = min(PRESS_OFFSET_MS, row["ready_ms"])
    count = max(1, math.floor(strip_ms * STRIP_FPS / 1000.0) + 1)
    rows = math.ceil(count / STRIP_COLUMNS)
    filters = (f"fps={STRIP_FPS},scale={THUMBNAIL_WIDTH}:{THUMBNAIL_HEIGHT},"
               f"tile={STRIP_COLUMNS}x{rows}:nb_frames={count}")
    subprocess.run(run_ffmpeg + [
        "-ss", str(start_ms / 1000.0), "-i", str(path / MOVIE),
        "-an", "-vf", filters, "-frames:v", "1", str(path / "reveal-30fps.png"),
    ], check=True)
    print(f"FEL29 NATIVE {row['case']} {build} ready_ms={round(row['ready_ms'])} "
          f"dark_frames={row['dark_frames']} room_frames={row['room_frames']} "
          f"max_frame_ms={row['max_frame_ms']:.1f}")


def compare(path):
    release = path / "release" / MOVIE
    branch = path / "branch" / MOVIE
    # Offer both original game mixes as selectable audio tracks.
    subprocess.run([
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-nostdin", "-y",
        "-i", str(release), "-i", str(branch),
        "-filter_complex", "[0:v][1:v]hstack=inputs=2[paired]",
        "-map", "[paired]", "-map", "0:a", "-map", "1:a",
        "-c:v", "libx264", "-preset", "fast", "-crf", "18", "-c:a", "copy",
        "-metadata:s:a:0", "handler_name=Release", "-metadata:s:a:1", "handler_name=fel-29",
        "-disposition:a:0", "default", "-disposition:a:1", "0",
        "-movflags", "+faststart", str(path / "release-left.mp4"),
    ], check=True)


def verify(path):
    failed = []
    for take in ("map", "combat", "new_game"):
        row = json.loads((path / take / "branch" / "00001.json").read_text())
        if row["dark_frames"] or row["room_frames"] or row["max_frame_ms"] > MAX_FRAME_MS:
            failed.append(take)
    if failed:
        raise SystemExit("FEL29 NATIVE FAIL " + ", ".join(failed))
    print("FEL29 NATIVE PASS takes=3")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("measure", "compare", "verify"):
        command = commands.add_parser(name)
        command.add_argument("path", type=Path)
        if name == "measure":
            command.add_argument("build", choices=("release", "branch"))
    args = parser.parse_args()
    if args.command == "measure":
        measure(args.path, args.build)
    elif args.command == "compare":
        compare(args.path)
    else:
        verify(args.path)


if __name__ == "__main__":
    main()
