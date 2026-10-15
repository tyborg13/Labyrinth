# Chainbound gaoler mq3 — phase 2b

The case uses the final approved `mq3_front_v4` / `mq3_rear_v3` pair and all
42 director-rendered solos. The requested deterministic fill is implemented
and applied to all 41 hidden regions (34,180 pixels). One request has no hidden
pixels. Feedback 3 resolves the three sparse rear parts with the same parts
from the approved front view. No magenta remains in any of the 81 runtime
images. Rest assemblies remain exact RGBA; no design placeholders remain.

The director merged phase 2a externally; all canonical supplied inputs are now
present. The director's native rest probe passed and reel
`/private/tmp/rr-02-mq3-render-v02` was reviewed for correct motion/mapping.
Its hashes independently verified before this fill. Those captures are now
historical evidence; phase 2b needs a fresh reel. The provided
`proof/native_rest_result.json` is preserved unchanged.

All phase-2b changes remain uncommitted at HEAD `528518258`.
The complete file list is `proof/changed_files_phase2b.txt`.
No production integration, motion change, commit, peer review or publication
was performed in phase 2b. The director owns art acceptance and may replace
individual generated fills with painted material later.

## Requirement status

| Feedback | Implementation and evidence | Remaining work |
| --- | --- | --- |
| 1. Deterministic hidden fill | `maquette_cutout.py fill-hidden`; recorded harmonic diffusion, seeded k-means and one-pixel outline; all 41 hidden regions filled, including three recorded cross-view donors; all rest-visible RGBA and part alpha unchanged | Director judges the native reel |
| 2. Provenance | 42 per-request records in `hidden_fills/index.json`, method recipe, palette/counts/digests, native previews and contact sheet; original request PNGs remain byte-identical | None |
| 3. Fresh proof | Rest identity, validation and all 318 motion samples refreshed; all five clip exposures remain measured for every request | Windowed v03 reel and director judgment |

| Maquette cloth | Production part/bone | Parent, both views |
| --- | --- | --- |
| `tabard` | `tabard` | `pelvis` |
| `coat_near` | `coat_fist` | `pelvis` |
| `coat_far` | `coat_hook` | `pelvis` |

The case has 21 joints per view, 41 painted/support nodes in front and 40 in
rear, zero meshes, and no unmaterialized logical parts. Support nodes are
camera-depth-ordered underlays below the exact visible partition;
intersecting proxy surfaces cannot be represented by one depth per whole part.
Their motion exposes the filled material without changing rest ownership.

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
of the approved rest paint was made. Small neighbouring-region counts are retained faithfully
from that categorical ownership; the paint plan does not invent hidden anatomy.

## Hidden fill and provenance

`recipes/hidden_fill.json` records the method and algorithm parameters.
`hidden_fills/index.json` records each part's material, palette, palette source,
visible/hidden/donor/outline counts, donor IDs, solver metrics, source/request/
mask/pixel/output digests and status. `hidden_fills/contact_sheet.png` shows all
42 results at native resolution. The original requests, 4× images, paint plan
and request sheet remain provenance; they deliberately still show magenta.

Same-material means an exact match to the material descriptions in the paint
plan and rig recipe. Diffusion fixes the part's own visible RGB and listed
matching neighbours' visible RGB. Feedback 3 enables `--cross-view-fallback`:
when a part has fewer than 40 visible pixels and no matching local neighbour,
use the same part's visible RGB in the paired view for palette and diffusion.
This decision is recorded in `recipes/hidden_fill.json`; reruns retain it.
Cross-view donor pixels keep their registered native coordinates without
resizing or mirroring, and target-visible paint takes priority. Unrelated
materials and background remain unknown values. Six clusters
are requested (or fewer if fewer distinct input colors exist). The outline is
applied only to hidden pixels on the four-connected edge of the whole part.
It does not outline the seam between visible and hidden paint or delete alpha.

Rerunning the command produces identical outputs. All inputs are checked before
writing fills, and the tool refuses to overwrite hidden files that differ from
the previous generated output digest, protecting later manual replacements.
Art status is `hidden_filled_pending_director_review`; numerical completion
does not approve the art. `proof/feedback3_audit.json` confirms that only the
three approved rear underlays changed from the previous fill, all 249 protected
files remain byte-identical, and all 81 runtime images contain zero magenta.

