# Iskaldra editable cutout and combat presentation

Generated proof paths cited below are retained in the [external roster evidence archive](enemy_cutout_roster_integration.md#evidence-archive-and-compact-history). Editable source cases remain in this repository.

Iskaldra uses one persistent 512×512 SubViewport per actor with its own front and
rear dragon rigs. Each rig uses Skeleton2D/Bone2D, rigid crystal panels and claws,
and four hind-leg/hip-fill meshes. The production loader is shared with the
protagonist, but the 17-joint graph, registration, paint, gait and action sampler
belong to Iskaldra. The editable case is `experiments/cutouts/iskaldra/v01`.

## Art and anatomy

The existing front painting is retained unchanged in `source/front_original.png`
and `source/front_registered.png` (SHA-256
`2cec2c774387ddf351bb3fe9277b983df3f9e5ad663feb6b69925e004bb957ac`). Explicit
ownership polygons and pixel overrides reconstruct the registered front and rear
sources exactly. The rear is a newly generated dorsal view registered uniformly
onto the 255×255 logical body canvas, rather than a reflected front drawing.
`source/generation_requests.json` retains the actual prompts, references,
selected/rejected outputs and digests. `source/registration.json` records the
whole-source crop and fit.

A generated torso's opaque interior scale patch supplies concealed joint overlap;
its checkerboard background and unsuitable full assembly were rejected. The
recipe selects no checker pixels and paints no new anatomy procedurally. Front
fills remain beneath fully opaque original pixels; the generated rear uses its
native nearly opaque interior alpha. `recipes/hidden_material.json` records every
socket polygon, source crop and registration. The final native rest bakes are the
production HUD/shadow silhouettes, with their digests in each production layout.

Wings, tail, head, torso and foreclaws stay rigid. Hind-leg meshes share a weight
field with their overlapping hip fills; rigid paws counter the projected leg
basis so their painted width and sole direction do not stretch. The gait keeps
separate near/far ground lanes in the board's 2:1 projection. Travel advances the
actor through whole gait cycles for every resolved segment. Each stride is
calibrated to that segment’s exact source-pixel distance, while both feet retain
their complete authored rest offsets. The entry and final poses therefore join
the accepted resting stance without a foot jump. Supporting soles cancel actual
root travel, including the first and final translation. The idle is a 1.7-pixel coordinated upper-body bob with stationary
hind legs and tail and unchanged bone bases.

## Runtime and timing

`IskaldraAction` maps existing resolved effects to dragon presentation. It never
resolves a move, damage, status, surface or initiative result. The four families
are a foreclaw rake for Rime Talon, a head/maw gather and thrust for Whiteout Lance,
a rigid-wing crystalline release for Shatterstorm, and a guarded wing fold for
Crystal Mantle.

| Clip | Authored time | Existing result boundary |
| --- | --- | --- |
| Idle | 2.0 s loop | No combat result |
| Walk | 0.8 s per cycle; stride fitted to whole cycles per segment | Resolved path and footprint center |
| Talon | 0.32 s preparation + 0.24 s effect | Existing melee progress 0.42 |
| Lance | 0.24 s preparation + 0.672 s effect | Release 4/42, arrival 14/42 |
| Storm | 0.36 s preparation + 0.24 s effect | Existing area progress 0.38 |
| Mantle | Existing 0.48 s floating-status presentation | Existing status application |

Preparation occurs before the existing attack effect clock. `cutout.json` maps
editable playback time to the same sampler phases. The whiteout projectile uses
a fixed authored maw release socket, so its launch point does not follow head
recovery. Its trajectory destination, shards, arrival, surfaces and damage clock
remain controlled by the existing ice effect. Iskaldra's melee stance remains
planted while the arm performs the attack.

Combat-board routing uses `enemy_cutout_facing.gd`: active movement/actions retain
their resolved direction; idle watches the player after completed movement. A
2×2 actor uses doubled coordinates to preserve its half-tile center. The same
policy selects front/rear and their reflections. Reduced motion displays the
same directional rest art. Death freezes the current pose and dissolves that
same texture; destination echoes and retained drawing layers share the actor's
texture. The existing portrait remains in the turn clock.

The enemy definition, 2×2 footprint, boss bar, HP, initiative, reward, freeze
immunity, frost armor, ranges, damage, terrain and other actors' resolution are
unchanged. Existing analytics descriptors and append-only local events require
no schema change because the resolver and event creation are unchanged.

## Reproduction

Use the maintained `tools/cutout_workflow.py` commands to validate, segment, skin,
inspect and verify the case. `author.py` records ownership and `build_rig.py`
records the rig/hidden-material/weight-field inputs. Choose new output revisions
when rerunning segmentation or skinning; those commands refuse overwrites.
`promote.py --native-rest-dir <native-output>` copies the selected case closure
and native bakes to the production namespace. Do not substitute registered
sources for these rendered rest images.

`capture.py --output <fresh-directory>` uses the maintained native visual runner,
validator, video packer and `verify_render`. Its explicit shared-GPU lease wait
accommodates concurrent workers without disabling serialization or extending the
actual capture watchdog. Freeze case/runtime/rendering inputs for the complete
wait and capture. Re-run proof after any bound input changes.

Focused checks are `tests/iskaldra_cutout_test.gd`; the full suite calls its
extracted suite. `tests/iskaldra_cutout_asset_probe.gd` compares every sampled
production pose with the editable case across all four directions and checks
native rest bakes. `tests/iskaldra_cutout_gameplay_probe.gd` exercises actual
RunScene input, resolver outcomes, effect boundaries, support-foot registration,
player repositioning, reduced motion, target previews, controller cancellation,
multiple bosses and death at 1920×1080 and 100% UI scale.

`tests/iskaldra_cutout_pack_test.gd` builds a production-only PCK. The matching
unmodified macOS 4.6.1 debug export template boots the isolated
`tests/fixtures/iskaldra_cutout_export_smoke.gd` entry scene with `editor=false`,
without the source project, tools, experiments or an imported asset cache. This
checks cutout packaging, not a complete platform release or Windows execution.

## Retained proof and inspection

`v01/proof_v2` contains the native editable scenes, complete front/rear cycles,
round-trip comparisons, support/bounds measurements and the cutout review movie.
The capture binds its rendering inputs and every retained output. Twelve
saved-scene reload samples are pixel-identical. The native pose comparison
checks 900 samples across front, rear and both reflections.

`runtime_v4` binds 1,637 inputs for the final gameplay capture. Its native asset
capture was freshly produced after the gait fix; `asset_proof_transfer.json`
verifies the 1,635 relevant original inputs remained unchanged after correcting
the separate gameplay probe's reduced-motion assertion. It
supersedes the earlier proof after peer review identified an entry/exit foot
jump. The old within-walk drift check excluded those transitions. The corrected
probe retains support history across idle/walk boundaries, requires both entry
and exit checks, and saves adjacent native PNGs around each transition. Focused
regressions compare every bone’s start/end transform to rest and test support
cancellation with different finite path lengths. `review_fix.json` records the
finding and correction.

The final gameplay proof contains 18 clips, 1,596 native samples and 88 retained
native PNGs, including forty adjacent walk-boundary frames. Maximum supporting
sole drift is 0.000252 screen pixels; entry/exit drift is at most 0.000069 pixels.
All 118 captured reduced-motion samples retain the directional rest pose at
phase zero while their actor translates. Reduced motion intentionally has no
supporting gait, so it is excluded from the planted-foot measurement.

Native gameplay compares exact player/enemy, terrain, trap, surface, event and
initiative outcomes against the unchanged resolver. All four Rime Talon paths
move two tiles and apply 12 damage; Whiteout Lance applies 8, Shatterstorm applies
7 and creates its existing Ice pattern, and Crystal Mantle grants one armor
layer or two with its revealed Ice fuel. Controller checks use simulated
modality and RunScene handlers, rather than a physical gamepad.

The gameplay movies preserve actual monotonic sample intervals at 60 fps through
frame repetition, without interpolating poses. Raw gameplay JPEG intermediates
are compacted only after movie encoding and a full decode pass; all their
timestamps and SHA-256 digests remain in the bundle. Native PNGs, complete
movies, boundary sequences and representative travel stills are retained.

The full Godot suite and focused cutout suite pass. Both suites were rerun
after the grounded finite-path gait correction. The production-only PCK build and unmodified export-template
runtime pass with `editor=false`. Logs and a byte-preservation audit are retained
in `runtime_v4`. The full suite emits the existing legacy-save migration and
ObjectDB shutdown warnings; Windows and a complete release export were not run.

Visual review at 1920×1080 and 100% UI scale checks the boss silhouette, stable
HUD/shadow registration, readable target feedback, turn-clock portrait, all four
directions and action extremes. Animation adds anticipation while the existing
FX/result clock still determines impact. Reduced motion keeps directional rest
art. No new controls, rules copy, icons, balance assumptions or analytics fields
are introduced.

The self-healing boss fixture opens before Rime Talon, with Iskaldra at `4:2`, the
player at `2:4` with 80 HP, and movement, defense and attack cards available. It
regenerates and independently verifies the pre-action save before launch. The
first two Pass actions advance player initiative; the third makes Iskaldra move
from `4:2` to `2:2` and strike the player at `2:4` for 12 damage:

```bash
cd /Users/borgerding/.codex/worktrees/317f/Labyrinth && python3 tools/inspection_fixture.py --project /Users/borgerding/.codex/worktrees/317f/Labyrinth --task-id animate-iskaldra-cutout --run-id animate-iskaldra-cutout-inspection --godot godot --godot-home-root /private/tmp/labyrinth-godot-home --manifest /private/tmp/iskaldra-inspection-precheck.json --launch --scenario boss --enemy-types iskaldra --enemy-positions 4:2 --enemy-intents rime_talon --player-position 2:4 --player-hp 80 --player-max-hp 80 --hand quick_stab,brace,sidestep_slash,bone_dart,patch_up --summary 'Iskaldra before Rime Talon. Continue, then press Pass three times to see two tiles of travel and its claw strike. Move around the boss afterward to inspect facing.'
```

The task remains local until user inspection and explicit publication approval.
