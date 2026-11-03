#!/usr/bin/env python3
"""Report the common seed prefix, retaining every completed raw run."""
from __future__ import annotations

import argparse
from collections import Counter
import gzip
import json
from pathlib import Path
import statistics

from run_curve import POLICIES, ROOT

FIGHT_KINDS = ("standard", "guardian", "dragon", "warband", "umbral_snare", "ember_hoarder", "last_light")


def median(rows: list[dict], key: str) -> str:
    return f"{statistics.median(r[key] for r in rows):g}" if rows else "—"


def reach_table(records: list[dict]) -> list[str]:
    lines = ["| Policy | Section | Entering | Died there | Escaped |",
             "|---|---:|---:|---:|---:|"]
    for policy in POLICIES:
        group = [r for r in records if r["policy"] == policy]
        for section in range(6):
            entering = sum(any(e["section"] == section for e in r["entries"]) for r in group)
            died = sum(r["end_section"] == section and not r["escaped"] for r in group)
            escaped = sum(r["end_section"] == section and r["escaped"] for r in group)
            lines.append(f"| {policy} | {section} | {entering} | {died} | {escaped} |")
    return lines


def comparisons(records: list[dict]) -> str:
    parts = []
    for policy in POLICIES:
        group = [r for r in records if r["policy"] == policy]
        reach = [sum(any(e["section"] == s for e in r["entries"]) for r in group) for s in range(6)]
        falls = [reach[s] - reach[s + 1] for s in range(5)]
        largest = max(falls)
        fastest = ", ".join(f"{s}→{s + 1} ({falls[s]} runs)" for s in range(5) if falls[s] == largest)
        if not largest:
            fast_text = "has no observed between-section reach loss"
        else:
            fast_text = f"loses reach fastest at {fastest}"
        if reach[2]:
            drop = f"its section 2→3 reach drop is {'present' if reach[2] > reach[3] else 'absent'} ({reach[2]}→{reach[3]})"
        else:
            drop = "its section 2→3 drop cannot be assessed because no run entered section 2"
        parts.append(f"`{policy}` {fast_text}; {drop}.")
    return " ".join(parts)


