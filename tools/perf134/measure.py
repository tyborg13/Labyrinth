#!/usr/bin/env python3
"""Run perf-135 timing pairs and compare the 14 strict capture states."""
import argparse
import json
import os
from pathlib import Path
from statistics import mean, median
from tempfile import TemporaryDirectory
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
PROBE = Path(__file__).with_name("probe.gd")
TASK_ID = "perf-135"
BASE_HEAD = "dbf5bdb5fca5d089b3c98ee777324aaa35e4952f"
ORDER = "ABBAAB"
CAPTURES = (
    "idle", "hover", "targeting", "enemy-mid-frame", "umbra", "tharokh", "guardian", "warband",
    "umbra-hover-light", "umbra-hover-dark", "second-activation", "burrow-marks", "skybreak-marks", "walk-destination",
)
SECTIONS = (
    "stage_board_submission", "hover_stage_refresh_total", "refresh_ui_total",
    "enemy_round_final_refresh_ui_wall_total", "animation_lock_ui_total",
    "card_preview_refresh_total", "refresh_ui_choice_bar_total",
    "pass_preview_enemy_actions_total", "engine_enemy_preview_total",
)
REFRESH_SECTIONS = SECTIONS[2:7]
THRESHOLDS_MS = (16.67, 20.0, 33.0, 33.33, 50.0, 100.0)
RENDER_COLUMNS = ("process_monitor_peak_ms", "viewport_cpu_ms", "viewport_gpu_ms",
                  "draw_calls", "objects", "primitives")


def run(command, cwd, extra_env=None):
    print(f"Running in {cwd}", flush=True)
    subprocess.run(command, cwd=cwd, check=True, env={**os.environ, "SteamDeck": "0", **(extra_env or {})})


def validate_base(project, expected=BASE_HEAD):
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=project, text=True).strip()
    if revision != expected:
        raise ValueError(f"Baseline must be {expected}, got {revision}")
    if subprocess.check_output(["git", "diff", "HEAD", "--name-only"], cwd=project).strip():
        raise ValueError("Baseline has tracked changes")


def prepare_fixtures(base, output, task_id=TASK_ID):
    output.mkdir(parents=True, exist_ok=True)
    bundle = output / "fixtures-v3.var"
    if not bundle.exists():
        # Generate one archive with release rules for the entire comparison.
        # Never regenerate a different starting board on candidate boot.
        with TemporaryDirectory(prefix="fixture-", dir=output) as scratch:
            generated = Path(scratch) / bundle.name
            headless_probe(base, scratch, f"--prepare-fixtures={generated}", task_id=task_id)
            generated.replace(bundle)
    return bundle


def headless_probe(project, output, *args, fixed_fps=False, stand_in=False, task_id=TASK_ID, environment=None):
    clock = ["--fixed-fps", "60"] if fixed_fps else []
    policy = ["taskpolicy", "-c", "background"] if stand_in else []
    run([*policy, sys.executable, str(TOOLS / "godot_task_runner.py"), "--task-id", task_id,
         "--stream", "--", "godot", "--headless", *clock, "--path", str(project), "--script", str(PROBE),
         "--", "--headless-check", f"--output={output}", *args], project, environment)


def timing(project, output, bundle, task_id=TASK_ID):
    run(["taskpolicy", "-c", "background", sys.executable, str(TOOLS / "godot_task_runner.py"),
         "--task-id", task_id, "--stream", "--", "godot", "--path", str(project),
         "--windowed", "--display-driver", "macos",
         "--rendering-driver", "metal", "--rendering-method", "mobile", "--audio-driver", "Dummy",
         "--script", str(PROBE), "--", f"--output={output}", f"--fixtures={bundle}"], project)


def percentile(sorted_values, fraction):
    offset = (len(sorted_values) - 1) * fraction
    lower = int(offset)
    return sorted_values[lower] + (offset - lower) * (sorted_values[min(lower + 1, len(sorted_values) - 1)] - sorted_values[lower])


def histogram(usec):
    samples = sorted(value / 1000 for value in usec)
    over = {str(limit): sum(value > limit for value in samples) for limit in THRESHOLDS_MS}
    return {
        "count": len(samples), "mean_ms": mean(samples), "median_ms": median(samples),
        "p95_ms": percentile(samples, .95), "p99_ms": percentile(samples, .99), "max_ms": samples[-1],
        "over_ms": over, "over_33ms_count": over["33.0"], "over_33ms_rate": over["33.0"] / len(samples),
    }


