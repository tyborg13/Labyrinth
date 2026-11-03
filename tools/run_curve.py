#!/usr/bin/env python3
"""meas-06 whole-run sampling. Every engine process uses the task runner."""
from __future__ import annotations

import argparse
import concurrent.futures
import gzip
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

import card_heuristic

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "spec/peer_benchmark/encounter_redesign/measurements/run_curve_2026-11"
POLICIES = ("best", "random", "none")
# Measurement infrastructure defaults, never gameplay configuration.
WALL_SECONDS = 60 * 60
MAX_WORKERS = 3
RUNS_PER_POLICY = 100
FIRST_SEED = 1


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def policy_hash() -> str:
    actual = sha256(ROOT / "tools/encounter_bot.gd")
    expected = json.loads((ROOT / "spec/peer_benchmark/encounter_redesign/measurements/revision7/baseline.json").read_text())["policy_sha256"]
    if actual != expected:
        raise RuntimeError(f"Frozen policy changed: {actual} != {expected}")
    return actual


def write_scores(path: Path) -> None:
    """Use the actual heuristic resolver and unrounded total, not a copied formula."""
    cards = card_heuristic.load_cards(ROOT / "data/cards.json")
    weights = card_heuristic.HeuristicWeights()
    path.write_text(json.dumps({key: card_heuristic.score_card(key, value, weights).total
                                for key, value in cards.items()}, indent=2) + "\n")


def worker(policy: str, seed: int, runs: int, scores: Path, output: Path,
           log: Path, deadline: float = 0, ladder: bool = False) -> int:
    command = [sys.executable, "tools/godot_task_runner.py", "--task-id", "meas-06",
               "--timeout", "0", "--stream", "--", "godot", "--headless", "--path", ".",
               "--script", "tools/run_curve.gd", "--", "--policy", policy,
               "--seed", str(seed), "--runs", str(runs), "--scores", str(scores),
               "--output", str(output), "--deadline-unix", str(deadline)]
    if ladder:
        command.append("--ladder")
    with log.open("w") as stream:
        result = subprocess.run(command, cwd=ROOT, env={**os.environ, "LABYRINTH_CEL_LOOK": "off"},
                                stdout=stream, stderr=subprocess.STDOUT)
    if result.returncode:
        raise RuntimeError(f"{policy} worker failed ({result.returncode}); see {log}")
    lines = log.read_text()
    if f"RUN_CURVE_WORKER_PASS policy={policy} completed=" not in lines:
        raise RuntimeError(f"{policy} worker did not finish; see {log}")
    return result.returncode


