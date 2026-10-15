# Chainbound gaoler mq3 — round 6

All four director design decisions are implemented. Validation, exact rest identity,
hidden fill, all 458 CPU motion frames and all ten value-distribution checks pass.
Native v06 renderer proof remains for the director's windowed session below.

Changes remain uncommitted in the rr-02 worktree. The approved source pixels and
copied production sampler are unchanged. No windowed run, commit, peer review or
delegation was attempted. Gameplay inspection is not applicable before production
integration. This case is ready for native inspection, not yet visually approved.

## Numbered director requirements

1. **Scoped colour gate:** strict DeltaE76 < 12 against the approved tabard median,
   on front pelvis, both thighs, both shins and both coats; rear pelvis and thighs.
   The explicit list selects whole logical owners associated with the 6px-dilated
   front silhouette. Other owners' protected rust/copper is excluded. All 70
   part/clip combinations have zero total and maximum-frame counts. Runtime PNGs
   also have zero qualifying pixels, including pixels hidden in the composite.
   Six final source collisions required geometric ownership repair; 15 connecting
   source pixels keep them attached. Relative to round5, 7 far-shin pixels move to
   tabard, 13 near-shin pixels to the boot and one coat pixel to the upper arm.
   Their RGBA and original rest draw depth are preserved; rear ownership is exact.
   The earlier DeltaE76 <= 15 transfer heuristic remains recorded separately from
   the new strict final gate, retaining the accepted round5 material cleanup.
2. **Sparse value references:** the 14-pixel front and 7-pixel rear far thighs now
   use their own view's near-thigh visible trousers, with per-pixel L* lowered 6.
   Near-thigh a*/b* provides material chroma/hue. Provenance records the source
   view/part, mask/RGB hashes, counts, L* shift and original/target/encoded medians.
   Other leg regions retain their same-part reference. All ten differences are
   below 8 and all hidden fills contain reference mid-tones.
3. **Rear torso/shoulder:** rear strike and manacle_pin add torso rotation
   `0.07 rad * hit` and fist-side shoulder `Vector2(0,-3) * prep`. Production
   `manacle_pin` calls its punch envelope `cast`; that existing envelope supplies
   `hit`, without introducing timing. Head and both arms inherit the torso lean,
   along with the attached hook/chain. Pelvis drive, front motion and other clips
   match archived round5 matrices. The fist constraint is rebaked after the lean;
   all 70 rear punch samples have zero outside-arm and zero visible-arm pixels.

## Scoped colour counts per part and clip

These are sums over sampled **CPU diagnostic** frames, including repeated pixels
across frames. Every maximum per frame is also zero. Native counts are pending.
`proof/cpu_motion_gates.json` contains all 458 frame records and 70 aggregate rows.

| View/clip | Pelvis | Far thigh | Near thigh | Far shin | Near shin | Far coat | Near coat |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| front/idle | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| front/walk | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| front/strike | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| front/hit | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| front/death | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| front/chain_reel | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| front/manacle_pin | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| rear/idle | 0 | 0 | 0 | excluded | excluded | excluded | excluded |
| rear/walk | 0 | 0 | 0 | excluded | excluded | excluded | excluded |
| rear/strike | 0 | 0 | 0 | excluded | excluded | excluded | excluded |
| rear/hit | 0 | 0 | 0 | excluded | excluded | excluded | excluded |
| rear/death | 0 | 0 | 0 | excluded | excluded | excluded | excluded |
| rear/chain_reel | 0 | 0 | 0 | excluded | excluded | excluded | excluded |
| rear/manacle_pin | 0 | 0 | 0 | excluded | excluded | excluded | excluded |

## Per-part value report

L* is measured per pixel before its median. The two far-thigh reference medians
are the same-view near-thigh medians minus 6, not their own sparse medians.
Mid-tones are hidden pixels within the reference 25th–75th percentile L* range.

| Region | Own visible pixels | Reference median L* | Hidden median L* | Difference | Hidden mid-tones |
| --- | ---: | ---: | ---: | ---: | ---: |
| front/pelvis | 42 | 1.103 | 4.026 | 2.923 | 1367 |
| front/thigh_far | 14 | 7.377 | 8.805 | 1.428 | 1561 |
| front/thigh_near | 483 | 13.377 | 11.694 | 1.683 | 1313 |
| front/shin_far | 555 | 2.801 | 3.619 | 0.818 | 821 |
| front/shin_near | 909 | 6.761 | 6.761 | 0.000 | 313 |
| rear/pelvis | 375 | 13.053 | 12.700 | 0.353 | 1082 |
| rear/thigh_far | 7 | 9.232 | 11.633 | 2.401 | 1538 |
| rear/thigh_near | 759 | 15.232 | 17.498 | 2.265 | 649 |
| rear/shin_far | 792 | 6.532 | 8.640 | 2.108 | 712 |
| rear/shin_near | 1455 | 11.031 | 14.372 | 3.342 | 392 |

The source near-thigh medians are 13.377 front and 15.232 rear, giving targets
7.377 and 9.232. Source a*/b* is retained before sRGB gamut clipping and 8-bit
encoding; encoded reference medians are separately recorded in fill provenance.

## Proof and provenance

- `focused_round6.log`: Ran 32 tests in 16.566s / OK.
- `art_gate_round6.log`: Ran 49 tests in 15.061s / OK.
- `python_suite_round6.log`: Ran 429 tests in 309.165s / OK (skipped=61).
- `godot_suite_round6.log`: FULL SUITE RUNTIME: 784.570 seconds (budget 900 seconds) / TEST RESULT: PASS.
- `validation_round6.json`: `ok: true`, no errors; 81 front / 60 rear painted
  nodes, 23 joints each, zero meshes.
