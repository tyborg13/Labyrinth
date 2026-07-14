# Local Analytics

The game now records local-only analytics as append-only JSON Lines under `user://analytics/` by default. The storage format is intentionally boring so it can later be uploaded to S3 and queried or compacted into Parquet without changing the in-game emitter.

## Storage

- File format: newline-delimited JSON (`.jsonl`)
- Default path: `user://analytics/events-YYYY-MM-DD.jsonl`
- Metadata: `user://analytics/meta.json`
- Schema version: `1`

Each event includes a stable `install_id`, per-launch `session_id`, monotonic `sequence`, `run_id`, and `combat_id` when available.

Run and combat events also include the current character progression snapshot in
their context when available:

- `progression_level`
- `progression_stats`

Combat-mode events also include initiative context when combat state is
available:

- `initiative_clock`
- `current_actor_kind`
- `current_actor_key`
- `umbra_stage`
- `umbra_radius`
- `visible_enemy_count`

## Current Event Types

- `run_started`
- `run_resumed`
- `run_ended`
- `combat_started`
- `combat_resumed`
- `combat_ended`
- `reward_offered`
- `reward_choice`
- `card_drawn`
- `card_became_playable`
- `card_played`
- `enemy_status_tick`
- `progression_level_up`
- `equipment_equipped`
- `magic_attuned`
- `item_equipped`
- `merchant_trade`

`run_started` includes the compiled starting deck plus the equipment model used
to build it: `reward_cards`, `equipped_equipment`, `equipment_inventory`, and
`collected_equipment`. It also includes recovery marker fields when a previous
death dropped embers for the new run: `recovery_marker_active`,
`recovery_marker_amount`, and `recovery_marker_coord`.
It also includes the active magic loadout fields `attuned_magic_cards` and
`magic_inventory`; `reward_cards` remains the collected reward-card history.
Consumable item loadout state is included as `equipped_items` and
`item_inventory`.

## Card Metrics Supported

The current event stream is enough to derive:

- pick rate via `reward_offered` + `reward_choice`
- combats-in-deck via `combat_started.payload.deck_cards`
- equipment and magic build context via `combat_started.payload.equipped_equipment`,
  `reward_cards`, `attuned_magic_cards`, `magic_inventory`,
  `equipped_items`, `item_inventory`, `equipment_inventory`, and
  `equipment_drops`
- elemental intensity at combat start via `combat_started.payload.elemental_intensity`
- draw count via `card_drawn`
- playable count via `card_became_playable`
- play count via `card_played`
- immediate observed card value ingredients from `card_played.payload`

`card_played.payload` currently logs raw observed ingredients instead of a single heuristic score:

- enemy HP, realized block, and stoneskin removed; future guard intents do not
  count as removable block until that enemy resolves the block action
- pierce actions resolved, sunder actions resolved, and enemy defense bypassed
  by observed HP damage
- terrain HP damage, terrain destroyed, traps triggered, summed triggered trap
  damage, and battlefield pickups collected, including dropped ember piles
  reclaimed through `embers_recovered`
- kills secured
- player HP delta
- block, stoneskin, and healing gained
- move distance
- cards drawn during resolution
- card play economy during resolution: plays spent, remaining plays before/after,
  net remaining-play delta, total play capacity gained, kill-granted plays, and
  card-action-granted plays
- Flurry identification via `flurry` plus the snapped repeat/spend count in
  `flurry_plays_spent`; the resolved action list contains every printed action
  for every repeat so realized utility, damage, and target selection remain
  observable. Initiative fields record the single top-level time payment rather
  than multiplying it by `flurry_plays_spent`.
- initiative timing: printed `card_time`, player turn time spent before/after
  the play, and the current `player_base_initiative`
- elemental intensity before/after resolution, gross positive per-element
  intensity gained by the played card, and intensity spent by relic payoffs
- illusions created and their total created health
- immediate status application deltas for burn, bleed, expose, freeze, shock,
  immobilize, and poison
- actual resolved action list and chosen targets
- consumable item flags via `item_card` and `consume_on_play`
- Radiance and visibility context: `radiance_card`, Umbra stage and radius
  before/after, tiles illuminated, enemies newly revealed, light sources
  created, and hidden-enemy movement interruptions caused during resolution

AOE card actions are logged in that action list with their explicit `pattern`
offsets so offline balance analysis can distinguish close, line, cluster, and
large-area attacks. Runtime-selected AOE aim orientation is additive on the
resolved action as `orientation`; legal push and pull direction choices are
additive as `force_direction`, while `play_mode` comparison ignores those runtime
direction fields so printed cards still classify as printed plays.

`enemy_status_tick` captures delayed enemy status resolution. Burn and poison
use `trigger: "turn_start"` when the affected enemy's initiative activation
starts; bleed can use `trigger: "action"` plus `action_type` when a wounded enemy
resolves a move or attack action during that activation. It is useful for later
value-model work, but it is not yet card-source attributed.

