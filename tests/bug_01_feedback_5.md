# bug-01 feedback 5 — review aa3a6bf58 fixes

Changes are based on integration HEAD `aa3a6bf58` and remain uncommitted.
The owner's review was read from the integration worktree. No new peer review,
registration, quarantine edit or Git lifecycle action was performed.

## Requirements

1. `board_scene_prop_redraws.gd` now compares alpha returned by the draw path's
   `_foreground_blocker_tint()`, using complete old/new obstruction entries.
   The shared collector accepts an optional prop snapshot; actors, terrain,
   loot, traps and unchanged props retain their normal draw geometry. Candidate
   metadata identifies its actual drawing kind (pillar, wall, door, prop or
   terrain), so actor-specific pillar opacity uses the same rule as rendering.
   Only unequal effective alpha queues a candidate. The parallel prop-only
   overlap decision and duplicate prop-entry builder were removed.
2. The case-21 positive onset/removal assertions remain. New negatives ensure
   the unaffected pillar (2,2) is not queued. An independent real-board fixture
   checks the exact reviewer example: hero (5,5), pillar (6,6), brazier (5,4).
   It verifies the actor-obstructed alpha before and after both prop onset and
   removal, and verifies neither pillar is needlessly queued. The 106 native
   case definitions/numbers and their retained histories remain intact.
3. Removed the unused `NATIVE_DUMP_TIMEOUT_SECONDS`. The actual execution cap is
   the visual runner CLI argument **`--timeout 600`**, as documented in
   [bug_01_findings.md](bug_01_findings.md) and corrected in the diagnostic handoff.
   GDScript does not set or enforce that runner timeout.

All new `Array[T]` variables use no-literal declarations and `.assign()`.
No authored opacity, timing, assets, mechanics, saves, analytics or input paths
changed. The effective alpha rule remains solely in the existing draw function.

## Regression and mutation evidence

Before the production change, the extended floor program exited 1 with exactly:

```text
Scene prop onset must not redraw a pillar already obstructed by the hero
Scene prop removal must not redraw a pillar still obstructed by the hero
```

Report: `output/bug-01/qa-07-floor-feedback-5-before.json`; 106 cases, 163241
checks, zero orphans. The corrected program passed through qa-07, exit 0,
`qa-07-floor-feedback-5-fixed.json`, 15.608 s total.

The required negative control replaced the helper's condition with
`if true or previous_alpha != next_alpha:`, unconditionally queuing every
candidate. Qa-07 and its child both exited **1**, with no timeout or script error.
The floor program reported these six failed negative assertions:

```text
Scene prop onset must not redraw an unaffected pillar
Scene prop removal must not redraw an unaffected pillar
Scene prop onset must not redraw a pillar already obstructed by the hero
Scene prop onset behind hero must not redraw an unaffected pillar
Scene prop removal must not redraw a pillar still obstructed by the hero
Scene prop removal behind hero must not redraw an unaffected pillar
```

Mutation report: `output/bug-01/qa-07-floor-feedback-5-mutation.json`, 11.585 s
total; full child log in its adjacent `.logs/` directory. The coordinator restored
the correct condition in `finally` and verified the restored file hash:
`0f40ba3452a0a64d7eaff65515897a01d68753ae8e144d165c78c6e9ff6310a0`.
The dump-enabled headless floor program passed again after restoration:
`qa-07-floor-feedback-5-final.json`, exit 0, 16.305 s total:

```text
BUG_01 CAPTURE END_TO_END SMOKE: PASS (ClockedBoard + ClockedReference; GPU readback/fences mocked)
BUG_01 DIFF DUMP CHECKS: PASS (strict RGBA metrics, masks, crops, JSON, fresh fixture, isolated mutation)
RESTORED EMPTY BOARD LOGIC: PASS (native pixel proof requires window server)
STATIC FLOOR CACHE RESULT: {"cases":106,"checks":163241,"errors":[],"native":false,"orphans":0,"pixel_differences":[]}
```

## Full verification

All four focused programs passed through qa-07: `qa-07-feedback-5.json` has
`complete: true`, `failed: false`, every child `returncode: 0`, no timeouts,
83.551 s total. Exact result lines:

```text
PREPARED OTHER CHARACTER VIEW RESULT: {"boundaries":{"equipment":16,"magic":38},"cancellation_boundaries":14,"cases":48,"checks":1147,"differences":0,"errors":[],"orphans":0}
CHARACTER RETENTION RESULT: {"cases":121,"differences":0,"errors":[],"orphan_nodes":0,"preparation_frames":4375}
SHOP RETAINED CONTENT TEST RESULT: PASS
STATIC FLOOR CACHE RESULT: {"cases":106,"checks":163241,"errors":[],"native":false,"orphans":0,"pixel_differences":[]}
```

First full Godot run, concurrent with Python discovery: exit 1, log
`output/bug-01/godot-full-feedback-5.log`. All 34 parallel programs passed; the
sole failure was the existing, unmodified section-map wall-time assertion:

