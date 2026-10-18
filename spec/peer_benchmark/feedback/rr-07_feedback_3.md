# rr-07 feedback 3: TODO_DESIGN_native_outer_uv_edge_policy

The Seer passes and the Thrall's four earlier failures cleared. The remaining case is rear/seam_upper_near_fore_near/65
"before", pixel (193,252): native is transparent, and the only in-range tie candidate is opaque. That's coverage
rounding at the quad's outer edge.

## Decision
- A tied pixel whose native value matches **neither** legal candidate (an "invalid tie") no longer fails on its own.
  It counts as one ordinary changed pixel under the existing allowance (`native_raster_edge_pixels` 1 +
  `native_raster_fraction` 1% of the union), exactly like a non-tie mismatch.
- Rationale: the reviewer's rr-05 case (a 12×12 texture with its first row and column erased, 23 pixels) still fails,
  because it far exceeds the allowance. A single coverage-rounding pixel at a quad edge passes.
- Everything else stays:
  - the 1/512 sub-texel tie band;
  - in-range candidates only, with no out-of-range alternative ever considered a match;
  - held-frame tie consistency, so a held flip still fails;
  - the shimmer residual rules;
  - tie reporting. Also report invalid-tie pixel counts per part and frame.

## Tests
- The rr-05 12×12 erasure regression must still fail.
- Add the Thrall pixel (193,252) as a retained fixture: it passes as one counted pixel.
- Add a synthetic check: two invalid-tie pixels on a part small enough that the allowance is 1 must fail.

## Proof
- Re-gate both creatures against the existing captures: zero errors. Seer and Thrall `--from-review` are then mine to
  run.
- All focused maquette tests, plus the full Godot and Python suites. The density-rest records are still expected to be
  missing until my windowed run.
