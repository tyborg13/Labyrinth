# mq-09 feedback 3 — slag_mortar

Feedback 3 shortens the crucible axis, keeps the up/back mouth and thick rolled rim, and replaces the two thin ring profiles with raised, bevelled iron belts. Native measurements include the rolled rim in the total height/outer-diameter ratio. The probe measures the two actual belt meshes, their axial width, radial relief and visible outer samples in each view. `delivery/validation/shape_measurements.json` binds these values to the native cold mesh; the separate head/harness occlusion probe remains required. The measured total ratio is **0.592205188**. There are **two** raised bands, each **7.061%** of vessel height, with positive relief and visible outer samples in both views.

The crucible is a squat, wide native hollow loft: total height / outer rim diameter is 0.592205188. It has a thick rolled rim and two raised iron body bands, each 7.061% of vessel height; its mouth faces up and back. The slag cap follows the real inner mouth and is one `mortar` feature visible in both views. The vessel, bands and cap share a rigid torso attachment whose origin remains the harness pivot between the shoulder blades. The broadened native torso and massive arms surround a low, forward head with a conformed heavy brow. Native leather apron panels have 12 mm thickness, folds, pleats and torn hems, and remain bound to `pelvis`; harness straps remain on `torso` and bracers on their forearm labels.

The sole authoring input is `measurements.json`; `spec_native.json` is generated and discarded. The approved processed paintings retain their protected SHA-256 values. All geometry is real and native on the approved CC0 humanoid armature. Every figure uses one frozen pose and mesh for the front and true 180-degree rear; no mirror, per-view pose or camera correction is used. Native corner normals survive the ownership split so the segmentation does not change the skin shading at joints.

## Numbered acceptance criteria

1. The Blender-native spec, 3/4 facing axis and rendered torso-asymmetry checks pass. The forms above implement the director's feedback; the contact sheet compares them directly with the approved paintings and the Lancer r3, Thrall mq-07 and batch-B clays.
2. Front IoU **0.783361070 → 0.799598979**; rear **0.759250602 → 0.772701972**. Every label has a nonempty solo and genuine visible owner pixels in both views. No explicit whole-part occlusion exception is needed. `delivery/fit_report.json` and the batch `part_coverage.csv` report each arm and leg part separately.
3. Shoulder observed / expected: **40.800000 / 47.137864 px**; error **6.337864 px**; 3D height difference **0.000000000 m**. Both feet are planted. Front lower foot is near, rear lower foot is far, and each lower foot is on the right. Near / far body-side pixels over torso: front **3693 / 882**; rear **0 / 15246**. The independent pixel true-turn gate passes.
4. Curated native 1024 clays, part maps, solos, joints, manifests and fit overlays are in `delivery/`. The batch contact sheet and before/after table are in `../hollow_mimic/delivery/review/`. `COMMIT_MANIFEST.txt` inventories the complete retained tree under the 6,000,000-byte cap. No `.blend`, cache, candidate or determinism copy is retained; discarded evidence is hashed before removal.
5. Native cold/cache/independent geometry, exact mesh/joint replay, ownership and mutation gates pass. A clean input-only regeneration matches all four canonical front/rear clay and part-map PNG SHA-256 values, without a reused cache. Native delivery and `acceptance_binding.json` bind those outputs, fit, pose and mutation/regeneration receipts to the current recipe and cold mesh. The clean input inventory records the exact builder source.

## Proof for the design owner

All Blender execution is through the director-owned bridge. These commands wrap that bridge; they do not launch Blender directly. Use fresh, empty proof directories.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-09 && python3 -B -m spec.art_identity.maquettes.hollow_mimic.workflow build slag_mortar --proof-subdir proof/owner_fresh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-09 && python3 -B -m spec.art_identity.maquettes.hollow_mimic.workflow regenerate slag_mortar --regeneration-subdir proof/owner_regeneration
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-09 && python3 -B -m spec.art_identity.maquettes.hollow_mimic.workflow verify slag_mortar
```

The batch sheet is regenerated with `python3 -B -m spec.art_identity.maquettes.hollow_mimic.workflow sheet`. Its first three rows are approved painting | clay, front and rear, at the same board scale. The reference row uses native 1:1 clays; the final row contains the three fit overlays. Source hashes and cell positions are recorded in `contact_sheet.json`.

No windowed Godot probe or inspection fixture applies to this offline Blender unit. The director retains commits, peer review, inspection and publication. All implementation changes are left uncommitted.

## Focused verification

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-09 && python3 -B -m unittest spec.art_identity.maquettes.blender.test_source_recipe spec.art_identity.maquettes.blender.test_delivery spec.art_identity.maquettes.blender.test_delivery_validation tests.test_maquette_blender tests.test_mq09_maquettes tests.test_mq09_forms
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-09 && python3 -B -m unittest tests.test_maquette_rear_turn
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-09 && python3 -B tests/test_art_identity_gate.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-09 && python3 -B -m spec.art_identity.maquettes.hollow_mimic.workflow verify
```

Observed final test logs are retained in `../hollow_mimic/delivery/validation/`. The full suites are left to the director at merge, as requested. The two optional Lancer native bridge tests remain opt-in; all three new figures have their own fresh native proofs and clean regenerations.

## Chosen defaults

Feedback-3 measurement controls are named in `SHAPE_DEFAULTS`, `MEASURE_DEFAULTS` and `PROBE_DEFAULTS`: hair radial-envelope centre [500,284] at 1024; 0.25-degree angle bins over [-200,60] degrees; seven-bin smoothing; 12 px valley prominence; 10-degree tip separation; alpha threshold 128; 30 m proof rays and 0.00001 m outer-band sample tolerance. These are proof-only settings. The minimum eight tips, 16 px hood tolerance, maximum 0.8 vessel ratio and minimum 4% band width come from the director.

Only implementation/proof controls were chosen: `FORM_DEFAULTS` epsilon 1e-9; `FABRIC_DEFAULTS` 8 samples per measured row span; `SKIN_NORMAL_DEFAULTS` maximum normal dot error 0.0001. The native corrective fitting uses the named `source_core_weight` and `source_fit_relaxation` fields. Native hair resolution is recorded as 48 radial samples, smooth radius interpolation and a 0.003 m union voxel size. These resolve the fitted surface; they introduce no gameplay tuning. Existing cloth physics and native neck registration are retained.

`PROOF_DEFAULTS` retains native 1024 px cells, 28 px captions, 4 px padding, RGBA background 24/24/24/255 and the existing Pillow default font. The new sheet has four columns and five rows; the approved 255 px processed crops are enlarged exactly 4× with nearest sampling and clays stay 1:1. `FIXTURE` in `tests/test_mq09_forms.py` holds the synthetic test geometry. Native jobs retain the 900-second budget; bridge waiting follows the director's 20-minute busy / 120-second idle rule.

## TODO_DESIGN and open issues

No TODO_DESIGN placeholder is needed. The six previously recorded prompt-manifest mismatches belong to earlier director-owned figures and remain unchanged. Their seven compiled specs and native delivery seals remain unchanged and validate; `../hollow_mimic/delivery/validation/baseline_compatibility.json` records this check.
