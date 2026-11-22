#!/usr/bin/env python3
"""Interleave cold Continue / Begin takes and compare baseline and candidate."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import statistics
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
# Release baseline with perf-159 focus-canvas reuse.
BASE = "2965e9b91"
TASK = "perf-171b"
PROBE = "res://tools/perf171/arena_probe.gd"
ARENAS = (
    *(f"guardian:{name}" for name in ("ashen_reaver", "rimejaw", "storm_cantor", "gallows_roc", "craghide", "last_lamplighter")),
    *(f"dragon:{name}" for name in ("vyraketh", "iskaldra", "zekarion", "vaeloryx", "tharokh", "noctyrax")),
    "room:pre_battle",
)
ORDER = "ABBAABBAAB"
# Another app taking focus, or another GUI job holding the render lease, fails
# a native take without saying anything about either arm. Retry those once.
ENVIRONMENT_FAILURES = ("Native window lost focus", "Native window is unfocused", "GUI render lease")
ENVIRONMENT_RETRIES = 1
# Captures add a second baseline take: A must match A before B is judged.
CAPTURE_ORDER = "ABA"
# A collapsed board (tile width <= 2 px, see arena_probe.gd _frame_state) is
# a few wall-clock-animated pixels; never exclude more than this.
MAX_COLLAPSED_PX = 64 * 64
OWNED_RUNTIME = {
    "scripts/combat_board_view.gd",
    "scripts/combat_texture_preparation.gd",
    "scripts/encounter_asset_preparation.gd",
    "scripts/run_initial_preparation.gd",
    "scripts/run_scene.gd",
    "scripts/room_asset_preparation.gd",
    "scripts/board_threat_isolation.gd",
}


def stage_baseline(project):
    """Restore this unit's runtime files without changing the active worktree."""
    project.mkdir(parents=True)
    runtime = project / "scripts"
    runtime.mkdir()
    for source in ROOT.iterdir():
        if source.name not in {".git", ".godot", "output", "scripts"}:
            (project / source.name).symlink_to(source)
    for source in (ROOT / "scripts").iterdir():
        if f"scripts/{source.name}" not in OWNED_RUNTIME:
            (runtime / source.name).symlink_to(source)
    for relative in sorted(OWNED_RUNTIME):
        result = subprocess.run(
            ["git", "show", f"{BASE}:{relative}"], cwd=ROOT, capture_output=True, check=False
        )
        result.check_returncode()
        (project / relative).write_bytes(result.stdout)
    subprocess.run(["cp", "-cR", ROOT / ".godot", project / ".godot"], check=True)


def take(project, destination, fixture, profile, mode, native):
    destination.mkdir(parents=True)
    env = {
        **os.environ,
        "LABYRINTH_CEL_LOOK": "all",
        "LABYRINTH_DEMO": "0",
        "LABYRINTH_HITCH_TRACE": str(int(mode == "attribute")),
        "LABYRINTH_PROBE_WINDOW": "1",
    }
    probe_args = ["--", f"--fixture={fixture}", f"--output={destination}"]
    if mode == "attribute":
        probe_args.append("--attribute")
    display = ["--display-driver", "macos", "--rendering-method", "mobile",
               "--rendering-driver", "metal", "--audio-driver", "Dummy"]
    if mode == "capture":
        command = [sys.executable, "tools/visual_probe_runner.py", "--project", str(project),
                   "--task-id", TASK, "--no-headless", *display,
                   # Another queued GUI job can hold the render lease longer than the 30 s default.
                   "--gui-lease-timeout", "300",
                   "--proof-contract", "tools/perf171/first_frames.json",
                   "--result-manifest", str(destination / "images.json"), PROBE,
                   *probe_args, "--capture"]
    else:
        command = [sys.executable, "tools/godot_task_runner.py", "--task-id", TASK,
                   "--stream", "--", "godot", "--path", str(project),
                   *(display if native else ["--headless"]), "--script", PROBE, *probe_args]
    if profile == "background":
        command[:0] = ["taskpolicy", "-c", "background"]
    (destination / "command.json").write_text(json.dumps(command, indent=2) + "\n")
    receipt_path = destination / "receipt.json"
    for attempt in range(ENVIRONMENT_RETRIES + 1):
        with (destination / "runner.log").open("w") as log:
            result = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
        if not result.returncode and receipt_path.is_file():
            break
        runner_log = (destination / "runner.log").read_text(errors="replace")
        if attempt == ENVIRONMENT_RETRIES or not any(marker in runner_log for marker in ENVIRONMENT_FAILURES):
            raise RuntimeError(f"Godot take failed. See {destination / 'runner.log'}")
        # Keep the failed attempt for audit; the retry starts from an empty take.
        failed = destination.with_name(f"{destination.name}.environment-failure-{attempt + 1}")
        destination.rename(failed)
        destination.mkdir()
        (destination / "command.json").write_text(json.dumps(command, indent=2) + "\n")
        print(f"PERF171 TAKE RETRY {destination} (focus or GUI lease; see {failed / 'runner.log'})", flush=True)
    receipt = json.loads(receipt_path.read_text())
    if receipt["errors"]:
        raise RuntimeError(f"{destination}: {receipt['errors']}")
    print(f"PERF171 TAKE PASS {destination} Begin={receipt['begin_frame_us'] / 1000:.2f} ms", flush=True)
    return receipt


