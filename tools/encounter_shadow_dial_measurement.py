#!/usr/bin/env python3
"""meas-05: production composition, damage attribution and paired shadow dials."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import subprocess
import sys

from encounter_bot import compress_report, read_report
from encounter_sweep import MEASUREMENT_TIMEOUT_SECONDS, ROOT

TASK_ID = "meas-05"
DEFAULT_WORKERS = 4
RUNS_PER_BATCH = 10
ARTIFACTS = ROOT / "spec/peer_benchmark/encounter_redesign/measurements/shadow_dials_2026-11"
RESULT_PATH = Path("/private/tmp/labyrinth_codex/meas-05/result.md")
WORK = RESULT_PATH.parent / "collection"
SCRIPT = "tools/encounter_shadow_dial_run.gd"


def policy_hash() -> str:
    actual = hashlib.sha256((ROOT / "tools/encounter_bot.gd").read_bytes()).hexdigest()
    expected = json.loads((ROOT / "spec/peer_benchmark/encounter_redesign/measurements/revision7/baseline.json").read_text())["policy_sha256"]
    assert actual == expected, "Frozen default policy changed"
    return actual


def run(arguments: list[str], log: Path) -> None:
    command = [sys.executable, str(ROOT / "tools/godot_task_runner.py"), "--task-id", TASK_ID,
               "--timeout", str(MEASUREMENT_TIMEOUT_SECONDS), "--stream", "--", "godot", "--headless",
               "--path", str(ROOT), "--script", SCRIPT, "--", *arguments]
    with log.open("w") as stream:
        code = subprocess.call(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
    if code:
        raise RuntimeError(f"Measurement exit {code}; {log}")


def batch_name(group: str, tier: int, biome: str, offset: int, runs: int) -> str:
    return f"{group}-t{tier}-{biome}-o{offset}-n{runs}"


def measure(batch: tuple, catalog: Path, work: Path, selection: dict) -> Path:
    group, tier, biome, offset, runs = batch
    selected = selection.get(str(tier), {}) if group in ("F", "G") else {}
    name = batch_name(*batch)
    path, log = work / f"{name}.json", work / f"{name}.log"
    run(["--catalog", str(catalog), "--group", group, "--tier", str(tier), "--biome", biome,
         "--offset", str(offset), "--runs", str(runs), "--selection", json.dumps(selected),
         "--output", str(path)], log)
    report = json.loads(path.read_text())
    assert len(report["results"]) == runs and report["policy_sha256"] == policy_hash()
    if group == "baseline":
        previous = read_report(ROOT / f"spec/peer_benchmark/encounter_redesign/measurements/shadow_2026-11/default-t{tier}.json.gz")
        original = {(r["biome"], r["seed"]): r for r in previous["results"]}
        for row in report["results"]:
            old = original.get((biome, row["seed"]))
            if old:
                for key in old:
                    if key not in ("room_dark", "enemy_types"):
                        assert row[key] == old[key], (tier, biome, row["seed"], key, row[key], old[key])
    print(f"SHADOW DIAL BATCH: PASS ({name})", flush=True)
    return path


def collect(groups: list[str], catalog: Path, work: Path, output: Path, runs: int,
            workers: int, selection: dict) -> None:
    batches = [(group, tier, biome, offset, min(RUNS_PER_BATCH, runs - offset))
               for offset in range(0, runs, RUNS_PER_BATCH) for tier in (3, 2, 1)
               for group in groups for biome in (("shadow", "earth") if group == "baseline" else ("shadow",))]
    with ThreadPoolExecutor(max_workers=workers) as pool:
        paths = list(pool.map(lambda batch: measure(batch, catalog, work, selection), batches))
    for group in groups:
        for tier in (1, 2, 3):
            for biome in (("shadow", "earth") if group == "baseline" else ("shadow",)):
                reports = [json.loads(p.read_text()) for p in paths if p.name.startswith(f"{group}-t{tier}-{biome}-")]
                reports.sort(key=lambda r: r["offset"])
                rows = [row for report in reports for row in report["results"]]
                expected = [r for r in json.loads(catalog.read_text())["results"] if r["tier"] == tier and r["biome"] == biome]
                assert [r["seed"] for r in rows] == [r["seed"] for r in expected]
                assert len(rows) == runs and len({r["seed"] for r in rows}) == runs
                report = {**reports[0], "offset": 0, "runs": runs, "results": rows}
                path = output / f"{group}-t{tier}-{biome}.json"
                path.write_text(json.dumps(report, indent=2) + "\n")
                compress_report(path, path.with_suffix(".json.gz"))
                path.unlink()
    print(f"SHADOW DIAL COLLECTION: PASS ({len(batches)} batches; groups {','.join(groups)})", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workers", type=int, default=DEFAULT_WORKERS)
    parser.add_argument("--runs", type=int, default=200)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--work-dir", type=Path, default=WORK)
    parser.add_argument("--output-dir", type=Path, default=ARTIFACTS)
    parser.add_argument("--phase", choices=("all", "baseline", "dials"), default="all")
    parser.add_argument("--include-g", action="store_true", help="include the sharper intent after reviewing damage concentration, even below the automatic half-damage threshold")
    args = parser.parse_args()
    if not 1 <= args.workers <= 4 or args.runs <= 0 or args.seed < 0:
        parser.error("workers must be 1..4; runs positive; seed nonnegative")
    args.work_dir.mkdir(parents=True, exist_ok=True)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    batches = args.work_dir / "batches"
    batches.mkdir(exist_ok=True)
    # A resumed directory is bound to all runtime source/data inputs, not merely
    # the frozen policy hash. Report-only Python changes do not invalidate fights.
    files = sorted([*ROOT.glob("scripts/**/*.gd"), *ROOT.glob("data/**/*.json"),
                    *ROOT.glob("tools/encounter*.gd")])
    sources = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    contract = {"runs": args.runs, "first_seed": args.seed, "include_g": args.include_g, "policy_sha256": policy_hash(), "sources": sources}
    contract_path = args.work_dir / "contract.json"
    if contract_path.exists(): assert json.loads(contract_path.read_text()) == contract, "Runtime inputs differ; use a fresh work directory"
    else: contract_path.write_text(json.dumps(contract, indent=2) + "\n")
    catalog = args.work_dir / "catalog.json"
    if not catalog.exists():
        run(["--make-catalog", "--runs", str(args.runs), "--seed", str(args.seed), "--output", str(catalog)], args.work_dir / "catalog.log")
    raw_catalog = json.loads(catalog.read_text())
    assert raw_catalog["runs_per_group"] == args.runs and raw_catalog["first_seed"] == args.seed
    compress_report(catalog, args.output_dir / "catalog.json.gz")
    compress_report(contract_path, args.output_dir / f"{args.phase}-inputs.json.gz")
    if args.phase in ("all", "baseline"):
        collect(["baseline"], catalog, batches, args.output_dir, args.runs, args.workers, {})
    from encounter_shadow_dial_report import choose_dials, build
    selection = choose_dials(raw_catalog, args.output_dir, include_g=args.include_g)
    (args.output_dir / "selection.json").write_text(json.dumps(selection, indent=2) + "\n")
    print("SHADOW DIAL SELECTION: " + json.dumps(selection), flush=True)
    if args.phase in ("all", "dials"):
        collect(["A", "B", "C", "D", "E", "F", *(["G"] if any(s.get("intent") for s in selection.values()) else [])],
                catalog, batches, args.output_dir, args.runs, args.workers, selection)
        build(args.output_dir, RESULT_PATH, args.runs, args.seed)
    assert policy_hash() == contract["policy_sha256"]
    print("DEFAULT POLICY SHA256: PASS (unchanged; matches revision7/baseline.json)", flush=True)


if __name__ == "__main__":
    main()
