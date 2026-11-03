# pt13-06 implementation proof

Only Glacial Mirror's profile changes in production. The paintings, rigs,
registration code, other profiles, rules, input, saves and analytics are unchanged.

## Measurements

Measure the bottom three fully opaque rows of each separate foot component.
The test uses source pixel centres (`x + 0.5`, `y + 0.5`). Below source y=175,
the feet are disconnected. Foot seeds select the two foot components; the
rear's disconnected hanging hand is excluded. No silhouette-wide average or
single-foot shortcut participates in the anchor.

| View | Far sole centroid | Near sole centroid | Two-sole midpoint | Profile |
| --- | --- | --- | --- | --- |
| Front | (74.038462, 199.192308) | (153.235849, 244.292453) | (113.637155, 221.742380) | (113.64, 221.74) |
| Rear | (77.523810, 199.214286) | (142.267442, 244.197674) | (109.895626, 221.705980) | (109.90, 221.71) |

The front's measured x differs from the brief's rough estimate of 122. Both
views' sole centroids differ vertically by about 45 px; neither is a square
stance under the 6 px rule. The midpoint is used for both.

The previous heights encode painted-rest HUD landmarks at source y=16 front
and y=8 rear. Subtracting those same landmarks from the new anchor y yields
205.74 / 213.71, preserving the existing head association and 4 screen pixel gap.

## Proof for the design owner

The worker sandbox cannot capture windows. Run the complete before/after/Seer
package from a window-server session:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pt13-06 && python3 tests/glacial_mirror_board_proof.py
```

The helper uses `tools/visual_probe_runner.py` for three separate engine
processes. It temporarily substitutes only the old Glacial Mirror profile for
the before process and restores the exact source bytes in `finally`, including
if the renderer fails. After and Seer run against the current source. It refuses
to overwrite a prior proof directory; move that directory before another run.

Each stage uses the production inspection fixture builder's `enemy_types` and
`enemy_positions` overrides and the actual RunScene. The hero is at (4,4), with
foes at (4,3), (5,4), (4,5), (3,4). Actual renderer facings, tile registration,
HUD clearance, camera scale and camera origin are asserted.

The direct after command writes to its isolated `user://probes/glacial_mirror_board`
folder (the runner prints the exact path):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pt13-06 && python3 tools/visual_probe_runner.py --task-id pt13-06 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --min-images 5 tests/glacial_mirror_board_probe.gd -- --stage after
```

The complete helper validates `tests/glacial_mirror_board_probe_contract.json`:
three 1920x1080 frames and eight 720x480 feet/ring crops (3x nearest-neighbour).
Output is `output/pt13-06/board/`: `before.png`, `after.png`,
`seer_reference.png`, `{before,after}_{front,rear,front_mirrored,rear_mirrored}_feet_3x.png`,
per-stage geometry JSON, and per-stage runner manifests. These files are not
present until the design owner runs the capture command. The director judges
the actual standing impression from those images.

For interactive inspection using the same production fixture overrides:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pt13-06 && python3 tools/inspection_fixture.py --task-id pt13-06 --run-id pt13-06-mirrors --scenario combat --player-position 4:4 --enemy-types glacial_mirror,glacial_mirror,glacial_mirror,glacial_mirror --enemy-positions 4:3,5:4,4:5,3:4 --summary 'pt13-06 four-facing Glacial Mirror registration' --launch
```

