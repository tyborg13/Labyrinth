# perf-04 feedback 1 (from the Codex review of 26e30a0f1; evidence /private/tmp/perf-04-review/)

The director accepts the ordinary-hover result (5.40 ms headless; native min-of-3 12.6 ms), so finding 4 is closed. No
more optimisation is needed. Finding 5 (the deleted ledger row) is a base-advance artifact: ignore it, don't touch
spec/. Fix the correctness issues:

1. **Blocking: the warmup must never leave the retained HUD stale.** `scripts/combat_board_view.gd` ~3326 runs the
   warmup after retained sync, so a later hover flush sees an unchanged source and skips the sync. Reproduction:
   `Arena.arena()`, hover the first enemy, add an obstacle over its intent rectangle, then controller-focus that enemy.
   The retained HUD differs from the parent. Warm before the retained sync (or sync and redraw the warmed result), and
   add that reproduction as a regression.
2. **Medium: detaching must not drop the final hover update** (~4255). The pending state is cleared before the
   tree-membership check. Keep it dirty across detach and reschedule on tree entry. Regression: hover enemy 2, detach
   before the deferred flush, reattach, and the HUD shows enemy 2.
3. **Medium: the equivalence checks must catch the 8 surviving mutants** (list in
   /private/tmp/perf-04-review/mutations.json):
   - the HUD registration key, warmup hover restoration, badge catalog keys and the torch cycling clock;
   - the overlay leader, burrow, burst and zone selectors.
   Make the reference independent of the candidate's warmup and submission behaviour. Exercise retained layers (don't
   disable them), cutout-pose and catalog invalidation, and the real overlay and torch draw paths across changing
   inputs and clocks. Report each mutant as caught.

Re-run the harness `--equivalence-only`, the hover equivalence test, warband_ui, card_keywords and
full_scene_controls_program. No full suites.
