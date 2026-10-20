# rr-30 feedback 1 (director)

The stretch report found the real cause. Each arm and leg is one skinned piece over two bones, so every bend stretches
the texels across the joint, up to 17× at the elbow in `brace`. That's what the owner saw. Fix the construction, not the
gate.

1. **Limbs become rigid segments with covered joints.** This is the Glacial Mirror model (rr-18): rigid pieces, so air
   may open between them, but there's never a hole through a piece.
   - **Arms:**
     - `upper_<side>` (rigid);
     - `fore_<side>` (rigid, with the bracer as its own rigid child, `bracer_<side>`);
     - `hand_<side>` (rigid fist).
   - **Legs:** `thigh_<side>`, `shin_<side>`, `foot_<side>`, all rigid.
   - **Joint cover:**
     - Shoulder, elbow, wrist, hip, knee and ankle are each covered by own-piece continuation texels (rr-27/rr-28
       method) on the parent's side.
     - The child draws over the parent where the painting shows that overlap.
     - No tear under the canonical gate, in any frame of any clip, in both views.
   - The bracer and the face can no longer stretch because nothing is skinned. Keep the head rigid as it is.
2. **Stretch gate:** keep 12%.
   - Measure each piece's local deformation relative to that piece's declared uniform scale. The gait's declared
     `leg_scale` lengthening (up to 1.22) is intent, not stretch.
   - With rigid limbs every piece should read about 0%. Report the per-piece maximum.
3. **`TODO_DESIGN_flap_sway_waveform`:**
   - a sine, one full cycle per step;
   - phase origin at each foot's contact;
   - delayed by `lag_s` (0.06), with amplitude `deg` (4) on top of `flap.swing_deg`;
   - zero in the first and last 12% of the clip with a smoothstep ramp, so `move` starts and ends at rest.
4. **`TODO_DESIGN_mq11_director_04`:** use **director_08**, the owner's round-2 maquette.
5. **New inputs (owner, 2026-10-20: the rear flap "is like a thong").**
   - Integration now carries:
     - the round-2 rear raw `staged/mq11/paint/slag_mortar_rear_mq11_raw.png`, a wide back flap, composited below y 560;
     - its prompt `staged/paintovers/slag_mortar_rear_mq11b.md`;
     - its references `staged/mq11/paint/refs_slag_mortar_rear_mq11b/`;
     - the maquette at native acceptance director_08.
   - The director merged integration into your branch.
   - The director_08 delivery is at `tests/mq11_proof/director_08/slag_mortar/capture/` in your worktree.
   - Re-cut the rear from these, keeping 0 px rest.
6. Focused tests, then both full suites once. List the director's windowed commands.
