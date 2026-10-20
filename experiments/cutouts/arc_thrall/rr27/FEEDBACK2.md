# rr-27 feedback 2

The director's exact rear Tether path **(0,90)** with A's **65/153** hold is
installed and compiled. Both-view strict census, pose scope and action
direction pass. **The existing minimum-reach gate fails** during lowering:

```text
rear/tether/tube_tip: minimum reach 25.770794 px < 60.466233 px at 0.842910645
```

No path, reach threshold or waiver was chosen to resolve that conflict. The
approved data remains installed. Changes are uncommitted on `codex/rr-27`.

## 1. Exact director import

Only `arc_thrall.clips.tether.view_keys.rear` changed in the staged director
file:

```json
{
  "tube_tip.forward_px": [[0,0],[0.2,0],[0.35,65],[0.8,65],[0.9,0],[1,0]],
  "tube_tip.lift_px": [[0,0],[0.2,90],[0.35,153],[0.8,153],[0.9,90],[1,0]]
}
```

`rr15_motion_import.py --owned-only` calls the existing `compile_motion`
pipeline, imports the director bytes into the case and production, and
refreshes the owned integration closure and build record. The new flag
avoids shared registry writes; the original default import behavior remains.
Front keys, every other channel, paint, layouts and rest remain exact.
Compiled tracks equal the selected 0/90 study, excluding the author digest.
The existing [raise](tether_study/feedback1/cpu_sheets/F0_L90_raise_3x.png)
and [lower](tether_study/feedback1/cpu_sheets/F0_L90_lower_3x.png) strips show
that exact selected motion, with cap/elbow captions. They are CPU estimates,
not fresh renderer captures. The director's feedback 2 supersedes the
historical study's crossing/flip verdict.

## 2. Pose identity

`rear_tether_feedback2_pin.json` records the exact authorized rows with an
explicit feedback-2 authority comment. `rr27_tether_identity.py` checks all
five director/imported/compiled files against the pre-edit revision
`64f394c7e1793b4899e7063cbfef90acf3c64331`, allowing only these two channels.
It checks raw JSON row bytes, including their order, outside rear Tether.

- All **959** rows outside rear Tether are byte-identical. Their before and
  after SHA-256 is `16d8eaeb92aeab0bbdcec03eb844e2d1af6d5e173180b9022fc15c4dbc0b55e8`.
- Changed presented rows: rear / `tether` / frames **1 through 70**, inclusive.
- Changed authored rows: rear / `tether` / phases **0.175, 0.35, 0.425, 0.5,
  0.525, 0.55, 0.575, 0.6, 0.625, 0.65, 0.675, 0.7, 0.725, 0.75, 0.775,
  0.8, 0.9**.
- Added authored rows: rear / `tether` / phases **0.1, 0.2, 0.275, 0.85,
  0.95**. No rows removed. These are the sampler's additional key/midpoint
  coverage, not additional animation channels.
- Four original rear Tether endpoint rows also remain exact. Thus 963 of
  the 1,050 original rows are unchanged; the new inventory has 1,055 rows.
- Rear continuation removals change **zero** pose rows. The accepted front
  11-copy repair is unchanged. All PNG files are byte-identical to the start
  of this feedback, including rest composites.

The full changed/added row lists and rear raw-row hash are in the pin and
`preservation.json`. Mutation checks reject both an unapproved front row and
an unapproved rear Tether row. Original preservation pins remain recorded;
the adapters permit only the exact director-authorized deltas.

The old shoulder-hole fixture keeps its captured rear Tether pose from the
pre-edit revision. Its hole/pixel assertions remain unchanged. Current rear
Tether is covered separately by the complete census and raster checks.

## 3. Census and gates

```text
RR27 POSE ROW IDENTITY: PASS (959 other rows byte-identical; 87 changed + 5 added rear tether rows)
RR27 PAINT/REST/MOTION IDENTITY: PASS (440 protected files; 4 copy-removal outputs; 4 rear-tether motion outputs; 0 unexpected)
RR27 STRICT CENSUS FRONT: PASS (335 frames; 0 unmatched detached; 0 pocket failures)
RR27 STRICT CENSUS REAR: PASS (335 frames; 0 unmatched detached; 0 pocket failures)
RR24 CPU FRONT SEAMS: PASS (335 frames; 0 failing frames; native acceptance pending)
RR24 CPU REAR SEAMS: PASS (335 frames; 0 failing frames; native acceptance pending)
RR11 SOURCE/CUT GATES: PASS (0 errors; both views)
RR15 FRONT ACTION DIRECTION: PASS (501 positive checks)
RR15 REAR ACTION DIRECTION: PASS (480 positive checks)
RR15 FRONT REACH: PASS (11 keyed paths; 1000 intervals; 0 errors)
RR15 REAR REACH: FAIL (11 keyed paths; 1000 intervals; 1 errors)
RR11 BONE/CUT/KNEE GATES: FAIL (1 errors)
```

The canonical source-space classifier has no new exemptions. Knees, support
and gait checks pass. Rear Tether's dense adaptive reach result has 2,967
samples, minimum 25.770793547018958 px at phase 0.84291064453125, against
allowed minimum 60.46623337217056 px. Its maximum 143.78108633690925 px is
below allowed maximum 147.56395249010973 px. The failing minimum assertion
is retained. This is the sole gate conflict, recorded as
`TODO_DESIGN_REAR_TETHER_REACH_CONFLICT` in `feedback2_verification.json`.

## 4. Records and focused proof

