# rr-36 implementation handoff

Changes are uncommitted on `codex/rr-36`. No peer review, windowed run, publication or task-queue mutation was performed. The design owner owns native judgment, density registration/rebake, review, fixture and publication.

## Requirements, causes and repairs

1. **D1 — heel wedge.** The isolated native `foot_far` layer draws it. Maquette ownership assigned a small fringe of the **near** boot below source y210 to the far foot. The component bridge builder then added a 445-texel gait continuation to that travelling island. Return the boot fringe to `foot_near` and remove/recompute affected far-foot recipes. The floor wedge is not the shadow.
2. **D2 — broken near shin.** The categorical cut gave cloak-edge paint to the leg, and leg-edge/maquette underfill to the moving cloth. The leg's hidden surface retained flat fill and cloth/violet fringes instead of its wrapped material. Trace the original painted hem boundary, return its texels to cloth, and continue the limb using only its own non-outline **interior** wrapped texels. Coverage uses the certified thigh/shin solo silhouette, the existing three-pixel tuck, and source-connected coverage; hidden-only islands are discarded.
3. **D3 — rear thigh band and Y.** The projected pelvis cut split painted wraps among torso, pelvis and leg; flat hidden fill and repeated violet cloth pixels were exposed by their different transforms. Reunite the wrapped thigh with its leg (preserving the exclusive carapace mask), replace the leg underfill with own wrapped interior donors, and remove violet donors from every hidden layer. Original violet pixels remain on the visible head/cloth surfaces. No accent, joint, track, timing or skin-field rule is retuned.
4. **D4 — cloak seam.** The source y151 pelvis cut bisected the same front cloth between torso and pelvis transforms. Give that cloth to the torso surface above it; give the wrapped portion of the old pelvis cut to the far leg. Keep the now occluded pelvis draw node and its ID. There is no longer a moving horizontal cut through that cloth.
5. **D5 — hem fray.** Thin cloth-edge texels inherited leg ownership and separated from the cloak when the leg moved; hidden cloth also duplicated the violet edge. Trace those original texels back to `cape_near`, remove the hidden feature copies, and regenerate the masks/mesh bounds. The original skin fields and motion stay fixed.
6. **Preservation.** Only two entries in `rr35/proof/round0/samples.json.inputs` were reconciled with the accepted `187ce0327f3da507d4ba1e24ea55f4b76fdf09a8` rests:
   - `production:assets/units/gloam_stalker_cutout/humanoid_v2/front/rest.png`: `85e742bf…` → `1bed75d3…`.
   - `production:assets/units/gloam_stalker_cutout/humanoid_v2/rear/rest.png`: `42dfcc6b…` → `df2bcd1c…`.
   Those PNGs themselves remain unchanged. `rr35/proof/rr36_preservation.json` records full before/after hashes for the authorized **derived partitions** separately. Paintings, maquette, director motion and other figures remain unchanged. There are no new generic changes; the three generic changes mentioned by the inherited preservation report belong to rr-35.

The original builder is revision-specific: reproduce this repair with `PYTHONPATH=tools python3 -B experiments/cutouts/gloam_stalker/rr36_repair.py`, then seal the diagnostic material contract and refresh samples. Do not rerun the original rr35 builder alone and expect it to retain these repairs. The repair is pinned to immutable e4b source partitions. It copies original texels; it does not paint, generate or download assets.

## Why the old gates passed

| Defect | Component count | Seams / coverage |
|---|---|---|
| D1 | The bridge made the false boot island part of the body. | Added legal own-foot donor texels filled the alpha gap, without checking anatomical ownership. |
| D2 | Cloak and underfill connected the shredded limb to the whole silhouette. | Alpha coverage and a percentile outline class did not establish a solid wrapped limb or correct hidden material. |
| D3 | The band remained connected. | A thin horizontal band need not form a 3×3 dark slab; the visible feature gate did not forbid hidden copies of a drip. |
| D4 | Both cloth halves remained in the main component. | Hidden fill covered the opening; coverage did not test that the same cloth crossed the cut under one transform. |
| D5 | The fringe could touch the leg/underfill and remain globally connected. | Inherited ownership/check masks authorized those texels; no local hem/foreign-material check detected them. |

