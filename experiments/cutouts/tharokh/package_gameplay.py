"""Retain native gameplay keyframes and a timed, fully decoded review reel.

Run after the real-renderer probe passes. Frame durations come from its actual
wall-clock samples. Encoding only repeats/drops captured frames at 60fps; it
does not interpolate poses. Original frame digests remain in the package.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile


def run(arguments: list[str]) -> None:
    subprocess.run(arguments, check=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runner", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = json.loads(args.runner.read_text())
    assert result["ok"], "Only passing native captures may be packaged"
    source = next(Path(i["path"]).parent for i in result["images"] if Path(i["path"]).name == "idle_southwest.png")
    manifest = json.loads((source / "manifest.json").read_text())
    assert manifest["ok"] and not manifest["errors"]
    assert not args.output.exists(), "Choose a fresh proof output"
    args.output.mkdir(parents=True)
    for path in list(source.glob("*.png")) + [source / "manifest.json"]:
        shutil.copy2(path, args.output / path.name)
    shutil.copy2(args.runner, args.output / "capture_runner.json")
    timeline = {"timing": "Actual native capture timestamps; 60fps frame repetition, no synthesized poses", "clips": []}
    source_hashes: dict[str, str] = {}
    with tempfile.TemporaryDirectory(prefix="tharokh-gameplay-encode-") as scratch:
        scratch = Path(scratch)
        chapter_start = 0.0
        for clip_index, clip in enumerate(manifest["clips"]):
            frames = sorted((source / clip["label"]).glob("frame_*.jpg"))
            samples = clip["samples"]
            assert len(frames) == len(samples) and len(frames) > 1
            durations = [b["seconds"] - a["seconds"] for a, b in zip(samples, samples[1:])]
            durations.append(durations[-1])
            assert all(d > 0 for d in durations)
            seconds = sum(durations)
            lines = ["ffconcat version 1.0"]
            for path, duration in zip(frames, durations):
                source_hashes[str(path.relative_to(source))] = hashlib.sha256(path.read_bytes()).hexdigest()
                lines += ["file '" + str(path).replace("'", "'\\''") + "'", "option framerate 1000000", f"duration {duration:.6f}"]
            lines += ["file '" + str(frames[-1]).replace("'", "'\\''") + "'", "option framerate 1000000"]
            concat = scratch / f"{clip_index:02d}.ffconcat"
            concat.write_text("\n".join(lines) + "\n")
            video = scratch / f"{clip_index:02d}.mp4"
            run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(concat), "-t", f"{seconds:.6f}", "-an", "-vf", "fps=60", "-c:v", "libx264", "-preset", "fast", "-crf", "18", "-pix_fmt", "yuv420p", str(video)])
            metadata = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-count_frames", "-select_streams", "v:0", "-show_entries", "stream=nb_read_frames,width,height", "-of", "json", str(video)], text=True))["streams"][0]
            encoded = int(metadata["nb_read_frames"]) / 60.0
            assert (metadata["width"], metadata["height"]) == (1920, 1080)
            assert abs(encoded - seconds) <= 1 / 60 + 0.000001
            timeline["clips"].append({"label": clip["label"], "reel_start_seconds": chapter_start, "source_frames": len(frames), "source_seconds": seconds, "encoded_seconds": encoded, "duration_error_seconds": encoded - seconds, "durations": durations})
            chapter_start += encoded
        concat = scratch / "reel.ffconcat"
        concat.write_text("ffconcat version 1.0\n" + "".join(f"file '{index:02d}.mp4'\n" for index in range(len(timeline["clips"]))))
        reel = args.output / "tharokh_gameplay_full_speed.mp4"
        run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(concat), "-c", "copy", "-movflags", "+faststart", str(reel)])
        run(["ffmpeg", "-v", "error", "-i", str(reel), "-f", "null", "-"])
        timeline["encoded_seconds"] = chapter_start
        timeline["full_decode"] = "PASS"
    (args.output / "video_timeline.json").write_text(json.dumps(timeline, indent=2) + "\n")
    (args.output / "source_frames_sha256.json").write_text(json.dumps(source_hashes, indent=2) + "\n")
    print(json.dumps({"ok": True, "clips": len(timeline["clips"]), "native_source_frames": len(source_hashes), "encoded_seconds": timeline["encoded_seconds"], "reel": str(reel)}, indent=2))


if __name__ == "__main__":
    main()
