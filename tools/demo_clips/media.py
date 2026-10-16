"""AVI Movie Maker input, PCM extraction and delivery media validation."""
from __future__ import annotations

import json
from pathlib import Path
import re
import struct
import subprocess

FPS = 60
AUDIO_RATE = 48000
FFMPEG_THREADS = 2


def read_wave(path):
    """PCM RIFF reader, including ffmpeg's WAVE_FORMAT_EXTENSIBLE on Python 3.9."""
    data = Path(path).read_bytes()
    if data[:4] != b"RIFF" or data[8:12] != b"WAVE": raise ValueError("Expected RIFF WAV")
    offset, fmt, audio = 12, None, None
    while offset + 8 <= len(data):
        kind, size = struct.unpack_from("<4sI", data, offset)
        payload = data[offset+8:offset+8+size]
        if kind == b"fmt ": fmt = payload
        if kind == b"data": audio = payload
        offset += 8 + size + (size % 2)
    if fmt is None or audio is None or len(fmt) < 16: raise ValueError("Incomplete WAV chunks")
    code, channels, rate, _, align, bits = struct.unpack_from("<HHIIHH", fmt)
    if code == 65534 and len(fmt) >= 40: code = struct.unpack_from("<H", fmt, 24)[0]
    if code != 1 or align != channels * bits // 8 or len(audio) % align: raise ValueError("Unsupported or malformed PCM WAV")
    return {"channels": channels, "rate": rate, "width": bits//8, "frames": len(audio)//align, "data": audio}


def ffmpeg(args):
    result = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-threads", str(FFMPEG_THREADS), "-filter_threads", str(FFMPEG_THREADS), "-filter_complex_threads", str(FFMPEG_THREADS), *map(str, args)], capture_output=True, text=True)
    if result.returncode: raise ValueError("ffmpeg failed: " + result.stderr)
    return result


def probe(path):
    result = subprocess.run(["ffprobe", "-v", "error", "-count_frames", "-show_streams", "-show_format", "-of", "json", str(path)], check=True, capture_output=True, text=True)
    return json.loads(result.stdout)


def remove_frames(directory):
    """Remove legacy/interrupted PNGs; the current capture never creates them."""
    count = 0
    for path in directory.glob("movie*.png"):
        if re.fullmatch(r"movie\d+\.png", path.name):
            path.unlink()
            count += 1
    return count


def intermediate_info(directory, expected_size=(1920, 1080)):
    path = directory / "movie.avi"
    streams = probe(path)["streams"]
    video = next((s for s in streams if s["codec_type"] == "video"), {})
    audio = next((s for s in streams if s["codec_type"] == "audio"), {})
    if video.get("codec_name") != "mjpeg": raise ValueError("Expected an MJPEG AVI intermediate")
    if audio.get("codec_name") not in {"pcm_s16le", "pcm_s24le", "pcm_s32le"}:
        raise ValueError("AVI must contain uncompressed PCM audio")
    if int(audio["sample_rate"]) != AUDIO_RATE or int(audio["channels"]) != 2:
        raise ValueError("AVI PCM must be stereo 48 kHz")
    if (int(video["width"]), int(video["height"])) != expected_size:
        raise ValueError("Unexpected intermediate dimensions")
    if video["r_frame_rate"] != "60/1": raise ValueError("Intermediate is not 60 fps")
    return {"path": str(path), "frame_count": int(video["nb_read_frames"]), "audio_codec": audio["codec_name"]}


def prepare_avi(directory, expected_size=(1920, 1080)):
    info = intermediate_info(directory, expected_size)
    # Copy the AVI's PCM verbatim for sync analysis and retained audio evidence.
    # Video stays in the original AVI; no video transcode or PNG stage occurs.
    ffmpeg(["-i", directory / "movie.avi", "-map", "0:a:0", "-vn", "-c:a", "copy", directory / "movie.wav"])
    return info


def duration_info(directory, report, expected_size=(1920, 1080)):
    info = intermediate_info(directory, expected_size)
    start, end = report["start_frame"], report["end_frame"]
    if start < 0 or end <= start or end > info["frame_count"]:
        raise ValueError("Logged frame range is outside the AVI intermediate")
    wav = read_wave(directory / "movie.wav")
    if wav["rate"] != AUDIO_RATE: raise ValueError("Movie Maker WAV must be 48 kHz")
    if wav["frames"] < end * AUDIO_RATE // FPS:
        raise ValueError("Movie Maker audio ends before logged video")
    return {"intermediate": info["path"], "raw_frame_count": info["frame_count"],
            "start_frame": start, "end_frame": end, "frame_count": end - start,
            "duration": (end - start) / FPS, "wav_duration": wav["frames"] / AUDIO_RATE}

