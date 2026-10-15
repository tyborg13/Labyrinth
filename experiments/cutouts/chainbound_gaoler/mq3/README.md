# Chainbound gaoler mq3 — phase 2a

The case uses the final approved `mq3_front_v4` / `mq3_rear_v3` pair and all
42 director-rendered solos. Visible paint is untouched; hidden material stays
magenta until the director paints it. Production assets, gameplay, saves and
analytics are unchanged. All implementation changes remain uncommitted.

## Merge prerequisite

The requested `git merge --no-commit codex/peer-benchmark` was blocked:

```text
fatal: update_ref failed for ref 'ORIG_HEAD': cannot lock ref 'ORIG_HEAD': Unable to create '/Users/borgerding/workspace/Labyrinth/.git/worktrees/rr-02/ORIG_HEAD.lock': Operation not permitted
```

The director must perform the merge outside this sandbox. To finish the case,
its supplied inputs were read directly from the director's
`/Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark` checkout.
The final raws came from the main checkout's
`output/peer-benchmark-2026-10-12/identity_gate/raw/chainbound_gaoler_mq3_{front_v4,rear_v3}.png`.
`proof/supplied_inputs.json` verifies all 47 render/joint files and six approved
job files against that checkout. Both raw digests match `processed.json`.
The two production layouts and motion script also match this worktree exactly.
No Git metadata workaround, commit, peer review or publication was performed.

## Requirement status

| Feedback | Implementation and evidence | Remaining proof |
| --- | --- | --- |
| 1. Supplied renders | `--renders` checks required files, dimensions and joint names before case creation, never invokes Blender, and records 47 SHA-256 digests in `source/maquette_manifest.json` | Merge prerequisite above |
| 2. Final pair | Front v4 and rear v3 copied byte-for-byte; exact registered RGBA reconstruction, including hidden underlays, has zero differing pixels for both views | Native rest probe |
| 3. Rigid cloth | No skin meshes or skin recipes; production bones, parents and cloak visibility slots preserved and checked in both views; mapping in `build_report.json` | Native motion inspection |
| 4. Complete hidden requests | 42 measured native/4× pairs, all five clips measured per request, descending exposure order, contact sheet and `hidden_requests/paint_plan.md` with bounds, exposing motions and neighbouring materials | Director paints magenta material later |
| 5. Motion and validation | Existing sampler/timing unchanged; 318 headless poses pass; case validation passes with `--protect all` | Native reel and eight-frame sheets |

| Maquette cloth | Production part/bone | Parent, both views |
| --- | --- | --- |
| `tabard` | `tabard` | `pelvis` |
| `coat_near` | `coat_fist` | `pelvis` |
| `coat_far` | `coat_hook` | `pelvis` |

The case has 21 joints per view, 41 painted/support nodes in front and 40 in
rear, zero meshes, and no unmaterialized logical parts. Support nodes are
camera-depth-ordered magenta underlays below the exact visible partition;
intersecting proxy surfaces cannot be represented by one depth per whole part.
Their motion exposes the missing paint without changing rest ownership.

## Artifacts

- `source/maquette_manifest.json`: all expected renders and their digests.
- `registered/`: maps, all solos, joints and exact processing transforms.
- `proof/front_rest_3x.png`, `proof/rear_rest_3x.png`,
  `proof/front_ownership_3x.png`, `proof/rear_ownership_3x.png`: rest assemblies
  and flat part ownership at 3× nearest; inspected as diagnostic images.
- `proof/front_registered_inputs.png`, `proof/rear_registered_inputs.png`:
  inspected contact sheets containing every supplied map and solo at registration size.
- `hidden_requests/contact_sheet.png`: all 42 requests in exposure order.
- `hidden_requests/paint_plan.md`: the same order, with native/4× links,
  hidden area, bounds, exposure per motion and neighbouring materials.
- `hidden_requests/index.json`: measured counts and all five clip records for
  every part. Two requests have zero peak exposure (both hooks); these are
  measured zeros. The front hook has zero hidden pixels; rear has one.
- `proof/motion_samples.json`: actual Skeleton2D matrices, bound to input
  digests. Exposure uses nearest CPU mask rasterization, not native captures.

Ownership still flags seven front parts above 15% reassignment: thigh_near
19.1%, shin_near 21.7%, thigh_far 33.5%, shin_far 31.9%, foot_far 20.5%, chain
57.0%, hook 71.1%. Five rear parts are flagged: coat_near 16.8%, foot_near
47.7%, foot_far 61.7%, chain 68.3%, hook 76.0%. No manual ownership correction
or repaint was made. Small neighbouring-region counts are retained faithfully
from that categorical ownership; the paint plan does not invent hidden anatomy.

## Checks

Fresh results are retained under `proof/`. The standard focused test currently
has two missing-input errors because the canonical supplied-art paths have not
been merged into this worktree. Its other 13 tests pass, including exact rest,
all requests/exposure, rigid parenting and the synthetic fixture. The separate
53-file parity report checks those supplied inputs directly in the director's
checkout. These errors are not assertions rewritten to pass.

Observed result lines:

- Focused: `Ran 15 tests in 1.221s`, `FAILED (errors=2)`; both are the
  missing canonical input files described above.
- Python suite: `Ran 412 tests in 289.576s`, `FAILED (errors=2, skipped=61)`;
  no additional failures. Logs retain every skip and its reason.
- Motion: `MAQUETTE_MOTION_SAMPLES: PASS (318 poses)`.
- Exposure: `MAQUETTE_EXPOSURE: PASS (42 requests; 0 unknown solos)`.
- Validation: `"ok": true`, `"errors": []`, including `--protect all`.
- Rest identity: `different_pixels: 0`, `pixel_identical: true` for both views.
- Supplied-input parity: `SUPPLIED_INPUTS: PASS (53 supplied files)`.
- Fresh CLI rebuild: `proof/repeatability.json` has `ok: true`; all 231
  compared derived files and the runtime/source closure match. This includes
  the portable motion samples, exposure index, paint plan and request sheet.
