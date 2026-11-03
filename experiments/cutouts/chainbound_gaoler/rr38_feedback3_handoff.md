# rr-38 feedback 3 handoff

Calibration is complete. Native fill/continuation acceptance remains blocked. Channel-specific maximum-budget work is incomplete; no claim of infeasibility for every channel combination is made. **No production paint, rig, motion channel, mechanic or other creature was changed.** All work remains uncommitted for the director. No peer review, sign-off or windowed launch was attempted.

## 1. Calibrate first — met

The original director log contains 314 raw errors, mapping to 263 distinct `(view, clip, frame, kind)` signatures on 125 poses. Duplicate floating-error renderings explain the different counts. The tracked candidate fixture `rr38/proof/feedback3_native_errors.json` contains every raw error, its canonical signature, both full-log/manifest hashes and exact sampled-pose hashes.

The CPU sweep previously omitted the native source-space pocket classifier, strict detached-source provenance, released-item component policy, and pocket-to-missing-pixel union. It also used float source skin weights instead of Godot's packed UNORM16 weights. The optional `CpuPose(native_skin=True)` path now uses the existing native mesh oracle for both pieces and proof masks. Existing callers retain `False` and their existing raster behavior.

`tests/test_rr38_feedback3.py` reconstructs round 2 from tracked `0fd3939eb` blobs in an ignored proof copy, generates fresh Godot poses, verifies all 125 pose hashes, and runs bounded CPU shards. It never reads retained ignored proof logs. A lost frame/kind signature fails the test.

Observed result:

```text
RR38 CPU/NATIVE CALIBRATION: PASS (263/263 frame/kind signatures; 314 native errors; 0 misses)
```

The final standalone receipt is `rr38/proof/logs/feedback3/calibration_final/calibration.json`; its longest shard was 5.877483 s. The small tracked `rr38/proof/feedback3_receipts.json` binds this full log by hash.

## 2. Floating pieces / fills — traced; blocked

Read-only native ownership analysis found 65 unmatched component records. Summed across their presented frames, the visible owners are:

| Owner | Presented pixels | Finding |
|---|---:|---|
| `coat_far` | 898 | Original rear coat paint, including the detached 53-source-pixel island. Removing it would change the approved rest. |
| `foot_far` | 42 | Original boot-edge paint detaching during motion in both views. |
| `hidden_arm_far` | 17 | A single generated source texel `(104, 62)` repeated by skin deformation in front reel frames 29, 30, 32–35 and 42. |

The UV trace corrected an initial four-target attribution: the four round-2 shoulder continuation targets do **not** cause this speck. They remain unchanged. The single actual generated texel was tested for removal only in proof copies. Removal triggers the independent source gate:

```text
tuck: missing actual texels: arm_far
```

`rr38_prune.py` is explicitly a rejected experiment, restricted to proof copies. Its regression proves the immutable required tuck is not waived. No failing deletion was retained in source or production.

The native flat blocks are also retained as real evidence, not labeled CPU artifacts. The four director-named frames have fresh native-only flat diagnostics and 4× full-figure crops under `rr38/proof/logs/feedback3/native_judged_frames/`. Counts are 13 flags for front move 12, 17 for press 13, 10 for death 37, and 8 for reel 33. For example, front move 12's exposed `hidden_leg_far` region has 79 pixels, variance ratio 0.08163; several smaller regions have zero variance. Press 13 includes zero-variance `hidden_leg_far` and `hidden_coat_near` regions. No procedural replacement was attempted after the director's rejection.

Full component ownership, per-frame crops and hashes: `rr38/proof/logs/feedback3/fill_sources/fill_sources.json`. Native figure crops:

- `rr38/proof/logs/feedback3/native_judged_frames/front_move_12_native_4x.png`
- `rr38/proof/logs/feedback3/native_judged_frames/front_press_13_native_4x.png`
- `rr38/proof/logs/feedback3/native_judged_frames/front_death_37_native_4x.png`
- `rr38/proof/logs/feedback3/native_judged_frames/front_reel_33_native_4x.png`

## 3. Motion limits — tested; stopped for underlay

The corrected search uses the original, unchanged round-2 treated paint and continuation recipes. It generates fresh IK poses for each candidate. It scales the clip's non-chain channels uniformly toward rest, keeping chain angle, release and floor-drop semantics intact. Each scale is rejected at the first tearing witness. A witness pass is never treated as full-frame acceptance.

Both clips rejected all 21 tested **common** scales, descending from `1` to `2/3` in `1/60` increments. This is a discrete search, **not a proof about every intermediate real-valued scale**. No tear-free maximum was found or applied. Production retains its approved channels at scale 1; these are still visually defective.

