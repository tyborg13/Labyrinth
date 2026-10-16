# rr-03 round 1 — built, uncommitted, gates not passed

The rig is built from the supplied originals and all 23 Blender exports. Both
assembled rests are byte-identical RGBA to the approved processed paintings:
**0 different pixels front and rear**. Each view has seven joints, six independent
painted groups and sixteen rigid paint nodes (visible and hidden). There are no
meshes. Production remains on the approved directional stills while gates fail.

## Inputs and implementation

The staged path in the request was absent. The delivered protected file was
`../motion_tracks_director.json`; its SHA-256 is
`c714f4c691abce13b5b1fbd6653af4cdfd4414a3d621f214faef936f2f31e6a0`.
It is copied unchanged to `director_motion.json`. Neither original was edited.
Raw hashes match the approved records:

- Front: `a43816b7191b78e13e8f25604fc625b586079b5faa7ab3583ba18f9d9b11bd43`.
- Rear: `b236be7b28e3529b79b0ee19fb495d042b3805d9c6938b0597e60c73b4f417ac`.

`compile_motion.py` maps semantic channels independently through the actual
exported object/camera transforms. Those are 0/180 degrees; the protected file's
135/315 prose is stale. Signed pitch, roll, wing, tail and leg angles come from
projected axes, and forward translation follows each view's projected +X.
The compiler writes the runtime `motion_data.gd` and a case copy; the exported
game has no dependency on experiments or the protected input path.

Pixel distances are screen pixels. `motion_metadata.gd` measures the actual
1920x1080, 100% RunScene fixture: **0.452636090446921 screen pixels per source
pixel**. Native case diagnostics use that reference; production passes its
current draw scale to the sampler. Grounded crouch/collapse preserve the exported
foot contact. Talon contact maps to the existing presentation's actual first
impact sample, with authored phase 0.5. Dive keeps its existing 0.35s flight,
then six 1/30s recovery frames: frame 1 at impact, frame 3 at +2/30s, frame 6 at
+5/30s, holding frame 6 through +6/30s. Total duration is 0.55s.

The six director semantic classes are recorded in `recipes/gates.json` and
calibrated against the registered maquette owners. Beak and mask bind to head.
The director's explicit no-occlusion finding is recorded for each view. No
humanoid trouser/tabard predicates are applied to the bird.

All hidden regions are filled using the existing rr-02 tool. Rear beak/mask had
fewer than 40 visible donor pixels; the existing `--cross-view-fallback` option
uses the approved front painting's same part. Fill status is complete, with no
pending donor and no magenta. No approved visible pixel changed.

Changed implementation files this round: `compile_motion.py`, `pipeline.py`,
`recipes/gates.json`, `recipes/motion_interpretation.json`, the generated case
sources/layouts/parts, case sampler/data/probes, runtime
`scripts/gust_shrike_cutout/{motion_data,motion,action,renderer,presentation}.gd`,
the effect-frame-count field in `scripts/run_scene.gd`, and the focused shrike
Python/Godot tests. Earlier round-0 integration remains uncommitted.

## Remaining issues

1. **`TODO_DESIGN_head_snap_clock`**: the protected `step2` data does not specify
   its frame rate or whether a snap starts or finishes at each authored key time.
   These were asked of the director. `recipes/motion_interpretation.json` keeps
   them unresolved (`head_snap_fps: 0`, empty placement). No head cadence was
   invented; idle head tracks remain absent until supplied. The compiler supports
   both placements and includes the snap within the interval.
2. **Specks:** final CPU sampling reports 1,412 detached components smaller than
   12 pixels across 326 of 904 poses. `proof/speck_examples.json` identifies
   example nodes/bounds. `proof/cpu_diagnostic.png` is a CPU diagnostic image,
   not a renderer capture. It is not native proof or art approval.
3. **Hidden value:** the inherited rr-02 median-L* tolerance is 8 and requires
   reference-IQR midtones. Front `wing_near` differs by 14.08 with no midtones;
   rear `head` differs by 11.83. Details are in `proof/hidden_value_gates.json`.
   The gate was retained; no value-policy exception was introduced.

The full CPU motion gate is **FAIL**. It reports zero rendered magenta pixels,
zero clipping and zero empty frames. Numeric motion checks other than the
unresolved idle head pass. Native inspection is still required for articulation,
part boundaries, overlap and hidden paint. No native captures, production rig
promotion or production PCK success is claimed.

## Observed checks

Logs are in `proof/`, prefixed `round1_`.

