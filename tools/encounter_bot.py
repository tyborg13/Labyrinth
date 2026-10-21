#!/usr/bin/env python3
"""Play a seeded room, or collect the complete encounter baseline through Godot."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import subprocess

from encounter_sweep import DEFAULT_OUTPUT, ROOT, cell, distribution, run_engine

DEFAULT_WORKERS = 6
DEFAULT_RUNS = 200
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
    args = parser.parse_args()
    runs = args.runs if args.runs is not None else DEFAULT_RUNS if args.baseline else 1
    if runs <= 0 or args.workers <= 0 or args.seed < 0:
        parser.error("runs/workers must be positive and seed nonnegative")
    if args.coord and (args.baseline or runs != 1):
        parser.error("--coord requires a single-room run")
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    groups = [(tier, obj) for tier in (1, 2, 3) for obj in OBJECTIVES] if args.baseline else [(args.tier, args.objective)]

    def measure(group: tuple[int, str]) -> dict:
        tier, objective = group
        stem = f"bot-t{tier}-{objective}"
        path = output / f"{stem}.json"
        elapsed = run_engine("tools/encounter_bot.gd", ["--seed", str(args.seed), "--tier", str(tier), "--objective", objective,
                            "--runs", str(runs), "--output", str(path), *(["--coord", args.coord] if args.coord else [])], output / f"{stem}.log")
        report = json.loads(path.read_text())
        if len(report["results"]) != runs:
            raise RuntimeError(f"Incomplete baseline {stem}")
        return {"tier": tier, "objective": objective, **summarize(report["results"]),
                "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "elapsed_seconds": round(elapsed, 3)}

    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        summaries = list(executor.map(measure, groups))
    if args.baseline:
        report = {"schema_version": 1, "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                  "runs_per_group": runs, "first_seed": args.seed, "workers": args.workers, "groups": summaries}
        (output / "baseline.json").write_text(json.dumps(report, indent=2) + "\n")
        example = json.loads((output / summaries[0]["file"]).read_text())
        composition = (output / "composition.md").read_text()
        lines = ["# Encounter measurement baseline (spx-01)", "", f'Measured against integration HEAD `{report["source_head"]}` with additive analytics changes only. {runs} natural rooms per objective per tier; all outcomes are included in percentiles. This is a bounded greedy bot baseline, not a model of expert play. No encounter, objective, reward, map, combat or save rules change.', "",
                 "Run `python3 tools/encounter_sweep.py` then `python3 tools/encounter_bot.py --baseline` from this worktree. Raw room records are in `measurements/composition.jsonl.gz`; `composition.json` and `baseline.json` contain summaries. The nine `bot-t*-*.json` files retain every outcome, seed, room coordinate and entrance, plus deck ids and policy defaults. Per-process logs retain exact runner commands. Replay a recorded room with `python3 tools/encounter_bot.py --seed SEED --tier TIER --objective OBJECTIVE --coord=X,Y --runs 1 --output-dir /private/tmp/spx-01-replay`.", "",
                 "## Sampling and definitions", "", "For each seed, generate all six real sections. For each tier/biome choose one actual standard combat node at index `seed % candidate_count` in generation order, and use its first incoming map edge. A missing tier is skipped and that bin continues with later seeds until it has 2,000 distinct seeds. An earlier combat is marked cleared in the isolated measurement input to avoid the onboarding objective override; encounter history is empty. The layout is produced by RunEngine, including equipment drops. Biomes follow the section's actual boss, including shuffled elemental section order. No objective is forced. Bot groups scan these samples in ascending seed and production section order, retaining the first 200 matching rooms; biome counts are in baseline.json.", "",
                 "Turns count hero activations, starting at 1, with lethal enemy phases attributed to the preceding hero turn. HP lost is cumulative actual HP damage (the production damage_received counter); net HP loss is also retained. Kills and HP removed use the production enemies_killed and damage_dealt counters, excluding objective-cleared followers and including summoned units killed inside a single transition. First death is the first committed card/move/phase transition that increases enemies_killed; null means none. One-turn escape share uses all Reach Exit runs as denominator, counting victories on activation 1. P10/P90 use nearest rank; medians average the middle pair. Turn-capped runs count as losses and retain their cap flag.", "", "## Combat baseline", "", "| Tier | Objective | N | Win rate | Turns median (P10–P90) | HP lost median (P10–P90) | One-turn escapes |", "|---|---|---:|---:|---:|---:|---:|"]
        for row in summaries:
            escapes = "—" if row["one_turn_escape_share"] is None else f'{row["one_turn_escape_share"]:.1%}'
            lines.append(f'| {row["tier"]} | {row["objective"]} | {row["n"]} | {row["win_rate"]:.1%} | {cell(row["turns"])} | {cell(row["hp_lost"])} | {escapes} |')
        lines += ["", "## Chosen defaults", "", "These affect measurement only. Tier 1 uses GameData.starting_deck(), default equipment, no relics, 24 HP. Tier 2 appends three common reward rolls; tier 3 appends those commons and two rares. Rewards come from the actual coordinate-based reward offer stream on the fixed seed below (coordinates `(roll + 1, 0)`, with each room’s natural element); accepted duplicates are retained. No skills, consumables, omens or Defiance; no Empower. All ties use explicit generation order. Non-exit movement shortlists prioritize distance to a living enemy; exit shortlists prioritize exit distance closed. Optional free moves happen before a card; movement-only choices support exits. Multiaction cards use sequential engine resolution with bounded target branches. Search first ranks candidates by HP removed + 5 per kill + leader damage + unblocked exit distance closed; it evaluates the exact revealed-intent preview penalty for the best bounded shortlist. That preview respects card Time, the end tile and defenses. The bot chooses the highest positive score, otherwise passes. Equal scores retain the first option. Search limits deliberately constrain the policy and must be held fixed for future comparisons.", "", "```json", json.dumps(example["defaults"], indent=2), "```", "", "Reward presets:", "", "```json", json.dumps(example["decks"], indent=2), "```", "", f"The sweep starts at seed 1 and accepts 2,000 seeds per tier/biome. Golden seeds are 1, 19 and 421. Baselines start at seed 1; the Python driver uses {args.workers} concurrent isolated Godot processes. The offline measurement timeout is 7,200 seconds per process; ordinary tests retain the project caps.", "", "## Composition sweep", "", composition]
        report_path = output.parent / "baseline.md"
        report_path.write_text("\n".join(lines))
        print(f"ENCOUNTER BASELINE: PASS ({len(groups) * runs} runs; {runs} per objective/tier); {report_path}")


if __name__ == "__main__":
    main()
