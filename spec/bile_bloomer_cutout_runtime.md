# Shale Bloomer cutout in gameplay

Current travel cadence, floor registration and room fitting are specified in [Actor presentation](actor_presentation.md); the timings and offsets below describe the original integration.

Generated proof paths cited below are retained in the [external roster evidence archive](enemy_cutout_roster_integration.md#evidence-archive-and-compact-history). Editable source cases remain in this repository.

## Design and scope

The combat board shows Shale Bloomer's rooted travel, outward Shale Burst and aimed Shard Mark through distinct poses. The player keeps choosing movement, cards and Pass through the existing controls. The accepted front painting and stable enemy ID `bile_bloomer` remain unchanged. The creature is a pitted mineral trunk, crown, amber core, five tendrils and spreading roots. It does not inherit the Stone Warden's limbs or attack motion. Shale Shell retains the restrained existing Stoneskin effect.

No combat rule changes: 14 HP, 14 base initiative, 12 reward embers, earth identity, existing intent weights and costs, Burst's three damage and diamond-two rubble, Mark's three damage/range four/two Expose/rubble, and Shell's two Stoneskin plus two from rubble fuel are preserved. The resolver, result application and append-only analytics paths remain unchanged. Art-only changes require no balance rescoring or icon-registry edits.

## Runtime and motion contract

Production owns the parts and JSON in `assets/units/bile_bloomer_cutout` and the sampler, rig, renderer, pool and emitted-shard drawing in `scripts/bile_bloomer_cutout`. The selected editable case is `experiments/cutouts/bile_bloomer/v01`. It uses 18 bones, 19 parts and three root meshes in each painted view. Production reuses the existing skeleton loader and common enemy-facing policy; it never loads experiment or tool files. All export presets explicitly include its layout JSON and its PNGs use raw keep imports.

Each actor retains a 512px viewport texture with both facing rigs loaded. A 255px logical body at the existing 0.86 art scale and -6px Y offset continues to supply target, obstruction, HP and intent geometry. Only the submitted texture receives the transparent padding. The dedicated 128px turn-clock portrait stays separate. Neutral shadows and HUD geometry use the registered rest bake, with no per-frame GPU image readback. Preview echoes reuse the actor's texture. Hidden actors stop idle updates. Death freezes the same texture for the existing dissolve, then removes only that actor's renderer.

Idle uses a 1.8-second coordinated upper-body translation with a 1.2 source-pixel bob. The three root contacts countertranslate; every painted basis stays unchanged. Crown petals open only for attacks, so rigid mineral plates do not ripple in idle. The roots travel with a 40px stride and 70% support fraction: 57.142857 source pixels per 0.9-second cycle. Three staggered root groups keep at least two contacts planted. Each rigid terminal root draws backward at the actor's actual board speed while planted and lifts six source pixels during its return. Runtime phase follows cumulative travel distance across route segments.

Shale Burst takes 1.0 second, bracing before the crown opens at the existing 38% area-result boundary. Nine small angular mineral fragments leave the core; the existing area indicator, rubble and damage remain on their original paths. Shard Mark adds a 0.28-second aiming preparation before the unchanged 0.704-second earth effect. Its complete authored cycle is 0.984 seconds; release occurs at `(0.28 + 0.064) / 0.984`, and contact at `(0.28 + 0.256) / 0.984`. The existing earth effect originates at the current core socket, including reflections. No result or analytics event is emitted during preparation.

Enemy idle selects the closest front/rear/reflected direction toward the player's displayed tile through `enemy_cutout_facing.gd`. Walks and attacks keep their action direction. Idle updates after either actor finishes moving, without turning toward an uncompleted player destination. The protagonist keeps its camera-facing idle. Reduced motion retains the same directional art in a still pose, suppresses the added fragment motion and skips preparation frames.

## Paint and ownership

The original and registered front sources are byte-identical to `assets/art/enemies/bile_bloomer.png`. Built-in image generation supplied the rear and concealed calyx/root donors. Untouched outputs, actual prompts, reference roles, disposition and digests are retained under the case's `source` directory. The alpha-correction result was rejected because it again returned RGB checkerboard and changed the design. The coordinating task explicitly authorized deterministic background exclusion as ownership/registration. The retained mask excludes neutral background RGB; explicit solid-material regions preserve neutral highlights. Source RGB remains unchanged. Rear registration uniformly scales the whole creature, with only integer raster rounding. Hidden donor crops also use uniform registration.

The r11 case retains the r10 owners that separate the amber core and moving crown edges. The front middle-left and rear upper-left amber trunk rims belong to the rigid trunk, avoiding floating slivers when their tendrils move. Lateral root weights stay on the trunk through source Y=211, then blend to the rigid toes by Y=225; this keeps the entire upper attachment closed during the return stroke. The rear central stem reaches full toe weight at its earlier Y=210 ownership boundary. The front painting has slightly translucent source pixels, so hidden calyx and root donors are off in rest/idle. The calyx appears only during an opened attack and the basal donor only during root travel. Original visible paint remains above these concealed inserts. All semantic extraction and three root weight fields use the maintained segment/skin pipeline, with explicit ownership polygons and no catch-all sweep.

## Verification and inspection

Evidence is retained in `experiments/cutouts/bile_bloomer/runtime_v2`; the editable scene proof is under `v01/proof`. The earlier r10 walk inspection exposed a straight root-attachment gap. `root_attachment_repair.json` retains that finding and the fresh r11 comparison images. The current native asset capture passes all 580 production/case pose comparisons and both rest-bake comparisons. All 16 front/rear/painted/reflected idle, walk, Burst and Mark cycles were inspected. The complete 512px canvas bounds range from (134,123) to the exclusive end (377,390), including roots in travel.

The focused suite and full suite pass after the repair. They check independent actors, Warden coexistence, persistent textures, idle and action facing, reduced motion, padding/HUD geometry, preview echoes, hidden actors, frozen death art and renderer removal. The full suite retains its expected ambiguous-save warning and existing ObjectDB shutdown warning. The production-only PCK also passes on the unmodified macOS 4.6.1 debug export template (`editor=false`) from an empty directory. `export_template.json` and `export_pack.json` bind the binary and pack; this proves the shipped cutout loads without the experiment, tools or imported texture cache.

`preservation_audit.json` verifies all 38 promoted part images and both rig topologies against the selected case, the byte-identical accepted front copies, untouched generated RGB behind the explicit ownership masks, and the unchanged baseline portrait, enemy data, resolver, shared facing and effect library. `capture_input_sha256.json` binds the complete case/rendering dependency closure and native probe scripts; `verification_input_sha256.json` binds the full-suite and export/test entry points.

The editable-scene capture passes 408 authored samples and eight pixel-identical saved-scene reloads. `verify-render` checks 1,100 inputs and 1,031 outputs. The 14.767-second scene reel preserves authored timing. Actual RunScene proof passes 21 clips, 2,118 timestamped samples and 51 native PNGs. It exercises both attacks in all four directions, two idle views and their reflections, Shell with and without fuel, reduced motion, targeting/cancel/input handoff, player repositioning and death. Outcome assertions preserve damage, Expose, rubble, fuel consumption and initiative. Maximum planted-root drift is 0.000252 world pixels. The full gameplay reel is 80.683 seconds; the short preview uses four complete clips totaling 19.267 seconds. Both fully decode, and actual sample timing is retained with at most one 60fps frame of rounding per clip.

`visual_review.json` records the inspected native art cycles, scene studies and gameplay states. `gameplay/source_frame_sha256.json` retains hashes for every raw JPEG, its original isolated capture root, and 154 selected native frames; the full videos, native PNGs and actual timestamps remain in this case. `proof_sha256.json` binds the retained runtime evidence. The reproducible commands are in `runtime_v2/README.md`.

UI rubric results apply to the changed combat actor at 1920×1080/100%:

| Gate | Result and evidence |
| --- | --- |
| Immediate comprehension | Pass: idle, travel and open-crown release read alongside the existing intent and action labels. |
| Visual hierarchy | Pass: the restrained bob and small fragments leave damage, targeting and the current card primary. |
| Gameplay visibility | Pass: registered logical bounds preserve tiles, HP, intents and the hand; padded textures do not expand hit geometry. |
| Compact, precise copy | Pass: no new player copy or changed mechanics text. Existing intent labels and values remain intact. |
| State and consequence | Pass: damage, rubble, Expose, Shell values, lethal preview and dissolve remain visible and match asserted outcomes. |
| Interaction completeness | Pass: existing pointer selection, controller focus/cancel and return to the pointer are exercised; no new controls or hover dependency. |
| Visual cohesion | Pass: accepted mineral paint, existing HUD and existing earth effect are retained; generated rear and concealed paint match that anatomy. |
| Accessibility | Pass: reduced motion uses still directional art and existing static outcomes; no rule relies on the new animation or fragments. |
| Layout resilience | Pass: the actor and its complete cycles stay inside the padded canvas; normal and controller-focus board presentations retain operable controls at the required configuration. |
| Visual proof | Pass: fresh native complete asset cycles and relevant real RunScene states were inspected, including the corrected moving root attachments. |

The targeting probe invokes the existing hover handler directly, so its pointer preview arrow terminates at the capture pointer's corner position. Its selected tile, lethal preview and target geometry are still exercised; this does not claim physical pointer/controller hardware testing. Peer review and the final verified fixture are recorded against the committed branch HEAD at handoff.

The inspection command regenerates and independently reloads the pre-action combat save before opening the game. Choose **Continue**, watch both idle views, then **Pass three times** to reach their first attacks (the clock starts at zero). Select the player and move around the Bloomers to inspect their other facings. Brace and Patch Up allow additional turns; the player starts at 40 HP. The branch is `codex/animate-bile-bloomer-cutout`, based on local `master` at `01c7dccbc931ae7dddf3eb8f797fb3d1d33def3e`.

```sh
cd /Users/borgerding/.codex/worktrees/4a12/Labyrinth && python3 tools/inspection_fixture.py --task-id shale-bloomer-editable-cutout-and-gameplay-animation --run-id shale-bloomer-cutout-inspection --manifest /private/tmp/shale-bloomer-cutout-inspection.json --launch --scenario combat --summary "Shale Bloomer: inspect rooted idle, then Pass three times for Shale Burst and Shard Mark" --player-position 3:5 --player-hp 40 --player-max-hp 40 --enemy-types bile_bloomer,bile_bloomer --enemy-positions 3:2,5:5 --enemy-intents bile_burst,spore_mark --hand quick_stab,brace,sidestep_slash,bone_dart,patch_up
```

Residual scope: native proof targets macOS Metal/mobile at 1920×1080 and 100% UI scale. Alternate resolutions/scales, physical controller hardware and a Windows runtime are not part of this proof. Typed Array assignments follow the Windows compatibility rule. The neutral shadow intentionally uses a static rest silhouette. No new block, hit or Shell animation is introduced; those states preserve the cutout and their existing feedback.
