#!/usr/bin/env python3
"""Capture pace-02's staged Normal round at 1920x1080/60 fps with game audio.

The visual-probe runner owns launch isolation, renderer leasing, failure scanning,
and semantic PNG validation. This adapter adds Godot Movie Maker arguments to
its command builder, then trims native video and PCM at the same frame boundary.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import visual_probe_runner as visual  # noqa: E402

CAPTURE_FPS = 60
AUDIO_SAMPLE_RATE = 48000
CAPTURE_TIMEOUT_SECONDS = 120
CAPTURE_HOME_ROOT = Path("/private/tmp/labyrinth-godot-home")
VIDEO_CRF = 15
VIDEO_PRESET = "medium"
AUDIO_BITRATE = "192k"
ORIGINAL_BUILD_COMMAND = visual.build_command


def movie_command(args, driver, log_file, movie: Path) -> list[str]:
    command = ORIGINAL_BUILD_COMMAND(args, driver, log_file)
    command[1:1] = ["--disable-vsync", "--fixed-fps", str(CAPTURE_FPS),
                    "--write-movie", str(movie), "--resolution", "1920x1080"]
    return command


def capture_boundaries(log: str) -> tuple[int, int]:
    def boundary(name: str) -> int:
        values = re.findall(rf"^PACE ROUND CAPTURE {name}_FRAME=(\d+)$", log, re.MULTILINE)
        if len(values) != 1:
            raise ValueError(f"Expected one {name} capture boundary")
        return int(values[0])
    start, end = boundary("START"), boundary("END")
    if end <= start:
        raise ValueError("Capture has no round frames")
    return start, end


def encode_command(movie: Path, output: Path, start: int, end: int) -> list[str]:
    samples_per_frame = AUDIO_SAMPLE_RATE // CAPTURE_FPS
    return ["ffmpeg", "-n", "-hide_banner", "-loglevel", "error", "-i", str(movie),
            "-map", "0:v:0", "-map", "0:a:0", "-vf",
            f"trim=start_frame={start}:end_frame={end},setpts=PTS-STARTPTS,"
            "scale=1920:1080:in_range=pc:out_range=tv:in_color_matrix=bt601:out_color_matrix=bt709,format=yuv420p,setsar=1",
            "-af", f"atrim=start_sample={start*samples_per_frame}:end_sample={end*samples_per_frame},asetpts=PTS-STARTPTS",
            "-r", str(CAPTURE_FPS), "-c:v", "libx264", "-crf", str(VIDEO_CRF), "-preset", VIDEO_PRESET,
            "-color_range", "tv", "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709",
            "-c:a", "aac", "-b:a", AUDIO_BITRATE, "-ar", str(AUDIO_SAMPLE_RATE), "-movflags", "+faststart", str(output)]


def probe_arguments(manifest_path: Path, *, before: bool) -> list[str]:
    arguments = ["tests/combat_feel_probe.gd", "--project", str(ROOT), "--task-id", "pace-02",
                 "--no-headless", "--display-driver", "macos", "--audio-driver", "Dummy",
                 "--timeout", str(CAPTURE_TIMEOUT_SECONDS), "--expect-size", "1920x1080",
                 "--godot-home-root", str(CAPTURE_HOME_ROOT),
                 "--proof-contract", str(ROOT / "tests/pace_round_proof_contract.json"),
                 "--result-manifest", str(manifest_path), "--", "--round-only"]
    if before:
        arguments.append("--baseline")
    return arguments


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--before", action="store_true", help="Use the exact merged pace-01 pacing (4e874c34f)")
    parser.add_argument("--output-dir", type=Path, required=True, help="Fresh capture directory")
    args = parser.parse_args()
    for executable in ("godot", "ffmpeg", "ffprobe"):
        if not shutil.which(executable):
            parser.error(f"Required existing capture tool is unavailable: {executable}")
    directory = args.output_dir.resolve()
    directory.mkdir(parents=True, exist_ok=False)
    movie = directory / "round.avi"
    manifest_path = directory / "renderer-manifest.json"
    visual.build_command = lambda opts, driver, log: movie_command(opts, driver, log, movie)
    if visual.main(probe_arguments(manifest_path, before=args.before)):
        return 1
    manifest = json.loads(manifest_path.read_text())
    # The runner preserves the Godot log inside the attempt's isolated HOME.
    log = (CAPTURE_HOME_ROOT / manifest["namespace"] / "godot.log").read_text()
    start, end = capture_boundaries(log)
    source = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_streams", "-of", "json", str(movie)], text=True))
    source_audio = next(s for s in source["streams"] if s["codec_type"] == "audio")
    if int(source_audio["sample_rate"]) != AUDIO_SAMPLE_RATE:
        raise ValueError("Native movie audio must be 48000 Hz for exact sample/frame alignment")
    output = directory / ("before.mp4" if args.before else "after.mp4")
    subprocess.run(encode_command(movie, output, start, end), check=True)
    metadata = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_streams", "-of", "json", str(output)], text=True))
    video = next(s for s in metadata["streams"] if s["codec_type"] == "video")
    audio = next(s for s in metadata["streams"] if s["codec_type"] == "audio")
    if (video["width"], video["height"], video["r_frame_rate"], int(audio["sample_rate"])) != (1920, 1080, "60/1", AUDIO_SAMPLE_RATE):
        raise ValueError("Capture failed resolution/frame-rate/audio validation")
    volume = subprocess.run(["ffmpeg", "-hide_banner", "-i", str(output), "-vn", "-af", "volumedetect", "-f", "null", "-"], capture_output=True, text=True, check=True)
    peak = re.search(r"max_volume: ([^ ]+) dB", volume.stderr)
    if peak is None or peak[1] == "-inf":
        raise ValueError("Capture must retain audible game audio")
    (directory / "capture.json").write_text(json.dumps({"before": args.before, "start_frame": start, "end_frame": end,
        "fps": CAPTURE_FPS, "audio_peak_dbfs": peak[1], "streams": metadata["streams"],
        "renderer_manifest": str(manifest_path), "mp4": str(output)}, indent=2) + "\n")
    print(f"PACE ROUND CAPTURE RESULT: PASS; {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
