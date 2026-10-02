# Card keywords, wave 3: Retaliate, Quicken, next-attack buffs, Rites

Owning spec for the wave-3 mechanics of the [card pool overhaul](card_pool_overhaul/README.md).
Rules code: `scripts/retaliate_rules.gd`, `scripts/tempo_rules.gd`, `scripts/rite_rules.gd`,
with small hooks in `CombatEngine`, `GameData`, `SurfaceRelicRules` and `GuardianRelicRules`.
Tests: `tests/suites/card_keywords_w3_suite.gd` (wrapper `tests/card_keywords_w3_test.gd`).

## Retaliate

Action `{"type": "retaliate", "amount": N, "bleed"?: n, "shock"?: 1, "push"?: n}`, targetless.

- Stored as combat `retaliate` `{amount, bleed, shock, push, sources}`; cleared by
  `prepare_next_player_turn` beside the Block reset. Several plays stack: `amount` and
  `bleed` add, `shock` and `push` take the maximum.
- Trigger: an enemy attack in `_resolve_board_attack` whose hit on the player carried at
  least 1 damage before defenses (Block-absorbed hits count), when the action is `melee`
  or the attacker's footprint was adjacent to the tile where the player was struck
  (judged before any knockback). Once per enemy attack. Ranged hits from distance,
  illusion hits and zero-damage shoves never trigger it.
- Effect: `amount` as non-direct damage (`_damage_enemy(..., false, false)`: Block and
  Stoneskin absorb; no Chill/Freeze multiplier, no Crystal Mantle, no Expose use), then
  the riders through `_apply_action_keywords_to_enemy` with source = the player: Bleed
  adds, Shock applies (affects the enemy's next turn), Push moves it `push` tiles in the
  cardinal direction away from the player via the engine's normal forced movement.
- Damage context `{actor_kind: player, source_kind: retaliate, player_card: false,
  causal_owner: player}`: kills pay embers and death relics but grant no card play.
- Rite `thorns` effects (`{"type": "thorns", "damage": N, "bleed"?, "shock"?, "push"?}`)
  are a permanent Retaliate that adds to card Retaliate under the same rules.

## Quicken

Action `{"type": "quicken", "amount": N}`: the next card played this activation costs
N less Time, minimum 1.

- Pending pool: `turn_flags.quicken_pending`; several Quickens add up.
- Pricing: `GameData.card_def_for_progression` applies the Rite `card_time_discount` and
  then pending Quicken (each clamped at 1) before Winter's Hourglass reserve, stamping
  `_time_discount_base`, `_quicken_discount` and `_rite_time_discount`. Hand Time badges,
  `card_time_cost` and the Turn Clock preview read this definition.
- Self-discount guard: `_snapshot_pending_card_payment` records the pool when the card's
  first action resolves; `finish_player_card` prices the card from that snapshot
  (`TempoRules.pricing_state`) and leaves only Quicken the card itself granted pending.
  Borrowed Time still zeroes the paid Time; Quicken is consumed either way.
- Unused Quicken expires in `finish_player_activation` (and with `turn_flags`).

## Next-attack buffs

Action `{"type": "next_attack", "damage"?: n, "pierce"?: true, "chain"?: n,
"element"?: e, "per_tile_moved"?: {"damage": d, "max": m}}`.

- Stored in `turn_flags.next_attack_buffs` with `granted_at = cards_played_this_turn`; a
  buff is eligible only for an attack action (melee/ranged/aoe/push/pull/detonate) of a
  later card, and with `element` only for an attack of that element. A push/pull (or a
  push/pull-only area) that deals no damage is forced movement, not an attack
  (`TempoRules.is_forced_movement_only`): it neither receives nor spends the buff, which
  waits for the card's later damaging hit (Sleet Squall's Ice hit) or the next card.
