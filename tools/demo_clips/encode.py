#!/usr/bin/env python3
"""Encode approved demo takes, audit sync, and assemble reels in director order."""
from __future__ import annotations

import argparse
from array import array
from contextlib import contextmanager
import json
from pathlib import Path
import re
import subprocess
import sys
import uuid
import wave

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.demo_clips import media, pipeline, recording, storage, sync
from tools.demo_clips.media import AUDIO_RATE, FFMPEG_THREADS, FPS, ffmpeg, probe, read_wave

FADE_SECONDS = 0.006


@contextmanager
def atomic_delivery(output):
    """Keep the previous delivery until the replacement passes media probing."""
    output.parent.mkdir(parents=True, exist_ok=True)
    pending = output.with_name(f".{output.stem}.{uuid.uuid4().hex}.pending{output.suffix}")
    try:
        yield pending
        pending.replace(output)
    finally:
        pending.unlink(missing_ok=True)


def caption_image(clip, style, work, size):
    subtitle_y = style.get("subtitle_top_px")
    if subtitle_y is None:
        raise ValueError("caption_style.subtitle_top_px is required")
    work.mkdir(parents=True, exist_ok=True)
    x, y = style["position_px"]
    if style["font"] != "game UI font": raise ValueError("Unapproved caption font")
    shadow = re.fullmatch(r"(\d+) px (#[0-9A-Fa-f]{6}) at (\d+)%", style["shadow"])
    if not shadow: raise ValueError("Unsupported director shadow syntax")
    lines = []
    for name, top, font_size in (("title", y, style["title_px"]), ("subtitle", subtitle_y, style["subtitle_px"])):
        lines.append({"text": clip[name], "x": x, "y": top, "size": font_size})
    spec = work / f"{clip['id']}-caption.json"
    image = work / f"{clip['id']}-caption.png"
    # JSON carries text unchanged, including apostrophes, dashes and percent.
    spec.write_text(json.dumps({"width": size[0], "height": size[1], "color": style["color"], "lines": lines,
                               "shadow_px": int(shadow[1]), "shadow_color": shadow[2], "shadow_alpha": int(shadow[3])/100}))
    result = subprocess.run([sys.executable, "tools/godot_task_runner.py", "--task-id", "demo-01", "--stream", "--", "godot", "--headless", "--path", ".", "--quit-after", "3", "--script", "tools/demo_clips/caption_raster.gd", "--", str(spec.resolve()), str(image.resolve())], cwd=pipeline.ROOT, capture_output=True, text=True)
    if result.returncode or not image.exists(): raise ValueError("Caption raster failed: " + result.stdout + result.stderr)
    return image


def encode_clip(directory, report, clip, style, output, work, expected_size=(1920, 1080)):
    source = media.duration_info(directory, report, expected_size)
    raw_count = source["raw_frame_count"]
    start, end = report["start_frame"], report["end_frame"]
    count = end - start
    duration = count / FPS
    captions = caption_image(clip, style, work, expected_size)
    fade_start = style["visible_s"] - style["fade_out_s"]
    graph = (f"[0:v]trim=start_frame={start}:end_frame={end},setpts=PTS-STARTPTS[base];"
             f"[1:v]format=rgba,fade=t=out:st={fade_start}:d={style['fade_out_s']}:alpha=1[caption];"
             f"[base][caption]overlay=shortest=1:format=auto[v];"
             f"[0:a]atrim=start_sample={start*AUDIO_RATE//FPS}:end_sample={end*AUDIO_RATE//FPS},asetpts=PTS-STARTPTS,asplit=2[a][pcm]")
    output.parent.mkdir(parents=True, exist_ok=True)
    lossless_audio = work / f"{clip['id']}.wav"
    with atomic_delivery(output) as pending:
        ffmpeg(["-i", directory / "movie.avi", "-loop", "1", "-framerate", FPS, "-i", captions, "-filter_complex", graph,
                "-map", "[v]", "-map", "[a]", "-c:v", "libx264", "-crf", "16", "-preset", "slow", "-pix_fmt", "yuv420p", "-r", FPS,
                "-c:a", "aac", "-b:a", "192k", "-ar", AUDIO_RATE, "-threads", FFMPEG_THREADS, "-movflags", "+faststart", pending,
                "-map", "[pcm]", "-c:a", "pcm_s32le", "-ar", AUDIO_RATE, "-ac", "2", "-threads", FFMPEG_THREADS, lossless_audio])
        info = probe(pending)
        video = next(s for s in info["streams"] if s["codec_type"] == "video")
        audio = next(s for s in info["streams"] if s["codec_type"] == "audio")
        if (int(video["width"]), int(video["height"])) != expected_size: raise ValueError("Unexpected encoded dimensions")
        if int(video["nb_read_frames"]) != count or video["r_frame_rate"] != "60/1": raise ValueError("Encoded frame count / rate mismatch")
        if audio["codec_name"] != "aac" or int(audio["sample_rate"]) != AUDIO_RATE: raise ValueError("Encoded audio mismatch")
    return {"clip": clip["id"], "duration": duration, "frame_count": count, "raw_frame_count": raw_count,
            "start_frame": start, "end_frame": end, "sync_time_origin": "raw Movie Maker WAV/frame zero",
            "path": str(output), "lossless_audio": str(lossless_audio)}


