# Stone Warden cutout in gameplay

## Design and scope

The combat board must show which way the Stone Warden travels and when its mace lands, while the player keeps choosing movement, cards and end turn through the existing pointer, keyboard and controller paths. The v04 revision repairs front chest/arm ownership and removes idle ripple while preserving the accepted body design, walking and attack poses. Keep the logical body, target tiles, HP/intent panels and turn-clock portrait stable; only the padded art canvas follows the skeleton. Prove both views and reflections, real move/melee outcomes, support, reduced-motion still art, multiple Wardens, preview echoes and death in fresh 1920×1080/100% native captures. No rules, intent weights, initiative, damage, rewards or analytics event boundaries change.

## Runtime contract

Production owns the selected parts/layouts in `assets/units/stone_warden_cutout` and the sampler, rig and renderer in `scripts/stone_warden_cutout`. The current editable case is `experiments/cutouts/stone_warden/v04`; production never loads experiment or tool files. Export presets explicitly include the layout JSON and all paint uses raw keep imports.

Each Warden has a persistent 512px viewport and two loaded facing rigs. A 255px logical body at the existing 1.18 art scale continues to supply board geometry. The renderer uses the shared `scripts/enemy_cutout_facing.gd` policy: idle always chooses the closest of the four supported directions toward the player. Walks and attacks face their own action; completed actions and completed player movement recompute idle from the displayed tiles. A pending destination does not turn observers before movement finishes. This is the default for future directional enemy cutouts; the protagonist retains camera-facing idle. Destination previews share their actor's texture. Hidden actors stop idle updates; removed actors release their renderers after any death presentation. Death freezes the same cutout texture for the existing dissolve.

Walking keeps the approved 72px stride, 60% support and 120px source travel per cycle. Production uses a 0.62-second cycle to account for the Warden's existing 1.18 body scale: its nominal board speed is about 85.6% of the protagonist's. Phase follows actual distance, including multi-segment routes. Idle retains the accepted 1.6-second period and 1.4px bob. Its whole upper body translates together; the thighs counter-translate so all leg transforms remain fixed. Idle adds no local rotations, scaling, skew or leg deformation. The 0.9-second overhead attack reaches the authored contact pose at the existing effect/result boundary (42% for melee, 38% for Crushing Step). Feet stay planted instead of adding the old whole-sprite lunge. The existing melee trail begins with the downstroke, leaving the raised preparation visible. Only playback timing changes; the combat resolver and its append-only analytics remain unchanged.

The turn clock keeps the existing dedicated Stone Warden portrait. A fresh native rest bake supplies cached HUD/shadow geometry. The neutral shadow stays static; animated textures are never read back each frame for bounds or shadows. Reduced motion shows the same art in a still pose and retains facing.

## Front arm repair

The v04 case forks the accepted v03. Its original source ownership assigned 155 chest-edge pixels to `arm_r`, so a gold-edged breastplate strip moved with the raised arm. `recipes/front_arm_repair.json` records the exact registered coordinates now assigned to the rigid `chest` torso. The unchanged shoulder/forearm drawing remains on the arm. A small generated dark iron sleeve insert fills that same concealed footprint in the existing `shoulder_cap_r` mesh, below the torso and using the existing arm weights. The front mesh is rebuilt for the expanded hidden crop; no extra cover layer is added.

The untouched generation outputs, reference roles, actual prompts, selection/rejection rationale and digests are retained under `v04/source`, including `front_arm_generation.json`. The selected interior sleeve crop is registered uniformly at 1/15 scale and selected only beneath the transferred footprint, preserving its alpha. The rejected full-arm edit supplies no runtime pixels. All 29 other original paint files, including every rear piece, remain byte-identical. Both fresh native 255px rest images exactly match the existing production bakes, so the neutral silhouette does not change. Walking and attack transforms remain exactly equal to v03 in both views.

## Verification and inspection

The changed surface is the Stone Warden body on the live combat board. Affected UI rubric gates—immediate comprehension, hierarchy, gameplay visibility, state/consequence, input completeness, visual cohesion, reduced motion, layout resilience and native proof—pass at 1920×1080 and 100% UI scale. Native front/rear/reflected walks, attack preparation/contact/recovery, reduced motion, targeting, controller cancel/handoff and death were inspected. Target tiles, health, intent panels and the separate turn-clock portrait stay legible. The previously accepted raised-mace overlap with its health panel remains; the live slash now waits for the downstroke.

Fresh case evidence is in [v04/proof](../experiments/cutouts/stone_warden/v04/proof/): **288** native authored samples, complete action bounds, support checks and **10** pixel-identical saved-scene reload comparisons pass. The editable `front.tscn` and `rear.tscn` retain their Skeleton2D, mesh and AnimationPlayer tracks. All native idle samples have exactly zero bone-basis error and zero leg-transform change; the measured upper-body bob is 1.399994 source pixels. `verify-render` binds **986 inputs and 679 outputs**. The real-renderer board and full-cycle preparation/contact/recovery were inspected at 1920×1080/100%.

Fresh gameplay evidence is in [runtime_v3](../experiments/cutouts/stone_warden/runtime_v3/):

