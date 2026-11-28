#!/usr/bin/env python3
"""Align the two MovieWriter takes at each input segment and label the pair."""
import argparse
import json
import subprocess
from pathlib import Path

BUILDS = ("before", "after")
PARTS = ("hand", "grimoire")
SOURCE_SIZE = (1920, 1080)
PANEL_SIZE = (960, 540)
BADGE_POSITION = (8, 44)  # Below the room title and depth.
BADGE_FONT_SIZE = 18
BADGE_PADDING = 6


def read_timeline(folder: Path, build: str) -> dict:
    take = json.loads((folder / "take.json").read_text())
    if take["build"] != build or set(take["parts"]) != set(PARTS):
        raise ValueError(f"{folder} is missing a take or a segment")
    previous_end = 0
    for part in PARTS:
        segment = take["parts"][part]
        start, end = segment["first_frame"], segment["end_frame"]
        if not previous_end <= start < end <= take["last_process_frame"]:
            raise ValueError(f"{folder} has invalid {part} cuts")
        previous_end = end
    return take


def segment_lengths(take: dict) -> tuple:
    return tuple(take["parts"][part]["end_frame"] - take["parts"][part]["first_frame"] for part in PARTS)


def read_video(path: Path) -> tuple:
    document = subprocess.check_output(
        ["ffprobe", "-v", "error", "-show_streams", "-of", "json", str(path)],
        text=True,
    )
    streams = json.loads(document)["streams"]
    video = next(stream for stream in streams if stream["codec_type"] == "video")
    return video, any(stream["codec_type"] == "audio" for stream in streams)


def make_badge(label: str, path: Path) -> None:
    from PIL import Image, ImageDraw, ImageFont

    font = ImageFont.load_default(size=BADGE_FONT_SIZE)
    left, top, right, bottom = font.getbbox(label)
    width = right - left + 2 * BADGE_PADDING
    height = bottom - top + 2 * BADGE_PADDING
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((0, 0, width - 1, height - 1), radius=4, fill=(0, 0, 0, 216))
    draw.text((BADGE_PADDING - left, BADGE_PADDING - top), label, font=font, fill="white")
    image.save(path)


def aligned_cuts(take: dict, movie: Path) -> list:
    video, has_audio = read_video(movie)
    if (video["width"], video["height"]) != SOURCE_SIZE or not has_audio:
        raise ValueError(f"{movie} must contain a 1920x1080 image and audio")
    frames = int(video["nb_frames"])
    # MovieWriter and SceneTree count fixed-fps frames from different origins.
    # Anchor the timeline to the total frames present when the take quit.
    offset = frames - take["last_process_frame"]
    cuts = []
    for part in PARTS:
        segment = take["parts"][part]
        start = segment["first_frame"] + offset
        end = segment["end_frame"] + offset
        if not 0 <= start < end <= frames:
            raise ValueError(f"{movie} does not cover its {part} cut")
        cuts.append((start, end))
    return cuts


def encode(output: Path, takes: list) -> None:
    movies = [output / build / "raw.avi" for build in BUILDS]
    badges = [output / f"{build}.png" for build in BUILDS]
    filters = []
    fps = takes[1]["fps"]
    width, height = PANEL_SIZE
    x, y = BADGE_POSITION
    for source, (take, movie, badge) in enumerate(zip(takes, movies, badges)):
        make_badge(BUILDS[source].title(), badge)
        for part, (start, end) in enumerate(aligned_cuts(take, movie)):
            filters.append(
                f"[{source}:v]trim=start_frame={start}:end_frame={end},"
                f"setpts=PTS-STARTPTS,scale={width}:{height}[v{source}{part}]"
            )
            # Use the after take's audio to avoid playing both scores at once.
            if source == 1:
                filters.append(
                    f"[1:a]atrim=start={start / fps:.9f}:end={end / fps:.9f},"
                    f"asetpts=PTS-STARTPTS[a{part}]"
                )
        videos = "".join(f"[v{source}{part}]" for part in range(len(PARTS)))
        filters.append(f"{videos}concat=n={len(PARTS)}:v=1:a=0[video{source}]")
        filters.append(f"[video{source}][{source + 2}:v]overlay={x}:{y}[panel{source}]")
    audio = "".join(f"[a{part}]" for part in range(len(PARTS)))
    filters.append(f"{audio}concat=n={len(PARTS)}:v=0:a=1[audio]")
    filters.append("[panel0][panel1]hstack=inputs=2[video]")
    pair = output / "pair.mp4"
    command = ["ffmpeg", "-nostdin", "-v", "error"]
    for source in movies + badges:
        command.extend(("-i", str(source)))
    command.extend((
        "-filter_complex", ";".join(filters), "-map", "[video]", "-map", "[audio]",
        "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", "-movflags", "+faststart", str(pair),
    ))
    subprocess.run(command, check=True)
    video, has_audio = read_video(pair)
    if (video["width"], video["height"]) != (width * 2, height) or not has_audio:
        raise ValueError("the pair has incorrect dimensions or missing audio")
    if int(video["nb_frames"]) != sum(segment_lengths(takes[1])):
        raise ValueError("the pair has an incorrect frame count")
    print(f"POL85 NATIVE PAIR PASS {width * 2}x{height} with audio\n{pair}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--timeline-only", action="store_true")
    args = parser.parse_args()
    takes = [read_timeline(args.output / build, build) for build in BUILDS]
    lengths = segment_lengths(takes[0])
    if takes[0]["fps"] != takes[1]["fps"] or lengths != segment_lengths(takes[1]):
        raise ValueError("before and after have different input segment lengths")
    print(f"POL85 TIMELINE PASS hand={lengths[0]} grimoire={lengths[1]} fps={takes[0]['fps']}")
    if not args.timeline_only:
        encode(args.output, takes)


if __name__ == "__main__":
    main()
