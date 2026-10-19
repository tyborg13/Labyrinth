# mq-09 — slag_mortar

15 humanoid labels plus mortar and apron. Harness straps share torso; bracers share their forearms. The native CC0 fingers close into the palm. Every crucible band and its single slag surface share mortar, parented to torso with their editable origins at mortar_pivot between the shoulder blades. The slag surface has native visibility checks in both views.

Status: final native delivery; all quantitative acceptance and clean-regeneration gates passed. The sole authored build input is `measurements.json`; `spec_native.json` is compiled output and will be discarded by curation. Approved processed paintings are protected by SHA-256; no painting, image generation, font, audio, game data, save, analytics or runtime change is included.

## Construction

The real CC0 humanoid anatomy, heat weights and armature remain editable in the transient build. Native neck registration places the head bone at the anatomical neck instead of leaving the face weighted to the torso. Two-view measured profiles fit the skin; the corrective field is regularized without smoothing or shrinking native skin. Native skin shading flags survive the ownership split. The torso retains the original anatomical shape instead of a row-wise chest warp; the remaining profiles fit the hulking limb proportions. Both cloth aprons are pelvis-bound. Full feet use their observed contour from one view, retaining native depth in the opposite view. Both views share the same pose and immutable geometry; the rear is its 180-degree turn.

## Chosen defaults

Implementation/proof sampling only: anatomy subdivision level 1; corrective-field relaxation recorded in the recipe at factor 0.5; the native neck rest registration is 1.68 m. Cloth uses the existing accepted stiffness, damping, mass and collision settings, with fixed native pre-roll recorded in each recipe. Angular/longitudinal sampling and root/pivot tolerances are named in the owning builder module. Limb roots use 8 interpolated samples per source span where surface projection requires it.

Slag fist closure derives four finger groups and their returning arcs from the native webbing, palm plane and skin thickness; the implementation quantiles and 48 bisection steps live in `HAND_DEFAULTS`. Native thumb opposition uses a length-preserving two-segment solve in `THUMB_DEFAULTS`. The other figures retain their open hands. The shaped leaf support uses the existing armature collision margin and a common, permanent native-space translation along its source registration ray. Curve roots embed half their existing measured root radius in the native support. These are fitting operations, not new character design or gameplay tuning.

Proof composition uses native 1024 clay cells at the inherited 2.4 m scale, a 28 px caption strip, 4 px padding, the existing Pillow default font, background (24,24,24,255), and lossless WebP. Approved fit overlays alone are magnified with nearest sampling; clay cells are copied 1:1. No local windowed Godot run or inspection fixture applies to offline Blender maquettes.

## Proof for the design owner

All Blender execution goes through `blender/bridge_client.py`. The director continuation allows 20 minutes while another bridge job is running, and fails after 120 seconds of idle service. Each native job has its own 900-second execution budget.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-09 && python3 -B -m spec.art_identity.maquettes.hollow_mimic.workflow build slag_mortar
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-09 && python3 -B -m spec.art_identity.maquettes.hollow_mimic.workflow regenerate slag_mortar
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-09 && python3 -B -m spec.art_identity.maquettes.hollow_mimic.workflow verify slag_mortar
```

Use empty proof directories for fresh builds; retain/hash any previous intermediates before replacement. The batch sheet is produced by `workflow sheet`; `delivery/acceptance_binding.json` binds fit, pose, native mutation and verified regeneration to the cold proof; curation by `workflow curate`, after all gates and clean regeneration pass. The design owner retains commits, peer review, inspection and publication.

No TODO_DESIGN placeholders are required by the supplied brief.

## Acceptance

1. The sole measured recipe compiles the real CC0 anatomy and humanoid armature, with board-facing and torso-asymmetry gates passing. Native neck registration and skin shading are preserved. The hidden rear head outline is not guessed: the complete front contour fits the same forward-posed skull. The crucible fits the approved rim and axis; its surface follows the inner native mouth one wall thickness below the rim. The measured lower-body spans and their width registration are recorded in `body_span_fit`. Fingers/thumbs close using the original native skin and topology. The rigid mortar/bands share `mortar_pivot` on torso. Both leather aprons use native cloth attached to the measured waist, with a directional hip-frame rest keeping free fabric on the correct side of the legs.
2. Front IoU 0.807755131; rear IoU 0.657356636. All 17 labels have nonempty solos and genuine owner pixels in both views, with no occlusion exception. Exact per-part coverage is in `delivery/fit_report.json` and `../hollow_mimic/delivery/review/part_coverage.csv`.
3. Front shoulder offset 40.800000 px, expected 47.137864 px; error 6.337864 px (within the brief's 10 px tolerance). 3D shoulder height difference 0.000000000 m. Both feet are planted, and both pixel true-turn views pass. Front near/far body-side pixels over torso: 115/0; rear: 0/8303. The front head has zero genuine mortar pixels over its solo; the rear has 1304. The bridge-only `occlusion_probe.py` independently ray-tests the anterior skull, posterior skull and harness pivot: front face first owner=head; rear skull and rear pivot first owner=mortar. This report is bound to the current spec and cold mesh.
4. `delivery/` contains native 1024 clays, packed part maps and solos, joints, manifests, overlay and compact proof receipts. The exhaustive `COMMIT_MANIFEST.txt` is capped at 6,000,000 bytes. Models, caches, candidates and proof bulk are hashed before removal. The single batch contact sheet uses native 1:1 clay cells for all three figures and the Lancer r3, Thrall r2 and both batch-B references.
5. Native cold/cache/independent geometry, exact mesh/joint replay, ownership, rigid binding/pivot, single slag-surface visibility in both views, modifier/material mutation, and front/rear head-occlusion gates pass. Clean regeneration and its hash-bound receipt are retained in `delivery/validation/` and `delivery/acceptance_binding.json`.

Observed result lines:

```text
MQ09_FIT: PASS; slag_mortar; front_iou=0.807755131; rear_iou=0.657356636
MQ09_HEAD_OCCLUSION: PASS
CLEAN_REGENERATION: PASS; slag_mortar; canonical_png_sha256=true
```

The probe's named defaults are upper_skull_fraction=0.5 and ray_distance_m=30. The first selects a proof sample above the neck; the second matches the existing native feature ray length. They do not add appearance controls. Pixel occlusion uses the existing coverage alpha threshold and genuine-colour tolerance, excluding nearest-colour antialias false positives.

Final shared focused test logs and the comparison sheet are in `../hollow_mimic/delivery/validation/` and `../hollow_mimic/delivery/review/`. The director runs the full suites at merge, as specified by the unit brief. Earlier figure recipes and native seals remain unchanged; six pre-existing prompt-file inventory mismatches are retained in the shared baseline report.
