#!/usr/bin/env python3
"""Rebuild meas-05 tables and validate paired raw records; no recommendations."""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import hashlib
import json
import math
from pathlib import Path
import subprocess

from encounter_bot import read_report, summarize
from encounter_sweep import BIOMES, ROOT, cell, distribution
from encounter_shadow_dial_measurement import ARTIFACTS, RESULT_PATH, policy_hash

DOMINANT_INTENT_SHARE = 0.5
METADATA_TOTAL_ABS_TOLERANCE = 1e-8


def same_selection(actual: dict, expected: dict) -> bool:
    if actual.keys() != expected.keys(): return False
    # Godot JSON rounds this derived evidence total to ~14 significant digits.
    # Every field that configures a dial remains an exact comparison.
    return all(math.isclose(float(value), float(expected[key]), rel_tol=0, abs_tol=METADATA_TOTAL_ABS_TOLERANCE)
               if key == "source_total_hp_lost" else value == expected[key]
               for key, value in actual.items())


def damage_summary(rows: list[dict]) -> dict:
    types, intents, kinds, activations = Counter(), Counter(), Counter(), Counter()
    hit_turns = defaultdict(list)
    lethal_turns = []
    total = 0
    for row in rows:
        hits = row["damage"]["hits"]
        assert sum(h["hp_lost"] for h in hits) == row["hp_lost"]
        for index, hit in enumerate(hits, 1):
            assert abs(sum(s["hp_lost"] for s in hit["sources"]) - hit["hp_lost"]) < 1e-8
            total += hit["hp_lost"]
            hit_turns[index].append(hit["turn"])
            if hit["lethal"]: lethal_turns.append(hit["turn"])
            for source in hit["sources"]:
                types[source["enemy_type"]] += source["hp_lost"]
                intents[source["enemy_type"], source["intent_id"]] += source["hp_lost"]
                kinds[source["kind"]] += source["hp_lost"]
        activations.update(a["enemy_type"] for a in row["damage"]["activations"])
    def source_rows(counter: Counter, per_intent: bool) -> list[dict]:
        return [{"enemy_type": key[0] if per_intent else key,
                 **({"intent_id": key[1]} if per_intent else {}),
                 "hp_lost": value, "share": value / total if total else 0,
                 "damage_per_enemy_turn": value / activations[key[0] if per_intent else key]
                 if activations[key[0] if per_intent else key] else None}
                for key, value in sorted(counter.items(), key=lambda item: (-item[1], str(item[0])))]
    enemy_damage = sum(v for k, v in types.items() if k not in ("non_enemy", "unattributed"))
    return {"n": len(rows), "hp_lost_total": total, "enemy_turns": sum(activations.values()),
            "damage_per_enemy_turn": enemy_damage / sum(activations.values()) if activations else 0,
            "by_type": source_rows(types, False), "by_intent": source_rows(intents, True),
            "by_kind": dict(kinds), "activations_by_type": dict(activations),
            "hit_turns": [{"hit": rank, **distribution(turns)} for rank, turns in sorted(hit_turns.items())],
            "lethal_turn": distribution(lethal_turns)}


def choose_dials(catalog: dict, output: Path, include_g: bool = False) -> dict:
    selected = {}
    candidates = []
    for tier in (1, 2, 3):
        rows = read_report(output / f"baseline-t{tier}-shadow.json.gz")["results"]
        damage = damage_summary(rows)
        top_type = next(r["enemy_type"] for r in damage["by_type"] if r["enemy_type"] not in ("non_enemy", "unattributed"))
        counts = Counter()
        for room in catalog["results"]:
            if room["tier"] == tier and room["biome"] == "shadow": counts.update(room["enemy_counts"])
        ranked = sorted(counts, key=lambda key: (-counts[key], key))
        replacement = next(key for key in ranked if key != top_type)
        selected[str(tier)] = {"source": top_type, "replacement": replacement,
                               "source_total_hp_lost": next(r["hp_lost"] for r in damage["by_type"] if r["enemy_type"] == top_type),
                               "replacement_spawn_count": counts[replacement]}
        candidates.extend(r for r in damage["by_intent"] if (include_g or r["share"] >= DOMINANT_INTENT_SHARE)
                          and r["enemy_type"] not in ("non_enemy", "unattributed"))
    if candidates:
        # The brief's "half" is an example, not a mandatory cutoff. A reviewed
        # concentration can explicitly include G below that automatic threshold.
        # Greatest observed share, then damage, lexical identity; same G at all tiers.
        chosen = sorted(candidates, key=lambda r: (-r["share"], -r["hp_lost"], r["enemy_type"], r["intent_id"]))[0]
        for row in selected.values():
            row.update(intent=chosen["intent_id"], intent_enemy=chosen["enemy_type"])
    return selected


