# rr-18 feedback 1 (director): answers to the four TODO_DESIGN items

1. **`move_supports` and `move_swing_apex`: the director replaced the move clip** (commit 7b06ce2b4,
   `spec/peer_benchmark/staged/rr-18/motion_tracks.json`). My step-to walk world-planted the foreshortened far leg, which
   can't reach. The new clip uses the Thrall's proven pattern:
   - `foot_stride` (camera-side long leg) plants two half-tile world steps with a 5 px lift;
   - `foot_trailing` follows the body (`forward_mode: body`) with a 2 px / 3 px shuffle between strides;
   - the pelvis never rises above rest and dips 3 px after each landing.

   Re-import it byte for byte and recompile. If a swing apex still bends less than the stance knee or a support slides,
   report the numbers; don't tune.
2. **`near_knee_facing`**: the boulder knees rest bent about 9° backward in both views (front near leg: thigh 17.9°,
   shin 8.9° from vertical; rear similar). Declare them near-straight in the Mirror's case anatomy:
   `knee_policy.near_straight_deg = 10` for both legs in both views. Rest bends up to 10° count as straight, and swing
   bends go toward the facing (§3), as for the Thrall.
3. **`density_rest_identity`**: follow the Thrall and Capacitor precedent.
   - The authoring cut stays exact against the paintings in source space (0 px).
   - The production rest is the density pipeline's output (front `clean`, rear `regrid` 1.22 by the board-density
     rule), sealed by the director's windowed `rest` step.
   - Production rest identity is measured against that density-processed rest, not the raw painting.
   - No density override.
4. Then all gates (knees, supports, reach, direction coverage, seams, production rest) must pass headless. List the
   exact windowed sequence again. Proof captures stay gitignored. No full suites.
