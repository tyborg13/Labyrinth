# rr-05 feedback 12: TODO_DESIGN_exposed_hidden_lightning_wisp_tail (director decision)

Round 11 is good: the Bloomer's dark slabs are gone, every Bloomer CPU gate passes, and the four bloated hidden parts
shrank 3–5×.

## Decision: the dark-slab gate blocks derived material only
- What the owner objected to was material the pipeline invented: nearest-edge or outline-filled support dilation,
  bleed and seam bands.
- The Wisp's flagged pixels are the original approved painted tail fill: 70 px of (29,18,26). That colour is a
  painted interior shadow. It never appears on the approved silhouette's outline ring, and it sits only 0.3 below the
  p5 cutoff. The owner approved this tail in motion.
- So:
  1. **Blocking scope.** The 3×3 dark-component check counts only exposed pixels whose source texel is **derived**:
     support dilation, bleed, seam bands and any other pipeline-generated texel. Use the texel provenance you already
     track.
  2. **Approved painted fills** (hidden-request outputs with provenance, plus approved visible paint) are not blocked.
     Report their largest exposed dark component per clip and view in the gate JSON and README, as information.
  3. Keep the dark-class definition, the donor exclusion, the seed-growth fix and the Bloomer socket edit exactly as in
     round 11.
  4. **Tests.**
     - The Bloomer's derived-slab regression still fails before the fix and passes after.
     - Add a test that a derived 3×3 dark block fails, while the same block in approved painted fill only reports.

## Proof
- CPU gates pass for both creatures, with the informational table for painted-fill exposures.
- All `tests/test_maquette_*.py`, plus the full Godot (parallel runner) and Python suites. The Bloomer adoption
  failures are expected until the director's windowed adoption.
- Then I run the full recapture and adoption for both creatures myself (`proof_for_design_owner.sh`, Bloomer then
  Wisp).
