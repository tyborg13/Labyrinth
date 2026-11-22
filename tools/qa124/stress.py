#!/usr/bin/env python3
"""Exercise managed quit in fresh headless Godot or release probe processes."""

import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import signal
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
CASES = ("title", "pause", "movement", "enemy", "card", "cover", "startup", "idle-load", "steam")
REPETITIONS = 30
JOBS = 4
TIMEOUT_SECONDS = 40


def run_case(output, binary, case, iteration):
    log = output / f"{case}-{iteration:02d}.log"
    runner = [sys.executable, "tools/godot_task_runner.py", "--task-id", "qa-124",
              "--timeout", str(TIMEOUT_SECONDS), "--stream", "--"]
    command = ([str(binary)] if binary else
               ["godot", "--path", ".", "--script", "tools/qa124/quit_entry.gd"])
    result = subprocess.run([*runner, *command, "--headless", "--verbose", "--", f"--case={case}"],
                            cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    log.write_bytes(result.stdout + f"\nQA124 PROCESS EXIT: {result.returncode}\n".encode())
    text = result.stdout.decode(errors="replace")
    # Python's runner exits via sys.exit, so an engine SIGABRT (-6) becomes 250
    # on POSIX. Keep the returned code and the engine crash marker together.
    abort = result.returncode in (-signal.SIGABRT, 256 - signal.SIGABRT, 128 + signal.SIGABRT)
    abort = abort or "handle_crash: Program crashed" in text
    return {
        "case": case, "iteration": iteration, "exit": result.returncode,
        "armed": f"QA124 ARMED {case} " in text,
        "drained": f"QA124 QUIT TEST RESULT: PASS ({case}," in text,
        "abort": abort, "leak": "ObjectDB instances leaked at exit" in text,
        "script_error": any(marker in text for marker in ("SCRIPT ERROR:", "Parse Error:")),
        "log": str(log),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", action="append", choices=CASES)
    parser.add_argument("--runs", type=int, default=REPETITIONS)
    parser.add_argument("--jobs", type=int, default=JOBS)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--binary", type=Path, help="Executable from a release build with the packed quit probe")
    args = parser.parse_args()
    if args.runs < 1 or args.jobs < 1:
        parser.error("--runs and --jobs must be positive")
    binary = args.binary.resolve(strict=True) if args.binary else None
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    cases = args.case or CASES
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        rows = list(pool.map(
            lambda trial: run_case(output, binary, *trial),
            ((case, iteration) for iteration in range(1, args.runs + 1) for case in cases),
        ))
    (output / "results.json").write_text(json.dumps(rows, indent=2) + "\n")
    for case in cases:
        selected = [row for row in rows if row["case"] == case]
        counts = dict(sorted(Counter(row["exit"] for row in selected).items()))
        print(f"QA124 {case}: exit={counts} armed={sum(r['armed'] for r in selected)}/{len(selected)} "
              f"drained={sum(r['drained'] for r in selected)} aborts={sum(r['abort'] for r in selected)} "
              f"leaks={sum(r['leak'] for r in selected)} script_errors={sum(r['script_error'] for r in selected)}")
    passed = all(r["armed"] and r["drained"] and r["exit"] == 0 and not r["abort"] and not r["script_error"] for r in rows)
    print(f"QA124 STRESS: {'PASS' if passed else 'FAIL'} ({len(rows)} processes) {output / 'results.json'}")
    return int(not passed)


if __name__ == "__main__":
    raise SystemExit(main())
