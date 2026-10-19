# rr-22 feedback 3 (director): crucible mask fragments — last round

The director merged integration into this branch again. It brings the updated crucible masks, the gait-01 scope-test
fix (your required PNG changes no longer trip it), and the rig spec's new negative-space rule.

1. **`TODO_DESIGN_crucible_mask_outside_fragments` (decided).** The masks were 1 px short of the rim's dark silhouette
   outline. `make_crucible_mask.py` now adds the rim's own outline where the pot meets the background: opaque pixels
   within 2 px of the polygon and of transparent background that are dark or grey. That's +31 front and +100 rear
   pixels; the masks are regenerated and protected.
   - Re-import them and keep exact mask ownership.
   - If any fragment still falls outside, report its pixels and its current owner. Don't reassign it yourself.
2. **Rig spec §1, "Negative space vs holes" (new, binding for every humanoid).** Pockets that map to air in the approved
   painting pass. A component already detached in the painting passes when it moves rigidly with its owner. Report the
   pockets passed.
3. Then every gate passes headless in both views. List the exact windowed sequence, including `walk`. Focused tests
   only. This is the last round of this session.
