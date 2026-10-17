# bug-01 feedback 1 — native floor proof: freeze actor animation; drop the duplicate batcher

Verdict: all four failures are stale fixtures or references, with no production defect. Accepted.

1. **The native floor proof fails, and the cause is the test, not the floor.** I ran your command. Log and captures:
   `output/bug-01/director_native/`. It reports `RESTORED EMPTY BOARD NATIVE: FAIL`, with 38 cases where "complete
   board pixels must match original submissions" fails.
   - The restored capture equals the reference exactly (0 px). Restored vs fresh differs by 4,940 px, all inside the
     hero's bounds (682–837, 357–498). The hero's idle animation is at a different phase. The floor is identical.
   - Freeze every actor animation clock (hero idle, enemy idles, any board animation) at a fixed time before each
     native comparison. The alternative, masking actor layers, isn't wanted: freezing keeps them in the comparison.
   - Floor and board pixels stay strictly equal. Prove that the 38 cases pass natively, and that a deliberate
     floor-pixel mutation still fails.
2. **Drop the duplicate scheduler.**
   - I merged `codex/peer-benchmark` (b37559721). It brings qa-07's parallel runner (`tools/program_suite_runner.py`).
   - I restored `tests/helpers/program_sub_suites.gd` to the integration version, removing your registrations.
   - Delete `tests/helpers/program_sub_suite_batch.gd`, and rewrite `tools/bug_01_programs.gd` to run the four tests
     through `tools/program_suite_runner.py` (its `--suite` arguments), or drop it.
   - Registration happens when qa-08 lands: these four are in its quarantine, and I'll move them into its supplemental
     manifest. Don't register them yourself.
3. Re-run the four tests as programs through the qa-07 runner, plus the Python suite. Hand back the native command for
   me to re-run.
