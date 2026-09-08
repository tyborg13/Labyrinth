# Protagonist cutout in gameplay

## Design statement

The player must read their position, facing, travel and melee contact on the existing combat board. Promote the accepted pass-seven front/rear paint unchanged, reflect it into all four board directions, and keep the same cutout visible through every action and idle state. Give breathing a subtle planted-foot bob, keep walking brisk, and concentrate the sword cut around damage contact. Preserve board registration, HUD clearance, target selection, input paths, and the existing action-result/event boundaries. Reduced motion retains the new artwork and final facing with a still neutral pose.

The primary proof is actual 1920×1080 gameplay at 100% UI scale: idle, four directions of movement/melee, other action transitions, equipment, reduced motion and save/resume. The full Godot suite and focused animation tests must pass, followed by independent review and a playable combat Continue fixture. Publication requires separate user approval.

## Ownership and rendering

`assets/units/protagonist_cutout` and `scripts/protagonist_cutout` own the production rig, motion and accepted paint. The experiment remains a frozen inspection reference. Layout JSON is included explicitly in every export preset; painted PNGs use the existing `keep` import convention and load through AssetLoader in source and exported builds. Experiment/reference/proof assets are excluded from shipped packages.

The board owns one transparent viewport and two persistent facing rigs. Only the selected rig draws. The viewport texture updates without invalidating retained board layers for breathing. Body/HUD/obstruction geometry uses the fixed 255-pixel source registration; only texture submission expands to the padded 512-pixel action canvas. Static cutout rest art supplies cached shadows and HUD silhouette geometry, so animation never reads a live viewport back from the GPU or accumulates per-frame silhouette caches.

Motion descriptors are presentation-only. No resolver, card balance, initiative, save format, or analytics event payload changes. `player_moved` and `card_played` keep their existing single resolved-action boundaries described in analytics.md.

The walking gait runs at a 0.24-second cycle (2.78× the experiment cadence). Root speed follows its projected source-pixel travel, so a typical full-size tile takes about 0.67 seconds and support feet do not skate. Single-target melee takes 0.50 seconds overall; its cut occupies 30 milliseconds around the existing 42% contact threshold. Self-centered AoE weapon attacks use the existing melee sound classification and play the cutout swing while preserving their 0.24-second effect and 38% contact boundary. Targeted AoE remains a casting action. Other actors keep their existing presentation timing.

The old whole-sprite melee lunge is removed: the articulated torso drive and planted feet supply the action on the protagonist’s real tile. Slash artwork is withheld during anticipation and peaks with the cut; idle resumes as soon as the recovery ends even while damage text is still finishing. Cached equipment views follow later reduced-motion changes. Existing death squash and Blink echo scaling transform the logical body rectangle before padding is added, preserving their floor registration.

## Verification and UI handoff — pass eight

The changed surface is the full-body protagonist on the combat/room board and equipment panel. The player identifies facing, travel and melee contact while selecting tiles/cards through the existing pointer and controller paths. Board, HP, action results and target previews retain their hierarchy; there are no copy or icon conversions. CombatBoardView, RunScene, AttackFxLibrary, retained board layers, AssetLoader and the existing equipment TextureRect are extended.

Affected rubric gates: immediate comprehension, visual hierarchy, gameplay visibility, state/consequence, interaction completeness, visual cohesion, accessibility, layout resilience and visual proof all **Pass** at 1920×1080/100%. All four movement facings and melee preparation/contact/recovery frames were inspected at native resolution, together with controller target/cancel, equipment, reduced motion, Blink, incoming damage, terminal defeat, resumed combat and ordinary-room idle. The grounded body remains registered to the tile; target rings and HP remain readable. Reduced motion deliberately holds the new rest pose and keeps facing. No rules/copy/identity changes.

Evidence is in `experiments/protagonist_2d/renders/pass8/gameplay/`:

- `movement_melee_idle_full_speed.mp4`: primary 14.99-second 1920×1080 reel; idle, four directions of actual movement/melee, and Whirlwind Slash. `movement_melee_idle_closeup.mp4` is a 704×512 crop of the same reel, with the same timing.
- `gameplay_full_speed.mp4`: 33.73 seconds across 21 actual gameplay sequences, including defensive/ranged actions, Blink, Guarded Step, damage, reduced motion and defeat. Both full-frame videos preserve recorded wall-clock sample intervals, converted to 60 fps; there is no slow motion, interpolated animation, or time stretching. All three videos decode without errors; selected decoded frames were also inspected.
- 49 native PNGs and four mid-step JPEGs show the final rendered states. `gameplay_manifest.json` records pose, facing, stable texture identity, positions, HP and effects for all 884 sampled frames. `visual_probe_result.json` records the accepted Metal/mobile rendering run.
- `capture_input_sha256.json` binds the 105 runtime, art and test inputs to the final capture. `proof_sha256.json` hashes the retained outputs. No runtime or test input changed after that capture.
- `full_suite.log`: **TEST RESULT: PASS**. The suite still emits its established CanvasItem/dummy-texture/ObjectDB/resource shutdown warnings (also documented by the board-surface/performance verification specifications); this is not a clean-shutdown claim.
- `focused_suite.log`: focused cutout suite **PASS**, including facing/reflection, persistent texture, loadable paint, planted idle/attack feet, idle loop seam, action return, reduced motion, board registration through squash/echo scaling, and self-centered AoE classification/contact timing.
- `native_gameplay.log`: real RunScene action probe **PASS**, including Whirlwind Slash applying exactly 8 damage once to each of four adjacent enemies and targeted Cinderburst retaining its casting pose. The native run exercises real enemy turns, damage and terminal defeat; the optional headless probe skips those frame-post-draw-dependent enemy steps.
- `export_runtime.log`: **PASS (editor=false)** in the unmodified macOS 4.6.1 debug export runtime using a production-only PCK, without experiment files or imported caches. This verifies packaged cutout loading, not a full platform export or Windows certification.

Reproduction from this worktree:

```sh
python3 tools/godot_task_runner.py --task-id protagonist-2d-skeletal-experiment --stream -- godot --headless --path . --script tests/protagonist_cutout_test.gd
python3 tools/godot_task_runner.py --task-id protagonist-2d-skeletal-experiment --stream -- godot --headless --path . --script tests/run_tests.gd
python3 tools/visual_probe_runner.py --task-id protagonist-2d-skeletal-experiment tests/protagonist_cutout_gameplay_probe.gd --no-headless --rendering-method mobile --rendering-driver metal --expect-size 1920x1080 --timeout 180 --result-manifest /private/tmp/protagonist-cutout-gameplay-result.json
python3 tools/godot_task_runner.py --task-id protagonist-2d-skeletal-experiment --stream -- godot --headless --path . --script tests/protagonist_cutout_pack_test.gd -- build /private/tmp/protagonist-cutout-v8-export/godot_export_debug.pck
```

For the last check, extract the matching Godot macOS debug template as `/private/tmp/protagonist-cutout-v8-export/godot_export_debug`, then run it through godot_task_runner from `/private/tmp` with `--headless`. Export templates disable `--path`; the same-basename PCK contains its minimal boot scene and production files.

Remaining limits: the shadow uses the new neutral cutout silhouette as a static cache instead of following limb articulation; this avoids live GPU readback and matches the retained shadow pipeline. The accepted pass-seven art quirks remain available for the user's later fine tuning. No alternate resolutions/UI scales or physical controller/Windows device runs were requested or certified.
