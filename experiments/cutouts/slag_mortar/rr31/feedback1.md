# rr-31 feedback 1: stopped at calibrated overlap

All 3,016 presented CPU frames of the four integration humanoid v2 rigs were measured, across all clips and both views. The required maxima do **not** separate all six torn round-3 frames. Both brace holds and rear death overlap. No threshold has been installed, no budget has been rerun, and no motion key has been changed.

This report supersedes the earlier rest-relative acceptance and budget conclusions. The earlier 47 `TODO_DESIGN_budget_*` labels are withdrawn as current motion findings; the historical numeric records remain intact.

## 1. Approved calibration population

| Integration rig | Case | Front / rear frames | Rest heights (px) | Zones |
|---|---|---:|---:|---:|
| hoarfrost_seer | experiments/cutouts/hoarfrost_seer/rr10 | 467 / 467 | 206 / 235 | 10 / 9 |
| arc_thrall | experiments/cutouts/arc_thrall/rr11 | 335 / 335 | 202 / 217 | 13 / 13 |
| glacial_mirror | experiments/cutouts/glacial_mirror/rr18 | 344 / 344 | 230 / 238 | 14 / 14 |
| hollow_mimic | experiments/cutouts/hollow_mimic/rr29 | 362 / 362 | 218 / 215 | 14 / 14 |

The hero uses its own protagonist rig/motion, cape and equipment schema; it has no shared humanoid-v2 ownership or joint-zone records and is excluded under the brief’s condition. No foreign rig or record was modified.

The formulas, native 14 px radius and 2 px contour depth are unchanged. Shared ownership tags split skinned sleeves/legs into anatomical regions; semantic aliases make fists/hands and robes/pelves comparable. A zone follows the mean painted contact posed through both pieces. Separated approved stones use the exact nearest painted pixel-centre pairs; regions without visible anatomical owners are absent for that rig/view. Those measurement correspondences are explicit in `calibration.json`, alongside centroids and contact methods.

The shared `mesh_map`/`mapped` raster handles skins. Rigid layers use actual sampled Sprite2D matrices. Mimic uses its captured dynamic z indices, then actual scene-tree order for equal depths. Only topmost rest-exterior source texels count as contours. Each metric is counted separately inside each posed zone.

`calibration.json` records complete raw-count histograms, sample counts, median, p95, extrema and normalized maxima for every available zone/rig/view, input hashes, sample hashes and the exact maximum witness for all 42 threshold entries. Height is the fixed inclusive vertical extent of that view’s assembled rest silhouette. Normalization is `count * 100 / rest_height`; no resizing, tuning or extra tolerance is used. `proof/logs/calibration_frames.json` retains all frame observations. All 3,016 approved frames are within these maxima by construction.

## 2. Proof for the design owner: six historical negatives

Values below are the **largest signed excess across zones for each metric**, in pixels per 100 px figure height. Positive means failure; negative means overlap. All per-zone margins and native-pixel equivalents are in `calibration.json`. Notches/frays use the untouched lossless native review frames. Interior contours use CPU attribution through those historical native Sprite2D matrices, as the original CPU-only contour requirement specifies.

| View / torn frame | Notch excess | Fray excess | CPU contour excess | Result |
|---|---:|---:|---:|---|
| front lob32 | +6.658764 | -0.153396 | -8.372093 | rejected |
| front brace20 | -2.522904 | -0.917431 | -2.268807 | **OVERLAP** |
| front death78 | -2.053421 | -0.917431 | +0.018593 | rejected |
| rear lob32 | +1.355897 | -0.917431 | -8.372093 | rejected |
| rear brace20 | -3.107663 | -0.917431 | -3.388704 | **OVERLAP** |
| rear death78 | -1.322674 | -0.641470 | -3.089639 | **OVERLAP** |

Observed result: `RR31 CALIBRATION: STOP_overlap (3016 approved frames; 3/6 torn frames rejected)` (exit 2, intentional acceptance failure). Native morphology alone rejects 2/6; front death is rejected only by CPU contour. Front death’s contour excess is just 0.039604 native pixels of normalized allowance, not a robust visual separator.

