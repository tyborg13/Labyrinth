#!/usr/bin/env python3
"""Ladder fight/entry tables and comparison-only prose, preserving report.md."""
from __future__ import annotations

import gzip
import json
from pathlib import Path
import statistics

from run_curve import ROOT
from run_curve_report import FIGHT_KINDS

LABELS = {"standard": "Standard", "guardian": "Guardian", "dragon": "Dragon", "warband": "Warband",
          "umbral_snare": "Snare", "ember_hoarder": "Hoarder", "last_light": "Last Light"}
LOW_COUNT_FIGHTS = 30


def percentile(values: list[int], fraction: float) -> float:
    ordered = sorted(values)
    position = (len(ordered) - 1) * fraction
    index = int(position)
    weight = position - index
    return ordered[index] * (1 - weight) + ordered[min(index + 1, len(ordered) - 1)] * weight


def cell(fights: list[dict]) -> str:
    n = len(fights)
    low = "†" if n < LOW_COUNT_FIGHTS else ""
    if not n: return f"0 fights{low}; —"
    wins = sum(f["won"] for f in fights)
    turns = [f["turns"] for f in fights]
    return (f"{wins}/{n} ({100 * wins / n:.1f}%){low}; H {statistics.median(f['hp_lost'] for f in fights):g}; "
            f"T {statistics.median(turns):g} [{percentile(turns, .1):g}, {percentile(turns, .9):g}]")


def fixed_rows() -> list[list[str]]:
    text = (ROOT / "spec/peer_benchmark/decisions.md").read_text()
    start = text.index("| Tier | s0 | s1 | s2 | s3 | s4 | s5 (shadow) |")
    table = text[start:text.index("\n\n", start)].splitlines()[2:]
    return [[part.strip() for part in line.strip("|").split("|")] for line in table]


def first_table(records: list[dict]) -> list[str]:
    lines = ["| Fight kind / fixed-deck reference | s0 | s1 | s2 | s3 | s4 | s5 |", "|---|---|---|---|---|---|---|"]
    for kind in FIGHT_KINDS:
        cells = [cell([f for r in records for f in r["fights"] if f["section"] == section and f["kind"] == kind]) for section in range(6)]
        lines.append("| " + LABELS[kind] + " | " + " | ".join(cells) + " |")
        if kind == "standard":
            for row in fixed_rows():
                lines.append(f"| **Fixed-deck reference tier {row[0]}** | " + " | ".join(row[1:]) + " |")
    lines.append("| All fight kinds | " + " | ".join(cell([f for r in records for f in r["fights"] if f["section"] == section]) for section in range(6)) + " |")
    return lines


def comparison(records: list[dict]) -> str:
    groups = [[f for r in records for f in r["fights"] if f["section"] == s and f["kind"] == "standard"] for s in range(6)]
    rates = [100 * sum(f["won"] for f in group) / len(group) if group else None for group in groups]
    rate_text = ", ".join(f"s{s} {rate:.1f}%" + (f" ({len(groups[s])} fights, under 30)" if len(groups[s]) < LOW_COUNT_FIGHTS else f" ({len(groups[s])} fights)") if rate is not None else f"s{s} unobserved (0 fights, under 30)" for s, rate in enumerate(rates))
    available = [(float(rates[s]) - float(rates[s + 1]), s) for s in range(5) if rates[s] is not None and rates[s + 1] is not None]
    if not available: return f"Ladder standard-fight win rates are {rate_text}; no adjacent-section drop can be assessed."
    drop = max(0.0, max(value for value, _ in available))
    pairs = ", ".join(f"s{s}→s{s + 1}" for value, s in available if abs(value - drop) < 1e-9)
    drop_text = f"The largest adjacent-section drop is {drop:.1f} percentage points at {pairs}." if drop > 0 else "There is no observed adjacent-section drop."
    refs = []
    for row in fixed_rows():
        values = [float(v.rstrip("%")) for v in row[1:]]
        largest = max(values[s] - values[s + 1] for s in range(5))
        steps = ", ".join(f"s{s}→s{s + 1}" for s in range(5) if values[s] - values[s + 1] == largest)
        relation = "smaller than" if drop < largest else "larger than" if drop > largest else "equal to"
        refs.append(f"{relation} fixed-deck tier {row[0]}'s {largest:g}-point largest drop ({steps})")
    return f"Ladder standard-fight win rates are {rate_text}. {drop_text} The ladder's largest drop is " + "; ".join(refs) + "."


