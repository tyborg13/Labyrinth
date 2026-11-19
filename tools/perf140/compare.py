#!/usr/bin/env python3
"""Compare stand-in forecast receipts and acceptance metrics."""
import argparse
import json
from pathlib import Path


def read(directory, name):
    return json.loads((directory / f"forecast-{name}.json").read_text())


def longest(row, section):
    scopes = (row["rest"]["sections"], row["committed_sections"], row["warm_sections"], row["badge_sections"])
    return max(scope[section]["max_usec"] for scope in scopes if section in scope)


def compare(base, candidate):
    before, after = (read(path, "receipts") for path in (base, candidate))
    differences = sorted(key for key in before.keys() | after.keys() if before.get(key) != after.get(key))
    if differences:
        print(f"PERF-140 IDENTITY: FAIL ({len(differences)} mismatches)")
        for key in differences:
            print(key)
    else:
        forecasts = sum("steps" in row for row in before.values())
        print(f"PERF-140 IDENTITY: PASS ({forecasts} forecasts, {len(before) - forecasts} badge receipts)")
    ok = not differences
    before, after = (read(path, "timings") for path in (base, candidate))
    for kind in ("normal", "tharokh"):
        left, right = before[kind], after[kind]
        base_slice, candidate_slice = (longest(row, "enemy_preview_slice_total") for row in (left, right))
        base_badges, candidate_badges = (longest(row, "rest_badges_build") for row in (left, right))
        max_advance = max(candidate_slice, *right["rest"]["advance_usec"])
        slice_reduction = 1 - candidate_slice / base_slice
        badge_reduction = 1 - candidate_badges / base_badges
        committed = right["committed_ready_frames"] - left["committed_ready_frames"]
        targeting = right["prewarm_frames"] - left["prewarm_frames"]
        checks = {
            "advance": (max_advance <= 8000, f"{max_advance / 1000:.3f} ms max"),
            "preview slice": (slice_reduction >= 0.6, f"{base_slice / 1000:.3f} → {candidate_slice / 1000:.3f} ms ({-slice_reduction:+.1%})"),
            "rest badges": (badge_reduction >= 0.5, f"{base_badges / 1000:.3f} → {candidate_badges / 1000:.3f} ms ({-badge_reduction:+.1%})"),
            "committed ready": (committed <= 2, f"{left['committed_ready_frames']} → {right['committed_ready_frames']} frames ({committed:+d})"),
            "target prewarm": (targeting <= 2, f"{left['prewarm_frames']} → {right['prewarm_frames']} frames ({targeting:+d})"),
        }
        for metric, (passed, detail) in checks.items():
            print(f"PERF-140 {kind} {metric}: {'PASS' if passed else 'FAIL'} ({detail})")
            ok &= passed
    return ok


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("base", type=Path)
    parser.add_argument("candidate", type=Path)
    options = parser.parse_args()
    raise SystemExit(0 if compare(options.base, options.candidate) else 1)
