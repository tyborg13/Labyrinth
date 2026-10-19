# rr-24 feedback 1 (director): your two design questions, re-pinned baselines, seams

1. **`TODO_DESIGN_COLLAR_DEATH_CLEARANCE` (decided).** The owner's complaint was the collar covering the mouth. In
   `death` the head bows, and the chin resting on the band is natural.
   - The collar requirement becomes a draw-order rule: wherever the head and the collar overlap, the head draws above
     the collar, so no collar pixel ever covers a head pixel in any presented frame of any clip.
   - Contact is allowed.
   - Gate it on rendered ownership, not geometric clearance, and report the frames with contact.
2. **`TODO_DESIGN_PRESENTED_NEGATIVE_SPACE` (decided).** An enclosed transparent pocket between the skirt or belt and a
   leg passes as natural negative space when every pixel maps to air in the approved mq7b painting: outside every
   piece's painted area and tuck. This is the rule the Glacial Mirror uses for air between rigid pieces, here scoped to
   the Thrall's skirt and leg boundary.
   - Front `tether` frame 17 (`[265,305,268,309]`) is such a pocket.
   - A hole through skin, cloth or a joint still fails.
   - Make it a case-level policy, not frame exceptions. Report every pocket it passes, with its bounds.
3. **Re-pin the preservation baselines to the repaint.** The rr-15 and gait-01 tests pin the old mq7 paint, crops and
   seam fixtures. The owner-requested repaint supersedes them for the Thrall's own paths only.
   - Re-pin those assertions to the rr-24 baseline (the mq7b paintings and this unit's director-data commit).
   - Keep every other figure's assertions exactly as they are.
   - List each re-pinned test and its old and new baselines.
4. **Remaining CPU seam failures** (51 front / 5 rear frames). After rules 1 and 2, fix every failure that's left by
   its root cause: continuations and hidden fills from the pieces' own edge texels. No exemptions.
5. Then every Thrall gate passes headless in both views, including the gait-01 walk gates. Focused tests only. List
   the exact windowed sequence, including `crops`.
