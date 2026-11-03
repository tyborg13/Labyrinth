# mq-12 — feedback 1 (director decisions on the two TODO_DESIGNs)

Round 0 poses are accepted: Herald far shoulder (364, 381.5) with hand and horn fixed; Gloam far shoulder (334, 335.7)
with the arm and claw translated at unchanged angles. Shoulder, facing, ownership, determinism and true-turn gates pass.
Keep all of that.

## TODO_DESIGN_SHOULDER_CLOTH_CLEARANCE (both figures)
"Stay as they are" in the brief meant the garments keep their design, not that their meshes stay frozen in place.
- Garments that rest on or hang from the far shoulder ride up with it: the Herald's cowl and its far-side banner root
  (`cape_far`) and tabard top; the Gloam's far drape (`cape_far`) and the carapace plates over the far shoulder.
- Their shape, length, fold pattern and silhouette stay the same; only the part attached at the far shoulder moves, by
  the shoulder's own delta, blending back to the unchanged garment away from the shoulder (or re-simulate the cloth on
  the corrected body with the same settings — your choice, as long as the result matches this description).
- Everything else (near side, mask/hood, legs, horn) stays exactly as round 0.
- The collision gate must pass for both figures, and the delivery must seal.

## TODO_DESIGN_GLOAM_FRONT_IOU
Accepted. I repaint the Gloam from the new clays, so the old painting's silhouette no longer binds the far arm.
- Gloam r2 front IoU gate: ≥ 0.65 (rear stays ≥ 0.65; Herald keeps 0.70 / 0.65).
- Report per-part overlap before and after for the Gloam front, showing the loss is confined to `upper_far`,
  `fore_far`, `hand_far` and the far shoulder garments.

## Proof
Same sheets and joint table as round 0, refreshed, plus the collision gate output and the Gloam per-part table. Focused
tests only.
