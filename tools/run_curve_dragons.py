#!/usr/bin/env python3
"""On-demand dragon repeats from exactly recovered ladder-entry loadouts."""
from __future__ import annotations

import argparse
import base64
from concurrent.futures import FIRST_COMPLETED, ThreadPoolExecutor, wait
import gzip
import json
import os
from pathlib import Path
import subprocess
import sys
import time

from run_curve import ROOT, DEFAULT_OUTPUT, policy_hash, sha256, read_records, archive

WALL_SECONDS = 40 * 60
MAX_WORKERS = 3
RNG_REPEATS = 4
RNG_SEED_STRIDE = 1000003
POLL_SECONDS = 10


def worker(seed: int, scores: Path, directory: Path, deadline: float) -> Path:
    directory.mkdir(parents=True)
    command = [sys.executable, "tools/godot_task_runner.py", "--task-id", "meas-06", "--timeout", "0", "--stream", "--",
               "godot", "--headless", "--path", ".", "--script", "tools/run_curve_dragons.gd", "--",
               "--seed", str(seed), "--scores", str(scores), "--output-dir", str(directory), "--deadline-unix", str(deadline)]
    with (directory / "worker.log").open("w") as stream:
        result = subprocess.run(command, cwd=ROOT, env={**os.environ, "LABYRINTH_CEL_LOOK": "off"}, stdout=stream, stderr=subprocess.STDOUT)
    if result.returncode or f"DRAGON_WORKER_PASS seed={seed}" not in (directory / "worker.log").read_text():
        raise RuntimeError(f"Dragon worker failed: {directory / 'worker.log'}")
    return directory