`rr36_native_checks.py` now checks each named defect on its cited native layers: floor extent, own wrapped underfill palette, thigh material/hidden drip duplication, cloth still on the separate pelvis, and cloth fringe on the leg/hidden hem duplication. Every one of the 16 cited defect/frame cases fails on e4b native pixels. The retained fixture contains 13 unique full native frames and 78 isolated layers, copied byte-for-byte, with source-manifest and payload hashes. It is explicitly a negative-control subset, not a complete acceptance capture.

The same measurements pass on repaired CPU construction frames. They remain diagnostics. Native pass-after and acceptance require the director's fresh renderer captures and 2x clip inspection.

## Files and validation

The complete changed-path inventory is `rr36_files_changed.txt`. Repair/build integration, native diagnostics, retained fixture, production partitions, ownership/check/tuck/seam records, and tests are all inside the brief's owned paths. `rr35/proof/rr36_verification.json` records commands and exact result lines; full transcripts and labelled CPU stills are in `rr35/proof/logs/rr36/`.

Production uses the existing density settings. Density adoption and native rest certification remain pending, and `assets/units/gloam_stalker_cutout/integration.json` says so. A source-space composition of the treated partitions differs from the accepted front production rest at 10 RGB texels (alpha unchanged), owing to cleanup at changed partition boundaries; rear differs at zero. This is not native proof. The director must inspect/rebake and record the resulting density rest; do not relabel the old rest as a new capture.

The full Godot suite's unrelated `special_encounter_test` failure reproduces with `--assets-only`: missing imported `.ctex` files for Warband, Umbral Snare and Ember Hoarder emblems. The affected test and import sidecars are byte-identical to local `master`. No assertions or foreign sidecars were rewritten.

## Proof for the design owner

Run from this worktree at 1920×1080, 100% UI scale:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-36 && LABYRINTH_TASK_ID=rr-36 sh experiments/cutouts/gloam_stalker/rr35_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-36 && LABYRINTH_TASK_ID=rr-36 sh experiments/cutouts/gloam_stalker/rr35_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-36 && LABYRINTH_TASK_ID=rr-36 sh experiments/cutouts/gloam_stalker/rr35_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-36 && LABYRINTH_TASK_ID=rr-36 sh experiments/cutouts/gloam_stalker/rr35_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-36 && LABYRINTH_TASK_ID=rr-36 sh experiments/cutouts/gloam_stalker/rr35_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-36 && LABYRINTH_TASK_ID=rr-36 sh experiments/cutouts/gloam_stalker/rr35_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-36 && LABYRINTH_TASK_ID=rr-36 sh experiments/cutouts/gloam_stalker/rr35_proof.sh review
```

Changed stages: **density** stages raw repaired partitions before existing adoption/processing; **native, sheets and review** run the five named checks. The native capture/proof contract also requires the exact move 13/20/27, slash 14/21/23 and ambush 10/17/25 review frames, in addition to existing representatives. Isolated layers now carry payload hashes. Rest/idle/production stages retain their existing behavior. No inspection-fixture command was requested by this brief; that workflow step belongs to the design owner.

Output paths under `rr35/proof/`: `native/`, `native_rest/production/`, `contact_sheets/`, `idle_native/`, `production_native/{front,rear}/`, `gloam_stalker_protagonist_idle.mp4`, and `gloam_stalker_review.mp4`.

## TODO_DESIGN placeholders

None. Native visual acceptance and the unrelated missing emblem imports are open proof/environment issues, not missing design values.

## Chosen defaults

- `MUTATION_RGBA = [1, 255, 1, 255]`: test-only disallowed-color negative control.
- `full_suite_timeout_seconds = 900`: headless full-suite process guard, recorded in the verification receipt.

All source boundary coordinates and the D1 local-row cutoff are measured ownership/diagnostic coordinates. The existing camera, native origin, 60 fps, 2x review scale, three-pixel tuck and density settings are reused.
