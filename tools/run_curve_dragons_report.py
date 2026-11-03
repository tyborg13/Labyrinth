#!/usr/bin/env python3
"""Wilson intervals and existing-log-only dragon comparisons."""
from __future__ import annotations

from collections import Counter
import gzip
import json
import math
from pathlib import Path
import statistics

from run_curve_ladder_report import percentile

WILSON_Z = statistics.NormalDist().inv_cdf(.975)


def wilson(wins: int, n: int) -> tuple[float, float]:
    p = wins / n
    z2 = WILSON_Z * WILSON_Z
    center = (p + z2 / (2*n)) / (1 + z2/n)
    half = WILSON_Z * math.sqrt(p*(1-p)/n + z2/(4*n*n)) / (1+z2/n)
    return max(0.0, center-half), min(1.0, center+half)


def cells(rows: list[dict]) -> str:
    n = len(rows)
    wins = sum(r["won"] for r in rows)
    lo, hi = wilson(wins, n)
    turns = [r["turns"] for r in rows]
    won_hp = [r["hp_after"] for r in rows if r["won"]]
    return (f"{wins}/{n} | {100*wins/n:.1f}% [{100*lo:.1f}, {100*hi:.1f}] | "
            f"{statistics.median(r['hp_lost'] for r in rows):g} | {statistics.median(turns):g} [{percentile(turns,.1):g}, {percentile(turns,.9):g}] | "
            + (f"{statistics.median(won_hp):g}" if won_hp else "—") + f" | {sum(r['turn_cap_reached'] for r in rows)}")


def section_table(rows: list[dict]) -> list[str]:
    lines = ["| Section | Wins/fights | Win rate [95% Wilson CI] | Median Health lost | Turns median [P10, P90] | Median Health left in wins | Caps |",
             "|---:|---:|---|---:|---|---:|---:|"]
    for section in range(6):
        group = [r for r in rows if r["section"] == section]
        lines.append(f"| {section} | " + cells(group) + " |")
    return lines


def load_rows(output: Path) -> tuple[list[dict], list[dict]]:
    sample = json.loads((output / "dragons_sample.json").read_text())
    with gzip.open(output / "dragons_runs.jsonl.gz", "rt") as stream: raw = [json.loads(x) for x in stream]
    cases = {tuple(pair) for pair in sample["common_cases"]}
    rows = [r for r in raw if (r["ladder_seed"], r["repeat"]) in cases]
    return rows, raw


def comparison(rows: list[dict]) -> str:
    groups = [[r for r in rows if r["section"] == section] for section in range(6)]
    rates = [100*sum(r["won"] for r in group)/len(group) for group in groups]
    parts = ["Dragon win rates by section 0–5 are " + " / ".join(f"{v:.1f}%" for v in rates) + "."]
    for section in (3,4):
        delta = rates[5]-rates[section]
        direction = "higher" if delta>0 else "lower" if delta<0 else "equal"
        parts.append(f"The final dragon is {abs(delta):.1f} percentage points {direction} than section {section} ({rates[5]:.1f}% versus {rates[section]:.1f}%).")
    intervals = [wilson(sum(r["won"] for r in groups[s]),len(groups[s])) for s in (3,4,5)]
    for i,section in enumerate((3,4)):
        overlap = max(intervals[i][0],intervals[2][0]) <= min(intervals[i][1],intervals[2][1])
        parts.append(f"The final and section-{section} 95% Wilson intervals {'overlap' if overlap else 'do not overlap'}.")
    return " ".join(parts)



def half_health_notes(rows: list[dict]) -> list[str]:
    retained = [r for r in rows if r["native_battlefield_rule"].get("at_half_health")]
    switched = sum(bool(r["native_battlefield_rule"].get("half_health_switched", False)) for r in retained)
    events = sum(e.get("kind") == "battlefield_rule_switched" for r in rows for e in r["native_surface_events"])
    examples = []
    for r in retained:
        source_id = r["native_battlefield_rule"].get("source", {}).get("id")
        source = next((e for e in r["native_enemy_end"] if e["id"] == source_id), None)
        if source and source["hp"] == 1 and not r["native_battlefield_rule"].get("half_health_switched", False):
            examples.append(r)
    lines = ["", "### Elemental half-Health rule acceptance is missing from this frozen path", "",
             f"Native end states retain {len(retained)} configured `at_half_health` rules; {switched} have `half_health_switched=true`. "
             f"Retained native event windows contain {events} `battlefield_rule_switched` events. "
             f"In {len(examples)} fights the configured source dragon remains alive at exactly 1 Health and its switch is still false. "
             "Successful kills can clear the rule from the end state, so these counts are end-state evidence, not a count of every threshold crossing.", "",
             "The code path explains this observation: `scripts/battlefield_rules/committed.gd` calls `HalfHealth.check` on accepted transitions. The byte-frozen policy and `tools/run_curve_combat.gd` call base CombatEngine card/phase methods without that acceptance callback. `data/battlefield_rules.json` configures half-Health changes for Tharokh, Vyraketh, Vaeloryx, Iskaldra and Zekarion; Noctyrax has none. Thus this is a material simulation-fidelity caveat for the elemental fights. No policy/gameplay change or counterfactual effect size is included in this measurement.", ""]
    for r in examples[:4]:
        lines.append(f"- Native example: ladder seed {r['ladder_seed']}, section {r['section']}, repeat {r['repeat']}, {r['dragon_id']}, dragon Health 1, switch false, won={r['won']}, turns={r['turns']}.")
    return lines


