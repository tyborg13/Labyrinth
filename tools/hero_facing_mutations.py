#!/usr/bin/env python3
"""Run the hf-01 behavior tests against three in-memory policy mutations."""
from __future__ import annotations

import argparse
from pathlib import Path
import subprocess
import sys

MUTATIONS = ("always-front", "never-turn-on-hit", "turn-on-beat")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--task-id", default="hf-01")
    parser.add_argument("--output-dir", required=True)
    args = parser.parse_args()
    output = Path(args.output_dir).resolve()
    output.mkdir(parents=True, exist_ok=True)
    for mutation in MUTATIONS:
        result = subprocess.run(
            [sys.executable, "tools/godot_task_runner.py", "--task-id", args.task_id,
             "--stream", "--", "godot", "--headless", "--path", ".", "--script",
             "tests/hero_facing_test.gd", "--", "--mutation", mutation],
            text=True, capture_output=True,
        )
        log = result.stdout + result.stderr
        (output / (mutation + ".log")).write_text(log)
        killed = result.returncode != 0 and "HERO FACING TEST: FAIL" in log and "Parse Error" not in log
        print(f"HERO FACING MUTATION {mutation}: {'KILLED' if killed else 'FAIL'}", flush=True)
        if not killed:
            print(log)
            return 1
    print("HERO FACING MUTATIONS: PASS (3/3 killed)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