```text
Section map fast performance: FAIL (21 seeds x 6 sections; max section 257.063ms; max run 476.297ms; fallback 0)
MAIN BODY RUNTIME: 370.566 seconds
MAIN BODY ASSERTIONS: 385083
ERROR: seed=2426260977 section=6 257.063ms > 250ms
FULL SUITE RUNTIME: 467.129 seconds (budget 900 seconds)
TEST RESULT: FAIL (1 failure(s))
```

The measured map code uses `section_map_graph.gd`, with no board redraw calls.
No map code, assertion or timing limit was changed. A full rerun with the same
parallel runner and 900-second budget follows Python discovery, without that
concurrent load. That rerun exited **0**, with all 34 parallel programs passing;
log `output/bug-01/godot-full-feedback-5-recheck.log`:

```text
Section map fast performance: PASS (21 seeds x 6 sections; max section 173.441ms; max run 301.511ms; fallback 0)
MAIN BODY RUNTIME: 259.793 seconds
MAIN BODY ASSERTIONS: 385082
FULL SUITE RUNTIME: 352.703 seconds (budget 900 seconds)
TEST RESULT: PASS
```

The first run has one extra main-body assertion because the benchmark emits an
assertion for each measured failure. No assertions were removed. The initial
concurrent-load timing failure remains reported above; existing ObjectDB leak
warnings also remain. Focused bug-01 programs report zero orphan nodes.

Full Python discovery: exit 0, log `output/bug-01/python-feedback-5.log`:

```text
Ran 702 tests in 864.347s
OK (skipped=63)
```

The skips cover the existing optional audio and Blender environments; the 39
sound-lab checks passed separately in their prescribed environment. No
dependencies were added.

Prescribed sound-lab environment: exit 0, `Ran 39 tests in 37.913s` / `OK`,
log `python-sfx-feedback-5.log`. UI identity lint: exit 0,
`Ran 25 tests in 3.858s` / `OK`, log `ui-identity-feedback-5.log`.
Output hygiene: `OUTPUT GDIGNORE: PASS (14 folders; 3 referenced roots)`.
Review-fix hygiene also passed: no new typed-array initializers, restored helper
hash matches, unused constant removed, and quarantine untouched.
`git diff --check` passed after the final edits.

Commands (headless only):

```sh
python3 tools/program_suite_runner.py --task-id bug-01 --result-file output/bug-01/qa-07-feedback-5.json --suite prepared_other_character_view_test --suite retained_character_inventory_equivalence_test --suite shop_retained_content_test --suite static_floor_cache_equivalence_test
LABYRINTH_BUG_01_DIFF_DUMP=1 python3 tools/program_suite_runner.py --task-id bug-01 --result-file output/bug-01/qa-07-floor-feedback-5-final.json --suite static_floor_cache_equivalence_test
python3 tools/godot_task_runner.py --task-id bug-01 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
python3 -m unittest discover -s tests -p 'test_*.py' -v
/Users/borgerding/.cache/umbra-sfx/venv/bin/python -m unittest discover -s tests -p 'test_sfx_lab.py' -v
python3 tests/test_ui_identity_lint.py
python3 tools/output_gdignore.py
```

The full Godot command was executed twice with the same arguments: first
concurrently with Python, then after Python completed. Both logs are retained.

## Files changed

- `scripts/board_scene_prop_redraws.gd`: compare complete effective draw alpha.
- `scripts/combat_board_view.gd`: share entry collection with explicit old/new
  props and identify each candidate's drawing kind.
- `tests/static_floor_cache_equivalence_test.gd`: retain positives and wire the
  negative regressions into case-21 coverage.
- `tests/fixtures/static_floor_scene_prop_checks.gd`: real-board alpha/queue
  checks, with a separate fixture to preserve numbered case histories.
- `tests/fixtures/static_floor_diff_capture.gd`: remove unused timeout constant.
- `tests/bug_01_findings.md`, `tests/bug_01_diff_dump.md`, this handoff:
  corrected timeout ownership and review-fix evidence.
- `output/bug-01/feedback-5-contract.md` and observed logs/results.

## Chosen defaults / TODO_DESIGN / open issues

Test-only fixture fields reuse the review's hero (5,5), pillar (6,6) and brazier
(5,4), and the existing case-21 brazier asset/width/baseline fields. The unaffected
pillar (2,2) already exists in the case fixture. Expected actor opacity is read
from `Board.PILLAR_ACTOR_OBSTRUCTION_TINT`; no numeric alpha rule is copied.
No new production defaults or TODO_DESIGN placeholders. Open issue outside this
patch: the unmodified map benchmark exceeded its wall-time limit once under
concurrent load; it passed without that load. No limits or assertions were changed.

No windowed run was attempted. Native proof commands remain those in
[the feedback-4 handoff](bug_01_feedback_4.md), using the real `--timeout 600` cap;
strict equality and the isolated single-pixel mutation are unchanged.
