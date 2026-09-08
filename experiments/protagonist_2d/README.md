# Protagonist 2D skeletal animation experiment

The fourth pass raises the attack preparation overhead, speeds up walking by 50%, relaxes airborne boots, steadies idle knees, closes shoulder/leg gaps and brings the guard across the front body. The canonical front and second-pass rear paintings are unchanged. This remains an isolated animation study with two editable 20-bone rigs and five actions each.

Start with [the all-action combat-board reel](renders/board/videos/all_animations_board.mp4): front and rear appear side by side, with every action twice at normal speed and once at half speed. The 26.67-second reel uses a single native-pixel crop of the actual Godot board across every action and complete walk path. [Fourth-pass rationale](iteration_4.md) documents the motion and attachment changes; [the segmentation assessment](segmentation_audit.md) preserves the underlying source ownership audit.

Open `inspection.tscn` for the live combat-board comparison, using [the verified launch instructions](inspection.md). It supports front/rear selection, all five actions, walking across the floor, source comparison, pause/frame-step and optional detail bones.

## Preview artifacts

- `renders/board/videos/all_animations_board.mp4`: primary proof, all five actions and both facings on the real combat floor at normal/half speed.
- `renders/board/videos/protagonist_2d_showcase.mp4`: every action with the complete 1920×1080 inspection surface visible.
- `renders/all_animations_feedback.mp4`: supplemental in-place, magnified motion/seam review.
- `renders/board/videos/walking_front_rear_paired.gif` and `.mp4`: simultaneous front/rear travel across the actual combat floor at native scale.
- `renders/board/videos/walking_front_rear.mp4`: traveling walks with the complete inspection controls visible.
- `renders/walking_front_rear.gif`: paired in-place walk cycles at a fixed scale.
- `renders/walk_iteration_comparison.mp4`: third/fourth-pass walks with accurate 24/36fps timing and fixed framing.
- `renders/animation_showcase.mp4`: one normal-speed cycle of each action, both facings.
- `assets/front/ownership_overview.png` and `assets/rear/ownership_overview.png`: source beside color-coded cutout ownership; `exclusive_part_review.png` shows every base part.
- `renders/pass3/`: action sheets, reports and reel from reviewed commit `1ce20af71335f2f4ac64cfead08fedef34111ee2`.
- `renders/pass2/`: retained sheets and reports from reviewed commit `6bcc01b2d8b0e05729fe1d217a1006c902ba24e5`. `renders/pass1/` retains the earlier study.

## What changed

Attack raises the sword almost vertically, pauses briefly, then cuts down and across the space ahead while the blade remains above foot level. The front guard crosses the chest; the rear guard is a high diagonal partly occluded by the head. The walk uses 24 poses at 36fps (0.667 seconds per stride); board travel increases by the same 50%. Boots turn less while planted and relax through swing instead of curling toward the knee. Ground clearance is calculated from the actual rotated painted sole. Idle retains the accepted body bob but counter-translates both leg chains so their original angles and positions remain steady.

The segmentation audit covers all 17 front and 14 rear exclusive base parts. It corrects exposed arm material left on the cloak, bracer material assigned to the hands, green cloth attached to the scarf/torso, knee boundaries and stray outline islands. Every reassigned pixel keeps its original RGBA. The audit checks source landmarks, garment boundaries, connected components and exported cutouts; full rendered pose inspection checks how those parts behave in motion.

The paired sleeve and trouser meshes use local endpoint weights to keep the joints attached while reducing folded texture. The front arm emerging from beneath the cloak follows the same cape weights at its concealed shoulder, then blends into its arm weights down the sleeve. Both source paintings and every exclusive cutout pixel remain unchanged from pass three. Hands, boots and sword remain rigid. Source-only seam overlaps stay local to adjacent body parts. No hidden anatomy is painted into the cutouts.

## Verification

Both neutral rigs reproduce their reference images in Godot with zero differing RGBA pixels. All 272 authored motion frames fit the fixed 512px canvas: idle 20, walk 24, attack 32, block 36 and hit 24 per facing. The original 255px source retains offset (128, 128); per-frame cropping or recentering never changes registration.

Retained proof includes:

