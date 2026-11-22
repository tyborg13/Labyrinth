#!/usr/bin/env python3
"""Matched perf-161 takes and an all-frame census of texture cache misses."""

import argparse
from collections import defaultdict
import json
import os
from pathlib import Path
import statistics
import struct
import subprocess
import sys

from census import ROOT, WINDOW_CORNER_POSITION, validate_prepared


TASK_ID = "perf-161"
WORKLOADS = {"demo-7": ("demo", 7), "tour-83": ("tour", 83),
             **{f"whole-{seed}": ("whole", seed) for seed in (84, 85, 86)}}
SECONDS = {"demo": 900, "tour": 210, "whole": 900}
VIEWPORT = "1920x1080"
UI_SCALE = 1.0
ENTRY_LIMIT = 1.10
MIB = 1024 ** 2
TEXTURE_MEMORY_MONITOR = "RENDER_TEXTURE_MEM_USED"


def collect(args):
    output = args.output.resolve()
    project = ROOT
    if not args.headless:
        if args.prepared is None:
            raise ValueError("Native takes need a census.py prepare output")
        validate_prepared(args.prepared.resolve())
        project = args.prepared.resolve() / "project"
        override = project / "override.cfg"
        override.write_text(override.read_text().replace("1280", "1920").replace("800", "1080").replace("1.15", "1.0"))
    for workload in args.workloads:
        driver, seed = WORKLOADS[workload]
        seconds = args.seconds or SECONDS[driver]
        for profile in args.profiles:
            prefix = ["taskpolicy", "-c", "background"] if profile == "background" else []
            for variant in args.variants:
                directory = output / workload / profile / variant
                directory.mkdir(parents=True)
                env = dict(os.environ, LABYRINTH_HITCH_TRACE="1", LABYRINTH_CEL_LOOK="all",
                           SteamDeck="1", LABYRINTH_PROBE_WINDOW="1", LABYRINTH_DEMO=str(int(driver == "demo")))
                display = ["--headless"] if args.headless else [
                    "--resolution", VIEWPORT, "--windowed", "--position", WINDOW_CORNER_POSITION]
                command = [*prefix, sys.executable, "tools/godot_task_runner.py", "--task-id", TASK_ID,
                           "--timeout", str(seconds + 90), "--stream", "--", "godot", "--path", str(project),
                           *display, "--script", "res://tools/hitch_census/driver.gd", "--",
                           "--combat-texture-census", f"--driver={driver}", f"--seed={seed}", f"--seconds={seconds}",
                           f"--size={VIEWPORT}", f"--ui-scale={UI_SCALE}", f"--output={directory}"]
                if args.headless or driver == "demo":
                    command.append("--quick")
                if args.headless:
                    command.append("--headless-smoke")
                if variant == "baseline":
                    command.append("--combat-texture-baseline")
                if driver == "tour":
                    command.append("--staged-tharokh-tour")
                if driver == "whole":
                    command.append("--first-boss")
                    if args.stop_after:
                        command.append(f"--stop-after={args.stop_after}")
                print(f"PERF-161 TAKE: {workload} {profile} {variant} ({directory})", flush=True)
                with (directory / "runner.log").open("w") as log:
                    status = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
                (directory / "take.json").write_text(json.dumps({
                    "workload": workload, "profile": profile, "variant": variant,
                    "exit": status.returncode, "command": command,
                }) + "\n")


def texture_size(path):
    source = ROOT / path.removeprefix("res://")
    if source.is_file() and source.suffix == ".png":
        with source.open("rb") as file:
            header = file.read(24)
        if len(header) == 24 and header.startswith(b"\x89PNG\r\n\x1a\n"):
            return struct.unpack(">II", header[16:])
    return None


