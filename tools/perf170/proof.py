#!/usr/bin/env python3
"""Attribute and compare controller X and B press frames."""
import argparse
import json
import subprocess
import sys
from pathlib import Path
from statistics import median
from tempfile import TemporaryDirectory

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
TASK = "perf-170"
PROBE = Path(__file__).with_name("probe.gd")
EDGE_PROBE = PROBE.with_name("edge_replay.gd")
CONTRACT = PROBE.with_name("capture_contract.json")
TIMEOUT_SECONDS = 180
HEADLESS_FPS = 60
PAIR_ORDERS = ("AB", "BA", "AB", "BA", "AB")
SAMPLES_PER_PHASE = 10
LEGACY_CYCLE_RECEIPTS = 60
ENCOUNTERS = ("normal", "tharokh")
PHASES = ("x-open", "x-tuck", "x-cancel", "b-tuck", "b-cancel", "b-idle")
TAB_ROUTES = ("x-cancel", "b-cancel", "rapid-x-b", "mouse-x-cancel", "mouse-b-cancel")
TAB_REVEAL_FRAMES = 12
TAB_CAPTURE_FRAMES = (1, TAB_REVEAL_FRAMES)
SLOW_REDUCTION = 0.30

sys.path.insert(0, str(ROOT))
from tools.perf163.proof import STRICT, distribution, native_receipts, same, write_json


def environment(side):
    return {
        "LABYRINTH_PERF170_BASELINE": str(int(side == "A")),
        "LABYRINTH_PERF163_BASELINE": "0",
        "LABYRINTH_PERF154_BASELINE": "0",
        "LABYRINTH_PERF148_BASELINE": "0",
        "LABYRINTH_BOARD_REDRAW_BASELINE": "0",
        "LABYRINTH_CEL_LOOK": "all",
    }


def run_take(args, side, directory, script=PROBE, flags=(), movie=None):
    directory.mkdir(parents=True)
    probe_args = [f"--output={directory}", f"--fixtures={args.fixtures}", *flags]
    env = environment(side)
    if script == EDGE_PROBE:
        # The Chain restart also needs the original perf-163 hand tooltip path.
        env["LABYRINTH_PERF163_BASELINE"] = str(int(side == "A"))
    if args.native:
        command = [
            sys.executable, str(TOOLS / "visual_probe_runner.py"), str(script),
            "--task-id", TASK, "--no-headless", "--display-driver", "macos",
            "--rendering-driver", "metal", "--rendering-method", "mobile",
            "--audio-driver", "Dummy", "--timeout", str(TIMEOUT_SECONDS),
            "--min-images", "0", "--result-manifest", str(directory / "runner.json"),
        ]
        if movie is not None:
            env["PERF134_CAPTURE_MOVIE"] = str(movie)
            command += ["--godot", str(TOOLS / "perf134/capture_godot.sh")]
            if script == PROBE:
                command += ["--expect-size", "1920x1080", "--proof-contract", str(CONTRACT)]
        command += ["--", *probe_args]
    else:
        command = [
            sys.executable, str(TOOLS / "godot_task_runner.py"), "--task-id", TASK, "--stream",
            "--", "godot", "--headless", "--fixed-fps", str(HEADLESS_FPS), "--path", str(ROOT),
            "--script", str(script), "--", *probe_args,
        ]
    if args.qos == "background":
        command = ["taskpolicy", "-c", "background", *command]
    STRICT.run(command, ROOT, env)


def read_take(directory, count, native):
    take = json.loads((directory / "cycle.json").read_text())
    expected = {f"{encounter}/{phase}" for encounter in ENCOUNTERS for phase in PHASES}
    if take["errors"] or take["headless"] == native or set(take["samples"]) != expected:
        raise ValueError(f"Incomplete or invalid press route in {directory}")
    intervals = []
    for key, rows in take["samples"].items():
        if len(rows) != count or any(len(row["interval_usec"]) != 3 for row in rows):
            raise ValueError(f"Incomplete press sample for {key} in {directory}")
        intervals.extend(value for row in rows for value in row["interval_usec"])
    if native:
        if min(intervals) <= 0 or sum(900_000 <= usec <= 1_200_000 for usec in intervals) >= 3:
            raise ValueError(f"Invalid native frame delivery in {directory}")
    return take


def attribution(args):
    details = {}
    for side in "AB":
        directory = args.output / side
        run_take(args, side, directory, flags=("--detail",))
        take = read_take(directory, 1, args.native)
        details[side] = {key: rows[0] for key, rows in take["samples"].items()}
        if args.native and any(not row["native_boundaries_usec"] for row in details[side].values()):
            raise ValueError(f"Incomplete native boundary attribution in {directory}")
        write_json(directory / "sections.json", details[side])
    for key, rows in details["A"].items():
        candidate = details["B"][key]
        print(f"PERF-170 ATTRIBUTION {key} input {rows['input_usec']} -> {candidate['input_usec']} us")
    print(f"PERF-170 ATTRIBUTION: wrote {args.output}/{{A,B}}/sections.json")


