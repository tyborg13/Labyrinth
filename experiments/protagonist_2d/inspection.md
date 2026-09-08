# Live 2D protagonist inspection

This scene evaluates the original painted character on a live Godot skeletal rig inside the existing `CombatBoardView`. It changes no production character art, combat rules, save files, or game animation selection. The second pass demonstrates actual travel across the board at the speed authored into the foot plant cycle. This is an inspection preview; production tile movement is not connected to the experiment.

## Launch

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/protagonist-2d-skeletal-experiment && python3 tools/godot_task_runner.py --task-id protagonist-2d-skeletal-experiment --timeout 0 --stream -- godot --path . --windowed --resolution 1920x1080 res://experiments/protagonist_2d/inspection.tscn
```

Select Idle, Walk, Attack, Block, or Hit; choose Front or Rear when the actual cutout layout exists. Pause and Next frame inspect individual poses. Show static reference compares the selected facing to its source image at identical board registration. The original front uses the game's canonical static PNG; the rear uses its separately authored painted reference, not a flipped front image.

Walk across board is selected by default. Each walk traverses three complete gait cycles before resetting to its starting point. Turn it off to inspect the cycle in place. Pause, Next frame, and resume preserve the cumulative travel across gait boundaries. The right comparison and detail remain stationary in both modes. The player starts in the board's open foreground so both front and rear paths remain visible.

The right comparison preserves the original 255×255 framing at 1×. Its crop can exclude motion beyond the original source frame; the board and Full pose view retain all 512×512 pixels of motion room. Bones appear only in the separate detail viewport and never on the board. Zoom detail magnifies that viewport 1.75×; Full pose shows its entire fixed canvas.

Native buttons support pointer activation, Tab focus, and keyboard activation. Board zoom and pan retain the existing renderer's input behavior. This new inspection scene does not claim the game's full controller routing.

## Rig and registration contract

`cutout_rig.gd` extends `Node2D`. The host applies `position = Vector2(128,128)` to the rig; its joints and cutout pieces remain in original 255px source coordinates. Its transparent viewport is 512×512 with nearest-neighbor texture sampling. The host owns the discrete frame clock and calls `seek_frame()` on both main/detail rigs. The rig must not independently advance in `_process`.

Required methods are `load_rig()->bool`, `has_facing(name)->bool`, `set_facing(name)`, `set_clip(name)`, `seek_frame(index)`, `get_frame_count()->int`, `get_fps()->float`, and `get_anchor()->Vector2` normalized to 512px. `get_reference_texture(facing)` supplies the matching 255px static image. Optional `get_frame_index()` strengthens verification; `set_debug_bones(bool)` enables the detail-only overlay.

The board wrapper maps the full 512px canvas at `512/255` of the original sprite rectangle, offsetting it by the 128px padding. Thus each unchanged source pixel reaches exactly the original board position. It never fits the puppet to its changing alpha bounds. `Motion.walk_cycle_info(layout, facing).travel_per_cycle` supplies the displacement in source pixels; the host advances the board center linearly at that displacement per gait cycle. Its conversion uses the same source-pixel scale as the foot motion. The health bar and shadow follow the same center. The production static-reference silhouette shadow is reused for both modes to keep comparison consistent and avoid per-frame GPU readbacks. Animated shadow deformation is outside this experiment.

## Design and proof

The inspection question is whether the painted character keeps its appearance while its bones produce convincing actions and planted feet support actual travel. The board is the main surface; original/live comparison, magnified detail, and the optional skeleton help examine seams and motion. The primary action selects a clip and facing; the selected Walk across board control reveals traveling versus in-place state. Shared `UiSkin` controls/panel treatment and `UiTypography` are reused. Pointer and native keyboard focus/activation remain available. The inspection target is 1920×1080 at 100% UI scale. Pause/frame-step exposes the full state without requiring continuous motion.

Parser validation:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/protagonist-2d-skeletal-experiment && python3 tools/godot_task_runner.py --task-id protagonist-2d-skeletal-experiment --stream -- godot --headless --path . --check-only --script experiments/protagonist_2d/inspection_probe.gd
```

Early front-only proof, while the real rear reference is unfinished:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/protagonist-2d-skeletal-experiment && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract experiments/protagonist_2d/inspection_front_proof_contract.json --result-manifest /private/tmp/protagonist-2d-front-result.json experiments/protagonist_2d/inspection_probe.gd --task-id protagonist-2d-skeletal-experiment -- --front-only
```

Full front/rear proof with authentic board frames for videos:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/protagonist-2d-skeletal-experiment && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --timeout 420 --expect-size 1920x1080 --proof-contract experiments/protagonist_2d/inspection_proof_contract.json --result-manifest /private/tmp/protagonist-2d-full-v2-result.json experiments/protagonist_2d/inspection_probe.gd --task-id protagonist-2d-skeletal-experiment -- --capture-motion
```

The longer execution allowance is for saving every actual 1920×1080 frame of four stationary front actions and three gait cycles of front/rear travel; startup behavior is unchanged. All actions receive posed screenshots. Both walks also receive eight full-canvas pose screenshots and start/middle/end travel screenshots. `--front-only --capture-motion` records the front actions without claiming rear verification.

The probe prints an isolated output directory. Its `validation.json` identifies covered facings, checked frame count, captured video clips, fixed source registration, matching gait/travel speed, health placement following travel, unchanged enemy art, live viewport use in retained board layers, pause/step/wrap/frame rate, native focus, and bone-overlay isolation. Every delivered screenshot still requires visual inspection; these assertions do not judge animation quality.

Run `inspection_encode_videos.py` with that output directory as its positional argument. It encodes the captured board frames using the rig's frame rate, repeats stationary actions three times by default, and preserves the already captured three-cycle traveling sequence. It writes individual MP4s, `videos/protagonist_2d_showcase.mp4`, and a front/rear walking comparison at `videos/walking_front_rear.mp4` when both are captured. It cannot encode a still-only capture and does not generate or interpolate new character poses. Required stills are PNG; captured motion frames are lossless WebP so the screenshot runner does not decode hundreds of additional full-HD PNGs. The encoder uses Pillow to load and verify every motion frame at 1920×1080, then verifies each encoded video's dimensions and complete decoding. `videos/video_manifest.json` retains frame and video SHA-256 hashes. Both the lossless frame sequences and videos remain in the isolated proof directory. First-pass board evidence is preserved in `renders/pass1/board` for comparison.

The encoder also produces `walking_front_rear_paired.mp4` and `.gif`: simultaneous front/rear travel cropped from the actual board frames, with the selected facing controls retained above them. Each side uses the same fixed board rectangle for all three cycles at native pixel scale, retaining the floor and entire path; no per-frame camera tracking or alpha fitting is used. `--travel-crop X Y WIDTH HEIGHT` changes that single fixed rectangle when a future inspection layout changes. The manifest records the crop, scale, GIF timing, and hashes. Lead inspection with this actual-travel preview; the stationary detail serves seam examination.
