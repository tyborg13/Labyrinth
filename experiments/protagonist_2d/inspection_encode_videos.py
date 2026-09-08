#!/usr/bin/env python3
"""Encode the proof's actual 1920x1080 Godot frames into per-action loop videos."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

from PIL import Image, ImageSequence


def encode_paired_travel(ffmpeg: str, clips: list[dict], output: Path, crop: tuple[int, int, int, int]) -> dict:
    """Keep one fixed board window per facing, at native scale for all frames."""
    selected = {clip["name"]: clip for clip in clips if clip.get("board_travel")}
    if not {"front_walk", "rear_walk"}.issubset(selected):
        return {}
    front, rear = selected["front_walk"], selected["rear_walk"]
    if (front["frame_count"], front["fps"]) != (rear["frame_count"], rear["fps"]):
        raise ValueError("Paired travel requires equal captured frame count and cadence")
    x, y, width, height = crop
    if min(x, y) < 0 or min(width, height) <= 0 or x + width > 1320 or y + height > 924 or width % 2 or height % 2:
        raise ValueError("Travel crop must be an even-sized fixed rectangle inside the board")
    inputs = []
    for clip in (front, rear):
        inputs += ["-framerate", str(clip["fps"]), "-i", str(Path(clip["frames_path"]) / f'frame_%04d.{clip.get("frame_extension", "webp")}')]
    # All inputs are recorded board pixels. The heading is the actual selected
    # facing control from each capture, with no generated character pixels,
    # resizing, retiming, or camera tracking.
    filters = []
    for index, button_x in enumerate((742, 918)):
        filters.append(f"[{index}:v]split[b{index}][h{index}]")
        filters.append(f"[b{index}]crop={width}:{height}:{x}:{y}[c{index}]")
        filters.append(f"[h{index}]crop=172:58:{button_x}:926,pad={width}:58:(ow-iw)/2:0:color=0x100e12[l{index}]")
        filters.append(f"[l{index}][c{index}]vstack=inputs=2[p{index}]")
    filters.append("[p0][p1]hstack=inputs=2[paired]")
    video = output / "walking_front_rear_paired.mp4"
    subprocess.run([ffmpeg, "-hide_banner", "-loglevel", "error", "-y", *inputs, "-filter_complex", ";".join(filters), "-map", "[paired]", "-an", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-preset", "medium", "-crf", "16", "-movflags", "+faststart", str(video)], check=True)
    gif = output / "walking_front_rear_paired.gif"
    gif_filter = ";".join(filters) + ";[paired]split[a][b];[a]palettegen=stats_mode=full[p];[b][p]paletteuse=dither=bayer:bayer_scale=3[gif]"
    subprocess.run([ffmpeg, "-hide_banner", "-loglevel", "error", "-y", *inputs, "-filter_complex", gif_filter, "-map", "[gif]", "-loop", "0", str(gif)], check=True)
    with Image.open(gif) as animated:
        gif_frames = animated.n_frames
        duration_ms = 0
        frame_delays_ms = []
        for frame in ImageSequence.Iterator(animated):
            frame.load()
            if frame.size != (width * 2, height + 58):
                raise ValueError("Unexpected paired GIF size")
            delay = frame.info.get("duration", 0)
            if delay <= 0 or delay % 10:
                raise ValueError("Unexpected GIF centisecond frame delay")
            frame_delays_ms.append(delay)
            duration_ms += delay
    expected_duration_ms = round(front["frame_count"] / front["fps"] * 100) * 10
    if duration_ms != expected_duration_ms or gif_frames != front["frame_count"]:
        raise ValueError("Paired GIF changed captured frame count or playback duration")
    return {"video": str(video), "gif": str(gif), "fixed_source_rect_per_facing": [x, y, width, height], "size": [width * 2, height + 58], "facings_left_to_right": ["front", "rear"], "heading": "actual selected facing control from source capture", "source_pixel_scale": 1.0, "camera_tracking": False, "gif_frames": gif_frames, "gif_duration_ms": duration_ms, "gif_frame_delays_ms": frame_delays_ms, "gif_palette": "one shared full-sequence palette", "gif_dither": "fixed Bayer pattern", "gif_sha256": hashlib.sha256(gif.read_bytes()).hexdigest()}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("proof_directory", type=Path)
    parser.add_argument("--cycles", type=int, default=3)
    parser.add_argument("--travel-crop", type=int, nargs=4, metavar=("X", "Y", "WIDTH", "HEIGHT"), default=(200, 330, 420, 350))
    args = parser.parse_args()
    if args.cycles < 1:
        parser.error("Cycles must be positive")
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise SystemExit("ffmpeg is required to encode the captured frames")
    proof = args.proof_directory.expanduser().resolve()
    evidence = json.loads((proof / "validation.json").read_text())
    clips = evidence.get("video_clips", [])
    if not evidence.get("motion_frames_captured") or not clips:
        raise SystemExit("Run inspection_probe.gd with --capture-motion first")
    output = proof / "videos"
    output.mkdir(exist_ok=True)
    videos = []
    captured = []
    for clip in clips:
        name = clip["name"]
        if not re.fullmatch(r"[a-z_]+", name):
            raise ValueError("Unexpected clip name")
        count = int(clip["frame_count"])
        fps = float(clip["fps"])
        frames = Path(clip["frames_path"]).resolve()
        frames.relative_to(proof)
        extension = clip.get("frame_extension", "png")
        if extension not in {"png", "webp"}:
            raise ValueError(f"Unsupported capture format: {extension}")
        if count <= 0 or fps <= 0:
            raise ValueError(f"Invalid captured clip timing: {name}")
        frame_hashes = []
        for index in range(count):
            frame = frames / f"frame_{index:04d}.{extension}"
            if not frame.is_file():
                raise ValueError(f"Incomplete captured clip: {frame}")
            with Image.open(frame) as rendered:
                rendered.load()
                if rendered.size != (1920, 1080):
                    raise ValueError(f"Unexpected rendered frame size: {frame}")
            frame_hashes.append(hashlib.sha256(frame.read_bytes()).hexdigest())
        destination = output / f"{name}.mp4"
        repeats = 1 if clip.get("board_travel") else args.cycles
        command = [ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-framerate", str(fps), "-i", str(frames / f"frame_%04d.{extension}"), "-vf", f"loop=loop={repeats-1}:size={count}:start=0,setpts=N/({fps}*TB),fps=72,format=yuv420p", "-an", "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-movflags", "+faststart", str(destination)]
        subprocess.run(command, check=True)
        videos.append(destination)
        captured.append({"name": name, "captured_frames": count, "captured_fps": fps, "board_travel": bool(clip.get("board_travel")), "gait_cycles": clip.get("gait_cycles"), "repeats": repeats, "lossless_frame_sha256": frame_hashes})
    playlist = output / "showcase.txt"
    playlist.write_text("".join("file '" + str(path).replace("'", "'\\''") + "'\n" for path in videos))
    showcase = output / "protagonist_2d_showcase.mp4"
    subprocess.run([ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(playlist), "-c", "copy", "-movflags", "+faststart", str(showcase)], check=True)
    report = {"proof_kind": "actual Godot board capture", "cycles_per_stationary_action": args.cycles, "full_frame_output_fps": 72, "captured_clips": captured, "videos": [str(path) for path in videos], "showcase": str(showcase)}
    walking_clips = [path for path in videos if path.stem in {"front_walk", "rear_walk"}]
    if len(walking_clips) == 2:
        walking_playlist = output / "walking.txt"
        walking_playlist.write_text("".join("file '" + str(path).replace("'", "'\\''") + "'\n" for path in walking_clips))
        walking_video = output / "walking_front_rear.mp4"
        subprocess.run([ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(walking_playlist), "-c", "copy", "-movflags", "+faststart", str(walking_video)], check=True)
        report["walking_front_rear"] = str(walking_video)
    paired = encode_paired_travel(ffmpeg, clips, output, tuple(args.travel_crop))
    if paired:
        report["paired_travel"] = paired
    expected = {
        output / (clip["name"] + ".mp4"): ((1920, 1080), 72,
            round(clip["captured_frames"] * clip["repeats"] * 72 / clip["captured_fps"]))
        for clip in captured
    }
    expected[showcase] = ((1920, 1080), 72, sum(value[2] for value in expected.values()))
    if len(walking_clips) == 2:
        expected[walking_video] = ((1920, 1080), 72, sum(expected[path][2] for path in walking_clips))
    if paired:
        walk = next(clip for clip in captured if clip["name"] == "front_walk")
        expected[Path(paired["video"])] = (tuple(paired["size"]), int(walk["captured_fps"]), walk["captured_frames"])
    verified = []
    # Verify only outputs from this run; a separately composed board reel may
    # already coexist here when the documented encoders are rerun.
    for path in sorted(expected):
        metadata = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height,avg_frame_rate,duration,nb_frames", "-of", "json", str(path)], text=True))["streams"][0]
        expected_size, expected_fps, expected_frames = expected[path]
        if ((metadata["width"], metadata["height"]) != expected_size
                or metadata["avg_frame_rate"] != f"{expected_fps}/1"
                or int(metadata["nb_frames"]) != expected_frames):
            raise ValueError(f"Unexpected encoded dimensions or timing: {path}")
        subprocess.run([ffmpeg, "-hide_banner", "-v", "error", "-xerror", "-i", str(path), "-f", "null", "-"], check=True)
        verified.append({"path": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "complete_decode": True, **metadata})
    report["verified_videos"] = verified
    (output / "video_manifest.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
