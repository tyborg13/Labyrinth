# rr-31 feedback 2 — source seam repair

The director accepted the new motion on the supplied round-1 native action sheets. Image morphology/contour metrics are now diagnostics only. Acceptance remains director visual judgment plus the unchanged rr30 native gates.

## 1. Seven native failures and source construction

The saved round-1 native report contains exactly seven failures. Its images and manifest are untouched. The following source repairs cover every legal nearest-sampling choice at each flagged native destination; this is CPU source/pose evidence, not a new native capture.

| Native failure | Destination pixel | Source pieces | Hidden cover source choices |
|---|---|---|---|
| front lob33 | [322,242] | upper_near / its hidden cover | [194,111], [194,112] |
| front lob67 | [322,240] | upper_near / its hidden cover | [194,111], [194,112] |
| front scatter39 | [321,238] | upper_near / its hidden cover | [194,111], [194,112] |
| rear brace7 | [284,265] | upper_far / its hidden cover | [154,134], [154,135] |
| rear brace8 | [284,265] | upper_far / its hidden cover | [154,134], [154,135] |
| rear brace47 | [284,266] | upper_far / its hidden cover | [154,134], [154,135] |
| rear brace48 | [284,265] | upper_far / its hidden cover | [154,134], [154,135] |

The front defects were one-pixel pockets. The four rear brace pockets contained 566, 574, 564 and 566 pixels respectively, but only one missing source-contact pixel made each fail the rigid-air classifier. The repaired upper-arm contact pixel is painted in both legal sampling directions; the surrounding natural arm/body air remains unrestricted under the existing rule.

The final source delta is **14 front texels and 2 rear texels**, all copied from existing own-piece non-outline material. The front shoulder/strap and forearm covers use hidden_torso, hidden_upper_near, hidden_upper_far and hidden_fore_far. The far cuff/hand junction beside the brace hip uses hidden_hand_far. The rear patches use hidden_upper_far and hidden_fore_far; the latter also resolves four CPU wrist observations absent from the native failure list. No painting or visible cut changed.

`feedback2_source_fixes.json` records targets, exact donor coordinates, rejected candidate texels, the original seven errors and original native input hashes. `feedback2_native_targets.json` retains captured native matrices and frame hashes. Every addition is hidden in the neutral pose. Disconnected or over-budget candidate patches were discarded, including two forearm texels exceeding 3 px during death. The connected hand-side cuff repair has maximum potential exposure distance 2.366480 px across all 431 front poses. The existing 3 px cover and dark-donor checks were retained.

The case textures, proof classification masks, required tuck masks, untreated Mortar density sources and processed production underlays agree. Integration hashes are refreshed and production remains marked pending native proof. Density processing parameters are unchanged; only seven Mortar source/output digest pairs changed.

## 2. Diagnostics cannot block proof

`rr31_images.py` always returns success after writing either its measurements or an explicit unavailable/error report, with `blocking=false`. A diagnostic failure remains `ok=false` in the report. `rr30_seams.py` records image failures without adding acceptance errors, including diagnostic exceptions.

The native stage keeps the rr30 gate exit status. rr31 diagnostic failures do not alter it. Sheets/review retain their canonical native validation; production retains its production gate. Neither consults rr31 image acceptance. Tests inject a failing image process and verify successful dispatch through native/sheets/production/review, while an injected rr30 native failure still stops the native stage. The existing eight-stage runner/1920×1080/100% contract test is unchanged.

## 3. Preservation

`proof/feedback2_preservation.json` checks 101 immutable files against this turn’s HEAD: protected director input, both imports, both compiled motion files, paintings, visible source/production cuts, layouts, neutral production rest PNGs, identity registry and density registry. Both assembled rests have 0 differing pixels. Bone graph, node names, piece count, pivots, scales, flap and all motion channels are unchanged. The existing stretch and walk-fit checks remain active.

## 4. Focused verification

Final result lines and numerical summaries are recorded in `proof/feedback2_results.json`. No full suite, audio probe, windowed engine, peer review or publication was run. The original native report is retained with its seven historical errors; fresh native zero-error acceptance must be observed by the director after recapture.

