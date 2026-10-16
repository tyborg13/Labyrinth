# rr-03 implementation handoff — incomplete, uncommitted

**This is the round-0 record. See [ROUND3.md](ROUND3.md) for current status,
gate results and native_v02 commands. [ROUND2.md](ROUND2.md) and [ROUND1.md](ROUND1.md)
records the original build.**

No art was generated, painted, downloaded or changed. No Blender/windowed run,
commit, publication, peer review or sign-off was performed. The approved mq2
job files and enemy balance/portrait data remain untouched.

## Acceptance status

1. **Maquette export:** implemented sixteen label solos, projected joints,
   actual camera/root transforms and primitive-centre metadata. Beak and mask
   retain their ownership labels but bind to the head, giving six independent
   painted groups. Blender execution remains with the design owner. Use the
   existing maquette README's `FRONT_YAW=0` command: its 0/180 views match the
   approved mq2 references; the exporter's legacy default 135 is unchanged.
2. **Registered rig:** recipe and reproducible builder implemented; NOT built.
   Both digest-matching raw paintings are absent, as are the Blender outputs.
   The front raw was 1254px (processed record), while maquette exports are
   1024px. `pipeline.py` normalizes the shared registration affine once for
   every map, joint and solo, leaving rr-02 tooling unchanged.
3. **Seven motions:** supplied magnitudes are transcribed in
   `scripts/gust_shrike_cutout/motion_data.gd`. The independent rigid-part
   sampler, per-view tracks, interpolation validation, contact mapping and
   held terminal pose are implemented. Exact pose tracks remain empty and
   explicitly incomplete: no unseen visual decisions were filled in.
   `motion_metadata.gd` derives reel timing from the production constants.
   Dive impact is at flight end, not the ranged effect's 0.66 boundary; its
   requested six-frame recovery follows that impact. Recovery cadence is
   unresolved. The head's four minimum 0.6s intervals already fill 2.4s;
   the owner must clarify whether the two snap frames are inside those intervals.
4. **Production:** shrike-only lifecycle, move/action/reaction routing, static
   path replacement, persistent canvas, reduced-motion rendering and export
   filters are wired. Activation is gated by complete motion and a verified
   promoted asset manifest. The current game still displays the approved
   directional stills. No production assets have been promoted. Damage,
   analytics payloads, saves, enemy numbers and other actors are unchanged.
5. **Proof:** native rest, native ownership surfaces, reel, numeric motion
   gates, semantic owner/occlusion masks, hidden-fill equality, specks, magenta,
   production combat capture/reel and PCK checks are written. No rendered
   identity, motion, hidden fill, final art, package or production capture
   success is claimed. The unbuilt scaffold correctly fails validation.

## Results observed

Logs are under `proof/`.

- `focused_godot.log`: `GUST SHRIKE CUTOUT: PASS (25 checks, 0 failures; headless logic only)`.
- `focused_python.log`: `Ran 7 tests in 0.033s`, `OK`.
- `full_python.log`: `Ran 516 tests in 377.217s`, `OK (skipped=61)`.
  Discovery preceded addition of the seven new shrike tests, which ran separately.
- `full_godot.log`: `FULL SUITE RUNTIME: 788.902 seconds (budget 900 seconds)`,
  `TEST RESULT: PASS`; runner exit 0. Its diagnostics include missing
  image/certificate and resource-exit messages; no assertions were rewritten
  to hide them. Subsequent new-sampler validation and recovery endpoint fixes
  passed the focused test; the full suite was not repeated for those isolated changes.
- `art_identity.log`: `Ran 111 tests in 56.130s`, `OK`.
- `ui_identity.log`: `Ran 25 tests in 2.670s`, `OK`.
- `en05_live.log`: `EN05 LIVE INTEGRATION: PASS (14 checks, 0 failures; headless logic only)`.
- `en05_sync.log`: `EN05 INTEGRATION SYNC: PASS (six protected enemy entries; integration shadows preserved; two en-05 additions)`.
- `static_facing.log`: `STATIC FACING TEST RESULT: PASS (74 checks, 0 failures)`.
- Headless `--check-only` passes: production probe, motion samples, native
  ownership probe. Python compilation and `git diff --check` pass.
