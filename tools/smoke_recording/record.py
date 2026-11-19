#!/usr/bin/env python3
"""Record or rehearse one seeded Escape the Umbra demo descent."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import threading
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from tools.demo_clips import media
from tools.smoke_recording import report

TASK_ID = "cap-09"
ROUTE = "tools/smoke_recording/route.gd"
PROOF = "tools/smoke_recording/proof.json"
SIZE = (1920, 1080)
FPS = 30
CAPTURE_TIMEOUT_SECONDS = 5400  # Wall-clock cap for the full native route.
PROGRESS_INTERVAL_SECONDS = 60
DRY_RUN_TIMEOUT_SECONDS = 420
DRY_RUN_MAX_FPS = 120
MIN_CAPTURE_BYTES = 5_000_000_000  # AVI and the encoded MP4 coexist until verification.
AVI_PATH = Path("movie-maker/movie.avi")
CHAPTER_PROGRESS = "chapter-progress.txt"
CONTACT_WIDTH, CONTACT_HEIGHT = 640, 360
CHAPTER_COUNT = 5
DURATION_RANGE_S = (180, 240)


def watch_progress(chapter_path: Path, log: Path, done: threading.Event) -> None:
    # The visual runner buffers Godot's stdout. Read the last chapter directly
    # so the heartbeat also works if Godot stops processing frames.
    start = time.monotonic()
    chapter = "Starting native probe"
    with log.open("a", encoding="utf-8", buffering=1) as receipt:
        while not done.wait(PROGRESS_INTERVAL_SECONDS):
            try:
                chapter = chapter_path.read_text(encoding="utf-8").strip() or chapter
            except FileNotFoundError:
                pass
            elapsed = int(time.monotonic() - start)
            line = f"CAP09 PROGRESS: {chapter} ({elapsed}s elapsed)"
            print(line, flush=True)
            receipt.write(line + "\n")


def checked_run(command: list[str], environment: dict[str, str], log: Path, *, native: bool) -> None:
    print(shlex.join(command), flush=True)
    with subprocess.Popen(command, cwd=ROOT, env=environment, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, text=True, errors="replace") as process:
        done = threading.Event()
        progress = None
        with log.open("a", encoding="utf-8", buffering=1) as receipt:
            if native:
                progress = threading.Thread(target=watch_progress,
                                            args=(log.with_name(CHAPTER_PROGRESS), log, done))
                progress.start()
            try:
                for line in process.stdout:
                    print(line, end="", flush=True)
                    receipt.write(line)
            finally:
                done.set()
                if progress is not None:
                    progress.join()
    if process.returncode:
        raise ValueError(f"Route exited {process.returncode}; see {log}")


def run_capture(output: Path, dry_run: bool) -> dict:
    env = dict(os.environ, LABYRINTH_DEMO="1", LABYRINTH_CEL_LOOK="all", LABYRINTH_PROBE_WINDOW="1")
    env.pop("LABYRINTH_TELEMETRY_ENDPOINT", None)
    env.pop("LABYRINTH_TELEMETRY_TOKEN", None)
    if dry_run:
        command = [
            sys.executable, "tools/godot_task_runner.py", "--task-id", TASK_ID, "--timeout",
            str(DRY_RUN_TIMEOUT_SECONDS), "--stream", "--", "godot", "--headless", "--path", ".",
            "--max-fps", str(DRY_RUN_MAX_FPS), "--script", ROUTE, "--", "--dry-run",
            f"--out={output}",
        ]
    else:
        # Movie Maker puts MJPEG video and the game's mixed PCM in the same AVI.
        avi = output / AVI_PATH
        avi.parent.mkdir()
        wrapper = output / "movie-godot.sh"
        engine = [
            "godot", "--windowed", "--resolution", "1920x1080",
            "--write-movie", str(avi), "--fixed-fps", str(FPS),
        ]
        wrapper.write_text(f'#!/bin/sh\nexec {shlex.join(engine)} "$@"\n', encoding="utf-8")
        wrapper.chmod(0o755)
        command = [
            sys.executable, "tools/visual_probe_runner.py", "--task-id", TASK_ID, "--godot", str(wrapper),
            "--no-headless", "--timeout", str(CAPTURE_TIMEOUT_SECONDS),
            "--expect-size", "1920x1080", "--proof-contract", PROOF, "--result-manifest",
            str(output / "visual-proof.json"), ROUTE, "--", f"--out={output}", "--fixed-fps", str(FPS),
        ]
    checked_run(command, env, output / "godot.log", native=not dry_run)
    route = report.read_json(output / "route.json")
    if (route["dry_run"] != dry_run or route["failed"] or len(route["chapters"]) != CHAPTER_COUNT
            or route["resolution"] != list(SIZE) or route["ui_scale"] != 1.0 or route["fps"] != FPS):
        raise ValueError("Incomplete route or capture geometry mismatch")
    return route


def timestamp(frame: int) -> str:
    milliseconds = round(1000 * frame / FPS)
    minutes, remainder = divmod(milliseconds, 60_000)
    seconds, milliseconds = divmod(remainder, 1000)
    return f"{minutes:02d}:{seconds:02d}.{milliseconds:03d}"


def write_chapters(output: Path, route: dict, frames: int) -> Path:
    chapters = route["chapters"]
    starts = [chapter["frame"] for chapter in chapters]
    if starts[0] != 0 or any(a >= b for a, b in zip(starts, starts[1:] + [frames])):
        raise ValueError("Chapter frames fall outside the movie or are out of order")
    metadata = [";FFMETADATA1"]
    listing = ["# Chapters", ""]
    for chapter, end in zip(chapters, starts[1:] + [frames]):
        title, start = chapter["title"], chapter["frame"]
        for symbol in ("\\", "=", ";", "#"):
            title = title.replace(symbol, "\\" + symbol)
        metadata += ["[CHAPTER]", f"TIMEBASE=1/{FPS}", f"START={start}", f"END={end}", f"title={title}"]
        listing.append(f"- {timestamp(start)} — {chapter['title']}")
    (output / "chapters.md").write_text("\n".join(listing) + "\n", encoding="utf-8")
    path = output / "chapters.ffmetadata"
    path.write_text("\n".join(metadata) + "\n", encoding="utf-8")
    return path


def encode(output: Path, route: dict) -> None:
    avi = output / AVI_PATH
    streams = media.probe(avi)["streams"]
    source_video = next((row for row in streams if row["codec_type"] == "video"), {})
    source_audio = next((row for row in streams if row["codec_type"] == "audio"), {})
    if (source_video.get("codec_name") != "mjpeg"
            or (source_video.get("width"), source_video.get("height")) != SIZE
            or source_video.get("r_frame_rate") != f"{FPS}/1"):
        raise ValueError(f"Movie Maker AVI requires 1920x1080 MJPEG at {FPS} fps")
    if (source_audio.get("codec_name") not in {"pcm_s16le", "pcm_s24le", "pcm_s32le"}
            or int(source_audio.get("sample_rate", 0)) != media.AUDIO_RATE or source_audio.get("channels") != 2):
        raise ValueError("Movie Maker AVI requires stereo 48 kHz mixed PCM")
    frames = int(source_video["nb_read_frames"])
    if abs(frames - route["end_frame"]) > 2:
        raise ValueError("Movie Maker output and rendered route frame counts disagree")
    seconds = frames / FPS
    if not DURATION_RANGE_S[0] <= seconds <= DURATION_RANGE_S[1]:
        print(f"CAP09 DURATION: {seconds:.1f}s outside the requested ~3–4 minutes", flush=True)
    volume = subprocess.run(
        ["ffmpeg", "-hide_banner", "-i", str(avi), "-map", "0:a:0", "-af", "volumedetect", "-f", "null", "-"],
        check=True, capture_output=True, text=True,
    )
    samples = sum(map(int, re.findall(r"n_samples:\s+(\d+)", volume.stderr)))
    if abs(samples / (2 * media.AUDIO_RATE) - seconds) > 2 / FPS:
        raise ValueError("Movie Maker mixed PCM and video durations disagree")
    maximum = re.search(r"max_volume:\s+(-?[\d.]+) dB", volume.stderr)
    if maximum is None or float(maximum[1]) <= -90:
        raise ValueError("Movie Maker mixed PCM is silent")

    chapters = write_chapters(output, route, frames)
    partial = output / "recording.partial.mp4"
    media.ffmpeg([
        "-i", avi, "-i", chapters, "-map", "0:v:0", "-map", "0:a:0", "-map_chapters", "1",
        "-c:v", "libx264", "-preset", "medium", "-crf", "17", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "192k", "-t", f"{seconds:.9f}", "-movflags", "+faststart", partial,
    ])
    delivered = media.probe(partial)
    video = next(row for row in delivered["streams"] if row["codec_type"] == "video")
    sound = next(row for row in delivered["streams"] if row["codec_type"] == "audio")
    if (video["codec_name"] != "h264" or sound["codec_name"] != "aac"
            or (video["width"], video["height"]) != SIZE or int(video["nb_read_frames"]) != frames
            or video["r_frame_rate"] != f"{FPS}/1"
            or abs(float(sound["duration"]) - seconds) > 2 / FPS):
        raise ValueError("Encoded MP4 failed the frame, size, codec or sync contract")
    partial.replace(output / "recording.mp4")
    avi.unlink()
    print(f"CAP09 MEDIA: PASS ({frames} frames, {seconds:.1f}s, 1920x1080 at {FPS} fps, H.264 + AAC)")


def contact_sheet(output: Path) -> None:
    inputs = []
    filters = []
    positions = []
    for index in range(CHAPTER_COUNT):
        inputs += ["-i", output / f"chapter-{index + 1}.png"]
        filters.append(f"[{index}:v]scale={CONTACT_WIDTH}:{CONTACT_HEIGHT}[v{index}]")
        row, column = divmod(index, 3)
        positions.append(f"{column * CONTACT_WIDTH}_{row * CONTACT_HEIGHT}")
    stack = "".join(f"[v{i}]" for i in range(CHAPTER_COUNT))
    stack += f"xstack=inputs={CHAPTER_COUNT}:layout={'|'.join(positions)}:fill=black"
    media.ffmpeg([*inputs, "-filter_complex", ";".join(filters + [stack]),
                  "-frames:v", "1", "-update", "1", output / "contact-sheet.png"])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True, help="Fresh output directory")
    parser.add_argument("--compare", type=Path, help="Previous native recording directory")
    parser.add_argument("--dry-run", action="store_true", help="Run the route headlessly without recording")
    args = parser.parse_args()
    output = args.out.expanduser().resolve()
    compare = args.compare.expanduser().resolve() if args.compare else None
    if args.dry_run and compare:
        parser.error("--compare expects a native recording")
    try:
        if not shutil.which("godot"):
            raise ValueError("godot must be on PATH")
        if not (ROOT / "cel_look_variants/manifest.json").is_file():
            raise ValueError("This worktree needs the existing approved cel look variants before recording")
        if compare:
            previous = report.summarize(compare)
            if previous["identity"]["dry_run"]:
                raise ValueError("--compare expects a native recording")
            if previous["identity"]["fps"] != FPS:
                raise ValueError(f"--compare expects a previous {FPS} fps recording")
        if not args.dry_run:
            for binary in ("ffmpeg", "ffprobe"):
                if not shutil.which(binary):
                    raise ValueError(f"{binary} must be on PATH")
        output.mkdir(parents=True, exist_ok=False)
        (output / ".gdignore").touch()
        if not args.dry_run and shutil.disk_usage(output).free < MIN_CAPTURE_BYTES:
            raise ValueError("Movie Maker AVI and MP4 require at least 5 GB of free space")
        route = run_capture(output, args.dry_run)
        timing = report.write_timing(output, compare)
        print(f"CAP09 TIMING: PASS ({timing['windows']} performance windows, "
              f"{len(timing['cohorts'])} cohorts, {len(timing['sections'])} sections)")
        if not args.dry_run:
            encode(output, route)
            contact_sheet(output)
        print(f"CAP09 OUTPUT: {output}")
        return 0
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(f"CAP09 ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