def write_ladder_report(output: Path) -> None:
    with gzip.open(output / "ladder_runs.jsonl.gz", "rt") as stream:
        records = [json.loads(line) for line in stream]
    sample = json.loads((output / "ladder_sample.json").read_text())
    contract = json.loads((output / "ladder_contract.json").read_text())
    unknown = {f["kind"] for r in records for f in r["fights"]} - set(FIGHT_KINDS)
    if unknown: raise ValueError(f"Unreported ladder fight kinds: {unknown}")
    lines = ["# Growing-deck ladder — meas-06 feedback 1", "",
             f"Best draft policy only; **N={sample['n']}** whole ladders, completed seeds {sample['seeds']}. "
             f"At most {contract['max_workers']} workers; new runs stop launching after {contract['launch_budget_seconds']:g} seconds. "
             f"Elapsed including in-flight completion: {sample['elapsed_seconds']:.1f} seconds. The original `report.md` and all its artifacts are unchanged.", "",
             "## Fight table", "",
             "Cells: wins/fights (win rate); H = median gross Health lost; T = median hero turns [P10, P90]. "
             "† marks every ladder cell with fewer than 30 fights, including zero-exposure cells. "
             "Fixed-deck reference rows copy the percentages from `decisions.md` directly below the Standard row; they contain win rates only.", "",
             *first_table(records), "", "## Section entry medians", "",
             "| Section | Runs entering | Deck size | Relics | Equipment | Card-reward picks so far |", "|---:|---:|---:|---:|---:|---:|"]
    for section in range(6):
        entries = [e for r in records for e in r["entries"] if e["section"] == section]
        values = [f"{statistics.median(e[key] for e in entries):g}" if entries else "—" for key in ("deck_size", "relics", "equipment", "card_reward_picks")]
        lines.append(f"| {section} | {len(entries)} | " + " | ".join(values) + " |")
    lines += ["", "## Comparisons", "", comparison(records), "", "## Protocol and production mapping", "",
              "- Same whole-run driver, default progression, map, route, merchant, equipment, relic, event and policy-v2 combat decisions. Ladder overrides only fight-start Health, continuation after losses/caps, noncombat minimum Health, and the director's new Hearth purge rule.",
              "- The offline RunEngine subclass overrides `_player_snapshot`: it sets the run's `player_hp` to `player_max_hp` immediately before the production CombatEngine factory, after route and layout selection. The combat factory then applies its ordinary start effects. Every measured fight asserts full initial Health.",
              "- Production `finish_combat` cannot reward a defeated or unfinished battle. The original result, gross damage and turns are recorded first. For a loss/cap only, a separate copy is shaped into a normal victory end: dead hero HP is set to 1; Defeat All/leader/boss foes are cleared; Survive clock reaches its authored target; Reach Exit uses the first open authored exit (or reopens the first if all are sealed). No extra combat turns are played and no measured damage, kills, death effects or relic procs are fabricated.",
              "- For foes that would award currency in that victory end, remaining enemy Embers are added using the production enemy definitions, Omen modifier and dragon modifier; Guardian helpers, leader followers and Snare hunters retain their production exclusions. Escape/Survive do not create kill currency. Hoarder leader completion sets its normal caught/goal fields. These fields exist only in the transition copy. The unchanged `finish_combat`, card/relic reward and dragon-continuation paths then run, including the final dragon whether the recorded fight was won or lost. `completed_ladder` is protocol completion, not survival/escape performance.",
              "- Hearth always uses production `purge_magic_card(..., 'campfire')` for the lowest-scored offered/purgeable deck card when deck size is above 10; otherwise it leaves. Equipment-granted cards cannot be purged by production and are excluded. Equal scores retain deck order. No rest/upgrade is taken in ladder mode. The old normal-mode TODO remains only to preserve the original protocol and report; ladder has no unresolved design placeholder.",
              "- Noncombat costs and choices are unchanged. Production EventRules already clamps damaging effects at 1; a private replay counts those native clamps. The driver also clamps any other post-transition noncombat Health below 1. Dead-hero repairs for forced victory are counted separately, not as noncombat clamps.", "",
              f"Noncombat Health clamps: **{sample['noncombat_health_clamps']}**. Loss/cap transitions: **{sample['forced_victories']}**; turn-cap fights: **{sample['turn_cap_fights']}**. "
              f"Dead-hero transition repairs: {sum(r['victory_hp_repairs'] for r in records)}. Hearth purges: {sum(bool(c.get('purged')) for r in records for c in r['choices'] if c['kind'] == 'hearth')}.", "",
              "## Proof and chosen defaults", "",
              f"Frozen policy v2: `policy_sha256={sample['policy_sha256']}`. Source HEAD `{contract['source_head']}` plus fingerprinted uncommitted harness/runtime inputs in `ladder_contract.json`. "
              "Focused proof: `tools/run_curve_test.py --ladder` compares normal seed 1 with its original record hash and runs best/ladder seed 1 twice through all six sections. It verifies full fight-start Health, continuation counts, entry sections, reward-pick counts, record equality and the unchanged policy hash. No full suites, windowed Godot or default-group tests.", "",
              "Chosen measurement defaults: percentiles use linear interpolation at (n−1)×p; gross damage includes overkill; equipment counts occupied slots; card-reward picks count reward-screen selections (including event card choices), excluding automatic grants and merchant purchases. Workers take consecutive seeds as slots free; launches are bounded by the shared deadline and in-flight runs finish. First engine-ordered open exit is used only for a forced loss continuation; first authored exit is reopened if necessary. Existing 1,000-transition fault guard remains. No gameplay/data/policy edits.", "",
              f"Raw records: `ladder_runs.jsonl.gz` ({sample['raw_bytes']:,} bytes); each run also flushes to the task-local scratch JSONL at completion. Scores: `ladder_card_scores.json`; sample metadata: `ladder_sample.json`; focused proof: `ladder_determinism.json`. No tuning recommendations.", ""]
    (output / "ladder.md").write_text("\n".join(lines))
