# Protagonist 2D skeletal animation experiment

This is the second pass on the painted protagonist animation study. It revises the rear character art, replaces rigid limb connections with weighted mesh joints, and authors a fuller walk with matching movement across the actual combat board. Idle, attack, block and hit remain available in both facings.

Open `inspection.tscn` for the live comparison, or follow [the verified inspection instructions](inspection.md). The viewer supports front/rear selection, five actions, walking across the floor, original/reference comparison, pause/frame-step and optional detail bones. [Second-pass rationale and research](iteration_2.md) records the user feedback, source-backed techniques and remaining limits.

## Preview artifacts

- `renders/board/videos/walking_front_rear.mp4`: front/rear walking across the real combat board, with inspection controls visible.
- `renders/board/videos/walking_front_rear_paired.gif`: paired front/rear floor-contact preview at fixed camera positions.
- `renders/walking_front_rear.gif`: paired in-place cycles at fixed scale.
- `renders/walk_iteration_comparison.mp4`: first/second-pass walks, retaining each cycle's original timing.
- `renders/animation_showcase.mp4`: the five actions from both directions.
- `references/rear_comparison.png`: canonical front, first rear interpretation and revised rear at identical scale.
- `renders/pass1/`: retained first-pass walk sheets, previews and board evidence for comparison.

## What changed

Each facing still has a real 20-bone `Skeleton2D` and five editable `AnimationPlayer` clips. The front uses the original source pixels. The rear uses a separately generated rear image and freshly placed masks/pivots; its source and complete ImageGen prompts are retained under `references/`.

The cape is a weighted `Polygon2D`. Upper/lower sleeve and trouser pieces now use paired meshes with matching source-space geometry and weights. Their existing source overlap stays attached to the same body, hand or foot bone. Elbow bands use local pin neighborhoods so endpoint locking does not collapse a whole short forearm cross-section. The boots, hands and sword remain rigid. This addresses separation at the cut boundaries while retaining their painted silhouettes.

The walk is 24 frames at 24fps, with approximately 30 source pixels of fore/aft stride, 11.6px foot lift, narrower walking foot lanes, weight transfer and counterrotation. Its 60% stance phase moves a planted foot backward relative to the body. The board's matching forward travel keeps that foot planted in world space. Attack, block and hit have staged preparation/impact/recovery; the raised block guard is visually distinct from the sword strike.

## Verification

Both neutral rigs reproduce their reference images in Godot without alpha or opaque-color mismatches. All 328 authored motion frames fit the fixed 512px canvas. The original 255px image retains offset (128, 128), so source placement never changes through per-frame cropping or recentering.

Retained proof includes:

- `renders/render_validation.json` and `renderer_proof_result.json`: both references, canvas bounds and actual renderer trajectories.
- `renders/motion_validation.json`: actual-layout IK, foot-contact/world-travel drift and loop continuity across 257 phases of every clip.
- `renders/joint_mesh_validation.json`: normalized skinning, common geometry, rigid endpoint welds and source texture identity.
- `renders/roundtrip/`: real-renderer comparisons after saving and loading both editable scenes.
- `renders/board/`: fresh 1920×1080, 100% UI proof, native focus/pause/step/travel checks and captured motion.
- `renders/asset_reproduction.json`: hashes before/after deterministic regeneration.

The screenshots and videos require visual review as well as these numeric checks. Exact rest reconstruction cannot establish convincing motion, and shared weights cannot supply missing artwork.

## Editable sources and reproduction

`cutout_assets.py` owns the front masks; `prepare_rear.py` and `rear_assets.py` own rear preparation/masks. `mesh_assets.py` authors joint topology/weights. `cutout_motion.gd` authors complete bone poses and exposes the walk displacement contract. `cutout_rig.gd` builds and saves the rig. `rigs/reaver_front.tscn` and `rigs/reaver_rear.tscn` are editable scenes; select their `Animations` node to preview clips.

From this task worktree, using Godot 4.6, Python 3/Pillow and ffmpeg:

```bash
python3 experiments/protagonist_2d/prepare_rear.py
python3 experiments/protagonist_2d/cutout_assets.py
python3 experiments/protagonist_2d/rear_assets.py
LABYRINTH_CUTOUT_POSE_MATRICES=/private/tmp/reaver-2d-v2-poses.json python3 tools/godot_task_runner.py --task-id protagonist-2d-skeletal-experiment --stream -- godot --headless --path . --script experiments/protagonist_2d/motion_contract_probe.gd
python3 experiments/protagonist_2d/joint_mesh_contract_probe.py --pose-matrices /private/tmp/reaver-2d-v2-poses.json
python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --expect-size 512x512 --timeout 60 --result-manifest /private/tmp/reaver-2d-v2-render-result.json experiments/protagonist_2d/render_frames_probe.gd --task-id protagonist-2d-skeletal-experiment
```

Pass the render probe's printed directory to `pack_renders.py '<directory>' --require-both`. Every probe rerun needs a fresh result-manifest path. The packer creates ten fixed-cell sheets and timing/anchor metadata, both saved scenes, and previews assembled only from actual rendered frames. See [inspection.md](inspection.md) for board proof and video encoding. Intermediate video frames stay outside Git.

## Limits and inspection fixture

The revised rear is closer in proportions and costume, but still infers hidden surfaces. Its hair is somewhat more rounded and its armor highlights more regular than the canonical front. [The rear-art review](references/rear_review.json) preserves that distinction.

The two paintings do not support unrestricted perspective changes. Deep bends can compress trouser texture, and larger turns or newly exposed anatomy need additional painted views or coverage. Animated shadow deformation and production performance evaluation remain outside this study.

The verified fixture is the standalone live board inspection scene. A production Continue save is not applicable: this experiment does not change production animation selection or gameplay routing. Board travel is a presentation demonstration with matching gait speed; production tile traversal, combat triggers and general directional transitions are not integrated.
