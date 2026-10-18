# mq-07 feedback 3 — review 70ac9e5ef: geometry accepted; fix the proof validation

The review is in `spec/peer_benchmark/feedback/mq-07_review_70ac9e5ef.md`. The delivered geometry passed: the shoulder
rule, every tube dimension, the planted far foot, the exact turn, framing, coverage and fit. Don't change the
delivery's geometry or images. Fix the validation:

1. **Medium — curation accepts a stale or failed tube proof** (`arc_thrall/r2/curate.py:22`).
   - Bind the gates receipt to the current spec and capture hashes.
   - Require every mandatory gate before deleting any native evidence: tube geometry, native tube entry, floor, fit,
     framing and coverage.
   - Add tests for a stale hash, a missing receipt and a false gate. Each must stop curation without deleting anything.
2. **Medium — resealing permits missing socket proof** (`blender/delivery_validation.py:22`).
   - Require `native_socket_tucks` in the build and capture checks, plus the socket details, whenever
     `base.socket_tucks` exists in the spec.
   - Test that omitting them fails before and after resealing.
3. **Low — merged builder wiring lacks coverage.**
   - Add mocked dispatch/order tests for the procedural-chain branch, the repose call and the socket-tuck call.
   - Add invalid-contract fixtures for socket validation and foot-exception rejection.
   - Each removal the reviewer made must now fail.

Your branch has director merges of `codex/peer-benchmark` (now including the final mq-06); don't merge again. Rerun the
focused tests and the full Python suite.
