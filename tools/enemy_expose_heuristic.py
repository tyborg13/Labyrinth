#!/usr/bin/env python3
"""Report the authored intent packages with the existing card heuristic.

These are relative health-equivalent package scores, not encounter difficulty.
Only Expose is removed for the prior inert-hero-status comparison; all other
printed actions, weights and Time costs are retained. No gameplay data is changed.
"""
from __future__ import annotations
import copy
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.card_heuristic import HeuristicWeights, score_card

AFFECTED_ENEMY_IDS = ("bile_bloomer", "noctyrax")


def scores() -> list[dict]:
    enemies = json.loads((ROOT / "data/enemies.json").read_text())
    rows = []
    for enemy_id in AFFECTED_ENEMY_IDS:
        enemy = enemies[enemy_id]
        totals = {"before": 0.0, "after": 0.0}
        weight_total = sum(intent.get("weight", 1) for intent in enemy["intents"])
        packages = []
        for intent in enemy["intents"]:
            package = {"actions": intent["actions"], "time": intent["time"],
                       "element": enemy.get("element", "none")}
            previous = copy.deepcopy(package)
            for action in previous["actions"]:
                action.pop("expose", None)
            before = score_card(intent["id"], previous, HeuristicWeights()).total
            after = score_card(intent["id"], package, HeuristicWeights()).total
            for kind, value in (("before", before), ("after", after)):
                totals[kind] += value * intent.get("weight", 1) / weight_total
            packages.append({"intent_id": intent["id"], "before": before, "after": after})
        rows.append({"enemy_id": enemy_id, **totals, "intents": packages})
    return rows


if __name__ == "__main__":
    print(json.dumps(scores(), indent=2))
