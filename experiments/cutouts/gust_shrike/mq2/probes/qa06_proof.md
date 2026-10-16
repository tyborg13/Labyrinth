# qa-06 proof handoff

Risk tier: standard (focused proof tooling; the brief additionally requires the full suites).

This unit changes proof only. Production scripts, motion data, art, density
records, action outcomes and animation values remain unchanged.

1. `motion_samples.gd` applies every key and interval midpoint through the case
   rig, then reads its actual Bone2D matrices in both views (196 authored poses,
   alongside the existing 904 playback poses). `director_contract.py` checks
   signed body/relative bone rotations, projected offsets and scales against
   independently projected director tracks. Existing 1 degree / 0.5 pixel /
   0.002 scale tolerances are retained. Channel and compiler checks remain.
2. The capture fixture substitutes only `CombatPacing.presentation_usec()`.
   All production callbacks and popup/clip/phase calculations run unchanged.
   `PROOF_STEP_USEC = 6000` is the sole new chosen capture-clock default. It
   advances only after capture; encoded action timestamps use this elapsed
   clock, so image IO cannot stretch the action reel. Idle retains its existing
   real-time recorder.

The old fixture manufactured endpoints that production never submits. Move
and melee begin at frame 1; their first samples must precede the first authored
key. Dive's sixth recovery frame holds rest at its actual phase (about 0.9394),
which is required along with exact contact. Hit must include preparation, an
apex sample within one existing production popup frame, recovery, and its actual
return to idle. Every action still needs at least six distinct, advancing poses.
When adjacent native poses quantize to identical pixels, the recorder retains an
actually observed required checkpoint; it never changes a clip or phase.

The Python regressions use disposable cases/resource overlays. They negate the
compiler tail sign, drop the authored tail hold, negate the applied tail angle,
and freeze production hover at zero. The latter must fail both the focused
Godot test and the actual production recorder. Original files are untouched.
Native coverage regressions still reject missing hover progression, missing Dive
contact and frozen move hashes; missing hit retirement also fails.

## Headless proof

Run from this task worktree. `qa06_results/` is local ignored evidence. The
`--samples` option keeps the prior rr-03 proof untouched.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-06 && mkdir -p experiments/cutouts/gust_shrike/mq2/probes/qa06_results
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-06 && python3 tools/output_gdignore.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-06 && python3 tools/godot_task_runner.py --task-id qa-06 --stream -- godot --headless --path . --script tests/gust_shrike_cutout_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-06 && python3 tests/test_gust_shrike_cutout.py -v
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-06 && python3 tools/godot_task_runner.py --task-id qa-06 --stream -- godot --headless --path . --script tests/gust_shrike_cutout_probe.gd -- --logic-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-06 && python3 tools/godot_task_runner.py --task-id qa-06 --stream -- godot --headless --path . --script experiments/cutouts/gust_shrike/mq2/probes/motion_samples.gd -- --case res://experiments/cutouts/gust_shrike/mq2/cutout.json --output res://experiments/cutouts/gust_shrike/mq2/probes/qa06_results/motion_samples.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-06 && python3 experiments/cutouts/gust_shrike/mq2/probes/motion_gates.py --case experiments/cutouts/gust_shrike/mq2 --cpu --samples experiments/cutouts/gust_shrike/mq2/probes/qa06_results/motion_samples.json --output experiments/cutouts/gust_shrike/mq2/probes/qa06_results/cpu_motion_gates.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-06 && python3 tools/godot_task_runner.py --task-id qa-06 --stream -- godot --headless --path . --script experiments/cutouts/gust_shrike/mq2/probes/native_motion.gd -- --case res://experiments/cutouts/gust_shrike/mq2/cutout.json --check-poses
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-06 && python3 tools/godot_task_runner.py --task-id qa-06 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-06 && python3 -m unittest discover -s tests -p 'test_*.py' -v
```

## Proof for the design owner

No windowed command was attempted by the implementation worker. After the
fresh headless sampler above, run these commands in order. They reuse approved
art and density inputs; there is no rebuild, promotion or density processing.
The primary render also packs its native review reel. The ownership capture
runs and verifies the native motion gates against those rendered frames.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-06 && python3 tools/cutout_workflow.py render experiments/cutouts/gust_shrike/mq2 --output experiments/cutouts/gust_shrike/native_v06 --task-id qa-06
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-06 && python3 experiments/cutouts/gust_shrike/mq2/probes/motion_gates.py --case experiments/cutouts/gust_shrike/mq2 --capture-native experiments/cutouts/gust_shrike/native_v06 --task-id qa-06 --samples experiments/cutouts/gust_shrike/mq2/probes/qa06_results/motion_samples.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-06 && python3 tools/visual_probe_runner.py tests/gust_shrike_cutout_probe.gd --task-id qa-06 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --expect-size 512x512 --timeout 180 --proof-contract experiments/cutouts/gust_shrike/mq2/probes/production_contract.json --result-manifest experiments/cutouts/gust_shrike/mq2/probes/production_result_v06.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-06 && python3 experiments/cutouts/gust_shrike/mq2/probes/pack_production.py --result-manifest experiments/cutouts/gust_shrike/mq2/probes/production_result_v06.json
```