## Checks

Current results are recorded in `proof/*feedback3.log`,
`proof/hidden_fill_report.json` and `proof/feedback3_audit.json`. Earlier
phase-2a and initial phase-2b logs remain historical evidence.

- Focused: `Ran 21 tests in 17.596s`, `OK`.
- Python full suite: `Ran 418 tests in 265.527s`, `OK (skipped=61)`; includes
  the art identity gate tests.
- Godot full suite: `FULL SUITE RUNTIME: 752.065 seconds (budget 900 seconds)`,
  `TEST RESULT: PASS`, exit 0. Logs retain macOS certificate and scene-tree
  diagnostics plus the ObjectDB exit warning; all program sub-suites pass.
- Motion: `MAQUETTE_MOTION_SAMPLES: PASS (318 poses)`.
- Exposure: `MAQUETTE_EXPOSURE: PASS (42 requests; 0 unknown solos)`.
- Rest identity: `different_pixels: 0`, `pixel_identical: true` for both views.
- Fill: `ok: true`, `complete: true`; 41 filled requests, one empty request,
  zero pending requests. Filled hidden pixels: 34,180; outlines: 3,333.
- Validation with `--protect all`: `"ok": true`, `"errors": []`.
- `FEEDBACK3_AUDIT: PASS (only 3 approved underlays changed; 249 protected files unchanged; 0 magenta pixels across 81 runtime images)`.
- `FEEDBACK3_PRESERVATION: PASS (41 hidden alpha masks, all motion transforms and all exposure records unchanged)`.
- Historical v02 proof is stale after filling. No phase-2b native capture or
  reel is claimed; use the fresh v03 commands below.

## Resolved donor decisions

No `TODO_DESIGN` placeholders remain in the current case. The director's
feedback 3 approves this fallback only for sparse parts without local
same-material neighbours. Both palette and inpaint donors are recorded per
request under `cross_view_donor`, with source/ownership digests and pixel counts.

| Target | Own visible pixels | Hidden pixels | Cross-view donor | Donor visible pixels |
| --- | ---: | ---: | --- | ---: |
| `rear/thigh_far` | 7 | 2,063 | `front/thigh_far` | 188 |
| `rear/hand_near` | 0 | 594 | `front/hand_near` | 448 |
| `rear/tabard` | 10 | 1,206 | `front/tabard` | 1,394 |

The other 38 filled underlay PNGs are byte-identical to the preceding fill.
Original request images retain magenta for provenance. Rigid cloth, visible
paint, source assets, alpha masks, skeletons and motion timing are unchanged.

## Chosen defaults

Feedback 3 introduces no new numeric defaults; it uses the recorded fill values
and the existing registered native coordinates. Gameplay and motion timing remain production-derived.

- `PROOF_DEFAULTS`: five sheet columns, 28px captions, alpha threshold 128,
  joint rounding tolerance 0.02px and four-connected material neighbours.
  Native 255px registration, 3×/4× images, 512px action canvas and eight
  keyframes per clip come from the brief/workflow.
- `recipes/rig.json.proof_defaults`: sample counts idle 24, walk 48, strike 31,
  hit 24, death 32, one proof cycle. The obsolete skin grid was removed.
- `FILL_DEFAULTS`: fixed seed 0, k-means iteration cap 256; diffusion iteration
  cap 4,096 and absolute residual tolerance 1e-6. Deterministic weighted RGB
  k-means++ initialization, four-neighbour harmonic diffusion, reflecting
  boundaries and a donor/target domain padded by 3px. The director specified
  radius 3, palette k=6, the 40px fallback threshold and outline `(20,16,21)`.
- Native diagnostic origins `(80,160)` and `(1000,160)` on 1920×1080; existing
  default font for contact-sheet captions. Only the expressly requested hidden pixels were filled; fonts/audio are unchanged.
- Headless tolerances: rigid basis 0.001, foot target 0.2px, planted support
  0.02px. Default runner timeouts; documented 900 seconds for the full suite.

