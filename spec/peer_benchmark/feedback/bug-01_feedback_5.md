# bug-01 feedback 5: peer-review fixes (review aa3a6bf58)

The review is in `spec/peer_benchmark/feedback/bug-01_review_aa3a6bf58.md` in the integration worktree. Your
branch already has integration merged at aa3a6bf58, so work on top of it.

1. **Invalidate only on a real change in effective opacity (Medium).** `scripts/board_scene_prop_redraws.gd` queues
   a pillar whenever prop obstruction changes, even when the pillar's drawn alpha stays the same. Example: hero
   `(5,5)`, pillar `(6,6)`, add a brazier at `(5,4)`; the alpha stays `0.32` but the pillar is queued anyway.
   - For each candidate pillar, compute its effective alpha before and after the change. Use the same function the
     draw path uses, with no parallel copy of the rule, and account for unchanged actors and objects.
   - Queue a redraw only when the alpha differs.
2. **Regression strength.**
   - Extend the case-21 regression in `tests/static_floor_cache_equivalence_test.gd` with negative assertions:
     - a pillar the change doesn't affect is not queued;
     - a pillar that something else already obstructs (the example above) is not queued.
   - Keep the positive case.
   - The mutation "redraw every candidate unconditionally" must fail the test. Show that it does, then restore.
3. **Unused constant (Low).**
   - Remove `NATIVE_DUMP_TIMEOUT_SECONDS` from `tests/fixtures/static_floor_diff_capture.gd`.
   - In the handoff (`tests/bug_01_findings.md`), document that the cap is the runner's real `--timeout 600`.

Proof:
- the four focused programs and `static_floor_cache_equivalence_test`, headless;
- the mutation result for item 2;
- the full Godot suite through the parallel runner, and the Python suite.

Don't touch `tests/quarantine.json`. New typed arrays use the no-literal declaration (`var x: Array[T]`).
