# cap-01 feedback 1 (director; Codex review of 6e76ac2b6 requested changes)

The director's windowed before/benchmark/after/compare run used 6e76ac2b6. Its captures remain the evidence. After
this round the director re-runs `compare` on them, plus `after` only if the writer changes.

1. **Every native reader goes through `native_frames.load_frame`.** These still bypass it:
   - `experiments/cutouts/briar_weaver/rr21_residue.py:124`: it opens the logical PNG directly, so an indexed or RGBA
     input raises `FileNotFoundError`;
   - `experiments/cutouts/gust_shrike/mq2/probes/motion_gates.py:302`;
   - `experiments/cutouts/chainbound_gaoler/mq3/probes/motion_gates.py:30`.
     A cropped fixture returns 32×32 instead of the restored 64×48.
   - Route them through the helper.
   - Grep the whole repo for any other direct read of native capture frames and fix those too. List them.
   - Test each with crop and alternate-codec inputs.
2. **Equivalence must not pass vacuously.**
   - `tools/capture_director.py:114` accepts two empty capture and reel sets.
   - Require the complete expected artifact set for the Seer and the Mortar before comparing: every clip's frames,
     manifests, gate JSONs and reels, with counts matching the case's clip inventory.
   - A missing or extra artifact fails, naming the path.
3. **Close the two surviving mutations.**
   - Make the board fixture in `tests/maquette_cutout/capture_storage_test.gd` non-uniform.
   - Verify writer-to-Python reconstruction pixel for pixel. A 1 px shift of the sampled crop with unchanged recorded
     coordinates must fail.
   - Exercise the real consumer reader paths. Bypassing the native gate's rest-image loader must fail.
   - Report the mutation table.
4. Focused tests only. Don't change the writer's on-disk format unless a finding requires it. If it does, say so; the
   director then re-captures `after`.
5. **Gate failures must not abort the comparison.**
   - The director's `before` run stopped at the Seer: `rr10_gates.py --native` exited 1 with 31 errors, all 2–3 px
     joint tears. Those are real failures under rr-26's canonical gate. They are not caused by cap-01: the same 31
     appear with integration's code on the same frames.
   - `capture_director.py` must record each gate's JSON and exit code for before and for after, keep going, and have
     `compare` require them identical.
   - A gate failure is evidence, not a capture failure. Only capture or manifest errors stop the run.
   - Capture each gate's JSON without overwriting the case's committed records. The director's manual run rewrote
     `rr10/proof/native_gates.json` and `samples.json`; write to the proof output folder instead.
