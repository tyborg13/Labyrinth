#!/usr/bin/env python3
"""spx-08: measure Last Light beside the Warband and the Umbral Snare (numbers only).

Revision-7 maps after Last Light is enabled, tiers 1-3, the unchanged policy-v2 bot
and deck presets. Every group samples natural rooms from seed 1 upward, so the three
cohorts share the same map generation. Run from the task worktree:

    python3 tools/last_light_measurement.py [--runs 150] [--workers 2]
    python3 tools/last_light_measurement.py --report-only
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

from encounter_bot import compress_report, read_report
from encounter_sweep import ROOT, cell, distribution, run_engine

OUTPUT = ROOT / "spec/peer_benchmark/encounter_redesign/measurements/last_light"
LOG_ROOT = Path("/private/tmp/labyrinth_codex/int-09/last-light-measurement")
REVISION = 7
RUNS = 150
FIRST_SEED = 1
WORKERS = 2
COHORTS = (("warband", "kill_leader"), ("snare", ""), ("last_light", ""))
TIERS = (1, 2, 3)
TASK_ID = "int-09"
TOOLS = ("encounter_bot.gd", "encounter_measurement_bot.gd", "encounter_sweep.gd", "last_light_measurement_engine.gd", "last_light_measurement.py")


def stem(cohort: str, tier: int) -> str:
    return f"bot-t{tier}-{cohort}"


def summarize(cohort: str, tier: int, records: list[dict]) -> dict:
    n = len(records)
    summary = {"cohort": cohort, "tier": tier, "objective": records[0]["objective"], "n": n,
               "win_rate": sum(r["won"] for r in records) / n,
               "turns": distribution([r["turns"] for r in records]),
               "hp_lost": distribution([r["hp_lost"] for r in records]),
               "turn_cap_reached": sum(r["turn_cap_reached"] for r in records),
               "biomes": {b: sum(r["biome"] == b for r in records) for b in sorted({r["biome"] for r in records})}}
    if cohort == "last_light":
        wins = [r for r in records if r["won"]]
        summary["braziers_lit_at_dawn"] = distribution([r["braziers_lit_at_dawn"] for r in wins])
        summary["braziers_lit_at_dawn_counts"] = {str(k): sum(r["braziers_lit_at_dawn"] == k for r in wins) for k in range(4)}
        summary["brazier_snuffs"] = distribution([r["brazier_snuffs"] for r in records])
        summary["mean_brazier_snuffs"] = sum(r["brazier_snuffs"] for r in records) / n
    return summary


def render(report: dict) -> str:
    lines = ["# Last Light beside the Warband and the Umbral Snare (spx-08)", "",
             f"Revision {report['revision']} maps with Last Light and Ember Hoarder enabled (int-09), source HEAD `{report['source_head']}` plus the "
             f"uncommitted int-09 integration. {report['runs_per_group']} natural rooms per cohort and tier, first seed "
             f"{report['first_seed']}, the unchanged policy-v2 bot (`policy_sha256` {report['policy_sha256'][:12]}…) and its "
             "tier deck presets. Numbers only; tuning is the director's.", "",
             "| Tier | Cohort | Objective | N | Win rate | Turns median (P10–P90) | HP lost median (P10–P90) | Turn cap |",
             "|---|---|---|---:|---:|---:|---:|---:|"]
    for row in report["groups"]:
        lines.append(f"| {row['tier']} | {row['cohort']} | {row['objective']} | {row['n']} | {row['win_rate']:.1%} | "
                     f"{cell(row['turns'])} | {cell(row['hp_lost'])} | {row['turn_cap_reached']} |")
    lines += ["", "## Last Light braziers", "",
              "Braziers lit at dawn count victories only (the brief's reward basis); Snuffs are per fight, all outcomes.", "",
              "| Tier | Wins | Lit at dawn median (P10–P90) | 0 / 1 / 2 / 3 lit | Snuffs per fight mean | Snuffs median (P10–P90) |",
              "|---|---:|---:|---:|---:|---:|"]
    for row in report["groups"]:
        if row["cohort"] != "last_light":
            continue
        counts = row["braziers_lit_at_dawn_counts"]
        lines.append(f"| {row['tier']} | {row['braziers_lit_at_dawn']['n']} | {cell(row['braziers_lit_at_dawn'])} | "
                     f"{counts['0']} / {counts['1']} / {counts['2']} / {counts['3']} | {row['mean_brazier_snuffs']:.2f} | "
                     f"{cell(row['brazier_snuffs'])} |")
    lines += ["", "## Notes", "",
              "- The bot policy has no objective term for braziers: it never walks to a brazier to relight it, so "
              "relights happen only when its dodge or approach steps onto one. Lit-at-dawn counts are a floor for a "
              "player who tends the braziers.",
              "- Survive is not in the policy's objective-distance terms; it plays the room as Defeat All (damage, kills and "
              "dodging) until dawn.",
              "- Enabling Last Light changes revision-7 special placement, so the Warband and Snare rows are re-measured "
              "on the same maps rather than taken from `measurements/revision7/`.",
              "- Both new specials use `first_layout_revision: 7`; the shared place-level gate preserves revision-6 maps. "
              "`data_sha256` in `summary.json` records the exact merged catalog used for this measurement.", "",
              f"Reproduce: `python3 tools/last_light_measurement.py --runs {report['runs_per_group']} --workers {report['workers']}`; "
              "raw gzipped records are beside this report.", ""]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runs", type=int, default=RUNS)
    parser.add_argument("--workers", type=int, default=WORKERS)
    parser.add_argument("--report-only", action="store_true")
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    if args.report_only:
        report = json.loads((OUTPUT / "summary.json").read_text())
        (OUTPUT / "report.md").write_text(render(report))
        return
    LOG_ROOT.mkdir(parents=True, exist_ok=True)
    log_dir = Path(tempfile.mkdtemp(prefix="bot-", dir=LOG_ROOT))
    groups = [(cohort, objective, tier) for tier in TIERS for cohort, objective in COHORTS]

    def measure(group: tuple[str, str, int]) -> dict:
        cohort, objective, tier = group
        name = stem(cohort, tier)
        path = log_dir / f"{name}.json"
        elapsed = run_engine("tools/encounter_measurement_bot.gd", ["--revision", str(REVISION), "--cohort", cohort, "--seed", str(FIRST_SEED),
                             "--tier", str(tier), "--runs", str(args.runs), "--output", str(path), *(["--objective", objective] if objective else [])],
                             log_dir / f"{name}.log", task_id=TASK_ID)
        records = json.loads(path.read_text())["results"]
        if len(records) != args.runs:
            raise RuntimeError(f"Incomplete group {name}")
        compressed = OUTPUT / f"{name}.json.gz"
        compress_report(path, compressed)
        return {**summarize(cohort, tier, records), "file": compressed.name,
                "sha256": hashlib.sha256(compressed.read_bytes()).hexdigest(), "elapsed_seconds": round(elapsed, 3)}

    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        summaries = list(executor.map(measure, groups))
    example = read_report(OUTPUT / summaries[0]["file"])
    report = {"revision": REVISION, "policy_version": example["defaults"]["policy_version"],
              "policy_sha256": hashlib.sha256((ROOT / "tools/encounter_bot.gd").read_bytes()).hexdigest(),
              "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "runs_per_group": args.runs, "first_seed": FIRST_SEED, "workers": args.workers, "groups": summaries,
              "tool_sha256": {name: hashlib.sha256((ROOT / "tools" / name).read_bytes()).hexdigest() for name in TOOLS},
              "data_sha256": {name: hashlib.sha256((ROOT / "data" / name).read_bytes()).hexdigest()
                              for name in ("special_encounters.json", "enemies.json", "battlefield_rules.json")}}
    (OUTPUT / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
    (OUTPUT / "report.md").write_text(render(report))
    print(f"LAST LIGHT MEASUREMENT: PASS ({sum(g['n'] for g in summaries)} runs); {OUTPUT / 'report.md'}")


if __name__ == "__main__":
    main()
