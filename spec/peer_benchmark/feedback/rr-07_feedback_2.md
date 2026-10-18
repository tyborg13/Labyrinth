# rr-07 feedback 2: native near-ties from GPU sub-texel precision (director diagnosis)

The windowed proof ran for both creatures. Native capture, motion gates and pixel samples PASS. `RR07 NATIVE GATES`
fails 4 frames per creature (`proof/native/verification.json`):
- Seer: front/skirt_far/67; rear/seam_fore_far_hand_far/86 and /130; rear/hand_near/136.
- Thrall: rear/seam_hand_near_club/26; rear/seam_torso_upper_far/18; rear/fore_near/116 and hidden_fore_near/116.

## Diagnosis (director)
- The "after" (presented, snapped) captures match exactly: 0 changed pixels. Every mismatch is in the **"before"**
  capture, the unsnapped pose used as the shimmer baseline (19 px for skirt_far/67, 4 px for the others).
- The transforms carry a small rotation (0.39°, 1.03°). Every mismatched pixel's texel coordinate lies within
  **0.00006–0.0013 texel** of a texel boundary. These are near-ties, not exact ties.
- GPUs quantise texture coordinates to 8 bits of sub-texel precision (a 1/256 step), so any sample within half a step
  (1/512 ≈ 0.00195 texel) of a boundary can resolve to either neighbour.
- The CPU model's `EXACT_TIE_EPSILON` (1e-6) only covers exact ties. That was enough for rr-05's unrotated cases, not
  for rotated "before" poses.

## Decision
1. In `tools/maquette_motion/raster.py`, the tie band becomes the GPU sub-texel half step: a coordinate within **1/512
   texel** of an integer is a tie. Rename the constant `SUBTEXEL_TIE_EPSILON = 1/512`, with a comment citing the 8-bit
   sub-texel precision and these rr-07 frames.
2. Everything else in rr-05's rule stays:
   - only the two in-range neighbours are candidates;
   - the per-frame choice must be consistent across held frames, so a held flip still fails;
   - non-tie pixels keep the strict rule;
   - the tie report stays.
3. Tests:
   - Add retained fixtures from these frames (Seer front skirt_far/67 "before"; Thrall rear fore_near/116 "before").
   - The three rr-05 fixtures still pass.
   - A pixel 0.01 texel from a boundary, set to the other neighbour, must still fail.
   - Re-run rr-05's Bloomer and Wisp native gates against their committed proof records; they must still pass.
4. Re-gate both rr-07 creatures against the existing native captures, with no recapture: zero errors. Then finish the
   rest of `rr07_proof.sh` from the review step, or give me the exact resume commands (review MP4, density rest
   rebake, production capture).

This is a shared pipeline change: keep it minimal and documented. rr-06 will pick it up at merge.
