# Local Analytics

The game now records local-only analytics as append-only JSON Lines under `user://analytics/` by default. The storage format is intentionally boring so it can later be uploaded to S3 and queried or compacted into Parquet without changing the in-game emitter.

## Storage

- File format: newline-delimited JSON (`.jsonl`)
- Default path: `user://analytics/events-YYYY-MM-DD.jsonl`
- Metadata: `user://analytics/meta.json`
- Schema version: `1`

Each event includes a stable `install_id`, per-launch `session_id`, monotonic `sequence`, `run_id`, and `combat_id` when available.

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

## Card Metrics Supported

The current event stream is enough to derive:

- pick rate via `reward_offered` + `reward_choice`
- combats-in-deck via `combat_started.payload.deck_cards`
- draw count via `card_drawn`
- playable count via `card_became_playable`
- play count via `card_played`
- immediate observed card value ingredients from `card_played.payload`

`card_played.payload` currently logs raw observed ingredients instead of a single heuristic score:

- enemy HP, block, and stoneskin removed
- kills secured
- player HP delta
- block, stoneskin, and healing gained
- move distance
- cards drawn during resolution
- immediate status application deltas
- actual resolved action list and chosen targets

`enemy_status_tick` captures delayed status resolution at the combat level. It is useful for later value-model work, but it is not yet card-source attributed.

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
- draw rules, opening hand, reshuffle, or fatigue
- alternate card play modes
- combat outcome flow
- status timing or turn sequencing
- any fields used by the balance heuristic or future card-performance dashboards
