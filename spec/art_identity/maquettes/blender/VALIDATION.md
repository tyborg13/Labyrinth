# mq-03 — latest review fixes

Round-5 acceptance, commands and observed results are in [ROUND5_VALIDATION.md](ROUND5_VALIDATION.md).
Round-4 history is in [REVIEW_FIXES.md](REVIEW_FIXES.md).
The round-3 handoff below records the approved geometry baseline and its original proof.

# mq-03 — round 3 implementation handoff (2026-10-17)

All changes remain uncommitted on `codex/mq-03`. No commit, branch change, peer
review, queue mutation, publication or cleanup command was run. This is offline
Python/Blender authoring; game code, saves, input, analytics, balance and icon
registries are unchanged. The owner-provided prompt, r2 spec, reference image,
label colours, camera, source annotations and fit gate are protected and unchanged.

## Director's round-3 requirements

1. **Board facing:** the approved bundle's native -Y forward is normalized to
   +X by the v2 builder's asset/rest registration. The posed spine has an explicit
   anatomical anterior basis. Head/neck garments, visor and front chest plates/
   gems turn in that frame. World-space pose joints, limb-plate placements, spear path and cloak pattern
   retain their authored coordinates. Chest-front pieces use vertical anatomical
   registration, with the diamond below the retained collar. This is a
   builder correction, shared by all v2 specs; v1 builders remain unchanged.
   The actual posed torso heading must project down-left in front and up-right
   in rear at the board convention. Native torso mattes measure left/right area
   and reflected silhouette difference. A rendered frontal rotation control
   must fail the facing-axis check. Chest attachment frames are checked too.
2. **Single tabard:** one connected native cloth pattern hangs from the belt,
   hip-wide at the top, flaring from 0.30 to 0.40 world units. Three cuts start
   at mid-thigh, forming four ragged strips with above-knee hems. The top row follows the measured belt arc; all its
   vertices are pinned; cut-away loose points are removed with pin remapping
   before physics. Four fold-ease waves and the 24-frame native simulation
   provide folds. Body collision stays enabled; self-collision is disabled for
   this open front panel. Both short two-lame tassets remain over the hips.
3. **Refit and proof:** actual Cycles CPU silhouettes drive the unchanged source
   gate. The body asset, base input matrix, all joints, every bone scale/length,
   camera and fit annotations match the round-2 r3 proposal. The fit tool does
   not edit accessory design. Front/rear labels and clay, solos, torso controls,
   six-type gallery, overlay and numerical reports are delivered through the
   approved external bridge. See observed results below.

## Original unit acceptance

V2 retains appended approved anatomy, automatic heat weights, spec-named bones,
joint-driven lengths and transverse scales, weighted body ownership, plates,
lames, five cloth kinds, native curves, faceted crystals and bipyramid gems.
`realistic_body_male` resolves to the bundle's `GEO-body_male_realistic`; its
10,582-vertex subdivision-0 surface binds successfully. No substitute asset,
art, font, audio, dependency or protected-data change was needed.

All plate/lame Shrinkwrap offsets including lifts remain ≤0.015. Native tests
cover fresh-build determinism, cache replay, labels, cloth/body clearance and
triangle overlap, collar symmetry, sharp corners, contact, posed joints and
crystal continuation. Negative fixtures catch crossing cloth, front wings,
eroded corners, floating armour and frontal facing. Production has a separate
fresh-cache build. The proof contract requires 72 native RGBA 1024² images.

`cloth_contacts.py` isolates collision preparation/constraints. Regional native
convex contact surfaces avoid alternating front/back contacts; final gates still
check the complete original posed anatomy. Shoulder/hip lames conform over the
underlying cloth. The chest gem seats by one rigid translation above sampled
plate/cloth contacts, preserving its bipyramid and avoiding ridge penetration.

## Observed verification

- Full native production: `BLENDER_MAQUETTE: PASS` (bridge exit 0, 234.7s).
- Independent fresh build: `BLENDER_MAQUETTE: PASS` (exit 0, 3.3s); every mesh hash matches.
- Native integration: `BLENDER_NATIVE_INTEGRATION: PASS` (exit 0, 22.3s).
- Facing: `BLENDER_FACING: PASS`; horizontal forward projects to
  `[-0.698594, 0.349314]`, board-axis cosine 0.999999999818. Torso reflected
  silhouette difference is 0.390131 versus 0.374318 for the frontal control;
  the frontal control fails the axis gate. Both chest attachment axes pass.
- Measure and fit: `MAQUETTE_FIT: PASS; IoU=0.812207; median band error=0.036732; max band error=0.124394; conflicting bands=[]`.
- Proof: `MQ03_PROOF: PASS; captures=72; projection_error_max_px=0.005899; fresh_builds_identical=true`.
- Inspection: `BUILD_INSPECTION: PASS` (exit 0, 0.8s); maximum joint endpoint
  error 6.37354494e-06, far-hand/shaft surface distance -0.0220670, crystal tip
  error 0.0 and head fraction 0.219999994 (five sides, six jags).
- Every cloth/body overlap count is zero. Minimum clearances: hood 0.031775,
  collar 0.009649, tabard 0.048705, cloak 0.034356; required margin is 0.003.
- `ROUND2_BODY_CAMERA_GATE_PRESERVED: PASS` and
  `FIT_PRESERVED_JOINTS_BONE_SCALES_PIECES: PASS`.
