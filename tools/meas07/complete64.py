#!/usr/bin/env python3
"""Restore the target sample if completed N=48 throughput fits the same deadline."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import time

from collect import (BATCH_FIGHTS, PROJECTION_MARGIN, ROOT, WORKERS, archive, command,
                     execute, sha256, write_json)
from report import write_report


def complete(scratch: Path, output: Path) -> None:
    contract = json.loads((output / "contract.json").read_text())
    if not contract["complete"] or contract["selected_n"] != 48:
        raise RuntimeError("Requires a complete N=48 sample")
    for path, digest in contract["source_sha256"].items():
        if sha256(ROOT / path) != digest:
            raise RuntimeError(f"Production source changed: {path}")
    rows = [json.loads(p.read_text()) for p in scratch.glob("fight-*.jsonl") if p.stat().st_size]
    if len(rows) != 24 * 48:
        raise RuntimeError("Scratch/archive sample mismatch")
    measured_elapsed = max(r["started_unix"] + r["elapsed_seconds"] for r in rows) - min(r["started_unix"] for r in rows)
    estimate = measured_elapsed / 3 * PROJECTION_MARGIN
    remaining = contract["deadline_unix"] - time.time()
    contract["extension_budget_check"] = {"completed_48_collection_seconds": measured_elapsed,
                                           "projected_two_repeats_seconds": estimate,
                                           "remaining_seconds": remaining, "checked_unix": time.time()}
    if estimate >= remaining:
        write_json(output / "contract.json", contract)
        print(f"MEAS07_KEEP_48 projected_extra_seconds={estimate:.1f} remaining_seconds={remaining:.1f}")
        return
    tasks = json.loads((scratch / "plan.json").read_text())
    jobs = []
    for repeat in (6, 7):
        for index, task in enumerate(tasks):
            jobs.append({"task": str(scratch / f"task-{index}.json"), "repeat": repeat,
                         "output": str(scratch / f"fight-{task['cell']}-l{task['ladder_seed']}-r{repeat}.jsonl")})
    batches = []
    for index, offset in enumerate(range(0, len(jobs), BATCH_FIGHTS)):
        path = scratch / f"extension-{index}.json"
        write_json(path, jobs[offset:offset+BATCH_FIGHTS])
        batches.append(path)
    print(f"MEAS07_RESTORE_64 projected_extra_seconds={estimate:.1f} remaining_seconds={remaining:.1f}", flush=True)
    def batch(path: Path):
        if time.time() >= contract["deadline_unix"]:
            return
        try:
            execute(command("tools/meas07/measure.gd", ["--jobs", str(path), "--deadline-unix", str(contract["deadline_unix"])],
                            max(1, contract["deadline_unix"] - time.time())), path.with_suffix(".log"), "MEAS07_BATCH_PASS")
        except RuntimeError:
            if time.time() < contract["deadline_unix"]:
                raise
    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        list(pool.map(batch, batches))
    rows = [json.loads(p.read_text()) for p in sorted(scratch.glob("fight-*.jsonl")) if p.stat().st_size]
    if len(rows) != 24 * 64:
        # Keep the complete N=48 report; preserve every extra raw observation
        # separately, without turning an incomplete extension into a full cell.
        archive(output / "extension_partial.jsonl.gz", [r for r in rows if r["repeat"] >= 6])
        archive(output / "worker_logs.jsonl.gz", [{"path": str(p), "text": p.read_text()}
                                                 for p in sorted(scratch.glob("*.log"))])
        commands = json.loads((output / "commands.json").read_text())
        commands += [json.loads(p.read_text()) for p in sorted(scratch.glob("extension-*.command.json"))]
        write_json(output / "commands.json", commands)
        contract["extension_incomplete"] = True
        contract["elapsed_seconds"] = time.time() - contract["started_unix"]
        contract["artifact_sha256"] = {p.name: sha256(p) for p in output.glob("*.gz")}
        write_json(output / "contract.json", contract)
        write_report(output)
        print("MEAS07_EXTENSION_INCOMPLETE retained_n=48")
        return
    if any(sha256(ROOT / p) != digest for p, digest in contract["source_sha256"].items()):
        raise RuntimeError("Production sources changed during extension")
    archive(output / "runs.jsonl.gz", rows)
    archive(output / "worker_logs.jsonl.gz", [{"path": str(p), "text": p.read_text()}
                                             for p in sorted(scratch.glob("*.log"))])
    commands = json.loads((output / "commands.json").read_text())
    commands += [json.loads(p.read_text()) for p in sorted(scratch.glob("extension-*.command.json"))]
    write_json(output / "commands.json", commands)
    contract.update({"extended_to_64": True, "initial_selected_n": 48, "selected_n": 64,
                     "selected_repeats": 8, "completed_fights": len(rows), "elapsed_seconds": time.time()-contract["started_unix"]})
    contract["artifact_sha256"] = {p.name: sha256(p) for p in output.glob("*.gz")}
    contract["measurement_tool_sha256"] = {str(p.relative_to(ROOT)): sha256(p)
                                          for p in sorted((ROOT / "tools/meas07").glob("*")) if p.suffix in (".py", ".gd")}
    write_json(output / "contract.json", contract)
    write_report(output)
    print(f"MEAS07_EXTENSION_PASS cohorts=24 n=64 fights={len(rows)} wall_seconds={contract['elapsed_seconds']:.1f}", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scratch-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    complete(args.scratch_dir.resolve(), args.output_dir.resolve())
