#!/usr/bin/env python3
"""Run all 14 perf134 receipt or pixel comparisons with the perf148 A/B switch."""
import argparse
import json
from pathlib import Path
from subprocess import SubprocessError
import sys
from tempfile import TemporaryDirectory

from measure import ROOT, TARGETING_TASK, TASK_ID, comparison_environment, route


def native_receipts(strict, projects, output, bundle, environments, task_id):
    captures = output / "captures"
    captures.mkdir(parents=True, exist_ok=True)
    states = {}
    for state in strict.CAPTURES:
        diff_path = captures / f"{state}-diff.json"
        try:
            difference = strict.capture(projects, output, state, bundle, task_id, environments, enforce=False)
        except (OSError, ValueError, SubprocessError) as error:
            difference = {"error": str(error), "different_pixels": None, "mismatched_state_fields": None}
            diff_path.write_text(json.dumps(difference, indent=2) + "\n")
            print(f"{task_id.upper()} PIXELS: {state} could not be compared ({diff_path})", flush=True)
        passed = not (difference.get("error") or difference["different_pixels"] or difference["mismatched_state_fields"])
        states[state] = {**difference, "passed": passed, "diff": str(diff_path)}
    passed_count = sum(result["passed"] for result in states.values())
    report = {"passed": passed_count, "failed": len(states) - passed_count, "states": states}
    summary_path = captures / "summary.json"
    summary_path.write_text(json.dumps(report, indent=2) + "\n")
    print(f"{task_id.upper()} STRICT PIXELS: {'PASS' if not report['failed'] else 'FAIL'} "
          f"({passed_count}/{len(states)} states identical) {summary_path}", flush=True)
    return int(bool(report["failed"]))


def native_confirmations(strict, output, bundle, environments, task_id):
    """Compare the frame that keeps the existing sprite children across the aim exit."""
    probe = ROOT / "tools/perf134/probe.gd"
    contract = ROOT / "tools/perf157/capture_contract.json"
    output.mkdir(parents=True, exist_ok=True)
    for side in "AB":
        directory = output / side
        directory.mkdir()
        with TemporaryDirectory(prefix=f"{side}-movie-", dir=output) as scratch:
            command = [
                sys.executable, str(ROOT / "tools/visual_probe_runner.py"), str(probe),
                "--project", str(ROOT), "--task-id", task_id, "--no-headless",
                "--display-driver", "macos", "--rendering-driver", "metal", "--rendering-method", "mobile",
                "--audio-driver", "Dummy", "--godot", str(probe.with_name("capture_godot.sh")),
                "--expect-size", "1920x1080", "--timeout", "90", "--proof-contract", str(contract),
                "--result-manifest", str(directory / "validation.json"), "--",
                f"--output={directory}", f"--fixtures={bundle}", "--fixed-fps", "60",
                "--board-redraw-route=res://tools/perf157/transition_route.gd", "--capture-targeting-transitions",
            ]
            strict.run(command, ROOT, {**environments[side], "LABYRINTH_BOARD_REDRAW_TRACE": "inputs",
                                      "PERF134_CAPTURE_MOVIE": str(Path(scratch) / "clock.avi")})
    states = {}
    for room in ("normal", "tharokh"):
        for action in ("cancel", "confirm"):
            name = f"{room}-{action}"
            states[name] = strict.pixel_difference(output / "A" / f"{name}.png", output / "B" / f"{name}.png")
            print(f"{task_id.upper()} {name}: {states[name]['different_pixels']} differing pixels", flush=True)
    (output / "summary.json").write_text(json.dumps(states, indent=2) + "\n")
    return int(any(state["different_pixels"] for state in states.values()))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixtures", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    renderer = parser.add_mutually_exclusive_group()
    renderer.add_argument("--native", action="store_true")
    renderer.add_argument("--native-confirm", action="store_true", help="Compare the four aim exit frames")
    parser.add_argument("--perf157", action="store_true", help="Compare targeting routing against the perf-157 release base")
    args = parser.parse_args()
    if args.native_confirm and not args.perf157:
        parser.error("--native-confirm requires --perf157")
    strict = route.load_fixture_tools()
    projects = dict.fromkeys("AB", ROOT)
    task_id = TARGETING_TASK if args.perf157 else TASK_ID
    environments = {
        side: {**comparison_environment(side, args.perf157), "LABYRINTH_BOARD_REDRAW_TRACE": "timing"}
        for side in projects
    }
    output = args.output.resolve()
    bundle = args.fixtures.resolve()
    if args.native_confirm:
        return native_confirmations(strict, output, bundle, environments, task_id)
    if args.native:
        return native_receipts(strict, projects, output, bundle, environments, task_id)
    strict.headless_receipts(projects, output, bundle, task_id, environments)
    print(f"{task_id.upper()} STRICT RECEIPTS: PASS ({len(strict.CAPTURES)} states)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
