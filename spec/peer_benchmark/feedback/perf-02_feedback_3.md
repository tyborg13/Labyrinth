# perf-02 feedback 3 (final round; from the re-review of 254d2bca0, evidence /private/tmp/perf02-rereview-artifacts/)

The behaviour proof is excellent (9,944 enemy turns, 190,464 anchors, 939 forecasts: all exact). Finish with:

1. **Warm-frame measurement, not more optimisation.** The Witchglass step measured 13.9-15.3 ms in 3 of 6 runs while
   other jobs loaded the machine, and 10.5-11.8 ms otherwise. Measure it like every other performance budget in the
   repo (det-03's rule): run the warm pass 5 times per case/mode and assert the 12 ms budget on the minimum of the
   five per-pass maxima. Report all five maxima per case so the spread is visible. Keep 12 ms. No further engine work.
2. **Delete the five dead helpers** in `scripts/combat_engine.gd` (~10180, 10233, 10242, 10249, 10262):
   `_enemy_future_blocking_enemy_count`, `_enemy_future_terrain_indices`, `_enemy_future_actor_target_overlap`,
   `_enemy_future_trap_penalty`, `_enemy_anchor_is_in_grid`. Confirm no caller, including string-based calls.
3. **Make the three surviving guards fail in repository tests:**
   - one enemy per frame: a stub cursor with several enemy steps, assert exactly one advances per frame;
   - exit cancellation: assert the queue is cancelled synchronously in `_exit_tree`, before any frame passes;
   - counters: run the revisit check with profiling explicitly disabled.
   Each mutation (remove the guard) must fail the suite.

Re-run only: the new suite with those mutations, `tests/spx07_hover_benchmark.gd --fresh` and `--fresh --no-profile`,
the enemy tactical AI suite and `en02_enemies_test`. No full suites.
