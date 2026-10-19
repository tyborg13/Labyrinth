# mq-09 feedback 2 — briar_weaver

The hood is a dense, thick, sculpted cloth rest with a rounded crown, real face opening toward the board's lower-left, nonuniform folds and a torn shoulder hem. Its back is a rounded drape over the mantle. The mantle consists of overlapping closed, curved torn-leaf clumps around the shoulders, including the approved far-shoulder leaf shape; mantle leaves and thorns share `torso`. Forearm thorns remain on their respective `fore_<side>` labels. Native CC0 root limbs have shallow spiral relief; the large hooked hand claws remain. The hunch is in the native spine/neck pose. `tatters` remain shaped, curved leaf cloth bound to `pelvis`. The green eye is one front-only `head` paint feature. Hood, mantle and tatters use sculpted meshes rather than cloth simulation; the tatters use the director-authorized fallback.

The sole authoring input is `measurements.json`; `spec_native.json` is generated and discarded. The approved processed paintings retain their protected SHA-256 values. All geometry is real and native on the approved CC0 humanoid armature. Every figure uses one frozen pose and mesh for the front and true 180-degree rear; no mirror, per-view pose or camera correction is used. Native corner normals survive the ownership split so the segmentation does not change the skin shading at joints.

## Numbered acceptance criteria

1. The Blender-native spec, 3/4 facing axis and rendered torso-asymmetry checks pass. The forms above implement the director's feedback; the contact sheet compares them directly with the approved paintings and the Lancer r3, Thrall mq-07 and batch-B clays.
2. Front IoU **0.716258381 → 0.707308272**; rear **0.720184800 → 0.688125394**. Every label has a nonempty solo and genuine visible owner pixels in both views. No explicit whole-part occlusion exception is needed. `delivery/fit_report.json` and the batch `part_coverage.csv` report each arm and leg part separately.
3. Shoulder observed / expected: **34.800000 / 34.800000 px**; error **0.000000 px**; 3D height difference **0.000000000 m**. Both feet are planted. Front lower foot is near, rear lower foot is far, and each lower foot is on the right. Near / far body-side pixels over torso: front **87 / 0**; rear **0 / 3693**. The independent pixel true-turn gate passes.
4. Curated native 1024 clays, part maps, solos, joints, manifests and fit overlays are in `delivery/`. The batch contact sheet and before/after table are in `../hollow_mimic/delivery/review/`. `COMMIT_MANIFEST.txt` inventories the complete retained tree under the 6,000,000-byte cap. No `.blend`, cache, candidate or determinism copy is retained; discarded evidence is hashed before removal.
5. Native cold/cache/independent geometry, exact mesh/joint replay, ownership and mutation gates pass. A clean input-only regeneration matches all four canonical front/rear clay and part-map PNG SHA-256 values, without a reused cache. Native delivery and `acceptance_binding.json` bind those outputs, fit, pose and mutation/regeneration receipts to the current recipe and cold mesh. The clean input inventory records the exact builder source.

## Proof for the design owner

All Blender execution is through the director-owned bridge. These commands wrap that bridge; they do not launch Blender directly. Use fresh, empty proof directories.

```sh
python3 -B -m spec.art_identity.maquettes.hollow_mimic.workflow build briar_weaver --proof-subdir proof/owner_fresh
python3 -B -m spec.art_identity.maquettes.hollow_mimic.workflow regenerate briar_weaver --regeneration-subdir proof/owner_regeneration
python3 -B -m spec.art_identity.maquettes.hollow_mimic.workflow verify briar_weaver
```

The batch sheet is regenerated with `python3 -B -m spec.art_identity.maquettes.hollow_mimic.workflow sheet`. Its first three rows are approved painting | clay, front and rear, at the same board scale. The reference row uses native 1:1 clays; the final row contains the three fit overlays. Source hashes and cell positions are recorded in `contact_sheet.json`.

No windowed Godot probe or inspection fixture applies to this offline Blender unit. The director retains commits, peer review, inspection and publication. All implementation changes are left uncommitted.

## Focused verification

```sh
python3 -B -m unittest spec.art_identity.maquettes.blender.test_source_recipe spec.art_identity.maquettes.blender.test_delivery spec.art_identity.maquettes.blender.test_delivery_validation tests.test_maquette_blender tests.test_mq09_maquettes tests.test_mq09_forms
python3 -B -m unittest tests.test_maquette_rear_turn
python3 -B tests/test_art_identity_gate.py
python3 -B -m spec.art_identity.maquettes.hollow_mimic.workflow verify
```

Observed final test logs are retained in `../hollow_mimic/delivery/validation/`. The full suites are left to the director at merge, as requested. The two optional Lancer native bridge tests remain opt-in; all three new figures have their own fresh native proofs and clean regenerations.

## Chosen defaults

Only implementation/proof controls were chosen: `FORM_DEFAULTS` epsilon 1e-9; `FABRIC_DEFAULTS` 8 samples per measured row span; `SKIN_NORMAL_DEFAULTS` maximum normal dot error 0.0001. The native corrective fitting uses the named `source_core_weight` and `source_fit_relaxation` fields. Native hair resolution is recorded as 48 radial samples, smooth radius interpolation and a 0.003 m union voxel size. These resolve the fitted surface; they introduce no gameplay tuning. Existing cloth physics and native neck registration are retained.

`PROOF_DEFAULTS` retains native 1024 px cells, 28 px captions, 4 px padding, RGBA background 24/24/24/255 and the existing Pillow default font. The new sheet has four columns and five rows; the approved 255 px processed crops are enlarged exactly 4× with nearest sampling and clays stay 1:1. `FIXTURE` in `tests/test_mq09_forms.py` holds the synthetic test geometry. Native jobs retain the 900-second budget; bridge waiting follows the director's 20-minute busy / 120-second idle rule.

## TODO_DESIGN and open issues

No TODO_DESIGN placeholder is needed. The six previously recorded prompt-manifest mismatches belong to earlier director-owned figures and remain unchanged. Their seven compiled specs and native delivery seals remain unchanged and validate; `../hollow_mimic/delivery/validation/baseline_compatibility.json` records this check.
