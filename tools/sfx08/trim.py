#!/usr/bin/env python3
"""Apply the five approved trims. Run as python -m tools.sfx08.trim."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import stat
import subprocess
import tempfile

from tools.qa111.measure import describe_signal
from tools.sfx06.trim import ASSETS, MANIFEST, PINS, ROOT, blob_hash, probe
from tools.sfx_lab.common import decode, encode, np, sf
from tools.sfx_sync_audit import BASELINE, rounded, sample_measurements

CUES = ROOT / "data/sfx_cues.json"
REPEATS = 3
GAP_SECONDS = 0.6
PROOF_WAV_SUBTYPE = "PCM_24"
TARGETS = (
    # Cue, full-level seconds, linear fade seconds, before/after cue gain, source blob.
    ("illusion.break", 0.30, 0.12, -1.0, -3.0, "22464dccaad175f3ae1da4a84228d16c20d25e68"),
    ("spell.shadow", 0.70, 0.20, -3.0, -6.0, "d882964a17db5044f5a9b7741633562c4e4b7f36"),
    ("illusion.spawn", 0.70, 0.25, -4.2, -4.2, "6f30d19530d0664fb506f61299ed7fee6c39743f"),
    ("dragon.roar", 1.30, 0.30, 3.3, -1.7, "a9596fbce85a7d6d3fd300828f642fbbe3b11ec7"),
    ("omen.bane", 0.80, 0.25, -5.6, -11.6, "a3b0a4c5197012e0f1e64bb177217a3e6f441bd0"),
)


def replace_row(document, key, update):
    pattern = re.compile(r"(?m)^(    " + re.escape(json.dumps(key)) + r":\s*)(\{[^\n]+\})(,?)$")
    document, count = pattern.subn(lambda match: match[1] + update(match[2]) + match[3], document)
    if count != 1:
        raise ValueError(f"Expected exactly one row for {key}")
    return document


def with_gain(row, before, after):
    observed = json.loads(row)["volume_db"]
    if observed not in (before, after):
        raise ValueError(f"Unexpected cue gain {observed}, expected {before} or {after}")
    if observed == after:
        return row
    return re.sub(r'("volume_db":\s*)-?\d+(?:\.\d+)?',
                  lambda match: match[1] + str(after), row, count=1)


def original_bytes(current, source_blob):
    if blob_hash(current) == source_blob:
        return current
    return subprocess.check_output(["git", "cat-file", "blob", source_blob], cwd=ROOT)


def verify_existing(current, original, trimmed, manifest_row, source_blob):
    # Accept an exact staged encode if a previous run stopped before updating metadata.
    if current in (original, trimmed):
        return
    if (manifest_row.get("release_trim", {}).get("input_git_blob") != source_blob
            or hashlib.sha256(current).hexdigest() != manifest_row["output_sha256"]):
        raise ValueError(f"Unexpected source bytes: {manifest_row['path']}")


def trim(source, output, keep, fade):
    codec, rate, channels, before = probe(source)
    keep_samples, fade_samples = round(keep * rate), round(fade * rate)
    total_samples = keep_samples + fade_samples
    total_seconds = total_samples / rate
    pcm, _ = sf.read(source, frames=total_samples, dtype="float32", always_2d=True)
    if len(pcm) != total_samples:
        raise ValueError(f"Approved source is too short: {source.name}")
    pcm[keep_samples:] *= np.linspace(1, 0, fade_samples, dtype=np.float32)[:, None]
    encode(output, pcm, rate, "ogg")
    if probe(output) != (codec, rate, channels, total_seconds) or sf.info(output).frames != total_samples:
        raise ValueError(f"Unexpected format or duration: {output.name}")
    return {
        "input_duration": before, "output_duration": total_seconds, "sample_rate": rate,
        "channels": channels, "codec": codec, "keep_seconds": keep, "fade_out_seconds": fade,
        "fade_curve": "linear",
    }


def proof_sample(cue, phase, path, gain, proof_dir):
    samples, rate = decode(path)
    metrics = describe_signal(samples, rate)
    rendered = samples * 10 ** (gain / 20)
    gap = np.zeros((round(GAP_SECONDS * rate), samples.shape[1]))
    repeated = np.concatenate([part for _ in range(REPEATS - 1) for part in (rendered, gap)] + [rendered])
    sf.write(proof_dir / f"{cue}_{phase}.wav", repeated, rate, subtype=PROOF_WAV_SUBTYPE)
    end = "†" if metrics["to_eof"] else ""
    return (f'{metrics["duration"]:.3f} | {metrics["decay"]:.3f}{end} | '
            f'{metrics["sustain"]:.1%} | {metrics["lufs_s"] + gain:.1f} | {metrics["hf"]:.1%}')


def sync_row(row, asset, staged):
    # Measure only this staged asset with the audit's normal decoder and meter.
    measured, = sample_measurements(staged.parent, {"cue": {"variants": [staged.name]}}).values()
    entry = json.loads(row)
    entry.update({field: measured[field] for field in entry.keys() & measured.keys()})
    print(f'{asset.name}: {entry["duration_seconds"]:.3f} s, '
          f'{entry["sample_rate"]} Hz, peak at {entry["peak_ms"]:.3f} ms')
    return json.dumps(rounded(entry), sort_keys=True, ensure_ascii=False, separators=(",", ":"))


def write_changed(path, content):
    if path.read_text() != content:
        with tempfile.TemporaryDirectory(prefix="trim-", dir=path.parent) as temporary:
            staged = Path(temporary) / path.name
            staged.write_text(content)
            staged.chmod(stat.S_IMODE(path.stat().st_mode))
            staged.replace(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--proof-dir", type=Path, help="Also write the QA-111 table and ten A/B WAVs")
    proof_dir = parser.parse_args().proof_dir
    if proof_dir is not None:
        proof_dir.mkdir(parents=True, exist_ok=True)

    manifest = json.loads(MANIFEST.read_text())
    pins = json.loads(PINS.read_text())
    cue_text = CUES.read_text()
    snapshot = ROOT / BASELINE
    snapshot_text = snapshot.read_text()
    variants = {row["path"]: row for row in manifest["outputs"]}
    table = [
        "| Cue | Version | Duration (s) | Last −20 (s) | Sustain | LUFS-S | HF >4 kHz |",
        "| --- | --- | ---: | ---: | ---: | ---: | ---: |",
    ]
    with tempfile.TemporaryDirectory(prefix="trim-", dir=Path(__file__).resolve().parent) as temporary:
        staged_assets = []
        for cue, keep, fade, before, after, source_blob in TARGETS:
            name = f"{cue}_01.ogg"
            asset = ASSETS / "cues" / cue / name
            relative = asset.relative_to(ROOT).as_posix()
            row = variants[f"{cue}/{name}"]
            current = asset.read_bytes()
            original = original_bytes(current, source_blob)
            source, output = Path(temporary) / ("source-" + name), Path(temporary) / name
            source.write_bytes(original)
            details = trim(source, output, keep, fade)

            payload = output.read_bytes()
            verify_existing(current, original, payload, row, source_blob)
            row["output_sha256"] = hashlib.sha256(payload).hexdigest()
            row["processing"]["output_duration"] = details["output_duration"]
            row["release_trim"] = {
                "input_git_blob": source_blob, "input_sha256": hashlib.sha256(original).hexdigest(),
                **details,
            }
            pins["files"][relative] = blob_hash(payload)
            cue_text = replace_row(cue_text, cue, lambda text: with_gain(text, before, after))
            snapshot_text = replace_row(snapshot_text, "res://" + relative,
                                        lambda text: sync_row(text, asset, output))
            if payload != current:
                output.chmod(stat.S_IMODE(asset.stat().st_mode))
                staged_assets.append((output, asset))
            if proof_dir is not None:
                for phase, path, gain in (("before", source, before), ("after", output, after)):
                    metrics = proof_sample(cue, phase, path, gain, proof_dir)
                    table.append(f"| {cue} | {phase} | {metrics} |")

        for output, asset in staged_assets:
            output.replace(asset)
        write_changed(MANIFEST, json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
        write_changed(PINS, json.dumps(pins, indent=2, ensure_ascii=False) + "\n")
        write_changed(CUES, cue_text)
        write_changed(snapshot, snapshot_text)
    if proof_dir is not None:
        table.append("\nLast −20 is measured from the strongest RMS peak. † marks EOF.")
        (proof_dir / "measurements.md").write_text("\n".join(table) + "\n")


if __name__ == "__main__":
    main()
