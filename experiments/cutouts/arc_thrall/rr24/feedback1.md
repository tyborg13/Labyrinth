# rr-24 feedback 1 handoff

This historical report is superseded by [feedback 2](feedback2.md).

Implementation is uncommitted on `codex/rr-24`, based on the director's
`4de3c0dc2d59a83246c6b36abfcada081ff1fdc0` repaint handoff. The director's
two decisions are implemented. There are no active `TODO_DESIGN` placeholders.
Native visual acceptance, rest records and shadows still require the windowed
sequence below. No windowed run, full suite, peer review or publication was run.

## Feedback requirements

1. **Head/collar ownership.** Collar, front lock and chain remain rigid torso
   paint. The visible head draws above the torso in both views. The gate
   compares rendered isolated alpha and resolved ownership, checking the entire
   torso (a stricter surface than the collar alone); it permits contact and
   rejects every covered visible-head pixel. Hidden neck continuations remain
   under the collar as in the painting. CPU results: **236 front / 229 rear
   contact frames; zero covered-head frames**. These are whole head/torso
   contacts, not a geometric jaw-clearance measurement. All contact frames,
   pixel counts and bounds are in `checks.json`; the compact frame list is in
   [feedback1_observations.md](feedback1_observations.md).
2. **Skirt/leg source air.** `../rr11/rr24_policy.json` selects the Thrall-only
   policy. A pocket must border skirt and leg owners, border no other owner,
   and lie outside **every** piece's immutable painted/tuck footprint. Skinned
   inverse fragments and rigid transforms are checked; gait texels also count
   as occupied source. Single-owner punched cloth/skin, missing joint material,
   hidden non-boundary tucks and torso/belt air still fail. There are no frame
   exceptions in this policy. CPU results: **121 front / four rear admitted
   pockets**; each frame, bounds, pixel count and source evidence is reported.
   Front tether 17 `[265,305,268,309]` passes with eight air pixels. Native
   validation uses GPU-transported immutable masks, not CPU skinning.
3. **Repaint baselines.** Eleven Thrall rr-15/gait assertions use the explicit
   [re-pin inventory](repinned_tests.json), which lists each test's old and new
   baseline. The new [repaint baseline](repaint_baseline.json) pins mq7b source
   hashes, 548 Thrall file fingerprints, mesh fields and exact current seam
   removal fixtures. Director data remains byte-bound to
   `80d5ec39bfa4b79c176835a02c6137044a7de75e`. Tests never regenerate baselines.
   Derived rest fingerprints pin their adopted density calibration source until
   the director rebakes; layout canonicalization excludes only that derived
   `rest_source_sha256`. Other figures' assertions are unchanged.
4. **Actual seams.** Own-edge nape texels extend under the collar at four
   covered source points. Three tiny rigid joint tucks register the front waist
   and rear nape/collar corners to existing joints, avoiding crop-origin snap
   gaps. Their exact points and rationale are in `joint_continuations.json`.
   They remain hidden at rest and use their own head/torso surface texels. The
   existing shoulder continuation keeps its alpha and now uses mq7b own-arm
   donors. Removal tests reopen front jab 11/12, rear death 71, the five nape
   defects and all pinned gait defects. No new painted area, motion change or
   seam exemption was used. Both raw mq7b rests remain **0 px mismatch**.
5. **Headless proof.** The source, bone, reach, direction, support, gait-01,
   hem, residue and CPU seam checks cover both views. Each CPU view scans
   **335 frames with zero failing frames**. The exact focused results and
   commands are recorded in [feedback1_verification.json](feedback1_verification.json).
   Native acceptance remains a separate director step.

The skirt/belt remains on `pelvis` / `loincloth_tip` above both thighs. Its
maximum follow-through is **3.605543 px front / 3.605532 px rear**, and the end
delta is zero in every clip. All motion, timing, contacts, skeleton and the
rr-05 presentation remain unchanged. Every sampled frame has zero keyed-green
residue. Density paint is rebuilt for 189 files. The 26,355-file protection
audit covers all other figures, the paintings and the protected director input;
unrelated registry records are retained.

## Files changed

- `../rr24_build.py`, `joint_continuations.json`, case layouts/pieces/checks
  and production `assets/units/arc_thrall_cutout/`: head priority and covered
  own-surface continuations; refreshed Thrall density sources and records.
