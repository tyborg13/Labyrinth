#!/usr/bin/env python3
"""Interleave release/candidate confirms under normal and background QoS."""

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


ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
PROBE = HERE / "confirm_probe.gd"
PROFILES = ("normal", "background")
NATIVE_TIMEOUT = 900
PAIRS = 5
ITERATIONS = 5
TARGET_RATIO = 0.60
BASE_REVISION = "f9b159baf"


def percentile(values: list[int], quantile: float) -> int:
    return sorted(values)[math.ceil(quantile * len(values)) - 1]


def checkout(path: Path) -> str:
    return subprocess.check_output(
        ["git", "-C", str(path), "rev-parse", "HEAD"], text=True
    ).strip()


def take(args: argparse.Namespace, project: Path, label: str, profile: str) -> dict:
    folder = args.output / label
    folder.mkdir()
    if args.headless:
        command = [
            sys.executable, str(ROOT / "tools/godot_task_runner.py"), "--task-id", "perf-162",
            "--timeout", str(NATIVE_TIMEOUT), "--stream", "--", "godot", "--headless",
            "--path", str(project), "--script", str(PROBE),
        ]
    else:
        command = [
            sys.executable, str(ROOT / "tools/visual_probe_runner.py"), "--task-id", "perf-162",
            "--project", str(project), "--no-headless", "--display-driver", "macos",
            "--audio-driver", "Dummy", "--rendering-driver", "metal",
            "--min-images", "0", "--timeout", str(NATIVE_TIMEOUT), str(PROBE),
        ]
    command += ["--", f"--output={folder}", f"--iterations={args.iterations}"]
    command.extend(f"--case={case}" for case in args.case)
    if profile == "background":
        command = ["/usr/sbin/taskpolicy", "-c", "background", *command]
    environment = {
        **os.environ, "LABYRINTH_HITCH_TRACE": "1" if args.attribution else "0",
        "LABYRINTH_CEL_LOOK": "all", "LABYRINTH_DISABLE_STEAM": "1",
        "LABYRINTH_PROBE_WINDOW": "1", "SteamDeck": "1",
    }
    diff = subprocess.check_output(["git", "--no-optional-locks", "-C", str(project), "diff", "--binary", "HEAD", "--", "scripts", "spec", "tests"])
    metadata = {"project": str(project), "revision": checkout(project), "tracked_diff_sha256": hashlib.sha256(diff).hexdigest(),
                "command": command, "profile": profile, "load_before": os.getloadavg()}
    print(f"PERF162 {label}", flush=True)
    with (folder / "godot.log").open("w") as log:
        result = subprocess.run(command, cwd=ROOT, env=environment, stdout=log, stderr=subprocess.STDOUT)
    metadata["load_after"] = os.getloadavg()
    (folder / "metadata.json").write_text(json.dumps(metadata, indent=2))
    if result.returncode:
        raise RuntimeError(f"{label} failed ({result.returncode}); see {folder / 'godot.log'}")
    data = json.loads((folder / "confirm.json").read_text())
    if data["native"] == args.headless or data["focus_losses"] or data["invalid_intervals"]:
        raise RuntimeError(f"{label} has invalid delivery conditions")
    if data["viewport"] != [1920, 1080] or data["ui_scale"] != 1.0:
        raise RuntimeError(f"{label} did not use the requested viewport")
    if any(len(group["samples"]) != args.iterations for group in aggregate(data).values()) or not data["samples"]:
        raise RuntimeError(f"{label} did not complete every requested repetition")
    return data


def aggregate(take_data: dict) -> dict:
    grouped: dict = {}
    for sample in take_data["samples"]:
        group = grouped.setdefault(sample["case"], {"frames": [], "samples": [], "receipts": {}})
        group["frames"].extend(sample["intervals_usec"])
        group["samples"].append(sample)
        group["receipts"][sample["index"]] = sample["receipt"]
    return grouped


