# Vaeloryx editable cutout and combat presentation

Current travel cadence, floor registration and room fitting are specified in [Actor presentation](actor_presentation.md); the timings and offsets below describe the original integration.

Generated proof paths cited below are retained in the [external roster evidence archive](enemy_cutout_roster_integration.md#evidence-archive-and-compact-history). Editable source cases remain in this repository.

## Design and scope

The combat board should make Vaeloryx's facing, dive contact and wind release
readable while the player chooses movement, cards and Pass through the existing
pointer, keyboard and controller paths. The pale ivory/teal dragon retains its
accepted front painting and its 2×2 boss footprint. A matching rear painting,
reflections and a creature-specific skeleton supply directional presentation.
Body/HUD/shadow anchors and the boss dossier remain stable. Native proof targets
1920×1080 at 100% UI scale, including reduced motion, completed player movement,
multiple actors, real action outcomes and death.

This is presentation work. `data/enemies.json`, combat rules, the boss library,
spawn pools, targeting, terrain/minion interactions, rewards and analytics
boundaries remain authoritative. The existing boss has 58 HP, initiative 12,
80 reward embers, a 2×2 footprint, the boss bar and Immobilize immunity. Hollow
Gale uses `gale_force`; Skyhook uses `pull`; Razor Dive resolves `move_toward`
then `melee`; Eye of the Storm resolves `move_away` then `block`.

## Art and motion contract

The fresh case is `experiments/cutouts/vaeloryx/v01`. Its source originals,
generation requests, dispositions, digests, whole-view registration, explicit
ownership polygons/contour transfers and concealed-joint recipes are retained.
The front source is unchanged. Generated underbody scales supply only hidden
joint material beneath fully opaque source pixels at rest. The rear source is
registered once to the 255px canvas; individual visible parts are never resized.

Fifteen bones represent the root, body, neck/head, two wings, two forelimbs with
separate rigid claws, the tucked hindlimb/claws and the long curled tail chain.
The cranial surface is substantially occluded by wings in both accepted views;
ownership records this uncertainty. The rig uses the production Skeleton2D mesh
loader. Idle is a coordinated 2.4px hover over two seconds, with no local basis
change. A traveling wing cycle accompanies 96:48 source pixels in 0.8 seconds.
The creature is airborne; no planted-foot claim is made.

Razor Dive prepares above and behind the target direction, sweeps its claws
through contact and returns to the registered body. Hollow Gale gathers its
wings inward before an outward release. Skyhook opens then scoops inward. Eye
of the Storm settles into a brief defensive hover. Source-pixel action offsets
are confined to the padded art canvas; the resolver owns logical movement.

Production integration, native verification and regression checks are complete.
Exact-commit peer review and the final playable fixture are recorded in the task
handoff after the branch is committed.

## Runtime ownership

`assets/units/vaeloryx_cutout` contains production paint, two layouts and baked
neutral silhouettes. `scripts/vaeloryx_cutout/{rig,motion,renderer}.gd` owns the
15-bone topology, phase sampler and persistent per-actor viewport. The shared
board registration is additive to the protagonist and Stone Warden. Presentation
uses the shared enemy-facing policy with doubled tile coordinates for the boss's
half-tile center. Idle updates after displayed player movement completes.

The logical 255px body remains inside a padded 512px canvas at offset (128,128).
HUD, neutral shadow and obstruction geometry use the baked logical body. Travel
phase derives from the resolved board path and source-pixel scale; the hover
sampler never changes occupancy. Action phases map the authored 42% release to
the existing melee 42% and wind 50% feedback boundaries. Dives last 0.8 seconds,
wind gestures 1.0 second, and the defensive pose follows the existing 0.48-second
block presentation. The existing resolver applies results and emits analytics.

`wind_feedback.gd` gives these two wind actions the existing teal air ribbons,
directed outward for Hollow Gale and inward for Skyhook. It uses the original
player tile, since a pull's final adjacent tile previously selected the shared
melee-slash fallback. Travel reaches its endpoint at the unchanged 50% result
boundary. This specialization leaves effect kinds, action types, the resolver,
other enemies, previews and existing Umbra clipping intact.

Reduced motion uses the new directional still art. Destination previews share
the real actor texture; death freezes that same pose for the existing dissolve.
Independent Vaeloryx instances retain separate textures. The dedicated portrait
remains `assets/art/portraits/vaeloryx.png`. Export presets explicitly include the
new layout JSON; production scripts do not reference experiments or tools.

## Reproduction and evidence

The namespaced scripts in `tests/vaeloryx_cutout_*` cover focused runtime contracts,
actual RunScene presentation, production-versus-case native pixels and packaging.
`experiments/cutouts/vaeloryx/runtime_v01` retains logs, package digests, source
preservation checks and the preliminary inspection audit. The front source,
registered image and final ownership reconstruction have identical RGBA pixels;
the production source file is also byte-identical to its retained original.

The full Godot suite passes after replacing two obsolete Vaeloryx sprite-sheet
expectations with cutout expectations. Other dragons retain their existing sheet
checks. The focused suite passes, as do 16 cutout-workflow and 16 visual-runner
Python tests. The isolated production PCK loads both facing layouts, all paint,
15 bones and all six motion clips in the unmodified Godot 4.6.1 macOS debug
export template (`editor=false`). The logs retain the environment's certificate
warning and the full suite's established ambiguous-save and ObjectDB warnings.

The 27-case RunScene logic audit checks all four directions for idle, dive,
Gale, Skyhook, guard and completed player movement, plus reduced motion, death
and a Gale blocked by the arena corner. Gale follows the existing resolver's
passable-tile selection, including movement along a wall; it is not constrained
to a straight ray. Actual results and appended action events match independently
resolved expectations. The retained logic-mode manifest explicitly identifies
headless draw-signal advancement and is not a native visual claim.

The final native `runtime_v01/gameplay` capture passes the same 27 scenarios in
actual RunScene, retaining 118 PNGs at 1920×1080/100% and full action videos with
88.667 seconds of measured timing. The retained package has input/output hashes;
duplicate JPEG encoder inputs remain in the original isolated capture, with
their digests retained. `runtime_v01/visual_review.md` records the inspected
frames, full-cycle sheets and affected UI rubric results.

`runtime_v01/assets` compares all 772 front/rear/reflected native samples with
the production renderer pixel for pixel. All samples fit the fixed canvas, with
at least 127px of margin, and both shipped 255px neutral images exactly match
the final assembly. All 24 full-cycle contact sheets were inspected. The current
maintained `native_v01` render contains 480 authored frames, 12 pixel-identical
AnimationPlayer save/reload comparisons, editable front/rear scenes and a timed
study reel. `verify-render` passes all 1,030 input and 1,279 output digests.

The cutout render command accepts an optional `--gui-lease-timeout`, matching the
small forwarding change coordinated for this enemy batch. It changes only the
shared renderer lease wait. Startup and capture watchdogs remain unchanged.

The draft inspection uses seed 105, room (4,0), the real Hollow Gale boss room.
Vaeloryx starts at (4,2), the player at (4,5), with 100 HP and a useful five-card
hand. A separate placement audit confirms the entire initial 2×2 body is clear.
The first Pass advances the normal initiative clock; the second triggers Razor
Dive, moves the boss to (4,3), and applies 14 damage. Further turns exercise its
normal intent choices. The final fixture must be regenerated and independently
verified after exact-HEAD reviewer signoff.

Remaining limits: the shadow is a static neutral silhouette; the wing-occluded
head remains faithful to the source's ambiguous anatomy. Alternate resolutions,
UI scales, Windows execution and physical controller hardware are not claimed.
The standard fixture is regenerated after structured exact-commit peer signoff.

## Commands

Run these from the task worktree. Native captures need a fresh output directory
and the shared renderer lease; submit only one at a time. The maintained render
includes the complete front/rear cycles, editable scenes, reload comparisons,
input/output digests and authored-speed preview encoding.

```sh
python3 tools/cutout_workflow.py validate experiments/cutouts/vaeloryx/v01/cutout.json
python3 tools/cutout_workflow.py render experiments/cutouts/vaeloryx/v01/cutout.json --output experiments/cutouts/vaeloryx/native_v01 --task-id vaeloryx-the-hollow-gale-editable-cutout-and-gameplay-animation --backend metal --gui-lease-timeout 1800
python3 tools/cutout_workflow.py verify-render experiments/cutouts/vaeloryx/v01/cutout.json --output experiments/cutouts/vaeloryx/native_v01
python3 tools/godot_task_runner.py --task-id vaeloryx-the-hollow-gale-editable-cutout-and-gameplay-animation --stream -- godot --headless --path . --script tests/vaeloryx_cutout_test.gd
python3 tools/godot_task_runner.py --task-id vaeloryx-the-hollow-gale-editable-cutout-and-gameplay-animation --stream -- godot --headless --path . --script tests/run_tests.gd
```

The separate `tests/vaeloryx_cutout_asset_probe.gd` covers all four direct/reflected
views, all action phases, 512px bounds, case/production equality and shipped-rest
equality. `tests/vaeloryx_cutout_gameplay_probe.gd` records actual RunScene input,
resolved outcomes and append-only analytics in all four directions. Run both
through `tools/visual_probe_runner.py` with `--no-headless`, native Metal/mobile,
the task ID and `--gui-lease-timeout 1800`. Its `--logic-only` mode is explicitly
headless evidence and does not replace the native captures.
