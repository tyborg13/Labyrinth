# Frostglass Lancer mq4 pair — director acceptance (2026-10-17)

Front: owner-approved r4 painting (review inbox lancer-r4-facing, "Middle looks great").
Rear: img-mq-lancer-rear-r4, round 2 (height and hem fix, then the 3/4 turn restored), plus the recorded tone step
`refs/tone_rear_r4.json` (warm hue 0–40°, chroma ×0.65), which removes the copper cast so the plates, shaft and
leather match the front (rear_consistency chroma delta 0.0024).

Two accepted gate FAILs:
- `rear.height_drawn` 224 vs [226, 255]. The front's 240 includes the raised spear tip. The hood tip (y 22) and the
  boot soles (y 245) are identical in both views, which is what matters when the rig turns.
- `rear.thin_rel` 0.134 vs 0.12. This comes from the full-length spear shaft and the ragged hem fringe, the same
  features the front has (0.107). Judged at board scale on the sheet: legible.

Lateral axis (feet landmarks, `mq4_landmarks_pair.json`): front 9.9°, rear 17.6°. Both are inside the 3/4 band.
