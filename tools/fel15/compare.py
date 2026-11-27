#!/usr/bin/env python3
"""Compare matched fel-09 endpoint receipts and report the fel-15 median."""

import argparse
import json
from pathlib import Path
from statistics import median


MEDIAN_FIXTURES = {"02", "04", "05", "06", "07", "11", "12"}
MINIMUM_IMPROVEMENT = 15.0


def read(directory):
    report = json.loads((directory / "timeline.json").read_text())
    run = (report["mode"], report["engine"], report["settings"], report["variant"])
    return run, {row["fixture"]: row for row in report["fixtures"]}


def steps(row):
    return [{key: value for key, value in step.items() if not key.endswith("_ms")} for step in row["steps"]]


def compare(release, branch):
    run, before = read(release)
    after_run, after = read(branch)
    if run != after_run or before.keys() != after.keys():
        raise ValueError("Mismatched census settings or fixtures")
    fields = ("final_state", "outcome", "input_accepted", "input_witness", "action_count")
    same_game = True
    pairs = []
    print("| Fixture | Actions | Release ms/action | Branch ms/action | Reduction |")
    print("| --- | ---: | ---: | ---: | ---: |")
    for name in sorted(before):
        left, right = before[name], after[name]
        differences = [field for field in fields if left[field] != right[field]]
        if steps(left) != steps(right):
            differences.append("steps")
        if differences:
            print(f"FEL15 STATE DIFF fixture={name} fields={','.join(differences)}")
            same_game = False
        actions = left["action_count"]
        if not actions:
            print(f"| {name} | 0 | — | — | — |")
            continue
        a, b = left["turn_ms"] / actions, right["turn_ms"] / actions
        print(f"| {name} | {actions} | {a:.1f} | {b:.1f} | {100 * (1 - b / a):.1f}% |")
        if name[:2] in MEDIAN_FIXTURES:
            pairs.append((a, b))
    stacked = sum(row["stacked_number_frames"] for row in after.values())
    print(f"FEL15 SAME GAME {'PASS' if same_game else 'FAIL'} fixtures={len(before)}")
    print(f"FEL15 STACKED NUMBERS frames={stacked}")
    return same_game and stacked == 0, pairs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("release", type=Path)
    parser.add_argument("branch", type=Path)
    parser.add_argument("--require-median", action="store_true")
    args = parser.parse_args()
    ok, pairs = compare(args.release, args.branch)
    if args.require_median:
        if len(pairs) != len(MEDIAN_FIXTURES):
            parser.error("Median needs all seven specified fixtures")
        a, b = (median(values) for values in zip(*pairs))
        reduction = 100 * (1 - b / a)
        passes = reduction >= MINIMUM_IMPROVEMENT
        print(f"FEL15 MEDIAN {'PASS' if passes else 'FAIL'} release={a:.1f} branch={b:.1f} reduction={reduction:.1f}% target={MINIMUM_IMPROVEMENT:g}%")
        ok = ok and passes
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
