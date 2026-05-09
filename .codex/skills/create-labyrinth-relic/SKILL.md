---
name: create-labyrinth-relic
description: Create, rebalance, review, or implement Labyrinth of Ash relics. Use when Codex needs to add or modify data/relics.json, tune relic room placement or offer rates, create relic icons in assets/art/relics, design reusable relic effect hooks, or update relic-related combat, run-map, UI, analytics, tests, and memento notes.
---

# Create Labyrinth Relic

## Core Workflow

1. Rebuild live repo context first. Read `AGENTS.md`, then run:
   ```bash
   memento brief data/relics.json scripts/game_data.gd scripts/run_engine.gd scripts/combat_engine.gd scripts/run_scene.gd tests/run_tests.gd assets/art/relics .codex/skills
   ```
2. Classify the request:
   - **Data-only relic**: usually touch `data/relics.json` and `assets/art/relics/<relic_id>.png`.
   - **Reusable effect hook**: touch `scripts/game_data.gd`, `scripts/combat_engine.gd`, and tests.
   - **Room frequency/offer tuning**: touch `scripts/run_engine.gd`, tests, and this skill if durable rules changed.
   - **Visual-only relic work**: use the `imagegen` skill and current relic icons as style references.
3. Design the relic as build glue. Prefer situational synergies and tactical rule-bending over plain stat bumps.
4. Implement relic data, effect hooks, offer behavior, UI color behavior, icons, and tests together when adding new relics.
5. Validate:
   ```bash
   jq empty data/relics.json
   godot --headless --path . --script tests/run_tests.gd
   ```

## Relic Data

- Relic ids are lowercase snake_case keys in `data/relics.json`.
- Required fields: `name`, `rarity`, `description`, `icon_path`, `accent`, and `effects`.
- Rarities and border colors:
  - `common`: grey `#8f9499`
  - `rare`: blue `#4b84d8`
  - `epic`: purple `#9b62d6`
  - `legendary`: orange `#d9862f`
- Offer weights live in `GameData.RELIC_RARITY_OFFER_WEIGHTS`. Stronger rarities should be less common in offers.
- Rarer relics should be more situational and offer higher peak power, not universally better baseline value.

## Effect Design

- Use reusable data-driven effect types, not per-relic id branches.
- It is okay for relic effects to bend combat rules, but encode that as a reusable hook such as:
  - `card_action_mod`
  - `card_append_action`
  - `damage_vs_status`
  - `first_status_card_play`
  - `status_draw_once_per_turn`
  - `blink_draw_once_per_turn`
  - `long_move_card_play`
  - `stoneskin_thorns`
  - `kill_status_heal`
  - `prevent_lethal_once`
  - start-combat bonuses such as `start_combat_block`, `start_combat_stoneskin`, or deck-count scaling hooks
- Card-modifying relic effects are applied through `GameData.card_def_for_progression` when combat state includes `relics`.
- Combat-trigger effects belong in `CombatEngine` helpers grouped by trigger timing, not scattered through card UI code.

## Room And Offer Rules

- Relic rooms are `treasure` rooms.
- Relic rooms must never be direct exits from the central starting room.
- Relic rooms should average roughly one quarter of non-boss rooms over seeds.
- Placement should remain probabilistic by seed, not fixed by depth or ring slot.
- Relic rooms must not be cardinally adjacent to another relic room.
- Weighted relic offers should draw without replacement from unowned relics.

## Icon Production

- Relic icons live in `assets/art/relics/<relic_id>.png`.
- Match the existing relic icon format: 96x96 PNG, RGBA, transparent background, centered object, compact dark-fantasy pixel-painted style, high contrast, no text, no border frame.
- Use the `imagegen` skill for final raster icons. Generate on a flat chroma-key background, remove the key locally, crop to alpha bounds, and fit inside a 96x96 transparent canvas.
- Keep generated source files under `$CODEX_HOME/generated_images`; copy processed project assets into `assets/art/relics`.
- Review a contact sheet when adding many relics so scale and silhouette drift are obvious.

## Tests

Add or update focused tests for:

- relic data schema, rarity accents, offer weights, and icon existence
- room density, no start-adjacent relic rooms, and no adjacent relic rooms
- reusable effect hook behavior for each new mechanic category
- max HP effects on claim, start-combat effects, and card-definition mutations when relevant

## Finish Notes

When finishing relic work, report:

- new or changed relic ids with rarity and role
- reusable effect hooks added or reused
- room/offer-rate changes
- icon paths and whether `imagegen` was used
- validation commands run
