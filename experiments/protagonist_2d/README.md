# Protagonist 2D skeletal animation experiment

The fifth pass adds newly generated complete limbs, gloves, boots, hidden pelvis material and a sword grip while preserving the recognizable head, scarf, torso, belt, cloak and chipped blade. Both front/rear rigs are editable, with 21 bones and five actions each. The new relaxed assembly gives the joints room to move and the boots an appropriate painted perspective.

Start with [the all-action combat-board reel](renders/board/videos/all_animations_board.mp4): front and rear appear side by side, with every action twice at normal speed and once at half speed. The 26.67-second reel uses a single native-pixel crop of the actual Godot board across every action and complete walk path. [Fifth-pass rationale](iteration_5.md) explains the art selection and rig changes; [the identity/assembly comparison](references/pass5/assembly_review.png) shows the new neutral pose beside the reference.

Open `inspection.tscn` for the live combat-board comparison, using [the verified launch instructions](inspection.md). It supports front/rear selection, all five actions, walking across the floor, source comparison, pause/frame-step and optional detail bones.

## Preview artifacts

- `renders/board/videos/all_animations_board.mp4`: primary proof, all five actions and both facings on the real combat floor at normal/half speed.
- `renders/board/videos/protagonist_2d_showcase.mp4`: every action with the complete 1920×1080 inspection surface visible.
- `renders/all_animations_feedback.mp4`: supplemental in-place, magnified motion/seam review.
- `renders/board/videos/walking_front_rear_paired.gif` and `.mp4`: simultaneous front/rear travel at native board scale.
- `renders/walk_iteration_comparison.mp4`: fourth/fifth-pass walks, both at their accurate 36fps cadence with fixed framing.
- `renders/walking_front_rear.gif`: paired in-place walk cycles.
- `renders/animation_showcase.mp4`: one normal-speed cycle of each action, both facings.
- `references/pass5/`: accepted ImageGen sources, prompts and candidate assessments, frozen baseline layouts, and assembled reference images.
- `assets/pass5/front/` and `assets/pass5/rear/`: native complete appendages, their overlapping rig pieces, pelvis and weapon components.
- `renders/pass4/`: retained sheets, reports and reels from reviewed commit `a3d2bce6f45f775b311fa59dd7326bfab9995afc`. Earlier studies remain under `renders/pass1` through `pass3`.

## Artwork and motion

Built-in ImageGen supplied the new artwork. A full-character redraw was rejected for changing the face, palette and paint density. Two limb atlases were also rejected for false transparency or overly fine texture. The selected art uses dark grouped values, sparse ochre highlights, complete hidden joints and separately painted front/rear boot views. [Prompts and verdicts](references/pass5/prompts.json) retain those decisions and source filenames.

`articulated_assets.py` keys, crops and scales the accepted source art with nearest-neighbor sampling, partitions local overlaps and builds the skin weights. The canonical identity cutouts and cape texture remain byte-identical to pass four. The old hand is removed from the compound sword asset; its chipped blade/crossguard are retained, with a new narrow grip shaft and closed glove. The sword has its own bone so strong weapon rotation does not fold the wrist texture. A painted pelvis underlay supplies material behind the belt and moving thighs.

Each facing has six limb meshes: two overlapping pieces per sleeve and one continuous mesh per leg. Their glove/boot collars share the rigid terminal bone. Complete upper caps rotate into the body overlap instead of pinning their full width to the torso. The front cloak covers the concealed sleeve shoulder while the forearm can emerge in front of it.

Attack raises the blade nearly vertically above the head, briefly holds, then cuts down and forward above foot level. Front block crosses the chest; rear block is a high diagonal partly hidden by the head. Walking retains 24 poses at 36fps (0.667 seconds per cycle), with a 34px stride and matching 56.67px board displacement per cycle. The new painted boot views need only small swing rotation. Actual sole contours control ground clearance. Idle keeps its body bob while counter-translating the leg chains so the knees stay steady.

## Verification

The neutral rigs reproduce their **new assembled reference images** in Godot: no alpha mismatches or color differences exceeding one 8-bit code value. The original paintings remain identity comparisons, not reconstruction targets for the changed pose. All 272 authored motion frames fit the fixed 512px canvas: idle 20, walk 24, attack 32, block 36 and hit 24 per facing. The 255px coordinate system retains offset (128,128); no per-frame crop or recentering changes registration.

