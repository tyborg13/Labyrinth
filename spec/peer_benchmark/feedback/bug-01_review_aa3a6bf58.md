1. **Medium — invalidation is broader than the effective opacity change.** [board_scene_prop_redraws.gd:9](/private/tmp/labyrinth_codex/review/bug-01-aa3a6bf58/scripts/board_scene_prop_redraws.gd:9) compares prop obstruction alone. Reproduction: hero `(5,5)`, pillar `(6,6)`, add brazier `(5,4)`. The computed pillar alpha stays `0.32`, yet the helper queues it. Removing the helper eliminates that queue.

   Compare effective old/new obstruction, including unchanged actors and other objects. Add negative assertions for unaffected and already-obstructed pillars. The current [regression:384](/private/tmp/labyrinth_codex/review/bug-01-aa3a6bf58/tests/static_floor_cache_equivalence_test.gd:384) checks presence only: **unconditionally redrawing every candidate survives all 106 cases**.

2. **Low — unused timeout constant.** [static_floor_diff_capture.gd:9](/private/tmp/labyrinth_codex/review/bug-01-aa3a6bf58/tests/fixtures/static_floor_diff_capture.gd:9) defines `NATIVE_DUMP_TIMEOUT_SECONDS` without any consumer. The diagnostic handoff describes it as enforcing the cap. Remove it and document the actual CLI `--timeout 600`.

All four focused programs passed, plus health-ghost integration and the dump-enabled headless floor test. Floor result: **106 cases, 163,232 checks, zero errors or orphans**.

Mutation results: **9 caught, 1 survived**. Caught: omitted pillar fix, stale reserve mutation, cancellation-limit exhaustion, unreached owner boundary, unfrozen retention clock, unsettled HP, stale fresh-navigation setup, single-page fixture, and lax pixel comparator. Broad candidate invalidation survived. [Mutation evidence](/private/tmp/bug_01_review_evidence/mutations.json).

The reference/fixture corrections otherwise preserve assertions. Diagnostics remain test-only; no new typed-array literal initializers or production tunables were found. Native proof relies on the director’s supplied results; no windowed run was performed.

Every mutation was restored. HEAD remains `aa3a6bf585accd3ae3d744048fc93eac46d27daa`; checkout clean; quarantine untouched.

CHANGES REQUESTED