# rr-05 feedback 1 — feature masks supplied (director)

The TODO_DESIGN feature inputs are resolved. They are director data: do not edit the masks, owners or reasons.
Copies are staged at `spec/peer_benchmark/staged/rr-05/features/` on the integration branch.

## Shale Bloomer (`experiments/cutouts/shale_bloomer/mq3/features.json`, masks under `features/`)
| feature | front | rear | owner |
|---|---|---|---|
| crown_gem | features/front_crown_gem.png (1167 px) | features/rear_crown_gem.png (161 px, the sliver under the flower) | core |
| amber_upper | features/front_amber_upper.png | occluded | trunk |
| amber_right | features/front_amber_right.png | occluded | trunk |
| amber_left | features/front_amber_left.png | occluded | trunk |
| amber_rear_left | occluded | features/rear_amber_rear_left.png | trunk |
| amber_rear_low | occluded | features/rear_amber_rear_low.png | trunk |

## Lightning Wisp (`experiments/cutouts/lightning_wisp/mq4/features.json`)
| eye | features/front_eye.png (166 px, white eye + 2 px rim) | occluded (rear shows the back of the cloud) | core |

Occluded views use `features/empty.png` plus an `occluded_reason`. Each mask is the gem/eye body plus a 1 px rim
(eye: 2 px) with interior holes filled, so the dark facets and outline travel with the gem. `features.declarations()`
already accepts all four views.

## Do next
1. Run both `derive` commands from `experiments/cutouts/shale_bloomer/rr05/proof_for_design_owner.sh`, then every
   headless feature/shimmer gate, the focused suites, and the full Godot + Python suites.
2. Fix any failure in code. If a gate rejects a mask itself (for example, the owner part does not draw in front of
   an overlapping part in some pose), report the exact feature, view, pose and failing check under TODO_DESIGN
   instead of editing the mask; I'll decide.
3. Do not run `promote` or production adoption; they need the windowed native rebake, which I run. Keep
   `proof_for_design_owner.sh` current and in run order (derive → native review MP4s → promote → density adopt → rest
   rebake) so I can run it in one pass.
4. Report the gate results per feature (pixels preserved, single painted node, owner bone, sampled poses).