def summarize(case):
    frames = case["frame_usec"]
    if set(frames) != {"combat_idle", "combat_targeting", "combat_animation"}:
        raise ValueError(f"Incomplete frame cohorts {list(frames)}")
    combined = [value for cohort in frames.values() for value in cohort]
    if sum(900_000 <= value <= 1_200_000 for value in combined) >= 3:
        raise ValueError("Repeated one-second frame intervals invalidate native frame delivery")
    sections = {}
    for name in SECTIONS:
        row = case["sections"].get(name)
        sections[name] = {
            "calls": row["count"], "mean_ms": row["usec_per_call"] / 1000, "max_ms": row["max_usec"] / 1000,
        } if row else None
    render_samples = case["render_samples"]
    if len(render_samples) != len(combined) or any(len(row) != len(RENDER_COLUMNS) for row in render_samples):
        raise ValueError("Render monitors must supply one complete row per frame")
    render_medians = dict(zip(RENDER_COLUMNS, map(median, zip(*render_samples))))
    return {"sections": sections, "frame_cohorts": {name: histogram(values) for name, values in frames.items()},
            "unfocused_frames": case.get("unfocused_frames", 0),
            "combat_frames": histogram(combined), "render_medians": render_medians,
            "board_submission": case["board_submission"], "board_render": case["render"],
            "board_submissions_by_phase": case["board_submissions_by_phase"],
            "memory": case["memory"], "nodes": case["nodes"],
            "initial_combat_sha256": case["initial_combat_sha256"],
            "initial_turn": case["initial_turn"], "final_turn": case["final_turn"]}


def reduction(before, after):
    if before is None or after is None or before == 0:
        return None
    return (before - after) / before


def assessment(values, minimum):
    if any(value is None for value in values):
        return {"pair_reductions": values, "win": False, "reason": "no measurable baseline or candidate call"}
    middle = median(values)
    spread = max(values) - min(values)
    return {"pair_reductions": values, "median": middle, "spread": spread,
            "win": min(values) > 0 and middle > spread and middle >= minimum}


def report(output, base_head=BASE_HEAD):
    samples = []
    for index, side in enumerate(ORDER, 1):
        path = output / f"{index}-{side}" / "summary.json"
        result = json.loads(path.read_text())
        if result["headless"] or result["deck"] or result["errors"] or result["orphan_nodes"]:
            raise ValueError(f"Invalid native sample {path}")
        if result["size"] != [1920, 1080] or result["ui_scale"] != 1.0 or result["rendering_driver"] != "metal":
            raise ValueError(f"Unexpected viewport, UI scale or renderer in {path}")
        samples.append({"path": str(path), "side": side, "environment": {key: value for key, value in result.items()
                                                                       if key != "cases"},
                        "cases": {name: summarize(case) for name, case in result["cases"].items()}})
    if any(sample["environment"] != samples[0]["environment"] for sample in samples[1:]):
        raise ValueError("Native sample environments differ")
    pairs = [(samples[0], samples[1]), (samples[3], samples[2]), (samples[4], samples[5])]
    checks = {}
    for kind in ("normal", "tharokh"):
        initial = {sample["cases"][kind]["initial_combat_sha256"] for sample in samples}
        final_turns = {sample["cases"][kind]["final_turn"] for sample in samples}
        if len(initial) != 1 or len(final_turns) != 1:
            raise ValueError(f"Native {kind} routes disagree on the initial combat state or final turn")
        checks[kind] = {}
        for name in SECTIONS:
            metrics = ("mean_ms", "max_ms") if name == "stage_board_submission" else ("max_ms",)
            for metric in metrics:
                values = []
                for a, b in pairs:
                    before = a["cases"][kind]["sections"][name]
                    after = b["cases"][kind]["sections"][name]
                    # An eliminated section has zero measured calls and zero cost.
                    values.append(reduction(before[metric] if before else None, after[metric] if after else 0.0))
                checks[kind][f"{name}.{metric}"] = assessment(values, .5)
        for metric in ("over_33ms_count", "over_33ms_rate", "median_ms", "p95_ms", "p99_ms"):
            values = [reduction(a["cases"][kind]["combat_frames"][metric], b["cases"][kind]["combat_frames"][metric])
                      for a, b in pairs]
            checks[kind][f"combat_frames.{metric}"] = assessment(values, .5 if metric.startswith("over_33ms_") else 0)
    path = output / "paired-report.json"
    path.write_text(json.dumps({"baseline": base_head, "order": list(ORDER), "samples": samples, "checks": checks}, indent=2) + "\n")
    for kind, rows in checks.items():
        for metric, row in rows.items():
            print(f"{kind} {metric}: {json.dumps(row)}")
    print(path)


