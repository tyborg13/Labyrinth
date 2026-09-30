# Card Keywords: Stagger, Follow-up, Empower, State and Scale Bonuses

Owner code: `scripts/card_keyword_rules.gd` (rules), hooks in
`scripts/combat_engine.gd`, rows in `scripts/action_icon_library.gd`, UI in
`scripts/run_scene.gd` (search `Card keywords`). Tests:
`tests/suites/card_keywords_suite.gd` (standalone `tests/card_keywords_test.gd`)
and `tests/test_card_heuristic_keywords.py`. Card data shapes are authored in
`spec/card_pool_overhaul/card_defs.py`.

The rule that holds everything together: previews, the hand display and commit
all read the same resolved actions. Card-level keywords are applied once, when
the card starts (`prepare_player_card` then `card_play_actions`); per-hit
bonuses are applied inside the ordinary attack resolver, which hover previews
run on a copy.

## Stagger

Data: action field `stagger: N` on `melee`, `ranged`, `aoe`, `push`, `pull`
(also granted by `state_bonus`).

- When a hit lands on an enemy that is still alive after the hit, that enemy's
  next queued `turn_queue` entry moves `N` later (`time += N`, new `seq`). The
  initiative clock never changes. Chain hits stagger each enemy they hit.
- An enemy with no queued entry (the current actor) keeps the delay in
  `stagger_pending` and receives it when `_schedule_actor` next schedules it.
- Dragons (`DragonBossLibrary.is_dragon_boss_id`) take half, rounded down.
- At most 6 total delay per enemy per player activation. The running total is
  `turn_flags.stagger_applied[enemy_id]`, so it resets with the turn flags.
  `stagger_applied_total` is a monotonic combat counter for analytics.
- UI: `stagger` token (value N) in the action row, before Push/Pull. While a
  selected card's Stagger target is hovered, the turn-order rail shows the
  enemy at its delayed slot with a `Stagger +N` badge (transient
  `turn_order_preview_enemy_delays`, visible enemies only; the committed queue
  is untouched). On commit the rail animates from the undelayed order, and the
  hit shows a `Stagger +N` float.

## Follow-up

Data: card field `follow_up: {"mods": [{"action": i, "add": {...}, "set": {...}}], "append": [action...]}`.

- Active when `cards_played_this_turn > 0` during the player's activation at the
  card's start (that counter increments only in `finish_player_card`, so the
  card never counts itself).
- `add` increments a numeric field, `set` overrides a field; `action` indexes
  the printed action list. `append` actions follow the printed actions and
  inherit the card's element/action-type tags. Flurry repeats all use the
  state captured at the card's start.
- Modded fields carry `_modifiers` (source `Follow-up`) so tokens show the
  modifier marker and tooltip. Every action of an active card has
  `_follow_up_active: true`.
- UI: a Follow-up segment row (`follow_up` icon, then the bonus tokens, e.g.
  damage `+3`, draw `1`). In combat, while active, the hand shows the boosted
  values, marks the segment active (`✓`, bonus tone) and does not duplicate
  appended actions as separate rows.

## Empower

Data: card field `empower: {"cost": {"time": N} | {"health": N} | {"exhaust": true}, "mods": [...], "append": [...]}`.

- An optional extra cost toggled while playing the card; mods/appends apply
  exactly like Follow-up (after Follow-up when both apply).
- The choice is stamped on the prepared state (`card_play_modifiers`,
  `prepare_player_card(..., "empower")`), separate from technique
  `_surface_relic_modes`, and cleared by `finish_player_card`.
- Costs are paid when the card finishes: `time` is added to the paid Time
  (still paid when Borrowed Time removes the printed Time); `health` is lost
  after effects and bypasses Block, once per card; `exhaust` sends the card to
  `burned`, and an armed Rehearsed Escape preserves it like normal Exhaust
  (such cards also make Rehearsed Escape armable).
- UI: the action-context command host shows `Empower +N Time`, `Empower N HP`
  or `Empower: Exhaust` (prefixed `✓` when on) while no board target has been
  chosen: at a targeted card's first decision, and at a targetless card's
  confirmation stage (tracker mode `confirmation`). Keyboard `E`; controller
  right-stick press (`controller_empower`, glyph `RS` / `R3`), listed in the
  controller prompt bar. Toggling rebuilds the preview from the card's start, so
  earlier automatic actions resolve with the bonus. The turn-order Time preview
  includes the `+Time` cost. The card's rows show an Empower segment
  (`empower` icon, cost token, bonus tokens).

## State bonuses

Data: action field `state_bonus: [{"state": "light"|"frozen"|"half_hp", "damage": N?, "stagger": N?}]`.

- Evaluated per hit against that hit's enemy target, before its damage:
  `light` = any footprint tile covered by Light (`_light_source_covers_tile`);
  `frozen` = `freeze > 0`; `half_hp` = `hp * 2 <= max_hp`. Matching bonuses add
  to the hit's `damage`/`stagger`.
- UI: a condition row using the surface-condition token style (icon
  `illuminate`, `freeze` or `health`) followed by the bonus tokens. The hand
  shows printed damage; the hover preview shows the exact bonus for the target.

## Scale bonuses

Data: action field `scale_bonus: {"per": "stoneskin"|"tiles_moved", "damage": 1, "max": N}`.

- Damage `+damage` per point of the player's current Stoneskin, or per tile
  moved this activation, capped at `max`; evaluated at hit time through the
  final-damage path (so hand, preview and commit agree).
- Tiles moved (`turn_flags.tiles_moved`) counts independent movement and card
  Move by tiles entered, and Blink by Manhattan distance. It resets each turn.
- UI: condition-style token with the `stoneskin` or `move` icon and
  `+1 each (max N)`; in combat the hand shows the current scaled damage and
  lists the bonus as a damage modifier.

## Heuristic

`tools/card_heuristic.py` (details in `spec/card_balance_heuristic.md`):
Stagger `0.30` per point × playability × targets; state bonuses by expected
availability (Light `0.40`, Frozen `0.30`, half health `0.45`); scale bonuses by
expected points (Stoneskin `2.5`, tiles moved `1.5` + the card's own movement),
capped at `max`; Follow-up adds `0.55 ×` the score of its bonus; Empower adds
`0.5 × max(0, bonus − cost)` with Time `0.45`/pt, health `1.0`/pt, Exhaust `0.55`.

## Analytics

`card_played.payload` adds `follow_up_active`, `empowered`, `empower_cost`
(the cost dict or null) and `stagger_applied` (delay added by this card); see
`spec/analytics.md`.