Source replay, mutation, CLI/dispatch, preservation and runtime tests are in `tests/test_rr31_finish_seams.py`, the existing rr31 tests and the existing focused Mortar/joint-surface tests. Old round-1 seam attribution remains bound to its native input inventory after these source edits.

## Proof for the design owner

New unmasked CPU frames: `proof/feedback2_cpu/{view}_{clip}_{frame:04d}.png` (13 exports). Native-before / CPU-after detail comparisons: `proof/feedback2_{lob,brace,death}_detail.png`. Their JSON labels explicitly distinguish renderer evidence from CPU projection; no capture is masked or rewritten. All exported frames and detail comparisons were inspected.

The exact owner commands, from this worktree, are:

```sh
LABYRINTH_TASK_ID=rr-31 sh experiments/cutouts/slag_mortar/rr30_proof.sh density
LABYRINTH_TASK_ID=rr-31 sh experiments/cutouts/slag_mortar/rr30_proof.sh rest
LABYRINTH_TASK_ID=rr-31 sh experiments/cutouts/slag_mortar/rr30_proof.sh native
LABYRINTH_TASK_ID=rr-31 sh experiments/cutouts/slag_mortar/rr30_proof.sh sheets
LABYRINTH_TASK_ID=rr-31 sh experiments/cutouts/slag_mortar/rr30_proof.sh walk
LABYRINTH_TASK_ID=rr-31 sh experiments/cutouts/slag_mortar/rr30_proof.sh idle
LABYRINTH_TASK_ID=rr-31 sh experiments/cutouts/slag_mortar/rr30_proof.sh production
LABYRINTH_TASK_ID=rr-31 sh experiments/cutouts/slag_mortar/rr30_proof.sh review
```

These still route Godot through the task runner and native rendering through visual_probe_runner. No inspection-fixture command was requested. Native outputs stay under rr30 `proof/native_rest/`, `native/`, `contact_sheets/`, `gait_move_native/`, `idle_native/`, `production_native/{front,rear}/`, and `slag_mortar_review.mp4`. No review clip was fabricated from CPU frames.

## Chosen defaults, TODOs and open issues

Only proof choices were selected: 4× diagnostic crops, existing proof matte [30,30,36,255], the recorded crop rectangles, 100-frame progress logging and a 180-second test subprocess cap. Source coordinates/donor coordinates are measurements of the approved paint and captured defects; the cover bound and luminance policy are inherited. `proof/feedback2_defaults.json` records these values.

No new TODO_DESIGN placeholder or budget is introduced. Motion TODOs from the rejected image thresholds remain withdrawn. The outstanding acceptance step is the director’s fresh native run and visual judgment, including the review clip; this sandbox cannot run windowed proof. All changes are uncommitted.

## Final observed result lines

- rr31: `Ran 29 tests in 14.688s`; `OK`.
- mortar: `Ran 10 tests in 11.307s`; `OK`.
- joint_surfaces: `Ran 4 tests in 432.951s`; `OK`.
- `RR30 FRONT CPU COVERAGE AND JOINT GATES: PASS (431 frames; 0 errors)`.
- `RR30 REAR CPU COVERAGE AND JOINT GATES: PASS (431 frames; 0 errors)`.
- `RR30 SOURCE/BONE/KNEE GATES: PASS (0 errors; both views)`.
- `RR31 SEAM CPU TARGETS: PASS (11/11 clean)`.
- `RR31 NATIVE-POSE SOURCE COVERAGE: PASS (7/7 holes covered for every legal UV tie; CPU source replay)`.
- `RR31 FEEDBACK2 PRESERVATION: PASS (101 immutable files; both rests 0px; density calibration unchanged)`.
- `RR31 FEEDBACK2 PRODUCTION ALPHA: PASS (80/80 case/production masks match)`.
- `RR31 NATIVE DIAGNOSTIC: UNAVAILABLE (Stale native proof; rerun rr30_proof.sh native; non-blocking)`; exit 0.

Maximum visible cover distances are front 2.999497061328248 px and rear 2.9981903453869387 px. Walk fit remains front 0.091893 px / rear 0.098218 px; stance drift remains 0 px. All 80 pieces retain their rigid transforms (maximum affine residue 2.6365098459990577e-07). Image diagnostics flag 363 front and 338 rear frames; all 862 frames pass blocking CPU coverage/material checks.
