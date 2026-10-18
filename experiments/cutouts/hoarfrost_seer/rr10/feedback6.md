# rr-10 feedback 6 handoff

Implemented on `codex/rr-10`, starting at director commit `903d1427d`. All changes remain uncommitted. No merge, branch change, peer review, publication, queue edit or windowed run was performed.

## Approved donor and requirements

| Requirement | Implementation / evidence |
| --- | --- |
| Feedback 6: rear near-foot donor | `inputs.json` now selects the visible rear `foot_far` heel as the donor. The reusable `occluded_surface.py` binds the derived heel crop and registered near-foot solo by SHA-256. Visible ownership of the near foot remains empty. |
| Feedback 6: placement and fill | Translation only, bottom-center registration in source pixels: **(-66, -12)**. The donor's bottom row aligns with solo row **233**. Horizontal half-pixel registration uses nearest/ties-to-even, consistent with the existing whole-pixel derivation. No mirror, rotation, scaling or colour generation. **152** directly copied pixels plus **36** exact squared-Euclidean nearest donor pixels, with stable row/column ties. |
| Feedback 6: outline and dark-slab gate | The 188-pixel borrowed boot surface retains **22** outline pixels. It is classified separately from its additional tuck, which retains the existing non-outline rule. The existing **3×3** dark-slab test applies both in source space and to exposed native boot pixels; thresholds are unchanged. Transparent-boot and planted black-slab mutations fail. |
| Feedback 6: rest identity | Both full source assemblies match their approved paintings by **0 px**, including all underlays. Three registered solo fringe pixels lie outside the approved painting's opaque alpha: **(x=87,y=230), (87,231), (78,233)**. Filling those would contradict 0 px rest identity. They are clipped by the existing covered-fill policy, the closest implementation of the requested hidden foot. All remaining solo pixels are filled. |
| Feedback 6: integration | New rigid `hidden_foot_near` paint is parented to the existing `foot_near` / `hem_near` chain. It retains the **4 px** top tuck. Board, pre-battle and portrait consumers retain the existing v2 registration; the production rear layout includes the new surface. All presented bone samples retain the existing parent, planted anchors and move progression. |
| Original §1 cut / §2 meshes | Ten logical pieces, fused materials and the three garment fields are unchanged. No mesh topology or weights changed. |
| Original §3 tucks / §4 runtime | Only the approved occluded boot is added; its covered continuation uses the common foot rule. Runtime scripts, contacts, snapping, IK/FK, action data and the idle seed are unchanged. Both-view **1,258** bone samples pass. |
| Original §5 production / §6 gates | Promoted rear assets and density provenance are refreshed. The focused suite retains idle, robe split, 2 px tuck, staff, hem, signed motion, stray, elbow, wrist, foot and shoulder/belt mutations. Current native acceptance remains pending the director's renderer; no CPU mesh oracle or stale capture rebinding was added. |

The existing density processing runs after exact source derivation. It changes **four RGB texels** in the new production PNG (three base pixels and one extra tuck pixel), preserving alpha and outline pixels. This is the established Seer cleanup, not a new colour rule or exception. Full values and donor hashes are recorded in `proof/feedback6/donor_trace.json`.

## Files changed

See `feedback6_files.txt` for the exhaustive list. Principal files:

- `tools/humanoid_cutout/occluded_surface.py`: approved fully occluded surface derivation and independent donor gate.
- `source_view.py`, `rr10_build.py`: keep visible ownership empty, add the approved boot surface and top tuck, and transport its hem seam proof mask.
- `gates.py`, `promotion.py`: preserve source boot outlines while retaining continuation checks, apply the existing slab rule, omit authoring provenance from the production closure.
- Case `inputs.json`, `cutout.json`, rear layout, paint/check/tuck/seam masks and headless proof reports.
- Production rear layout/PNG/import metadata, Seer integration record, and the one new untouched density source with registry/output records.
- `tests/test_rr10_occluded_foot.py`: five source, pose, rest and physical mutation regressions.

**Existing runtime hooks changed this round: none.** Front case and production paint/layouts, all protected paintings/masks/motion/delivery inputs, and other creature assets remain unchanged.

## Observed headless proof

