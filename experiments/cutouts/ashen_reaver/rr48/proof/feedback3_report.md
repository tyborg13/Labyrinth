# rr-48 feedback 3 implementation

All implementation changes are uncommitted. The director-started merge remains open; the five conflicted files have no conflict markers. Native proof for this revision is pending the director.

## Requirements

| Requirement | Implementation and observed proof |
|---|---|
| 0. Runtime unification | Integration compiler, elbows and held-follow are the production defaults. Reaver opts into body-frame follow with pelvis/hand displacement, 35° limit and zero at move endpoints. Grip, painted floor/drop, presentation anchor and gait bend side remain generic opt-ins. Old humanoid_arm_policy.gd retired. Exact int-07 additive_extensions.json is unchanged; Reaver byte deltas normalize through exact runtime provenance, and mutations still fail closed. |
| 1. Native ground truth | Before paint changes, the frozen round-2 CPU sweep contains every native finding: 179 hole frames, 225 pockets, 3,281 part-outline records; no misses, both views and every clip. The separate native pixel/source-UV replay certifies all 3,281 outline records. |
| 2. Exact dark paint | Case-owned native/CPU surface policy accepts exact same-coordinate director underlay or approved-paint cap RGBA. Final source and production each report 21,913 accepted outline pixel/frame occurrences in 3,867 part/frame records; zero non-director outline pixels and zero blocking dark slabs. The 3×3 slab gate remains strict. |
| 3. Whole-body underlay | Every opaque director underlay texel is allocated once by the receiver partition, then transported with its receiving bone beneath visible pieces. Tucks/caps duplicate only exact registered director paint. Natural air uses the whole underlay through actual skin/rigid inverse UVs, independently of the ownership masks. 249 measured missing source UVs plus 21 shortest painted support-path texels close the gaps without isolated paint. |
| 4. Walk arms | Near arm restored to 14° and far arm to 9°, both scale 1.0. Legs also retain scale 1.0. Below-1.0 near-arm mutation fails. No new painted-motion clamps. |
| 5. Remaining tears | Final independent source and production sweeps each pass all 844 frames: zero blocking tears, detached paint, premature item releases, non-director outlines or 3×3 slabs. Six small/short tears are listed below; every run is at most two frames and every pocket at most 2 px. All 28 measured excursion profiles remain 1.0. |
| Keep | Elbows: 2,552 checks, maximum hyperextension 1.959927°, within the 2° limit. Source/production each pass 710 painted-grip and 144 floor checks. Final floor angle: −90° front, +90° rear (floating-point output ±90.0000017°). Signed direction, gait/knees, supports, idle, reach reporting and production routes pass the overall gate. The Guardian mechanics and tuning are unchanged. |

The integration body reference reproduces round-2 pelvis-relative displacement arithmetic. The integration elbow/pendulum implementation changes the rear hand trajectory slightly: migration comparison records a maximum presented follow-angle difference of 1.5000005° before the explicitly requested walk restoration. The selected reference frame remains body; root travel contributes no tilt.

## Accepted short tears

| View | Clip | Frame | Joint | Pixels | Bbox, native-origin CPU coordinates |
|---|---|---:|---|---:|---|
| rear | move | 9 | cloth_front_root | 2 | [306, 353, 307, 355] |
| rear | move | 15 | cloth_front_root | 1 | [319, 362, 320, 363] |
| rear | move | 16 | cloth_front_root | 1 | [321, 363, 322, 364] |
| rear | move | 29 | cloth_front_root | 1 | [349, 375, 350, 376] |
| rear | move | 35 | cloth_front_root | 1 | [362, 383, 363, 384] |
| rear | death | 81 | wrist_near | 1 | [259, 309, 260, 310] |

No blocking tear remains for native judgment at an excursion floor. The six listed records pass only the director's ≤4 px, ≤3 consecutive-frame rule; no component or material finding is waived. Full source/production records also list 4,010 natural-air pockets each, including their bounds.

## Native calibration by view and clip

