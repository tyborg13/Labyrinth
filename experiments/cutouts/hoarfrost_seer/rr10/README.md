# rr-10 front handoff

**Current handoff:** [director feedback 3](feedback3.md), with current result
lines in [feedback verification](proof/feedback3_verification.md). The exact
protected rope mask from [feedback 2](feedback2.md) remains unchanged. The new
boundary and outline criteria reduce the existing native flags to 217 hole
frames and one detached-component frame; they do not yet permit native
acceptance or contact sheet composition. The original covered-tuck and
rest-hole rules were superseded by [feedback 1](feedback1.md).

This is the front-only humanoid v2 candidate. The approved mq6 rear painting and
rebuilt rear delivery are absent. `inputs.json` owns the rear job and delivery
paths. The existing production Seer remains registered until both views can be
promoted together; the rejected mirrored rear is never loaded by this case.
No commit, peer review, fixture publication, queue mutation or Git publication
was performed by the implementation worker.

## Contract and acceptance

Risk: **high**, because the opt-in sampler/presentation shares runtime entrypoints.

1. **Cut (partial):** the front source is a lossless ownership partition (0 pixel mismatch).
   Collar and torso share the torso piece/bone; shaft and crystal share the staff.
   Pelvis is at the supplied belt joint, hems at the robe alpha's lower bounding
   corners on its floor line, feet parented to hems. Three real `joint_meshes`
   replace the two sleeves and one robe through the existing protagonist loader.
   The original hanging-rope split is now resolved by the exact protected
   director mask; see `feedback2.md` for ownership and cloth-under-tail proof.
2. **Weights:** source-space 2 px grid; top four robe rows entirely pelvis,
   linear vertical hem blend and middle-third smoothstep near/far split. Sleeve
   weights project onto the arm segments and blend over elbow ±4 px. See
   `tools/humanoid_cutout/mesh.py`. Native key-pose fold/tear inspection is pending.
3. **Tucks/fills:** required 3 px source masks, 0 missing tuck texels; verified
   rr-05 fill seeds are clipped to their maquette solos and rest occlusion. The
   remaining tuck texels use rr-05 non-outline same-material edge replication.
   Original visible pixels and approved fill texels stay unchanged. Packed GPU
   check textures distinguish silhouette, tuck and derived outline material.
   All-frame coverage, holes and dark slabs still require windowed proof.
4. **Runtime:** `rig: humanoid_v2` selects source-pixel channels, inward offsets,
   two-bone hand targets retaining the rest bend side, FK unkeyed arms,
   world-relative staff angle/release floor pivot, and world-step hem anchors.
   Idle uses 10 fps holds, three rigid groups, whole pixels and no rotations or
   scale. Actions drive meshes from the same snapped bone transforms as sprites.
   The simultaneous 4° torso limit and 1.5° step require 4° to present at the
   nearest in-limit step, 3°, rather than 4.5°. Authored keys remain untouched.
5. **Production:** promotion to board/pre-battle/portrait registration is
   deliberately deferred at the required rear-input stop. The staged asset
   configuration is under `assets/units/hoarfrost_seer_cutout/humanoid_v2/`;
   it references the case paint until promotion/density adoption. A proof-only adapter injects
   the front candidate into real RunScene callbacks and asserts its identity on
   every captured frame. The existing portrait atlas API and actor phase-seed
   API are exercised headlessly. Production selectors, action durations,
   contacts, SFX/VFX callbacks, gameplay, analytics and saves remain unchanged.
6. **Gates:** source identity, actual tuck texels, crystal integrity, structure,
   authored keys/midpoints, presented bone limits and rigidity are headless
   gates. Native isolated group/piece/check textures establish the pixel gates;
   skinned meshes never enter the CPU raster oracle. Mutations cover idle 1°,
   split robe, 2 px and physically removed tuck, 40° staff, ward hem, signed
   motion, crystal repaint, stray piece pixels, exposed tuck, dark slab, hole,
   idle pixel mismatch and rigid native disagreement. Rear checks are pending.
   Existing source openings are transported through GPU-only reference masks,
   including skinned masks, and matched one-to-one to current openings. Native
   verification streams one frame's layers at a time and compares their exact
   composition with the captured main frame.

## Minimal existing runtime hooks

- `scripts/maquette_cutout_runtime/motion.gd`: dispatch the explicit v2 rig tag.
- `scripts/maquette_cutout_runtime/rig.gd`: dispatch v2 bone/sprite presentation.
- `scripts/maquette_cutout_runtime/renderer.gd`: overridable rig factory and
  view inventory; the default path builds the same front/rear legacy rigs.

No Lancer, Herald, Gloam, Thrall, Bloomer, Wisp or Shrike art/data was edited.

