# rr-13 feedback 1 — director-reviewed exceptions; finish

The director ran `density` and `native` on your fills: density PASS; native 39 flags. The director inspected them on
the captured frames (crops in the scratchpad: `rr13_rear_mark.png`, `rr13_front_move7.png`). They aren't defects:
- **rear `mark` 10–51 (and the similar front `bolt` 20, `hit` 4/8/9, `death` 62).** Background legitimately shows
  between the robe's side and the raised staff arm or knocked-back torso, where the sleeve hung at rest. It reads as
  natural negative space, and your sleeve-footprint fill is correct. These areas lie outside the body.
- **front `move` 7.** Scattered 1–3 px slivers, 12 px in total, not visible at board scale.
- **front `move` 11/12/15 and rear `move` 10 (`TODO_DESIGN_detached_robe_tip_rest_identity`, decided).** These are the
  approved painting's own ragged robe-tip pixels, separating for a frame during the step. Keep them: rest identity
  stays exact.

Implement a director-approved exception list as case data,
`experiments/cutouts/hoarfrost_seer/rr10/gate_exceptions.json`, read by the native gate.
- Each entry: `view`, `clip`, the exact `frames` list, `rule` (the error text) and a `reason`.
- The entries:
  - (front, bolt, [20]) joint-seam hole
  - (front, death, [62]) joint-seam hole
  - (front, hit, [4, 8, 9]) joint-seam hole
  - (front, move, [7]) joint-seam hole
  - (front, move, [11, 12, 15]) detached component
  - (rear, mark, [10, 19, 23–48, 51]) joint-seam hole, listed exactly as in `native_gates.json`
  - (rear, move, [10]) detached component
- Any flag not on the list still fails.
- A test proves it: a flag in a listed clip but an unlisted frame fails.

Then stop. Run focused tests only. The director reruns `native`, `sheets` and `review`.