## Headless checks

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pt13-06 && python3 tests/test_glacial_mirror_registration.py -v
cd /Users/borgerding/workspace/Labyrinth.worktrees/pt13-06 && python3 tools/godot_task_runner.py --task-id pt13-06 --stream -- godot --headless --path . --script tests/glacial_mirror_board_probe.gd -- --validate-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/pt13-06 && python3 tools/godot_task_runner.py --task-id pt13-06 --stream -- godot --headless --path . --script tests/glacial_mirror_board_probe.gd -- --stage seer_reference --validate-only
```

The Python tests pin both anchors to the paintings within 0.5 px, require
restoring either old single-sole anchor to fail, pin the unchanged painted-rest
HUD landmarks, and verify that a failed before capture restores the source.
The native-only probe is registered in the windowed allowlist; its fixture and
production-facing checks also have an explicit headless validation path.

## Chosen defaults

These affect proof and measurement only: the existing fixture seed 7262026;
hero tile (4,4) and the four adjacent positions above; camera tile width 128
and origin (960,160); zero-second animation clocks; 5 settle frames and a
0.5-second settle timer; a 240x160 feet/ring crop before the required 3x zoom;
semantic image checks with minimum luma range 12 and standard deviation 3.
The rendered registration assertion uses a 0.01 screen pixel tolerance.
The hero holds the existing front idle, direction (0,1). Semantic regions are
[768,240,384,288] in each board frame and [180,120,360,240] in each enlarged crop.
Segmentation uses lower-region y=175, full opacity 255, pixel-centre offset
0.5, and foot seeds front (74,199)/(153,244), rear (78,199)/(142,244).

No `TODO_DESIGN_` placeholders or production tuning defaults were needed.

## Worker verification results

- Focused Python: `Ran 4 tests`; `OK`. Both legacy-anchor mutations are rejected.
- Actor integration: `ACTOR PRESENTATION TEST: PASS`.
- Mirror and Seer probe setup: `GLACIAL MIRROR BOARD HEADLESS FIXTURE: PASS`
  for each of the two commands above, including the fixed-camera checks.
  One Seer run additionally logged an ObjectDB leak warning and two resources
  still in use at exit. A verbose repeat passed without reproducing those
  resource warnings; `/private/tmp/pt13-06-seer-verbose.log` records that repeat.
- Fixture wrapper: `Inspection fixture verified.` Its manifest is
  `/private/tmp/labyrinth-inspection-manifests/pt13-06-mirrors.json`.
- Registration: `TEST REGISTRATION AUDIT: PASS (858 scripts; full suite=501, quarantined=29, windowed probe=328)`.
- Full Godot: **incomplete**, exit 124, `error: command timed out after 900 seconds.`
  The main body reported `MAIN BODY RUNTIME: 493.221 seconds` and
  `MAIN BODY ASSERTIONS: 495562`. Child programs `sfx_sync_0_program` and
  `sfx_sync_1_program` each timed out at their existing 180-second caps.
  `special_encounter_test` reported `SPX special encounter suite: 2 failures`:
  approved/staged emblem imports could not load missing `.godot/imported/*.ctex`
  cache files (including the staged `last_light.png`). These are outside this
  unit; no assertions were changed. The scheduler recorded 210 passing children,
  those three failed children, and 13 children cancelled as `parent interrupted`
  when the outer deadline ended the run. This run does **not** establish that the
  entire Godot suite passes.
- Headless import: **incomplete**, exit 124,
  `error: command timed out after 300 seconds.` The probe's UID was generated.
  No unrelated tracked or untracked source/sidecar changes remained afterward.
  The scan also reported the existing duplicate UID on the two player placeholder
  PNGs. Engine launches reported the host's `get_system_ca_certificates` error.
- Full Python discovery: `Ran 1995 tests in 8776.862s`;
  `FAILED (errors=2, skipped=66)`. Both errors occurred before assertions in
  `test_rr21_review.ReviewTests.test_native_preflight_requires_current_capture_and_never_rebinds_it`
  and `test_review_from_clean_proof_state_regenerates_real_direction_evidence`:
  their `TemporaryDirectory` parent, the ignored
  `experiments/cutouts/briar_weaver/mq9/proof/logs/`, was absent. No assertions
  were rewritten. The empty directory was then created for focused reruns.
  Both reruns passed: `Ran 2 tests in 39.242s`; `OK` (exit 0). This does not
  relabel the original full-discovery run as passing; it isolates and clears
  its two fixture-bootstrap errors without modifying RR21 test code.

Worker logs: `/private/tmp/pt13-06-focused-python.log`,
`/private/tmp/pt13-06-actor-presentation.log`,
`/private/tmp/pt13-06-mirror-fixture.log`,
`/private/tmp/pt13-06-seer-fixture.log`,
`/private/tmp/pt13-06-inspection-fixture.log`,
`/private/tmp/pt13-06-registration-audit.log`,
`/private/tmp/pt13-06-import.log`, `/private/tmp/pt13-06-godot-full.log`.
The full discovery log is `/private/tmp/pt13-06-python-full.log`; focused RR21
reruns are recorded in `/private/tmp/pt13-06-rr21-rerun.log`.
The child logs and partial scheduler report are named by `PROGRAM SUITE REPORT`
in the full Godot log.
