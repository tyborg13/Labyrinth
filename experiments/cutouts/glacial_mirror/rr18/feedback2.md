# rr-18 — director feedback 2: rigid air calibration

Implemented the director's [seam calibration](../../../../spec/peer_benchmark/feedback/rr-18_feedback_2.md). The case explicitly opts into `seam_policy: "air_between_rigid_pieces"`, with `seam_protected_pieces: ["torso"]`. `TODO_DESIGN_source_gap_calibration` is resolved and removed from inputs, cutout metadata and production integration. **Seam acceptance remains incomplete: 13 rear frames contain 14 rejected pocket occurrences.** No frame exceptions or art/motion changes were added.

## Rule and implementation

- The generic `tools/humanoid_cutout/rigid_air.py` checks **every pixel in every enclosed pocket**, including one-pixel pockets and single-owner boundaries. Each pixel is mapped through every rigid piece's inverse into immutable allowed silhouette/tuck masks. This also catches a missing piece that disappears from the boundary.
- A pocket passes when every mapped pixel is outside the pieces' own painted silhouettes and tucks. Transparent approved-paint provenance is recorded; unrelated stones occupying the same source coordinate cannot turn air into this piece's interior. A hit on any piece's immutable mask fails, even when the approved composite is transparent there.
- The protected torso uses its visible contour, including enclosed interiors. Actual continuation/tuck texels remain checked separately. Combining overlapping tucks before filling the protected contour would incorrectly close exterior air between boulders; the code explicitly avoids that.
- Headless `rr18_seams.py` and the native shared gate use the same classifier. The anatomy schema adds optional policy/protected-piece fields. Omitted/`strict` policies retain the exact existing joint-local rule for every other figure. No runtime renderer code changed and no creature-name branch was added.
- Remaining failures receive per-pocket crops at 3× zoom with 8 px context; the report records the original pose bbox, source coordinates, material hit counts and crop path. These are CPU diagnostics, never native renderer proof.

The small generic extensions are exactly `rigid_air.py`, `anatomy.schema.json` and the opt-in branch in `gates.py`. Case tools/data, `tests/test_rr18_air_policy.py`, `tests/test_rr18_humanoid.py`, mutations, documentation and proof metadata are the other changes. Production changes only clear the resolved integration placeholder.

## Regressions and observed results

Nine generic policy regressions cover allowed air, punched stone, a single missing pixel, missing whole-piece ownership, missing tuck despite transparent composite, protected torso, unrelated source paint, strict Seer/Thrall default, and invalid/skinned policy inputs. A further real-pose regression checks the director's front guard20/rear Refraction32 examples plus rear idle0. Existing crop-snap mutation coverage remains active. Two new mutation probes deliberately disable air allowance and stone rejection; both are caught.

```text
Ran 198 tests in 168.006s
OK
RR18 MUTATION rigid air allowance: CAUGHT
RR18 MUTATION rigid stone interior: CAUGHT
RR10 BONE SAMPLES: PASS (896 poses; headless transforms only)
RR18 NATIVE PROBE LOAD: PASS
MAQUETTE PRODUCTION LOGIC: PASS (940 frames)
SFX SYNC HARNESS RESULT: PASS (4075 observations, 0 failures)
SFX SYNC HARNESS RESULT: PASS (3348 observations, 0 failures)
SFX SYNC HARNESS RESULT: PASS (1604 observations, 0 failures)
TEST REGISTRATION AUDIT: PASS (750 scripts; full suite=406, quarantined=29, windowed probe=315)
RR18 FRONT SEAMS: PASS (0 errors)
RR18 REAR SEAMS: FAIL (13 errors)
RR18 SOURCE/CUT GATES: PASS (0 errors; both views)
RR18 ALL GATES: FAIL (13 unique errors)
```

Production logic passes 940 frames **in each view**; all **eight** mutations are caught. Knees, supports, action direction/coverage, dense reach and production rest pass with zero errors in both views. Raw source rest and density-derived production rest remain 0 px. The scan covers **341 frames per view**, allows 349 front and 1,735 rear air-pocket occurrences, and finds zero other clean-piece defects. There are no native pixels from this worker.

Seer/Thrall preservation: `RR14 SEER BYTE IDENTITY: PASS (777 files; only two input-binding objects excluded)`, `RR16 THRALL POSE IDENTITY: PASS (990 exact rows)`, `RR16 SEER POSE IDENTITY: PASS (1258 exact rows)`. The Git-blob audit passes **3,616 protected tracked files** and **313 unchanged Mirror PNGs**, excluding only the declared generic extensions. Exact log lines/hashes are in [proof/verification.json](proof/verification.json). No full suites, peer review, commit, stage or publication were performed.

## Remaining failures with crops

All remaining pockets contain **one** pixel mapping into an existing hidden continuation. The columns show total pocket pixels / failing stone pixels; source coordinates are in the approved 255×255 source space. No case/frame exceptions were added. Every crop was inspected.

