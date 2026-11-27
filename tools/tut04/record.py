#!/usr/bin/env python3
"""Record or rehearse the first-Umbra pointer flow."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(ROOT), str(ROOT / "tools")]

import visual_probe_runner as visual
from tools.demo_clips import media
from tools.smoke_recording.record import CONTACT_HEIGHT, CONTACT_WIDTH, checked_run

TASK_ID = "tut-04"
ROUTE = "tools/tut04/route.gd"
PROOF = "tools/tut04/proof_contract.json"
OUTPUT_ROOT = Path("/private/tmp/labyrinth_codex/tut-04")
SIZE = (1920, 1080)
FPS = 30
STEPS = 6
FRAME_TOLERANCE = 2
DURATION_RANGE = (20, 35)
PCM_CODECS = {"pcm_s16le", "pcm_s24le", "pcm_s32le"}
STILL_DELIVERABLES = {
    "step-3.png": "umbra-card.png",
    "step-4.png": "umbra-hud-popup.png",
    "after-continue.png": "after-continue.png",
}


def receipt(log: Path, line: str) -> None:
    print(line, flush=True)
    with log.open("a", encoding="utf-8") as file:
        print(line, file=file)


def capture(work: Path, log: Path, dry_run: bool) -> dict:
    environment = dict(os.environ, LABYRINTH_CEL_LOOK="all", LABYRINTH_PROBE_WINDOW="1")
    for key in ("LABYRINTH_DEMO", "LABYRINTH_TELEMETRY_ENDPOINT", "LABYRINTH_TELEMETRY_TOKEN"):
        environment.pop(key, None)
    command = [sys.executable, "tools/godot_task_runner.py", "--task-id", TASK_ID, "--stream", "--", "godot"]
    timing_args = ["--fixed-fps", str(FPS)]
    route_args = ["--path", ".", "--script", ROUTE, "--", f"--out={work}"]
    if dry_run:
        # Pace readiness waits in real time so threaded asset-loading delays
        # aren't magnified by the uncapped headless fixed-delta loop.
        checked_run([*command, "--headless", "--max-fps", str(FPS), *route_args, "--dry-run"],
                    environment, log, native=False)
    else:
        # Use the shared GPU policy and lease. The Godot task runner keeps the
        # recording window focused so CursorFeedback draws its production glyph.
        size = f"{SIZE[0]}x{SIZE[1]}"
        probe_args = visual.build_parser().parse_args([ROUTE, "--no-headless", "--expect-size", size])
        visual.resolve_probe_rendering_mode(probe_args, ROOT)
        native = ["--windowed", "--resolution", size, "--write-movie", str(work / "movie.avi")]
        for flag, value in (("--display-driver", probe_args.display_driver),
                            ("--rendering-method", probe_args.rendering_method),
                            ("--rendering-driver", probe_args.rendering_driver)):
            if value:
                native.extend([flag, value])
        with visual.gui_render_lease(probe_args):
            checked_run([*command, *native, *timing_args, *route_args, *timing_args], environment, log, native=False)
    route = json.loads((work / "route.json").read_text(encoding="utf-8"))
    start, end, stills = route["start_frame"], route["end_frame"], route["still_frames"]
    if (route["dry_run"] != dry_run or route["fps"] != FPS or tuple(route["size"]) != SIZE
            or route["ui_scale"] != 1.0 or len(stills) != STEPS
            or not start < stills[0] or not stills[-1] <= end
            or not stills[3] < route["after_continue_frame"] < stills[4]
            or any(a >= b for a, b in zip(stills, stills[1:]))):
        raise ValueError("Incomplete route or unexpected capture geometry/timing")
    return route


def streams(path: Path) -> tuple[dict, dict]:
    rows = media.probe(path)["streams"]
    video = next((row for row in rows if row["codec_type"] == "video"), {})
    audio = next((row for row in rows if row["codec_type"] == "audio"), {})
    if ((video.get("width"), video.get("height")) != SIZE or video.get("r_frame_rate") != f"{FPS}/1"
            or video.get("avg_frame_rate") != f"{FPS}/1"):
        raise ValueError(f"{path.name} must be 1920x1080 at {FPS} fps")
    if int(audio.get("sample_rate", 0)) != media.AUDIO_RATE or audio.get("channels") != 2:
        raise ValueError(f"{path.name} must contain the stereo 48 kHz game mix")
    return video, audio


def encode(work: Path, route: dict, log: Path) -> Path:
    avi = work / "movie.avi"
    video, audio = streams(avi)
    if video["codec_name"] != "mjpeg" or audio["codec_name"] not in PCM_CODECS:
        raise ValueError("Movie Maker AVI must contain MJPEG and mixed PCM")
    raw_frames = int(video["nb_read_frames"])
    if abs(raw_frames - route["end_frame"]) > FRAME_TOLERANCE:
        raise ValueError("Movie Maker and the rendered route disagree on the ending frame")

    # Drop startup before the map. Trim both streams by their matching frame
    # and sample indices so the game audio stays in sync with the mouse input.
    start = route["start_frame"]
    end = raw_frames
    samples_per_frame = media.AUDIO_RATE // FPS
    frames = end - start
    seconds = frames / FPS
    partial = work / "flow.mp4"
    graph = (
        f"[0:v]trim=start_frame={start}:end_frame={end},setpts=PTS-STARTPTS[v];"
        f"[0:a]atrim=start_sample={start * samples_per_frame}:end_sample={end * samples_per_frame},"
        "asetpts=PTS-STARTPTS[a]"
    )
    media.ffmpeg(["-i", avi, "-filter_complex", graph, "-map", "[v]", "-map", "[a]",
                  "-c:v", "libx264", "-preset", "medium", "-crf", "17", "-pix_fmt", "yuv420p",
                  "-c:a", "aac", "-b:a", "192k", "-threads", media.FFMPEG_THREADS,
                  "-movflags", "+faststart", partial])
    video, audio = streams(partial)
    if (video["codec_name"] != "h264" or audio["codec_name"] != "aac"
            or int(video["nb_read_frames"]) != frames
            or abs(float(audio["duration"]) - seconds) > FRAME_TOLERANCE / FPS):
        raise ValueError("Encoded MP4 failed the frame, codec or A/V sync contract")
    volume = subprocess.run(["ffmpeg", "-hide_banner", "-threads", str(media.FFMPEG_THREADS),
                             "-i", str(partial), "-map", "0:a:0", "-af", "volumedetect", "-f", "null", "-"],
                            check=True, capture_output=True, text=True)
    peak = re.search(r"max_volume:\s+(-?[\d.]+) dB", volume.stderr)
    if peak is None or float(peak[1]) <= -90:
        raise ValueError("Encoded game mix is silent")
    receipt(log, f"TUT-04 MEDIA PASS: {frames} frames, {seconds:.2f}s, 1920x1080 at 30 fps, H.264 + stereo AAC")
    if not DURATION_RANGE[0] <= seconds <= DURATION_RANGE[1]:
        receipt(log, f"TUT-04 DURATION: {seconds:.2f}s outside the expected ~20–35s")
    return partial


def contact_sheet(work: Path, log: Path) -> Path:
    stills = [work / f"step-{step}.png" for step in range(1, STEPS + 1)]
    visual.validate_pngs([*stills, work / "after-continue.png"], STEPS + 1, [SIZE], visual.load_proof_contract(PROOF))
    inputs = []
    filters = []
    positions = []
    for index, still in enumerate(stills):
        inputs.extend(["-i", still])
        filters.append(f"[{index}:v]scale={CONTACT_WIDTH}:{CONTACT_HEIGHT}[v{index}]")
        row, column = divmod(index, 3)
        positions.append(f"{column * CONTACT_WIDTH}_{row * CONTACT_HEIGHT}")
    stack = "".join(f"[v{i}]" for i in range(STEPS))
    stack += f"xstack=inputs={STEPS}:layout={'|'.join(positions)}"
    sheet = work / "contact-sheet.png"
    media.ffmpeg([*inputs, "-filter_complex", ";".join([*filters, stack]), "-frames:v", "1",
                  "-threads", media.FFMPEG_THREADS, "-update", "1", sheet])
    visual.validate_pngs([sheet], 1, [(3 * CONTACT_WIDTH, 2 * CONTACT_HEIGHT)])
    receipt(log, "TUT-04 CONTACT SHEET PASS: six verified 1920x1080 source frames in route order")
    return sheet


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="Exercise the same route headlessly")
    args = parser.parse_args()
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    prefix = "dry-run." if args.dry_run else "take."
    temporary = subprocess.run(["mktemp", "-d", str(OUTPUT_ROOT / (prefix + "XXXXXX"))],
                               check=True, capture_output=True, text=True)
    output = Path(temporary.stdout.strip())
    log = output / "checks.log"
    receipt(log, f"TUT-04 OUTPUT: {output}")
    try:
        for binary in (["godot"] if args.dry_run else ["godot", "ffmpeg", "ffprobe"]):
            if not shutil.which(binary):
                raise ValueError(f"{binary} must be on PATH")
        work = output if args.dry_run else output / "work"
        work.mkdir(exist_ok=args.dry_run)
        route = capture(work, log, args.dry_run)
        if not args.dry_run:
            movie = encode(work, route, log)
            sheet = contact_sheet(work, log)
            movie.replace(output / movie.name)
            sheet.replace(output / sheet.name)
            for source, destination in STILL_DELIVERABLES.items():
                still = (work / source).replace(output / destination)
                receipt(log, f"TUT-04 STILL: {still}")
            shutil.rmtree(work)
        else:
            receipt(log, "TUT-04 NATIVE DRY RUN: PASS")
            receipt(log, f"TUT-04 WINDOWED COMMAND: cd {ROOT} && tools/tut04/record.sh")
        return 0
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError, visual.ProbeError) as error:
        receipt(log, f"TUT-04 ERROR: {error}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
