# Fresh-task cutout skill rehearsal

This is a temporary authoring demonstration and behavioral evaluation, not an accepted production animation. No repository art, runtime, skill or toolkit source was edited by this rehearsal; no commit, publication, paid image generation or unbounded interactive inspection was performed. New cases, evaluation scripts and retained proof are under `/private/tmp/cutout-forward-HD8292`. The documented renderer used its normal isolated Godot home under `/private/tmp/labyrinth-godot-home`, as the parent task clarified was permitted.

## Result

The skill and its referenced repository contract were sufficient to seed the approved protagonist, add a case-owned 0.9-second nonlooping sword salute, protect the art and existing three actions, produce native 1920×1080/100% board frames, and export editable front/rear scenes containing idle, walk, attack and salute. I did not need a historical builder or undocumented baseline rig. The new action reuses each facing's accepted attack-preparation arm excursion; it raises through phase 0.30, holds to 0.62 and returns to rest at 1.0. The sampler change and new clip record are retained in `salute-motion.patch` and `salute-clip.json`.

The advertised complete timed reel could **not** be accepted from this toolkit revision. Its encoding command truncates clips whose source frame rate differs from 60fps. This was not detected by render/verify-render PASS and was found by inspecting decoded output and measuring actual video durations.

## Evidence and checks

- Case: `protagonist_salute/v01/cutout.json`, sampler: `protagonist_salute/v01/motion.gd`.
- Untouched seed passed `validate --protect all`; edited candidate passed `validate --protect art`.
- `pose_regression.gd` and `pose_regression.json`: 606 exact old/new pose comparisons (101 phases × 3 approved actions × 2 facings), exact salute rest endpoints, and unchanged root/hips/leg/foot local transforms through 31 salute phases per facing. The existing clip JSON records were retained unchanged.
- Native proof: `proof-v01/`, 312 board frames with complete 512×512 pose canvases. `render_manifest.json` reports 1920×1080, UI scale 1.0, no transform/bounds/support errors, and eight pixel-identical saved-scene reload comparisons (four clips × two facings).
- Editable scenes: `proof-v01/front.tscn`, `proof-v01/rear.tscn`. Each contains an AnimationPlayer and all four clip resources.
- Main native stills inspected: `proof-v01/front_salute_0015.png`, `proof-v01/rear_salute_0015.png`, both `*_without_cloak.png`, and all 30 pose frames per facing via `front-salute-cycle.png` / `rear-salute-cycle.png`.
- Visual assessment: both views show a coherent sword raise, clear upright hold and recovery; feet remain fixed, weapon/hand stay attached and the full pose fits the fixed canvas. The rear board view has the HP obstruction described below.
- Video: `proof-v01/videos/cutout_review.mp4`; decoded attack sample `reel-decoded-attack.png` and final rear salute sample `reel-rear-salute-last-frame.png` were inspected. The latter ends at displayed frame 17/30 with the sword still upright.
- Capture-time standard render and separate verify-render both PASS: 919 hashed inputs and 557 hashed outputs. Their original results are in `render-v01-native.log` and `verify-render-v01.json`.
- After the parent resumed toolkit edits, a fresh `verify-render` correctly rejects the old proof. `verify-render-current.json` names changed `assets.py`, `cases.py`, `preview.gd`, `proof.py`, and `cutout_workflow.py`. This proof is a retained observation of the earlier toolkit revision, not current final-tool verification. No hashes or verification were weakened.

## Observed issues

1. **Video truncation (tool correctness).** `proof.py` passes `-frames:v <source-frame-count>` while also filtering to 60fps. The frame cap applies to encoded output frames. Both idle clips encode 42 frames/0.70s instead of 1.68s; both salute clips encode 30 frames/0.50s instead of 0.90s. Walk (0.90s) and attack (0.50s) happen to match because their source sampling is already 60fps. The reel is 5.20s versus the declared total of 7.96s. Full decoding and proof hash validation still pass. Exact measurements: `video-timing-audit.json`. The PNG sequences and editable scenes contain all salute poses; the defect is in packing.
2. **Raised rear blade is partly behind HP bar (candidate visual limit).** `proof-v01/rear_salute_0015.png` and the enlarged `rear-board-detail.png` show the tip hidden by the health bar. The isolated full canvas is complete, so bounds PASS cannot substitute for native board judgment. This is a temporary candidate posing/clearance issue, not production art corruption. It was left explicit as requested by the parent; this salute is not accepted for production.
3. **Cloak-off capture samples only frame zero (proof coverage).** Both `*_without_cloak.png` show salute frame 1/30, after the action loop. They do not expose the shoulder at the maximum raised-arm pose. The skill asks for this visual check, but this renderer revision's automatic evidence does not supply it. Interactive inspect can supply it; unbounded inspection was outside this rehearsal's scope.
4. **macOS native startup requires permitted GUI execution (environment).** The sandboxed documented render failed its normal 8-second startup watchdog without producing a Godot log. An identical bounded retry using the available native GUI escalation succeeded with Metal/Mobile on Apple M5 Pro. No timeout was extended. The headless regression emitted the usual host certificate lookup warning, with no GDScript failure.

## Acolyte starting case

`acolyte/v01/cutout.json` was created with explicit front/rear layouts. Each layout has exactly one `root`, no painted parts and no meshes; `rigid_bones` and `contact_feet` are empty. It does not copy the protagonist's 21 joints. Validation and render both exit 1 with clear missing-paint errors for each view; render stops before launching Godot.

