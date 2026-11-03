# rr-44 — feedback 1 implementation and evidence

All changes are uncommitted on `codex/rr-44`. This round is **not native-clean**.
The calibrated CPU sweep still fails, and the director must judge the flagged
paint, clear regions and hidden surfaces. No paint was generated. No windowed
Godot run, full suite, peer review, commit or publication was performed this
round. The existing Blender bridge was used as requested.

## Feedback 1 acceptance

1. **Native ground truth first — calibration passes; repairs are partial.**
   Before changing ownership or fills, the director's round-0 case, 892 poses,
   CPU observations, 2,683 raw report errors and native witness crops were
   frozen in `rr44/fixtures/native_r0/`. The immutable manifest SHA-256 is
   `8245c825fb7d9eba06d5474dbf0fa5dd3f1ecc07cd9c15892b6b8aae7d5cb8dd`.
   The gate now reports previously measured but omitted defect categories.
   The fresh final replay covers **1,336/1,336 unique typed native signatures**
   over all 892 frames; removing an outline category or frame fails the test.
   Tests read the hash-bound fixture, never ignored proof logs.

   Front ownership corrects 13 exact painted texels at sleeve, cowl, helm,
   belt and tabard boundaries. Rear ownership recovers 158 exact arm, glove
   and chain edge texels using their approved source contacts, with zero
   unresolved contacts. Retired high-arm footprints receive the new supplied
   body paint. Waist overlap uses supplied paint behind both sides of the
   torso/pelvis joint. Director-transparent areas keep justified source-owner
   clears instead of demanding procedural replacement paint.

   The final CPU diagnostics find **no seam, detached or floating component**
   in front death frames 10–13, 16–22 or 31. These are CPU results; the director's
   new native capture is still required. Other frames retain real failures.
   Final sweep: **809 flagged frames / 892**, with 228 shards and zero process
   failures. The combined gate fails with **826 unique error lines**, including
   17 distinct missing/insufficient tuck errors. Counts are not directly
   comparable to the original 2,683 raw native error lines.

2. **Press near-elbow seam — implemented; native judgment pending.**
   The existing 3px elbow band has a hidden cap made only from exact approved
   sleeve texels. The visible band and its outline follow the forearm; touched
   mesh cells use 1px quads and untouched cells keep their existing weights.
   The density partition includes both visible and hidden cap texels. RGBA,
   cap-depth and mesh-weight mutations fail. Front press frames 13–15 have
   zero CPU joint-seam, detached or floating findings. Their other backing
   and outline findings remain flagged.

3. **Press lift / budgets — no press clamp was applied.**
   `hand_near.lift_px` is the director's full **22px**, with forward 18px.
   It was never clamped to 14px. Walk peaks remain near 14°, far 10°; reel
   forward/lift 10/8px; pin 6/4px; guard lift 8px. The only retained historical
   clamp is death `coat_near_tip.lift_px`, **4 → 2.5px in both views**.
   No new motion clamp is certified: two witness frames per view for each of
   move, press, reel, pin and guard still flag at their specified floors.
   This is a rejection witness, not a complete candidate clip sweep. Source
   bindings and tested values are in `rr44/proof/floors/*/floor.json`, with
   4× CPU crops. Nothing was reduced below a floor. Further paint/clear
   decisions are required before claiming any native-clean channel budget.

4. **Production pose equality — passes.**
   The production probe and comparison now accept an explicit source case;
   rr-44 passes its current source case instead of the historical rr-38 case.
   Defaults for older callers are unchanged. Both front and rear have
   `MAQUETTE PRODUCTION LOGIC: PASS (1440 frames)` and
   `RR38 PRODUCTION CONTACTS/POSES: PASS (0 errors)`, including upper_near and
   upper_far. These are fresh headless pose comparisons, not fresh screenshots.

5. **Body-frame held follow — implemented and passes.**
   The generated angle measures the actual painted grip through the hand,
   relative to the moving torso/body frame and its rest grip, projected onto
   facing at the delayed sample time. Root/pelvis travel and body lean alone
   cannot move the hook. The explicit zero placeholder is removed; protected
   director motion remains byte-identical. Zero gain, zero lag, a locked
   chain, a static arm, inverted elbows and missing policy are rejected.
   Tests also exercise the two existing alternate reference-frame modes.