| Clip | Tested floor scale | Resulting target peaks at that scale | Failing witness |
|---|---:|---|---|
| press | 2/3 | Near-hand lift 14.6667 px, forward 12 px; torso lean 4.6667°, forward 4 px; hip drop 2.6667 px | Front frame 14: 9-pixel knee pocket, bbox `[298,371,301,378]` |
| death | 2/3 | Hip drop 10 px; far-hand lift −24 px; torso lean 12°, forward 4 px | Front frame 37: 23-pixel far-shoulder seam, bbox `[260,277,263,286]` |
| death end | 2/3 | Same 10 px hip drop, feet planted | Front frame 95: 2-pixel knee pocket, bbox `[290,379,291,381]` |

The provisional press 0.70 candidate cleared the first six witnesses in an earlier pass, but a full 102-frame sweep rejected it: eight front seam/missing frames and six rear detached/floating frames. The corrected search includes the newly identified rejecting witness. Its motion was not promoted.

Canonical corrected full search logs:

- `rr38/proof/logs/feedback3/limits_press_final/search.json`
- `rr38/proof/logs/feedback3/limits_death_final/search.json`

Underlay receipts, 4× with 12 px context:

- `rr38/proof/logs/feedback3/handoff_crops/press_floor_front_14_0_4x.png`
- `rr38/proof/logs/feedback3/handoff_crops/death_floor_front_37_0_4x.png`
- `rr38/proof/logs/feedback3/handoff_crops/death_floor_front_95_knee_0_4x.png`

A common-scale failure does **not** establish an independent-channel budget. Additional independent tests were therefore run:

- Press: hand lift scale `10/22`, forward scale `12/18`, hip-dip scale `0`, other channels unchanged. Full result: `RR38 CPU SWEEP: PASS (102 frames; 0 findings; 509 flat regions; native=False)`. This demonstrates a feasible minimum for hard pixel gates, not a maximum amplitude or native visual acceptance. The remaining flat warnings were not waived.
- Death at 10 px hip drop: pelvis forward, torso lean/forward and head lean set to rest; far-hand lift scale `2/3` (−24 px peak). Selected shoulders clear, but front frame 95 retains a 2-pixel knee pocket `[290,378,291,380]`.
- Death at the full 15 px hip drop with those other channels relaxed: full result `RR38 CPU SWEEP: FAIL (192 frames; 124 findings; 1088 flat regions; native=False)`. Seams/missing pixels occur on 29 front and 2 rear frames. Endpoint-only tests at 0.25 px intervals from 15 down to 10 show several clear endpoints, so checking only the last pose would give a false pass. Full failure-frame lists and all log hashes are in the tracked receipts.

Reproduce independent candidates with `rr38_channel_probe.py` and `rr38_feedback3_channel_probes.json`, then use `rr38_sweep.py --clips press` or `--clips death`. The independent full logs are:

- `rr38/proof/logs/feedback3/independent_floors/press/proof/logs/cpu_sweep.json`
- `rr38/proof/logs/feedback3/death_hip_budget/drop_15.00/proof/logs/cpu_sweep.json`
- `rr38/proof/logs/feedback3/death_hip_budget/report.json` (endpoint survey)

Reel, movement and every production clip retain scale 1. No channel-specific maximum or safe production clamp is claimed. The unresolved native flat surfaces and original coat/boot continuation require the director's painted-underlay or cut/ownership decision; the brief forbids a further procedural repaint. No destructive deletion or arbitrary clip retuning was retained to hide those failures. The original native failures remain open.

## 4. Focused verification — worker checks met; native acceptance pending

Commands run:

```sh
python3 -B -m unittest tests.test_rr38_gaoler tests.test_rr38_feedback1 tests.test_rr38_feedback2 tests.test_rr38_feedback3 tests.test_rr39_native_ties
python3 -B -m unittest tests.test_godot_sidecars
python3 tools/godot_task_runner.py --task-id rr-38 --stream -- godot --headless --path . --script tests/rr38/runtime_checks.gd
python3 tools/godot_task_runner.py --task-id rr-38 --stream -- godot --headless --path . --script tests/prepared_unit_canvas_equivalence_test.gd
python3 -B experiments/cutouts/chainbound_gaoler/rr38_evidence.py --refresh
python3 -B experiments/cutouts/chainbound_gaoler/rr38_gates.py
sh -n experiments/cutouts/chainbound_gaoler/rr38_proof.sh
git diff --check
```

Observed result lines:

```text
Ran 38 tests in 252.753s
OK
Ran 19 tests in 1.749s
OK
RR38 RUNTIME: PASS (239 checks; headless registration, views, portraits and clocks)
V2 BOARD SPRITE GEOMETRY: {"cases":88,"errors":[],"native":false,"orientation_mutations_rejected":0,"placement_mutations_rejected":0}
PREPARED UNIT CANVAS RESULT: {"cases":64,"checks":4864,"errors":[],"native":false,"orphans":0,"pixel_differences":[]}
RR38 ALL GATES: PASS (0 unique errors; native=False)
RR38 ORIGINAL NATIVE EVIDENCE: PASS (44600 hashed rows; 0 changed)
```

