# mq-07 — Arc Thrall r2, feedback 1

Offline Blender implementation. The accepted raised shoulder is unchanged in
both views. Feedback 1 replaces the 1.4× upper-arm rule and resolves all three
design TODOs. Exact owner values are recorded in `feedback_1.json`; the complete
candidate input is `measurements.json`.

## Acceptance

1. Constant shaft diameter 17 source px / 68 native px, within ±1 source px,
   perpendicular to its front axis. Preserve the existing distal tip.
2. Open mouth at −2 source px / −8 native px from the elbow along the axis.
   Upper-arm skin enters the mouth, with no gap or proximal cap. The distal
   dome is 0.35 diameter: 5.95 source px / 23.8 native px high.
3. One mouth band: 3 source px / 12 native px tall, raised 1 source px / 4 native
   px radially. No other bands or rivets. Tube and band belong to `fore_near`;
   the inserted arm end stays `upper_near`.
4. Keep the accepted shoulder, all bone lengths and every other figure's
   delivery. Pass front IoU ≥0.70, rear ≥0.65, native facing/collision/ownership,
   unchanged capture geometry, cold/cache replay and bit-exact native replay.
   The camera-near lower foot must remain right of the other in both views.
5. Six native 1024 old/new/parts cells, shoulder marks, and front/rear elbow
   crops enlarged exactly 3×. Keep the complete commit inventory, ≤6,000,000
   bytes per figure, and hashes for discarded proof.

Axial pixel dimensions are normalized through the front projection. The
1.5-source-px wall is inherited from mq-04's measured tube. No new wall value,
decoration or perceptible dimension was chosen. No TODO_DESIGN fields remain.

## Implementation and files

- `blender/capped_cylinder.py`, `compile_recipe.py`: hollow socket, annular rim,
  integrated single band, constant shaft and oblate distal dome.
- `blender/socket_tuck.py`, `build.py`, `contract.py`: continue the actual anatomy
  boundary into the bore. Original boundary coordinates stay exact; the end
  contour fits the bore at the unchanged elbow joint and retains `upper_near`.
- `tube_proof.py`: independent dimensions, centre ray through the empty mouth,
  native arm entry/ownership, and front/rear raster shaft-width checks.
- `proof.py`, `assemble.py`, `curate.py`: capture binding, gates, native sheet
  with 3× crops, compact receipts, hash inventory and byte-budget verification.
- `tests/test_arc_thrall_maquette_r2.py`: shoulder/source/length preservation,
  feedback dimensions, annular mouth and closed distal shell, one band,
  anatomy continuation, labels, unchanged other-figure hashes and crop proof.

The prior shoulder helper `pose_adjustment.py` and covered-region support in
`view_states.py`/`validation.py` are retained. No .gd, runtime, input, save,
analytics, balance, icon, font or audio changes. The owner retains commits,
peer review, inspection acceptance and publication; this unit requests none.

## Chosen defaults

Implementation/proof only: 32 angular samples, 8 dome rings, solve epsilon
1e-10, socket epsilon 1e-8 m, native length tolerance 1e-5 m, rounded-joint
comparison tolerance 0.011 px. Entry-ray padding is 0.001 m. Raster widths sample
fractions 0.3/0.5/0.7 at 0.1 px intervals. These do not change analytic dimensions.

Proof crop is 256×256 native px; its 3× scale is owner-specified. Headers 28 px,
markers 6 px with 2 px outlines, padding 4 px, cyan/magenta shoulder marks,
background (24,24,24,255), existing Pillow default font, PNG compression 9.
Geometry fixtures use radius 0.5 m, length 3 m, 16 samples and 4 rings. Test-cell
RGBA values are (40,50,60,255)/(70,80,90,255). Native renderer settings are reused.

## Proof for the design owner

