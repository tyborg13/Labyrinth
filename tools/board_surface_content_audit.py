#!/usr/bin/env python3
"""Validate the complete surface roster and regenerate its reviewable score receipt.

This is content/schema proof. Real combat, save, targeting and renderer tests
remain separate. Run from any directory; --output-dir selects isolated artifacts.
"""
from __future__ import annotations

import argparse
import collections
import csv
import json
from pathlib import Path

import card_heuristic as heuristic

PROJECT = Path(__file__).resolve().parents[1]
SURFACES = {"fire", "ice", "electrified", "rubble"}
REMOVED_FIELDS = {"intensity", "intensity_bonus", "requires_intensity", "intensity_cost", "burn", "poison", "freeze"}
TRANSFORMATIONS = {
    "coalheart_crucible": "conductive_fire", "updraft_bottle": "transport_surface",
    "briar_winch": "rubble_redirect", "thornmail_brooch": "stoneskin_melee_cross",
    "frost_prism": "frozen_kill_rubble", "rimecatcher_vial": "freeze_relocate_ice",
    "worldroot_idol": "rubble_attack_origin", "basalt_calendar": "rubble_detonate",
    "thunder_relay": "chain_swap_endpoints",
}


def load(relative: str):
    return json.loads((PROJECT / relative).read_text())


def walk_rules(value, path: str, errors: list[str]) -> None:
    if isinstance(value, list):
        for index, child in enumerate(value):
            walk_rules(child, f"{path}[{index}]", errors)
    elif isinstance(value, dict):
        for field in REMOVED_FIELDS & value.keys():
            errors.append(f"{path}: retired/unconditional {field} field")
        if value.get("type") == "intensity":
            errors.append(f"{path}: retired action")
        if "surface" in value and value["surface"] not in SURFACES:
            errors.append(f"{path}: unknown surface {value['surface']}")
        for condition_key in ("surface_bonus", "requires_surface"):
            if condition_key in value and value[condition_key].get("subject") not in {"player", "target", "consumed", "conducted"}:
                errors.append(f"{path}: missing/unknown conditional subject")
        for key, child in value.items():
            walk_rules(child, f"{path}.{key}", errors)


def connected(pattern: list) -> bool:
    cells = {tuple(cell) for cell in pattern}
    if not cells:
        return False
    seen = {next(iter(cells))}
    pending = list(seen)
    while pending:
        x, y = pending.pop()
        for neighbor in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if neighbor in cells and neighbor not in seen:
                seen.add(neighbor)
                pending.append(neighbor)
    return seen == cells


def rule_nodes(value):
    """Include nested conditional rewards when measuring package support."""
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from rule_nodes(child)
    elif isinstance(value, list):
        for child in value:
            yield from rule_nodes(child)


