# rr-29 feedback 2 (director: native run, and the Codex review of 052a20fb8)

Motion and art are accepted as they are. Fix the code. Focused tests only, plus the native gate replay below.

1. **Blocker: the native gate crashes.**
   - The director ran `rr29_proof.sh native`. The capture passed, then `rr29_gates.py` → `gates.native_errors` raised
     `KeyError: 'transform'` at `tools/humanoid_cutout/gates.py:438`. Some pose part has no `transform`.
   - Log: `experiments/cutouts/hollow_mimic/rr29/proof/director_native_run.log`; captures at `experiments/cutouts/hollow_mimic/rr29/proof/native/`.
   - Find which parts lack it (likely the pendulum or draw-order-promoted parts in the samples) and fix the producer,
     not the gate.
   - Replay the gate headlessly on the existing native capture. Include the result line.
2. **Medium: far-arm runtime behaviour is untested.**
   - Disabling far-arm promotion in `draw_order.gd:36` survived all 11 tests.
   - Add a headless Godot fixture that crosses the overlapping far wrist, runs the runtime ordering, and checks:
     - the hand and sleeve are promoted;
     - they are restored afterwards;
     - the rear view is excluded.
3. **Medium: the rear's r2 prompt bindings are inert.**
   - Make the final revision (`prompt_rear_mq11_r2.md`, chained after `prompt_rear_mq11.md`) part of the certified
     prompt binding, so tampering with it fails certification.
   - Add a tampering test.
4. **Medium: preservation ignores committed scope violations.**
   - Compare against the immutable integration base `8b6cf8d06`, including committed changes.
   - Register a regression test in which a committed out-of-scope change fails.
