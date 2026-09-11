# Cinder Droplet cutout runtime

Current travel cadence, floor registration and room fitting are specified in [Actor presentation](actor_presentation.md); the timings and offsets below describe the original integration.

Generated proof paths cited below are retained in the [external roster evidence archive](enemy_cutout_roster_integration.md#evidence-archive-and-compact-history). Editable source cases remain in this repository.

Cinder Droplet (`cinder_droplet`) uses the editable [v01 case](../experiments/cutouts/cinder_droplet/v01/cutout.json) and production-owned [rig](../scripts/cinder_droplet_cutout/rig.gd), [motion](../scripts/cinder_droplet_cutout/motion.gd), [renderer](../scripts/cinder_droplet_cutout/renderer.gd), and [paint/layout closure](../assets/units/cinder_droplet_cutout/). The source is the approved local-master front painting. Its scale remains 0.56 beside Cinder Ooze's 0.82.

## Art, anatomy and registration

The original front PNG is retained byte-for-byte in `v01/source/front_original.png`; the production original is unchanged. The generated rear matches the cap, spike, cooled crust, orange fissures and low tendril silhouette. `source/generation_requests.json` retains the actual prompts, reference roles, output hashes and disposition. The rear generation returned an opaque checker background; a second alpha attempt was rejected because it also changed the proportions. The chosen rear uses the explicit neutral-background matte and uniform registration in `register_sources.py`. No generated front redraw is selected. Generated concealed belly material is retained as an unused authoring experiment.

Each view has root, rigid core, and five base/bend/tip chains: 17 bones, six semantic paint owners and six weighted meshes. The core owns the complete cap and facial crust. The five owners follow actual tendrils or small connected tendril bundles; no humanoid skeleton or weapon pose is transplanted. Original paint is copied by ownership, without frame-dependent repair.

The connected molten web uses the same source-space weight field on a globally aligned 2px mesh grid across every owner. Independent mesh fields exposed holes and dangling torso strips in the first draft; the shared field fixes their adjoining deformation. The core is rigid above the lower flesh transition. Each 6px toe contact patch is weighted exclusively to its rigid terminal, blending back into the common field over 4px. Projected segments preserve their transverse basis while their soft lengths change. Recipes and snapshots are retained under `v01/recipes`; the executable entry recipes are one directory above the case.

The source remains 255×255 at offset `(128,128)` in a fixed 512×512 action canvas. The logical body supplies tile, HP and obstruction geometry; padding is applied only to texture submission, including death and preview echoes. Native neutral bakes provide cached HUD/shadow geometry. Shadow shape is static; live limb shadows are not part of this change.

## Motion and combat routing

Idle is a 1.5-second coordinated 1.2px vertical settle. There are no idle rotations, scales or skews. The cap and face move as one rigid core, soft lower tendrils counter the bob, and the painted terminal contacts remain fixed.

Forward scuttle uses a 48px stride, 68% stance, five staggered contact phases, and a 0.34-second cycle. A cycle travels 70.588 source pixels along the 2:1 isometric lane. At least three supports remain planted; the others lift 5px for recovery. Runtime phase follows resolved path distance and actual body scale, including multiple-tile movement. Hiss Back runs this supported gait backward, facing opposite the resolved escape direction. Idle then faces the player. The case's `retreat` animation is an in-place reverse-gait authoring study; actual backward root travel is verified in RunScene.

Spatter is a 0.60-second low two-tendril lash. Leading tendrils draw inward, reach 43/56 source pixels into contact, and recover while three supports remain fixed. The authored 0.52 contact pose maps to the existing 0.42 melee feedback boundary. A small low fire impact begins at that boundary. Hiss Back retains the existing block feedback and an idle guard hold. There are no ranged, area or casting attacks in this enemy's live definition.

RunScene adds namespaced motion descriptors and timing only for this enemy. CombatBoardView retains one viewport texture and two loaded views per actor, shares those renderers with retained board layers, and releases each independently after its death dissolve. `enemy_cutout_facing.gd` selects four supported directions toward the player after completed actions or player movement. Hidden/dead actors pause; death keeps its frozen facing. Reduced motion uses the new neutral art and the same facing policy. The protagonist's camera-facing idle and the Warden registration remain unchanged. The dedicated Cinder Droplet turn-clock portrait remains registered.

HP, initiative, AI, intent weights, ranges, damage, surfaces, status timing, rewards, spawn pools, footprints and analytics are unchanged. Cinder Ooze still creates two summoned Droplets on death; killing them grants neither embers nor an ordinary enemy kill refund. All three export presets include the new production JSON; raw PNGs use the existing `keep` import/AssetLoader path.

## Verification and inspection

The runtime capture contains 22 sequences and 1,832 native samples, with maximum measured world support drift of 0.000137px. The full gameplay reel is 69.67 seconds; the four-clip preview is 16.32 seconds. Native asset bounds span `(129,204)` through `(382,367)` across all 584 poses, leaving ample fixed-canvas clearance.

The maintained case capture contains 658 frames, with two idle cycles and three forward/reverse gait cycles per view. All eight saved-scene reload comparisons are pixel-identical. Current `verify-render` passes for 980 inputs and 1,285 outputs; its 11.27-second reel passes full decode and authored timing checks. `runtime_v1/case_review.json` records the native study inspection and contact metrics.

The current evidence is retained in [runtime_v1](../experiments/cutouts/cinder_droplet/runtime_v1/) and the case's `proof` directory. The native proof uses Godot 4.6.1 Metal at 1920×1080, 100% UI scale, with a fixed 512×512 pose canvas. Shared GUI captures use `visual_probe_runner.py` and its shared lease; other Godot runs use `godot_task_runner.py`.

- `validation.json`: structural validation of both views and the selected closure.
- `v01/proof`: full native study, fixed-canvas bounds, grounded forward travel, editable Skeleton2D/mesh/AnimationPlayer scenes and pixel-identical scene reload comparisons. `cutout_workflow.py verify-render` checks current input and output hashes.
- `assets/comparison.json`: all 584 native production/case poses across front, rear and both reflections, including idle, walk, retreat and Spatter. It compares the shipped neutral bakes and the assembled neutral front against the original front rendered through the same native pipeline.
- `gameplay/manifest.json`: real RunScene Pass actions, four Spatter directions, a two-tile approach, four corridor-constrained Hiss Back retreats, both reduced-motion actions, pointer targeting, controller Cancel/pointer handoff, four completed player repositioning paths, independent actors, death, actual Ooze split and summoned-child death. Engine-computed outcomes and observed outcomes are retained together. Dull Bolt is used for the exact child kill; retired Bone Dart now resolves to Pale Spark and is not a valid four-damage lethal fixture.
- `gameplay/cinder_droplet_gameplay_full_speed.mp4` and `video_timeline.json`: native frames repeated at recorded wall-clock intervals, with no synthesized poses or speed changes. The final frame of each captured clip holds 1/30 second; cumulative rounding is at most one 60fps frame per clip.
- `focused_suite.log` and `full_suite.log`: facing, routing, texture lifecycle, preview/death registration, two actors, reduced motion, unchanged definitions, full forward/backward contact cycles and rigid painted contact patches, plus the complete integration suite. The legacy idle-sheet roster excludes Cinder Droplet because its focused suite verifies the replacement rig.
- `export_build.log`, `export_runtime.log`, `export_binary.json`: a production-only PCK runs from an empty directory on the unmodified non-editor export template. It contains no experiments, tools, loose asset tree or imported texture cache.
- `capture_input_sha256.json`, `proof_sha256.json`, `preservation_audit.json`: frozen inputs, retained evidence and unchanged source/rule/art audit.

The affected UI rubric rows are immediate comprehension, hierarchy, gameplay visibility, input parity, feedback and state clarity, motion/accessibility, and visual consistency. Native frames must show the small Droplet and its contact without obscuring HP, targets or cards; the existing HUD, copy and controls are preserved. No new concept/icon identity is introduced. Numeric support assertions complement inspection of the complete native pose cycles and actual board frames. `asset_review/inspection.json` records every pose cycle; `gameplay/inspection.json` records the affected rubric rows and the offscreen cursor/crowded-layout limits of the test harness. Actual contact JPEGs are separately selected by the existing feedback boundary and visible HP change; `attack_052.png` is the nearest sampled authored pose, which may precede contact by one sample.

After exact-HEAD independent peer signoff, generate and independently verify a pre-action combat fixture with Spatter and Hiss Back actors. The handoff command must start by changing to the task worktree and regenerate the fixture before launch. Publication requires separate explicit user approval of the reviewed HEAD.