def write_report(output: Path) -> None:
    rows,raw = load_rows(output)
    sample=json.loads((output/"dragons_sample.json").read_text())
    contract=json.loads((output/"dragons_contract.json").read_text())
    lines=["# Dragons from growing-deck ladder loadouts — meas-06 feedback 2", "",
           f"**N={sample['n_per_section']} fights per section**, truncated to the same ordered prefix of complete four-RNG ladder loadouts. "
           f"Target: 25 saved ladders × 4 RNG seeds = 100 per section; it was not reached because the 40-minute budget included required ladder recovery. Retained complete loadouts: {sample.get('complete_ladder_seeds', [])}. Recovered ladder seeds: {sample['recovered_ladder_seeds']}. "
           f"Raw counts before truncation: {sample['raw_counts_per_section']}; excluded counts: {sample['truncated_per_section']}.", "",
           f"New measured fights stop launching at {contract['launch_budget_seconds']:g} seconds; at most {contract['max_workers']} workers. "
           f"Elapsed including active recovery/fight completion: {sample['elapsed_seconds']:.1f} seconds. All earlier reports and artifacts are unchanged.", "",
           "## Per section", "", *section_table(rows), "", "## Per section and real dragon", "",
           "| Section | Dragon id / element | Wins/fights | Win rate [95% Wilson CI] | Median Health lost | Turns median [P10, P90] | Median Health left in wins | Caps |",
           "|---:|---|---:|---|---:|---|---:|---:|"]
    for section in range(6):
        for dragon in sorted({r['dragon_id'] for r in rows if r['section']==section}):
            group=[r for r in rows if r['section']==section and r['dragon_id']==dragon]
            lines.append(f"| {section} | {dragon} / {group[0]['element']} | "+cells(group)+" |")
    lines += ["", "## Comparisons", "", comparison(rows), "", "## Damage-source limits and existing log evidence", "",
              "The saved ladder records did not contain full pre-dragon loadouts, dragon identity, or a damage-source ledger. The same ladder seeds and best policy were replayed to recover exact production constructor inputs. Each complete recovered ladder was compared against its original full JSON record, and every original-seed dragon result was checked against the old dragon metrics. No gameplay or damage instrumentation was added.", "",
              "The retained native combat state has a total Health-loss counter, a 12-line text-log tail and at most 256 surface/rule events. Direct damage does not have an exhaustive source-attributed per-hit ledger in that state. Therefore complete shares for dragon direct attacks / dragon rule / surfaces / helpers are **unavailable for every dragon**. The table below reports only existing counters and retained evidence, not a reconstructed four-way attribution.", "",
              "| Dragon | Fights | Total Health lost | Native hidden-attack Health lost | Fights with hidden loss | Truncated native event windows | Turn caps |",
              "|---|---:|---:|---:|---:|---:|---:|"]
    for dragon in sorted({r['dragon_id'] for r in rows}):
        group=[r for r in rows if r['dragon_id']==dragon]
        hidden=[int(r['native_umbra'].get('hidden_attack_damage_received_total',0)) for r in group]
        lines.append(f"| {dragon} | {len(group)} | {sum(r['hp_lost'] for r in group)} | {sum(hidden)} | {sum(v>0 for v in hidden)} | {sum(r['native_surface_event_sequence']>len(r['native_surface_events']) for r in group)} | {sum(r['turn_cap_reached'] for r in group)} |")
    shadow=[r for r in rows if r['dragon_id']=='noctyrax']
    unlit=[r for r in shadow if any(not b.get('lit',True) for b in r['native_braziers'])]
    restored=sum(e.get('kind')=='dragon_light_restored' for r in shadow for e in r['native_surface_events'])
    examples=[r for r in rows if r['native_umbra'].get('hidden_attack_damage_received_total',0)>0][:3]
    lines += ["", "## Bot caveat — evidence, not counterfactual play", "",
              f"Policy v2 uses revealed-intent previews and bounded greedy search. Measured turn caps: {sum(r['turn_cap_reached'] for r in rows)}; decision-cap flags: {sum(r['search_capped'] for r in rows)}. Caps are losses. Per-dragon counts appear above. The flags above report whether those bounds were reached; no causal effect of unlogged candidate rejection is inferred.", "",
              f"Noctyrax: {len(unlit)}/{len(shadow)} retained final states have at least one unlit brazier; native retained events contain {restored} `dragon_light_restored` events. "
              f"Native Noctyrax hidden-attack Health loss totals {sum(int(r['native_umbra'].get('hidden_attack_damage_received_total',0)) for r in shadow)}. "
              "The frozen policy's `gain`, `objective_distance` and `option_score` reward damage, kills, survival/Health and Reach Exit progress; they have no explicit light-restoration term. Native state/logs establish actual darkness/relighting and hidden damage, but do not enumerate available and rejected targets. They cannot establish that a particular target was ignored, or what a sight-aware/target-aware alternative would have achieved.", ""]
    if examples:
        for r in examples:
            lines.append(f"- Logged example seed {r['ladder_seed']}, section {r['section']}, repeat {r['repeat']}, {r['dragon_id']}: native hidden-attack Health loss {r['native_umbra']['hidden_attack_damage_received_total']}; won={r['won']}; turns={r['turns']}. Raw native log tail and event window are retained in `dragons_runs.jsonl.gz`.")
    else: lines.append("No selected fight's native hidden-attack counter reports Health loss; the sampled logs do not support attributing the observed comparison to hidden attacks.")
    lines.extend(half_health_notes(rows))
    lines += ["", "## Recovery, identity and RNG protocol", "",
              "- On-demand tools: `tools/run_curve_dragons.py` and `.gd`. The existing whole-run driver gained no-op factory/observation hooks; the recovery subclass observes production `CombatEngine.begin_combat_creation` inputs without changing transitions or policy. Captured layouts and full player snapshots include deck ids, relics, equipment, max Health, omens, skills, Defiance and all other production snapshot fields. Native Variant serialization is round-tripped, and reconstructing the original combat from it is asserted identical to the ladder's initial combat state.",
              "- Repeat 0 is the actual recovered original-RNG dragon fight. Repeats 1–3 call the identical production `create_combat` factory with the same captured layout/snapshot and full current max Health, changing only the combat seed input to `ladder_seed + repeat × 1000003`. Original room geometry, section depth/scaling and dragon identity remain fixed. Every record retains dragon id, element, ladder seed, room coordinate, original geometry room seed (production salt 101), combat seed input and derived combat RNG seed.",
              "- Recovery runs can finish after the launch deadline to validate the saved run, but their dragon fights that start after the deadline are excluded from measurements. Additional RNG fights check the same deadline before creation. All finished measured records remain in the raw archive; tables use the complete common seed prefix across all six sections, rounded down to four-repeat blocks so every retained loadout has equal weight.",
              "- The first five sections can contain different elemental dragons across ladder seeds; the final section is Noctyrax/shadow. The per-section/id table separates the observed identities rather than assuming a single elemental dragon per section.",
              "- Wilson intervals are ordinary 95% binomial intervals over fights. Four RNG repeats share a loadout; these are descriptive fight-level intervals, not cluster-adjusted uncertainty over a new population of ladder loadouts. The comparison is conditional on the section-specific grown loadouts and production section scaling; it does not isolate intrinsic dragon strength from those inputs.",
              "- Health lost is the engine's gross `damage_received` increment, not net Health change after healing; the engine caps each actual Health loss at available Health. Turns use the unchanged 30-turn-cap semantics. P10/P90 use linear interpolation at (n−1)×p. Health remaining is measured immediately after a real fight win, before run rewards/healing.", "",
              f"Frozen `policy_sha256={sample['policy_sha256']}`. Collection-source and prior artifact hashes: `dragons_contract.json`; archived collection Python sources: `dragons_collection_tools.json.gz`. Reporting-only refinements after collection are recorded separately in the contract. Recovery loadouts and native typed payloads: `dragons_loadouts.jsonl.gz`. Native fight records: `dragons_runs.jsonl.gz` ({sample['raw_bytes']:,} bytes). Sample/truncation metadata: `dragons_sample.json`. No full suites, windowed Godot, new default-group tests or tuning recommendations.", ""]
    (output/'dragons.md').write_text('\n'.join(lines))
