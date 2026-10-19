# rr-22 feedback 1 (director)

1. **Green rule (director decision; it replaces the zero-green gate).**
   - The gate targets chroma-key residue only. A texel is residue when G ≥ max(R, B) + 12 AND G ≥ 1.5 × max(R, B).
   - In the derived presentation (pieces, continuations, hidden fills, rests), replace each residue texel with the
     nearest non-residue texel of the same piece, as the Mirror did. Protected source art stays unchanged.
   - Texels inside a declared feature mask are exempt (the Weaver's green eye).
   - Olive and brown paint outside the band is legitimate and stays.
   - The gate then requires zero residue texels outside features in every presented frame.
   - Your `TODO_DESIGN_front_green_dominant_texels` is resolved by this rule. Most of the 28 approved-paint texels
     are probably olive leather and fall outside the band; any that are residue get cleaned.
2. **Ownership (`TODO_DESIGN_surface_ownership_masks`): use these colour rules instead of hand masks.**
   - **Crucible vs shoulder/harness (front).** Inside the maquette's mortar region, `mortar` owns only the crucible's
     own paint: the iron rim, bands and body (neutral greys, saturation < 0.25) and the molten top (oranges and yellows,
     hue 15–50°, value > 0.55). Skin and leather there (warm browns) go to the nearest non-mortar label (`torso` for
     the straps and back, `upper_near` for the shoulder). Keep each piece one connected component; isolated specks of
     under 4 px join their surrounding piece.
   - **Fist vs forearm (rear near arm).** The iron bracer belongs to `fore_near`. The fist (`hand_near`) is the skin
     beyond the bracer's lower edge along the forearm axis. The boundary follows the bracer's painted lower rim.
   - Show both cuts on the source-cut sheet with the boundaries outlined.
3. Then all headless gates pass. List the exact windowed sequence. Proof captures stay gitignored. No full suites.