6. **Maquette — every mq-15 acceptance row passes.**
   The failing native grip probe used the old grip frame after the hand was
   moved. The new surface pose supplies its own grip frame. A rigid hand
   twist and rigid armor centroid refit preserve limb dimensions and produce
   one front pose; rear is always the proper `diag(-1,-1,1)` half-turn.
   The bridge build, both captures, native probe, cold replay and exact replay
   pass. Bounded capture jobs take at most 54.5s. Lossless capture compaction
   preserves all decoded RGBA and masks.

   New sealed delivery: `rr44/maquette/delivery/`, spec hash
   `a418639631060cb67fc4db8a90485f787bed35cf3a3e06843e5788be3f1281ac`;
   acceptance hash
   `b75ff880916f3d97cacfca351b44e462b920172c2d1919a76fce32bcfac18849`.
   Front IoU **0.8489029631305135**; maximum semantic centroid error
   **4.971802989523241px**. Grip, mass/cloth, holes, shoulder rise, sole,
   proportions and true-turn rows are all green. The historical canonical
   delivery remains unchanged and passes its own acceptance/hash tests.

7. **Suites — caused Python failures fixed; full runs deferred.**
   The 11 previously failing change-affected Python checks pass in a focused
   run. Historical tests now bind their exact rr-42 snapshot; current density
   and registration have independent current-revision checks. Existing
   assertions still check the historical paint, motion and persisted records.
   Shared dependency hashes are checked separately from unchanged rest pixels.
   The affected rr-38/42 suites also pass (29 tests). No assertion for an
   existing master failure was weakened. Full suites were not rerun because
   the director explicitly excludes them this round. The earlier 11F/1E
   Python and 93 Godot failure lists remain historical evidence in
   `rr44_IMPLEMENTATION.md` and `rr44/proof/`; no full-suite pass is claimed.

## Original contract coverage

| Requirement | Current result |
|---|---|
| 1. New art jobs / provenance / sheet / identity check | v5/v4 registered; protected inputs and numerical recipe replays exact; identity check passes. Sheet judgment belongs to director. |
| 2. Maquette refit | Every mq-15 native row passes; new joints below. |
| 3. Both source cuts | Skinned sleeve, rigid glove and one rigid chain/hook; correct overlaps; source rest mismatch 0px both views. |
| 4. Supplied painted backing | Exact supplied opaque texels replace backing in footprints; old footprint also covered. Unpainted, flat and rear-strip exposure remains failing with crops. |
| 5. Motion / optional features | Director keys preserved; both pendulums, elbow policy, delayed body-frame follow and shorter measured death drop implemented. |
| 6. Native-clean floors | Calibrated sweep and floor witnesses implemented; clean budgets unresolved. No new or below-floor clamp. |
| 7. Elbow gate and mutations | Every fresh frame passes; hash-bound base press/hit fixture fails both views. Nine other rigs are report-only. |
| 8. Gate bundle | Structural, bones, support/reach, both-leg walk, both pendulums, elbows, chain/grip, paint and native-defect diagnostics run. Current combined result fails; new native and native sprite-geometry proof pending. |
| 9. Records / routing | Deterministic density/rest/shadow refresh; 0px CPU production rests both views; every other unit's records retained; production routing unchanged. |

## New joint positions

| Joint | Front source pixels | Rear source pixels |
|---|---|---|
| Far shoulder | (112.797962, 81.296007) | (145.202038, 98.186618) |
| Far elbow | (106, 110) | (152, 118.928609) |
| Far wrist | (94, 137) | (164, 147.084326) |
| Painted grip | (89, 145) | (170, 162) |

Native 3D positions: shoulder_far `(0.2449846, -0.2967696, 1.5140511)`,
elbow_far `(0.3432139, -0.2890227, 1.2453673)`, hand_far
`(0.4153840, -0.3765756, 0.9456575)`. Full precision is retained in
`rr44/maquette/spec_native.json` and `joints_source_px.json`.

`inputs.json` deliberately retains the certified historical body/feet delivery
references. Fresh arm registration uses the new sealed delivery above, and
`tests/rr44/registration.py` verifies every far-arm joint against that native
projection while requiring every other body/foot joint to equal the baseline.
The old body baseline has not been relabelled as newly captured evidence.
`rr44/proof/feedback1_registration.json` records this split explicitly.

## Remaining TODO_DESIGN fields and crops

The durable catalog is [rr44_feedback1_design_requests.json](rr44_feedback1_design_requests.json).
Its **34 named fields** contain exact uncovered source texels or joint/frame
regions, and are bound to the final sweep/report hashes:

- 20 `TODO_DESIGN_painted_backing_<view>_<hidden_part>` fields;
- 12 `TODO_DESIGN_hidden_surface_<view>_<joint>` fields;
- `TODO_DESIGN_rear_underlay_strip` (356 exposed-frame findings);
- `TODO_DESIGN_flat_backing_regions` (743 frames).

