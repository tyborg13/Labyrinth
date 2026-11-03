"""Render the revision-7 comparison from measured records, without tuning advice."""
from __future__ import annotations

import json
from pathlib import Path

from encounter_sweep import ROOT, cell


def comparison(groups: list[dict], boss_summary: dict) -> str:
    sentences = []
    for tier in (1, 2, 3):
        rows = {row["cohort"]: row for row in groups if row["tier"] == tier and row["cohort"] != "boss"}
        ordered = [rows[key] for key in ("warband", "standard", "guardian")]
        wins = " / ".join(f'{row["win_rate"]:.1%}' for row in ordered)
        turns = " / ".join(f'{row["turns"]["median"]:g}' for row in ordered)
        hp = " / ".join(f'{row["hp_lost"]["median"]:g}' for row in ordered)
        sentences.append(f'Tier {tier}, Warband / standard / Guardian: {wins} wins, {turns} median turns, {hp} median HP lost.')
    sentences.append(f'With the same tier-3 deck, the six dragons together have {boss_summary["win_rate"]:.1%} wins, '
                     f'{boss_summary["turns"]["median"]:g} median turns and {boss_summary["hp_lost"]["median"]:g} median HP lost.')
    return " ".join(sentences)


def write_report(report: dict, output: Path, report_path: Path | None = None) -> None:
    from encounter_bot import read_report, summarize

    groups = report["groups"]
    composition = json.loads((output / "composition.json").read_text())
    boss_records = [row for group in groups if group["cohort"] == "boss"
                    for row in read_report(output / group["file"])["results"]]
    example = read_report(output / groups[0]["file"])
    lines = ["# Encounter measurement baseline — revision 7 (meas-02)", "",
             f'Integration HEAD `{report["source_head"]}`; map revision 7; policy v{report["policy_version"]}, `policy_sha256={report["policy_sha256"]}`. '
             f'{report["runs_per_group"]} runs per standard/Warband/Guardian tier, {report["runs_per_dragon"]} per dragon '
             f'({sum(g["n"] for g in groups):,} total), first seed {report["first_seed"]}, {report["workers"]} workers. '
             'The policy file, search limits, deck presets, gameplay and balance are unchanged. Revision-6 evidence and baseline.md remain unchanged.', "",
             'Values are median (nearest-rank P10–P90), including losses and capped runs. Turns count hero activations; HP lost is cumulative production damage_received, including damage later healed. '
             'A turn cap is a loss. Dragon rooms retain their natural depth band 4 and use the requested tier-3 deck; tier 3 below denotes that deck comparison, not a change to their room tier.', "",
             '| Tier / deck | Cohort | Dragon | Objective | N | Win rate | Turns median (P10–P90) | HP lost median (P10–P90) | Turn caps |',
             '|---|---|---|---|---:|---:|---:|---:|---:|']
    for row in groups:
        lines.append(f'| {row["tier"]} | {row["cohort"]} | {row.get("boss_id", "—")} | {row["objective"]} | {row["n"]} | '
                     f'{row["win_rate"]:.1%} | {cell(row["turns"])} | {cell(row["hp_lost"])} | {row["turn_cap_reached"]} |')
    lines += ["", comparison(groups, summarize(boss_records)), "",
              'For each seed the sweep generates all six production sections and selects one actual room per cohort/tier/biome at `seed % candidate_count` in generation order, using its first incoming map edge. '
              'Standard selects combat nodes, Warband selects special/warband nodes, Guardian selects guardian nodes, and boss selects each section’s dragon node. '
              'Guardian tiers are their rooms’ own depth bands (1–3). Objectives and rosters come from RunEngine unchanged. '
              'The bot takes the first matching rooms in ascending seed and production section order; each dragon is filtered by its own boss_id. '
              'An earlier combat is marked cleared only in the isolated measurement input to bypass onboarding; encounter history is empty. '
              'Ordinary combat and Warband are remeasured with spx-07 spread spawns and locked wind. '
              'The existing revealed-intent preview and committed engine transitions handle Guardian/dragon mechanics without an added policy hook.', "",
              f'The composition sweep accepts {composition["seeds_per_cohort_tier_biome"]} distinct seeds per cohort/tier/biome '
              f'({composition["rooms"]:,} rooms). The complete composition table and role mix are in '
              '[measurements/revision7/composition.md](measurements/revision7/composition.md). '
              'The Guardian and boss rows follow. Spawn HP sums generated max_hp; leader distance is Manhattan distance from entry to the leader spawn anchor, with ties counted as closest.', "",
              '| Tier / deck | Biome | Cohort / objective | N | Units | Spawn HP | Leader distance | Closest |',
              '|---|---|---|---:|---:|---:|---:|---:|']
    for row in composition["groups"]:
        if row["cohort"] not in ("guardian", "boss"):
            continue
        closest = "—" if row["leader_closest_share"] is None else f'{row["leader_closest_share"]:.1%}'
        lines.append(f'| {row["tier"]} | {row["biome"]} | {row["cohort"]} / {row["objective"]} | {row["n"]} | '
                     f'{cell(row["unit_count"])} | {cell(row["spawn_hp"])} | {cell(row["leader_distance"])} | {closest} |')
    lines += ["", 'Raw gzipped bot records, composition JSONL and summary JSON are in '
              '[measurements/revision7/](measurements/revision7/); baseline.json records hashes for the unchanged policy and measurement drivers. '
              'All summaries can be recomputed from those records. Per-run records retain room coordinate, entrance, biome, section, objective and identity for replay.', "",
              'Reproduce from this worktree:', "", '```bash',
              'cd <task-worktree> && python3 tools/encounter_sweep.py --revision 7 --seeds 200 --first-seed 1',
              'cd <task-worktree> && python3 tools/encounter_bot.py --baseline --revision 7 --runs 200 --boss-runs 50 --seed 1 --workers 6',
              'cd <task-worktree> && python3 tools/encounter_bot.py --baseline --revision 7 --report-only', '```', "",
              'Replay a recorded room using `cd <task-worktree> && python3 tools/encounter_bot.py --revision 7 --cohort COHORT --tier TIER --seed SEED --coord=X,Y --runs 1 --output-dir /private/tmp/meas-02-replay`; '
              'for a dragon also pass `--boss-id DRAGON --tier 3`. All engine launches use godot_task_runner.py with task id meas-02. '
              'No windowed proof or inspection fixture applies: this unit changes offline measurement tools and reports only.', "",
              'Measurement defaults remain the existing policy-v2 defaults: 24 HP, starting equipment, no relics, skills, consumables, omens, Defiance or Empower. '
              'Tier 1 uses the starting deck; tier 2 adds the same three common reward rolls, tier 3 the same two rares. '
              'The full unchanged defaults and deck presets are retained in every raw bot file. '
              f'Seed scans remain capped at 100,000; process timeout remains 7,200 seconds. Newly selected measurement-only values are '
              '`TASK_ID="meas-02"`, `--seeds 200` for composition and the separate measurement-driver filename. '
              'Test fixtures retain SMALL_SWEEP_MAX_SEED=100 and the existing policy arena.', "",
              '```json', json.dumps(example["defaults"], indent=2), '```', "",
              '```json', json.dumps(example["decks"], indent=2), '```', ""]
    (output / "baseline.json").write_text(json.dumps(report, indent=2) + "\n")
    report_path = report_path or ROOT / "spec/peer_benchmark/encounter_redesign/baseline_revision7.md"
    report_path.write_text("\n".join(lines))
    print(f'ENCOUNTER BASELINE: PASS ({sum(g["n"] for g in groups)} runs; revision 7; {len(groups)} groups); {report_path}')
