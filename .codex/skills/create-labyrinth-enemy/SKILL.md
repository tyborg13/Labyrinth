---
name: create-labyrinth-enemy
description: Create, rebalance, review, or implement Labyrinth of Ash enemies. Use when Codex needs to add or modify data/enemies.json, enemy intents, enemy sprites or idle sheets, encounter spawn pools, enemy mechanics, combat previews, balance assumptions, tests, visual probes, or enemy-related analytics.
---

# Create Labyrinth Enemy

## Core Workflow

1. Rebuild live repo context first. Read `AGENTS.md`, then run:
   ```bash
   memento brief data/enemies.json scripts/game_data.gd scripts/room_generator.gd scripts/combat_engine.gd scripts/combat_board_view.gd scripts/run_scene.gd tests/run_tests.gd tests/ui_probe.gd spec/card_balance_heuristic.md tools/card_heuristic.py assets/placeholders/units assets/art
   ```
2. Classify the request:
   - **Data-only enemy using existing verbs**: usually touch `data/enemies.json`, `scripts/room_generator.gd`, tests, and enemy art.
   - **New enemy mechanic**: touch `scripts/combat_engine.gd`, `scripts/combat_board_view.gd` or `scripts/run_scene.gd` if previews/presentation change, `tests/run_tests.gd`, and balance docs/tooling if enemy assumptions change.
   - **Spawn-pool tuning**: touch `scripts/room_generator.gd`, `spec/card_balance_heuristic.md`, `tools/card_heuristic.py`, and tests.
   - **Visual-only enemy work**: use the `imagegen` skill and current unit sprites as style references.
3. Define the enemy's tactical job before editing: pressure pattern, counterplay, depth band, visual silhouette, and why this enemy earns a roster slot beside crawler, acolyte, harrier, warden, lightning wisp, and Zekarion.
4. Implement data, mechanics, spawn integration, visuals, previews, and tests together. A new normal enemy that never appears in encounter pools is unfinished unless the task explicitly asks for a staged prototype.
5. Validate:
   ```bash
   jq empty data/enemies.json
   godot --headless --path . --script tests/run_tests.gd
   ```
   In parallel task worktrees, run Godot through `tools/godot_task_runner.py`, and run visual probes through `tools/visual_probe_runner.py`.

## Enemy Data

- Enemy ids are lowercase snake_case keys in `data/enemies.json`.
- Required fields: `name`, `max_hp`, `base_initiative`, `reward_embers`, `accent`, `art_path`, and `intents`.
- Optional presentation fields: `art_scale`, `art_offset_x`, `art_offset_y`, `idle_sheet_columns`, `idle_sheet_rows`, `idle_sheet_order`, `idle_sheet_ping_pong`, `idle_frame_seconds`, `footprint`, `boss_bar`, and `status_immunities`.
- Numbers in `data/enemies.json` are player-scale values. `GameData.enemy_def` multiplies HP and action amounts/damage by `10` for runtime fixed-point combat. Do not pre-scale data values.
- Each intent needs `id`, `name`, `time`, `weight`, and `actions`. Keep names short enough for board intent popups.
- Existing enemy action verbs include `move_toward`, `move_away`, `melee`, `ranged`, `aoe`, `push`, `pull`, `block`, `stoneskin`, `heal_self`, `lightning_strikes`, and `summon_minions`.
- Existing attack keywords include `burn`, `freeze`, `shock`, `poison`, `bleed`, `expose`, `sunder`, `immobilize`, `pierce`, `push`, and `pull`.
- Do not add stun. Stun was intentionally removed from the game.
- `summon_minions` already creates summoned enemies with no ember reward/card-play bonus on death. If a new summoner needs custom copy/split behavior, make the mechanic reusable and test id assignment, spawn tiles, intent assignment, and rewards.
- Use `status_immunities` sparingly for enemies whose identity requires it. Zekarion's `shock` immunity is a precedent, not a default.

## Mechanical Design

- Give every new enemy at least two meaningfully different intents, and normally three or four. Avoid enemies that are only "crawler but bigger" or "acolyte with a renamed bolt."
- Preserve readable counterplay. The revealed intent should tell the player whether to reposition, block, kill, freeze/shock, use terrain/traps, or accept a delayed consequence.
- Anchor normal enemies near current roster bands before depth scaling:
  - light fast nuisance: about `6-10` HP, base initiative `7-10`, low damage, high movement or status pressure
  - standard threat: about `10-16` HP, base initiative `9-13`, mixed move/attack/support
  - heavy anchor: about `18-26` HP, base initiative `13-17`, slower reach, block/stoneskin/AoE/control
  - boss or elite: only when the task explicitly includes boss integration and inspection proof
