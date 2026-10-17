# boon-01 feedback 4 — delta review CHANGES on c67fa8aa6

Review: `spec/peer_benchmark/feedback/boon-01_review_c67fa8aa6.md`. The previous findings are fixed. Two remain:

1. **Blocking: resuming a victory can lose its banked Embers.**
   - Resume repair (`run_scene.gd:30175`) must keep the newer terminal snapshot's settled wallet before
     `opening_boon_recovery.gd` treats the recorded result as acknowledged.
   - Add the reviewer's resume-before-replacement regression: profile writes fail during victory settlement, Leave
     nothing, writes restored, resume in a fresh scene, new descent. The bank must hold 120 Embers and the next
     descent must receive them.
2. **Medium: two guard removals still survive.**
   - Replace the blanket write block with a one-shot acknowledgment failure, so the acknowledgment-failure guard is
     really exercised.
   - Test rollback from an unprocessed terminal snapshot, so removing the terminal-flag restoration fails the test.
   - The reviewer's experiments (`/private/tmp/boon01-delta-guard-experiments.json`) show the shape.

Keep the fix minimal and inside the recovery/settlement path. Re-run the focused boon and recovery suites and the
Python suite. For the full Godot suite, report the result if you can run it under 900 s; the serial suite is known to
be at the budget limit (qa-07 is fixing it), so a budget timeout alone is not a blocker.
