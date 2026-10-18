# mq-07 — Arc Thrall planted r2, feedback 2

Offline Blender implementation. The accepted raised shoulder is unchanged in
both views. Feedback 1 replaces the 1.4× upper-arm rule and resolves all three
design TODOs. Exact owner values are recorded in `feedback_1.json`; the complete
input is `measurements.json`, promoted unchanged to `../measurements.json` after the gates pass.

## Acceptance

1. Constant shaft diameter 17 source px / 68 native px, within ±1 source px,
   perpendicular to its front axis. Preserve the existing distal tip.
2. Open mouth at −2 source px / −8 native px from the elbow along the axis.
   Upper-arm skin enters the mouth, with no gap or proximal cap. The distal
   dome is 0.35 diameter: 5.95 source px / 23.8 native px high.
3. One mouth band: 3 source px / 12 native px tall, raised 1 source px / 4 native
   px radially. No other bands or rivets. Tube and band belong to `fore_near`;
   the inserted arm end stays `upper_near`.
4. Keep the accepted shoulder and all bones outside the newly planted far leg, and every other figure's
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

Blender runs only through the director bridge: stop if pickup exceeds 120 s;
allow up to 900 s after pickup. No windowed Godot or inspection_fixture.py command applies to
this offline-only unit. Exact rebuild commands:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B -m spec.art_identity.maquettes.blender.compile_recipe spec/art_identity/maquettes/arc_thrall/r2/measurements.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 900 spec/art_identity/maquettes/blender/build.py -- /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/spec_native.json /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/proof/native --build-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 900 spec/art_identity/maquettes/arc_thrall/r2/tube_proof.py -- /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/spec_native.json /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/proof/native/maquette.blend /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/proof/tube_geometry.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 900 spec/art_identity/maquettes/blender/capture_view.py -- /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/spec_native.json /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/proof/native/maquette.blend /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/proof/front front
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 900 spec/art_identity/maquettes/blender/capture_view.py -- /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/spec_native.json /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/proof/native/maquette.blend /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/proof/rear rear
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 900 spec/art_identity/maquettes/blender/recipe_proof.py -- /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/spec_native.json /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/proof/determinism
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 900 spec/art_identity/maquettes/blender/exact_native_replay.py -- /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/proof/determinism /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/proof/determinism/exact_native_replay.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B spec/art_identity/maquettes/blender/bridge_client.py --timeout 900 spec/art_identity/maquettes/arc_thrall/r2/tube_proof.py -- /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/spec_native.json /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/proof/native/maquette.blend /Users/borgerding/workspace/Labyrinth.worktrees/mq-07/spec/art_identity/maquettes/arc_thrall/r2/proof/tube_geometry.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B -m spec.art_identity.maquettes.arc_thrall.r2.assemble
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B -m spec.art_identity.maquettes.arc_thrall.r2.proof --capture spec/art_identity/maquettes/arc_thrall/r2/proof/capture
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B -m spec.art_identity.maquettes.arc_thrall.r2.curate
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B -m unittest tests.test_arc_thrall_maquette_r2 tests.test_rr07_delivery.DeliveryTests.test_both_committed_deliveries_have_every_label_and_joint -v
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B -m unittest tests.test_maquette_rear_turn -v
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B -m unittest spec.art_identity.maquettes.blender.test_source_recipe spec.art_identity.maquettes.blender.test_delivery spec.art_identity.maquettes.blender.test_delivery_validation -v
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B tests/test_art_identity_gate.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B -m unittest discover -s tests -p 'test_*.py' -v
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-07 && python3 -B -m spec.art_identity.maquettes.blender.curate_delivery verify spec/art_identity/maquettes/arc_thrall
```

After passing native proof, curation promotes both complete views into
`../delivery/`, preserving clay RGBA and all mask alpha/visible RGBA through the
shared lossless packer. It retains the native cells and 3× elbow crops in
`proof/shoulder_tube_sheet.png`, the original clays in `proof/baseline/`, compact
native delivery reports, `tube_geometry.json`, `gates.json`, `height_table.json`
and test/bridge logs. Every discarded blend, cache and duplicate capture is
hash-inventoried before deletion. `baseline_measurements.json` and
`baseline_fit.json` preserve the immutable mq-04 comparison and registrations.

## Feedback-2 planting and promotion

The actual far hip/knee/ankle bones are re-posed before the native cloth solve,
using mq-06's front-ray height correction. The hip and every front joint pixel
stay fixed; ankle height becomes the near ankle's 0.2485619374 m floor plane
(previously 0.3189265015 m, a 0.0703645641 m lift). The loincloth uses its existing
native collision settings; it is not converted into a floor-length robe.
The Thrall entry in mq-06's shared floor-guard exceptions is cleared explicitly.

The earlier fixed-length planting attempt was rejected: its front IoU was
0.6790656031, below 0.70. The supplied mq-06 planting method preserves the
front projection and changes the real far-leg segment lengths as follows.
This supersedes the initial brief's unchanged-leg requirement for feedback 2;
the accepted shoulder and all other limb lengths remain unchanged.

| Far-leg bone | Before m | Planted m |
|---|---:|---:|
| hip_far | 0.3287382662 | 0.3887234969 |
| knee_far | 0.3393611876 | 0.4034519023 |
| ankle_far | 0.2624302363 | 0.2624302363 |

Shared builder edits for this feedback are small and opt-in: `planted_leg.py`
uses the merged floor helpers; `compile_recipe.py` retains the fitted joints;
`build.py` invokes the existing real-bone reposer and records floor/endpoint
checks; `rear_body.pose_leg` accepts an explicit config; `delivery_validation.py`
requires the floor gate for a planted recipe and rejects failed nested checks.
`view_delivery.py` applies the recorded pan when readers request a view of a
single planted body. Other recipes take unchanged paths.

No new visual tuning is chosen. The only new fixture value is `TEST_DEFAULTS.scale_mutation_multiplier = 2`,
used to prove that a changed camera scale is rejected. No new visual defaults
are introduced. The existing mq-06 native bone
endpoint tolerance is 1e-4 m (`REAR_POSE_DEFAULTS`). All previous proof
settings remain as documented. Native framing uses the owner's 8 px margin.

The exact commands above regenerate proof. Before a fresh run, compile the
canonical input (the r2 input is byte-identical), then run build, both captures,
recipe proof, exact replay, tube entry, assembly, numerical proof and curation.
The old clay files and baseline registration are retained, so the sheet can be
recreated after curation. No local windowed commands or inspection-fixture
commands apply; the director bridge supplies native Blender rendering.

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

## Feedback-2 native gate results

| Contact / joint | Before m | After m |
|---|---:|---:|
| hip_far | 0.8818430140 | 0.8818430140 |
| knee_far | 0.6003847577 | 0.5652024757 |
| ankle_far | 0.3189265015 | 0.2485619374 |
| ankle_near | 0.2485619374 | 0.2485619374 |
| foot_tip_far | 0.1673720558 | 0.0970074918 |

The ankle floor is 0.2485619374 m; no offender or exception remains.

| Painting registration | Before | Planted r2 | Minimum |
|---|---:|---:|---:|
| front / dynamic_iou | 0.7222672242 | 0.7081009476 | 0.7 |
| front / fixed_original_iou | 0.7222672242 | 0.7081009476 | 0.7 |
| rear / dynamic_iou | 0.7035146695 | 0.7047716117 | 0.65 |
| rear / fixed_original_iou | 0.7035146695 | 0.6921367394 | 0.65 |

Rear camera pan: (0, −20.9999880572) native px; unchanged direction and
2.4 m scale. Native clay margins (left/top/right/bottom): 154 / 146 / 149 / 8 px.
Every required solo is nonempty, every part has genuine visible owner pixels,
and neither loincloth panel has a sample below its collision margin or an
intersecting face pair. Raised front shoulders: far (338, 310.3), near (616, 352).
The complete before/after front/rear shoulder table is in `proof/gates.json`.

Native receipts: `BLENDER_MAQUETTE: PASS`; both `FITTED_VIEW_CAPTURE: PASS`;
`FITTED_RECIPE_PROOF: PASS; raw_hashes_identical=true; max_joint_error=4.140378204781795e-06`;
`EXACT_NATIVE_REPLAY: PASS; unrounded_float32=true; mesh_count=17`;
`MQ07_TUBE_ENTRY: PASS`; `MQ07_POSE: PASS`; `MQ07_FLOOR: PASS; exceptions=[]`;
`MQ07_TUBE: PASS`; `MQ07_DELIVERY: PASS; native_capture=true`.

Art identity verification: `Ran 111 tests in 35.991s`, `OK`. Fresh focused and
full-suite results follow below.
The existing delivery assertions detected the nested per-view geometry-check
gap; the validator now rejects those failures before sealing. No assertions
were weakened. The full-suite result and final byte budget follow below.

The first full run reported `Ran 891 tests in 832.937s`,
`FAILED (errors=1, skipped=63)`: rr-07 did not apply the single-body rear framing
pan when checking native joints. The shared reader now applies that measured
pan and rejects changed scale/direction metadata. The live-input test's exact
Thrall file count changes from 39 to 35 because the approved removal of
`hand_near` and `club` removes four solo PNGs across the two views. All provenance,
joint and missing-input assertions remain. The failed run's hash is archived
before replacing its log with the fresh complete run.

## Final feedback-2 verification

- mq-07 and live rr-07 input integration: `Ran 17 tests in 0.434s`, `OK`.
- Builder/source/delivery: `Ran 43 tests in 3.351s`, `OK`.
- Turn regression: `Ran 13 tests in 10.278s`, `OK`.
- Art identity: `Ran 111 tests in 35.991s`, `OK`.
- Full Python: `Ran 892 tests in 838.554s`, `OK (skipped=63)`, exit 0.
- Rechecking the packed delivery: `MQ07_POSE: PASS`;
  `MQ07_FLOOR: PASS; exceptions=[]`; `MQ07_TUBE: PASS`;
  `MQ07_DELIVERY: PASS; native_capture=true`. The regenerated sheet is
  byte-identical to the inspected native-cell sheet.

The final curation check verifies the complete manifest, current cold-proof
binding, unchanged native clay RGBA and the 6,000,000-byte limit.
No TODO_DESIGN remains. Non-gating maximum-band and rear source-landmark
diagnostics remain visible in the fit reports for the director's repaint.
No .gd or runtime changes; no separate Godot suite, local windowed capture or
inspection fixture is applicable. All changes remain uncommitted.

## Feedback 3 — proof validation only

The accepted delivery geometry and every PNG are unchanged. The supplied review
path `spec/peer_benchmark/feedback/mq-07_review_70ac9e5ef.md` was absent in this
worktree; the three findings in the owner's feedback are implemented directly.

1. `gate_receipt.py` binds acceptance to the current compiled spec, measured
   recipe, verified capture manifest (all PNG/joint hashes), native report and
   replay hashes, native tube receipt and accepted sheet. `curate.py` requires
   this receipt before its first deletion. It checks every required pose, tube
   geometry/entry/width, floor, fit, framing and per-part coverage gate, including
   required nonempty collections and numerical limits. Packing is re-bound only
   after source acceptance and the shared packer's pixel-preservation checks.
2. `blender/socket_proof.py` requires the exact socket IDs and complete native
   boundary, insertion, bore and ownership details. `delivery_validation.py`
   requires those details and `native_socket_tucks` in both build and capture
   checks before sealing. Build and single-view capture collect native object
   receipts independently. No vertex, pose, geometry setting or renderer value
   changes. Socket contracts also reject duplicate IDs and invalid axes/bores.
3. `tests/test_arc_thrall_proof_validation.py` checks stale hashes, missing
   receipts, false gates, empty collections and failing limits against complete
   copied captures. Every rejection preserves every fixture file byte and never
   calls staging/deletion. `test_delivery_validation.py` rejects omitted socket
   flags/details before resealing and after a forged fresh hash seal.
   `tests/test_maquette_builder_wiring.py` mocks the real build dispatcher,
   checking procedural dispatch and fit → repose → split → socket-tuck order.
   Invalid socket and lifted-foot-exception fixtures exercise the real contract.
   In-memory AST mutations reproduce deletion of the procedural branch, repose
   call, socket-tuck call, socket contract and foot-exception guard: all five
   removals fail their regression through assertions, with no engine invocation.

Proof-only defaults are named in `DISPATCH_FIXTURE`: root/elbow fixture joints
(0,0,0)/(1,0,0), source elbow (0,1,0), triangle [(0,0,0),(1,0,0),(0,1,0)],
label RGB (0.1,0.2,0.3), gravity (0,0,−9.81), fps 24, forward (1,0,0), and
bundle bytes `approved anatomy fixture`. `PROOF_FIXTURE` uses 64 zeroes as a
stale SHA and bytes `retained native evidence fixture`. These are test fixtures;
no new player-facing values are selected. Margin 8 and diameter 68 native px
are the owner's existing requirements, not new defaults.

Read-only proof and verification commands (no local windowed commands apply):

```sh
python3 -B -m spec.art_identity.maquettes.arc_thrall.r2.proof --capture spec/art_identity/maquettes/arc_thrall/delivery --keep-images
python3 -B -m spec.art_identity.maquettes.arc_thrall.r2.gate_receipt
python3 -B -m unittest tests.test_arc_thrall_maquette_r2 tests.test_arc_thrall_proof_validation tests.test_maquette_builder_wiring tests.test_rr07_delivery.DeliveryTests.test_both_committed_deliveries_have_every_label_and_joint tests.test_maquette_rear_turn spec.art_identity.maquettes.blender.test_source_recipe spec.art_identity.maquettes.blender.test_delivery spec.art_identity.maquettes.blender.test_delivery_validation -v
python3 -B tests/test_art_identity_gate.py
python3 -B -m unittest discover -s tests -p 'test_*.py' -v
python3 -B -m spec.art_identity.maquettes.blender.curate_delivery verify spec/art_identity/maquettes/arc_thrall
```

`proof/feedback3_geometry_lock.json` records the accepted PNG, measurement,
joint and native-build hashes before these validation edits. Focused results
and the full-suite result are recorded below when observed.

### Observed feedback-3 results

- Focused: `Ran 92 tests in 26.083s`, `OK`.
- Art identity: `Ran 111 tests in 45.128s`, `OK`.
- Full Python: `Ran 909 tests in 760.985s`, `OK (skipped=63)`, exit 0.
- `MQ07_REVIEW_MUTATION_REJECTED`: procedural_chain, repose, append_tucks,
  socket_contract, foot_exception — all five assertion-based regressions fire.
- `MQ07_EVIDENCE: PASS; spec/capture/tube hashes and every mandatory gate current`.
- The accepted-file hash lock and unchanged `delivery/` diff verify that every
  delivered image, measurement, joint table and native geometry report is unchanged.

Files for feedback 3: r2 `gate_receipt.py`, `curate.py`, `proof.py`, this README,
the gates/hash-lock/test receipts and complete commit/discard inventories; shared
Blender `socket_proof.py`, `build.py`, `capture_view.py`, `contract.py`,
`delivery_validation.py`, `test_delivery_validation.py`; new root tests
`test_arc_thrall_proof_validation.py` and `test_maquette_builder_wiring.py`.
There are no new design TODOs. No separate native capture or engine run is
needed for validation-only changes; all work remains uncommitted.
