# det-04 feedback 1 (from the Codex review of 6c3459bad)

The root-cause fix holds: the real combat-feel program passes, and 27/27 production timing mutations are caught. Fix the
cleanup itself:

1. **Medium: async cleanup must finish before the caller resumes.** `tests/helpers/presentation_test_clock.gd` ~12:
   after an awaited early return or failed assertion, the caller saw clock 1012345 instead of 1000000. Restoration ran
   only after the caller had resumed. Own cleanup in an outer wrapper that restores all state before it forwards
   completion. Regressions: early return after an await, and failure after an await. Both show restored state at the
   caller's first resumed line.
2. **Medium: restore the window's `content_scale_factor`** (~85; size and embedding are already restored). Reproduction:
   seed 1.25, await `movement_undo_suite.run_live`, and the scale ends at 1.0. Regression with a non-default scale.
3. **Low: make the cleanup guards bite** (`tests/helpers/timing_suite_driver.gd` ~113):
   - seed a distinct clock sentinel, not zero;
   - mutate nested properties in place so a shallow snapshot fails;
   - change an audio bus property and assert it's restored.
   Each of the three surviving mutants must fail. Also add a Python proof test with the mutation environment variable
   populated, so removing its cleanup fails.

Note: the two full-run failures in the review copy are not yours. Skybolt's text check was fixed on integration
(c23049280), and the review copy simply had no emblem import cache. Merge `codex/peer-benchmark` into your branch?
No: the director does that at merge time.

Re-run the host programs (alone, then one run under load), the mutation proof and the proof tests. No full suites.
