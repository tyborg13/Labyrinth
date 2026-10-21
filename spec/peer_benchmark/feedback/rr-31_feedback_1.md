# rr-31 feedback 1 (director: calibrate the image gates against owner-approved rigs)

Your measurement is right, and it shows the gate thresholds in my brief were wrong, not the motion. With "no more notch
pixels than at rest" and "at most 2 more frayed pixels than at rest", even the approved 2 px idle bob (budget 0.25 px)
and a pelvis drop of 0 px fail. The Seer, Thrall, Mirror and Mimic rigs the owner approved would fail the same gates.
So a gate has to separate *owner-approved motion* from *the round-3 tearing*, not from rest.

1. **Calibrate on approved rigs.**
   - Run the same three image gates (notch, frayed edge, interior contour), per joint zone, over every frame of every
     clip in both views of the owner-approved humanoid v2 rigs on integration: Hoarfrost Seer, Arc Thrall, Glacial
     Mirror and Hollow Mimic, plus the hero's cutout if it uses the same zones.
   - Use their CPU renders through the shared humanoid-cutout tooling, the cheapest faithful path.
   - Record the per-zone distributions in `rr31/calibration.json`.
2. **Thresholds.**
   - Per joint zone, allow up to the maximum the approved rigs reach, normalized per 100 px of figure height so the
     Mortar's larger figure is comparable.
   - Report the margin between those thresholds and the round-3 torn frames: lob32, brace20 and death78 in both views
     must still fail, with their excess stated.
   - If no threshold separates them, stop and report the overlap, frame by frame, instead of picking one.
3. **Re-run the budgets** with the calibrated gates and re-validate the director keys. Report any remaining
   `TODO_DESIGN_budget_*` with measured limits. Don't change the motion data.
4. **Seam holes:** report the 11 remaining seam-hole observations (clip, frame, location, pieces). Fix them at the
   source if the cause is construction.
5. Keep everything else: identity, rests, stretch, flap, walk fit and density. Focused tests only, no full suites. The
   two audio-child timeouts belong to the full suite and aren't this unit's concern.
