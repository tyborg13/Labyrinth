# rr-05 feedback 8 — replace the silhouette backing with per-joint seam underlays

## Verdict on round 7
I'm rejecting the full-silhouette backing. In `output/rr-05/feedback7/cpu-evidence/contact_sheet.png` (right column)
it shows as black blobs around the crown in the shell and death poses, wherever petals swing away. Remove it. Your
numbers explain it: inside-body visibility was tiny (≤ 0.16%), so the real interior cracks are small, while the static
shape protrudes wherever outer parts move (up to 4,191 px).

## Decision: per-joint seam underlays
The remaining interior cracks are joints where the parent part is drawn above its child. The parent's bleed can't go
under the child without being drawn over it.
- For every pair of parts that are adjacent at rest (shared boundary ≥ 3 px), create a seam underlay node:
  - a band along their shared boundary, with width = that joint's derived maximum sampled separation + 1 px;
  - it extends on both sides of the boundary, clipped to the union of the two parts' rest regions;
  - paint: edge-texel replication of the parent's paint (the part nearer the root);
  - drawn beneath every part, attached to the parent's bone, through the same stepped presentation.
- Features are never covered by or used as underlay paint. Rest identity stays 0 px. Keep the 1,376 bleed texels.

## Gates (replacing the hole gate)
- **Interior tears (hard).** No background pixel inside the rest silhouette eroded by 1 px, in any pose of any clip,
  on CPU or native.
- **Natural negative space.** New enclosed holes outside the rest silhouette are allowed (limbs curling against the
  body). Report the per-clip maximum; it isn't a failure.
- **Underlay protrusion.** Underlay visible outside the union of the posed parts must be at most 2 px wide anywhere,
  so it reads as part of the outline. Report the maximum width per clip.
- Detached components, features and shimmer are unchanged.

If a specific pose can't meet the interior-tear gate, list it as before (clip, pose, pixels, joint), and I'll decide.
Then hand back `--from-native --creature shale_bloomer`. I judge the native MP4 myself; the gates are necessary, not
sufficient.
