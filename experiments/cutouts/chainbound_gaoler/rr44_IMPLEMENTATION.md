# rr-44 — implementation for the director's native calibration round

Round-0 historical report. Current feedback-1 implementation and proof are in [rr44_FEEDBACK1.md](rr44_FEEDBACK1.md).

This is an uncommitted implementation on `codex/rr-44`. It is **not ready for
publication**. No windowed process, peer review, commit, task-queue change or
publication was performed. The director's protected staged files are unchanged.

## Acceptance criteria

1. **Art registration:** `mq3_front_v5` and `mq3_rear_v4` contain the supplied
   painting, raw, prompt and composite recipe byte for byte. The optional
   `gaoler_arm_rr44` replay verifies every input and runs an audited numerical
   implementation rather than executing a job's Python file. Both standalone
   replay checks pass. `rr44/proof/art_identity_review.png` is the gate sheet;
   its judgment belongs to the director. Production identity records point to
   the new sources.
2. **Maquette:** `experiments/cutouts/chainbound_gaoler/rr44/maquette/` contains
   the prepared surface-pose recipe and compiled native specification. Arm
   segment lengths and shoulder Z level are preserved. The front trace is
   fitted with one body's depth solutions; the rear remains the proper
   `diag(-1,-1,1)` half-turn, never an independently fitted or mirrored body.
   **Native IoU, centroid, mass/cloth and delivery recertification are pending:**
   the existing director Blender bridge has a `STOP` marker. The existing
   certified mq-15 delivery is preserved, not relabelled as a new delivery.
   `rr44/maquette/fit_status.json` explicitly records that limitation.
3. **Cuts:** both views are cut from v5/v4. Source-space assembly is **0 px
   mismatch front and rear**. The far sleeve uses the standard upper/fore skin;
   its glove is rigid. Chain and hook use one rigid held item with a separately
   registered painted grip. Front arm is below torso/cowl and above the far
   tail; rear camera-side arm is above body/tails; helm remains above arms.
   The chain is above body layers at reel/pin contact. Every limb, held-item,
   head, cloth, torso and pelvis footprint used by the exposure gate is derived from the
   new rest ownership. All source RGB/alpha comes from approved paint.
4. **Painted backing:** both director underlays are copied exactly inside the
   new arm/chain footprints (front also legs), through the density partition
   hook. The rear's known x121–142/y63–120 strip is deliberately uncertified
   for exposure, so exposed texels are flagged even when they exactly match
   the supplied underlay. The all-frame CPU gate retains painted/procedural,
   missing, flat-region and native-defect diagnostics with 4× CPU crops.
   **Flagged regions and missing tuck coverage remain for director judgment;
   no paint was synthesized to clear a gate.**
5. **Motion:** the protected rr-44 keys are imported unchanged. The optional
   elbow policy owns the IK side, the pendulum flex direction and constrained
   pixel rounding. Both arms use the director's shoulder pendulum and envelope.
   Hit uses the new hand tracks. Approved death channels remain identical to
   rr-42 except the specified far-hand lift; its measured floor drop uses the
   new chain endpoint and existing per-view sole line. The generated held-follow
   evaluator supports both possible displacement frames and has gain/lag
   mutation tests. **`TODO_DESIGN_held_follow_reference_frame` remains in the
   compiled data:** the formula does not specify whether root travel is included.
   The generated channel remains at its explicit zero placeholder until that
   design field is resolved; the protected director file is never rewritten.
6. **Budgets:** no new clamp is claimed before CPU ≥ native calibration.
   Director floors are recorded in `rr44_motion.py`. The sole retained clamp
   is the already approved death `coat_near_tip.lift_px`, 4 → 2.5 px in both
   views. New channel search/clamps, floor enforcement against actual tears and
   the fixture-bound native superset test require the director's first native
   frames and `native_gates.json`.