The full posed/source crop index is `rr44/proof/paint_requests/requests.json`.
It contains every frame for each request, not just the first witness. The
known rear strip is still independently rejected even when its texels match
the supplied underlay. Exposed flat regions have not been accepted as paint.
The resolved held-follow placeholder no longer exists in compiled motion.

Inspected current CPU examples, relative to `rr44/proof/production_case/`:

- `proof/logs/rr44_crops/front_press_014_cpu_4x.webp` — filled elbow band;
- `proof/logs/rr44_crops/front_death_016_cpu_4x.webp` — closed body joint, remaining backing/outline findings;
- `proof/logs/rr44_crops/rear_idle_006_cpu_4x.webp` — known strip exposure;
- `proof/logs/rr44_crops/rear_death_031_cpu_4x.webp` — remaining rear hidden-surface seam.

All these are conservatively rasterized CPU crops (`native_pixels:false`).
They do not replace the director's new windowed captures.

## Files changed and optional shared changes

Exact per-file inventory: `rr44/proof/feedback1_files.txt`. Groups:

- `rr44/**`, `rr44_*.py/.sh/.json`, scoped rr-38/42 helpers: source cuts,
  masks, native maquette delivery, immutable fixtures, deterministic build,
  calibration, diagnostic sweeps, floor/paint requests and seven-stage proof.
- `assets/units/chainbound_gaoler_cutout/**`: production cuts, motion and
  integration; new identity jobs `mq3_front_v5` / `mq3_rear_v4` and Gaoler-only
  identity, registration, density/rest and shadow records.
- Optional art recipe in `tools/art_identity_gate.py` and
  `tools/art_identity_gaoler_arm.py`: hash-bound supplied repaint replay.
- Optional `elbow_policy`, legal rounding and generated `held_follow` in
  `tools/humanoid_cutout/{compiler,bone_contracts,elbows,held_follow}.py` and
  `scripts/maquette_cutout_runtime/{humanoid_motion,humanoid_gait,humanoid_presentation,humanoid_elbows,humanoid_held_follow,rig}.gd`.
  Absent fields retain old behavior. Both probe dependency lists include the
  new helpers; the full Transform2D assignment path is retained.
- Optional exact painted joint caps in `painted_caps.py` and source gates;
  optional rigid-source component factory in shared native gates. A disconnected
  chain link is certified only if full RGBA exactly matches source transport
  and the independently checked held grip stays attached. Mutated pixel,
  scale and detached-grip cases fail. Body fragments receive no exemption.
- `rr42_exposure.py` has opt-in packed footprint transport. Overlapping
  fragments combine with bitwise OR; all masks, rows and observations match
  the unoptimized path for both skin families, both origins and every rounding
  choice. The default is unchanged.
- Optional mq-15 `up_axis`, surface-pose grip frame, source masks/extra semantic
  labels and bounded capture wrapper; historical delivery remains byte exact.
- Optional source-case production probe and geometry-only/type proof selection;
  default historical calls retain their existing path. Focused tests, new
  test/resource registrations and revision-aware historical fixture checks.

All nine foreign compiled reference sets and **10,294 runtime poses** are
byte-identical. Other-rig elbow reports are in `rr44/proof/foreign_elbows/`:

| Rig | Failing arm/frame records | Witness crops |
|---|---:|---:|
| Seer | 5 | 2 |
| Thrall | 215 | 8 |
| Mirror | 9 | 3 |
| Weaver | 518 | 14 |
| Mimic | 49 | 7 |
| Mortar | 626 | 16 |
| Herald | 10 | 3 |
| Gloam | 481 | 14 |
| Lancer | 438 | 15 |

Each rig JSON contains every failing clip/frame; total 2,351 records, 82 crops.
No foreign rig is changed. Preservation audit confirms 147 other identity
records, 112 density entries and 2,187 density outputs unchanged, with all
protected director inputs byte exact.

## Observed verification

Logs and selected exact result lines are indexed in
`rr44/proof/feedback1_results.json`; copied logs are under
`rr44/proof/logs/feedback1/`. Passing checks were not repeated after unrelated
paint changes. This is a focused round, not a full-suite result.

