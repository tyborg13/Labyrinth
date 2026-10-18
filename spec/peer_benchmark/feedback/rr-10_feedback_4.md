# rr-10 feedback 4 — the remaining flags are real: deepen three tucks

Your calibrated gate is right. The director checked your crops: the remaining flags are small real seam openings, not
calibration. Examples: mark 30 and death 30 at the far wrist, move 9 at the near foot, ward 12 at the belt side. At
board scale the far hand reads as slightly detached from its cuff when it is raised or tipped.

The director committed your round as 477e6d24a, squashing r1–r3; proof captures and logs are now gitignored. Fix
these in the rig data and tucks, not in the gates:
1. **Wrist (fore sleeve ↔ hand, both arms).**
   - Extend each hand's hidden wrist continuation to 5 px under the cuff, along the forearm axis.
   - Weight the sleeve mesh's last 4 px of rows at the cuff 100% to `fore_<side>`, so the cuff stays rigid with the
     hand's parent and doesn't stretch away from the wrist.
   - The far wrist in mark, bolt and death must close.
2. **Foot under the hem (both feet).** Extend each foot's hidden top continuation to 4 px up under the robe hem.
3. **Robe top at the belt sides.** Extend the robe's hidden top continuation under the torso from 3 px to 5 px across
   its full width, including both side edges where ward 12 opens.
4. **Gates:**
   - the calibrated hole gate must pass headlessly on every sampled pose;
   - keep the elbow mutation;
   - add wrist and foot mutations that reopen these specific seams.

No motion, art or gate-threshold changes. Rerun the headless suites, then stop. The director reruns `native` and
`sheets`.
