# Protagonist 2D skeletal animation experiment

The third pass revises sword cuts, walking foot orientation and idle body motion, and audits every cutout in both painted facings. The canonical front and second-pass rear paintings are unchanged. This remains an isolated animation study with two editable 20-bone rigs and five actions each.

Start with [the all-action feedback reel](renders/all_animations_feedback.mp4): front and rear appear side by side, with each action twice at normal speed and once at half speed. The 22.67-second reel uses actual Godot frames with one shared fixed crop and pixel scale across every action. [Third-pass rationale](iteration_3.md) and [the complete segmentation assessment](segmentation_audit.md) document the changes and limits.

Open `inspection.tscn` for the live combat-board comparison, using [the verified launch instructions](inspection.md). It supports front/rear selection, all five actions, walking across the floor, source comparison, pause/frame-step and optional detail bones.

## Preview artifacts

- `renders/all_animations_feedback.mp4`: labeled front/rear idle, walk, attack, block and hit at normal and half speed.
- `renders/board/videos/walking_front_rear_paired.gif` and `.mp4`: simultaneous front/rear travel across the actual combat floor at native scale.
- `renders/board/videos/walking_front_rear.mp4`: traveling walks with the complete inspection controls visible.
- `renders/walking_front_rear.gif`: paired in-place walk cycles at a fixed scale.
- `renders/walk_iteration_comparison.mp4`: second/third-pass walks with matching timing and fixed framing.
- `renders/animation_showcase.mp4`: one normal-speed cycle of each action, both facings.
- `assets/front/ownership_overview.png` and `assets/rear/ownership_overview.png`: source beside color-coded cutout ownership; `exclusive_part_review.png` shows every base part.
- `renders/pass2/`: retained sheets and reports from reviewed commit `6bcc01b2d8b0e05729fe1d217a1006c902ba24e5`. `renders/pass1/` retains the earlier study.

## What changed

Attack now has a distinct preparation followed by a faster downward/across cut, authored separately for the opposing painted sword orientations. The walk retains its 24-frame, one-second stride and matching floor travel; the near boots turn toward the direction of movement, with a correction based on their painted soles to preserve floor contact. The idle is a 20-frame, 0.833-second coordinated body bob with delayed sword motion and little cloth movement relative to the torso. Its cadence and body coherence follow the authored idle sheet. Block and hit retain their second-pass motion.

The segmentation audit covers all 17 front and 14 rear exclusive base parts. It corrects exposed arm material left on the cloak, bracer material assigned to the hands, green cloth attached to the scarf/torso, knee boundaries and stray outline islands. Every reassigned pixel keeps its original RGBA. The audit checks source landmarks, garment boundaries, connected components and exported cutouts; full rendered pose inspection checks how those parts behave in motion.

The cape and paired upper/lower sleeve and trouser meshes retain the source-space geometry and shared weights established in pass two. Hands, boots and sword remain rigid. Source-only seam overlaps stay local to adjacent body parts. No hidden anatomy is painted into the cutouts.

## Verification

Both neutral rigs reproduce their reference images in Godot with zero differing RGBA pixels. All 272 authored motion frames fit the fixed 512px canvas: idle 20, walk 24, attack 32, block 36 and hit 24 per facing. The original 255px source retains offset (128, 128); per-frame cropping or recentering never changes registration.

Retained proof includes:

- `assets/segmentation_audit.json`: 78 selected anatomical/material landmarks, 709 boundary-region pixels, all 31 exclusive parts and 37 saved cutout checks.
- `renders/render_validation.json` and `renderer_proof_result.json`: references, frame bounds, actual-renderer trajectories and runtime input hashes.
- `renders/motion_validation.json`: actual-layout IK, toe direction, painted sole depth, body-bob coherence, downward cut direction, foot-contact/world-travel drift and loop continuity across 257 phases per clip/facing.
- `renders/joint_mesh_validation.json`: normalized weights, common geometry, rigid endpoint welds and source texture identity through all 272 poses.
- `renders/roundtrip/`: ten pixel-identical actual-renderer comparisons after saving/reloading both editable scenes, including a non-neutral idle pose.
- `renders/board/`: fresh inspected 1920×1080, 100% UI proof, 38 native screenshots, 416 pose/travel checks and complete captured walking sequences. Input and output hashes bind the proof to the delivered files.
- `renders/asset_reproduction.json`: all 67 core generated files reproduced byte-identically in an isolated directory.
- `renders/feedback_reel_validation.json`: source hashes, fixed framing, action/speed timing, frame counts and complete video decoding.

Visual inspection covers every source part and all 272 final poses, plus the native board screenshots and all 72 paired travel frames. Numeric checks alone cannot establish convincing motion or semantic ownership. Native pointer/keyboard controls, pause/frame-step, source comparison and detail-only bones remain verified in the board fixture.

## Editable sources and reproduction

`cutout_assets.py` owns the front masks; `prepare_rear.py` and `rear_assets.py` own rear preparation/masks. `mesh_assets.py` owns joint topology/weights. `segmentation_audit.py` evaluates and illustrates source ownership. `cutout_motion.gd` authors complete bone poses and the walk displacement contract. `cutout_rig.gd` builds and saves the rigs. In `rigs/reaver_front.tscn` or `rigs/reaver_rear.tscn`, select the `Animations` node to preview the editable clips.

From this task worktree, using Godot 4.6, Python 3/Pillow and ffmpeg:

```bash
python3 experiments/protagonist_2d/prepare_rear.py
python3 experiments/protagonist_2d/cutout_assets.py
python3 experiments/protagonist_2d/rear_assets.py
python3 experiments/protagonist_2d/segmentation_audit.py
LABYRINTH_CUTOUT_POSE_MATRICES=/private/tmp/reaver-2d-v3-poses.json python3 tools/godot_task_runner.py --task-id protagonist-2d-skeletal-experiment --stream -- godot --headless --path . --script experiments/protagonist_2d/motion_contract_probe.gd
python3 experiments/protagonist_2d/joint_mesh_contract_probe.py --pose-matrices /private/tmp/reaver-2d-v3-poses.json
python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --expect-size 512x512 --timeout 60 --result-manifest /private/tmp/reaver-2d-v3-render-result.json experiments/protagonist_2d/render_frames_probe.gd --task-id protagonist-2d-skeletal-experiment
```

Pass the render probe's printed directory to `pack_renders.py '<directory>' --require-both`. Every rerun needs a fresh result-manifest path. The packer creates ten fixed-cell sheets, timing/anchor metadata, both saved scenes and previews made only from the actual rendered frames. It invokes `feedback_reel.py` for the labeled normal/half-speed review. Half speed repeats source frames without interpolation. Intermediate video frames stay outside Git. See [inspection.md](inspection.md) for board capture and encoding.

## Limits and inspection fixture

The rear is a separately authored interpretation of hidden surfaces; its hair and armor highlights still differ somewhat from the canonical front. [The second-pass rationale](iteration_2.md) and [rear-art review](references/rear_review.json) preserve that distinction.

The boot turn rotates painted 2D pieces; a true change of perspective needs another painted boot view. Deep bends can compress trouser texture, and large turns or newly exposed anatomy need additional artwork. Animated shadow deformation and production performance evaluation remain outside this study.

The verified fixture is the standalone live board inspection scene. A production Continue save is not applicable: this experiment changes no production animation selection or gameplay routing. Board travel demonstrates matching gait speed; production tile traversal, combat triggers and general directional transitions are not integrated.
