"""Rebuild sfx-04 onset trims from the existing build provenance, without remixing."""
from __future__ import annotations

import argparse
import copy
from pathlib import Path
import sys
import tempfile

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

import numpy as np

from tools.sfx_lab.build import process
from tools.sfx_lab.common import (LabError, TakeLibrary, cli, decode, encode, fade_in,
                                  loudness, read_json, sha256, write_json)

# All audible values below come from the sfx-04 director brief. Retaining a
# 2 ms lead lets the mandated fade finish before the measured transient.
THRESHOLD_DBFS = -45.0
REBUILD_ABOVE_MS = 10.0
MAX_LEAD_MS = 5.0
FADE_IN_MS = 2.0


def onset_sample(samples: np.ndarray) -> int:
    above = np.flatnonzero(np.max(np.abs(samples), axis=1) > 10 ** (THRESHOLD_DBFS / 20))
    if not len(above):
        raise LabError("No sample exceeds the sfx-04 onset threshold (-45 dBFS)")
    return int(above[0])


def leading_ms(samples: np.ndarray, rate: int) -> float:
    return onset_sample(samples) * 1000 / rate


def trim_onset(samples: np.ndarray, rate: int) -> tuple[np.ndarray, dict]:
    first = onset_sample(samples)
    removed = max(0, first - round(FADE_IN_MS * rate / 1000))
    result = fade_in(samples[removed:].copy(), rate, FADE_IN_MS)
    if leading_ms(result, rate) > MAX_LEAD_MS:
        raise LabError("The prescribed trim/fade did not meet the 5 ms onset bound")
    return result, {"task": "sfx-04", "threshold_dbfs": THRESHOLD_DBFS,
                    "removed_samples": removed, "removed_ms": removed * 1000 / rate,
                    "fade_in_ms": FADE_IN_MS, "fade_in_curve": "linear",
                    "float_leading_ms": leading_ms(result, rate)}


def variant_from_provenance(entry: dict) -> dict:
    parameters = entry["processing"]
    variant = {"take": entry["take_id"], "source_path": entry["source_path"],
               "trim": parameters["trim"], "pitch": parameters["pitch"],
               "fade_out_ms": parameters["fade_out_ms"],
               "gain_db": parameters.get("gain_db", 0)}
    if parameters.get("lowpass_hz") is not None:
        variant["lowpass_hz"] = parameters["lowpass_hz"]
    if "limiter" in parameters:
        variant["limiter"] = {key: parameters["limiter"][key] for key in
                              ("input_gain_db", "ceiling_dbfs", "lookahead_ms", "release_ms")}
    return variant


def rebuild(root: Path, manifest: Path, features: Path, provenance: Path) -> dict:
    original = read_json(manifest)
    library = TakeLibrary(features)
    prior = read_json(provenance) if provenance.exists() else {"outputs": []}
    outputs = {entry["path"]: entry for entry in prior["outputs"]}
    changed = []
    for entry in original["outputs"]:
        path = root / "assets/audio/sfx/cues" / entry["path"]
        shipped, shipped_rate = decode(path)
        before_ms = leading_ms(shipped, shipped_rate)
        if before_ms <= REBUILD_ABOVE_MS:
            continue
        if sha256(path) != entry["output_sha256"]:
            raise LabError(f"Unrecognized audio revision; refusing to overwrite {path}")
        variant = variant_from_provenance(entry)
        row = library.get(variant)
        samples, rate, parameters = process(library, row, variant, entry["category"], entry["loop"], {})
        # Reconstruct from the lossless source, not from a lossy decoded Ogg.
        # Refuse a different build recipe/toolchain instead of silently changing
        # normalization, channel policy, EQ, pitch, or any sfx-03 gain.
        for key, value in parameters.items():
            if entry["processing"].get(key) != value:
                raise LabError(f"Original build parameter changed: {entry['cue_id']} {key}")
        correction = float(entry["processing"]["encoder_gain_correction_db"])
        samples = samples * 10 ** (correction / 20)
        trimmed, timing = trim_onset(samples, rate)
        with tempfile.TemporaryDirectory(prefix="sfx-04-build-", dir=path.parent) as temporary:
            rebuilt = Path(temporary) / path.name
            encode(rebuilt, trimmed, rate, "ogg")
            actual, actual_rate = decode(rebuilt)
            after_ms = leading_ms(actual, actual_rate)
            if after_ms > MAX_LEAD_MS or np.max(np.abs(actual)) >= 1:
                raise LabError(f"Encoded trim failed onset/clipping verification: {path}")
            output = copy.deepcopy(entry)
            output["parent_output_sha256"] = entry["output_sha256"]
            output["output_sha256"] = sha256(rebuilt)
            output["processing"]["sfx_04"] = {**timing, "before_encoded_leading_ms": before_ms,
                                                "after_encoded_leading_ms": after_ms,
                                                "stage": "after_original_processing_and_encoder_gain"}
            output["processing"]["output_duration"] = len(actual) / actual_rate
            output["processing"]["output_lufs"], output["processing"]["output_loudness_method"] = loudness(actual, actual_rate)
            output["processing"]["output_peak_dbfs"] = float(20 * np.log10(np.max(np.abs(actual))))
            rebuilt.replace(path)
        outputs[entry["path"]] = output
        changed.append(entry["path"])
        print(f"SFX04 TRIM {entry['path']}: {before_ms:.3f} ms -> {after_ms:.3f} ms")
    result = {"schema_version": 1, "task": "sfx-04", "parent_manifest": str(manifest.relative_to(root)),
              "parent_manifest_sha256": sha256(manifest),
              "note": "Timing-only provenance overlay; director-owned source manifest and mix parameters are unchanged.",
              "outputs": [outputs[key] for key in sorted(outputs)]}
    write_json(provenance, result)
    print(f"SFX04 BUILD RESULT: PASS ({len(changed)} rebuilt; {len(outputs)} provenance records)")
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--manifest", type=Path, default=Path("spec/assets/sfx/manifest.json"))
    parser.add_argument("--features", type=Path, required=True)
    parser.add_argument("--provenance", type=Path, default=Path("assets/audio/sfx/sfx-04-provenance.json"))
    parser.add_argument("--align-audit", type=Path, help="Apply feedback-1 peak/onset constraints from the retained pre-feedback audit")
    args = parser.parse_args()
    root = args.root.resolve()
    if args.align_audit:
        from tools.sfx_lab.sync_align import rebuild_aligned
        rebuild_aligned(root, root / args.manifest, args.features, root / args.provenance, root / args.align_audit)
    else:
        rebuild(root, root / args.manifest, args.features, root / args.provenance)


if __name__ == "__main__":
    cli(main)
