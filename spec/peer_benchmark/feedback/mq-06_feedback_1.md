# mq-06 feedback 1 — TODO_DESIGN_SEER_DEPTH decided

Good root cause. The turn is exact; the fit faked the far foot's screen height by lifting it 0.157 m instead of placing
it deeper. The owner sees the result as "wrong orientation entirely".

## Decision
1. **Floor contact.** Every part that touches the floor rests on the floor plane, at the near ankle's height:
   - the far foot;
   - the far side of the robe hem;
   - the staff butt, if it is lifted too.
   
   Report each one's height before and after.
2. **Correct along the front camera's view ray.** Move each lifted point, and the geometry that depends on it (the far
   leg under the robe, the hem vertices), along the front camera's view direction, down and away, until it reaches
   the floor.
   - An orthographic front projection is then unchanged, so the approved front painting stays registered.
   - The front delivery bytes should remain byte-identical. If shading or occlusion changes any front pixel, report the
     diff:
     - accept ≤ 0.5% of figure pixels;
     - no label silhouette may move by more than 2 px;
     - otherwise stop and report.
   - The front `joints_px.json` entries must not change by more than 1 px.
3. **Rebuild the rear** from the corrected body with the exact 180° turn (unchanged):
   - rear clay, part map, solos, rear joints and reports;
   - your regression must pass for the Seer;
   - rear fit IoU vs the old approved rear painting ≥ 0.65; report it.
4. **Generalise the guard.** Add a check that no maquette figure has a floor-contact point (ankle, hem, prop foot)
   more than 0.02 m above the floor. Run it over every committed figure and report any other offender. Don't fix other
   figures in this unit.

## Proof
- Update the 1024 sheet with the corrected rear: corrected rear clay | corrected rear part map | old approved rear
  painting.
- The front pixel-diff report.
- Focused tests and the full Python suite PASS.
