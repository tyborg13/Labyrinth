#!/usr/bin/env python3
"""Deadline-bounded best-only ladder collection; invoked by run_curve.py --ladder."""
from __future__ import annotations

from concurrent.futures import FIRST_COMPLETED, ThreadPoolExecutor, wait
import json
from pathlib import Path
import subprocess
import time

from run_curve import ROOT, FIRST_SEED, MAX_WORKERS, archive, policy_hash, read_records, sha256, worker, write_scores

LADDER_WALL_SECONDS = 45 * 60
COMPLETION_POLL_SECONDS = 10


def collect_ladder(output: Path, scratch: Path, runs: int | None, wall_seconds: float, workers: int) -> None:
    if not 1 <= workers <= MAX_WORKERS or not 0 < wall_seconds <= LADDER_WALL_SECONDS:
        raise ValueError("Use 1–3 workers and a positive launch budget of at most 45 minutes")
    if runs is not None and runs < 1:
        raise ValueError("Optional debug run limit must be positive")
    scratch.mkdir(parents=True, exist_ok=True)
    output.mkdir(parents=True, exist_ok=True)
    if any(scratch.iterdir()) or (output / "ladder_runs.jsonl.gz").exists():
        raise RuntimeError("Use fresh scratch/output files to preserve prior results")
    contract_path = output / "ladder_contract.json"
    contract = json.loads(contract_path.read_text()) if contract_path.exists() else {}
    sources = [*sorted((ROOT / "scripts").rglob("*.gd")), *sorted((ROOT / "data").glob("*.json")),
               ROOT / "tools/card_heuristic.py", ROOT / "tools/encounter_bot.gd",
               *sorted((ROOT / "tools").glob("run_curve*.gd")), *sorted((ROOT / "tools").glob("run_curve*.py"))]
    frozen = policy_hash()
    scores = output / "ladder_card_scores.json"
    write_scores(scores)
    started = time.time()
    deadline = started + wall_seconds
    contract.update({"ladder": True, "policy": "best", "first_seed": FIRST_SEED,
                     "max_workers": workers, "launch_budget_seconds": wall_seconds,
                     "debug_run_limit": runs, "started_unix": started, "deadline_unix": deadline,
                     "policy_sha256": frozen, "source_sha256": {str(p.relative_to(ROOT)): sha256(p) for p in sources},
                     "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                     "scores_sha256": sha256(scores), "source_art": "LABYRINTH_CEL_LOOK=off"})
    contract_path.write_text(json.dumps(contract, indent=2) + "\n")
    records = []
    skipped = []
    next_seed = FIRST_SEED
    with (scratch / "completed.jsonl").open("w") as live, ThreadPoolExecutor(max_workers=workers) as pool:
        active = {}
        while active or time.time() < deadline:
            while len(active) < workers and time.time() < deadline and (runs is None or next_seed < FIRST_SEED + runs):
                path = scratch / f"seed-{next_seed}.jsonl"
                job = pool.submit(worker, "best", next_seed, 1, scores, path,
                                  scratch / f"seed-{next_seed}.log", deadline, True)
                active[job] = (next_seed, path)
                next_seed += 1
            if not active: break
            done, _ = wait(active, timeout=COMPLETION_POLL_SECONDS, return_when=FIRST_COMPLETED)
            for job in done:
                seed, path = active.pop(job)
                job.result()
                rows = read_records(path)
                if not rows:
                    skipped.append(seed)  # Engine startup crossed the shared launch deadline.
                    continue
                if len(rows) != 1 or rows[0]["seed"] != seed:
                    raise RuntimeError(f"Invalid ladder seed record: {seed}")
                row = rows[0]
                if not row.get("completed_ladder") or row["end_section"] != 5:
                    raise RuntimeError(f"Ladder failed to finish all sections: {seed}")
                if row["policy_sha256"] != frozen or not row.get("ladder") or row["policy"] != "best":
                    raise RuntimeError("Ladder provenance mismatch")
                live.write(json.dumps(row, sort_keys=True) + "\n")
                live.flush()
                records.append(row)
                print(f"RUN_CURVE_LADDER_RUN_DONE seed={seed} completed={len(records)} fights={len(row['fights'])}", flush=True)
    if not records:
        raise RuntimeError("No completed ladder run; inspect worker logs")
    records.sort(key=lambda row: row["seed"])
    if policy_hash() != frozen or any(sha256(ROOT / p) != digest for p, digest in contract["source_sha256"].items()):
        raise RuntimeError("Ladder inputs changed while measuring")
    original = contract.get("original_artifact_sha256", {})
    if any(sha256(output / p) != digest for p, digest in original.items()):
        raise RuntimeError("Original whole-run artifacts changed")
    archive(records, output / "ladder_runs.jsonl.gz")
    sample = {"n": len(records), "seeds": [r["seed"] for r in records], "startup_deadline_skips": skipped,
              "elapsed_seconds": time.time() - started, "raw_bytes": (output / "ladder_runs.jsonl.gz").stat().st_size,
              "policy_sha256": frozen, "noncombat_health_clamps": sum(r["noncombat_health_clamps"] for r in records),
              "forced_victories": sum(r["forced_victories"] for r in records),
              "turn_cap_fights": sum(r["turn_cap_fights"] for r in records)}
    (output / "ladder_sample.json").write_text(json.dumps(sample, indent=2) + "\n")
    from run_curve_ladder_report import write_ladder_report
    write_ladder_report(output)
    print(f"RUN_CURVE_LADDER_SAMPLE_PASS n={len(records)} raw_bytes={sample['raw_bytes']}", flush=True)
