# Protagonist 2D skeletal animation experiment

This experiment tests whether the existing painted protagonist can gain useful animations through a 2D cutout rig. The priority here is walking from both front and rear while keeping the game’s painted appearance.

Open `inspection.tscn` to compare the live rig with its static reference on the actual combat board. The rig runs inside a transparent SubViewport; the board receives its live texture. The top comparison shows the original 255px framing, and the detail view can expose the bones. See [inspection.md](inspection.md) for the verified launch and proof commands.

## Results and limits

Both views have a real 20-bone `Skeleton2D`, cropped painted `Sprite2D` parts, a weighted `Polygon2D` cape, and five editable `AnimationPlayer` clips: idle, walk, attack, block, and hit. The front uses the exact original sprite pixels. The rear uses a separately generated, reviewed rear view; it is not a mirror of the front.

The neutral front and rear rigs render pixel-identically to their respective reference images: zero alpha differences and zero color differences in the actual Godot renderer. All 344 animation frames fit one 512px canvas without per-frame cropping, scaling or recentering. The original 255px image occupies offset (128,128); this stable mapping keeps the character’s board placement and health bar unchanged.

The walk was tuned at native board size, using 4.5 source pixels of travel, 6.5 of lift, and opposing arm motion. Inspected front/rear frames retain connected knees and ankles. The motion is an in-place walking study, not integrated board traversal. Hit, guard and sword gestures work within a limited range. Large turns, extreme foreshortening and newly exposed surfaces still need additional painted views or repaired layers; this is not a general 360-degree character.

The rear reference is a plausible interpretation of hidden costume details. Its leather detailing is somewhat more ornate than the front. Its first version was rejected for a cloak reaching too close to the boot soles and an opaque painted checkerboard. The retained corrected version shortens the cloak, exposes the lower legs, and uses a removable solid key background. See [references/rear_review.json](references/rear_review.json) and [references/prompts.json](references/prompts.json).

Production character assets and combat routing are outside this experiment. The live viewer and exported 512px sheets are inspection assets. A production integration would need animation triggers, movement timing, memory/performance evaluation, and broader action coverage.

## Editable sources

- `cutout_assets.py`, `cutout_layout.json`, `assets/front/`: source-only front masks, crops, pivots and exact-rest proof.
- `prepare_rear.py`, `rear_assets.py`, `cutout_layout_rear.json`, `assets/rear/`: deterministic rear keying, sizing, masks and proof.
- `cutout_rig.gd`: real bone hierarchy, sprite bindings, cape weights and AnimationPlayer authoring.
- `cutout_motion.gd`: complete local poses with analytic leg IK, exact neutral endpoints and cape follow-through.
- `rigs/reaver_front.tscn`, `rigs/reaver_rear.tscn`: saved editable Godot scenes with their painted textures and five animation clips. Select the `Animations` node to inspect the clips in Godot.
- `renders/animation_showcase.mp4`, `renders/walking_front_rear.gif`: paired rendered previews.
- `renders/animations.json` and ten PNG sheets: fixed 512px cells with timing and anchor metadata.
- `renders/board/`: fresh 1920×1080 real-board proof and videos.

## Reproduction

From this task worktree, with Godot 4.6, Python 3/Pillow, and ffmpeg available:

```bash
python3 experiments/protagonist_2d/prepare_rear.py
python3 experiments/protagonist_2d/cutout_assets.py
python3 experiments/protagonist_2d/rear_assets.py
python3 tools/godot_task_runner.py --task-id protagonist-2d-skeletal-experiment --stream -- godot --headless --path . --check-only --script experiments/protagonist_2d/render_frames_probe.gd
python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --expect-size 512x512 --timeout 60 --result-manifest /private/tmp/reaver-2d-render-result.json experiments/protagonist_2d/render_frames_probe.gd --task-id protagonist-2d-skeletal-experiment
```

The render probe prints its unique output directory. Pass that directory to the packer:

```bash
python3 experiments/protagonist_2d/pack_renders.py '<printed output directory>' --require-both
python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --expect-size 512x512 --result-manifest /private/tmp/reaver-2d-roundtrip-result.json experiments/protagonist_2d/roundtrip_probe.gd --task-id protagonist-2d-skeletal-experiment
```

Every rerun needs a fresh result-manifest path. The renderer records the actual joint trajectories and alpha bounds. The separate roundtrip probe loads the saved scenes and checks their pixels against freshly built rigs across all five clips. Intermediate video frames remain excluded from Git; retained videos and sheets can be regenerated from the scripts.

## Technical references

The approach follows Godot’s [cutout animation workflow](https://docs.godotengine.org/en/4.6/tutorials/animation/cutout_animation.html), [2D skeleton workflow](https://docs.godotengine.org/en/stable/tutorials/animation/2d_skeletons.html), and [Bone2D API](https://docs.godotengine.org/en/stable/classes/class_bone2d.html). The cape uses texture-pixel UVs and bone paths relative to the skeleton, consistent with the [Godot 4.6 Polygon2D implementation](https://raw.githubusercontent.com/godotengine/godot/4.6/scene/2d/polygon_2d.cpp).

## Inspection fixture

The verified fixture is the standalone `inspection.tscn` scene described in `inspection.md`. A production Continue save is not applicable because this task supplies an art study without changing production combat animation routing. The fixture exposes the original/reference comparison, both real facings, five actions, deterministic pause/step controls, and optional detail bones.

Validation artifacts in `renders/` retain exact source-pixel reconstruction, all 344 fixed-canvas frames, asset regeneration hashes, both actual-layout foot-contact checks, and ten pixel-identical saved-scene reload comparisons. `renders/board/` contains the separate real 1920×1080 board evidence.
