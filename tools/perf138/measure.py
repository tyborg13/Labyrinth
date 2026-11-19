#!/usr/bin/env python3
"""Replay matched controller trigger frames against release invalidation."""
import argparse
from collections import Counter, defaultdict
import importlib.util
import json
import os
from pathlib import Path
from statistics import median
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
PERF134 = ROOT / "tools" / "perf134"
BASE_HEAD = "e5a6d3f53fd6ee96bd0f367b3bd9649a540fe24c"
ORDER = "ABBAAB"
ROUTE = "res://tools/perf138/controller_route.gd"
TASK_ID = "perf-138"


def load_fixture_tools():
    spec = importlib.util.spec_from_file_location("perf134_measure", PERF134 / "measure.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run_sample(fixtures, directory, side, mode, native):
    directory.mkdir()
    renderer = (
        ["--windowed", "--display-driver", "macos", "--rendering-driver", "metal",
         "--rendering-method", "mobile", "--audio-driver", "Dummy"]
        if native else ["--headless"]
    )
    command = [sys.executable, str(ROOT / "tools/godot_task_runner.py"), "--task-id", TASK_ID,
               "--stream", "--", "godot", *renderer, "--fixed-fps", "60", "--path", str(ROOT),
               "--script", str(PERF134 / "probe.gd"), "--", f"--output={directory}",
               f"--fixtures={fixtures}", f"--board-redraw-route={ROUTE}"]
    if not native:
        command.append("--headless-check")
    environment = {
        "LABYRINTH_BOARD_REDRAW_TRACE": mode,
        "LABYRINTH_BOARD_REDRAW_BASELINE": "1" if side == "A" else "0",
        "LABYRINTH_CEL_LOOK": "all",
    }
    print(f"perf-138 {directory.name} ({mode})", flush=True)
    with (directory / "run.log").open("w") as log:
        subprocess.run(command, cwd=ROOT, env={**os.environ, **environment, "SteamDeck": "0"},
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    report = json.loads((directory / "summary.json").read_text())
    if (report["errors"] or report["headless"] == native or report["deck"] or report["orphan_nodes"]
            or report["size"] != [1920, 1080] or report["ui_scale"] != 1.0
            or set(report["cases"]) != {"normal", "tharokh"}):
        raise ValueError(f"Invalid workload receipt in {directory}")
    result_line = next((line for line in (directory / "run.log").read_text().splitlines()
                        if line.startswith("PERF-135 PROBE: PASS")), None)
    if result_line is None:
        raise ValueError(f"Missing probe completion in {directory}")
    print(result_line, flush=True)
    return report


def workload_receipt(report):
    return {
        case: (route["initial_combat_sha256"], route["destination"], route["final_turn"],
               [(s["trigger"], s["button"], s["before"], s["after"]) for s in route["samples"]])
        for case, route in report["cases"].items()
    }


def rows(report, case=None, trigger=None):
    for room, route in report["cases"].items():
        if case is not None and case != room:
            continue
        for sample in route["samples"]:
            if trigger is None or trigger == sample["trigger"]:
                yield sample


def trigger_draws(sample):
    return [row for row in sample["draws"] if row["frame"] == sample["start_frame"]]


def timing(reports, case=None, trigger=None):
    samples = [s for report in reports for s in rows(report, case, trigger)]
    return {
        "median_redraws": median(len(trigger_draws(s)) for s in samples),
        "median_draw_ms": median(sum(row["usec"] for row in trigger_draws(s)) for s in samples) / 1000,
        "stage_total_max_ms": max(s["stage"].get("stage_total", {}).get("max_usec", 0) for s in samples) / 1000,
        "stage_board_submission_max_ms": max(
            s["stage"].get("stage_board_submission", {}).get("max_usec", 0) for s in samples) / 1000,
    }


def layer_report(report, case):
    layers = defaultdict(Counter)
    stage = Counter()
    for sample in rows(report, case):
        for row in trigger_draws(sample):
            values = layers[row["kind"]]
            values["redraws"] += 1
            values["exclusive_usec"] += row["usec"]
            outcome = row["redundant"]
            if outcome is None:
                values["unknown"] += 1
                values["unknown_usec"] += row["usec"]
            elif outcome:
                values["redundant"] += 1
                values["redundant_usec"] += row["usec"]
        for name, phase in sample["stage"].items():
            if name not in {"stage_total", "stage_board_submission", "hover_stage_refresh_total",
                            "stage_hidden_path_warmup"}:
                stage[name] += phase["usec"]
        # Board's top-level phases partition stage_board_submission. HUD and
        # roster detail are nested in those phases and are omitted here.
        for name in ("decorate", "diff", "signatures", "assign_and_assets", "derived_caches",
                     "hud_layout", "retained_sync", "redraw_routing", "identical"):
            stage[f"board.{name}"] += sample["board_submission"].get(name, {}).get("total_usec", 0)
    for values in layers.values():
        values["redundant_share"] = values["redundant"] / values["redraws"]
        values["unknown_share"] = values["unknown"] / values["redraws"]
    return {"layers": layers, "top_stage_costs_usec": stage.most_common(3)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", type=Path, required=True, help="Clean release worktree")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--native", action="store_true")
    parser.add_argument("--inputs-only", action="store_true")
    args = parser.parse_args()
    output = args.output.resolve()
    order = "AB" if args.inputs_only else ORDER
    mode = "inputs" if args.inputs_only else "timing"
    if any((output / f"{index}-{side}").exists() for index, side in enumerate(order, 1)):
        parser.error("Use a fresh output directory for the run")
    fixture_tools = load_fixture_tools()
    base = args.base.resolve()
    fixture_tools.validate_base(base, BASE_HEAD)
    fixtures = fixture_tools.prepare_fixtures(base, output, TASK_ID)
    samples = {"A": [], "B": []}
    receipt = None
    for index, side in enumerate(order, 1):
        report = run_sample(fixtures, output / f"{index}-{side}", side, mode, args.native)
        actual = workload_receipt(report)
        if receipt is not None and actual != receipt:
            raise ValueError(f"Controller routes differ in {index}-{side}")
        receipt = actual
        samples[side].append(report)
    if args.inputs_only:
        summary = {side: {case: layer_report(reports[0], case) for case in receipt}
                   for side, reports in samples.items()}
    else:
        summary = {}
        for case in (None, *receipt):
            for trigger in (None, "A_select", "D-pad", "A_confirm", "Y_pass"):
                name = f"{case or 'both'}/{trigger or 'all'}"
                comparison = {side: timing(reports, case, trigger) for side, reports in samples.items()}
                comparison["reduction_pct"] = {
                    metric: round(100 * (1 - comparison["B"][metric] / baseline), 2) if baseline else None
                    for metric, baseline in comparison["A"].items()
                }
                comparison["pairs"] = [
                    {side: timing([report], case, trigger) for side, report in zip("AB", pair)}
                    for pair in zip(*samples.values())
                ]
                summary[name] = comparison
                if trigger is None:
                    print(f"PERF-138 {name} {comparison['A']} -> {comparison['B']} "
                          f"reduction_pct={comparison['reduction_pct']}")
    result = output / f"{mode}.json"
    result.write_text(json.dumps({"release_head": BASE_HEAD, "order": order, "results": summary}, indent=2) + "\n")
    print(result)


if __name__ == "__main__":
    main()