7. **Elbow gate:** fresh authored and presented samples pass in both views,
   including the actual native-capture origin. UV rounding changes pixel
   samples, not the signed joint geometry. The committed-file candidate
   `rr44/fixtures/rr42_elbows.json` binds the exact d7ed719d9 inputs and four CPU
   crops: press and hit fail in both views. Its SHA-256 is
   `1c0c0b2473955e4734d0764acc8ccdd75956b6e857e5ae5141c456286ffd4598`.
   Inverted-elbow and missing-policy mutations fail. Nine other rigs are
   report-only in `rr44/proof/other_elbows/` and its summary; none was changed.
8. **Gate bundle:** source/structure/ownership, signed bones, walk/support/reach,
   rigid chain/grip, draw order, pendulum, elbow and painted exposure are wired
   together. Original native diagnostics, hook occlusion and rr-40 four-facing
   geometry capture are retained in the director commands. **Native-clean
   acceptance, CPU ≥ native calibration and real-renderer geometry remain
   unverified.** A failing gate is retained as a failing gate.
9. **Records/routing:** density processing uses exact changed source texels and
   the prior approved production outside each partition. CPU production-rest
   equivalence is 0 px in both views, explicitly `native_pixels: false`.
   Shadow refresh replaces only the two Gaoler records. Identity/density/output
   records for all other units are unchanged. Production routing, combat,
   analytics, saves, input paths and timing boundaries are unchanged.

## Joint positions

Registered source pixels from the one native body (not independent rear fitting):

| Joint | Front | Rear |
|---|---|---|
| Far shoulder | (113.547962, 81.408507) | (144.452038, 98.074118) |
| Far elbow | (106, 110) | (152, 118.501484) |
| Far wrist | (94, 131) | (164, 149.756966) |
| Painted chain grip | (89, 145) | (170, 162) |

`experiments/cutouts/chainbound_gaoler/rr44/maquette/joints_source_px.json` and
`spec_native.json` retain the complete projected and 3D joint positions.

## Optional generic changes

- `tools/art_identity_gate.py` / `art_identity_gaoler_arm.py`: a bound,
  already-registered 255px recipe kind used only by the two new Gaoler jobs.
- `tools/humanoid_cutout/compiler.py`, `elbows.py`, `held_follow.py`: emit and
  validate the two optional motion fields; existing compiled reference sets
  remain equal.
- `humanoid_motion.gd`, `humanoid_gait.gd`, `humanoid_presentation.gd`, new
  `humanoid_elbows.gd`: opt-in IK, pendulum-side, generated held angle and legal
  nearest-pixel rounding. The full Transform2D assignment path is retained.
- `bone_contracts.py` / `gates.py`: optional facing bend expectation and a
  separately checked generated-angle contract. The matching Python/Godot
  isolated-probe dependency lists also bind the new elbow helper.
- Gaoler helpers `rr38_build.py`, `rr38_acceptance.py`, `rr42_density.py`,
  `rr42_exposure.py`: optional case roots, painted grip, task/timeout and
  supplied backing contracts. Their legacy defaults are unchanged.

The reference comparison emitted **10,294 byte-identical poses** across Seer,
Thrall, Mirror, Weaver, Mimic, Mortar, Herald, Gloam and Lancer. Its report-only
elbow findings are 2,351 arm/frame records with 82 witness crops. Every affected
clip's complete failing-frame list is retained in `other_elbows_summary.json`.

## Chosen defaults

Proof/numerical choices only: `rr44/chosen_defaults.json` records 12px crop
context, 4× crop zoom, 85s sample/shard limits, four frames per CPU shard, two
shard workers, 0.0001 serialized-matrix tolerance and 0.751° presentation-angle
tolerance (the existing 1.5° quantization plus numerical tolerance).
`rr44_maquette.FIT_NUMERICS` records the 0.25px front shoulder fit search and
0.0001° bend epsilon; its x107 bound is the measured front sleeve trace.
Test cases use unique temporary directories and named source-frame witnesses.
After both full suites finished, the remaining CPU proof used eight supervisor
workers on the 15 logical CPUs; `rr44/proof/headless_execution.json` records
that proof-only override. Individual shards retain four frames and the 85s
limit. The normal owner script defaults to two supervisor workers.
The full Godot invocation has an 1800s process deadline; the suite retains its
existing 900s acceptance budget. The final Python invocation uses the default
worker settings and the default 2400s shard deadline. An earlier attempt with
one sweep worker reached that deadline; its incomplete shard is not a full-suite
pass and no deadline was increased.