def trigger(path, screen, action, stack=()):
    sources = {Path(frame["source"]).stem for frame in stack}
    functions = {frame["function"] for frame in stack}
    if "prepared_victory_reward" in sources or "_build_reward_choice_stack" in functions:
        return "hidden victory offer"
    if "_loot_texture" in functions:
        return "battlefield loot"
    if "_unit_mask" in functions:
        return "unit rest mask when facing changes"
    if "_masked_emblem_texture" in functions:
        return "card role emblem"
    if "_watch_texture" in functions:
        return "card time badge"
    if "_animate_staged_draw_hand_fx" in functions:
        return "card drawn"
    if "retained_pass_preview" in sources:
        return "Pass forecast"
    if "/cards/" in path or "card_frame" in path or "/card_role_emblems/" in path:
        return "card face or inspection"
    if "/items/" in path or "/equipment/" in path:
        return "loot, item or equipment display"
    if "/tiles/" in path:
        return "board overlay or terrain"
    if "/turn_order_ink/" in path or "/portraits/" in path or "umbra_presence" in path:
        return "initiative rail"
    if "/icons/" in path:
        return "action, intent or HUD icon"
    if "/units/" in path:
        return "unit renderer or pose"
    return f"{screen} / {action}"


def reduce_take(directory, metadata):
    drivers = directory / "receipt.json"
    receipt = json.loads(drivers.read_text()) if drivers.exists() else {}
    result = {"take": str(directory), **metadata, "outcome": receipt.get("outcome"),
              "coverage": receipt.get("coverage", {}), "errors": receipt.get("errors", []),
              "combat_frames": 0, "entries": {}, "loads": {}, "scope": [], "preparation_ms": [],
              "trace_complete": bool(receipt)}
    path = directory / "frames.jsonl"
    if not path.exists():
        return result
    pending_entries = {}
    visits = defaultdict(int)
    with path.open() as frames:
        first = next(frames, None)
        if first is None:
            return result
        header = json.loads(first)
        result["native"] = header["native"]
        result["host"] = {key: header.get(key) for key in ("cpu", "renderer", "adapter", "display", "godot")}
        result["viewport"] = receipt.get("viewport", {})
        columns = header["columns"]
        wall_ms = 0.0
        for line in frames:
            if not line.endswith("\n"):
                result["trace_complete"] = False
                break
            frame = json.loads(line)
            if not isinstance(frame, list):
                continue
            row = dict(zip(columns, frame))
            wall_ms += row["draw_interval_ms"]
            context, events = row["context"], row["events"]
            if context.get("live_mode") == "combat":
                result["combat_frames"] += 1
            room = context.get("live_room")
            pending = context.get("pending_room")
            generation = context.get("room_generation")
            video_bytes = row["monitors"].get(TEXTURE_MEMORY_MONITOR)
            if room and pending and room != pending:
                pending_entries.setdefault((generation, pending), (wall_ms - row["draw_interval_ms"], video_bytes))
            if room and (generation, room) in pending_entries:
                started, start_bytes = pending_entries.pop((generation, room))
                visits[room] += 1
                result["entries"][f"{room} #{visits[room]}"] = {
                    "ms": wall_ms - started,
                    "texture_delta_bytes": video_bytes - start_bytes if video_bytes is not None and start_bytes is not None else None,
                    "mode": context["live_mode"],
                }
            for key, event in events.items():
                operation, domain, asset = (key.split(":", 2) + ["", ""])[:3]
                if operation not in ("texture_load", "texture_flip") or domain != "combat":
                    continue
                entry = result["loads"].setdefault(key, {
                    "operation": operation, "path": asset, "size": texture_size(asset), "count": 0,
                    "total_us": 0, "peak_frame_us": 0, "first_us": event["total_us"], "first_frame": row["frame"],
                    "room": room, "screen": context.get("screen", ""), "action": context.get("action", ""),
                    "phase": context.get("phase", ""), "trigger_stack": event.get("trigger_stack", []),
                })
                entry["count"] += event["count"]
                entry["total_us"] += event["total_us"]
                entry["peak_frame_us"] = max(entry["peak_frame_us"], event["total_us"])
            if "combat_texture_scope" in events:
                result["scope"].append({**events["combat_texture_scope"], "video_texture_bytes": video_bytes})
            prep = row["hitch_phase_times_us"].get("combat_texture_preparation:wall")
            if prep is not None:
                result["preparation_ms"].append(prep / 1000)
    return result


