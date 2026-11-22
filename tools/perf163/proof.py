#!/usr/bin/env python3
"""Run the hand-cycle attribution, interleaved timing and identity comparisons."""
import argparse
import json
import re
from pathlib import Path
from statistics import median
import subprocess
import sys
from tempfile import TemporaryDirectory

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
TASK = "perf-163"
PROBE = Path(__file__).with_name("probe.gd")
CONTRACT = PROBE.with_name("capture_contract.json")
PAIR_ORDERS = ("AB", "BA", "AB", "BA", "AB")
TIMEOUT_SECONDS = 180
HEADLESS_FPS = 60

sys.path.insert(0, str(TOOLS / "perf148"))
from strict import native_receipts, route

STRICT = route.load_fixture_tools()


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def environment(side):
    return {
        "LABYRINTH_PERF163_BASELINE": str(int(side == "A")),
        "LABYRINTH_PERF154_BASELINE": "0",
        "LABYRINTH_PERF148_BASELINE": "0",
        "LABYRINTH_BOARD_REDRAW_BASELINE": "0",
        "LABYRINTH_CEL_LOOK": "all",
    }


def run_take(args, side, directory, script=PROBE, flags=(), scratch=None):
    directory.mkdir(parents=True)
    probe_args = [f"--output={directory}", f"--fixtures={args.fixtures}", *flags]
    env = environment(side)
    if args.native:
        command = [
            sys.executable, str(TOOLS / "visual_probe_runner.py"), str(script),
            "--task-id", TASK, "--no-headless", "--display-driver", "macos",
            "--rendering-driver", "metal", "--rendering-method", "mobile",
            "--audio-driver", "Dummy", "--timeout", str(TIMEOUT_SECONDS),
            "--min-images", "0", "--result-manifest", str(directory / "runner.json"),
        ]
        if scratch is not None:
            env["PERF134_CAPTURE_MOVIE"] = str(Path(scratch) / "clock.avi")
            command += [
                "--godot", str(TOOLS / "perf134/capture_godot.sh"),
                "--expect-size", "1920x1080", "--proof-contract", str(CONTRACT),
            ]
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


FLOAT_TEXT = re.compile(r"-?\d+\.\d+")
POSITION_TOLERANCE = 0.05  # px


def same(a, b):
    """Witness equality with positions printed in text (e.g. "P: (x, y)") within 0.05 px: rapid-cadence takes sample tweens a hair
    apart (badge at 708.1138 vs 708.1119) without any visible difference. Everything else exact."""
    if isinstance(a, (list, tuple)) and isinstance(b, (list, tuple)):
        return len(a) == len(b) and all(same(x, y) for x, y in zip(a, b))
    if isinstance(a, dict) and isinstance(b, dict):
        return a.keys() == b.keys() and all(same(a[k], b[k]) for k in a)
    if isinstance(a, float) and isinstance(b, float):
        return a == b  # rotations, scales and other numbers stay exact (review: 0.04 rad passed before)
    if isinstance(a, str) and isinstance(b, str) and a != b:
        xs, ys = FLOAT_TEXT.findall(a), FLOAT_TEXT.findall(b)
        return (FLOAT_TEXT.sub("#", a) == FLOAT_TEXT.sub("#", b) and len(xs) == len(ys)
                and all(abs(float(x) - float(y)) <= POSITION_TOLERANCE for x, y in zip(xs, ys)))
    return a == b


def read_cycle(directory):
    data = json.loads((directory / "cycle.json").read_text())
    if (data["errors"] or len(data["samples"]) != 16
            or any(len(row["interval_usec"]) != 3 for rows in data["samples"].values() for row in rows)):
        raise ValueError(f"Incomplete hand cycle in {directory}")
    return data


def distribution(values):
    return {"median": median(values), "min": min(values), "max": max(values)}


def summarize_take(take):
    if any(len(rows) != 10 for rows in take["samples"].values()):
        raise ValueError("Incomplete timed take")
    all_intervals = [value for rows in take["samples"].values() for row in rows for value in row["interval_usec"]]
    if sum(900_000 <= usec <= 1_200_000 for usec in all_intervals) >= 3:
        raise ValueError("Repeated roughly one-second intervals invalidate frame delivery")
    cohorts = dict(take["samples"])
    for cohort, actions in (("shoulder", {"lb", "rb"}), ("hand-dpad", {"left", "right"})):
        cohorts[cohort] = [row for key, rows in take["samples"].items() if key.split("/")[-1] in actions for row in rows]
    return {
        cohort: {
            "press": STRICT.histogram([row["interval_usec"][0] for row in rows]),
            "input": STRICT.histogram([row["input_usec"] for row in rows]),
            "following": STRICT.histogram([usec for row in rows for usec in row["interval_usec"][1:]]),
        }
        for cohort, rows in cohorts.items()
    }