def pixel_difference(left, right):
    sys.path.insert(0, str(TOOLS))
    from visual_probe_runner import decode_png

    a, b = decode_png(left), decode_png(right)
    if any((shot["width"], shot["height"]) != (1920, 1080) for shot in (a, b)):
        raise ValueError("Expected 1920x1080 captures")
    if a["color_type"] != b["color_type"] or a["color_type"] not in (2, 6):
        raise ValueError("Captures must both use RGB or both use RGBA")
    channels = a["channels"]
    count = 0
    min_x, min_y, max_x, max_y = 1920, 1080, -1, -1
    for y, (a_row, b_row) in enumerate(zip(a["rows"], b["rows"])):
        if a_row == b_row:
            continue
        for offset in range(0, len(a_row), channels):
            if a_row[offset:offset + channels] != b_row[offset:offset + channels]:
                x = offset // channels
                count += 1
                min_x, max_x = min(min_x, x), max(max_x, x)
                min_y, max_y = min(min_y, y), max(max_y, y)
    return {"different_pixels": count, "bbox": [min_x, min_y, max_x + 1, max_y + 1] if count else None,
            "masks": []}


def capture(projects, output, state, bundle, task_id=TASK_ID, environments=None, *, enforce=True):
    for side, project in projects.items():
        directory = output / "captures" / side
        directory.mkdir(parents=True, exist_ok=True)
        with TemporaryDirectory(prefix=f"{state}-movie-", dir=output) as scratch:
            run([sys.executable, str(TOOLS / "visual_probe_runner.py"), str(PROBE),
                 "--project", str(project), "--task-id", task_id, "--no-headless",
                 "--display-driver", "macos", "--rendering-driver", "metal", "--rendering-method", "mobile",
                 "--audio-driver", "Dummy", "--godot", str(PROBE.with_name("capture_godot.sh")),
                 "--expect-size", "1920x1080", "--timeout", "90",
                 "--proof-contract", str(PROBE.with_name("capture_contract.json")),
                 "--result-manifest", str(directory / f"{state}.json"), "--",
                 f"--output={directory}", f"--capture={state}", f"--fixtures={bundle}", "--fixed-fps", "60"],
                project, {**(environments or {}).get(side, {}),
                          "PERF134_CAPTURE_MOVIE": str(Path(scratch) / "clock.avi")})
    a, b = (output / "captures" / side for side in "AB")
    input_a, input_b = (json.loads((side / f"{state}-state.json").read_text()) for side in (a, b))
    difference = pixel_difference(a / f"{state}.png", b / f"{state}.png")
    difference["mismatched_state_fields"] = mismatched_fields(input_a, input_b)
    invalid_masks = input_a.get("masks") != [] or input_b.get("masks") != []
    if invalid_masks:
        difference["error"] = "This capture contract requires a full-frame comparison"
    diff_path = output / "captures" / f"{state}-diff.json"
    diff_path.write_text(json.dumps(difference, indent=2) + "\n")
    if invalid_masks or difference["different_pixels"] or difference["mismatched_state_fields"]:
        message = f"Capture mismatch: {difference} ({diff_path})"
        if enforce:
            raise ValueError(message)
        print(message, flush=True)
    else:
        print(f"PERF-135 PIXELS: {state} has 0 differing pixels across the whole viewport and identical state receipts")
    return difference


def mismatched_fields(left, right):
    missing = object()
    return sorted(key for key in left.keys() | right.keys() if left.get(key, missing) != right.get(key, missing))


def headless_receipts(projects, output, bundle, task_id=TASK_ID, environments=None):
    directories = [output / "headless-captures" / side for side in projects]
    for (side, project), directory in zip(projects.items(), directories):
        headless_probe(project, directory, f"--fixtures={bundle}", "--capture-all", fixed_fps=True,
                       task_id=task_id, environment=(environments or {}).get(side))
    for state in CAPTURES:
        left, right = (json.loads((directory / f"{state}-state.json").read_text()) for directory in directories)
        fields = mismatched_fields(left, right)
        if fields:
            raise ValueError(f"Headless receipt mismatch for {state}: {fields}")
        print(f"PERF-135 RECEIPTS: {state} identical (headless)")


def headless_timing(projects, output, bundle, task_id=TASK_ID):
    results = {}
    for side, project in projects.items():
        directory = output / "headless-timing" / side
        headless_probe(project, directory, f"--fixtures={bundle}", task_id=task_id)
        result = json.loads((directory / "summary.json").read_text())
        if not result["headless"] or result["deck"] or result["errors"] or result["orphan_nodes"]:
            raise ValueError(f"Invalid headless sample {directory}")
        results[side] = result
    for key in results["A"].keys() - {"cases"}:
        if results["A"][key] != results["B"][key]:
            raise ValueError(f"Headless timing environments differ on {key}")
    for kind in ("normal", "tharokh"):
        left, right = (result["cases"][kind] for result in results.values())
        for key in ("initial_combat_sha256", "initial_turn", "final_turn"):
            if left[key] != right[key]:
                raise ValueError(f"Headless {kind} routes differ on {key}")
        for section in SECTIONS:
            print(f"PERF-135 HEADLESS {kind} {section}: "
                  f"{section_text(left, section)} -> {section_text(right, section)}")


