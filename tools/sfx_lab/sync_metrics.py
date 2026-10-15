"""Director-defined sfx-04 timing measures, shared by the audit and rebuild."""
from __future__ import annotations

from pathlib import Path
import runpy

import numpy as np

from tools.sfx_lab.common import LabError

ENVELOPE_MS = 5.0
PERCEIVED_DB_BELOW_PEAK = 6.0
PEAK_LATE_LIMIT_MS = 30.0
MIN_PRE_PEAK_MS = 15.0
ALIGNMENT_FADE_MS = 3.0
LOUDNESS_WINDOW_SECONDS = 0.1
LOUDNESS_TOLERANCE_LU = 0.5
FAST_ONSET_CAP_MS = 40.0
MOTION_ONSET_CAP_MS = 60.0
ROOT = Path(__file__).resolve().parents[2]
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
    peak = int(np.argmax(rms))
    if rms[peak] <= 0:
        raise LabError("A silent file has no perceived onset or RMS peak")
    onset = int(np.flatnonzero(rms >= rms[peak] * 10 ** (-PERCEIVED_DB_BELOW_PEAK / 20))[0])
    return {"perceived_onset_ms": onset * 1000 / rate,
            "peak_ms": peak * 1000 / rate,
            "envelope_peak_dbfs": float(20 * np.log10(rms[peak]))}


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