def summarize(take):
    cohorts = dict(take["samples"])
    for button in ("x", "b"):
        # Idle B is the route control. The player has no adjustment to cancel.
        cohorts[button] = [row for key, rows in take["samples"].items()
                           if key.split("/")[-1].startswith(button) and not key.endswith("/b-idle")
                           for row in rows]
    return {
        cohort: {
            "press": STRICT.histogram([row["interval_usec"][0] for row in rows]),
            "following": STRICT.histogram([usec for row in rows for usec in row["interval_usec"][1:]]),
            "input": STRICT.histogram([row["input_usec"] for row in rows]),
            "monitors": {name: distribution([row["press_monitors"][name] for row in rows])
                         for name in rows[0]["press_monitors"]},
        }
        for cohort, rows in cohorts.items()
    }


def timing(args):
    pairs = []
    witness = None
    for index, order in enumerate(PAIR_ORDERS, 1):
        pair = {}
        for side in order:
            directory = args.output / f"{index}-{side}"
            run_take(args, side, directory)
            take = read_take(directory, SAMPLES_PER_PHASE, True)
            current = {key: take[key] for key in ("fixture_sha256", "receipts", "engine", "os",
                                                 "cpu", "gpu", "display", "viewport", "max_fps")}
            if len(take["receipts"]) != len(ENCOUNTERS) * len(PHASES):
                raise ValueError(f"Incomplete settled receipts in {directory}")
            if witness is not None and not same(current, witness):
                raise ValueError(f"Timing environment or settled receipt differed in {directory}")
            witness = current
            pair[side] = summarize(take)
        pairs.append(pair)
    checks = {}
    for button in ("x", "b"):
        checks[button] = {}
        for field in ("p95_ms", "max_ms"):
            base = [pair["A"][button]["press"][field] for pair in pairs]
            candidate = [pair["B"][button]["press"][field] for pair in pairs]
            reduction = distribution([1 - after / before for before, after in zip(base, candidate)])
            threshold = SLOW_REDUCTION if args.qos == "background" else 0.0
            passed = reduction["median"] >= threshold
            checks[button][field] = {"A_ms": distribution(base), "B_ms": distribution(candidate),
                                     "paired_reduction": reduction, "passed": passed}
            print(f"PERF-170 {args.qos} {button.upper()} {field}: {'PASS' if passed else 'FAIL'} "
                  f"({median(base):.3f} -> {median(candidate):.3f} ms; "
                  f"paired reduction {reduction['median']:+.1%}; "
                  f"range {reduction['min']:+.1%} to {reduction['max']:+.1%})")
    write_json(args.output / "summary.json", {
        "qos": args.qos, "order": PAIR_ORDERS, "checks": checks, "pairs": pairs,
        "release_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
    })
    return int(not all(row["passed"] for button in checks.values() for row in button.values()))


def frames(args):
    receipts = {}
    for side in "AB":
        directory = args.output / side
        with TemporaryDirectory(prefix=f"{side}-movie-", dir=args.output) as scratch:
            movie = Path(scratch) / "clock.avi" if args.native else None
            run_take(args, side, directory, flags=("--frames",), movie=movie)
        receipts[side] = read_take(directory, 1, args.native)["receipts"]
    expected = {f"{encounter}-{phase}-{frame:02d}" for encounter in ENCOUNTERS for phase in PHASES
                for frame in range(4)}
    tab_routes = {f"{encounter}/intent-tabs/{route}" for encounter in ENCOUNTERS for route in TAB_ROUTES}
    expected.update(f"{route.replace('/', '-')}-{frame:02d}"
                    for route in tab_routes for frame in TAB_CAPTURE_FRAMES)
    if any(set(rows) != expected | tab_routes for rows in receipts.values()):
        raise ValueError("Incomplete frame receipts")
    tab_differences = {}
    for route in sorted(tab_routes):
        base, candidate = (receipts[side][route]["frames"] for side in "AB")
        if len(base) != TAB_REVEAL_FRAMES or len(candidate) != TAB_REVEAL_FRAMES:
            raise ValueError(f"Incomplete tab reveal sequence for {route}")
        if route in ("tharokh/intent-tabs/x-cancel", "tharokh/intent-tabs/b-cancel"):
            before = receipts["A"][route]["before"]
            for actor in before:
                if not any(0.0 < frame.get(actor, {}).get("reveal", 0.0) < 1.0 for frame in base):
                    raise ValueError(f"Baseline did not show the opening tween for {route}/{actor}")
        mismatches = [index for index, (left, right) in enumerate(zip(base, candidate), 1) if left != right]
        if mismatches:
            tab_differences[route] = mismatches
    different_receipts = STRICT.mismatched_fields(receipts["A"], receipts["B"])
    pixels = {
        name: STRICT.pixel_difference(args.output / "A" / f"{name}.png", args.output / "B" / f"{name}.png")
        for name in sorted(expected)
    } if args.native else {}
    different_frames = [name for name, diff in pixels.items() if diff["different_pixels"]]
    write_json(args.output / "summary.json", {"different_receipts": different_receipts,
                                             "different_tab_reveal_frames": tab_differences,
                                             "different_frames": different_frames, "pixels": pixels})
    passed = not different_receipts and not different_frames
    print(f"PERF-170 INTENT TABS: {'FAIL' if tab_differences else 'PASS'} "
          f"({len(tab_routes)} routes, {len(tab_routes) * TAB_REVEAL_FRAMES} frame samples, "
          f"{sum(map(len, tab_differences.values()))} differing)")
    print(f"PERF-170 IDENTITY: {'PASS' if passed else 'FAIL'} ({len(expected | tab_routes)} receipts, "
          f"{len(different_receipts)} differing receipts, {len(pixels)} native frames, "
          f"{len(different_frames)} differing frames)")
    edge_status = edges(args, args.output / "edges")
    return int(not passed or edge_status)