Blender runs only through the director bridge with 120 s per job. Stop if a job
is unanswered. No windowed Godot or inspection_fixture.py command applies to
this offline-only unit. Exact rebuild commands:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B -m spec.art_identity.maquettes.blender.compile_recipe spec/art_identity/maquettes/arc_thrall/r2/measurements.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 120 spec/art_identity/maquettes/blender/build.py -- /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/spec_native.json /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/proof/native --build-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 120 spec/art_identity/maquettes/arc_thrall/r2/tube_proof.py -- /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/spec_native.json /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/proof/native/maquette.blend /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/proof/tube_geometry.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 120 spec/art_identity/maquettes/blender/capture_view.py -- /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/spec_native.json /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/proof/native/maquette.blend /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/proof/front front
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 120 spec/art_identity/maquettes/blender/capture_view.py -- /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/spec_native.json /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/proof/native/maquette.blend /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/proof/rear rear
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 120 spec/art_identity/maquettes/blender/recipe_proof.py -- /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/spec_native.json /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/proof/determinism
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 120 spec/art_identity/maquettes/blender/exact_native_replay.py -- /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/proof/determinism /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/proof/determinism/exact_native_replay.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B -m spec.art_identity.maquettes.arc_thrall.r2.assemble
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B -m spec.art_identity.maquettes.arc_thrall.r2.proof --capture spec/art_identity/maquettes/arc_thrall/r2/proof/capture
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B -m unittest discover -s tests -p 'test_arc_thrall_maquette_r2.py' -v
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B -m unittest spec.art_identity.maquettes.blender.test_source_recipe spec.art_identity.maquettes.blender.test_delivery spec.art_identity.maquettes.blender.test_delivery_validation -v
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B tests/test_art_identity_gate.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B -m unittest discover -s tests -p 'test_*.py' -v
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B -m spec.art_identity.maquettes.arc_thrall.r2.curate
```

After passing native proof, curation retains the native cells and 3× elbow
crops in `proof/shoulder_tube_sheet.png`, compact `native_*.json` reports,
`tube_geometry.json`, `gates.json` and validation/bridge logs. Temporary PNGs,
blends and caches are hash-inventoried before deletion. Original mq-04 inputs
and native captures stay the comparison baseline.

## Feedback-1 native results

| Required measurement | Observed native px |
|---|---:|
| Shaft diameter, mesh perpendicular extent | 67.9218 |
| Shaft diameter, front raster samples | 67.3 / 67.0 / 67.3 |
| Shaft diameter, rear raster samples | 66.7 / 67.4 / 66.7 |
| Mouth offset above elbow | −8.0000 |
| Single-band axial height | 12.0000 |
| Band radial raise | 4.0000 |
| Distal dome height | 23.8000 |

The near upper-arm continuation crosses the mouth plane; 23 used vertices
are inside the bore. Its 22-vertex source boundary is retained exactly, and
its endpoint is the unchanged elbow joint. The independent centre ray through
the tube mouth first hits the inner distal cap, not a proximal disk.

| Painting fit | mq-04 baseline IoU | Feedback-1 IoU | Minimum |
|---|---:|---:|---:|
| Front | 0.7222672242 | 0.7071754385 | 0.70 |
| Rear | 0.7035146695 | 0.7310500094 | 0.65 |

Accepted shoulder coordinates remain front near (616,352), far (338,310.3),
and rear near (408,344), far (686,385.7). Every bone length is unchanged. The
shoulder rule and the direct lower-foot-right turn rule pass in both views.

`BLENDER_MAQUETTE: PASS` (10.1 s); `MQ07_TUBE_ENTRY: PASS` (0.6 s);
`FITTED_VIEW_CAPTURE: PASS; view=front` (60.5 s), `view=rear` (50.9 s).
`FITTED_RECIPE_PROOF: PASS; raw_hashes_identical=true;
max_joint_error=4.140378204781795e-06` (23.0 s).
`EXACT_NATIVE_REPLAY: PASS; unrounded_float32=true; mesh_count=17` (0.9 s).
`MQ07_NATIVE_ASSEMBLY: PASS`; `MQ07_POSE: PASS`; `MQ07_TUBE: PASS`;
`MQ07_DELIVERY: PASS; native_capture=true` (exit 0).

The 3072×2900 sheet has six unscaled 1024 cells and two 256-native-px crops
magnified exactly 3×. It has been opened for implementation inspection; the
director retains the visual verdict. Existing maximum-band fit guidance is
false in both old and new views; the required IoU gates pass. No threshold or
existing master assertion was changed.

## Feedback-1 validation

- Focused: `Ran 13 tests in 0.359s`, `OK`.
- Builder/source/delivery: `Ran 43 tests in 2.917s`, `OK`.
- Art identity: `Ran 111 tests in 39.709s`, `OK`.
- Full Python: `Ran 852 tests in 721.352s`, `OK (skipped=63)`.
- Curation: `COMMIT_CURATION: PASS`, within the 6,000,000-byte limit.
- `git diff --check`: PASS. All authored changes remain within the owned figure,
  shared Blender helpers and focused test. No .gd files changed.

No design TODO or implementation blocker remains. The existing maximum-band
fit guidance and the design-owner-owned empty task-helper metadata remain as
previously reported; neither required threshold nor an existing assertion was
rewritten. The original mq-04 delivery stays the comparison baseline, while
this complete r2 input/proof is ready for the owner's next inspection step.
