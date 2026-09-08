# Protagonist 2D skeletal animation experiment

The sixth pass rebuilds the complete protagonist as newly painted, composable front and rear artwork. The canonical sprite supplies the concept, proportions and style reference. Each facing has 19 art attachments on an editable 21-bone rig, with **walk and attack only**.

Start with the [sixth-pass combat-board reel](renders/pass6/board/videos/walk_attack_board.mp4): both facings, twice at normal speed and once at half speed. The 13.33-second reel uses actual Godot board pixels with fixed framing. Compare the [canonical reference and new assemblies](references/pass6/assembly_review.png), then inspect the [front parts](references/pass6/front_parts_review.png) and [rear parts](references/pass6/rear_parts_review.png) at a shared 2× pixel scale.

[Launch the live inspection scene](inspection.md) to switch facing/action, walk across the board, hide the cloak, compare the source, pause, step and inspect bones. [The art and motion review](iteration_6.md) records the decisions and limits.

## Current artifacts

- `renders/pass6/board/videos/walk_attack_board.mp4`: primary front/rear walk and attack comparison on the real board, normal and half speed.
- `renders/pass6/walk_attack_feedback.mp4`: supplemental enlarged, in-place comparison.
- `renders/pass6/board/videos/protagonist_2d_showcase.mp4`: full 1920×1080 inspection surface for both actions/facings.
- `renders/pass6/board/videos/walking_front_rear_paired.mp4` and `.gif`: three gait cycles of simultaneous front/rear board travel.
- `renders/pass6/review/`: every authored pose with/without cloak, all 39 board regions, and all 72 paired travel phases at native pixel scale.
- `references/pass6/`: retained raw artwork, prompts/provenance, source registration and ownership traces, assembly and part comparisons.
- `assets/pass6/front/` and `assets/pass6/rear/`: current composable character pieces. Their `source/` directories preserve the manually split master paint before joint completion.
- `rigs/reaver_front.tscn` and `rigs/reaver_rear.tscn`: saved, editable Godot scenes. Select `Animations` for the two clips.

Prior pass-five root previews are frozen in `renders/pass5/`; the historical fifth-pass full board proof remains in `renders/board/`. Earlier versioned folders and `iteration_1.md` through `iteration_5.md` describe superseded studies. Use the explicit **pass6** paths for this revision.

## Artwork and motion

Built-in ImageGen supplied two complete new paint sources and individually requested joint/material components. The full paintings establish head/body/limb consistency; manually authored ownership masks split them at registered coordinates. Individually generated sleeves caps, chest coverage, pelvis, rear trouser material, boots, cloak drapes and blade complete the hidden or revised surfaces. Source images are never stretched to fit a changing pose. Import uses measured destination dimensions and nearest-neighbor sampling; limb-length fitting is explicit in `registered_assets.py`.

The two source traces recompose their respective new master paint exactly. The final neutral assemblies additionally include complete hidden material and revised components, so they have distinct assembled reference images. Neither reconstruction assertion treats the canonical concept sprite as an immutable body.

Head, scarf, chest, pelvis, gloves, boots and weapon are independently attached. Each sleeve is a complete weighted mesh; thighs and shins use overlapping rigid painted pieces. Two shoulder mantle pieces and a separate three-bone drape share the cloak equipment slot. Hiding the cloak exposes complete shoulders/chest/back for review. The blade rotates about its own grip bone. Slots organize this prototype's attachments; a production equipment swapping system is not implemented.

Walk has 24 authored frames at 36fps (0.667 seconds), a 30px stride and 50px board displacement per cycle along the 2:1 floor direction. View-dependent projected leg lengths keep the foot planted without forcing a deep pelvis dip; local affine transforms preserve painted limb width and the boot's rigid basis. This is an authored 2D approximation to foreshortening. Attack has 32 frames at 24fps: raised preparation, a quicker forward/downward cut, and recovery. Gloves and boots keep fixed painted viewing angles.

## Verification

Fresh Godot 4.6.1 Metal/Mobile proof passed at 1920×1080 and 100% UI scale. The review includes all 112 authored poses, the same 112 poses without cloak, all 39 board screenshot regions and 72 paired travel phases. Full-surface screenshots check control layout, focus, references and detail. Numeric checks support those visual judgments; they do not establish art quality by themselves.

- `renders/pass6/render_validation.json`: assembled rest reconstruction, fixed 512×512 motion canvas, per-clip timing, pose bounds and input hashes.
- `renders/pass6/motion_validation.json`: 257 sampled phases per clip/facing; foot target error below 0.000064px, world support drift below 0.000081px, preserved boot basis/limb width, loop closure and sword trajectory.
- `renders/pass6/registered_art_validation.json`: exact source segmentation, equipment grouping, cuff/knee overlap, valid visible mesh geometry and attachment checks across all 224 rendered poses.
- `renders/pass6/roundtrip/`: all four action/facing cases render pixel-identically after saving and reloading the two editable rigs.
- `renders/pass6/asset_reproduction.json`: all 89 generated layout, part and assembly files reproduced byte-identically from retained inputs in an isolated directory.
- `renders/pass6/board/`: 39 native stills, 256 checked action/travel states and video manifests for 208 captured lossless motion frames. The before/after hash set contains 886 unchanged runtime inputs.
- `renders/pass6/proof_manifest.json` and `inspection_review.json`: retained proof hashes and visual inspection scope. Raw full-HD lossless motion sequences remain in the isolated capture directory recorded in the manifest; native sheets and videos are retained here.

## Reproduction

Run from this task worktree with Python 3/Pillow, Godot 4.6 and ffmpeg:

```bash
python3 experiments/protagonist_2d/registered_assets.py
LABYRINTH_CUTOUT_POSE_MATRICES=/private/tmp/reaver-2d-v6-poses.json python3 tools/godot_task_runner.py --task-id protagonist-2d-skeletal-experiment --stream -- godot --headless --path . --script experiments/protagonist_2d/motion_contract_probe.gd
python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --expect-size 512x512 --timeout 60 --result-manifest /private/tmp/reaver-2d-v6-render-result.json experiments/protagonist_2d/render_frames_probe.gd --task-id protagonist-2d-skeletal-experiment
```

Pass the last probe's printed directory to `pack_renders.py '<directory>' --require-both` and `registered_contract_probe.py --pose-matrices /private/tmp/reaver-2d-v6-poses.json --renders '<directory>'`. The packer creates the eight sheets (including cloak-off poses), saved rigs and previews in `renders/pass6`. Use a fresh result manifest path for each capture. Then run `roundtrip_probe.gd` through `visual_probe_runner.py` at 512×512. [Board capture and encoding commands](inspection.md) provide the final UI proof.

`registered_assets.py` is the current builder. The older `articulated_assets.py`, `mesh_assets.py`, `cutout_assets.py`, `rear_assets.py` and related audits describe previous pipelines and must not be used to reproduce pass six.

## Limits

This remains a standalone art/animation study. Both facings are fixed 2D views; large turns, different palm views or substantially different bends would require replacement drawings. The rear leather has warmer, broader highlights and the new cape has a narrower flow than the concept. Animated joints still resample their pixels, especially in the rear sleeve and overlapping knee during extreme phases. The attack tests an arm-led overhead cut with restrained body motion, not a complete combat choreography set.

Production animation selection, tile traversal, combat triggers, equipment replacement, dynamic shadows and performance integration remain outside this prototype. The board reuses the production static-reference shadow. The inspection scene is the playable fixture; a production Continue save is not applicable because production gameplay does not route to this experiment.
