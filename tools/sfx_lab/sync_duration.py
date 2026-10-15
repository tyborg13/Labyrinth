"""Registry-resolved one-shot length caps and deterministic tail fades."""
from __future__ import annotations

import math

import numpy as np

from tools.sfx_lab.common import LabError, fade_out
from tools.sfx_lab.sync_metrics import RULES


def duration_cap(cue: str, entry: dict) -> float | None:
    policy = RULES["duration"]
    if entry.get("loop", False) or cue.startswith(policy["ambience_prefix"]):
        return None
    kind = "signature"
    if (entry.get("bus") == policy["short_bus"] or cue in policy["short_cues"] or
            cue.startswith(tuple(policy["short_prefixes"]))):
        kind = "short"
    elif cue.startswith(tuple(policy["spell_prefixes"])):
        kind = "spell"
    return float(policy["caps_seconds"][kind])


def cue_paths(cue: str, cues: dict) -> list[str]:
    """Mirror SfxBank: resolve inheritance, then variants or the active fallback.

    Historical fallback entries are not loaded while variants exist, even if a
    variant fails to load. They are not extra playable variants of that cue.
    """
    visited = set()
    while cue not in visited:
        visited.add(cue)
        entry = cues[cue]
        if "variants_from" not in entry:
            return entry.get("variants") or entry.get("fallback", [])
        cue = entry["variants_from"]
    raise LabError("Cyclic variants_from: " + cue)


def variant_limits(cues: dict) -> dict[str, float]:
    limits = {}
    for cue, entry in cues.items():
        cap = duration_cap(cue, entry)
        if cap is None:
            continue
        for path in cue_paths(cue, cues):
            limits[path] = min(limits.get(path, cap), cap)
    return limits


def duration_audit(cues: dict, samples: dict) -> tuple[list[dict], list[str]]:
    rows, failures = [], []
    for cue, entry in cues.items():
        cap = duration_cap(cue, entry)
        for path in cue_paths(cue, cues):
            sample = samples.get(path, {})
            duration = sample.get("duration_seconds")
            row = {"cue": cue, "path": path, "duration_seconds": duration, "cap_seconds": cap,
                   "exempt": cap is None}
            rows.append(row)
            if duration is None:
                failures.append("Unmeasured cue duration: " + cue + " / " + path)
            elif cap is not None and duration > cap + 1e-9:
                failures.append(f"One-shot exceeds {cap:g} s cap: {cue} / {path} ({duration:.6f} s)")
    return rows, failures


def trim_tail(samples: np.ndarray, rate: int, cap: float | None) -> np.ndarray:
    if cap is None or len(samples) <= math.floor(cap * rate):
        return samples
    policy = RULES["duration"]
    return fade_out(samples[:math.floor(cap * rate)], rate, policy["tail_fade_ms"],
                    {"fade_curve": policy["tail_fade_curve"]})


def bind_duration_constraints(document: dict, cues: dict) -> None:
    """Pin the approved head before introducing a tail constraint.

    Rebuilds always start from the original lossless recipe, never a previous
    compressed output. Per-path caps also cover stricter inherited consumers.
    """
    limits = variant_limits(cues)
    for row in document["outputs"]:
        cap = limits.get("res://assets/audio/sfx/cues/" + row["path"])
        bound = row["constraints"]
        bound["max_duration_seconds"] = cap
        if cap is not None and row["after"]["duration_seconds"] > cap:
            bound.setdefault("head_removed_samples", row["removed_samples"])
            row.setdefault("tail_trim", {
                "before_duration_seconds": row["after"]["duration_seconds"],
                "before_output_sha256": row["output_sha256"],
                "before_peak_ms": row["after"]["peak_ms"],
                "before_short_loudness_lufs": row["after"]["short_loudness_lufs"]})