- Native rest probe: headless `--check-only` passed; parser proof only.
- Godot full suite: `FULL SUITE RUNTIME: 765.339 seconds (budget 900 seconds)`,
  `TEST RESULT: PASS`. The engine reports an ObjectDB leak warning at exit;
  the suite and its program sub-suites pass.

`verify-render` currently fails because no native capture exists. No native
pass, reel or renderer screenshot is claimed.

## TODO_DESIGN placeholders

None. The director resolved the cloth question in phase 2a: rigid production
attachments, no skinning. Missing hidden paint is the explicitly requested
next art phase, not a guessed material or weight field.

## Chosen defaults

Only tooling/proof values were chosen; gameplay and motion timing remain production-derived.

- `PROOF_DEFAULTS`: five sheet columns, 28px captions, alpha threshold 128,
  joint rounding tolerance 0.02px and four-connected material neighbours.
  Native 255px registration, 3×/4× images, 512px action canvas and eight
  keyframes per clip come from the brief/workflow.
- `recipes/rig.json.proof_defaults`: sample counts idle 24, walk 48, strike 31,
  hit 24, death 32, one proof cycle. The obsolete skin grid was removed.
- Native diagnostic origins `(80,160)` and `(1000,160)` on 1920×1080; existing
  default font for contact-sheet captions. No art, font or audio was generated.
- Headless tolerances: rigid basis 0.001, foot target 0.2px, planted support
  0.02px. Default runner timeouts; documented 900 seconds for the full suite.

Playback: idle 1.6s, walk 0.64s, strike 6×0.04s, hit 0.36s; death 28×0.037s
with settlement at 62% of the existing dissolve clock. Move/attack/hurt use the
existing clip names walk/strike/hit. Chain Reel/Manacle Pin remain outside the
requested five-clip proof; no extra chain topology or timing was invented.

## Repeat and verify headlessly

All commands start from this worktree. Use a fresh output case for regeneration;
completed cases are deliberately not overwritten by the CLI. Once merged, the
[From a maquette command](../../../../spec/cutout_workflow.md#from-a-maquette)
uses the canonical supplied inputs. The following rebuild uses the exact
self-contained copies and does not need Blender:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02 && python3 tools/maquette_cutout.py --spec experiments/cutouts/chainbound_gaoler/mq3/source/spec.json --front-job experiments/cutouts/chainbound_gaoler/mq3/source/front --rear-job experiments/cutouts/chainbound_gaoler/mq3/source/rear --renders experiments/cutouts/chainbound_gaoler/mq3/source/maquette --rig-recipe experiments/cutouts/chainbound_gaoler/mq3/recipes/rig.json --case experiments/cutouts/chainbound_gaoler/mq3_repeat --task-id rr-02
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02 && python3 tests/test_maquette_cutout.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02 && python3 tools/cutout_workflow.py validate experiments/cutouts/chainbound_gaoler/mq3 --protect all
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02 && python3 tools/godot_task_runner.py --task-id rr-02 --stream -- godot --headless --path . --script experiments/cutouts/chainbound_gaoler/mq3/probes/motion_samples.gd -- --case /Users/borgerding/workspace/Labyrinth.worktrees/rr-02/experiments/cutouts/chainbound_gaoler/mq3/cutout.json --output /Users/borgerding/workspace/Labyrinth.worktrees/rr-02/experiments/cutouts/chainbound_gaoler/mq3/proof/motion_samples.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02 && python3 experiments/cutouts/chainbound_gaoler/mq3/probes/proof.py --case experiments/cutouts/chainbound_gaoler/mq3 --samples experiments/cutouts/chainbound_gaoler/mq3/proof/motion_samples.json
```

## Proof for the design owner

These windowed commands were **not run**. They use the required runners at
1920×1080, 100% UI scale. Use a fresh output name on subsequent runs.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02 && python3 tools/visual_probe_runner.py experiments/cutouts/chainbound_gaoler/mq3/probes/native_rest.gd --task-id rr-02 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --expect-size 255x255 --proof-contract experiments/cutouts/chainbound_gaoler/mq3/probes/rest_contract.json --result-manifest experiments/cutouts/chainbound_gaoler/mq3/proof/native_rest_result.json -- --case /Users/borgerding/workspace/Labyrinth.worktrees/rr-02/experiments/cutouts/chainbound_gaoler/mq3/cutout.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02 && python3 tools/cutout_workflow.py render experiments/cutouts/chainbound_gaoler/mq3 --output /private/tmp/rr-02-mq3-render-v02 --task-id rr-02
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02 && python3 tools/cutout_workflow.py verify-render experiments/cutouts/chainbound_gaoler/mq3 --output /private/tmp/rr-02-mq3-render-v02
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02 && python3 experiments/cutouts/chainbound_gaoler/mq3/probes/proof.py --case experiments/cutouts/chainbound_gaoler/mq3 --native-output /private/tmp/rr-02-mq3-render-v02
```

Expected reel: `/private/tmp/rr-02-mq3-render-v02/videos/cutout_review.mp4`.
Expected eight-frame sheets: `proof/native_keyframes/<view>_<clip>_8frames.png`.
The rest probe writes native rests and rest/ownership captures under isolated
`user://probes/maquette_rest`; its result manifest lists the exact paths.
The collector verifies hashes and native RGBA equality before writing sheets.
`inspection_fixture.py` is not applicable until production integration: a
playable game fixture would still show the production rig.
