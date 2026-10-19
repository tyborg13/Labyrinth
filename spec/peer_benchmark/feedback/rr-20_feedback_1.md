# rr-20 feedback 1 (director)

1. **Green rule (director decision; it replaces the zero-green gate).**
   - The gate targets chroma-key residue only. A texel is residue when G ≥ max(R, B) + 12 AND G ≥ 1.5 × max(R, B).
   - In the derived presentation (pieces, continuations, hidden fills, rests), replace each residue texel with the
     nearest non-residue texel of the same piece, as the Mirror did. Protected source art stays unchanged.
   - Texels inside a declared feature mask are exempt (the Weaver's green eye).
   - Olive and brown paint outside the band is legitimate and stays.
   - The gate then requires zero residue texels outside features in every presented frame.
   - Your `TODO_DESIGN_rear_green_texel`, (0, 26, 7) at rear (125, 54), is key residue and gets cleaned this way.
2. **Death boot clamp:** accepted. A 1 px boot shift from the reach clamp at the end of death is fine. Report it in the
   proof; don't change the motion.
3. Then all headless gates pass. List the exact windowed sequence; the director runs density, rest, native, sheets,
   idle, production and review. Proof captures stay gitignored. No full suites.
