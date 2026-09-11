# Zekarion cutout in gameplay

Current travel cadence, floor registration and room fitting are specified in [Actor presentation](actor_presentation.md); the timings and offsets below describe the original integration.

Generated proof paths cited below are retained in the [external roster evidence archive](enemy_cutout_roster_integration.md#evidence-archive-and-compact-history). Editable source cases remain in this repository.

## Design and scope

The combat board makes Zekarion's movement, claw contact, maw release, lightning charge and wisp call readable while the player continues choosing cards, movement and Pass through the existing pointer, keyboard and controller paths. The boss bar, intent and footprint keep their existing geometry; a padded canvas carries the dragon's pose.

This is presentation of the existing 2×2 lightning boss. The sole enemy-data change is `art_path`: 60 HP, initiative 14, 80 embers, shock immunity, Storm Claw's 15 damage/electrified surface, Tempest Breath's 9 damage/chain 2/conducted bonus, Skybreak's six 9-damage strikes, and Call Wisps' two rewardless summoned lightning wisps remain unchanged. Encounter and terrain routing remain unchanged. `runtime_v1/data_invariants.json` records the exact enemy-data delta against the task's base, `01c7dccbc931ae7dddf3eb8f797fb3d1d33def3e`.

## Authoring and source provenance

The fresh editable case is `experiments/cutouts/zekarion/v01`; it is not a historical humanoid experiment. Its source folder retains the byte-identical accepted front at `source/front_original.png` and `source/front_registered.png`. The rear and concealed scale material were generated with the built-in image generator. Each request JSON records the actual prompt, reference role, output and selection/rejection reason:

- The first rear painting retained a painted checkerboard, so it was rejected as runtime input. A second image edit removed that background and supplied real RGBA; the untouched output is `source/rear_alpha_generated.png`.
- The attempted complete concealed underbody redesigned the source and produced unsuitable sockets. It is retained as rejected evidence; no pixels from it ship.
- `source/concealed_scales_generated.png` supplies only small, explicitly masked internal joint caps behind the unchanged visible paint. Each cap is clipped to fully opaque registered source pixels at rest. It is not a generated replacement torso.

`recipes/build_case.py` records registration, anatomical ownership, joint placement, layers, small concealed caps, and calls the maintained segmentation and skin commands. The rear receives one uniform 243×243 registration at offset (6,3) inside the logical 255×255 canvas; landmarks receive that same transform. Both views have zero unassigned painted pixels. No residual mask acts as a catch-all torso or head.

Each view has 22 bones: root/torso, neck/head/jaw, two wings, paired upper/lower forelegs and claws, paired thighs/shins/feet, and a three-part tail. Eight weighted meshes blend limb/neck/wing/tail roots; claws, feet, head and jaw remain rigid terminal paint. Proximal skin bands blend into the torso/root, and distal bands reach the rigid claw/foot before the visible seam. Small head/neck rotations are coordinated rather than independently bending the head off its collar.

`recipes/promote_runtime.py --baked-rest <native-asset-probe-folder>` copies the case closure into `assets/units/zekarion_cutout` and `scripts/zekarion_cutout`. Production JSON adds explicit maw and claw-strike landmarks. Neutral HUD/shadow silhouettes are freshly baked native assembly images. Their alpha matches the registered source; their color channels have the native viewport's premultiplied representation. The original straight-alpha front source remains untouched.

## Motion and action boundaries

All source coordinates use the game's 2:1 floor projection. The logical body is 255×255 within a 512×512 texture, at offset (128,128). Existing `art_scale: 1.92`, `art_offset_y: 18`, 2×2 footprint, draw ordering, intent compass, turn-clock portrait and boss bar remain in place. Bounds never fit or recenter individual poses.

| Clip | Duration | Pose and playback contract |
| --- | --- | --- |
| Idle | 1.80 s | One 1.2px coordinated torso/neck/head/wing bob; legs, feet, tail and every rigid bone basis remain fixed. No chain of small independent idle rotations. |
| Walk | 0.96 s | Diagonal support pairs, 44px stride, 64% stance and 7px swing lift. Distance drives both board traversal and cycle phase; source travel per cycle is 68.75px. |
| Storm Claw | 0.90 s | Lift and draw back the near foreclaw, sweep through contact, recover. The slash starts with the sweep; normalized damage boundary stays 0.42. |
| Tempest Breath | 1.30 s | Brace, coil/aim the neck and open the maw. Lightning launches from the posed maw at 4/30 effect progress and reaches the existing result boundary at 8/30. |
| Skybreak | 1.10 s | Raise head and wings while four supports remain grounded. Existing ground telegraphs precede the vertical bolts at the 0.38 result boundary. |
| Call Wisps | 1.10 s | A wider wing call and open jaw; reveal the already-resolved wisps at 0.50 progress. |

The case's `phase_curve` mappings match the renderer's playback mappings; pose phase is distinct from elapsed action time. The animation durations above are newly authored; the existing normalized effect/result boundaries and atomic combat/analytics resolution remain unchanged. Presentation never applies extra damage, status, surfaces or summons.

The only combat-engine addition is `spawned_enemies` on the existing summon animation step. `scripts/zekarion_cutout/action.gd` reveals those resolved snapshots with ID deduplication in the display state only. It never calls the summoning resolver. The analytics specification documents this additive presentation payload; no new event or saved-state field is introduced.

Each living actor owns one persistent SubViewport texture and two loaded rigs. All retained board layers, destination echoes, reduced-motion stills and death dissolves share that actor's texture. Death freezes the current facing/pose before the existing dissolve; removal releases only that actor. Cached HUD/shadow geometry uses the neutral bake and does not read back the moving viewport each frame.

Idle uses `scripts/enemy_cutout_facing.gd`, with doubled coordinates to represent the 2×2 footprint center exactly. Actions keep their travel/target heading. Once movement completes, including player-only movement, idle selects the closest supported view toward the player. Reduced motion has the same facing policy. The protagonist keeps its unmirrored camera-facing idle.

## Verification

The focused suite covers actor independence, persistent texture/geometry, four facings, player-facing recovery, reduced motion, hidden actors, death, rigid bob motion, four action families, mouth release and deduplicated summon snapshots. The full runtime suite passes, including the updated legacy sprite-sheet assertions and existing combat, terrain, chain, reward and analytics checks. Both logs are in `experiments/cutouts/zekarion/runtime_v1`.

The production-only PCK loads both 22-bone rigs and all six clips using the unmodified Godot 4.6.1 macOS export runtime (`editor=false`). Its package has no experiment, authoring-tool, legacy-sprite or imported texture-cache dependency. Build and export-runtime logs are retained alongside the focused/full-suite logs.

The maintained native proof in `v01/proof_v1` passes `verify-render`: 480 frames, 1,038 capture inputs, 1,279 outputs, and 12 pixel-identical editable-scene reloads. Front and rear idle/walk loops span two cycles; each action includes preparation, release/contact and recovery. Every unique cycle frame was inspected at fixed registration for joints, outline integrity and clipping. The maximum measured support drift is 0.000103 source pixels and rigid-basis error is 0.00000136. The inspected action bounds fit the fixed 512 canvas without per-pose recentering.

`runtime_v2/asset` separately passes all 370 native production-versus-case pose comparisons and both rest-bake comparisons. Its input/output hashes remain current. `runtime_v2/README.md` gives repeatable capture and timing-preserving encoding commands.

The final native RunScene proof in `runtime_v2/gameplay` passes all 26 sequences: four idle views, four intents in each view, reduced motion, death, and four real player repositionings. It checks exact final resolver state, display-result boundaries, two rewardless wisps, persistent textures, input recovery, controller Cancel/pointer handoff and unchanged protagonist idle. The maximum observed world-space support drift is 0.000153px. All 80 native PNGs and the complete sample/state manifest are retained, with 1,039 current capture-input hashes. All four facings' action keyframes, movement, recovery, targeting, reduced-motion and dissolve images were inspected.

The 2,251 recorded samples encode to 26 clips and an 85.7333s review reel against 85.7374s of recorded intervals. Each clip differs by less than 0.008324s, and the complete reel decodes successfully. Encoding repeats native samples at 60fps without generated poses or time scaling. Intermediate JPEGs remain in the isolated native capture directory, with their digests and location in `raw_capture_sha256.json`; the repository retains the videos and PNGs instead of duplicating 1.4 GB of intermediate frames.

| UI review area | Evidence and result |
| --- | --- |
| Visual hierarchy and registration | PASS: 1920×1080/100% native board captures preserve the 2×2 body registration, boss bar and portrait. Action poses remain inside the padded canvas. |
| Action feedback and precise rules | PASS: claw, maw lightning, Skybreak and wisp call have distinct poses; actual display results match the resolver and original normalized result boundaries. |
| Input and recovery | PASS: real Pass, card targeting, controller Cancel, pointer handoff and four player movements complete with input restored and idle facing updated after movement. |
| Motion and continuity | PASS: fixed-basis idle bob, distance-driven planted supports, independent actors, reduced-motion stills, destination texture reuse and frozen-pose death dissolve. |

The committed branch still requires separate exact-HEAD peer signoff and a verified pre-action boss fixture before user handoff.

The remaining implementation choice is a cached neutral shadow, rather than a shadow animated from every limb pose. Native proof targets macOS Metal at 1920×1080 and 100% UI scale. Windows execution and device-specific performance measurements are not claimed; new typed-array assignments use the portable typed-helper/temporary pattern.
