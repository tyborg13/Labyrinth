#!/usr/bin/env python3
"""Compare the declaration sweep and Tharokh's matched perf-140 workload."""
import argparse
import json
from pathlib import Path


def read(path):
    return json.loads(path.read_text())


def compare_sweep(release, candidate):
    before, after = read(release), read(candidate)
    if len(before["rolls"]) != 1000 or len(after["rolls"]) != 1000:
        raise ValueError("Expected exactly 1,000 declarations on each side")
    for data in (before, after):
        helpers = sum("guardian_helper" in row for row in data["rolls"])
        if helpers != 500 or data.get("guardian_helper_cases") != helpers:
            raise ValueError("Expected 500 equal-hazard Guardian helper fixtures on each side")
    mismatches = [
        (index, left["boss"], left["id"], right["id"])
        for index, (left, right) in enumerate(zip(before["rolls"], after["rolls"]))
        if left != right
    ]
    if mismatches or before["sha256"] != after["sha256"]:
        print(f"PERF-143 SWEEP IDENTITY: FAIL ({len(mismatches)} mismatched declarations)")
        for mismatch in mismatches[:10]:
            print(mismatch)
        return False
    print(f"PERF-143 SWEEP IDENTITY: PASS (1,000 declarations, SHA-256 {before['sha256']})")
    return True


def tharokh_peak(data, section):
    sections = (data["rest"]["sections"], data["committed_sections"], data["warm_sections"])
    return max(scope[section]["max_usec"] for scope in sections if section in scope)


def compare_timing(release, candidate):
    before, after = (read(path / "forecast-timings.json")["tharokh"] for path in (release, candidate))
    old_roll, new_roll = (tharokh_peak(data, "enemy_turn_roll_total") for data in (before, after))
    reduction = 1 - new_roll / old_roll
    advance = max(tharokh_peak(after, "enemy_preview_slice_total"), *after["rest"]["advance_usec"])
    roll_passed = reduction >= 0.60
    advance_passed = advance <= 8_000
    print(f"PERF-143 THAROKH ROLL: {'PASS' if roll_passed else 'FAIL'} "
          f"({old_roll / 1000:.3f} → {new_roll / 1000:.3f} ms, {reduction:.1%} reduction)")
    print(f"PERF-143 THAROKH ADVANCE: {'PASS' if advance_passed else 'FAIL'} ({advance / 1000:.3f} ms max)")
    return roll_passed and advance_passed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("release_sweep", type=Path)
    parser.add_argument("candidate_sweep", type=Path)
    parser.add_argument("release_forecasts", type=Path)
    parser.add_argument("candidate_forecasts", type=Path)
    args = parser.parse_args()
    identity = compare_sweep(args.release_sweep, args.candidate_sweep)
    timing = compare_timing(args.release_forecasts, args.candidate_forecasts)
    return 0 if identity and timing else 1


if __name__ == "__main__":
    raise SystemExit(main())
