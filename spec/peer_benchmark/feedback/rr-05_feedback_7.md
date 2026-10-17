# rr-05 feedback 7 — static silhouette backing (director decision)

Bleed fixed what it can. The remaining 451 hole poses are structural. When a part drawn behind its neighbours swings
away, it uncovers its own rest area, and no static support exists underneath. That part's bleed travels with it.

## Decision: silhouette backing layer, generic for every maquette cutout rig
- **Shape and colour.** Add one backing node per view: the creature's rest silhouette (approved rest alpha), filled
  with a single flat colour. The colour is the darkest non-outline interior tone of the approved painting. Derive it as
  the 10th-percentile luminance of the opaque interior pixels, excluding the 1 px outline ring and the features.
  Record the derived colour in the case data.
- **Placement and motion.** Draw it beneath every part and attach it to the root body bone (Bloomer: `trunk`; Wisp:
  `core`). It moves only with that bone, through the same stepped and snapped presentation.
- **Visibility and gates.**
  - At rest it is fully covered: rest identity stays 0 px in all views.
  - In motion, any gap inside the rest silhouette shows deep shadow instead of background, which reads as depth
    between roots rather than a tear.
  - The hole gate counts backing pixels as body, not background. Detached-component and feature gates are unchanged.
  - Add a gate that backing pixels never appear outside the silhouette of the posed parts' union, so the backing
    never shows beyond the creature's outline. Add a gate that backing visible inside the body stays ≤ 3% of the
    body's pixels in any pose. Report the per-clip maximum; I want to see it.
- **Scope.** It applies to the Bloomer and the Wisp. The Wisp should show ~0 visible backing.
- **Cleanup.** Keep the 1,376 bleed texels; they reduce how much backing ever shows. Revert the idle key edit
  (`tendril_high_r.raise_deg (0.5, 4)` back to `(0.5, 5)`). It didn't help, and the backing covers that gap.

Report the remaining holes, if any. They can now only lie outside the rest silhouette: give the clip, pose and
pixels, and I'll decide. Re-run the Bloomer gates, the focused suites, and the Python suite after I've run the Wisp
adoption (the 24 Python failures are the Wisp's pending adoption, which I'm running now). Hand back the
`--from-native --creature shale_bloomer` command.
