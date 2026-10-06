# Protagonist cutout in gameplay

## Design statement

The player must read their position, facing, travel and melee contact on the existing combat board. Promote the accepted pass-seven front/rear paint unchanged, reflect it into all four board directions, and keep the same cutout visible through every action and idle state. Give breathing a subtle planted-foot bob, keep walking brisk, and concentrate the sword cut around damage contact. Preserve board registration, HUD clearance, target selection, input paths, and the existing action-result/event boundaries. Reduced motion retains the new artwork in a still neutral pose and returns to the same front default when the action ends.

The primary proof is actual 1920×1080 gameplay at 100% UI scale: idle, four directions of movement/melee, other action transitions, equipment, reduced motion and save/resume. The full Godot suite and focused animation tests must pass, followed by independent review and a playable combat Continue fixture. Publication requires separate user approval.

For new character cutouts and animation/equipment variants, use [the maintained cutout workflow](cutout_workflow.md) and `$create-labyrinth-cutout`. The experimental recipes remain historical references.

## Ownership and rendering

`assets/units/protagonist_cutout` and `scripts/protagonist_cutout` own the production rig, motion and accepted paint. The experiment remains a frozen inspection reference. Layout JSON is included explicitly in every export preset; painted PNGs use the existing `keep` import convention and load through AssetLoader in source and exported builds. Experiment/reference/proof assets are excluded from shipped packages.

The board owns one transparent viewport and two persistent facing rigs. Only the selected rig draws. The viewport texture updates without invalidating retained board layers for breathing. Body/HUD/obstruction geometry uses the fixed 255-pixel source registration; only texture submission expands to the padded 512-pixel action canvas. Static cutout rest art supplies cached shadows and HUD silhouette geometry, so animation never reads a live viewport back from the GPU or accumulates per-frame silhouette caches.

Motion descriptors are presentation-only. No resolver, card balance, initiative, save format, or analytics event payload changes. `player_moved` and `card_played` keep their existing single resolved-action boundaries described in analytics.md.

The walking gait runs at a 0.30-second cycle with 48 source-pixel strides and 80 source pixels of travel per cycle. Relative to pass eight, cadence is 20% lower, travel per cycle is 60% greater, and nominal ground speed is 28% greater. Root speed follows this projected travel, so a typical full-size tile takes 31 frames (about 0.52 seconds), with support feet held against the ground. Single-target melee takes 0.50 seconds overall; its cut occupies 30 milliseconds around the existing 42% contact threshold. Self-centered AoE weapon attacks use the existing melee sound classification and play the cutout swing while preserving their 0.24-second effect and 38% contact boundary. Targeted AoE remains a casting action. Other actors keep their existing presentation timing.

The old whole-sprite melee lunge is removed: the articulated torso drive and planted feet supply the action on the protagonist’s real tile. Slash artwork is withheld during anticipation and peaks with the cut; idle resumes as soon as the recovery ends even while damage text is still finishing. Cached equipment views follow later reduced-motion changes. Existing death squash and Blink echo scaling transform the logical body rectangle before padding is added, preserving their floor registration.

## Visible equipment

`assets/units/protagonist_cutout/gear_visuals.json` owns the five slots' visual
defaults, weapon motion/hand count, per-facing part replacements and bone
attachments in the unchanged 255-pixel source registration. Armor owns only the
torso, sleeves and hips; boots own the feet and shins (including same-size
skinned rear shin replacements). Mesh textures must retain their base
crop size. Cloak, mantle, scarf, head, hands and trousers keep their base paint.
The loader validates and caches the JSON once, reports broken entries, and falls
back to the slot default for absent or invalid item IDs. Missing/empty weapon,
armor and boots use defaults; missing/empty offhand and trinket draw nothing.
All registered weapons are one-handed. Shields and held offhands stay visible in
every clip, reaction and reduced-motion still; there is no clip-hiding or
two-handed offhand-hiding path. `is_two_handed` remains a metadata API for later.
The temporary `crossbow_r` bone is under `hand_r`, registered at the main weapon
joint. Generic `shoot` hides `weapon_r`, exactly while the crossbow is visible
(phase > 0.01 and < 0.94). Equipped bow/repeater shooting variants keep
`weapon_r` visible and the generic crossbow hidden; casting still uses the left hand.

