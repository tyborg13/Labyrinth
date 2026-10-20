# rr-27 feedback 1

Rear repair is applied. Both views pass the strict census. **None of the
three prescribed Tether pairs qualifies**, so no Tether motion edit was
installed and no alternative value was chosen. All changes remain uncommitted.

## 1. Rear continuation removals

`continuation_removals.json` now drives `rr27_build.py`:

- `mq7b_continuation_leg_far`: source `(171,218)`, local `(53,97)`. The copy
  was baked into the hidden continuation output. Remove that output texel in
  both case and density-treated production, preserving every other RGBA value.
- `mq7b_continuation_leg_near`: source `(109,179)`, local `(17,60)`. Remove
  this entry from the case, production and retained mq7b gait recipe tables.

The far copy's generated check mask and required-tuck raster lose that same
point; its derived required-pixel count and source hash are refreshed. This
removes the obsolete requirement generated from the copied texel. It does not
add a frame exception or alter the canonical classifier. The rest composites
and approved paintings remain exact. Source/cut gates pass independently.
Production keeps its existing density-treated colours; only this one copied
texel is cleared. No shared density registry, manifest, source calibration or
shadow cache was changed. Coordinate their refresh with int-03/director.

`rr27_preservation.py` checks the four generated PNG outputs against the
original pixels, permitting exactly the declared point in each. Original
baseline values are retained. Mutation tests restore each removed copy in
memory and reproduce its original detached component. The accepted front
11-copy `jab`/`death` recipe is unchanged.

## 2. Tether: all three prescribed paths fail

Each temporary author file uses the exact requested six keys per channel,
with A's 65/153 hold and the intermediate pair at .2 and .9. Each is compiled
with the existing `humanoid_cutout.compiler.compile_motion`. The main staged
director file, imported copies and production compiled motion remain exact.
Candidate hashes bind the compilation, Godot samples and evaluator.

| Intermediate (F,L) | Torso crossing samples, raise / lower | Snapped bend-side flips, raise / lower | Maximum elbow step px, raise / lower | Qualifies |
|---|---:|---:|---:|---|
| (10,110) | 17/32 / 12/19 | 6 / 4 | 23.345 / 42.720 | No |
| (0,90) | 11/32 / 8/19 | 2 / 2 | 33.601 / 40.817 | No |
| (20,130) | 21/32 / 13/19 | 4 / 4 | 38.328 / 51.430 | No |

The 60fps inventory is the actual 72-frame clip, phase `frame/71`, plus the
exact requested strip phases and .5. This gives 84 poses per candidate,
252 total. The raise interval contains 25 actual presented frames plus
seven additional exact phases; lower contains 15 plus four.

Unsnapped authored IK bend-side signs do **not** reverse. The table's flips
are in the presented, snapped shoulder/elbow/terminal triangle. Maximum elbow
steps are measured between consecutive 60fps frames; no new step-distance
acceptance threshold was invented. Frame pairs and positions are retained in
`tether_study/feedback1/cpu_sheets/result.json`.

Torso crossing uses the initial study's explicit measurement: the interior
10–90% of the shoulder–elbow or elbow–cap centreline intersects isolated rigid
torso alpha. Separate full alpha-overlap counts include attachment contact.
Under that measurement even the common A hold at .35/.8 crosses the torso:
cap `(226,146)`, elbow `(229,247.75)` on the 512px source canvas. This is a
constraint to resolve alongside the intermediate path. No socket allowance
or new crossing interpretation was introduced.

Requested 3x nearest-neighbour strips, with cap and elbow under every frame:

- [10/110 raise](tether_study/feedback1/cpu_sheets/F10_L110_raise_3x.png), [lower](tether_study/feedback1/cpu_sheets/F10_L110_lower_3x.png)
- [0/90 raise](tether_study/feedback1/cpu_sheets/F0_L90_raise_3x.png), [lower](tether_study/feedback1/cpu_sheets/F0_L90_lower_3x.png)
- [20/130 raise](tether_study/feedback1/cpu_sheets/F20_L130_raise_3x.png), [lower](tether_study/feedback1/cpu_sheets/F20_L130_lower_3x.png)

These are inspected **CPU estimates**, rendered from the existing approved
textures and actual Godot pose records. No windowed run was attempted. Native
probe/contract/evaluation commands are below.

**Changed production pose rows: none**, including rear Tether and both rear
removals. All 1,050 raw pose rows remain byte-identical to the original
inventory. No Tether pair was installed because all three failed. The exact
changed-row list is the empty `changed_pose_rows` list in `preservation.json`.

## 3. Proof

Focused suite: `Ran 127 tests in 138.543s` / `OK`, retained in
`feedback1_tests.log`. The final Thrall-only rerun, including the new
candidate-hash tamper guard, reports `Ran 11 tests in 6.204s` / `OK` in
`feedback1_thrall_final.log`. No full suite, peer review or windowed proof was run,
as directed. Source/bone/direction/reach/gait/support checks pass. Runtime:
`RR11 RUNTIME: PASS (5722 checks; headless logic only)`. Native probe
`--validate-only` reports `RR11 NATIVE PROBE LOAD: PASS` and takes no screenshot.

