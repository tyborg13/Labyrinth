# rr-24 implementation handoff

**Historical pre-feedback handoff.** The director resolved both design questions
and authorized the repaint re-pins. See [the current feedback 2 handoff](feedback2.md)
for the passing headless results, changed files and exact windowed commands.
The text below records the superseded initial state.

Changes are uncommitted on `codex/rr-24`. This is **not an accepted/ready rig**:
literal collar clearance and presented negative-space decisions remain open,
and the director must perform the native rest/shadow/capture sequence. No
reviewer, commit, publication, queue update, windowed run or full suite was run.

## Numbered requirements

1. **mq7b re-cut:** both raw source partitions reconstruct their supplied
   painting with **0 px RGBA mismatch**. `raw/` retains the complete source-space
   partitions; the protected jobs and director file were never edited. The
   skinned limbs, closed tube, shoulder joints, original skeleton, skin fields
   and motion remain. `baseline/` freezes the prior gait-01 closure. The director's
   existing residue rule (G >= max(R,B)+12 and G >= 1.5*max(R,B)) replaces five key
   texels in derived presentation only: one front, four rear. Olive collar
   paint remains. Cleaned presentation also reconstructs with 0 px mismatch.
2. **Collar:** the band, front lock and chain are rigid `torso` paint. Front
   head priority and rear collar priority retain the painting's occlusion.
   CPU rigid-mask clearance is **0 px minimum in each view**. The front jaw
   contacts the band by one pixel in death frames **41, 66, 70, 72**. No front
   idle, walk, jab, tether or hit frame contacts the traced jaw. The rear has
   no painted jaw/mouth; its 0 px figure measures the lower head/nape, which
   contacts the collar during articulation. This is not a claim of clearance.
3. **Skirt:** the full wrapped hide and rope belt are one `loincloth` mesh on
   `pelvis` / `loincloth_tip`, above both thigh meshes. Hidden thigh material
   comes from that leg's own non-outline skin texels, with covered thigh
   domains from the certified maquette. Maximum sampled follow-through is
   **3.605543 px front / 3.605532 px rear**, including snapped parent frames;
   every clip's final two attachment-relative offsets agree. All original
   motion, timing and contacts are retained. Gait-only skin coverage is rebuilt.
4. **Gates and integration:** density paint is adopted/processed. Real native
   rest rebake, rest records and shadow refresh are pending. The existing
   headless source, bone, direction, reach, knee and support gates are run;
   new checks cover raw/presentation identity, ownership, skin donors, residue,
   collar contact and hem settling. CPU seam diagnostics are explicitly not
   native acceptance and retain unresolved non-move pockets. Other figures
   and unrelated registry records are checked independently.

## Files and reproduction

- `../rr24_build.py`: replayable cut, raw/presentation split, covered fills,
  fixed bone/skin/presentation metadata and production promotion. Its gait
  target guard rejects stale coordinate recipes after texture-domain changes.
- `ownership.json`, `raw/`, `baseline/`, `gait_continuations.json`: source
  contours, exact raw partition, frozen geometry and final gait-only recipes.
- `../rr24_check.py`, `../../../../tests/test_rr24_thrall.py`,
  `../rr24_mutations.py`: headless contracts, diagnostics and in-memory guard
  removal mutations. No mutation changes a working source file.
- `../rr24_crops.py`, `crop_contract.json`, `../rr24_proof.sh`: native-only,
  current-input-bound collar/hem sheets for every move, arc_jab and death frame
  in both views, on 1920x1080 sheets.
- Current `../rr11/` source/cut/check/seam/tuck/layout/gait artifacts;
  `assets/units/arc_thrall_cutout/` production closure; only Thrall records and
  sources in the identity and density registries. `files_changed.txt` lists
  the complete working-tree change inventory.

Rebuild from the worktree root:

```sh
python3 -B experiments/cutouts/arc_thrall/rr24_build.py
python3 -B experiments/cutouts/arc_thrall/rr11_density.py --refresh-sources
```

The rr-11/rr-15 builders are historical recipes. Do not use them to initialize
this repaint. If source domains change again, run `rr11_gait_coverage.py` with
fresh bone samples, save its resulting `rr11/gait_continuations.json` here,
then replay this builder. `proof/build.json` binds the derivation hashes.

## TODO_DESIGN placeholders and open issues

- `TODO_DESIGN_COLLAR_DEATH_CLEARANCE` in case inputs/cutout data: four front
  death contacts remain with the approved paint and locked motion. The front
  head renders above the band, but that does not satisfy a literal geometric
  no-overlap requirement. The per-frame measurement is in `checks.json`.
