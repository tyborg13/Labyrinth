> Historical round1 record. Current feedback2 fixes, focused results and open acceptance items are in [rr38_FEEDBACK2.md](rr38_FEEDBACK2.md).

# rr-38 feedback 1 handoff

Feedback fixes are implemented and remain uncommitted. Native acceptance is incomplete: the confirmed rear knee paint pocket needs a director underlay, and this sandbox cannot run windowed captures. No review, publication or task-queue edit was performed.

## Requirements

1. Rear near arm and glove remain unpainted by design. Source emptiness plus every-frame CPU/native outside-cowl gates are implemented, with an exposure mutation control. The three original TODO_DESIGN decisions are resolved.
2. The protected revised motion is imported byte for byte. The case-owned `held_drop.gd` follows the existing unit floor registration: 57.338835px front / 19.624591px rear measured drop. It falls vertically with constant-acceleration ease from .30 to .45, then pivots about the landed contact; .60/.72/.80/1 angular keys retain their times, including 85→80→82. The item shares the existing body fade and adds no sound.
3. Native layer-composition failure is diagnosed and corrected: all hidden layers previously had z=-1, while GPU tree order differed from the layout sort. Unique depths retain the measured GPU order. All ten supplied front/rear move frames 0–4 reconstruct exactly (0px difference), using a small hash-bound native fixture. The rear move-1 3px pocket remains real: its sampled source pixels are approved-paint background. Lattice alignment did not fix it and was removed. `TODO_DESIGN_rear_knee_underlay` records the required director continuation; no replacement paint was invented. Current windowed `native`/`sheets`/`review` exit 0 and the final review reel remain pending.
4. Death opts into planted feet, rest boot orientation and facing knees. Oblique forward Y is compensated on the pelvis so the requested screen-space sink is the full 15px in both views. Measured terminal knee bends (near/far): front 71.452698° / 74.001144°; rear 77.146803° / 77.354674°. Foot positions and segment lengths are checked through every authored death sample. Far-arm -36 is reachable in front; rear reaches its geometric limit with a maximum .825466px radial clamp.
5. Stronger Press targets remain protected. Reach constraints clamp them without stretching the two-segment chains. Near-arm maxima: front 16.126792px / rear 2.225635px radial target clamp; wind-up lift 22 remains reachable. Existing near-hand death -6 also clamps by 5.994828px front / 5.986002px rear. Every authored and presented clamp is listed in `rr38/proof/feedback1_motion.json` (322 receipts). Press torso 7° presents at 6° on the existing 1.5° grid while staying within its director limit; all such presentation limits are separately listed. Full arm-footprint coverage is measured for every press and falling-arm frame in the CPU sweeps.
6. Full headless import completed (the first bulk import timed out at 300s; the known bulk reimport then completed with an explicit budget). The final full suites were run after import; exact results are recorded below. Every windowed stage is supplied below for the director because this worker has no window-server access.

## Validation

All command/result/log hashes and full failure lists are in `rr38/proof/feedback1_verification.json`. Logs under `/private/tmp` and renderer/CPU captures remain untracked proof output.

- Focused: `Ran 22 tests in 25.884s` / `OK` (1352 fresh poses).
- Closure/fixture rerun after the case-owned helper: `Ran 25 tests in 27.383s` / `OK`.
- Final bounded-raster regression: `Ran 8 tests in 10.269s` / `OK`; every default/batched sample and UV tie matches, transported mask pixels match, and the missing-fill negative control still fails.
- Source and density-treated numeric gates: `RR38 ALL GATES: PASS (0 unique errors; native=False)`.
- Source and density-treated motion: `RR38 FEEDBACK1 MOTION: PASS (0 errors; 322 measured clamps; no native claim)`.
- Full Godot final: `FULL SUITE RUNTIME: 667.304 seconds (budget 900 seconds)` / `TEST RESULT: PASS`; all 220 program suites passed (no failures). Gaoler: `RR38 RUNTIME: PASS (239 checks; headless registration, views, portraits and clocks)`. Registration: `TEST REGISTRATION AUDIT: PASS (841 scripts; full suite=487, quarantined=29, windowed probe=325)`. The SFX sync programs and all requested reference sets passed.
- Full Python: `Ran 1978 tests in 4457.068s` / `FAILED (failures=1, skipped=66)`. Sole failure: `test_godot_sidecars.GodotSidecarRepositoryTests.test_tracked_sources_have_sidecars_and_sidecars_have_sources` requires `tests/rr38/contextual.gd.uid` to be tracked. Import generated the file; it is included in the uncommitted handoff. The instruction to leave all changes uncommitted was honored without staging or rewriting the assertion. Prospective tracked-plus-new-file inventory: `RR38 PROSPECTIVE SIDECARS: PASS (working-tree sources and generated sidecars; no Git staging)`.
- Production: `MAQUETTE PRODUCTION LOGIC: PASS (1440 frames)` in each view; freshly rebound contact/outcome/source-pose checks report `RR38 PRODUCTION CONTACTS/POSES: PASS (0 errors)` in each view.
- Export: `GAOLER CUTOUT PACK TEST RESULT: PASS (build, editor=true)`, `GAOLER CUTOUT PACK TEST RESULT: PASS (verify, editor=true)`, `GAOLER CUTOUT EXPORT RUNTIME: PASS (editor=false)` using an unmodified matching stock runtime and empty-project verification.
- Density: `CHECK-OK`. Shadow scope: `RR38 SHADOW RECORDS: PASS (2 v2 views; every other unit retained)`. Native script load only: `RR38 NATIVE PROBE LOAD: PASS` (no renderer capture).
- Preservation: protected paint/maquette/staged motion untouched; both motion copies byte-exact; every other unit asset and density/identity registry unchanged; both rest images have identical RGBA pixels to HEAD (PNG encoding hashes changed).
- Complete source CPU sweep: **892 frames, 477 findings** (153 joint-tear frame findings, 8 tiny-component frame findings, 316 missing-pixel frame findings); **5936 low-texture regions**. Treated sweep: same 892 frames and 477 findings; **5854 low-texture regions**. D1–D5 totals are zero. The scoped press/falling-arm footprint totals are zero. Four-frame shard maxima are **7.803426s source / 7.882230s treated**, with **zero timeouts**. These CPU findings remain failures, not native acceptance. `feedback1_source_cpu.json` and `feedback1_treated_cpu.json` retain every error, grouped flat-region frames and crop paths, bound to each full log hash. Native texture/tie judgment remains outstanding.

