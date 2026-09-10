# Noctyrax cutout in gameplay

Generated proof paths cited below are retained in the [external roster evidence archive](enemy_cutout_roster_integration.md#evidence-archive-and-compact-history). Editable source cases remain in this repository.

## Design and acceptance

Noctyrax's combat-board silhouette should communicate its facing and distinguish a claw rake, aimed breath, radial coil and Last Eclipse gathering/release. The existing boss bar, intent text, target tiles and turn-clock portrait continue to answer the player's tactical questions. Movement, cards and Pass remain available through the established pointer, keyboard and controller paths. Proof targets the real board at 1920×1080 and 100% UI scale, including reduced motion, multiple actors, all four supported facings, completed player movement and death.

This is presentation work. The authoritative definition remains `data/enemies.json`: 72 HP, initiative 14, 120 embers, 2×2 footprint, boss bar and 1.86 art scale with the existing 10px vertical offset. The encounter's veilbound acolytes, statuses, surfaces, targeting and pathing remain unchanged. No balance or analytics boundaries change.

## Authoring

The fresh case is `experiments/cutouts/noctyrax/v01`. Its front master is the unchanged accepted 255px source. Generated rear paint and concealed joint material retain untouched outputs, actual prompts, reference roles, disposition and hashes. Registration uses one 255px source coordinate frame and a fixed padded 512px canvas. The skeleton is built for the dragon's crouched body, neck/maw, wings, claws and curled tail.

The retained native editor entry points are `v01/proof/front.tscn` and `v01/proof/rear.tscn`. Recipes live in `v01/recipes`: `build_front.py` and `build_rear.py` define pixel ownership and the dragon skeleton, `register_rear.py` registers the retained rear output, `hidden_material.py` adds concealed paint, and `skin_and_promote.py` runs the maintained skin command and copies the production closure. Rebuild from the repository root in registration → segmentation → concealed paint → skin/promotion order, deliberately moving only the derived segment output aside first. Keep the accepted source and generation records intact. Motion edits belong in the case's `motion.gd` and are promoted with the same recipe.

## Runtime

Production owns `assets/units/noctyrax_cutout` and `scripts/noctyrax_cutout`. Each actor retains its own viewport texture and both painted views. The shared enemy-facing policy owns idle directions; actions face their resolved target and return to player-facing idle after completion. Death freezes the cutout for the existing dissolve. Static rest paint supplies cached HUD and shadow bounds; portraits remain independently registered.

`umbra_eclipse` arrives from the resolver as an `aoe` step with an explicit action type. The renderer selects the eclipse clip before the generic area coil. Melee and area actions retain their original result/effect boundaries: authored release phase 0.5 maps to 42% for the claw and 38% for coil/eclipse. Breath aims the maw at the existing 18% projectile launch, holds through the 66% impact and then recovers. A violet-edged shadow plume begins at the animated head anchor, with a compact impact ring and a still impact cue under reduced motion. The existing Umbra path clips visible shadow fragments; it cannot select the physical arrow texture. The claw trail waits for the rake, leaving preparation readable. The animation never applies outcomes.

Idle uses one coordinated 1.5px body translation over 2.4 seconds, with all four legs counter-translated and no local rotation, scale or skew. The low quadruped walk uses a 40px stride with 65% support, 61.538 source pixels of projected travel and a 0.85-second cycle. Phase follows resolved board distance at the unchanged boss scale. Limbs preserve their transverse width, while terminal claws stay rigid. Actions last 1.1 seconds (claw), 1.2 seconds (breath and coil) and 1.6 seconds (eclipse) before returning to idle.

The ownership recipes place the front tail tip before the claws and the scaly proximal tail before the overlapping wing. Tail rotations then curl inward beneath the body. Concealed joint material comes from the retained generated paints; no substitute geometric limbs are introduced. The small native rest bakes are retained as explicit source inputs to `skin_and_promote.py`. After changing anatomy, regenerate them from the asset probe and require the subsequent strict comparison to pass.

## Verification

Fresh case evidence is retained in `experiments/cutouts/noctyrax/v01/proof`: 608 rendered board frames, 464 measured poses and 12 pixel-identical saved-scene reloads pass. Both `front.tscn` and `rear.tscn` retain the editable skeleton, skinned parts and AnimationPlayer tracks. Every sampled action fits inside the padded canvas; maximum native support drift is 0.000077805 source pixels and target error is 0.000068240 source pixels. The 23.2-second study reel retains the declared playback durations, with verified full decode and no synthesized poses. `verify-render` binds 1,021 inputs and 1,599 outputs. Eight native phases from each of the twelve clips were inspected and retained as contact sheets under `runtime_v1/authoring`. The runtime probe owns real `RunScene` triggers and compares final state with a separate call to the existing resolver, including damage, pull, statuses, terrain, traps, Umbra, initiative and every enemy footprint.

The asset probe compares 370 native production/case frames across rest and all six clips. Both shipped rest bakes match the native assembly exactly. The front and rear action sheets retain the inspected preparation, release and recovery poses, including the concealed wing-base repair. `identity_audit.json` verifies the accepted front master, exact registered segmentation reconstruction, generation provenance hashes and unchanged enemy definitions. The runtime proof verifier binds 1,553 current inputs and 159 retained outputs; all 928 freshly rendered pose images match the previously inspected pose images exactly after the board-only breath-effect correction.

The production-only PCK loads with the unmodified macOS 4.6.1 debug export template (`editor=false`) without case/tool files or imported caches. The focused cutout suite and all 16 workflow tests pass. The full suite passes with its established ambiguous-save migration and ObjectDB shutdown warnings. The environment also emits a macOS certificate initialization warning under the sandbox; no network behavior is exercised.

The final native gameplay capture contains 27 clips, 2,590 samples and 81 full-resolution stills. Its 98.067-second gameplay reel repeats captured frames at 60fps using their measured timestamps, with no synthesized poses and less than one frame of timing error per clip; full decoding and the exact frame count pass. Maximum measured world-space support drift is 0.000152588px. The live probe uses two dragons plus two veilbound acolytes to stress per-actor rendering, while only the first dragon is due to act. It covers both idle cycles in four directions; all four existing intent families; reduced claw and breath motion; pointer targeting on the 2×2 footprint; controller Cancel and pointer handoff; four legal two-tile player moves; and the defeated actor's dissolve/removal while the other renderer survives. Night Coil's existing fixed 2×2-origin pattern cannot reach a southwest cardinal victim: its first successful action sample uses the northwest edge instead. Both front/rear authoring views and reflections still cover the coil clip, and the other intents exercise all four real action directions.

The affected UI rubric gates are comprehension, hierarchy, battlefield visibility, action/result feedback, input completeness, visual cohesion, reduced motion, layout resilience and native proof. The changed-presentation checks pass at 1920×1080 and 100% UI scale; `runtime_v1/visual_review.json` records the observed result and limits. The oversized 12×12 stress scene exposes existing top-edge overlap with the fixed boss header, and controller focus uses the existing zoom that can place the hand below the viewport. This task does not alter those camera/HUD layouts. Boss HP, intent text, target tiles and the separate turn-clock portrait retain their established roles.

The optional `cutout_workflow.py render --gui-lease-timeout` argument forwards only the native runner's shared lease wait. It matches the concurrent Tharokh task's small change; default waits, startup watchdogs and capture execution limits are unchanged. GUI probes run sequentially through the same common lease.

## Reproduce

```sh
python3 tools/cutout_workflow.py validate experiments/cutouts/noctyrax/v01
python3 tools/cutout_workflow.py verify-render experiments/cutouts/noctyrax/v01 --output experiments/cutouts/noctyrax/v01/proof
python3 tools/godot_task_runner.py --task-id animate-noctyrax-cutout --stream -- godot --headless --path . --script tests/noctyrax_cutout_test.gd
python3 tools/godot_task_runner.py --task-id animate-noctyrax-cutout --stream -- godot --headless --path . --script tests/run_tests.gd
python3 tools/visual_probe_runner.py tests/noctyrax_cutout_asset_probe.gd --task-id animate-noctyrax-cutout --no-headless --expect-size 512x512 --expect-size 255x255 --timeout 120 --gui-lease-timeout 1800
python3 tools/visual_probe_runner.py tests/noctyrax_cutout_gameplay_probe.gd --task-id animate-noctyrax-cutout --no-headless --expect-size 1920x1080 --timeout 180 --gui-lease-timeout 1800
python3 experiments/cutouts/noctyrax/runtime_v1/assemble_proof.py verify
```

Remaining limits: neutral shadows use a static native rest silhouette to avoid per-frame GPU readback. Other resolutions/UI scales, physical controller hardware and Windows execution are not claimed. Combat mechanics, encounter composition, analytics and icon identities are unchanged. Publication requires inspection and explicit approval of the reviewed commit.

## Inspect the committed branch

Regenerate and independently verify the pre-action fixture before each interactive launch:

```sh
cd /Users/borgerding/.codex/worktrees/094d/Labyrinth && python3 tools/inspection_fixture.py --task-id animate-noctyrax-cutout --run-id noctyrax-v01-inspection --manifest /private/tmp/noctyrax-v01-inspection.json --launch --scenario boss --summary 'Noctyrax: inspect idle and facing, then Pass until Void Claw; continue turns for breath, coil and eclipse' --enemy-types noctyrax,veilbound_acolyte,veilbound_acolyte --enemy-positions 3:3,6:2,2:6 --enemy-intents void_claw --player-position 3:6 --player-hp 120 --player-max-hp 120 --hand quick_stab,brace,sidestep_slash,bone_dart,patch_up
```

The fixture contains one Noctyrax and two veilbound acolytes, with extra player HP for inspection. Noctyrax is not the first actor due: press Pass until its first turn, then continue or move the player to inspect facing and travel. To inspect breath or eclipse immediately on that first boss turn, replace `--enemy-intents void_claw` with `starless_breath` or `last_eclipse`. For coil, use `night_coil` and also `--player-position 5:3`, inside the existing fixed pull pattern. The hand supports attacking, blocking, movement and healing. The saved fixture embeds its persisted-state contract; the manifest records the independent verifier and regeneration command. The review handoff binds this fixture to the exact committed HEAD.