- Applied in `CombatEngine._resolved_surface_action` (so final damage, hover previews,
  hand rows and resolution agree): eligible buffs stack additively into `damage`,
  `chain` and `pierce`, marked `_next_attack_bonus`; `_apply_player_action` consumes them
  once, when the attack resolves. `per_tile_moved` reads `turn_flags.tiles_moved` at that
  moment, counting independent movement and card Move (path tiles) and Blink (Manhattan
  distance).
- Hand display: `TempoRules.display_action` shows granted Pierce/Chain;
  `damage_modifiers_for_player_action` lists the bonus. Expire at activation end.

## Rites

Card field `"rite": {"effects": [...]}` on a `burn: true` card. `card_play_actions` appends
one targetless `{"type": "rite"}` step so the card is playable; `finish_player_card` then
Exhausts the card as usual, pays Time and health cost, fires card-play relics, and
appends `{card_id, name, description, effects}` to combat `active_rites` (never copied
to the run; a new combat starts without it). A Rite never discounts its own Time.

`GameData.relic_effects_for_state(state)` = relic effects + `RiteRules.effects(state)`.
Each Rite effect gets `relic_id = "rite:<card_id>:<n>"` (unique, stable), `rite_card_id`
and `source_name` (the card name, used by `_relic_effect_source_name`). CombatEngine's
`_relic_effects` cache keys on relic ids and active Rites. Readers routed through it:
SurfaceRelicRules, GuardianRelicRules, `card_def_for_progression`,
`stat_bonus_from_state` (movement pool).

| Authored effect | Implementation |
| --- | --- |
| `surface_damage_bonus` (surface fire, amount) | `+amount` to Fire entry and turn-start damage for every actor (optional `owner: player` limits it to player-made Fire) |
| `surface_immunity` (fire) | the player takes no Fire tile damage; player pathing ignores Fire hazard |
| `turn_start_on_surface` | player turn start, after the normal draw: rewards if the player stands on the surface |
| `status_applied_reward` (status, rewards) | `_trigger_status_relics`: every player-applied status of that kind pays the rewards |
| `turn_start_surface_pulse` | player turn start: each enemy on the surface takes `damage` (player-credited, non-card, non-direct); event `rite_surface_pulse` |
| `card_time_discount` | every card costs `amount` less Time (min 1), before Quicken |
| `independent_movement_bonus` | normalized to `movement_pool_bonus` |
| `forced_movement_bonus` | normalized to `card_action_mod` on Push/Pull `amount` and on `push`/`pull` keyword fields, any element |
| `turn_start_reward` | player turn start rewards |
| `player_light_aura` (radius) | a tethered Light source `player_aura` that moves with the player |
| `target_state_action_mod` with `conditions`/`add` | normalized to the existing `target_in_light`/`field`/`amount` form over attack actions |
| `thorns` | permanent Retaliate (above) |

## UI contract

- Icons (`ActionIconLibrary.KEYWORDS`, aliases in `ACTION_ICON_ALIASES`): `retaliate`,
  `quicken`, `rite`, and `next_attack` (purpose-built `next_attack.png`, a charged blade:
  the bonus waits on your next attack). Grimoire: `keyword:retaliate`, `keyword:quicken`,
  `keyword:next_attack`, `keyword:rite`. A Rite card also unlocks the entries its
  effects lean on (Thorns: Retaliate and its riders; reward types; status rewards;
  surfaces; movement and Push/Pull bonuses; Light aura or Light payoff).
- Next-attack, Retaliate and Quicken amounts are valued by the upgrade pricer
  (`GameData._action_value`), so their stat upgrades always add value.
- Rite cards lead with a keyword row (the `rite` icon labelled "Rite", tooltip "Rite:
  Exhaust. Lasts for the rest of this combat.", then the health-cost token when the card
  has one), followed by a `rules_text` row: the description without its "Rite:" prefix
  (`ActionIcons.rite_face_rules_text`), in the card text font, wrapped inside the
  parchment. The face lends a little art height to that text instead of shrinking it.
  `ActionIcons.card_rules_text` keeps the complete text (with "Health cost N.") for
  plain-text surfaces; the card focus tooltips lead with the Rite keyword.
