Two findings remain.

1. **Blocking — resuming a victory can lose its banked Embers.**  
   [opening_boon_recovery.gd:42](/private/tmp/labyrinth_codex/review/boon-01-c67fa8aa6/scripts/opening_boon_recovery.gd:42) treats a recorded result as acknowledgment of wallet settlement. However, [run_scene.gd:30175](/private/tmp/labyrinth_codex/review/boon-01-c67fa8aa6/scripts/run_scene.gd:30175) can repair that result while retaining the old profile balance.

   Reproduction: fail profile writes during victory settlement and Leave nothing, restore writes, resume in a fresh scene, then start another descent. The saved victory contains **120 Embers**; resume leaves the disk bank at **0**; the next descent receives **0**. [Reproduction log](/private/tmp/boon01-delta-cold-resume.log).

   **Fix:** make resume repair preserve the newer terminal snapshot’s settled wallet before acknowledging its result. Add this resume-before-replacement regression. A temporary terminal-aware repair made the reproduction pass; it was reverted.

2. **Medium — two new guard removals survive the regression coverage.**  
   [opening_boon_recovery_test.gd:58](/private/tmp/labyrinth_codex/review/boon-01-c67fa8aa6/tests/opening_boon_recovery_test.gd:58) blocks every profile write, so the later new-descent write masks removal of the acknowledgment-failure guard. At [line 171](/private/tmp/labyrinth_codex/review/boon-01-c67fa8aa6/tests/opening_boon_recovery_test.gd:171), terminal preparation settles the bookkeeping before rollback testing, masking removal of terminal-flag restoration.

   **Fix:** inject a one-shot acknowledgment failure and test rollback from an unprocessed terminal snapshot. [Reviewer experiments](/private/tmp/boon01-delta-guard-experiments.json) pass on the original code and catch both removals.

The original Rapier replacement and Save & Quit receipt reproductions now pass. All three previously surviving mutations are caught. Across **10 guard mutations: 8 caught, 2 survived**, with no parser failures. [Detailed results](/private/tmp/boon01-delta-all-mutations.json).

Additional checks passed:

- Partial receipt delivery, failed acknowledgment, cold-store replay, ordering and deduplication.
- Fifty interrupted runs: **150 unique receipts**, draining to **zero pending**.
- Schema-5 profiles with absent and existing outboxes.
- Purge selection, confirmation, text and effects at data counts **1 and 3**.
- All **108 relic presentations**: required padding, maximum five lines.
- Fresh boon, recovery, probe, recap, menu, UI lint, balance and whitespace checks.

Reviewed submitted full-suite logs: Godot **835.208s**; Python **617 tests in 481.224s**, 61 skipped. Inspected the director’s supplied capture. No Windows typed-array violations, boon-related merge conflicts, scope creep, dead code or stray files found.

Every mutation and experiment was reverted. HEAD remains `c67fa8aa63a4d5c72093fc29f2252da44d0a1463`; checkout is clean. No commits or pushes made.

CHANGES REQUESTED