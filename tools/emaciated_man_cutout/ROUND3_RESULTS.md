# emac-02 rounds 2/3: observed focused results

No full suite or windowed run. All changes are uncommitted.

| Check | Observed result |
| --- | --- |
| `python3 tests/test_art_identity_gate.py` | `Ran 111 tests in 94.025s` / `OK` |
| `LABYRINTH_TASK_ID=emac-02 python3 -m unittest tests.test_approved_content_manifest` | `Ran 1 test in 10.001s` / `OK` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 4.373s` / `OK` |
| `python3 tools/cutout_workflow.py validate experiments/cutouts/emaciated_man/emac02` | `"ok": true`, 11 joints, 12 parts, 1 mesh, 3570 vertices, no errors |
| Strict art registry check, emac only | `ART IDENTITY CHECK: PASS (0 failures, 0 pending_reart warnings, 0 skipped replays)` |
| Runner → `tools/emaciated_man_cutout/sample_motion.gd` | `EMAC RIGID MOTION: PASS; samples=337; basis_mismatches=0; group_offset_mismatches=0; bob=1.68s; loop=3.36s` |
| `python3 tools/emaciated_man_cutout/rigid_cpu.py` | `EMAC RIGID CPU: PASS; samples=337; upper_mismatches=0; lower_mismatches=0; offsets=0,1,2; green_pixels=0` |
| `python3 tools/emaciated_man_cutout/round1_checks.py` | `EMAC ROUND1 CPU: PASS; poses=337; sack_changed_pixels=0; green_pixels=0; glow_cutoff=0.75` |
| Runner → editable probe | `EMAC EDITABLE: PASS; idle=3.36s; transform_and_glow_keys=6` |
| Runner → rigid probe `-- --verify-only` | `EMAC RIGID PROBE: PASS; group_samples=70; native_pixels=false` |
| Runner → game probe `-- --verify-only`, `LABYRINTH_CEL_LOOK=all` | `EMAC GAME PROBE: PASS; waypoint=cutout; dialogue=portrait_region; reduced=rest; sheet=unused` |
| Board comparison | `EMAC BOARD COMPARISON: PASS; height=194; art_scale=1.0` |
| Source/cel sheet | `ART IDENTITY SHEET: spec/art_identity/jobs/emaciated_man/mq_front/sheet.png` |
| Python compile / `git diff --check` | exit 0 |

Runner prefix: `python3 tools/godot_task_runner.py --task-id emac-02 --stream -- godot --headless --path . --script`.
Exact focused logs are copied into the current case's `proof/round3_*`.

`rigid_cpu.json` compares source texels with actual Godot group transforms using
the binding spec's shared `idle_pixel_errors` / `idle_group_offset`. Both group
mismatch counts are zero over 337 poses. The far forearm's nonzero influences
all belong to the upper group. This is not a native mesh-raster result. The new
native gate will report counts from 70 isolated group frames; those counts are
pending the design owner's window server. The source-only sack guard excludes
the newly authorized two-pixel hand contact sweep and still requires zero
changes in the remaining static sack surface.

## Registration and placement evidence

- Direct normalized-raw reduction 2.783505154639175; `fit_scale=1.0`.
- Rest bbox `(42,60,244,254)`, height 194, art_scale 1.0; hero front height 216.
- Ground pivot `(128,254)`; root `(128,242.5037037037037)`.
- All joints, maquette masks, solos and landmarks share that affine map.
- `proof/board_placement_comparison.json` compares actual round-1 and round-3
  default RunScene placement. Both use tile width 149.413848876953; both actors'
  logical rectangles are exactly unchanged. NPC rectangle:
  `(957.7587890625,286.948059082031,153.896270751953,153.896270751953)`.
- Shadow ground y 440.240814208984 vs canvas-ground y 440.240815877914.
  The root is not an input to board, waypoint, shadow or room fitting.
- The baked rest silhouette still supplies shadow bounds. Native rebake and
  cache regeneration are needed to certify the larger silhouette's shadow.
- Actual overlay boxes, exclusive xyxy: eyes `(103,109,107,112)` (12 pixels),
  `(117,109,121,113)` (14 pixels); tear `(221,241,230,247)` (36 pixels).
  .75 saturation retained. No glow overlay is assigned to skin.
- Portrait region `[51.06657094978562,54,120.81500624857692,120.81500624857692]`.

## Density check: native rest pending

`python3 tools/process_board_density.py --check` returned exit 1, exactly:

```
rest rebake needed: assets/units/chainbound_gaoler_cutout/humanoid_v2/front/rest.png: rig part pixels changed since recorded rebake
rest rebake needed: assets/units/chainbound_gaoler_cutout/humanoid_v2/rear/rest.png: rig part pixels changed since recorded rebake
rest rebake needed: assets/units/emaciated_man_cutout/front/rest.png: rest pixels changed since recorded rebake
```

The stale obsolete emac part records were removed. Gaoler's production files,
registry and output records remain unchanged from HEAD. Emac's pending native
rest record was not replaced by a CPU certification. The full native sequence
is in README.md, including rest recording, shadow cache and a fresh density check.

## Artifacts and remaining proof

- `experiments/cutouts/emaciated_man/emac02/proof/board_comparison.png`: painted
  hero / NPC / Grave Surgeon on approved tiles, 1× and 2×; inspected.
- `spec/art_identity/jobs/emaciated_man/mq_front/sheet.png`: fresh source/cel
  review rows, metrics and provenance; inspected.
- `proof/portrait_region_source.png`: new bust source crop; inspected.
- `proof/hidden_scope.json` / `hidden_fills/`: measured 41-pixel hidden support.
- Native rigid pixel counts, final keyframes/reel, waypoint contact shadow and
  portrait renderer capture remain pending. No fresh native success is claimed.

No active TODO_DESIGN placeholder remains. New proof-only defaults: 337 pose
samples and 224 reel frames. Existing named proof thresholds and authoring
raster margins remain as documented in README.md. No new player-visible value
was invented. Existing macOS certificate and NumPy/Pillow warnings appeared on
passing runs. No master failure assertion was changed.
