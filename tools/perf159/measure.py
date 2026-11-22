#!/usr/bin/env python3
"""Compare the perf-159 focus route and release identity in the same worktree."""
import argparse
from contextlib import ExitStack
import importlib.util
import json
import os
from pathlib import Path
from statistics import median
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
TASK = "perf-159"
NORMAL_PAIRS = 2
BACKGROUND_PAIRS = 5
LOAD_WORKERS = 4
HEADLESS_FPS = 60
NATIVE_TIMEOUT_SECONDS = 180
NORMAL_BOSS_REDUCTION = 0.10
FOCUS_INPUTS = ("board-dpad", "stick", "mouse-tile")
SPEC = importlib.util.spec_from_file_location("perf134_measure", TOOLS / "perf134/measure.py")
STRICT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(STRICT)
ENVIRONMENTS = {
    side: {
        "LABYRINTH_PERF159_BASELINE": str(int(side == "A")),
        "LABYRINTH_PERF154_BASELINE": "0",
        "LABYRINTH_PERF148_BASELINE": "0",
        "LABYRINTH_PERF157_BASELINE": "0",
        "LABYRINTH_BOARD_REDRAW_BASELINE": "0",
        "LABYRINTH_BOARD_REDRAW_TRACE": "timing",
        "LABYRINTH_CEL_LOOK": "all",
    }
    for side in "AB"
}


def run_take(args, side, directory, script):
    directory.mkdir()
    probe_args = [f"--output={directory}", f"--fixtures={args.fixtures}"]
    if args.mode == "attribution":
        probe_args.append("--detail")
    if args.native:
        command = [
            sys.executable, str(TOOLS / "visual_probe_runner.py"), str(script),
            "--task-id", TASK, "--no-headless", "--display-driver", "macos",
            "--rendering-driver", "metal", "--rendering-method", "mobile",
            "--audio-driver", "Dummy", "--min-images", "0",
            "--timeout", str(NATIVE_TIMEOUT_SECONDS), "--result-manifest", str(directory / "runner.json"),
            "--", *probe_args,
        ]
    else:
        command = [
            sys.executable, str(TOOLS / "godot_task_runner.py"), "--task-id", TASK,
            "--stream", "--", "godot", "--headless", "--fixed-fps", str(HEADLESS_FPS),
            "--path", str(ROOT), "--script", str(script), "--", *probe_args,
        ]
    if args.qos == "background":
        command[:0] = ["taskpolicy", "-c", "background"]
    STRICT.run(command, ROOT, ENVIRONMENTS[side])


def stop_load(worker):
    worker.terminate()
    worker.wait()


def pair_order(args):
    if args.mode != "timing":
        return "AB"
    pairs = args.pairs if args.pairs is not None else (BACKGROUND_PAIRS if args.qos == "background" else NORMAL_PAIRS)
    return "".join("AB" if index % 2 == 0 else "BA" for index in range(pairs))