Retained proof includes:

- `renders/render_validation.json` and `renderer_proof_result.json`: assembled references, frame bounds, actual-renderer trajectories and input hashes.
- `renders/motion_validation.json`: actual-layout IK, toe/knee clearance, sole depth, idle stability, sword path, foot-contact/world-travel drift and loop continuity across 257 phases per action/facing.
- `renders/joint_mesh_validation.json`: identity hashes, normalized weights, common sleeve geometry, glove/boot welds, and no collapsed or reversed opaque limb triangles through all 272 authored poses. Actual rendered frames also have no detached opaque component of eight pixels or more; this supplements visual inspection.
- `renders/roundtrip/`: ten pixel-identical renderer comparisons after saving/reloading the two editable scenes, including non-neutral idle.
- `renders/board/`: inspected 1920×1080, 100% UI proof, 40 native screenshots, 416 pose/travel checks and 368 captured motion frames covering all ten action/facing combinations. Input/output hashes bind the proof to the delivered files.
- `renders/asset_reproduction.json`: all 39 fifth-pass generated files reproduced byte-identically from retained source images and baseline assets in an isolated directory.
- `renders/board/videos/board_feedback_reel_validation.json` and `renders/feedback_reel_validation.json`: source hashes, fixed framing, exact 24/36fps action timing, normal/half-speed segments and complete decoding.

Visual inspection covers the new assembly, all 272 final poses, all 40 native board regions and all 72 paired travel poses. Full-surface screenshots additionally check focus, controls, detail and references. Numeric checks alone cannot establish convincing motion or an art match.

## Editable sources and reproduction

`articulated_assets.py` owns the current artwork import and rig layout. `cutout_motion.gd` authors complete bone poses and the walk displacement contract. `cutout_rig.gd` builds and saves the rigs. In `rigs/reaver_front.tscn` or `rigs/reaver_rear.tscn`, select `Animations` to preview the editable clips.

The older `cutout_assets.py`, `prepare_rear.py`, `rear_assets.py`, `mesh_assets.py` and `segmentation_audit.py` describe the historical source-only pipeline. Their audits and ownership images apply to that baseline. Do not run those builders to reproduce pass five; the frozen layouts under `references/pass5/` are its identity inputs.

From this task worktree, using Godot 4.6, Python 3/Pillow and ffmpeg:

```bash
python3 experiments/protagonist_2d/articulated_assets.py
LABYRINTH_CUTOUT_POSE_MATRICES=/private/tmp/reaver-2d-v5-poses.json python3 tools/godot_task_runner.py --task-id protagonist-2d-skeletal-experiment --stream -- godot --headless --path . --script experiments/protagonist_2d/motion_contract_probe.gd
python3 experiments/protagonist_2d/articulated_contract_probe.py --pose-matrices /private/tmp/reaver-2d-v5-poses.json
python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --expect-size 512x512 --timeout 60 --result-manifest /private/tmp/reaver-2d-v5-render-result.json experiments/protagonist_2d/render_frames_probe.gd --task-id protagonist-2d-skeletal-experiment
```

Pass the render probe's printed directory to `pack_renders.py '<directory>' --require-both` and to `articulated_contract_probe.py --pose-matrices '<pose-matrices>' --renders '<directory>'`. Every rerun needs a fresh result-manifest path. The packer creates ten fixed-cell sheets, timing/anchor metadata, both saved scenes and previews from actual rendered frames. It invokes `feedback_reel.py` for normal/half-speed review; half speed duplicates frames without interpolation. See [inspection.md](inspection.md) for board capture/encoding.

## Limits and inspection fixture

The retained rear head/body/cloak are the earlier interpretation of hidden surfaces; their hair and highlights differ somewhat from the canonical front. The new arms and legs match the costume and palette but are a new painting, with a more relaxed silhouette. Two fixed facings do not provide continuous 3D turns; additional views would require more artwork. Strong bends still compress texture even without triangle reversal.

The verified fixture is the standalone live board inspection scene. A production Continue save is not applicable: this experiment changes no production animation selection or gameplay routing. Board travel demonstrates matching gait speed; production tile traversal, combat triggers and directional transitions are not integrated. The production static-reference shadow is reused; animated shadow deformation and production performance evaluation remain outside this study.
