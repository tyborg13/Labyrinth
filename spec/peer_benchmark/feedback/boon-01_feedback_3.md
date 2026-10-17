# boon-01 feedback 3 — peer review CHANGES on 1382b6916 + one director layout fix

Full review: `spec/peer_benchmark/feedback/boon-01_review_1382b6916.md` (integration branch). Fix all four findings:

1. **Blocking: a consumed heirloom can come back on a replacement descent.** Before a new descent replaces an
   existing saved run, reconcile that run's newer progression (heirloom consumption, wallet) into the profile and
   acknowledge it durably.
   - Add a regression for the reviewer's reproduction: the profile write fails while taking the Rapier, writes are
     restored, and the next descent must not offer the Rapier.
2. **Medium: Save & Quit deletes unflushed terminal analytics receipts.** Preserve outstanding boon-event receipts, or
   transfer them, until delivery succeeds, across quit and replacement. Analytics stay local-first and append-only.
   - Add the reviewer's reproduction as a regression: forced append failure, Leave nothing, then Save & Quit. The
     events must be delivered once writes succeed, never duplicated.
3. **Medium: kill the three surviving mutations.**
   - The repeated-selection test must retry a piece that is still equipped.
   - Purge must refuse two copies when only one remains.
   - Inject save failures and assert that gameplay, progression and receipts are unchanged (rollback).
4. **Low:** use one data-backed Purge count everywhere; remove the literal `2`s. Remove `focus.remove_count`, or
   validate it.
5. **Director layout fix.** Pawned Light's relic text wraps to 5 lines with about 8 px of side padding
   (`output/boon-01/director_r2` once I copy it; it's the right card of `offer_with_heirloom`). Rules text on boon
   cards always keeps 24 px of side padding (width 252).
   - If it needs more than 4 lines at the body role, use the existing next-smaller body role.
   - Never exceed 5 lines at the smaller role.
   - Add a test that renders every relic in the pool as a Trinket and as Pawned Light text, and asserts the line
     and padding limits.

Re-run the focused suites, the probe headless semantics, and the full Godot and Python suites. Report the full-suite
time. I re-run the windowed proof afterwards.
