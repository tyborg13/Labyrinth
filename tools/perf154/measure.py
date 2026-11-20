#!/usr/bin/env python3
"""Interleave controller navigation takes and check perf154 identity receipts."""
import argparse
from contextlib import ExitStack
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
PROBE = Path(__file__).with_name("probe.gd")
TASK = "perf-154b"
PAIR_ORDER = "ABBA"
LOAD_WORKERS = 4
NATIVE_TIMEOUT_SECONDS = 180
HEADLESS_FIXED_FPS = 60
FOCUS_COHORTS = {"board-dpad", "hand-dpad", "shoulder", "stick"}
ENVIRONMENTS = {
    side: {
        "LABYRINTH_PERF154_BASELINE": str(int(side == "A")),
        "LABYRINTH_CEL_LOOK": "all",
        "LABYRINTH_BOARD_REDRAW_BASELINE": "0",
        "LABYRINTH_PERF148_BASELINE": "0",
    }
    for side in "AB"
}
SPEC = importlib.util.spec_from_file_location("perf134_measure", TOOLS / "perf134/measure.py")
STRICT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(STRICT)


def run_take(args, side, directory, script=PROBE):
    directory.mkdir(parents=True, exist_ok=False)
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
            "--stream", "--", "godot", "--headless", "--fixed-fps", str(HEADLESS_FIXED_FPS),
            "--path", str(ROOT), "--script", str(script), "--", *probe_args,
        ]
    if args.qos == "background":
        command[0:0] = ["taskpolicy", "-c", "background"]
    STRICT.run(command, ROOT, ENVIRONMENTS[side])


def stop_load(worker):
    worker.terminate()
    worker.wait()


def run_navigation(args):
    pairs = "AB" if args.mode == "attribution" else PAIR_ORDER
    witness = None
    samples = {"A": [], "B": []}
    with ExitStack() as cleanup:
        for _ in range(args.load_workers):
            worker = subprocess.Popen(["yes"], stdout=subprocess.DEVNULL)
            cleanup.callback(stop_load, worker)
        for index, side in enumerate(pairs, 1):
            directory = args.output / f"{index}-{side}"
            run_take(args, side, directory)
            take = json.loads((directory / "navigation.json").read_text())
            if take["unfocused"] or take["headless"] == args.native:
                raise ValueError(f"Invalid display witness in {directory}")
            identity = (take["fixture_sha256"], take["receipts"])
            if witness is not None and identity != witness:
                baseline_rows, actual_rows = witness[1], identity[1]
                affected = sorted(
                    key for key in baseline_rows.keys() | actual_rows.keys()
                    if baseline_rows.get(key) != actual_rows.get(key)
                )
                raise ValueError(f"Navigation receipts differ at {directory}: {affected or 'fixture digest'}")
            witness = identity
            intervals = [
                duration
                for rows in take["samples"].values()
                for sample in rows for duration in sample["interval_usec"]
            ]
            if sum(900_000 <= duration <= 1_200_000 for duration in intervals) >= 3:
                raise ValueError(f"Repeated one-second intervals invalidate {directory}")
            samples[side].append(take["samples"])
    print("PERF-154 NAVIGATION RECEIPTS: PASS", flush=True)
    return report(args, samples)


