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
| `surface_adjacent_enemies` `{surface, include_self?}` | none | Place `surface` (ordinary placement and replacement) on every footprint tile of a visible enemy that is orthogonally adjacent to the player; `include_self` also places it on the player's tile. Placement alone applies no contact effect. |
| `convert_surface` `{range, surface, to, connected, source_optional?, damage, element, shock}` | a visible tile within `range` and line of sight, holding `surface` unless `source_optional` | The selected tile becomes `to`. With `connected`, the effect follows the cardinally connected network of `surface` from the selected tile. A connected conversion includes concealed ground. Each enemy on a converted tile takes one direct hit of `damage` and the riders (Shock). |
| `discharge` `{range, damage, element}` | a visible Electrified tile within `range` and line of sight | Burst `damage` the tile and its cardinally connected Electrified network, including concealed ground (see Burst): every unit in the union of the network's crosses, you included, takes one direct hit; the network is destroyed. |
| `all_enemies` `{selector, damage, element, range?, expose?, stagger?, surface_bonus?}` | none | Select living visible enemies, within `range` when printed, then apply one direct hit of `element` plus riders to each selected enemy. `visible` adds no condition. `on_fire`, `on_electrified`, `on_ice`, and `in_light` match any footprint tile in the required ground or Light. At least one enemy must qualify. White Silence Staggers each qualifying enemy by 6. Lightning does not conduct. |
| `meteor_marks` `{range, pattern, rotate, damage, surface, element}` | an Area target (passable, visible, in range and sight; not the player's tile) aimed with the Area Rotate UI | Store a mark `{tiles, damage, element, surface, card_id, source}` in combat `meteor_marks`. At the start of the player's next turn, after start-of-turn ground and before the draw, each mark deals `damage` once to every occupant of its tiles (enemies, the player, illusions, terrain), then each tile gains `surface`; the marks clear. Marks persist through enemy turns and ride in the saved combat state. If combat has ended, nothing resolves. |

- Frost Circuit uses `source_optional`. The chosen tile can hold any ground or none,
  provided the tile can hold a surface. On Ice, the effect reaches every cardinally
  connected Ice tile, including Ice beyond targeting range or visibility. Hover
  uses the full network to forecast hits on visible enemies and shows ground
  changes within committed sight.
- Stoke uses the `visible` selector and a target `surface_bonus`. Every visible enemy
  takes one hit. A Fire tile touching any part of the target's footprint adds 3 to
  that hit and stays on the board. The confirmation preview uses the same
  footprint check and keeps concealed Fire tiles hidden.

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
- Burst (`detonate` actions): `detonate_surface` destroys that ground instead of Fire (the
  Basalt Kiln crush path; targets must cover the fuel unless `fuel_optional`, Dust Devil);
  `leave_surface` places that surface on the tiles the Burst destroyed (Magma Vent's Fire),
  or on every tile it hit with `leave_surface_on: "tiles_hit"` (Rockburst); `spare_player` keeps you
  out. Immolation is range 0 around you; only Fire tiles in its pattern Burst and its Empower
  widens the pattern. See Burst below.
- `consume_surface` rewards with `per_tile: true` add `base_amount` to the amount scaled by
  tiles removed, then apply `max` to the total. Grounding sets `min_consumed: 0` so the
  base reward applies even without any Electrified tiles within 2.
- `on_result` `{when: "on_ice"|"killed", rewards}`: if the target stood on Ice at impact
  or the hit killed the target, the rewards apply once
  through the ordinary reward application after deaths flush. Draw rewards reshuffle like a card
  draw. The normal kill card play still applies separately.
- `surface_bonus.stagger` (pla-06): "On Ice: also Stagger N". The target-subject bonus adds
  `stagger: N` to the hit when its target stands on Ice when hit; the hit then Staggers through
  `CombatEngine._apply_card_stagger`. When one of your Ice cards Staggers an enemy, rites and
  relics with `status: "ice_stagger"` trigger (Rite of Hoarfrost, Cold Mirror) and a
  `status_applied {status: "stagger", element: "ice"}` event feeds Rimecatcher Vial.

- `ignore_los: true` on ranged: any visible enemy within `range` regardless of line of sight
  (`range` 99 is unlimited). `shock_all_hits: true`: every enemy hit, including Chain and
  conduction, is Shocked.
- `surface_follows_facing: true` with a melee `surface_pattern`: the pattern is oriented along
  the cardinal direction from the player to the struck tile; `[0, 0]` is that tile and `[1, 0]`
  the tile behind it.

### Ice ground (pla-06)

A unit (hero, enemy or illusion) that enters Ice or starts its turn on it gets Expose 2
(`BoardSurfaceRules.ICE_EXPOSE`). Ice contact does not stack Expose past 2, and the next
damage spends it. Ice placed under a unit does not Expose it until it enters or starts a turn
there. Skate and Hobnail Cleats (`ice_expose_immunity`) stop it for the hero. Previews show the
Expose a unit will have after a move or push onto Ice.

## Burst (pla-04, owner-approved playability plan 2026-11-20)

One verb, one shape. Burst N destroys the thing named (a Fire, Ice, Rubble or Electrified
tile's ground, an Outcrop, crate, keg or illusion), then deals N to every unit on its tile and
the four tiles next to it, you included unless the card says "sparing you". Several
sources (a connected network, each Fire tile an area hit) union their crosses: each unit is hit
once per Burst. Terrain in the cross takes the same damage (kegs chain) and traps there trigger.
`scripts/burst_rules.gd` owns the shape, the victim
set and the non-card resolver; `CombatEngine._resolve_board_detonate` owns card hits (attack
bonuses for attack types, Expose, Retaliate, Stagger riders).

- Conditions are additive: "On Fire: also Burst N the Fire" is a `detonate` follow-up with
  `target: previous_target` after the card's own attack, which always resolves first. The
  follow-up reads its fuel from the ground as it was before the card's first action.
  A single-target Burst uses the aimed square if fueled, then the first fueled square of the
  struck unit's footprint in row-major order.
  `pattern` covers each qualifying ground tile hit (Fire for Inferno Ritual, Ice for Flashsteam).
  `sources: "hits"` chooses one fueled square per enemy the attack hit
  (Plasma Arc); `after_attack: true` marks a range-0 Burst around you that follows an attack
  (Phoenix Cleave). A damage bonus (Tectonic Maul) stays one hit with a bonus token.
- Ashen Brand expands follow-up Fire Bursts on that same snapshot. Mirror Triptych echoes
  a Burst that actually resolved and requires the matching fuel at the echo's location.
- Discharge, Rockburst/Worldbreak (`burst_terrain`), Shattered Reflection (`destroy_illusion`
  with `any_tile`), powder kegs, Crownfire, Faultline and the enemies' death Burst share the
  same cross and victim set. The death Burst hits units only.
- Crownfire resolves around marked Fire that survives to the strike. Faultline keeps its
  held cross and triggers traps there.
- Dust Devil: a `fuel_optional` Rubble Burst on any tile in range 3, then `force_area`
  centred on that tile (`target: previous_target`).
- Previews resolve the same actions (the hovered action plus its automatic follow-ups), so
  every Burst hit, including your own Health loss, shows on the board.
- The `terrain_burst` icon's glossary entry is Groundsplit (Craghide's attack, not a Burst).
  `detonate_fire` shows the cross and is available for Fire cards and the Burst entry.
- Rekindle Edge, Shatter Swing, Phoenix Cleave and Worldbreak Burst next to you, so they
  spare you. Black Sun Dial counts ground your Bursts destroy as it counts Expended ground
  (removals tagged `burst: true`).

Zero-damage areas such as Caltrops (Expose and Rubble) can target empty tiles. Apply riders
and surfaces as for any area. Flash Powder creates Light. An enemy that starts a turn in Light gains Expose 2.

## UI contract

- Icons (`ActionIconLibrary.ACTION_ICON_ALIASES`, groups in the icon policy test):
  `meteor_marks` → `cinder_marks` (the same Meteorfall concept as the dragon's);
  `surface_adjacent_enemies` → `surface`; purpose-built `convert_surface` →
  `surface_convert` (Convert Ground), `discharge` → `discharge`, `all_enemies` →
  `all_enemies` (Sweeping Strike).
- Card rows: wards show the placed surface; convert shows source → result surfaces, damage,
  range, Shock; discharge shows the Discharge icon + Electrified, damage, range; selectors lead with
  an "Each on [surface]:" condition token and show their damage on the Sweeping Strike icon; meteor shows the Meteorfall mark, damage, range,
  pattern and the surface left. Rider rows: consume ("Target on/Only Target on/Each hit on
  [surface]:" + bonus + Consume Ground), on_result ("On Ice:" or "If it kills:" + rewards).
  Unlimited `ignore_los` range shows as `∞`.
  Detonate rows add the fuel surface, the surface left and "spares you".
- Hand rows (`RunScene._card_widget_display`) show final damage for the new damage types.
  The action context names the steps by their icon labels (Convert Ground, Discharge,
  Sweeping Strike); Meteorfall keeps its card name over the shared Kindle Ground label.
- Card role emblems: selectors, Discharge, Convert Ground and Meteorfall follow the
  attack range rule (all ranged at their printed ranges); Wards choose block only when
  nothing else on the card has a role, so Rime Step stays mobility. Detonate is a setup
  role by the same range rule (Magma Vent ranged, Immolation melee, Cinder Second keeps
  its shield), and a ground consume that pays Stoneskin or Block (Grounding) reads as block.
- Meteorfall uses the Area aim: Rotate button, keys and controller bumpers; the hover footprint
  (`_aoe_tiles_for_action`) equals the marked tiles. `CombatBoardView` draws each marked tile
  (ember fill, ring, Meteorfall icon, tooltip with the incoming damage) from combat state, so
  marks stay visible through enemy turns. The landing is a turn-start `status_damage` step
  (`trigger: "meteor_marks"`). `scripts/meteorfall_landing_view.gd` plays it with Vyraketh's
  meteor: impact sound, damage, Fire and cleared marks all arrive on its contact frame.
- Inspection fixture: `tests/meteor_marks_board_probe.gd` (run through
  `tools/visual_probe_runner.py --no-headless --expect-size 1920x1080`) renders marked tiles
  beside ordinary Fire. `card_targeting_audit_suite.state_for` seeds an enemy on
  Ice and Rubble, an enemy on Electrified ground and Light so every family card is playable
  in the one-click audit.
- Grimoire: `combat:surface_techniques` (consume, convert, discharge, wards; Consume
  Ground icon), `combat:sweeping_strikes` (selectors; Sweeping Strike icon), `combat:cinder_marks` (now also the Meteorfall card),
  `keyword:surface_electrified` (convert, discharge),
  `keyword:burst` (`detonate_surface`, `leave_surface`, Discharge), `keyword:surface` (wards).

## Analytics

Additive `surface_event` kinds through the existing append-only stream (see
[analytics](analytics.md)): `meteor_marked`, `meteor_impact` (with `victims`, `losses`),
`surface_converted`, `surface_discharge`, `selector_strike`, `attack_consumed_surface`,
and `card_result_reward` (`when`, `enemy_id`, `rewards`). `card_played` is
unchanged; its existing surface and damage fields already cover these plays.

## Heuristic

Scored by `tools/card_heuristic.py`; values in the
[balance heuristic](card_balance_heuristic.md#wave-4-surface-family). The campfire
upgrade pricer (`GameData._action_value`) values the damage of `all_enemies`,
`convert_surface`, `discharge` and `meteor_marks` (and the illusion/terrain blasts
`burst_terrain`, `destroy_illusion`), so their Damage upgrades always add value.

## Deferred

- Enemy AI does not yet avoid tiles under the player's Meteorfall marks, and the
  TURN END risk forecast (which stops before the player's turn starts) does not count a
  mark landing on the hero's own tile.
- Range-0 Detonates (Immolation) remain playable with no Fire in their pattern, like
  Phoenix Cleave.
