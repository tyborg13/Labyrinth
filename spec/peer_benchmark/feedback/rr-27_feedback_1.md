# rr-27 feedback 1 (director): rear repair authorized; rear Tether = candidate A with a near-side raise

Front pockets: accepted (11 own-piece copies, `jab` and `death` only, no pose row changed).

1. **`TODO_DESIGN_REAR_COMPONENT_REPAIR` (decided): remove the two copied texels.**
   - Remove them from the continuation recipes:
     - `mq7b_continuation_leg_far`: texel (171,218);
     - `mq7b_continuation_leg_near`: texel (109,179).
   - These are copies in a continuation recipe, not paint. Your in-memory trial shows the removal passes all 335 rear
     frames and opens no pocket.
   - Apply it, then re-run the strict census in both views: zero unmatched, zero pockets.
2. **Rear Tether: candidate A, with a near-side raise.**
   - A's hold reads best: the tube stands upright beside the near shoulder, cap high.
   - But its raise flips the IK elbow between phases 0.1 and 0.3: elbow (185,197), then (258,171), then (232,248).
     The tube sweeps diagonally across the back for 2–3 frames.
   - Fix it with an intermediate key, so the tube rises along the near side before it swings forward. The same key on
     the way down.
   - Rear `view_keys` (`spec/peer_benchmark/staged/rr-11/motion_tracks.json`, `arc_thrall.clips.tether.view_keys.rear`),
     then recompile through the existing builder:
     - `tube_tip.forward_px`: `[[0,0],[0.2,F],[0.35,65],[0.8,65],[0.9,F],[1,0]]`
     - `tube_tip.lift_px`: `[[0,0],[0.2,L],[0.35,153],[0.8,153],[0.9,L],[1,0]]`
   - (F, L) is the first of (10, 110), (0, 90), (20, 130) that meets both conditions over 0–0.35 and 0.8–1.0:
     - **(a)** the elbow path is continuous, with no bend-direction flip between consecutive 60 fps frames;
     - **(b)** neither the upper arm nor the tube crosses the torso silhouette.
     - If none qualifies, stop and report all three. Don't choose another value.
   - The front view and every other channel are unchanged.
   - Report:
     - the pair you chose;
     - a raise strip (phases 0, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.35) and a lower strip (0.8, 0.85, 0.9, 0.95, 1.0)
       at 3×, with the cap and elbow per frame;
     - the changed pose rows (rear `tether` only, plus any rows from item 1).
3. **Records and proof.**
   - Regenerate the Thrall's headless records.
   - Focused tests only.
   - Re-list the exact `rr24_proof.sh` windowed sequence.
