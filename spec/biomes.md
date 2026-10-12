# Section biomes

Section domains are presentation only: the room's section boss selects its floor
repaints, pillar, wall lights, floor-light color, active-profile tint/ambient,
hall pool, mote preset and backdrop modulation. Rules, saves, room topology,
actor ordering, surfaces, elemental overlays, traps, terrain and doors retain
their existing behavior. Biome IDs are derived, never serialized.

## Data and mapping

`data/biomes.json` is protected director-authored data. `BiomeLibrary` loads it
once and provides copied definitions and cached textures, trimmed pillars and
idle atlas frames. `biome_for_run(run_state, room)` requires the existing section
map version and the room's `section_index`, obtains that section's `boss_id`
from `map_sections`, and looks up `section_biomes`. Legacy/non-section/invalid
section rooms use `default_biome` (`stone`). Room type does not affect mapping,
so combat, guardian, boss, Hearth, treasure, Scavenger, Graftwright, event and
entry-threshold rooms all follow their section.

| Boss | Biome name |
| --- | --- |
| tharokh | Worldspine Roots |
| vyraketh | Cinder Crown |
| vaeloryx | Hollow Gale |
| iskaldra | Rime Hall |
| zekarion | Tempest Spire |
| noctyrax | Heart of the Umbra |

Stone retains the exact existing asset paths. Each missing biome PNG falls back
independently to its corresponding stone asset and logs once. Floor selection
uses the existing deterministic four-variant tile lookup. Room replacement
updates retained layer bindings and floor-cache inputs, including pool color;
it retains unrelated wall/door resources and elemental overlay preparation.
Texture decoding and atlas building occur at preparation/biome boundaries,
with no per-frame texture loads.

## Lighting and atmosphere

The active named profile and its existing source-density blend are resolved
first. `CombatLightingProfiles.with_biome` then multiplies its tint by the biome
tint, component by component, and ambient by `ambient_scale`. Other profile
fields remain unchanged. The composed parameters enter the treatment's owned
map and all three shared world/floor materials, including the parameters copied
to enemy dissolves. Each resolution starts from the base profile, preventing
cumulative multiplication when moving between rooms or changing profiles.

Biome `light_color` supplies the existing retained column floor pools.
`CombatAtmosphere.set_biome` supplies the hall pool and mote preset. New presets
read color, amount, direction, velocity range, lifetime/preprocess and spread
from the protected data, retaining the existing particle texture, gravity,
scale, angular motion and temporal alpha envelope. Reduced motion suppresses
both visibility and emission, including after a biome replacement. RunScene
passes the derived ID through both ordinary board refreshes and animation
submissions and applies `backdrop_modulate` to the hall backdrop.

Stone's data-authored identity tint/ambient and pool `[1, 0.60, 0.28, 1]`
preserve the exact legacy look through the same composition path as every
biome. Presets marked `"color_ramp": "legacy"` retain the existing authored
RGB/alpha ramp and white particle modulation; count, direction, speed, lifetime
and spread still come from data. The director's `embers` values match today's
legacy motes exactly. Tests retain exact property/ramp equality and substitute
other approved data temporarily to detect hard-coded stone/embers bypasses.

## Approved art processing

See [provenance and per-output density measurements](assets/biomes/README.md)
and [raw hashes](assets/biomes/raw_sha256.txt). The processing command is:

```bash
python3 tools/process_biome_art.py --raw-dir /Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/raw_art/biomes --all
```

`--biome <id>` processes one non-stone domain. The tool keys/despills green,
applies `raw_grade.floor`/`raw_grade.pillar` when present, fits alpha bboxes with
BOX to the untouched templates and restores floor/pillar template alpha.
Transparent repaint holes inside that alpha receive the nearest painted RGB.
The four floors then match per-channel means toward their channel median with
the prescribed gain clamp. Shared board-density functions apply the template's
mode/grid/resample path and alpha class; final floor/pillar alpha is asserted
byte-identical to the production template. Every output reports its orphan
share beside the template's. Static lights retain keyed repaint alpha and their
own right mirror; idle sheets preserve stone's sixteen-frame 4×4 layout.