Before it can render, an author must establish the acolyte's own anatomy/projection, register its actual source paint and landmarks, supply hidden moving surfaces, retain provenance and explicit ownership, define its joint graph, register parts with bones/layers and any needed mesh weights, and implement the requested clips. Front/rear are requested views to author, not fabricated imagery. Traveling actions additionally need anatomy-appropriate support surfaces and a projected travel/contact model before claiming grounded locomotion. No humanoid limb count, gait or protagonist naming is required by the scaffold.

## Exact main commands

Commands ran from `/Users/borgerding/workspace/Labyrinth.worktrees/protagonist-2d-skeletal-experiment` unless the input path is absolute. Temporary authoring is represented by the retained patch and complete regression script.

```sh
python3 tools/cutout_workflow.py doctor
mktemp -d /private/tmp/cutout-forward-XXXXXX
python3 tools/cutout_workflow.py seed-protagonist --character protagonist_salute --output /private/tmp/cutout-forward-HD8292/protagonist_salute/v01
python3 tools/cutout_workflow.py init --character acolyte --facings front,rear --output /private/tmp/cutout-forward-HD8292/acolyte/v01
python3 tools/cutout_workflow.py validate /private/tmp/cutout-forward-HD8292/protagonist_salute/v01 --protect all
python3 tools/cutout_workflow.py validate /private/tmp/cutout-forward-HD8292/acolyte/v01
PYTHONDONTWRITEBYTECODE=1 TMPDIR=/private/tmp/cutout-forward-HD8292 python3 tools/godot_task_runner.py --task-id cutout-forward-hd8292 --godot-home-root /private/tmp/cutout-forward-HD8292/godot-home --stream -- godot --headless --path . --script /private/tmp/cutout-forward-HD8292/pose_regression.gd
PYTHONDONTWRITEBYTECODE=1 python3 tools/cutout_workflow.py validate /private/tmp/cutout-forward-HD8292/protagonist_salute/v01 --protect art
PYTHONDONTWRITEBYTECODE=1 python3 tools/cutout_workflow.py render /private/tmp/cutout-forward-HD8292/acolyte/v01 --output /private/tmp/cutout-forward-HD8292/acolyte-proof-v01 --task-id cutout-forward-acolyte-hd8292
PYTHONDONTWRITEBYTECODE=1 TMPDIR=/private/tmp/cutout-forward-HD8292 python3 tools/cutout_workflow.py render /private/tmp/cutout-forward-HD8292/protagonist_salute/v01 --output /private/tmp/cutout-forward-HD8292/proof-v01 --task-id cutout-forward-hd8292 --backend metal > /private/tmp/cutout-forward-HD8292/render-v01.log 2>&1
PYTHONDONTWRITEBYTECODE=1 TMPDIR=/private/tmp/cutout-forward-HD8292 python3 tools/cutout_workflow.py render /private/tmp/cutout-forward-HD8292/protagonist_salute/v01 --output /private/tmp/cutout-forward-HD8292/proof-v01 --task-id cutout-forward-hd8292 --backend metal > /private/tmp/cutout-forward-HD8292/render-v01-native.log 2>&1
PYTHONDONTWRITEBYTECODE=1 python3 tools/cutout_workflow.py verify-render /private/tmp/cutout-forward-HD8292/protagonist_salute/v01 --output /private/tmp/cutout-forward-HD8292/proof-v01 > /private/tmp/cutout-forward-HD8292/verify-render-v01.json
ffmpeg -v error -framerate 30 -i /private/tmp/cutout-forward-HD8292/proof-v01/front_salute/pose_%04d.png -vf 'tile=6x5:nb_frames=30:padding=2:margin=2:color=0x222222' -frames:v 1 /private/tmp/cutout-forward-HD8292/front-salute-cycle.png
ffmpeg -v error -framerate 30 -i /private/tmp/cutout-forward-HD8292/proof-v01/rear_salute/pose_%04d.png -vf 'tile=6x5:nb_frames=30:padding=2:margin=2:color=0x222222' -frames:v 1 /private/tmp/cutout-forward-HD8292/rear-salute-cycle.png
ffmpeg -v error -i /private/tmp/cutout-forward-HD8292/proof-v01/rear_salute_0015.png -vf 'crop=240:300:500:420,scale=720:900:flags=neighbor' -frames:v 1 /private/tmp/cutout-forward-HD8292/rear-board-detail.png
ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate -show_entries format=duration -of json /private/tmp/cutout-forward-HD8292/proof-v01/videos/cutout_review.mp4
ffmpeg -v error -ss 4.65 -i /private/tmp/cutout-forward-HD8292/proof-v01/videos/cutout_review.mp4 -frames:v 1 /private/tmp/cutout-forward-HD8292/reel-decoded-attack.png
ffmpeg -v error -sseof -0.02 -i /private/tmp/cutout-forward-HD8292/proof-v01/videos/rear_salute.mp4 -frames:v 1 /private/tmp/cutout-forward-HD8292/reel-rear-salute-last-frame.png
PYTHONDONTWRITEBYTECODE=1 python3 tools/cutout_workflow.py verify-render /private/tmp/cutout-forward-HD8292/protagonist_salute/v01 --output /private/tmp/cutout-forward-HD8292/proof-v01 > /private/tmp/cutout-forward-HD8292/verify-render-current.json
```

Per-clip timing audit used `ffprobe -v error -select_streams v:0 -show_entries stream=nb_frames,r_frame_rate -show_entries format=duration -of json <each videos/*.mp4 path listed in encoding.json>`, retaining declared-versus-measured values in `video-timing-audit.json`.
