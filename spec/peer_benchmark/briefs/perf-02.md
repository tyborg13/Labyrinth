# perf-02 — No hitch the first time a card is aimed at each tile

## Header
- **Why.** With a card selected, the first visit to each target tile takes 23-38 ms (budget 20). On a cache miss,
  `_pass_preview_summary()` (`scripts/run_scene.gd` ~15480) builds the confirmed hover state
  (`_pass_preview_confirmed_hover_state` ~15318) and runs the revealed-enemy preview cursor
  (`preview_revealed_enemy_actions_before_player_turn_with_steps`, `scripts/combat_engine.gd` ~2408). Two problems:
  1. `_pass_preview_key()` (~19474) includes `_move_attack_approach.revision`, which `observe()` bumps on every tile
     change, so even returning to a tile misses.
  2. Nothing computes target previews ahead of the hover. `_warm_pass_preview_cache_across_frames` (~19524) only warms
     the no-card state after the enemy round.
- **Accepted at the spx-07 merge** as this follow-up. `tests/spx07_hover_benchmark.gd` holds `TARGET_WORST_BUDGET_MS` 40.
- **Base:** `codex/peer-benchmark`. **Risk tier:** standard.
- **Owned:** a new `scripts/pass_preview_prewarm.gd` (the warm queue), the PASS preview key/cache code in
  `scripts/run_scene.gd` (small hooks only; net growth of run_scene.gd ≤ 40 lines), `tests/spx07_hover_benchmark.gd`,
  a new focused suite `tests/suites/pass_preview_prewarm_suite.gd` + runner registered in
  `tests/headless_test_programs.json`.

## Rule that matters most
**The player sees nothing different.** For every hovered target, the PASS chip forecast (tone, losses, projected HP,
defeat, unrevealed/Umbra flags) must equal what today's code shows for the same state, card, action, tile, aim,
choice mode and approach. No frame shows a missing or placeholder forecast. No threads (the engine and several static
memos aren't thread-safe).

## Change
1. **Key.** Replace `_move_attack_approach.revision` in `_pass_preview_key()` with the approach's effective input: the
   entry tile when the move-attack approach produces a non-empty plan for the hovered tile, otherwise (-1,-1). Prove
   in tests that two hovers with the same effective input produce identical summaries (so the key is sound) and that
   a different entry giving a different plan misses.
2. **Tile parameter.** `_pass_preview_confirmed_hover_state` takes the target tile as a parameter instead of reading
   `_hovered_board_tile`; the hover path passes the hovered tile. The key builder takes the tile the same way.
3. **Prewarm queue** (`scripts/pass_preview_prewarm.gd`), started when a card preview begins (`_begin_card_preview`)
   and restarted when the target set or aim changes (`_pending_target_tiles`, AoE aim orientation, choice mode):
   - Order: the tile under the cursor first, then by board distance from the cursor (ties: from the hero), then row
     order.
   - Work per frame: advance the existing cursor by one enemy per frame, like `_warm_pass_preview_cache_across_frames`,
     and never more than 6 ms of warm work in one frame (finish the current enemy step, then yield).
   - Prewarm uses the default approach (no entry tile). An actual hover with a different effective approach is simply
     a miss and computes synchronously as today.
   - Cancel immediately (generation counter, reuse `_pass_preview_warm_generation`) on any preview invalidation,
     selection change, card play, end of the player phase, or leaving combat. A cancelled queue writes nothing.
   - Results go into `_pass_preview_cache` under exactly the key a hover would use. Raise `PASS_PREVIEW_CACHE_LIMIT`
     to 256.
   - A synchronous hover on a tile the queue hasn't reached computes as today and the queue skips it later.
4. If the warmed worst still exceeds 20 ms, profile the remaining hover cost (`_refresh_stage_view` /
   `_preview_damage_for_action`, `_refresh_turn_order_bar`) and report the breakdown. You may prewarm the resolved
   player-action preview per tile in the same queue under the same rules, if that's what remains.
5. If `_update_action_context_risk` / `_update_action_context_copy` really have no callers, delete them (it reduces
   run_scene.gd); report it either way.

## Benchmark and budgets
- Keep today's cold sweep (no frames between selection and sweep) and its budgets unchanged.
- Add a warmed sweep: select the card, run idle frames until the queue reports done (cap 120 frames; record how many it
  took), then sweep card and drag modes. Budget: warmed worst ≤ 20 ms, median ≤ 6 ms, on all three fixture cases
  (ordinary, air_t2, lightning_t3).
- Record the worst single-frame warm cost; budget ≤ 10 ms.
- Report cold and warmed numbers, frames-to-warm per case, and the cache hit rate on a revisit sweep (target 100%).

## Tests (`pass_preview_prewarm_suite.gd`)
- Equivalence: for every target tile in the three fixture cases, the prewarmed summary equals a fresh synchronous
  computation with caches cleared (deep equality).
- Cancellation: invalidating mid-warm (play a card, change selection, rotate aim) leaves no entry from the old
  generation in the cache.
- Revisit: hover A, hover B, hover A → the third hover is a cache hit.
- Approach: a move-attack shortcut tile entered from two different directions with different plans gives two entries.
- Mutations (report each): keep the revision in the key → the revisit test fails; prewarm with a stale generation →
  the cancellation test fails; drop the tile parameter (read the hovered tile) → the equivalence test fails.

## Proof
Focused: the new suite, `tests/spx07_hover_benchmark.gd` headless (`--fresh`; report both sweeps), `warband_ui_test`,
`warband_wind_lock_test`, `card_keywords_test`, `full_scene_controls_program` (it covers live targeting). No full suites.
Under "Proof for the design owner", list the windowed command for the native frame check (the spx-07 director probe
sweep) so the director can confirm frame times on the real renderer.

## Out of scope
Changing what the forecast shows, the enemy preview cursor itself, threading, the board hover (no-card) path.
