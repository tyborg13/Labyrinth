# Novel Mechanics

## Table Of Contents

- Decide keyword vs action type
- Keyword/status checklist
- Action type checklist
- Analytics and specs
- Validation

## Decide Keyword Vs Action Type

Prefer an **action keyword** when the mechanic modifies an existing attack or action without changing target selection or action sequencing. Examples: burn, poison, freeze, shock, chain, push, pull.

Use a **new action type** when the mechanic needs its own target validation, resolution step, animation, preview, upgrade surface, or non-attack timing. Examples: move, blink, draw, block, summon-like effects, unusual targeting modes.

Before creating either, confirm the request cannot be expressed by existing action primitives plus numeric tuning.

## Keyword Or Status Checklist

For a new keyword or status field:

- `data/cards.json`: add the field only on actions that should carry it.
- `scripts/action_icon_library.gd`: add a `KEYWORDS` entry, a 64x64 icon path, tooltip copy, and token emission in `_append_keyword_tokens` or the action-specific token path.
- `assets/art/icons/<keyword>.png`: create a 64x64 PNG RGBA icon if no existing icon fits.
- `scripts/combat_engine.gd`: update `_action_has_keyword_effect`, `_apply_action_keywords_to_enemy`, `_apply_action_keywords_to_player`, `_normalized_unit` if stored on units, turn-start decay/tick behavior, status restrictions, immunities, and enemy action steps if enemies can apply it.
- `scripts/combat_board_view.gd`: update unit status badges, tooltips, trap or intent displays if the status should be visible outside the card.
- `scripts/game_data.gd`: add to `STATUS_UPGRADE_FIELDS` and `_status_upgrade_options` only if permanent upgrades should generate it; update `_action_value`.
- `tools/card_heuristic.py` and `spec/card_balance_heuristic.md`: add a coefficient or explicit blind spot.
- `spec/analytics.md` and `scripts/run_scene.gd`: add observed payload fields if the keyword affects card value analysis or status timing.
- `tests/run_tests.gd`: cover icon tokenization, combat application/timing, status badge display, and upgrades/heuristic-sensitive behavior.

Keep tooltip copy terse and action-oriented.

## Action Type Checklist

For a new action type:

- `scripts/combat_engine.gd`:
  - `player_action_needs_target`
  - `player_action_can_resolve` if restrictions matter
  - `valid_targets_for_player_action`
  - `path_for_player_action` for movement or previews
  - `apply_player_action`
  - `final_damage_for_player_action` and damage modifiers if attack-like
  - enemy action resolution and enemy intent step metadata if enemies can use it
- `scripts/game_data.gd`:
  - `ATTACK_ACTION_TYPES` if it damages enemies or should receive attack bonuses/upgrades
  - `upgradeable_elements_for_card`, `_stat_upgrade_options`, `_action_upgrade_options`, and `_action_value`
- `scripts/action_icon_library.gd`:
  - `KEYWORDS` entry and `tokens_for_action` branch
  - plain-text output should still make sense
- `scripts/run_scene.gd`:
  - card play options and fallback modes if relevant
  - `_card_widget_display` for final damage or preview-sensitive rows
  - preview/selection flow and selected-target tracking
  - `_animate_player_card_resolution` if animations need special handling
  - analytics payload if the action changes tracked value ingredients
- `scripts/combat_board_view.gd`: target overlays, attack previews, intent icons, status badges, and animations where applicable.
- `tools/card_heuristic.py` plus `spec/card_balance_heuristic.md`: score the new action or explicitly document why it remains a manual review item.
- `tests/run_tests.gd`: add resolution, target validity, icon, preview, and analytics tests.

Use typed-array helpers for `Array[Vector2i]` changes. Godot on Windows is stricter than macOS about assigning bare array literals to typed arrays.

## Analytics And Specs

Consult `spec/analytics.md` whenever mechanics affect reward flow, draw rules, card play flow, combat outcome flow, or status timing. Keep analytics local-first and append-only; prefer additive schema fields.

Update both the spec and instrumentation in the same change when card-balance analysis needs the new behavior.

Update both `spec/card_balance_heuristic.md` and `tools/card_heuristic.py` when changing:

- cards per turn or draw per turn
- fatigue rules
- status behavior
- damage, block, stoneskin, or healing semantics
- enemy preview rules
- room size, enemy spacing, trap count/placement, or spawn selection
- enemy roster or intent pacing
- AOE, chain, push, or pull behavior
- new card action types or keywords

## Validation

Run:

```bash
jq empty data/cards.json
python3 tools/card_heuristic.py --card-id <card_id> --show-breakdown
python3 tools/card_heuristic.py
godot --headless --path . --script tests/run_tests.gd
```

For UI/art changes, also run or inspect the game scene enough to verify card name fitting, icon rows, rarity frame, elemental tint, art visibility, and tooltips.