def compare(takes):
    pairs = defaultdict(dict)
    for take in takes:
        pairs[take["workload"], take["profile"]][take["variant"]] = take
    comparisons = []
    for (workload, profile), pair in pairs.items():
        if pair.keys() != {"baseline", "candidate"}:
            continue
        before, after = pair["baseline"], pair["candidate"]
        if any(not take.get("native") or not take["trace_complete"] or take["exit"] for take in (before, after)):
            continue
        if before["host"] != after["host"]:
            continue
        if workload == "tour-83":
            baseline = before["coverage"].get("tharokh_resume_wall_us")
            candidate = after["coverage"].get("tharokh_resume_wall_us")
            if baseline and candidate:
                comparisons.append({"workload": workload, "profile": profile, "room": "Tharokh resume",
                                    "baseline_ms": baseline / 1000, "candidate_ms": candidate / 1000,
                                    "ratio": candidate / baseline})
            continue
        for room, entry in after["entries"].items():
            base = before["entries"].get(room)
            if base and base["ms"] and base["mode"] == entry["mode"] and entry["mode"] in ("combat", "pre_battle"):
                comparisons.append({"workload": workload, "profile": profile, "room": room,
                                    "baseline_ms": base["ms"], "candidate_ms": entry["ms"],
                                    "ratio": entry["ms"] / base["ms"],
                                    "baseline_texture_delta_bytes": base["texture_delta_bytes"],
                                    "candidate_texture_delta_bytes": entry["texture_delta_bytes"]})
    return comparisons


