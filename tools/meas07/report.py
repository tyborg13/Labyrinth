#!/usr/bin/env python3
"""Descriptive statistics only; regenerate from the archived native records."""
from __future__ import annotations

import gzip
import json
import math
from pathlib import Path
import statistics


def wilson(wins: int, n: int) -> tuple[float, float]:
    if not n:
        return (0.0, 1.0)
    z = 1.959963984540054
    p = wins / n
    d = 1 + z * z / n
    center = (p + z * z / (2 * n)) / d
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return max(0.0, center - half), min(1.0, center + half)


def median(values) -> str:
    values = list(values)
    return f"{statistics.median(values):g}" if values else "—"


def rate(rows: list[dict]) -> float:
    return sum(r["won"] for r in rows) / len(rows) if rows else float("nan")


def metrics(rows: list[dict]) -> str:
    n = len(rows)
    wins = sum(r["won"] for r in rows)
    lo, hi = wilson(wins, n)
    return (f"{wins}/{n} | {100*rate(rows):.1f}% [{100*lo:.1f}, {100*hi:.1f}] | "
            f"{100*(hi-lo)/2:.2f} | {median(r['turns'] for r in rows)} | "
            f"{median(r['hp_lost'] for r in rows)} | "
            f"{median(r['boss_hp_at_hero_death'] for r in rows if r['boss_hp_at_hero_death'] is not None)} | "
            f"{sum(r['hp_after'] <= 0 for r in rows)} | {sum(r['turn_cap_reached'] for r in rows)}")


