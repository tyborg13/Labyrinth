# rr-31 feedback 2 (director: native frames judged; finish the seams)

**Director decision on round 1:** the image gates can't separate approved motion from the old tearing, so they stay as
diagnostics only. Acceptance is the director's visual judgment plus the existing rr-30 native gates, which passed for
the approved rigs.

**Judged on your round-1 native frames:**
- `/Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/proof/rr-30/rr31_round1_front_actions_2x.png`
- `/Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/proof/rr-30/rr31_round1_rear_actions_2x.png`
- Rows in each: lob, brace, scatter, death; six frames each at 2×.

With the new motion the arms stay attached in every action, and the rear view is nearly clean. That's the owner's main
complaint fixed. What remains is small and specific.

1. **The seven native seam holes.** `RR30 NATIVE GATES: FAIL (7 errors)`:
   - front lob 33 and 67, rear brace 7, 8, 47 and 48, and front scatter 39: "new joint-seam hole larger than 1px";
   - on the 2× sheets: dark 1–3 px notches at the far shoulder strap through the front lob and death, and specks at the
     far forearm and hip in the front brace.
   Attribute each to its pieces and fix it at the source (cover shape or registration). The existing rr-30 native gate
   must reach 0 errors in both views.
2. **Make the rr-31 image gates non-blocking.**
   - Keep them as diagnostics: they write their report but never fail a proof stage.
   - Make sure `sheets`, `production` and `review` aren't blocked by them. They refused to run, so the director has no
     review clip.
   - The rr-30 native gates stay blocking.
3. Keep the motion data, identity, rests, stretch, flap, walk fit and density exactly as they are.
4. Focused tests only. This is the unit's last fix round in this session. The director reruns all eight windowed
   stages after it.
