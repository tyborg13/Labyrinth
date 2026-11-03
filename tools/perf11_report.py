#!/usr/bin/env python3
"""Summarize opt-in hover attribution; never enforce machine-time budgets."""
import argparse
import collections
import csv
import json
import math
from pathlib import Path


def stats(values):
    values = sorted(values)
    if not values:
        return "—"
    return " / ".join(f"{values[i]:.3f}" for i in
                      ((len(values) - 1) // 2, math.ceil(len(values) * .95) - 1, len(values) - 1))


def summarize(report):
    actions = collections.defaultdict(list)
    sections = collections.defaultdict(list)
    action_sections = collections.defaultdict(list)
    node_events = collections.Counter()
    first = []
    rest = []
    rows = []
    sweep = []
    input_frames = collections.defaultdict(list)
    for round_row in report["rounds"]:
        intervals = round_row["raw_samples"].get("hover_preview", {}).get("frame_interval_ms", [])
        first.extend(intervals[:1])
        rest.extend(intervals[1:])
        sweep.extend(round_row["raw_samples"].get("hand_sweep", {}).get("frame_interval_ms", []))
    rows += ["Native post-draw intervals" if report["native"] else "Headless scheduler intervals (not native pacing)",
             f"First hover sample p50 / p95 / max ms: {stats(first)}",
             f"Remaining hover samples p50 / p95 / max ms: {stats(rest)}", ""]
    if sweep:
        rows += [f"Hand sweep phase p50 / p95 / max ms: {stats(sweep)}", ""]
    for round_row in report.get("hover_attribution", []):
        actions_by_frame = collections.defaultdict(list)
        for action in round_row["actions"]:
            actions_by_frame[action["frame"]].append(action["kind"])
        for action in round_row["actions"]:
            actions[action["kind"]].append((action["ended_usec"] - action["started_usec"]) / 1000)
            scoped = collections.Counter()
            for frame in round_row["frames"]:
                if frame["frame"] != action["frame"]:
                    continue
                for interval in frame["intervals"]:
                    if (interval["start_usec"] >= action["started_usec"] and
                            interval["end_usec"] <= action["ended_usec"]):
                        scoped[interval["phase"]] += interval["end_usec"] - interval["start_usec"]
            for name in ("turn_order_strip_construct_and_layout", "card_glossary_construct_and_layout", "stage_total"):
                if name in scoped:
                    action_sections[f"{action['kind']} / {name}"].append(scoped[name] / 1000)
        for frame in round_row["frames"]:
            kinds = actions_by_frame[frame["frame"]]
            if kinds:
                label = "sweep" if any(k.startswith("sweep_") for k in kinds) else "+".join(kinds)
                times = frame["inclusive_usec"]
                values = (times.get("stage_total", 0) / 1000,
                          times.get("deferred_hover_total", 0) / 1000,
                          frame["counts"].get("stage_total", 0))
                input_frames[label].append(values)
                if label == "sweep":
                    input_frames["sweep / " + "+".join(kinds)].append(values)
            node_events.update(frame["events"])
            for name, usec in frame["inclusive_usec"].items():
                sections[name].append(usec / 1000)
    rows += ["Synchronous input calls (count; p50 / p95 / max ms):"]
    rows += [f"- {name}: {len(values)}; {stats(values)}" for name, values in actions.items()]
    rows += [f"- {name}: {len(values)}; {stats(values)}" for name, values in action_sections.items()]
    rows += ["", "Input frames (includes the coalesced deferred pass; counts are observed, not budgets):",
             "", "| Inputs | Frames | Stage p50 / p95 / max ms | Deferred p50 / p95 / max ms | Stage refreshes p50 / max |",
             "|---|---:|---:|---:|---:|"]
    for label, values in input_frames.items():
        counts = sorted(v[2] for v in values)
        rows.append(f"| {label} | {len(values)} | {stats([v[0] for v in values])} | "
                    f"{stats([v[1] for v in values])} | {counts[(len(counts)-1)//2]} / {max(counts)} |")
    if "hand_leave" in input_frames and not any(v[2] for v in input_frames["hand_leave"]):
        rows += ["", "Default tracing ends before deferred hand-leave work. Its zero traced stage count is unavailable, not free; use the sweep-only final-leave row for that CPU path."]
    rows += ["", "Node additions during the traced hover window:"]
    rows += [f"- {name}: {count}" for name, count in sorted(node_events.items()) if name.startswith("node_added:")]
    rows += ["", "Inclusive section sum per active frame (nested rows must not be added):", "",
             "| Section | Active frames | p50 / p95 / max ms |", "|---|---:|---:|"]
    for name, values in sorted(sections.items(), key=lambda item: max(item[1]), reverse=True):
        rows.append(f"| {name} | {len(values)} | {stats(values)} |")
    return "\n".join(rows) + "\n"


def write_frames(report, path):
    fields = ("round", "frame", "phase", "stage_refreshes", "inputs", "synchronous_input_ms", "deferred_hover_ms",
              "stage_ms", "strip_ms", "board_process_ms", "draw_ms", "tooltip_lookup_ms",
              "tooltip_construct_ms", "nodes_added", "subviewports_added", "pipelines_delta",
              "boundary_ms", "root_viewport_cpu_ms", "root_viewport_gpu_ms")
    with path.open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, delimiter="\t")
        writer.writeheader()
        for round_row in report.get("hover_attribution", []):
            last_boundary = None
            boundaries = {}
            actions_by_frame = collections.defaultdict(list)
            for action in round_row["actions"]:
                actions_by_frame[action["frame"]].append(action)
            last_pipelines = next((a["pipelines_before"] for a in round_row["actions"]
                                   if "pipelines_before" in a), None)
            for boundary in round_row["boundaries"]:
                boundary = dict(boundary)
                boundary["interval_ms"] = ((boundary["usec"] - last_boundary) / 1000
                                            if last_boundary is not None else "")
                boundary["pipeline_delta"] = (sum(boundary["pipelines"]) - sum(last_pipelines)
                                               if last_pipelines is not None else "")
                last_pipelines = boundary["pipelines"]
                last_boundary = boundary["usec"]
                boundaries[boundary["frame"]] = boundary
            for frame in round_row["frames"]:
                times = frame["inclusive_usec"]
                boundary = boundaries.get(frame["frame"], {})
                inputs = actions_by_frame[frame["frame"]]
                writer.writerow(dict(zip(fields, (
                    round_row["round"], frame["frame"], boundary.get("phase", next((a.get("phase", "") for a in inputs), "")),
                    frame["counts"].get("stage_total", 0), ",".join(a["kind"] for a in inputs),
                    sum(a["ended_usec"] - a["started_usec"] for a in inputs) / 1000,
                    times.get("deferred_hover_total", 0) / 1000,
                    times.get("stage_total", 0) / 1000,
                    times.get("turn_order_strip_construct_and_layout", 0) / 1000,
                    times.get("board_process", 0) / 1000,
                    sum(v for k, v in times.items() if k.startswith("draw:")) / 1000,
                    times.get("tooltip_lookup", 0) / 1000,
                    times.get("tooltip_construct", 0) / 1000,
                    sum(v for k, v in frame["events"].items() if k.startswith("node_added:")),
                    frame["events"].get("node_added:SubViewport", 0),
                    boundary.get("pipeline_delta", ""), boundary.get("interval_ms", ""),
                    boundary.get("viewport_cpu_ms", ""), boundary.get("viewport_gpu_ms", "")
                ))))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--frames-tsv", type=Path)
    args = parser.parse_args()
    report = json.loads(args.report.read_text())
    summary = summarize(report)
    if args.output:
        args.output.write_text(summary)
    if args.frames_tsv:
        write_frames(report, args.frames_tsv)
    print(summary)


if __name__ == "__main__":
    main()
