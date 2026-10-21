# spx-01 — Encounter measurement: analytics context, composition sweep, a combat bot and today's baseline

## Header
- **Owner, enc-specials (approved 2026-10-21):** the objective fights become four authored special encounters on the
  map. Standard fights are always Defeat All. Proposal: https://claude.ai/artifact/D6P63LRV4ccFizPGmMqzRX, with sources
  in `spec/peer_benchmark/encounter_redesign/` (`body.html` holds the rules, guardrails and target bands).
- **Why first:** the special encounters ship with measured guardrails ("a median deck reaches the captain in 2–3
  turns", "no first-turn escapes", "turns 3–6, HP lost 4–8"). We need today's numbers and a repeatable way to measure
  them before anything changes. Nothing player-facing changes in this unit.
- **Base:** integration HEAD. **Owned:** `scripts/analytics_store.gd` (additive only) and the callers that build its
  context; new `tools/encounter_sweep.*` and `tools/encounter_bot.*`; their tests; `spec/analytics.md`;
  `spec/peer_benchmark/encounter_redesign/baseline.md` (new). rr-31 (the Mortar rig) runs in parallel and owns nothing
  here.

## Change
1. **Analytics context (bug).** `AnalyticsStore._event_record` copies a fixed list of context keys. The room type,
   Guardian id, encounter id, biome and section index that callers build are silently dropped.
   - Add them as additive fields: `room_type`, `guardian_id`, `encounter_id`, `biome`, `section_index`. Add
     `special_type` and `special_variant` now too, empty until the special encounters exist.
   - Fill them at combat start, combat end and reward events from the room metadata the game already has.
   - Update `spec/analytics.md`. Write a regression test that fails before the fix and passes after.
2. **Composition sweep** (`tools/encounter_sweep`, headless). Generate rooms through the real section-map and room
   generators for 2,000 seeds per tier, for each of the six section biomes. For each objective that exists today
   (Defeat All, Defeat the Leader, Reach the Exit), report:
   - unit count, base HP and the role mix;
   - the leader's type and its distance from the player, and whether it is the closest enemy;
   - for exits: path length from the entry, and the minimum number of turns a player with 2 free tiles per turn
     needs to reach the nearest exit with nothing blocking.
   Output JSON plus a Markdown table.
3. **Combat bot** (`tools/encounter_bot`, headless, built on the engine the headless console already drives). It plays
   one combat room from a seed and reports won or lost, turns, HP lost, kills and the turn of the first enemy death.
   These are measurement defaults, never player-facing; list any you add under "Chosen defaults".
   - **Decks:** tier 1 is the new-run starting deck. Tier 2 adds 3 common rewards from the game's own reward roll on a
     fixed seed. Tier 3 adds 3 commons and 2 rares the same way. Default equipment, no relics, 24 max HP.
   - **Policy:** greedy, one card at a time. Each option is a card, a target and an optional free move. Score it as
     enemy HP removed, plus 5 per kill, plus objective progress (exit distance closed, leader damage), minus 1.5 × the
     damage the incoming-intent preview predicts at the end tile. Play the best option while one scores above zero,
     then end the turn. Cap the search so a room finishes in seconds.
   - **Determinism:** the same seed, deck and policy always give the same result. Add a test.
4. **Baseline report** in `spec/peer_benchmark/encounter_redesign/baseline.md`: 200 bot runs per objective per tier,
   with medians and the 10th and 90th percentiles for turns and HP lost, win rate, and the share of one-turn escapes.
   Put the composition sweep tables beside it.

## Keep
Every existing analytics field and event, save formats, run state, and all generation and combat behaviour. A
golden-seed check must show the generators produce identical rooms before and after.

## Proof
Focused tests: the analytics regression, bot determinism, the sweep on a small seed count, and the golden-seed check.
Run the full sweep and the 200-run baselines and commit their outputs. No windowed captures: nothing visual changes.

## Out of scope
Any change to encounters, objectives, rewards or the map. The special encounters come in spx-02 onward.