Playback: idle 1.6s, walk 0.64s, strike 6×0.04s, hit 0.36s; death 28×0.037s
with settlement at 62% of the existing dissolve clock. Move/attack/hurt use the
existing clip names walk/strike/hit. Chain Reel/Manacle Pin remain outside the
requested five-clip proof; no extra chain topology or timing was invented.

## Repeat and verify headlessly

All commands start from this worktree. Use a fresh output case for regeneration;
completed cases are deliberately not overwritten by the build CLI. The
[From a maquette command](../../../../spec/cutout_workflow.md#from-a-maquette)
uses the canonical supplied inputs. The following rebuild uses the exact
self-contained copies and does not need Blender:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02 && python3 tools/maquette_cutout.py --spec experiments/cutouts/chainbound_gaoler/mq3/source/spec.json --front-job experiments/cutouts/chainbound_gaoler/mq3/source/front --rear-job experiments/cutouts/chainbound_gaoler/mq3/source/rear --renders experiments/cutouts/chainbound_gaoler/mq3/source/maquette --rig-recipe experiments/cutouts/chainbound_gaoler/mq3/recipes/rig.json --case experiments/cutouts/chainbound_gaoler/mq3_repeat --task-id rr-02
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02 && python3 tools/maquette_cutout.py fill-hidden --case experiments/cutouts/chainbound_gaoler/mq3_repeat --task-id rr-02 --cross-view-fallback
```

To reapply or verify the current case:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02 && python3 tools/maquette_cutout.py fill-hidden --case experiments/cutouts/chainbound_gaoler/mq3 --task-id rr-02
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02 && python3 tests/test_maquette_cutout.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02 && python3 tools/cutout_workflow.py validate experiments/cutouts/chainbound_gaoler/mq3 --protect all
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02 && python3 tools/godot_task_runner.py --task-id rr-02 --stream -- godot --headless --path . --script experiments/cutouts/chainbound_gaoler/mq3/probes/motion_samples.gd -- --case /Users/borgerding/workspace/Labyrinth.worktrees/rr-02/experiments/cutouts/chainbound_gaoler/mq3/cutout.json --output /Users/borgerding/workspace/Labyrinth.worktrees/rr-02/experiments/cutouts/chainbound_gaoler/mq3/proof/motion_samples.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02 && python3 experiments/cutouts/chainbound_gaoler/mq3/probes/proof.py --case experiments/cutouts/chainbound_gaoler/mq3 --samples experiments/cutouts/chainbound_gaoler/mq3/proof/motion_samples.json
```

## Proof for the design owner

These phase-2b windowed commands were **not run**; the sandbox has no window-server access. They use the required runners at
1920×1080, 100% UI scale. Use a fresh output name on subsequent runs.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02 && python3 tools/visual_probe_runner.py experiments/cutouts/chainbound_gaoler/mq3/probes/native_rest.gd --task-id rr-02 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --expect-size 255x255 --proof-contract experiments/cutouts/chainbound_gaoler/mq3/probes/rest_contract.json --result-manifest experiments/cutouts/chainbound_gaoler/mq3/proof/native_rest_phase2b_result.json -- --case /Users/borgerding/workspace/Labyrinth.worktrees/rr-02/experiments/cutouts/chainbound_gaoler/mq3/cutout.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02 && python3 tools/cutout_workflow.py render experiments/cutouts/chainbound_gaoler/mq3 --output /private/tmp/rr-02-mq3-render-v03 --task-id rr-02
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02 && python3 tools/cutout_workflow.py verify-render experiments/cutouts/chainbound_gaoler/mq3 --output /private/tmp/rr-02-mq3-render-v03
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02 && python3 experiments/cutouts/chainbound_gaoler/mq3/probes/proof.py --case experiments/cutouts/chainbound_gaoler/mq3 --native-output /private/tmp/rr-02-mq3-render-v03
```

Expected reel: `/private/tmp/rr-02-mq3-render-v03/videos/cutout_review.mp4`.
Expected eight-frame sheets: `proof/native_keyframes/<view>_<clip>_8frames.png`.
The rest probe writes native rests and rest/ownership captures under isolated
`user://probes/maquette_rest`; its result manifest lists the exact paths.
The collector verifies hashes and native RGBA equality before writing sheets.
`inspection_fixture.py` is not applicable until production integration: a
playable game fixture would still show the production rig.