The independent candidate results above are additional focused probes, not production changes. The headless all-gates result concerns structural/motion gates; it does not override the failing CPU pixel searches or the director's 314 native errors. The direct invocation of the `RefCounted` helper `tests/rr40/board_sprite_geometry.gd` produced no test result and was canceled (exit 130); the correct standalone prepared-canvas entry point above then passed. An initial new mutation-test fixture omitted `compiled_motion.json`; that setup was fixed, and the final focused run is green. No existing failure assertion was changed. Full Godot/Python suites were not rerun, per feedback 3.

Complete final test output is copied to `rr38/proof/logs/feedback3/{focused,sidecars,runtime,canvas,gates,calibration-final,source-samples}.log` and hash-bound in the tracked receipts. All Godot invocations used the task runner. No engine/editor scan was used as a parser check.

## Proof for the design owner

From the worktree root, exact requested windowed commands:

```sh
sh experiments/cutouts/chainbound_gaoler/rr38_proof.sh native
sh experiments/cutouts/chainbound_gaoler/rr38_proof.sh sheets
sh experiments/cutouts/chainbound_gaoler/rr38_proof.sh production
sh experiments/cutouts/chainbound_gaoler/rr38_proof.sh review
```

These remain 1920×1080 / 100% UI scale via the existing visual-probe contracts. They were not run here. Native/sheets/review now use `rr38/proof/native_feedback3/`, `rr38/proof/feedback3_contact_sheets/`, and `rr38/proof/logs/feedback3/native_current_gates.json`, preserving the original round-2 capture and log. Review still writes the required `rr38/proof/chainbound_gaoler_review.mp4`. No fresh review MP4 or native pass is claimed. Existing defects are expected until the director supplies the pending continuation decision/art.

The other existing stages remain available unchanged:

```sh
sh experiments/cutouts/chainbound_gaoler/rr38_proof.sh density
sh experiments/cutouts/chainbound_gaoler/rr38_proof.sh rest
sh experiments/cutouts/chainbound_gaoler/rr38_proof.sh idle
```

No inspection fixture is prepared in this round; the task split assigns that to the director.

## TODO_DESIGN / open issues

These are plain data fields in `rr38/proof/feedback3_receipts.json`, not invented runtime values:

- `TODO_DESIGN_front_shoulder_underlay`
- `TODO_DESIGN_front_knee_underlay`
- `TODO_DESIGN_front_leg_coat_underlay`
- `TODO_DESIGN_detached_coat_boot_continuation`

They cover the required-tuck/death shoulder conflict, press/death knee pockets, native flat leg/coat fills, and original coat/boot components. The director's 2–4× judgment remains acceptance.

## Chosen defaults

Only proof values were chosen: scale denominator 60, crop context 12 px, crop enlargement 4×, four-frame CPU shards, two calibration workers, 90 s child timeouts and 128-triangle raster batches. Search witness frames are named in `WITNESSES`, drawn from the measured native/sweep failures; they do not affect playback. Maximum measured corrected search frame-process time was 1.157396 s. Independent proof-only channel factors are named in `rr38_feedback3_channel_probes.json`: press lift `10/22`, forward `12/18`, hip `0`; death hip `2/3` (or 1 for the full-clip experiment), forward/torso/head `0`, far-hand lift `2/3`. No player-facing default was chosen.

## Files changed

- `tools/humanoid_cutout/cpu_pose.py`: optional packed-skin switch; defaults unchanged. This is the only shared change.
- `rr38_frames.py`, `rr38_cpu_diagnostics.py`: calibrated native-equivalent CPU checks.
- `rr38_calibrate.py`, `rr38_calibration_case.py`, `tests/test_rr38_feedback3.py`, `rr38/proof/feedback3_native_errors.json`: fresh historical reconstruction, exact pose binding, superset regression and rejected-removal mutation.
- `rr38_fill_sources.py`, `rr38_prune.py`, `rr38_feedback3_pruning.json`, `rr38_limit_search.py`, `rr38_channel_probe.py`, `rr38_feedback3_channel_probes.json`: ownership receipts and bounded, proof-only failed experiments.
- `tests/rr38/samples.gd`, `rr38_sweep.py`: optional focused clip/frame filters; default behavior retained.
- `rr38_proof_case.py`: explicit case/assets/output parameters so historical reconstruction stays isolated.
- `rr38_proof.sh`, `rr38/.gitignore`: preserve round-2 evidence; ignore new capture/sheet outputs.
- `rr38/proof/samples.json`, `rr38/proof/cpu_poses.json`, `rr38/proof/feedback3_receipts.json`, `rr38_feedback3_contract.json`, this handoff: compact proof bindings and acceptance/open-issue records.

No new `.gd` file or `.uid` was introduced. `tests/rr38/contextual.gd.uid` is already tracked; the sidecar guard passes. All new source/fixture/report files are left untracked for the director to add and commit. Native PNGs, full proof logs and generated crops remain ignored.
