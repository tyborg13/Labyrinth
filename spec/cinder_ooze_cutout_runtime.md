# Cinder Ooze cutout in gameplay

Current travel cadence, floor registration and room fitting are specified in [Actor presentation](actor_presentation.md); the timings and offsets below describe the original integration.

Generated proof paths cited below are retained in the [external roster evidence archive](enemy_cutout_roster_integration.md#evidence-archive-and-compact-history). Editable source cases remain in this repository.

## Design and scope

The combat board shows where Cinder Ooze is creeping and when its molten mass
strikes or erupts. Players continue to choose movement, cards and End Turn with
the established pointer, keyboard and controller paths. Health, intents, turn
clock, tiles and shadows remain registered to the existing logical body. The
accepted front painting retains all of its exposed painted surfaces; generated
overlap material fills only newly revealed soft seams during movement. The
matching rear view supplies the unseen side. This is presentation work: HP,
initiative, AI, action weights, damage, surfaces, fuel consumption, rewards and
analytics/result boundaries do not change.

The live definition has 12 HP, initiative 13 and 12 reward embers. Smolder Slide
moves up to one tile, then performs a five-damage range-one fire melee attack.
Cinder Bloom applies the existing four-damage cardinal area pattern and fire
surfaces. Slag Shell retains three block and its nearby-fire fuel bonus. Death
still spawns up to two summoned Cinder Droplets through the existing resolver;
this cutout belongs only to `cinder_ooze`.

## Authoring ownership

The fresh case is `experiments/cutouts/cinder_ooze/v01`. It uses the maintained
`tools/cutout_workflow.py` init, segment, skin, validate and native render paths.
`source/front_original.png` and `front_registered.png` are byte-identical copies
of the accepted 255px sprite. Both views retain the same source coordinate
system inside the 512px action canvas. The rear is registered uniformly to the
front's size and ground line; no part is individually enlarged to fit a cell.

Actual built-in image generation requests, reference roles, untouched outputs,
selected dispositions and digests are retained in `source`. The rear request
uses the original solely as an identity/style reference. A separate generated
soft underbody supplies concealed overlap material. It never replaces visible
front paint. Its crop and placement are explicit in
`recipes/hidden_registration.json`; fully opaque front coverage hides those
bridges at rest. The rear output has slightly translucent interiors, retained
from generation, so rear bridges use its near-opaque interior mask.

The creature has a root, one rigid crusted mass, and six soft lobe/contact pairs
(14 bones). Ownership polygons name the distal tendril lobes; all eyes, shell
plates and attached proximal crust remain on the coherent mass. Generated
bridges and the corresponding lobes share source-space weights. Meshes attach
to the rig's Skeleton2D once. Translation fields preserve cross-band painted
width, and terminal regions have a rigid basis.

## Motion and runtime boundaries

Idle is a 1.8-second coordinated settle with a 1.1px vertical mass translation;
it introduces no bone rotations, scaling or skew. Six terminal contacts stay
fixed. Locomotion uses a staggered six-contact cycle, 72 percent stance,
36px projected stride and 50px travel per 0.62-second cycle on the 2:1 board
plane. Support translations counter actual root travel. Soft lobes recover
with a low 2.5px lift while the shell remains rigid.

Smolder Slide has preparation, short forward mass/tendril contact and recovery.
It lasts 0.7 seconds and contacts at 42 percent. Cinder Bloom is a distinct
0.8-second gather/eruption/recovery clip: the crust rises as alternating lobes
spread, with three support lobes braced. Its release is at the existing
38 percent area boundary. Slag Shell may retain the restrained idle while the
existing block and fuel feedback plays.

Production assets and scripts are owned by `assets/units/cinder_ooze_cutout`
and `scripts/cinder_ooze_cutout`. The production skeleton loader and shared
`scripts/enemy_cutout_facing.gd` policy provide the common behavior: actions face
their resolved direction, idle chooses the closest supported view toward the
player after completed movement, and the protagonist keeps camera-facing idle.
Persistent viewports, actor-specific motion maps, cached rest silhouettes and
logical-body padding preserve echoes, reduced-motion stills and frozen death
presentation without loading experiment or tool files at runtime.

## Verification and inspection

The changed surface is Cinder Ooze on the live combat board. The relevant UI
rubric gates—immediate comprehension, hierarchy, gameplay visibility,
state/consequence, input completeness, cohesion, reduced motion, layout
resilience and native proof—pass at 1920×1080 and 100% UI scale. Full native
front/rear/reflected cycles, live travel and contact, the outward molten Bloom,
Slag Shell's block/fuel feedback, target preview, controller Cancel/pointer
handoff, player repositioning and death were inspected. Logical targeting,
health bars and the separate turn-clock portrait retain their established
anchors. No icon identity, balance rule or analytics boundary changed.

The editable case's current evidence is [v01/proof_v2](../experiments/cutouts/cinder_ooze/v01/proof_v2/).
It retains **392** native authored frames, complete fixed-canvas
bounds and support checks, and **8** pixel-identical saved-scene reloads.
`front.tscn` and `rear.tscn` retain Skeleton2D, skinned meshes and AnimationPlayer
tracks. Both layouts have 14 bones. The rigid-basis error is zero, and maximum
case support drift is **0.000055017 source pixels**. Current `verify-render`
binds **998 inputs and 983 outputs**.

Current production evidence is [runtime_v1](../experiments/cutouts/cinder_ooze/runtime_v1/):

- `assets/comparison.json`: **548** native front/rear/reflected
  rest/idle/walk/attack/Bloom samples are pixel-identical between the case and
  production. Every sample retains fixed-canvas clearance; all four rest views
  match the shipped bakes. Full-cycle contact sheets retain equal source-space
  crops of every sampled pose.
- `gameplay/cinder_ooze_gameplay_full_speed.mp4`: **64.65 seconds**,
  1920×1080/60 fps, containing **21 clips and 1,706 native samples**.
  It covers two idle cycles and real Smolder Slide in every direction, four
  Bloom directions, both reduced-motion attack families, plain/fueled Slag
  Shell, split/death and four real player movement paths. `video_timeline.json`
  preserves recorded wall-clock intervals with frame repetition only; each
  clip's last sample holds 1/30 second. The full reel decodes without errors.
- `gameplay/manifest.json`: **12 complete resolver outcomes** match the same
  actions without presentation. This includes damage, positions, initiative,
  fire surfaces, statuses and Slag Shell fuel/block. Visible damage starts at
  contact. Maximum measured world-space walk support drift is
  **0.000244141 pixels**. One texture survives each action; the second actor
  remains independent. Lethal Quick Stab creates two summoned Droplets and
  awards the parent’s 12 embers once. The parent renderer survives its dissolve
  and is then released. Player movement defers observers' idle turns until the
  destination is reached; the protagonist retains camera-facing idle.
- **59 native 1920×1080 PNGs** retain the inspected gameplay states.
  Original captured JPEGs remain in the task's temporary probe directory;
  their hashes are retained in `gameplay/source_frame_sha256.json`.
- `preservation_audit.json`: the original front, portrait, enemy definitions,
  resolver and shared facing policy match the starting commit byte for byte.
  The source copies are exact. Native front rest has identical alpha and every
  opaque pixel; 1,679 edge/transparent RGB differences are GPU premultiplied
  alpha quantization or unused transparent RGB. No accepted paint is redrawn.
- `focused_suite.log` and `full_suite.log`: **PASS**, covering anatomy, timing,
  support, facing, reduced motion, renderer lifecycle and affected integration.
  The full suite retains the established ambiguous-save migration and ObjectDB
  shutdown warnings; no clean-shutdown claim is made.
- `export_build.log` and `export_runtime.log`: **PASS (editor=false)** using the
  byte-identical Godot 4.6.1 macOS debug template and a production-only PCK.
  Both rigs and all clips load without loose experiment/tool files or imported
  art caches. This proves cutout packaging, not a full platform release.
- `fixture_layout_audit.log`: an exploratory copy confirms all actors and the
  Smolder route stand on clear floor. Three Passes exercise all three intent
  families without trap detonation and leave the player at 28/40 HP. The final
  delivered pre-action fixture is regenerated after exact-HEAD peer signoff.
- `capture_input_sha256.json` binds **1,477** case/runtime/art/test/import/export/
  workflow inputs; `proof_sha256.json` binds **648** retained
  outputs. The hash inventory precedes final gameplay/case capture. It was
  recorded 16 seconds into the asset pass; `capture_provenance.json` records
  that timing and that the last input edit predates its first frame. All bound
  input hashes remain current. The case pipeline separately records its own
  hashes before capture and checks them afterward.

Reproduce checks from this task worktree; use a fresh output path for every
new native capture:

```sh
python3 tools/cutout_workflow.py validate experiments/cutouts/cinder_ooze/v01
python3 tools/cutout_workflow.py verify-render experiments/cutouts/cinder_ooze/v01 --output experiments/cutouts/cinder_ooze/v01/proof_v2
python3 tools/godot_task_runner.py --task-id cinder-ooze-editable-cutout-and-gameplay-animation --stream -- godot --headless --path . --script tests/cinder_ooze_cutout_test.gd
python3 tools/godot_task_runner.py --task-id cinder-ooze-editable-cutout-and-gameplay-animation --stream -- godot --headless --path . --script tests/run_tests.gd
python3 tools/visual_probe_runner.py tests/cinder_ooze_cutout_asset_probe.gd --task-id cinder-ooze-editable-cutout-and-gameplay-animation --no-headless --rendering-method mobile --rendering-driver metal --expect-size 512x512 --timeout 180 --gui-lease-timeout 1800
python3 tools/visual_probe_runner.py tests/cinder_ooze_cutout_gameplay_probe.gd --task-id cinder-ooze-editable-cutout-and-gameplay-animation --no-headless --rendering-method mobile --rendering-driver metal --expect-size 1920x1080 --timeout 180 --gui-lease-timeout 1800
python3 tools/godot_task_runner.py --task-id cinder-ooze-editable-cutout-and-gameplay-animation --stream -- godot --headless --path . --script tests/cinder_ooze_cutout_pack_test.gd -- build /private/tmp/cinder-ooze-export/godot_export_debug.pck
```

For the last check, put the matching macOS debug export template beside the PCK
as `godot_export_debug`, then run it through `godot_task_runner.py --project
/private/tmp/cinder-ooze-export --task-id
cinder-ooze-editable-cutout-and-gameplay-animation --stream --
/private/tmp/cinder-ooze-export/godot_export_debug --headless`. The same-basename
PCK supplies its boot scene. The retained `runtime_v1/recipes` scripts document
hashing, video encoding, and the maintained case render with only its shared
GUI lease wait extended. Startup and capture watchdogs are unchanged.

## Playable inspection

The command below regenerates and independently reloads the pre-action save
before launching. Choose **Continue**. Watch the quiet idle, move around the
Oozes to inspect all facings, then choose **Pass** three times: the second Pass shows Slag Shell and the
third shows Smolder Slide and Cinder Bloom. Brace and Patch Up allow more turns. Damage an Ooze to inspect its split and death.
The branch is `codex/animate-cinder-ooze-cutout`, based on local `master`
commit `01c7dccbc931ae7dddf3eb8f797fb3d1d33def3e`.

```sh
cd /Users/borgerding/.codex/worktrees/8d94/Labyrinth && python3 tools/inspection_fixture.py --task-id cinder-ooze-editable-cutout-and-gameplay-animation --run-id cinder-ooze-cutout-inspection --manifest /private/tmp/cinder-ooze-cutout-inspection.json --launch --scenario combat --summary "Cinder Ooze: inspect idle and facing, then Pass three times for Slag Shell, Smolder Slide and Cinder Bloom" --player-position 3:5 --player-hp 40 --player-max-hp 40 --enemy-types cinder_ooze,cinder_ooze,cinder_ooze --enemy-positions 5:4,3:3,4:5 --enemy-intents slag_shell,smolder_slide,cinder_bloom --trap-elements earth --trap-positions 7:1 --hand quick_stab,brace,sidestep_slash,pale_spark,patch_up
```

Remaining limits: cached neutral shadows use the static front rest silhouette
instead of per-frame GPU readback; the generated rear retains its slightly
translucent paint. Alternate resolutions/scales, physical controller hardware
and Windows runtime were not exercised. Publication awaits user inspection
and explicit approval of the reviewed commit.