def edges(args, output=None):
    output = args.output if output is None else output
    output.mkdir(parents=True, exist_ok=True)
    cases = {"erupt-tooltip", "chain-dpad", "chain-rb"}
    receipts = {}
    for side in "AB":
        directory = output / side
        with TemporaryDirectory(prefix=f"{side}-edge-clock-", dir=output) as scratch:
            movie = Path(scratch) / "clock.avi" if args.native else None
            run_take(args, side, directory, script=EDGE_PROBE, movie=movie)
        take = json.loads((directory / "cycle.json").read_text())
        if take["errors"] or take["headless"] == args.native or set(take["receipts"]) != cases:
            raise ValueError(f"Incomplete tooltip edge receipts in {directory}")
        receipts[side] = take["receipts"]
    base = receipts["A"]
    if base["erupt-tooltip"]["press"]:
        raise ValueError("The baseline Erupt tooltip hit before the next draw")
    for route in ("chain-dpad", "chain-rb"):
        row = base[route]
        if not row["replaced"] or row["frames"][-1] < 0 or row["frames"][-1] >= row["start"]:
            raise ValueError(f"The baseline did not restart playback on {route}")
    differences = STRICT.mismatched_fields(base, receipts["B"])
    write_json(output / "summary.json", {"different_receipts": differences, "receipts": receipts})
    print(f"PERF-170 TOOLTIP EDGES: {'FAIL' if differences else 'PASS'} "
          f"({len(cases)} routes, {len(differences)} differing)")
    return int(bool(differences))


def integration(args):
    if args.mode == "strict":
        projects = dict.fromkeys("AB", ROOT)
        envs = {side: {**environment(side), "LABYRINTH_BOARD_REDRAW_TRACE": "timing"} for side in projects}
        if args.native:
            return native_receipts(STRICT, projects, args.output, args.fixtures, envs, TASK)
        STRICT.headless_receipts(projects, args.output, args.fixtures, TASK, envs)
        print(f"PERF-170 STRICT RECEIPTS: PASS ({len(STRICT.CAPTURES)} states)")
        return 0
    cycling = args.mode == "cycle"
    script = TOOLS / ("perf163/probe.gd" if cycling else "perf140/probe.gd")
    name = "cycle.json" if cycling else "forecast-receipts.json"
    receipts = {}
    for side in "AB":
        directory = args.output / side
        run_take(args, side, directory, script, flags=("--frames",) if cycling else ())
        data = json.loads((directory / name).read_text())
        if cycling and (data["errors"] or len(data["receipts"]) != LEGACY_CYCLE_RECEIPTS):
            raise ValueError(f"Incomplete perf-163 cycle in {directory}")
        receipts[side] = data["receipts"] if cycling else data
    different = STRICT.mismatched_fields(receipts["A"], receipts["B"])
    write_json(args.output / "summary.json", {"different_fields": different})
    status = "FAIL" if different else "PASS"
    if cycling:
        print(f"PERF-163 IDENTITY: {status} ({len(receipts['A'])} receipts, {len(different)} differing)")
    else:
        forecasts = sum("steps" in row for row in receipts["A"].values())
        print(f"PERF-140 IDENTITY: {status} "
              f"({forecasts} forecasts, {len(receipts['A']) - forecasts} badge receipts)")
    return int(bool(different))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    operations = {"attribution": attribution, "timing": timing, "frames": frames, "edges": edges,
                  "strict": integration, "forecast": integration, "cycle": integration}
    parser.add_argument("--mode", choices=operations, required=True)
    parser.add_argument("--qos", choices=("normal", "background"), default="normal")
    parser.add_argument("--native", action="store_true")
    parser.add_argument("--fixtures", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.mode == "timing" and not args.native:
        parser.error("The press frame gate requires --native")
    if args.mode in ("forecast", "cycle") and args.native:
        parser.error("Use headless mode for forecast and legacy hand cycle receipts")
    args.fixtures = args.fixtures.resolve(strict=True)
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=False)
    (args.output / ".gdignore").touch()
    return operations[args.mode](args)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"PERF-170: {error}", file=sys.stderr)
        raise SystemExit(1)
