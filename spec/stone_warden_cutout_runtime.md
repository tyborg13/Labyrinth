# Stone Warden cutout in gameplay

## Design and scope

The combat board must show which way the Stone Warden travels and when its mace lands, while the player keeps choosing movement, cards and end turn through the existing pointer, keyboard and controller paths. Promote the reviewed v03 paint and poses unchanged. Keep the logical body, target tiles, HP/intent panels and turn-clock portrait stable; only the padded art canvas follows the skeleton. Prove both views and reflections, real move/melee outcomes, support, reduced-motion still art, multiple Wardens, preview echoes and death in fresh 1920×1080/100% native captures. No rules, intent weights, initiative, damage, rewards or analytics event boundaries change.

## Runtime contract

Production owns the selected parts/layouts in `assets/units/stone_warden_cutout` and the sampler, rig and renderer in `scripts/stone_warden_cutout`. The frozen reviewed case remains `experiments/cutouts/stone_warden/v03`; production never loads experiment or tool files. Export presets explicitly include the layout JSON and all paint uses raw keep imports.

Each Warden has a persistent 512px viewport and two loaded facing rigs. A 255px logical body at the existing 1.18 art scale continues to supply board geometry. The renderer initially faces the player and retains the latest action direction through idle. Destination previews share their actor's texture. Hidden actors stop idle updates; removed actors release their renderers after any death presentation. Death freezes the same cutout texture for the existing dissolve.

Walking keeps the approved 72px stride, 60% support and 120px source travel per cycle. Production uses a 0.62-second cycle to account for the Warden's existing 1.18 body scale: its nominal board speed is about 85.6% of the protagonist's. Phase follows actual distance, including multi-segment routes. Idle retains the accepted 1.6-second period. The 0.9-second overhead attack reaches the authored contact pose at the existing effect/result boundary (42% for melee, 38% for Crushing Step). Feet stay planted instead of adding the old whole-sprite lunge. The existing melee trail begins with the downstroke, leaving the raised preparation visible. Only playback timing changes; the combat resolver and its append-only analytics remain unchanged.

The turn clock keeps the existing dedicated Stone Warden portrait. A fresh native rest bake supplies cached HUD/shadow geometry. The neutral shadow stays static; animated textures are never read back each frame for bounds or shadows. Reduced motion shows the same art in a still pose and retains facing.

## Verification and inspection

The changed surface is the Stone Warden body on the live combat board. Affected UI rubric gates—immediate comprehension, hierarchy, gameplay visibility, state/consequence, input completeness, visual cohesion, reduced motion, layout resilience and native proof—pass at 1920×1080 and 100% UI scale. Native front/rear/reflected walks, attack preparation/contact/recovery, reduced motion, targeting, controller cancel/handoff and death were inspected. Target tiles, health, intent panels and the separate turn-clock portrait stay legible. The previously accepted raised-mace overlap with its health panel remains; the live slash now waits for the downstroke.

Fresh evidence is in [runtime_v1](../experiments/cutouts/stone_warden/runtime_v1/):

