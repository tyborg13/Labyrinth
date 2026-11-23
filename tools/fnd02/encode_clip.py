#!/usr/bin/env python3
"""Join the two native relic takes with their synchronized MovieWriter audio."""

import argparse
import json
from pathlib import Path
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "fnd01"))
from encode_clips import ffmpeg, probe, take_audio, write_mix

CASES = ("venom", "storm")
SIZE = (1920, 1080)
FPS = 60
FRAMES_PER_CLAIM = 120
CROP_FRAMES = [0, 4, 8, 14, 22, 30]


def load_takes(root):
    directories = []
    for case in CASES:
        before, after = (root / version / case for version in ("before", "after"))
        receipts = [json.loads((path / "take.json").read_text()) for path in (before, after)]
        prior, take = receipts
        new_timing = take["timing"]
        if (prior["timing"] != {key: value for key, value in new_timing.items()
                                if key not in ("burst", "burst_end")}
                or prior["crop_position"] != take["crop_position"]
                or any(receipt["snap_frames"] != CROP_FRAMES for receipt in receipts)):
            raise ValueError(f"Before/after claim pacing or crop differs for {case}")
        clip = take["clip"]
        if ((clip["width"], clip["height"]) != SIZE or clip["fps"] != FPS
                or clip["frames"] != FRAMES_PER_CLAIM or not
                0 < clip["lead"] < clip["lead"] + new_timing["complete"] < FRAMES_PER_CLAIM):
            raise ValueError(f"Invalid 1080p60 claim span for {case}")
        print(f"FND-02 CAPTURE PACING PASS {case}: {new_timing}")
        directories.append(after)
    return directories


def encode(directories, output):
    paths = [directory / "frames.rgb" for directory in directories]
    ranges = [(0, FRAMES_PER_CLAIM)] * len(paths)
    for path in paths:
        if path.stat().st_size != FRAMES_PER_CLAIM * SIZE[0] * SIZE[1] * 3:
            raise ValueError(f"Unexpected RGB frame count in {path}")
    audio = [take_audio(directory, first, end)
             for directory, (first, end) in zip(directories, ranges)]
    if not all(audio):
        raise ValueError("Both takes must have audible MovieWriter audio.")
    with tempfile.TemporaryDirectory(prefix="relic-claims-", dir=output.parent) as temporary:
        mix = Path(temporary) / "claims.wav"
        movie = Path(temporary) / output.name
        write_mix(mix, audio, ranges)
        inputs = []
        for path in paths:
            inputs.extend(["-f", "rawvideo", "-pixel_format", "rgb24", "-video_size", "1920x1080",
                           "-framerate", FPS, "-i", path])
        ffmpeg(*inputs, "-i", mix, "-filter_complex",
               "[0:v][1:v]concat=n=2:v=1:a=0,settb=1/60,setpts=N[video]",
               "-map", "[video]", "-map", "2:a", "-r", FPS, "-fps_mode", "cfr",
               "-c:v", "libx264", "-crf", 20, "-pix_fmt", "yuv420p", "-c:a", "aac",
               "-movflags", "+faststart", movie)
        streams = probe(movie)
        video = next(stream for stream in streams if stream["codec_type"] == "video")
        if ((video["width"], video["height"]) != SIZE or video["avg_frame_rate"] != f"{FPS}/1"
                or int(video["nb_frames"]) != len(paths) * FRAMES_PER_CLAIM
                or not any(stream["codec_type"] == "audio" for stream in streams)):
            raise ValueError("Encoded clip differs from the 1080p60 video and audio contract.")
        movie.replace(output)
    for path in paths:
        path.unlink()
    print(f"FND-02 CLIP PASS: {len(paths) * FRAMES_PER_CLAIM} frames at {FPS} fps with audio")
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
        print(f"FND-02 CLIP PLAN: {len(CASES) * FRAMES_PER_CLAIM} frames at {FPS} fps with audio")
        print(args.output)
    else:
        encode(directories, args.output)


if __name__ == "__main__":
    main()