- Tune `time` with initiative in mind. Enemy repeat cadence is `base_initiative + intent time`, with initial spawn stagger for readability. Very fast enemies need lower damage or fragile HP; slow enemies need enough board impact to matter.
- `reward_embers` should reflect difficulty and whether the enemy is summoned. Normal enemies currently sit roughly from `8` to `14`; summoned support enemies can use `0`.
- Depth and elemental room transforms already modify HP, damage/support, attack shape, and control. Test the enemy in neutral and at least one elemental room if the new intent has unusual movement, AoE, status, or summoning.
- If enemy roster, intent pacing, spawn density, room spacing, or enemy assumptions change, update both `spec/card_balance_heuristic.md` and `tools/card_heuristic.py` in the same change.

## Encounter Integration

- Normal room pools live in `RoomGenerator._encounter_enemy_types`. Add new enemies deliberately by local depth band and composition role.
- Keep early depth-one rooms learnable. Introduce complex mechanics at low frequency, behind lower damage, or at deeper local depths.
- Respect spawn constraints: rooms reserve the player entry halo, avoid door tiles, softly discourage pileups, and support larger footprints. Large footprints need focused placement and movement tests.
- Boss rooms use `_pick_boss_enemy_positions` and explicit enemy lists. Do not add boss-sized or 2x2 enemies to normal pools unless pathing, targeting, and visual proof cover them.
- For enemies that summon, split, or create copies, cap runaway board clutter through action weights, spawn tile limits, summon health, or one-at-a-time rules.

## Visual Production

- Final enemy sprites should be runtime-visible raster art, not SVG placeholders. Use the `imagegen` skill for final enemy art unless the user explicitly asks for a placeholder.
- Prefer new final sprites under `assets/art/enemies/<enemy_id>.png`. Existing legacy sprites live under `assets/placeholders/units`; do not add new placeholder-era art there unless intentionally staging.
- Static combat unit sprites use a transparent `255x255` PNG with a grounded full-body silhouette, readable at board scale, no text, no border frame, and no opaque square background.
- Optional idle sheets use the same stem with `_idle.png` and are discovered automatically, for example `assets/art/enemies/<enemy_id>_idle.png`. Configure `idle_sheet_columns`, `idle_sheet_rows`, `idle_sheet_order`, `idle_sheet_ping_pong`, and `idle_frame_seconds` in `data/enemies.json`.
- Match Labyrinth's visual language: grim ash-fantasy, worn material surfaces, sharp silhouettes, muted shadows with one clear accent color, and painterly pixel-readable detail. Avoid cute mascots, bright toy colors, sci-fi tech, modern clothing, or generic high-fantasy monsters that do not look ash-corrupted or dungeon-native.
- Tune `art_scale` and offsets against real board screenshots so the sprite's feet anchor to the tile and health/intent UI remains readable.
- Save visual proof screenshots with fresh timestamped or versioned filenames.

## Tests And Proof

Add focused coverage for the actual risk:

- enemy schema: required fields, valid art paths, intent ids/names/times/weights, action verbs, and loaded textures
- spawn integration: the new enemy appears in intended depth pools, deterministically, without breaking player halo, door, reachability, or boss tests
- mechanics: each novel action, status, summon, split, copy, footprint, or targeting behavior has a direct `CombatEngine` test
- previews: board threat tiles, intent rows, status badges, damage previews, and animation steps make the mechanic legible
- visuals: a board visual probe or contact sheet shows the enemy at board scale, with any idle sheet active
- balance: compare turn cadence, reach, damage/support, HP, and ember reward against nearest existing enemies

For new normal enemies, create an inspection fixture that opens directly into a combat room containing the enemy before the key mechanic resolves. For data-only or tooling-only enemy work with no useful playable state, explain why no fixture applies.

## Finish Notes

When finishing enemy work, report:

- enemy id, name, role, intended depth band, and closest existing comparison
- HP, base initiative, weighted intent cadence, reward embers, and major counterplay
- spawn pool changes and any boss/elite restrictions
- novel mechanic hooks added or reused
- art path, idle sheet path if any, `art_scale`/offset choices, and whether `imagegen` was used
- visual proof paths and inspection fixture launch command or not-applicable reason
- tests/probes run
- any `spec/card_balance_heuristic.md`, `tools/card_heuristic.py`, analytics, or memento updates