def composition_summary(catalog: dict) -> list[dict]:
    result = []
    for tier in (1, 2, 3):
        for biome in BIOMES:
            rows = [r for r in catalog["results"] if r["tier"] == tier and r["biome"] == biome]
            instances, presence = Counter(), Counter()
            for row in rows:
                instances.update(row["enemy_counts"])
                presence.update(row["enemy_counts"].keys())
            result.append({"tier": tier, "biome": biome, "n": len(rows),
                           "enemies": distribution([r["unit_count"] for r in rows]),
                           "hp": distribution([r["spawn_hp"] for r in rows]),
                           "types": [{"id": key, "instances": instances[key], "rooms": presence[key],
                                      "room_share": presence[key] / len(rows)}
                                     for key in sorted(instances, key=lambda k: (-instances[k], k))]})
    return result


def validate_baseline(output: Path, catalog: dict, runs: int) -> int:
    previous = ROOT / "spec/peer_benchmark/encounter_redesign/measurements/shadow_2026-11"
    checked = 0
    for tier in (1, 2, 3):
        original = {(r["biome"], r["seed"]): r for r in read_report(previous / f"default-t{tier}.json.gz")["results"]}
        for biome in ("shadow", "earth"):
            report = read_report(output / f"baseline-t{tier}-{biome}.json.gz")
            assert report["policy_sha256"] == policy_hash()
            expected = [r for r in catalog["results"] if r["tier"] == tier and r["biome"] == biome]
            assert len(report["results"]) == len(expected) == runs
            for row, room in zip(report["results"], expected):
                for field in ("seed", "coord", "travel_dir"):
                    assert row[field] == room[field], (tier, biome, field)
                assert row["natural_layout_sha256"] == row["override_layout_sha256"] == room["layout_sha256"]
                old = original.get((biome, row["seed"]))
                if old:
                    for key in old:
                        if key not in ("room_dark", "enemy_types"): assert row[key] == old[key], (tier, biome, row["seed"], key, row[key], old[key])
                    checked += 1
    return checked


