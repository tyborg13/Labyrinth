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

from encounter_sweep import COHORTS, CURRENT_REVISION, ROOT, cell, distribution, output_for_revision, run_engine

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


def write_baseline(report: dict, output: Path, report_path: Path | None = None) -> None:
    runs, revision, workers = report["runs_per_group"], report["revision"], report["workers"]
    summaries = report["groups"]
    example = read_report(output / summaries[0]["file"])
    composition = (output / "composition.md").read_text()
    cohort_description = "standard Defeat All and Warband" if revision == CURRENT_REVISION else "legacy standard objective"
    data_link = f"measurements/revision{revision}"
    replay_selection = "--cohort COHORT" if revision == CURRENT_REVISION else "--objective OBJECTIVE"
    lines = ["# Encounter measurement baseline (spx-01)", "",
             f'Revision {revision}, policy version {report["policy_version"]}, integration HEAD `{report["source_head"]}`. {runs} natural rooms per {cohort_description} cohort per tier; all outcomes are included in percentiles. The exact tooling hash is in `{data_link}/baseline.json`. This bounded greedy bot measures current production rules. No gameplay or policy tuning changed in this integration update.', "",
             f'Run `python3 tools/encounter_sweep.py --revision {revision}` then `python3 tools/encounter_bot.py --baseline --revision {revision}`. Gzipped raw records, summary JSON and composition tables are in `{data_link}/`. Per-process logs and uncompressed working records stay under `/private/tmp/spx-01-measurement-logs/`. Replay with `python3 tools/encounter_bot.py --revision {revision} {replay_selection} --seed SEED --tier TIER --coord=X,Y --runs 1 --output-dir /private/tmp/spx-01-replay`.', "",
             '[Revision-5 policy v2](baseline_policy_v2_revision5.md) and [policy v1](baseline_policy_v1.md) retain the earlier nine-cohort reports. Their original gzipped records and summaries remain unchanged in `measurements/`. To measure the supported legacy generator today, add `--revision 5` to both tools; select bot cohorts with `--objective kill_all`, `kill_leader` or `reach_exit`. Legacy reruns default to `measurements/revision5/`, preserving historical evidence. Current standard rooms never roll leader or exit objectives; Warband supplies Defeat the Leader. Reach Exit is not a current cohort, so its escape share is not applicable.', "",
             '## Sampling and definitions', "",
             'For each seed, generate all six real sections using the selected saved map revision. For each cohort/tier/biome choose one actual node at index `seed % candidate_count` in generation order, and use its first incoming map edge. Standard nodes have type `combat`; Warband nodes have type `special` and `special_type=warband`. A missing bin is skipped and continues with later seeds until it has 2,000 distinct seeds. The Warband variant is the actual section biome. No room type, tier, roster, variant or objective is forced. An earlier combat is marked cleared in the isolated measurement input to avoid the onboarding override; encounter history is empty. RunEngine produces each layout, including equipment drops and spx-03 Warband formation. Biomes follow the actual section boss. Bot cohorts scan these samples in ascending seed and production section order, retaining the first 200 matches; biome counts are in baseline.json.', "",
             'The golden oracle is pinned to the supported revision-5 generator, retaining the original seed hashes rather than replacing them with spx-02/03 revision-6 output. Its purpose is to detect measurement side effects. The real ProgressionStore save/load regression still exercises current revision-6 runs. Separate sweep checks cover both revisions, and dodge/defense and three-objective determinism use explicit test arenas independent of map rolls. Headless proof and exact commands are in `measurements/feedback_3_proof.json`; no windowed proof applies.', "",
             'Turns count hero activations, starting at 1, with lethal enemy phases attributed to the preceding hero turn. HP lost is cumulative actual HP damage (production damage_received); net HP loss is also retained. Kills and HP removed use production enemies_killed and damage_dealt, excluding fleeing/objective-cleared followers and including summons killed inside a transition. First death is the first committed transition increasing enemies_killed; null means none. One-turn escape share uses all Reach Exit runs as denominator, counting activation-1 victories. P10/P90 use nearest rank; medians average the middle pair. Turn-capped runs count as losses and retain their flag.', "",
             '## Combat baseline', "",
             '| Tier | Cohort | Objective | N | Win rate | Turns median (P10–P90) | HP lost median (P10–P90) | One-turn escapes |',
             '|---|---|---|---:|---:|---:|---:|---:|']
    for row in summaries:
        escapes = "—" if row["one_turn_escape_share"] is None else f'{row["one_turn_escape_share"]:.1%}'
        lines.append(f'| {row["tier"]} | {row["cohort"]} | {row["objective"]} | {row["n"]} | {row["win_rate"]:.1%} | {cell(row["turns"])} | {cell(row["hp_lost"])} | {escapes} |')
    tier1 = next(row for row in summaries if row["tier"] == 1 and row["objective"] == "kill_all")
    target_met = tier1["win_rate"] >= .70 and tier1["hp_lost"]["median"] <= 8
    report["tier1_target"] = {"minimum_win_rate": .70, "maximum_median_hp_lost": 8, "met": target_met}
    (output / "baseline.json").write_text(json.dumps(report, indent=2) + "\n")
    calibration_path = output / "calibration_policy_v2.json"
    if report["policy_version"] == 2 and calibration_path.exists():
        lines += ["", calibration_note(json.loads(calibration_path.read_text()))]
    lines += ["", f"Tier-1 Defeat All target (≥70% wins, median HP lost ≤8): {'PASS' if target_met else 'NOT MET'}. The earlier revision-5 policy v2 baseline measured 64% wins and 15 median HP lost; policy v1 measured 12.5% and 24. Those historical rooms differ from this revision-6 cohort. A failed target leaves the policy unqualified for encounter-band calibration.", "", "## Chosen defaults", "", "These affect measurement only. Tier 1 uses GameData.starting_deck(), default equipment, no relics, 24 HP. Tier 2 appends three common reward rolls; tier 3 appends those commons and two rares. Rewards come from the actual coordinate-based reward offer stream on the fixed seed below (coordinates `(roll + 1, 0)`, with each room’s natural element); accepted duplicates are retained. No skills, consumables, omens or Defiance; no Empower. All otherwise equal ties use explicit generation order. Before each card, search the current tile and up to five free-move origins, prioritizing retained movement and then distance to the objective. Multiaction cards use sequential engine resolution with bounded target branches. Rank the shortlist by actual HP removed + 5 per kill + objective progress + potential defense and healing, preferring retained free movement on ties. For each of the top six candidates, search every legal remaining free-movement destination and staying put. Destinations are ordered by objective distance; a surviving zero-damage preview reaches the exact lower bound, so the remaining previews can be pruned. Choose the dodge with the least predicted HP damage (including damage on the path); ties approach the nearest living enemy or designated leader by Manhattan distance, or the nearest exit by grid-only path distance. Evaluate the card against passing with its own best dodge: damage/kills/objective progress + healing + 1.5 × (pass damage − candidate damage). Thus Block and Stoneskin earn only the HP damage the live preview says they prevent this phase; no flat defense bonus is paid. Free exit progress already available when passing is subtracted. A pass or evaluated candidate whose preview survives always displaces a lethal preview, regardless of raw score. The live preview stops at unrevealed follow-up intents; the policy does not inspect those future actions. Commit the card and its approach, then replan; commit the dodge after the final card. Highest positive score wins; otherwise pass and dodge. Search limits deliberately constrain the policy and must be held fixed for future comparisons.", "", "```json", json.dumps(example["defaults"], indent=2), "```", "", "Reward presets:", "", "```json", json.dumps(example["decks"], indent=2), "```", "", f"The sweep starts at seed 1 and accepts 2,000 seeds per cohort/tier/biome. Golden seeds are 1, 19 and 421 at revision 5. Seed scanning is bounded at 100,000 seeds per process; an unfilled cohort fails explicitly. Baselines start at seed 1; the Python driver uses {workers} concurrent isolated Godot processes. The offline measurement timeout is 7,200 seconds per process; ordinary tests retain the project caps. New test-only defaults are `SMALL_SWEEP_MAX_SEED=100` and `POLICY_FIXTURE.determinism_enemy_hp=8`; they affect fixture coverage only. Completed bot rooms checkpoint after each room. Interrupted JSONL sweep output retains complete rows and trims the incomplete final row. Rebuild Markdown from finished measurements with `--baseline --report-only`.", "", "## Composition sweep", "", composition]
    default_report = "baseline.md" if revision == CURRENT_REVISION else "baseline_revision5.md"
    report_path = report_path or ROOT / "spec/peer_benchmark/encounter_redesign" / default_report
    report_path.write_text("\n".join(lines))
    print(f"ENCOUNTER BASELINE: PASS ({len(summaries) * runs} runs; {runs} per cohort/tier; revision {revision}); {report_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", action="store_true", help="run every tier/cohort group (legacy: tier/objective)")
    parser.add_argument("--revision", type=int, choices=(5, 6), default=CURRENT_REVISION)
    parser.add_argument("--cohort", choices=COHORTS, default="standard")
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--tier", type=int, choices=(1, 2, 3), default=1)
    parser.add_argument("--objective", choices=OBJECTIVES, help="revision 5 only; revision 6 derives this from --cohort")
    parser.add_argument("--coord", help="replay a recorded sampled room at x,y (one run, with --seed)")
    parser.add_argument("--runs", type=int, help="default: 200 per group for baseline, otherwise 1")
    parser.add_argument("--workers", type=int, default=DEFAULT_WORKERS)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--report-path", type=Path, help="baseline Markdown destination")
    parser.add_argument("--report-only", action="store_true", help="render saved baseline summaries without running Godot")
    parser.add_argument("--resume-dir", type=Path, help="resume raw per-cohort JSON checkpoints from a previous log directory")
    parser.add_argument("--log-root", type=Path, default=DEFAULT_LOG_ROOT, help="temporary per-process logs and uncompressed working records")
    args = parser.parse_args()
    runs = args.runs if args.runs is not None else DEFAULT_RUNS if args.baseline else 1
    if runs <= 0 or args.workers <= 0 or args.seed < 0:
        parser.error("runs/workers must be positive and seed nonnegative")
    if args.coord and (args.baseline or runs != 1):
        parser.error("--coord requires a single-room run")
    if args.revision == 5 and args.cohort != "standard":
        parser.error("revision 5 has no Warband cohort")
    expected_objective = "kill_leader" if args.cohort == "warband" else "kill_all"
    if args.revision == CURRENT_REVISION and args.objective and args.objective != expected_objective:
        parser.error("revision 6 objectives follow --cohort; use --revision 5 for legacy objective cohorts")
    output = (args.output_dir or output_for_revision(args.revision)).resolve()
    output.mkdir(parents=True, exist_ok=True)
    if args.report_only:
        if not args.baseline:
            parser.error("--report-only requires --baseline")
        report = json.loads((output / "baseline.json").read_text())
        if report["revision"] != args.revision:
            parser.error("saved baseline revision differs from --revision")
        write_baseline(report, output, args.report_path)
        return
    args.log_root.mkdir(parents=True, exist_ok=True)
    log_dir = Path(tempfile.mkdtemp(prefix="bot-", dir=args.log_root))
    if args.revision == CURRENT_REVISION:
        groups = [(tier, cohort, "kill_leader" if cohort == "warband" else "kill_all")
                  for tier in (1, 2, 3) for cohort in COHORTS] if args.baseline else [(args.tier, args.cohort, expected_objective)]
    else:
        groups = [(tier, "standard", obj) for tier in (1, 2, 3) for obj in OBJECTIVES] if args.baseline else [(args.tier, "standard", args.objective or "kill_all")]

    def measure(group: tuple[int, str, str]) -> dict:
        tier, cohort, objective = group
        stem = f"bot-t{tier}-{cohort if args.revision == CURRENT_REVISION else objective}"
        path = log_dir / f"{stem}.json"
        resume = args.resume_dir / f"{stem}.json" if args.resume_dir else None
        elapsed = run_engine("tools/encounter_bot.gd", ["--revision", str(args.revision), "--cohort", cohort, "--seed", str(args.seed), "--tier", str(tier), "--objective", objective,
                            "--runs", str(runs), "--output", str(path), *(["--coord", args.coord] if args.coord else []),
                            *(["--resume-report", str(resume)] if resume and resume.exists() else [])], log_dir / f"{stem}.log")
        report = json.loads(path.read_text())
        if len(report["results"]) != runs:
            raise RuntimeError(f"Incomplete baseline {stem}")
        compressed = output / f"{stem}.json.gz"
        compress_report(path, compressed)
        return {"revision": args.revision, "cohort": cohort, "tier": tier, "objective": objective, **summarize(report["results"]),
                "file": compressed.name, "sha256": hashlib.sha256(compressed.read_bytes()).hexdigest(), "elapsed_seconds": round(elapsed, 3)}

    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        summaries = list(executor.map(measure, groups))
    example = read_report(output / summaries[0]["file"])
    if args.baseline:
        report = {"schema_version": 3, "revision": args.revision, "policy_version": example["defaults"]["policy_version"],
                  "policy_sha256": hashlib.sha256((ROOT / "tools/encounter_bot.gd").read_bytes()).hexdigest(), "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                  "runs_per_group": runs, "first_seed": args.seed, "workers": args.workers, "groups": summaries}
        (output / "baseline.json").write_text(json.dumps(report, indent=2) + "\n")
        if (output / "composition.md").exists():
            write_baseline(report, output, args.report_path)
        else:
            print(f"ENCOUNTER BASELINE RECORDS: PASS ({len(groups) * runs} runs); render with --baseline --report-only after the composition sweep")


if __name__ == "__main__":
    main()
