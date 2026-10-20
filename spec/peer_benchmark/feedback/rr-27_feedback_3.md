# rr-27 feedback 3 (director): lower the rear Tether outward so the arm never folds

Census, direction and identity: accepted. Keep the raise as applied: the (0, 90) key at 0.2.

**`TODO_DESIGN_REAR_TETHER_REACH_CONFLICT` (decided): change the lowering path, not the gate.**
- The minimum-reach gate stops the arm folding up. The owner flagged that kind of crumple on the first Thrall.
- On the way down, the (0, 90) key at 0.9 pulls the cap past the shoulder: reach is 25.8 px at 0.843, against a
  60.5 px minimum.
- Lower the tube outward instead. From the high hold, the cap swings out past the near side at about shoulder height,
  then drops to rest. It stays well clear of the shoulder.

1. Replace only the 0.9 key, in both rear channels (`arc_thrall.clips.tether.view_keys.rear`). The 0.2 key stays (0, 90).
   - `tube_tip.forward_px`: `[[0,0],[0.2,0],[0.35,65],[0.8,65],[0.9,F],[1,0]]`
   - `tube_tip.lift_px`: `[[0,0],[0.2,90],[0.35,153],[0.8,153],[0.9,L],[1,0]]`
2. (F, L) is the first of (-40, 145), (-30, 120), (-50, 160) that meets both conditions over 0.8–1.0:
   - **(a)** the unchanged minimum-reach gate passes;
   - **(b)** there is no snapped bend-side flip.
   - If none qualifies, stop and report all three with strips. Don't change the threshold or pick another value.
3. Report:
   - the chosen pair;
   - a lower strip (0.8, 0.825, 0.85, 0.875, 0.9, 0.95, 1.0) at 3×, with the cap, elbow and reach per frame;
   - the updated rear-tether pose pin.
   - Every other row stays byte-identical.
   - Strict census in both views.
4. Focused tests only. All reach assertions must pass. Re-list the `rr24_proof.sh` sequence.
