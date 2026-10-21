# rr-31 feedback 3 — accepted rig, compact calibration storage

The director accepted the rig at `e9aadfc32`. This final cleanup changes only
calibration storage and documentation. See [feedback3.md](feedback3.md) for
lossless evidence packaging, focused verification and runtime byte identity.
The earlier rounds below remain historical records.

---

# rr-31 feedback 2 — seam construction and diagnostic-only images

Current work and proof are in [feedback2.md](feedback2.md). The director has
accepted the new motion visually. rr31 image metrics are non-blocking
diagnostics; acceptance is the director’s judgment plus the unchanged rr30
native gates. Fresh windowed verification belongs to the director.

---

# rr-31 feedback 1 — calibration stop

The director withdrew the original rest-relative thresholds. See
[feedback1.md](feedback1.md) for the current calibration and frame-by-frame
overlap report. The earlier budget limits and 47 motion TODOs below are
historical, uncalibrated results; they do not establish a motion defect.
No calibrated thresholds or replacement budgets have been installed.

---

# rr-31 implementation and proof

The new motion is imported and the requested gates and budget validator are
implemented. **Image acceptance is failing.** The immutable director input is
unchanged. The measured excesses are recorded as 47 named design placeholders
in [TODO_DESIGN.md](TODO_DESIGN.md), with signed limits and rejected values per
view. The design owner owns re-authoring, windowed proof, review and publication.
All implementation changes are uncommitted; no windowed run or peer review was
attempted.

## Numbered requirements

1. `../rr31_build.py` copies staged rr-31 motion byte for byte into the existing
   editable rr30 case and production. It recompiles the protected tracks, updates
   clip metadata and both production layout declarations, refreshes integration
   hashes, and leaves production unready. Keeping the accepted rr30 case paths
   preserves all eight native proof stages. Use this motion refresh rather than
   rerunning the historical painting/ownership builder. The director restored
   `brace:block` in the staged brace metadata. Both supplied-file imports are
   byte-identical to that staged data, and the editable and production compiled
   motion files are byte-identical, including the selector. Regression checks
   verify both the input path and compiled-data equality.
2. `../rr31_budgets.py` and `tests/rr31/joint_samples.gd` sample 21 channels in
   both views: 5,922 real headless Bone2D poses, with one channel varying at a
   time. Generated foot/root channels retain their required gait solver context
   with companion targets held at zero. The CPU sweep checks the passing prefix
   in both signs and every distinct continuation-material state. It rendered
   207 channel samples: 109 pass, 98 fail. Limits are conservative sampled limits,
   not claimed continuous extrema. The fine spacing is 0.25 source px/degrees;
   later search extents and censoring are explicit in `joint_budgets.json`.
   The validator checked 408 director keys and reports 47 TODOs without editing
   any key. Some gait zero-target poses already fail the painted-rest reference;
   their maximum passing value is `null`, not an invented zero budget.
3. The additive `tools/humanoid_cutout/image_gates.py` implements the exact disk
   closing/opening formulas. Joint counts use native pixel centres within 14 px
   of the posed mean contact centroid, transformed from both painted cuts.
   The CPU contour gate tracks topmost visible source texels on the assembled
   rest exterior, including painted holes; internal ownership cuts are not
   exterior contours. A texel fails at Euclidean distance at least 2 from air.
   Failure records contain piece, source pixel, destination pixel and RGBA.
   Original round-3 cover/dark-donor gates remain active. The gates are registered
   in the existing Mortar full-sweep test and have independent notch, fray and
   contour mutation checks. Both frame inventory and input/verification hashes
   are checked; native gates use the existing lossless full-coordinate loader.
4. Construction fixes remove source texels, never mask captures. Action-only
   recipes enlarged unchanged rests by 14 front pixels and 13/21 rear pixels;
   those exterior recipe texels are removed in `source_cover_cuts.json`.
   The complete new-motion cover calibration adds 48 front and 31 rear static
   source cuts, with attribution in `source_joint_cuts.json`. Two hidden-only
   islands (1 front pixel, 23 rear pixels) left by those cuts are removed in
   `source_cover_islands.json`. Tuck masks and their records are rebuilt from
   the resulting construction. Source, classification, untreated density source
   and processed production assets receive the same cuts. All cover and dark
   checks now pass; the requested image criteria still fail and need owner
   resolution alongside the recorded budgets.

## Preservation

`proof/preservation.json` verifies 88 immutable files against this worktree's
base HEAD, including both paintings, all visible source/production cuts, both
native rest PNGs, protected director input and the identity registry. All are
unchanged. Both assembled source rests differ by 0 pixels. No painting, palette,
icon, font, audio, gameplay timing or VFX was generated or changed.

