# bug-01 feedback 6: moss opacity invalidation (re-review 6e9791666)

The re-review is in `spec/peer_benchmark/feedback/bug-01_review_6e9791666.md` in the integration worktree; the repro
log is in `bug-01_fb6/`.

1. **Moss tint changes must queue a redraw (Medium, regression).**
   - Moss on pillars and walls is tinted through `_foreground_blocker_tint` with its own rectangle (the moss draw
     around `combat_board_view.gd:7289` and `:7305`). The candidate list only has the body rectangle.
   - Repro: moss pillar `(6,6)`, hero `(6,5)`, lit brazier added at `(5,5)` (`width_scale` 0.60, `baseline_scale`
     0.36). Body alpha stays 0.32, but moss alpha goes 1.0 → 0.54, and no redraw is queued. Removal misses too.
   - Fix: every rectangle the draw path tints for a tile is a candidate, with the same tile id the draw path uses: body,
     moss and any other overlay (e.g. the pillar torch at `:7422`/`:7491`, if its tint can differ).
   - Better still, derive the candidate rectangles from one shared helper that the draw path also uses, so they can't
     drift apart again. Use your judgement on structure; behaviour must match drawing exactly.
2. **Regressions.**
   - Moss onset and moss removal (the repro above) each queue the tile.
   - The existing positive and negative cases still pass.
   - Show that reverting the moss candidates makes the new moss checks fail. Then restore.

Proof:
- the four focused programs and the dump-enabled floor test;
- the mutation results for item 2;
- the full Godot suite through the parallel runner, and the Python suite.

Don't touch `tests/quarantine.json`. Follow the typed-array rule for new code.