`gear_visuals.gd` exposes static `resolve`, `signature`, `weapon_motion`, `ranged_motion`,
`is_two_handed`, `offhand_kind` and `ops_for_facing` (replace/attach/weapon_grip).
`rig.gd.apply_gear({})` restores original textures and rigid positions and removes
all gear attachments. This layer is opt-in for the protagonist; enemy callers
keep their original loading and pose paths. The renderer exposes `set_gear`,
`weapon_motion`, `offhand_kind` and `rest_texture`; identical signatures do no work.
Snapshots include `gear` and `offhand_visible`. Board, illusions, previews and the
Character figure receive the run's gear without changing action ownership.

`rest_texture` uses an unmirrored front neutral 255×255 bake, cached across all
renderers by resolved signature. A dedicated canvas makes one GPU readback per
new signature; its retained CPU pixels also supply shadow/HUD extraction without
reading back the uploaded ImageTexture. The live action viewport is never read
per frame. While a bake is
pending (or under the dummy renderer), the bare static rest PNG is the fallback.
The default loadout instead uses `front_default_gear_rest.png`, baked through the
real renderer and covered by the precomputed shadow cache. Other loadouts use the
existing exact silhouette extraction once when their bake arrives. Bare layout
`rest_source` files and digests remain the gearless baseline.