def timing(args):
    pairs = []
    identity = None
    for i, order in enumerate(PAIR_ORDERS, 1):
        pair = {}
        for side in order:
            directory = args.output / f"{i}-{side}"
            run_take(args, side, directory)
            take = read_cycle(directory)
            witness = tuple(take[key] for key in
                            ("fixture_sha256", "receipts", "engine", "cpu", "gpu", "display", "viewport", "max_fps"))
            if identity is not None and not same(witness, identity):
                raise ValueError(f"Timing fixture or settled receipt differed at {directory}")
            identity = witness
            pair[side] = summarize_take(take)
        pairs.append(pair)
    threshold = 0.30 if args.qos == "background" else 0.0
    checks = {}
    for cohort in ("shoulder", "hand-dpad"):
        checks[cohort] = {}
        for field in ("median_ms", "p95_ms"):
            a = [pair["A"][cohort]["press"][field] for pair in pairs]
            b = [pair["B"][cohort]["press"][field] for pair in pairs]
            reduction = distribution([1 - after / before for before, after in zip(a, b)])
            passed = reduction["median"] >= threshold
            checks[cohort][field] = {"A_ms": distribution(a), "B_ms": distribution(b),
                                     "paired_reduction": reduction, "passed": passed}
            print(f"PERF-163 {args.qos} {cohort} {field}: {'PASS' if passed else 'FAIL'} "
                  f"({median(a):.3f} -> {median(b):.3f} ms; paired reduction {reduction['median']:+.1%}; "
                  f"spread {reduction['min']:+.1%} to {reduction['max']:+.1%})")
    write_json(args.output / "summary.json", {
        "qos": args.qos, "native": args.native,
        "release_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "order": PAIR_ORDERS, "checks": checks, "pairs": pairs,
    })
    return int(not all(row["passed"] for cohort in checks.values() for row in cohort.values()))


def attribution_sections(sections):
    return {
        name: section for name, section in sections.items()
        if name.startswith("hand_") or name in ("stage_total", "deferred_layout_turn_order_anchor")
    }


def attribution(args):
    for side in "AB":
        directory = args.output / side
        run_take(args, side, directory, flags=("--detail",))
        take = read_cycle(directory)
        write_json(directory / "sections.json", {
            key: [{
                "press_usec": row["interval_usec"][0],
                "input_usec": row["input_usec"],
                "press": attribution_sections(row["press_sections"]),
                "window": attribution_sections(row["window_sections"]),
            } for row in rows]
            for key, rows in take["samples"].items()
        })
    print(f"PERF-163 ATTRIBUTION: wrote {args.output}/{{A,B}}/sections.json")
    return 0


def frames(args):
    receipts = {}
    pixels = {}
    for side in "AB":
        directory = args.output / side
        with TemporaryDirectory(prefix=f"{side}-movie-", dir=args.output) as scratch:
            run_take(args, side, directory, flags=("--frames",), scratch=scratch if args.native else None)
        receipts[side] = read_cycle(directory)["receipts"]
    fields = STRICT.mismatched_fields(receipts["A"], receipts["B"])
    if args.native:
        for name in sorted(receipts["A"].keys() | receipts["B"].keys()):
            if "/" in name:
                continue
            pixels[name] = STRICT.pixel_difference(args.output / "A" / f"{name}.png", args.output / "B" / f"{name}.png")
    different_frames = [name for name, diff in pixels.items() if diff["different_pixels"]]
    write_json(args.output / "summary.json", {"different_receipts": fields, "different_frames": different_frames, "pixels": pixels})
    passed = not fields and not different_frames
    print(f"PERF-163 IDENTITY: {'PASS' if passed else 'FAIL'} ({len(receipts['A'])} receipts, "
          f"{len(fields)} differing receipts, {len(pixels)} native frames, {len(different_frames)} differing frames)")
    return int(not passed)


def integration_identity(args):
    if args.mode == "strict":
        projects = dict.fromkeys("AB", ROOT)
        envs = {side: {**environment(side), "LABYRINTH_BOARD_REDRAW_TRACE": "timing"} for side in projects}
        if args.native:
            return native_receipts(STRICT, projects, args.output, args.fixtures, envs, TASK)
        STRICT.headless_receipts(projects, args.output, args.fixtures, TASK, envs)
        print(f"PERF-163 STRICT RECEIPTS: PASS ({len(STRICT.CAPTURES)} states)")
        return 0
    name = "forecast-receipts.json"
    for side in "AB":
        run_take(args, side, args.output / side, TOOLS / "perf140/probe.gd")
    a, b = (json.loads((args.output / side / name).read_text()) for side in "AB")
    fields = STRICT.mismatched_fields(a, b)
    write_json(args.output / "summary.json", {"different_fields": fields})
    forecasts = sum("steps" in row for row in a.values())
    print(f"PERF-140 IDENTITY: {'FAIL' if fields else 'PASS'} ({forecasts} forecasts, {len(a) - forecasts} badge receipts)")
    return int(bool(fields))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("timing", "attribution", "frames", "strict", "forecast"), required=True)
    parser.add_argument("--qos", choices=("normal", "background"), default="normal")
    parser.add_argument("--native", action="store_true")
    parser.add_argument("--fixtures", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.mode == "timing" and not args.native:
        parser.error("The frame timing gate requires --native")
    if args.mode == "forecast" and args.native:
        parser.error("Forecast receipts use the headless fixture")
    args.fixtures = args.fixtures.resolve(strict=True)
    args.output = args.output.resolve()
    args.output.mkdir(parents=True)
    (args.output / ".gdignore").touch()
    operations = {"timing": timing, "attribution": attribution, "frames": frames,
                  "strict": integration_identity, "forecast": integration_identity}
    return operations[args.mode](args)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"PERF-163: {error}", file=sys.stderr)
        raise SystemExit(1)