- `assets/comparison.json`: all **178** native rest/idle/walk/attack poses are pixel-identical between the approved v03 case and production. Both fresh 255px rest bakes match the shipped HUD/shadow silhouettes.
- `gameplay/warden_gameplay_full_speed.mp4`: **28.02 seconds**, 1920×1080/60 fps, covering all four real Marching Blow directions, Crushing Step, reduced motion, Bulwark and death. The eight source clips and 737 recorded samples retain actual wall-clock intervals; encoding repeats frames without inventing poses or changing speed. The complete reel decodes without errors. `video_timeline.json` records per-frame durations and rounding, at most one 60 fps frame per clip.
- `gameplay/manifest.json`: real End Turn resolution preserves Marching Blow's one-tile advance, exactly nine damage and initiative; Crushing Step still deals six damage; Bulwark gives the other Warden six block. Visible damage changes at the existing contact boundary. Walking's maximum measured world-space support drift is **0.000153 pixels**. One texture survives each action; lethal damage removes only the defeated Warden after its dissolve. Controller Cancel preserves state, then pointer handoff restores the existing interface.
- 29 native 1920×1080 PNGs and five mid-step JPEGs retain the inspected states. Both native runner manifests are accepted on macOS Metal/mobile.
- `focused_suite.log`: **PASS**, including independent actors, four facings, distance phase wrap, attack/contact/trail timing, production speed ratio, reduced motion, hidden updates, stable logical registration, destination echoes, death geometry and renderer release.
- `full_suite.log`: **TEST RESULT: PASS**, including the protagonist cutout and shared runtime suites. It retains the established ambiguous-save migration warning and ObjectDB shutdown warning; this is not a clean-shutdown claim.
- `export_build.log` and `export_runtime.log`: **PASS (editor=false)** with an unmodified macOS 4.6.1 export template and a production-only PCK. Layouts and all paint load without experiment/tool files or an imported cache. This verifies cutout packaging, not a complete platform release or Windows execution.
- `capture_input_sha256.json` binds 1,467 case/runtime/art/test/import/export inputs to the capture and checks. `proof_sha256.json` binds all 60 retained outputs. No bound input changed during or after capture. The old v03 board proof is historical because its shared runtime dependency hashes changed; this new direct native comparison proves the approved poses remain intact.

Reproduce checks from the task worktree:

```sh
python3 tools/godot_task_runner.py --task-id stone-warden-editable-front-rear-cutout --stream -- godot --headless --path . --script tests/stone_warden_cutout_test.gd
python3 tools/godot_task_runner.py --task-id stone-warden-editable-front-rear-cutout --stream -- godot --headless --path . --script tests/run_tests.gd
python3 tools/visual_probe_runner.py tests/stone_warden_cutout_asset_probe.gd --task-id stone-warden-editable-front-rear-cutout --no-headless --expect-size 512x512 --expect-size 255x255 --timeout 120
python3 tools/visual_probe_runner.py tests/stone_warden_cutout_gameplay_probe.gd --task-id stone-warden-editable-front-rear-cutout --no-headless --expect-size 1920x1080 --timeout 120
python3 tools/godot_task_runner.py --task-id stone-warden-editable-front-rear-cutout --stream -- godot --headless --path . --script tests/stone_warden_cutout_pack_test.gd -- build /private/tmp/warden-cutout-export/godot_export_debug.pck
```

For the last check, place the matching macOS debug export template beside the PCK as `godot_export_debug`, then run it from `/private/tmp` through `godot_task_runner.py --project /private/tmp/warden-cutout-export --task-id stone-warden-editable-front-rear-cutout --stream -- /private/tmp/warden-cutout-export/godot_export_debug --headless`. The same-basename PCK supplies its boot scene; the template disables the normal `--path` override.

## Playable inspection

The self-healing fixture command regenerates and independently reloads the pre-action save before opening the game. Choose **Continue**, then **Pass** to see the two Wardens advance and attack. Moving around them shows the front/rear/reflected views. Brace and Patch Up allow further turns; the fixture starts the player at 40 HP. The review branch is `codex/stone-warden-editable-front-rear-cutout`, based on local `master` commit `65b667daf19568ff62892b458e36a41645f579be`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/stone-warden-editable-front-rear-cutout && python3 tools/inspection_fixture.py --task-id stone-warden-editable-front-rear-cutout --run-id stone-warden-runtime-v1-inspection --manifest /private/tmp/stone-warden-runtime-v1-inspection.json --launch --scenario combat --summary "Stone Warden cutout: Continue, then Pass to watch movement and overhead strikes" --player-position 3:5 --player-hp 40 --player-max-hp 40 --enemy-types warden,warden --enemy-positions 3:3,5:5 --enemy-intents marching_blow,crushing_step --hand quick_stab,brace,sidestep_slash,bone_dart,patch_up
```

Remaining limits: neutral shadows use a static rest silhouette to avoid per-frame GPU readback; the accepted art quirks remain. Alternate resolutions/UI scales, physical controller hardware and Windows runtime were not exercised. Combat rules, analytics and icon identities are unchanged. Publication remains pending inspection and explicit approval of the reviewed commit.