- Focused Python: `Ran 19 tests in 0.240s` / `OK (skipped=1)`.
- Full Python: `Ran 585 tests in 370.258s` / `OK (skipped=62)`.
- Art identity: `Ran 111 tests in 34.283s` / `OK`.
- `PYTHON_SYNTAX: PASS (28 files)`.
- `git diff --check`: exit 0, no output.

All six successful native bridge receipts and exact commands are embedded in
`proof_manifest.json`. Logs are `lancer_r3.log`, `fresh_build.log`,
`integration_final.log`, `measure.log`, `fit.log`, `native_geometry.log`,
`proof.log`, `proportions.log`, `python_focused.log`, `python_full.log`,
`art_identity.log` and `syntax.log` in the proof root. Front/rear parts/clay,
overlay, and both gallery sheets were inspected.

## Proof for the design owner

Proof root: `/private/tmp/labyrinth_codex/mq-03/round3/delivery`.
The manifest binds the exact spec/source hashes, capture hashes, bridge receipts,
fresh geometry hashes, facing controls, joint/grip/spear checks and fit metrics.
The gallery sheets paste the six native type captures in a 3×2 proof layout:
plate/lames/cloth, then curve/crystal/gem. No new artwork or fonts are introduced.

Run from `/Users/borgerding/workspace/Labyrinth.worktrees/mq-03`:

```bash
python3 -B -m spec.art_identity.maquettes.blender.round3_lancer
python3 -B spec/art_identity/maquettes/blender/bridge_client.py spec/art_identity/maquettes/blender/build.py -- /Users/borgerding/workspace/Labyrinth.worktrees/mq-03/spec/art_identity/maquettes/frostglass_lancer/spec_r3.json /private/tmp/labyrinth_codex/mq-03/round3/delivery/lancer_r3 --gallery
python3 -B tools/maquette_fit.py measure --spec spec/art_identity/maquettes/frostglass_lancer/spec_r3.json --source spec/art_identity/jobs/frostglass_lancer/mq1_front_v3/refs/03_identity_lancer_current.png --renders /private/tmp/labyrinth_codex/mq-03/round3/delivery/lancer_r3 --out /private/tmp/labyrinth_codex/mq-03/round3/delivery/measure --require-gate
python3 -B tools/maquette_fit.py fit --spec spec/art_identity/maquettes/frostglass_lancer/spec_r3.json --source spec/art_identity/jobs/frostglass_lancer/mq1_front_v3/refs/03_identity_lancer_current.png --out /private/tmp/labyrinth_codex/mq-03/round3/delivery/fit
python3 -B spec/art_identity/maquettes/blender/bridge_client.py spec/art_identity/maquettes/blender/integration.py -- /private/tmp/labyrinth_codex/mq-03/round3/delivery/integration_final
python3 -B spec/art_identity/maquettes/blender/bridge_client.py spec/art_identity/maquettes/blender/build.py -- /Users/borgerding/workspace/Labyrinth.worktrees/mq-03/spec/art_identity/maquettes/frostglass_lancer/spec_r3.json /private/tmp/labyrinth_codex/mq-03/round3/delivery/fresh_build --build-only
python3 -B spec/art_identity/maquettes/blender/bridge_client.py spec/art_identity/maquettes/blender/inspect_build.py -- /private/tmp/labyrinth_codex/mq-03/round3/delivery/lancer_r3/maquette.blend /private/tmp/labyrinth_codex/mq-03/round3/delivery/native_geometry.json /Users/borgerding/workspace/Labyrinth.worktrees/mq-03/spec/art_identity/maquettes/frostglass_lancer/spec_r3.json
python3 -B -m unittest tests.test_maquette_blender -v
python3 -B -m unittest discover -s tests -p 'test_*.py' -v
```

There is no game scene/UI in this unit. Godot probes, windowed 1920×1080 captures
and `tools/inspection_fixture.py` are not applicable; native maquette captures
retain the brief's 1024² camera. Direct sandbox Blender remains unavailable
because of the previously observed Metal SIGSEGV; it was not retried. All native
work uses the director's serial bridge with factory startup and autoexec disabled.

## Files changed

- `blender/`: native builder/rig, conformance, cloth/contact helpers, pieces,
  render/bridge/fitting adapter, validation, native integration, director/proof
  helpers, inspection, source recipes and facing probes.
- `frostglass_lancer/spec_r3.json`: reviewable numeric proposals.
- `maquettes/fitting.py`, `tools/maquette_fit.py`: actual v2 native-render fit path.
- `tests/test_maquette_blender.py`: portable contracts and opt-in bridge suite.
- `maquettes/FITTING.md`, `blender/VALIDATION.md`: data contract and proof handoff.

## TODO_DESIGN placeholders

None in r3. Every visible proposal remains marked `proposed: true`.

## Chosen defaults

New technical settings are `FACING_DEFAULTS`: native asset forward -Y, board
forward +X, axis cosine ≥0.995, torso reflection difference ≥0.01, epsilon 1e-9;
and cloth cache revision 7. These are registration/proof settings, not creature
tuning. Existing named bridge, collision, rendering, binding, projection, hash,
inspection, gallery and synthetic-test settings are documented in `FITTING.md`.
No additional appearance defaults were chosen.

## Open issues

No remaining functional blocker. Native direct launch remains sandbox-blocked;
the approved bridge supplied all required proof. Appearance values remain
explicit proposals for the design owner.
The two tracked geometry/raster `.pyc` modifications predate this round and are
preserved. The owner-provided `prompt_front_r3.md` is read-only and untouched.
