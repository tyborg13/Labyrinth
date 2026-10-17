#!/usr/bin/env python3
"""Report opening-boon card power with the unchanged production heuristic.

Scores are intrinsic health-saved-equivalent per card, not a forecast of total
run value. The expected best of k is an exact order statistic for distinct
uniform draws, with no simulation seed or sample-count tuning.
"""
from __future__ import annotations

import json
import math
from pathlib import Path
from statistics import mean

from card_heuristic import HeuristicWeights, score_card

ROOT = Path(__file__).resolve().parents[1]
ELEMENTS = ("fire", "ice", "lightning", "air", "earth")


def expected_best(values: list[float], count: int) -> float:
    ordered = sorted(values)
    denominator = math.comb(len(ordered), count)
    return sum(value * math.comb(index, count - 1) / denominator
               for index, value in enumerate(ordered) if index >= count - 1)


def report() -> dict:
    cards = json.loads((ROOT / "data/cards.json").read_text())
    gear = json.loads((ROOT / "data/equipment.json").read_text())
    boons = json.loads((ROOT / "data/opening_boons.json").read_text())["boons"]
    gear_cards = {card for item in gear.values() for card in item["cards"]}
    weights = HeuristicWeights()
    scores = {key: score_card(key, card, weights).total for key, card in cards.items()}
    spells = {key: card for key, card in cards.items()
              if card.get("reward_pool", True) and not card.get("retired", False)
              and not card.get("starter", False) and not card.get("item", False)
              and key not in gear_cards}
    rare = [scores[key] for key, card in spells.items() if card["rarity"] == "rare"]
    starter_ids = ["pale_spark", "dull_bolt", "waning_pulse"]
    starter = {key: scores[key] for key in starter_ids}
    starters_total = 2 * sum(starter.values())
    elements = {}
    for element in ELEMENTS:
        rare_element = [scores[key] for key, card in spells.items()
                        if card["rarity"] == "rare" and card.get("element") == element]
        common_element = [scores[key] for key, card in spells.items()
                          if card["rarity"] == "common" and card.get("element") == element]
        elements[element] = {
            "rare_pool_size": len(rare_element),
            "elemental_gift_uniform_pick": mean(rare_element),
            "elemental_gift_best_of_three": expected_best(rare_element, boons["elemental_gift"]["count"]),
            "focus_four_cards": boons["focus"]["count"] * mean(common_element),
            "focus_deck_score_delta": boons["focus"]["count"] * mean(common_element) - starters_total,
        }
    starter_gear = {item["slot"]: key for key, item in gear.items() if item.get("starter", False)}
    gear_deltas = {}
    for key, item in gear.items():
        starter_item = gear[starter_gear[item["slot"]]]
        gear_deltas[key] = sum(scores[card] for card in item["cards"]) - sum(scores[card] for card in starter_item["cards"])
    armory_slots = {
        slot: {key: gear_deltas[key] for key, item in gear.items()
               if item["slot"] == slot and item.get("rarity") == boons["armory"]["rarity"]
               and not item.get("starter", False)}
        for slot in starter_gear
    }
    armory_slots = {slot: pool for slot, pool in armory_slots.items() if pool}
    return {
        "units": "intrinsic health-saved-equivalent per card; deck totals are one-pass sums, not run power",
        "starter_spell_scores": starter,
        "six_starter_spells_total": starters_total,
        "elemental_gift": {
            "uniform_pick": mean(row["elemental_gift_uniform_pick"] for row in elements.values()),
            "best_of_three": mean(row["elemental_gift_best_of_three"] for row in elements.values()),
        },
        "armory": {
            "rarity": boons["armory"]["rarity"],
            "eligible_items": sum(len(pool) for pool in armory_slots.values()),
            "expected_card_score_delta": mean(mean(pool.values()) for pool in armory_slots.values()),
            "card_score_delta_by_slot": {slot: mean(pool.values()) for slot, pool in armory_slots.items()},
            "card_score_delta_by_item": {key: delta for pool in armory_slots.values() for key, delta in pool.items()},
            "sampling": "uniform eligible slot, then uniform rare piece in that slot; starter cards removed",
            "stat_bonuses": "equipment stats are not scored by the per-card heuristic",
        },
        "heirloom": {"card_score_delta_by_item": gear_deltas},
        "purge": {"two_lowest_starter_card_scores_removed": 2 * min(starter.values()), "deck_thinning_value": "not modelled by intrinsic card scores"},
        "focus": {"four_cards": mean(row["focus_four_cards"] for row in elements.values()), "deck_score_delta": mean(row["focus_deck_score_delta"] for row in elements.values())},
        "vitality": {"max_hp_capacity": boons["vitality"]["max_hp"], "immediate_heal": boons["vitality"]["current_hp"]},
        "trinket": {"rarity": "common", "power": "relic-specific; the per-card scorer does not value persistent relics"},
        "blood_price": {"uniform_pick": mean(rare), "best_of_five": expected_best(rare, boons["blood_price"]["count"]), "max_hp_cost": -boons["blood_price"]["max_hp"], "best_card_minus_max_hp_budget": expected_best(rare, boons["blood_price"]["count"]) + boons["blood_price"]["max_hp"]},
        "pawned_light": {"rarity": "rare", "current_hp": "ceil(max_hp / 2) after normal relic pickup", "power": "relic-specific; lost current HP is the explicit health cost"},
        "debt": {"embers": boons["debt"]["embers"], "first_room_prices": "ceil(normal_price * 1.5)", "power": "the per-card scorer has no Ember-to-health conversion"},
        "elements": elements,
    }


if __name__ == "__main__":
    print(json.dumps(report(), indent=2, sort_keys=True))