The existing identity certification test reports 111/111; rear chroma remains
0.19884831373817569. All 80 rigid pieces retain effectively zero stretch
(largest floating-point residue 0.0000263651%). Source/bone/knee gates pass;
walk fit remains front 0.091893 px and rear 0.098218 px, with zero stance drift.
Idle/move authored data, hinged flap, gait sway, joints, registration and density
calibration values are retained. Density part hashes are refreshed after the
source cuts. Both recorded native rests require a fresh renderer rebake;
their unchanged PNG bytes do not certify the changed moving construction.

## Headless reproduction

Run from the rr-31 worktree. CPU/image commands intentionally exit nonzero
while the reported acceptance problems remain. Full logs and per-frame source
attribution are retained locally under `proof/logs/` (ignored by this unit).

```sh
python3 experiments/cutouts/slag_mortar/rr31_build.py
python3 tools/godot_task_runner.py --task-id rr-31 --stream -- godot --headless --path . --script tests/rr22/samples.gd -- --case res://experiments/cutouts/slag_mortar/rr30 --output res://experiments/cutouts/slag_mortar/rr30/proof/logs/samples_full.json
python3 experiments/cutouts/slag_mortar/rr30_records.py samples
python3 experiments/cutouts/slag_mortar/rr31_budgets.py requests
python3 tools/godot_task_runner.py --task-id rr-31 --stream -- godot --headless --path . --script tests/rr31/joint_samples.gd -- --requests res://experiments/cutouts/slag_mortar/rr31/proof/logs/joint_requests.json --output res://experiments/cutouts/slag_mortar/rr31/proof/logs/joint_samples.json
python3 experiments/cutouts/slag_mortar/rr31_budgets.py sweep
python3 experiments/cutouts/slag_mortar/rr31_images.py cpu
python3 experiments/cutouts/slag_mortar/rr31_images.py round3
python3 experiments/cutouts/slag_mortar/rr30_gates.py
python3 experiments/cutouts/slag_mortar/rr31_proof_data.py
LABYRINTH_TASK_ID=rr-31 python3 -m unittest discover -s tests -p 'test_rr31*.py' -v
LABYRINTH_TASK_ID=rr-31 python3 -m unittest discover -s tests -p 'test_rr30*.py' -v
python3 tests/test_art_identity_gate.py
LABYRINTH_TASK_ID=rr-31 python3 -m unittest discover -s tests -p 'test_*.py' -v
python3 tools/godot_task_runner.py --task-id rr-31 --timeout 1200 --stream -- godot --headless --path . --script tests/run_tests.gd
```

After a director motion revision, source cover calibration is explicitly:
`../rr31_repair.py`, then `../rr31_repair.py --finalize`, density processing and
`../rr31_build.py`. Refresh all headless samples and budgets afterward. The repair
   refuses cuts that change the approved rest. Its records list the sweep's cuts;
do not substitute a frame-specific mask or rebuild historical paint.

## Proof for the design owner

| Evidence | Pass | Fail |
|---|---:|---:|
| Round-3 native morphology, both views | 185 | 677 |
| rr31 isolated-channel CPU sweep | 109 | 98 |
| rr31 complete CPU clips, both views | 161 | 701 |
| rr31 complete CPU cover/dark-donor checks | 862 | 0 |
| rr31 new native frames | pending | pending |

`proof/round3.json` lists every failing historical native frame. In both views,
lob heave frame 32, brace hold frame 20 and death frame 78 fail. Front lob 1–70,
brace 1–52 and death 0–89 fail; rear lob 1–70, brace 1–52 and death 4–89 fail.
The retained six-frame native alpha fixture records the source frame hashes
and contact positions, so negative coverage does not depend on another
worktree remaining present. The full historical check reads the rr-30 tree
without modifying it.

`proof/cpu.json` lists all current failing frames. Per-frame detailed reports
are `proof/logs/cpu_full.json` and `proof/logs/joint_sweep_full.json`.
Current maximum exposed cover distances are front 2.999497061328248 px and
rear 2.9981903453869387 px; no dark-donor failures remain. Six inspected
full-canvas CPU frames are in `proof/cpu_frames/`, for front/rear lob0032,
brace0020 and death0078. They are CPU evidence, not native acceptance.