def stats(group: dict) -> dict:
    values = group["frames"]
    phase_maxima: dict = {}
    for row in group["samples"]:
        for name, phase in row["phases"].items():
            phase_maxima[name] = max(phase_maxima.get(name, 0), phase["max_usec"])
    phase_names = {
        "rules": [name for name in phase_maxima if name.startswith("choice_") and name.endswith("_rules")],
        "storage": ["combat_checkpoint_persist_storage", "choice_campfire_embrace_checkpoint"],
        "encoding": ["checkpoint_write_serialize"],
        "worker": ["checkpoint_write_worker"],
        "profile": ["choice_campfire_embrace_profile", "choice_campfire_strength_profile"],
        "history": ["choice_event_history"],
        "analytics": [name for name in phase_maxima if name.startswith("choice_") and name.endswith("_analytics")],
        "refresh": ["refresh_ui_total"],
        "overlay": ["choice_event_overlay", "choice_graft_result_overlay", "shop_inventory"],
    }
    phase_totals = {
        label: statistics.median(
            sum(row["phases"].get(name, {}).get("total_usec", 0) for name in names)
            for row in group["samples"]
        )
        for label, names in phase_names.items()
    }
    phase_totals["texture_load"] = statistics.median(
        sum(load["total_us"] for key, load in row["loads"].items() if key.startswith("load:"))
        for row in group["samples"]
    )
    commit_frames = []
    for row in group["samples"]:
        frames = row["frames_with_work"]["top_frames"]
        frame = max(frames, key=lambda item: sum(item["phase_usec"].get(key, 0) for key in phase_names["storage"]), default={})
        if any(frame.get("phase_usec", {}).get(key, 0) for key in phase_names["storage"]):
            commit_frames.append(frame["phase_usec"])
    commit_phases = {
        label: statistics.median(sum(frame.get(key, 0) for key in phase_names[label]) for frame in commit_frames)
        for label in ("rules", "storage", "profile", "history", "analytics", "refresh", "overlay")
    } if commit_frames else {}
    return {
        "p50": percentile(values, 0.50), "p95": percentile(values, 0.95),
        "p99": percentile(values, 0.99), "max": max(values),
        "over_16_67": sum(value > 16667 for value in values),
        "over_20": sum(value > 20000 for value in values),
        "over_33_33": sum(value > 33333 for value in values),
        "frames": len(values),
        "dispatch_median": statistics.median(row["dispatch_usec"] for row in group["samples"]),
        "completion_median": statistics.median(row["completion_usec"] for row in group["samples"]),
        "node_delta": max(row["nodes_after"] - row["nodes_before"] for row in group["samples"]),
        "orphan_max": max(row["orphans"] for row in group["samples"]),
        "phase_max_usec": phase_maxima,
        "phase_median_total_usec": phase_totals,
        "commit_frame_phase_median_usec": commit_phases,
    }


