# rr-21 feedback 1 (director)

1. **Green rule (director decision; it replaces the zero-green gate).**
   - The gate targets chroma-key residue only. A texel is residue when G ≥ max(R, B) + 12 AND G ≥ 1.5 × max(R, B).
   - In the derived presentation (pieces, continuations, hidden fills, rests), replace each residue texel with the
     nearest non-residue texel of the same piece, as the Mirror did. Protected source art stays unchanged.
   - Texels inside a declared feature mask are exempt (the Weaver's green eye).
   - Olive and brown paint outside the band is legitimate and stays.
   - The gate then requires zero residue texels outside features in every presented frame.
   - Declare the eye as a feature with its own mask: your `TODO_DESIGN_green_eye_gate` is resolved by the exemption.
2. **Front move (`TODO_DESIGN_front_move_knee_apex`, `TODO_DESIGN_front_move_supports`): the director changed the
   protected move clip** (`spec/peer_benchmark/staged/rr-21/motion_tracks.json`, integration 12dc76c04; copy it in byte
   for byte).
   - The hunch already bends the stance knee, so the stride foot now lifts 7 px.
   - The pelvis sits at rest height at each swing apex (0.2 and 0.65) and dips only 2 px after each landing.
   - Re-import and recompile. If the swing knee still bends less than the stance knee at an apex, or a stance foot
     still shifts, report the numbers; don't tune.
3. Then all headless gates pass. List the exact windowed sequence. Proof captures stay gitignored. No full suites.