| View | Clip | Native hole frames | Native pockets | Native part-outline records | CPU misses |
|---|---|---:|---:|---:|---:|
| front | death | 47 | 52 | 223 | 0 |
| front | fall | 25 | 37 | 163 | 0 |
| front | hit | 4 | 7 | 13 | 0 |
| front | idle | 0 | 0 | 0 | 0 |
| front | move | 0 | 0 | 155 | 0 |
| front | rake | 29 | 36 | 146 | 0 |
| front | sweep | 33 | 40 | 135 | 0 |
| rear | death | 5 | 5 | 611 | 0 |
| rear | fall | 17 | 25 | 556 | 0 |
| rear | hit | 1 | 1 | 59 | 0 |
| rear | idle | 0 | 0 | 48 | 0 |
| rear | move | 0 | 0 | 345 | 0 |
| rear | rake | 13 | 17 | 416 | 0 |
| rear | sweep | 5 | 5 | 411 | 0 |

The archive actually contains 709 outline frame findings plus 179 hole frame findings, totaling the reported 888 errors. The director diagnostic expands those outline frames to 3,281 per-part records. Calibration uses conservative CPU pocket/outline bounds and counts; the outline replay additionally compares actual native black texels to legal exact source UVs.

## Clamp values

There are no new painted-joint clamps. The 24 previously accepted binding-spec angular clamps remain below; the protected director JSON is imported byte for byte. Every record retains its budget_note. Runtime held-follow limit events, with target and clamped angles, are in gates.json/dynamic_budget_clamps.

| View | Clip | Channel | Phase | Director target | Binding clamp |
|---|---|---|---:|---:|---:|
| front | rake | torso.lean_deg | 0.5 | -10 | -4 |
| front | rake | torso.lean_deg | 0.7 | -11 | -4 |
| front | sweep | torso.lean_deg | 0.28 | 5 | 4 |
| front | sweep | torso.lean_deg | 0.45 | -8 | -4 |
| front | sweep | torso.lean_deg | 0.6 | -9 | -4 |
| front | sweep | torso.lean_deg | 0.75 | -9 | -4 |
| front | fall | falchion.angle_deg | 0.3 | 70 | 35 |
| front | fall | falchion.angle_deg | 0.5 | -40 | -35 |
| front | fall | falchion.angle_deg | 0.85 | -40 | -35 |
| front | fall | torso.lean_deg | 0.3 | 6 | 4 |
| front | fall | torso.lean_deg | 0.5 | -14 | -4 |
| front | fall | torso.lean_deg | 0.85 | -14 | -4 |
| rear | rake | torso.lean_deg | 0.5 | 10 | 4 |
| rear | rake | torso.lean_deg | 0.7 | 11 | 4 |
| rear | sweep | torso.lean_deg | 0.28 | -5 | -4 |
| rear | sweep | torso.lean_deg | 0.45 | 8 | 4 |
| rear | sweep | torso.lean_deg | 0.6 | 9 | 4 |
| rear | sweep | torso.lean_deg | 0.75 | 9 | 4 |
| rear | fall | falchion.angle_deg | 0.3 | -70 | -35 |
| rear | fall | falchion.angle_deg | 0.5 | 40 | 35 |
| rear | fall | falchion.angle_deg | 0.85 | 40 | 35 |
| rear | fall | torso.lean_deg | 0.3 | -6 | -4 |
| rear | fall | torso.lean_deg | 0.5 | 14 | 4 |
| rear | fall | torso.lean_deg | 0.85 | 14 | 4 |

## Files changed

Exact per-file inventory: [feedback3_files.json](feedback3_files.json). It separates round-3 owned-path changes from the shared Reaver deltas relative to the sync target; the many inherited integration changes are the director's merge.

- Source/art/data: ../layouts, pieces, checks, ownership, seams, tucks and source; ../feedback3_policy.json, ../feedback3_joint_caps.json and ../feedback3_joint_budgets.json; generated production counterparts under assets/units/ashen_reaver_cutout/humanoid_v2; only Reaver registration, density and shadow records.
- Case helpers: rr48_feedback3_build/source/caps/cpu/policy/sweep/native/contract/sheets/outline_calibration.py, and focused updates to the existing source, motion, density and gate helpers.
- Unified shared code: humanoid_motion.gd, humanoid_presentation.gd, humanoid_held_follow.gd, humanoid_grip.gd, presentation.gd; cpu_pose.py and the opt-in native-gate callback. compiler.py uses integration unchanged. No creature name in shared runtime code.
- Tests/proof: tests/test_rr48_reaver.py, tests/rr48/raster_samples.gd and existing samples/follow/provenance/inventory helpers; tests/rr46/preservation.py retains the exact int-07 mechanism. tests/fix18/rest_provenance.py and the helper in tests/test_rr41_feedback3.py route exact pinned Reaver deltas without changing existing assertions. Old arm-policy references removed from the helper inventories. The 428 new sidecars are enumerated separately in feedback3_sidecars.json.

