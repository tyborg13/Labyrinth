#!/usr/bin/env python3
"""Trim the four approved release assets in place and refresh their metadata."""

import hashlib
import json
import math
from pathlib import Path
import stat
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets/audio/sfx"
MANIFEST = ROOT / "spec/assets/sfx/manifest.json"
PINS = ROOT / "tests/approved_asset_pins.json"
sys.path.insert(0, str(ROOT / "tools/sfx_lab"))
from common import encode, np, sf  # Existing sound-lab encoder and dependencies.

RMS_INTERVAL_SECONDS = 0.1
TARGETS = (
    ("cues/spell.lightning/spell.lightning_01.ogg", "spell.lightning", 0.40, 0.15,
     "9618f341aa99c43aa9ec78ccc07eaea6298203c0"),
    ("elemental/lightning_attack.wav", "spell.lightning", 0.40, 0.15,
     "f49d566a0c1590b9fc986500209f5295aa6289bc"),
    ("cues/status.shock/status.shock_01.ogg", "status.shock", 0.22, 0.10,
     "aa2e521803c3295a3b73aeb05a6e9cba997ee098"),
    ("cues/surface.electric/surface.electric_01.ogg", "surface.electric", 0.28, 0.12,
     "b75eeeb7f92a7d89703d97dc6bf938547806d400"),
)


def probe(path):
    result = subprocess.check_output([
        "ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries",
        "stream=codec_name,sample_rate,channels,duration", "-of", "json", str(path),
    ])
    stream, = json.loads(result)["streams"]
    return stream["codec_name"], int(stream["sample_rate"]), stream["channels"], float(stream["duration"])


def envelope(path, rate, sample_count):
    pcm, _ = sf.read(path, dtype="float32", always_2d=True)
    if len(pcm) != sample_count:
        raise ValueError(f"Decoded PCM length differs from the specified duration: {path}")
    step = round(rate * RMS_INTERVAL_SECONDS)
    values = []
    for start in range(0, sample_count, step):
        chunk = pcm[start:start + step]
        mean_square = float(np.mean(np.square(chunk, dtype=np.float64)))
        values.append(f"{10 * math.log10(mean_square):.1f}" if mean_square else "-inf")
    return ", ".join(values)


def blob_hash(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def write_json(path, data):
    serialized = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    if path.read_text() != serialized:
        path.write_text(serialized)


def main():
    manifest = json.loads(MANIFEST.read_text())
    pins = json.loads(PINS.read_text())
    variants = {row["path"]: row for row in manifest["outputs"]}
    fallbacks = manifest.setdefault("fallback_outputs", {})
    results = []
    with tempfile.TemporaryDirectory(prefix="sfx-06-", dir=Path(__file__).resolve().parent) as temporary:
        staging = Path(temporary)
        for path, cue, keep, fade, source_blob in TARGETS:
            asset = ASSETS / path
            relative = asset.relative_to(ROOT).as_posix()
            is_vorbis = asset.suffix == ".ogg"
            row = variants[path.removeprefix("cues/")] if is_vorbis else fallbacks.setdefault(relative, {
                "cue_id": cue, "loop": False,
            })
            current = asset.read_bytes()
            current_sha = hashlib.sha256(current).hexdigest()
            postprocess = row.get("release_trim", {})
            source = staging / ("source-" + asset.name)
            if blob_hash(current) == source_blob:
                source.write_bytes(current)
            elif postprocess.get("input_git_blob") == source_blob and current_sha == row["output_sha256"]:
                source.write_bytes(subprocess.check_output(["git", "cat-file", "blob", source_blob], cwd=ROOT))
            else:
                raise ValueError(f"Unexpected source bytes: {relative}")

            codec, rate, channels, before = probe(source)
            keep_samples = round(keep * rate)
            fade_samples = round(fade * rate)
            total_samples = keep_samples + fade_samples
            total_seconds = total_samples / rate
            pcm, _ = sf.read(source, frames=total_samples, dtype="float32", always_2d=True)
            if len(pcm) != total_samples:
                raise ValueError(f"Approved input is too short: {relative}")
            pcm[keep_samples:] *= np.linspace(1.0, 0.0, fade_samples, dtype=np.float32)[:, None]
            trimmed = staging / asset.name
            if is_vorbis:
                encode(trimmed, pcm, rate, "ogg")
            else:
                sf.write(trimmed, pcm, rate, subtype=sf.info(source).subtype)
            if probe(trimmed) != (codec, rate, channels, total_seconds):
                raise ValueError(f"Unexpected format or duration: {relative}")
            print(f"{asset.name}: {before:.3f} s -> {total_seconds:.3f} s; "
                  f"RMS dBFS: {envelope(trimmed, rate, total_samples)}")

            payload = trimmed.read_bytes()
            row["output_sha256"] = hashlib.sha256(payload).hexdigest()
            # Retain the upstream mastering recipe as provenance. release_trim
            # describes the shipped release asset that this recipe postprocesses.
            row["release_trim"] = {
                "input_git_blob": source_blob,
                "input_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                "input_duration": before,
                "output_duration": total_seconds,
                "sample_rate": rate,
                "channels": channels,
                "codec": codec,
                "keep_seconds": keep,
                "fade_out_seconds": fade,
                "fade_curve": "linear",
            }
            if is_vorbis:
                row["processing"]["output_duration"] = total_seconds
            pins["files"][relative] = blob_hash(payload)
            if payload != current:
                trimmed.chmod(stat.S_IMODE(asset.stat().st_mode))
                results.append((trimmed, asset))

        for trimmed, asset in results:
            trimmed.replace(asset)
        write_json(MANIFEST, manifest)
        write_json(PINS, pins)


if __name__ == "__main__":
    main()
