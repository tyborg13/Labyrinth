#!/usr/bin/env python3
"""Migrate player-facing grimoire guidance to committed board combat."""

from __future__ import annotations

import json
from pathlib import Path


GRIMOIRE_PATH = Path("data/grimoire.json")


def entry(entry_id: str, section: str, title: str, icon: str, body: list[str], **extra: object) -> dict:
    result = {"id": entry_id, "section": section, "title": title, "icon": icon, "body": body}
    result.update(extra)
    return result


REPLACEMENTS = {
    "combat:board": entry(
        "combat:board", "combat", "Combat Board", "combat_board",
        [
            "Cards and enemy intents resolve against exact board coordinates. Previews show movement paths, attack patterns, forced movement, and tile effects before commitment.",
            "Attack variety comes from shape, reach, movement, and board setup. Selecting an anchor automatically orients a pattern; there is no separate direction choice.",
        ], default=True,
    ),
    "combat:turn_clock": entry(
        "combat:turn_clock", "combat", "Turn Clock", "turn_clock",
        [
            "Each played card adds its printed Time to the player's initiative delay. Fields and Surfaces expire when the absolute clock reaches their shown expiry.",
            "Enemies resolve their stored intent, take one harmless setup step when able, then visibly commit their next geometric intent.",
        ], aliases=["initiative", "turn order", "timeline"], default=True,
    ),
    "combat:card_plays": entry(
        "combat:card_plays", "combat", "Card Plays and Free Movement", "free_move",
        [
            "Each player turn begins with two card plays and one free Move 2. The free move costs neither a card play nor Time and cannot be split.",
            "Cards can add temporary plays for larger turns. There are no default attack or card-funded movement fallbacks: cards resolve only their printed actions.",
        ], aliases=["actions", "action points", "plays", "free move"], default=True,
    ),
    "combat:targeting": entry(
        "combat:targeting", "combat", "Committed Patterns", "targeting",
        [
            "Every enemy intent is stored as board geometry. Displacing an enemy translates that stored pattern; it never retargets the player after commitment.",
            "Paths and projectiles short-circuit on first contact. Terrain, enemies, and Illusions can intercept attacks, prevent later Corruption, or cause friendly fire.",
        ], default=True,
    ),
    "combat:traps": entry(
        "combat:traps", "combat", "Traps", "traps",
        [
            "Traps resolve when entered or struck and blast adjacent tiles for their shown fixed damage.",
            "Earth traps Immobilize and Lightning traps suppress attack segments for the current turn. Other elemental traps deal damage without adding actor statuses.",
        ], default=True,
    ),
    "combat:intensity": entry(
        "combat:fields", "combat", "Fields", "corruption",
        [
            "Each tile can hold one Field. Corruption damages the player on entry and turn start, but heals enemies at turn start.",
            "Radiance damages enemies on entry and turn start. Placing Radiance replaces Corruption and reveals that tile through the Umbra.",
        ], aliases=["corruption", "radiance", "tile field"], default=True,
    ),
    "combat:umbra": entry(
        "combat:umbra", "combat", "The Umbra", "umbra",
        [
            "The Umbra hides board tiles beyond current vision. Concealed enemies cannot be directly targeted, and their identities and committed previews remain hidden.",
            "Light, Vision, Truesight, Dispel Umbra, and Radiance reveal or protect board space. Radiance also clears Corruption from its tile.",
        ], aliases=["darkness", "fog of war", "shadow"],
    ),
    "keyword:move": entry(
        "keyword:move", "keywords", "Move", "move",
        [
            "Move walks through a single contiguous route. Occupancy, terrain, Fields, and Surfaces resolve on every entered tile.",
            "Each player turn also provides one free Move 2 that costs neither a card play nor Time.",
        ], default=True,
    ),
    "keyword:blink": entry(
        "keyword:blink", "keywords", "Blink", "blink",
        ["Blink teleports directly to a legal destination without traversing intermediate Fields, Surfaces, traps, or blockers."], default=True,
    ),
    "keyword:immobilize": entry(
        "keyword:immobilize", "keywords", "Immobilize", "immobilize",
        ["Immobilize prevents Move and Blink for the rest of the affected unit's current turn. Attack segments can still resolve."], default=True,
    ),
    "keyword:burn": entry(
        "keyword:corruption", "keywords", "Corruption", "corruption",
        [
            "Corruption is a Field. The player takes 1 damage when entering it and at turn start while standing on it.",
            "Enemies heal 1 at turn start while standing on Corruption. Enemy intent previews mark every tile they will corrupt.",
        ], default=True,
    ),
    "keyword:poison": entry(
        "keyword:surface_poison", "keywords", "Poison Surface", "surface_poison",
        ["Entering Poison arms it without damage. Every further tile moved in that continuous route deals 1 direct damage."], default=True,
    ),
    "keyword:freeze": entry(
        "keyword:surface_ice", "keywords", "Ice Surface", "surface_ice",
        ["Entering Ice locks the current direction and slides the unit until collision or the first open non-Ice tile. Collision deals damage to the moving unit."], default=True,
    ),
    "keyword:shock": entry(
        "keyword:surface_electrified", "keywords", "Electrified Surface", "surface_electrified",
        ["Entering or beginning a turn on Electrified suppresses attack segments for that turn, then consumes the Surface. Movement and non-attack actions still resolve."], default=True,
    ),
    "keyword:radiance": entry(
        "keyword:radiance", "keywords", "Radiance Field", "radiance",
        [
            "Radiance is a Field. Enemies take 1 damage when entering it and at turn start while standing on it.",
            "Radiance replaces Corruption and reveals its tile through the Umbra. It coexists with one Surface on the same tile.",
        ], default=True,
    ),
    "enemy:bile_bloomer": {
        "id": "enemy:bile_bloomer", "section": "creatures", "enemy_id": "bile_bloomer", "title": "Bile Bloomer",
        "body": ["Earth controller whose patterns leave Corruption and Expose targets.", "It can also heal itself, making board denial more urgent than passive waiting."],
    },
    "enemy:frostglass_lancer": {
        "id": "enemy:frostglass_lancer", "section": "creatures", "enemy_id": "frostglass_lancer", "title": "Frostglass Lancer",
        "body": ["Ice striker with long committed thrust lines and Immobilize.", "Its support intent can guard an ally, changing which geometric threat should be interrupted first."],
    },
    "enemy:lightning_wisp": {
        "id": "enemy:lightning_wisp", "section": "creatures", "enemy_id": "lightning_wisp", "title": "Lightning Wisp",
        "body": ["Summoned lightning minion with small committed ranged patterns.", "Wisps can protect themselves before committing another attack and Corruption footprint."],
    },
    "enemy:vyraketh": {
        "id": "enemy:vyraketh", "section": "creatures", "enemy_id": "vyraketh", "title": "Vyraketh, the Cinder Crown",
        "body": ["Fire dragon boss whose broad cross patterns damage and Corrupt the arena.", "Intercept or displace its committed geometry before safe space collapses."],
    },
}