def section_text(case, section):
    row = case["sections"].get(section)
    if row is None:
        return "0 calls"
    return f"{row['count']} calls, mean {row['usec_per_call'] / 1000:.3f} ms, max {row['max_usec'] / 1000:.3f} ms"


def headless_pairs(projects, output, bundle, task_id, base_head):
    samples = []
    for index, side in enumerate(ORDER, 1):
        directory = output / f"{index}-{side}"
        headless_probe(projects[side], directory, f"--fixtures={bundle}", stand_in=True, task_id=task_id)
        result = json.loads((directory / "summary.json").read_text())
        if (not result["headless"] or result["deck"] or result["errors"] or result["orphan_nodes"]
                or result["size"] != [1920, 1080] or result["ui_scale"] != 1.0):
            raise ValueError(f"Invalid stand-in sample {directory}")
        samples.append(result)
    environment = {key: value for key, value in samples[0].items() if key != "cases"}
    for sample in samples[1:]:
        if any(sample[key] != value for key, value in environment.items()):
            raise ValueError("Stand-in sample environments differ")
    pairs = [(samples[0], samples[1]), (samples[3], samples[2]), (samples[4], samples[5])]
    checks = {}
    for kind in ("normal", "tharokh"):
        for key in ("initial_combat_sha256", "initial_turn", "final_turn"):
            if len({sample["cases"][kind][key] for sample in samples}) != 1:
                raise ValueError(f"Stand-in {kind} routes differ on {key}")
        checks[kind] = {}
        for section in REFRESH_SECTIONS:
            pair_max_ms = [[sample["cases"][kind]["sections"][section]["max_usec"] / 1000
                            for sample in pair] for pair in pairs]
            pooled_max_ms = [max(side) for side in zip(*pair_max_ms)]
            checks[kind][section] = {
                "pair_max_ms": pair_max_ms,
                "pooled_max_ms": pooled_max_ms,
                "pooled_max_reduction": reduction(*pooled_max_ms),
            }
            print(f"HEADLESS PAIRS {kind} {section} max ms (A, B): {pair_max_ms}")
    path = output / "headless-pairs.json"
    path.write_text(json.dumps({"baseline": base_head, "order": ORDER, "environment": environment, "checks": checks}, indent=2) + "\n")
    print(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for command in ("pairs", "report", "capture", "headless-receipts", "headless-timing", "headless-pairs", "opening-glyphs"):
        action = sub.add_parser(command)
        action.add_argument("--output", type=Path, required=True)
        action.add_argument("--base-head", default=BASE_HEAD)
        if command != "report":
            action.add_argument("--base", type=Path, required=True)
            action.add_argument("--task-id", default=TASK_ID)
        if command == "capture":
            action.add_argument("state", choices=CAPTURES)
    args = parser.parse_args()
    output = args.output.resolve()
    if args.command == "report":
        report(output, args.base_head)
        return
    projects = {"A": args.base.resolve(), "B": ROOT}
    validate_base(projects["A"], args.base_head)
    bundle = prepare_fixtures(projects["A"], output, args.task_id)
    if args.command == "headless-receipts":
        headless_receipts(projects, output, bundle, args.task_id)
        return
    if args.command == "headless-timing":
        headless_timing(projects, output, bundle, args.task_id)
        return
    if args.command == "capture":
        capture(projects, output, args.state, bundle, args.task_id)
        return
    if args.command == "opening-glyphs":
        for side, project in projects.items():
            headless_probe(project, output / f"opening-glyphs-{side}", f"--fixtures={bundle}",
                           "--opening-glyphs", stand_in=True, task_id=args.task_id)
        return
    if any((output / f"{index}-{side}").exists() for index, side in enumerate(ORDER, 1)):
        parser.error("Use a fresh --output for a complete set of paired samples")
    if args.command == "headless-pairs":
        headless_pairs(projects, output, bundle, args.task_id, args.base_head)
        return
    for index, side in enumerate(ORDER, 1):
        timing(projects[side], output / f"{index}-{side}", bundle, args.task_id)
    report(output, args.base_head)


if __name__ == "__main__":
    main()