def summarize(results: dict, args: argparse.Namespace) -> bool:
    frame_basis = "headless process-frame intervals" if args.headless else "native post-draw intervals"
    lines = [
        "# perf-162 confirms", "",
        f"Interleaved pairs per QoS profile = {args.pairs}. Basis is {frame_basis}.",
        "Cells show median [min, max] over per-take statistics. Readback is excluded.",
        "",
        "| Profile | Confirm | Release p99 / max ms | Candidate p99 / max ms | Paired p99 / max delta % | Gate |",
        "|---|---|---|---|---|---|",
    ]
    passed = True
    report: dict = {}
    for profile, pairs in results.items():
        profile_rows = report.setdefault(profile, {})
        cases = set(pairs[0]["release"])
        if any(set(side) != cases for pair in pairs for side in pair.values()):
            raise RuntimeError(f"{profile} cases differ between takes")
        for case in pairs[0]["release"]:
            base = [stats(pair["release"][case]) for pair in pairs]
            candidate = [stats(pair["candidate"][case]) for pair in pairs]
            ratios = {
                metric: [right[metric] / left[metric] for left, right in zip(base, candidate)]
                for metric in ("p99", "max")
            }
            parity = all(
                pair["release"][case]["receipts"] == pair["candidate"][case]["receipts"]
                for pair in pairs
            )
            target = TARGET_RATIO if profile == "background" else 1.0
            eligible = all(statistics.median(values) <= target for values in ratios.values())
            passed = passed and parity and (args.headless or eligible)
            profile_rows[case] = {"release": base, "candidate": candidate,
                                  "paired_ratios": ratios, "receipts_equal": parity}
            def spread(values: list[float]) -> str:
                return f"{statistics.median(values):.2f} [{min(values):.2f}, {max(values):.2f}]"
            def timing(side: list[dict]) -> str:
                return " / ".join(spread([row[key] / 1000 for row in side]) for key in ("p99", "max"))
            deltas = " / ".join(spread([(ratio - 1) * 100 for ratio in values]) for values in ratios.values())
            gate = "proxy only" if args.headless else "PASS" if eligible else "FAIL"
            lines.append(f"| {profile} | {case} | {timing(base)} | {timing(candidate)} | {deltas} | {gate}; receipts {'match' if parity else 'differ'} |")
    if args.attribution and "background" in report:
        lines.extend([
            "", "## Background QoS candidate phase costs (ms)", "",
            "Median per-activation totals across takes. Checkpoint storage includes the main-thread wait for the worker.",
            "Encoding and disk worker wall time are diagnostic components of storage. Overlay and load spans can overlap refresh.",
            "Zero denotes no recorded span. These are action-window spans and include later presentation work.",
            "",
            "| Confirm | Rules | Checkpoint storage | Encode / worker | Profile | History | Analytics | Refresh / overlay | Load spans |",
            "|---|---:|---:|---:|---:|---:|---:|---:|---:|",
        ])
        for case, pair in report["background"].items():
            samples = [take["phase_median_total_usec"] for take in pair["candidate"]]
            ms = {key: statistics.median(row[key] for row in samples) / 1000 for key in samples[0]}
            lines.append(
                f"| {case} | {ms['rules']:.2f} | {ms['storage']:.2f} | {ms['encoding']:.2f} / {ms['worker']:.2f} "
                f"| {ms['profile']:.2f} | {ms['history']:.2f} | {ms['analytics']:.2f} "
                f"| {ms['refresh']:.2f} / {ms['overlay']:.2f} | {ms['texture_load']:.2f} |"
            )
        lines.extend([
            "", "## Background QoS checkpoint frame (ms)", "",
            "For each activation, select the instrumented frame with the largest checkpoint storage span.",
            "The checkpoint frame can follow the A-button dispatch during an authored animation.",
            "Overlapping overlay and refresh spans are inclusive.",
            "",
            "| Confirm | Rules | Checkpoint storage | Profile | History | Analytics | Refresh / overlay |",
            "|---|---:|---:|---:|---:|---:|---:|",
        ])
        for case, pair in report["background"].items():
            frames = [take["commit_frame_phase_median_usec"] for take in pair["candidate"]
                      if take["commit_frame_phase_median_usec"]]
            if not frames:
                lines.append(f"| {case} | — | — | — | — | — | — |")
                continue
            ms = {key: statistics.median(frame[key] for frame in frames) / 1000 for key in frames[0]}
            lines.append(
                f"| {case} | {ms['rules']:.2f} | {ms['storage']:.2f} | {ms['profile']:.2f} | {ms['history']:.2f} "
                f"| {ms['analytics']:.2f} | {ms['refresh']:.2f} / {ms['overlay']:.2f} |"
            )
    (args.output / "metrics.json").write_text(json.dumps(report, indent=2))
    (args.output / "report.md").write_text("\n".join(lines) + "\n")
    print(f"PERF162 REPORT {args.output / 'report.md'}", flush=True)
    print(f"PERF162 {'RECEIPT' if args.headless else 'NATIVE'} GATE: {'PASS' if passed else 'FAIL'}", flush=True)
    return passed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", type=Path, default=ROOT.parent / "release")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--attribution", action="store_true", help="enable load and input spans for diagnosis")
    parser.add_argument("--case", action="append", default=[])
    parser.add_argument("--profile", action="append", choices=PROFILES)
    parser.add_argument("--pairs", type=int, default=PAIRS)
    parser.add_argument("--iterations", type=int, default=ITERATIONS)
    args = parser.parse_args()
    args.base = args.base.resolve()
    args.output = args.output.resolve()
    if args.base == ROOT or args.pairs < 1 or args.iterations < 1:
        parser.error("Use a separate release worktree and positive sample counts")
    base_head = checkout(args.base)
    # Both revisions launch with this worktree's runners. The release project
    # must still match the original application content.
    base_diff = subprocess.check_output(
        ["git", "-C", str(args.base), "diff", "--name-only", BASE_REVISION, base_head, "--", ".",
         ":(exclude)tools/visual_probe_runner.py", ":(exclude)tools/godot_task_runner.py"],
        text=True,
    )
    if base_diff.strip():
        parser.error(f"Release project must match the content at {BASE_REVISION}")
    args.output.mkdir(parents=True)
    results = {profile: [] for profile in args.profile or PROFILES}
    for index in range(args.pairs):
        profiles = tuple(results) if index % 2 == 0 else tuple(reversed(results))
        for profile in profiles:
            worktrees = [("release", args.base), ("candidate", ROOT)]
            if index % 2: worktrees.reverse()
            pair = {}
            environment = None
            for side, project in worktrees:
                data = take(args, project, f"{profile}-{index + 1}-{side}", profile)
                observed = tuple(data[key] for key in ("godot", "cpu", "display", "renderer", "driver", "adapter", "os", "frame_cap"))
                if environment is not None and environment != observed:
                    raise RuntimeError("Base/candidate renderer or frame settings differ")
                environment = observed
                pair[side] = aggregate(data)
            results[profile].append(pair)
    return 0 if summarize(results, args) else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, ValueError) as error:
        print(f"PERF162 FAIL {error}", file=sys.stderr)
        raise SystemExit(1)