An item equipped outside its native slot (Open Arsenal's wild trinket) draws
nothing rather than a misleading default: `run_scene` filters the run's loadout
through `scripts/visual_equipment.gd` (cached per loadout) before it reaches the
board, the Character figure or the melee effect. The cutout runtime itself stays
independent of the rules/data layer, as the production-only export smoke check
requires.

### Weapon and shield motion

The resolved weapon's `motion` picks the melee clip: `sword` keeps the accepted
`attack` cut and its phase remap; `heavy` plays `attack_heavy` (43 frames,
0.72 s), a one-handed gather, an apex raised over the weapon-side shoulder so
the hammer head stays visible beside the hair, a four-frame slam over the top and an impact hold;
`stab` plays `attack_stab` (24 frames, 0.40 s), a cock at the hip, then a
step-in lunge (leading foot 8 source px and root 10 px along the board diagonal)
with the trailing foot planted. Heavy/stab frame counts come from `clip_specs()`
(the sword keeps the renderer's `MELEE_FRAMES`);
contact stays at effect progress 0.42 for every melee archetype and self-centred sweeps keep
their 0.24 s / 0.38 boundary by retiming the archetype pose. Resolver results,
sounds and analytics do not change. Only the right arm holds the maul; the left
forearm braces at -0.12 rad (front, mirrored rear) at contact and recovers by
0.80. The approved body/direction keys stay intact. Front wrist targets are
(106,118) at gather, (104,78) at apex with the maul pointing (-0.35,-0.94),
(96,134) at contact/hold and (94,130) at lift. Rear targets are (145,114) at
gather, (150,80) at apex pointing (0.60,-0.80), (155,130) at contact/hold and
(157,126) at lift. The rear apex is deliberately lower than a mirror of the
front so the hammer head stays under the board HP bar. Owner rule: a
right-handed overhead raise goes over the weapon-side shoulder (screen-left in
front, screen-right in rear) and the downstroke passes through that side; tests
require the hammer head to clear the posed hair by at least 8 source px at the
apex. No reach corrections are needed. The updated
registry `weapon_grip` preserves the painted palm/pommel registration through
a per-rig layout copy, without mutating the shared `RigData` dictionary.

`stab` replaces the slash arc with a thrust streak at the target (52 px behind
to 16 px past contact, a 7-px warm glow under a 3-px core, plus a short contact
spark); the harrier keeps its original thin streak. A `block` reaction plays
`block_shield` (the shield rises in front of the chest, the sword stays down)
only when a shield is drawn, including the maul loadout; held or empty offhands
keep the weapon-guard `block`.
Gear attachments follow their bone's position and rotation but never its scale
or skew, so foreshortened rear casting/shooting cannot stretch a shield; the
rig's mirroring still applies. Reduced motion keeps the neutral still with gear.

The full-pass poses live in `full_gear_motion.gd` and reuse the existing sampler's painted-length IK. `thrust` selects `attack_thrust` (34 frames, 0.56 s):
- lower the pole from its steep carry (below) to the attack line by .20;
- cock the hip-height wrist 8 source px back by .30;
- drive it 26 px forward by .42 and hold through .56;
- recover through the lowered pose to the carry by 1.0.

The pole stays along the front/rear stab line from .20 through .62. It shares the stab's leading-foot step, 10 px root lunge, planted trailing foot and minimum pelvis fit, with a −0.10 rad front offhand brace at contact (mirrored rear). Its contact effect is the stab streak.

`lash` selects `attack_lash` (29 frames, 0.48 s): gather the wrist 20px above
and 6px behind the shoulder, point the whip up over the weapon-side shoulder,
snap along the attack line at shoulder height at .42, follow through low and
recover by .90. `melee_lash_fx.gd` draws a hand-to-target quadratic crack bowed
18 screen px upward, a 3px warm-white core under a 6px teal glow from .36 to
.62 and a small fading burst at .42. Reduced motion omits both new trails.

`bow` and `repeater` keep the sword cut and phase remap for melee bashes, and keep `cast` for magic. Physical shots are one-armed (see `protagonist_ranged_animations.md`). The new clips keep the offhand, rigid paint and planted feet, and existing clips are unchanged. The gameplay effect carries both visual motion values without changing resolver, sound, analytics or save ownership.

### Carry and draw order

**Steep carry.** Poles (`thrust`) and the bow rest in the owner's steep outward carry:
- through the fist, head up past the near shoulder, butt down by the foot;
- never crossing the body;
- front axis (−0.30, −0.95), rear (0.30, −0.95), read from the weapon's `weapon_grip` landmarks.

`gear_carry.gd` adds per-rig `weapon_carry` metadata for these two motions only.
- In rest, idle, walk, block, block_shield, hit and death, the fist turns toward the landmark axis through the existing 15/85 grip split: the glove takes 15% of the angle from the sword's rest direction and the weapon the rest.
- `attack_thrust` fades the carry out and back in.
- Sword, heavy and stab poses are unchanged; the carry suite compares 1,320 poses per facing.

**Rear draw order.** In the rear facing, the main weapon belongs to the far arm and draws behind the whole body at z 5. This covers every registered weapon (an optional `z_index` on a `weapon_r` replacement), the default sword and the generic crossbow in `rear.json`. `apply_gear({})` restores the base depth. The front facing keeps z 66 under the fist (67).

Proof:
- Suites: `tests/suites/protagonist_gear_suite.gd`, `protagonist_gear_motion_suite.gd`, `protagonist_full_gear_motion_suite.gd`, `protagonist_gear_carry_suite.gd`, `tests/protagonist_ranged_test.gd`, `tests/cutout_rig_data_test.gd`, `tests/protagonist_gear_motion_gameplay_test.gd` and `tests/test_gear_visual_assets.py`.
- Real-renderer probes: `tests/protagonist_gear_probe.gd` and `tests/protagonist_gear_motion_probe.gd`.
- Design and review captures: `spec/design/visible_gear_slice/` (`review/round2_*.png`, `review/full_*.png`).
- Full-pass native proof (r15): the gear probe (49 images, Metal, with `--write-default-rest`, which produced no file change) and the motion probe (236 images: all archetypes, the carry front and rear, and the one-arm bow and repeater front, rear and mirrored). Both PASS at 1920×1080 and were inspected by the design owner.

Grip and side carry (unit 6, owner-approved):
- **Glove and grip:** the glove (`hand_r`) draws at z 65, a grip piece of the weapon at 66 and the glove's lit knuckles (`hand_r_fingers.png`) at 67, so the shaft crosses the palm under the fingers. Both overlays derive from committed art through `tools/process_gear_visual_assets.py`.
- **Front:** a carried weapon (rest, idle, walk, hit, death, cast, block_shield) draws at z 8, behind the near leg and foot, so a pole's butt tucks behind the boot; the grip piece keeps the handle in the fist. Use clips (every attack, the weapon guard `block`, every shot) draw it at 66.
- **Rear:** unchanged (z 5; z 66 during a bow or repeater shot).
- **Code and proof:** `gear_layers.gd` owns the policy. Native proof r16: gear probe 49 images, motion probe 256.

Offhand layering:
- **Front shields** draw at z 72 (over the mantle at 70, under the scarf at 75 and head at 80), so the shield's top sits in front of the cloak.
- **Rear offhands** draw at z 6, below the far arm (7), so the whole body occludes them and only the rim shows past the silhouette.
- **Parrying dagger (front):** z 50, over the sleeve. Its texture has the fist's rest silhouette cut out (`occluded_by: hand_l`, applied at derivation), so the fist reads as gripping it. Both ride `hand_l`, which stays rigid, so the hole stays aligned in every pose.
- **Grapple hook and sunken anchor (front):** hang from the fist at z 48.
- `hands: 2` currently has no runtime effect: every weapon is one-handed and the offhand is always on.

Pixel density and derivation: `tools/process_gear_visual_assets.py` takes its output paths from the registry and its native sizes from `spec/assets/visible_gear_slice/native_sizes.json`. Whole items use `item|facing`; a piece that differs from its rig part uses `item|facing|part`, such as robe-style hips at mid-thigh length. Other pieces take the bare rig part's own size, so sleeves and rear shins always match their meshes. Every texture is consolidated to the hero's density (`consolidate`: posterise to 24 colours, 3×3 mode filter, orphan cleanup), and `occluded_by` cuts a covering rig part out. The output depends on the Pillow and numpy versions; `--check` and `tests/test_gear_visual_assets.py` catch drift.

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

## Refinement pass nine — design statement

Idle is the protagonist’s camera-facing home pose: every action may face its target, then returns to unmirrored front idle. Restore the earlier short, coordinated body bob with planted soles and delayed sword-hand motion, replacing the slow chain of tiny rotations. Longer steps should increase travel per cycle while reducing the current shuffle cadence; keep support-foot travel tied to board movement. Repair the rear lower-leg bend/paint transition, unify the near front boot’s outline, shading and sole width with its mate, and give the rear cloak a single visible drape without a competing chest-attached scrap. Preserve the accepted swing poses/contact timing, precise board/HUD registration, continuous new artwork and existing inputs/outcomes.

Proof targets remain the real 1920×1080/100% gameplay board and equipment view: front idle bob, four action directions returning to front, full-speed stride comparison and detailed rear leg/boot/cloak phases. Reduced motion uses the same front default without bobbing. Reusable-workflow operationalization is the next user-requested stage, after this pass is inspected; death animation replacement remains deferred.


## Refinement pass nine — implementation and verified proof

The renderer resets every idle submission, including completed melee recovery, to unmirrored front. The coordinated two-source-pixel bob takes 0.84 seconds, with planted rigid legs and a slightly delayed sword hand. The longer gait retains the existing torso movement amplitude and support fraction, reaches the authored ankle targets, and cancels root travel beneath each support foot. All 33 sampled attack poses in each facing equal the frozen pass-eight poses exactly; attack timing/contact code is unchanged.

Both rear legs now use two-pixel columns and one-pixel rows across the existing thigh, knee-cover and shin paint, sharing smooth thigh/shin/foot weights. Original boot geometry remains rigid. The rear cloak's independent mesh covers both shoulders: its far edge widens 70%, near edge 20%, and the top rises three pixels, tapering to the unchanged tails by source y118. Underlying shoulder coverage is retained, as the user requested. The front near boot uses a generated refinement with heavier outline, darker underside and broader sole while retaining the approved toe direction and occupied cuff. New rest renders keep cached HUD/shadow silhouettes aligned with this paint.

The bounded `experiments/protagonist_2d/refine_pass9_meshes.py` producer records the rear-mesh recipe against the frozen pass-eight layout. `pass9_bake_rest_probe.gd` writes the two assembled rest PNGs into its isolated `user://probes/cutout_rest_bake`; copy them into the corresponding production front/rear directories, retain their `keep` imports, and update the layout `rest_source`/SHA-256 fields. `pass9_pose_probe.gd` reproduces the enlarged comparisons and attack regression check. These preserve this pass's inputs; broader workflow operationalization remains deferred until user inspection. Boot source, generation request and registration are retained in `references/pass9/front_boot_provenance.json` beside the original generated RGBA.

Fresh evidence is in `experiments/protagonist_2d/renders/pass9/`:

- `gameplay/`: 50 native 1920×1080 PNGs, five mid-step JPEGs, 22 real gameplay clips and 887 recorded frame samples. Every sampled idle is front/unmirrored; the action samples face the correct board direction. The two-tile walk reaches its destination and spends exactly two movement. Existing melee damage, AoE, Blink, card movement, reduced motion, equipment, controller targeting/cancel, save/resume and enemy-phase checks all pass.
- `gameplay/movement_melee_idle_full_speed.mp4`: 15.75 seconds covering idle, all four movement/melee directions, two-tile travel and Whirlwind Slash. `gameplay_full_speed.mp4`: 33.78 seconds for all clips. The 704×512 closeup uses the same source/timebase. All three decode without errors. `video_timeline.json` retains the actual wall-clock frame durations; no time stretching is used.
- `poses/`: 40 real-renderer 1920×1080 comparisons (8 idle, 24 walking, 8 attack), plus labeled crops of all 24 front/rear leg phases for inspection. Detailed body/leg/boot/shoulder phases and native board/equipment images were visually inspected. These enlarged panels emphasize the body; the outer weapon tips can extend beyond the panel during the widest swing, whose complete rendering is verified on the gameplay board.
- Focused suite and full suite **PASS**. The full suite retains the known CanvasItem, dummy-texture, ObjectDB/resource shutdown warnings. Sandboxed headless runs also emit the host certificate lookup warning. Native probes have no script failures.
- Production-only PCK build and unmodified macOS 4.6.1 export-runtime load **PASS (editor=false)**, including the added paint and weighted meshes without experiment sources. The runtime stdout is retained in `gameplay/export_runtime.log`.
- `gameplay/capture_input_sha256.json` binds 114 runtime/art/test/producer inputs to the final capture. Separate `proof_sha256.json` files bind the retained gameplay and pose evidence. Both assembled 255×255 rest renders passed the native probe collector.

Affected UI rubric gates remain **Pass** at 1920×1080 and 100% UI scale: immediate comprehension, hierarchy, gameplay visibility, state/consequence, input completeness, cohesion, reduced motion, layout resilience and native proof. Target rings, HP, cards and the grounded body retain their established layout. There are no rules, copy, outcome, analytics or icon-identity changes. Static neutral shadows, untested Windows/physical-controller hardware, and the deferred death redesign remain the limits. Independent exact-HEAD review and a freshly verified pre-action combat fixture are required before handoff; publication remains pending explicit user approval.

## Publication integration

The accepted checkpoint was integrated with upstream performance work at `685c3dde` while preserving cutout initialization and staged asset reuse. [Fresh publication evidence](../experiments/cutouts/workflow_validation/publication/README.md) covers staged startup identity, native Continue, gameplay and the full test suite.

## Offhand ranged actions

The integrated straight-arm casting and temporary crossbow clips, their source sockets, timing, art provenance, and proof contract are documented in [protagonist_ranged_animations.md](protagonist_ranged_animations.md). The 21 accepted joints gain one independent offhand weapon attachment; existing rest paint and idle/walk/sword poses are protected by differential tests.

## Illusion animation ownership

Illusions and illusion placement previews reuse protagonist paint and rig definitions,
but own persistent renderers keyed by their illusion/preview actor key. Player
movement, melee, casting, shooting, and facing never change their front idle pose.
Only `presentation.illusion_motion[actor_key]` can supply an individual illusion's
own action; an absent descriptor returns it to idle. Placement previews always
idle. Reduced motion uses the same neutral rest pose. Removed illusions release
their renderers, and retained board layers share the pool by reference.

`tests/illusion_animation_gameplay_probe.gd` exercises real player actions beside
two illusions at 1920×1080/100%, plus explicitly addressed illusion motion. The
focused protagonist suite checks ownership, return to idle, and cleanup. This is
presentation routing only; it adds no independent illusion combat ability.