- `input_status.json`: `ok: false`; two raw files and 23 exporter files missing.
- `validation.json`: `ok: false`; no projected head joint in either unbuilt layout.
- `motion_metadata.log`: `SHRIKE MOTION METADATA: extracted; design_complete=false`.
- `pack.log`: `SHRIKE PACK: BLOCKED: completed promoted rig required` (exit 1).
- Inspection command was dry-run only (`proof/inspection_command.txt`).

Exact test entry points used (all from this worktree):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 tools/godot_task_runner.py --task-id rr-03 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 -m unittest discover -s tests -p 'test_*.py' -v
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 tools/godot_task_runner.py --task-id rr-03 --stream -- godot --headless --path . --script tests/gust_shrike_cutout_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 -m unittest discover -s tests -p 'test_gust_shrike_cutout.py' -v
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 tests/test_art_identity_gate.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 tests/test_ui_identity_lint.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 tools/godot_task_runner.py --task-id rr-03 --stream -- godot --headless --path . --script tests/en05_live_integration_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 tools/godot_task_runner.py --task-id rr-03 --stream -- godot --headless --path . --script tests/en05_integration_sync_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 tools/godot_task_runner.py --task-id rr-03 --stream -- godot --headless --path . --script tests/static_facing_test.gd
```

## TODO_DESIGN fields

- `TODO_DESIGN_approved_raw_front`, `TODO_DESIGN_approved_raw_rear`: supply originals
  matching the approved processed records; never substitute processed paint.
- `TODO_DESIGN_{idle,move,dive,talon_rake,hover,hit,death}_tracks`: exact timing,
  interpolation, per-view pose signs and unprovided pose amounts.
- `TODO_DESIGN_DIVE_RECOVERY_FRAME_SECONDS`, `TODO_DESIGN_CONTACT_PHASES`.
- Recipe `TODO_DESIGN_motion_tracks`, `TODO_DESIGN_dive_recovery_cadence` are
  removed by the builder only after the motion data reports complete.
- `TODO_DESIGN_material_ownership_and_occlusion` and
  `TODO_DESIGN_semantic_and_occlusion_masks`: bird-specific semantic masks and
  shadow ownership, or a reviewed explicit no-occlusion finding for each view.
  Gaoler trouser/tabard predicates must not be reused as bird anatomy.

The input/status reports and native gates reject unresolved fields. Fill the
motion tracks in the production data; the builder snapshots the exact sampler
and data into this case. Masks use native 255px label indices + 1, zero outside
reviewed regions; see `recipes/gates.json`. Keep the approved painted pixels
exact when applying any owner-directed ownership repairs.

## Chosen defaults (proof and tests only)

- Proof sample counts: idle 144, move 49, dive 61, talon rake 49, hover 49,
  hit 37, death 63. They do not select gameplay cadence.
- Production recording 30fps; final encoded frame hold 1/30s; eight settle frames.
- Probe-only movement target (2,3), melee origin (5,4), existing EN05 fixture seed.
- Synthetic layout/contact fixtures in `tests/gust_shrike_cutout_test.gd`.
- Motion tolerances: 1 degree, 0.5px, 0.002 scale; inherited support 0.02px,
  rigid basis 0.001. Native capture timeout 900s for all five surfaces.
- Rest/ownership sheet framing is copied from rr-02. All gameplay durations
  come from existing runtime constants; no missing timing was chosen.

## Proof for the design owner

Run from this exact worktree. Do not run the later steps until their inputs and
TODO fields are resolved. The production asset switch is intentionally closed.
The commands below use existing approved paint and the existing deterministic
same-material hidden-fill tool; they do not request new art.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && FRONT_YAW=0 /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P spec/art_identity/maquettes/gust_shrike.py -- experiments/cutouts/gust_shrike/maquette
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 experiments/cutouts/gust_shrike/mq2/pipeline.py check-inputs
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 experiments/cutouts/gust_shrike/mq2/pipeline.py build
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 tools/maquette_cutout.py fill-hidden --case experiments/cutouts/gust_shrike/mq2 --task-id rr-03
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 tools/godot_task_runner.py --task-id rr-03 --stream -- godot --headless --path . --script experiments/cutouts/gust_shrike/mq2/probes/motion_samples.gd -- --case /Users/borgerding/workspace/Labyrinth.worktrees/rr-03/experiments/cutouts/gust_shrike/mq2/cutout.json --output /Users/borgerding/workspace/Labyrinth.worktrees/rr-03/experiments/cutouts/gust_shrike/mq2/proof/motion_samples.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 experiments/cutouts/gust_shrike/mq2/probes/proof.py --case experiments/cutouts/gust_shrike/mq2 --samples experiments/cutouts/gust_shrike/mq2/proof/motion_samples.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 experiments/cutouts/gust_shrike/mq2/probes/motion_gates.py --case experiments/cutouts/gust_shrike/mq2 --cpu
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 tools/visual_probe_runner.py experiments/cutouts/gust_shrike/mq2/probes/native_rest.gd --task-id rr-03 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --expect-size 255x255 --proof-contract experiments/cutouts/gust_shrike/mq2/probes/rest_contract.json --result-manifest experiments/cutouts/gust_shrike/mq2/proof/native_rest_result.json -- --case /Users/borgerding/workspace/Labyrinth.worktrees/rr-03/experiments/cutouts/gust_shrike/mq2/cutout.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 tools/cutout_workflow.py render experiments/cutouts/gust_shrike/mq2 --output experiments/cutouts/gust_shrike/native_v01 --task-id rr-03
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 experiments/cutouts/gust_shrike/mq2/probes/motion_gates.py --case experiments/cutouts/gust_shrike/mq2 --capture-native experiments/cutouts/gust_shrike/native_v01 --task-id rr-03
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 experiments/cutouts/gust_shrike/mq2/probes/proof.py --case experiments/cutouts/gust_shrike/mq2 --native-output experiments/cutouts/gust_shrike/native_v01
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 experiments/cutouts/gust_shrike/mq2/pipeline.py promote --native-output experiments/cutouts/gust_shrike/native_v01
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 tools/visual_probe_runner.py tests/gust_shrike_cutout_probe.gd --task-id rr-03 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --timeout 180 --proof-contract experiments/cutouts/gust_shrike/mq2/probes/production_contract.json --result-manifest experiments/cutouts/gust_shrike/mq2/proof/production_result.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 tools/inspection_fixture.py --task-id rr-03 --run-id rr-03-shrike --scenario combat --enemy-types gust_shrike --enemy-positions 2:4 --enemy-intents dive --player-position 6:4 --hand quick_stab,pale_spark --summary 'Gust Shrike cutout inspection' --manifest /private/tmp/labyrinth-inspection-manifests/rr-03-shrike.json --launch
```

