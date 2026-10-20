# rr-27 implementation handoff

Changes are uncommitted on `codex/rr-27`. No peer review, publication, queue
edit, windowed run, density processing or shadow/registry change was made.
The prepared task contract/preflight was supplied by the design owner. This
unit is **incomplete** under the original rear attachment-only instruction.

## Numbered requirements

1. **Rear move: unresolved.** Both specified texels have an eight-connected
   neighbour in their own active piece, and both already have exactly that
   neighbour's weights: 100% `shin_far` / `shin_near`. The Seer attachment
   method therefore leaves the same detached pixel. The diagnostic preserves
   every opaque texel in a replaced cell and tests the actual canonical gate.
   `rear_attachment_diagnostic.json` records the exact source points, weights,
   trials and unchanged failing presented pixels. No rear production edit was
   made. The brief permits removal only **without** an in-piece neighbour;
   extending that condition requires the director's decision.
   `removal_proposal.json` is an **unapplied**, all-335-rear-frame counterfactual:
   removing the far copied hidden texel `(171,218)` and the near gait recipe
   target `(109,179)` gives zero detached components and zero pockets. It is
   evidence for a decision, not a claim that the current rear census passes.
2. **Front pockets: implemented.** `upper_near` gains 11 coordinate-only donor
   copies through `gait_continuations`, with `clips: ["jab", "death"]`. Nine
   close the specified tears; two more close the joint pocket that those
   copies otherwise enclose at the start of jab/death. Donors are the existing
   density-treated texels of that same piece. Every other clip selects its
   original texture. `joint_continuations.json` retains the inverse-source
   traces, and `rr27_build.py` replays the edit without rebuilding paint.
3. **Strict census: incomplete.** `census.json` uses canonical
   `source_space.py` and the independent rr-24 joint-tear result, without
   frame exemptions. Front: 335 frames, 0 unmatched, 0 pocket failures.
   Rear: 335 frames, 2 unmatched, 0 pocket failures. The only rear failures
   remain move 14 `(340,319)` and move 23 `(323,269)`.
4. **Pose/rest identity: implemented.** All 1,050 original raw JSON pose rows
   are byte-identical, including both views, all clips, authored/presented and
   continuous-direction evidence. **Changed/reweighted pose rows: none.**
   All 440 protected current-case/production PNG and motion files are exact;
   source/rest composites remain exact. The full hash ledger is
   `preservation.json`. No motion or Tether data was edited.
5. **Tether study: headless study and native tooling implemented.**
   `tether_study/cpu/hold_contact_sheet_3x.png` contains current plus A–D at
   phase .5; each candidate has `<candidate>_raise_3x.png` at phases
   0/.1/.2/.3/.35/.5. These are explicitly labelled **CPU estimates**. Real
   snapped Godot poses supply the geometry; existing approved textures supply
   every rendered pixel. No new art was made. The director's native probe and
   proof contract are ready; native images have not been captured.

The study's cap coordinate is the transported rest `tube_tip` landmark,
floored to the 512px presented canvas with source origin `(128,128)`. Elbows
are reported in that same canvas. “Torso axis crossing” tests the interior
10–90% of the shoulder–elbow / elbow–cap centreline against isolated torso
alpha. Separate alpha-overlap counts include attachment contact. These are
explicit reproducible measurements for inspection, not an aesthetic verdict.
The native composer measures real isolated renderer masks and refuses CPU,
stale, incomplete or tampered capture evidence.

## Verification

The brief's **focused-only** proof restriction was followed; no full suite was
run. `focused_tests_final.log` retains the final 124-test result. The earlier
run (`focused_tests.log`) exposed two outdated gait-only/layout assumptions
and a canonical-record test's missing ignored scratch directory. Tests now
verify clip-scoped selection on every clip in both case and production, and
allow exactly the new front continuation table while preserving all original
baseline values and raw pose checks. The directed runner redirects only the
canonical test's temporary folder to this unit; its assertions are unchanged.

Observed results:

```text
Ran 124 tests in 157.261s
OK
RR10 BONE SAMPLES: PASS (1050 poses; headless transforms only)
RR11 SOURCE/CUT GATES: PASS (0 errors; both views)
RR11 BONE/CUT/KNEE GATES: PASS (0 errors)
RR11 RUNTIME: PASS (5722 checks; headless logic only)
GAIT CONTINUATION TEXTURES: PASS (1404 own-edge/clip-selection checks; case and production)
RR11 NATIVE PROBE LOAD: PASS
RR27 POSE ROW IDENTITY: PASS (1050 rows; 0 changed raw rows)
RR27 PAINT/REST/MOTION IDENTITY: PASS (440 protected files; 0 changed)
RR27 STRICT CENSUS FRONT: PASS (335 frames; 0 unmatched detached; 0 pocket failures)
RR27 STRICT CENSUS REAR: FAIL (335 frames; 2 unmatched detached; 0 pocket failures)
RR27 TETHER STUDY LOGIC: PASS (30 poses; in-memory keys only)
RR27 REMOVAL PROPOSAL: PASS (335 rear frames; 0 failing; not applied)
```

