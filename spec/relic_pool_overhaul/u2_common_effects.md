# U2 common relic implementation

Rules text and numbers remain in `relic_data.py` and `data/relics.json`.
`scripts/common_relic_rules.gd` owns automatic opening, defense and consumption
hooks. The engine and existing card/surface helpers call them for both the real
action and the hover simulation.

| Relic | Effect types | Timing |
| --- | --- | --- |
| Iron Buckler | `retain_turn_block` | Replace the normal turn-start Block reset with `min(previous, 3)`. |
| Grave Dirt | `start_combat_stoneskin` | Existing combat-construction stat hook, before the first turn. |
| Tallow Candle | `start_combat_light` | Ordinary hero Light source, before opening illusion selection. |
| Waxen Effigy | `start_combat_adjacent_illusion` | Empty cardinal neighbor nearest a visible enemy footprint; row-major tie order. Living terrain is occupied. No visible enemy or legal tile means no illusion. |
| Rubblewalker Greaves | `ignore_rubble_movement_cost`, `turn_start_surface_stoneskin` | Shared navigation and Move expenditure use the same override; Stoneskin also applies on the initial turn. |
| Hobnail Cleats | `surface_chill_immunity`, `player_state_action_mod` | Ignore Ice contact Chill; require both hero Ice support and an Ice attack for damage. |
| Pitch Gloves | `surface_damage_bonus` | Existing surface damage helper now supports an optional recipient `actor_kind` and clamps at zero. Enemy bonus requires player ownership. |
| Grounding Pin | `target_state_action_mod` | Single-target damaging actions read any Electrified target footprint tile when planning Chain. Zero-damage forces are not attacks. |
| Leaden Pommel | `card_action_mod` | `min_time: 5` uses the same undiscounted card test as Hourglass Awl; add to printed Stagger, then ordinary limits/dragon halving. |
| Fencer's Gloves | `nth_card_time_discount` | Price through `GameData.card_def_for_progression` and the existing Time badge; discount before Quicken and the Hourglass reserve. |
| Duelist Whetstone | `moved_tiles_card_attack_bonus` | Read the ordinary tiles-moved counter at each attack action, including earlier movement on that card. |
| Coffin Nails | `fully_blocked_attack_status` | Accumulate direct hero health/Block losses for one enemy attack; apply one Bleed rider when health loss is zero and Block loss positive, before Retaliate. Stoneskin may absorb the remainder; health-loss statistics prevent Defiance recovery from hiding damage. |
| Briar Vambrace | `card_block_retaliate` | Actual positive Block actions and authored nested action rewards qualify once per card. Automatic relic Block rewards do not qualify. |
| Flint Edge | `melee_consume_elemental_damage` | Spend only the selected primary enemy tile before damage/conduction planning, then add three only to the primary hit. Consumed Ice cannot Freeze, even if the enemy has other Ice footprint tiles. |

For a large actor contacting Fire of mixed ownership, choose the strongest
applicable contact and its causal source, once for the actor. Tile iteration
order must not hide Pitch Gloves' bonus or multiply Fire damage.

Flint's spent tile cannot also bridge conduction. Target-state Chain is acquired
when the attack begins, before the tile payment. Native Chain side hits neither
consume their own ground nor receive Flint's damage bonus.

## Persistence and analytics

`turn_flags.cards_finished` counts finished cards separately from play slots:
Flurry consumes several slots but finishes one card. It resets with other turn
flags. `pending_card_payment.block_retaliate_used` guards multi-action/Flurry
Block triggers and clears with payment at card completion. Both use the ordinary
run save serializer; a resumed partially resolved card preserves the guard.
`surface_rule_overrides.player_ignores_rubble` is derived from effects alongside
the existing conductive-Fire override and also survives the normal combat save.

No new analytics event types or payload fields are introduced. Flint uses the
existing `surface_removed` (`reason: consume`) and `attack_consumed_surface`
events; Fire retains `surface_damage` and the chosen tile's creator. Enemy
attack status outcomes and ordinary Retaliate continue through their existing
resolution/event boundaries. Forecasts only modify copies and do not append
analytics.

Proof: `tests/relic_u2_test.gd`, registered `tests/suites/relic_u2_suite.gd`, and
`tests/relic_u2_probe.gd` (four production-scene captures at 1920×1080, UI scale 1).