Regenerated owned headless records: director imports, compiled motion, build,
Godot samples, direction/reach/support/gates, strict census, preservation,
and rr-24 raster/source checks. Final commands and observed result lines
are recorded in `feedback2_verification.json`; logs are named
`feedback2_*.log`. No full suite, peer review or windowed run was performed.

```text
RR15 MOTION IMPORT: PASS (director byte-identical; accepted paint/layouts unchanged)
RR10 BONE SAMPLES: PASS (1055 poses; headless transforms only)
RR11 RUNTIME: PASS (5722 checks; headless logic only)
RR11 NATIVE PROBE LOAD: PASS
```

The focused suite retains two failing minimum-reach assertions for the
approved rear Tether path; no failing reach assertion was weakened. The
final focused result is:

```text
Ran 130 tests in 137.414s
FAILED (failures=2)
```

Both failures are in `tests.test_rr15_reach.ReachTests`:
`test_current_data_passes_with_documented_overreach` and
`test_new_rear_paths_clear_minimum_margin_and_maximum_in_dense_samples`.
The targeted shoulder/Thrall rerun passed (`Ran 15 tests in 11.237s` / `OK`).
After naming the unchanged one-pixel debug mutation, its final isolated
check passed (`Ran 1 test in 0.813s` / `OK`).
The earlier full focused log has an additional historical shoulder-pose
fixture failure; `feedback2_tests_final.log` is the final suite result after
that fixture's pose source was corrected. Godot also emitted the existing
macOS certificate message, image-load warnings and shutdown resource
warnings; the headless load check supplies no renderer acceptance.

Headless reproduction, sequentially from this worktree (the gates and
focused suite intentionally exit 1 until the reach conflict is resolved):

```sh
python3 -B experiments/cutouts/arc_thrall/rr15_motion_import.py --owned-only
LABYRINTH_TASK_ID=rr-27 OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 python3 -B experiments/cutouts/arc_thrall/rr27_focused.py
python3 tools/godot_task_runner.py --task-id rr-27 --stream -- godot --headless --path . --script tests/rr11/action_direction.gd -- --case res://experiments/cutouts/arc_thrall/rr11 --output res://experiments/cutouts/arc_thrall/rr11/proof/samples.json
python3 -B experiments/cutouts/arc_thrall/rr27_tether_identity.py
python3 -B experiments/cutouts/arc_thrall/rr11_gates.py
python3 -u -B experiments/cutouts/arc_thrall/rr27_check.py
python3 -u -B experiments/cutouts/arc_thrall/rr24_check.py --raster
python3 tools/godot_task_runner.py --task-id rr-27 --stream -- godot --headless --path . --script tests/rr11/runtime_checks.gd
python3 tools/godot_task_runner.py --task-id rr-27 --stream -- godot --headless --path . --script experiments/cutouts/arc_thrall/rr24_native_capture.gd -- --case res://experiments/cutouts/arc_thrall/rr11 --output res://experiments/cutouts/arc_thrall/rr11/proof/native --validate-only
```

The rear pose pin is an explicit director-authorized record, never regenerated by
the focused tests. Ordinary reproduction checks it without repinning.

## Proof for the design owner

No windowed command was attempted. Exact rr24 sequence, at 1920x1080 and
100% UI scale, stopping at a failed stage:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-27 && LABYRINTH_TASK_ID=rr-27 sh experiments/cutouts/arc_thrall/rr24_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-27 && LABYRINTH_TASK_ID=rr-27 sh experiments/cutouts/arc_thrall/rr24_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-27 && LABYRINTH_TASK_ID=rr-27 sh experiments/cutouts/arc_thrall/rr24_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-27 && LABYRINTH_TASK_ID=rr-27 sh experiments/cutouts/arc_thrall/rr24_proof.sh crops
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-27 && LABYRINTH_TASK_ID=rr-27 sh experiments/cutouts/arc_thrall/rr24_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-27 && LABYRINTH_TASK_ID=rr-27 sh experiments/cutouts/arc_thrall/rr24_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-27 && LABYRINTH_TASK_ID=rr-27 sh experiments/cutouts/arc_thrall/rr24_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-27 && LABYRINTH_TASK_ID=rr-27 sh experiments/cutouts/arc_thrall/rr24_proof.sh review
```

The native stage runs the existing gates and is blocked by the documented
reach conflict. Density/manifest/shadow coordination belongs to int-03 and
the director. Expected captures remain under `rr11/proof/native_rest/`,
`native/`, `rr24_crops/`, `contact_sheets/`, `idle_native/`,
`production_native/`, `thrall_protagonist_idle.mp4` and `arc_thrall_review.mp4`.
The brief requests no inspection-fixture command; the director owns that.

## Files, placeholders, chosen defaults and open issues

`feedback2_files_changed.txt` inventories every changed/new file relative to
the supplied feedback-2 HEAD. Implementation files: staged director data;
case/production imports and owned integration; import/scope/preservation
helpers; Thrall tests and their historical fixture adapters. The remaining
changes are derived records and this handoff. No shared registry, density
manifest, shadow cache or other unit was changed.

`TODO_DESIGN_REAR_COMPONENT_REPAIR` and `TODO_DESIGN_REAR_TETHER_PATH` are
resolved. Their occurrences in historical study documents remain historical.
The one open placeholder is `TODO_DESIGN_REAR_TETHER_REACH_CONFLICT`; no
further player-visible value was selected. Native proof is pending.

Chosen defaults: one pixel of synthetic pose corruption in the pin rejection
test, stored in its named test field; existing proof layout, timeouts and
tolerances are reused. No gameplay/design defaults were chosen.
