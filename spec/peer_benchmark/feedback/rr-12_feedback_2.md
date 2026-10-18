# rr-12 feedback 2 — director windowed proof at 5b7f85a14

- **Ember Tick: all native, review, contact-sheet, density and production gates PASS.** The director reviewed the MP4
  and sheets and accepts the Tick. Don't touch its rig, data or captures.
- **Burrow Grub: native gates FAIL with 4 errors, all on `burrow` frame 55 (the last frame, alpha 0):**
  `front/burrow/55` and `rear/burrow/55`: "native rest reference differs from source transform" and "native interior
  reference differs from source transform".
  - The clip ends fully faded (`body.alpha` 0 from 0.95), so the native capture is empty there. The reference
    comparison doesn't treat an all-transparent frame as a match.
  - Fix the gate: an all-transparent presented frame (every part at alpha 0) must compare equal to an empty
    reference.
  - Add a regression: a 0-alpha frame passes. The same frame with one part at alpha 0.5 must still be compared
    normally, and must fail when a transform is tampered.
  - No change to the motion data or the rig.
- Then stop. The director reruns `rr12_proof.sh burrow_grub`.