def collect(output: Path, scratch: Path, workers: int, wall_seconds: float, max_seed: int) -> None:
    if not 1 <= workers <= MAX_WORKERS or not 0 < wall_seconds <= WALL_SECONDS:
        raise ValueError("Use 1–3 workers and at most 40 minutes for launches")
    if scratch.exists() and any(scratch.iterdir()):
        raise RuntimeError("Use a fresh scratch directory")
    if (output / "dragons_runs.jsonl.gz").exists():
        raise RuntimeError("Preserve previous dragon measurements; use a new output directory")
    output.mkdir(parents=True, exist_ok=True)
    scratch.mkdir(parents=True, exist_ok=True)
    with gzip.open(DEFAULT_OUTPUT / "ladder_runs.jsonl.gz", "rt") as stream:
        reference = {r["seed"]: r for r in map(json.loads, stream)}
    if max_seed not in reference or not all(s in reference for s in range(1, max_seed + 1)):
        raise ValueError("Request a consecutive prefix of the saved ladder seeds")
    contract_path = output / "dragons_contract.json"
    contract = json.loads(contract_path.read_text()) if contract_path.exists() else {}
    sources = [*sorted((ROOT / "scripts").rglob("*.gd")), *sorted((ROOT / "data").glob("*.json")),
               *sorted((ROOT / "tools").glob("run_curve*.gd")), *sorted((ROOT / "tools").glob("run_curve*.py")),
               ROOT / "tools/card_heuristic.py", ROOT / "tools/encounter_bot.gd"]
    started = time.time()
    deadline = started + wall_seconds
    contract.update({"started_unix": started, "deadline_unix": deadline, "launch_budget_seconds": wall_seconds,
                     "max_workers": workers, "first_ladder_seed": 1, "last_requested_ladder_seed": max_seed,
                     "combat_rng_repeats": RNG_REPEATS, "rng_seed_stride": RNG_SEED_STRIDE,
                     "policy_sha256": policy_hash(), "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                     "source_sha256": {str(p.relative_to(ROOT)): sha256(p) for p in sources},
                     "ladder_archive_sha256": sha256(DEFAULT_OUTPUT / "ladder_runs.jsonl.gz"),
                     "ladder_scores_sha256": sha256(DEFAULT_OUTPUT / "ladder_card_scores.json"),
                     "recovery_required": True, "source_art": "LABYRINTH_CEL_LOOK=off"})
    contract_path.write_text(json.dumps(contract, indent=2) + "\n")
    completed = []
    next_seed = 1
    with ThreadPoolExecutor(max_workers=workers) as pool:
        active = {}
        while active or (next_seed <= max_seed and time.time() < deadline):
            while len(active) < workers and next_seed <= max_seed and time.time() < deadline:
                directory = scratch / f"seed-{next_seed}"
                job = pool.submit(worker, next_seed, DEFAULT_OUTPUT / "ladder_card_scores.json", directory, deadline)
                active[job] = next_seed
                next_seed += 1
            if not active: break
            done, _ = wait(active, timeout=POLL_SECONDS, return_when=FIRST_COMPLETED)
            for job in done:
                seed = active.pop(job)
                directory = job.result()
                recovered = directory / "recovered.json"
                if not recovered.exists(): continue
                if json.loads(recovered.read_text()) != reference[seed]:
                    raise RuntimeError(f"Recovered ladder differs from saved ladder seed {seed}")
                completed.append(seed)
                print(f"DRAGON_RECOVERY_EQUIVALENCE_PASS seed={seed} sections=6", flush=True)
    raw = []
    loadouts = []
    for seed in sorted(completed):
        directory = scratch / f"seed-{seed}"
        rows = read_records(directory / "fights.jsonl")
        for row in rows:
            if row["repeat"] == 0:
                old = next(f for f in reference[seed]["fights"] if f["kind"] == "dragon" and f["section"] == row["section"])
                for key in ("won", "turns", "hp_lost", "hp_after", "hp_before", "turn_cap_reached", "search_capped", "decisions"):
                    if row[key] != old[key]: raise RuntimeError(f"Original dragon mismatch: {seed}/{row['section']}/{key}")
            if row["hp_before"] != row["max_hp"] or row["policy_sha256"] != contract["policy_sha256"]:
                raise RuntimeError("Invalid dragon protocol record")
        raw.extend(rows)
        for meta in read_records(directory / "inputs.jsonl"):
            path = Path(meta.pop("input_file"))
            if sha256(path) != meta["input_sha256"]: raise RuntimeError("Constructor input changed")
            meta["typed_payload_base64"] = base64.b64encode(path.read_bytes()).decode()
            loadouts.append(meta)
    present = {(r["ladder_seed"], r["repeat"], r["section"]) for r in raw}
    prefix = []
    for seed in range(1, max_seed + 1):
        incomplete = False
        for repeat in range(RNG_REPEATS):
            if not all((seed, repeat, section) in present for section in range(6)):
                incomplete = True
                break
            prefix.append([seed, repeat])
        if incomplete: break
    raw_prefix_n = len(prefix)
    prefix = prefix[:(raw_prefix_n // RNG_REPEATS) * RNG_REPEATS]
    if not prefix: raise RuntimeError("No complete four-repeat loadout prefix before the deadline")
    if policy_hash() != contract["policy_sha256"] or any(sha256(ROOT/p) != v for p,v in contract["source_sha256"].items()):
        raise RuntimeError("Dragon inputs changed during collection")
    if any(sha256(output/p) != v for p,v in contract.get("prior_artifact_sha256", {}).items()):
        raise RuntimeError("Previous measurement artifacts changed")
    raw.sort(key=lambda r: (r["ladder_seed"], r["repeat"], r["section"]))
    archive(raw, output / "dragons_runs.jsonl.gz")
    archive(loadouts, output / "dragons_loadouts.jsonl.gz")
    counts = {str(s): sum(r["section"] == s for r in raw) for s in range(6)}
    summary = {"raw_common_prefix_n": raw_prefix_n, "complete_ladder_seeds": list(range(1, len(prefix)//RNG_REPEATS + 1)), "n_per_section": len(prefix), "common_cases": prefix, "raw_counts_per_section": counts,
               "truncated_per_section": {s: n-len(prefix) for s,n in counts.items()},
               "recovered_ladder_seeds": sorted(completed), "elapsed_seconds": time.time()-started,
               "policy_sha256": contract["policy_sha256"], "raw_bytes": (output/"dragons_runs.jsonl.gz").stat().st_size}
    (output / "dragons_sample.json").write_text(json.dumps(summary, indent=2) + "\n")
    from run_curve_dragons_report import write_report
    write_report(output)
    print(f"DRAGON_SAMPLE_PASS n_per_section={len(prefix)} recovered_ladders={len(completed)} raw_fights={len(raw)}", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scratch-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--workers", type=int, default=MAX_WORKERS)
    parser.add_argument("--wall-seconds", type=float, default=WALL_SECONDS)
    parser.add_argument("--max-seed", type=int, default=25)
    args = parser.parse_args()
    collect(args.output_dir.resolve(), args.scratch_dir.resolve(), args.workers, args.wall_seconds, args.max_seed)


if __name__ == "__main__": main()