| View | Clip | Frame | Pose bbox | Pocket / stone px | Rejected source | CPU crop |
|---|---|---:|---|---:|---|---|
| rear | move | 1 | [296, 305, 299, 306] | 3 / 1 | `hidden_thigh_far` (168,178) | [crop](proof/seam_cpu/rear_move_0001_pocket_00.png) |
| rear | refraction | 13 | [295, 305, 299, 306] | 4 / 1 | `hidden_thigh_far` (168,178) | [crop](proof/seam_cpu/rear_refraction_0013_pocket_00.png) |
| rear | refraction | 14 | [296, 305, 299, 306] | 3 / 1 | `hidden_thigh_far` (168,178) | [crop](proof/seam_cpu/rear_refraction_0014_pocket_00.png) |
| rear | refraction | 15 | [296, 305, 299, 306] | 3 / 1 | `hidden_thigh_far` (168,178) | [crop](proof/seam_cpu/rear_refraction_0015_pocket_00.png) |
| rear | refraction | 16 | [296, 305, 299, 306] | 3 / 1 | `hidden_thigh_far` (168,178) | [crop](proof/seam_cpu/rear_refraction_0016_pocket_00.png) |
| rear | refraction | 17 | [296, 305, 299, 306] | 3 / 1 | `hidden_thigh_far` (168,178) | [crop](proof/seam_cpu/rear_refraction_0017_pocket_00.png) |
| rear | refraction | 58 | [296, 305, 299, 306] | 3 / 1 | `hidden_thigh_far` (168,178) | [crop](proof/seam_cpu/rear_refraction_0058_pocket_00.png) |
| rear | refraction | 59 | [295, 305, 299, 306] | 4 / 1 | `hidden_thigh_far` (168,178) | [crop](proof/seam_cpu/rear_refraction_0059_pocket_00.png) |
| rear | guard | 7 | [295, 305, 299, 306] | 4 / 1 | `hidden_thigh_far` (168,178) | [crop](proof/seam_cpu/rear_guard_0007_pocket_00.png) |
| rear | guard | 8 | [296, 305, 299, 306] | 3 / 1 | `hidden_thigh_far` (168,178) | [crop](proof/seam_cpu/rear_guard_0008_pocket_00.png) |
| rear | guard | 16 | [300, 181, 302, 186] | 8 / 1 | `hidden_upper_far` (165,93) | [crop](proof/seam_cpu/rear_guard_0016_pocket_00.png) |
| rear | guard | 16 | [337, 187, 343, 189] | 8 / 1 | `hidden_upper_far` (168,55) | [crop](proof/seam_cpu/rear_guard_0016_pocket_01.png) |
| rear | guard | 47 | [296, 305, 299, 306] | 3 / 1 | `hidden_thigh_far` (168,178) | [crop](proof/seam_cpu/rear_guard_0047_pocket_00.png) |
| rear | guard | 48 | [295, 305, 299, 306] | 4 / 1 | `hidden_thigh_far` (168,178) | [crop](proof/seam_cpu/rear_guard_0048_pocket_00.png) |

## Headless reproduction

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && python3 tools/godot_task_runner.py --task-id rr-18 --stream -- godot --headless --path . --script tests/rr18/action_direction.gd -- --case experiments/cutouts/glacial_mirror/rr18 --output experiments/cutouts/glacial_mirror/rr18/proof/samples.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && python3 -B experiments/cutouts/glacial_mirror/rr18_gates.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && python3 -B experiments/cutouts/glacial_mirror/rr18_focused.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && python3 -B experiments/cutouts/glacial_mirror/rr18_mutations.py
```

The gate exits 1 for the 13 reported rear frames; this result is retained. Captures stay ignored, while source-coordinate reports and this index remain reviewable.

## Proof for the design owner

Run this exact sequence at **1920×1080, 100% UI scale**. No windowed command was attempted here. The wrapper uses `tools/visual_probe_runner.py` and the existing proof contracts. Native proof retains the newly approved case policy and all remaining stone/tuck failures.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-18 && sh experiments/cutouts/glacial_mirror/rr18_proof.sh review
```

Capture paths: `proof/{native_rest,native,contact_sheets,idle_native,production_native}`, plus ignored `*.mp4`. Native rest sealing and renderer inspection are pending. No `inspection_fixture.py` command was requested; fixture preparation belongs to the director.

## TODO_DESIGN, chosen defaults and open issues

- **TODO_DESIGN:** none. The calibration question is resolved. The 13 rejected frames are explicit failures rather than unspecified policy.
- **Chosen defaults:** diagnostic `CROP_PADDING_PX=8`, inherited `CROP_ZOOM=3`; named 24 px synthetic fixtures, body/air/punch rectangles, split coordinate, RGBA/check values and identity transform in `tests/test_rr18_air_policy.py`; `AIR_PROOF_FRAMES` selects three existing poses. All are proof-only. Existing proof cadence/cameras/timeouts remain unchanged. No player-facing value was chosen.
- **Open issues:** the reported rear continuation pixels and director native rest/sprite/idle/production inspection. Art, motion and masks are preserved; no exceptions were added. Existing macOS headless CA-certificate/shutdown warnings remain visible in logs without changing assertion outcomes.
