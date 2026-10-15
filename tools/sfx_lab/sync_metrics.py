"""Director-defined sfx-04 timing measures, shared by the audit and rebuild."""
from __future__ import annotations

from pathlib import Path
import runpy
import json
from scipy.signal import find_peaks, resample_poly

import numpy as np

from tools.sfx_lab.common import LabError

ROOT = Path(__file__).resolve().parents[2]
RULES = json.loads((ROOT / "data/sfx_cues.json").read_text())["rules"]["sync"]
ENVELOPE_MS = RULES["envelope_window_ms"]
PERCEIVED_DB_BELOW_PEAK = RULES["perceived_below_peak_db"]
PEAK_LATE_LIMIT_MS = RULES["peak_window_ms"][1]
MIN_PRE_PEAK_MS = RULES["minimum_pre_peak_ms"]
ALIGNMENT_FADE_MS = RULES["fade_ms"]
LOUDNESS_WINDOW_SECONDS = RULES["loudness_window_ms"] / 1000
LOUDNESS_TOLERANCE_LU = RULES["loudness_delta_lu"][1]
FAST_ONSET_CAP_MS = RULES["onset_caps_ms"]["fast"]
MOTION_ONSET_CAP_MS = RULES["onset_caps_ms"]["motion"]
_MIX_MEASURE = runpy.run_path(str(ROOT / "spec/peer_benchmark/staged/sfx/measure_mix.py"))


def envelope(samples: np.ndarray, rate: int) -> np.ndarray:
    """Centered 5 ms RMS, channel-mean power, sample hop, zero-padded edges.

    Timestamps refer to the window center, not its trailing edge. Measure the
    entire file: restricting the search to an early window hides slow swells.
    """
    count = max(1, round(ENVELOPE_MS * rate / 1000))
    power = np.mean(np.asarray(samples, dtype=np.float64) ** 2, axis=1)
    padded = np.pad(power, (count // 2, count - 1 - count // 2))
    cumulative = np.concatenate(([0.0], np.cumsum(padded)))
    return np.sqrt(np.maximum(0.0, (cumulative[count:] - cumulative[:-count]) / count))


def envelope_times(samples: np.ndarray, rate: int) -> dict:
    rms = envelope(samples, rate)
    strongest = int(np.argmax(rms))
    peaks, _ = find_peaks(rms, height=rms[strongest] * 10 ** (-RULES["alignment_peak_within_db"] / 20))
    peak = int(peaks[0]) if len(peaks) else strongest
    if rms[peak] <= 0:
        raise LabError("A silent file has no perceived onset or RMS peak")
    onset = int(np.flatnonzero(rms >= rms[peak] * 10 ** (-PERCEIVED_DB_BELOW_PEAK / 20))[0])
    return {"perceived_onset_ms": onset * 1000 / rate,
            "peak_ms": peak * 1000 / rate,
            "envelope_peak_dbfs": float(20 * np.log10(rms[peak])),
            "strongest_peak_ms": strongest * 1000 / rate,
            "strongest_envelope_dbfs": float(20 * np.log10(rms[strongest]))}


def short_loudness(path: Path) -> float:
    # Exactly the sfx-03 BS.1770 maximum of 100 ms windows at 25 ms hops,
    # including its zero-padding policy for samples shorter than 100 ms.
    return float(_MIX_MEASURE["mmax"](path, LOUDNESS_WINDOW_SECONDS))


def onset_cap(cue: str, entry: dict) -> float | None:
    if entry.get("loop", False) or cue.startswith("ambience."):
        return None
    if cue.startswith(("move.", "step.", "cast.", "spell.", "shot.", "swing.", "vocal.")) or cue in {
        "dragon.roar", "dragon.wings", "push.slide", "illusion.spawn", "illusion.break", "radiance.light"
    }:
        return MOTION_ONSET_CAP_MS
    return FAST_ONSET_CAP_MS


def peak_levels(samples: np.ndarray) -> dict:
    """Sample peak and four-times oversampled true peak, before playback gain."""
    return {"peak_dbfs": float(20 * np.log10(max(1e-15, np.max(np.abs(samples))))),
            "true_peak_dbtp": float(20 * np.log10(max(1e-15, np.max(np.abs(resample_poly(samples, 4, 1, axis=0))))))}