## Tests and probes

- `RR48 CALIBRATED CPU SWEEP: PASS 844 frames; 0 remaining tears; 6 accepted short tears; Counter()` — independently source and production.
- `RR48 ELBOW GATE: PASS (2552 checks; maximum hyperextension 1.959927 deg)`; `RR48 OVERALL GATE: PASS`.
- Focused final module: `Ran 17 tests in 170.430s`, `OK`. After final support-path changes, all six affected paint/material/cap/motion tests pass: `Ran 6 tests in 4.367s`, `OK`. The mandated mutations reject changed underlay RGBA, non-director exposed outline, exact-director exposed 3×3 slab, a false negative-space claim, reduced near-arm walk, changed cap, outside-tuck cap, detached falchion and reversed floor path.
- `INT07 OTHER RIGS: PASS (664/664 submitted states byte-identical to ff77c892c; 12 rigs; both views; every clip)`.
- `RR49 EXACT IDENTITY: PASS (8364 poses; 304685 polygon buffers; actual one-vertex mutation caught)`; submission timing, cache mutations and reload pass.
- `RR46 chainbound_gaoler PRESERVATION: PASS (279 protected files)`; exact 80-file integration extension audit and all 80 same-file byte mutations pass.
- `RR48 EARLIER RIG PARITY: PASS (all earlier humanoid production frames byte-identical)` — 10 earlier humanoids, 8,086 frames; compiled data unchanged.
- `RR48 HEADLESS DEPTH: PASS (2 boards; 496 routes; 26784 samples; 104980 prop comparisons; native pixels=false)`.
- `RR48 STRIKE REGISTRATION: PASS (1808 checks; production registry and every supported facing)`.
- `SFX SYNC HARNESS RESULT: PASS (4243 observations, 0 failures)`; `PASS (3516 observations, 0 failures)`; `PASS (1688 observations, 0 failures)`.
- Registration: `TEST REGISTRATION AUDIT: PASS (918 scripts; full suite=550, quarantined=29, windowed probe=339)`. Resource audit: `ISOLATION AUDIT: 264 modules`, exit 0.
- Protected director inputs: nine provenance hashes match. Exact source and production supply: 35,752 texel checks each; 2,030 approved-paint cap texels each. `RR48 NATIVE PROBE LOAD: PASS` is headless validation only.

Final full Python: `Ran 2539 tests in 3055.936s`; `FAILED (failures=6, errors=3, skipped=66)`. The final Reaver module completes without failures (`MODULE test_rr48_reaver: 285.948s`), including the required mutations. The first post-fix attempt exhausted the default 2,400-second shard deadline and encountered sandbox `os.killpg` PermissionError during cleanup. The completed retry uses a 6,000-second shard deadline based on the measured negative-fixture workload; fixture assertions and their own deadlines are unchanged.

Full Godot: `MAIN BODY RUNTIME: 370.391 seconds`; `MAIN BODY ASSERTIONS: 495984`. The outer command reached its 900-second deadline (exit 124) after 239 supplemental programs passed, one timed out and 24 were interrupted/not started. Only those 25 programs were then run through `tools/program_suite_runner.py` with unchanged per-program limits: 24 pass, and `HERO FACING TEST: FAIL (76 checks)` reports the known Frostbite fixture. `threats_at_rest_test` passes in the continuation. Combined coverage is the main body plus all 264 supplemental programs, with 263 passing and one known fixture failure; no whole-suite PASS is claimed. The three known GameData compile failures were not observed in the completed program logs.

Every final failure counterpart was checked on the refreshed `codex/peer-benchmark` snapshot **133e8da4e**: `Ran 9 tests in 15.754s`, `OK`, and `HERO FACING TEST: PASS (76 checks)`. The seven director-listed Python sync failures and Frostbite failure belong to the older 6135c6ec6 sync target; their integration fixes are not copied into this unit. Detailed traces, baseline commands/results and earlier attempts: [feedback3_full_suites.json](feedback3_full_suites.json). Complete supplemental coverage: [feedback3_godot_programs_final.json](feedback3_godot_programs_final.json). Logs: logs/feedback3_final/. No new native captures were attempted.