The failing excesses are front lob32: shoulder_far notches +14.183168 native px; rear lob32: elbow_near notches +3.037209 native px; front death78: hip_far contour +0.039604 native px. The three overlap frames exceed no calibrated metric in any zone. There is no lower maximum-based threshold that both preserves every approved witness and rejects these frames under this prescription.

## 3. Budgets and current motion

Stopped at the director’s explicit overlap condition. No replacement budget sweep, director-key validation or new-motion full-frame acceptance was run. The old strict-rest budgets cannot establish any remaining motion violation. No new `TODO_DESIGN_budget_*` is asserted. The raw protected motion, compiled motion, and both imports are unchanged. Old strict-rest pass/fail counts are historical only.

## 4. Eleven seam observations

All 11 reproduce. Bboxes are half-open native 512×512 proof coordinates. Four large pockets are each flagged by only one inverse-mapped pixel. The seven others contain one pixel each. The visible source texel selected by the inverse remains opaque; the fixed-grid renderer selects an adjacent transparent texel. This is an inverse/raster disagreement, not evidence that a construction texel was removed. No source repair or gate exemption was applied at the requested stop. The observations remain open for native inspection.

| Clip / frame | Hole bbox | Area | Flagged visible piece | Inverse source → raster source |
|---|---|---:|---|---|
| front/lob33 | [322, 242, 323, 243] | 1 | upper_near | [194, 112] → [194, 111] |
| front/lob67 | [322, 240, 323, 241] | 1 | upper_near | [194, 112] → [194, 111] |
| front/scatter39 | [321, 238, 322, 239] | 1 | upper_near | [194, 112] → [194, 111] |
| rear/lob59 | [347, 307, 348, 308] | 1 | fore_far | [215, 182] → [215, 183] |
| rear/lob60 | [347, 307, 348, 308] | 1 | fore_far | [215, 182] → [215, 183] |
| rear/brace4 | [344, 312, 345, 313] | 1 | fore_far | [215, 182] → [215, 183] |
| rear/brace7 | [280, 264, 311, 331] | 566 | upper_far | [154, 134] → [154, 135] |
| rear/brace8 | [280, 264, 309, 331] | 574 | upper_far | [154, 134] → [154, 135] |
| rear/brace47 | [280, 264, 309, 331] | 564 | upper_far | [154, 134] → [154, 135] |
| rear/brace48 | [280, 264, 311, 331] | 566 | upper_far | [154, 134] → [154, 135] |
| rear/brace50 | [344, 312, 345, 313] | 1 | fore_far | [215, 182] → [215, 183] |

`seam_observations.json` includes all surrounding pieces, hidden-layer traces, source hashes and exact destinations. All 11 unmasked CPU frames are under `proof/seam_holes/{view}_{clip}_{frame:04d}.png`; each was inspected.

## 5. Focused verification and preservation

No art, source construction, production asset, layout, timing, motion, identity or density record changed. Existing rest, stretch, flap, walk-fit and density assertions remain unchanged. Both raw imports were directly checked against the protected file. No full suite or audio probe was run.

- hoarfrost_seer: `RR10 BONE SAMPLES: PASS (1258 poses; headless transforms only)`.
- arc_thrall: `RR10 BONE SAMPLES: PASS (1050 poses; headless transforms only)`.
- glacial_mirror: `RR10 BONE SAMPLES: PASS (968 poses; headless transforms only)`.
- hollow_mimic: `RR29 BONE SAMPLES: PASS (1008 poses; headless transforms only)`.
- slag_mortar: `RR10 BONE SAMPLES: PASS (1214 poses; headless transforms only)`.
- calibration: `Ran 8 tests in 0.599s`; `OK`.
- image_gates: `Ran 14 tests in 2.388s`; `OK`.
- mortar: `Ran 10 tests in 11.532s`; `OK`.
- `RR31 SEAM TRACE: 11/11 reproduced; 11/11 inverse/raster disagreements; no source edits`.
- `RR31 DIRECTOR IMPORTS: PASS (2/2 byte-identical; protected file unchanged)`.