def attribution(receipt):
    runtime = receipt["runtime"]
    board = receipt["board"]

    def runtime_ms(phase):
        return runtime.get(phase, {}).get("total_usec", 0) / 1000

    return {
        "encounter_commit_ms": runtime_ms("pre_battle_start_engine"),
        "combat_state_sync_ms": runtime_ms("pre_battle_start_sync"),
        "shadow_geometry_ms": runtime_ms("pre_battle_start_shadows"),
        "rig_instancing_and_pose_ms": sum(v["total_usec"] for k, v in board.items() if k.startswith("roster_")) / 1000,
        "board_submission_ms": runtime_ms("stage_board_submission"),
        "board_redraw_routing_ms": board.get("redraw_routing", {}).get("total_usec", 0) / 1000,
        "static_and_retained_draw_ms": (receipt["draw"]["static_draw_total_usec"] + receipt["draw"]["dynamic_draw_total_usec"]) / 1000,
        "forecast_source_ms": runtime_ms("pass_preview_source_total"),
        "opening_query_adoption": receipt["queries"],
        "hud_and_other_refresh_ms": runtime_ms("refresh_ui_total") - runtime_ms("refresh_ui_stage_total"),
        "turn_clock_ms": runtime_ms("refresh_ui_turn_order_total"),
        "hand_ms": runtime_ms("refresh_ui_hand_total"),
        "checkpoint_ms": runtime_ms("pre_battle_start_checkpoint"),
        "analytics_ms": runtime_ms("pre_battle_start_analytics"),
    }


def compare(base, candidate, destinations, mode):
    metrics = {}
    for key in ("begin_frame_us", "begin_handler_us", "continue_us"):
        before = [row[key] / 1000 for row in base]
        after = [row[key] / 1000 for row in candidate]
        metrics[key.removesuffix("_us") + "_ms"] = {
            "baseline_samples": before, "candidate_samples": after,
            "baseline_median": statistics.median(before), "candidate_median": statistics.median(after),
            "baseline_worst": max(before), "candidate_worst": max(after),
            "paired_median_change": statistics.median(b - a for a, b in zip(before, after)),
        }
    begin = metrics["begin_frame_ms"]
    metrics["begin_median_reduction_pct"] = 100 * (1 - begin["candidate_median"] / begin["baseline_median"])
    metrics["receipts_equal"] = {
        key: all(a[key] == b[key] for a, b in zip(base, candidate))
        for key in ("combat_hash", "checkpoint_hash", "analytics_hash")
    }
    if mode == "attribute":
        metrics["cover_trap_paths"] = [
            sorted(path for path in rows[0]["cover_loads"] if "/traps/" in path)
            for rows in (base, candidate)
        ]
        metrics["cover_sync_count"] = [
            sum(event["count"] for event in rows[0]["cover_loads"].values()) for rows in (base, candidate)
        ]
        metrics["continue_sync_trap_gate"] = not metrics["cover_trap_paths"][1]
    if mode == "capture":
        metrics["pixels"] = compare_pixels(destinations["A"][0], base[0], destinations["B"][0], candidate[0])
        metrics["pixels_equal"] = {name: row["equal"] for name, row in metrics["pixels"].items()}
        if len(destinations["A"]) > 1:
            metrics["control_pixels"] = compare_pixels(destinations["A"][0], base[0], destinations["A"][1], base[1])
            metrics["control_pixels_equal"] = {name: row["equal"] for name, row in metrics["control_pixels"].items()}
    return metrics


def collapsed_rect(receipt, index):
    frames = receipt.get("capture_frames", [])
    return frames[index].get("collapsed_board_rect", []) if index < len(frames) else []


