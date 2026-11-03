# perf-02 feedback 2 (from the Codex review of 409a9d1f8; evidence /tmp/perf02-review-artifacts/)

The forecast oracle is clean (939 combinations, zero mismatches), so keep the design. Fix these:

1. **Medium: scene exit.** `_exit_tree()` in `scripts/run_scene.gd` (~3792) doesn't cancel the prewarm, and the queued
   callback binds a typed `Node` (`scripts/pass_preview_prewarm.gd` ~49). Reproduction: select `shadow_step`, wait five
   frames, `queue_free()` the scene → "Cannot convert argument 1 from Object to Object" and the queue stays
   `done=false`. Cancel on scene exit, and have the callback hold the scene's instance id (or a weakref) and reject a
   freed scene. Regression test: that exact reproduction, no error output, queue done/cancelled.
2. **Medium: warm frames over budget on heavier cards.** With `witchglass_double` on the ordinary fixture, warm callbacks
   take 11.7 ms (click) / 14.8 ms (drag); the allowance is 10 ms.
   - First split the work so one warm frame runs at most one indivisible step: resolving the player's action for a
     tile, one enemy's preview step, or building the summary. Never two of them in one frame if the first took
     ≥ 3 ms.
   - If one indivisible step still exceeds 10 ms, profile it, name the function and its cost, and optimize its hot path
     only in ways that cannot change results (memoize pure lookups, avoid repeated deep copies). Prove it with the
     forecast oracle.
   - If it's still over 10 ms after that, stop and report the step, the numbers and what you tried. Don't raise the
     budget.
   - Add `witchglass_double` (ordinary fixture, click and drag) to the benchmark's warmed sweep and warm-cost budget.
3. **Low: `--no-profile`.** The revisit checks fail in that mode because instrumentation is off. Count cache hits with
   counters that don't depend on instrumentation, so both modes assert the same thing.
4. **Surviving mutants.** Add assertions that catch them:
   - removing the source-cache bound (fill past 256 and assert the size stays ≤ 256, oldest evicted first);
   - raising the per-frame slice budget (drive the queue with an injected clock or a step-cost stub and assert it
     yields once the 6 ms threshold is crossed).

Re-run only: the new suite (with the mutations above), the approach suite/probe, `tests/spx07_hover_benchmark.gd
--fresh` and `--fresh --no-profile` (report the table including witchglass_double), `full_scene_controls_program`.
No full suites.
