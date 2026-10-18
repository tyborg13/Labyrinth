# rr-10 feedback 3 — native proof at 5abe9b561: visuals pass; calibrate two gates

The director ran `rest`, `native`, `sheets` and `idle`:
- rest PASS;
- idle PASS (252 frames; still exactly right);
- native gates FAIL with 344 errors, so `sheets` refuses.

The director overlaid every flagged region on the posed frames (mark 30 and 57, hit 6, ward 12, bolt 10, death 30;
evidence at `/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/020b9ac4-7b92-4113-a7d2-bc6e802828dd/scratchpad/rr10_holes2.png`
and `rr10_specks.png`). The visual defects from feedback 1 are fixed; the remaining errors are calibration.

1. **"New joint-seam hole" (325 errors)** is negative space, not a seam opening. Every flagged region is background
   enclosed between the staff or the free hand and the robe or sleeve, for example under the raised staff arm in
   mark 30. Those pieces aren't jointed to each other; the grip seam is merely within 3 px.
   - Count a new hole as a defect only when at least 80% of its boundary pixels belong to the two pieces of a single
     joint pair: upper/fore sleeve, sleeve/hand at the wrist, torso/head, torso/sleeve at the shoulder, robe top under
     the torso, hem/foot.
   - Holes bounded by the staff, or by pieces not jointed to each other, are free negative space.
   - Mutation: open a 3 px gap at the far elbow and it must still fail.
2. **"Detached opaque component ≤ 8 px" (19 errors).** All are single outline-dark pixels, colour (18,18,23) or near
   black, one or two at a time, at most 1–2 px off the far sleeve's or the hem's edge. At board scale they read as
   outline.
   - Exempt outline-dark components (luma < 0.12) of ≤ 2 px that sit within 2 px of the main silhouette.
   - Any other detached component still fails, including the feedback 1 frames' clusters. Keep that mutation.

No rig, mesh, data or art changes. Rerun the headless suites, then stop. The director reruns `native` and `sheets`.
