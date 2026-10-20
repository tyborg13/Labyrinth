# rr-27 feedback 2 (director): apply the rear Tether path (0, 90)

Rear repair accepted: census clean in both views, zero pose rows changed.

**`TODO_DESIGN_REAR_TETHER_PATH` (decided): use (F, L) = (0, 90).**
- My criterion (b) was wrong. The axis test flags A's own hold, which I chose.
- Judged by eye on your strips:
  - (0, 90) raises the tube along the near side first, swings it up through about four frames, and stands it
    upright.
  - The lowering mirrors that.
  - A swing across the body during the raise is natural. The front view's Tether swings across the chest too.
- The original defect was the held pose lying across the back, and A fixes it.
- (0, 90) also has the fewest crossings and flips of the three.

1. **Edit the director file** `spec/peer_benchmark/staged/rr-11/motion_tracks.json`, at
   `arc_thrall.clips.tether.view_keys.rear`:
   - `tube_tip.forward_px`: `[[0,0],[0.2,0],[0.35,65],[0.8,65],[0.9,0],[1,0]]`
   - `tube_tip.lift_px`: `[[0,0],[0.2,90],[0.35,153],[0.8,153],[0.9,90],[1,0]]`
   - Then import and compile through the existing pipeline (`rr15_motion_import.py` / `rr11_build.py` /
     `compile_motion`, as the case does today).
2. **Pose identity.** Only rear `tether` rows may change.
   - Update the Thrall pose-identity pins for exactly those rows, with a comment citing this feedback.
   - Every other row (front, and every other rear clip) stays byte-identical. Prove it.
3. **Census and gates.** Strict census: zero unmatched and zero pockets, both views, including the new rear tether
   frames. Rear reach and action-direction gates as before.
4. **Records and tests.**
   - Regenerate the headless records.
   - Focused tests only.
   - Re-list the `rr24_proof.sh` windowed sequence.
