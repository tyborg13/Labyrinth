"""Measure registry-resolved cue files and the four approved electric comparisons."""

from collections import defaultdict
from functools import lru_cache
from io import BytesIO
from pathlib import Path
import json

import numpy as np
import pyloudnorm as pyln
from scipy.signal import welch
import soundfile as sf

from tools.sfx_lab.common import decode
from tools.sfx_lab.features import SPECTRAL_WINDOW_SAMPLES
from tools.sfx_lab.sync_metrics import envelope, peak_levels
from tools.sfx_sync_audit import cue_samples, ffmpeg_true_peak, git_file

ROOT = Path(__file__).resolve().parents[2]
ELECTRIC_FIX = "89e9d5d1f"
ELECTRIC = {"spell.lightning", "status.shock", "surface.electric"}
SUSTAIN_START = 0.150
SUSTAIN_LEVEL_DB = -6
SUSTAIN_SHARE = 0.40
DECAY_LEVEL_DB = -20
LONG_IMPACT_SECONDS = 0.60
BUS_MARGIN_LU = 3
HIGH_HZ = 4000
HIGH_PERCENTILE = 90
SHORT_TERM_SECONDS = 3
LOUDNESS_HOP_SECONDS = 0.100


@lru_cache(maxsize=None)
def pcm(path):
    return decode(ROOT / path.removeprefix("res://"))


def short_term_peak(samples, rate):
    """Ungated BS.1770 K-weighted three-second window peak (LUFS-S)."""
    window = round(SHORT_TERM_SECONDS * rate)
    if len(samples) < window:
        samples = np.pad(samples, ((0, window - len(samples)), (0, 0)))
    meter = pyln.Meter(rate)
    power = np.zeros(len(samples))
    for channel, data in enumerate(samples.T):
        for weighting in meter._filters.values():
            data = weighting.apply_filter(data)
        power += data ** 2 * (1.41 if channel >= 3 else 1.0)
    hop = round(LOUDNESS_HOP_SECONDS * rate)
    last = max(0, len(power) - window)
    starts = np.append(np.arange(0, last, hop, dtype=int), last)
    integral = np.concatenate(([0.0], np.cumsum(power)))
    maximum = ((integral[np.minimum(starts + window, len(power))] - integral[starts]) / window).max()
    return float(-0.691 + 10 * np.log10(max(maximum, 1e-30)))


def describe_signal(samples, rate):
    rms = envelope(samples, rate)
    peak = int(rms.argmax())
    relative = rms / rms[peak]
    above = relative >= 10 ** (DECAY_LEVEL_DB / 20)
    below = np.flatnonzero(~above[peak:])
    above_end = int(np.flatnonzero(above)[-1]) + 1
    size = min(SPECTRAL_WINDOW_SAMPLES, len(samples))
    frequencies, power = welch(samples, rate, window="hann", nperseg=size,
                               detrend=False, scaling="spectrum", axis=0)
    high = float(power[frequencies > HIGH_HZ].sum() / power.sum())
    return {
        "rate": rate, "duration": len(samples) / rate,
        "first_fall": float(below[0] / rate) if len(below) else None,
        "decay": (above_end - peak) / rate,
        "above_seconds": float(np.count_nonzero(above) / rate),
        "to_eof": above_end == len(samples),
        "sustain": float(np.count_nonzero(relative[round(SUSTAIN_START * rate):]
                                          >= 10 ** (SUSTAIN_LEVEL_DB / 20)) / len(samples)),
        "lufs_s": short_term_peak(samples, rate), "true_peak": peak_levels(samples)["true_peak_dbtp"],
        "hf": high,
    }


@lru_cache(maxsize=None)
def measure_file(path, revision=None):
    if revision:
        raw = git_file(ROOT, revision, path.removeprefix("res://"))
        samples, rate = sf.read(BytesIO(raw), dtype="float64", always_2d=True)
    else:
        samples, rate = pcm(path)
    metrics = describe_signal(samples, rate)
    if revision is None:
        metrics["true_peak"] = max(metrics["true_peak"], ffmpeg_true_peak(ROOT / path.removeprefix("res://"), rate))
    return metrics


def variant(cue, path, entry, category, revision=None, fallback=False):
    metrics = measure_file(path, revision).copy()
    gain = float(entry.get("volume_db", 0.0))
    metrics["lufs_s"] += gain
    metrics["true_peak"] += gain
    impact = category in {"impact", "status"} or cue.startswith(("hit.", "spell.", "status.", "surface."))
    return dict(metrics, cue=cue, path=path, bus=entry["bus"], loop=entry.get("loop", False),
                trigger=entry["trigger"], gain=gain, impact=impact, fallback=fallback)


def measure_registry(cues):
    manifest = json.loads((ROOT / "spec/assets/sfx/manifest.json").read_text())
    categories = {"res://assets/audio/sfx/cues/" + row["path"]: row["category"] for row in manifest["outputs"]}
    baseline = [variant(cue, path, entry, categories.get(path))
                for cue, entry in cues.items() for path in cue_samples(cue, cues)]
    if {row["cue"] for row in baseline} != cues.keys():
        raise ValueError("Registry contains an unmeasured cue")
    candidates = [row for row in baseline if row["cue"] not in ELECTRIC]
    buses = defaultdict(list)
    for row in candidates:
        buses[row["bus"]].append(row["lufs_s"])
    medians = {bus: float(np.median(values)) for bus, values in buses.items()}
    high_cutoff = float(np.percentile([row["hf"] for row in candidates], HIGH_PERCENTILE))
    fixed = json.loads(git_file(ROOT, ELECTRIC_FIX, "data/sfx_cues.json"))["cues"]
    comparison = []
    for cue in sorted(ELECTRIC):
        for path in cue_samples(cue, cues) + cues[cue].get("fallback", []):
            fallback = path not in cue_samples(cue, cues)
            comparison.append((variant(cue, path, cues[cue], categories.get(path), fallback=fallback),
                               variant(cue, path, fixed[cue], categories.get(path), ELECTRIC_FIX, fallback)))
    for row in baseline + [row for pair in comparison for row in pair]:
        row["bus_delta"] = row["lufs_s"] - medians[row["bus"]]
        sustained = row["sustain"] > SUSTAIN_SHARE
        checks = {
            "S": sustained,
            "T": row["impact"] and row["above_seconds"] > LONG_IMPACT_SECONDS,
            "L": row["bus_delta"] > BUS_MARGIN_LU,
            "H": sustained and row["hf"] >= high_cutoff,
        }
        row["flags"] = [flag for flag, active in checks.items() if active]
    return baseline, comparison, medians, high_cutoff
