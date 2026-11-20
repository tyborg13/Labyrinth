"""Reduce matched room-entry and run-start frame traces."""

from __future__ import annotations

import json
import math
from statistics import median

WINDOWS = ("run_start", "room_entry")
NORMAL_PAIR_LIMIT_PERCENT = 10.0
BACKGROUND_WALL_LIMIT_PERCENT = 5.0


def take_metrics(take, native):
    windows = json.loads((take / "windows.json").read_text())
    intervals = {name: [] for name in WINDOWS}
    waits = dict.fromkeys(WINDOWS, 0)
    with (take / "frames.jsonl").open() as stream:
        header = json.loads(next(stream))
        if header["native"] != native:
            raise ValueError(f"Unexpected display mode in {take}")
        for line in stream:
            row = dict(zip(header["columns"], json.loads(line)))
            if native and not row["focused"]:
                raise ValueError(f"Unfocused frame in accepted take {take}")
            if not row["complete_interval"]:
                continue
            boundary = row["post_draw_us"] if native else (
                row["process_frame_us"] + round(row["draw_interval_ms"] * 1000))
            for name in WINDOWS:
                window = windows[name]
                # Keep the full interval that straddles the input press.
                if window["start"]["usec"] < boundary <= window["end"]["usec"]:
                    intervals[name].append(row["draw_interval_ms"])
                    waits[name] += row["events"].get("preparation:budget_yields", 0)

    metrics = {}
    for name in WINDOWS:
        window = windows[name]
        frames = sorted(intervals[name])
        if not frames:
            raise ValueError(f"Missing timing window {name} in {take}")
        metrics[name] = {
            "max": frames[-1],
            "median": median(frames),
            "p95": frames[math.ceil(len(frames) * 0.95) - 1],
            "over_33ms": sum(interval > 33.33 for interval in frames),
            "frames": len(frames),
            "wall": (window["end"]["usec"] - window["start"]["usec"]) / 1000,
            "budget_yields": waits[name],
            "witness": tuple(window.get(key) for key in ("room", "mode", "destination", "preview")),
        }
    environment = {key: header[key] for key in ("godot", "cpu", "renderer", "adapter", "display", "cel_look")}
    return metrics, environment


def delta(before, after, key):
    return 100 * (after[key] - before[key]) / before[key]


def timing_report(takes, path, profile, native):
    environment = None
    lines = [
        f"# perf-158 {profile} QoS",
        "",
        "Native post-draw interval (CPU submission proxy)." if native else "Headless process-frame intervals.",
        "Wall time spans the controller press through the first eligible presentation boundary.",
        "Deltas are candidate minus base, as a percentage of base. Spread is the min–max of the paired deltas.",
        "",
        "| Pair | Window | Max ms A → B (Δ) | Wall ms A → B (Δ) | Median frame ms A → B | p95 frame ms A → B | >33.33 ms A → B | Frames A → B | Candidate preparation yields |",
        "|---|---|---:|---:|---:|---:|---:|---:|---:|",
    ]
    deltas = {name: {"max": [], "wall": []} for name in WINDOWS}
    for pair, base, candidate in takes:
        a, base_environment = take_metrics(base, native)
        b, candidate_environment = take_metrics(candidate, native)
        if environment is None:
            environment = base_environment
        if environment != base_environment or environment != candidate_environment:
            raise ValueError(f"Pair {pair} has a different trace environment")
        for name in WINDOWS:
            before, after = a[name], b[name]
            if before["witness"] != after["witness"]:
                raise ValueError(f"Pair {pair} has different {name} witnesses")
            worst, wall = (delta(before, after, key) for key in ("max", "wall"))
            deltas[name]["max"].append(worst)
            deltas[name]["wall"].append(wall)
            lines.append(
                f"| {pair} | {name} | {before['max']:.3f} → {after['max']:.3f} ({worst:+.2f}%) | "
                f"{before['wall']:.3f} → {after['wall']:.3f} ({wall:+.2f}%) | "
                f"{before['median']:.3f} → {after['median']:.3f} | {before['p95']:.3f} → {after['p95']:.3f} | "
                f"{before['over_33ms']} → {after['over_33ms']} | {before['frames']} → {after['frames']} | "
                f"{after['budget_yields']} |"
            )

    render_environment = [f"Godot {environment['godot']['string']}"]
    render_environment.extend(environment[key] for key in ("cpu", "display", "renderer", "adapter") if environment[key])
    lines.insert(3, ", ".join(render_environment) + ".")
    lines.extend(["", "| Window | Metric | Median delta | Spread |", "|---|---|---:|---:|"])
    for name, metrics in deltas.items():
        for key, values in metrics.items():
            lines.append(f"| {name} | {key} | {median(values):+.2f}% | {min(values):+.2f}% to {max(values):+.2f}% |")

    start = deltas["run_start"]
    if not native:
        lines.extend(["", "Native acceptance is pending."])
        accepted = True
    elif profile == "normal":
        accepted = all(median(values) < 0 and max(values) <= NORMAL_PAIR_LIMIT_PERCENT
                       for values in start.values())
    else:
        accepted = median(start["max"]) < 0 and median(start["wall"]) <= BACKGROUND_WALL_LIMIT_PERCENT
    if native:
        lines.extend(["", f"Run-start acceptance: {'PASS' if accepted else 'FAIL'}"])
    path.write_text("\n".join(lines) + "\n")
    return accepted
