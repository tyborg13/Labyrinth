#!/usr/bin/env python3
"""Measure matched startup takes and compare lossless native startup captures."""

import argparse
import json
import math
import os
from pathlib import Path
import platform
import statistics
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools/perf167"
PROBE = TOOLS / "startup_probe.gd"
PAIR_COUNT = 5
SETTLE_TOLERANCE_MS = 1000 / 60
THRESHOLDS_MS = (16.67, 20, 33.33, 50, 100)
MENU_PHASES = {"menu_black", "menu_fade_in", "complete"}
PROFILES = {"background": ["taskpolicy", "-c", "background"], "normal": []}


def invoke(command, directory, args, tracing=False):
    directory.mkdir(parents=True, exist_ok=False)
    env = {
        **os.environ,
        "LABYRINTH_CEL_LOOK": "all",
        "LABYRINTH_DEMO": "1",
        "LABYRINTH_HITCH_TRACE": str(int(tracing)),
        "LABYRINTH_PROBE_WINDOW": "1",
        "SteamDeck": "1",
    }
    print(directory, flush=True)
    with (directory / "runner.log").open("w") as log:
        proc = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
    if proc.returncode:
        raise RuntimeError(f"runner exited {proc.returncode}; see {directory / 'runner.log'}")
    report = read_report(directory)
    if not report["native"] or report["capture_only"] != (args.mode == "pixels"):
        raise ValueError(f"wrong proof mode in {directory / 'startup.json'}")
    return report


def read_report(directory):
    return json.loads((directory / "startup.json").read_text())


def timing_take(args, project, directory, home, profile, tracing=False, reduced=False):
    command = [
        *PROFILES[profile], sys.executable, str(ROOT / "tools/godot_task_runner.py"),
        "--project", str(project), "--task-id", "perf-167", "--run-id", home,
        "--godot-home-root", str(args.output / "homes"), "--stream",
    ]
    if tracing and args.allow_steam:
        command.append("--allow-steam")
    command += [
        "--", "godot", "--path", str(project), "--windowed", "--resolution", "1920x1080",
        "--display-driver", "macos", "--audio-driver", "Dummy", "--rendering-method", "mobile",
        "--rendering-driver", "metal", "--script", str(PROBE), "--", f"--output={directory}",
    ]
    if reduced:
        command.append("--reduced-motion")
    return invoke(command, directory, args, tracing)


def pixel_take(args, project, directory, reduced):
    contract = "proof_reduced.json" if reduced else "proof.json"
    command = [
        sys.executable, str(ROOT / "tools/visual_probe_runner.py"), "--project", str(project),
        "--task-id", "perf-167", "--godot", str(TOOLS / "fixed_clock.sh"), "--no-headless",
        "--display-driver", "macos", "--audio-driver", "Dummy", "--rendering-method", "mobile",
        "--rendering-driver", "metal", "--expect-size", "1920x1080",
        "--proof-contract", str(TOOLS / contract), "--result-manifest", str(directory / "visual.json"),
        str(PROBE), "--", "--capture", f"--output={directory}",
    ]
    if reduced:
        command.append("--reduced-motion")
    return invoke(command, directory, args)


def ms(value):
    return round(value / 1000, 3)


def percentiles(values):
    ordered = sorted(values)
    return {
        "median_ms": ms(statistics.median(ordered)),
        "p95_ms": ms(ordered[math.ceil(0.95 * len(ordered)) - 1]),
        "p99_ms": ms(ordered[math.ceil(0.99 * len(ordered)) - 1]),
        "mean_ms": ms(statistics.mean(ordered)),
        "max_ms": ms(ordered[-1]),
        "counts_above_ms": {str(limit): sum(value > limit * 1000 for value in ordered) for limit in THRESHOLDS_MS},
    }


def summarize_take(report):
    stages = report["stage_usec"]
    menu = [frame for frame in report["frames"] if frame["phase"] in MENU_PHASES]
    return {
        "menu": percentiles([frame["interval_us"] for frame in menu]),
        "menu_first_frame_ms": ms(menu[0]["interval_us"]),
        "menu_canvas_compilations": sum(frame["canvas_compilations"] for frame in menu),
        "seal_hold_ms": ms(stages["fade_out"] - stages["hold"]),
        "splash_ms": ms(stages["menu_black"] - stages["fade_in"]),
        "input_ready_ms": ms(stages["complete"] - stages["fade_in"]),
        "menu_reveal_ms": ms(stages["complete"] - stages["menu_fade_in"]),
    }


