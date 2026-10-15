"""Idempotent lossless SFX sync rebuild from compact per-path provenance."""
from __future__ import annotations

import argparse
from pathlib import Path
import sys

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

import numpy as np

from tools.sfx_lab.common import LabError, cli, fade_in

# All audible values below come from the sfx-04 director brief. Retaining a
# 2 ms lead lets the mandated fade finish before the measured transient.
from tools.sfx_lab.sync_metrics import RULES
THRESHOLD_DBFS = RULES["first_sample_threshold_dbfs"]
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


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--manifest", type=Path, default=Path("spec/assets/sfx/manifest.json"))
    parser.add_argument("--features", type=Path, default=Path(".godot/sfx_lab/features.jsonl"))
    parser.add_argument("--sources", type=Path, help="Relocate the approved lossless source library")
    parser.add_argument("--provenance", type=Path, default=Path("assets/audio/sfx/sfx-04-provenance.json"))
    args = parser.parse_args()
    from tools.sfx_lab.sync_align import rebuild_aligned
    root = args.root.resolve()
    rebuild_aligned(root, root / args.manifest, root / args.features, root / args.provenance, args.sources)


if __name__ == "__main__":
    cli(main)