Flame cycles brightness 0.86–1.06 with alternating one-pixel upward glow jitter;
glow cycles 0.92–1.05 without jitter. The glow mask uses luminance > 0.55. Spark
holds 0.9 except the director-approved zero-based frames 4 and 11, which flash
at 1.25. Noctyrax's protected floor grade `[1.30, 1.25, 1.35]` improves grid
readability; it is applied before fitting and variant matching.

## Validation and native proof

Run from the task worktree:

```bash
python3 tests/test_process_biome_art.py
python3 tests/test_board_pixel_density.py
python3 tools/godot_task_runner.py --task-id biome-01 --stream -- godot --headless --path . --script tests/biome_test.gd
python3 tools/godot_task_runner.py --task-id biome-01 --stream -- godot --headless --path . --script tests/static_floor_cache_equivalence_test.gd
python3 tools/godot_task_runner.py --task-id biome-01 --stream -- godot --headless --path . --script tests/board_density_consumer_test.gd
python3 tools/godot_task_runner.py --task-id biome-01 --stream -- godot --headless --path . --script tests/run_tests.gd
python3 tools/godot_task_runner.py --task-id biome-01 --stream -- godot --headless --path . --script tests/biome_gallery_probe.gd -- --headless-check
```

The dedicated suite covers protected data, all six boss mappings and room
types, legacy mapping, per-asset fallback/log-once, deterministic variant
selection, unchanged wall/door bindings, exact legacy embers, every new mote
preset, reduced motion, profile multiplication and all three shader materials.
The full Godot suite remains untouched; the new suite has its own launcher.
The static floor reference remains frozen so its stone comparison retains an
independent pre-biome baseline. Headless cache/gallery checks prove structure,
not rendered pixel equality.

Observed headless implementation proof on 2026-10-12:

| Check | Result line |
| --- | --- |
| Biome suite (feedback 1) | `BIOME RESULT: PASS (500 checks, 0 failures)` |
| Processing tests (feedback 1) | `Ran 6 tests in 10.557s` / `OK` |
| Board-density Python tests | `Ran 41 tests in 100.934s` / `OK` |
| Board-density consumer suite | `BOARD DENSITY CONSUMERS: PASS` |
| Static floor cache | `STATIC FLOOR CACHE RESULT: {"cases":102,"checks":156711,"errors":[],"native":false,"orphans":0,"pixel_differences":[]}` |
| Gallery structure | `BIOME GALLERY HEADLESS CHECK: PASS (8 cases)` |
| Full Godot suite | `TEST RESULT: PASS` |
| Existing fixture Python tests | `Ran 9 tests in 8.245s` / `FAILED (failures=1)` |

The existing failing test is
`test_deepest_route_depth_generates_a_verified_room_with_live_moves`:
`INSPECTION FIXTURE ERROR: Could not traverse a resolved route to depth 23 with live moves; stopped at (4, 0) depth 4 in mode reward after 9 steps.`
The unchanged base `tools/inspection_fixture.gd` reproduces that same failure;
its assertion and route logic were not changed. The engine also emits the
existing macOS certificate error and ObjectDB leak warnings; the full base and
modified Godot suites both report PASS and exit zero.

Headless fixture generation and verification with and without
`--biome iskaldra` both report `Inspection fixture verified.` and have identical
state contracts, including run-state SHA-256
`468e91079489febeb352cb26d754af4bcce36bffabd5bf81ad8bc3d605ec78e7`.
The override appears in the launch command, not that certified save contract.
The manifests are `/private/tmp/biome-01-iskaldra-fixture.json` and
`/private/tmp/biome-01-no-override-fixture.json`. Test logs live at
`/private/tmp/biome-01-{biome-test,art-test,density-test,density-consumer,static-cache,gallery-headless,full-final,fixture-test,fixture-baseline}.log`.
No windowed run was attempted in the implementation sandbox.

