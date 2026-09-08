# Live 2D protagonist inspection

The sixth-pass scene shows newly painted composable Reaver art inside the existing `CombatBoardView`. It exposes two editable 21-bone rigs, walk and attack, source comparison and cloak removal. This standalone fixture is the inspection surface for the experiment.

## Launch

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/protagonist-2d-skeletal-experiment && python3 tools/godot_task_runner.py --task-id protagonist-2d-skeletal-experiment --timeout 0 --stream -- godot --path . --windowed --resolution 1920x1080 res://experiments/protagonist_2d/inspection.tscn
```

Select Walk or Attack and Front or Rear. Pause and Next frame expose individual poses. Show cloak removes both mantle pieces and the full drape; the setting persists when changing facing and also affects the detail rig. Show static reference uses the canonical front sprite or the previously authored rear concept view, at the original board registration.

Walk across board is enabled by default. Each traversal covers three full gait cycles before resetting. Turn it off for an in-place comparison. Pause, step and resume preserve cumulative travel through gait boundaries. The right comparison/detail rigs remain stationary, and the health bar/shadow follow the board actor.

The upper comparison uses the original 255×255 frame at 1×; motions above that frame can be cropped there. The board and Full pose detail retain the full 512×512 motion canvas. Zoom detail magnifies by 1.75×. Bones appear only in detail. Native buttons support pointer activation, Tab focus and keyboard activation; the existing board zoom/pan input paths remain available. This inspection scene does not claim production controller routing.

## Registration

The host places the `Node2D` rig at (128,128) in a transparent 512×512 viewport, with nearest-neighbor sampling. Joints and attachments retain 255px source coordinates. The board maps this fixed canvas back to the source sprite rectangle without per-frame alpha fitting. The host owns the discrete frame clock and calls `seek_frame()` on main/detail rigs.

`Motion.walk_cycle_info(...).travel_per_cycle` supplies a 50px source-space displacement along the 2:1 board basis; the host applies that displacement at the same scale as foot motion. The 24-frame/36fps gait supports both in-place and actual travel. The static-reference shadow remains a comparison aid and does not animate with the new silhouette.

The rig API is `load_rig()`, `has_facing()`, `set_facing()`, `set_clip()`, `seek_frame()`, `get_frame_count()`, `get_fps()`, `get_anchor()`, `get_frame_index()`, `get_reference_texture()`, `get_rest_texture()`, `set_debug_bones()` and `set_cloak_visible()`. Original concept and new assembled rest reference are deliberately separate textures.

## Capture and encoding

Use the real renderer at 1920×1080, 100% UI scale:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/protagonist-2d-skeletal-experiment && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --timeout 420 --expect-size 1920x1080 --proof-contract experiments/protagonist_2d/inspection_proof_contract.json --result-manifest /private/tmp/protagonist-2d-full-v6-result.json experiments/protagonist_2d/inspection_probe.gd --task-id protagonist-2d-skeletal-experiment -- --capture-motion
```

The timeout allows lossless full-HD capture/encoding of 208 source frames; startup behavior is unchanged. The probe saves 39 PNGs: references, both actions and overhead preparation, eight gait poses per facing, travel endpoints/midpoints, cloak-off poses, and focus/detail states. It checks 256 authored/travel states, pause/step/wrap/FPS, registration, health placement, enemy art, detail-only bones, native focus and cloak toggle persistence.

The probe prints an isolated output directory. Run:

```bash
python3 experiments/protagonist_2d/inspection_encode_videos.py '<proof-directory>'
python3 experiments/protagonist_2d/board_feedback_reel.py '<proof-directory>'
```

The first command verifies every lossless WebP frame at 1920×1080 and encodes full-surface, individual-action and paired-travel previews. Its paired travel crop defaults to `(200,330,420,350)` as x/y/width/height. The final reel derives one common crop for all actions/travel; current bounds are `(194,336)-(614,674)`. Both preserve native board pixels, floor cues and the full motion path without per-frame tracking.

`videos/walk_attack_board.mp4` is the primary 936×540, 72fps, 13.33-second reel: walk for eight seconds, then attack for 5.33 seconds. Each action appears twice at normal speed and once at half speed. Integer frame duplication preserves the original 36fps walk and 24fps attack; there is no pose interpolation. `board_feedback_reel_validation.json` records source hashes, framing, 960 output frames, exact timing and complete decoding.

Current retained proof is under `renders/pass6/board/`; use its versioned URLs. Raw lossless motion frames remain at the original isolated capture path in `renders/pass6/proof_manifest.json`. Prior `renders/board/` contains fifth-pass evidence.

## Sixth-pass inspection record

The real Metal/Mobile capture passed at 1920×1080, 100% UI scale. Visual review covers every authored pose with and without cloak, every native board screenshot region and all 72 paired travel phases. Full-surface inspection covers action preparation, references, controls, focus, cloak-off and detail states. The reel's decoded proof frames preserve its labels and full actor bounds. All 886 captured runtime input hashes were unchanged before/after recording and at packaging.

The board remains the primary surface; existing `UiSkin` and `UiTypography` keep controls legible. Action/facing state and pause/frame-step are exposed through native buttons; cloak removal enables direct shoulder/chest inspection. Detail and skeleton overlays do not obscure gameplay. These are the applicable UI rubric checks for this surface; no new gameplay icon identities or rules text are introduced.

No detached limb, exposed torso gap or opaque inverted joint was found in the final authored-pose review. The fixed hand/boot views and warmer rear leather remain visible art limitations, recorded in [iteration_6.md](iteration_6.md). Two fixed views do not establish arbitrary turning or production-ready animation.

The saved rigs passed four pixel-identical reload cases. The playable inspection fixture is this standalone scene. A production Continue save is not applicable because production gameplay does not select the experiment. A post-review task-runner startup check is recorded in the final handoff.