| Check | Exact result / log |
| --- | --- |
| Build | `RR10 FRONT BUILD: PASS (rest mismatch: 0 px; 3 joint_meshes; protected tracks byte-identical)`; `RR10 REAR BUILD: PASS (rest mismatch: 0 px; 3 joint_meshes; protected tracks byte-identical)`; `RR10 TUCK COVERAGE: 0 missing source pixels (both views; see proof/build.json)` — `/private/tmp/rr10-feedback6-build.log` |
| Density paint | `ADOPTED 1 source file(s)` / `PROCESSED 167 file(s)` / `RR10 DENSITY PAINT: PASS (both views adopted/processed; native rest records pending director)` — `/private/tmp/rr10-feedback6-density-initial.log` |
| Actual runtime bones | `RR10 BONE SAMPLES: PASS (1258 poses; headless transforms only)` — `/private/tmp/rr10-feedback6-samples.log` |
| Source/bone gates | `RR10 BONE/CUT GATES: PASS (0 errors)` — `/private/tmp/rr10-feedback6-gates-final.log` |
| Focused regressions | `Ran 50 tests in 44.488s` / `OK` — `/private/tmp/rr10-feedback6-focused-final.log`. After closing a test image handle for Windows compatibility: `Ran 5 tests in 0.631s` / `OK` — `/private/tmp/rr10-feedback6-donor-tests-final.log`. |
| Native probe load only | `RR10 NATIVE PROBE LOAD: PASS` — `/private/tmp/rr10-feedback6-native-load.log`; texture/geometry/mask load checks, no rendered pixels. |
| Standalone production package | `RR10 PRODUCTION PACK: PASS (2 views; source-only PNG loading; editor=false)` — `/private/tmp/rr10-feedback6-pack.log`; `proof/production_pack/rr10.pck`. |
| Full Godot suite | `TEST REGISTRATION AUDIT: PASS (744 scripts; full suite=400, quarantined=29, windowed probe=315)`; `MAIN BODY ASSERTIONS: 378906`; `FULL SUITE RUNTIME: 361.633 seconds (budget 900 seconds)`; `TEST RESULT: PASS` — `/private/tmp/rr10-feedback6-godot-full.log`. |
| Full Python suite | `Ran 926 tests in 816.700s` / **`FAILED (failures=1, skipped=63)`** — `/private/tmp/rr10-feedback6-python-full-final.log`. Sole failure: `test_shipped_derivations_and_manifest_are_current`, naming the four missing native density rest records (two active v2, two preserved legacy). All other tests pass or skip. |
| Whitespace | `git diff --check`: exit **0**. |

The first focused run rejected a new slab fixture because `(18,18,23)` is not an outline colour in this rear painting. The fixture now uses the approved heel's actual black `(0,0,0)`. No gate threshold changed. The initial full Python run was interrupted before completion to restart with that corrected fixture; it is not reported as a suite result.

Reproduction commands:

```sh
python3 experiments/cutouts/hoarfrost_seer/rr10_build.py
python3 experiments/cutouts/hoarfrost_seer/rr10_density.py
python3 tools/godot_task_runner.py --task-id rr-10 --stream -- godot --headless --path . --script tests/rr10/samples.gd
python3 -B experiments/cutouts/hoarfrost_seer/rr10_gates.py
python3 -m unittest discover -s tests -p 'test_rr10*.py' -v
python3 tools/godot_task_runner.py --task-id rr-10 --stream -- godot --headless --path . --script tests/rr10/native_capture.gd -- --output /private/tmp/rr10-feedback6-probe-load --validate-only
sh experiments/cutouts/hoarfrost_seer/rr10_pack.sh
python3 tools/godot_task_runner.py --task-id rr-10 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

Diagnostic source crops, not renderer proof: `proof/feedback6/painting_feet.png`, `far_feet.png`, `near_feet.png`, `donor_preview.png` and `donor_trace.json`.

## Proof for the design owner

Run in this order from this worktree. All windowed stages remain **unrun** here, per the worker's window-server restriction. Density must precede captures because rest recording changes input bindings.

```sh
sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh density
sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh rest
sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh native
sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh sheets
sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh idle
sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh production
sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh review
```

`density` runs the existing forced two-view native rebaker through `visual_probe_runner.py`, then `process_board_density.py --record-rests --only hoarfrost_seer_cutout`, the runner-wrapped shadow cache generator, density check and `rr10_density.py seal`. The worker has not fabricated records for the two active and two preserved rest paths.

Expected captures under `experiments/cutouts/hoarfrost_seer/rr10/proof/`:

- `native_rest/rest_pair.png`, `native/frames.json`, `native_gates.json` (required **0** native errors).
- `contact_sheets/front_<clip>_3x.png` and `rear_<clip>_3x.png`, every presented frame.
- `seer_protagonist_idle.mp4`: board scale, 2× nearest, #1E1E24, five loops.
- `production_native/frames.json`: real production progression, 1920×1080 / 100% UI scale.
- `hoarfrost_seer_review.mp4`: front left/rear right, 2× nearest, #1E1E24, clip label centered, idle ×3 / move ×3 / other actions ×2 / death once plus 1 s hold.

The director owns the inspection fixture; feedback 6 requests no worker `inspection_fixture.py` command or sign-off.

## TODO_DESIGN placeholders

**None in current case data.** `TODO_DESIGN_rear_foot_near_hidden_paint` is removed from `inputs.json` and generated `cutout.json`. Historical handoffs retain the record of the former blocker.

## Chosen defaults

Only test/diagnostic values, stored as named fields:

- `FIXTURE_SLAB_YX = (225,73)`, `FIXTURE_SLAB_RGBA = (0,0,0,255)`, `FIXTURE_MOVEMENT_MIN_PX = 1` in the new test. The 3×3 patch size is the existing slab gate; transform tolerance reuses `EPSILON`.
- `DEBUG_FEET_CROP_XYXY = [50,210,165,252]`, `DEBUG_FEET_ZOOM = 6`, `DEBUG_DONOR_CROP_XYXY = [60,210,95,240]`, `DEBUG_DONOR_ZOOM = 8` in `proof/feedback6/crop_defaults.json`.

No new player-facing tuning, motion, timing, palette, font or camera value was chosen.

## Open issues

1. The three maquette fringe pixels are intentionally clipped as detailed above to retain exact approved rest identity.
2. Director native density rebake/records and the full windowed proof remain pending. Run the full Python suite again after the `density` stage to clear its sole failure. Source tests cannot certify posed mesh seam closure or the native composite. No current native PASS is claimed.
