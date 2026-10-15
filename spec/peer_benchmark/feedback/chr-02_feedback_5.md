# chr-02 — round 5 (peer SIGNOFF 99d872fa5 with notes; small cleanup before merge)

1. Remove the 12 `output/` files the round-4 commit picked up (logs, measurements JSON and the stale
   `output/chr02_candidate_test.gd`); delete them from the worktree (I commit). Nothing under `output/` belongs in this unit.
2. Test gap: a mutant that keys the normalization cache by card id instead of definition content still passes. Add a
   test with two records holding the same card id with different stored changes; assert each record keeps its own.
3. Performance bound: the 5 ms absolute limit leaves ~15% headroom on an idle M5 Pro and will flake on slower machines.
   Fail above 10 ms; print the 5 ms target and the measured medians.

Proof: chronicle test, chronicle performance, UI lint. No full suite needed unless code outside tests changes.
