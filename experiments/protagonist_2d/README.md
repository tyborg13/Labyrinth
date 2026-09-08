# Protagonist 2D skeletal animation experiment

The seventh pass refines the sixth-pass character's garment connections: closed boot openings and overlapping trouser cuffs, a rear cloak attached at the neckline, and rounded knee joins with small painted covers. The arms, glove/sword grip, sword art and all bone pose curves remain unchanged. Each facing has 21 art attachments on the existing editable 21-bone rig, with **walk and attack only**. Production integration waits for the user's visual acceptance.

Start with the [seventh-pass combat-board reel](renders/pass7/board/videos/walk_attack_board.mp4): both facings, twice at normal speed and once at half speed. The 13.33-second reel uses actual Godot board pixels with fixed framing. Compare [boots and knees through walk](references/pass7/boots_knees_comparison.png), [the rear cloak through attack](references/pass7/rear_cloak_comparison.png), and [complete before/after assemblies](references/pass7/assembly_review.png).

[Launch the live inspection scene](inspection.md) to change facing/action, walk across the board, hide the cloak, compare the concept, pause, step and inspect bones. [The garment review](iteration_7.md) records changes and remaining limitations.

## Current artifacts

- `renders/pass7/board/videos/walk_attack_board.mp4`: primary front/rear walk and attack reel, normal and half speed.
- `renders/pass7/walk_attack_feedback.mp4`: enlarged, in-place comparison.
- `renders/pass7/board/videos/protagonist_2d_showcase.mp4`: full 1920×1080 inspection surface.
- `renders/pass7/board/videos/walking_front_rear_paired.mp4` and `.gif`: three gait cycles of paired board travel.
- `renders/pass7/review/`: every authored pose with/without cloak, all 39 board regions and all 72 paired travel phases; sheets retain native source pixels.
- `references/pass7/`: before/after comparisons and frozen sixth-pass layout/motion/scene baseline.
- `assets/pass7/front/` and `assets/pass7/rear/`: refined leg pieces, knee covers, reoriented boots and rear drape. Other attachments still use `assets/pass6/` unchanged.
- `rigs/reaver_front.tscn` and `rigs/reaver_rear.tscn`: saved editable Godot scenes; select `Animations` for the two clips.

Sixth-pass assets, references and renders are preserved. [Iteration six](iteration_6.md) owns the original painting, manual segmentation and generation provenance. Use explicit **pass7** preview paths for this revision.

## Garment construction and motion

`seam_assets.py` reads the frozen layouts from sixth-pass commit `a01366412c8dd9263044751ac63bce6c556b9544`. It removes the visibly empty reoriented shoe collars, mutes their orange leather, and places the boots behind the trousers. Small cuff fills extend existing calf paint into the shoe. Toe, heel and sole remain on the same foot bones.

Thigh and shin ends now overlap with rounded contours. One small cover per knee uses matching local paint on the existing shin bone, with a one-native-pixel alpha blend at its edge. This adds coverage without a new deforming leg mesh or altered bone curves. The original painted cloth bands remain visible, especially in deep walk bends.

The rear drape moves 6px left and 13px up in source coordinates. It draws over the old mantle joins and upper arms, beneath the scarf and head. Its own neckline supplies the visible continuous garment; the lower cloth retains the existing three-bone motion with weights re-registered to the moved paint. Cloak removal still hides both mantle pieces and the drape. Front cloak construction is unchanged.

Walk retains 24 frames at 36fps, a 30px stride and 50px board travel per cycle along the 2:1 floor direction. Attack retains 32 frames at 24fps. The existing authored projection preserves planted feet, painted limb width and rigid boot bases. Gloves and boots retain their fixed viewing angles. Equipment slots organize the prototype; production equipment swapping is deferred.

## Verification

Fresh Godot 4.6.1 Metal/Mobile proof passed at 1920×1080 and 100% UI scale. Visual review covers all 224 authored poses with/without cloak, full UI states, all 39 board regions and 72 paired travel phases. Connectivity measurements supplement the specific visual checks for empty shoe rims, doubled cloak collars and abrupt leg cuts.

- `renders/pass7/seam_validation.json`: removed hollow collar pixels, foreground cuffs with painted overlap, shoulder-level cape coverage, protected art hashes and 112 exactly identical existing bone poses.
- `renders/pass7/registered_art_validation.json`: retained source segmentation, equipment grouping, valid mesh geometry and attachments in all 224 actual rendered poses.
- `renders/pass7/motion_validation.json`: 257 sampled phases per clip/facing; unchanged foot targets, support drift, loop closure and sword trajectory.
- `renders/pass7/render_validation.json`: exact assembled rest reconstruction, fixed 512×512 motion canvas, timing, bounds and input hashes.
- `renders/pass7/roundtrip/`: all four action/facing cases render pixel-identically after saving/reloading the editable rigs.
- `renders/pass7/asset_reproduction.json`: 22 generated asset, layout and assembly files reproduced byte-identically in isolation.
- `renders/pass7/board/`: 39 full-HD stills, 256 checked action/travel states and video manifests for 208 lossless motion frames. All 901 runtime input hashes remained unchanged during capture.
- `renders/pass7/proof_manifest.json` and `inspection_review.json`: retained proof hashes, raw capture locations and visual inspection scope.

## Reproduction

Run from this task worktree with Python 3/Pillow, Godot 4.6 and ffmpeg:

```bash
python3 experiments/protagonist_2d/seam_assets.py
LABYRINTH_CUTOUT_POSE_MATRICES=/private/tmp/reaver-2d-v7-poses.json python3 tools/godot_task_runner.py --task-id protagonist-2d-skeletal-experiment --stream -- godot --headless --path . --script experiments/protagonist_2d/motion_contract_probe.gd
python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --expect-size 512x512 --timeout 60 --result-manifest /private/tmp/reaver-2d-v7-render-result.json experiments/protagonist_2d/render_frames_probe.gd --task-id protagonist-2d-skeletal-experiment -- --capture-uncloaked
```

Pass the last probe's printed directory to `pack_renders.py '<directory>' --require-both` and `registered_contract_probe.py --pose-matrices /private/tmp/reaver-2d-v7-poses.json --renders '<directory>'`. Run `seam_contract_probe.py --pose-matrices /private/tmp/reaver-2d-v7-poses.json`. The packer produces the eight sheets, saved rigs and previews in `renders/pass7`. Use fresh result manifest paths. Run `roundtrip_probe.gd` through `visual_probe_runner.py` at 512×512 after packing. [Board capture and encoding commands](inspection.md) provide the final UI proof.

`seam_assets.py` is the current builder. It imports the generic mesh utility from `registered_assets.py`, but running that older builder would restore the sixth-pass layouts. Earlier builders likewise describe superseded revisions.

## Limits

This remains a standalone two-view art/animation study. Boot and glove perspectives are fixed; a larger range of turns or bends would need additional paintings. Local cuff fills simplify some boot-top detail, and rounded knee covers soften joins without removing every dark band in the source cloth. Rear leather remains warmer than front. The static-reference shadow still comes from the production board.

The user explicitly deferred production animation selection, tile traversal, combat triggers, equipment replacement, dynamic shadows and performance integration until this visual pass is accepted. The existing board inspector is the playable fixture. A production Continue save is not applicable because production gameplay does not route to the experiment.
