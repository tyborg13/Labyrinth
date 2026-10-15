# rr-02 — round 7 (director review of the v06 reel)

Round 6 is committed (b3bb9f846). The tabard red is gone, the rear strike fist is hidden, chain_reel reads well.
Evidence: scratchpad/rr02v6_front.png, rr02v6_rear.png, rr02v6_walkzoom.png (from /private/tmp/rr-02-mq3-render-v06).

1. **Painted inter-leg shadow swings with the leg.** In the front walk (frames 0 and 47) the far thigh shows a pure-black
   jagged patch above the boot; in the rear walk (frames 27, 34) the far leg shows a dark streaked patch with a light
   jagged edge. These are the painting's occlusion shadows between the legs/under the tabard, now owned by thigh/shin
   parts. Rule: near-black pixels (L* < 15) inside thigh/shin parts within 6 px of the other leg's label, the pelvis or the
   tabard boundary are **occlusion shadow**: move them to an under-shadow layer attached to the pelvis and drawn behind
   both legs (it does not swing); fill the vacated leg area with the trousers material (your sparse-reference rule).
   Gate (motion frames, both views): inside any thigh/shin part, no 8-connected near-black (L* < 15) region larger than
   12 px that was not near-black in the same part's visible rest pixels; rest identity stays exact.
2. **Native motion probe fails**: `SCRIPT ERROR: Invalid access to property or key 'rest'` at
   `tools/cutout_pipeline/rig.gd:96` (`show_frame`) from `probes/native_motion.gd:88`, so `motion_gates.py` and
   `proof.py` failed natively (headless passed). Fix it and make the native gates part of what you verify headless where
   possible; the windowed command must end with MOTION GATES: PASS and MAQUETTE_PROOF: PASS.

Proof: focused/gate/full suites, validation, rest identity 0, zero magenta, motion gates; windowed commands with capture
path `/private/tmp/rr-02-mq3-render-v07`.
