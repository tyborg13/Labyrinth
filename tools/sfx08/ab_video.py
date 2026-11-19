#!/usr/bin/env python3
"""Render captioned MP4s from the A/B WAVs using the repo's existing Pillow and FFmpeg."""

import argparse
from pathlib import Path
import subprocess
import tempfile
import wave

from PIL import Image, ImageDraw, ImageFont

FRAME_SIZE = (1920, 1080)
FRAME_RATE = 30
CAPTION_SIZE = 60
CAPTION_COLOR = "white"
ENCODER_THREADS = 2
MOVIE_TIMESCALE = 48000
AUDIO_BITRATE = "256k"


def caption(path, cue, phase):
    frame = Image.new("RGB", FRAME_SIZE, "black")
    draw = ImageDraw.Draw(frame)
    draw.multiline_text((FRAME_SIZE[0] // 2, FRAME_SIZE[1] // 2), f"{cue}\n{phase}",
                        fill=CAPTION_COLOR, font=ImageFont.load_default(size=CAPTION_SIZE),
                        anchor="mm", align="center")
    frame.save(path)


def video(directory, cue, temporary):
    command = ["ffmpeg", "-v", "error", "-y", "-filter_complex_threads", str(ENCODER_THREADS)]
    for phase in ("before", "after"):
        audio = directory / f"{cue}_{phase}.wav"
        image = temporary / f"{phase}.png"
        caption(image, cue, phase)
        with wave.open(str(audio), "rb") as wav:
            duration = wav.getnframes() / wav.getframerate()
        command += ["-loop", "1", "-framerate", str(FRAME_RATE), "-t", str(duration), "-i", str(image),
                    "-i", str(audio)]
    subprocess.run(command + [
        "-filter_complex", "[0:v][2:v]concat=n=2:v=1:a=0[v];[1:a][3:a]concat=n=2:v=0:a=1[a]",
        "-map", "[v]", "-map", "[a]", "-c:v", "libx264", "-threads", str(ENCODER_THREADS),
        "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", AUDIO_BITRATE,
        "-movie_timescale", str(MOVIE_TIMESCALE),
        "-movflags", "+faststart",
        str(directory / f"{cue}_ab.mp4"),
    ], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path, help="Directory with the proof WAVs")
    args = parser.parse_args()
    suffix = "_before.wav"
    with tempfile.TemporaryDirectory(prefix="caption-", dir=args.directory) as temporary:
        for wav in sorted(args.directory.glob("*" + suffix)):
            video(args.directory, wav.name[:-len(suffix)], Path(temporary))


if __name__ == "__main__":
    main()
