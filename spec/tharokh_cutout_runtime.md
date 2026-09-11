# Tharokh editable cutout runtime

Current travel cadence, floor registration and room fitting are specified in [Actor presentation](actor_presentation.md); the timings and offsets below describe the original integration.

Generated proof paths cited below are retained in the [external roster evidence archive](enemy_cutout_roster_integration.md#evidence-archive-and-compact-history). Editable source cases remain in this repository.

Tharokh, the Worldspine (`tharokh`) retains the existing earth boss rules: 64 HP,
base initiative 15, 80 embers, a 2×2 footprint and the dedicated boss bar. Its
terrain-denial role, pathing, attack ranges, statuses, rewards and spawn pools
are unchanged. This is presentation work; it changes no balance assumptions,
icon identity or analytics event/result boundary.

## Art and editable anatomy

The authoring case is `experiments/cutouts/tharokh/v01/cutout.json`, initialized
with the maintained `tools/cutout_workflow.py`. It uses the production
Skeleton2D/Polygon2D loader and its own 20-joint dragon graph: body, neck, head,
two wings, two tail joints and four upper/lower/claw limb chains. This is not a
humanoid skeleton or a weapon animation.

`source/front_original.png` is a byte-identical copy of
`assets/art/enemies/tharokh.png`; its registered view is unchanged. Ordered
semantic ownership polygons retain every source pixel and reconstruct the
original RGBA painting exactly before rigging. Chest plates belong to the
body/neck, wing ribs to their wings, limb plates to their limbs and claws to
rigid terminal bones. No front repaint is substituted for this original art.

The built-in image generator supplied a matching rear painting and front/rear
concealed body references. `source/generation_requests.json` retains the actual
prompts, reference roles and dispositions; the untouched outputs, registration
recipe, masks, cropped parts and source digests live beside it. `author.py`
records each source-space joint and ownership polygon and invokes the maintained
`segment` and `skin` commands. `promote.py` copies only the case closure to
`assets/units/tharokh_cutout` and `scripts/tharokh_cutout`.

The rear view is fit once to the 255×255 canvas and keeps that registration for
every part. Its generator supplied alpha 252 over much of the interior. Rear
concealed patches therefore select alpha ≥250; front patches select only alpha
255. Both masks are inset and restricted to proximal limb sockets. These small
patches expose actual generated body paint during motion without broad new
visible surfaces. Some far-side attachment landmarks are concealed by the body;
they are projected articulation guides, not a claim to recovered hidden pixels.

## Motion and presentation

All art stays in 255px registered coordinates inside one persistent 512×512
canvas per actor. The original 1.78 art scale and +14px vertical offset remain.
The logical body, HUD and static shadow use a native baked neutral silhouette;
transparent action padding is applied only when submitting the live texture.
Destination previews reuse the same actor texture. Death freezes that texture
and uses the existing dissolve and logical-body anchor.

Idle is a coordinated 1.2-source-pixel bob over 2.4 seconds. Every bone basis is
constant; all four legs and the floor-resting tail remain fixed. The wings,
head, neck and body move together. There are no idle plate rotations or ripples.
The four-foot crawl advances 47.37 source pixels per 1.12-second cycle, with a
36px stride and 76% support per foot. Four quarter-cycle offsets keep at least
three claws in support during ordinary travel. Feet counter the actual board
displacement; projected leg length can change while perpendicular paint width
and rigid claw bases are preserved.

| Existing intent/action | Motion and existing result |
| --- | --- |
| Worldspine Claw: move_toward → melee | Distance-driven crawl, three supporting feet, near-foreclaw draw-back and forward rake; 15 damage and Sunder remain resolver-owned. Authored claw contact maps to the existing 42% melee boundary. |
| Stonewake: raise_terrain | A deliberate four-foot brace, then release as the existing terrain snapshot becomes visible; three Worldspines with their existing health and destruction surface. |
| Bedrock Aegis: stoneskin → raise_terrain | Existing six Stoneskin status cue, then the same grounded brace/release for its two Worldspines. |
| Faultline: terrain_burst | Load the supporting limbs, lift the near foreclaw and stamp; authored contact maps to the existing 38% area boundary. The existing spire-centered area result, damage, destruction and Rubble remain intact. |

`RunScene` consumes the existing immutable animation-step snapshots. The ground
call displays its before/after snapshot at the brace's release; it does not
rerun an action. Attack damage and terrain losses still use the established
feedback boundary and final step application. Neither Faultline nor Stonewake
is converted to melee.

`scripts/enemy_cutout_facing.gd` chooses player-facing idle using the displayed
state. Doubled tile coordinates preserve the half-tile center of the 2×2 boss.
Active motion uses the shared `attack` descriptor with a Tharokh-specific action
name, so its facing stays locked through contact/recovery. Idle turns only when
player movement completes. The protagonist keeps its camera-facing idle.
Reduced motion uses still rig art in the same selected direction.

## Proof and inspection

The changed surface is the combat board. The player needs to distinguish the
claw attack from terrain creation/release while choosing movement, cards or
Pass. Existing health, intent, target and turn-order hierarchy stays in place;
there are no new controls, copy or icon conversions. Proof targets 1920×1080 at
100% UI scale, pointer/controller targeting and cancel/handoff, reduced motion,
multiple actors, completed-player-movement facing and death.

The current gameplay package is
[`runtime_v1/gameplay`](../experiments/cutouts/tharokh/runtime_v1/gameplay/).
Its real `RunScene` probe drives Pass, card targeting, movement and controller
cancel; it compares each resolved combat state with the unchanged resolver.
All 26 sequences pass: four idle views, all four intents in all four views,
reduced motion, death with a surviving second actor, and four actual two-tile
player paths. Maximum measured world-space support-foot drift during movement
is 0.000153px. Claw damage is 15; Faultline deals 10 and destroys its 5 HP spire;
Stonewake creates three spires and Aegis applies six Stoneskin and two spires at
the fixture's depth. The captured states equal the resolver's player, enemy,
terrain, surface and initiative results.

The native 1920×1080 full-speed reel retains 2,264 source frames over 85.8833
seconds. `video_timeline.json` records the actual sample intervals and each
chapter's encoded duration, accurate within one 60fps frame. Encoding only
repeats or drops captured frames; it synthesizes no poses. The entire reel
decodes successfully. Eighty native PNG keyframes retain preparation, contact,
recovery, reduced motion, death and input states. Source JPEG digests and the
original native-runner result are included.

The native keyframes and complete front/rear/reflected asset cycles were
inspected for attached limbs, coherent rock plates, grounded support, return
to rest, scene bounds and HUD clearance. The required UI rubric ratings are:

| Gate | Result and evidence |
| --- | --- |
| Immediate comprehension | Pass: health, intent, selected card, movement pool and Pass remain identifiable. |
| Visual hierarchy | Pass: the established boss bar and combat decisions keep their hierarchy. |
| Gameplay visibility | Pass: target highlights, damage, terrain creation and Rubble remain legible through the action. |
| Compact, precise copy | Pass: no player-facing rules or controls were rewritten. |
| State and consequence | Pass: preparation, contact, terrain release and resolved health/status changes are distinct. |
| Interaction completeness | Pass: pointer targeting, all four movement paths, controller target/cancel and pointer handoff pass. |
| Visual cohesion | Pass: the preserved front painting and matching rear use existing board scale, HUD and effects. |
| Accessibility | Pass: reduced motion retains the selected still facing and ordinary static consequence cues. |
| Layout resilience | Pass: the required 1920×1080, 100% configuration preserves controls and body/HUD clearance. |
| Visual proof | Pass: fresh native gameplay and complete asset cycles were inspected; provenance and timing are retained. |

The focused Tharokh suite, affected full Godot suite, and 16 Python cutout
workflow tests pass. The production-only cutout PCK boots all five clips and
both 20-joint rigs in the unmodified macOS Godot 4.6.1 export runtime with
`editor=false`, without `experiments` or `tools`. Export payload and unmodified
runtime byte hashes are retained in `runtime_v1/export_payload.json`. This
smoke check covers the production cutout closure, not a full-game export.

The maintained editable-case proof is
[`v01/proof`](../experiments/cutouts/tharokh/v01/proof/): 480 authored samples,
fixed 512px bounds, contact/rigid-body checks and ten pixel-identical saved-scene
reloads across both facings and all five clips. Its 19.9667-second review reel
passes timing and full-decode checks. `verify-render` verifies 1,029 current
inputs and 1,239 outputs. Maximum measured walk support drift is 0.000094px;
idle, claw, brace and Faultline supporting feet remain fixed.

[`runtime_v1/assets`](../experiments/cutouts/tharokh/runtime_v1/assets/) contains
708 native production/case comparisons across rest and every complete clip in
front, rear and their reflections. Every comparison is pixel-identical, and
both shipped neutral silhouettes equal the current native assembly. The 736
retained images also match the native samples used for the complete-cycle
visual inspection; fixed-registration review sheets and their image binding
are in `assets/cycle_qa`.

`runtime_v1/capture_input_sha256.json` binds 1,034 current render, case, probe and
packaging inputs. `runtime_v1/proof_sha256.json` binds the final runtime evidence,
including native captures, timelines and test/export logs. The case has its own
maintained input/output manifests. The only shared workflow addition forwards
an optional GUI-lease wait to the existing serialized native runner; capture
and startup timeouts retain their existing behavior.

The inspection reset uses seed 1 at depth 4, which resolves to the actual earth
boss room, The Worldspine Vault. Two normal 64 HP bosses begin at (3,3) and (5,5),
with Worldspine Claw and Stonewake prepared, and the player at (3,6). Their full
2×2 footprints fit the authored 9×9 room. The player has 120 HP for repeated
inspection. The normal movement pool and all enemy rules still apply.

```sh
cd /Users/borgerding/.codex/worktrees/4f0e/Labyrinth && python3 tools/inspection_fixture.py --task-id tharokh-the-worldspine-editable-cutout-and-gameplay-animation --run-id tharokh-cutout-inspection --launch --scenario combat --seed 1 --room-coord 4,0 --enemy-types tharokh,tharokh --enemy-positions 3:3,5:5 --enemy-intents worldspine_claw,stonewake --player-position 3:6 --player-hp 120 --player-max-hp 120 --hand quick_stab,brace,sidestep_slash,pale_spark,patch_up --summary "Two Tharokhs before claw and ground-call actions; Pass to advance and move around them to inspect facing."
```

Residual platform limits: native proof targets macOS Metal at the required
resolution and scale. It does not certify Windows execution or physical
controller hardware. Shadows intentionally use the static neutral silhouette.
The original portrait and legacy source sheets remain retained reference art.
Headless suite logs retain the existing macOS certificate-query message and
legacy-save/teardown warnings; the native gameplay probe reports no errors.
