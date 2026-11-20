#!/usr/bin/env python3
"""Interleave release redraw routing and retained paint on the same fixture."""
import argparse
from collections import Counter, defaultdict
from contextlib import ExitStack
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
ROUTE_TOOLS = importlib.util.spec_from_file_location("perf138_measure", ROOT / "tools/perf138/measure.py")
route = importlib.util.module_from_spec(ROUTE_TOOLS)
ROUTE_TOOLS.loader.exec_module(route)

TASK_ID = "perf-148"
BASE_HEAD = "e3d3aba7f306de1f6ac289a6ca6d197c2ea90611"
ORDER = "ABBAAB"
CONFIRMS = ("A_confirm", "Y_pass")
DEFAULT_LOAD_WORKERS = 4
MINIMUM_REDUCTION = .5
NORMAL_TOLERANCE = 0.0
TARGETING_TASK = "perf-157"
TARGETING_BASE_HEAD = "52cd3916f7fdf334f745ae775bd0eebce7e8feb3"


def comparison_environment(side, targeting):
    return {
        "LABYRINTH_BOARD_REDRAW_BASELINE": "0",
        "LABYRINTH_CEL_LOOK": "all",
        "LABYRINTH_PERF148_BASELINE": "1" if side == "A" and not targeting else "0",
        "LABYRINTH_PERF157_BASELINE": "1" if side == "A" or not targeting else "0",
    }


def run_sample(fixtures, directory, side, mode, native, targeting=False):
    directory.mkdir()
    renderer = (
        ["--windowed", "--display-driver", "macos", "--rendering-method", "mobile",
         "--rendering-driver", "metal", "--audio-driver", "Dummy"]
        if native else ["--headless"]
    )
    task_id = TARGETING_TASK if targeting else TASK_ID
    fixture_route = "perf157/transition_route" if targeting else "perf148/fixture_route"
    command = [
        sys.executable, "tools/godot_task_runner.py", "--task-id", task_id,
        "--stream", "--", "godot", *renderer, "--fixed-fps", "60", "--path", ".",
        "--script", "tools/perf134/probe.gd", "--", f"--output={directory}",
        f"--fixtures={fixtures}", f"--board-redraw-route=res://tools/{fixture_route}.gd",
    ]
    if not native:
        command.append("--headless-check")
    environment = {**os.environ, **comparison_environment(side, targeting),
                   "SteamDeck": "0", "LABYRINTH_BOARD_REDRAW_TRACE": mode}
    print(f"{task_id.upper()} {directory.name} ({mode})", flush=True)
    with (directory / "run.log").open("w") as log:
        subprocess.run(command, cwd=ROOT, env=environment, stdout=log, stderr=subprocess.STDOUT, check=True)
    report = json.loads((directory / "summary.json").read_text())
    if (report["errors"] or report["headless"] == native or report["deck"] or report["orphan_nodes"]
            or report["size"] != [1920, 1080] or report["ui_scale"] != 1.0
            or set(report["cases"]) != {"normal", "tharokh"}):
        raise ValueError(f"Invalid fixture receipt in {directory}")
    validate_confirm_samples(report, directory)
    line = next(line for line in (directory / "run.log").read_text().splitlines()
                if line.startswith("PERF-135 PROBE: PASS"))
    print(line, flush=True)
    return report


def validate_confirm_samples(report, directory):
    for room in report["cases"]:
        for trigger in CONFIRMS:
            samples = confirm_rows([report], room, trigger)
            if not samples:
                raise ValueError(f"{directory}: {room}/{trigger} produced no confirm samples")
            for sample in samples:
                if not any(row["usec"] > 0 for row in confirm_draws(sample)):
                    frames = sorted({row["frame"] for row in sample["draws"]})
                    raise ValueError(f"{directory}: {room}/{trigger} has no timed board draws on "
                                     f"frame {sample.get('draw_frame')}; observed draw frames: {frames}")


def confirm_rows(reports, room, trigger=None):
    return [sample for report in reports for sample in report["cases"][room]["samples"]
            if sample["trigger"] in CONFIRMS and (trigger is None or sample["trigger"] == trigger)]


def confirm_draws(sample):
    frame = sample.get("draw_frame")
    return [row for row in sample["draws"] if row["frame"] == frame]


def draw_summary(samples):
    return route.load_fixture_tools().histogram([
        sum(row["usec"] for row in confirm_draws(sample)) for sample in samples
    ])


def attribution(samples):
    layers = defaultdict(lambda: {"calls": 0, "usec": 0, "reasons": Counter(),
                                 "sites": Counter(), "operations_usec": Counter()})
    for sample in samples:
        for row in confirm_draws(sample):
            key = row["kind"]
            if key == "scene_tile":
                key += f"/{row['depth_pass']}"
            layer = layers[key]
            layer["calls"] += 1
            layer["usec"] += row["usec"]
            layer["reasons"].update(row["reasons"])
            layer["sites"].update(row["sites"])
            layer["operations_usec"].update(row["operations"])
    return dict(sorted(layers.items(), key=lambda item: -item[1]["usec"]))


def transition_attribution(sample):
    before = sample["transition_paint"]["before"]
    after = sample["transition_paint"]["after"]
    draws = {"scene_tiles": Counter(), "bodies": Counter()}
    for row in sample["draws"]:
        if row["kind"] == "scene_tile":
            x, y = row["tile"]
            draws["scene_tiles"][f"{x},{y}/{row['depth_pass']}"] += 1
        elif row["kind"] in ("unit_body_outline", "unit_throw_shadow"):
            body = next((node for node in row["path"].split("/") if node.startswith("UnitBody_")), "")
            if body:
                draws["bodies"][body.removeprefix("UnitBody_")] += 1
    return {
        kind: {"draws": dict(sorted(counts.items())),
               "changed_receipts": sorted(key for key in before[kind].keys() | after[kind].keys()
                                          if before[kind].get(key) != after[kind].get(key))}
        for kind, counts in draws.items()
    } | {"live_clock_tiles": sorted(set(before["clock_tiles"]) | set(after["clock_tiles"]))}


