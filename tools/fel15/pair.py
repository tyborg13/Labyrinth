#!/usr/bin/env python3
"""Align two Movie Maker takes at Pass and retain both game-audio tracks."""

import json
from pathlib import Path
import re
import subprocess
import sys


AUDIO_HZ = 48000
SIZE = (1920, 1080)
VIDEO_CRF = "15"
AUDIO_BITRATE = "192k"
MIN_AUDIO_PEAK_DBFS = -90


def streams(path):
    return json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_streams", "-of", "json", str(path)
    ], text=True))["streams"]


def boundaries(directory, fps):
    video, audio = streams(directory / "turn.avi")
    if (video["width"], video["height"], video["r_frame_rate"], audio["sample_rate"]) != (*SIZE, f"{fps}/1", str(AUDIO_HZ)):
        raise ValueError(f"Unexpected Movie Maker format in {directory}")
    fixture, = json.loads((directory / "timeline.json").read_text())["fixtures"]
    start, end = fixture["movie_frames"]
    if not 0 <= start < end <= int(video["nb_frames"]):
        raise ValueError(f"Invalid Pass-to-input boundaries in {directory}")
    return start, end


def filters(bounds, fps):
    samples_per_frame = AUDIO_HZ // fps
    longest = max(end - start for start, end in bounds)
    graph = []
    for index, (start, end) in enumerate(bounds):
        graph.append(f"[{index}:v]trim=start_frame={start}:end_frame={end},setpts=PTS-STARTPTS,"
                     f"tpad=stop_mode=clone:stop={longest - end + start},setsar=1[v{index}]")
        graph.append(f"[{index}:a]atrim=start_sample={start * samples_per_frame}:end_sample={end * samples_per_frame},"
                     f"asetpts=PTS-STARTPTS,apad=whole_len={longest * samples_per_frame}[a{index}]")
    graph.append("[v0][v1]hstack=shortest=1,format=yuv420p[side]")
    return ";".join(graph)


def encode(release, branch, output, fps):
    if AUDIO_HZ % fps:
        raise ValueError("Capture FPS must divide the audio sample rate")
    bounds = [boundaries(directory, fps) for directory in (release, branch)]
    subprocess.run([
        "ffmpeg", "-n", "-v", "error", "-i", str(release / "turn.avi"), "-i", str(branch / "turn.avi"),
        "-filter_complex", filters(bounds, fps), "-map", "[side]", "-map", "[a0]", "-map", "[a1]",
        "-metadata:s:a:0", "handler_name=Release game audio", "-metadata:s:a:1", "handler_name=Branch game audio",
        "-c:v", "libx264", "-crf", VIDEO_CRF, "-c:a", "aac", "-b:a", AUDIO_BITRATE, "-movflags", "+faststart", str(output),
    ], check=True)
    video, *audio = streams(output)
    longest = max(end - start for start, end in bounds)
    if ((video["width"], video["height"], video["r_frame_rate"], int(video["nb_frames"]))
            != (SIZE[0] * 2, SIZE[1], f"{fps}/1", longest) or len(audio) != 2):
        raise ValueError(f"Invalid paired video or missing audio tracks in {output}")
    for index in range(len(audio)):
        volume = subprocess.run(["ffmpeg", "-hide_banner", "-i", str(output), "-map", f"0:a:{index}",
                                 "-af", "volumedetect", "-f", "null", "-"], capture_output=True, text=True, check=True)
        peak = re.search(r"max_volume: (-?[\d.]+) dB", volume.stderr)
        if peak is None or float(peak[1]) <= MIN_AUDIO_PEAK_DBFS:
            raise ValueError(f"Missing audible game audio in track {index} of {output}")
    print(f"FEL15 PAIRED MOVIE PASS {output} release_left=1920x1080 branch_right=1920x1080 audio_tracks=2")


if __name__ == "__main__":
    encode(*map(Path, sys.argv[1:4]), int(sys.argv[4]))
