#!/usr/bin/env python3
"""Apply the card pool overhaul to data/cards.json and data/equipment.json up to a wave.

    python3 spec/card_pool_overhaul/apply_pool.py --wave 1 [--check]

Idempotent. A card definition is written when its `_wave` <= --wave. A new gear piece is
added (and an existing piece's card list changed) when every card it needs is enabled.
Cut cards are removed at wave 1. `--check` reports what would change without writing.
"""
import argparse
import collections
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))

import card_defs  # noqa: E402
import pool_data  # noqa: E402

CUTS = ["ember_jab", "cinderburst", "gate_gambit"]
# Existing-card keys that a definition does not restate but should keep.
CARRY_KEYS = ("starter", "reward_pool", "icon_path", "replacement_id", "retired", "role_emblem")
RARITY_ACCENT = card_defs.RARITY_ACCENT


def card_order_key(cid, cards):
    return list(cards).index(cid) if cid in cards else len(cards)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--wave", type=int, required=True)
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    cards_path = ROOT / "data/cards.json"
    equip_path = ROOT / "data/equipment.json"
    cards = json.loads(cards_path.read_text())
    equipment = json.loads(equip_path.read_text())
    changes = collections.Counter()

    enabled = {cid for cid, d in card_defs.DEFS.items() if d["_wave"] <= args.wave}
    status = {c["id"]: c["status"] for c in pool_data.CARDS}

    # Cards: rewrite enabled definitions, keeping unrelated existing metadata.
    for cid in sorted(enabled):
        entry = {k: v for k, v in card_defs.DEFS[cid].items() if k != "_wave"}
        old = cards.get(cid)
        if old is not None:
            for key in CARRY_KEYS:
                if key in old and key not in entry:
                    # A definition that deliberately drops a role emblem sets role_emblem=None.
                    entry[key] = old[key]
            if old.get("element") == entry.get("element") and "accent" in old:
                entry["accent"] = old["accent"]
            entry = {k: v for k, v in entry.items() if v is not None}
            if old != entry:
                changes["changed" if status.get(cid) != "new" else "rewritten"] += 1
        else:
            changes["added"] += 1
        cards[cid] = entry

    for cid in CUTS:
        entry = card_defs.RETIRED[cid]
        if cards.get(cid) != entry:
            cards[cid] = entry
            changes["retired"] += 1

    # Gear pieces.
    by_card_owner = {}
    for p in pool_data.PIECES:
        for cid in p["cards"]:
            by_card_owner[cid] = p["id"]
    for p in pool_data.PIECES:
        pid = p["id"]
        needed = [cid for cid in p["cards"] if cid in card_defs.DEFS or cid in cards]
        ready = all((cid not in card_defs.DEFS) or (cid in enabled) for cid in p["cards"])
        if not ready:
            continue
        if pid in equipment:
            if equipment[pid]["cards"] != p["cards"]:
                equipment[pid]["cards"] = list(p["cards"])
                changes["piece_cards_changed"] += 1
        else:
            equipment[pid] = {
                "name": p["name"],
                "slot": p["slot"],
                "rarity": p["rarity"],
                "icon_path": f"res://assets/art/equipment/{pid}.png",
                "accent": RARITY_ACCENT[p["rarity"]],
                "cards": list(p["cards"]),
            }
            changes["piece_added"] += 1
        for cid in needed:
            if cid in cards and not cards[cid].get("item"):
                if cards[cid].get("reward_pool", True) and not cards[cid].get("starter"):
                    cards[cid]["reward_pool"] = False

    # Report dangling references.
    missing = sorted({cid for e in equipment.values() for cid in (c if isinstance(c, str) else c.get("id", c.get("card_id")) for c in e["cards"]) if cid not in cards})
    live = [c for c, v in cards.items() if not v.get("retired")]
    print(json.dumps({"wave": args.wave, "changes": dict(changes), "live_cards": len(live),
                      "equipment": len(equipment), "missing_equipment_cards": missing}, indent=1))
    if missing:
        print("ERROR: equipment references missing cards", file=sys.stderr)
        return 1
    if not args.check:
        cards_path.write_text(json.dumps(cards, indent=2, ensure_ascii=False) + "\n")
        equip_path.write_text(json.dumps(equipment, indent=2, ensure_ascii=False) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
