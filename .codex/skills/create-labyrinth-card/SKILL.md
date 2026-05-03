---
name: create-labyrinth-card
description: Create, implement, rebalance, or review cards for Labyrinth of Ash. Use when Codex needs to add or modify entries in data/cards.json, generate or size card art in assets/art/cards, choose rarity or element visuals, arrange action icons, use the card balance heuristic, add a novel card keyword or action type, or update related combat, reward, analytics, upgrade, and test integration points.
---

# Create Labyrinth Card

## Core Workflow

1. Rebuild live repo context first. Read `AGENTS.md`, then run:
   ```bash
   memento brief data/cards.json spec/card_balance_heuristic.md tools/card_heuristic.py scripts/game_data.gd scripts/combat_engine.gd scripts/action_icon_library.gd scripts/card_widget.gd scripts/run_scene.gd assets/art/cards assets/art/icons assets/art/ui
   ```
2. Classify the request:
   - **Existing-mechanic card**: usually touch `data/cards.json` and `assets/art/cards/<card_id>.png`.
   - **Visual-only card work**: load [Visual Production](references/visual-production.md).
   - **Balance-only card work**: load [Mechanics And Balance](references/mechanics-and-balance.md).
   - **Novel keyword or action type**: load [Novel Mechanics](references/novel-mechanics.md) before editing.
3. Design mechanics against the current pool, then run the heuristic before and after edits:
   ```bash
   python3 tools/card_heuristic.py --card-id <card_id> --show-breakdown
   python3 tools/card_heuristic.py
   ```
4. Implement the card data and art together when the card is new. Use the same snake_case stem for the card id and art file.
5. Validate the integration. At minimum run JSON parsing, the touched-card heuristic, and the full heuristic. Run Godot tests for any code or novel-mechanic change:
   ```bash
   jq empty data/cards.json
   godot --headless --path . --script tests/run_tests.gd
   ```

## Data Rules

- Card ids are lowercase snake_case keys in `data/cards.json`.
- New playable cards need `name`, `rarity`, `burn`, `health_cost`, `description`, `accent`, `art_path`, and `actions`.
- Neutral cards normally omit `element`; elemental cards use `fire`, `ice`, `lightning`, `air`, or `earth` and should keep `accent` aligned with `scripts/element_data.gd`.
- `rarity` is `common`, `uncommon`, or `rare` for rewards. Use `starter` only when also updating the starting deck intentionally.
- Top-level `burn: true` means **Exhaust this card for the rest of combat**. It is rendered as the Exhaust cost icon. Do not confuse it with action-level `burn`, which is the fire status.
- `description` is still useful fallback text, but the card UI primarily renders icon rows from `ActionIconLibrary.rows_for_card`.

## References

- Load [Mechanics And Balance](references/mechanics-and-balance.md) for card schema, current action fields, elemental identity, rarity/curve expectations, and heuristic interpretation.
- Load [Visual Production](references/visual-production.md) for card art generation, background removal, resizing, element frame behavior, rarity frames, names, and icon-row layout.
- Load [Novel Mechanics](references/novel-mechanics.md) before adding a new keyword, status, action type, targeting mode, card cost, reward behavior, or analytics-relevant card rule.

## Review Notes

When finishing card work, explicitly report:

- The card id, rarity, element, and intended role.
- The heuristic score and closest comparisons.
- Any deliberate curve deviation.
- The generated or edited art path.
- Tests and heuristic commands run.
- Any analytics, heuristic, or spec updates required by changed mechanics.
