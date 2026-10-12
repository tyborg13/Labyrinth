# enc-01 — Data-driven section encounter tables

## Header
- Goal: section-map runs pick regular-fight compositions from a director-authored table so each section has its own
  cast (the section enemy roster in `spec/peer_benchmark/enemy_roster_v1.md` lands into it as data). Today pools are
  hard-coded in `RoomGenerator._base_encounter_enemy_type_pool` / `_add_element_locked_enemy_type_pools` and identical
  in every section.
- Base: `codex/peer-benchmark` (director gives the commit).
- Data provided (director-authored, committed before launch, protected): `data/encounters.json` (format documented in
  its `_doc`; read every value from it).
- Owned files: new `scripts/encounter_tables.gd`, new `tests/suites/encounter_tables_suite.gd` +
  `tests/encounter_tables_test.gd`; modify `scripts/room_generator.gd` (section runs route through the tables; legacy
  path untouched), `scripts/run_engine.gd` only if the recent-composition history must be stored in run state,
  `spec/encounters.md` (new), `spec/analytics.md` + the combat-start analytics call site (additive `encounter_id`),
  `spec/card_balance_heuristic.md` + `tools/card_heuristic.py` only if the scorer reads encounter pools.
- Rules: legacy layouts (non-section runs, map revisions < 4, guardian/boss/objective-special rooms) produce
  byte-identical compositions and state hashes; deterministic per seed; Windows typed-array rule.
- Contract: risk tier standard. Acceptance: (1) section regular fights come from the table with correct token
  expansion, weights, tier and section biome; (2) no composition repeats one of the previous `no_repeat_last` fights of
  the run when another is available; (3) `max_units` + trim rule; (4) legacy byte-identical; (5) analytics.

## Change (numbered, testable)
1. `EncounterTables.load()` reads `data/encounters.json` once; validates every unit id exists in `data/enemies.json`,
   every biome/element key, weights > 0; a bad table fails loudly in tests (not silently at runtime).
2. `EncounterTables.pick(tier, room_element, biome, history, rng) -> {id, units}`: filter out entries whose `id` is in
   the last `no_repeat_last` picks (unless that empties the tier), weighted pick, expand `$element` (room element, or
   the mystery's element for a mystery combat; `none` → treat as no element and skip entries containing `$element`) and
   `$biome` (weighted pick per token from the section dragon's biome element's groups), then apply `max_units` with the
   trim rule. The biome is the section's dragon element (`fire`, `earth`, `ice`, `air`, `lightning`, `shadow`).
3. `RoomGenerator`: for revision-4 section regular combat rooms only, use `EncounterTables.pick`; keep the existing
   objective adjustments (Reach Exit extras, leader) applied after the pick; store the composition id in room metadata
   and append it to a per-run history (saved, old saves → empty history).
4. Spawn placement must handle up to `max_units` (7) units on the section room layouts without violating the player
   halo, door tiles or reachability; add a suite case that generates every table entry × every biome × every element
   on 32 seeds and asserts placement succeeded with all units present.
5. Analytics: additive `encounter_id` (and `biome`) on the combat-start event; update `spec/analytics.md`.
6. Spec `spec/encounters.md`: format, tokens, how to add a section enemy (one `biome_groups` entry), the legacy rule.

## Proof
- Suite: token expansion, weights (10k picks within ±2% of expected shares on a fixed seed), no-repeat, trim, legacy
  byte-identity (existing pool outputs for 64 seeds unchanged), placement sweep, save/load of history.
- Report per tier: min/mean/max total base HP and unit count across all expansions (director checks against the
  legacy tier means 36 / 49 / 67).
- Keep green: full suite, section map v2, room generator suites, dragon boss, guardian suites.

## Out of scope
- New enemies, guardian/dragon rooms, reward changes.
