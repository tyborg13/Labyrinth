#!/usr/bin/env python3
"""Inventory retired combat mechanics during the committed-pattern overhaul.

The default report is progress-oriented and exits successfully. ``--strict`` is
the completion gate: every retired live-data mechanic must be gone. Source-code
compatibility/migration references are reported separately because legacy save
migrations may retain old field names at explicit load boundaries.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[1]

RETIRED_ACTION_TYPES = {"intensity"}
RETIRED_ACTION_FIELDS = {
    "burn",
    "poison",
    "freeze",
    "shock",
    "intensity_bonus",
    "spend_intensity",
}
RETIRED_CARD_FIELDS = {"intensity_cost"}
RETIRED_RELIC_EFFECT_TYPES = {
    "blink_intensity_gain_once_per_turn",
    "damage_vs_status",
    "intensity_threshold_reward",
    "start_combat_stoneskin_per_deck_element",
    "status_count_reward",
    "status_intensity_gain",
    "stoneskin_intensity_gain_once_per_turn",
}
RETIRED_SKILL_EFFECT_TYPES = {
    "arm_intensity",
    "fallback_blink",
    "highest_intensity",
    "preserve_fallback_item",
}
RETIRED_TERMS = (
    "elemental_intensity",
    "intensity_cost",
    "spend_intensity",
    "intensity_bonus",
    "fallback_attack",
    "fallback_move",
)
LIVE_SOURCE_PATHS = (
    "scripts/combat_engine.gd",
    "scripts/combat_board_view.gd",
    "scripts/game_data.gd",
    "scripts/run_scene.gd",
    "scripts/run_engine.gd",
    "scripts/room_generator.gd",
    "scripts/action_icon_library.gd",
    "scripts/skill_tree_library.gd",
    "tools/card_heuristic.py",
)


def _load_json(relative_path: str) -> dict[str, Any]:
    with (ROOT / relative_path).open(encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ValueError(f"{relative_path} must contain a top-level object")
    return value


def _actions(value: Any) -> Iterable[dict[str, Any]]:
    if not isinstance(value, list):
        return
    for entry in value:
        if isinstance(entry, dict):
            yield entry


def _retired_action_reasons(actions: Any) -> list[str]:
    reasons: set[str] = set()
    for action in _actions(actions):
        action_type = str(action.get("type", ""))
        if action_type in RETIRED_ACTION_TYPES:
            reasons.add(f"action:{action_type}")
        for field in RETIRED_ACTION_FIELDS:
            if field in action:
                reasons.add(f"field:{field}")
    return sorted(reasons)


def _card_inventory(cards: dict[str, Any]) -> tuple[dict[str, list[str]], Counter[str]]:
    impacted: dict[str, list[str]] = {}
    action_types: Counter[str] = Counter()
    for card_id, raw in cards.items():
        card = raw if isinstance(raw, dict) else {}
        reasons = _retired_action_reasons(card.get("actions", []))
        reasons.extend(f"card_field:{field}" for field in RETIRED_CARD_FIELDS if field in card)
        for action in _actions(card.get("actions", [])):
            action_types[str(action.get("type", ""))] += 1
        if reasons:
            impacted[card_id] = sorted(set(reasons))
    return impacted, action_types


def _enemy_inventory(enemies: dict[str, Any]) -> dict[str, list[str]]:
    impacted: dict[str, list[str]] = {}
    for enemy_id, raw in enemies.items():
        enemy = raw if isinstance(raw, dict) else {}
        reasons: set[str] = set()
        for intent in _actions(enemy.get("intents", [])):
            reasons.update(_retired_action_reasons(intent.get("actions", [])))
        if reasons:
            impacted[enemy_id] = sorted(reasons)
    return impacted


def _relic_inventory(relics: dict[str, Any]) -> dict[str, list[str]]:
    impacted: dict[str, list[str]] = {}
    for relic_id, raw in relics.items():
        relic = raw if isinstance(raw, dict) else {}
        reasons: set[str] = set()
        for effect in _actions(relic.get("effects", [])):
            effect_type = str(effect.get("type", ""))
            if effect_type in RETIRED_RELIC_EFFECT_TYPES:
                reasons.add(f"effect:{effect_type}")
            serialized = json.dumps(effect, sort_keys=True).lower()
            for term in ("intensity", '"status": "burn"', '"status": "poison"', '"status": "freeze"', '"status": "shock"'):
                if term in serialized:
                    reasons.add(f"payload:{term.replace(chr(34), '')}")
        if reasons:
            impacted[relic_id] = sorted(reasons)
    return impacted


def _skill_inventory(skills: dict[str, Any]) -> dict[str, list[str]]:
    impacted: dict[str, list[str]] = {}
    for skill_id, raw in skills.items():
        skill = raw if isinstance(raw, dict) else {}
        effect = skill.get("effect", {})
        reasons: set[str] = set()
        if isinstance(effect, dict):
            effect_type = str(effect.get("type", ""))
            if effect_type in RETIRED_SKILL_EFFECT_TYPES:
                reasons.add(f"effect:{effect_type}")
            if "intensity" in json.dumps(effect, sort_keys=True).lower():
                reasons.add("payload:intensity")
        if reasons:
            impacted[skill_id] = sorted(reasons)
    return impacted


def _equipment_dependencies(equipment: dict[str, Any], impacted_cards: set[str]) -> dict[str, list[str]]:
    result: dict[str, list[str]] = {}
    for equipment_id, raw in equipment.items():
        definition = raw if isinstance(raw, dict) else {}
        references: list[str] = []
        for card_entry in definition.get("cards", []):
            if isinstance(card_entry, str):
                card_id = card_entry
            elif isinstance(card_entry, dict):
                card_id = str(card_entry.get("id", card_entry.get("card_id", "")))
            else:
                card_id = ""
            if card_id in impacted_cards:
                references.append(card_id)
        if references:
            result[equipment_id] = sorted(set(references))
    return result


def _source_inventory() -> dict[str, dict[str, int]]:
    result: dict[str, dict[str, int]] = {}
    for relative_path in LIVE_SOURCE_PATHS:
        path = ROOT / relative_path
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8").lower()
        counts = {term: text.count(term) for term in RETIRED_TERMS if term in text}
        for status in ("burn", "poison", "freeze", "shock"):
            count = text.count(status)
            if count:
                counts[f"status_term:{status}"] = count
        if counts:
            result[relative_path] = counts
    return result


def build_report() -> dict[str, Any]:
    cards = _load_json("data/cards.json")
    enemies = _load_json("data/enemies.json")
    relics = _load_json("data/relics.json")
    equipment = _load_json("data/equipment.json")
    skills = _load_json("data/skills.json")
    card_issues, action_types = _card_inventory(cards)
    enemy_issues = _enemy_inventory(enemies)
    relic_issues = _relic_inventory(relics)
    skill_issues = _skill_inventory(skills)
    equipment_dependencies = _equipment_dependencies(equipment, set(card_issues))
    strict_issue_count = sum(map(len, (card_issues, enemy_issues, relic_issues, skill_issues)))
    return {
        "counts": {
            "cards": len(cards),
            "enemies": len(enemies),
            "relics": len(relics),
            "equipment": len(equipment),
            "skills": len(skills),
        },
        "card_action_types": dict(sorted(action_types.items())),
        "retired_live_data": {
            "cards": card_issues,
            "enemies": enemy_issues,
            "relics": relic_issues,
            "skills": skill_issues,
        },
        "equipment_referencing_impacted_cards": equipment_dependencies,
        "retired_live_source_terms": _source_inventory(),
        "strict_issue_count": strict_issue_count,
    }


def _print_section(title: str, entries: dict[str, Any]) -> None:
    print(f"\n{title} ({len(entries)})")
    for item_id, reasons in sorted(entries.items()):
        if isinstance(reasons, dict):
            detail = ", ".join(f"{key}={value}" for key, value in sorted(reasons.items()))
        else:
            detail = ", ".join(str(reason) for reason in reasons)
        print(f"  {item_id}: {detail}")


def print_text(report: dict[str, Any]) -> None:
    counts = report["counts"]
    print("Combat overhaul migration audit")
    print("  " + ", ".join(f"{key}={value}" for key, value in counts.items()))
    retired = report["retired_live_data"]
    _print_section("Cards with retired mechanics", retired["cards"])
    _print_section("Enemies with retired mechanics", retired["enemies"])
    _print_section("Relics with retired mechanics", retired["relics"])
    _print_section("Skills with retired mechanics", retired["skills"])
    _print_section("Equipment depending on impacted cards", report["equipment_referencing_impacted_cards"])
    _print_section("Live source references requiring migration review", report["retired_live_source_terms"])
    print(f"\nStrict live-data issues: {report['strict_issue_count']}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="Emit the structured report as JSON")
    parser.add_argument("--strict", action="store_true", help="Fail while retired live-data mechanics remain")
    args = parser.parse_args()
    report = build_report()
    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        print_text(report)
    return 1 if args.strict and int(report["strict_issue_count"]) > 0 else 0


if __name__ == "__main__":
    raise SystemExit(main())