## Reproduce headless proof

From `/Users/borgerding/workspace/Labyrinth.worktrees/rr-10`:

```sh
python3 -B experiments/cutouts/hoarfrost_seer/rr10_build.py
python3 tools/godot_task_runner.py --task-id rr-10 --stream -- godot --headless --path . --script tests/rr10/samples.gd
python3 -B experiments/cutouts/hoarfrost_seer/rr10_gates.py
python3 -m unittest discover -s tests -p 'test_rr10_humanoid.py' -v
python3 tools/godot_task_runner.py --task-id rr-10 --stream -- godot --headless --path . --script tests/rr10/runtime_checks.gd
python3 tools/godot_task_runner.py --task-id rr-10 --stream -- godot --headless --path . --script tests/rr10/native_capture.gd -- --output /private/tmp/rr10-validate --validate-only
python3 tools/godot_task_runner.py --task-id rr-10 --stream -- godot --headless --path . --script tests/rr10/production_capture.gd -- --type hoarfrost_seer --output /private/tmp/rr10-production-v2 --logic-only
python3 tools/godot_task_runner.py --task-id rr-10 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

## Proof for the design owner

No windowed commands were attempted by the worker. These commands are at
1920×1080 / 100% UI scale and call the mandatory visual runner:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-10 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-10 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-10 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-10 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-10 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh sheets
```

After the rear is supplied and built, recapture native proof for both views,
then run the rr-04 reel command (front left/rear right, 2× nearest, #1E1E24,
clip title; idle/move ×3, other actions ×2, death once +1 s):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-10 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh review
```

The exact underlying commands/contracts are in `../rr10_proof.sh`. Outputs:

- `proof/native_rest/{front_rest.png,rest_pair.png,frames.json}`
- `proof/native/`: every native frame, pair, isolated piece and packed check
  texture; `proof/native_gates.json`; failure crops in `proof/native_failures/`
- `proof/production_native/{frames.json,frame_*.png}` (candidate-only progression)
- `proof/seer_protagonist_idle.mp4` (five loops at measured production board scale)
- `proof/contact_sheets/<view>_<clip>_3x.png` (every frame, nearest)
- `proof/hoarfrost_seer_review.mp4` (two-view only, deferred)

The owner prepares the inspection fixture after both-view production promotion;
this front-only candidate has no published playable fixture.

## TODO_DESIGN and remaining work

`TODO_DESIGN_mq6_rear_delivery_and_paint` remains in `inputs.json` and `cutout.json`.
The front rope ownership mask is supplied and wired. Supply the approved rear
inputs and its rope mask, resume the worker,
then build/prove the rear and complete production promotion/density/native rests.
Native renderer identity, clean pieces/tuck coverage/dark slabs/holes, mesh
tears/folds and visual review remain unobserved in this sandbox.

The worker discovered the task metadata contract was empty. `parallel_task.py
contract ...` failed with `PermissionError: [Errno 1] Operation not permitted` on
`/Users/borgerding/workspace/Labyrinth/.git/worktrees/rr-10/labyrinth-parallel-task.json`.
`parallel_task.py preflight` then reported `Task acceptance contract is incomplete`.
The acceptance/proof contract above records the intended scope; the owner must
repair the existing metadata and preflight before their commit/review steps.

## Chosen defaults

These affect test fixtures/proof or numerical robustness only:

- Headless samples: `PROOF_STEP_PX = 96`, `PROOF_SCALE = 2`; runtime checks use
  phase 0.3, seed 0.37 and test screen scales 0.5, 1, 2.
- Comparison board fixture: `PROOF_RUN_SEED = 91210`, 8 settle frames. Actor
  scales are read from the real production board, never chosen for the reel.
- Proof layout: title y=60, height=60, vertical offset=40; six representative
  paths emitted for runner validation. Source/native canvas geometry, colours,
  display zoom, loop counts and durations come from the brief/existing rr-04.
- Sheets: 8 columns, 18 px labels, 3 px crop margin; failure crops 3× nearest.
- Belt ownership diagnostic: source crop `(115,125,170,180)`, 6× nearest;
  recipe in `proof/design/rope_belt_ownership.json`.
- Encoder: 2 threads, CRF 16, medium preset (the existing rr-04 encoding settings).
- Process timeouts: 180 s focused subprocesses, 900 s full Godot/production proof,
  3600 s native isolated-layer proof, 120 s rest, 300 s idle comparison.
- Float comparison tolerance 0.0001; IK degeneracy epsilon 0.000001.

## Observed result lines

See `proof/verification.md` for final observed commands/results. Native output
paths above are planned proof destinations, not completed captures.
