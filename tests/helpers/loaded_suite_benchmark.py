#!/usr/bin/env python3
"""Qualify the eight-slot suite with repeated loaded runs and a 13 GB bound."""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import json
import os
from pathlib import Path
import subprocess
import sys

import pool_width_benchmark as benchmark

TASK_ID = "qa-50"
POOL_WIDTH = 8
REQUIRED_RUNS = 3
LOAD_WORKERS = 12
MEMORY_BOUND_BYTES = 13_000_000_000
LOAD_STOP_SECONDS = 5
CPU_WORK = "while True: sum(i*i for i in range(10000))"


def qualifies(rows: list[dict]) -> bool:
    return len(rows) == REQUIRED_RUNS and all(
        row["passed"] and row["complete"] and row["actual_width"] == POOL_WIDTH
        and not row["guard_reason"]
        and max(row["peak_rss_bytes"], row["peak_footprint_bytes"]) < MEMORY_BOUND_BYTES
        for row in rows)


@contextmanager
def cpu_load(workers: int):
    processes = []
    try:
        for _worker in range(workers):
            processes.append(subprocess.Popen([sys.executable, "-c", CPU_WORK],
                                             stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                             stderr=subprocess.DEVNULL))
        yield processes
    finally:
        for process in processes:
            if process.poll() is None:
                process.terminate()
        for process in processes:
            try:
                process.wait(timeout=LOAD_STOP_SECONDS)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--load-workers", type=int, default=LOAD_WORKERS)
    args = parser.parse_args()
    if args.load_workers < 0:
        parser.error("load-workers must be nonnegative")
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    benchmark.TASK_ID = TASK_ID
    benchmark.ABORT_MEMORY_BYTES = MEMORY_BOUND_BYTES
    benchmark.MEMORY_BOUND_BYTES = MEMORY_BOUND_BYTES
    rows = []
    with cpu_load(args.load_workers) as workers:
        metadata = {"load_workers": args.load_workers, "load_pids": [p.pid for p in workers],
                    "cpu_count": os.cpu_count(), "initial_load": os.getloadavg(),
                    "memory_bound_bytes": MEMORY_BOUND_BYTES}
        (output / "workload.json").write_text(json.dumps(metadata, indent=2) + "\n")
        for index in range(1, REQUIRED_RUNS + 1):
            if any(process.poll() is not None for process in workers):
                raise RuntimeError("Owned CPU workload exited before suite completion")
            rows.append(benchmark.run_trial(output, POOL_WIDTH, "loaded-%02d-pool-8" % index))
    result = dict(metadata, runs=rows, qualified=qualifies(rows))
    (output / "summary.json").write_text(json.dumps(result, indent=2) + "\n")
    print("LOADED POOL QUALIFICATION: " + ("PASS" if result["qualified"] else "FAIL"), flush=True)
    return 0 if result["qualified"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