def compare_pixels(first_dir, first_receipt, second_dir, second_receipt):
    """Strict per-pixel comparison outside a collapsed board both takes report identically."""
    from PIL import Image, ImageChops

    rows = {}
    for png in sorted(first_dir.glob("arena_first_*.png")):
        other = second_dir / png.name
        row = {"equal": False, "diff_px": None, "excluded_rect": [], "excluded_diff_px": 0}
        rows[png.name] = row
        if not other.is_file():
            continue
        if hashlib.sha256(png.read_bytes()).digest() == hashlib.sha256(other.read_bytes()).digest():
            row.update(equal=True, diff_px=0)
            continue
        first, second = Image.open(png).convert("RGBA"), Image.open(other).convert("RGBA")
        if first.size != second.size:
            continue
        channels = ImageChops.difference(first, second).split()
        changed = channels[0]
        for channel in channels[1:]:
            changed = ImageChops.lighter(changed, channel)
        changed = changed.point(lambda value: 255 if value else 0)
        index = int(png.stem.rsplit("_", 1)[1])
        rect = collapsed_rect(first_receipt, index)
        if rect and rect == collapsed_rect(second_receipt, index) and rect[2] * rect[3] <= MAX_COLLAPSED_PX:
            box = (rect[0], rect[1], rect[0] + rect[2], rect[1] + rect[3])
            row["excluded_rect"] = rect
            row["excluded_diff_px"] = changed.crop(box).histogram()[255]
            changed.paste(0, box)
        row["diff_px"] = changed.histogram()[255]
        row["diff_bbox"] = list(changed.getbbox() or [])
        row["equal"] = row["diff_px"] == 0
    return rows


def main():
    global TASK
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("attribute", "pairs", "capture"))
    parser.add_argument("--native", action="store_true")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--fixture", choices=ARENAS, action="append")
    parser.add_argument("--profile", choices=("normal", "background"), action="append")
    parser.add_argument("--baseline-only", action="store_true")
    parser.add_argument("--baseline-project", type=Path, help="Reuse a baseline-project directory from a completed staging step")
    parser.add_argument("--task-id", default=TASK, help="Task runner id (the worktree's task)")
    args = parser.parse_args()
    TASK = args.task_id
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    (output / ".gdignore").touch()
    baseline = args.baseline_project.resolve() if args.baseline_project else output / "baseline-project"
    if not baseline.exists():
        stage_baseline(baseline)
    projects = {"A": baseline, "B": ROOT}
    order = "A" if args.baseline_only else ORDER if args.mode == "pairs" else CAPTURE_ORDER if args.mode == "capture" else "AB"
    results = {}
    for profile in args.profile or (["normal"] if args.mode == "capture" else ["normal", "background"]):
        for fixture in args.fixture or ARENAS:
            label = fixture.replace(":", "-")
            receipts = {"A": [], "B": []}
            destinations = {"A": [], "B": []}
            for index, arm in enumerate(order):
                destination = output / profile / label / f"{index + 1:02}-{arm}"
                receipts[arm].append(take(projects[arm], destination, fixture, profile, args.mode, args.native))
                destinations[arm].append(destination)
            if receipts["B"]:
                comparison = compare(receipts["A"], receipts["B"], destinations, args.mode)
                if args.mode == "pairs":
                    comparison["begin_median_gate"] = (
                        comparison["begin_median_reduction_pct"] >= (50 if profile == "background" else 0)
                        if fixture not in ("room:pre_battle",) or profile == "normal" else None
                    )
                if args.mode == "attribute":
                    comparison["begin_attribution"] = {arm: attribution(rows[0]) for arm, rows in receipts.items()}
                    comparison["begin_sync_loads"] = {arm: rows[0]["begin_loads"] for arm, rows in receipts.items()}
                results[f"{profile}/{fixture}"] = comparison
            else:
                result = receipts["A"][0]
                if args.mode == "attribute":
                    result["begin_attribution"] = attribution(result)
                results[f"{profile}/{fixture}"] = result
            (output / "summary.json").write_text(json.dumps(results, indent=2) + "\n")
    if args.baseline_only:
        return 0
    failed = []
    unstable = []
    for label, comparison in results.items():
        receipts_equal = all(comparison["receipts_equal"].values())
        pixels_equal = all(comparison.get("pixels_equal", {}).values())
        if not all(comparison.get("control_pixels_equal", {}).values()):
            # Baseline differs from itself: the capture, not the candidate, is unreliable.
            unstable.append(label)
        if not receipts_equal or not pixels_equal or comparison.get("begin_median_gate") is False or comparison.get("continue_sync_trap_gate") is False:
            failed.append(label)
    if unstable:
        print("PERF171 CAPTURE CONTROL (baseline vs baseline) UNSTABLE: " + ", ".join(unstable))
    failed.extend(label for label in unstable if label not in failed)
    print(f"PERF171 {args.mode.upper()} GATES: " + (f"FAIL ({', '.join(failed)})" if failed else "PASS"))
    return int(bool(failed))


if __name__ == "__main__":
    sys.exit(main())
