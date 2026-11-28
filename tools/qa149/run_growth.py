#!/usr/bin/env python3
"""Run the three headless QA149 routes and retain one verbose engine log each."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
ROUTES = ("A", "B", "C")
CYCLE_COUNT = 5
FIXED_FPS = 120


def run_route(route: str, output: Path) -> tuple[str, bool, bool]:
    env = dict(os.environ, QA149_ROUTE=route, LABYRINTH_DEMO="1")
    command = [sys.executable, "tools/godot_task_runner.py", "--task-id", "qa-149", "--stream",
               "--", "godot", "--headless", "--verbose", "--fixed-fps", str(FIXED_FPS),
               "--path", ".", "--script", "tools/qa149/growth_probe.gd"]
    log_path = output / f"route-{route}.log"
    with log_path.open("w") as log:
        status = subprocess.run(command, cwd=ROOT, env=env, stdout=log,
                                stderr=subprocess.STDOUT, check=False).returncode
    log = log_path.read_text(errors="replace")
    growth = [line for line in log.splitlines() if line.startswith(f"QA149 GROWTH {route} ")]
    cycles = re.findall(rf"^QA149 GROWTH {route} cycle=(\d+) ", log, re.MULTILINE)
    complete = status == 0 and cycles == list(map(str, range(1, CYCLE_COUNT + 1))) and len(growth) == CYCLE_COUNT + 1
    flat = complete and growth[-1].endswith(" FLAT")
    report = "\n".join([*growth, f"QA149 ROUTE {route} exit={status} log={log_path}"])
    return report, complete, flat


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--route", choices=ROUTES)
    args = parser.parse_args()
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=False)
    routes = (args.route,) if args.route else ROUTES
    with ThreadPoolExecutor(max_workers=len(routes)) as pool:
        results = list(pool.map(lambda route: run_route(route, output), routes))
    for report, _, _ in results:
        print(report)
    if not all(complete for _, complete, _ in results):
        return 1
    if not all(flat for _, _, flat in results):
        return 2
    if len(routes) == len(ROUTES):
        print("QA149 PASS routes=3")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
