#!/usr/bin/env python3
"""Matched perf-168 controller arrivals and exact native-frame comparison."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import statistics
import subprocess
import sys
from tempfile import TemporaryDirectory

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tools"))
from visual_probe_runner import decode_png

BASE_REVISION = "119c9c4271655a1be1f931b8fd6e402da434ae59"
CASES = ("combat", "elite", "guardian", "campfire", "event", "scavenger", "treasure", "graftwright")
PHASES = ("map_open", "map_a", "travel", "arrival")
PROFILES = ("normal", "background")
FRAMES = ("map", "walk", "travel", "arrival")
PAIRS = 5
ITERATIONS = 5
TIMEOUT = 900
BACKGROUND_RATIO = 0.50


def git(project: Path, *arguments: str) -> bytes:
    return subprocess.check_output(["git", "--no-optional-locks", "-C", str(project), *arguments])


def take(args: argparse.Namespace, project: Path, label: str, profile: str) -> dict:
    folder = args.output / label
    folder.mkdir()
    script = str(HERE / "arrival_probe.gd")
    if args.headless:
        command = [sys.executable, str(ROOT / "tools/godot_task_runner.py"), "--task-id", "perf-168",
                   "--timeout", str(TIMEOUT), "--stream", "--", "godot", "--headless",
                   "--path", str(project), "--script", script]
    else:
        command = [sys.executable, str(ROOT / "tools/visual_probe_runner.py"), "--task-id", "perf-168",
                   "--project", str(project), "--no-headless", "--display-driver", "macos",
                   "--audio-driver", "Dummy", "--rendering-driver", "metal",
                   "--timeout", str(TIMEOUT), "--min-images", "0"]
        if args.capture:
            command += ["--expect-size", "1920x1080", "--proof-contract", str(HERE / "visual_contract.json"),
                        "--result-manifest", str(folder / "manifest.json"),
                        "--godot", str(ROOT / "tools/perf134/capture_godot.sh")]
        command.append(script)
    command += ["--", f"--output={folder}", f"--iterations={args.iterations}"]
    if args.capture:
        command.append("--capture")
    for case in args.case:
        command.append(f"--case={case}")
    if profile == "background":
        command = ["/usr/sbin/taskpolicy", "-c", "background", *command]
    env = {**os.environ, "LABYRINTH_HITCH_TRACE": str(int(args.attribution)),
           "LABYRINTH_CEL_LOOK": "all", "LABYRINTH_DISABLE_STEAM": "1",
           "LABYRINTH_PROBE_WINDOW": "1", "SteamDeck": "1"}
    metadata = {"revision": git(project, "rev-parse", "HEAD").decode().strip(),
                "runtime_diff_sha256": hashlib.sha256(git(project, "diff", "--binary", "HEAD", "--",
                                                        "scripts", "scenes", "data")).hexdigest(),
                "folder": str(project), "command": command, "load_before": os.getloadavg()}
    untracked = git(project, "ls-files", "-z", "--others", "--exclude-standard", "--", "scripts", "scenes", "data")
    metadata["untracked_runtime_sha256"] = {path: hashlib.sha256((project / path).read_bytes()).hexdigest()
                                            for path in os.fsdecode(untracked).split("\0") if path}
    print(f"PERF168 {label}", flush=True)
    with TemporaryDirectory(prefix="scratch-", dir=folder) as scratch, (folder / "godot.log").open("w") as log:
        if args.capture:
            env["PERF134_CAPTURE_MOVIE"] = str(Path(scratch) / "clock.avi")
            command.extend(["--fixed-fps", "60"])
        result = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, check=False)
    metadata["load_after"] = os.getloadavg()
    (folder / "metadata.json").write_text(json.dumps(metadata, indent=2))
    if result.returncode:
        raise RuntimeError(f"{label} failed ({result.returncode}). See {folder / 'godot.log'}.")
    data = json.loads((folder / "arrival.json").read_text())
    cases = args.case or CASES
    expected = {(case, index) for case in cases for index in range(1 if args.capture else args.iterations)}
    actual = {(sample["case"], sample["index"]) for sample in data["samples"]}
    if actual != expected or len(data["samples"]) != len(expected):
        raise RuntimeError(f"{label} did not exercise every requested transition.")
    if data["native"] == args.headless or data["focus_losses"] or data["invalid_intervals"]:
        raise RuntimeError(f"{label} has invalid delivery conditions.")
    if not args.headless and (data["viewport"] != [1920, 1080] or data["ui_scale"] != 1.0):
        raise RuntimeError(f"{label} did not use 1920x1080 at 100% UI scale.")
    return data


def compare_images(folder: Path) -> bool:
    differences = []
    for case in CASES:
        for frame in FRAMES:
            name = f"{case}_{frame}.png"
            left = decode_png(folder / "base" / name)
            right = decode_png(folder / "candidate" / name)
            fields = ("width", "height", "channels", "color_type", "rows")
            if any(left[key] != right[key] for key in fields):
                differences.append(name)
    (folder / "pixels.json").write_text(json.dumps({"compared": len(CASES) * len(FRAMES), "different": differences}, indent=2))
    print("PERF168 PIXELS " + ("PASS" if not differences else "FAIL: " + ", ".join(differences)))
    return not differences


def percentile(ordered: list[int], quantile: float) -> int:
    return ordered[math.ceil(quantile * len(ordered)) - 1]


def stats(data: dict, phase: str, case: str, cold: bool | None = None) -> dict:
    rows = [row for row in data["samples"] if (case == "all" or row["case"] == case)
            and (cold is None or (row["index"] == 0) == cold)]
    frames = sorted(value for row in rows for value in row["intervals"][phase])
    if not frames:
        raise RuntimeError(f"Missing {phase} intervals for {case}.")
    return {"frames": len(frames), "p50": percentile(frames, .50), "p95": percentile(frames, .95),
            "p99": percentile(frames, .99), "p99.9": percentile(frames, .999), "max": frames[-1],
            "mean": statistics.mean(frames), "over_16_67": sum(x > 16667 for x in frames),
            "over_20": sum(x > 20000 for x in frames), "over_33_33": sum(x > 33333 for x in frames),
            "walk_median_usec": statistics.median(row["map_walk_usec"] for row in rows),
            "door_to_arrival_median_usec": statistics.median(row["door_to_arrival_usec"] for row in rows)}


def check_pair(left: dict, right: dict) -> None:
    fields = ("native", "driver", "display", "godot", "os", "cpu", "adapter", "viewport", "ui_scale",
              "frame_cap", "dwell_frames")
    if any(left[key] != right[key] for key in fields):
        raise RuntimeError("Pair used different renderer, hardware or viewport settings.")
    receipts = lambda data: {(row["case"], row["index"]): row["receipt"] for row in data["samples"]}
    if receipts(left) != receipts(right):
        raise RuntimeError("Room layout, persisted state or analytics receipts differed within a pair.")


def metric_text(values: dict) -> str:
    return " / ".join(f"{values[m] / 1000:.2f}" for m in ("p50", "p95", "p99", "p99.9", "max"))


def timing_report(results: dict, args: argparse.Namespace) -> bool:
    basis = "Headless process frames" if args.headless else "Native post-draw intervals"
    lines = ["# perf-168 matched arrivals", "", f"{basis} in ms. Statistics use nearest rank.",
             "First traversal per destination is retained. A take uses a fresh process. Later destinations can share cached art.",
             "Map A covers the button press through the frame showing door travel. Arrival covers the first destination draw and seven following draws.",
             "Map-open and door-travel intervals are reported separately.", "",
             "| Profile | Phase | Destination | Base p50 / p95 / p99 / p99.9 / max | Candidate p50 / p95 / p99 / p99.9 / max | p99.9 / max change | Frames base / candidate | Gate |",
             "|---|---|---|---|---|---|---|---|"]
    passed = True
    report = {}
    for profile, pairs in results.items():
        grouped = {side: {"samples": [row for pair in pairs for row in pair[side]["samples"]]}
                   for side in ("base", "candidate")}
        ratio = BACKGROUND_RATIO if profile == "background" else 1.0
        profile_report = report.setdefault(profile, {})
        for phase in PHASES:
            for case in ("all", *(args.case or CASES)):
                base = stats(grouped["base"], phase, case)
                candidate = stats(grouped["candidate"], phase, case)
                per_pair = [{side: stats(pair[side], phase, case) for side in ("base", "candidate")} for pair in pairs]
                gate = case == "all" and phase in ("map_a", "arrival") and not args.headless
                meets = all(candidate[key] <= base[key] * ratio for key in ("p99.9", "max"))
                passed = passed and (not gate or meets)
                delta = " / ".join(f"{candidate[key] / base[key] - 1:+.1%}" for key in ("p99.9", "max"))
                lines.append(f"| {profile} | {phase} | {case} | {metric_text(base)} | {metric_text(candidate)} | "
                             f"{delta} | {base['frames']} / {candidate['frames']} | "
                             f"{('PASS' if meets else 'FAIL') if gate else '—'} |")
                row = {"base": base, "candidate": candidate, "pairs": per_pair, "gate_pass": meets if gate else None}
                if args.iterations > 1:
                    row["first"] = {side: stats(grouped[side], phase, case, True) for side in grouped}
                    row["repeat"] = {side: stats(grouped[side], phase, case, False) for side in grouped}
                profile_report[f"{phase}/{case}"] = row
    (args.output / "report.md").write_text("\n".join(lines) + "\n")
    (args.output / "report.json").write_text(json.dumps(report, indent=2))
    return passed


def attribution_report(results: dict, output: Path) -> None:
    first_pair = next(iter(results.values()))[0]
    basis = "Native post-draw intervals" if first_pair["base"]["native"] else "Headless process frames"
    lines = ["# perf-168 section attribution", "",
             f"{basis}. Sections are inclusive wall times in ms. Load spans include nested resource loads and cached lookups. "
             "Checkpoint time can include map analytics. Base reports the enclosing checkpoint span for that overlap.", "",
             "| Profile | Side | Destination | Input dispatch | Move generation | Checkpoint hold / storage | Analytics (measured) | Hidden overlay prepare / visible choices | Max interval map A / arrival |",
             "|---|---|---|---:|---:|---:|---:|---:|---:|"]
    peak_frames = []
    for profile, pairs in results.items():
        for side in ("base", "candidate"):
            for pair in pairs:
                for row in pair[side]["samples"]:
                    def section(*names: str) -> float:
                        return sum(row["phases"].get(name, {}).get("total_usec", 0) for name in names) / 1000

                    maxima = [max(row["intervals"][phase]) / 1000 for phase in ("map_a", "arrival")]
                    overlay = section(*(name for name in row["phases"] if name.startswith("room_overlay_prepare_")))
                    lines.append(f"| {profile} | {side} | {row['case']} | {row['dispatch_usec'] / 1000:.2f} | "
                                 f"{row['generation_usec'] / 1000:.2f} | {section('combat_checkpoint_hold_total'):.2f} / "
                                 f"{section('combat_checkpoint_persist_storage'):.2f} | "
                                 f"{section('room_move_analytics', 'room_map_analytics_flush', 'refresh_ui_dialogue_and_tracker'):.2f} | "
                                 f"{overlay:.2f} / {section('refresh_ui_choice_bar_total', 'choice_event_overlay'):.2f} | "
                                 f"{maxima[0]:.2f} / {maxima[1]:.2f} |")
                    for phase in PHASES:
                        peak = max(row["attribution"][phase], key=lambda frame: frame["interval_usec"])
                        loads = sorted(((key.removeprefix("load:").rsplit("/", 1)[-1], value["total_us"])
                                        for key, value in peak["loads"].items() if key.startswith("load:")),
                                       key=lambda entry: entry[1], reverse=True)[:3]
                        top = ", ".join(f"{name} {usec / 1000:.2f}" for name, usec in loads) or "—"
                        peak_frames.append(f"| {profile} | {side} | {row['case']} | {phase} | "
                                           f"{peak['interval_usec'] / 1000:.2f} | {top} | "
                                           f"{sum(peak['mounted_nodes'].values())} |")
    lines += ["", "## Peak frames", "",
              "| Profile | Side | Destination | Phase | Interval | Top texture spans | Mounted nodes |",
              "|---|---|---|---|---:|---|---:|", *peak_frames]
    lines += ["", "Each take's arrival.json contains frame-local texture paths and spans, hidden preview and scene preparation phases, "
              "checkpoint diagnostics, all refresh sections, and renderer/node/memory monitors."]
    (output / "attribution.md").write_text("\n".join(lines) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", type=Path, default=ROOT.parent / "perf-162")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--pairs", type=int, default=PAIRS)
    parser.add_argument("--iterations", type=int, default=ITERATIONS)
    parser.add_argument("--profile", choices=PROFILES, action="append", default=[])
    parser.add_argument("--case", choices=CASES, action="append", default=[])
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--capture", action="store_true")
    modes.add_argument("--attribution", action="store_true")
    parser.add_argument("--headless", action="store_true")
    args = parser.parse_args()
    if args.pairs < 1 or args.iterations < 1 or (args.capture and (args.headless or args.case or args.profile)):
        parser.error("Use positive counts and both complete native capture sets.")
    args.base = args.base.resolve()
    args.output = args.output.resolve()
    if args.base == ROOT or git(args.base, "rev-parse", "HEAD").decode().strip() != BASE_REVISION:
        parser.error(f"--base must be a separate checkout at {BASE_REVISION}.")
    if git(args.base, "status", "--porcelain", "--", "scripts", "scenes", "data", "project.godot"):
        parser.error("--base has runtime changes.")
    args.output.mkdir(parents=True)
    if args.capture:
        base = take(args, args.base, "base", "normal")
        candidate = take(args, ROOT, "candidate", "normal")
        check_pair(base, candidate)
        return 0 if compare_images(args.output) else 1
    projects = {"base": args.base, "candidate": ROOT}
    profiles = args.profile or PROFILES
    results = {profile: [] for profile in profiles}
    for index in range(args.pairs):
        order = ("base", "candidate") if index % 2 == 0 else ("candidate", "base")
        for profile in profiles if index % 2 == 0 else reversed(profiles):
            pair = {side: take(args, projects[side], f"pair-{index + 1}-{profile}-{side}", profile) for side in order}
            check_pair(pair["base"], pair["candidate"])
            results[profile].append(pair)
    if args.attribution:
        attribution_report(results, args.output)
        return 0
    passed = timing_report(results, args)
    print(f"PERF168 {'HEADLESS REPORT' if args.headless else 'NATIVE PASS' if passed else 'NATIVE FAIL'}")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
