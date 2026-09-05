---
name: create-labyrinth-equipment
description: Create, balance, illustrate, or review Escape the Umbra equipment and its cards.
---

# Create Labyrinth Equipment

## Core Workflow

1. Classify the request, then inspect only the relevant data, code, and reference sections:
   - **Equipment data/content**: usually touch `data/equipment.json`, one or more equipment-only cards in `data/cards.json`, card art, and tests.
   - **Drop/ownership rules**: touch `scripts/run_engine.gd`, `scripts/room_generator.gd`, `scripts/combat_engine.gd`, and tests.
   - **Inventory/equip UI**: touch `scripts/run_scene.gd`, possibly `scripts/combat_board_view.gd`, and visual probes/tests.
   - **Novel card mechanic**: also use `$create-labyrinth-card` and load its novel-mechanics reference before changing combat semantics.
2. Design equipment as deck-shaping gear. Each non-starter equipment item should have at least one signature equipment-only card that expresses the item, plus optional existing cards if needed for deck footprint and curve.
3. Run the card heuristic when equipment-card mechanics change. Score touched cards; use the full pool for comparisons or changed global assumptions, not art-only edits:
   ```bash
   python3 tools/card_heuristic.py --card-id <card_id> --show-breakdown
   python3 tools/card_heuristic.py
   ```
4. Implement data, visuals, UI/analytics hooks, and tests together. Equipment affects starting decks, card rewards, room drops, save migration, and character inventory, so isolated data-only changes are rare.
5. Validate changed data with JSON parsing and affected behavior with focused checks. Use risk-tier breadth for integration/full suites; these examples apply when data and shared runtime change:
   ```bash
   jq empty data/equipment.json data/cards.json
   python3 tools/godot_task_runner.py --task-id <task-id> --stream -- godot --headless --path . --script tests/run_tests.gd
   ```

## Equipment Data

- Equipment ids are lowercase snake_case keys in `data/equipment.json`.
- Required fields: `name`, `slot`, `rarity`, `icon_path`, `accent`, and `cards`.
- Valid slots are `weapon`, `offhand`, `armor`, `boots`, and `trinket`.
- Rarities and colors match relics:
  - `common`: grey `#8f9499`
  - `rare`: blue `#4b84d8`
  - `epic`: purple `#9b62d6`
  - `legendary`: orange `#d9862f`
- Starter gear should fill every slot and set `starter: true`. Keep starter equipment out of random drop pools.
- `cards` can be a list of card ids or dictionaries with `id`/`card_id` and `count`. Use a count dictionary only when duplicates are intentional.
- Equipment-provided cards should generally set `reward_pool: false` in `data/cards.json`; combat room rewards are for elemental reward cards, while equipment owns neutral starter/utility texture.

## Balance And Drop Rules

- Equipment changes deck composition, not just reward options. Check the compiled deck for:
  - total deck size
  - attack/defense/movement/draw mix
  - slot identity
  - how the item compares with the starter item it replaces
- Common gear should mostly produce healthy filler/core cards in the `2-3.5` heuristic band. Rare/epic/legendary gear may carry premium or swingy cards when the item is narrower, slower, exhausts, costs health, or occupies a scarce slot.
- Random equipment drops should:
  - appear only in eligible combat rooms
  - use rarity-weighted selection aligned with relic weights
  - never offer starter gear
  - never duplicate equipment already collected, equipped, or in inventory
  - remain deterministic by run seed and room coordinate

## Visual Production

- Equipment icons should use the relic icon format unless a task explicitly changes the UI surface: `96x96` PNG, RGBA, transparent background, centered object, compact dark-fantasy pixel-painted style, high contrast, no text, no border frame.
- Equipment card art follows `$create-labyrinth-card` rules: final card art lives under `assets/art/cards/<card_id>.png`, uses the transparent ragged art-window treatment, and needs fresh `CardWidget` visual proof for new or changed art.
- Use the `imagegen` skill for final equipment icons or card art. Every finished equipment identity needs a distinct purpose-built icon. Reuse is permitted only for a user-requested temporary prototype, never for finished handoff.

## UI And Analytics

- Gear can be changed only outside active combat. UI should visibly keep inventory and slot state intact when changes are blocked.
- Character UI should show equipped slots, inventory, active deck impact, and concise item/card tooltips. Avoid multi-sentence instructional text in the client UI.
- Preserve loaded-run migration: old saves with only `deck_cards` should rebuild starter equipment and migrate non-equipment cards into `reward_cards`.
- Analytics should remain local-first and append-only. Prefer additive fields/events such as equipped equipment, inventory, collected equipment, and equipment-equipped actions over renaming existing card/reward events.

## Tests

Select checks for affected behavior and the task risk tier. Do not add unrelated tests for art-only edits.

Add or update focused tests for:

- equipment schema, slot coverage, rarity accents, icon paths, and referenced card ids
- starter equipment compiling to the expected starting deck
- reward cards staying separate from equipment cards
- loaded-run migration from old deck-only saves
- equip swapping, combat lockout, and deck rebuilds
- room equipment pickup placement and pickup tooltips
- duplicate-drop exclusion
- character gear UI rendering and equip interaction

## Finish Notes

When finishing equipment work, report:

- new or changed equipment ids by slot and rarity
- signature card ids and heuristic scores
- drop/rate or starter-deck impacts
- icon/card art paths and whether `imagegen` was used
- UI/analytics/schema updates
- validation commands run
