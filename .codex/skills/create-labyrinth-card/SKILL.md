---
name: create-labyrinth-card
description: Create, balance, illustrate, or review Escape the Umbra cards and their mechanics.
---

# Create Labyrinth Card

## Core Workflow

1. Classify the request, then inspect only the relevant data, code, and reference sections:
   - **Existing-mechanic card**: usually touch `data/cards.json` and `assets/art/cards/<card_id>.png`.
   - **Visual-only card work**: load [Visual Production](references/visual-production.md).
   - **Balance-only card work**: load [Mechanics And Balance](references/mechanics-and-balance.md).
   - **Novel keyword or action type**: load [Novel Mechanics](references/novel-mechanics.md) before editing.
2. For new or changed mechanics, compare against the current pool and run the touched-card heuristic before and after edits. Run the full heuristic when comparing the pool or changing shared assumptions; skip scoring for art-only work:
   ```bash
   python3 tools/card_heuristic.py --card-id <card_id> --show-breakdown
   python3 tools/card_heuristic.py
   ```
3. Implement the card data and art together when the card is new. Use the same snake_case stem for the card id and art file.
4. For card art, action icons, or other raster visual assets, use the `imagegen` skill and current Labyrinth visual references. Do not substitute hand-drawn, code-drawn, SVG, canvas, PIL, or placeholder graphics for final card art or icons unless the user explicitly asks for a placeholder. For card art, also preserve the existing transparent ragged art-window treatment; a full-bleed opaque 16:9 rectangle is not acceptable even when the file is `256 x 144`.
5. Validate changed data with JSON parsing and changed rules with focused behavioral tests. Select integration/full-suite breadth from the task risk tier. For example, when data and shared runtime change:
   ```bash
   jq empty data/cards.json
   python3 tools/godot_task_runner.py --task-id <task-id> --stream -- godot --headless --path . --script tests/run_tests.gd
   ```
6. Always create a `CardWidget` preview image for new or visually changed cards, including card art, icon, name, frame, rarity, or summary-row changes. Render the widget at an actual game card size: use the scene default `250 x 352` for standalone proof sheets, or the relevant live size from `RunScene._hand_card_size`, pile, reward, or upgrade surfaces when validating a specific UI context. Do not enlarge the `CardWidget` to make a prettier proof; if a larger preview is needed, render at the true card size first and scale the final bitmap uniformly.
7. For new or visually changed card art, also verify the character-menu badge read. The Gear/Magic deck badges and Magic loadout tiles automatically use the card's `art_path` as a cropped horizontal background with a dark wash; do not create separate badge assets. Confirm the card still has a recognizable central cue and readable name in at least the compact deck badge or a full badge contact sheet.
8. When showing visual proof screenshots, always save them with a fresh timestamped or versioned filename. Do not overwrite and relink a previously shown screenshot path, because Codex image previews may cache stale bitmap content.

## Data Rules

- Card ids are lowercase snake_case keys in `data/cards.json`.
- New playable cards need `name`, `rarity`, `time`, `burn`, `health_cost`, `description`, `accent`, `art_path`, and `actions`.
- Neutral cards normally omit `element`; elemental cards use `fire`, `ice`, `lightning`, `air`, or `earth` and should keep `accent` aligned with `scripts/element_data.gd`.
- `rarity` uses the shared loot tiers: `common`, `rare`, `epic`, or `legendary`. Starting-deck cards use `starter: true` plus a normal rarity, usually `common`; do not use `starter` as a rarity value.
- `time` is the card's initiative cost on a `1-10` scale. Use `5` as the normal baseline, lower values for fast/simple/low-impact cards, and higher values for heavy, high-impact, broad, or setup-payoff cards.
- Top-level `burn: true` means **Exhaust this card for the rest of combat**. It is rendered as the Exhaust cost icon. Do not confuse it with action-level `burn`, which is the fire status.
- `description` is still useful fallback text, but the card UI primarily renders icon rows from `ActionIconLibrary.rows_for_card`.

## References

- Load [Mechanics And Balance](references/mechanics-and-balance.md) for card schema, current action fields, elemental identity, rarity/curve expectations, and heuristic interpretation.
- Load [Visual Production](references/visual-production.md) for card art generation, background removal, resizing, element frame behavior, rarity frames, names, and icon-row layout.
- Load [Novel Mechanics](references/novel-mechanics.md) before adding a new keyword, status, action type, targeting mode, card cost, reward behavior, or analytics-relevant card rule.

## Review Notes

Report the following where affected by the task; art-only edits do not need a new balance rationale:

- The card id, rarity, element, and intended role.
- The chosen `time` cost and why it fits the card's power and pacing role.
- The heuristic score and closest comparisons.
- Any deliberate curve deviation.
- The generated or edited art path.
- The fresh `CardWidget` preview image path and the card size/context used to render it.
- The fresh character-menu badge preview path when card art was added or changed.
- Tests and heuristic commands run.
- Any analytics, heuristic, or spec updates required by changed mechanics.