Place the raw originals at `experiments/cutouts/gust_shrike/inputs/front_raw.png`
and `rear_raw.png`, or pass explicit `--front-raw`/`--rear-raw` paths to the first
three pipeline commands. `native_v01/videos/cutout_review.mp4` is the native
case reel. The production result manifest identifies the isolated capture
folder (`user://probes/gust_shrike_cutout`); run `probes/pack_production.py` with
that absolute folder to create `production_reel.mp4` from measured timestamps.
No capture paths exist yet. Native proof is required before production promotion;
production captures and the isolated PCK build/verify are required afterward.
Use a fresh empty directory for the PCK verification, without the project source
tree or import cache. These commands have not succeeded with a production rig:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 tools/godot_task_runner.py --task-id rr-03 --stream -- godot --headless --path . --script tests/gust_shrike_cutout_pack_test.gd -- build /Users/borgerding/workspace/Labyrinth.worktrees/rr-03/experiments/cutouts/gust_shrike/mq2/proof/shrike.pck
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && mkdir experiments/cutouts/gust_shrike/mq2/proof/empty_project
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 tools/godot_task_runner.py --task-id rr-03 --stream -- godot --headless --path experiments/cutouts/gust_shrike/mq2/proof/empty_project --script /Users/borgerding/workspace/Labyrinth.worktrees/rr-03/tests/gust_shrike_cutout_pack_test.gd -- verify /Users/borgerding/workspace/Labyrinth.worktrees/rr-03/experiments/cutouts/gust_shrike/mq2/proof/shrike.pck
```

The package also includes an executable smoke-test main scene for the design
owner's unmodified desktop export runtime (`--headless --main-pack <shrike.pck>`
through the task runner). That runtime binary was not selected or run here.

No balance/heuristic update is needed: this unit changes presentation only.
No icon identities, audio, fonts or analytics schema were changed.