```text
RR44 CPU/NATIVE CALIBRATION: PASS (1336/1336 native signatures; 892 fresh frames; max shard 6.895s)
Ran 12 tests in 110.880s
OK
Ran 9 tests in 6.797s
OK
Ran 5 tests in 48.097s
OK
Ran 1 test in 9.611s
OK
RR44 TWO-LEG WALK MUTATION: PASS (both views; displaced planted foot fails)
Ran 11 tests in 141.661s
OK
Ran 29 tests in 133.375s
OK
Ran 111 tests in 116.796s
OK
RR44 TWO-LEG WALK: PASS (254 poses; 0 errors)
RR44 REGISTRATION AUDIT: PASS (all mq-15 rows; new native far-arm projection; unchanged certified body/feet)
MAQUETTE PRODUCTION LOGIC: PASS (1440 frames)
RR38 PRODUCTION CONTACTS/POSES: PASS (0 errors)
RR38 RUNTIME: PASS (239 checks; headless registration, views, portraits and clocks)
V2 BOARD SPRITE GEOMETRY: {"cases":8,"errors":[],"native":false,"orientation_mutations_rejected":0,"placement_mutations_rejected":0}
RR42 REST EQUIVALENCE: PASS (front=0px rear=0px; native_pixels=False)
RR38 SHADOW RECORDS: PASS (2 v2 views; every other unit retained)
ART IDENTITY CHECK: PASS (0 failures, 0 pending_reart warnings, 0 skipped replays)
TEST REGISTRATION AUDIT: PASS (866 scripts; full suite=506, quarantined=29, windowed probe=331)
RR44 SHARD EXECUTION: 228 shards; 0 process failures
RR44 CPU SWEEP: FAIL (892 frames; 809 findings; native_calibrated=True)
RR44 ALL GATES: FAIL (826 errors; native=False)
RR44 DIRECTOR PAINT REVIEW: 20 source regions; 743 frames with flat regions; 356 rear-strip frames; all remain flagged
```

The 12-test run comprises nine feedback/cap/release/maquette tests and three
fixture calibration tests. The nine-source-test run includes eight source
tests and the exact rear contact test. Five motion tests use fresh Godot
samples; the added walk mutation uses another fresh sample. Production lines
above occur independently for front and rear. The resource audit-only command
completed with exit 0 (228 audited modules); all four new test modules have
explicit `[]` declarations. `git diff --check` and both shell syntax checks pass.
One mistyped unittest class invocation failed to load; its correctly named
single-test rerun passed. One broad headless canvas probe timed out at 85s
under load; the scoped four-facing geometry check passes. Neither is reported
as a full canvas/suite pass.

## Chosen defaults

Only proof, numerical search, test and diagnostic defaults were chosen:

- `rr44/chosen_defaults.json`: crop context 12px / zoom 4; sample and shard
  deadlines 85s; four frames/shard; four sweep workers; serialized matrix
  tolerance 0.0001 and presentation angle tolerance 0.751°.
- Calibration: eight workers, four frames/shard, 85s deadline. Actual final
  maximum calibration shard 6.895s. The complete proof is sharded; aggregate
  unittest/sweep supervision is longer than 90s.
- Maquette: shoulder search step 0.25px, numerical bend epsilon 0.0001°,
  rigid hand twist search 5°, centroid quantization guard 1px; four semantic
  labels/capture batch. The x107 trace bound is measured paint geometry, not
  a player-facing choice. Original mq-15 5px/15% acceptance limits are retained.
- Packed diagnostic footprints hold at most 16 masks. Tests use body/grip
  displacements 17px/4px, release rotation 0.41rad, existing proof offset 192px,
  invalid RGBA `(254,7,199,255)`, and named witness frames in each floor receipt.

No additional gameplay, art, animation tuning, camera or UX values were chosen.

## Proof for the design owner

Run from this worktree. These are the seven exact windowed commands, using the
visual runner and existing 1920×1080 / 100% UI-scale contracts:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-44
bash experiments/cutouts/chainbound_gaoler/rr44_proof.sh density
bash experiments/cutouts/chainbound_gaoler/rr44_proof.sh rest
bash experiments/cutouts/chainbound_gaoler/rr44_proof.sh native
bash experiments/cutouts/chainbound_gaoler/rr44_proof.sh sheets
bash experiments/cutouts/chainbound_gaoler/rr44_proof.sh idle
bash experiments/cutouts/chainbound_gaoler/rr44_proof.sh production
bash experiments/cutouts/chainbound_gaoler/rr44_proof.sh review
```

`native` refreshes current samples, captures, reruns the bounded calibrated CPU
sweep and checks both-leg walk plus native gates; it does not reuse an old
sweep. `sheets` and `review` preserve diagnostic output on gate failure.
Captures go under `rr44/proof/{native,native_rest,contact_sheets,idle_native,production_native}`.
Videos: `rr44/proof/chainbound_gaoler_review.mp4` and
`rr44/proof/chainbound_gaoler_protagonist_idle.mp4`. Inspect front/rear walk,
press, hit, reel and death at 2–4×. New Godot native pixels and native geometry
acceptance remain pending. The brief requests no worker inspection-fixture
command; fixture creation and eventual full-suite/final-round approval remain
with the design owner.