| Final failure/error | Worktree disposition | Integration 133e8da4e |
|---|---|---|
| board density: shipped derivations/rest record | New Reaver composite needs director native rebake | PASS |
| tracked Godot sidecars | 428 prepared; Git-index writes belong to director | PASS, revision-tree inventory |
| rr-46 Lancer input preservation | Known sync issue; untouched | PASS |
| rr-46 historical runtime pin | Known sync issue; untouched | PASS |
| rr-46 motion/reference input preservation | Known sync issue; untouched | PASS |
| rr-46 native archive inventory | Known sync issue; untouched | PASS |
| pt14-04 runtime boundary | Known sync issue; untouched | PASS |
| rr-47 feedback1 setUpClass | Known sync issue; untouched | PASS, class setup exercised |
| rr-47 feedback2 native route | Known sync issue; untouched | PASS |
| Godot hero_facing_test: Frostbite damage fixture | Director-listed known fixture; untouched | PASS, 76 checks |

Final scope audit: `RR48 FINAL SCOPE: PASS (9 protected hashes; 2 exact imports; integration compiler/80-file manifest exact; earlier assets unchanged; 5 conflict files resolved)`. `git diff --check` exits 0. The merge index remains intentionally open.

## Certificate and metadata corrections from the initial full run

The initial full Python run completed 2,539 tests in 1,957.256 seconds: `FAILED (failures=10, errors=5, skipped=66)`. Its complete traces are preserved in feedback3_full_suites.json.

The Lancer rest normalizer now routes the exact Reaver source delta before the existing integration/fix-18 transformations. The original fix-18 manifest is restored byte for byte from the sync target; the Reaver presentation addition is pinned in its own manifest. Existing complete-pose and source-mutation assertions are unchanged. `Ran 9 tests in 204.945s`, `OK`, including all four real certificate mutations and fix-18 regressions.

Density calibration now measures the preserved untouched source, retaining the existing 0.87/0.96 grids. `Ran 1 test in 1.255s`, `OK`. The new composed rests still need the director's native rebake; no CPU composite was recorded as native proof.

A purposeful headless metadata import generated 428 new unit-owned sidecars. All 27,879 pre-existing metadata files remained unchanged; 2,071 generated files outside this unit were removed. The prospective tracked inventory passes with the actual prepared additions/deletions. The real Git-index guard still reports its 346 missing tracked siblings until the director stages them; this worker cannot write Git metadata. See feedback3_sidecars.json.

Earlier packed-resource controls passed on integration 85a114897 (306 and 217 assertions) but timed out after 300 seconds in this worktree, including quiet replays. An isolated diagnostic reached `pack.flush() == OK`, then stalled inside `ProjectSettings.load_resource_pack`, before board or cutout logic. Both cache probes were restored. The final full Python retry passes the packed-resource control/mutation modules, including all ten coverage mutations and their restored control; these transient timeouts are not final test failures. No UI assertions or fixture timeout limits were changed. The derived frozen runtime project is preserved outside the project tree at /private/tmp/rr48-r3-frozen-runtime-project; calibration source cases and saved native-origin poses remain in this proof folder.

## Captures

