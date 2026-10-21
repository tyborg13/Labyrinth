#!/usr/bin/env python3
"""Play a seeded room, or collect the complete encounter baseline through Godot."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import gzip
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

from encounter_sweep import DEFAULT_OUTPUT, ROOT, cell, distribution, run_engine

DEFAULT_WORKERS = 6
DEFAULT_RUNS = 200
DEFAULT_LOG_ROOT = Path("/private/tmp/spx-01-measurement-logs")
OBJECTIVES = ("kill_all", "kill_leader", "reach_exit")


def summarize(records: list[dict]) -> dict:
    n = len(records)
    if not n:
        raise ValueError("Cannot summarize an empty baseline")
    return {"n": n, "win_rate": sum(r["won"] for r in records) / n,
            "one_turn_escape_share": (sum(r["won"] and r["turns"] == 1 for r in records) / n
                                      if records[0]["objective"] == "reach_exit" else None),
            "turns": distribution([r["turns"] for r in records]),
            "hp_lost": distribution([r["hp_lost"] for r in records]),
            "turn_cap_reached": sum(r["turn_cap_reached"] for r in records),
            "biomes": {biome: sum(r["biome"] == biome for r in records) for biome in sorted({r["biome"] for r in records})}}


def read_report(path: Path) -> dict:
    with gzip.open(path, "rt") if path.suffix == ".gz" else path.open() as stream:
        return json.load(stream)


def compress_report(source: Path, destination: Path) -> None:
    # No filename or timestamp in the gzip header: repeated records yield
    # byte-identical artifacts. Pretty JSON remains available after extraction.
    with destination.open("wb") as stream:
        with gzip.GzipFile(filename="", fileobj=stream, mode="wb", mtime=0) as zipped:
            zipped.write(source.read_bytes())


def calibration_note(report: dict) -> str:
    observations = "; ".join(f'{row["name"]}: {row["win_rate"]:.1%} wins and {row["hp_lost"]["median"]:g} median HP lost'
                             for row in report["configurations"])
    return (f'{len(report["configurations"])} bounded configurations were compared on the same first '
            f'{report["runs_per_configuration"]} tier-1 Defeat All rooms. {observations}. '
            f'Selected `{report["selected_configuration"]}` by {", then ".join(report["selection_order"])}. '
            'Search limits, decks and HP were held fixed. Calibration records and summaries are in '
            '`measurements/calibration_policy_v2.json` and its gzipped raw files. Tuning stopped after '
            'these configurations; the full cohort above reports the selected policy. This policy '
            'remains unqualified for encounter-band calibration if the target below is not met.')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", action="store_true", help="run every tier/objective group")
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--tier", type=int, choices=(1, 2, 3), default=1)
    parser.add_argument("--objective", choices=OBJECTIVES, default="kill_all")
    parser.add_argument("--coord", help="replay a recorded sampled room at x,y (one run, with --seed)")
    parser.add_argument("--runs", type=int, help="default: 200 per group for baseline, otherwise 1")
    parser.add_argument("--workers", type=int, default=DEFAULT_WORKERS)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--log-root", type=Path, default=DEFAULT_LOG_ROOT, help="temporary per-process logs and uncompressed working records")
    args = parser.parse_args()
    runs = args.runs if args.runs is not None else DEFAULT_RUNS if args.baseline else 1
    if runs <= 0 or args.workers <= 0 or args.seed < 0:
        parser.error("runs/workers must be positive and seed nonnegative")
    if args.coord and (args.baseline or runs != 1):
        parser.error("--coord requires a single-room run")
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    args.log_root.mkdir(parents=True, exist_ok=True)
    log_dir = Path(tempfile.mkdtemp(prefix="bot-", dir=args.log_root))
    groups = [(tier, obj) for tier in (1, 2, 3) for obj in OBJECTIVES] if args.baseline else [(args.tier, args.objective)]

    def measure(group: tuple[int, str]) -> dict:
        tier, objective = group
        stem = f"bot-t{tier}-{objective}"
        path = log_dir / f"{stem}.json"
        elapsed = run_engine("tools/encounter_bot.gd", ["--seed", str(args.seed), "--tier", str(tier), "--objective", objective,
                            "--runs", str(runs), "--output", str(path), *(["--coord", args.coord] if args.coord else [])], log_dir / f"{stem}.log")
        report = json.loads(path.read_text())
        if len(report["results"]) != runs:
            raise RuntimeError(f"Incomplete baseline {stem}")
        compressed = output / f"{stem}.json.gz"
        compress_report(path, compressed)
        return {"tier": tier, "objective": objective, **summarize(report["results"]),
                "file": compressed.name, "sha256": hashlib.sha256(compressed.read_bytes()).hexdigest(), "elapsed_seconds": round(elapsed, 3)}

    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        summaries = list(executor.map(measure, groups))
    example = read_report(output / summaries[0]["file"])
    if args.baseline:
        report = {"schema_version": 2, "policy_version": example["defaults"]["policy_version"],
                  "policy_sha256": hashlib.sha256((ROOT / "tools/encounter_bot.gd").read_bytes()).hexdigest(), "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                  "runs_per_group": runs, "first_seed": args.seed, "workers": args.workers, "groups": summaries}
        (output / "baseline.json").write_text(json.dumps(report, indent=2) + "\n")
        composition = (output / "composition.md").read_text()
        lines = ["# Encounter measurement baseline (spx-01)", "", f'Policy version {report["policy_version"]}, source HEAD `{report["source_head"]}`; the exact measurement policy hash is in baseline.json. {runs} natural rooms per objective per tier; all outcomes are included in percentiles. This is a bounded greedy bot baseline, not a model of expert play. No encounter, objective, reward, map, combat or save rules change.', "",
                 "Run `python3 tools/encounter_sweep.py` then `python3 tools/encounter_bot.py --baseline` from this worktree. Raw room records are in `measurements/composition.jsonl.gz`; `composition.json` and `baseline.json` contain summaries. The nine `bot-t*-*.json.gz` files retain every outcome, seed, room coordinate and entrance, plus deck ids and policy defaults. Per-process logs and uncompressed working records stay under `/private/tmp/spx-01-measurement-logs/`. [Policy v1](baseline_policy_v1.md) and `measurements/baseline_policy_v1.json` retain the original baseline for comparison. Verification commands and results are in [the proof manifest](measurements/proof.json). Windowed proof is not applicable. Replay a recorded room with `python3 tools/encounter_bot.py --seed SEED --tier TIER --objective OBJECTIVE --coord=X,Y --runs 1 --output-dir /private/tmp/spx-01-replay`.", "",
                 "## Sampling and definitions", "", "For each seed, generate all six real sections. For each tier/biome choose one actual standard combat node at index `seed % candidate_count` in generation order, and use its first incoming map edge. A missing tier is skipped and that bin continues with later seeds until it has 2,000 distinct seeds. An earlier combat is marked cleared in the isolated measurement input to avoid the onboarding objective override; encounter history is empty. The layout is produced by RunEngine, including equipment drops. Biomes follow the section's actual boss, including shuffled elemental section order. No objective is forced. Bot groups scan these samples in ascending seed and production section order, retaining the first 200 matching rooms; biome counts are in baseline.json.", "",
                 "Turns count hero activations, starting at 1, with lethal enemy phases attributed to the preceding hero turn. HP lost is cumulative actual HP damage (the production damage_received counter); net HP loss is also retained. Kills and HP removed use the production enemies_killed and damage_dealt counters, excluding objective-cleared followers and including summoned units killed inside a single transition. First death is the first committed card/move/phase transition that increases enemies_killed; null means none. One-turn escape share uses all Reach Exit runs as denominator, counting victories on activation 1. P10/P90 use nearest rank; medians average the middle pair. Turn-capped runs count as losses and retain their cap flag.", "", "## Combat baseline", "", "| Tier | Objective | N | Win rate | Turns median (P10–P90) | HP lost median (P10–P90) | One-turn escapes |", "|---|---|---:|---:|---:|---:|---:|"]
        for row in summaries:
            escapes = "—" if row["one_turn_escape_share"] is None else f'{row["one_turn_escape_share"]:.1%}'
            lines.append(f'| {row["tier"]} | {row["objective"]} | {row["n"]} | {row["win_rate"]:.1%} | {cell(row["turns"])} | {cell(row["hp_lost"])} | {escapes} |')
        tier1 = next(row for row in summaries if row["tier"] == 1 and row["objective"] == "kill_all")
        target_met = tier1["win_rate"] >= .70 and tier1["hp_lost"]["median"] <= 8
        report["tier1_target"] = {"minimum_win_rate": .70, "maximum_median_hp_lost": 8, "met": target_met}
        (output / "baseline.json").write_text(json.dumps(report, indent=2) + "\n")
        calibration_path = output / "calibration_policy_v2.json"
        if report["policy_version"] == 2 and calibration_path.exists():
            lines += ["", calibration_note(json.loads(calibration_path.read_text()))]
        lines += ["", f"Tier-1 Defeat All target (≥70% wins, median HP lost ≤8): {'PASS' if target_met else 'NOT MET'}. Policy v1 measured 12.5% wins and 24 median HP lost on these same rooms.", "", "## Chosen defaults", "", "These affect measurement only. Tier 1 uses GameData.starting_deck(), default equipment, no relics, 24 HP. Tier 2 appends three common reward rolls; tier 3 appends those commons and two rares. Rewards come from the actual coordinate-based reward offer stream on the fixed seed below (coordinates `(roll + 1, 0)`, with each room’s natural element); accepted duplicates are retained. No skills, consumables, omens or Defiance; no Empower. All otherwise equal ties use explicit generation order. Before each card, search the current tile and up to five free-move origins, prioritizing retained movement and then distance to the objective. Multiaction cards use sequential engine resolution with bounded target branches. Rank the shortlist by actual HP removed + 5 per kill + objective progress + potential defense and healing, preferring retained free movement on ties. For each of the top six candidates, search every legal remaining free-movement destination and staying put. Destinations are ordered by objective distance; a surviving zero-damage preview reaches the exact lower bound, so the remaining previews can be pruned. Choose the dodge with the least predicted HP damage (including damage on the path); ties approach the nearest living enemy or designated leader by Manhattan distance, or the nearest exit by grid-only path distance. Evaluate the card against passing with its own best dodge: damage/kills/objective progress + healing + 1.5 × (pass damage − candidate damage). Thus Block and Stoneskin earn only the HP damage the live preview says they prevent this phase; no flat defense bonus is paid. Free exit progress already available when passing is subtracted. A pass or evaluated candidate whose preview survives always displaces a lethal preview, regardless of raw score. The live preview stops at unrevealed follow-up intents; the policy does not inspect those future actions. Commit the card and its approach, then replan; commit the dodge after the final card. Highest positive score wins; otherwise pass and dodge. Search limits deliberately constrain the policy and must be held fixed for future comparisons.", "", "```json", json.dumps(example["defaults"], indent=2), "```", "", "Reward presets:", "", "```json", json.dumps(example["decks"], indent=2), "```", "", f"The sweep starts at seed 1 and accepts 2,000 seeds per tier/biome. Golden seeds are 1, 19 and 421. Baselines start at seed 1; the Python driver uses {args.workers} concurrent isolated Godot processes. The offline measurement timeout is 7,200 seconds per process; ordinary tests retain the project caps.", "", "## Composition sweep", "", composition]
        report_path = output.parent / "baseline.md"
        report_path.write_text("\n".join(lines))
        print(f"ENCOUNTER BASELINE: PASS ({len(groups) * runs} runs; {runs} per objective/tier); {report_path}")


if __name__ == "__main__":
    main()
