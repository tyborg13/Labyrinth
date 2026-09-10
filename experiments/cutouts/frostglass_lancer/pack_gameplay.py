"""Package native RunScene samples at their recorded wall-clock timing."""
import argparse
from fractions import Fraction
import hashlib
import json
from pathlib import Path
import statistics
import subprocess


def read(path):
    return json.loads(path.read_text())


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("capture", type=Path)
args = parser.parse_args()
root = args.capture.resolve()
manifest = read(root / "manifest.json")
if not manifest.get("ok") or manifest.get("errors"):
    raise SystemExit("Require a passing native RunScene capture")
videos = root / "videos"
videos.mkdir(exist_ok=False)
records = []
for clip in manifest["clips"]:
    frames = sorted((root / clip["label"]).glob("frame_*.jpg"))
    samples = clip["samples"]
    if len(frames) != len(samples) or len(frames) < 2:
        raise SystemExit("Native frames and samples disagree: " + clip["label"])
    gaps = [b["seconds"] - a["seconds"] for a, b in zip(samples, samples[1:])]
    if min(gaps) <= 0:
        raise SystemExit("Native sample timestamps must increase")
    durations = gaps + [statistics.median(gaps)]
    source_seconds = sum(durations)
    concat = videos / (clip["label"] + ".ffconcat")
    lines = ["ffconcat version 1.0"]
    for frame, duration in zip(frames, durations):
        lines += ["file '../" + str(frame.relative_to(root)) + "'", "duration %.9f" % duration]
    lines.append("file '../" + str(frames[-1].relative_to(root)) + "'")
    concat.write_text("\n".join(lines) + "\n")
    video = videos / (clip["label"] + ".mp4")
    subprocess.run([
        "ffmpeg", "-v", "error", "-f", "concat", "-safe", "0", "-i", str(concat),
        "-t", str(source_seconds), "-an", "-vf", "fps=60", "-c:v", "libx264",
        "-preset", "fast", "-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(video)
    ], check=True)
    metadata = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-select_streams", "v:0", "-count_frames",
        "-show_entries", "stream=nb_read_frames,avg_frame_rate,width,height", "-of", "json", str(video)
    ], text=True))["streams"][0]
    seconds = int(metadata["nb_read_frames"]) / float(Fraction(metadata["avg_frame_rate"]))
    if abs(seconds - source_seconds) > 1 / 60 + 0.000001 or [metadata["width"], metadata["height"]] != [1920, 1080]:
        raise SystemExit("Encoded timing or dimensions changed: " + clip["label"])
    records.append({"file": str(video.relative_to(root)), "source_frames": len(frames),
                    "source_seconds": source_seconds, "encoded_seconds": seconds,
                    "duration_error_seconds": seconds - source_seconds})
concat = videos / "clips.ffconcat"
concat.write_text("ffconcat version 1.0\n" + "".join("file '" + Path(c["file"]).name + "'\n" for c in records))
reel = videos / "frostglass_gameplay.mp4"
subprocess.run(["ffmpeg", "-v", "error", "-f", "concat", "-safe", "0", "-i", str(concat),
                "-c", "copy", "-movflags", "+faststart", str(reel)], check=True)
subprocess.run(["ffmpeg", "-v", "error", "-i", str(reel), "-f", "null", "-"], check=True)
write(videos / "encoding.json", {"clips": records, "reel": str(reel.relative_to(root)),
      "manifest_sha256": digest(root / "manifest.json"), "full_decode": "PASS",
      "timing": "Measured native sample intervals, final median interval held; 60fps repetition without synthesized poses or speed-up"})
write(root / "output_sha256.json", {str(p.relative_to(root)): digest(p) for p in sorted(root.rglob("*"))
                                    if p.is_file() and p.name != "output_sha256.json"})
print(json.dumps({"ok": True, "reel": str(reel), "clips": len(records)}, indent=2))
