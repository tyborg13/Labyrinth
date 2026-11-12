#!/usr/bin/env python3
"""Streaming hitch census reducer. No third-party dependencies or invented attribution."""
from __future__ import annotations

import argparse
from array import array
from collections import defaultdict
import json
import math
import redraw
from pathlib import Path

from attribution import attribute, hitch_id, new_catalog_row, add_catalog_frame, finish_catalog, catalog_markdown

THRESHOLDS_MS = (33.3, 50.0, 100.0)


def stats(values):
    values = sorted(values)
    if not values:
        return {"count": 0, "p50": None, "p99": None, "p99.9": None, "max": None}
    def percentile(p):
        return values[max(0, math.ceil(len(values) * p) - 1)]
    return {"count": len(values), "p50": percentile(.5), "p99": percentile(.99),
            "p99.9": percentile(.999), "max": values[-1]}


def frames(path):
    """A killed process may leave only its final row truncated. Interior damage fails."""
    with path.open() as stream:
        header = json.loads(next(stream))
        if header.get("schema") not in (1, 2, 3):
            raise ValueError(f"Unsupported trace schema: {path}")
        columns = header["columns"]
        previous_resources = None
        for number, line in enumerate(stream, 2):
            try:
                raw = json.loads(line)
            except json.JSONDecodeError:
                if not line.endswith("\n") and not stream.read(1):
                    return
                raise ValueError(f"Corrupt trace: {path}:{number}") from None
            if len(raw) != len(columns):
                raise ValueError(f"Wrong column count: {path}:{number}")
            frame = dict(zip(columns, raw))
            frame['frame_accurate'] = header.get('timing_version') == 3
            expected = frame['frame'] if header['native'] else frame['frame'] - 1
            frame['phase_map_was_stale'] = bool(frame.get('phase_times_us')) and frame.get('phase_frame', -1) != expected
            if frame.get('phase_frame', -1) != expected:
                frame['phase_times_us'] = {}
            resources = frame.get('monitors', {}).get('OBJECT_RESOURCE_COUNT')
            if frame.get('redraw_frame', expected) != expected:
                frame.pop('redraws', None)
                frame.pop('redraw_ms_estimate', None)
                frame.pop('redraw_span_ms', None)
                frame.pop('redraw_polygons', None)
            frame['resource_count_delta'] = resources - previous_resources if resources is not None and previous_resources is not None else None
            previous_resources = resources
            yield header, frame


def trigger(frame):
    ctx = frame["context"]
    resources = sorted(k for k in frame["events"] if k.startswith("instance:") and not k.startswith("instance:builtin:"))
    shader = sorted(k for k in frame["events"] if k.startswith("pipeline:") or k.startswith("shader:"))
    return (ctx.get("screen", "unknown"), ctx.get("action", "unknown"),
            ctx.get("phase", "unknown"), tuple(resources), tuple(shader))


def invalid_viewport_reason(run, directory):
    viewport = run.get("viewport") or {}
    if viewport.get("status") == "rejected":
        return "startup viewport rejected: " + viewport.get("failure", "pixel count or UI scale")
    # Keep the director's original failed take for audit, without mixing its
    # unknown Retina/fullscreen load into corrected Deck measurements.
    log = directory / "godot.log"
    if not viewport and run.get("returncode") and log.is_file():
        with log.open(errors="replace") as stream:
            if any("HITCH TRACE: Deck viewport drift" in line for line in stream):
                return "legacy Deck viewport drift rejection; actual render pixels unrecorded"
    return None