def focus_pairs(args):
    order = pair_order(args)
    script = TOOLS / "perf154/probe.gd" if args.mode == "navigation" else Path(__file__).with_name("probe.gd")
    samples = {"A": [], "B": []}
    witness = None
    with ExitStack() as cleanup:
        for _ in range(args.load_workers if args.mode in ("timing", "attribution") else 0):
            worker = subprocess.Popen(["yes"], stdout=subprocess.DEVNULL)
            cleanup.callback(stop_load, worker)
        for index, side in enumerate(order, 1):
            directory = args.output / f"{index}-{side}"
            run_take(args, side, directory, script)
            take = json.loads((directory / "navigation.json").read_text())
            if take["unfocused"] or take["headless"] == args.native:
                raise ValueError(f"Invalid display witness in {directory}")
            intervals = [
                value for cohort in take["samples"].values() for row in cohort for value in row["interval_usec"]
            ]
            if sum(900_000 <= value <= 1_200_000 for value in intervals) >= 3:
                raise ValueError(f"Repeated one-second frame intervals invalidate {directory}")
            identity = (take["fixture_sha256"], take["receipts"])
            if witness is not None and witness != identity:
                fields = STRICT.mismatched_fields(witness[1], identity[1])
                raise ValueError(f"Navigation receipt mismatch in {directory}: {fields or 'fixture digest'}")
            witness = identity
            samples[side].append(take["samples"])
            if index % 2 == 0 and args.mode == "timing":
                for route in FOCUS_INPUTS:
                    a, b = [input_median(samples[arm][-1][f"tharokh/{route}"]) for arm in "AB"]
                    print_pair(index // 2, order[index - 2:index], route, a, b)
    print(f"PERF-159 NAVIGATION RECEIPTS: PASS ({len(witness[1])} cohorts, {len(order)} takes)", flush=True)
    if args.mode == "navigation":
        return 0
    return report_pairs(args, samples)


def input_median(rows):
    return median(row["interval_usec"][0] for row in rows) / 1000


def print_pair(number, arm_order, route, a, b):
    print(f"PERF-159 PAIR {number} ({arm_order}) tharokh/{route}: "
          f"{a:.3f} -> {b:.3f} ms ({a - b:+.3f} ms, {1 - b / a:+.1%})", flush=True)


def report_pairs(args, samples):
    metrics = {}
    comparisons = {}
    gates = {}
    order = pair_order(args)
    for kind in ("normal", "tharokh"):
        for route in FOCUS_INPUTS:
            key = f"{kind}/{route}"
            metrics[key] = {}
            for side, takes in samples.items():
                rows = [row for take in takes for row in take[key]]
                metrics[key][side] = {
                    "first": STRICT.histogram([row["interval_usec"][0] for row in rows]),
                    "window": STRICT.histogram([value for row in rows for value in row["interval_usec"]]),
                }
            pairs = []
            for index, (rows_a, rows_b) in enumerate(zip(samples["A"], samples["B"]), 1):
                a, b = input_median(rows_a[key]), input_median(rows_b[key])
                pairs.append({"pair": index, "order": order[(index - 1) * 2:index * 2],
                              "baseline_ms": a, "candidate_ms": b, "delta_ms": a - b, "reduction": 1 - b / a})
            deltas = [pair["delta_ms"] for pair in pairs]
            reductions = [pair["reduction"] for pair in pairs]
            center = median(deltas)
            spread = max(deltas) - min(deltas)
            comparisons[key] = {
                "pairs": pairs, "median_delta_ms": center, "spread_ms": spread,
                "median_reduction": median(reductions), "spread_reduction": max(reductions) - min(reductions),
            }
            before, after = (metrics[key][side]["first"] for side in "AB")
            if args.mode == "timing" and kind == "tharokh":
                if args.qos == "background":
                    passed = all(delta >= 0 for delta in deltas)
                    if center > 0:
                        passed = passed and center > spread
                else:
                    passed = 1 - after["median_ms"] / before["median_ms"] >= NORMAL_BOSS_REDUCTION
                gates[key] = passed
                print(f"PERF-159 {key} {'PASS' if passed else 'FAIL'} "
                      f"(paired median {center:+.3f} ms, spread {spread:.3f} ms; "
                      f"pooled median {before['median_ms']:.3f} -> {after['median_ms']:.3f} ms, "
                      f"p95 {before['p95_ms']:.3f} -> {after['p95_ms']:.3f} ms)", flush=True)
    report = {"native": args.native, "qos": args.qos, "mode": args.mode, "order": order,
              "load_workers": args.load_workers, "histograms": metrics, "paired_medians": comparisons,
              "acceptance": gates}
    (args.output / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
    return int(args.mode == "timing" and not all(gates.values()))


def check_identity(args):
    if args.mode == "forecast":
        for side in "AB":
            run_take(args, side, args.output / side, TOOLS / "perf140/probe.gd")
        before, after = (json.loads((args.output / side / "forecast-receipts.json").read_text()) for side in "AB")
        fields = STRICT.mismatched_fields(before, after)
        if fields:
            raise ValueError(f"Perf-140 receipt mismatches: {fields}")
        count = sum("steps" in row for row in before.values())
        print(f"PERF-140 IDENTITY: PASS ({count} forecasts, {len(before) - count} badge receipts)")
        return 0
    projects = dict.fromkeys("AB", ROOT)
    if args.native:
        failures = []
        for state in STRICT.CAPTURES:
            difference = STRICT.capture(projects, args.output, state, args.fixtures, TASK, ENVIRONMENTS, enforce=False)
            if difference.get("error") or difference["different_pixels"] or difference["mismatched_state_fields"]:
                failures.append(state)
        count = len(STRICT.CAPTURES)
        print(f"PERF-159 STRICT PIXELS: {count - len(failures)}/{count} states identical")
        return int(bool(failures))
    STRICT.headless_receipts(projects, args.output, args.fixtures, TASK, ENVIRONMENTS)
    print(f"PERF-159 STRICT RECEIPTS: PASS ({len(STRICT.CAPTURES)} states)")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("timing", "attribution", "navigation", "forecast", "strict"), default="timing")
    parser.add_argument("--native", action="store_true")
    parser.add_argument("--qos", choices=("normal", "background"), default="normal")
    parser.add_argument("--load-workers", type=int)
    parser.add_argument("--pairs", type=int, help="Alternating AB and BA pairs (background defaults to five)")
    parser.add_argument("--fixtures", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.load_workers is None:
        args.load_workers = LOAD_WORKERS if args.mode == "timing" else 0
    if args.load_workers < 0 or (args.native and args.mode == "forecast"):
        parser.error("Invalid worker count or display mode")
    if args.pairs is not None and (args.pairs < 1 or args.mode != "timing"):
        parser.error("--pairs requires timing mode and a positive count")
    if args.mode == "strict" and args.qos != "normal":
        parser.error("Run strict identity in normal QoS")
    args.fixtures = args.fixtures.resolve(strict=True)
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=False)
    (args.output / ".gdignore").touch()
    if args.mode in ("strict", "forecast"):
        return check_identity(args)
    return focus_pairs(args)


if __name__ == "__main__":
    raise SystemExit(main())
