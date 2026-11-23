#!/usr/bin/env python3
"""Validate the paired takes and assemble the director's 1080p60 reel."""

import argparse
import json
from pathlib import Path
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "fnd01"))
from encode_clips import ffmpeg, probe, take_audio, write_mix

CASES = ("shop_card", "shop_gear", "event_relic", "event_card", "dragon")
SIZE = (1920, 1080)
FPS = 60
FRAMES_PER_TAKE = 96
LEAD_FRAMES = 8
CROP_FRAMES = [0, 4, 8, 14, 22, 30]
ARRIVAL_OFFSETS = [0, 6]


def load_takes(root):
    after_paths = []
    for case in CASES:
        before, after = (root / version / case for version in ("before", "after"))
        prior, take = (json.loads((directory / "take.json").read_text()) for directory in (before, after))
        keys = ("timing", "effects", "crop_position", "snap_frames")
        if any(prior[key] != take[key] for key in keys) or take["snap_frames"] != CROP_FRAMES:
            raise ValueError(f"Before/after pacing or origin crop differs for {case}")
        clip = take["clip"]
        arrival = take["arrival"]
        if ((clip["width"], clip["height"]) != SIZE or clip["fps"] != FPS
                or clip["lead"] != LEAD_FRAMES or clip["frames"] != FRAMES_PER_TAKE
                or arrival["offsets"] != ARRIVAL_OFFSETS
                or not 0 < LEAD_FRAMES + arrival["frame"] + ARRIVAL_OFFSETS[-1] < FRAMES_PER_TAKE):
            raise ValueError(f"Invalid 1080p60 take or arrival crop for {case}")
        if root.name == "native":
            for name in ("arrival.png", "arrival-plus-100ms.png"):
                if not (after / name).is_file():
                    raise ValueError(f"Missing {name} for {case}")
        print(f"FND-03 CAPTURE PACING PASS {case}: {take['effects']} {take['timing']}")
        after_paths.append(after)
    return after_paths


def encode(directories, output):
    paths = [directory / "frames.rgb" for directory in directories]
    ranges = [(0, FRAMES_PER_TAKE)] * len(paths)
    for path in paths:
        if path.stat().st_size != FRAMES_PER_TAKE * SIZE[0] * SIZE[1] * 3:
            raise ValueError(f"Unexpected RGB frame count in {path}")
    audio = [take_audio(directory, first, end)
             for directory, (first, end) in zip(directories, ranges)]
    if not all(audio):
        raise ValueError("Each take must have audible synchronized MovieWriter audio.")
    with tempfile.TemporaryDirectory(prefix="acquisition-gains-", dir=output.parent) as temporary:
        mix = Path(temporary) / "gains.wav"
        movie = Path(temporary) / output.name
        write_mix(mix, audio, ranges)
        inputs = []
        for path in paths:
            inputs.extend(["-f", "rawvideo", "-pixel_format", "rgb24", "-video_size", "1920x1080",
                           "-framerate", FPS, "-i", path])
        frames = len(paths) * FRAMES_PER_TAKE
        tracks = "".join(f"[{index}:v]" for index in range(len(paths)))
        ffmpeg(*inputs, "-i", mix, "-filter_complex",
               f"{tracks}concat=n={len(paths)}:v=1:a=0,settb=1/{FPS},setpts=N[video]",
               "-map", "[video]", "-map", f"{len(paths)}:a", "-r", FPS, "-fps_mode", "cfr",
               "-c:v", "libx264", "-crf", 20, "-pix_fmt", "yuv420p", "-c:a", "aac",
               "-movflags", "+faststart", movie)
        streams = probe(movie)
        video = next(stream for stream in streams if stream["codec_type"] == "video")
        if ((video["width"], video["height"]) != SIZE or video["avg_frame_rate"] != f"{FPS}/1"
                or int(video["nb_frames"]) != frames
                or not any(stream["codec_type"] == "audio" for stream in streams)):
            raise ValueError("Encoded reel differs from the 1080p60 video and audio contract.")
        movie.replace(output)
    for path in paths:
        path.unlink()
    print(f"FND-03 REEL PASS: {frames} frames at {FPS} fps with audio")
    print(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("takes", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--plan", action="store_true")
    args = parser.parse_args()
    directories = load_takes(args.takes)
    if args.plan:
        for case in CASES:
            for version in ("before", "after"):
                native = args.output.parent / version / case
                print(native / "native-evidence.png")
                print(native / "strip.png")
                if version == "after":
                    print(native / "arrival.png")
                    print(native / "arrival-plus-100ms.png")
        print(f"FND-03 REEL PLAN: {len(CASES) * FRAMES_PER_TAKE} frames at {FPS} fps with audio")
        print(args.output)
    else:
        encode(directories, args.output)


if __name__ == "__main__":
    main()
