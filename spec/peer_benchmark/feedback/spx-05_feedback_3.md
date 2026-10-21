# spx-05 feedback 3 (director, from the Codex re-review of fb68b3f7b)

Review: `/private/tmp/labyrinth_codex/review/spx-05-fb68b3f7b.md`. Everything else in feedback 2 is confirmed fixed. Two
items remain. This is the last fix round, so close both completely and prove them.

1. **Blocking: Vaulting Sigil still crosses sealed thresholds.**
   - Cause: actor navigation takes raw-grid tiles (`combat_engine.gd:6512`), then `surface_variety_relic_rules.gd:250` lets
     enemy occupancy override the seal blocker.
   - Reproduction: place the Gaoler on `(7,4)` before the turn-two seal, with the player at `(7,5)` and Vaulting Sigil
     equipped. On turn three, free movement follows `(7,5) → (7,4) → (7,3)`, although
     `_tile_is_passable(state, (7,4)) == false`.
   - Fix: actor navigation enumerates tiles through the shared state-aware passability first, then applies occupancy
     exceptions; geometric queries keep the raw grid.
   - Add this exact regression.
2. **Low: two mutants survive the committed tests.** Add regressions that catch both:
   - a raw-grid force blocker;
   - removing the direct illusion guard.
   The reviewer's probes caught them, so mirror those probes as committed tests.

Proof: focused tests only (the Snare suites, movement, pathfinding, illusion and forced-movement suites, and the relic
suite you touch). No full suites; no windowed runs; no visual changes.
