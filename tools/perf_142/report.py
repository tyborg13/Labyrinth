#!/usr/bin/env python3
"""Compare matching perf-142 takes and list every interval over 16 ms."""

from __future__ import annotations

import argparse
import copy
import json
import math
import statistics
from pathlib import Path

MATCHING_INPUTS = ("headless", "seed", "title_idle_seconds", "viewport", "ui_scale", "renderer", "godot", "demo", "capture")
WAIT_NAMES = (
    ("resource_request", "first loading presentation"),
    ("threaded_load_wait", "scene resource wait"),
    ("initial_asset_preparation", "initial asset preparation"),
    ("initial_ui_preparation", "staged run UI"),
    ("presentation_ready_wait", "presentation readiness"),
)


def load_take(directory: Path) -> dict:
    return json.loads((directory / "probe.json").read_text())


def stable_receipt(data: dict) -> dict:
    receipt = copy.deepcopy(data["receipt"])
    for step in receipt.values():
        for snapshot in (step["state"], step["saved"]):
            snapshot.get("analytics", {}).pop("run_id", None)
            snapshot.get("run_stats", {}).pop("run_seconds", None)
    return receipt


def context(frame: dict, take: dict) -> str:
    if frame["waiting_for"]:
        return frame["waiting_for"]
    profile = take["transition"]
    for end, name in WAIT_NAMES:
        if frame["finished_usec"] <= profile.get(end + "_finished_usec", 0):
            return name
    if frame["stage"] == "opening_to_map":
        return "opening dialogue to map"
    return "reveal and input handoff"


def details(name: str, take: dict) -> list[str]:
    frames = take["frames"]
    intervals = sorted(frame["ms"] for frame in frames)
    p95 = intervals[math.ceil(len(intervals) * 0.95) - 1]
    p99 = intervals[math.ceil(len(intervals) * 0.99) - 1]
    misses = " / ".join(str(sum(ms > threshold for ms in intervals)) for threshold in (16, 50, 100))
    route = take["landmarks"]
    lines = [
        f"## {name}",
        "",
        f"Median / p95 / p99 / max = {statistics.median(intervals):.3f} / {p95:.3f} / {p99:.3f} / {intervals[-1]:.3f} ms.",
        f"Frames over 16 / 50 / 100 ms = {misses}.",
        f"Press → first playable frame {route['first_interactive_frame']['ms']:.3f} ms, press → first map {route['first_map_frame']['ms']:.3f} ms.",
        "",
        "Named work below is inclusive. The context column identifies the active wait or presentation when no recorded CPU span accounts for the interval.",
        "",
        "| Frame | ms | Context | Phases (ms) | Texture spans (ms) |",
        "| --- | ---: | --- | --- | --- |",
    ]
    if "interactive_title_usec" in take:
        lines.insert(2, f"Engine start → first interactive title {take['interactive_title_usec'] / 1000:.3f} ms.")
    for frame in frames:
        if frame["ms"] <= 16:
            continue
        phases = sorted(frame["phases_usec"].items(), key=lambda pair: (-pair[1], pair[0]))
        loads = sorted(frame["loads"].items(), key=lambda pair: (-pair[1]["total_us"], pair[0]))
        phase_text = ", ".join(f"{label} {usec / 1000:.3f}" for label, usec in phases)
        load_text = ", ".join(f"{label} {values['total_us'] / 1000:.3f}" for label, values in loads[:5])
        if len(loads) > 5:
            load_text += f" (+{len(loads) - 5} in raw trace)"
        lines.append(f"| {frame['frame']} | {frame['ms']:.3f} | {context(frame, take)} | {phase_text} | {load_text} |")
    return lines


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("release", type=Path)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    release = load_take(args.release)
    candidate = load_take(args.candidate)
    mismatches = [key for key in MATCHING_INPUTS if release[key] != candidate[key]]
    if mismatches:
        parser.error("take conditions differ: " + ", ".join(mismatches))
    receipts_match = stable_receipt(release) == stable_receipt(candidate)
    receipt_result = f"receipts {'MATCH' if receipts_match else 'DIFFER'}"
    if candidate["capture"]:
        summary = f"PERF142 VISUAL RECEIPTS: {receipt_result}"
        args.output.write_text(summary + "\n")
        print(summary)
        return 0 if receipts_match else 1
    old = max(frame["ms"] for frame in release["frames"])
    new = max(frame["ms"] for frame in candidate["frames"])
    reduction = (old - new) / old * 100
    summary = f"PERF142 COMPARISON: max {old:.3f} -> {new:.3f} ms ({reduction:.1f}% lower); {receipt_result}"
    text = [
        "# perf-142 New Run to first map",
        "",
        summary,
        "",
        f"Seed {candidate['seed']}, {candidate['viewport']} at {candidate['ui_scale']:.0%}, "
        f"title idle {candidate['title_idle_seconds']:.1f} s, {'headless process-frame proxy' if candidate['headless'] else 'native post-draw boundary'}.",
        "Receipt comparison excludes the independently generated analytics ID and elapsed play clock. It includes the complete remaining live run state, save, profile, and first-map destinations.",
        "",
        *details("Release", release),
        "",
        *details("Candidate", candidate),
    ]
    args.output.write_text("\n".join(text) + "\n")
    print(summary)
    return 0 if receipts_match else 1


if __name__ == "__main__":
    raise SystemExit(main())