The retained joint-seam checker also reports 11 hole observations larger than
one pixel: front lob33/lob67/scatter39; rear lob59/lob60 and
brace4/brace7/brace8/brace47/brace48/brace50. These remain unresolved with the
supplied over-budget motion and are included in the failing Mortar acceptance
test. Source/bone/knee validation and cover/dark validation pass independently.

The eight-stage driver retains the existing semantic proof contracts,
1920×1080 capture and 100% UI scale, with refreshable result manifests. Its
native stage runs both the old native gates and new morphology gates, and
returns failure if either fails. Run these windowed commands on the owner's
native renderer; no windowed run was attempted here:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-31 && LABYRINTH_TASK_ID=rr-31 sh experiments/cutouts/slag_mortar/rr30_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-31 && LABYRINTH_TASK_ID=rr-31 sh experiments/cutouts/slag_mortar/rr30_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-31 && LABYRINTH_TASK_ID=rr-31 sh experiments/cutouts/slag_mortar/rr30_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-31 && LABYRINTH_TASK_ID=rr-31 sh experiments/cutouts/slag_mortar/rr30_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-31 && LABYRINTH_TASK_ID=rr-31 sh experiments/cutouts/slag_mortar/rr30_proof.sh walk
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-31 && LABYRINTH_TASK_ID=rr-31 sh experiments/cutouts/slag_mortar/rr30_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-31 && LABYRINTH_TASK_ID=rr-31 sh experiments/cutouts/slag_mortar/rr30_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-31 && LABYRINTH_TASK_ID=rr-31 sh experiments/cutouts/slag_mortar/rr30_proof.sh review
```

Outputs retain the established rr30 `proof/native_rest/`, `native/`,
`contact_sheets/`, `gait_move_native/`, `gait_move_sheet.png`, `idle_native/`,
`production_native/{front,rear}/`, idle comparison MP4 and review MP4 paths.
New native image counts will be written to rr31 `proof/native.json`.
No inspection-fixture command was requested; inspection and publication belong
to the design owner.

## Chosen defaults and open issues

`proof/chosen_defaults.json` names all proof/test choices: 0.25-unit fine grid,
16-unit fine extent, coarse extents 24/32/48/64/90/128, selected CPU frames
32/20/78, progress every 100 frames, 48-pixel morphology fixture, fixture joint
at [24,12], sampler fixture step 96 px at scale 2, sampler offset 6, contour
mutation 4 px, isolated clip duration 1 s, subprocess cap 180 s and full Godot
cap 1200 s. None changes a player-visible value.

The director must resolve the 47 named budget excesses, the remaining image
violations (including retained idle/walk behavior), and native rest/capture
acceptance. `TODO_DESIGN.md` and `proof/budget_validation.json` contain the
complete placeholder inventory with measured limits. No production-ready
claim or visual signoff is made.

## Final observed test results

- New rr31 tests: `Ran 14 tests in 2.230s`; `OK`.
- Mortar motion/preservation followup: `Ran 10 tests in 12.826s`; `OK`.
- Production selector/runtime: `RR30 RUNTIME: PASS (318 checks; headless logic only)`.
- All focused rr30 tests: `Ran 34 tests in 841.308s`; `FAILED (failures=1)`.
  The failing frame-acceptance test includes the new image violations and the
  11 retained seam-hole observations listed above.
- Identity: `Ran 111 tests in 38.865s`; `OK`.
- Full Python: `Ran 1600 tests in 2843.579s`;
  `FAILED (failures=2, skipped=66)`. Failures are density freshness and Mortar
  frame acceptance. Density freshness reports both pending native rebakes plus
  20 retained, unregistered legacy arm/leg/apron output entries. Those 20 entries
  and their registration state are byte/value-identical to base HEAD; they
  were not removed or relabelled. The check/assertion was not weakened.
- Final full Godot: `MAIN BODY ASSERTIONS: 378990`;
  `FULL SUITE RUNTIME: 769.247 seconds (budget 900 seconds)`;
  `TEST RESULT: FAIL (2 failure(s))`. The two failures are 180-second timeouts in
  `sfx_sync_0_program` and `sfx_sync_1_program`. Both passed serially with the same
  unchanged caps: `SFX SYNC HARNESS RESULT: PASS (4231 observations, 0 failures)`
  in 146.648 s and `PASS (3504 observations, 0 failures)` in 127.420 s.
  One child slot was a proof-only scheduling choice; no audio or assertions
  were changed. The aggregate full-run failure is retained in the report.
- Shell syntax, all eight driver dispatches, and `git diff --check` pass.

Machine-readable results are in `proof/results.json`. Complete final transcripts
are in `proof/logs/`; `proof/files_changed.txt` lists the owned changes.