Earlier final-round failures are retained, not hidden:

- First bulk import exceeded the default 300s; the known bulk import completed with an explicit 1200s budget before the final suites.
- First full Godot used the default 300s and timed out. A 900s full run then completed in 797.228s with one failed program: three short-Press fixture assertions. The director's stronger fist travel measures 28.794 source pixels; the fixture now tests the moving trail and separately retains stationary fallback coverage. Focused `full_scene_cutouts_program`: `TEST RESULT: PASS`, 646907 assertions, 25.223s.
- Two subsequent full runs (801.330s and 778.044s) failed only `perf/transition_failure_case` with exit 124 while CPU/Python work also ran. Its isolated rerun passed all seven cases: `PERF03 TRANSITION DIFFERENTIAL RESULT: PASS`. The last full suite was then run without competing CPU/Python suites; its exact result is above. No performance assertion or timeout was changed.
- Early production proof receipts became stale after a proof-source edit. Fresh sealed logic captures and rebinding replaced them; no stale receipt was relabeled.
- Twelve-frame and initial four-frame kneeling CPU shards exceeded the 90s watchdog. Conservative transparent-mask triangle culling plus bounded triangle batches resolved the allocation cost without changing raster samples or ties. The final complete sweeps above contain no timed-out shards.

## Shared changes

- Optional compiler drop metadata, independent held-drop angular oracle and authored drop sampling inventory.
- Optional runtime planted-death feet, clip-specific knee side, screen-lift compensation and per-clip presentation limit. The drop helper is Gaoler-owned and explicitly included in production bindings and PCK exports.
- Opt-in CPU triangle batching and conservative transparent-mask triangle culling keep the complete kneeling diagnostic below its watchdog. Production parts, uncovered-domain mappings, default callers and sample/tie order are unchanged; exact equivalence and mutation tests cover this path.
- Optional `proof --diagnostic`: fresh/complete native input checks remain strict; failed gates may save review media with `ok=false`, exact errors and a nonzero exit. Default behavior still rejects failed native gates.
- Every other rig’s assets remain unchanged; default motion compilations are covered by the focused reference checks.

## TODO_DESIGN

`TODO_DESIGN_rear_knee_underlay`: rear move frame 1, proof bbox [277,368,279,370], three pixels. Crop: `rr38/proof/logs/feedback1/rear_move1_seam_4x.png`; retained round-0 source manifest: `rr38/proof/logs/feedback1/round0_native_frames.json`. Its full hash and sampled pixels are in the committed-size `feedback1_native_fixture.json`. An asynchronous question requests the approved underlay path; no answer has been assumed.

## Chosen defaults

`rr38_chosen_defaults.json` records four-frame/two-worker/90s CPU shards, existing diagnostic geometry/thresholds, measurement epsilon, 8px synthetic fixture with pixel [3,3], 5px mutation, 60° diagnostic minimum knee bend and a two-column 2× round-0 sheet. These are proof/test defaults. Player motion values come from the protected data; floor distance, joint reach and knee angles are measurements.

## Proof for the design owner

No current windowed stages were run by this worker. From the worktree, run:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-38
LABYRINTH_TASK_ID=rr-38 sh experiments/cutouts/chainbound_gaoler/rr38_proof.sh density
LABYRINTH_TASK_ID=rr-38 sh experiments/cutouts/chainbound_gaoler/rr38_proof.sh rest
LABYRINTH_TASK_ID=rr-38 sh experiments/cutouts/chainbound_gaoler/rr38_proof.sh native
LABYRINTH_TASK_ID=rr-38 sh experiments/cutouts/chainbound_gaoler/rr38_proof.sh sheets
LABYRINTH_TASK_ID=rr-38 sh experiments/cutouts/chainbound_gaoler/rr38_proof.sh idle
LABYRINTH_TASK_ID=rr-38 sh experiments/cutouts/chainbound_gaoler/rr38_proof.sh production
LABYRINTH_TASK_ID=rr-38 sh experiments/cutouts/chainbound_gaoler/rr38_proof.sh review
```

All captures are 1920×1080 / 100%. The required current reel is `rr38/proof/chainbound_gaoler_review.mp4`; it cannot be generated faithfully without current native frames. Diagnostic encoding retains failure status and never relabels the round-0 captures.

## Files changed

Complete inventory: `rr38_FEEDBACK1_FILES.txt`. The main changes are the Gaoler-owned held-drop helper, layouts/compiled motion and proof bindings; optional shared compiler/runtime/raster/proof hooks; rear-occlusion, floor/knee/reach and native-fixture gates; and the larger-fist trail/pack/sampling tests. Every shared change is described above and covered by focused and full-suite results.

Open acceptance issues: `TODO_DESIGN_rear_knee_underlay`; the listed CPU findings and texture regions awaiting native confirmation/director judgment; current windowed native/sheets/review exits and review reel; Git-index sidecar guard until the owner records the handoff. No new player-facing values were chosen.
