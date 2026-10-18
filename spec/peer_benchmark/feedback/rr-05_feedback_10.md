# rr-05 feedback 10: exact texel ties in the native check (director, final proof)

## Status
- The director's final windowed proof ran with two director edits, both uncommitted in your worktree. Keep both:
  - `joint_seams.py`: any equal-depth pair is owned by the part drawn lower.
  - `pixels.py`: boundary residual is 1%.
- I also fixed one line in `experiments/cutouts/shale_bloomer/rr05/proof_for_design_owner.sh`: the registry lookup now
  uses `item.get('dir')`, because density-registry prop entries have no `dir`.
- **Bloomer:** derivation, pixel gates, native capture, native verification, review MP4 and promotion all PASS. The run
  stopped only at that registry KeyError.
- **Wisp:** everything passes except native verification, which fails on one part and one held pose:
  - Part `rear/seam_core_arc_right`, frames 12–17.
  - The errors: "native part does not match its source transform", plus "unexplained shimmer (3px, 0.046875)" at 12.
- Native captures are in `output/rr-05/wisp-native/` and `output/rr-05/shale-native/`. Don't delete them; re-gate
  against them.

## Root cause (director diagnosis)
Three pixels on one scanline differ: (308,274), (311,274) and (312,274) on the 512 canvas.
- With the 8-bit vertex snap from `raster.nearest_quad`, the sample's `v` is **exactly 7.000** for all three, in both
  triangles. The snapped vertices are dyadic and the pixel centres are half-integers, so exact ties are common.
- The CPU model resolves `rint(v - 0.5)` to the even texel (row 6). Native Metal picked row 7: native matches the
  source row-7 texels exactly (60,48,78), (59,49,75) and transparent.
- So the "ties to even" rule (fitted to Wisp `arc_right` frames 18 and 90) isn't the GPU's rule. The tie goes to
  whichever side the GPU's interpolation rounding lands on, and the CPU can't reproduce that.
- Diagnostics: `experiments/cutouts/shale_bloomer/rr05/proof/seam_diag.py` and `seam_diag2.py` (director), as reproduced above.

## Decision: an exact tie may resolve either way; nothing else changes
1. **Mark ties in `raster.nearest_quad`.**
   - A pixel is a tie when its float64 `u` or `v`, after the vertex snap, is within `1e-6` of an integer.
   - Return or expose a second rendering in which every tied coordinate resolves to the other neighbour (the per-axis
     alternative), plus the tie mask. The default rendering keeps today's behaviour.
2. **Native match (`native_frame_matches` and the `ideal` comparison in the native loop).**
   - A tied pixel matches when native equals either candidate.
   - Every other pixel keeps the current rule and allowance (1 px + 1% of the union); don't change them.
3. **Shimmer residual.**
   - In the native path, build the ideal for each frame from the native frame's own tie choices. Where native equals a
     tie candidate, use that candidate as the ideal pixel. Then compute the residual as today.
   - So a tie resolved the same way in consecutive native frames explains nothing extra. A held pose whose native
     pixels flip between candidates still counts as held shimmer and fails. Held tolerance stays exactly 0.
4. **Report.** Per part and view, report the tied-pixel counts: total, and the maximum per frame. Show them for both
   creatures in the gate JSON and the README.
   - Guard: fail if more than 2% of a part's occupied pixels are tied in any frame. That would mean a broken
     transform, not a tie.
5. **Fixtures and tests.**
   - Keep the retained native fixtures for Wisp `arc_right` frames 18 and 90, and add this case: rear
     `seam_core_arc_right` frame 12. Each must pass because native equals one of the two candidates.
   - Also add a synthetic negative: a tied pixel set to a third colour must fail.
   - Update the `raster.py` docstring and comments: drop the claim that ties go to even, and state the exact-tie rule.

## Proof
- All `tests/test_maquette_*.py`.
- Re-run the native gate headless against the existing captures for both creatures: `pixel_gate(case,
  capture/'pixel_samples.json', capture)` plus `native_errors`. Expect 0 errors for both, and show the tie table.
- Then list the exact director command to finish adoption from the existing native captures for both creatures
  (`--from-native`, Bloomer then Wisp): review MP4, promotion, rebake, production captures. I run it under the lock.
- The full Godot suite through the parallel runner, and the Python suite.

Don't change gate tolerances, poses, motion, seams or art beyond the above.
