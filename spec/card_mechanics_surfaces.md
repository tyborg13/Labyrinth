# Card mechanics, wave 4 family A: surfaces, selectors and hit results

Owning spec for the wave-4 surface family of the [card pool overhaul](card_pool_overhaul/README.md)
(data shapes: `spec/card_pool_overhaul/card_defs.py`). Rules code:
`scripts/surface_card_rules.gd`, called from small hooks in `CombatEngine`
(`player_action_needs_target/_orientation/_can_resolve`, `valid_targets_for_player_action`,
`_apply_player_action`, `_resolve_board_attack`, `_resolve_board_detonate`,
`_resolve_surface_consumer`, `_surface_action_tiles`, `prepare_next_player_turn`,
`advance_one_activation_with_steps`) and `DragonTrophyRules.route` (`ignore_los`).
Tests: `tests/suites/card_mechanics_surfaces_suite.gd` (wrapper
`tests/card_mechanics_surfaces_test.gd`).

Hover forecasts run the same resolver on a copy (`surface_preview_for_player_action`), so
preview and commit agree for every mechanic below. "Footprint" means every tile of a large
(2x2) enemy.

## New action types

| Type | Targeting | Rule |
| --- | --- | --- |
| `surface_adjacent_enemies` `{surface, include_self?}` | none | Place `surface` (ordinary placement and replacement) on every footprint tile of a visible enemy that is orthogonally adjacent to the player; `include_self` also places it on the player's tile. Placement is not contact: Fire deals no entry damage and Ice does not Chill until the unit enters or starts a turn there. |
| `convert_surface` `{range, surface, to, connected, damage, element, shock}` | a visible tile holding `surface` within `range` and line of sight | The tile and, with `connected`, every cardinally connected visible tile of `surface` become `to`. Each enemy (any footprint tile) on a converted tile takes one direct hit of `damage` and the riders (Shock). |
| `discharge` `{range, damage, element}` | a visible Electrified tile within `range` and line of sight | Take its cardinally connected visible Electrified network. Each enemy on or orthogonally adjacent to any network tile takes one direct hit of `damage`; then the network is removed. |
| `all_enemies` `{selector, damage, element, range?, expose?}` | none | Every living enemy the player can see (never Umbra-hidden) matching `selector`, within `range` of the player when printed, is selected first and then takes one direct hit of `element` plus riders. Selectors: `on_fire`, `on_electrified` (any footprint tile on that surface), `chilled` (Chilled and not Frozen), `in_light` (any footprint tile in Light). The action cannot resolve with no matching enemy, so a card made only of it is unplayable then. An Ice strike on a Chilled enemy Freezes it by the normal rule; lightning does not conduct. |
| `meteor_marks` `{range, pattern, rotate, damage, surface, element}` | an Area target (passable, visible, in range and sight; not the player's tile) aimed with the Area Rotate UI | Store a mark `{tiles, damage, element, surface, card_id, source}` in combat `meteor_marks`. At the start of the player's next turn, after start-of-turn ground and before the draw, each mark deals `damage` once to every occupant of its tiles (enemies, the player, illusions, terrain), then each tile gains `surface`; the marks clear. Marks persist through enemy turns and ride in the saved combat state. If combat has ended, nothing resolves. |

These damage types are not `ATTACK_ACTION_TYPES`: attack relic bonuses and next-attack buffs
do not apply; Expose and damage-vs-status do. The damage context is a player card, so a kill
grants the usual card play (a meteor kill grants it in the new turn).

## New action fields

- `consume` `{surface, bonus_damage?, required?, per_hit?}` on melee/ranged/aoe. A single-target
  hit on an enemy standing on `surface` (any footprint tile) gains `bonus_damage` and consumes
  the surface under the struck footprint after the hit. `per_hit` extends this to Chain and
  conducted hits; otherwise only the primary target. An area consumes `surface` on every pattern
  tile after all hits, and enemies whose footprint touched a consumed tile gain the bonus.
  `required` makes the attack legal only against enemies standing on `surface` (no ground or
  bare-enemy targets). Trailing `surface` riders are placed after consumption.
- Detonate: `detonate_surface` consumes that surface instead of Fire (the Basalt Kiln crush
  path; targets must cover the fuel); `leave_surface` places that surface on each consumed tile
  and its four passable neighbors after the blast; `spare_player` keeps the player out of the
  blast. Immolation is range 0 around the player; only Fire tiles in its pattern detonate and
  its Empower widens the pattern.
- `consume_surface` rewards with `per_tile: true` scale by the tiles removed, capped at `max`.
- `on_result` `{when: "froze"|"killed", rewards}`: after the primary hit, if it Froze the target
  (not Frozen before, Frozen after) or killed it, the rewards apply once through the ordinary
  reward application after deaths flush. Draw rewards reshuffle like a card draw. The normal kill
  card play still applies separately.
- `frozen_splash: N`: if the primary target was Frozen before the hit, after the hit each other
  enemy orthogonally adjacent to its footprint takes `N` (not a direct hit, never tripled).
- `ignore_los: true` on ranged: any visible enemy within `range` regardless of line of sight
  (`range` 99 is unlimited). `shock_all_hits: true`: every enemy hit, including Chain and
  conduction, is Shocked.
- `surface_follows_facing: true` with a melee `surface_pattern`: the pattern is oriented along
  the cardinal direction from the player to the struck tile; `[0, 0]` is that tile and `[1, 0]`
  the tile behind it.

Zero-damage areas (Flash Powder: Expose + Light; Caltrops: Bleed + Rubble) need no new rule:
an empty tile is a legal area target and riders and surfaces apply as for any area.

## UI contract

- Icons (`ActionIconLibrary.ACTION_ICON_ALIASES`, groups in the icon policy test):
  `meteor_marks` → `cinder_marks` (the same Meteorfall concept as the dragon's);
  `surface_adjacent_enemies` → `surface`. Placeholders awaiting purpose-built icons:
  `convert_surface` → `surface` (needed key `surface_convert`), `discharge` →
  `surface_consume` (needed key `discharge`), `all_enemies` → `aoe` (needed key `all_enemies`).
- Card rows: wards show the placed surface; convert shows source → result surfaces, damage,
  range, Shock; discharge shows Consume Ground + Electrified, damage, range; selectors lead with
  an "Each on [surface]:" condition token; meteor shows the Meteorfall mark, damage, range,
  pattern and the surface left. Rider rows: consume ("Target on/Only Target on/Each hit on
  [surface]:" + bonus + Consume Ground), on_result ("if it Freezes:/if it kills:" + rewards),
  frozen_splash ("if Target Frozen:" + splash). Unlimited `ignore_los` range shows as `∞`.
  Detonate rows add the fuel surface, the surface left and "spares you".
- Hand rows (`RunScene._card_widget_display`) show final damage for the new damage types.
  The action context names the steps Convert Ground, Discharge, Sweeping Strike and
  Meteorfall rather than their shared icon labels.
- Meteorfall uses the Area aim: Rotate button, keys and controller bumpers; the hover footprint
  (`_aoe_tiles_for_action`) equals the marked tiles. `CombatBoardView` draws each marked tile
  (ember fill, ring, Meteorfall icon, tooltip with the incoming damage) from combat state, so
  marks stay visible through enemy turns. The landing animates at turn start as a
  `status_damage` step (`trigger: "meteor_marks"`) carrying losses for floating text.
- Inspection fixture: `tests/meteor_marks_board_probe.gd` (run through
  `tools/visual_probe_runner.py --no-headless --expect-size 1920x1080`) renders marked tiles
  beside ordinary Fire. `card_targeting_audit_suite.state_for` seeds a Chilled enemy on
  Ice and Rubble, an enemy on Electrified ground and Light so every family card is playable
  in the one-click audit.
- Grimoire: `combat:surface_techniques` (consume, convert, discharge, wards),
  `combat:sweeping_strikes` (selectors), `combat:cinder_marks` (now also the Meteorfall card),
  `keyword:surface_electrified` (convert, discharge), `keyword:freeze` (`frozen_splash`),
  `keyword:detonate` (`detonate_surface`, `leave_surface`), `keyword:surface` (wards).

## Analytics

Additive `surface_event` kinds through the existing append-only stream (see
[analytics](analytics.md)): `meteor_marked`, `meteor_impact` (with `victims`, `losses`),
`surface_converted`, `surface_discharge`, `selector_strike`, `attack_consumed_surface`,
`card_result_reward` (`when`, `enemy_id`, `rewards`) and `frozen_splash`. `card_played` is
unchanged; its existing surface and damage fields already cover these plays.

## Heuristic

Scored by `tools/card_heuristic.py`; values in the
[balance heuristic](card_balance_heuristic.md#wave-4-surface-family).

## Deferred

- Purpose-built icons for `convert_surface`, `discharge` and `all_enemies`.
- Enemy AI does not yet avoid tiles under the player's Meteorfall marks, and the
  TURN END risk forecast (which stops before the player's turn starts) does not count a
  mark landing on the hero's own tile.
- Range-0 Detonates (Immolation) remain playable with no Fire in their pattern, like
  Phoenix Cleave.
