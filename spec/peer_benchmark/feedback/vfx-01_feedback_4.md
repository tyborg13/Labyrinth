# vfx-01 — round 4 (peer review of 70a477346: correctness verified; CPU on real frames regressed)

Work on top of 70a477346. Do not commit. Evidence: scratchpad/review_vfx_chr/v3/.

1. **Line cores on real frames** (blocking). The benchmark measured CPU on held frames (cache hits). With progress
   changing every frame (gameplay), lightning costs **+5.35 ms median** (p95 +6.45) per redraw — round 2 was +1.96 ms —
   and the mesh cache almost never hits. Mesh build ≈3.5 ms (temporary packed arrays per quad, palette and hex ramp
   re-parsed per stroke), halo neighbourhood dictionaries ≈1.5 ms, rasterization 0.3–0.5 ms, LRU key copies up to 1 ms.
   Preferred fix (director): **move line rasterization to the GPU**. In the low-res layer draw each stroke with
   non-antialiased `draw_polyline` (core: width = 1 low-res pixel, full alpha, flagged so the quantizer never dithers it,
   e.g. a separate core layer or a reserved alpha band; halo: width 3, lower alpha, dithered as now). The look target is
   unchanged: a continuous 8-connected one-cell core following the zigzag, dithered one-cell halo, element ramp colours.
   Verify continuity on the GPU (render probe: core cells of conduction, chain arc and lightning form one 8-connected path)
   and compare captures with round 3 (same frames; small rasterization differences are acceptable, gaps are not).
   If you keep any CPU path, preallocate arrays (`resize` + index writes), cache palettes per halo colour/element and
   parsed ramps, and drop the LRU (clear instead).
   **Target** on unique-progress frames at 1080p: lightning, chain and tether CPU submission ≤ 0.3 ms median, ≤ 1.0 ms p95.
2. **Benchmark CPU sampling**: advance progress every frame for the CPU measurement (or record submission on the first
   frame of each held sample) and gate on that; keep the GPU timing as now.
3. **Cache memory**: if any per-layer cache remains, clear it in `finish()` when the layer has no line strokes (or one
   shared cache with a global cap); test the accounting (the `_cached_quads` non-decrement mutant must fail).
4. **Fading arcs**: drop the forced-opaque core once the source alpha falls below `alpha_floor` (arcs fade out instead of
   popping on the last frame).

Proof: pixel FX tests, elemental FX test, hash equivalence, full suite, the unique-frame CPU numbers; list the windowed
compare/render probes and the Vulkan benchmark for me.