Both rear diagnostics intentionally preserve their failures. Native probe
`--validate-only` loads the real rig/masks headlessly and does not capture.
Godot also emitted the existing macOS certificate message and sampler/probe
shutdown resource warnings; these are not presented as renderer acceptance.
An initial `py_compile` command could not write the system cache:
`PermissionError: [Errno 1] Operation not permitted:
/Users/borgerding/Library/Caches/com.apple.python/Users/borgerding/workspace/Labyrinth.worktrees/rr-27`.
Python syntax was then checked in memory without external writes. One rr-24
checker run correctly rejected evidence after its bound test helper changed;
`rr24_check_final.log` is the fresh run after resampling.

Headless reproduction (from this worktree):

```sh
python3 -B experiments/cutouts/arc_thrall/rr27_build.py
python3 tools/godot_task_runner.py --task-id rr-27 --stream -- godot --headless --path . --script tests/rr11/action_direction.gd -- --case res://experiments/cutouts/arc_thrall/rr11 --output res://experiments/cutouts/arc_thrall/rr11/proof/samples.json
python3 -B experiments/cutouts/arc_thrall/rr11_gates.py
python3 -u -B experiments/cutouts/arc_thrall/rr27_check.py
python3 -u -B experiments/cutouts/arc_thrall/rr24_check.py --raster
python3 tools/godot_task_runner.py --task-id rr-27 --stream -- godot --headless --path . --script tests/rr11/runtime_checks.gd
LABYRINTH_TASK_ID=rr-27 OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 python3 -B experiments/cutouts/arc_thrall/rr27_focused.py
python3 -B experiments/cutouts/arc_thrall/rr27_rear_diagnostic.py
python3 -u -B experiments/cutouts/arc_thrall/rr27_rear_diagnostic.py --removal-proposal
python3 tools/godot_task_runner.py --task-id rr-27 --stream -- godot --headless --path . --script experiments/cutouts/arc_thrall/rr27_tether_study.gd -- --logic-only
python3 -B experiments/cutouts/arc_thrall/rr27_tether_sheets.py --cpu
```

## Proof for the design owner

No windowed command was attempted. After resolving the rear repair, run the
exact rr-24 sequence at 1920x1080 / 100% UI scale, stopping on a failed stage:

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

Those outputs remain under `rr11/proof/native_rest/`, `native/`,
`rr24_crops/`, `contact_sheets/`, `idle_native/`, `production_native/`,
`thrall_protagonist_idle.mp4` and `arc_thrall_review.mp4`. Density/rest/shadow
publication and the inspection fixture belong to the director/int-03; this
brief requests no `inspection_fixture.py` command.

The Tether native study is independent of that sequence:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-27 && python3 tools/visual_probe_runner.py --task-id rr-27 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --expect-size 512x512 --proof-contract experiments/cutouts/arc_thrall/rr27/tether_contract.json --result-manifest experiments/cutouts/arc_thrall/rr27/tether_study/native_runner.json experiments/cutouts/arc_thrall/rr27_tether_study.gd -- --output res://experiments/cutouts/arc_thrall/rr27/tether_study/native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-27 && python3 -B experiments/cutouts/arc_thrall/rr27_tether_sheets.py
```

This writes native raw 512px composites/isolated masks and five 1920x1080
proof captures in `tether_study/native/`, then the requested 3x hold sheet and
five raise strips directly in `tether_study/`. It only changes in-memory
compiled keys and restores the cache before exiting.

## TODO_DESIGN and chosen defaults

- `TODO_DESIGN_REAR_COMPONENT_REPAIR` in `rear_attachment_diagnostic.json`:
  choose an authorized repair when identical neighbour weights cannot attach
  these raster fragments. The tested two-texel removal is not applied.
- Proof-only defaults: 3 columns; 840x960 cells; 120px caption area; 18px
  caption font; 24px line pitch and 8px inset; 4px crop margin; one shared crop
  across all 30 poses; existing `#1E1E24` proof background. The requested 3x
  scale and candidate/phase values are unchanged. The native proof camera is
  `(576,0)` with the existing `(128,128)` source origin. Axis measurements use
  81 samples over 10–90% of the segment. These affect proof only.
- Census progress interval 50 frames, native study timeout 180 seconds, and
  the synthetic crossing test's 32px mask / 8–24px rectangle are proof/test
  defaults. No gameplay, art, tuning, timing or design value was selected.

`files_changed.txt` is the final owned-file inventory. Source changes are the
front case/production layouts, their continuation table, replay/census/study
tools, and focused Thrall tests; other changed files are derived evidence.