Expected native outputs: `experiments/cutouts/gust_shrike/native_v06/`,
`probes/production_result_v06.json`, and the runner capture directory selected by
that result manifest (`frames.json`, 1920x1080 board PNGs, 512x512 pose PNGs,
`production_reel.mp4`, `production_reel_proof.json`). Packing validates the per-
action native pixel hashes and phase coverage before encoding.

No new playable inspection fixture is required by this proof-only brief; the
design owner retains inspection, commit, review and publication responsibilities.
`parallel_task.py status` initially reported an empty contract despite the
provided setup description; the owner should reconcile that metadata with the
two acceptance criteria and headless/windowed proof above.

TODO_DESIGN placeholders added: none. No runtime elapsed-time seam was needed.

## Observed worker results

All commands used the required runners. Headless evidence is under
`probes/qa06_results/`; no native images or windowed success are claimed.

- `GUST SHRIKE CUTOUT: PASS (101 checks, 0 failures; headless logic only)`
- Focused Python: `Ran 21 tests in 33.804s` / `OK`.
- `SHRIKE CPU MUTATION: missing_hold rejected`
- `SHRIKE CPU MUTATION: applied_tail rejected`
- `SHRIKE CPU MUTATION: reversed_tail rejected`
- `SHRIKE FROZEN HOVER MUTATION: caught by tests/gust_shrike_cutout_test.gd`
- `SHRIKE FROZEN HOVER MUTATION: caught by tests/gust_shrike_cutout_probe.gd`
- `SHRIKE MOTION SAMPLES: PASS (904 poses; 196 authored bone poses; design complete=true)`
- `SHRIKE MOTION GATES: PASS` (904 CPU raster frames, zero errors).
- `MAQUETTE_NATIVE_POSES: PASS (906 poses; five surfaces; GPU readback not exercised)`
- `SHRIKE PRODUCTION LOGIC ONLY: PASS (209 frames; six or more per action)`.
  Action counts: move 8, Dive 11, Talon Rake 6, hover 81, hit 27, death 18.
  `production_logic_frames.json` is a local copy of the emitted transform-only
  manifest; `production_logic.log` records its original isolated capture path.
- `SHRIKE MOTION METADATA: extracted; design_complete=true`
- `GUST SHRIKE CUTOUT PACK TEST RESULT: PASS (build, editor=true)`
- `GUST SHRIKE CUTOUT PACK TEST RESULT: PASS (verify, editor=true)`
  The verify process used an empty project directory and mounted only the PCK.
- Full Python: `Ran 538 tests in 364.358s` / `OK (skipped=61)`.
  Skips: 6 pinned Python 3.12 audio environment, 16 missing `mido`/`music21`,
  39 missing `soundfile`/`scipy`/`pyloudnorm`. The final reel-result resolver
  regression is included in the 21-test focused run.
- `FULL SUITE RUNTIME: 708.360 seconds (budget 900 seconds)`
- `TEST RESULT: PASS`
- `OUTPUT GDIGNORE: PASS (12 folders; 2 referenced roots)`; `git diff --check`
  passed. Protected production/art/spec/motion paths have no diff.

Logs: `godot_focused.log`, `python_focused.log`, `motion_samples.log`,
`cpu_motion_gates.log`, `native_pose_check.log`, `production_logic.log`,
`motion_metadata.log`, `pack_build.log`, `pack_verify.log`, `godot_full.log`,
`python_full.log`. The implementation remains uncommitted on `codex/qa-06`.
