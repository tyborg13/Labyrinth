#!/usr/bin/env python3
"""Replace relic dependencies on retired intensity and actor statuses.

Each replacement listens to a shared combat event: a Surface placement,
Surface variety, Combust, Electrified attack suppression, Blink, or an enemy
dying on a Surface. This keeps relic build identity without adding private
subsystems.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
RELIC_PATH = ROOT / "data/relics.json"


def reward(reward_type: str, **values: Any) -> dict[str, Any]:
    return {"type": reward_type, **values}


def replacement(
    description: str,
    build_tags: list[str],
    *effects: dict[str, Any],
) -> dict[str, Any]:
    return {
        "description": description,
        "build_tags": build_tags,
        "effects": list(effects),
    }


RELIC_OVERRIDES: dict[str, dict[str, Any]] = {
    "flint_edge": replacement(
        "@icon(melee) attacks on Fire cards that also @icon(move) gain @icon(combust).",
        ["fire", "combust", "mobility"],
        {
            "type": "card_action_mod",
            "element": "fire",
            "requires_action_types": ["move"],
            "action_types": ["melee"],
            "field": "combust",
            "value": True,
        },
    ),
    "static_soles": replacement(
        "The first Lightning card that uses @icon(move) or @icon(blink) each turn grants @icon(block) {0.reward0.amount} and @icon(vision) {0.reward1.amount} for {0.reward1.duration} @icon(time).",
        ["lightning", "mobility", "defense", "vision"],
        {
            "type": "card_play_reward",
            "element": "lightning",
            "requires_any_action_types": ["move", "blink"],
            "once": "turn",
            "rewards": [reward("block", amount=4), reward("vision", amount=1, duration=2)],
        },
    ),
    "frost_prism": replacement(
        "Attacks deal +{0.value} damage to enemies on @icon(surface_snowdrift). The first such enemy killed each turn grants @icon(draw) {1.reward0.amount}.",
        ["ice", "snowdrift", "attack"],
        {"type": "damage_vs_surface", "surface_kind": "snowdrift", "value": 4},
        {
            "type": "enemy_death_reward",
            "on_surface": True,
            "surface_kind": "snowdrift",
            "once": "turn",
            "rewards": [reward("draw", amount=1)],
        },
    ),
    "venom_signet": replacement(
        "Attacks deal +{0.value} damage to enemies on @icon(surface_poison). The first time you place @icon(surface_poison) each turn, @icon(draw) {1.reward0.amount}.",
        ["earth", "poison_surface", "attack"],
        {"type": "damage_vs_surface", "surface_kind": "poison", "value": 3},
        {
            "type": "surface_placed_reward",
            "surface_kind": "poison",
            "once": "turn",
            "rewards": [reward("draw", amount=1)],
        },
    ),
    "briar_winch": replacement(
        "@icon(push) and @icon(pull) actions force enemies on @icon(surface_poison) 1 additional tile.",
        ["earth", "poison_surface", "forced_movement"],
        {
            "type": "target_state_action_mod",
            "target_surface": "poison",
            "action_types": ["push", "pull"],
            "field": "amount",
            "amount": 1,
        },
    ),
    "ember_siphon": replacement(
        "Once per combat, when an enemy dies on a Surface, gain @icon(heal) {0.reward0.amount} and @icon(card_play) {0.reward1.amount}.",
        ["fire", "surface", "execute"],
        {
            "type": "enemy_death_reward",
            "on_surface": True,
            "once": "combat",
            "rewards": [reward("heal", amount=3), reward("card_play", amount=1)],
        },
    ),
    "cold_mirror": replacement(
        "The first time you place @icon(surface_snowdrift) while you have @icon(block) each turn, convert up to @icon(block) {0.reward0.amount} into @icon(stoneskin).",
        ["ice", "snowdrift", "block", "stoneskin"],
        {
            "type": "surface_placed_reward",
            "surface_kind": "snowdrift",
            "player_min_block": 1,
            "once": "turn",
            "rewards": [reward("block_to_stoneskin", amount=6)],
        },
    ),
    "thunder_relay": replacement(
        "The first time @icon(surface_electrified) suppresses an enemy attack each turn, deal {0.reward0.amount} damage to all enemies.",
        ["lightning", "electrified", "control"],
        {
            "type": "attack_suppressed_reward",
            "once": "turn",
            "rewards": [reward("all_enemies_damage", amount=3)],
        },
    ),
    "phoenix_ember": replacement(
        "Gain @icon(defiance) {0.value} this run. When it triggers, @icon(dispel_umbra) {1.reward0.amount}, deal {1.reward1.amount} to all enemies, @icon(draw) {1.reward2.amount}, and gain @icon(card_play) {1.reward3.amount}.",
        ["fire", "radiance", "defiance", "comeback"],
        {"type": "defiance_capacity", "value": 1},
        {
            "type": "defiance_trigger_reward",
            "rewards": [
                reward("dispel_umbra", amount=2),
                reward("all_enemies_damage", amount=6),
                reward("draw", amount=3),
                reward("card_play", amount=3),
            ],
        },
    ),
    "worldroot_idol": replacement(
        "Start combat with @icon(stoneskin) {0.value} per Earth card, up to {0.max_value}. The first @icon(surface_bramble) or @icon(surface_poison) you place each turn grants @icon(stoneskin) {1.reward0.amount}.",
        ["earth", "bramble", "poison_surface", "stoneskin"],
        {
            "type": "start_combat_stoneskin_per_card_element",
            "element": "earth",
            "threshold": 1,
            "value": 2,
            "max_value": 16,
        },
        {
            "type": "surface_placed_reward",
            "surface_kinds": ["bramble", "poison"],
            "once": "turn",
            "rewards": [reward("stoneskin", amount=2)],
        },
    ),
    "cinderbrand_tongs": replacement(
        "The first @icon(combust) attack each turn creates radius-{0.radius} @icon(illuminate) at its target for {0.duration} @icon(time).",
        ["fire", "combust", "radiance"],
        {
            "type": "resolved_action_light",
            "action_types": ["melee", "ranged", "aoe", "push", "pull"],
            "requires_combust": True,
            "position_mode": "target",
            "radius": 1,
            "duration": 8,
            "once": "turn",
        },
    ),
    "starless_astrolabe": replacement(
        "While you have @icon(truesight), attacks that place @icon(surface_snowdrift) or @icon(surface_electrified) create radius-{0.radius} @icon(illuminate) beneath affected enemies for {0.duration} @icon(time).",
        ["radiance", "ice", "lightning", "truesight"],
        {
            "type": "resolved_action_light",
            "action_types": ["melee", "ranged", "aoe", "push", "pull"],
            "requires_any_surface_kinds": ["snowdrift", "electrified"],
            "player_has_truesight": True,
            "position_mode": "affected_enemies",
            "radius": 1,
            "duration": 8,
        },
    ),
    "rimecatcher_vial": replacement(
        "The first time you place @icon(surface_snowdrift) each turn, gain @icon(block) {0.reward0.amount}.",
        ["ice", "snowdrift", "block"],
        {
            "type": "surface_placed_reward",
            "surface_kind": "snowdrift",
            "once": "turn",
            "rewards": [reward("block", amount=4)],
        },
    ),
    "ion_spool": replacement(
        "The first time you place @icon(surface_electrified) each turn, deal {0.reward0.amount} damage to all enemies.",
        ["lightning", "electrified", "chain"],
        {
            "type": "surface_placed_reward",
            "surface_kind": "electrified",
            "once": "turn",
            "rewards": [reward("all_enemies_damage", amount=2)],
        },
    ),
    "updraft_bottle": replacement(
        "Your first @icon(blink) each turn grants @icon(draw) {0.value} and @icon(card_play) {0.card_play}.",
        ["air", "blink", "card_flow"],
        {"type": "blink_draw_once_per_turn", "threshold": 1, "value": 1, "card_play": 1},
    ),
    "basalt_calendar": replacement(
        "Once per combat after your first Earth card, gain @icon(stoneskin) 1 per Earth card in your deck, up to {0.reward0.max_value}, then @icon(draw) {0.reward1.amount}.",
        ["earth", "deck_scaling", "stoneskin"],
        {
            "type": "card_play_reward",
            "element": "earth",
            "once": "combat",
            "rewards": [
                reward("stoneskin_per_deck_element", deck_element="earth", value=1, max_value=8),
                reward("draw", amount=1),
            ],
        },
    ),
    "coalheart_crucible": replacement(
        "The first card with @icon(combust) each turn grants @icon(card_play) {0.reward0.amount} and deals {0.reward1.amount} damage to all enemies.",
        ["fire", "combust", "card_flow"],
        {
            "type": "card_play_reward",
            "requires_any_action_flags": ["combust"],
            "once": "turn",
            "rewards": [reward("card_play", amount=1), reward("all_enemies_damage", amount=2)],
        },
    ),
    "overflow_censer": replacement(
        "The first time you have placed {0.threshold} different Surfaces in one combat, gain @icon(stoneskin) {0.reward0.amount}, @icon(draw) {0.reward1.amount}, and @icon(card_play) {0.reward2.amount}.",
        ["multi_element", "surface", "card_flow"],
        {
            "type": "surface_variety_reward",
            "threshold": 3,
            "once": "combat",
            "rewards": [reward("stoneskin", amount=8), reward("draw", amount=2), reward("card_play", amount=2)],
        },
    ),
    "black_sun_dial": replacement(
        "Once per combat, after you have placed all {0.threshold} Surface kinds, deal {0.reward0.amount} to all enemies, gain @icon(stoneskin) {0.reward1.amount}, @icon(draw) {0.reward2.amount}, and @icon(card_play) {0.reward3.amount}.",
        ["multi_element", "surface", "payoff"],
        {
            "type": "surface_variety_reward",
            "threshold": 5,
            "once": "combat",
            "rewards": [
                reward("all_enemies_damage", amount=12),
                reward("stoneskin", amount=12),
                reward("draw", amount=3),
                reward("card_play", amount=3),
            ],
        },
    ),
}


def main() -> int:
    relics = json.loads(RELIC_PATH.read_text(encoding="utf-8"))
    missing = sorted(set(RELIC_OVERRIDES) - set(relics))
    if missing:
        raise SystemExit(f"Unknown relic overrides: {', '.join(missing)}")
    for relic_id, values in RELIC_OVERRIDES.items():
        relic = relics[relic_id]
        relic["description"] = values["description"]
        relic["build_tags"] = values["build_tags"]
        relic["effects"] = values["effects"]

    # Version 3 denotes that the complete identity has been audited against the
    # board-package overhaul, including relics whose existing Light, Illusion,
    # Blink, defense, or card-flow hooks remain valid without a rules rewrite.
    for relic in relics.values():
        relic["design_version"] = 3
    RELIC_PATH.write_text(json.dumps(relics, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Migrated {len(RELIC_OVERRIDES)} relic identities across {len(relics)} total relics.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
