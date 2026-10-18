# mq-04 feedback 5: verifier fixes (review 3d3be3d02)

The review is in `spec/peer_benchmark/feedback/mq-04_review_3d3be3d02.md` in the integration worktree. Your branch HEAD
is 3d3be3d02 (the director's commit of round 4). Work on top and keep the curation.

1. **Delivery must fail on failed checks (blocking).**
   - `quality_delivery.py` and `curate_delivery.py` require current, passing build, capture, facing, collision and
     ownership reports, bound to the cold-build proof by hash. Any `passed: false`, a missing report or a stale hash
     fails with a non-zero exit.
   - Add rejection tests for each field. The reviewer's copied-Thrall mutation must fail.
2. **Regeneration compares part maps (Medium).**
   - `regenerate_delivery.py --verify` canonicalises and compares the front and rear part maps as well as the clays.
     Missing or mismatched maps fail.
   - Run a fresh regeneration of all four figures through the bridge, which is up for this worktree, and keep the
     result JSON in each delivery.
3. **Frozen bytes stay frozen (Medium).**
   - Restore the original r3 PNG bytes for the frozen Seer and Thrall clays and part maps. Their recorded r3 file
     hashes are in your earlier manifests or discarded-proof hashes.
   - Herald and Gloam keep their round-4 deliverables, but don't re-encode committed PNGs either. Comparisons
     normalise temporary copies only.
   - Show that the Seer and Thrall pixel hashes still equal the paint-over kits' refs
     (`spec/art_identity/jobs/{hoarfrost_seer,arc_thrall}/mq5_*/refs/01_*`, `02_*` after green compositing).
4. **Helper-test strength (Low, from the mutations).** Removing required-part rejection must fail the helper tests;
   add the test.

Proof:
- the focused, art identity and full Python suites;
- the mutation results for 1–4;
- the four-figure regeneration results;
- per-figure disk sizes, which stay ≤ 6 MB.

Don't change any figure's geometry.