Machine results: `proof/feedback1_results.json`. Transcripts: `proof/logs/{calibration,feedback1_calibration_tests,feedback1_images_tests,feedback1_mortar_tests,seam_observations}.log`. The calibration acceptance intentionally fails; test success does not certify the visuals.

## Reproduce headless evidence

Run from the rr-31 worktree. Samplers write only this unit’s ignored logs.

```sh
python3 tools/godot_task_runner.py --task-id rr-31 --stream -- godot --headless --path . --script tests/rr22/samples.gd -- --case res://experiments/cutouts/hoarfrost_seer/rr10 --output res://experiments/cutouts/slag_mortar/rr31/proof/logs/hoarfrost_seer_samples.json
python3 tools/godot_task_runner.py --task-id rr-31 --stream -- godot --headless --path . --script tests/rr22/samples.gd -- --case res://experiments/cutouts/arc_thrall/rr11 --output res://experiments/cutouts/slag_mortar/rr31/proof/logs/arc_thrall_samples.json
python3 tools/godot_task_runner.py --task-id rr-31 --stream -- godot --headless --path . --script tests/rr22/samples.gd -- --case res://experiments/cutouts/glacial_mirror/rr18 --output res://experiments/cutouts/slag_mortar/rr31/proof/logs/glacial_mirror_samples.json
python3 tools/godot_task_runner.py --task-id rr-31 --stream -- godot --headless --path . --script tests/rr29/samples.gd -- --case res://experiments/cutouts/hollow_mimic/rr29 --output res://experiments/cutouts/slag_mortar/rr31/proof/logs/hollow_mimic_samples.json
python3 tools/godot_task_runner.py --task-id rr-31 --stream -- godot --headless --path . --script tests/rr22/samples.gd -- --case res://experiments/cutouts/slag_mortar/rr30 --output res://experiments/cutouts/slag_mortar/rr31/proof/logs/slag_mortar_samples.json
python3 experiments/cutouts/slag_mortar/rr31_calibration.py
python3 experiments/cutouts/slag_mortar/rr31_seam_observations.py
LABYRINTH_TASK_ID=rr-31 python3 -m unittest discover -s tests -p 'test_rr31_calibration.py' -v
LABYRINTH_TASK_ID=rr-31 python3 -m unittest discover -s tests -p 'test_rr31_images.py' -v
LABYRINTH_TASK_ID=rr-31 python3 -m unittest discover -s tests -p 'test_rr30_mortar.py' -v
```

## Proof for the design owner: windowed commands

No windowed command was attempted. The unchanged eight-stage driver remains covered by its dispatch test, including required visual-probe contracts at 1920×1080 and 100% UI scale. These are the exact existing commands for the owner’s later inspection; they do not resolve the calibration overlap. No inspection-fixture command was requested by this brief.

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

Capture destinations remain rr30 `proof/native_rest/`, `native/`, `contact_sheets/`, `gait_move_native/`, `idle_native/`, `production_native/{front,rear}/` and the existing review MP4. New CPU seam captures are only under rr31 `proof/seam_holes/`.

## Chosen defaults, TODOs and open issues

`feedback1_defaults.json` lists measurement/test-only choices: progress 100 frames, nearest-pair memory chunks 1,024 pixels, interpolation tolerance 1e-9, measured height/contact correspondence and the synthetic 200 px / threshold 2 interpolation fixtures. No player-facing default was chosen.

No new design values or motion TODOs were introduced. The prior 47 uncalibrated budget TODOs are withdrawn as current findings. Open issues are the three overlapping torn frames and the eleven retained seam observations. A separating image criterion is needed before a meaningful new budget sweep can proceed. No commit, publication, peer review or signoff was performed.