- Time badge detail adds `Rite: -N` and `Quickened: -N`.
- Player board badges: Retaliate (amount, tooltip lists riders and sources), Quicken
  (pending amount), Next attack (total bonus, tooltip per buff).
- Active Rites appear after the relics in the combat relic bar (`ActiveRite_<n>`, `rite`
  icon, tooltip = card name + rules text).
- An enemy strike that triggers Retaliate animates from the attacker's pre-push tile,
  then a `status_damage` step labelled `Retaliate` carries `enemy_losses` and
  `enemies_after` so the attacker's loss floats and applies (a rider-only Retaliate
  uses a `status` step with `enemy_after`).

## Heuristic values

`tools/card_heuristic.py` (see the card balance heuristic spec): Retaliate `0.35`/point,
Bleed `0.30`/point, Shock `1.0`, Push `0.20`/tile; Quicken `0.40` tempo per Time;
next-attack damage `0.40`/point, Pierce `0.60`, Chain `0.45`/hop, `per_tile_moved`
expects the card's own movement plus 1 tile. A Rite sums per-effect estimates over 3
remaining activations into `breakdown.rite`, with no extra penalty beyond Exhaust.

## Analytics

Additive `card_played` fields: `quicken_spent` (Time removed by Quicken from this card),
`next_attack_bonus_used` (`{action_type, damage, chain, pierce, sources}` or null),
`rite_started` (card id or null). Retaliate records a `retaliate_triggered` surface event
(see [analytics](analytics.md)).

## Tempo relics (relic overhaul U4)

`scripts/tempo_relic_rules.gd` owns data-driven tempo effects, with small engine
and card-definition hooks. Pocket Sundial reduces the projected and scheduled
hero activation by unused plays (up to two). Late Bell compares the enemy's
next queued action against that same projection, including the pending card's
Time, Empower/sash surcharges, discounts, and plays spent. Exact Time ties are
not late. Hidden enemies do not disclose their bell on the rail.

Borrowed Hourglass schedules a normal hero activation at the current clock
before enemies, once per combat. `relic_flags["tempo_used:<relic_id>"]` persists
its spent state; `tempo_turn_time_debt` carries the first turn's paid Time
(minus its Sundial reduction) until the extra activation finishes. The ordinary
start path draws, clears Block, resets movement/plays/status-turn flags, and
plays the turn banner. Both dictionaries survive the normal run save.

Hourglass Splinter tests the actual paid card Time, including optional Empower
and Whirling Sash, after discounts; Overclock tests the stamped Empower choice.
Both grant pending Quicken after the card consumes its incoming pool. Whirling
Sash adds its two-Time surcharge after printed-cost discounts/reserve, like
Empower's surcharge; hand badges show the identical final payment.

Feint Ribbon enables the normal Follow-up start snapshot after at least two
actual tiles of independent or earlier card movement. Echoing Blade grants
Quicken and a `card_scoped` next-attack buff. That buff applies to every attack
of the next card and expires when that card finishes, even if it has no attack.
The existing next-attack badge displays it; ordinary next-attack buffs still
expire on their first attack. All unused buffs expire at activation end.

Crown of Surplus grants an Empower spec with `repeat_first: true`, through
`GameData.card_def_for_progression`. Printed Empower, Rites, items and Flurry
are excluded. An enabled Crown repeat is inserted immediately after the first
action, before subsequent actions. It reuses the original enemy identity (and
follows that enemy's displacement), or the original tile for tile targeting;
if that target is dead or no longer legal, the repeat does nothing. Targetless
actions repeat automatically. Hover resolution includes the repeat, while its
single-action state is retained for the existing continuation/risk forecast.

Pendulum Weight deals only the Stagger removed by the six-Time activation cap,
after dragon halving. Its secondary damage uses the existing relic damage
context, with Block/Stoneskin absorption, no direct-hit multipliers and no
card-play kill credit. The normal hover copy resolves the same overflow.
