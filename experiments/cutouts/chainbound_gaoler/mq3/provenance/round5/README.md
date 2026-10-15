# Chainbound gaoler mq3 — round 5

The motion repairs and deterministic value matching are implemented. The literal
global colour gate still fails: the approved helmet, leather, hook and leg paint
share the tabard's colour range. The rear far-thigh dark-column issue also remains
unresolved: its seven visible reference pixels are nearly black. Additional torso
lean has no supplied curve. These are explicit design decisions below, not passes.

Changes remain uncommitted in the rr-02 worktree. Production assets, the copied
production motion, approved input pixels and game timing are unchanged. The
director owns windowed capture, review and publication. No windowed run, commit,
peer review or delegation was attempted. Gameplay inspection is not applicable
before production integration.

## Requirement status

1. **Tabard ownership:** all seven named front parts participate in material
   classification, with the 6px Euclidean tabard-solo dilation recorded. The
   explicit part list selects whole owners; dilation overlap does not crop the
   transfer. Initial candidate counts are pelvis 71, far thigh 174, near thigh 67,
   far shin 303, near shin 104, far coat 11 and near coat 20. After topology repairs,
   final tabard-owned pixels originating from those parts are respectively
   **71, 174, 69, 267, 0, 11 and 16**. Scattered matching colours on the shins must
   stay with the adjacent leg to avoid floating paint. No visible RGB is changed.
   The literal global gate reports **707,665** matching non-tabard sample
   pixels over 458 frames. This count includes repeated pixels across frames.
   At rest alone, front head 367, torso 171, belt 195 and hook 139 pixels qualify.
2. **Specks:** v04 native alpha/RGBA identified the supplied front/rear defects;
   ownership was traced through matching CPU pixels, explicitly labelled as CPU
   attribution. Six source repairs address the foot, coat and thigh-tip islands.
   A further 119 source pixels from newly separated 23/27/29/40px shin fragments
   return to adjacent leg owners. The full CPU sweep has **0** disconnected opaque
   8-connected components below 12px. The selected inspection frames have no
   detached components of any size. Native ownership-map capture is provided.
3. **Leg values:** pelvis, thighs and shins use same-view same-part visible RGB
   for a seeded k=6 palette and empirical L* quantiles. Diffusion determines spatial
   rank, then quantile matching restores the visible value distribution. Outlines
   remain unchanged and count in the gate. All ten median differences are below
   8, and all contain values in their visible part's interquartile range. Sparse
   references are reported rather than silently replaced. The rear far thigh
   remains nearly black; the numerical check does not resolve that visual defect.
4. **Rear punch:** the entire rigid fist arm is translated into the torso/head/coat
   union at all 70 strike/pin phases, using the shortest fitting integer offset.
   Every arm layer also draws behind that union. CPU counts are **0** outside-arm
   pixels and **0** visible-arm pixels. Compared with v04, only rear upper/fore/hand
   fist transforms in those two clips change; front transforms and pelvis drive
   are exact. No independent torso/shoulder lean curve was invented.

## Per-part value report

L* is measured per pixel before taking its median. Mid-tone counts are hidden
pixels within the visible part's 25th–75th percentile L* range. The full ranges,
source masks, palette, donor provenance and output digests are recorded in
`hidden_fills/index.json` and independently recomputed in the motion-gate report.

| Region | Visible pixels | Visible median L* | Hidden median L* | Difference | Hidden mid-tones |
| --- | ---: | ---: | ---: | ---: | ---: |
| front/pelvis | 42 | 1.103 | 4.026 | 2.923 | 1367 |
| front/thigh_far | 14 | 37.133 | 37.187 | 0.054 | 1093 |
| front/thigh_near | 483 | 13.377 | 11.694 | 1.683 | 1313 |
| front/shin_far | 562 | 2.801 | 3.619 | 0.818 | 811 |
| front/shin_near | 922 | 6.761 | 5.502 | 1.258 | 373 |
| rear/pelvis | 375 | 13.053 | 12.700 | 0.353 | 1082 |
| rear/thigh_far | 7 | 0.099 | 0.119 | 0.020 | 1312 |
| rear/thigh_near | 759 | 15.232 | 17.498 | 2.265 | 649 |
| rear/shin_far | 792 | 6.532 | 8.640 | 2.108 | 712 |
| rear/shin_near | 1455 | 11.031 | 14.372 | 3.342 | 392 |

The 14-pixel front far-thigh reference is unusually bright; the 7-pixel rear
reference contains no useful brighter mid-tones. Both carry named design TODOs.
The requested same-part calculation is implemented literally until a replacement
reference is authorized. Front candidate-part palettes exclude centroids within
DeltaE76 15 of tabard, since averaging other colours can recreate that hue.

## Proof and provenance

- Focused: `Ran 31 tests in 14.546s` / `OK` (`proof/focused_round5.log`).
- Art gate: `Ran 49 tests in 13.668s` / `OK`, exit 0 (`proof/art_gate_round5.log`).
- Python full suite: `Ran 428 tests in 265.181s` / `OK (skipped=61)` (`proof/python_suite_round5.log`).
- Godot full suite: `FULL SUITE RUNTIME: 750.855 seconds (budget 900 seconds)` /
  `TEST RESULT: PASS`, exit 0 (`proof/godot_suite_round5.log`).
