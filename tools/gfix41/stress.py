#!/usr/bin/env python3
"""Exercise managed quit at observed phases in fresh headless Godot processes."""

import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import signal
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
TITLE_CASES = ("title", "idle-load", "idle-load-close", "idle-load-late", "idle-load-near-end", "idle-loaded")
CASES = (*TITLE_CASES, "cover", "startup", "pause", "movement", "enemy", "card", "steam")
REPETITIONS = 3
JOBS = 1
TIMEOUT_SECONDS = 40
CERTIFICATE_ERROR = 'ERROR: Condition "ret != noErr" is true. Returning: ""'


def run_case(output, case, iteration):
    log = output / f"{case}-{iteration:02d}.log"
    runner = [sys.executable, "tools/godot_task_runner.py", "--task-id", "gfix-41",
              "--timeout", str(TIMEOUT_SECONDS), "--stream", "--"]
    command = ["godot", "--path", ".", "--script", "tools/gfix41/quit_entry.gd"]
    result = subprocess.run([*runner, *command, "--headless", "--verbose", "--", f"--case={case}"],
                            cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    log.write_bytes(result.stdout + f"\nGFIX41 PROCESS EXIT: {result.returncode}\n".encode())
    text = result.stdout.decode(errors="replace")
    # Python's runner exits via sys.exit, so an engine SIGABRT (-6) becomes 250
    # on POSIX. Keep the returned code and the engine crash marker together.
    abort = result.returncode in (-signal.SIGABRT, 256 - signal.SIGABRT, 128 + signal.SIGABRT)
    abort = abort or "handle_crash: Program crashed" in text
    lines = text.splitlines()
    return {
        "case": case, "iteration": iteration, "exit": result.returncode,
        "armed": f"GFIX41 ARMED {case} " in text,
        "drained": f"GFIX41 QUIT TEST RESULT: PASS ({case}," in text,
        "abort": abort, "leak": "ObjectDB instances leaked at exit" in text,
        "observations": [line for line in lines if line.startswith(("GFIX41 ARMED", "GFIX41 EXIT"))],
        "errors": [line.strip() for line in lines if line.startswith(("ERROR:", "SCRIPT ERROR:"))],
        "pending_at_exit": any(line.startswith(f"GFIX41 EXIT {case} pending=[\"") for line in lines),
        "log": str(log),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", action="append", choices=CASES)
    parser.add_argument("--runs", type=int, default=REPETITIONS)
    parser.add_argument("--jobs", type=int, default=JOBS)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.runs < 1 or args.jobs < 1:
        parser.error("--runs and --jobs must be positive")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    cases = args.case or TITLE_CASES
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        rows = list(pool.map(
            lambda trial: run_case(output, *trial),
            ((case, iteration) for iteration in range(1, args.runs + 1) for case in cases),
        ))
    (output / "results.json").write_text(json.dumps(rows, indent=2) + "\n")
    for case in cases:
        selected = [row for row in rows if row["case"] == case]
        counts = dict(sorted(Counter(row["exit"] for row in selected).items()))
        errors = [error for row in selected for error in row["errors"]]
        print(f"GFIX41 {case}: exit={counts} armed={sum(r['armed'] for r in selected)}/{len(selected)} "
              f"drained={sum(r['drained'] for r in selected)} aborts={sum(r['abort'] for r in selected)} "
              f"leaks={sum(r['leak'] for r in selected)} pending={sum(r['pending_at_exit'] for r in selected)} "
              f"errors={len(errors) - errors.count(CERTIFICATE_ERROR)} certificate_errors={errors.count(CERTIFICATE_ERROR)}")
    passed = all(
        r["armed"] and r["drained"] and r["exit"] == 0 and not r["abort"] and not r["leak"]
        and not r["pending_at_exit"] and all(error == CERTIFICATE_ERROR for error in r["errors"])
        for r in rows
    )
    print(f"GFIX41 STRESS: {'PASS' if passed else 'FAIL'} ({len(rows)} processes) {output / 'results.json'}")
    return int(not passed)


if __name__ == "__main__":
    raise SystemExit(main())
