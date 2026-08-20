#!/usr/bin/env python3
"""Apply the reviewed elemental-package migration to the complete card pool.

The migration is deliberately declarative: every elemental card and every
neutral card that used a retired actor status has an explicit replacement.
Names, rarity, art, equipment ownership, and top-level pacing fields remain
untouched.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
CARD_PATH = ROOT / "data/cards.json"

CROSS = [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]]
ADJACENT = [[0, -1], [1, 0], [0, 1], [-1, 0]]
WIDE = CROSS + [[2, 0], [-2, 0], [0, 2], [0, -2], [1, 1], [1, -1], [-1, 1], [-1, -1]]
LINE_2 = [[0, 0], [1, 0]]
LINE_3 = [[0, 0], [1, 0], [2, 0]]
FORWARD_3 = [[1, 0], [2, 0], [3, 0]]
BACKWARD_3 = [[0, 0], [-1, 0], [-2, 0]]


def action(action_type: str, **values: Any) -> dict[str, Any]:
    return {"type": action_type, **values}


def override(description: str, *actions: dict[str, Any]) -> dict[str, Any]:
    return {"description": description, "actions": list(actions)}


CARD_OVERRIDES: dict[str, dict[str, Any]] = {
    # Fire: broad patterns and Combust cash-outs; Fire creates no Surface.
    "guiding_flare": override(
        "Deal 7 at range 5 and Combust, then create radius-2 Light at the impact for 2 turns.",
        action("ranged", damage=7, range=5, combust=True, illuminate_radius=2, illuminate_duration=2),
    ),
    "firebrand_volley": override(
        "Deal 7 at range 5 and Combust, then create radius-1 Light at the impact for 2 turns.",
        action("ranged", damage=7, range=5, combust=True, illuminate_radius=1, illuminate_duration=2),
    ),
    "cinder_bloom": override(
        "Deal 8 and Combust in a cross pattern at range 4.",
        action("aoe", damage=8, range=4, pattern=CROSS, rotate=False, combust=True),
    ),
    "hearth_rush": override(
        "Create a 2-health illusion, move 2, then strike for 8 and Combust.",
        action("illusion", health=2, range=3),
        action("move", range=2),
        action("melee", damage=8, range=1, combust=True),
    ),
    "cinderline_tempo": override(
        "Deal 6 at range 4 and Combust, then gain 1 card play.",
        action("ranged", damage=6, range=4, combust=True),
        action("card_play", amount=1),
    ),
    "inferno_ritual": override(
        "Deal 11 and Combust in a cross pattern at range 4.",
        action("aoe", damage=11, range=4, pattern=CROSS, rotate=False, combust=True),
    ),
    "molten_reach": override(
        "Deal 12 and Combust at range 6.",
        action("ranged", damage=12, range=6, combust=True),
    ),
    "wildfire_halo": override(
        "Deal 7 and Combust in a large pattern at range 5.",
        action("aoe", damage=7, range=5, pattern=WIDE, rotate=False, combust=True),
    ),
    "phoenix_cleave": override(
        "Exhaust. Lose 1 health. Cleave every adjacent tile for 11 and Combust.",
        action("aoe", damage=11, range=0, pattern=ADJACENT, rotate=False, combust=True),
    ),
    "ember_guard": override(
        "Gain 7 block, draw 1, and gain 1 card play.",
        action("block", amount=7),
        action("draw", amount=1),
        action("card_play", amount=1),
    ),
    "rekindle_edge": override(
        "Strike for 8 and Combust, then gain 1 card play.",
        action("melee", damage=8, range=1, combust=True),
        action("card_play", amount=1),
    ),
    "cinderweave_guard": override(
        "Gain 6 block, then scorch every adjacent tile for 6 and Combust.",
        action("block", amount=6),
        action("aoe", damage=6, range=0, pattern=ADJACENT, rotate=False, combust=True),
    ),
    "cinder_patch": override(
        "Exhaust. Heal 2, gain 4 block, and Radiate your tile and every adjacent tile.",
        action("heal", amount=2),
        action("block", amount=4),
        action("field", kind="radiance", target_mode="self", pattern=CROSS, rotate=False, duration=18),
    ),
    "borrowed_spark": override(
        "Exhaust. Lose 1 health. Radiate your tile and every adjacent tile, draw 2, and gain 1 card play.",
        action("field", kind="radiance", target_mode="self", pattern=CROSS, rotate=False, duration=18),
        action("draw", amount=2),
        action("card_play", amount=1),
    ),
    "cinder_second": override(
        "Gain 1 card play and draw 1.",
        action("card_play", amount=1),
        action("draw", amount=1),
    ),
    "pitch_firebomb": override(
        "Consume. Hurl fire at range 5 for 9 and Combust in a wide blast.",
        action("aoe", damage=9, range=5, pattern=CROSS, rotate=False, combust=True),
    ),
    "cinder_fusillade": override(
        "Flurry. Deal 4 and Combust at range 6 for each card play spent.",
        action("ranged", damage=4, range=6, combust=True),
    ),

    # Ice: Ice routes movement; Snowdrift marks attack-vulnerable tiles.
    "prism_sight": override(
        "Gain truesight for 2 turns, gain 4 block, and draw 1.",
        action("truesight", duration=2), action("block", amount=4), action("draw", amount=1),
    ),
    "frostbolt": override(
        "Cover the target tile in Snowdrift, then deal 4 at range 6.",
        action("ranged", damage=4, range=6, surface_kind="snowdrift", surface_timing="before"),
    ),
    "icebound_chains": override(
        "Deal 6 and immobilize at range 6, then lay Ice behind the target.",
        action("ranged", damage=6, range=6, immobilize=True, surface_kind="ice", surface_pattern=FORWARD_3),
        action("truesight", duration=2),
    ),
    "rime_shard": override(
        "Create a 3-health illusion and surround it with Ice.",
        action("illusion", health=3, range=4, surface_kind="ice", surface_pattern=ADJACENT, surface_rotate=False),
    ),
    "cold_grasp": override(
        "Cover the target tile in Snowdrift, then strike up to range 2 for 6.",
        action("melee", damage=6, range=2, surface_kind="snowdrift", surface_timing="before"),
    ),
    "icicle_lance": override(
        "Pierce for 7 at range 5, then leave a two-tile Ice line behind the target.",
        action("ranged", damage=7, range=5, pierce=True, surface_kind="ice", surface_pattern=[[1, 0], [2, 0]]),
    ),
    "hush_of_winter": override(
        "Deal 9 at range 7, lay Ice behind the target, and draw 1.",
        action("ranged", damage=9, range=7, surface_kind="ice", surface_pattern=FORWARD_3),
        action("draw", amount=1),
    ),
    "shatterline": override(
        "Cover a line in Snowdrift, then pierce it for 8 at range 5.",
        action("aoe", damage=8, range=5, pattern=LINE_3, rotate=True, pierce=True, surface_kind="snowdrift", surface_mode="affected", surface_timing="before"),
    ),
    "glacier_pin": override(
        "Deal 7 across two tiles at range 5, immobilize targets, and cover the pattern in Ice.",
        action("aoe", damage=7, range=5, pattern=LINE_2, rotate=True, immobilize=True, surface_kind="ice", surface_mode="affected"),
    ),
    "white_silence": override(
        "Cover the target tile in Snowdrift, then deal 12 at range 7.",
        action("ranged", damage=12, range=7, surface_kind="snowdrift", surface_timing="before"),
    ),
    "rimeplate_lock": override(
        "Gain 4 stoneskin and 3 block, then pin for 3 and immobilize at range 4, leaving Ice behind the target.",
        action("stoneskin", amount=4), action("block", amount=3),
        action("ranged", damage=3, range=4, immobilize=True, surface_kind="ice", surface_pattern=[[1, 0], [2, 0]]),
    ),
    "hoarfrost_shell": override(
        "Gain 6 block and 3 stoneskin, then lay Ice on every adjacent tile.",
        action("block", amount=6), action("stoneskin", amount=3),
        action("surface", kind="ice", target_mode="self", pattern=ADJACENT, rotate=False, duration=18),
    ),
    "locket_chill": override(
        "Cover the target tile in Snowdrift, then deal 4 at range 6.",
        action("ranged", damage=4, range=6, surface_kind="snowdrift", surface_timing="before"),
    ),
    "kept_breath": override(
        "Cover a two-tile line in Snowdrift at range 4, gain 5 block, and draw 1.",
        action("surface", kind="snowdrift", range=4, pattern=LINE_2, rotate=True, duration=18),
        action("block", amount=5), action("draw", amount=1),
    ),
    "frost_snare": override(
        "Consume. Snap a target at range 5 for 6, immobilize, and lay Ice behind it.",
        action("ranged", damage=6, range=5, immobilize=True, surface_kind="ice", surface_pattern=FORWARD_3),
    ),

    # Air: deterministic force, movement, and card-flow compression.
    "dawnstep": override("Move 3, then gain 2 vision for 2 turns.", action("move", range=3), action("vision", amount=2, duration=2)),
    "threaded_path": override(
        "Move 5. Create radius-1 Light where you arrive for 2 turns, then draw 1.",
        action("move", range=5, illuminate_radius=1, illuminate_duration=2, illuminate_position_mode="destination"), action("draw", amount=1),
    ),
    "gust_step": override(
        "Create a 2-health illusion, pull 2 at range 4 for 4, then gain 1 card play.",
        action("illusion", health=2, range=4), action("pull", amount=2, range=4, damage=4), action("card_play", amount=1),
    ),
    "slipstream_cut": override(
        "Move 3, then strike for 6, push 1, and gain 1 card play.",
        action("move", range=3), action("melee", damage=6, range=1, push=1), action("card_play", amount=1),
    ),
    "updraft": override(
        "Push 2 at range 4 for 6, then gain 1 card play.",
        action("push", amount=2, range=4, damage=6), action("card_play", amount=1),
    ),
    "vacuum_line": override("Pull 5 at range 5 for 11, then draw 1.", action("pull", amount=5, range=5, damage=11), action("draw", amount=1)),
    "squall_shot": override(
        "Deal 6 in an odd pattern at range 5, push 1, and gain 1 card play.",
        action("aoe", damage=6, range=5, pattern=[[0, 0], [2, 0], [0, 2]], rotate=True, push=1), action("card_play", amount=1),
    ),
    "skybreak_current": override(
        "Move 4, then deal 12 at range 6 and push 3.",
        action("move", range=4), action("ranged", damage=12, range=6, push=3),
    ),
    "cloudstep_loop": override(
        "Blink 3, draw 1, and gain 1 card play.",
        action("blink", range=3), action("draw", amount=1), action("card_play", amount=1),
    ),
    "zephyr_feint": override(
        "Move 3, create a 2-health illusion, draw 1, and gain 1 card play.",
        action("move", range=3), action("illusion", health=2, range=3), action("draw", amount=1), action("card_play", amount=1),
    ),
    "razor_gale": override(
        "Flurry. Move 1, then deal 3 at range 5 and push 1 for each card play spent.",
        action("move", range=1), action("ranged", damage=3, range=5, push=1),
    ),

    # Lightning: Chain rewards grouping; Electrified tiles suppress attacks.
    "storm_beacon": override(
        "Deal 5 with chain 2 at range 6, Electrify the target tile, then create radius-2 Light there for 2 turns.",
        action("ranged", damage=5, range=6, chain=2, surface_kind="electrified", illuminate_radius=2, illuminate_duration=2),
    ),
    "spark_dart": override(
        "Deal 5 at range 6, Electrify the target tile, then create radius-1 Light there for 2 turns.",
        action("ranged", damage=5, range=6, surface_kind="electrified", illuminate_radius=1, illuminate_duration=2),
    ),
    "chain_bolt": override(
        "Deal 5 at range 5 with chain 2, then Electrify the target tile.",
        action("ranged", damage=5, range=5, chain=2, surface_kind="electrified"),
    ),
    "spark_focus": override(
        "Electrify a three-tile line at range 5, draw 1, then gain 1 vision for 2 turns.",
        action("surface", kind="electrified", range=5, pattern=LINE_3, rotate=True, duration=18), action("draw", amount=1), action("vision", amount=1, duration=2),
    ),
    "static_lash": override(
        "Deal 7 at range 6, then Electrify the target tile.",
        action("ranged", damage=7, range=6, surface_kind="electrified"),
    ),
    "storm_relay": override(
        "Deal 9 at range 6 with chain 2, then Electrify the target tile.",
        action("ranged", damage=9, range=6, chain=2, surface_kind="electrified"),
    ),
    "volt_surge": override(
        "Create a 3-health illusion surrounded by Electrified tiles, then deal 7 at range 6.",
        action("illusion", health=3, range=5, surface_kind="electrified", surface_pattern=ADJACENT, surface_rotate=False), action("ranged", damage=7, range=6),
    ),
    "thunderline": override(
        "Deal 10 in a line at range 6, then Electrify the entire pattern.",
        action("aoe", damage=10, range=6, pattern=LINE_3, rotate=True, surface_kind="electrified", surface_mode="affected"),
    ),
    "stormstring_shot": override(
        "Deal 6 at range 7 with chain 1, then Electrify the target tile.",
        action("ranged", damage=6, range=7, chain=1, surface_kind="electrified"),
    ),
    "forked_nock": override(
        "Deal 7 at range 6 with chain 2 and expose 2.",
        action("ranged", damage=7, range=6, chain=2, expose=2),
    ),
    "far_draw": override(
        "Electrify a two-tile line at range 5, then draw 1.",
        action("surface", kind="electrified", range=5, pattern=LINE_2, rotate=True, duration=18), action("draw", amount=1),
    ),
    "lodestone_reversal": override(
        "Electrify the pull route, pull 2 at range 5 for 4, then gain 5 block.",
        action("pull", damage=4, range=5, amount=2, surface_kind="electrified", surface_pattern=BACKWARD_3, surface_timing="before"), action("block", amount=5),
    ),
    "polar_guard": override("Gain 6 block and 1 card play.", action("block", amount=6), action("card_play", amount=1)),
    "static_pivot": override(
        "Move 4, deal 5 at range 4, then Electrify the target tile.",
        action("move", range=4), action("ranged", damage=5, range=4, surface_kind="electrified"),
    ),
    "spur_spark": override("Move 2, draw 1, and gain 1 card play.", action("move", range=2), action("draw", amount=1), action("card_play", amount=1)),
    "storm_jar": override(
        "Consume. Deal 9 at range 6 with chain 2, then Electrify the target tile.",
        action("ranged", damage=9, range=6, chain=2, surface_kind="electrified"),
    ),
    "storm_salvo": override(
        "Flurry. Deal 3 at range 6 with chain 1, then draw 1, for each card play spent.",
        action("ranged", damage=3, range=6, chain=1), action("draw", amount=1),
    ),

    # Earth: Bramble fixes positions; Poison punishes later route tiles.
    "glowstone_ward": override(
        "Gain 4 stoneskin and Radiate a cross pattern at range 3.",
        action("stoneskin", amount=4), action("field", kind="radiance", range=3, pattern=CROSS, rotate=False, duration=18),
    ),
    "venom_claw": override(
        "Strike for 10, then lay a three-tile Poison route behind the target.",
        action("melee", damage=10, range=1, surface_kind="poison", surface_pattern=FORWARD_3),
    ),
    "stone_plate": override(
        "Place Bramble at range 2, gain 5 stoneskin, then draw 1.",
        action("surface", kind="bramble", range=2, duration=18), action("stoneskin", amount=5), action("draw", amount=1),
    ),
    "quarry_step": override(
        "Move 2, strike for 7, lay Poison behind the target, then gain 3 stoneskin.",
        action("move", range=2), action("melee", damage=7, range=1, surface_kind="poison", surface_pattern=FORWARD_3), action("stoneskin", amount=3),
    ),
    "thorn_skewer": override(
        "Pierce an adjacent enemy for 9, then lay Poison behind the target.",
        action("melee", damage=9, range=1, pierce=True, surface_kind="poison", surface_pattern=FORWARD_3),
    ),
    "root_snare": override(
        "Deal 5 and immobilize at range 5, place Bramble behind the target, then create radius-1 Light there for 2 turns.",
        action("ranged", damage=5, range=5, immobilize=True, surface_kind="bramble", surface_pattern=[[1, 0]], illuminate_radius=1, illuminate_duration=2),
    ),
    "basalt_guard": override(
        "Create a 4-health illusion surrounded by Bramble, then gain 4 block and 3 stoneskin.",
        action("illusion", health=4, range=3, surface_kind="bramble", surface_pattern=ADJACENT, surface_rotate=False), action("block", amount=4), action("stoneskin", amount=3),
    ),
    "grave_mortar": override(
        "Strike every adjacent tile for 8, then cover the pattern in Poison.",
        action("aoe", damage=8, range=0, pattern=ADJACENT, rotate=False, surface_kind="poison", surface_mode="affected"),
    ),
    "spike_mantle": override(
        "Pierce every adjacent tile for 10, cover the pattern in Bramble, then gain 5 stoneskin.",
        action("aoe", damage=10, range=0, pattern=ADJACENT, rotate=False, pierce=True, surface_kind="bramble", surface_mode="affected"), action("stoneskin", amount=5),
    ),
    "tectonic_maul": override(
        "Move 1, strike for 14, then lay a three-tile Poison route behind the target.",
        action("move", range=1), action("melee", damage=14, range=1, surface_kind="poison", surface_pattern=FORWARD_3),
    ),
    "worldroot_stride": override(
        "Move 2, gain 4 stoneskin, then lash for 6 and immobilize at range 4, placing Bramble behind the target.",
        action("move", range=2), action("stoneskin", amount=4), action("ranged", damage=6, range=4, immobilize=True, surface_kind="bramble", surface_pattern=[[1, 0]]),
    ),
    "rooted_kick": override(
        "Lay Poison along the route, then move 2 and kick for 6, push 2, and sunder 3.",
        action("move", range=2), action("push", damage=6, range=1, amount=2, sunder=3, surface_kind="poison", surface_pattern=[[0, 0], [1, 0], [2, 0]], surface_timing="before"),
    ),

    # Neutral equipment cards that formerly carried elemental actor statuses.
    "grave_cleave": override(
        "Strike every adjacent tile for 10, then cover the pattern in Poison.",
        action("aoe", damage=10, range=0, pattern=ADJACENT, rotate=False, surface_kind="poison", surface_mode="affected"),
    ),
    "ember_tithe": override(
        "Exhaust. Deal 5 and Combust at range 4, then heal 1.",
        action("ranged", damage=5, range=4, combust=True), action("heal", amount=1),
    ),
    "thorn_crown_pact": override(
        "Lose 1 health. Gain 5 stoneskin, then pierce for 8 and bleed 1 at range 5, laying Poison behind the target.",
        action("stoneskin", amount=5), action("ranged", damage=8, range=5, pierce=True, bleed=1, surface_kind="poison", surface_pattern=FORWARD_3),
    ),
    "grave_dust_satchel": override(
        "Consume. Dust a cross within 4 for 8, expose 4, pierce, and cover the pattern in Poison.",
        action("aoe", damage=8, range=4, pattern=CROSS, rotate=False, expose=4, pierce=True, surface_kind="poison", surface_mode="affected"),
    ),
}


RETIRED_ACTION_FIELDS = {
    "burn",
    "poison",
    "freeze",
    "shock",
    "intensity_bonus",
    "spend_intensity",
    "requires_intensity",
}


def main() -> int:
    cards = json.loads(CARD_PATH.read_text(encoding="utf-8"))
    missing = sorted(set(CARD_OVERRIDES) - set(cards))
    if missing:
        raise SystemExit(f"Unknown card overrides: {', '.join(missing)}")
    for card_id, replacement in CARD_OVERRIDES.items():
        cards[card_id]["description"] = replacement["description"]
        cards[card_id]["actions"] = replacement["actions"]
    for card in cards.values():
        card.pop("intensity_cost", None)
    violations: list[str] = []
    for card_id, card in cards.items():
        for index, card_action in enumerate(card.get("actions", [])):
            if card_action.get("type") == "intensity":
                violations.append(f"{card_id}.actions[{index}].type=intensity")
            for field in RETIRED_ACTION_FIELDS & set(card_action):
                violations.append(f"{card_id}.actions[{index}].{field}")
    if violations:
        raise SystemExit("Retired card mechanics remain:\n" + "\n".join(violations))
    CARD_PATH.write_text(json.dumps(cards, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Migrated {len(CARD_OVERRIDES)} explicit card identities across {len(cards)} total cards.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