def support_card_counts(cards: dict) -> dict:
    live = [card for card in cards.values() if not card.get("retired", False)]
    counts = {}
    for surface in sorted(SURFACES):
        counts[f"{surface}_painters"] = sum(any(
            node.get("surface") == surface and node.get("type") not in (None, "consume_surface")
            for node in rule_nodes(card["actions"])
        ) for card in live)
    for action_type in ("detonate", "block", "stoneskin", "draw", "card_play"):
        counts[action_type] = sum(any(node.get("type") == action_type for node in rule_nodes(card["actions"])) for card in live)
    for name, types in {"movement": {"move", "blink"}, "force": {"push", "pull"}}.items():
        counts[name] = sum(any(node.get("type") in types for node in rule_nodes(card["actions"])) for card in live)
    for field in ("chain", "shock"):
        counts[field] = sum(any(node.get(field, 0) > 0 for node in rule_nodes(card["actions"])) for card in live)
    counts["damaging_ice"] = sum(any(node.get("element") == "ice" and node.get("damage", 0) > 0 for node in rule_nodes(card["actions"])) for card in live)
    counts["radiance"] = sum(bool(card.get("radiance", False)) for card in live)
    return counts


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=PROJECT / "output/board-surface-refactor")
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    cards, enemies, relics, skills, equipment = (load(f"data/{name}.json") for name in ("cards", "enemies", "relics", "skills", "equipment"))
    approved = load("spec/board_surface_refactor/CARD_MIGRATION_AUDIT.json")["cards"]
    errors: list[str] = []
    counts = {"cards": len(cards), "enemies": len(enemies), "relics": len(relics), "skills": len(skills), "equipment": len(equipment)}
    expected = {"cards": 159, "enemies": 18, "relics": 60, "skills": 30, "equipment": 42}
    if counts != expected:
        errors.append(f"Stable content inventory changed: {counts} != {expected}")
    if set(cards) != {entry["id"] for entry in approved}:
        errors.append("Card IDs differ from the complete approved migration inventory")
    for card_id, card in cards.items():
        walk_rules(card["actions"], card_id, errors)
        if card.get("radiance") and not any(action.get("type") in {"vision", "truesight", "illuminate", "dispel_umbra"} or action.get("illuminate_radius", 0) for action in card["actions"]):
            errors.append(f"{card_id}: Radiance tag has no Light mechanic")
        for action in card["actions"]:
            if action.get("surface") == "electrified" and len(action.get("surface_pattern", action.get("pattern", []))) > 1:
                if not connected(action.get("surface_pattern", action.get("pattern", []))):
                    errors.append(f"{card_id}: contiguous conductor painter has disconnected tiles")
    for enemy_id, enemy in enemies.items():
        for intent in enemy["intents"]:
            walk_rules(intent["actions"], f"{enemy_id}:{intent['id']}", errors)
            fuel = intent.get("surface_fuel", {})
            for index in fuel.get("action_bonuses", {}):
                if not 0 <= int(index) < len(intent["actions"]):
                    errors.append(f"{enemy_id}:{intent['id']}: fuel modifies a missing action")
    for relic_id, relic in relics.items():
        walk_rules(relic["effects"], relic_id, errors)
    for relic_id, effect in TRANSFORMATIONS.items():
        if effect not in {entry["type"] for entry in relics[relic_id]["effects"]}:
            errors.append(f"{relic_id}: missing approved transformation {effect}")
    for gear_id, gear in equipment.items():
        for card_id in gear["cards"]:
            if card_id not in cards:
                errors.append(f"{gear_id}: unknown granted card {card_id}")
    if sum(not skill.get("retired", False) for skill in skills.values()) != 29:
        errors.append("Active skill inventory must retain 29 abilities")
    sources = heuristic.equipment_card_sources(PROJECT / "data/equipment.json")
    scores = {row["card_id"]: row for row in heuristic.scored_rows(cards, heuristic.HeuristicWeights(), sources)}
    rows = []
    for proposal in approved:
        card_id = proposal["id"]
        card = cards[card_id]
        rows.append({"id": card_id, "name": card["name"], "source": proposal["source"], "equipment_sources": proposal["equipment_sources"], "rarity": card["rarity"], "element": card.get("element", "none"), "disposition": proposal["disposition"], "reviewed_role": proposal["proposed_role"], "implemented_rules": card["description"], "time": card["time"], "score": scores[card_id]["score"], "breakdown": scores[card_id]["breakdown"], "exhaust": card.get("burn", False), "health_cost": card.get("health_cost", 0), "flurry": card.get("flurry", False), "retired": card.get("retired", False), "replacement_id": card.get("replacement_id")})
    metadata = {"counts": counts, "source_counts": dict(collections.Counter(row["source"] for row in rows)), "rules_version": 5, "limitations": "Heuristic plus role review; scores do not prove encounter win rates. Combat, save, targeting and visual verification remain separate.", "errors": errors}
    metadata["support_card_counts"] = support_card_counts(cards)
    (args.output_dir / "relic-support-counts.json").write_text(json.dumps(metadata["support_card_counts"], indent=2) + "\n")
    (args.output_dir / "card-roster-review.json").write_text(json.dumps({"metadata": metadata, "cards": rows}, indent=2) + "\n")
    (args.output_dir / "heuristic-data-review.json").write_text(json.dumps(list(scores.values()), indent=2) + "\n")
    lines = ["# Complete board-surface card roster", "", metadata["limitations"], "", f"159 stable IDs: {metadata['source_counts']}", "", "| Card / ID | Source / rarity | Reviewed role | Implemented rules | Score |", "|---|---|---|---|---|"]
    for row in rows:
        lines.append(f"| {row['name']} / {row['id']} | {row['source']} / {row['rarity']} | {row['reviewed_role']} | {row['implemented_rules']} Time {row['time']}. | {row['score']:.2f} |")
    (args.output_dir / "card-roster-review.md").write_text("\n".join(lines) + "\n")
    with (args.output_dir / "card-roster-review.tsv").open("w") as handle:
        writer = csv.DictWriter(handle, fieldnames=["id", "name", "source", "rarity", "element", "reviewed_role", "implemented_rules", "time", "score"], delimiter="\t", extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    for error in errors:
        print(error)
    print(f"BOARD_SURFACE_CONTENT_{'FAIL' if errors else 'PASS'} {counts} transformations={len(TRANSFORMATIONS)}")
    return bool(errors)


if __name__ == "__main__":
    raise SystemExit(main())
