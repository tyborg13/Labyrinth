# Chainbound gaoler mq3 — phase-one maquette cutout

This is a diagnostic authoring case, with unchanged approved paint and the
existing gaoler's idle, walk, strike, hit and death sampler. No production
asset, game script, save or analytics code is changed. Changes are uncommitted;
review, inspection and publication belong to the design owner.

## Requirement status

| Brief | Implementation and evidence | Remaining limitation |
| --- | --- | --- |
| 1. Registration | Raw digests checked; exact `process_raw` crop/trim/fit recovered; projected joints checked against the protected camera; maps and available solos registered; exact Euclidean ownership with depth ties; per-part flags in `build_report.json` | New Blender renders unavailable in this sandbox. Cached front labels match the approved kit digest; rear matches its supplied reference. See `source/cache_provenance.json`. |
| 2. Case | Created through `init`; 21 logical labels and registered bones; mapping in `recipes/rig.json` and `build_report.json`; rigid parts use `segment`, cloth uses `skin`; camera-depth layers | Rear fore_near/hand_near have no visible pixels and no solo render, so their joints exist but their paint nodes remain explicitly unmaterialized. `TODO_DESIGN_cloth_weights` remains. |
| 3. Rest | Both source-space assemblies equal approved paint byte-for-byte, RGB and alpha, with hidden supports included; `proof/rest_identity.json` | Native renderer identity is a separate pending probe. |
| 4. Requests | 42 native/4× request pairs; 12 measured regions, magenta underlays, bounds, sampled clip exposure and descending exposure order in `hidden_requests/index.json`; contact sheet | 30 unavailable solos have null counts and UNKNOWN captions. Solo pixels outside all paint are recorded as registration disagreement, not claimed occlusion. |
| 5. Motion | Production sampler copied unchanged; adapter binds the new registered skeleton; 318 headless poses checked for finite transforms, rigid terminal bones and planted feet | Windowed reel, editable-scene roundtrip and eight-frame native sheets await the design owner. Magenta is intentional. |
| 6. Tool | `tools/maquette_cutout.py`; complete synthetic fixture covers registration, nearest snapping/ties, depth, hidden coverage, exact rest, repeatability and source preservation; arbitrary anatomies use explicit rig recipes | Blender and native proof need a renderer-capable machine. |

The cached directory is called `r4`, but it is the approved r3 geometry framed
at `ortho_scale=2.33`. All projected joint coordinates agree with the protected
spec. Only six solo renders per view were originally requested. Blender 5.2.1
crashed before Python execution in Metal capability detection (exit 139); its
only installed GPU backend is Metal. No windowed command was attempted here.

## Retained artifacts

- `source/`: approved raw and processed paint, processing/kit records, protected
  spec copy, cached maquette renders/joints, display palette provenance and
  unchanged production rig/motion inputs.
- `registered/`: common 255px maps, available solos, affine traces, projected
  joints and categorical ownership arrays.
- `segmented/`, `hidden/`, `layouts/`, `recipes/`: exact visible pixel partition,
  magenta supporting paint, rig topology, meshes and repeatable recipes.
- `proof/front_rest_3x.png`, `proof/rear_rest_3x.png`,
  `proof/front_ownership_3x.png`, `proof/rear_ownership_3x.png`: native-size
  registration shown at 3× nearest. `hidden_requests/contact_sheet.png` keeps
  every request at the same native scale and labels unavailable solos.
- `proof/motion_samples.json`: actual Skeleton2D matrices, not captured images.
  `hidden_requests/index.json` uses nearest CPU mask visibility to prioritize
  work and names the exposing clips. It does not claim native rendering proof.

Seven front parts exceed 15% reassignment: thigh_near 19.1%, shin_near 21.7%,
thigh_far 33.5%, shin_far 31.9%, foot_far 20.5%, chain 56.5%, hook 69.4%.
Five rear parts do: coat_near 16.8%, foot_near 47.7%, foot_far 61.7%, chain
63.7%, hook 74.0%. No manual ownership cleanup or anatomical repaint was made.

## Observed checks

- `proof/maquette_tests.log`: `Ran 12 tests in 1.828s`, `OK` (final focused run).
- `proof/python_suite.log`: `Ran 408 tests in 288.771s`, `OK (skipped=61)`.
  This discovery run preceded the added full synthetic rebuild test, which is
  included in the final 12-test focused run. Every skip and reason is in the log.
- `proof/godot_suite.log`: `FULL SUITE RUNTIME: 756.265 seconds (budget 900 seconds)`,
  `TEST RESULT: PASS`. Its program sub-suites also passed.
- `proof/art_identity_tests.log`: `Ran 49 tests in 12.239s`, `OK`.
- `proof/validation.json`: `"ok": true`, `"errors": []`, including `--protect all`.
- `proof/rest_identity.json`: `pixel_identical: true`, `different_pixels: 0`
  for both front and rear, including hidden support layers.
- `proof/motion_samples.log`: `MAQUETTE_MOTION_SAMPLES: PASS (318 poses)`.
- `proof/exposure.log`: `MAQUETTE_EXPOSURE: PASS (42 requests; 30 unknown solos)`.
- `proof/repeatability.json`: 168 derived files identical after a fresh CLI
  rebuild; automatic runner-backed sampling/exposure passed. The temporary
  rebuilt case was removed after comparison; its logs remain in `proof/rebuild_*`.
