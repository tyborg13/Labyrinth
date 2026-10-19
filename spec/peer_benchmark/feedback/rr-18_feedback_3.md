# rr-18 feedback 3 (director): close the last rear pockets

The director ran the windowed chain at 2cf77708e. Density, rest, idle (252 frames) and production (940 frames per view)
pass, and the Mirror reads well on the board. The native gates reproduce exactly your 13 rear pockets, so sheets and
review refused to run. This is the last round in this session; fix these and hand back:

1. **The 13 rear continuation pockets** (move 1; refraction 13–17, 58, 59; guard 7, 8, 16 (two), 47, 48). Each pocket
   maps a pixel into an existing continuation. Extend the affected continuations so the moving neighbour never exposes
   a hole there. Propagate the covered boulder's own edge texels outward, the way rr-15 built the Thrall's joint
   continuations. No new paint, no exemptions, no motion changes.
2. **Green residue.** The rear guard 16 crop shows a teal-green pixel inside an exposed continuation, which is chroma
   key residue. In every continuation and hidden fill of both views, replace any texel with G > R + 12 and G > B + 12 by
   the nearest non-green texel of the same boulder. Add a gate: no green-dominant texel in any presented frame.
3. **No flat patches.** The same crop shows a straight-edged, flat light-grey rectangle of continuation. Continuations
   follow the boulder's rounded edge and its surface texels, never a flat rectangle (spec §1: the hidden fill must read
   as the same surface).
4. Then every gate passes headless in both views. List the windowed sequence; the director re-runs native, sheets,
   production and review.

Proof captures stay gitignored. No full suites.
