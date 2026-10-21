#!/usr/bin/env python3
"""Run the production headless room sampler and report composition distributions."""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import gzip
import hashlib
import json
import math
from pathlib import Path
import statistics
import subprocess
import sys
import time
import tempfile

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "spec/peer_benchmark/encounter_redesign/measurements"
MEASUREMENT_TIMEOUT_SECONDS = 7200


def run_engine(script: str, arguments: list[str], log: Path) -> float:
    command = [sys.executable, str(ROOT / "tools/godot_task_runner.py"),
               "--task-id", "spx-01", "--timeout", str(MEASUREMENT_TIMEOUT_SECONDS),
               "--stream", "--", "godot", "--headless", "--path", str(ROOT),
               "--script", script, "--", *arguments]
    started = time.monotonic()
    with log.open("w") as stream:
        result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
    elapsed = time.monotonic() - started
    if result.returncode:
        raise RuntimeError(f"Measurement failed ({result.returncode}); see {log}")
    print(f"{script}: completed in {elapsed:.2f}s; log {log}", flush=True)
    return elapsed


def distribution(values: list[int]) -> dict:
    if not values:
        return {"n": 0, "median": None, "p10": None, "p90": None}
    ordered = sorted(values)
    return {"n": len(values), "median": statistics.median(ordered),
            "p10": ordered[max(0, math.ceil(len(ordered) * .1) - 1)],
            "p90": ordered[math.ceil(len(ordered) * .9) - 1]}


def summarize(rows: list[dict]) -> list[dict]:
    groups = defaultdict(list)
    for row in rows:
        groups[row["tier"], row["biome"], row["objective"]].append(row)
    result = []
    for (tier, biome, objective), records in sorted(groups.items()):
        roles = Counter()
        leaders = Counter()
        for row in records:
            roles.update(row["roles"])
            if row["leader_type"]:
                leaders[row["leader_type"]] += 1
        group = {"tier": tier, "biome": biome, "objective": objective, "n": len(records),
                 "roles": dict(sorted(roles.items())), "leader_types": dict(sorted(leaders.items())),
                 "leader_closest_share": (sum(bool(r["leader_closest"]) for r in records) / len(records)
                                           if objective == "kill_leader" else None)}
        for field in ("unit_count", "base_hp", "spawn_hp", "leader_distance", "exit_path_length", "exit_free_turns"):
            group[field] = distribution([r[field] for r in records if r[field] is not None])
        result.append(group)
    return result


def cell(stats: dict) -> str:
    return "—" if not stats["n"] else f'{stats["median"]:g} ({stats["p10"]:g}–{stats["p90"]:g})'


def markdown(groups: list[dict]) -> str:
    lines = ["Values are median (nearest-rank P10–P90). Base HP sums enemy-definition max_hp before scaling; spawn HP sums generated max_hp including leader bonuses. Roles use ai_profile.role, with missing roles labelled unspecified. Leader distance is Manhattan distance from the entry to the enemy spawn anchor; ties count as closest. Exit paths retain grid walls/pillars and ignore actors, destructible terrain, traps and surfaces. Free turns = ceil(path / 2).",
             "", "| Tier | Biome | Objective | N | Units | Base HP | Spawn HP | Leader distance | Closest | Exit path | Free turns |",
             "|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|"]
    for g in groups:
        closest = "—" if g["leader_closest_share"] is None else f'{g["leader_closest_share"]:.1%}'
        lines.append(f'| {g["tier"]} | {g["biome"]} | {g["objective"]} | {g["n"]} | ' +
                     " | ".join(cell(g[k]) for k in ("unit_count", "base_hp", "spawn_hp", "leader_distance")) +
                     f' | {closest} | {cell(g["exit_path_length"])} | {cell(g["exit_free_turns"])} |')
    lines += ["", "Role mix is a share of all units in the group. Leader types are room counts.", "",
              "| Tier | Biome | Objective | Role mix | Leader types |", "|---|---|---|---|---|"]
    for g in groups:
        total = sum(g["roles"].values())
        roles = ", ".join(f"{key} {value / total:.1%}" for key, value in g["roles"].items())
        leaders = ", ".join(f"{key}: {value}" for key, value in g["leader_types"].items()) or "—"
        lines.append(f'| {g["tier"]} | {g["biome"]} | {g["objective"]} | {roles} | {leaders} |')
    return "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seeds", type=int, default=2000, help="accepted distinct seeds per tier/biome")
    parser.add_argument("--first-seed", type=int, default=1)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    if args.seeds <= 0 or args.first_seed < 0:
        parser.error("seeds must be positive; first-seed must be nonnegative")
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    raw = output / "composition.jsonl"
    log_root = Path("/private/tmp/spx-01-measurement-logs")
    log_root.mkdir(parents=True, exist_ok=True)
    log_dir = Path(tempfile.mkdtemp(prefix="sweep-", dir=log_root))
    elapsed = run_engine("tools/encounter_sweep.gd", ["--seeds", str(args.seeds), "--first-seed", str(args.first_seed), "--output", str(raw)], log_dir / "sweep.log")
    rows = [json.loads(line) for line in raw.read_text().splitlines()]
    bins = Counter((r["tier"], r["biome"]) for r in rows)
    identities = {(r["tier"], r["biome"], r["seed"]) for r in rows}
    if len(bins) != 18 or set(bins.values()) != {args.seeds} or len(identities) != len(rows):
        raise RuntimeError("Incomplete or duplicate tier/biome seed coverage")
    groups = summarize(rows)
    compressed = output / "composition.jsonl.gz"
    # mtime=0 keeps the artifact byte-identical across repeated measurements.
    with compressed.open("wb") as stream:
        with gzip.GzipFile(filename="", mode="wb", fileobj=stream, mtime=0) as zipped:
            zipped.write(raw.read_bytes())
    raw.unlink()
    report = {"schema_version": 1, "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "generator": "production SectionMapGraph + RunEngine._combat_layout_for_room",
              "seeds_per_tier_biome": args.seeds, "first_seed": args.first_seed,
              "last_seed": max(r["seed"] for r in rows), "rooms": len(rows), "groups": groups,
              "raw_file": compressed.name, "raw_sha256": hashlib.sha256(compressed.read_bytes()).hexdigest(),
              "elapsed_seconds": round(elapsed, 3)}
    (output / "composition.json").write_text(json.dumps(report, indent=2) + "\n")
    (output / "composition.md").write_text(markdown(groups))
    print(f"ENCOUNTER COMPOSITION: PASS ({len(rows)} rooms; {args.seeds} seeds per tier/biome)")


if __name__ == "__main__":
    main()
