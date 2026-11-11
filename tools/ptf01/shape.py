#!/usr/bin/env python3
"""Interleave old/new Section I runs through the existing run_curve policy."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import json
import os
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import run_curve  # noqa: E402

OUTPUT = Path("/private/tmp/labyrinth_codex/ptf-01")
WALL_SECONDS = 2400


def worker(first_seed, runs, scores, deadline):
    remaining = max(1, deadline - time.time())
    cmd = [sys.executable, "tools/godot_task_runner.py", "--task-id", "ptf-01",
           "--timeout", str(remaining), "--stream", "--", "godot", "--headless",
           "--path", ".", "--script", "tools/ptf01/shape.gd", "--",
           "--scores", str(scores), "--output", str(OUTPUT / f"shape-{first_seed}.jsonl"),
           "--seed", str(first_seed), "--runs", str(runs)]
    with (OUTPUT / f"shape-{first_seed}.log").open("w") as log:
        result = subprocess.run(cmd, cwd=ROOT, env={**os.environ, "LABYRINTH_CEL_LOOK": "off"},
                                stdout=log, stderr=subprocess.STDOUT)
    return {"first_seed": first_seed, "runs": runs, "exit_code": result.returncode}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--continue-existing", action="store_true",
                        help="Use the original worker's deadline; add seeds 11-30 in two workers")
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    scores = OUTPUT / "card_scores.json"
    run_curve.write_scores(scores)
    started = time.time()
    if args.continue_existing:
        started = json.loads((OUTPUT / "shape_contract.json").read_text())["started_unix"]
    contract = {"policy_sha256": run_curve.policy_hash(), "policy": "best",
                "requested_per_variant": 30, "section": "I", "interleaved": True,
                "health_carries_over": True, "wall_seconds": WALL_SECONDS,
                "workers": 3, "started_unix": started,
                "continued_original_worker": args.continue_existing}
    path = OUTPUT / "shape_pool_contract.json"
    path.write_text(json.dumps(contract, indent=2) + "\n")
    first_seeds = [11, 21] if args.continue_existing else [1, 11, 21]
    with ThreadPoolExecutor(max_workers=3) as pool:
        futures = [pool.submit(worker, seed, 10, scores, started + WALL_SECONDS) for seed in first_seeds]
        contract["results"] = [future.result() for future in futures]
    contract["elapsed_seconds"] = time.time() - started
    path.write_text(json.dumps(contract, indent=2) + "\n")
    print(f"PTF01 SHAPE POOL: {contract['results']}", flush=True)
    return 0 if all(row["exit_code"] == 0 for row in contract["results"]) else 1


if __name__ == "__main__":
    raise SystemExit(main())