- `TODO_DESIGN_PRESENTED_NEGATIVE_SPACE`: CPU diagnostics find pockets where
  source space that is open at rest closes during articulation. One reproducible
  example is front tether frame 17, native-canvas bounds `[265,305,268,309]`,
  **8 px**, bounded by skirt and near thigh. All inverse-projected skin fill
  candidates (source x141–143, y177–180) are transparent in the final painting.
  A permanent fill would break raw/rest identity. Native inspection is needed
  before deciding whether this is natural negative space; action-only fills
  outside the existing gait path would need a shared runtime extension. No
  exception was invented and no generic code was changed.
- Density `--check` correctly reports missing native rebake records. Shadow
  records remain the previous director-certified ones until the density stage.
- Existing rr-15/gait-01 tests that require mq7 paint, crop and old seam-removal
  fixtures to stay byte-identical conflict with this requested repaint. Their
  assertions were retained. Exact failures and logs are recorded below.

## Chosen defaults

Only proof/test values were chosen. Crop sheets use 6 columns x 3 rows of
320x360 cells, 2x nearest-neighbour crops, 4 px crop margin and 20 px labels;
the 1920x1080 canvas is specified, and background `#1E1E24`, 60 fps and source
origin 128 reuse the existing proof pipeline. New test fixtures use a 10 px
head/hem mutation, foreign fill RGBA `(255,0,255,255)` and a synthetic skin
donor `(100,70,50,255)`. Green `(0,26,7,255)` and olive `(35,51,37,255)` are
existing approved-source examples. Progress interval 50 and float tolerance
0.0001 reuse existing diagnostic conventions. No gameplay values were chosen.

## Proof for the design owner

No windowed command was attempted: this worker has no window-server access.
Run the sequence below at 1920x1080 and 100% UI scale. Each wrapper calls the
existing `tools/visual_probe_runner.py` contracts. `density` performs the real
rest rebake, records rests, refreshes only Thrall shadows, checks density and
seals the pending integration record. `crops` can run after `native` even if
the native gates require owner decisions; sheets/review require passing gates.

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

All captures are gitignored under `../rr11/proof/`: `native_rest/`, `native/`,
`rr24_crops/` (44 pages, including collar and hem for each clip/view),
`contact_sheets/`, `idle_native/`, `production_native/{front,rear}/`,
`thrall_protagonist_idle.mp4` and `arc_thrall_review.mp4`. These are intended
paths, not captures produced by this worker. No inspection-fixture command is
requested by this brief; fixture preparation belongs to the design owner.

## Observed verification

Final exact result lines, command inventory and log paths are in
`verification.json`. No full Godot or Python suite was run, as directed by the
unit brief. Godot runs used the rr-24 runner; headless probe validation loaded
the real rig and masks without taking screenshots.

```text
Ran 11 tests in 2.866s
OK
RR24 MUTATION collar_attachment: CAUGHT
RR24 MUTATION skirt_depth: CAUGHT
RR24 MUTATION cloth_chain: CAUGHT
RR24 MUTATION collar_contact: CAUGHT
RR24 MUTATION hem_limit: CAUGHT
RR24 MUTATION own_skin: CAUGHT

Ran 318 tests in 408.291s
FAILED (failures=19, errors=2)

RR11 SOURCE/CUT GATES: PASS (0 errors; both views)
RR11 BONE/CUT/KNEE GATES: PASS (0 errors)
RR11 RUNTIME: PASS (5722 checks; headless logic only)
RR11 NATIVE PROBE LOAD: PASS
SFX SYNC HARNESS RESULT: PASS (4075 observations, 0 failures)
SFX SYNC HARNESS RESULT: PASS (3348 observations, 0 failures)
SFX SYNC HARNESS RESULT: PASS (1604 observations, 0 failures)
Ran 111 tests in 42.755s
OK
TEST REGISTRATION AUDIT: PASS (751 scripts; full suite=407, quarantined=29, windowed probe=315)
RR24 PROTECTED IDENTITY: PASS (26355 files; unrelated registry records retained)
```

The broad run's 19 failures are six retained rr-15 paint/crop/continuation
assertions, gait-01's no-PNG-changes assertion, and twelve old seam-removal
subtests whose old fixture no longer applies. Its two errors are gait-01's
fixture looking up the old `leg_far` continuation recipe (`KeyError`); the
new coverage resides in the hidden layers. No Seer, Mirror or Capacitor test
failed. No assertion was rewritten.

The final CPU report is current-input bound and scans 335 presented frames per
view. All gait frames have zero reported seam defects; unresolved non-move
diagnostics affect **51 front frames** (45 tether, six jab) and **five rear
death frames**. These are failures, not approved natural-space exceptions.
Every checked presentation frame has zero keyed-green residue. Rigid collar
clearance is measured separately and remains open as described above.

Density checking exits 1 with `rest rebake needed` for the two v2 views and
their retained legacy rest records. The director's `density` command is the
required next step for those records and shadows. There are no new native
captures to inspect in this worker's handoff.
