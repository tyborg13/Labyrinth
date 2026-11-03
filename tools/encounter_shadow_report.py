#!/usr/bin/env python3
"""Recompute meas-04 tables and the ten-loss decision audit from raw records."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess

from encounter_bot import read_report, summarize
from encounter_sweep import BIOMES, ROOT, cell, distribution
from encounter_shadow_measurement import ARTIFACTS

MIMIC = "hollow_mimic"
STALKER = "gloam_stalker"


def audit_summary(row: dict) -> dict:
    ended = row["audit_turns"]
    blocked, blocked_pass_ends, approaches, any_blocked, partial_approaches, collisions = 0, 0, 0, 0, 0, 0
    for turn in ended:
        facts = [turn["facts"], *(event["facts"] for event in turn["events"])]
        had_blocked = any(f["visibility_blocked_actions"] and not f["targeted_actions_with_legal_targets"] for f in facts)
        pass_facts = [turn["facts"], *(event["facts"] for event in turn["events"] if event["card"] == "pass")]
        blocked_pass_ends += any(f["visibility_blocked_actions"] and not f["targeted_actions_with_legal_targets"] for f in pass_facts)
        had_partial_block = any(f["visibility_blocked_actions"] for f in facts)
        any_blocked += had_partial_block
        moved_toward = turn["movement"]["moved_toward_nearest"] or any(
            event.get("movement", {}).get("moved_toward_nearest", False) for event in turn["events"])
        blocked += had_blocked
        approaches += had_blocked and moved_toward
        partial_approaches += had_partial_block and moved_toward
        collisions += turn["movement"].get("hidden_collisions", 0) + sum(event.get("movement", {}).get("hidden_collisions", 0) for event in turn["events"])
    return {"seed": row["seed"], "turn_ends": len(ended),
            "ends_with_playable_cards": sum(bool(t["facts"]["playable_cards"]) for t in ended),
            "unseen_target_turns": blocked, "unseen_target_turns_with_approach": approaches,
            "unseen_target_pass_ends": blocked_pass_ends,
            "turns_with_any_visibility_blocked_action": any_blocked,
            "partial_sight_approaches": partial_approaches,
            "hidden_collisions": collisions,
            "ending": "turn cap" if row["turn_cap_reached"] else "death"}


def build(output: Path, result_path: Path, runs: int = 200, first_seed: int = 1) -> dict:
    reports = {(tier, dark): read_report(output / f'{"default" if dark == "on" else "clear"}-t{tier}.json.gz')
               for tier in (1, 2, 3) for dark in ("on", "off")}
    policy_hash = hashlib.sha256((ROOT / "tools/encounter_bot.gd").read_bytes()).hexdigest()
    baseline_hash = json.loads((ROOT / "spec/peer_benchmark/encounter_redesign/measurements/revision7/baseline.json").read_text())["policy_sha256"]
    assert policy_hash == baseline_hash
    groups, cuts = [], []
    for tier in (1, 2, 3):
        for dark in ("on", "off"):
            report = reports[tier, dark]
            assert report["policy_sha256"] == policy_hash
            for biome in BIOMES if dark == "on" else ("shadow",):
                rows = [r for r in report["results"] if r["biome"] == biome]
                assert len(rows) == runs and len({r["seed"] for r in rows}) == runs and min(r["seed"] for r in rows) >= first_seed
                groups.append({"tier": tier, "biome": biome, "room_dark": dark, **summarize(rows)})
            shadow = [r for r in report["results"] if r["biome"] == "shadow"]
            for label in ("Mimic present", "Stalker present", "Other type present"):
                selected = [r for r in shadow if (MIMIC in r["enemy_types"] if label == "Mimic present" else
                            STALKER in r["enemy_types"] if label == "Stalker present" else
                            bool(set(r["enemy_types"]) - {MIMIC, STALKER}))]
                cuts.append({"tier": tier, "room_dark": dark, "held": label, "n": len(selected),
                             "win_rate": sum(r["won"] for r in selected) / len(selected) if selected else None,
                             "median_hp_lost": distribution([r["hp_lost"] for r in selected])["median"]})
    for tier in (1, 2, 3):
        natural = {r["seed"]: r for r in reports[tier, "on"]["results"] if r["biome"] == "shadow"}
        clear = {r["seed"]: r for r in reports[tier, "off"]["results"]}
        for seed in natural:
            for key in ("coord", "travel_dir", "encounter_id", "enemy_types", "section_index", "objective"):
                assert natural[seed][key] == clear[seed][key], (tier, seed, key)
    audit = read_report(output / "audit.json.gz")["results"]
    default = {r["seed"]: r for r in reports[2, "on"]["results"] if r["biome"] == "shadow"}
    expected_losses = sorted(seed for seed, r in default.items() if not r["won"])[:10]
    assert len(audit) == 10 and [r["seed"] for r in audit] == expected_losses
    for row in audit:
        for key, value in row.items():
            if key in default[row["seed"]]: assert default[row["seed"]][key] == value, (row["seed"], key)
    audited = [audit_summary(r) for r in audit]
    controls = [r for r in groups if r["room_dark"] == "on" and r["biome"] != "shadow" and r["win_rate"] < .25]
    table = ["| Tier | Element | Setup | N | Win rate | Turns median (P10–P90) | HP lost median (P10–P90) |",
             "|---:|---|---|---:|---:|---|---|"]
    for row in groups:
        setup = "dark off" if row["room_dark"] == "off" else "dark on" if row["biome"] == "shadow" else "default"
        table.append(f'| {row["tier"]} | {row["biome"]} | {setup} | {row["n"]} | {row["win_rate"]:.1%} | {cell(row["turns"])} | {cell(row["hp_lost"])} |')
    enemy_table = ["| Tier | Shadow room held | Dark | N | Win rate | Median HP lost | N < 30 |",
                   "|---:|---|---|---:|---:|---:|---|"]
    for row in cuts:
        rate = "—" if row["win_rate"] is None else f'{row["win_rate"]:.1%}'
        hp = "—" if row["median_hp_lost"] is None else f'{row["median_hp_lost"]:g}'
        enemy_table.append(f'| {row["tier"]} | {row["held"]} | {row["room_dark"]} | {row["n"]} | {rate} | {hp} | {"yes" if row["n"] < 30 else "no"} |')
    comparisons = []
    for tier in (1, 2, 3):
        current = [r for r in groups if r["tier"] == tier and r["room_dark"] == "on"]
        natural = next(r for r in current if r["biome"] == "shadow")
        clear = next(r for r in groups if r["tier"] == tier and r["room_dark"] == "off")
        others = ", ".join(f'{r["biome"]} {r["win_rate"]:.1%}' for r in current if r["biome"] != "shadow")
        comparisons.append(f'Tier {tier}: shadow wins {natural["win_rate"]:.1%} with dark on versus {others}; shadow dark off wins {clear["win_rate"]:.1%} ({(clear["win_rate"] - natural["win_rate"]) * 100:+.1f} percentage points).')
    totals = {key: sum(r[key] for r in audited) for key in ("turn_ends", "ends_with_playable_cards", "unseen_target_turns", "unseen_target_turns_with_approach", "unseen_target_pass_ends", "turns_with_any_visibility_blocked_action", "partial_sight_approaches", "hidden_collisions")}
    end_distances = [t["end_nearest_distance"] for r in audit for t in r["audit_turns"]]
    assert all("hidden_collisions" in t["movement"] for r in audit for t in r["audit_turns"])
    audit_lines = [f'Ten tier-2 dark-on losses, first losses in seed order; {totals["turn_ends"]} turn ends. '
                   f'{totals["ends_with_playable_cards"]} ended with cards still playable; {totals["unseen_target_turns"]} {"turn" if totals["unseen_target_turns"] == 1 else "turns"} had no legal targeted hand attack at a logged decision/end but gained a hidden-enemy target with darkness removed; '
                   f'the bot moved toward its nearest enemy on {totals["unseen_target_turns_with_approach"]} of those turns. '
                   f'The fully targetless count restricted to pass/end states is {totals["unseen_target_pass_ends"]}. '
                   f'{totals["turns_with_any_visibility_blocked_action"]} turns had at least one attack action blocked by sight, including turns with another legal attack; the bot approached on {totals["partial_sight_approaches"]} of these turns. '
                   f'Turns ended {min(end_distances)}–{max(end_distances)} Manhattan tiles from the nearest living enemy, {sum(d == 1 for d in end_distances)} adjacent. '
                   f'Committed card movement/dodges encountered unseen enemies {totals["hidden_collisions"]} times (production movement_interrupted_total deltas). '
                   f'Endings: {sum(r["ending"] == "death" for r in audited)} deaths, {sum(r["ending"] == "turn cap" for r in audited)} turn caps. '
                   'Sources: [decision log](audit.log.gz), [per-turn records](audit.json.gz).', ""]
    for row in audited:
        audit_lines.append(f'- Seed {row["seed"]}: {row["ends_with_playable_cards"]}/{row["turn_ends"]} turn ends with playable cards; '
                           f'turns without targets due to sight: {row["unseen_target_turns"]}, {row["unseen_target_turns_with_approach"]} with approach; {row["hidden_collisions"]} unseen collisions; {row["ending"]}.')
    definitions = ('Playable cards use the existing normal-play UI query after the final dodge, with play budget remaining. '
                   'An unseen-target turn has a logged decision/end state where every budgeted targeted hand attack has zero legal targets, '
                   'but changing only umbra.stage to clear on a diagnostic copy exposes a legal hidden-enemy target at the same hero position. '
                   'Approach counts such turns with at least one actual card movement or final dodge that decreases Manhattan distance to the '
                   'nearest living enemy anchor before that movement (the policy’s Manhattan metric; engine order breaks ties); it counts turns, not individual steps. '
                   'Audit outcomes, damage, turns, kills, decisions and preview counts match their unobserved default runs exactly.')
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    control_note = "; ".join(f'{r["biome"]} tier {r["tier"]}: {r["win_rate"]:.1%}' for r in controls) or "none"
    preface = (f'Integration `{head}`; map revision 7; policy v2 `{policy_hash}` unchanged. '
               f'{runs} runs per group, first seed {first_seed}; standard rooms only. '
               'Dark off changes only the shadow layout copy’s `umbra.stage` to the existing `clear` value before combat creation. '
               'All outcomes, including turn caps, enter medians and nearest-rank P10–P90; HP lost is cumulative damage_received. '
               'Presence cuts overlap; “Other type” means at least one enemy other than Hollow Mimic or Gloam Stalker. '
               'Paired shadow rows retain the same seeds, coordinates, entrances, encounters and initial enemy types.')
    seed_note = "; ".join(f'tier {r["tier"]} {r["biome"]} {r["room_dark"]}: last seed {max(x["seed"] for x in reports[r["tier"], r["room_dark"]]["results"] if x["biome"] == r["biome"]):g}'
                          for r in groups if max(x["seed"] for x in reports[r["tier"], r["room_dark"]]["results"] if x["biome"] == r["biome"]) > first_seed + runs - 1)
    preface += ' Seeds without an eligible room are skipped; each group retains the first 200 matching seeds. Extended scans: ' + (seed_note or 'none') + '.'
    body = "\n\n".join([preface, "\n".join(table), "\n".join(enemy_table), " ".join(comparisons),
                           "\n".join(audit_lines), definitions, f'Non-shadow controls below 25% (no reruns): {control_note}.'])
    commands = ('Reproduce collection and audit: `cd ' + str(ROOT) + ' && python3 tools/encounter_shadow_measurement.py --workers 4`; '
                'then `cd ' + str(ROOT) + ' && python3 tools/encounter_shadow_report.py`. '
                'Existing checkpoints under the work directory resume automatically. No windowed proof or inspection fixture applies.')
    (output / "shadow_report.md").write_text("# Shadow rooms — meas-04\n\n" + body + "\n\n" + commands + "\n")
    proof_path = output / "proof.json"
    proof_note = json.loads(proof_path.read_text()).get("feedback_1_proof_note", "See proof.json for focused checks and execution history.")
    result_body = body.replace("(audit.log.gz)", f"({output / 'audit.log.gz'})").replace("(audit.json.gz)", f"({output / 'audit.json.gz'})")
    result_path.write_text("# meas-04 feedback 1\n\n" + result_body + "\n\n" + proof_note + "\n")
    summary = {"source_head": head, "policy_sha256": policy_hash, "groups": groups, "enemy_cuts": cuts,
               "audit": audited, "audit_totals": totals, "controls": controls}
    (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(f"SHADOW REPORT: PASS ({runs * 21} runs; 21 groups; 10 matched loss replays)")
    return summary


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=ARTIFACTS)
    parser.add_argument("--result", type=Path, default=Path("/private/tmp/labyrinth_codex/meas-04/result_1.md"))
    args = parser.parse_args()
    build(args.output_dir, args.result)


if __name__ == "__main__":
    main()