INSERT_AFTER = {
    "combat:fields": [
        entry(
            "combat:surfaces", "combat", "Surfaces", "surface_bramble",
            [
                "Each tile can hold one Surface as well as one Field. A new Surface replaces the old Surface; duration is tied to the initiative clock.",
                "Bramble stops movement, Poison punishes continued movement, Ice slides, Snowdrift amplifies attacks, and Electrified suppresses attacks.",
            ], aliases=["bramble", "poison", "ice", "snowdrift", "electrified"], default=True,
        ),
        entry(
            "combat:elements", "combat", "Element Packages", "element_fire",
            [
                "Elements are card packages, not a combat currency. Earth controls with Bramble and Poison; Ice redirects with Ice and exposes with Snowdrift.",
                "Air pushes, pulls, Moves, and Blinks; Lightning creates Electrified and Chains through groups; Fire pays off setup with broad attacks and Combust.",
            ], aliases=["fire", "ice", "air", "lightning", "earth"], default=True,
        ),
    ],
    "keyword:illusion": [
        entry(
            "keyword:surface_bramble", "keywords", "Bramble Surface", "surface_bramble",
            ["Entering Bramble immediately ends the current movement route. It can pin enemies inside committed patterns or protect a lane."], default=True,
        ),
        entry(
            "keyword:surface_snowdrift", "keywords", "Snowdrift Surface", "surface_snowdrift",
            ["Attacks against a character standing on Snowdrift deal 2 additional damage. Environmental Field and traversal damage are unchanged."], default=True,
        ),
        entry(
            "keyword:combust", "keywords", "Combust", "combust",
            ["Combust consumes every Surface inside its attack footprint and adds damage for each Surface consumed. It does not create a Fire Surface."], default=True,
        ),
    ],
}


REMOVE_IDS = {"combat:cinder_marks"}

# Accept both pre-overhaul and already-migrated ids so the migration remains
# deterministic while its copy is iterated during development.
REPLACEMENTS.update({
    "combat:fields": REPLACEMENTS["combat:intensity"],
    "keyword:corruption": REPLACEMENTS["keyword:burn"],
    "keyword:poison_surface": REPLACEMENTS["keyword:poison"],
    "keyword:surface_poison": REPLACEMENTS["keyword:poison"],
    "keyword:ice_surface": REPLACEMENTS["keyword:freeze"],
    "keyword:surface_ice": REPLACEMENTS["keyword:freeze"],
    "keyword:electrified_surface": REPLACEMENTS["keyword:shock"],
    "keyword:surface_electrified": REPLACEMENTS["keyword:shock"],
})


def main() -> int:
    data = json.loads(GRIMOIRE_PATH.read_text(encoding="utf-8"))
    existing_ids = {raw["id"] for raw in data["entries"]}
    migrated: list[dict] = []
    seen_ids: set[str] = set()
    for raw in data["entries"]:
        original_id = raw["id"]
        if original_id in REMOVE_IDS:
            continue
        current = REPLACEMENTS.get(original_id, raw)
        # Normalize early generated names to the exact icon-identity ids.
        if current["id"] == "keyword:bramble_surface":
            current = INSERT_AFTER["keyword:illusion"][0]
        elif current["id"] == "keyword:snowdrift_surface":
            current = INSERT_AFTER["keyword:illusion"][1]
        if current["id"] in seen_ids:
            continue
        migrated.append(current)
        seen_ids.add(current["id"])
        for inserted in INSERT_AFTER.get(current["id"], []):
            if inserted["id"] not in existing_ids and inserted["id"] not in seen_ids:
                migrated.append(inserted)
                seen_ids.add(inserted["id"])
    data["entries"] = migrated
    GRIMOIRE_PATH.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Migrated {len(migrated)} grimoire entries.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