- `../rr24_seams.py`, `../rr24_check.py`, `../rr24_native_gates.py`,
  `../rr24_native_proof.py`, `../rr24_native_capture.gd`, `../rr11_gates.py`
  and `../rr11_proof.sh`: case-local policy, full native validation adapter,
  proof composition and immediate per-piece evidence hashes. The shared
  `tests/rr11/native_capture.gd` is unchanged. Every shared validator failure
  survives except a strict seam error whose complete pocket set passes the
  decided case air policy.
- `../rr24_baseline.py`, `repaint_baseline.json`, `repinned_tests.json`,
  `feedback1_shoulder_before.png`, Thrall rr-15/gait test sections and the two
  `tests/test_rr24*.py` files: explicit new baselines, regressions and mutations.
- Current contract, proof reports and this handoff. The complete per-file
  inventory is [feedback1_files_changed.txt](feedback1_files_changed.txt).

## Observed verification

Observed verification (full commands, logs and result lines are in the JSON
verification record above):

```text
Ran 327 tests in 446.644s
OK
RR24 CPU FRONT SEAMS: PASS (335 frames; 0 failing frames; native acceptance pending)
RR24 CPU REAR SEAMS: PASS (335 frames; 0 failing frames; native acceptance pending)
RR11 RUNTIME: PASS (5722 checks; headless logic only)
RR11 NATIVE PROBE LOAD: PASS
SFX SYNC HARNESS RESULT: PASS (4075 observations, 0 failures)
SFX SYNC HARNESS RESULT: PASS (3348 observations, 0 failures)
SFX SYNC HARNESS RESULT: PASS (1604 observations, 0 failures)
Ran 111 tests in 44.400s
OK
TEST REGISTRATION AUDIT: PASS (751 scripts; full suite=407, quarantined=29, windowed probe=315)
RR24 PROTECTED IDENTITY: PASS (26355 files; unrelated registry records retained)
```

All nine guard-removal mutations were caught by assertions, with zero mutation
errors. The first feedback run had one inventory failure (327 tests in
407.367s); the explicit baseline recorder omitted three untracked density-source
PNGs. The complete source root is now pinned and the final rerun passes.

## Chosen defaults

No player-facing values were chosen. New policy fixtures use the named
`FIXTURE_*` fields in `tests/test_rr24_policies.py`: a 24 px canvas, body
`[4:20,4:20]`, air `[8:12,8:12]`, split x=10, cloth/skin/joint punches
`[5:7,6:8]`, `[5:7,12:14]`, `[5:7,9:11]`, and immutable-mask RGBA
`(255,0,0,255)`. The native wrapper's resource UID is engine-generated.

Retained proof-only defaults are six columns by three rows of 320x360 cells,
2x nearest-neighbour crops, 4 px margin and 20 px labels. The canvas is the
required 1920x1080; background `#1E1E24`, source origin 128 and 60 fps reuse
the existing proof pipeline. The initial handoff records the unchanged
head/hem mutation and skin-donor fixture values.

## Proof for the design owner

Run in this order at 1920x1080, 100% UI scale. No windowed command was attempted
by this worker. `density` rebakes real native rests, records them, refreshes
only Thrall shadows, checks density and seals the pending integration record.
`native` produces GPU isolated pieces/check masks and the policy report.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-24 && sh experiments/cutouts/arc_thrall/rr24_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-24 && sh experiments/cutouts/arc_thrall/rr24_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-24 && sh experiments/cutouts/arc_thrall/rr24_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-24 && sh experiments/cutouts/arc_thrall/rr24_proof.sh crops
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-24 && sh experiments/cutouts/arc_thrall/rr24_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-24 && sh experiments/cutouts/arc_thrall/rr24_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-24 && sh experiments/cutouts/arc_thrall/rr24_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-24 && sh experiments/cutouts/arc_thrall/rr24_proof.sh review
```

Intended capture paths, all gitignored under `../rr11/proof/`:
`native_rest/`, `native/` (including `rr24_policy_report.json`),
`rr24_crops/` (44 collar/hem pages covering every move/arc_jab/death frame,
both views), `contact_sheets/`, `idle_native/`,
`production_native/{front,rear}/`, `thrall_protagonist_idle.mp4` and
`arc_thrall_review.mp4`. No new renderer captures were produced headless.
The brief requests no inspection-fixture command; that remains owner work.

## Open issues

No unresolved design questions remain. The density record check exits 1 with
`rest rebake needed` for the two v2 and retained legacy rests. Native
rest/density records, shadows, GPU seam/ownership results and visual inspection
await the director's sequence; this is not a claim of finished native proof.
The headless probe load verifies executable loading and masks; it does not
certify renderer pixels. Incidental macOS certificate and shutdown resource
messages, where emitted, are retained in logs alongside the observed exit codes.
