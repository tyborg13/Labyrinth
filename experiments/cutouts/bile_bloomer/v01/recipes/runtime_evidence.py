"""Bind, retain and encode this actor's actual native proof without retiming it."""
from pathlib import Path
import argparse
from datetime import datetime, timezone
from fractions import Fraction
import hashlib
import json
import shutil
import statistics
import subprocess
import sys

CASE = Path(__file__).resolve().parents[1]
REPO = CASE.parents[3]
sys.path.insert(0, str(REPO / "tools"))
from cutout_pipeline.proof import input_hashes


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inputs():
    hashes = input_hashes(CASE)
    extra = [REPO / "export_presets.cfg", *REPO.glob("tests/bile_bloomer_*.gd"), REPO / "tests/suites/bile_bloomer_cutout_suite.gd", REPO / "tests/fixtures/bile_bloomer_cutout_export_smoke.gd"]
    extra += list((REPO / "assets").rglob("*.import"))
    for path in extra:
        hashes["project:" + str(path.relative_to(REPO))] = sha(path)
    return hashes


def collect(result_file, output):
    result = json.loads(result_file.read_text())
    if not result.get("ok"):
        raise RuntimeError("Only an accepted native runner result may be retained")
    candidates = set()
    for item in result["images"]:
        parent = Path(item["path"]).parent
        for folder in [parent, parent.parent]:
            if (folder / "manifest.json").exists() or (folder / "comparison.json").exists():
                candidates.add(folder)
    if len(candidates) != 1 or output.exists():
        raise RuntimeError("Expected one raw proof root and a fresh output directory")
    raw = candidates.pop()
    shutil.copytree(raw, output)
    for item in result["images"]:
        item["path"] = str(Path(item["path"]).relative_to(raw))
    for attempt in result["attempts"]:
        for item in attempt.get("images", []):
            item["path"] = str(Path(item["path"]).relative_to(raw))
    write(output / "native_runner.json", result)
    print(json.dumps({"output": str(output), "native_images": len(result["images"])}))


def pack(gameplay):
    manifest = json.loads((gameplay / "manifest.json").read_text())
    if not manifest.get("ok") or manifest.get("errors"):
        raise RuntimeError("Cannot encode failed gameplay proof")
    videos = gameplay / "videos"
    videos.mkdir(exist_ok=False)
    timeline = []
    for clip in manifest["clips"]:
        samples = clip["samples"]
        intervals = [float(b["seconds"]) - float(a["seconds"]) for a, b in zip(samples, samples[1:])]
        if not samples or any(delta <= 0 for delta in intervals):
            raise RuntimeError("Missing or nonmonotonic actual samples")
        # Only the final held image needs an inferred display interval. Every
        # transition before it uses its actual monotonic capture timestamps.
        tail = statistics.median(intervals[-10:]) if intervals else 1 / 30
        durations = intervals + [tail]
        source_seconds = sum(durations)
        frames = max(1, round(source_seconds * 60))
        label = clip["label"]
        concat = videos / (label + ".ffconcat")
        records = ["ffconcat version 1.0"]
        for index, duration in enumerate(durations):
            path = (gameplay / label / ("frame_%04d.jpg" % index)).resolve()
            records.extend(["file '" + str(path).replace("'", "'\\''") + "'", "duration %.9f" % duration])
        records.append("file '" + str(path).replace("'", "'\\''") + "'")
        concat.write_text("\n".join(records) + "\n")
        video = videos / (label + ".mp4")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(concat), "-an", "-vf", "fps=60", "-frames:v", str(frames), "-c:v", "libx264", "-threads", "2", "-preset", "fast", "-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(video)], check=True)
        metadata = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-select_streams", "v:0", "-count_frames", "-show_entries", "stream=nb_read_frames,avg_frame_rate,width,height", "-of", "json", str(video)], text=True))["streams"][0]
        actual_frames = int(metadata["nb_read_frames"])
        seconds = actual_frames / float(Fraction(metadata["avg_frame_rate"]))
        if actual_frames != frames or abs(seconds - source_seconds) > 1 / 60 + 0.000001 or (metadata["width"], metadata["height"]) != (1920, 1080):
            raise RuntimeError("Encoded gameplay timing/resolution differs")
        timeline.append({"label": label, "source_samples": len(samples), "capture_start_seconds": samples[0]["seconds"], "source_durations": durations, "final_held_interval_seconds": tail, "source_seconds": source_seconds, "encoded_frames": actual_frames, "encoded_seconds": seconds, "duration_error_seconds": seconds - source_seconds})
    concat = videos / "reel.ffconcat"
    concat.write_text("ffconcat version 1.0\n" + "".join("file '" + clip["label"] + ".mp4'\n" for clip in timeline))
    reel = gameplay / "bile_bloomer_gameplay_full_speed.mp4"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(concat), "-c", "copy", "-movflags", "+faststart", str(reel)], check=True)
    subprocess.run(["ffmpeg", "-v", "error", "-i", str(reel), "-f", "null", "-"], check=True)
    write(gameplay / "video_timeline.json", {"timing": "Actual wall-clock sample intervals; 60fps repetition only, no synthesized poses. Last image held for the median of the last ten observed intervals. Each clip rounds by at most one output frame.", "clips": timeline, "source_seconds": sum(c["source_seconds"] for c in timeline), "encoded_seconds": sum(c["encoded_seconds"] for c in timeline), "full_decode": "PASS"})
    print(json.dumps({"reel": str(reel), "clips": len(timeline), "seconds": sum(c["encoded_seconds"] for c in timeline)}))


parser = argparse.ArgumentParser()
parser.add_argument("command", choices=["snapshot", "verify-inputs", "collect", "pack", "hash-outputs"])
parser.add_argument("path", type=Path)
parser.add_argument("--output", type=Path)
args = parser.parse_args()
if args.command == "snapshot":
    write(args.path, {"captured_at_utc": datetime.now(timezone.utc).isoformat(), "hashes": inputs()})
elif args.command == "verify-inputs":
    expected = json.loads(args.path.read_text())["hashes"]
    current = inputs()
    changed = [key for key in expected.keys() | current.keys() if expected.get(key) != current.get(key)]
    print(json.dumps({"ok": not changed, "inputs": len(current), "changed": changed}, indent=2))
    sys.exit(bool(changed))
elif args.command == "collect":
    collect(args.path, args.output)
elif args.command == "pack":
    pack(args.path)
else:
    write(args.path / "proof_sha256.json", {str(p.relative_to(args.path)): sha(p) for p in sorted(args.path.rglob("*")) if p.is_file() and p.name != "proof_sha256.json"})