`RR48 FEEDBACK 3 CPU SHEETS: PASS (19 sheets; six native worst frames and every fourth front move frame)`. All 19 sheets were inspected. Index: [feedback3_sheets.json](feedback3_sheets.json). Captures: seam_cpu/feedback3/*.png, gitignored. Panels are round-2 native clean/old holes, then final production CPU clean/overlay. Magenta indicates remaining blocking tears; cyan indicates measured director-underlay air.

Six requested frames: front sweep 20, rake 20, fall 29, death 90; rear sweep 12, fall 20. Front move: frames 0–48 every fourth frame. The old native panels were generated before the director overwrites native/ with this revision.

## TODO_DESIGN placeholders and open issues

No active TODO_DESIGN placeholder remains. Historical round-0/round-1 reports and protected snapshots retain their historical labels.

Full director-underlay supply adds 106 front and 47 rear opaque source texels outside the original painting alpha. This follows feedback 3's whole-underlay rule; the original visible cut partition remains 0 px from the paintings, while the composed production rest is the new density-treated rest. Whole-underlay supply and 0 px composed-rest identity against the original painting cannot both hold with these approved inputs. Native density/rest proof for the new composite remains pending the director. No director input was repainted or rewritten.

The open sync merge is intentionally unstaged/uncommitted by this worker. The director owns merge completion, inspection fixture, review and publication.

## Chosen defaults

- CPU-only `rr48_feedback3_cpu.DEFAULTS.triangle_batch_size = 128` for proof batching.
- Sheet-only `rr48_feedback3_sheets.DEFAULTS`: padding 16 px, gutter 8 px, matte RGBA [30,30,36,255], tear outline [255,0,190,255], air outline [40,220,255,255].
- Diagnostic-only `feedback3_diagnostic_defaults.json`: packed-resource probe timeout 30 seconds; Python retry shard deadline 6,000 seconds, justified by observed 300-second negative controls plus the normal shard workload. Fixture assertions and per-fixture limits remain unchanged.
- Mutation-only `FEEDBACK3_DEFAULTS`: wrong-source outline RGBA [0,0,0,255], reduced walk scale 0.99. Existing process timeout remains 300 seconds.
- The raster origin [192,192] matches the native viewport; it is measured registration rather than a new design default. Cap support paths use only the shortest existing opaque director-paint connection; no new colour, motion or tuning value is introduced.

## Proof for the design owner

All windowed stages are director-only, 1920×1080, 100% UI scale. Run in this worktree:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-48
sh experiments/cutouts/ashen_reaver/rr48_proof.sh density
sh experiments/cutouts/ashen_reaver/rr48_proof.sh rest
sh experiments/cutouts/ashen_reaver/rr48_proof.sh native
sh experiments/cutouts/ashen_reaver/rr48_proof.sh seams
sh experiments/cutouts/ashen_reaver/rr48_proof.sh sheets
sh experiments/cutouts/ashen_reaver/rr48_proof.sh idle
sh experiments/cutouts/ashen_reaver/rr48_proof.sh production
sh experiments/cutouts/ashen_reaver/rr48_proof.sh review
sh experiments/cutouts/ashen_reaver/rr48_proof.sh depth
```

Exact individual native depth jobs (also run by the depth stage):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-48 && python3 tools/visual_probe_runner.py --task-id rr-48 --no-headless --display-driver macos --audio-driver Dummy --timeout 330 --expect-size 1920x1080 --proof-contract tests/rr46/depth_proof_contract.json --result-manifest experiments/cutouts/ashen_reaver/rr48/proof/logs/fire_t1_r6-depth-result.json tests/rr48/depth_probe.gd -- --board fire_t1_r6 --actor ashen_reaver --output experiments/cutouts/ashen_reaver/rr48/proof/native/depth/fire_t1_r6/ashen_reaver
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-48 && python3 tools/visual_probe_runner.py --task-id rr-48 --no-headless --display-driver macos --audio-driver Dummy --timeout 330 --expect-size 1920x1080 --proof-contract tests/rr46/depth_proof_contract.json --result-manifest experiments/cutouts/ashen_reaver/rr48/proof/logs/earth_t3_r7-depth-result.json tests/rr48/depth_probe.gd -- --board earth_t3_r7 --actor ashen_reaver --output experiments/cutouts/ashen_reaver/rr48/proof/native/depth/earth_t3_r7/ashen_reaver
```

Director-owned inspection fixture:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-48 && python3 tools/inspection_fixture.py --task-id rr-48 --scenario guardian --guardian-id ashen_reaver --guardian-case encounter --seed 83 --manifest /private/tmp/labyrinth-inspection-manifests/rr48-guardian.json --summary 'rr-48 Ashen Reaver action inspection' --launch
```

Full literal command inventory: [owner_commands.json](owner_commands.json). New headless diagnostics: rr48_feedback3_cpu.py --calibrate (frozen round-2 inputs), rr48_feedback3_sweep.py (source; production uses the matching --case/--samples/--canonical-samples arguments), rr48_feedback3_sheets.py. Main gate:

```sh
python3 experiments/cutouts/ashen_reaver/rr48_gates.py --samples experiments/cutouts/ashen_reaver/rr48/proof/feedback3_samples.json
```
