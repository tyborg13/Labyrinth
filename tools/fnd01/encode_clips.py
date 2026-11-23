#!/usr/bin/env python3
"""Join two full-frame acquisition takes and preserve any source MovieWriter mix."""

import argparse
import json
from pathlib import Path
import subprocess
import tempfile
import wave

FPS = 60
LEAD_FRAMES = 18
TAIL_FRAMES = 30
INPUT_SIZE = (1920, 1080)
OUTPUT_SIZE = (1280, 720)
MAX_BYTES = 4_000_000
MUX_RESERVE_BYTES = 100_000
AUDIO_KBPS = 160
AUDIO_RATE = 48_000
AUDIO_CHANNELS = 2
PCM_SAMPLE_BYTES = 2
SPEED_DIVISOR = 4
VBV_SECONDS = 0.5


def ffmpeg(*args, capture=False):
    return subprocess.run(
        ["ffmpeg", "-nostdin", "-v", "error", *map(str, args)],
        check=True, stdout=subprocess.PIPE if capture else None,
    ).stdout


def probe(path):
    return json.loads(subprocess.check_output(
        ["ffprobe", "-v", "error", "-show_streams", "-of", "json", str(path)]
    ))["streams"]


def take_range(directory, case):
    take = json.loads((directory / "take.json").read_text())
    clip = take["clip"]
    if (take["case"] != case or clip["fps"] != FPS or
            (clip["width"], clip["height"]) != INPUT_SIZE or
            clip["pickup_frame"] - clip["first_frame"] != LEAD_FRAMES or
            clip["end_frame"] - clip["settled_frame"] != TAIL_FRAMES or
            not 0 <= clip["first_frame"] < clip["pickup_frame"] <= clip["settled_frame"]):
        raise ValueError(f"Invalid clip timing or framebuffer for {directory}")
    return clip["first_frame"], clip["end_frame"]


def sync_frame(movie):
    # The sink is solid red before the first raw frame and solid green from
    # that frame forward. Decode only the sink, which is separate from the HUD.
    pixels = ffmpeg("-i", movie, "-map", "0:v:0", "-vf", "scale=1:1,format=rgb24",
                    "-fps_mode", "passthrough", "-pix_fmt", "rgb24", "-f", "rawvideo", "-",
                    capture=True)
    saw_red = False
    for frame, (red, green, blue) in enumerate(zip(pixels[::3], pixels[1::3], pixels[2::3])):
        if red > 170 and green < 90 and blue < 90:
            saw_red = True
        if saw_red and green > 170 and red < 90 and blue < 90:
            return frame
    raise ValueError(f"MovieWriter sync mark missing in {movie}")