def stop_load(worker):
    worker.terminate()
    worker.wait()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    fixture = parser.add_mutually_exclusive_group(required=True)
    fixture.add_argument("--base", type=Path, help="Clean release worktree for generating shared fixtures")
    fixture.add_argument("--fixtures", type=Path, help="Existing perf134 schema-3 fixture archive")
    parser.add_argument("--inputs-only", action="store_true")
    parser.add_argument("--native", action="store_true")
    parser.add_argument("--perf157", action="store_true", help="Compare targeting routing against the perf-157 release base")
    parser.add_argument("--load-workers", type=int, default=DEFAULT_LOAD_WORKERS)
    args = parser.parse_args()
    if args.load_workers < 0:
        parser.error("--load-workers must be nonnegative")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    task_id = TARGETING_TASK if args.perf157 else TASK_ID
    label = task_id.upper()
    base_head = TARGETING_BASE_HEAD if args.perf157 else BASE_HEAD
    if args.base:
        fixture_tools = route.load_fixture_tools()
        base = args.base.resolve()
        fixture_tools.validate_base(base, base_head)
        fixtures = fixture_tools.prepare_fixtures(base, output, task_id)
    else:
        fixtures = args.fixtures.resolve()

    reports = {"A": [], "B": []}
    order = "AB" if args.inputs_only else ORDER
    mode = "inputs" if args.inputs_only else "timing"
    witness = None
    with ExitStack() as cleanup:
        for _ in range(args.load_workers):
            worker = subprocess.Popen(["yes"], stdout=subprocess.DEVNULL)
            cleanup.callback(stop_load, worker)
        for index, side in enumerate(order, 1):
            report = run_sample(fixtures, output / f"{index}-{side}", side, mode, args.native, args.perf157)
            actual = route.workload_receipt(report)
            if witness is not None and witness != actual:
                raise ValueError(f"Controller outcomes differ at take {index}-{side}")
            witness = actual
            reports[side].append(report)

    result = {"base": base_head, "order": order, "load_workers": args.load_workers, "mode": mode,
              "environment": {k: v for k, v in reports["A"][0].items() if k != "cases"}, "rooms": {}}
    for room in witness:
        by_trigger = {}
        for trigger in (None, *CONFIRMS):
            rows = {side: confirm_rows(takes, room, trigger) for side, takes in reports.items()}
            comparison = {}
            if args.inputs_only:
                comparison = {side: attribution(samples) for side, samples in rows.items()}
                paint = [[sample["paint_receipt"] for sample in rows[side]] for side in "AB"]
                comparison["paint_receipts_identical"] = paint[0] == paint[1]
                if paint[0] != paint[1]:
                    raise ValueError(f"Paint receipts differ for {room}/{trigger or 'all'}")
            else:
                comparison = {side: draw_summary(samples) for side, samples in rows.items()}
                comparison["pairs"] = [
                    {side: draw_summary(confirm_rows([report], room, trigger)) for side, report in zip("AB", pair)}
                    for pair in zip(reports["A"], reports["B"])
                ]
                comparison["reduction"] = {
                    metric: 1 - comparison["B"][metric] / comparison["A"][metric]
                    for metric in ("median_ms", "p95_ms") if comparison["A"][metric] > 0
                }
            by_trigger[trigger or "all"] = comparison
        result["rooms"][room] = by_trigger
        if not args.inputs_only:
            summary = by_trigger["all"]
            print(f"{label} {room} median/p95 ms: "
                  f"{summary['A']['median_ms']:.3f}/{summary['A']['p95_ms']:.3f} -> "
                  f"{summary['B']['median_ms']:.3f}/{summary['B']['p95_ms']:.3f}", flush=True)

    if args.perf157 and args.inputs_only:
        transitions = {}
        for room in witness:
            left, right = (reports[side][0]["cases"][room]["samples"] for side in "AB")
            transitions[room] = [
                {"trigger": a["trigger"], "button": a["button"], "A": transition_attribution(a),
                 "B": transition_attribution(b), "identical": a["transition_paint"] == b["transition_paint"]}
                for a, b in zip(left, right)  # The workload witness already requires the same input sequence.
            ]
        result["transitions"] = transitions
        result["transition_receipts_identical"] = all(row["identical"] for rooms in transitions.values() for row in rooms)
        status = "identical" if result["transition_receipts_identical"] else "differ"
        print(f"{label} TRANSITION PAINT RECEIPTS: {status} (scene tiles and bodies)", flush=True)
    path = output / f"{mode}.json"
    if args.inputs_only:
        print(f"{label} PAINT RECEIPTS: identical (normal and Tharokh, A and Y)", flush=True)
    if not args.inputs_only:
        reductions = [result["rooms"][room]["all"]["reduction"] for room in ("tharokh", "normal")]
        minimum_reduction = .30 if args.perf157 else MINIMUM_REDUCTION
        result["acceptance"] = all(set(check) == {"median_ms", "p95_ms"}
                                   and min(check.values()) >= threshold
                                   for check, threshold in zip(reductions, (minimum_reduction, -NORMAL_TOLERANCE)))
        print(f"{label} CONFIRM TIMING: {'PASS' if result['acceptance'] else 'FAIL'}", flush=True)
    path.write_text(json.dumps(result, indent=2) + "\n")
    print(path)
    return int(not result.get("acceptance", True) or not result.get("transition_receipts_identical", True))


if __name__ == "__main__":
    raise SystemExit(main())
