#!/usr/bin/env python3
"""Record one native gameplay movie, preserving and aligning production SFX."""
from __future__ import annotations

import argparse
import hashlib
import shutil
from datetime import datetime, timezone
import json
import re
from pathlib import Path
import subprocess
import sys
from png_srgb import tag_srgb
from source_lock import source_lock

REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT / "tools"))
from visual_probe_runner import gui_render_lease  # noqa: E402


def capture_origin() -> dict:
    files = [REPO_ROOT / "project.godot", REPO_ROOT / "tools/steam_trailer_capture.gd", REPO_ROOT / "tools/steam_trailer_frame_sink.gd", REPO_ROOT / "scenes/run_scene.tscn"]
    files += sorted((REPO_ROOT / "scripts").rglob("*.gd"))
    return {
        "repository_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO_ROOT, text=True).strip(),
        "repository_dirty": bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=REPO_ROOT, text=True).strip()),
        "recorded_at": "before_capture",
        "captured_script_sha256": {str(path.relative_to(REPO_ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in files},
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("clip")
    parser.add_argument("--task-id", required=True)
    parser.add_argument("--lossless", action="store_true", help="Spool native RGB with a bounded queue; encode PNG after gameplay and preserve native PCM")
    parser.add_argument("--render-scale", type=int, choices=(1, 2), default=1)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--archive-existing", action="store_true", help="Preserve the prior clip in .history before targeted replacement")
    args = parser.parse_args()
    footage = (args.output_dir or REPO_ROOT / "marketing/trailer/public/footage").resolve()
    with source_lock(footage):
        return capture(args, footage)


def capture(args: argparse.Namespace, footage: Path) -> int:
    footage.mkdir(parents=True, exist_ok=True)
    if args.archive_existing:
        if not args.lossless:
            raise ValueError("--archive-existing is for the native lossless workflow")
        prior = [path for path in footage.iterdir() if path.name == args.clip or path.name.startswith(args.clip + ".")]
        if prior:
            stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
            archive = REPO_ROOT / "build" / args.task_id / "proof/trailer/native-history" / f"{args.clip}-{stamp}"
            archive.mkdir(parents=True)
            for path in prior:
                shutil.move(str(path), str(archive / path.name))
            print(f"Preserved previous {args.clip} take: {archive}", flush=True)
    raw = footage / f"{args.clip}.avi"
    if args.lossless:
        native = footage / args.clip
        native.mkdir(parents=True, exist_ok=True)
        if any(native.iterdir()):
            raise RuntimeError(f"Archive the previous take before capture; native source directory must be empty: {native}")
        native = native.resolve()
    output = footage / f"{args.clip}.mp4"
    proof = REPO_ROOT / "build" / args.task_id / "proof/trailer/research-pass-captures"
    proof.mkdir(parents=True, exist_ok=True)
    log_path = (footage if args.lossless else proof) / f"{args.clip}.capture.log"
    command = [
        sys.executable, str(REPO_ROOT / "tools/godot_task_runner.py"),
        "--task-id", args.task_id, "--timeout", "240", "--stream", "--",
        "godot", "--path", str(REPO_ROOT), "--display-driver", "macos",
        "--audio-driver", "Dummy", "--rendering-driver", "metal", "--rendering-method", "mobile",
        "--disable-vsync", "--fixed-fps", "30", "--write-movie", str(raw),
        str(REPO_ROOT / "tools/steam_trailer_capture.tscn"), "--", f"--clip={args.clip}", f"--render-scale={args.render_scale}",
    ]
    if args.lossless:
        command[command.index("--disable-vsync"):command.index("--disable-vsync")] = ["--max-fps", "30"]
        command.append(f"--native-frame-dir={native}")
    lease_args = argparse.Namespace(
        headless=False, gui_lease=True,
        gui_lease_path="/private/tmp/labyrinth-gui-render.lock", gui_lease_timeout=60.0,
    )
    origin = capture_origin()
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
        "campfire": "campfire_choice_complete",
    }.get(args.clip)
    if expected_completion and not any(cue["kind"] == expected_completion for cue in cues):
        raise RuntimeError(f"Capture did not reach {expected_completion}; inspect {log_path}")
    starts = [int(line.split("=", 1)[1]) for line in lines if line.startswith("STEAM_TRAILER_SAFE_START_FRAME=")]
    if len(starts) != 1:
        raise RuntimeError(f"Expected exactly one safe first frame in {log_path}")
    trim_frames = starts[0]
    raw_inputs = ["-i", str(raw)]
    audio_input = raw
    probe = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(raw),
    ], text=True))
    audio_streams = [stream for stream in probe["streams"] if stream["codec_type"] == "audio"]
    if len(audio_streams) != 1 or int(audio_streams[0]["sample_rate"]) != 48000:
        raise RuntimeError("Native Movie Maker capture must contain one 48 kHz gameplay audio stream")
    if args.lossless:
        spool = [json.loads(line.removeprefix("STEAM_TRAILER_NATIVE_FRAMES ")) for line in lines if line.startswith("STEAM_TRAILER_NATIVE_FRAMES ")]
        if len(spool) != 1 or spool[0]["failure"] or spool[0]["written_frames"] != spool[0]["source_frames"]:
            raise RuntimeError("Native RGB capture did not complete without dropped frames")
        raster = f"{1920 * args.render_scale}x{1080 * args.render_scale}"
        rgb_inputs = ["-f", "image2", "-framerate", "30", "-video_size", raster, "-pixel_format", "rgb24", "-vcodec", "rawvideo", "-i", str(native / "frame%08d.rgb")]
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", *rgb_inputs, "-c:v", "png", "-compression_level", "1", "-pred", "sub", "-pix_fmt", "rgb24", "-start_number", "0", str(native / "frame%08d.png")], check=True)
        for frame_path in native.glob("frame????????.png"):
            tag_srgb(frame_path)
        # Verify every RGB sample through the PNG round trip before removing the
        # large uncompressed spool. PNGs remain the original source of truth.
        def frame_hashes(inputs: list[str]) -> list[str]:
            result = subprocess.check_output(["ffmpeg", "-v", "error", *inputs, "-pix_fmt", "rgb24", "-f", "framemd5", "-"], text=True)
            return [line.rsplit(",", 1)[-1].strip() for line in result.splitlines() if not line.startswith("#")]
        raw_hashes = frame_hashes(rgb_inputs)
        png_hashes = frame_hashes(["-framerate", "30", "-i", str(native / "frame%08d.png")])
        if raw_hashes != png_hashes or len(raw_hashes) != spool[0]["written_frames"]:
            raise RuntimeError("PNG capture failed the full native RGB lossless round-trip check")
        (native / "native-rgb-framemd5.json").write_text(json.dumps({"spool": spool[0], "rgb_frame_md5": raw_hashes, "png_srgb_sha256": [hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(native.glob("frame????????.png"))]}, indent=2) + "\n")
        for frame_path in native.glob("frame????????.rgb"):
            frame_path.unlink()
        raw_inputs = ["-framerate", "30", "-i", str(native / "frame%08d.png"), "-i", str(raw)]
    # Godot's AVI contains JPEG/BT.601 full-range video and PCM gameplay audio.
    # 48,000 / 30 = 1,600 samples per frame: trim both at the same native instant.
    video_filter = (
        f"trim=start_frame={trim_frames},setpts=PTS-STARTPTS,"
        "scale=1920:1080:flags=lanczos:in_range=pc:out_range=tv:in_color_matrix=bt601:out_color_matrix=bt709,"
        "format=yuv420p,setsar=1"
    )
    if args.lossless:
        # A review proxy only. The master editor consumes the original RGB PNGs.
        # Color transfer for the upload encode is handled by the final exporter.
        video_filter = "scale=1920:1080:flags=lanczos:in_range=pc:out_range=tv:out_color_matrix=bt709,format=yuv420p,setsar=1"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(audio_input), "-af", f"atrim=start_sample={trim_frames * 1600},asetpts=PTS-STARTPTS", "-c:a", "pcm_s24le", str(footage / f"{args.clip}.wav")], check=True)
    subprocess.run([
        "ffmpeg", "-y", "-loglevel", "error", *raw_inputs,
        "-map", "0:v:0", "-map", "1:a:0" if args.lossless else "0:a:0", "-vf", video_filter,
        "-af", f"atrim=start_sample={trim_frames * 1600},asetpts=PTS-STARTPTS",
        "-c:v", "libx264", "-preset", "medium", "-crf", "1" if args.lossless else "15", "-pix_fmt", "yuv420p",
        "-color_range", "tv", "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "iec61966-2-1" if args.lossless else "bt709",
        "-bsf:v", "h264_metadata=video_full_range_flag=0:colour_primaries=1:transfer_characteristics=%d:matrix_coefficients=1" % (13 if args.lossless else 1),
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
        "clip": args.clip, "fps": 30, "capture_origin": origin, "safe_start_raw_frame": trim_frames,
        "frames": int(video["nb_frames"]), "duration_seconds": float(video["duration"]),
        "width": video["width"], "height": video["height"],
        "audio": {"source": "native_gameplay", "music_muted": True, "sample_rate": 48000, "trim_samples": trim_frames * 1600, "peak_dbfs": peak_db, "duration_seconds": float(audio["duration"]), "channels": audio["channels"], "codec": audio["codec_name"]},
        "cues": cues,
    }
    if args.lossless:
        native_frames = sorted(native.glob("frame????????.png"))
        metadata["lossless"] = {"pattern": str(Path(args.clip) / "frame%08d.png"), "raw_frames": len(native_frames), "source_frame_offset": 0, "spool": spool[0], "round_trip_rgb_exact": True, "render_scale": args.render_scale, "native_width": 1920 * args.render_scale, "native_height": 1080 * args.render_scale, "audio": f"{args.clip}.wav", "pixel_encoding": "native_srgb_rgb", "png_color_profile": "explicit_srgb_chunk", "video_proxy_only": True}
    (footage / f"{args.clip}.cues.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(f"Captured {args.clip}: {metadata['frames']} frames, native SFX retained; {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
