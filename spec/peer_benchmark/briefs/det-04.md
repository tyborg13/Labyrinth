# det-04 — Land det-03's timing hardening: the real programs must pass

## Header
- **What happened.** det-03 (branch `codex/det-03`, HEAD `bef6aaa44`) converted 15 timing suites to the game clock. Every
  suite passed through its own proof driver (`tests/helpers/timing_suite_driver.gd`), alone and under load. But merged
  into integration, the real program `tests/combat_feel_test.gd` fails deterministically, and it passes on the base
  without det-03. The failing checks are:
  - "Scene exit during a stop restores time";
  - "Late stop release replaces the pending frozen submission in the same frame";
  - "First native-order post-stop draw has the exact approved white peak".
  The merge was reverted. A later full suite on integration (without det-03) also failed once on "Hit-stop restores
  Fast", a wall-clock check that passes 2/2 alone, so it's a load flake. Convert it too.
  The driver runs suites one by one and calls methods directly; the real programs run several
  suites in one process (`combat_feel_suite.run` ends with `combat_pacing_regression_suite.run`, and so on).
- **Base:** integration with det-03 reapplied (commit 34173cecd, "Reapply ... det-03"); the worktree is ready. **Risk tier:**
  low (tests only).
- **Owned:** det-03's files (the timing suites and `tests/helpers/presentation_*`, `timing_suite_*`). No production
  code.

## Change
1. Find the root cause (a guess to check, not a given: an injected clock, a patched script, `Engine.time_scale` or
   another static/global left installed by one converted suite and read by a later check in the same process). Fix it
   so every converted suite restores all global state it touches, even on early return or failure.
2. Make the proof run what CI runs: `timing_suite_proof.py repeat` must also run every real program that hosts a
   changed suite (at least `tests/combat_feel_test.gd`, `tests/combat_pacing_regression_test.gd` /
   `combat_pacing_mutation_test.gd` if present, `tests/run_tests.gd`'s in-process suites that include them, and
   `tests/guided_combat_tutorial_test.gd`). Find them from `tests/headless_test_programs.json` and `tests/run_tests.gd`.
3. A regression proving the fix: run the suite that leaked, then the check that failed, in one process. It fails
   before the fix and passes after.

## Proof
- Every hosting program: 3 passes alone plus 1 under 4 busy loops (stop them after).
- The mutation proof still 100%.
- `tests.test_test_registration_audit`.
- The full Godot suite once at the end (`tests/run_tests.gd` via the task runner). Report its result line.

## Out of scope
The blocked-prompt production change (that's fix-08), any timing value.
