# mq-09 — hollow_mimic

15 humanoid labels. Hair and mask share head; the violet crack is a single front-only paint feature. Open, clawless native glove hands; no cape or weapon.

Status: final native delivery, all quantitative acceptance gates passed. The sole authored build input is `measurements.json`; `spec_native.json` is compiled output and will be discarded by curation. Approved processed paintings are protected by SHA-256; no painting, image generation, font, audio, game data, save, analytics or runtime change is included.

## Construction

The real CC0 humanoid anatomy, heat weights and armature remain editable in the transient build. Native neck registration places the head bone at the anatomical neck instead of leaving the face weighted to the torso. Two-view measured profiles fit the skin; the corrective field is regularized without smoothing or shrinking native skin. Native skin shading flags survive the ownership split. The native torso and pelvis retain their anatomical shape instead of acquiring a row-wise silhouette warp. The fitted limb displacement field uses 64 relaxation iterations. Full feet use their observed contour from one view, retaining native depth in the opposite view. Both views share the same pose and immutable geometry; the rear is its 180-degree turn.

## Chosen defaults

Implementation/proof sampling only: anatomy subdivision level 1; corrective-field relaxation recorded in the recipe at factor 0.5; the native neck rest registration is 1.68 m. Cloth uses the existing accepted stiffness, damping, mass and collision settings, with fixed native pre-roll recorded in each recipe. Angular/longitudinal sampling and root/pivot tolerances are named in the owning builder module. Limb roots use 8 interpolated samples per source span where surface projection requires it.

Slag fist closure derives four finger groups and their returning arcs from the native webbing, palm plane and skin thickness; the implementation quantiles and 48 bisection steps live in `HAND_DEFAULTS`. Native thumb opposition uses a length-preserving two-segment solve in `THUMB_DEFAULTS`. The other figures retain their open hands. The shaped leaf support uses the existing armature collision margin and a common, permanent native-space translation along its source registration ray. Curve roots embed half their existing measured root radius in the native support. These are fitting operations, not new character design or gameplay tuning.

Proof composition uses native 1024 clay cells at the inherited 2.4 m scale, a 28 px caption strip, 4 px padding, the existing Pillow default font, background (24,24,24,255), and lossless WebP. Approved fit overlays alone are magnified with nearest sampling; clay cells are copied 1:1. No local windowed Godot run or inspection fixture applies to offline Blender maquettes.

## Proof for the design owner

All Blender execution goes through `blender/bridge_client.py`. The director continuation allows 20 minutes while another bridge job is running, and fails after 120 seconds of idle service. Each native job has its own 900-second execution budget.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-09 && python3 -B -m spec.art_identity.maquettes.hollow_mimic.workflow build hollow_mimic
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-09 && python3 -B -m spec.art_identity.maquettes.hollow_mimic.workflow regenerate hollow_mimic
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-09 && python3 -B -m spec.art_identity.maquettes.hollow_mimic.workflow verify hollow_mimic
```

Use empty proof directories for fresh builds; retain/hash any previous intermediates before replacement. The batch sheet is produced by `workflow sheet`; `delivery/acceptance_binding.json` binds fit, pose, native mutation and verified regeneration to the cold proof; curation by `workflow curate`, after all gates and clean regeneration pass. The design owner retains commits, peer review, inspection and publication.

No TODO_DESIGN placeholders are required by the supplied brief.

## Acceptance

1. One measured recipe compiles the real CC0 humanoid with the board-facing axis and rendered torso-asymmetry gates passing. Native neck registration, anatomical torso/pelvis shape and native skin shading survive fitting and ownership partitioning. Hair and the fitted mask share head; the single crack is front-only paint metadata.
2. Front IoU 0.748841419; rear IoU 0.668356378. Every one of the 15 labels has a nonempty solo and genuine owner pixels in each view; no occlusion exception was needed. Exact per-part visible/solo coverage is in `delivery/fit_report.json` and `delivery/review/part_coverage.csv`.
3. Front shoulder offset 28.800000 px, expected 28.800000 px; error 0.000000 px, 3D height difference 0.000000000 m. Both feet are planted; front/rear pixel depth order and lower-foot-right checks pass. Front near/far body-side pixels over torso: 1412/0; rear: 0/2897.
4. `delivery/` contains the native 1024 clays, losslessly packed part maps/solos, joints, manifests, fit overlay and receipts. The single batch contact sheet includes all three overlays and front/rear clays, with Lancer r3, Thrall r2 and both batch-B figures at native 1:1 scale. `COMMIT_MANIFEST.txt` is exhaustive and capped at 6,000,000 bytes. Discarded models, caches, candidate renders and proof bulk are hashed before removal.
5. Cold/cache/independent geometry hashes and exact mesh/joint replay match. Native ownership and material/modifier mutation checks pass. A clean input-only regeneration passed all four canonical clay/part-map PNG SHA-256 comparisons, without a reused cache. The native validator and `acceptance_binding.json` bind the delivery and its fit, pose, mutation and regeneration evidence to the current measured recipe and cold geometry. A mutation test changes an otherwise passing IoU report and requires validation to reject it.

Observed native result lines:

```text
MQ09_FIT: PASS; hollow_mimic; front_iou=0.748841419; rear_iou=0.668356378
CLEAN_REGENERATION: PASS; hollow_mimic; canonical_png_sha256=true
```

Final focused test logs are retained in `delivery/validation/`. The director runs the full suites at merge, as specified by this unit's proof scope. No windowed Godot probe or inspection-fixture command applies to this offline Blender delivery. Earlier figure recipes and native delivery seals remain unchanged; the baseline compatibility report covers all seven existing measured recipes. The separate baseline inventory report retains six pre-existing prompt-file manifest mismatches, without altering those figures.


## Focused verification commands

```sh
python3 -B -m unittest spec.art_identity.maquettes.blender.test_source_recipe spec.art_identity.maquettes.blender.test_delivery spec.art_identity.maquettes.blender.test_delivery_validation tests.test_maquette_blender tests.test_mq09_maquettes
python3 -B -m unittest tests.test_maquette_rear_turn
python3 -B tests/test_art_identity_gate.py
python3 -B -m spec.art_identity.maquettes.hollow_mimic.workflow verify
```

The two optional Lancer bridge tests in `tests.test_maquette_blender` remain opt-in; the batch runs its own native cold/cache, exact replay, mutation and clean regeneration jobs for all three figures.

Additional named fitting/proof defaults are in `HAND_DEFAULTS` and `THUMB_DEFAULTS` (native anatomical contact solve), `ROOT_DEFAULTS` (root epsilon 1e-8 m), `PIVOT_DEFAULTS` (native pivot tolerance 1e-6 m), `PROOF_DEFAULTS` (1024 native pixels; shoulder tolerance 10 px from the brief, joint projection tolerance .02 px, proof-only level tolerance 1e-8 m; header 28 px, padding 4 px, RGBA background 24/24/24/255, white default-font captions, overlay opacity .4) and `WORKFLOW_DEFAULTS` (900-second native jobs). These are procedural/proof controls; the approved paintings remain the design source.
