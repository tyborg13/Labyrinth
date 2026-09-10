# Tunnel Crawler cutout in gameplay

Generated proof paths cited below are retained in the [external roster evidence archive](enemy_cutout_roster_integration.md#evidence-archive-and-compact-history). Editable source cases remain in this repository.

## Design and runtime contract

The combat board shows the Tunnel Crawler's low four-limb skitter, hooked claw preparation and contact, stronger Lunge, and defensive Coil. The accepted front painting and creature design remain intact. The player continues using movement, cards, Pass, targeting, and controller Cancel through the existing input paths. The logical body, target tiles, health and intent panels, and dedicated turn-clock portrait keep their established geometry and behavior.

The editable case is `experiments/cutouts/crawler/v01`. Production owns the selected paint and layouts in `assets/units/crawler_cutout` and the sampler, rig, and renderer in `scripts/crawler_cutout`; it never loads an experiment or tool. All three export presets include its layout JSON. Each actor has one persistent 512px viewport with two loaded rigs. The 255px logical body and existing 0.64 art scale determine board geometry. Destination echoes reuse the actor texture. Hidden actors pause, death freezes the same texture for the established dissolve, and removed actors release their renderer.

The shared `scripts/enemy_cutout_facing.gd` policy chooses the closest supported front/rear/reflected direction toward the player during idle. Movement and melee face their own destination. Observers wait for completed player movement before turning. The player retains camera-facing idle. The existing `tunnel_crawler.png` portrait remains in the turn clock.

Idle is one coordinated 1.25px body/head bob over 1.4 seconds, with all four limb roots counter-translated. Every idle bone basis and limb transform stays fixed. Walking has four staggered contact phases, 70% stance, 56px support stride and 80px source travel per 0.34-second cycle. Hand/toe lifts are 6px/4px. Phase follows actual distance across multi-segment routes at the existing body scale. The shafts project along their lengths while their orthogonal width stays fixed; terminal claws, feet, and head remain rigid.

Skitter Strike hooks the near claw back and up, then rakes it forward with a small body commit. Lunge has a larger claw reach and body commit. The other three contacts stay planted, replacing the old whole-sprite melee lunge. The authored 52% contact maps to the existing 42% feedback boundary; the existing slash trail waits for the rake. Skitter Strike plays over 0.6 seconds and Lunge over 0.75 seconds. Coil performs a restrained 0.48-second defensive curl after its travel. Reduced motion keeps the same art still with the current facing. Cached neutral rest bakes supply stable HUD and shadow geometry without per-frame GPU readback.

No resolver, enemy definition, intent weight, initiative, HP, damage, Bleed, reward, spawn, or append-only analytics boundary changes. Skitter Strike retains move range 3 and melee 4/range 1/Bleed 1; Coil retains move 2 and self Block 4; Lunge retains move 4 and melee 6/range 1/Bleed 1. Balance scoring and analytics changes are therefore not applicable.

## Editable art

The original front image is retained byte-for-byte. The matching rear source and genuinely missing hidden flesh were generated with the built-in image tool; untouched outputs, actual prompts, reference roles, digests, and rejection reasons remain under `v01/source`. The rear is uniformly registered on the same 255px canvas using the crop and nearest-neighbor transform in `recipes/registration.json`.

The explicit ownership recipe assigns every original nontransparent source pixel to an anatomical piece exactly once. Each view has 15 joints, 15 painted parts, and eight continuously weighted limb meshes. Narrow generated hidden shafts and caps fill concealed gaps; the shoulder pocket stays beneath the torso. The head, hands, and feet are separate rigid pieces. Original paint is not redrawn or recolored. Hidden material can add concealed pixels to the rest assembly, so the assembled rest is not claimed to equal the original front image byte-for-byte. A scratch rebuild of segmentation and skinning reproduced all **51** case inputs exactly (`runtime_v1/recipe_rebuild.json`).

## Verification

Affected UI rubric gates are comprehension, hierarchy, gameplay visibility, consequence feedback, input completeness, visual cohesion, reduced motion, layout resilience, and native proof. Review uses the real renderer at **1920×1080, 100% UI scale**, with fixed-canvas creature detail where necessary.

The current [v01/proof](../experiments/cutouts/crawler/v01/proof/) passes **416** native authored samples, complete fixed-canvas bounds/contact checks, and **10** pixel-identical saved-scene reloads. Both editable `.tscn` files retain their Skeleton2D, continuous meshes, and AnimationPlayer tracks. Current `verify-render` checks **1,006 inputs and 1,079 outputs**. Native idle basis error is exactly zero, the body bob is 1.25px, and the largest limb-transform rounding difference is 0.0000153 source pixels. The authored-speed board reel is 10.63 seconds, with at most one 60fps frame of boundary rounding per clip and a passing full decode. Native board walk and claw contact frames were inspected alongside the complete production pose cycles.

Current runtime evidence is retained in [runtime_v1](../experiments/cutouts/crawler/runtime_v1/):

- `focused_suite.log`: **PASS** for rig independence, four-way facing, fixed idle limbs, contact timing, intent routing, logical/padded geometry, echoes, reduced motion, hidden actors, and death lifecycle.
- `assets/comparison.json`: **612** native samples of rest and all five clips match the editable case and production rig pixel-for-pixel in front/rear and both reflections. Every sample fits the fixed 512px canvas; both native rest bakes match the shipped silhouettes. All complete cycles were inspected, with review contact sheets retained under `visual_review`.
- `full_suite.log`: **TEST RESULT: PASS**. The pre-existing ambiguous-save migration and ObjectDB shutdown warnings remain; this is not a clean-shutdown claim.
- `export_build.log` and `export_runtime.log`: **PASS**, including `editor=false` from an unmodified Godot 4.6.1 macOS export template and a production-only PCK. The package contains no experiment/tool sources or imported asset cache. `export_template.json` retains the executable provenance and digest. This checks packaging, not a full platform release or Windows execution.
- `workflow_tests.log`: the maintained cutout workflow tests pass. The optional `--gui-lease-timeout` forwarding matches the batch coordinator's small shared change, preserving default behavior and all startup/capture watchdogs while allowing a bounded wait for the common renderer lease.
- `gameplay/manifest.json`: **19** actual RunScene sequences and **1,670** timed samples pass. Skitter Strike deals exactly 4 damage and 1 Bleed in all four directions; Lunge deals exactly 6 and 1 Bleed after its two-tile travel; Coil grants exactly 4 Block. Visible damage changes at the existing contact boundary, and resolved position/initiative match the unchanged CombatEngine. Maximum world-space planted-contact drift is **0.000244141px**. Two independent crawlers, reduced motion, lethal damage/dissolve/removal, controller Cancel, pointer handoff, and four completed player repositioning paths pass.
- `gameplay/crawler_gameplay_full_speed.mp4`: **63.40 seconds**, 1920×1080/60fps, preserving measured wall-clock intervals through frame repetition. `video_timeline.json` retains every interval and output-to-source frame mapping; clip-boundary rounding is at most one output frame, with no synthesized poses. Full decoding passes. **49** native PNGs retain preparation, contact, recovery, idle, targeting, input handoff, repositioning, and death states. Raw JPEG samples remain in the isolated probe directory and are identified by `source_frame_sha256.json`.

`capture_scope.json` records the two lease-only Python helper edits made after the gameplay capture. Neither helper is loaded by RunScene; every runtime script, art/layout, data, scene, shader, and gameplay probe input remains unchanged. `gameplay_capture_input_sha256.json` preserves the original 1,046-input capture snapshot; `capture_input_sha256.json` records 1,049 current inputs for the subsequent asset/case verification. The queue-forwarding addition is exercised by the current maintained native render and Python workflow tests.

`proof_sha256.json` binds **728** retained runtime outputs; `proof_verification.json` confirms those artifacts and the 1,049 current inputs. `native_metrics.json` records the complete study's rigid-basis, contact-target, support, and idle measurements. All current verification passes; construction drafts remain outside the branch.

Reproduce focused and live checks from the task worktree:

```sh
python3 tools/godot_task_runner.py --task-id animate-crawler-cutout --stream -- godot --headless --path . --script tests/crawler_cutout_test.gd
python3 tools/godot_task_runner.py --task-id animate-crawler-cutout --stream -- godot --headless --path . --script tests/run_tests.gd
python3 tools/visual_probe_runner.py tests/crawler_cutout_asset_probe.gd --task-id animate-crawler-cutout --no-headless --rendering-method mobile --rendering-driver metal --expect-size 512x512 --expect-size 255x255 --timeout 180 --gui-lease-timeout 1800
python3 tools/visual_probe_runner.py tests/crawler_cutout_gameplay_probe.gd --task-id animate-crawler-cutout --no-headless --rendering-method mobile --rendering-driver metal --expect-size 1920x1080 --timeout 240 --gui-lease-timeout 1800
python3 tools/cutout_workflow.py render experiments/cutouts/crawler/v01 --output /private/tmp/crawler-fresh-proof --task-id animate-crawler-cutout --backend metal --gui-lease-timeout 1800
python3 tools/cutout_workflow.py verify-render experiments/cutouts/crawler/v01 --output experiments/cutouts/crawler/v01/proof
```

The export smoke check builds with `tests/crawler_cutout_pack_test.gd -- build /private/tmp/crawler-cutout-export/godot_export_debug.pck`. Place the matching unmodified macOS debug template beside that PCK as `godot_export_debug`, then execute it through `godot_task_runner.py --project /private/tmp/crawler-cutout-export --task-id animate-crawler-cutout --stream -- /private/tmp/crawler-cutout-export/godot_export_debug --headless`.

## Playable inspection

The branch is `codex/animate-crawler-cutout`, based on local `master` commit `01c7dccbc931ae7dddf3eb8f797fb3d1d33def3e`. The fixture opens before the player acts, with three crawlers presenting Skitter Strike, Lunge, and Coil. Choose **Continue**, inspect idle and targeting, then **Pass twice** from the untouched fixture to watch all three intents. Their normal first activations fall after the player's first nine-time interval. Move the player around to inspect the four facings. Brace and Patch Up support additional turns.

```sh
cd /Users/borgerding/.codex/worktrees/077c/Labyrinth && python3 tools/inspection_fixture.py --task-id animate-crawler-cutout --run-id crawler-cutout-inspection --manifest /private/tmp/crawler-cutout-inspection.json --launch --scenario combat --summary "Tunnel Crawler: inspect idle and facings, then Pass twice for Skitter Strike, Lunge, and Coil" --player-position 3:5 --player-hp 40 --player-max-hp 40 --enemy-types crawler,crawler,crawler --enemy-positions 3:3,5:5,1:4 --enemy-intents skitter_strike,lunge,coil --hand quick_stab,brace,sidestep_slash,bone_dart,patch_up
```

Remaining limits: shadows use the neutral rest silhouette; alternate resolutions/UI scales, physical controller hardware, and Windows runtime were not exercised. Publication and cleanup await user inspection and explicit approval of the reviewed commit.
