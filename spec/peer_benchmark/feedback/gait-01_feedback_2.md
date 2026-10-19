# gait-01 feedback 2 (director): two windowed findings

The Codex re-review signed off fed320023. The director ran the windowed chains at that HEAD:
- Thrall: move probe PASS; production gates PASS.
- Mirror: move probe PASS; native and review PASS.
- The move sheets show both legs stepping in turn.

Two findings remain. Fix them, focused tests only:

1. **Thrall `move`: joint-seam holes larger than 1 px.** The native gate reports them in front frames 2, 9–11, 19, 25,
   31, 39–41 and 43–45, and rear frames 5 and 45. Logs: the director's `gait01_arc_thrall_native.log` and `_review.log`.
   - These come from the new projected leg scale: skinned legs stretched or shortened along the segment.
   - Find which seam opens (hip under the loincloth, knee or ankle) at the worst frame in each view.
   - Fix it at the root: continuation and hidden-fill coverage that follows the stretched segment, built from the
     pieces' own edge texels. No exemptions; keep the 0.78–1.22 clamp.
   - Add a regression that fails on fed320023 and passes after the fix.
2. **Mirror production: a planted foot moves 1 px.** Front `move`, near foot, presented frames 6, 7, 27, 34 and 35:
   "stance moved 1.000000 px". The headless gate passes, so the drift comes from whole-pixel presentation.
   - The root translates in whole pixels while the world-planted foot is placed relative to the root, so rounding can
     move the foot by one pixel.
   - Snap a stance foot's target in world (board) space, then derive its local position, so it never moves on screen
     while planted.
   - Apply this in shared gait code. Add a regression on the presented frames.
3. Then list the exact windowed commands for re-running `native` and `review` (Thrall) and `production` (Mirror).
   Proof captures stay gitignored.
