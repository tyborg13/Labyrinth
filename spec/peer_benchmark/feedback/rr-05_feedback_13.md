# rr-05 feedback 13: peer-review fixes (review c87609f84)

The review is in `spec/peer_benchmark/feedback/rr-05_review_c87609f84.md` in the integration worktree. Your branch HEAD
is c87609f84: the director committed your round-12 state plus the windowed adoption, merged integration, and added a
registration fix. Work on top. The adopted production assets and native captures are final; don't change them.

1. **Promotion binds to current inputs (Medium).**
   - `maquette_cutout_build.py` promotion and every other consumer of saved gate certificates must verify the
     certificate against the current case textures, layouts and the gate tool by hash before copying anything. A
     mismatch rejects.
   - Add the reviewer's regression: recolour hidden support after certification. Promotion must refuse, and a fresh
     gate must report the derived slab.
2. **Tie alternatives must be real texels (Medium).**
   - In `raster.py`, an alternative candidate exists only when the neighbouring texel index is inside the texture:
     `0 ≤ u, v < size`.
   - At the texture boundary, a tie has a single candidate, the in-range texel. Never a transparent out-of-range one.
   - Add the reviewer's regression: an opaque 12×12 texture translated by (0.5, 0.5) with its first row and column
     erased must fail the tie-aware match.
   - The three retained fixtures must still pass.
3. **Clean-checkout test (Low).** `tests/test_maquette_native_alpha.py` creates its temporary directory under the
   system temp dir, or creates `output/rr-05` explicitly first.

## Proof
- Re-run the CPU gates plus native verification headless against the existing native captures for both creatures. All
  must still pass with zero errors.
- The mutation results for items 1–2.
- All `tests/test_maquette_*.py` from a clean `output/` state.
- The full Godot suite through the parallel runner, plus the Python suite.

No windowed recapture is needed unless a gate result changes. If one does, stop and report it.
