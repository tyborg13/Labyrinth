# rr-03 round 3 — director r2 motion and fixed production capture

Changes remain uncommitted. The director's supplied r2 file was copied byte for
byte into `director_motion.json`; its SHA-256 is
`e080d2b2bf436c15cfc223a932b3dc787da2fc9c5dba806916c184d46e3e5a79`.
The protected source, original paintings, Blender exports and previously
promoted production files remain unchanged by this worker.

1. **Motion r2 imported and rebuilt.** Both views use the authored keys:
   3% breath, head poses 0/-10/7/-3 degrees with up to 2px forward offset,
   4-degree wing settles, 7-degree tail flick, 5px hit recoil with 12-degree
   head and 14-degree wings. Death follows the complete lift/roll/drop/settle
   sequence, ending at 70 degrees and 10px down. Its legs now travel with the
   body, including the explicit initial lift; idle/hit and grounded move
   crouches retain planted feet. The existing 30fps, start-at-key, two-frame
   head clock is unchanged. Numeric gates read the current authored values;
   zero-speck, clipping and hidden-value limits are unchanged.
2. **Production capture fixed.** `gust_shrike_capture_viewport.gd` creates a
   fixed 1920×1080 SubViewport with an independent World2D. Both the production
   probe and board-scale metadata use it. Captures read its texture instead of
   the OS-clamped root window. All seven existing real combat action recordings
   remain. The recorder retains every action frame and continues capturing the
   real board if necessary to reach at least 76 frames. The proof contract
   requires at least 83 images: those frames plus seven clip keyframes.

The rebuilt pieces and layouts exactly match the already promoted rig. No new
ownership repair, paint change or promotion is necessary. The existing runtime
motion script/data supply r2 to that rig. No motion-design TODO remains and no
new player-visible value was chosen. Diagnostic-only defaults remain the
existing 512px CPU canvas, five-column contact sheet, middle sample per clip and
terminal death sample. The 800×450 window is a synthetic regression fixture.

## Changed files

- `compile_motion.py`, generated case/runtime `motion_data.gd` and copied
  `director_motion.json`: current source keys and constants, with no stale
  amplitudes inherited from earlier generated files.
- Case/runtime `motion.gd`: death carries the legs with its body transform.
- `probes/motion_gates.py`: current director excursions, including hit distance
  and death drop; existing tolerances remain unchanged.
- `tests/gust_shrike_capture_viewport.gd`, `tests/gust_shrike_cutout_probe.gd`,
  `probes/motion_metadata.gd`, `probes/production_contract.json`: fixed capture
  geometry and the retained real-frame floor.
- `tests/gust_shrike_cutout_test.gd`: r2 motion checks and clamped-window geometry
  regression. Refreshed samples, exposure, gates, baseline and diagnostic proof.

## Observed checks

- Focused Godot: **PASS, 47 checks, 0 failures** (headless logic).
- Focused Python: **PASS, 15 tests in 0.057s**.
- Production probe headless parser check: exit 0.
- Motion sampler: **PASS, 904 poses, design_complete=true**.
- CPU motion gates: **PASS, 904 frames**, zero specks, magenta, clipping or empty
  frames; no errors. All retained hidden materials pass the unchanged limit.
- Exposure: **PASS, 16 requests, 0 unknown solos**.
- Front/rear approved rest identity: **0 changed pixels**.
- Protected inputs, case/runtime motion copies, existing production assets and
  protected structural validation: PASS.
- Full Python: **PASS, 531 tests in 352.847s, 61 skipped**, process exit 0.
- Full Godot: **PASS, 790.768 seconds (900-second budget)**, process exit 0.
- `git diff --check`: exit 0. Logs are in `proof/round3_*.log`; certificate,
  NumPy and resource-exit diagnostics did not cause test failures.

The refreshed CPU contact sheet was inspected as a diagnostic only. No native
windowed run was performed by this worker; native_v02 and production PASS still
require the design owner's commands below. Native_v01 is the prior reviewed
revision, not evidence for the new motion/capture implementation.

## Reproduce headless checks

```sh
python3 experiments/cutouts/gust_shrike/mq2/pipeline.py prepare-motion
python3 experiments/cutouts/gust_shrike/mq2/repair_ownership.py rebuild
python3 experiments/cutouts/gust_shrike/mq2/repair_fills.py
python3 tools/godot_task_runner.py --task-id rr-03 --stream -- godot --headless --path . --script experiments/cutouts/gust_shrike/mq2/probes/motion_samples.gd -- --case "$PWD/experiments/cutouts/gust_shrike/mq2/cutout.json" --output "$PWD/experiments/cutouts/gust_shrike/mq2/proof/motion_samples.json"
python3 experiments/cutouts/gust_shrike/mq2/probes/proof.py --case experiments/cutouts/gust_shrike/mq2 --samples experiments/cutouts/gust_shrike/mq2/proof/motion_samples.json
python3 experiments/cutouts/gust_shrike/mq2/probes/motion_gates.py --case experiments/cutouts/gust_shrike/mq2 --cpu
python3 -m unittest discover -s tests -p 'test_gust_shrike_cutout.py' -v
python3 tools/godot_task_runner.py --task-id rr-03 --stream -- godot --headless --path . --script tests/gust_shrike_cutout_test.gd
python3 -m unittest discover -s tests -p 'test_*.py' -v
python3 tools/godot_task_runner.py --task-id rr-03 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
```

## Proof for the design owner — native_v02

Run from this worktree after all files are final. The existing production paint
matches the rebuilt case, so omit promotion. This keeps the project input set
stable between rendering, verification and production capture.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-03
case_path="$PWD/experiments/cutouts/gust_shrike/mq2"
native_path="$PWD/experiments/cutouts/gust_shrike/native_v02"
python3 tools/visual_probe_runner.py "$case_path/probes/native_rest.gd" --task-id rr-03 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --expect-size 255x255 --proof-contract "$case_path/probes/rest_contract.json" --result-manifest "$case_path/proof/native_rest_result_v02.json" -- --case "$case_path/cutout.json"
python3 tools/cutout_workflow.py render "$case_path" --output "$native_path" --task-id rr-03
python3 tools/cutout_workflow.py verify-render "$case_path" --output "$native_path"
python3 "$case_path/probes/motion_gates.py" --case "$case_path" --capture-native "$native_path" --task-id rr-03
python3 "$case_path/probes/proof.py" --case "$case_path" --native-output "$native_path"
python3 tools/visual_probe_runner.py tests/gust_shrike_cutout_probe.gd --task-id rr-03 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --timeout 180 --proof-contract "$case_path/probes/production_contract.json" --result-manifest "$case_path/proof/production_result_v02.json"
```

Review `../native_v02/videos/cutout_review.mp4`. The production result manifest
reports the new capture directory. Pass that directory to
`python3 "$case_path/probes/pack_production.py" <capture-directory>` to encode
`production_reel.mp4` using the actual frame timestamps.

No Blender run, generated art, native capture, commit, publication, sub-agent or
peer review was performed by this worker.
