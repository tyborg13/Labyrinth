# rr-18 feedback 2 (director): seam calibration for a boulder golem

Good round: the gait, knees, supports and the density rest all pass. Decision on `TODO_DESIGN_source_gap_calibration`:

The Glacial Mirror is separate boulders held together by nothing visible. The painting already has air between many
boulders, and when a limb moves, that air may open further. That is in character. A hole through stone is not.

- **Allowed pocket:** every pixel of the pocket maps, through the inverse source coordinates of the pieces around it
  (you already compute these in `proof/seams.json`), to a pixel that is transparent in the approved painting of that
  view, or lies outside every boulder's painted silhouette and tuck. In other words, it's air between stones.
- **Still a failure:** any pocket containing a pixel that maps into a boulder's painted interior or into its tuck or
  continuation (a hole through stone, or a joint tearing open), and any pocket inside the torso/mirror silhouette.
- Implement this as a generic, data-driven rule in the Mirror's case (`seam_policy: "air_between_rigid_pieces"` or
  similar), not a list of frame exceptions. Keep the strict rule for every other figure. Add a regression for each
  side: an air pocket passes, and a synthetic hole punched through a boulder's interior fails.
- Report the remaining failures after the rule. If any remain, list them with crops; don't add exceptions.

Then list the windowed sequence again. Proof captures stay gitignored. No full suites.