`combat_started` marks recovery combats with `recovery_marker_present` and
`recovery_marker_amount`. It also includes any unclaimed floor equipment ids as
`equipment_drops`, plus the opening Umbra stage, effective vision radius, and
visible enemy count. `combat_ended` includes `recovered_embers`, the total embers
reclaimed from dropped piles during that combat, and `collected_equipment`, the
equipment ids picked up during that combat. Its additive `missed_equipment` list
contains equipment ids that were still unclaimed at victory and were resolved
from the cleared room without entering inventory, ownership, discovery, or deck
state. It also records the combat-wide Umbra totals for tiles illuminated,
enemies revealed, movement interruptions against unseen bodies, and damage
received from attacks whose source was hidden when the attack began.

`equipment_equipped` fires when the character overlay equips an owned item
outside combat. Its payload records `slot`, `previous_equipment_id`,
`equipment_id`, the full `equipped_equipment` map, current
`equipment_inventory`, and rebuilt `deck_cards`.

`magic_attuned` fires when the character overlay swaps a reserve magic card into
one of the six attuned slots outside combat. Its payload records the reserve and
attuned indices, the attuned `card_id`, full `attuned_magic_cards`,
`magic_inventory`, `reward_cards`, and rebuilt `deck_cards`.

`item_equipped` fires when the character overlay equips or stows a Scavenger
consumable outside combat. Its payload records `action` (`equip` or `stow`),
`card_id`, `inventory_index`, `equipped_index`, full `equipped_items`,
`item_inventory`, and rebuilt `deck_cards`.

`merchant_trade` fires when a blacksmith, arcanist, or scavenger transaction
succeeds in a non-combat merchant room. Its payload records `action` (`buy` or `sell`),
`merchant_kind`, `item_kind`, `item_id`, ember `amount`,
`held_embers_before`, `held_embers_after`, the current `room`, and the updated
equipment, magic, item, reward-card, and deck state.

Intermediate boss victories emit `combat_ended` and return the run to room mode
without `reward_offered` or `run_ended`; only defeat and the final boss victory
emit `run_ended`.

`run_ended` includes the canonical cumulative performance snapshot:
`enemies_killed`, `damage_dealt`, and `damage_received`. Damage fields count
actual fixed-point HP removed after block and stoneskin, capped by remaining HP;
they do not count absorbed defense or overkill. Enemy alive-to-dead transitions
are the sole kill source. The same monotonic `run_stats` dictionary travels in
the committed run/combat snapshot, so save/resume and animation checkpoints
replace a snapshot rather than reapplying a delta.

## Local Personal Bests

The local progression profile stores `run_bests` plus the idempotent
`last_run_result`. Higher values are eligible for personal-best treatment for
enemies killed, damage dealt, depth, rooms cleared, and bosses defeated. Damage
received remains an informational result because celebrating a larger value
would be misleading.

The first observed value for each eligible field establishes its baseline and
does not show `NEW BEST`; there is no invented prior history. Later values show
`NEW BEST` only when they strictly exceed the stored value, never on a tie. A
stable run result id makes repeated recap refresh, terminal retry, replay hooks,
and process restart idempotent while preserving the original badge decision for
the just-finished run. The profile keeps the 32 most recently used completed
result records, including their original stats and badge fields; a non-adjacent
`A → B → replay A` returns A's original decision without changing the monotonic
bests, and refreshes A's recency in that bounded ledger.

Terminal persistence must record the result before profile save and before the
terminal snapshot is cleared. Any committed-boundary save path should pass its
supplied victory/defeat dictionary through
`_terminal_state_with_recorded_run_result`, then adopt the progression embedded
in the returned state before banking/loss processing and `save_data`. Do not
rely only on later `_process_victory_carry` or `_process_defeat_loss` refresh
hooks: a save implementation may set those processed flags during committed
terminal finalization and legitimately bypass the UI-time hooks.

`progression_level_up` fires when the player confirms Draw Strength at a
campfire. Its payload records the previous and new levels, chosen stats,
post-purchase stat values, ember cost, held embers before purchase, and held
embers after purchase. `stat_id` remains as the first chosen stat for older
analysis, while `stat_ids` and `stat_values` represent the full two-stat
assignment.

## AWS-Friendly Expectations

If this gets uploaded later, keep the event contract compatible with object storage and batch processing:

- prefer additive schema changes over renaming existing keys
- keep top-level fields flat and stable
- avoid Godot-native object serialization in payloads
- continue converting vectors to `{x, y}` dictionaries
- keep per-event payloads self-contained enough for Athena or Spark jobs

## Maintenance

Update analytics instrumentation when changes affect:

- reward offering or reward selection flow
- equipment ownership, drops, equip rules, or deck compilation
- consumable item ownership, equip rules, use-on-play consumption, or deck compilation
- ember carry, loss, extraction, or campfire level-up flow
- draw rules, opening hand, reshuffle, or fatigue
- alternate card play modes
- elemental intensity production, gating, or room-start rules
- Umbra stage progression, visibility, hidden-enemy information, or Radiance
  actions
- card actions that create, remove, or redirect combat actors
- combat outcome flow
- status timing or turn sequencing
- any fields used by the balance heuristic or future card-performance dashboards