- `assets/segmentation_audit.json`: 78 selected anatomical/material landmarks, 709 boundary-region pixels, all 31 exclusive parts and 37 saved cutout checks.
- `renders/render_validation.json` and `renderer_proof_result.json`: references, frame bounds, actual-renderer trajectories and runtime input hashes.
- `renders/motion_validation.json`: actual-layout IK, toe-to-knee clearance, painted sole depth, idle leg stability, overhead/forward sword path, foot-contact/world-travel drift and loop continuity across 257 phases per clip/facing.
- `renders/joint_mesh_validation.json`: normalized weights, common geometry, rigid endpoint welds and source texture identity through all 272 poses.
- `renders/roundtrip/`: ten pixel-identical actual-renderer comparisons after saving/reloading both editable scenes, including a non-neutral idle pose.
- `renders/board/`: fresh inspected 1920×1080, 100% UI proof, 40 native screenshots, 416 pose/travel checks and 368 captured motion frames covering all ten action/facing combinations. Input and output hashes bind the proof to the delivered files.
- `renders/asset_reproduction.json`: all 67 core generated files reproduced byte-identically in an isolated directory.
- `renders/board/videos/board_feedback_reel_validation.json` and `renders/feedback_reel_validation.json`: source hashes, fixed framing, accurate 24/36fps action timing, normal/half-speed segments and complete video decoding.

Visual inspection covers every source part and all 272 final poses, plus the native board screenshots and all 72 paired travel poses at native board scale. Full-surface screenshots additionally verify focus, controls, detail and references. Numeric checks alone cannot establish convincing motion or semantic ownership. Native pointer/keyboard controls, pause/frame-step, source comparison and detail-only bones remain verified in the board fixture.

## Editable sources and reproduction

`cutout_assets.py` owns the front masks; `prepare_rear.py` and `rear_assets.py` own rear preparation/masks. `mesh_assets.py` owns joint topology/weights. `segmentation_audit.py` evaluates and illustrates source ownership. `cutout_motion.gd` authors complete bone poses and the walk displacement contract. `cutout_rig.gd` builds and saves the rigs. In `rigs/reaver_front.tscn` or `rigs/reaver_rear.tscn`, select the `Animations` node to preview the editable clips.

From this task worktree, using Godot 4.6, Python 3/Pillow and ffmpeg:

```bash
python3 experiments/protagonist_2d/prepare_rear.py
python3 experiments/protagonist_2d/cutout_assets.py
python3 experiments/protagonist_2d/rear_assets.py
python3 experiments/protagonist_2d/segmentation_audit.py
LABYRINTH_CUTOUT_POSE_MATRICES=/private/tmp/reaver-2d-v4-poses.json python3 tools/godot_task_runner.py --task-id protagonist-2d-skeletal-experiment --stream -- godot --headless --path . --script experiments/protagonist_2d/motion_contract_probe.gd
python3 experiments/protagonist_2d/joint_mesh_contract_probe.py --pose-matrices /private/tmp/reaver-2d-v4-poses.json
python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --expect-size 512x512 --timeout 60 --result-manifest /private/tmp/reaver-2d-v4-render-result.json experiments/protagonist_2d/render_frames_probe.gd --task-id protagonist-2d-skeletal-experiment
```

Pass the render probe's printed directory to `pack_renders.py '<directory>' --require-both`. Every rerun needs a fresh result-manifest path. The packer creates ten fixed-cell sheets, timing/anchor metadata, both saved scenes and previews made only from the actual rendered frames. It invokes `feedback_reel.py` for the labeled normal/half-speed review. Half speed repeats source frames without interpolation. Intermediate video frames stay outside Git. See [inspection.md](inspection.md) for board capture and encoding.

## Limits and inspection fixture

The rear is a separately authored interpretation of hidden surfaces; its hair and armor highlights still differ somewhat from the canonical front. [The second-pass rationale](iteration_2.md) and [rear-art review](references/rear_review.json) preserve that distinction.

The boot turn rotates painted 2D pieces; a true change of perspective needs another painted boot view. Deep bends can compress trouser texture, and large turns or newly exposed anatomy need additional artwork. Animated shadow deformation and production performance evaluation remain outside this study.

The verified fixture is the standalone live board inspection scene. A production Continue save is not applicable: this experiment changes no production animation selection or gameplay routing. Board travel demonstrates matching gait speed; production tile traversal, combat triggers and general directional transitions are not integrated.
