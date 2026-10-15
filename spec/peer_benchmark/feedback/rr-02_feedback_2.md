# rr-02 feedback 2 (director) — phase 2b: fill hidden material deterministically

Director review of phase 2a (native rest probe PASS; reel `/private/tmp/rr-02-mq3-render-v02`): the rig moves correctly
(the strike is the production fist punch, chain reel uses the hook — mapping is right). The magenta gaps are the only
blocker. Do not commit.

1. **Hidden fill tool** (`tools/maquette_cutout.py fill-hidden`, recorded in the case): for every hidden request, fill
   the magenta region at native resolution:
   - inpaint (OpenCV Telea, radius 3 px, or an equivalent deterministic diffusion fill if OpenCV is unavailable) from the
     part's own visible paint plus visible pixels of neighbouring parts listed with the **same material** in
     `paint_plan.md` (e.g. trousers from trousers, coat from coat; never from the helm, belt or tabard);
   - quantize the filled pixels to that part's palette: k-means (k = 6, fixed seed) over the part's visible pixels (fall
     back to the same-material neighbours' pixels if the part has < 40 visible pixels);
   - re-apply the one-pixel dark outline (tone (20,16,21), as the gate's clean_outline) wherever the filled region meets
     transparency in the part mask;
   - never change any pixel visible at rest (rest identity stays exact).
2. Record per request: method, palette, pixel counts and digests; keep the request images for provenance.
3. Re-run motion samples, validation, rest identity; regenerate the reel. List the windowed commands; the director
   judges the reel and may replace individual fills with painted material later.
