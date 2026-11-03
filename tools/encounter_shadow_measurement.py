#!/usr/bin/env python3
"""Collect the meas-04 default/clear standard-room comparison, headless only."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import subprocess
import sys

from encounter_bot import compress_report
from encounter_sweep import MEASUREMENT_TIMEOUT_SECONDS, ROOT

TASK_ID = "meas-04"
DEFAULT_WORKERS = 4
SEEDS_PER_BATCH = 20
LOG_ROOT = Path("/private/tmp/labyrinth_codex/meas-04")
ARTIFACTS = ROOT / "spec/peer_benchmark/encounter_redesign/measurements/shadow_2026-11"


def batches(first_seed: int, runs: int) -> list[dict]:
    # Larger tiers first, interleaved with clear rooms to avoid one long tail.
    return [dict(dark=dark, tier=tier, seed=seed, runs=min(SEEDS_PER_BATCH, first_seed + runs - seed))
            for seed in range(first_seed, first_seed + runs, SEEDS_PER_BATCH)
            for tier in (3, 2, 1) for dark in ("on", "off")]


def stem(batch: dict) -> str:
    return f'{batch["dark"]}-t{batch["tier"]}-s{batch["seed"]}-n{batch["runs"]}'


def measure(batch: dict, work: Path) -> Path | None:
    if batch.get("audit"):
        path, log = work.parent / "audit.json", work.parent / "audit-final.log"
        command = [sys.executable, str(ROOT / "tools/godot_task_runner.py"), "--task-id", TASK_ID,
                   "--timeout", str(MEASUREMENT_TIMEOUT_SECONDS), "--stream", "--", "godot", "--headless", "--path", str(ROOT),
                   "--script", "tools/encounter_shadow_audit_run.gd", "--", "--seed", "1", "--runs", "10", "--output", str(path)]
        with log.open("w") as stream:
            code = subprocess.call(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
        if code:
            raise RuntimeError(f"Audit: exit {code}; {log}")
        print("SHADOW AUDIT BATCH: PASS (10 losses)", flush=True)
        return None
    name = stem(batch)
    path, log = work / f"{name}.json", work / f"{name}.log"
    if path.exists():
        saved = json.loads(path.read_text())
        elements = ("shadow",) if batch["dark"] == "off" else ("fire", "earth", "ice", "air", "lightning", "shadow")
        actual = {(r["seed"], r["biome"]) for r in saved["results"]}
        if (len(actual) == len(saved["results"]) and {r["biome"] for r in saved["results"]} == set(elements)
                and all(sum(r["biome"] == element for r in saved["results"]) == batch["runs"] for element in elements)):
            print(f"SHADOW BATCH: retained ({name})", flush=True)
            return path
    command = [sys.executable, str(ROOT / "tools/godot_task_runner.py"), "--task-id", TASK_ID,
               "--timeout", str(MEASUREMENT_TIMEOUT_SECONDS), "--stream", "--", "godot", "--headless", "--path", str(ROOT),
               "--script", "tools/encounter_shadow_sweep.gd", "--", "--tier", str(batch["tier"]),
               "--runs", str(batch["runs"]), "--seed", str(batch["seed"]), f'--room-dark={batch["dark"]}',
               "--output", str(path)]
    if path.exists():
        command += ["--resume-report", str(path)]
    attempt = 1
    while log.exists():
        log = work / f"{name}.attempt{attempt}.log"
        attempt += 1
    with log.open("w") as stream:
        code = subprocess.call(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
    if code:
        raise RuntimeError(f"{name}: exit {code}; {log}")
    print(f"SHADOW BATCH: PASS ({name})", flush=True)
    return path


def unique_rows(reports: list[dict]) -> list[dict]:
    retained = {}
    for report in reports:
        for row in report["results"]:
            identity = row["seed"], row["biome"]
            if identity in retained:
                assert retained[identity] == row, f"Conflicting duplicate room {identity}"
            retained[identity] = row
    return sorted(retained.values(), key=lambda r: (r["seed"], r["section_index"]))


def assemble(paths: list[Path], output: Path, first_seed: int, runs: int) -> None:
    policy_hash = hashlib.sha256((ROOT / "tools/encounter_bot.gd").read_bytes()).hexdigest()
    output.mkdir(parents=True, exist_ok=True)
    for tier in (1, 2, 3):
        for dark in ("on", "off"):
            reports = [json.loads(p.read_text()) for p in paths]
            reports = [r for r in reports if r["tier"] == tier and r["room_dark"] == dark]
            example = reports[0]
            assert all(r["policy_sha256"] == policy_hash and r["defaults"] == example["defaults"]
                       and r["decks"] == example["decks"] for r in reports)
            rows = unique_rows(reports)
            elements = {"shadow"} if dark == "off" else {"fire", "earth", "ice", "air", "lightning", "shadow"}
            assert all(sum(r["biome"] == element for r in rows) <= runs for element in elements)
            report = {**example, "first_seed": first_seed, "runs_per_group": runs, "results": rows}
            path = output / f'{"default" if dark == "on" else "clear"}-t{tier}.json'
            path.write_text(json.dumps(report, indent=2) + "\n")
            if any(sum(r["biome"] == element for r in rows) < runs for element in elements):
                # A seed can have no eligible room in a bin. Batch scans then
                # overlap; resume the merged unique prefix to fill only its holes.
                command = [sys.executable, str(ROOT / "tools/godot_task_runner.py"), "--task-id", TASK_ID,
                           "--timeout", str(MEASUREMENT_TIMEOUT_SECONDS), "--stream", "--", "godot", "--headless", "--path", str(ROOT),
                           "--script", "tools/encounter_shadow_sweep.gd", "--", "--tier", str(tier), "--runs", str(runs),
                           "--seed", str(first_seed), f"--room-dark={dark}", "--output", str(path), "--resume-report", str(path)]
                log = paths[0].parent.parent / f"fill-{dark}-t{tier}.log"
                with log.open("w") as stream:
                    code = subprocess.call(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
                if code:
                    raise RuntimeError(f"Prefix completion: exit {code}; {log}")
                report = json.loads(path.read_text())
                rows = unique_rows([report])
            identities = {(r["seed"], r["biome"]) for r in rows}
            assert len(rows) == len(identities) and {r["biome"] for r in rows} == elements
            assert all(sum(r["biome"] == element for r in rows) == runs for element in elements)
            assert all(r["seed"] >= first_seed for r in rows)
            report["results"] = rows
            path.write_text(json.dumps(report, indent=2) + "\n")
            compress_report(path, path.with_suffix(".json.gz"))
            path.unlink()
    print(f"SHADOW MEASUREMENTS: PASS ({runs * 21} runs; {runs} per group)", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workers", type=int, default=DEFAULT_WORKERS)
    parser.add_argument("--runs", type=int, default=200, help="runs per element/tier group")
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--work-dir", type=Path, default=LOG_ROOT / "batches")
    parser.add_argument("--output-dir", type=Path, default=ARTIFACTS)
    args = parser.parse_args()
    if not 1 <= args.workers <= 4 or args.runs <= 0 or args.seed < 0:
        parser.error("workers must be 1..4, runs positive and seed nonnegative")
    args.work_dir.mkdir(parents=True, exist_ok=True)
    selected = [{"audit": True}, *batches(args.seed, args.runs)]
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        paths = list(pool.map(lambda batch: measure(batch, args.work_dir), selected))
    assemble([p for p in paths if p is not None], args.output_dir, args.seed, args.runs)
    for name, source in (("audit.json.gz", args.work_dir.parent / "audit.json"),
                         ("audit.log.gz", args.work_dir.parent / "audit-final.log")):
        compress_report(source, args.output_dir / name)


if __name__ == "__main__":
    main()
