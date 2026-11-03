| Part | Original → round 0 IoU | Original → feedback 1 IoU | Round 0 → feedback 1 IoU | Painting coverage before | Painting coverage after |
|---|---:|---:|---:|---:|---:|
| head | 1.000000 | 0.914457 | 0.914457 | 0.993325 | 0.995402 |
| torso | 1.000000 | 0.859184 | 0.859184 | 0.931324 | 0.935061 |
| cape_near | 1.000000 | 1.000000 | 1.000000 | 0.930036 | 0.930036 |
| cape_far | 1.000000 | 0.619951 | 0.619951 | 0.822279 | 0.877688 |
| upper_near | 1.000000 | 1.000000 | 1.000000 | 1.000000 | 1.000000 |
| fore_near | 1.000000 | 1.000000 | 1.000000 | 1.000000 | 1.000000 |
| claw_near | 1.000000 | 1.000000 | 1.000000 | 1.000000 | 1.000000 |
| upper_far | 0.023546 | 0.023546 | 1.000000 | 1.000000 | 1.000000 |
| fore_far | 0.000000 | 0.000000 | 1.000000 | 0.994536 | 0.994536 |
| claw_far | 0.210690 | 0.210690 | 1.000000 | 0.356092 | 0.356092 |
| thigh_near | 1.000000 | 1.000000 | 1.000000 | 0.992919 | 0.992919 |
| shin_near | 1.000000 | 1.000000 | 1.000000 | 0.932203 | 0.932203 |
| foot_near | 1.000000 | 1.000000 | 1.000000 | 0.981796 | 0.981796 |
| thigh_far | 1.000000 | 1.000000 | 1.000000 | 0.872904 | 0.872904 |
| shin_far | 1.000000 | 1.000000 | 1.000000 | 0.894472 | 0.894472 |
| foot_far | 1.000000 | 1.000000 | 1.000000 | 0.783354 | 0.783354 |
| carapace | 1.000000 | 0.536253 | 0.536253 | 0.935261 | 0.760588 |

`hand_far` is owned by the existing `claw_far` label. IoU uses native unoccluded part masks, so occlusion by a moved garment cannot masquerade as a change to the protected part. Painting coverage uses whole source alpha; the painting has no supplied part segmentation.

Allowed changes are the far arm/claw and far shoulder garments. `torso` includes its shoulder under-drape; `head` includes the lower shoulder-cowl skirt. The independent native preservation guard fixes every accepted body vertex, the complete skull-cover/opening faces, all other meshes, and all near-side garment faces. See `../validation/native/preservation.json`. Confinement gate: True.

The legacy transparent-face `cape_near` solo has 128 changed alpha pixels (IoU 0.998132777) despite identical native near-face geometry and ownership. The table uses fresh isolated-face native captures for this row, with excluded faces removed from a disposable scene. Native camera and solo settings are unchanged; original, round-0 and feedback selected-face hashes are identical. The legacy result is retained above and in the JSON. Delivery rendering is unchanged.