def report(output):
    takes = [reduce_take(path.parent, json.loads(path.read_text())) for path in sorted(output.glob("*/*/*/take.json"))]
    if not takes:
        raise ValueError(f"No take.json files under {output}")
    comparisons = compare(takes)
    criteria = {}
    for workload, outcome in (("demo-7", "tharokh_fight_end"), ("tour-83", "tour_complete")):
        for profile in ("normal", "background"):
            take = next((item for item in takes if (item["workload"], item["profile"], item["variant"])
                         == (workload, profile, "candidate")), None)
            comparison = [item for item in comparisons if (item["workload"], item["profile"]) == (workload, profile)]
            label = f"{workload} / {profile}"
            if (not take or not take.get("native") or not take["trace_complete"] or take["outcome"] != outcome
                    or take["exit"] or take["errors"] or not take["combat_frames"] or not comparison):
                criteria[label] = "UNVERIFIED"
            else:
                loads = any(item["operation"] == "texture_load" for item in take["loads"].values())
                criteria[label] = "FAIL" if loads or any(item["ratio"] > ENTRY_LIMIT for item in comparison) else "PASS"
    (output / "combat-textures.json").write_text(
        json.dumps({"takes": takes, "entries": comparisons, "native_acceptance": criteria}, indent=2) + "\n")
    lines = ["# Combat texture census", "",
             "Costs are main-thread cache-miss spans, including imports and source texture publication. "
             "Flips are listed separately. Dimensions come from the source PNG. Candidate scope bytes are an RGBA8 estimate.",
             "Room-entry wall time spans the first frame of the pending travel and the first frame of the destination. "
             "The Tharokh resume uses the loading-cover handoff timestamp.", "",
             "Native takes use a fresh runtime and shared host file cache. Background takes use macOS taskpolicy.", "",
             "## Native acceptance", "",
             *[f"- {label} — {status}" for label, status in criteria.items()], ""]
    for take in takes:
        lines += [f"## {take['workload']} / {take['profile']} / {take['variant']}", "",
                  f"{'Native' if take.get('native') else 'Headless or missing trace'} · exit {take['exit']} · "
                  f"{take['outcome']} · {take['combat_frames']} combat frames · "
                  f"{sum(e['count'] for e in take['loads'].values() if e['operation'] == 'texture_load')} texture loads.", ""]
        if take["errors"]:
            lines += [f"Driver errors — {take['errors']}", ""]
        if take["scope"]:
            scope = max(take["scope"], key=lambda item: item["rgba8_bytes"])
            lines += [f"Largest encounter scope retained {scope['textures']} textures, {scope['rgba8_bytes'] / MIB:.2f} MiB RGBA8.", ""]
        if take["preparation_ms"]:
            prep = take["preparation_ms"]
            lines += [f"Preparation wall median {statistics.median(prep):.2f} ms, max {max(prep):.2f} ms across {len(prep)} encounters.", ""]
        if take["loads"]:
            lines += ["| Path | Size | First use | Action / phase | Count | First / peak-frame ms |",
                      "|---|---|---|---|---:|---:|"]
            for entry in sorted(take["loads"].values(), key=lambda item: (item["path"], item["operation"])):
                first = trigger(entry["path"], entry["screen"], entry["action"], entry["trigger_stack"])
                size = "×".join(map(str, entry["size"])) if entry["size"] else "unavailable"
                lines.append(f"| `{entry['path']}` | {size} | {first} ({entry['operation']}) | "
                             f"{entry['action']} / {entry['phase']} | {entry['count']} | "
                             f"{entry['first_us'] / 1000:.3f} / {entry['peak_frame_us'] / 1000:.3f} |")
            lines.append("")
    if comparisons:
        lines += ["## Matched native room entries", "", "| Workload / profile | Entry | Baseline / candidate ms | Change | Limit | Texture memory delta, base / candidate MiB |",
                  "|---|---|---:|---:|---|---:|"]
        for item in comparisons:
            deltas = [item.get(f"{variant}_texture_delta_bytes") for variant in ("baseline", "candidate")]
            memory = " / ".join("—" if delta is None else f"{delta / MIB:+.2f}" for delta in deltas)
            lines.append(f"| {item['workload']} / {item['profile']} | {item['room']} | "
                         f"{item['baseline_ms']:.2f} / {item['candidate_ms']:.2f} | "
                         f"{item['ratio'] - 1:+.1%} | {'PASS' if item['ratio'] <= ENTRY_LIMIT else 'FAIL'} | {memory} |")
    else:
        lines += ["No matched native entry timings are available."]
    destination = output / "combat-textures.md"
    destination.write_text("\n".join(lines) + "\n")
    print(f"PERF-161 REPORT: {len(takes)} takes, {len(comparisons)} matched native entries, {destination}")
    for take in takes:
        misses = sum(entry["count"] for entry in take["loads"].values() if entry["operation"] == "texture_load")
        print(f"PERF-161 TAKE RESULT: {take['workload']} {take['profile']} {take['variant']} "
              f"exit={take['exit']} outcome={take['outcome']} combat_frames={take['combat_frames']} texture_loads={misses}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("collect", "report"))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--prepared", type=Path)
    parser.add_argument("--workloads", choices=WORKLOADS, nargs="+", default=list(WORKLOADS))
    parser.add_argument("--profiles", choices=("normal", "background"), nargs="+", default=["normal", "background"])
    parser.add_argument("--variants", choices=("baseline", "candidate"), nargs="+", default=["baseline", "candidate"])
    parser.add_argument("--seconds", type=int)
    parser.add_argument("--stop-after", type=int, default=0)
    parser.add_argument("--headless", action="store_true")
    args = parser.parse_args()
    if args.mode == "collect":
        collect(args)
    report(args.output)


if __name__ == "__main__":
    main()
