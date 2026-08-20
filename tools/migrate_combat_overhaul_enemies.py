#!/usr/bin/env python3
"""Author Corruption footprints and remove retired enemy combat mechanics.

Enemy variety remains in committed geometry, damage, forced movement, and
support actions. Corruption is the only persistent enemy-authored tile rule.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
ENEMY_PATH = ROOT / "data/enemies.json"

CROSS = [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]]

RETIRED_FIELDS = {"burn", "poison", "freeze", "shock", "intensity_bonus", "spend_intensity"}


def find_intent(enemy: dict[str, Any], intent_id: str) -> dict[str, Any]:
    for intent in enemy.get("intents", []):
        if intent.get("id") == intent_id:
            return intent
    raise KeyError(intent_id)


def corrupt(action: dict[str, Any], mode: str, duration: int = 18) -> None:
    action["field_kind"] = "corruption"
    action["field_mode"] = mode
    action["field_duration"] = duration


def action(enemy: dict[str, Any], intent_id: str, index: int) -> dict[str, Any]:
    return find_intent(enemy, intent_id)["actions"][index]


def replace_action(enemy: dict[str, Any], intent_id: str, index: int, replacement: dict[str, Any]) -> None:
    find_intent(enemy, intent_id)["actions"][index] = replacement


def migrate(enemies: dict[str, Any]) -> None:
    # Early enemies establish three readable sequences: corruption at impact,
    # corruption along a charge, and corruption across an AOE footprint.
    corrupt(action(enemies["crawler"], "skitter_strike", 1), "target")
    corrupt(action(enemies["crawler"], "lunge", 0), "route")

    corrupt(action(enemies["acolyte"], "dust_bolt", 1), "target")

    corrupt(action(enemies["harrier"], "pelt", 0), "target")
    corrupt(action(enemies["harrier"], "rush", 0), "route")

    corrupt(action(enemies["warden"], "marching_blow", 0), "route")
    corrupt(action(enemies["warden"], "crushing_step", 1), "affected")

    # Cinder Ooze alternates pressure with self-sustain; no private fire meter.
    corrupt(action(enemies["cinder_ooze"], "smolder_slide", 1), "target")
    corrupt(action(enemies["cinder_ooze"], "cinder_bloom", 0), "affected")
    replace_action(enemies["cinder_ooze"], "slag_shell", 1, {"type": "heal_self", "amount": 2})

    corrupt(action(enemies["cinder_droplet"], "spatter", 1), "target", 12)

    # Bile Bloomer's wide burst and precise mark share Corruption, while its
    # defensive turn heals instead of feeding an intensity gate.
    corrupt(action(enemies["bile_bloomer"], "bile_burst", 1), "affected")
    corrupt(action(enemies["bile_bloomer"], "spore_mark", 1), "target")
    replace_action(enemies["bile_bloomer"], "pustule_shell", 1, {"type": "heal_self", "amount": 2})

    corrupt(action(enemies["chainbound_gaoler"], "chain_reel", 0), "target")
    corrupt(action(enemies["chainbound_gaoler"], "manacle_pin", 0), "target")
    replace_action(
        enemies["chainbound_gaoler"],
        "iron_guard",
        2,
        {"type": "guard_ally", "amount": 3, "range": 4},
    )

    corrupt(action(enemies["grave_surgeon"], "saw_jab", 1), "target")

    corrupt(action(enemies["frostglass_lancer"], "glass_lunge", 1), "affected")
    corrupt(action(enemies["frostglass_lancer"], "spear_cast", 0), "target")
    replace_action(
        enemies["frostglass_lancer"],
        "refract_guard",
        2,
        {"type": "guard_ally", "amount": 3, "range": 4},
    )
    frost_pin = action(enemies["frostglass_lancer"], "frost_pin", 0)
    frost_pin["immobilize"] = True
    corrupt(frost_pin, "target")

    # Bosses retain their authored geometry, objects, force, summons, and Umbra
    # identities. Their persistent board pressure still speaks one Field rule.
    corrupt(action(enemies["tharokh"], "worldspine_claw", 0), "route", 20)
    corrupt(action(enemies["tharokh"], "faultline", 0), "affected", 20)

    kindle = find_intent(enemies["vyraketh"], "kindle_ground")
    kindle["actions"] = [
        {
            "type": "aoe",
            "damage": 0,
            "range": 4,
            "pattern": CROSS,
            "rotate": False,
            "field_kind": "corruption",
            "field_mode": "affected",
            "field_duration": 20,
        }
    ]
    crownfire = find_intent(enemies["vyraketh"], "crownfire")
    crownfire["weight"] = 2
    crownfire["actions"] = [
        {
            "type": "aoe",
            "damage": 12,
            "range": 4,
            "pattern": CROSS,
            "rotate": False,
            "field_kind": "corruption",
            "field_mode": "affected",
            "field_duration": 20,
        }
    ]
    corrupt(action(enemies["vyraketh"], "cinder_maw", 0), "route", 20)
    corrupt(action(enemies["vyraketh"], "cinderfall", 0), "affected", 20)

    corrupt(action(enemies["vaeloryx"], "skyhook", 0), "target", 20)
    corrupt(action(enemies["vaeloryx"], "razor_dive", 0), "route", 20)

    corrupt(action(enemies["iskaldra"], "rime_talon", 0), "route", 20)
    corrupt(action(enemies["iskaldra"], "whiteout_lance", 0), "target", 20)
    corrupt(action(enemies["iskaldra"], "shatterstorm", 0), "affected", 20)

    corrupt(action(enemies["noctyrax"], "void_claw", 0), "route", 20)
    corrupt(action(enemies["noctyrax"], "starless_breath", 0), "target", 20)
    corrupt(action(enemies["noctyrax"], "night_coil", 0), "affected", 20)

    corrupt(action(enemies["zekarion"], "storm_claw", 0), "route", 20)
    corrupt(action(enemies["zekarion"], "tempest_breath", 1), "target", 20)
    corrupt(action(enemies["zekarion"], "skybreak", 0), "affected", 20)

    corrupt(action(enemies["veilbound_acolyte"], "veil_needle", 0), "target", 12)
    corrupt(action(enemies["veilbound_acolyte"], "closing_shade", 0), "route", 12)

    corrupt(action(enemies["lightning_wisp"], "spark_dart", 1), "target", 12)
    static_lash = action(enemies["lightning_wisp"], "static_lash", 1)
    corrupt(static_lash, "target", 12)
    replace_action(enemies["lightning_wisp"], "static_lash", 2, {"type": "block", "amount": 2})
    capacitor_arc = action(enemies["lightning_wisp"], "blinding_arc", 1)
    corrupt(capacitor_arc, "target", 12)

    for enemy in enemies.values():
        enemy["design_version"] = 3
        retained_immunities = [
            immunity
            for immunity in enemy.get("status_immunities", [])
            if immunity == "immobilize"
        ]
        if retained_immunities:
            enemy["status_immunities"] = retained_immunities
        else:
            enemy.pop("status_immunities", None)
        for intent in enemy.get("intents", []):
            for enemy_action in intent.get("actions", []):
                for field in RETIRED_FIELDS:
                    enemy_action.pop(field, None)
                if enemy_action.get("type") == "intensity":
                    raise ValueError(f"Retired intensity action remains in {enemy.get('name')}: {intent.get('id')}")


def main() -> int:
    enemies = json.loads(ENEMY_PATH.read_text(encoding="utf-8"))
    migrate(enemies)
    ENEMY_PATH.write_text(json.dumps(enemies, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Migrated all {len(enemies)} enemy identities to committed Corruption footprints.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