def build(output: Path, result_path: Path, runs: int = 200, first_seed: int = 1) -> dict:
    source_head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    catalog = read_report(output / "catalog.json.gz")
    assert catalog["runs_per_group"] == runs and catalog["first_seed"] == first_seed
    composition = composition_summary(catalog)
    assert len(composition) == 18 and all(r["n"] == runs for r in composition)
    old_catalog = read_report(ROOT / "spec/peer_benchmark/encounter_redesign/measurements/shadow_2026-11/sampling_catalog.json.gz")
    for group in composition:
        key = f'{group["tier"]}/{group["biome"]}'
        rows = [r for r in catalog["results"] if r["tier"] == group["tier"] and r["biome"] == group["biome"]]
        assert [{k: r[k] for k in ("seed", "coord", "travel_dir")} for r in rows] == old_catalog["index"][key][:runs]
    parity = validate_baseline(output, catalog, runs)
    stored_selection = json.loads((output / "selection.json").read_text())
    selection = choose_dials(catalog, output, include_g=any(s.get("intent") for s in stored_selection.values()))
    assert stored_selection == selection
    groups = ["baseline", "A", "B", "C", "D", "E", "F", *(["G"] if any(s.get("intent") for s in selection.values()) else [])]
    damage, outcomes = [], []
    for tier in (1, 2, 3):
        for biome in ("shadow", "earth"):
            rows = read_report(output / f"baseline-t{tier}-{biome}.json.gz")["results"]
            damage.append({"tier": tier, "biome": biome, **damage_summary(rows)})
        natural = read_report(output / f"baseline-t{tier}-shadow.json.gz")
        for group in groups:
            report = read_report(output / f"{group}-t{tier}-shadow.json.gz")
            assert report["policy_sha256"] == policy_hash() and report["defaults"] == natural["defaults"] and report["decks"] == natural["decks"]
            rows = report["results"]
            assert len(rows) == runs and report["room_dark"] == "on"
            assert same_selection(report["selection"], selection[str(tier)] if group in ("F", "G") else {})
            assert len(natural["results"]) == runs
            for base, row in zip(natural["results"], rows):
                for key in ("seed", "coord", "travel_dir", "natural_layout_sha256", "objective", "encounter_id"):
                    assert base[key] == row[key], (group, tier, key)
                if group in ("A", "E"): assert row["roster"] == base["roster"][:max(1, len(base["roster"]) - 1)]
                if group == "B":
                    assert [r["type"] for r in row["roster"]] == [r["type"] for r in base["roster"]]
                    assert [r["hp"] for r in row["roster"]] == [max(1, (int(r["hp"]) * 3 + 3) // 4) for r in base["roster"]]
                if group == "F":
                    source, replacement = selection[str(tier)]["source"], selection[str(tier)]["replacement"]
                    assert [r["type"] for r in row["roster"]] == [replacement if r["type"] == source else r["type"] for r in base["roster"]]
                if group in ("C", "D", "G"): assert row["roster"] == base["roster"]
                damage_summary([row])
            outcomes.append({"group": group, "tier": tier, **summarize(rows)})
    lines = ["# Shadow-room dials — meas-05", "",
             f"Measurement only; map revision 7, seeds starting at {first_seed}, first {runs} eligible standard rooms per tier/element. "
             f"Source HEAD `{source_head}`; frozen policy SHA256 `{policy_hash()}`. Dark on throughout. All outcomes enter median and nearest-rank P10–P90. "
             "HP lost is cumulative actual damage_received (healing can make it exceed 24). No gameplay, authored data or policy edits.", "",
             "Composition: enemy instances at spawn; total generated enemy HP. Type frequency is rooms containing the type / N, followed by total instances in brackets.", "",
             "| Tier | Element | N | Enemies median (P10–P90) | Total HP median (P10–P90) | Type room presence [instances] |",
             "|---:|---|---:|---|---|---|"]
    for row in composition:
        types = "; ".join(f'{t["id"]} {t["rooms"]}/{runs} ({t["room_share"]:.1%}) [{t["instances"]}]' for t in row["types"])
        lines.append(f'| {row["tier"]} | {row["biome"]} | {runs} | {cell(row["enemies"])} | {cell(row["hp"])} | {types} |')
    lines += ["", "Damage: shares use all HP lost, including non-enemy sources. Each `type/intent` entry gives HP lost share and HP per activation of that enemy type. "
              "Enemy turns count all living activations, including status skips and misses. Bleed loss is apportioned by applied stack contribution. "
              "Fire retains its painting intent; Retaliate retains its granting intent. "
              "Fallbacks retain the resolver’s committed intent ID. "
              "Hit rank counts each positive HP-loss call in a run; its median turn uses only runs reaching that hit (N in brackets). Lethal is counted separately. "
              "Type and intent IDs are the authored identities, including enemies whose authored identity differs from the room element.", "",
              "| Tier | Element | N | HP lost total / enemy turns | Enemy HP loss / enemy turn | By enemy: share, HP/own turn | By intent: share, HP/own turn | Top three type/intent sources | Hit rank: median turn [N]; lethal |",
              "|---:|---|---:|---|---:|---|---|---|---|"]
    def shares(entries: list[dict], intent: bool = False) -> str:
        values = []
        for row in entries:
            label = row["enemy_type"] + ("/" + row["intent_id"] if intent else "")
            rate = "—" if row["damage_per_enemy_turn"] is None else f'{row["damage_per_enemy_turn"]:.2f}'
            values.append(f'{label} {row["share"]:.1%}, {rate}')
        return "; ".join(values)
    authored = json.loads((ROOT / "data/enemies.json").read_text())
    def named_sources(entries: list[dict]) -> str:
        result = []
        for entry in entries[:3]:
            definition = authored.get(entry["enemy_type"], {})
            name = definition.get("name", entry["enemy_type"])
            intent = next((i.get("name", i["id"]) for i in definition.get("intents", []) if i["id"] == entry["intent_id"]), entry["intent_id"])
            result.append(f'{name} / {intent} {entry["share"]:.1%}')
        return "; ".join(result)
    for row in damage:
        turns = "; ".join(f'{h["hit"]}: {h["median"]:g} [{h["n"]}]' for h in row["hit_turns"])
        lethal = row["lethal_turn"]
        lethal_text = "none" if not lethal["n"] else f'{lethal["median"]:g} [{lethal["n"]}]'
        lines.append(f'| {row["tier"]} | {row["biome"]} | {runs} | {row["hp_lost_total"]:g} / {row["enemy_turns"]} | {row["damage_per_enemy_turn"]:.2f} | '
                     f'{shares(row["by_type"])} | {shares(row["by_intent"], True)} | {named_sources(row["by_intent"])} | {turns}; lethal: {lethal_text} |')
    descriptions = {"baseline": "unchanged", "A": "remove last spawned, minimum 1", "B": "75% HP, ceil", "C": "attack damage −1, minimum 1", "D": "attack damage −2, minimum 1", "E": "A + C", "F": "pool substitution", "G": "selected intent damage ×2/3, ceil"}
    lines += ["", "F substitutions (highest total enemy-type HP loss → most common remaining shadow-room type by spawn count): " +
              "; ".join(f'tier {tier}: {s["source"]} → {s["replacement"]}' for tier, s in selection.items()) + ". "
              "The temporary table replaces every matching unit token for that shadow layout, retaining entry weights, selection draws and spawn order; the original table is immediately restored. "
              "B also scales subsequently spawned enemies. C/D/E alter authored attack damage after production depth scaling, preserving zero damage and all status riders.", ""]
    if "G" in groups:
        selected = selection["1"]
        concentration = max((entry["share"], row["tier"]) for row in damage if row["biome"] == "shadow"
                            for entry in row["by_intent"] if entry["enemy_type"] == selected["intent_enemy"] and entry["intent_id"] == selected["intent"])
        lines += [f'G: `{selected["intent_enemy"]}/{selected["intent"]}` caused {concentration[0]:.1%} of tier-{concentration[1]} HP loss. '
                  'This near-half concentration was included after damage review (`--include-g`); reduce this same intent across all tiers.', ""]
    else:
        lines += ["G was not added: no single enemy/intent caused at least half of total shadow HP loss in any tier.", ""]
    targets = {1: "about 70–80%", 2: "about 45%", 3: "about 28%"}
    # The brief gives no numeric tolerance around the tier-2/3 target points.
    # Use the observed other-element range as the empirical comparison band,
    # and label it explicitly rather than inventing a tolerance.
    bands = {1: (.70, .80)}
    for tier in (2, 3):
        controls = read_report(ROOT / f"spec/peer_benchmark/encounter_redesign/measurements/shadow_2026-11/default-t{tier}.json.gz")["results"]
        rates = [sum(r["won"] for r in controls if r["biome"] == biome) / sum(r["biome"] == biome for r in controls)
                 for biome in BIOMES if biome != "shadow"]
        bands[tier] = min(rates), max(rates)
        targets[tier] += f"; controls {bands[tier][0]:.1%}–{bands[tier][1]:.1%}"
    lines += ["| Dial | Change | Tier | N | Win rate | Turns median (P10–P90) | HP lost median (P10–P90) | Other-element target |",
              "|---|---|---:|---:|---:|---|---|---|"]
    for row in outcomes:
        lines.append(f'| {row["group"]} | {descriptions[row["group"]]} | {row["tier"]} | {runs} | {row["win_rate"]:.1%} | {cell(row["turns"])} | {cell(row["hp_lost"])} | {targets[row["tier"]]} |')
    in_band = {tier: [r["group"] for r in outcomes if r["tier"] == tier and r["group"] != "baseline" and low <= r["win_rate"] <= high]
               for tier, (low, high) in bands.items()}
    closest = {tier: min((r for r in outcomes if r["tier"] == tier and r["group"] != "baseline"),
                         key=lambda r: (abs(r["win_rate"] - target), r["group"])) for tier, target in ((2, .45), (3, .28))}
    source_repair = json.loads((output / "source-repair.json").read_text()) if (output / "source-repair.json").exists() else {}
    repair_note = (f' {source_repair["replayed_runs"]} source-origin replays corrected {source_repair["changed_intent_labels"]} delayed intent labels; '
                   'all outcomes, hit amounts and timing were identical.') if source_repair else ""
    lines += ["", f'Tier 1 groups within the supplied 70–80% band: {", ".join(in_band[1]) or "none"}. '
              f'Using the observed other-element ranges for tiers 2 and 3, tier 2 ({bands[2][0]:.1%}–{bands[2][1]:.1%}): {", ".join(in_band[2]) or "none"}; '
              f'tier 3 ({bands[3][0]:.1%}–{bands[3][1]:.1%}): {", ".join(in_band[3]) or "none"}. '
              f'Closest to the target centres: tier 2 {closest[2]["group"]} at {closest[2]["win_rate"]:.1%}; tier 3 {closest[3]["group"]} at {closest[3]["win_rate"]:.1%}.', "",
              f'Validation: {parity} baseline fights matched every shared meas-04 result field; 3,600 catalog samples matched the independent meas-04 eligible-seed catalog. '
              'Every dial uses the identical per-tier seed/coordinate/entrance and natural-layout digest. Every positive HP-loss call reconciles with cumulative damage_received.' + repair_note, "",
              "Chosen defaults (offline only): 10 accepted samples per batch; at most four workers; existing 7,200-second measurement timeout; fractional HP/intent damage rounds upward; "
              "frequency ties use lexical IDs; G’s automatic threshold is one-half, with explicit inclusion after reviewing a sharper concentration; its tie order is share, total damage, lexical identity. "
              "Derived HP-total metadata uses 1e-8 absolute tolerance for Godot JSON precision; dial identities remain exact. "
              "No TODO_DESIGN placeholders. No full suites, permanent guards, windowed proof, inspection fixture, commits or publication.", "",
              f'Reproduce in a fresh work directory: `cd {ROOT} && python3 tools/encounter_shadow_dial_measurement.py --workers 4 --work-dir {RESULT_PATH.parent / "reproduce"}' + (' --include-g' if 'G' in groups else '') + '`; '
              f'rebuild tables: `cd {ROOT} && python3 tools/encounter_shadow_dial_report.py`.', ""]
    report = "\n".join(lines)
    (output / "report.md").write_text(report)
    result_path.parent.mkdir(parents=True, exist_ok=True)
    result_path.write_text(report)
    summary = {"source_head": source_head, "policy_sha256": policy_hash(), "runs_per_group": runs, "first_seed": first_seed,
               "baseline_parity_runs": parity, "composition": composition, "damage": damage, "outcomes": outcomes, "selection": selection,
               "comparison_bands": bands, "groups_in_band": in_band}
    summary["raw_sha256"] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(output.glob("*.json.gz"))}
    (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(f"SHADOW DIAL REPORT: PASS ({18 * runs} composition rooms; {6 * runs} damage replays; {len(outcomes) * runs} paired shadow outcomes)")
    print(f"DEFAULT BASELINE PARITY: PASS ({parity} fights; all shared meas-04 fields identical)")
    return summary


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=ARTIFACTS)
    parser.add_argument("--result", type=Path, default=RESULT_PATH)
    args = parser.parse_args()
    build(args.output_dir, args.result)


if __name__ == "__main__":
    main()