- The native rest probe passed `--headless --check-only` through the Godot
  runner. This is parser proof only. Python syntax compilation passed without
  writing bytecode caches (the environment's default cache path is not writable).

## TODO_DESIGN placeholders

`TODO_DESIGN_cloth_weights` in `recipes/rig.json` and `cutout.json`: the existing
production coat panels and tabard are rigid. Its `drape_a..d` are restraint-chain
bones, not cloth. Supply the requested pelvis/thigh skin weight fields. Current
skin scaffolds use the original single controlling bone, preserving its motion.
The numerical exposure helper deliberately rejects nonconstant skin weights;
after adding real deformation, obtain exposure from native renders.

Missing solo images are a renderer/input blocker, not a guessed design field.
The single maquette chain follows the existing chain_a swing in these five
clips. Chain Reel/Manacle Pin are not added to this unit's requested proof;
the former additionally needs a three-segment chain topology decision.

## Chosen defaults

These affect tooling or proof only; no gameplay number or motion timing was chosen.

- `PROOF_DEFAULTS` in the tool: five sheet columns, 28px caption rows, alpha
  threshold 128, joint rounding tolerance 0.02px; source/action sizes and 3×/4×
  scales come from the brief/workflow. Eight keyframes per clip come from the brief.
- `recipes/rig.json.proof_defaults`: mesh grid `[2,1]`; sampled frame counts
  idle 24, walk 48, strike 31, hit 24, death 32; one proof cycle per clip.
- The native diagnostic places its 3× rest at `(80,160)` and ownership at
  `(1000,160)` on 1920×1080. It uses the existing default font only for generated
  contact-sheet captions. No new art, font or audio was generated or downloaded.
- Headless checks reuse the cutout pipeline tolerances: rigid basis 0.001,
  foot target 0.2px and planted-foot drift 0.02px. The task runner uses its default
  timeout; the full suite uses the documented 900 seconds.

Playback remains production-derived: idle 1.6s, walk 0.64s, strike 6×0.04s,
hit 0.36s; death 28×0.037s with settlement at 62% of its existing dissolve clock.
The unpainted compatibility drape joints retain production values. The two
unpainted chain compatibility joints coincide with chain_a because none of the
five requested clips rotates them; they add no painted geometry or motion.

## Repeat and verify headlessly

All commands run from this worktree. The task contract/preflight, committing,
peer review and publication are design-owner responsibilities for this unit.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02 && python3 tests/test_maquette_cutout.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02 && python3 tools/cutout_workflow.py validate experiments/cutouts/chainbound_gaoler/mq3
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02 && python3 tools/godot_task_runner.py --task-id rr-02 --stream -- godot --headless --path . --script experiments/cutouts/chainbound_gaoler/mq3/probes/motion_samples.gd -- --case /Users/borgerding/workspace/Labyrinth.worktrees/rr-02/experiments/cutouts/chainbound_gaoler/mq3/cutout.json --output /Users/borgerding/workspace/Labyrinth.worktrees/rr-02/experiments/cutouts/chainbound_gaoler/mq3/proof/motion_samples.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02 && python3 experiments/cutouts/chainbound_gaoler/mq3/probes/proof.py --case experiments/cutouts/chainbound_gaoler/mq3 --samples experiments/cutouts/chainbound_gaoler/mq3/proof/motion_samples.json
```

For a complete fresh maquette cache on the design owner's machine, run the
tool command in [From a maquette](../../../../spec/cutout_workflow.md#from-a-maquette).
It requests every solo without modifying the protected spec, creates the fresh
`mq3_complete` case, copies these probes and runs headless exposure automatically.
The cloth TODO still requires the owner's supplied weight recipe. To reproduce
this diagnostic case exactly, use its `source/maquette` as `--renders` and add
`--allow-incomplete-renders`, targeting a fresh case directory.

## Proof for the design owner

These windowed commands were **not run**. They capture at 1920×1080, 100% UI
scale through the required runner. Use fresh output names on subsequent runs.
For `mq3_complete`, replace the case argument and native output name accordingly.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02 && python3 tools/visual_probe_runner.py experiments/cutouts/chainbound_gaoler/mq3/probes/native_rest.gd --task-id rr-02 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --expect-size 255x255 --proof-contract experiments/cutouts/chainbound_gaoler/mq3/probes/rest_contract.json --result-manifest experiments/cutouts/chainbound_gaoler/mq3/proof/native_rest_result.json -- --case /Users/borgerding/workspace/Labyrinth.worktrees/rr-02/experiments/cutouts/chainbound_gaoler/mq3/cutout.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02 && python3 tools/cutout_workflow.py render experiments/cutouts/chainbound_gaoler/mq3 --output /private/tmp/rr-02-mq3-render-v01 --task-id rr-02
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02 && python3 tools/cutout_workflow.py verify-render experiments/cutouts/chainbound_gaoler/mq3 --output /private/tmp/rr-02-mq3-render-v01
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02 && python3 experiments/cutouts/chainbound_gaoler/mq3/probes/proof.py --case experiments/cutouts/chainbound_gaoler/mq3 --native-output /private/tmp/rr-02-mq3-render-v01
```

Expected reel: `/private/tmp/rr-02-mq3-render-v01/videos/cutout_review.mp4`.
Expected eight-frame sheets: `proof/native_keyframes/<view>_<clip>_8frames.png`.
The native rest probe saves its 255px images and 1920×1080 rest/ownership
captures in the runner's isolated `user://probes/maquette_rest`; paths appear in
`proof/native_rest_result.json`. The collector first verifies the render's hashes,
then requires both native rests to equal the approved RGBA bytes.

`verify-render` was invoked before capture and correctly failed because
`/private/tmp/rr-02-mq3-render-v01/capture_input_sha256.json` does not yet exist;
see `proof/verify_render_pending.log`. No native pass, reel or screenshot is claimed.
An `inspection_fixture.py` command is not applicable: phase one does not register
this case with gameplay, so a playable production fixture would show the old rig.