def write_report(output: Path) -> None:
    with gzip.open(output / "runs.jsonl.gz", "rt") as stream:
        raw_rows = [json.loads(line) for line in stream]
    contract = json.loads((output / "contract.json").read_text())
    with gzip.open(output / "inputs.jsonl.gz", "rt") as stream:
        planned_cells = sorted({json.loads(line)["cell"] for line in stream})
    present = {(r["cell"], r["ladder_seed"], r["repeat"]) for r in raw_rows}
    complete_repeats = 0
    for repeat in range(contract["selected_repeats"]):
        if not all((cell, seed, repeat) in present for cell in planned_cells for seed in range(1, 9)):
            break
        complete_repeats += 1
    rows = [r for r in raw_rows if r["repeat"] < complete_repeats]
    contract["reported_n_per_cohort"] = complete_repeats * 8
    contract["reported_fights"] = len(rows)
    contract["excluded_partial_block_fights"] = len(raw_rows) - len(rows)
    (output / "contract.json").write_text(json.dumps(contract, indent=2, sort_keys=True) + "\n")
    groups = {cell: [r for r in rows if r["cell"] == cell] for cell in sorted({r["cell"] for r in rows})}
    bosses = sorted(cell for cell in groups if not cell.startswith("standard_for_"))
    wide = [cell for cell, group in groups.items()
            if (wilson(sum(r["won"] for r in group), len(group))[1] -
                wilson(sum(r["won"] for r in group), len(group))[0]) / 2 > .12]
    release_note = ""
    if contract.get("release_ref_at_collection", contract["release_head"]) != contract["release_head"]:
        release_note = f" The local release ref advanced to `{contract['release_ref_at_collection']}` during the task; the measured data remain the owner-prepared baseline above."
    lines = ["# Guardians, dragons and matched standard rooms — 2026-11-16", "",
             f"Measured release `{contract['release_head']}`. Zekarion is **the task-start release Zekarion**, before the separate rework unit; no rework data was applied." + release_note, "",
             f"Target N=64 per boss/control cohort (8 ladder-entry loadouts × 8 combat seeds). "
             f"Budget target N={contract['selected_n']} (8 loadouts × {contract['selected_repeats']} combat seeds). **Achieved table N={complete_repeats*8}** (8 loadouts × {complete_repeats} complete combat-seed blocks). "
             + ("The pilot provisionally selected N=48. After those fights completed, their representative observed throughput left enough time for two more combat seeds, restoring N=64 within the original 90-minute deadline. Both budget decisions are recorded in the contract." if contract.get('extended_to_64') else
                ("The initial-batch projection exceeded the remaining 90-minute budget, so the authorized N=48 fallback was used." if contract['selected_n'] == 48 else "The initial-batch projection fit the budget.")), "",
             f"Completed {len(raw_rows)} raw fights; complete requested sample: **{contract['complete']}**. Tables include {len(rows)} fights from the common complete prefix; {len(raw_rows)-len(rows)} unfinished-block observations remain in the raw archive but are excluded from comparisons. "
             f"Wall time including setup, the discarded recovery/section-entry attempt, corrected measured fights and archival: **{contract['elapsed_seconds']:.1f} seconds ({contract['elapsed_seconds']/60:.2f} minutes)**. "
             f"At most {contract['max_workers']} engine workers; limit 90 minutes. "
             f"Pilot: {contract['pilot_fights']} fights in {contract['pilot_elapsed_seconds']:.1f} seconds; remaining N=64 projection with scheduling margin: {contract['projected_remaining_64_seconds']:.1f} seconds.", "",
             "## Scope and matching", "",
             "The five elemental dragons are permuted across sections s0–s4 by the production run seed; Noctyrax is in s5. Guardians follow that section's dragon identity and their native map rooms can occupy different depth tiers. There is no single fixed section/tier for an elemental boss. This report measures each boss across the eight ladders' native placements, with eight corresponding ladder-entry loadouts. A cohort pools those placements; it is **not** an N=64 estimate for every possible boss × section × tier combination. The placement table below makes that distinction explicit. Sections are zero-based here (s0 is the first section).", "",
             "Each seed's first Guardian in production map-step/lane order and its actual dragon room are used. Each has a standard-room control from the same map and section, at the same clamped native depth tier. The first standard room in map-step/lane order at that tier is selected. All identities, arenas, enemies, room geometry, stats, loot and effects come from release production factories. No boss identity is pinned or transplanted. Controls retain the standard room's native element/biome. Tier 3 dragon controls use native depth band 3; dragons themselves are at depth step 4. This matches tier and section, not absolute depth or enemy roster.", "",
             "## Boss versus standard-room summary", "",
             "Positive gaps mean the bot won more often against the boss. Controls are paired by ladder seed, section, tier and combat-repeat index; gaps are percentage points. These are comparisons conditional on the sampled placements and ladder-entry loadouts.", "",
             "| Boss | Kind | Boss wins/N | Boss win rate | Matched standard wins/N | Standard win rate | Gap (pp) |",
             "|---|---|---:|---:|---:|---:|---:|"]
    for boss in bosses:
        group = groups[boss]
        baseline = groups.get("standard_for_" + boss, [])
        paired = {(r['ladder_seed'], r['repeat'], r['section'], r['tier']) for r in group}
        controls = {(r['ladder_seed'], r['repeat'], r['section'], r['tier']) for r in baseline}
        if contract["complete"] and paired != controls:
            raise ValueError("Unpaired baseline")
        lines.append(f"| {boss} | {group[0]['kind']} | {sum(r['won'] for r in group)}/{len(group)} | {100*rate(group):.1f}% | "
                     f"{sum(r['won'] for r in baseline)}/{len(baseline)} | {100*rate(baseline):.1f}% | {100*(rate(group)-rate(baseline)):+.1f} |")
    lines += ["", "## Per-cohort measurements", "",
              "Intervals are 95% Wilson intervals; half-widths are percentage points. Turns and gross hero Health lost use all fights. Boss Health left uses **only fights ending with hero Health ≤0**, excluding surviving turn-cap losses. A dash means no qualifying death or no boss in a standard room.", "",
              "| Cohort | Wins/N | Win rate [95% Wilson] | CI half-width (pp) | Median turns | Median hero Health lost | Median boss Health at hero death | Hero deaths | Turn caps |",
              "|---|---:|---|---:|---:|---:|---:|---:|---:|"]
    lines += [f"| {cell} | {metrics(group)} |" for cell, group in groups.items()]
    lines += ["", "**95% interval half-width >12 points:** " + (", ".join(f"`{cell}`" for cell in wide) if wide else "none") + ".", "",
              "## Native placement breakdown", "",
              "Each entry below is `ladder seed: section/tier`. Every listed placement contributes the same number of combat seeds. The eight loadout identities are run seeds 1–8; deck contents may coincide.", "",
              "| Boss | Native placements |", "|---|---|"]
    for boss in bosses:
        placements = sorted({(r["ladder_seed"], r["section"], r["tier"]) for r in groups[boss]})
        lines.append(f"| {boss} | " + "; ".join(f"{seed}: s{section}/t{tier}" for seed, section, tier in placements) + " |")
    lines += ["", "## Protocol and limits", "",
              "- The final sample uses the existing `tools/run_curve_dragons.py` loadout library: saved ladder seeds 1–8, with each section's pre-dragon production constructor snapshot recovered by that tool. These are fight-entry loadouts after that section's route, rewards and services, not section-entry decks. The original typed snapshot values are preserved; current release card, equipment, relic, enemy, room and combat definitions apply to every measured fight. The archive hash is in the contract. The original eight ladder records are included as fixture provenance, not claimed as newly recovered current-release runs.",
              "- Measured fights use those archived ladder-entry snapshots independently, with full current maximum Health. Native Variant serialization is round-tripped and hashed. Production RunEngine layout construction supplies equipment drops, omens and encounter-table behavior; CombatEngine supplies the combat state. Standard controls use the first eligible fight number at their tier (1, 3 or 5), empty encounter history, and completed-combat context for later sections or tiers, avoiding first-fight onboarding objectives there. Layout travel direction is the production default `Vector2i.ZERO`; room geometry/loot is fixed per placement across RNG repeats. These are controlled entry-loadout fights, not complete in-run difficulty or win probabilities for humans.",
              "- Combat seed input is `ladder_seed + repeat × 1000003`; native geometry uses the map/run seed. The raw records retain both inputs, the derived combat RNG seed, room seed/coordinate, section, tier, identity, end-state enemy Health, native battlefield rule and decision/cap flags. Health lost is the gross production `damage_received` increment, including damage subsequently healed, rather than net Health change. The unchanged 30-turn cap counts as a loss; a capped surviving hero is not a hero death.",
              "- Wilson intervals treat fights as independent binomial observations. Repeated seeds share loadouts and room geometry, so these descriptive fight-level intervals are not cluster-adjusted uncertainty across future decks, rooms or players. Pooled elemental comparisons also mix the eight sampled natural section placements; the matching controls use exactly the same placement weights. No tuning recommendations or inferred causal effects are included.",
              f"- Frozen policy SHA-256: `{contract['policy_sha256']}`. Decision-cap fights: {sum(r['search_capped'] for r in rows)}; turn-cap fights: {sum(r['turn_cap_reached'] for r in rows)}. The existing bot calls base CombatEngine transitions; it does not use the presentation/accepted-transition dispatcher. In particular, `scripts/battlefield_rules/committed.gd` invokes the half-Health rule check outside this frozen bot path. The measurement therefore shares the prior ladder's simulation-fidelity limitation for those rules; no bot behavior was changed to compensate.", "",
              "## Reproduction and evidence", "",
              "Exact expanded worker commands, timings and log paths: [commands.json](commands.json). Source hashes, acceptance criteria, budget decision, elapsed time and archive hashes: [contract.json](contract.json). Raw fights: [runs.jsonl.gz](runs.jsonl.gz). Full typed constructor payloads: [inputs.jsonl.gz](inputs.jsonl.gz). Archived ladder-entry snapshots: [entry_loadouts.jsonl.gz](entry_loadouts.jsonl.gz). Original ladder fixture records: [ladders.jsonl.gz](ladders.jsonl.gz). Worker output: [worker_logs.jsonl.gz](worker_logs.jsonl.gz).", "",
              "From the task worktree, a fresh reproduction is:", "", "```sh",
              "cd /Users/borgerding/workspace/Labyrinth.worktrees/meas-07 && python3 tools/meas07/collect.py --scratch-dir /private/tmp/labyrinth_codex/meas07-reproduction --output-dir /private/tmp/labyrinth_codex/meas07-reproduction-report --archived-loadouts",
              "```", "",
              "If the pilot selected N=48, the same-deadline budget check for restoring N=64 is:", "", "```sh",
              "cd /Users/borgerding/workspace/Labyrinth.worktrees/meas-07 && python3 tools/meas07/complete64.py --scratch-dir /private/tmp/labyrinth_codex/meas07-reproduction --output-dir /private/tmp/labyrinth_codex/meas07-reproduction-report",
              "```", "",
              "The corrected collection used `--scratch-dir /private/tmp/labyrinth_codex/meas07-ladder-entry --archived-loadouts`. An initial section-entry protocol was stopped and excluded; its diagnostics are preserved separately in `discarded_section_entry/`. The wall-time clock starts before that attempt's fresh recovery, so the correction does not reset the 90-minute machine budget. Prior fight outcomes are not reused in the final sample; only the existing dragon tool's immutable loadout fixtures are reused. All engine invocations go through `tools/godot_task_runner.py --task-id meas-07 --stream`. No windowed proof, renderer capture or inspection fixture applies to this measurement-only unit; no game files or tests changed.", ""]
    (output / "report.md").write_text("\n".join(lines))


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    write_report(parser.parse_args().output)