- `validate --protect all`: `ok: true`, `errors: []`; 79 front / 60 rear nodes,
  23 joints each, zero meshes (`proof/validation_round5.json`).
- Fresh headless sampling: `MAQUETTE_MOTION_SAMPLES: PASS (458 poses)`;
  `MAQUETTE_EXPOSURE: PASS (42 requests; 0 unknown solos)`.
- Rest identity: front **0** and rear **0** different RGBA pixels. All 113 tracked
  source files remain byte-identical to v04. Archive `provenance/round4/` contains
  239 verified prior derived files, including requests and fill provenance.
- Hidden paint: 39 filled requests / 34,374 pixels, three empty
  requests, **0 magenta** in all 139 runtime images and all 458 CPU frames.
- CPU motion gates: **FAIL**, solely the literal colour count above. Other counts:
  small disconnected pixels **0**, arm outside **0**, visible rear arm **0**,
  magenta **0**, value failures **0** (`proof/cpu_motion_gates.json`).
- Native motion probe parser: exit 0; this is a parser check, not renderer proof.
- Fresh v05 `verify-render`: fails because `capture_input_sha256.json` does not
  exist yet. No native v05 counts are claimed.

`proof/cpu_round5_keyframes.png` was visually inspected as a CPU diagnostic,
including the supplied walk/strike problem poses. The filled rear far-thigh
preview was inspected and confirms the unresolved dark reference. The owner
traces and `proof/round5_audit.json` retain per-fragment and transform evidence.
Earlier test runs during regeneration and the rejected semantic-priority
experiment remain labelled separately; only the final logs above are the handoff.
The logs retain NumPy Lab warnings and Godot certificate/resource-exit diagnostics.

## Native motion-gate contract

The extra probe captures every authored frame in seven clips and both views,
plus one rest calibration per view: 460 poses, each with 512×512 RGBA, physical
paint-node IDs, unoccluded arm mask and torso/head/coat mask. Its overview is
1920×1080 at 100% UI scale. IDs encode the physical node index in RG bytes and
must reproduce the exact rest logical ownership before motion counts are trusted.

The Python collector verifies all input/output hashes, rejects incomplete or
duplicate frame sets, and requires every RGBA frame to match the main verified
reel byte-for-byte. It then evaluates the literal colour, silhouette, arm and
magenta gates. No CPU diagnostic can satisfy this contract. Overall exit status
remains failure when any gate fails; no metal/leather exceptions are hidden.

## TODO_DESIGN and chosen defaults

- `TODO_DESIGN_tabard_global_colour_gate`: choose a material/provenance scope or
  retain the literal global failures. Exact rest paint and cloth-only ownership
  cannot distinguish the shared helmet/leather/hook/blood colours by DeltaE alone.
- `TODO_DESIGN_sparse_value_reference_front_thigh_far` and
  `TODO_DESIGN_sparse_value_reference_rear_thigh_far`: authorize a useful reference
  for the 14/7-pixel samples. The established same-view trousers core is available
  but has not been substituted without a decision.
- `TODO_DESIGN_rear_torso_lean`: supply the lean curve, or accept the existing
  production body/pelvis motion with the concealed arm constraint.

New procedural defaults: closest integer arm translation, y then x tie break,
1px interior raster margin, linear interpolation between authored sample phases;
240s native-probe timeout for four surfaces over 460 poses; RG-byte node IDs;
empirical L* quantiles in stable diffusion order. The diagnostic contact sheet
uses 340px crops and four columns. Existing seed 0, k=6, radius 3, 40-pixel sparse
threshold, outline `(20,16,21)`, 8-connected component traversal and four-edge
adjacency voting remain recorded. Director thresholds are dilation 6px,
DeltaE76 15, disconnected component cutoff 12px and median L* difference 8.

## Proof for the design owner

Run in a window-server session from this worktree. The new directory must be
fresh. The colour gate will currently return failure and write its counts; the
other gates must still be inspected. Do not treat the entire result as approved.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02
case_dir="$PWD/experiments/cutouts/chainbound_gaoler/mq3"
capture_dir=/private/tmp/rr-02-mq3-render-v05
python3 tools/visual_probe_runner.py "$case_dir/probes/native_rest.gd" --task-id rr-02 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --expect-size 255x255 --proof-contract "$case_dir/probes/rest_contract.json" --result-manifest "$case_dir/proof/native_rest_round5_result.json" -- --case "$case_dir/cutout.json"
python3 tools/cutout_workflow.py render "$case_dir" --output "$capture_dir" --task-id rr-02
python3 tools/cutout_workflow.py verify-render "$case_dir" --output "$capture_dir"
python3 "$case_dir/probes/motion_gates.py" --case "$case_dir" --capture-native "$capture_dir" --task-id rr-02
python3 "$case_dir/probes/proof.py" --case "$case_dir" --native-output "$capture_dir"
```

Reel: `/private/tmp/rr-02-mq3-render-v05/videos/cutout_review.mp4`.
Native gate counts: `/private/tmp/rr-02-mq3-render-v05/motion_gates.json`.
Native ownership/masks: `/private/tmp/rr-02-mq3-render-v05/motion_gate_capture/`.
The collector also writes eight-frame sheets per clip/view under
`proof/native_keyframes/` and `proof/native_motion_gates.json`.