def write_report(output: Path) -> None:
    contract = json.loads((output / "contract.json").read_text())
    sample = json.loads((output / "sample.json").read_text())
    with gzip.open(output / "runs.jsonl.gz", "rt") as source:
        raw = [json.loads(line) for line in source]
    n = sample["common_n"]
    first = contract["first_seed"]
    records = [r for r in raw if first <= r["seed"] < first + n]
    assert len(records) == 3 * n
    fixed_source = (ROOT / "spec/peer_benchmark/decisions.md").read_text()
    start = fixed_source.index("| Tier | s0 | s1 | s2 | s3 | s4 | s5 (shadow) |")
    fixed = fixed_source[start:fixed_source.index("\n\n", start)]
    lines = ["# Whole-run difficulty curve — meas-06, 2026-11", "",
             f"Measurement only. Paired seeds {first}–{first + n - 1}, **N={n} per policy**; default progression, section maps, 24 starting Health, source art. "
             f"Completed before truncation: {sample['completed_per_policy']}; discarded from comparisons: {sample['truncated_runs']}. "
             f"Wall time {sample['elapsed_seconds']:.1f} seconds; launch budget {contract['launch_budget_seconds']:g} seconds, at most {contract['max_workers']} workers. "
             "An in-flight run may finish after the launch deadline. All completed runs, including any truncated suffix, remain in the raw archive.", "",
             f"Source HEAD `{contract['source_head']}` with the uncommitted measurement harness fingerprinted in `contract.json`. "
             f"Combat policy v2 unchanged: `policy_sha256={sample['policy_sha256']}`. "
             f"Map revision {sorted({r['map_revision'] for r in records})}; heuristic scores are the production scorer's unrounded totals in `card_scores.json`.", "",
             "## Reach", "", *reach_table(records), "",
             "Escaped is a whole-run escape after the final dragon; died includes the separately counted 30-turn-cap deaths. Section entry is recorded once, at the production section transition, before the next room choice.", "",
             "## Entry medians", "",
             "| Policy | Section | Health | Max Health | Deck size | Relics | Equipment |",
             "|---|---:|---:|---:|---:|---:|---:|"]
    for policy in POLICIES:
        for section in range(6):
            entries = [e for r in records if r["policy"] == policy for e in r["entries"] if e["section"] == section]
            values = " | ".join(median(entries, key) for key in ("hp", "max_hp", "deck_size", "relics", "equipment"))
            lines.append(f"| {policy} | {section} | {values} |")
    lines += ["", "Equipment counts occupied equipment slots, excluding the unequipped inventory. A dash means no observations.", "",
              "## Fights", "",
              "Each kind cell is wins/fights (win rate). Median Health lost is gross combat damage received, including lethal overkill; net Health change is also retained per fight in the raw data.", "",
              "| Policy | Section | Fights | Standard | Guardian | Dragon | Warband | Snare | Hoarder | Last Light | Median Health lost |",
              "|---|---:|---:|---|---|---|---|---|---|---|---:|"]
    observed_kinds = {f["kind"] for r in records for f in r["fights"]}
    unknown = observed_kinds - set(FIGHT_KINDS)
    if unknown:
        raise ValueError(f"Unreported fight kinds: {unknown}")
    for policy in POLICIES:
        for section in range(6):
            fights = [f for r in records if r["policy"] == policy for f in r["fights"] if f["section"] == section]
            cells = []
            for kind in FIGHT_KINDS:
                group = [f for f in fights if f["kind"] == kind]
                wins = sum(f["won"] for f in group)
                cells.append(f"{wins}/{len(group)} ({100 * wins / len(group):.1f}%)" if group else "—")
            lines.append(f"| {policy} | {section} | {len(fights)} | " + " | ".join(cells) + f" | {median(fights, 'hp_lost')} |")
    lines += ["", "### Fixed-deck reference (copied from decisions.md, 2026-11-01)", "",
              "These are fixed-deck standard-fight win rates from meas-04, not whole-run reach rates.", "", fixed, "",
              "## Comparisons", "", comparisons(records), "",
              "## Cap deaths and uncovered rooms", "",
              "| Policy | 30-turn-cap deaths | Uncovered room kind: count |", "|---|---:|---|"]
    for policy in POLICIES:
        group = [r for r in records if r["policy"] == policy]
        uncovered = Counter()
        for r in group:
            uncovered.update(r["uncovered_rooms"])
        lines.append(f"| {policy} | {sum(r['turn_cap_deaths'] for r in group)} | " + ", ".join(f"{k}: {v}" for k, v in sorted(uncovered.items())) + " |")
    lines += ["", "## Production-transition notes", "",
              "- Map moves follow the REPL's `move_to_room`; any `pre_battle` state uses `begin_pre_battle_combat`, and exits use `continue_pending_escape`. Dragon rewards use `continue_dragon_reward`; no scene-only transition was required.",
              "- Hearth `rest` in the REPL banks Embers and ends the run. To implement the brief's healing-and-continue intent, this harness uses the REPL's `linger`: `leave_campfire(state, CAMPFIRE_LINGER_HEAL)` (production 4 Health). It is used only below 70% Health. There is no production card-upgrade transition. Production purge removes spells, excluding equipment cards. The catalog has no Strike card and the brief does not identify which starter spells are Strike-tier: `TODO_DESIGN_HEARTH_STRIKE_TIER_CARD_IDS` remains empty. At higher Health the harness therefore leaves. This unresolved mapping limits the measured policy; no removal identity was invented.",
              "- `none` skips card rewards using production `skip_reward_for_heal`, so ordinary skipped fight rewards grant their production 3 Health. The `none` draft also selects no merchant card; every policy can buy at most one equipment piece for an empty slot. Event-granted automatic cards remain production effects for every policy.",
              "- Event eligibility uses the same deterministic production transaction as the event preview: gross current-Health cost must be strictly below 25%, and resulting deck size cannot shrink. The first eligible available choice wins, then leave/last available. Equipment from events or combat is equipped at the next legal loadout opportunity if its slot is empty or its rarity is higher.",
              "- Combat uses the unchanged policy's `choose` and `best_dodge` with its existing bounds, on the actual carried combat state. The loop preserves the frozen helper's turn-cap semantics (up to 30 hero turns). A cap is classified as death in measurement data without inventing a production defeat transition.",
              "- Start-room NPCs and Graftwright services are outside the policy; leave unused and count by room kind. Unknown map rooms rank as events. Below 50% Health, merchants under 60 Embers rank after the listed choices; a sole mandatory exit is always entered.", "",
              "## First 10 best-run death decks", ""]
    for record in sorted((r for r in records if r["policy"] == "best"), key=lambda r: r["seed"])[:10]:
        if record["escaped"]:
            lines.append(f"- Seed {record['seed']}: escaped; no death deck.")
        else:
            lines.append(f"- Seed {record['seed']}, section {record['end_section']}: `" + ", ".join(record["deck_at_end"]) + "`.")
    lines += ["", "## Proof and chosen defaults", "",
              "Focused proof: `tools/run_curve_test.py` runs best/seed 1 twice in isolated task-runner processes, compares complete per-run records, and verifies the frozen policy hash against the revision-7 baseline. Proof artifacts: `determinism.json` and `/private/tmp/labyrinth_codex/meas-06/proof/determinism-{1,2}.log`. No full suites or windowed Godot.", "",
              "Measurement-only defaults: random draft RNG seed equals the run seed, in a separate RNG stream; score ties and equipment purchase ties keep engine offer order; max 1,000 state transitions is a fault guard that fails the worker rather than classifying a death. Equipment count means occupied slots; gross damage is the fight Health-loss metric. Records flush after every completed run. `TODO_DESIGN_HEARTH_STRIKE_TIER_CARD_IDS` is the sole unresolved design mapping; no new player-visible values.", "",
              f"Raw per-run records: `runs.jsonl.gz` ({sample['raw_bytes']:,} bytes; under 5 MB). `contract.json` fingerprints inputs and records acceptance/proof/risk/inspection; `sample.json` records actual sample counts. No tuning recommendations.", ""]
    (output / "report.md").write_text("\n".join(lines))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    write_report(parser.parse_args().output.resolve())