def generate(run_paths, output):
    output.mkdir(parents=True, exist_ok=True)
    situations = defaultdict(lambda: array("d"))
    raw_situations = defaultdict(lambda: array("d"))
    catalog = {}
    loading = {}
    groups = {}
    redraw_cells = {}
    runs = []
    rejected = []
    calibration = defaultdict(dict)
    with (output / "slow_frames.jsonl").open("w") as slow:
        for run_path in sorted(run_paths):
            run = json.loads(run_path.read_text())
            directory = run_path.parent
            receipt_path = directory / "receipt.json"
            receipt = json.loads(receipt_path.read_text()) if receipt_path.exists() else {}
            run["receipt"] = receipt
            run["outcome"] = receipt.get("outcome", run.get("outcome"))
            run["errors"] = receipt.get("errors", run.get("errors", []))
            run["viewport"] = run.get("viewport") or receipt.get("viewport")
            runs.append(run)
            if run.get("driver") == "calibration":
                values = receipt.get("calibration_intervals_ms", [])
                calibration[run.get("cache", "unknown")][run.get("profile", "unknown") + ":" + run.get("trace_mode", "on")] = stats(values)
            if run.get("primer", False):
                continue
            viewport_failure = invalid_viewport_reason(run, directory)
            if viewport_failure:
                rejected.append({"run": str(run_path), "reason": viewport_failure})
                continue
            if run.get("driver") == "calibration":
                continue
            path = directory / "frames.jsonl"
            if not path.exists():
                if run.get("trace_mode", "on") == "on": rejected.append({"run": str(run_path), "reason": "missing trace"})
                continue
            previous_video_bytes = None
            for header, frame in frames(path):
                if not header["native"]:
                    rejected.append({"run": str(run_path), "reason": "headless trace excluded from renderer catalog"})
                    break
                ctx = frame["context"]
                duration = float(frame["draw_interval_ms"])
                if not math.isfinite(duration) or duration < 0:
                    raise ValueError(f"Invalid interval in {path}")
                attribution, previous_video_bytes = attribute(frame, previous_video_bytes)
                frame.update(attribution)
                duration = frame["game_ms"]
                screen, action, phase, resources, shaders = trigger(frame)
                is_loading = phase in ("startup", "fixture_install") or screen == "title"
                target = loading if is_loading else catalog
                catalog_key = (hitch_id(frame), run["profile"], run["cache"])
                if catalog_key not in target: target[catalog_key] = new_catalog_row(frame, run)
                add_catalog_frame(target[catalog_key], frame, run.get("replay", "unavailable"))
                if duration > THRESHOLDS_MS[0]:
                    slow.write(json.dumps({**frame, "run": str(run_path), "replay": run.get("replay", "unavailable"),
                                           "loading": is_loading, "over_ms": [t for t in THRESHOLDS_MS if duration > t]}) + "\n")
                if is_loading: continue
                if 'redraws' in frame:
                    for threshold in (50.0, 100.0):
                        key = (run['profile'], run['cache'], threshold)
                        if key not in redraw_cells:
                            redraw_cells[key] = dict(slow=redraw.new_cell(), ordinary=redraw.new_cell())
                        redraw.add_frame(redraw_cells[key]['slow' if duration > threshold else 'ordinary'], frame)
                situation = (screen, action, phase, ctx.get("room_type", ""), run["cache"], run["profile"])
                situations[situation].append(duration)
                raw_situations[situation].append(frame["draw_interval_ms"])
                if duration <= THRESHOLDS_MS[0]: continue
                replay = run.get("replay", "unavailable")
                first = {"seed": ctx.get("seed", run.get("seed")), "decision": ctx.get("decision", 0),
                         "frame": frame["frame"], "run": str(run_path), "replay": replay}
                key = (screen, action, phase, resources, shaders, run["cache"], run["profile"])
                if key not in groups:
                    groups[key] = {"screen": screen, "action": action, "phase": phase, "resources_instanced": resources,
                                   "shader_events": shaders, "cache": run["cache"], "profile": run["profile"],
                                   "values": array("d"), "raw_values": array("d"), "first": first, "severity_ms": 0.0,
                                   "phase_totals_us": {}, "matched_phase_frames": 0, "known_driver_total_us": 0,
                                   "over_ms": {str(t): 0 for t in THRESHOLDS_MS}}
                group = groups[key]
                if frame.get("phase_times_us"):
                    group["matched_phase_frames"] += 1
                    for label, usec in frame.get("phase_times_us", {}).items():
                        group["phase_totals_us"][label] = group["phase_totals_us"].get(label, 0) + usec
                group["known_driver_total_us"] += sum(frame.get("driver_cpu_us", {}).values())
                group["values"].append(duration)
                group["raw_values"].append(frame["draw_interval_ms"])
                group["severity_ms"] += duration - THRESHOLDS_MS[0]
                for threshold in THRESHOLDS_MS:
                    group["over_ms"][str(threshold)] += int(duration > threshold)
    clusters = []
    for group in groups.values():
        group.update(stats(group.pop("values")))
        group["raw_interval_ms"] = stats(group.pop("raw_values"))
        group["top_inclusive_cpu_phases"] = sorted(group.pop("phase_totals_us").items(), key=lambda item: -item[1])[:10]
        clusters.append(group)
    clusters.sort(key=lambda g: (-g["severity_ms"], -g["count"], g["screen"]))
    rows = [{"screen": k[0], "action": k[1], "phase": k[2], "room_type": k[3],
             "cache": k[4], "profile": k[5], "raw_interval_ms": stats(raw_situations[k]), **stats(v)} for k, v in sorted(situations.items())]
    ratios = []
    for cache, cells in sorted(calibration.items()):
        for numerator, denominator, label in (("background:on", "normal:on", "throttle_slowdown"),
                                               ("normal:on", "normal:off", "observer_impact")):
            a, b = cells.get(numerator, {}).get("p50"), cells.get(denominator, {}).get("p50")
            ratios.append({"cache": cache, "comparison": label, "p50_ratio": a / b if a is not None and b else None})
    result = {"metric": "game_ms = max(0, draw_interval_ms - sum(driver_cpu_us)/1000 - observer_previous_us/1000); present proxy, not scanout", "named_hitch_catalog": [row for row in finish_catalog(catalog, stats) if row["max"] > THRESHOLDS_MS[0]], "loading": finish_catalog(loading, stats), "thresholds_ms": THRESHOLDS_MS,
              "redraw": [dict(profile=k[0], cache=k[1], threshold_ms=k[2],
                              **{name: redraw.finish(cell) for name, cell in cells.items()})
                         for k, cells in sorted(redraw_cells.items())],
              "clusters": clusters, "situations": rows, "runs": runs, "rejected": rejected,
              "calibration": dict(calibration), "calibration_ratios": ratios}
    (output / "report.json").write_text(json.dumps(result, indent=2) + "\n")
    write_markdown(result, output / "report.md")
    return result