## Proof for the design owner

No windowed command was attempted. Run from this worktree, at 1920×1080 and
100% UI scale; the scripts use the existing proof contracts and visual runner:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-44 && bash experiments/cutouts/chainbound_gaoler/rr44_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-44 && bash experiments/cutouts/chainbound_gaoler/rr44_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-44 && bash experiments/cutouts/chainbound_gaoler/rr44_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-44 && bash experiments/cutouts/chainbound_gaoler/rr44_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-44 && bash experiments/cutouts/chainbound_gaoler/rr44_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-44 && bash experiments/cutouts/chainbound_gaoler/rr44_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-44 && bash experiments/cutouts/chainbound_gaoler/rr44_proof.sh review
```

`native` preserves a failing result for inspection. `sheets` and `review` save
diagnostic evidence even on gate failures; review never retries a stale capture.
Captures go under `rr44/proof/{native,native_rest,contact_sheets,idle_native,production_native}`;
review is `rr44/proof/chainbound_gaoler_review.mp4`, and the protagonist comparison
is `chainbound_gaoler_protagonist_idle.mp4`. Inspect front/rear walk, press, hit,
reel and death at 2–4× before directing repairs or approving any clamp.

When the existing Blender bridge is running:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-44 && python3 -B experiments/cutouts/chainbound_gaoler/rr44_maquette_native.py --output /private/tmp/labyrinth_codex/rr44-maquette-native
```

This prepares fresh native fit evidence but deliberately does not overwrite
the certified delivery before all mq-15 rows are recertified. A saved-run
inspection fixture is owned by the design owner under the workflow split;
the brief requests no `inspection_fixture.py` command for this worker.

## Final verification

The changed-file inventory is `rr44/proof/changed_files.txt`. It includes the
recut source and production assets, the new identity jobs, scoped records,
optional generic helpers, bounded proof tools and focused tests.

Observed focused result:

```text
Ran 12 tests in 71.975s
OK
RR44 SOURCE CUTS: PASS (front=0px rear=0px; masks rederived; exact painted backing)
RR44 MOTION: PASS (both elbows, both pendulums, rigid attached chain; every authored/presented frame)
RR44 HELD FOLLOW: PASS (world/moving-root implementations; zero gain, zero lag and locked chain rejected)
RR44 ELBOW/PENDULUM MUTATIONS: PASS (inverted elbow, missing policy, static far arm rejected)
RR44 SAMPLE ORIGINS: PASS (892 presented frames; canonical + native-origin; no renderer claim)
RR42 REST EQUIVALENCE: PASS (front=0px rear=0px; native_pixels=False)
RR38 SHADOW RECORDS: PASS (2 v2 views; every other unit retained)
ISOLATION AUDIT: 226 modules
TEST REGISTRATION AUDIT: PASS (866 scripts; full suite=506, quarantined=29, windowed probe=331)
```

Source/crop fixtures and the full-suite failure lists are retained in `rr44/proof/`.
The original historical assertions have not been rewritten. Some pin the old
Gaoler production revision or the complete density registry; those conflicts
must remain visible alongside current-revision checks.

Final Godot invocation (standard 900s suite budget):

```text
MAIN BODY RUNTIME: 734.625 seconds
MAIN BODY ASSERTIONS: 495687
FULL SUITE RUNTIME: 901.769 seconds (budget 900 seconds)
TEST RESULT: FAIL (93 failure(s))
```

`rr44/proof/godot_final_result.json` contains all 93 labels and the 92 program
records: 91 program timeouts, `prepared_shop_equivalence_test` exit 1, and the
full-suite budget assertion. This run overlapped the Python suite; do not treat
its unfinished sub-suites as passing. The earlier completed round had 15
failures (imports/unchanged GameData references/timeouts/budget), retained in
`godot_previous_result.json`.