- `assets/comparison.json`: **178** native rest/idle/walk/attack poses are pixel-identical between v04 and production. Every sampled walk/attack transform remains equal to v03; both resting silhouettes match the production bakes. Native front and rear attack preparation/contact images are retained.
- `gameplay/warden_gameplay_full_speed.mp4`: **46.47 seconds**, 1920×1080/60 fps, covering two idle cycles in all four directions, all four real Marching Blow directions, Crushing Step, reduced motion, Bulwark, death and four player repositioning paths. **16 clips and 1224 samples** retain actual wall-clock intervals; encoding repeats frames without inventing poses or changing speed. The complete reel decodes without errors. `video_timeline.json` records per-frame durations and at most one output-frame rounding per clip.
- `gameplay/warden_arm_idle_revision.mp4`: **21.02 seconds**, showing the front and mirrored idle/attacks plus both rear idles at actual gameplay speed.
- `gameplay/manifest.json`: End Turn preserves Marching Blow's one-tile advance and nine damage, Crushing Step's six damage and Bulwark's six ally block. Damage appears at the existing contact boundary. Walking's maximum measured world-space support drift is **0.000153 pixels**. Player repositioning preserves facing until movement finishes, then both Wardens turn toward the completed tile; the protagonist still idles toward the camera. One texture survives each action, controller Cancel preserves state, pointer handoff works and death removes only the defeated Warden after its dissolve.
- **37** native 1920×1080 PNGs and five mid-step JPEGs retain the inspected gameplay states. Both native runner manifests pass on macOS Metal/mobile.
- `preservation_audit.json`: exactly the three front paint files changed; the rear layout and remaining paint match v03.
- `focused_suite.log`: **PASS**, including every idle bone's unchanged basis, fixed legs, coordinated upper-body bob and the accepted amplitude, plus the established facing, action/contact timing, reduced-motion, death and renderer lifecycle checks.
- `full_suite.log`: **TEST RESULT: PASS**. It retains the established ambiguous-save migration and ObjectDB shutdown warnings; this is not a clean-shutdown claim.
- `export_build.log` and `export_runtime.log`: **PASS (editor=false)** with an unmodified macOS 4.6.1 export template and a production-only PCK. Layouts and paint load without experiment/tool files or an imported cache. This verifies cutout packaging, not a complete platform release or Windows execution.
- `capture_input_sha256.json` binds **1,479** case/runtime/art/test/import/export/workflow inputs. `proof_sha256.json` binds **88** retained outputs. No bound input changed during or after capture. Previous case/runtime evidence remains historical; v04 and runtime_v3 are the current proof.

Reproduce checks from the task worktree:

```sh
python3 tools/godot_task_runner.py --task-id stone-warden-editable-front-rear-cutout --stream -- godot --headless --path . --script tests/stone_warden_cutout_test.gd
python3 tools/godot_task_runner.py --task-id stone-warden-editable-front-rear-cutout --stream -- godot --headless --path . --script tests/run_tests.gd
python3 tools/visual_probe_runner.py tests/stone_warden_cutout_asset_probe.gd --task-id stone-warden-editable-front-rear-cutout --no-headless --expect-size 512x512 --expect-size 255x255 --timeout 120
python3 tools/visual_probe_runner.py tests/stone_warden_cutout_gameplay_probe.gd --task-id stone-warden-editable-front-rear-cutout --no-headless --expect-size 1920x1080 --timeout 180
python3 tools/godot_task_runner.py --task-id stone-warden-editable-front-rear-cutout --stream -- godot --headless --path . --script tests/stone_warden_cutout_pack_test.gd -- build /private/tmp/warden-cutout-export/godot_export_debug.pck
```

For the last check, place the matching macOS debug export template beside the PCK as `godot_export_debug`, then run it from `/private/tmp` through `godot_task_runner.py --project /private/tmp/warden-cutout-export --task-id stone-warden-editable-front-rear-cutout --stream -- /private/tmp/warden-cutout-export/godot_export_debug --headless`. The same-basename PCK supplies its boot scene; the template disables the normal `--path` override.

## Playable inspection

The self-healing fixture command regenerates and independently reloads the pre-action save before opening the game. Choose **Continue** and watch the rigid idle bob. Select the player, then choose a nearby destination to inspect other facings. Choose **Pass** to see the two Wardens advance and attack. Moving around them shows the front/rear/reflected views. Brace and Patch Up allow further turns; the fixture starts the player at 40 HP. The review branch is `codex/stone-warden-editable-front-rear-cutout`, based on local `master` commit `65b667daf19568ff62892b458e36a41645f579be`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/stone-warden-editable-front-rear-cutout && python3 tools/inspection_fixture.py --task-id stone-warden-editable-front-rear-cutout --run-id stone-warden-runtime-v3-inspection --manifest /private/tmp/stone-warden-runtime-v3-inspection.json --launch --scenario combat --summary "Stone Warden repair: inspect the clean idle bob, then Pass for the front-arm overhead strike" --player-position 3:5 --player-hp 40 --player-max-hp 40 --enemy-types warden,warden --enemy-positions 3:3,5:5 --enemy-intents marching_blow,crushing_step --hand quick_stab,brace,sidestep_slash,bone_dart,patch_up
```

Remaining limits: neutral shadows use a static rest silhouette to avoid per-frame GPU readback; the accepted art quirks remain. Alternate resolutions/UI scales, physical controller hardware and Windows runtime were not exercised. Combat rules, analytics and icon identities are unchanged. Publication remains pending inspection and explicit approval of the reviewed commit.