def read_records(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def archive(records: list[dict], path: Path) -> None:
    # Stable gzip bytes; JSONL records are flushed by workers as runs finish.
    with path.open("wb") as raw, gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as zipped:
        for row in records:
            zipped.write((json.dumps(row, sort_keys=True, separators=(",", ":")) + "\n").encode())
    if path.stat().st_size >= 5_000_000:
        raise RuntimeError(f"Raw archive exceeds 5 MB: {path}")


def collect(output: Path, scratch: Path, runs: int, wall_seconds: float, workers: int) -> None:
    if not 1 <= workers <= MAX_WORKERS or not 1 <= runs <= RUNS_PER_POLICY:
        raise ValueError("Use 1–3 workers and 1–100 runs per policy")
    if not 0 < wall_seconds <= WALL_SECONDS:
        raise ValueError("Launch budget must be positive and at most 60 minutes")
    output.mkdir(parents=True, exist_ok=True)
    scratch.mkdir(parents=True, exist_ok=True)
    if any((scratch / f"{policy}.jsonl").exists() for policy in POLICIES):
        raise RuntimeError("Use a fresh scratch directory to preserve prior results")
    frozen_hash = policy_hash()
    scores = output / "card_scores.json"
    write_scores(scores)
    source_paths = sorted(set(["data/cards.json", "data/equipment.json", "data/enemies.json", "data/events.json",
                              "tools/card_heuristic.py", "tools/encounter_bot.gd"] +
                             [str(p.relative_to(ROOT)) for p in (ROOT / "tools").glob("run_curve*.*")
                              if p.suffix in (".py", ".gd")] +
                             [str(p.relative_to(ROOT)) for p in (ROOT / "scripts").glob("*.gd")] +
                             [str(p.relative_to(ROOT)) for p in (ROOT / "data").glob("*.json")]))
    started = time.time()
    deadline = started + wall_seconds
    contract = {"task_id": "meas-06", "risk_tier": "standard", "first_seed": FIRST_SEED,
                "requested_runs_per_policy": runs, "max_workers": workers,
                "launch_budget_seconds": wall_seconds, "started_unix": started,
                "deadline_unix": deadline, "policy_version": 2, "policy_sha256": frozen_hash,
                "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                "source_sha256": {p: sha256(ROOT / p) for p in source_paths},
                "scores_sha256": sha256(scores), "source_art": "LABYRINTH_CEL_LOOK=off",
                "acceptance": ["Production whole runs, default progression, 24 Health, section maps",
                               "Director route and noncombat policy; frozen combat policy v2",
                               "Best/random/none paired common seed prefix, flushed run records",
                               "At most 100 runs/policy, at most 3 workers, no launches after 60 minutes",
                               "Reach/entry/fight tables, fixed-deck reference, comparison only, death decks, raw <5 MB"],
                "proof": "tools/run_curve_test.py: same seeded whole run twice and unchanged policy hash",
                "inspection": "not applicable: measurement only, headless; no UI or gameplay changes"}
    (output / "contract.json").write_text(json.dumps(contract, indent=2) + "\n")
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        futures = [pool.submit(worker, p, FIRST_SEED, runs, scores, scratch / f"{p}.jsonl",
                               scratch / f"{p}.log", deadline) for p in POLICIES]
        for future in concurrent.futures.as_completed(futures):
            future.result()
    by_policy = {p: read_records(scratch / f"{p}.jsonl") for p in POLICIES}
    common_n = min(map(len, by_policy.values()))
    if common_n == 0:
        raise RuntimeError("No common completed seed prefix; inspect worker logs")
    all_records = []
    for policy, records in by_policy.items():
        if [r["seed"] for r in records] != list(range(FIRST_SEED, FIRST_SEED + len(records))):
            raise RuntimeError(f"Non-contiguous seed stream: {policy}")
        if any(r["policy_sha256"] != frozen_hash or r["policy"] != policy for r in records):
            raise RuntimeError("Worker provenance mismatch")
        all_records.extend(records)
    if policy_hash() != frozen_hash:
        raise RuntimeError("Policy changed while measuring")
    changed = [p for p, digest in contract["source_sha256"].items() if sha256(ROOT / p) != digest]
    if changed:
        raise RuntimeError(f"Inputs changed while measuring: {changed}")
    archive(all_records, output / "runs.jsonl.gz")
    summary = {"completed_per_policy": {p: len(r) for p, r in by_policy.items()},
               "common_n": common_n, "elapsed_seconds": time.time() - started,
               "truncated_runs": {p: len(r) - common_n for p, r in by_policy.items()},
               "raw_bytes": (output / "runs.jsonl.gz").stat().st_size,
               "policy_sha256": frozen_hash}
    (output / "sample.json").write_text(json.dumps(summary, indent=2) + "\n")
    from run_curve_report import write_report
    write_report(output)
    print(f"RUN_CURVE_SAMPLE_PASS common_n={common_n} completed={summary['completed_per_policy']} raw_bytes={summary['raw_bytes']}", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--scratch-dir", type=Path, required=True)
    parser.add_argument("--runs", type=int, default=None)
    parser.add_argument("--ladder", action="store_true")
    parser.add_argument("--wall-seconds", type=float, default=None)
    parser.add_argument("--workers", type=int, default=MAX_WORKERS)
    args = parser.parse_args()
    if args.ladder:
        from run_curve_ladder import collect_ladder, LADDER_WALL_SECONDS
        collect_ladder(args.output_dir.resolve(), args.scratch_dir.resolve(), args.runs,
                       args.wall_seconds if args.wall_seconds is not None else LADDER_WALL_SECONDS, args.workers)
    else:
        collect(args.output_dir.resolve(), args.scratch_dir.resolve(),
                args.runs if args.runs is not None else RUNS_PER_POLICY,
                args.wall_seconds if args.wall_seconds is not None else WALL_SECONDS, args.workers)


if __name__ == "__main__":
    main()
