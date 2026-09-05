#!/usr/bin/env python3
"""Record one native gameplay movie, preserving and aligning production SFX."""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
import subprocess
import sys

REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT / "tools"))
from visual_probe_runner import gui_render_lease  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("clip")
    parser.add_argument("--task-id", required=True)
    args = parser.parse_args()
    footage = REPO_ROOT / "marketing/trailer/public/footage"
    footage.mkdir(parents=True, exist_ok=True)
    raw = footage / f"{args.clip}.avi"
    output = footage / f"{args.clip}.mp4"
    proof = REPO_ROOT / "build" / args.task_id / "proof/trailer/research-pass-captures"
    proof.mkdir(parents=True, exist_ok=True)
    log_path = proof / f"{args.clip}.capture.log"
    command = [
        sys.executable, str(REPO_ROOT / "tools/godot_task_runner.py"),
        "--task-id", args.task_id, "--timeout", "240", "--stream", "--",
        "godot", "--path", str(REPO_ROOT), "--display-driver", "macos",
        "--audio-driver", "Dummy", "--rendering-driver", "metal",
        "--disable-vsync", "--fixed-fps", "30", "--write-movie", str(raw),
        str(REPO_ROOT / "tools/steam_trailer_capture.tscn"), "--", f"--clip={args.clip}",
    ]
    lease_args = argparse.Namespace(
        headless=False, gui_lease=True,
        gui_lease_path="/private/tmp/labyrinth-gui-render.lock", gui_lease_timeout=60.0,
    )
    lines: list[str] = []
    with gui_render_lease(lease_args):
        with subprocess.Popen(command, cwd=REPO_ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True) as process:
            assert process.stdout is not None
            for line in process.stdout:
                print(line, end="", flush=True)
                lines.append(line)
            result = process.wait()
    log_path.write_text("".join(lines))
    if result:
        return result
    if any(line.startswith(("ERROR:", "SCRIPT ERROR:")) for line in lines):
        raise RuntimeError(f"Capture emitted a Godot error; inspect {log_path}")
    cues = [json.loads(line.removeprefix("STEAM_TRAILER_CUE ")) for line in lines if line.startswith("STEAM_TRAILER_CUE ")]
    expected_completion = {
        "push_bloom": "tactical_payoff_complete", "root_chain": "tactical_payoff_complete",
        "spell": "reward_claim_complete", "merchant": "shop_purchase_complete",
        "equipment": "equipment_complete", "route": "map_travel_start",
    }.get(args.clip)
    if expected_completion and not any(cue["kind"] == expected_completion for cue in cues):
        raise RuntimeError(f"Capture did not reach {expected_completion}; inspect {log_path}")
    starts = [int(line.split("=", 1)[1]) for line in lines if line.startswith("STEAM_TRAILER_SAFE_START_FRAME=")]
    if len(starts) != 1:
        raise RuntimeError(f"Expected exactly one safe first frame in {log_path}")
    trim_frames = starts[0]
    probe = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(raw),
    ], text=True))
    audio_streams = [stream for stream in probe["streams"] if stream["codec_type"] == "audio"]
    if len(audio_streams) != 1 or int(audio_streams[0]["sample_rate"]) != 48000:
        raise RuntimeError("Native Movie Maker capture must contain one 48 kHz gameplay audio stream")
    # Godot's AVI contains JPEG/BT.601 full-range video and PCM gameplay audio.
    # 48,000 / 30 = 1,600 samples per frame: trim both at the same native instant.
    video_filter = (
        f"trim=start_frame={trim_frames},setpts=PTS-STARTPTS,"
        "scale=1920:1080:flags=lanczos:in_range=pc:out_range=tv:in_color_matrix=bt601:out_color_matrix=bt709,"
        "format=yuv420p,setsar=1"
    )
    subprocess.run([
        "ffmpeg", "-y", "-loglevel", "error", "-i", str(raw),
        "-map", "0:v:0", "-map", "0:a:0", "-vf", video_filter,
        "-af", f"atrim=start_sample={trim_frames * 1600},asetpts=PTS-STARTPTS",
        "-c:v", "libx264", "-preset", "medium", "-crf", "15", "-pix_fmt", "yuv420p",
        "-color_range", "tv", "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709",
        "-bsf:v", "h264_metadata=video_full_range_flag=0:colour_primaries=1:transfer_characteristics=1:matrix_coefficients=1",
        "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-movflags", "+faststart", str(output),
    ], check=True)
    output_probe = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(output),
    ], text=True))
    video = next(stream for stream in output_probe["streams"] if stream["codec_type"] == "video")
    audio = next(stream for stream in output_probe["streams"] if stream["codec_type"] == "audio")
    audio_measurement = subprocess.run([
        "ffmpeg", "-hide_banner", "-i", str(output), "-vn", "-af", "volumedetect", "-f", "null", "-",
    ], check=True, capture_output=True, text=True)
    peak_match = re.search(r"max_volume: ([^ ]+) dB", audio_measurement.stderr)
    peak_db = peak_match.group(1) if peak_match else "unavailable"
    if args.clip in {"push_bloom", "root_chain", "merchant", "spell", "equipment"} and peak_db in {"-inf", "unavailable"}:
        raise RuntimeError("A gameplay clip with audible actions must retain non-silent native SFX")
    metadata = {
        "clip": args.clip, "fps": 30, "safe_start_raw_frame": trim_frames,
        "frames": int(video["nb_frames"]), "duration_seconds": float(video["duration"]),
        "width": video["width"], "height": video["height"],
        "audio": {"source": "native_gameplay", "music_muted": True, "sample_rate": 48000, "trim_samples": trim_frames * 1600, "peak_dbfs": peak_db, "duration_seconds": float(audio["duration"]), "channels": audio["channels"], "codec": audio["codec_name"]},
        "cues": cues,
    }
    (footage / f"{args.clip}.cues.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(f"Captured {args.clip}: {metadata['frames']} frames, native SFX retained; {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