For feedback 1, the director reported that the native seven-biome gallery and
Iskaldra Hearth looked right, then approved the stone/embers reconciliation,
spark frames and Noctyrax grade above. The protected JSON was read without
rewriting it. Noctyrax and Zekarion were reprocessed, all raw hashes still match,
and per-output measurements were refreshed in the provenance README. The
requested new headless logs are
`/private/tmp/biome-01-feedback-1-{biome-test,art-test,static-cache,full}.log`;
all four requested checks passed. The director reruns native gallery proof
after these changes. The new test-only `SPARK_GLOW_SAMPLE` is RGB 180 with
alpha 255, chosen to remain unclipped at the approved 1.25 flash gain; no new
production or proof-stage defaults were chosen.

`tests/biome_gallery_probe.gd` reuses the existing density probe's real RunScene
stage and freezing helpers. It captures one fixed combat with hero, three
production enemies, two lit pillars and crates in each of the seven biomes,
plus an iskaldra Hearth. Its native output is
`user://probes/biome_gallery/{combat_<id>,hearth_iskaldra}.png` and `gallery.json`.
The headless mode writes the same case manifest without images and reconstructs
the semantic proof contract at `/private/tmp/biome-01-gallery-proof.json`.

The design owner runs and inspects fresh native proof at 1920×1080, 100% UI:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/biome-01 && python3 tools/visual_probe_runner.py tests/biome_gallery_probe.gd --task-id biome-01 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --min-images 8 --expect-size 1920x1080 --proof-contract /private/tmp/biome-01-gallery-proof.json --result-manifest /private/tmp/biome-01-gallery-native.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/biome-01 && python3 tools/visual_probe_runner.py tests/static_floor_cache_equivalence_test.gd --task-id biome-01 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --min-images 1 --expect-size 1920x1080 --result-manifest /private/tmp/biome-01-static-cache-native.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/biome-01 && python3 tools/visual_probe_runner.py tests/board_density_probe.gd --task-id biome-01 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --min-images 13 --expect-size 1920x1080 --result-manifest /private/tmp/biome-01-density-native.json -- --label biome-01
cd /Users/borgerding/workspace/Labyrinth.worktrees/biome-01 && python3 tools/inspection_fixture.py --task-id biome-01 --run-id biome-01-owner-iskaldra --scenario combat --biome iskaldra --seed 62001 --room-coord 1,1 --summary 'Inspect iskaldra presentation' --manifest /private/tmp/biome-01-owner-iskaldra.json --launch
```

`--biome <id>` is validated by the fixture generator and forwarded by its
self-healing launch command to the game. `BiomeLibrary.inspection_override`
reads the launch argument; the fixture save/state contract contains no biome
override. A headless generation/verification can omit `--launch`.

Chosen defaults are confined to proof: the gallery inherits the density probe's
seed `7262026`, hero start `(6,8)`, 10×10 grid, pillar/terrain positions and
frozen clock `0`; its named roster is crawler/cinder_droplet/lightning_wisp at
`(2,4)/(6,3)/(2,7)`, with production HP. It uses six final settle frames, a
fixed proof-contract output path, and a board region `[320,120,1280,650]` with
minimum luma range `40` and standard deviation `3`. The listed native runner
timeout `120` accommodates eight fresh scene preparations or the existing
multi-case probes. None of these fields tune gameplay or production visuals.

## Adding a biome

The design owner adds a complete definition and any boss mapping to the
protected JSON and approves its raw repaint set against the existing templates.
Supply all four floor variants, pillar and light with the documented names;
provide any raw per-channel grade explicitly. Approve any new mote preset and
flicker behavior. Run the processing tool with `--biome`, retain provenance,
and run the dedicated suite, Python art tests, density tests, full runtime
suite and native gallery. The owner inspects the new paint and lighting and
resolves all design placeholders before publication.