def join_audio(paths, destination):
    """Hard-cut PCM with independent 6 ms fades at internal boundaries."""
    with wave.open(str(destination), "wb") as out:
        out.setparams((2, 4, AUDIO_RATE, 0, "NONE", "not compressed"))
        for index, path in enumerate(paths):
            source = read_wave(path)
            if (source["channels"], source["width"], source["rate"]) != (2, 4, AUDIO_RATE): raise ValueError("Reel PCM must be stereo 32-bit 48 kHz")
            data = array("i", source["data"])
            if sys.byteorder != "little": data.byteswap()
            frames = len(data) // 2
            fade = min(round(FADE_SECONDS * AUDIO_RATE), frames)
            for i in range(fade):
                scale = i / max(1, fade - 1)
                for channel in range(2):
                    if index > 0: data[2*i+channel] = round(data[2*i+channel] * scale)
                    if index < len(paths)-1: data[2*(frames-1-i)+channel] = round(data[2*(frames-1-i)+channel] * scale)
            if sys.byteorder != "little": data.byteswap()
            out.writeframes(data.tobytes())


def encode_reel(reel, rows, output, work):
    ordered = [rows[c["id"]] for c in reel["clips"]]
    audio = work / f"{reel['id']}-reel.wav"
    join_audio([r["lossless_audio"] for r in ordered], audio)
    concat = work / f"{reel['id']}.ffconcat"
    def quoted(path): return str(Path(path).resolve()).replace("'", "'\\''")
    concat.write_text("ffconcat version 1.0\n" + "".join(f"file '{quoted(r['path'])}'\nduration {r['duration']:.9f}\n" for r in ordered))
    output.parent.mkdir(parents=True, exist_ok=True)
    # Reuse already encoded H.264 packets: no second lossy video generation.
    # AAC is encoded once here from original trimmed PCM, not from clip AAC.
    with atomic_delivery(output) as pending:
        ffmpeg(["-f", "concat", "-safe", "0", "-i", concat, "-i", audio, "-map", "0:v", "-map", "1:a", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-ar", AUDIO_RATE, "-threads", FFMPEG_THREADS, "-movflags", "+faststart", pending])
        streams = probe(pending)["streams"]
        video = next(s for s in streams if s["codec_type"] == "video")
        audio_stream = next(s for s in streams if s["codec_type"] == "audio")
        if int(video["nb_read_frames"]) != sum(r["frame_count"] for r in ordered): raise ValueError("Reel frame count mismatch")
        if video["codec_name"] != "h264" or video["r_frame_rate"] != "60/1": raise ValueError("Reel video codec/rate mismatch")
        if audio_stream["codec_name"] != "aac" or int(audio_stream["sample_rate"]) != AUDIO_RATE:
            raise ValueError("Reel audio codec/rate mismatch")
    return {"reel": reel["id"], "clips": [c["id"] for c in reel["clips"]], "frame_count": int(video["nb_read_frames"]), "path": str(output), "probed": True}


def release_avis(output, manifest, expected_reels):
    """Release only proven source AVIs, after all requested reels pass probing."""
    cleanup = {"status": "retained", "deleted": [], "reason": "Reels are incomplete or failed probing"}
    if (manifest["failures"] or len(manifest["reels"]) != expected_reels
            or not all(reel.get("probed") for reel in manifest["reels"])):
        return cleanup
    paths = []
    # Validate every path/hash before deleting any source intermediate.
    for clip in manifest["clips"]:
        path = output / "raw" / clip["clip"] / "movie.avi"
        if storage.file_hash(path) != clip["input_hashes"]["movie.avi"]:
            raise ValueError(f"{clip['clip']}: AVI changed before cleanup; sources retained")
        paths.append(path)
    for path in paths:
        path.unlink()
        cleanup["deleted"].append(str(path))
    cleanup.update(status="deleted", reason="All reels encoded and probed successfully")
    return cleanup


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=pipeline.OUTPUT)
    args = parser.parse_args()
    output = args.output.resolve()
    director = json.loads(pipeline.DIRECTOR.read_text())
    selected = pipeline.clips()
    work = output / "encode-work"
    work.mkdir(parents=True, exist_ok=True)
    (output / ".gitignore").write_text("*\n")
    (output / ".gdignore").touch()
    manifest = {"clips": [], "reels": [], "failures": [], "input_hashes": pipeline.hashes(), "caption_style": director["caption_style"],
                "encoding_director_sha256": storage.file_hash(pipeline.DIRECTOR)}
    recorded = json.loads((output / "record-report.json").read_text())
    if recorded["input_hashes"] != manifest["input_hashes"]: raise ValueError("Recording inputs changed; refusing stale proof")
    rows = {}
    for clip in selected:
        item = {"clip": clip["id"], "sync_table": [], "sync_flags": [], "errors": []}
        manifest["clips"].append(item)
        destination = output / "clips" / f"{clip['id']}.mp4"
        try:
            # Validate the take before attempting an atomic replacement.
            directory, report, audited = recording.checked_take(output, clip["id"], recorded)
            item.update(sync_table=audited["sync_table"], sync_flags=audited.get("sync_flags", []),
                        validation_log=audited["validation_log"], intermediate=audited["intermediate"],
                        native_frame_offset_profile=audited["native_frame_offset_profile"],
                        timing_exemptions=audited.get("timing_exemptions", []),
                        renderer_log=audited["renderer_log"], capture_settings=audited["capture_settings"],
                        capture_wall_s=audited.get("capture_wall_s"), seconds_per_frame=audited.get("seconds_per_frame"))
            row = encode_clip(directory, report, clip, director["caption_style"], destination, work)
            item.update(row)
            item["input_hashes"] = audited["capture_hashes"]
            rows[clip["id"]] = row
        except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as exc:
            item["errors"].append(str(exc))
            manifest["failures"].append(f"{clip['id']}: {exc}")
    for reel in director["reels"]:
        destination = output / "reels" / f"{reel['id']}.mp4"
        try:
            if all(c["id"] in rows for c in reel["clips"]):
                manifest["reels"].append(encode_reel(reel, rows, destination, work))
            else:
                manifest["failures"].append(f"{reel['id']}: incomplete reel; no substitutes or omitted clips")
        except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as exc:
            manifest["failures"].append(f"{reel['id']}: {exc}")
    manifest["sync_summary"] = sync.summary(manifest["clips"])
    # Save delivery proof before removing its source media. Failed/incomplete
    # batches retain all AVIs, so they can be diagnosed and re-encoded.
    manifest["intermediate_cleanup"] = {"status": "pending", "deleted": []}
    storage.write_result(output, "manifest.json", manifest)
    try:
        manifest["intermediate_cleanup"] = release_avis(output, manifest, len(director["reels"]))
    except (OSError, ValueError, KeyError) as exc:
        manifest["intermediate_cleanup"] = {"status": "incomplete", "reason": str(exc)}
        manifest["failures"].append(str(exc))
    storage.write_result(output, "manifest.json", manifest)
    sync.print_summary(manifest["sync_summary"])
    for failure in manifest["failures"]: print("DEMO ENCODE FAILURE: " + failure, flush=True)
    print(f"DEMO ENCODE RESULT: {'FAIL' if manifest['failures'] else 'PASS'} ({len(rows)} clips, {len(manifest['reels'])} reels)")
    storage.print_size(output)
    return bool(manifest["failures"])


if __name__ == "__main__":
    raise SystemExit(main())