def take_audio(directory, first, end):
    movie = directory / "clock.avi"
    if not movie.is_file() or not any(stream["codec_type"] == "audio" for stream in probe(movie)):
        return b""
    pcm = ffmpeg(
        "-i", movie, "-map", "0:a:0", "-vn", "-ar", AUDIO_RATE, "-ac", AUDIO_CHANNELS,
        "-f", "s16le", "-", capture=True,
    )
    # MovieWriter can emit an empty mix. For audible sources, cut against the
    # same frame as the RGB stream and check the selected interval as well.
    if not any(pcm):
        return b""
    frame = sync_frame(movie)
    frame_bytes = (AUDIO_RATE // FPS) * AUDIO_CHANNELS * PCM_SAMPLE_BYTES
    samples = pcm[(frame + first) * frame_bytes:(frame + end) * frame_bytes]
    return samples if any(samples) else b""


def write_mix(path, chunks, ranges):
    with wave.open(str(path), "wb") as mix:
        mix.setnchannels(AUDIO_CHANNELS)
        mix.setsampwidth(PCM_SAMPLE_BYTES)
        mix.setframerate(AUDIO_RATE)
        for samples, (first, end) in zip(chunks, ranges):
            size = (end - first) * (AUDIO_RATE // FPS) * AUDIO_CHANNELS * PCM_SAMPLE_BYTES
            mix.writeframes(samples.ljust(size, b"\0"))


def encode(paths, ranges, output, speed_divisor, mix=None):
    width, height = INPUT_SIZE
    size = f"{width}x{height}"
    output_width, output_height = OUTPUT_SIZE
    command = []
    filters = []
    for index, (path, (first, end)) in enumerate(zip(paths, ranges)):
        command.extend(["-f", "rawvideo", "-pixel_format", "rgb24", "-video_size", size,
                        "-framerate", FPS, "-i", path])
        filters.append(
            f"[{index}:v]trim=start_frame={first}:end_frame={end},setpts=PTS-STARTPTS,"
            f"scale={output_width}:{output_height}:flags=lanczos,setsar=1[take{index}]"
        )
    # Rebuild contiguous timestamps across the cut. A 15 fps output presents
    # every source frame for four of its original 60 fps ticks.
    filters.append(
        f"[take0][take1]concat=n=2:v=1:a=0,settb=1/{FPS},setpts={speed_divisor}*N[video]"
    )
    rate = FPS // speed_divisor
    frames = sum(end - first for first, end in ranges)
    duration = frames / rate
    audio_kbps = AUDIO_KBPS if mix else 0
    # Leave space for the container and one VBV buffer. Use constrained CRF
    # so the byte limit never shortens the requested footage.
    maxrate = min(6_000, int((MAX_BYTES - MUX_RESERVE_BYTES) * 8 / 1_000 /
                            (duration + VBV_SECONDS) - audio_kbps))
    if mix:
        command.extend(["-i", mix])
    command.extend(["-filter_complex", ";".join(filters), "-map", "[video]"])
    if mix:
        command.extend(["-map", "2:a:0", "-c:a", "aac", "-b:a", f"{audio_kbps}k"])
    else:
        command.append("-an")
    ffmpeg(*command, "-r", rate, "-fps_mode", "cfr", "-c:v", "libx264", "-pix_fmt", "yuv420p",
           "-crf", 22, "-maxrate", f"{maxrate}k", "-bufsize", f"{int(maxrate * VBV_SECONDS)}k",
           "-movflags", "+faststart", output)
    streams = probe(output)
    video = next(stream for stream in streams if stream["codec_type"] == "video")
    if (int(video["nb_frames"]) != frames or video["avg_frame_rate"] != f"{rate}/1" or
            (video["width"], video["height"]) != OUTPUT_SIZE or
            video["codec_name"] != "h264" or video["pix_fmt"] != "yuv420p" or
            any(stream["codec_type"] == "audio" for stream in streams) != bool(mix)):
        raise ValueError(f"Encoded video or audio differs from the clip contract: {output.name}")
    if output.stat().st_size >= MAX_BYTES:
        raise ValueError(f"{output.name} exceeded the {MAX_BYTES:,}-byte limit")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--takes", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--plan", action="store_true")
    parser.add_argument("case", choices=["item", "gear", "epic", "common"])
    args = parser.parse_args()
    versions = ("before", "after")
    directories = [args.takes / version / args.case for version in versions]
    ranges = [take_range(directory, args.case) for directory in directories]
    destinations = (args.output / f"{args.case}.mp4", args.output / f"{args.case}-quarter-speed.mp4")
    if args.plan:
        print(f"FND-01 CLIP PLAN {args.case}: Before {ranges[0]}, Now {ranges[1]} "
              f"(end exclusive; {LEAD_FRAMES} lead frames, {TAIL_FRAMES} tail frames)")
        for destination in destinations:
            print(destination)
        return

    paths = [directory / "frames.rgb" for directory in directories]
    for path, (_, end) in zip(paths, ranges):
        if path.stat().st_size != end * INPUT_SIZE[0] * INPUT_SIZE[1] * 3:
            raise ValueError(f"Unexpected RGB frame count in {path}")
    chunks = [take_audio(directory, first, end) for directory, (first, end) in zip(directories, ranges)]
    audio_sources = [version for version, samples in zip(versions, chunks) if samples]
    args.output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=f"{args.case}-", dir=args.output) as temporary:
        directory = Path(temporary)
        mix = directory / "movie-writer.wav" if audio_sources else None
        if mix:
            write_mix(mix, chunks, ranges)
        game_speed, quarter_speed = (directory / destination.name for destination in destinations)
        encode(paths, ranges, game_speed, 1, mix)
        encode(paths, ranges, quarter_speed, SPEED_DIVISOR)
        game_speed.replace(destinations[0])
        quarter_speed.replace(destinations[1])
    for path in paths:
        path.unlink()
    audio_result = (f"MovieWriter audio kept from {', '.join(audio_sources)}"
                    if audio_sources else "silent (MovieWriter had no audible audio in either take)")
    print(f"FND-01 CLIP AUDIO {args.case}: {audio_result}. Quarter-speed clip is silent.")
    for destination in destinations:
        print(destination)


if __name__ == "__main__":
    main()