def compare_cell(profile, baseline, candidate):
    a = max(take["menu"]["max_ms"] for take in baseline)
    b = max(take["menu"]["max_ms"] for take in candidate)
    improvement = 1 - b / a
    paired_deltas = {
        field: round(statistics.median(right[field] - left[field] for left, right in zip(baseline, candidate)), 3)
        for field in ("seal_hold_ms", "splash_ms", "input_ready_ms", "menu_reveal_ms")
    }
    timing_pass = all(abs(delta) <= SETTLE_TOLERANCE_MS for delta in paired_deltas.values())
    intervals_pass = improvement >= 0.5 and b <= 100 if profile == "background" else b <= a
    return {
        "baseline_worst_ms": a, "candidate_worst_ms": b, "worst_reduction_pct": round(improvement * 100, 2),
        "median_paired_timing_delta_ms": paired_deltas,
        "timing_pass": timing_pass, "intervals_pass": intervals_pass,
    }


def run_timing(args):
    environment = None
    all_takes = {}
    cells = {}
    for profile in PROFILES:
        for pair in range(1, PAIR_COUNT + 1):
            order = ("baseline", "candidate") if pair % 2 else ("candidate", "baseline")
            for side in order:
                project = getattr(args, side)
                home = f"{profile}-{pair}-{side}"
                for cache in ("cold", "warm"):
                    directory = args.output / f"{home}-{cache}"
                    if (args.output / "homes" / home).exists() != (cache == "warm"):
                        raise ValueError(f"{cache} take has unexpected cache state: {home}")
                    report = timing_take(args, project, directory, home, profile)
                    take_environment = {key: report[key] for key in ("renderer", "adapter", "godot", "cpu")}
                    if environment is None:
                        environment = take_environment
                    if take_environment != environment:
                        raise ValueError("renderer or host identity changed between takes")
                    take = summarize_take(report)
                    take["host_load"] = os.getloadavg()
                    all_takes[directory.name] = take
                    cells.setdefault((profile, cache, side), []).append(take)
    comparisons = {
        f"{profile}-{cache}": compare_cell(profile, cells[profile, cache, "baseline"], cells[profile, cache, "candidate"])
        for profile in PROFILES for cache in ("cold", "warm")
    }
    write_summary(args, {"run_environment": environment, "takes": all_takes, "comparisons": comparisons})
    return all(cell["timing_pass"] and cell["intervals_pass"] for cell in comparisons.values())


def run_pixels(args):
    matches = {}
    for mode, reduced in (("normal-motion", False), ("reduced-motion", True)):
        reports = [pixel_take(args, getattr(args, side), args.output / f"{mode}-{side}", reduced)
                   for side in ("baseline", "candidate")]
        left, right = (report["pixels"] for report in reports)
        expected = {"black", "seal_opaque", "menu_ready"}
        if not reduced:
            expected |= {"menu_black", "seal_fade_in_12", "seal_fade_out_12"}
            expected.update(f"menu_first_{num:02d}" for num in range(1, 9))
        keys = expected | left.keys() | right.keys()
        matches[mode] = {key: key in left and key in right and left[key] == right[key] for key in sorted(keys)}
    write_summary(args, {"identical_rgba_and_alpha": matches})
    return all(all(frames.values()) for frames in matches.values())


def run_trace(args):
    reports = {}
    for motion, reduced in (("normal-motion", False), ("reduced-motion", True)):
        for side in ("baseline", "candidate"):
            name = f"{motion}-{side}"
            directory = args.output / name
            report = timing_take(args, getattr(args, side), directory, name, "background", tracing=True, reduced=reduced)
            spans = {}
            for frame in report["frames"]:
                for label, duration in frame["spans_us"].items():
                    phase = spans.setdefault(frame["phase"], {})
                    phase[label] = phase.get(label, 0) + duration
            reports[name] = {
                "spans_us_by_phase": spans,
                "steam_init_usec": report["steam_init_usec"], "steam_active": report["steam_active"],
                **summarize_take(report),
            }
    write_summary(args, {"attribution": reports})
    return True


def write_summary(args, data):
    sources = {}
    for side in ("baseline", "candidate"):
        project = getattr(args, side)
        revision = subprocess.check_output(["git", "-C", str(project), "rev-parse", "HEAD"], text=True).strip()
        sources[side] = {"project": str(project), "revision": revision}
    result = {"sources": sources, "host": platform.platform(), **data}
    (args.output / "summary.json").write_text(json.dumps(result, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("timing", "pixels", "trace"))
    parser.add_argument("--baseline", required=True, type=Path)
    parser.add_argument("--candidate", default=ROOT, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--allow-steam", action="store_true", help="Enable Steam init in the isolated attribution takes.")
    args = parser.parse_args()
    if args.allow_steam and args.mode != "trace":
        parser.error("--allow-steam applies only to the attribution take")
    for field in ("baseline", "candidate", "output"):
        setattr(args, field, getattr(args, field).resolve())
    if args.baseline == args.candidate:
        parser.error("baseline and candidate must be distinct worktrees")
    if platform.system() != "Darwin":
        parser.error("this native profile requires macOS")
    args.output.mkdir(parents=True, exist_ok=False)
    run = {"timing": run_timing, "pixels": run_pixels, "trace": run_trace}[args.mode]
    passed = run(args)
    print(f"PERF167 {args.mode.upper()}: {'PASS' if passed else 'FAIL'} {args.output / 'summary.json'}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
