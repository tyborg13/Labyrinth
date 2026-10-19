# mq-09 — briar_weaver

15 humanoid labels plus tatters. Mantle and all its thorns share torso; forearm thorns share their forearm; the eye is one front-only head paint feature. The hunch uses the common spine/neck pose. The director authorized sculpted, shaped tatters after the simulated fringe failed: closed curved leaves on the pelvis replace that simulation.

Status: final native delivery, all quantitative acceptance gates passed. The sole authored build input is `measurements.json`; `spec_native.json` is compiled output and will be discarded by curation. Approved processed paintings are protected by SHA-256; no painting, image generation, font, audio, game data, save, analytics or runtime change is included.

## Construction

The real CC0 humanoid anatomy, heat weights and armature remain editable in the transient build. Native neck registration places the head bone at the anatomical neck instead of leaving the face weighted to the torso. Two-view measured profiles fit the skin; the corrective field is regularized without smoothing or shrinking native skin. Native skin shading flags survive the ownership split. Full feet use their observed contour from one view, retaining native depth in the opposite view. Both views share the same pose and immutable geometry; the rear is its 180-degree turn.

## Chosen defaults

Implementation/proof sampling only: anatomy subdivision level 1; corrective-field relaxation recorded in the recipe at factor 0.5; the native neck rest registration is 1.68 m. Cloth uses the existing accepted stiffness, damping, mass and collision settings, with fixed native pre-roll recorded in each recipe. Angular/longitudinal sampling and root/pivot tolerances are named in the owning builder module. Limb roots use 8 interpolated samples per source span where surface projection requires it.

Slag fist closure derives four finger groups and their returning arcs from the native webbing, palm plane and skin thickness; the implementation quantiles and 48 bisection steps live in `HAND_DEFAULTS`. Native thumb opposition uses a length-preserving two-segment solve in `THUMB_DEFAULTS`. The other figures retain their open hands. The shaped leaf support uses the existing armature collision margin and a common, permanent native-space translation along its source registration ray. Curve roots embed half their existing measured root radius in the native support. These are fitting operations, not new character design or gameplay tuning.

Proof composition uses native 1024 clay cells at the inherited 2.4 m scale, a 28 px caption strip, 4 px padding, the existing Pillow default font, background (24,24,24,255), and lossless WebP. Approved fit overlays alone are magnified with nearest sampling; clay cells are copied 1:1. No local windowed Godot run or inspection fixture applies to offline Blender maquettes.

## Proof for the design owner

All Blender execution goes through `blender/bridge_client.py`. The director continuation allows 20 minutes while another bridge job is running, and fails after 120 seconds of idle service. Each native job has its own 900-second execution budget.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-09 && python3 -B -m spec.art_identity.maquettes.hollow_mimic.workflow build briar_weaver
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-09 && python3 -B -m spec.art_identity.maquettes.hollow_mimic.workflow regenerate briar_weaver
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-09 && python3 -B -m spec.art_identity.maquettes.hollow_mimic.workflow verify briar_weaver
```

Use empty proof directories for fresh builds; retain/hash any previous intermediates before replacement. The batch sheet is produced by `workflow sheet`; `delivery/acceptance_binding.json` binds fit, pose, native mutation and verified regeneration to the cold proof; curation by `workflow curate`, after all gates and clean regeneration pass. The design owner retains commits, peer review, inspection and publication.

No TODO_DESIGN placeholders are required by the supplied brief.

## Acceptance

1. One measured recipe compiles the real CC0 humanoid, with the approved board-facing axis and rendered torso-asymmetry gates passing. Native neck registration and skin shading are preserved. The hood and mantle are simulated native cloth; pelvis-bound tatters are closed, shaped leaf meshes, as authorized in the continuation.
2. Front IoU 0.716258381; rear IoU 0.720184800. Every one of the 16 labels has a nonempty solo and genuine owner pixels in each view; no occlusion exception was needed. Exact per-part visible/solo coverage is in `delivery/fit_report.json` and the shared batch `../hollow_mimic/delivery/review/part_coverage.csv`.
3. Front shoulder offset 34.800000 px, expected 34.800000 px; error 0.000000 px, 3D height difference 0.000000000 m. Both feet are planted; front/rear pixel depth order and lower-foot-right checks pass. Values are retained in `fit_report.json`.
4. `delivery/` contains the native 1024 clays, losslessly packed part maps/solos, joints, manifests, overlay and proof receipts. `COMMIT_MANIFEST.txt` is the exhaustive <=6,000,000-byte inventory; discarded native models, cache/candidate images and proof bulk are hashed before removal.
5. Cold/cache/independent geometry hashes and exact mesh/joint replay match. Native ownership and material/modifier mutation checks pass. A clean input-only regeneration passed all four canonical clay/part-map PNG SHA-256 comparisons, with no reused cache. The native delivery validator and `acceptance_binding.json` bind these reports to the measured recipe and cold geometry.

Observed result lines:

```text
MQ09_FIT: PASS; briar_weaver; front_iou=0.716258381; rear_iou=0.720184800
CLEAN_REGENERATION: PASS; briar_weaver; canonical_png_sha256=true
```

Final shared focused test logs and the comparison sheet are retained under `../hollow_mimic/delivery/validation/` and `../hollow_mimic/delivery/review/`. The director runs the full suites at merge, as specified by this unit's proof scope. Earlier figure recipes and native delivery seals remain unchanged; six pre-existing prompt-file manifest mismatches are recorded in the shared baseline inventory report.

