#!/usr/bin/env python3
"""Record and encode the ground motion gallery on a native macOS renderer."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
from tempfile import mkdtemp

ROOT = Path(__file__).resolve().parents[2]
TOOLS = Path("tools/grd04")
TASK_ID = "grd-06"
OUTPUT = ROOT / "output" / TASK_ID / "clips"
KINDS = ("fire", "electrified", "ice", "rubble", "stormcoal")
SPEEDS = (("full", "1.0"), ("half", "0.5"))
FPS = 30
FRAMES = 4 * FPS
SIZE = (1920, 1080)
PROBE_TIMEOUT_SECONDS = 120
ENCODE_THREADS = "2"
BASE_REVISION = "9b1493a4ae2cb8e65837a7a15e718619452b7bda"


def movie_frames(raw):
    frames = []
    for path in raw.glob("movie*.png"):
        match = re.fullmatch(r"movie(\d+)\.png", path.name)
        if match:
            frames.append((int(match[1]), match[1], path))
    frames.sort()
    selected = frames[-FRAMES:]
    if len(selected) != FRAMES:
        raise ValueError(f"{raw}: need {FRAMES} MovieWriter PNGs, found {len(frames)}")
    first, digits, _ = selected[0]
    sizes = set()
    for index, (number, _, path) in enumerate(selected, first):
        if number != index:
            raise ValueError(f"{raw}: missing MovieWriter frame {index}")
        with path.open("rb") as stream:
            header = stream.read(24)
        if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
            raise ValueError(f"{path}: expected a PNG frame")
        sizes.add(struct.unpack(">II", header[16:24]))
    if len(sizes) != 1:
        raise ValueError(f"{raw}: MovieWriter frame dimensions changed: {sizes}")
    return raw / f"movie%0{len(digits)}d.png", first, sizes.pop(), len(frames) - FRAMES


def encode(raw, output):
    sequence, first, size, startup_frames = movie_frames(raw)
    if size[0] * SIZE[1] != size[1] * SIZE[0] or size[0] < SIZE[0]:
        raise ValueError(f"{raw}: expected a 1920×1080 or larger 16:9 MovieWriter backing target, got {size}")
    filters = []
    if size != SIZE:
        filters = ["-vf", f"scale={SIZE[0]}:{SIZE[1]}"]
    subprocess.run([
        "ffmpeg", "-nostdin", "-v", "error", "-threads", ENCODE_THREADS,
        "-framerate", str(FPS), "-start_number", str(first), "-i", str(sequence),
        "-frames:v", str(FRAMES), "-an", "-filter_threads", ENCODE_THREADS, *filters,
        "-c:v", "libx264", "-crf", "18", "-pix_fmt", "yuv420p", "-threads", ENCODE_THREADS,
        "-movflags", "+faststart", str(output),
    ], check=True)
    return {"source_size": list(size), "startup_frames_trimmed": startup_frames}


def capture(run, kind, label, speed, *, project=ROOT, keep_frames=False, encode_movie=True):
    name = f"{kind}-{label}"
    proof = run / name
    raw = proof / "movie_raw"
    raw.mkdir(parents=True)
    frame_args = []
    if keep_frames:
        frames = proof / "frames"
        frames.mkdir()
        frame_args = [str(frames)]
    env = dict(os.environ, LABYRINTH_CEL_LOOK="all", LABYRINTH_GROUND_FX="pixel", LABYRINTH_GRD03_FIXTURE_ATLASES="0",
               LABYRINTH_GRD04_MOVIE=str(raw / "movie.png"))
    subprocess.run([
        sys.executable, "tools/visual_probe_runner.py", str(ROOT / TOOLS / "clips.gd"),
        "--project", str(project),
        "--task-id", TASK_ID, "--no-headless", "--display-driver", "macos", "--audio-driver", "Dummy",
        "--rendering-method", "mobile", "--rendering-driver", "metal", "--godot", str(ROOT / TOOLS / "movie_godot.sh"),
        "--timeout", str(PROBE_TIMEOUT_SECONDS), "--proof-contract", str(TOOLS / "clip_contract.json"),
        "--result-manifest", str(proof / "visual-proof.json"),
        "--", kind, speed, str(proof), "--fixed-fps", str(FPS), *frame_args,
    ], cwd=ROOT, env=env, check=True)
    receipt = json.loads((proof / "capture.json").read_text())
    if (receipt["kind"], receipt["speed"], receipt["fps"], receipt["frames"], receipt["size"]) != (
            kind, float(speed), FPS, FRAMES, list(SIZE)):
        raise ValueError(f"{proof}: unexpected clip receipt {receipt}")
    if receipt["last_draw_frame"] - receipt["first_draw_frame"] != FRAMES - 1:
        raise ValueError(f"{proof}: clip draw frames were not consecutive")
    if receipt["ui_scale"] != 1.0 or receipt["electrified_pairs"] != (15 if kind == "electrified" else 0):
        raise ValueError(f"{proof}: unexpected clip scale or Electrified topology")
    if encode_movie:
        output = run / f"{name}.mp4"
        receipt.update(encode(raw, output))
        receipt["file"] = output.name
        print(f"GRD-06 CLIP: {output}", flush=True)
    receipt["visual_proof"] = f"{name}/visual-proof.json"
    shutil.rmtree(raw)
    return receipt


def compare_frames(before, after):
    from PIL import Image, ImageChops

    names = [f"frame-{index:03d}.png" for index in range(FRAMES)]
    for folder in (before, after):
        if sorted(path.name for path in folder.glob("*.png")) != names:
            raise ValueError(f"{folder}: expected exactly {FRAMES} consecutive frame PNGs")
    changed_frames = 0
    changed_pixels = 0
    for name in names:
        with Image.open(before / name) as a, Image.open(after / name) as b:
            if a.size != SIZE or b.size != SIZE:
                raise ValueError(f"{name}: expected two {SIZE} frames, got {a.size} and {b.size}")
            channels = ImageChops.difference(a.convert("RGBA"), b.convert("RGBA")).split()
            mask = channels[0]
            for channel in channels[1:]:
                mask = ImageChops.lighter(mask, channel)
            count = SIZE[0] * SIZE[1] - mask.histogram()[0]
            changed_frames += bool(count)
            changed_pixels += count
    return {"frames": len(names), "changed_frames": changed_frames, "changed_pixels": changed_pixels}


def combine(run, names):
    playlist = run / "full-speed.ffconcat"
    playlist.write_text("ffconcat version 1.0\n" + "".join(f"file '{name}'\n" for name in names))
    output = run / "all-full.mp4"
    subprocess.run([
        "ffmpeg", "-nostdin", "-v", "error", "-f", "concat", "-i", str(playlist),
        "-an", "-c:v", "copy", "-threads", ENCODE_THREADS, "-movflags", "+faststart", str(output),
    ], check=True)
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--against", type=Path, metavar="GRD05_WORKTREE",
                        help="also capture grd-05 and compare consecutive lossless board frames")
    args = parser.parse_args()
    base = args.against.resolve() if args.against else None
    if base is not None:
        revision = subprocess.check_output(["git", "-C", str(base), "rev-parse", "HEAD"], text=True).strip()
        if revision != BASE_REVISION or base == ROOT:
            parser.error(f"--against needs a separate grd-05 worktree at {BASE_REVISION}")
    if not shutil.which("ffmpeg"):
        raise SystemExit("GRD-06 CLIPS: ffmpeg is required")
    style = json.loads((ROOT / "data/ground_surface_style.json").read_text())
    if style["electrified"]["atlas"] is None:
        subprocess.run([sys.executable, "tools/grd03/make_fixture_atlases.py", "--kind", "electrified"], cwd=ROOT, check=True)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT.parent / ".gdignore").touch()
    run = Path(mkdtemp(prefix="run-", dir=OUTPUT))
    print(f"GRD-06 CLIP OUTPUT: {run}", flush=True)
    clips = []
    comparisons = {}
    for kind in KINDS:
        for label, speed in SPEEDS:
            receipt = capture(run, kind, label, speed, keep_frames=base is not None)
            clips.append(receipt)
            if base is not None:
                reference = run / "grd-05"
                capture(reference, kind, label, speed, project=base, keep_frames=True, encode_movie=False)
                name = f"{kind}-{label}"
                comparisons[name] = compare_frames(reference / name / "frames", run / name / "frames")
                print(f"GRD-06 PIXEL IDENTITY {name}: {comparisons[name]}", flush=True)
    combined = combine(run, [clip["file"] for clip in clips if clip["speed"] == 1.0])
    (run / "clips.json").write_text(json.dumps({"clips": clips, "combined": {
        "file": combined.name, "kinds": list(KINDS), "fps": FPS, "frames": len(KINDS) * FRAMES,
    }}, indent=2) + "\n")
    print(f"GRD-06 CLIPS: PASS ({len(clips)} clips and {combined.name})")
    if base is not None:
        report = run / "pixel-identity.json"
        report.write_text(json.dumps({"base_revision": BASE_REVISION, "size": SIZE, "clips": comparisons}, indent=2) + "\n")
        frames = sum(row["frames"] for row in comparisons.values())
        pixels = sum(row["changed_pixels"] for row in comparisons.values())
        print(report)
        if pixels:
            raise SystemExit(f"GRD-06 PIXEL IDENTITY: FAIL ({frames} matched frames, {pixels} changed pixels)")
        print(f"GRD-06 PIXEL IDENTITY: PASS ({frames} matched frames, 0 changed pixels)")


if __name__ == "__main__":
    main()