The separate current-revision checks passed:

```text
RR38 RUNTIME: PASS (239 checks; headless registration, views, portraits and clocks)
V2 BOARD SPRITE GEOMETRY: {"cases":88,"errors":[],"native":false,"orientation_mutations_rejected":0,"placement_mutations_rejected":0}
PREPARED UNIT CANVAS RESULT: {"cases":64,"checks":4864,"errors":[],"native":false,"orphans":0,"pixel_differences":[]}
```

`focused_godot_result.json` also records the failed direct-helper invocation and
the 85s canvas timeout, followed by the correct registered entry at its standard
180s deadline (its earlier observed runtime was 98.316s).

The final Python command was `LABYRINTH_TASK_ID=rr-44 python3
tools/run_python_suite.py --shards 4 --output-dir /private/tmp/rr44-python-complete`:

```text
Ran 2101 tests in 2324.619s
FAILED (failures=11, errors=1, skipped=66)
```

`rr44/proof/python_final_result.json` retains all eleven test names/tracebacks
and the setup error. The failures are the unchanged historical Gaoler production
pins, the density source/reseal pins and rr-43's old gate-tool hash pin. The
error is `test_rr17_production.ProductionTests.setUpClass`: an engine signal-11
crash in `AudioDriverDummy::thread_func`, so its nine tests did not run. No
assertion was changed to hide a failure. Both new rr-44 modules passed in the
full run. The suite's attempt to update the untracked timing cache under the
shared `.git` directory was denied by this sandbox; no Git metadata was edited.

Final all-frame proof:

```text
RR44 SHARD EXECUTION: 125 shards; 0 process failures
RR44 CPU SWEEP: FAIL (892 frames; 807 findings; native calibration pending)
RR44 ALL GATES: FAIL (831 errors; native=False)
RR44 FINAL PROOF INVENTORY: PASS (892 exact frames; 807 flagged-frame crops exist; source inputs protected; no native claim)
CHECK-OK
RR44 FOREIGN RECORDS: PASS (all non-Gaoler identity, density and output records identical to HEAD)
```

The 103 already certified shards were retained; 125 unfinished shards completed
at the unchanged 85s limit. The initial concurrent run's two 85s timeouts remain
in `/private/tmp/rr44-sweep-complete.log`; both succeeded after contention was
removed. No passed shard was rerun. The final merge rejects missing/duplicate
frames and stale source, runtime, diagnostic or sample bindings.

`rr44/proof/diagnostic_summary.json` contains per-clip counts, all diagnostic
kind counts and both views' remaining source errors. Both elbow gates and both
pendulum gates have **zero errors**; walk/support/reach, rigid grip and draw-order
checks also have zero errors. The remaining non-raster errors are missing tuck
continuation and the explicit held-follow design placeholder. The 807 flagged
frames include overlapping missing (755), painted exposure (795), flat region
(745), detached (469), floating (471), tiny (236) and seam (138) findings; 359
frames also flag the known rear strip coordinates. None is certified native.

Full frame diagnostics/crops are in
`rr44/proof/production_case/proof/logs/{rr44_sweep.json,rr44_crops/}`. The portable
localized rear idle-6 witness is in `rr44/proof/painted_exposure_witnesses/`, bound
to the current shard, pose and source hashes (10 flagged texels). Its 4× CPU
crop was inspected; judgment remains with the director. The identity review
sheet is `rr44/proof/art_identity_review.png`. The baseline elbow fixture's four
crops and the other rigs' 82 report-only crops are portable source artifacts.

**Open work:** first native maquette fit/acceptance and delivery; director sheet
judgment; held-follow reference-frame decision; actual native captures, the
fixture-bound CPU ≥ native calibration test and floor-constrained channel
budget search; director disposition of backing/tuck/strip findings; the full
suite conflicts/crash described above. No new clamp, paint or acceptance was
invented to bypass any of these.
Do not interpret focused passes as a native-clean or publication-ready claim.
