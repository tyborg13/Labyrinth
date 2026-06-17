from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from render_buildaround_gallery import CARDS, ELEMENTS


ROOT = Path(__file__).resolve().parent
ART_ROOT = "res://output/buildaround_cards_100/assets/art/cards"


def game_ready_card(card: dict[str, Any]) -> dict[str, Any]:
    rule_action: dict[str, Any] = {
        "type": "text_rule",
        "effect_id": card["id"],
        "text": card["description"],
        "kind": card["kind"].lower(),
        "hooks": card["hooks"],
        "iconography": card["iconography"],
    }
    out: dict[str, Any] = {
        "name": card["name"],
        "rarity": card["rarity"],
        "time": card["time"],
        "burn": bool(card["burn"]),
        "health_cost": int(card["health_cost"]),
        "description": card["description"],
        "accent": card["accent"],
        "art_path": f"{ART_ROOT}/{card['id']}.png",
        "actions": [rule_action],
        "presentation": {
            "mode": "text_rule",
            "rule_text": card["description"],
            "iconography": card["iconography"],
        },
    }
    if card["element"] != "neutral":
        out["element"] = card["element"]
    return out


def design_card(card: dict[str, Any], number: int) -> dict[str, Any]:
    return {
        "number": number,
        "id": card["id"],
        "name": card["name"],
        "element": None if card["element"] == "neutral" else card["element"],
        "element_label": ELEMENTS[card["element"]]["label"],
        "rarity": card["rarity"],
        "time": card["time"],
        "burn": bool(card["burn"]),
        "health_cost": int(card["health_cost"]),
        "description": card["description"],
        "iconography": card["iconography"],
        "hooks": card["hooks"],
        "kind": card["kind"],
        "art_direction": card["art_direction"],
        "proposed_data": game_ready_card(card),
        "implementation_note": "Text-rule build-around. Card data/art can be staged now; combat rule and any non-card presentation need implementation before merging.",
    }


def main() -> None:
    proposed = {card["id"]: game_ready_card(card) for card in CARDS}
    designs = [design_card(card, index + 1) for index, card in enumerate(CARDS)]
    (ROOT / "proposed_cards_game_ready.json").write_text(json.dumps(proposed, indent=2) + "\n", encoding="utf-8")
    (ROOT / "buildaround_cards_100_design.json").write_text(json.dumps(designs, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {len(proposed)} proposed cards")


if __name__ == "__main__":
    main()