```text
RR27 STRICT CENSUS FRONT: PASS (335 frames; 0 unmatched detached; 0 pocket failures)
RR27 STRICT CENSUS REAR: PASS (335 frames; 0 unmatched detached; 0 pocket failures)
RR27 POSE ROW IDENTITY: PASS (1050 rows; 0 changed raw rows)
RR27 PAINT/REST/MOTION IDENTITY: PASS (440 protected files; 4 authorized copy-removal outputs; 0 unexpected)
RR27 TETHER STUDY LOGIC: PASS (252 poses; in-memory keys only)
RR27 TETHER PAIR [10, 110]: FAIL (raise/lower crossing samples 17/12; bend flips 6/4)
RR27 TETHER PAIR [0, 90]: FAIL (raise/lower crossing samples 11/8; bend flips 2/2)
RR27 TETHER PAIR [20, 130]: FAIL (raise/lower crossing samples 21/13; bend flips 4/4)
RR27 TETHER FEEDBACK SELECTION: NONE (all prescribed pairs fail; director data retained)
```

The Tether evaluator intentionally exits 1 for this rejected set. One rr-24
raster run completed with zero frame defects but rejected its bindings while
the focused tests created a temporary bound runtime fixture. It was rerun
after the suite finished; use `feedback1_raster_final.log`. Do not overlap
the broad focused tests with input-bound capture/check finalization.

Headless reproduction from this worktree, in sequence:

```sh
python3 -B experiments/cutouts/arc_thrall/rr27_build.py
LABYRINTH_TASK_ID=rr-27 OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 python3 -B experiments/cutouts/arc_thrall/rr27_focused.py
python3 tools/godot_task_runner.py --task-id rr-27 --stream -- godot --headless --path . --script tests/rr11/action_direction.gd -- --case res://experiments/cutouts/arc_thrall/rr11 --output res://experiments/cutouts/arc_thrall/rr11/proof/samples.json
python3 -B experiments/cutouts/arc_thrall/rr11_gates.py
python3 -u -B experiments/cutouts/arc_thrall/rr27_check.py
python3 -u -B experiments/cutouts/arc_thrall/rr24_check.py --raster
python3 tools/godot_task_runner.py --task-id rr-27 --stream -- godot --headless --path . --script tests/rr11/runtime_checks.gd
python3 -B experiments/cutouts/arc_thrall/rr27_tether_feedback.py prepare
python3 tools/godot_task_runner.py --task-id rr-27 --stream -- godot --headless --path . --script experiments/cutouts/arc_thrall/rr27_tether_study.gd -- --feedback-1 --logic-only
python3 -u -B experiments/cutouts/arc_thrall/rr27_tether_feedback.py evaluate
```

## Proof for the design owner

Exact rr24 sequence at 1920x1080, 100% UI scale; stop at a failed stage.
Density/manifest/shadow coordination remains director/int-03-owned.

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

Outputs remain under `rr11/proof/`: `native_rest/`, `native/`, `rr24_crops/`,
`contact_sheets/`, `idle_native/`, `production_native/` and the review reels.
No inspection-fixture command is requested by this unit brief.

For native confirmation of the three rejected Tether candidates, regenerate
their proof inputs after any integration/binding change, then run:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-27 && python3 -B experiments/cutouts/arc_thrall/rr27_tether_feedback.py prepare
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-27 && python3 tools/visual_probe_runner.py --task-id rr-27 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --expect-size 512x512 --proof-contract experiments/cutouts/arc_thrall/rr27/tether_feedback_contract.json --result-manifest experiments/cutouts/arc_thrall/rr27/tether_study/feedback1/native_runner.json experiments/cutouts/arc_thrall/rr27_tether_study.gd -- --feedback-1 --output res://experiments/cutouts/arc_thrall/rr27/tether_study/feedback1/native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-27 && python3 -u -B experiments/cutouts/arc_thrall/rr27_tether_feedback.py evaluate --native
```

This writes raw frames/isolated masks to `tether_study/feedback1/native/` and
the six strips plus verdict to `native_sheets/`. It changes no director data.

## Files, TODO_DESIGN, and chosen defaults

Changed implementation: rear continuation outputs/layouts/recipe tables and
their build/check records; `rr27_build.py`; exact removal preservation helper;
the existing Thrall baseline assertion adapter; feedback candidate compiler,
sampler and evaluator; focused Thrall tests. The new proof artifacts are in
`tether_study/feedback1/`. `feedback1_files_changed.txt` inventories every file.
The old baseline values, other units and shared registries are untouched.

`TODO_DESIGN_REAR_COMPONENT_REPAIR` is resolved. The remaining placeholder is
`TODO_DESIGN_REAR_TETHER_PATH` in the feedback verdict: all three supplied
pairs fail, and no fourth value was selected.

Chosen defaults affect proof only: existing 840x960 cells, 120px caption area,
18px caption font, 24px pitch, 8px inset, 4px shared crop margin, 3x nearest
scaling, background `#1E1E24`, and the existing native camera. Phase comparison
tolerance is `1e-9`; bend collinearity uses the existing normalized `1e-6`
bone-contract tolerance. The prescribed 60fps, phases, candidate pairs and
hold values are unchanged. No gameplay or design value was chosen.
