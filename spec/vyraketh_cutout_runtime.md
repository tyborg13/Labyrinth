# Vyraketh production cutout

Current travel cadence, floor registration and room fitting are specified in [Actor presentation](actor_presentation.md); the timings and offsets below describe the original integration.

Generated proof paths cited below are retained in the [external roster evidence archive](enemy_cutout_roster_integration.md#evidence-archive-and-compact-history). Editable source cases remain in this repository.

Vyraketh uses an editable dragon cutout for its board body. The accepted front design, portrait, 2×2 footprint, boss health bar, body scale 1.76, vertical art offset 14, 60 HP, 13 initiative and 80-ember reward remain unchanged. Resolver data, targeting, pathing, cinder marks/detonation, terrain interactions, minions, damage and analytics are unchanged. The presentation alone supplies the new anatomy and action cues.

## Art and editable source

The source case is `experiments/cutouts/vyraketh/v01`; its README explains anatomy, timing and authoring commands. `source/front_original.png` is an exact copy of `assets/art/enemies/vyraketh.png` (SHA-256 `70b841c5e3bf28ab4c0f5490b966ae76a21a92c240c0191255eeb34465d9f574`). The registered front uses uniform scaling within the existing logical canvas. Explicit semantic ownership separates torso, long neck, skull, jaw, near/far wings, tail, and four leg/claw chains without omitting source pixels.

The generated rear is registered and reflected to match the shared board direction contract. Two rejected rear candidates and a rejected checkerboard hidden-surface candidate remain beside the selected outputs. `source/generation_requests.json` records the actual requests, references, output digests and decisions. Generated skin/claw surfaces appear only where the accepted views conceal them at rest. Hidden mouth lining opens beneath the original jaw; the source teeth are retained. Front hidden masks require original alpha 255; rear masks allow alpha ≥240 because the generated rear contains near-opaque interior pixels. The small added rear underlays can therefore change near-opaque alpha while preserving the visible design.

Each view has 21 bones, 24 paint parts and 13 deforming meshes. The front graph is authored for its crouched lower-left projection and the rear graph for its upper-right projection. Four distinct limb chains keep separate support lanes; wings and neck use shared transition fields, while claws remain rigid. The tail has its own branch and stays resting during idle. This is a fresh dragon case, built using the maintained segment/skin/render pipeline; historical Warden builders are not runtime or authoring dependencies.

`proof_v1/front.tscn` and `rear.tscn` are self-contained editable Skeleton2D / Polygon2D / AnimationPlayer scenes. Current JSON layouts and `motion.gd` are the maintained authoring inputs. Production mirrors only the runtime layouts, cropped part textures, rest silhouettes and sampler under `assets/units/vyraketh_cutout` and `scripts/vyraketh_cutout`.

## Runtime behavior

Every living Vyraketh owns one persistent 512×512 viewport and two loaded view rigs. The logical 255×255 body begins at (128,128); the extra canvas is action room and does not enlarge HUD or footprint geometry. The shared enemy facing helper chooses the nearest board direction toward the player during idle, after player travel completes. Movement and attacks retain their action direction. The protagonist continues to use its camera-facing idle. Destination echoes share the actor's live texture. Hidden actors pause idle work; death freezes and dissolves the same padded texture, then releases that actor's renderer independently.

Idle is a coordinated 1.35-source-pixel body bob over two seconds with fixed limb supports and unchanged bone bases. Walking is a four-beat crawl with 72% stance, 48-pixel stride, 5.5-pixel lift and 66.667 source pixels of travel per 0.90-second cycle. Runtime phase follows actual world distance divided by the source-pixel scale. Limb segments adjust their projected length without narrowing the paint, and rigid claws counter the parent transforms. The dragon remains grounded.

| Existing action | Dragon presentation | Existing result boundary |
| --- | --- | --- |
| Cinder Maw | Pull neck back, open jaws, thrust and close, recover; paired ember bite marks replace the generic slash | Melee feedback at progress 0.42 maps to authored release phase 0.55; 0.85s presentation |
| Kindle Ground | Lower the head, gather breath, release toward marked ground | Existing 0.20s intent announcement gathers, status application releases, existing 0.48s text interval recovers |
| Crownfire | Raise crown and spread wings as marked tiles detonate | Existing area feedback at 0.38 maps to phase 0.55; 0.95s presentation |
| Cinderfall | Gather high, drive wings down with area fire | Existing area feedback at 0.38 maps to phase 0.55; 1.00s presentation |

These curves alter the visual pose at existing feedback boundaries, not resolver event timing or results. Reduced motion retains the new front/rear art and facing with a still rest pose and the existing reduced feedback path. No new icon identity, rule text, balance assumption or analytics event is introduced.

## Verification and inspection

The proof package lives under `experiments/cutouts/vyraketh/runtime_v2`; final native case proof lives under `v01/proof_v1`. Native asset studies compare every production pose to its editable source and capture every clip in all four facings on the production CombatBoardView at 1920×1080 and 100% UI scale. Actual RunScene proof uses Pass, card targeting and player movement to verify all intent families, actor independence, player-facing idle, reduced motion and boss death. Each resolved action is compared with the complete unchanged engine result for player, enemies, terrain, traps, persistent surfaces and their event records, and initiative.

`experiments/cutouts/vyraketh/proof.py` retains raw evidence, encodes actual gameplay sample intervals with frame repetition only, and checks input/output hashes. The maintained cutout packer retains declared case playback duration and fully decodes its reel. Captures use native Metal through the visual runner and shared GUI lease. Busy-queue runs extend only the lease wait; startup watchdogs remain intact.

Commands:

```sh
python3 tools/godot_task_runner.py --task-id vyraketh-the-cinder-crown-editable-cutout-and-gameplay-animation --stream -- godot --headless --path . --script tests/vyraketh_cutout_test.gd
python3 tools/godot_task_runner.py --task-id vyraketh-the-cinder-crown-editable-cutout-and-gameplay-animation --stream -- godot --headless --path . --script tests/run_tests.gd
python3 tools/visual_probe_runner.py tests/vyraketh_cutout_gameplay_probe.gd --task-id vyraketh-the-cinder-crown-editable-cutout-and-gameplay-animation --no-headless --rendering-method mobile --rendering-driver metal --expect-size 1920x1080 --timeout 420 --gui-lease-timeout 1800 --result-manifest /private/tmp/vyraketh-gameplay-fresh.json
python3 tools/visual_probe_runner.py tests/vyraketh_cutout_asset_probe.gd --task-id vyraketh-the-cinder-crown-editable-cutout-and-gameplay-animation --no-headless --rendering-method mobile --rendering-driver metal --expect-size 512x512 --expect-size 255x255 --expect-size 1920x1080 --timeout 300 --gui-lease-timeout 1800 --result-manifest /private/tmp/vyraketh-assets-fresh.json
python3 tools/cutout_workflow.py verify-render experiments/cutouts/vyraketh/v01 --output experiments/cutouts/vyraketh/v01/proof_v1
python3 experiments/cutouts/vyraketh/proof.py verify experiments/cutouts/vyraketh/runtime_v2
```

The production-only PCK test loads all six clips and both 21-bone rigs with the unmodified macOS Godot 4.6.1 export template (`editor=false`). The package excludes experiments, tools and the project import cache, and uses the production loader unchanged. `tests/vyraketh_cutout_pack_test.gd` creates the PCK and `tests/fixtures/vyraketh_cutout_export_smoke.gd` verifies it. Export preset JSON registrations are additive for all three platform presets.

Native case validation covers 608 authored frames and 12 pixel-identical saved-scene reloads. The independent production comparison covers 740 poses across front, rear and both reflections. Every fixed canvas retains its complete silhouette; the largest measured case support error is 0.000077 source pixels and rigid basis error is 0.00000051. The focused suite and complete standard suite pass, including Vyraketh lifecycle checks registered in the standard runner. The full suite retains its existing legacy-save ambiguity warning and shutdown ObjectDB warning.

The final actual RunScene capture passes all 17 recorded sequences (1,546 native frames). Each of the eight action-result comparisons matches the unchanged engine across all recorded fields. The four Maw approaches and reduced-motion Maw finish at 82/100 player HP, Kindle at 100/100, Crownfire at 92/100, and Cinderfall at 89/100; these totals include the existing surface effects. The largest measured world-space support drift is 0.000247 pixels. All 17 clips fully decode and retain 59.13 seconds of observed timing. `gameplay/videos/gameplay_review.mp4` selects idle, Maw and the three fire families for a short review.

### UI rubric record

The surface is the combat board. The player needs to see what the dragon is doing and where the effect lands, then choose a target, move or Pass. Boss health, turn clock and hand remain persistent; intent targets and action results stay contextual on the board. The integration extends the existing cutout loader, enemy facing helper, footprint geometry, effect feedback and death presentation.

| Affected gate | Result | Evidence and scope |
| --- | --- | --- |
| Immediate comprehension | Pass | Idle, travel, jaw preparation/contact/recovery and three distinct fire cues accompany the existing intent and result UI. |
| Visual hierarchy | Pass | The modest idle bob preserves the existing emphasis on boss health, turn clock, selected cards and consequences. |
| Gameplay visibility | Exception | At the requested unchanged boss scale, a rear-facing dragon can cover an adjacent player body. Tile focus, health and damage overlays remain visible. Keeping the accepted 2×2 boss proportions preserves the requested encounter presentation. |
| Compact, precise copy | Pass | Existing rules text and icon identities remain unchanged. |
| State and consequence | Pass | Native RunScene evidence covers targeted damage, seeded marks, detonation, area fire, reduced motion and death with unchanged result boundaries and engine outcomes. |
| Interaction completeness | Pass | Actual card targeting/activation, player movement, controller Cancel and pointer recovery pass; the complete standard input suites also pass. |
| Visual cohesion | Pass | The accepted front design and matching rear retain the existing palette, portrait, HUD, tiles and feedback components. |
| Accessibility | Pass | Reduced motion uses still cutout art with the same facing and static health, target and result information. |
| Layout resilience | Pass | The complete actor stays inside its fixed canvas in all tested poses; logical HUD bounds and 2×2 board registration remain unchanged at 1920×1080, 100%. |
| Visual proof | Pass | All native pose cycles and relevant RunScene states were inspected, including reflected views, movement, target preview, controller targeting, pointer handoff and dissolve stages. |

Remaining limits: neutral shadows use a static rest silhouette to avoid per-frame GPU readback. Accepted source-art quirks remain. Windows runtime, other resolutions/UI scales, and physical controller hardware are not exercised; typed-array patterns are preserved. Controller targeting/cancel and pointer handoff are exercised through the real RunScene input handlers. This presentation change does not claim a frame-pacing optimization.

## Playable inspection

Use the standard combat fixture at seed 6, room (4,0): this selects the real **The Cinder Crown** boss arena, with Vyraketh's boss metadata and objective. The generic `boss` fixture uses a different dragon's arena. Enemy origin (4,2) and player (4,5) leave the complete 2×2 approach clear; the helper clears the trap at the player's starting tile. The player starts with 100 HP and a small attack/defense/healing hand. The scene is saved before any action. Choose **Continue**, observe idle, then **Pass** through the turn clock to see the selected intent resolve. Select and move the player around the boss to inspect the other facings.

Maw approach and bite:

```sh
cd /Users/borgerding/.codex/worktrees/3345/Labyrinth && python3 tools/inspection_fixture.py --task-id vyraketh-the-cinder-crown-editable-cutout-and-gameplay-animation --run-id vyraketh-maw-inspection --manifest /private/tmp/vyraketh-maw-inspection.json --launch --scenario combat --seed 6 --room-coord 4,0 --summary "Vyraketh: observe idle, then Pass through the turn clock for Cinder Maw" --player-position 4:5 --player-hp 100 --player-max-hp 100 --enemy-types vyraketh --enemy-positions 4:2 --enemy-intents cinder_maw --hand quick_stab,brace,sidestep_slash,bone_dart,patch_up
```

For the low breath followed by marked-tile detonation, use the same command with `--run-id vyraketh-fire-inspection`, `--manifest /private/tmp/vyraketh-fire-inspection.json`, `--enemy-intents kindle_ground`, and a summary describing Kindle Ground and Crownfire. For the separate wing downstroke, use `vyraketh-cinderfall-inspection` and `--enemy-intents cinderfall`. Each command regenerates and independently verifies its pre-action save before launching.

Publication remains pending user inspection and explicit approval of the reviewed commit.
