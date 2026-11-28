#!/usr/bin/env python3
"""Run the two receipt-delivery regressions and compare them with baseline logs."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
FINDINGS = ("later_checkpoint", "departing_transition")
EVENTS = ["combat_ended", "reward_offered"]
MARKER = "QA147R1 RESULT "


def read_result(log):
    return next(json.loads(line.removeprefix(MARKER))
                for line in log.read_text().splitlines() if line.startswith(MARKER))


def measure(result):
    if result["finding"] == "later_checkpoint":
        return f'retained:{result["retained"]},rows:{len(result["rows"])}'
    return f'live_writes:{result["live_writes"]},pre_continue:{result["before_continue"]},rows:{len(result["rows"])}'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--before", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True)
    all_passed = True
    for finding in FINDINGS:
        before = read_result(args.before / (finding + ".log"))
        log = args.output_dir / (finding + ".log")
        command = [sys.executable, "tools/godot_task_runner.py", "--task-id", "qa-147", "--stream",
                   "--", "godot", "--headless", "--path", ".", "--script", "tools/qa147/round1.gd",
                   "--", finding]
        with log.open("w") as output:
            status = subprocess.run(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT,
                                    check=False).returncode
        after = read_result(log)
        if finding == "later_checkpoint":
            baseline_reproduced = before["retained"] == 0 and before["rows"] == []
            repaired = after["retained"] == len(EVENTS)
        else:
            baseline_reproduced = before["live_writes"] == 1 and before["before_continue"] == len(EVENTS)
            repaired = after["live_writes"] == 0 and after["before_continue"] == 0
        passed = (status == 0 and before["finding"] == finding == after["finding"]
                  and not before["passed"] and baseline_reproduced
                  and after["passed"] and repaired and after["rows"] == EVENTS)
        all_passed &= passed
        print(f"QA147R1 {finding} before={measure(before)} after={measure(after)} "
              f"{'PASS' if passed else 'FAIL'}", flush=True)
    print(f"QA147R1 {'PASS' if all_passed else 'FAIL'} findings={len(FINDINGS)}")
    return 0 if all_passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
