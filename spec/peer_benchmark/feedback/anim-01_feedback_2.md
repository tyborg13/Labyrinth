# anim-01 feedback 2 (director, after re-review of ae37c6a16)

Per-frame cost and the 12 Hz stepping are verified. Work on top of HEAD. Do not commit.

1. **Unbounded mesh cache** (blocker): the cache is keyed by draw rect, so pan/zoom/moves add entries forever (~50 MB/s
   while panning). Decision: build every idle mesh in the **texture's local pixel space** (independent of the draw rect)
   and position/scale it at draw time with the canvas transform (`draw_set_transform` / transform on the draw call), so
   the cache key is (texture, facing/mirror, profile state) only — bounded by the number of idle states per texture
   (~27–39). Keep pixel-true integer art-pixel offsets (the transform only maps texture space to the rect, like the
   original quad draw). Add a test that pans and zooms the board for 600 frames and asserts the cache entry count and
   mesh count stay constant after the first cycle.
2. **Pre-battle stall** (~200 ms for 8 types): build idle states **lazily** on first use (one state at a time) instead of
   all templates in `prepare_texture`; keep the glow byte scan in preparation only for glow profiles. Target: asset prep
   within +20 ms of the parent for 8 types; first draw of a new state ≤ 1 ms.
3. **Pivot weight** (director decision): w = 1 at the sprite's **opaque top** row (as the brief says), 0 at the pivot.
   Keep the data amplitudes; the director will re-check the strips.
4. **Tests for the surviving mutants**: redraw only on change (no redraw request when the stepped sample is unchanged),
   mirror template sign (a mirrored sway frame equals the mirrored image of the unmirrored frame), the board shadow
   shrink in the actual draw, and no sub-pixel transform in `draw_body`.

Proof: idle tests, board wiring, the new pan/zoom memory test (report entries/meshes/memory over 600 frames), the
benchmark (prep, combat start, per-frame), full suite. List the windowed strip probe command.
