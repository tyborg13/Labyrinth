#!/usr/bin/env python3
"""Create repeatable technical logs and visual proof sheets for a trailer master."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import shutil
import subprocess
from fractions import Fraction
from pathlib import Path
from typing import Any


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Audit a trailer master and generate deterministic proof artifacts."
    )
    parser.add_argument("video", type=Path, help="Encoded trailer master to inspect")
    parser.add_argument(
        "--output-dir", type=Path, required=True, help="Directory for logs and sheets"
    )
    parser.add_argument(
        "--focus",
        action="append",
        default=[],
        metavar="NAME:START_FRAME:END_FRAME",
        help="Generate a dense contact sheet for an inclusive frame range; repeatable",
    )
    parser.add_argument(
        "--boundary-frame",
        action="append",
        default=[],
        type=int,
        help="Add a scene-boundary frame to the boundary sheet; repeatable",
    )
    parser.add_argument(
        "--boundary-radius",
        type=int,
        default=6,
        help="Frames to include on each side of every boundary (default: 6)",
    )
    parser.add_argument(
        "--dense-fps",
        type=float,
        default=10.0,
        help="Sampling rate for focused sheets (default: 10)",
    )
    parser.add_argument(
        "--master-fps",
        type=float,
        default=1.0,
        help="Sampling rate for the whole-master sheet (default: 1)",
    )
    return parser


def _require_binary(name: str) -> str:
    result = shutil.which(name)
    if result is None:
        raise SystemExit(f"Required executable is not on PATH: {name}")
    return result


def _run(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )


def _write_log(path: Path, command: list[str]) -> str:
    completed = subprocess.run(
        command,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    path.write_text(completed.stdout, encoding="utf-8")
    if completed.returncode != 0:
        raise SystemExit(f"Audit command failed; inspect {path}")
    return completed.stdout


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _safe_name(value: str) -> str:
    cleaned = re.sub(r"[^a-zA-Z0-9_-]+", "-", value).strip("-").lower()
    if not cleaned:
        raise SystemExit("Focus NAME must contain a letter or number")
    return cleaned


def _parse_focus(value: str, last_frame: int) -> tuple[str, int, int]:
    parts = value.rsplit(":", 2)
    if len(parts) != 3:
        raise SystemExit(f"Invalid --focus value: {value!r}")
    name = _safe_name(parts[0])
    try:
        start = int(parts[1])
        end = int(parts[2])
    except ValueError as error:
        raise SystemExit(f"Focus frames must be integers: {value!r}") from error
    if start < 0 or end < start or end > last_frame:
        raise SystemExit(
            f"Focus range {start}:{end} is outside video frames 0:{last_frame}"
        )
    return name, start, end


def _render_sheet(
    ffmpeg: str,
    video: Path,
    output: Path,
    video_filter: str,
) -> None:
    _run(
        [
            ffmpeg,
            "-hide_banner",
            "-loglevel",
            "error",
            "-i",
            str(video),
            "-vf",
            video_filter,
            "-frames:v",
            "1",
            "-y",
            str(output),
        ]
    )


def _stream_metadata(probe: dict[str, Any]) -> tuple[dict[str, Any], float, int, float]:
    video_stream = next(
        (stream for stream in probe["streams"] if stream.get("codec_type") == "video"),
        None,
    )
    if video_stream is None:
        raise SystemExit("Input contains no video stream")
    frame_rate = 0.0
    for rate_value in (
        video_stream.get("avg_frame_rate"),
        video_stream.get("r_frame_rate"),
    ):
        if rate_value and rate_value != "0/0":
            frame_rate = float(Fraction(rate_value))
            if frame_rate > 0:
                break
    if frame_rate <= 0:
        raise SystemExit("Could not determine a positive video frame rate")
    duration = float(
        probe.get("format", {}).get("duration") or video_stream.get("duration") or 0
    )
    if duration <= 0:
        raise SystemExit("Could not determine a positive video duration")
    reported_frames = str(video_stream.get("nb_frames") or "")
    frame_count = (
        int(reported_frames) if reported_frames.isdigit() else round(duration * frame_rate)
    )
    if frame_count <= 0:
        raise SystemExit("Could not determine a positive video frame count")
    return video_stream, frame_rate, frame_count, duration


def _black_intervals(log: str) -> list[dict[str, float]]:
    pattern = re.compile(
        r"black_start:(?P<start>-?\d+(?:\.\d+)?)\s+"
        r"black_end:(?P<end>-?\d+(?:\.\d+)?)\s+"
        r"black_duration:(?P<duration>-?\d+(?:\.\d+)?)"
    )
    return [
        {key: float(value) for key, value in match.groupdict().items()}
        for match in pattern.finditer(log)
    ]


def _freeze_intervals(log: str) -> list[dict[str, float | None]]:
    starts = [float(value) for value in re.findall(r"freeze_start:\s*(-?\d+(?:\.\d+)?)", log)]
    ends = [float(value) for value in re.findall(r"freeze_end:\s*(-?\d+(?:\.\d+)?)", log)]
    durations = [
        float(value) for value in re.findall(r"freeze_duration:\s*(-?\d+(?:\.\d+)?)", log)
    ]
    return [
        {
            "start": start,
            "end": ends[index] if index < len(ends) else None,
            "duration": durations[index] if index < len(durations) else None,
        }
        for index, start in enumerate(starts)
    ]


def _volume_summary(log: str) -> dict[str, float | None]:
    def match_value(label: str) -> float | None:
        match = re.search(rf"{label}:\s*(-?\d+(?:\.\d+)?)\s+dB", log)
        return float(match.group(1)) if match else None

    return {"mean_db": match_value("mean_volume"), "max_db": match_value("max_volume")}


def main() -> int:
    args = _parser().parse_args()
    video = args.video.resolve()
    output_dir = args.output_dir.resolve()
    if not video.is_file():
        raise SystemExit(f"Video does not exist: {video}")
    if args.boundary_radius < 0:
        raise SystemExit("--boundary-radius must be zero or greater")
    if args.dense_fps <= 0 or args.master_fps <= 0:
        raise SystemExit("Sheet sampling rates must be positive")

    ffmpeg = _require_binary("ffmpeg")
    ffprobe = _require_binary("ffprobe")
    output_dir.mkdir(parents=True, exist_ok=True)

    probe_command = [
        ffprobe,
        "-v",
        "error",
        "-show_format",
        "-show_streams",
        "-of",
        "json",
        str(video),
    ]
    probe = json.loads(_run(probe_command).stdout)
    probe_path = output_dir / "probe.json"
    probe_path.write_text(json.dumps(probe, indent=2) + "\n", encoding="utf-8")
    video_stream, frame_rate, frame_count, duration = _stream_metadata(probe)
    last_frame = frame_count - 1

    black_log = _write_log(
        output_dir / "blackdetect.log",
        [
            ffmpeg,
            "-hide_banner",
            "-i",
            str(video),
            "-vf",
            "blackdetect=d=0.04:pix_th=0.10",
            "-an",
            "-f",
            "null",
            "-",
        ],
    )
    freeze_log = _write_log(
        output_dir / "freezedetect.log",
        [
            ffmpeg,
            "-hide_banner",
            "-i",
            str(video),
            "-vf",
            "freezedetect=n=-50dB:d=0.7",
            "-an",
            "-f",
            "null",
            "-",
        ],
    )
    volume_log = _write_log(
        output_dir / "volumedetect.log",
        [
            ffmpeg,
            "-hide_banner",
            "-i",
            str(video),
            "-af",
            "volumedetect",
            "-vn",
            "-f",
            "null",
            "-",
        ],
    )

    master_columns = 8
    master_samples = max(1, math.ceil(duration * args.master_fps))
    master_rows = math.ceil(master_samples / master_columns)
    master_sheet = output_dir / "master-sheet.png"
    _render_sheet(
        ffmpeg,
        video,
        master_sheet,
        (
            f"fps={args.master_fps},scale=320:-2,"
            f"tile={master_columns}x{master_rows}:padding=4:margin=4:color=black"
        ),
    )

    focus_outputs: list[dict[str, Any]] = []
    for focus_value in args.focus:
        name, start, end = _parse_focus(focus_value, last_frame)
        sampled_frames = max(
            1, math.ceil(((end - start + 1) / frame_rate) * args.dense_fps)
        )
        columns = 6
        rows = math.ceil(sampled_frames / columns)
        output = output_dir / f"focus-{name}-{start}-{end}.png"
        _render_sheet(
            ffmpeg,
            video,
            output,
            (
                f"trim=start_frame={start}:end_frame={end + 1},"
                f"setpts=PTS-STARTPTS,fps={args.dense_fps},scale=400:-2,"
                f"tile={columns}x{rows}:padding=4:margin=4:color=black"
            ),
        )
        focus_outputs.append(
            {"name": name, "start_frame": start, "end_frame": end, "file": output.name}
        )

    boundary_output: str | None = None
    boundary_frames: list[int] = []
    if args.boundary_frame:
        invalid = [frame for frame in args.boundary_frame if frame < 0 or frame > last_frame]
        if invalid:
            raise SystemExit(f"Boundary frames outside 0:{last_frame}: {invalid}")
        boundary_frames = sorted(
            {
                frame
                for boundary in args.boundary_frame
                for frame in range(
                    max(0, boundary - args.boundary_radius),
                    min(last_frame, boundary + args.boundary_radius) + 1,
                )
            }
        )
        columns = 13
        rows = math.ceil(len(boundary_frames) / columns)
        select = "+".join(f"eq(n\\,{frame})" for frame in boundary_frames)
        boundary_sheet = output_dir / "boundary-sheet.png"
        _render_sheet(
            ffmpeg,
            video,
            boundary_sheet,
            (
                f"select={select},setpts=N/FRAME_RATE/TB,scale=240:-2,"
                f"tile={columns}x{rows}:padding=4:margin=4:color=black"
            ),
        )
        boundary_output = boundary_sheet.name

    audio_stream = next(
        (stream for stream in probe["streams"] if stream.get("codec_type") == "audio"),
        None,
    )
    manifest = {
        "source": str(video),
        "sha256": _sha256(video),
        "video": {
            "codec": video_stream.get("codec_name"),
            "profile": video_stream.get("profile"),
            "width": video_stream.get("width"),
            "height": video_stream.get("height"),
            "frame_rate": frame_rate,
            "frame_count": frame_count,
            "duration_seconds": duration,
        },
        "audio": (
            {
                "codec": audio_stream.get("codec_name"),
                "channels": audio_stream.get("channels"),
                "sample_rate": int(audio_stream.get("sample_rate") or 0),
            }
            if audio_stream
            else None
        ),
        "findings": {
            "black_intervals": _black_intervals(black_log),
            "freeze_intervals": _freeze_intervals(freeze_log),
            "volume": _volume_summary(volume_log),
        },
        "proof": {
            "probe": probe_path.name,
            "blackdetect": "blackdetect.log",
            "freezedetect": "freezedetect.log",
            "volumedetect": "volumedetect.log",
            "master_sheet": master_sheet.name,
            "focused_sheets": focus_outputs,
            "boundary_sheet": boundary_output,
            "boundary_frames": boundary_frames,
        },
    }
    manifest_path = output_dir / "audit-manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