- Build/input/structural validation: `ok: true`; rests have 0 different pixels.
- `GUST SHRIKE CUTOUT: PASS (39 checks, 0 failures; headless logic only)`.
- Focused Python: 10 tests, `OK`.
- `SHRIKE MOTION SAMPLES: PASS (904 poses; design complete=false)`.
- `MAQUETTE_EXPOSURE: PASS (16 requests; 0 unknown solos)`.
- `SHRIKE MOTION GATES: FAIL` (issues above).
- `Ran 526 tests in 350.802s`; `OK (skipped=61)`.
- `FULL SUITE RUNTIME: 718.552 seconds (budget 900 seconds)`; `TEST RESULT: PASS`.
- Production probe headless parse and `git diff --check`: exit 0.

The full suites ran during implementation. The final grounded-support/contact
fixes additionally passed the focused Godot test; the full suite was not rerun
for those isolated fixes. Logs include macOS certificate, NumPy and resource-exit
diagnostics; no existing assertions were rewritten to conceal a failure.

Proof-only defaults remain the round-0 sample counts, recording settings,
synthetic fixture layout and gate tolerances. The new 0.5 draw scale in the
focused test is synthetic; the production scale is measured, not selected.

## Refresh after the head decision

Record the director's FPS and `start`/`finish` placement in
`recipes/motion_interpretation.json`, then run these commands. Motion refresh
preserves the build recipe bound by hidden-fill provenance and updates the
current runtime/case clocks without rebuilding paint.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 experiments/cutouts/gust_shrike/mq2/pipeline.py prepare-motion
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 tools/godot_task_runner.py --task-id rr-03 --stream -- godot --headless --path . --script experiments/cutouts/gust_shrike/mq2/probes/motion_samples.gd -- --case /Users/borgerding/workspace/Labyrinth.worktrees/rr-03/experiments/cutouts/gust_shrike/mq2/cutout.json --output /Users/borgerding/workspace/Labyrinth.worktrees/rr-03/experiments/cutouts/gust_shrike/mq2/proof/motion_samples.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 experiments/cutouts/gust_shrike/mq2/probes/proof.py --case experiments/cutouts/gust_shrike/mq2 --samples experiments/cutouts/gust_shrike/mq2/proof/motion_samples.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 experiments/cutouts/gust_shrike/mq2/probes/motion_gates.py --case experiments/cutouts/gust_shrike/mq2 --cpu
```

## Proof for the design owner

These have not been run windowed. `render` produces the native reel at
`../native_v01/videos/cutout_review.mp4`. The production capture records all
seven real combat clips at 1920x1080 and 100% UI scale.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 tools/visual_probe_runner.py experiments/cutouts/gust_shrike/mq2/probes/native_rest.gd --task-id rr-03 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --expect-size 255x255 --proof-contract experiments/cutouts/gust_shrike/mq2/probes/rest_contract.json --result-manifest experiments/cutouts/gust_shrike/mq2/proof/native_rest_result.json -- --case /Users/borgerding/workspace/Labyrinth.worktrees/rr-03/experiments/cutouts/gust_shrike/mq2/cutout.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 tools/cutout_workflow.py render experiments/cutouts/gust_shrike/mq2 --output experiments/cutouts/gust_shrike/native_v01 --task-id rr-03
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 tools/cutout_workflow.py verify-render experiments/cutouts/gust_shrike/mq2 --output experiments/cutouts/gust_shrike/native_v01
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 experiments/cutouts/gust_shrike/mq2/probes/motion_gates.py --case experiments/cutouts/gust_shrike/mq2 --capture-native experiments/cutouts/gust_shrike/native_v01 --task-id rr-03
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 experiments/cutouts/gust_shrike/mq2/probes/proof.py --case experiments/cutouts/gust_shrike/mq2 --native-output experiments/cutouts/gust_shrike/native_v01
```

Promotion is blocked until those gates pass and the head decision is resolved:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 experiments/cutouts/gust_shrike/mq2/pipeline.py promote --native-output experiments/cutouts/gust_shrike/native_v01
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03 && python3 tools/visual_probe_runner.py tests/gust_shrike_cutout_probe.gd --task-id rr-03 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --timeout 180 --proof-contract experiments/cutouts/gust_shrike/mq2/probes/production_contract.json --result-manifest experiments/cutouts/gust_shrike/mq2/proof/production_result.json
```

The production result manifest reports the absolute capture directory. Pass it
to `probes/pack_production.py` to encode `production_reel.mp4`. Inspection/PCK
commands remain in the round-0 README. Promotion adds project assets, so a final
whole-project `verify-render` requires a fresh native output version afterward;
the pre-promotion capture remains the evidence that authorized the asset copy.

No Blender/window-server run, art generation service, commit, publication or
peer review was performed by this worker.