def write_markdown(result, path):
    lines = ["# Hitch census", "", "Metric: game_ms = max(0, raw draw-boundary interval − known driver CPU ms − the previous observer callback). Raw intervals remain alongside game statistics. Native draw boundaries are a present proxy. True display presentation timestamps and separate texture upload timers are unavailable. Load spans and post_draw/input phases are inclusive; explained pre_process is an overlapping estimate capped per frame at pre_process. Boundaries are signal timestamps, not exclusive CPU time. Schema 1/2 and pre-fix schema 3: rolling-peak monitors: not frame-accurate; process/physics/pre_process/draw buckets are n/a. OBJECT_RESOURCE_COUNT deltas are unattributed-load proxies, not load counts. Shader/pipeline counters and instance paths are correlated observations, not proven causal attribution. Thresholds are strict >33.3, >50 and >100 ms; catalog ranking is frames >100 ms then max game_ms; trigger clusters use count × mean game excess over 33.3 ms. Loading is separate. Buckets are CPU/wall proxies, not an exclusive CPU/GPU decomposition. SubViewport CPU is part of draw. Older traces cannot reconstruct signal wall-time buckets. Video memory deltas use consecutive full-trace samples; they are allocation/upload proxies, not proof of uploads. Bucket means use frames >50 ms; event totals and mean video deltas use all row frames. Quantiles use nearest rank.", "", "Every slow frame, including monitors, context, observed events and replay command: `slow_frames.jsonl`.", "", "## Capture receipts", "", "| Driver / seed | Cache / QoS | Exit / outcome / errors | Frames | Observer mean / p99 µs | Known driver mean µs |", "|---|---|---|---:|---:|---:|"]
    for run in result["runs"]:
        receipt = run["receipt"]
        trace = receipt.get("trace", {})
        lines.append(f"| {run.get('driver')} / {run.get('seed')} | {run.get('cache')} / {run.get('profile')} | {run.get('returncode')} / {run.get('outcome', 'missing receipt')} / {json.dumps(run.get('errors', []))} | {trace.get('frames', 0)} | {trace.get('observer_mean_us', 'unmeasured')} / {trace.get('observer_sample_p99_us', 'unmeasured')} | {trace.get('known_driver_mean_us', 'unmeasured')} |")
    lines += ["", "Whole-driver settings (recorded per take; unknown for old runs):"]
    for run in result['runs']:
        if run.get('driver') == 'whole':
            settings = run.get('whole_settings', run['receipt'].get('whole_settings', 'unrecorded'))
            lines.append(f"- Seed {run.get('seed')}: {json.dumps(settings)}")
    lines += ["", "## Named hitch catalog", ""] + catalog_markdown(result["named_hitch_catalog"])
    lines += redraw.markdown(result["redraw"])
    lines += ["", "## Loading frames", ""] + catalog_markdown(result["loading"])
    lines += ["", "## Startup viewports", "", "Version 2 render pixels come from one backing-image readback. The texture getter is canvas-transformed and is shown separately; legacy measurements are not physical-pixel proof. The pixel/scale gate runs once before gameplay. Headless render pixels remain unknown.", "", "| Driver / seed / cache / QoS | Backing pixels / texture getter / root size | UI scale / canvas size | HiDPI allowed / screen scale | Check / pixel ratio / startup capture µs |", "|---|---|---|---|---|"]
    def dimensions(value):
        return "x".join(map(str, value)) if value is not None else "unmeasured"
    for run in result["runs"]:
        viewport = run.get("viewport") or {}
        version = viewport.get("pixel_measurement_version", 1)
        backing = viewport.get("root_pixel_size") if version >= 2 else None
        getter = viewport.get("root_texture_reported_size", viewport.get("root_pixel_size") if version < 2 else None)
        ratio = viewport.get("pixel_count_ratio", "unmeasured")
        if version < 2 and ratio != "unmeasured": ratio = "legacy:" + str(ratio)
        scale = viewport.get("content_scale")
        scale_text = f"{scale:g}" if scale is not None else "unmeasured"
        lines.append(f"| {run.get('driver')} / {run.get('seed')} / {run.get('cache')} / {run.get('profile')} | {dimensions(backing)} / {dimensions(getter)} / {dimensions(viewport.get('root_size'))} | {scale_text} / {dimensions(viewport.get('content_scale_size'))} | {str(viewport.get('hidpi_allowed', 'unmeasured')).lower()} / {viewport.get('screen_scale', 'unmeasured')} | {viewport.get('status', 'unmeasured')} / {ratio} / {viewport.get('startup_capture_us', 'unmeasured')} |")
    lines += ["", "## Ranked trigger clusters", "", "| Screen / action / phase | Raw max / p99 ms | Cache / QoS | Count >33.3 / >50 / >100 | Max / p99 ms | Excess ms | First seed / decision |", "|---|---:|---|---:|---:|---:|---|"]
    for index, group in enumerate(result["clusters"], 1):
        counts = group["over_ms"]
        lines.append(f"| {index}. {group['screen']} / {group['action']} / {group['phase']} | {group['raw_interval_ms']['max']:.3f} / {group['raw_interval_ms']['p99']:.3f} | {group['cache']} / {group['profile']} | {counts['33.3']} / {counts['50.0']} / {counts['100.0']} | {group['max']:.3f} / {group['p99']:.3f} | {group['severity_ms']:.3f} | {group['first']['seed']} / {group['first']['decision']} |")
    for index, group in enumerate(result["clusters"], 1):
        lines += ["", f"### Cluster {index}", "", f"Known driver CPU: {group['known_driver_total_us']} µs. Top inclusive CPU phases (matched-frame microseconds, not additive): {group['top_inclusive_cpu_phases']}; matched frames {group['matched_phase_frames']}.", "", f"Instances: {', '.join(group['resources_instanced']) or 'unknown'}. Shader events: {', '.join(group['shader_events']) or 'none exposed/observed'}.", "", "Replay the same cache preparation and input sequence; first decision is listed above:", "", f"```sh\n{group['first']['replay']}\n```"]
    lines += ["", "## Situation comparisons", "", "Each cell: count; game p50 / p99 / p99.9 / max ms. Raw statistics for each cache/QoS cell appear in the second column. Missing cells are unmeasured.", "", "| Screen / action / phase / room | Raw p50 / p99 / p99.9 / max per cache/QoS | Cold normal | Warm normal | Cold background | Warm background |", "|---|---|---|---|---|---|"]
    side = defaultdict(dict)
    raw_side = defaultdict(dict)
    for row in result["situations"]:
        key = (row["screen"], row["action"], row["phase"], row["room_type"])
        raw_side[key][(row["cache"], row["profile"])] = " / ".join(f"{row['raw_interval_ms'][k]:.3f}" for k in ("p50", "p99", "p99.9", "max"))
        side[key][(row["cache"], row["profile"])] = f"{row['count']}; " + " / ".join(f"{row[k]:.3f}" for k in ("p50", "p99", "p99.9", "max"))
    for key, cells in sorted(side.items()):
        lines.append("| " + " / ".join(key) + " | " + "; ".join("/".join(pair) + ": " + value for pair, value in sorted(raw_side[key].items())) + " | " + " | ".join(cells.get(pair, "—") for pair in (("cold", "normal"), ("warm", "normal"), ("cold", "background"), ("warm", "background"))) + " |")
    lines += ["", "## Fixed-scene calibration", "", "Background QoS requests the closest available macOS efficiency-core preference; it does not prove core residency. Ratios use the fixed scene's interval p50; >1 means slower.", ""]
    lines += [f"- {row['cache']} {row['comparison']}: {row['p50_ratio'] if row['p50_ratio'] is not None else 'unmeasured'}" for row in result["calibration_ratios"]]
    lines += ["", f"Excluded inputs: {json.dumps(result['rejected'])}", ""]
    path.write_text("\n".join(lines))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = generate(args.root.rglob("run.json"), args.output)
    print(f"HITCH REPORT: runs={len(result['runs'])} clusters={len(result['clusters'])} situations={len(result['situations'])} excluded={len(result['rejected'])}")


if __name__ == "__main__":
    main()
