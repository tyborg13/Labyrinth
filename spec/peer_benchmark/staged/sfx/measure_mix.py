"""Compare cue levels using BS.1770 window maxima at quarter-window hops."""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import numpy as np
import soundfile as sf
import pyloudnorm as pyln

DEFAULT_WINDOW_SECONDS = 0.4
HOP_WINDOW_RATIO = 0.25
SILENCE_AMPLITUDE = 1e-6
SILENT_MAX_LOUDNESS = -99.0
REFERENCES = {"ref.melee_sword(-5.5)": ("assets/audio/sfx/attack_melee_sword_first.wav", -5.5)}


def window_seconds(value) -> float:
    try:
        window = float(value)
    except (TypeError, ValueError) as error:
        raise argparse.ArgumentTypeError("window must be a positive finite number of seconds") from error
    if not math.isfinite(window) or window <= 0:
        raise argparse.ArgumentTypeError("window must be a positive finite number of seconds")
    return window


def mmax(path, window: float = DEFAULT_WINDOW_SECONDS) -> float:
    window = window_seconds(window)
    x, sr = sf.read(path, always_2d=True)
    win = int(window * sr)
    hop = int(window * HOP_WINDOW_RATIO * sr)
    if win < 1 or hop < 1:
        raise ValueError("window and quarter-window hop must each span at least one sample")
    meter = pyln.Meter(sr, block_size=window)
    if len(x) < win:
        x = np.vstack([x, np.zeros((win - len(x), x.shape[1]))])
    best = SILENT_MAX_LOUDNESS
    for start in range(0, len(x) - win + 1, hop):
        segment = x[start:start + win]
        if np.max(np.abs(segment)) < SILENCE_AMPLITUDE:
            continue
        value = meter.integrated_loudness(segment)
        if np.isfinite(value):
            best = max(best, value)
    return best


def measure_mix(root: Path, window: float = DEFAULT_WINDOW_SECONDS) -> dict:
    window = window_seconds(window)
    root = Path(root)
    with (root / "data/sfx_cues.json").open() as stream:
        document = json.load(stream)
    rows = {}
    for cue, settings in document["cues"].items():
        paths = settings.get("variants") or settings.get("fallback") or []
        if settings.get("variants_from"):
            source = document["cues"][settings["variants_from"]]
            paths = source.get("variants") or source.get("fallback") or []
        if not paths:
            continue
        values = [mmax(root / path.replace("res://", ""), window) for path in paths]
        level = float(np.mean(values))
        volume = settings.get("volume_db", 0)
        rows[cue] = {"file": round(level, 1), "volume_db": volume,
                     "eff": round(level + volume, 1), "n": len(paths),
                     "has_variants": bool(settings.get("variants"))}
    for cue, (path, volume) in REFERENCES.items():
        try:
            level = mmax(root / path, window)
            rows[cue] = {"file": round(level, 1), "volume_db": volume,
                         "eff": round(level + volume, 1)}
        except Exception as error:
            rows[cue] = {"err": str(error)}
    return rows


def main(argv=None) -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    parser.add_argument("out", type=Path)
    parser.add_argument("--window", type=window_seconds, default=DEFAULT_WINDOW_SECONDS,
                        help="BS.1770 window in seconds; hop is one quarter of the window (default: 0.4)")
    args = parser.parse_args(argv)
    rows = measure_mix(args.root, args.window)
    with args.out.open("w") as stream:
        json.dump(rows, stream, indent=1)
    for cue, values in sorted(rows.items(), key=lambda item: item[1].get("eff", 0)):
        effective = values.get("eff")
        label = f"{effective:>6}" if effective is not None else " error"
        print(f"{label} {cue:22} file={values.get('file')} vol={values.get('volume_db')}")


if __name__ == "__main__":
    main()
