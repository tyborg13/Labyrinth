# rr-11 feedback 1 — director decisions for the three TODO_DESIGN items

The director committed your r0 as a checkpoint (3037f03e3) together with a **revised protected motion file**,
`spec/peer_benchmark/staged/rr-11/motion_tracks.json`. Re-import it byte for byte. Root cause of all three blockers: the
Thrall's legs are almost straight at rest, so any pose that raises the pelvis or puts a planted foot on the wrong side
of the hip overreaches. In each view, one leg is also foreshortened (front far 36 px; rear near 50 px). The director
measured the geometry (step vector front (−42.9, +21.5), rear (+42.9, −21.5)): a planted foot only fits within about
±0.08 of a step of the hip, and the short leg can't plant at all.

1. **`TODO_DESIGN_near_knee_direction` (decided).** The near rest knees bend 2.85° (front) and 5.05° (rear) against
   facing, essentially straight. Rule: a rest knee within **6°** of straight counts as straight for direction, so the
   per-view knee policy applies (toward facing: front screen-left, rear screen-right). Larger rest bends keep their rest
   side. Put the threshold in the Thrall's case anatomy (`knee_policy.near_straight_deg: 6`), not as a generic constant.
   The far legs (14.7° front, 7.8° rear) already bend toward facing and keep their rest side.
2. **Leg roles per view (new; small generic extension).** Add per-view leg roles to case anatomy: `stride` = the long,
   camera-side leg (front: near; rear: far), `trailing` = the foreshortened leg (front: far; rear: near). Motion keys
   address `foot_stride.*` and `foot_trailing.*`, and the runtime and compiler resolve them per view. List and test the
   extension; the Seer stays byte-identical.
3. **`TODO_DESIGN_move_foot_targets` (decided; data revised).** The new move clip has:
   - a stride foot with `world_step` and two planted steps per tile, lift 4 px;
   - a trailing foot with `forward_mode: "body"`, following the body with a 3 px shuffle between strides (never
     world-planted);
   - the pelvis never above rest, dipping 3 px after each stride landing.
   Replace the knee gate:
   - for each stride-foot swing, the peak knee bend is at least **15°**;
   - at that swing's apex, the swinging knee bends more than the stance knee;
   - every bent knee bends toward facing;
   - the stride foot's stance drift is at most **0.5 px**;
   - the trailing leg is exempt from the 15° peak but not from the direction check.
   Lift-off and touch-down frames are naturally near-straight; the old every-frame ≥15° rule was a director error.
4. **`TODO_DESIGN_jab_planted_feet` (decided; data revised).** The pelvis now sinks 3 px into the stroke; the stride foot
   stays planted, and the trailing foot follows the body (`forward_mode: "body"`). Planted-anchor gate: the stride foot
   only, at most 0.5 px.
5. **Proof captures stay gitignored:** add `experiments/cutouts/arc_thrall/rr11/proof/.gitignore` (`native/`,
   `native_rest/`, `native_failures/`, `idle_native/`, `production_native/`, `contact_sheets/`, `logs/`, `*.mp4`) before
   anything else.

If the revised data still can't satisfy a gate, stop and report the frames and numbers. Don't change the data and don't
relax a gate. Proof: headless focused tests, gates and mutations; list the exact windowed commands. No full suites.