- Fresh headless sampling: `MAQUETTE_MOTION_SAMPLES: PASS (458 poses)` and
  `MAQUETTE_EXPOSURE: PASS (42 requests; 0 unknown solos)`.
- Rest identity: front **0**, rear **0** differing RGBA pixels. All 113 tracked
  source files match the round5 checkpoint. Archive `provenance/round5/` contains
  243 prior derived files with verified SHA-256 hashes.
- Hidden fill: 39 filled requests / 34,395 pixels; three empty requests;
  **0 magenta** in all 141 runtime images and all 458 CPU motion frames.
- CPU gates: **PASS**; scoped colour **0**, detached small pixels **0**, rear arm
  outside **0**, visible rear arm **0**, magenta **0**, value failures **0**.
- Native motion parser: exit 0 (`native_motion_parser_round6.log`), not renderer proof.

`proof/cpu_round6_keyframes.png` and the rear far-thigh fill were visually inspected
as CPU diagnostics. The eight selected problem/review poses have no detached
components of any size. `proof/round6_audit.json` records source, archive, runtime,
transform and component checks. The initial single-pixel repair failed the motion
speck gate; its diagnostic and focused log are retained under explicit initial
names. Final motion proofs include the connecting ownership repair.
NumPy Lab warnings and Godot certificate/resource-exit diagnostics remain in logs.

## Files and chosen procedural defaults

The implementation is in `tools/maquette_cutout.py`, covered by
`tests/test_maquette_cutout.py` and documented in `spec/cutout_workflow.md`.
This case owns `recipes/rig.json`, `recipes/motion_adapter.gd.in`, `motion.gd`,
`probes/motion_gates.py`, regenerated ownership/layout/request/fill artifacts,
`proof/` reports and the prior-state archive. No production integration changed.

New procedural defaults: final material repairs use the 6px dilated cloth mask
or nearest protected painted owner (label-order ties); small repaired islands use
shortest 8-connected paths through existing opaque paint, with y/x traversal ties.
Sparse reference L* shifts clamp to 0..100; a*/b* is retained before standard sRGB
clipping and nearest-integer 8-bit encoding. Pin uses its existing `cast` envelope.
Existing seed 0, k=6, radius 3, 40-pixel threshold, outline `(20,16,21)`, 8-connected
component checks, one-pixel arm margin, y/x translation ties and linear interpolation
between constrained phases remain recorded. The native four-surface probe timeout
is 240 seconds. No `TODO_DESIGN` remains in the current case or fill provenance.

## Reproduce headless verification

```sh
python3 tests/test_maquette_cutout.py
python3 tests/test_art_identity_gate.py
python3 -m unittest discover -s tests -p 'test_*.py' -v
python3 tools/godot_task_runner.py --task-id rr-02 --stream --timeout 900 -- godot --headless --path . --script tests/run_tests.gd
python3 tools/cutout_workflow.py validate experiments/cutouts/chainbound_gaoler/mq3 --protect all
python3 experiments/cutouts/chainbound_gaoler/mq3/probes/motion_gates.py --case experiments/cutouts/chainbound_gaoler/mq3 --cpu
python3 tools/godot_task_runner.py --task-id rr-02 --stream -- godot --headless --path . --check-only --script experiments/cutouts/chainbound_gaoler/mq3/probes/native_motion.gd
```

## Windowed proof for the director

Run from this worktree in a window-server session, using a fresh capture directory.
The overview/rest captures are 1920×1080 at 100% UI scale. The motion probe adds
512×512 RGBA, physical paint-node IDs, raw arm and body masks for all 458 frames
plus two rest calibrations. The collector requires current input/output hashes,
complete unique frame coverage, exact rest ownership calibration and byte-exact
RGBA agreement with the primary verified reel. CPU diagnostics cannot satisfy it.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02
case_dir="$PWD/experiments/cutouts/chainbound_gaoler/mq3"
capture_dir=/private/tmp/rr-02-mq3-render-v06
python3 tools/visual_probe_runner.py "$case_dir/probes/native_rest.gd" --task-id rr-02 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --expect-size 255x255 --proof-contract "$case_dir/probes/rest_contract.json" --result-manifest "$case_dir/proof/native_rest_round6_result.json" -- --case "$case_dir/cutout.json"
python3 tools/cutout_workflow.py render "$case_dir" --output "$capture_dir" --task-id rr-02
python3 tools/cutout_workflow.py verify-render "$case_dir" --output "$capture_dir"
python3 "$case_dir/probes/motion_gates.py" --case "$case_dir" --capture-native "$capture_dir" --task-id rr-02
python3 "$case_dir/probes/proof.py" --case "$case_dir" --native-output "$capture_dir"
```

Reel: `/private/tmp/rr-02-mq3-render-v06/videos/cutout_review.mp4`.
Native counts: `/private/tmp/rr-02-mq3-render-v06/motion_gates.json`.
Ownership/masks: `/private/tmp/rr-02-mq3-render-v06/motion_gate_capture/`.
The collector writes eight-frame clip/view sheets under `proof/native_keyframes/`
and `proof/native_motion_gates.json`. Native v06 capture, director visual review
and any later publication remain outstanding; no native v06 pass is claimed.