def report(args, samples):
    cohorts = sorted(samples["A"][0])
    scopes = {
        "focus": [key for key in cohorts if key.split("/")[1] in FOCUS_COHORTS],
        "select": [key for key in cohorts if key.endswith("/select")],
        **{key: [key] for key in cohorts},
    }
    metrics = {}
    for name, keys in scopes.items():
        rows_by_side = {
            side: [row for take in takes for key in keys for row in take[key]]
            for side, takes in samples.items()
        }
        metrics[name] = {
            side: {
                "first": STRICT.histogram([row["interval_usec"][0] for row in rows]),
                "all": STRICT.histogram([duration for row in rows for duration in row["interval_usec"]]),
            }
            for side, rows in rows_by_side.items()
        }
    hits = {}
    required_reductions = {
        ("focus", "median_ms"): 0.0,
        ("focus", "p95_ms"): 0.0,
        ("select", "median_ms"): 0.3,
    }
    for name in ("focus", "select"):
        a, b = (metrics[name][side]["first"] for side in "AB")
        for metric in ("median_ms", "p95_ms"):
            reduction = 1 - b[metric] / a[metric]
            threshold = required_reductions.get((name, metric))
            verdict = "INFO"
            if threshold is not None:
                hits[f"{name} {metric}"] = reduction >= threshold
                verdict = "PASS" if hits[f"{name} {metric}"] else "FAIL"
            print(f"PERF-154 {name} {metric}: {verdict} "
                  f"({a[metric]:.3f} -> {b[metric]:.3f} ms, {reduction:+.1%} reduction)")
    # Count following frames as well. A short press cannot trade its hitch
    # for equivalent work immediately after that press.
    a, b = [sum(metrics[key][side]["all"]["over_33ms_count"] for key in cohorts) for side in "AB"]
    regressed = [
        key for key in cohorts
        if metrics[key]["B"]["all"]["over_33ms_count"] > metrics[key]["A"]["all"]["over_33ms_count"]
    ]
    hits["over 33 ms"] = not regressed
    print(f"PERF-154 frames over 33 ms: {'FAIL' if regressed else 'PASS'} ({a} -> {b})")
    if regressed:
        print(f"PERF-154 cohorts with more frames over 33 ms: {', '.join(regressed)}")
    result = {"qos": args.qos, "native": args.native, "load_workers": args.load_workers,
              "mode": args.mode, "histograms": metrics, "acceptance": hits}
    (args.output / "summary.json").write_text(json.dumps(result, indent=2) + "\n")
    return int(args.mode == "timing" and not all(hits.values()))


def run_identity(args):
    if args.mode == "forecast":
        for side in "AB":
            run_take(args, side, args.output / side, TOOLS / "perf140/probe.gd")
        name = "forecast-receipts.json"
        before, after = (json.loads((args.output / side / name).read_text()) for side in "AB")
        fields = STRICT.mismatched_fields(before, after)
        if fields:
            raise ValueError(f"Perf-140 receipt mismatches: {fields}")
        count = sum("steps" in row for row in before.values())
        print(f"PERF-140 IDENTITY: PASS ({count} forecasts, {len(before) - count} badge receipts)")
        return 0
    projects = dict.fromkeys("AB", ROOT)
    env = {side: {**ENVIRONMENTS[side], "LABYRINTH_BOARD_REDRAW_TRACE": "timing"} for side in "AB"}
    if args.native:
        failures = []
        for state in STRICT.CAPTURES:
            difference = STRICT.capture(projects, args.output, state, args.fixtures, TASK, env, enforce=False)
            if difference.get("error") or difference["different_pixels"] or difference["mismatched_state_fields"]:
                failures.append(state)
        print(f"PERF-154 STRICT PIXELS: {len(STRICT.CAPTURES) - len(failures)}/{len(STRICT.CAPTURES)} states identical")
        return int(bool(failures))
    STRICT.headless_receipts(projects, args.output, args.fixtures, TASK, env)
    print(f"PERF-154 STRICT RECEIPTS: PASS ({len(STRICT.CAPTURES)} states)")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("timing", "attribution", "strict", "forecast", "frame-strip"), default="timing")
    parser.add_argument("--qos", choices=("normal", "background"), default="normal")
    parser.add_argument("--native", action="store_true")
    parser.add_argument("--load-workers", type=int, default=LOAD_WORKERS)
    parser.add_argument("--fixtures", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.fixtures = args.fixtures.resolve(strict=True)
    args.output = args.output.resolve()
    if args.load_workers < 0 or (args.native and args.mode == "forecast"):
        parser.error("Invalid worker count or display mode")
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / ".gdignore").touch()
    if args.mode in ("strict", "forecast"):
        return run_identity(args)
    if args.mode == "frame-strip":
        import frame_strip
        return frame_strip.run(args, STRICT, ENVIRONMENTS, ROOT, TOOLS, TASK)
    return run_navigation(args)


if __name__ == "__main__":
    raise SystemExit(main())
