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

`run_started` includes recovery marker fields when a previous death dropped
embers for the new run: `recovery_marker_active`, `recovery_marker_amount`, and
`recovery_marker_coord`.

## Card Metrics Supported

The current event stream is enough to derive:

- pick rate via `reward_offered` + `reward_choice`
- combats-in-deck via `combat_started.payload.deck_cards`
- elemental intensity at combat start via `combat_started.payload.elemental_intensity`
- draw count via `card_drawn`
- playable count via `card_became_playable`
- play count via `card_played`
- immediate observed card value ingredients from `card_played.payload`

`card_played.payload` currently logs raw observed ingredients instead of a single heuristic score:

- enemy HP, block, and stoneskin removed
- pierce actions resolved and enemy defense bypassed by observed HP damage
- terrain HP damage, terrain destroyed, traps triggered, and battlefield pickups
  collected, including dropped ember piles reclaimed through `embers_recovered`
- kills secured
- player HP delta
- block, stoneskin, and healing gained
- move distance
- cards drawn during resolution
- card play economy during resolution: plays spent, remaining plays before/after,
  net remaining-play delta, total play capacity gained, kill-granted plays, and
  card-action-granted plays
- elemental intensity before/after resolution, gross positive per-element
  intensity gained by the played card, and intensity spent by relic payoffs
- illusions created and their total created health
- immediate status application deltas
- actual resolved action list and chosen targets

AOE card actions are logged in that action list with their explicit `pattern`
offsets so offline balance analysis can distinguish close, line, cluster, and
large-area attacks. Runtime-selected AOE aim orientation is additive on the
resolved action as `orientation`; legal push and pull direction choices are
additive as `force_direction`, while `play_mode` comparison ignores those runtime
direction fields so printed cards still classify as printed plays.

`enemy_status_tick` captures delayed status resolution at the combat level. It is useful for later value-model work, but it is not yet card-source attributed.

`combat_started` marks recovery combats with `recovery_marker_present` and
`recovery_marker_amount`. `combat_ended` includes `recovered_embers`, the total
embers reclaimed from dropped piles during that combat.

Intermediate boss victories emit `combat_ended` and return the run to room mode
without `reward_offered` or `run_ended`; only defeat and the final boss victory
emit `run_ended`.

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
- ember carry, loss, extraction, or campfire level-up flow
- draw rules, opening hand, reshuffle, or fatigue
- alternate card play modes
- elemental intensity production, gating, or room-start rules
- card actions that create, remove, or redirect combat actors
- combat outcome flow
- status timing or turn sequencing
- any fields used by the balance heuristic or future card-performance dashboards
