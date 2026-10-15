# Chainbound gaoler mq3 — round 4

Round 4 applies the director's material ownership, detached-island and rear-arm
layer corrections and adds `chain_reel` / `manacle_pin` to both views. The case
uses the unchanged final approved `mq3_front_v4` / `mq3_rear_v3` pair and all 42
provided solo renders. All changes remain uncommitted on top of `addd470bd`.
The complete change list is `proof/changed_files_round4.txt`.
No production files, gameplay timing, commits, peer review or publication are
part of this round. The director owns the new native reel and art judgment.

The v03 reel and native proof passed before this round, per director review.
They are historical evidence after these changes. A fresh v04 reel is required;
no windowed process was launched in this sandbox. `proof/native_rest_result.json`
and preceding proof logs remain untouched. Pre-round4 request PNGs, 4× copies,
request sheet and provenance are preserved byte-for-byte in `provenance/round3/`
(182 archived files verified by its manifest).

## Requirement status

| Requirement | Result | Evidence |
| --- | --- | --- |
| Material ownership | Front pelvis 71, far thigh 174 and near thigh 67 tabard-like pixels reassigned; all three rear counts are zero, with no rear material reassignment | `proof/*_ownership_cleanup.json` |
| Trouser fill | Six pelvis/thigh regions use only view-specific trousers core and remaining original own-visible donors; every hidden-region median is within DeltaE76 12 | `hidden_fills/index.json`, table below |
| Exact rest and order | Both views differ by 0 RGBA pixels; all 35,381 visible pixels retain their original rest draw depth | `proof/rest_identity.json`, `proof/round4_audit.json` |
| Detached islands | 98 front and 76 rear component pixels moved; no deletion or forced retention; no remaining detached component below 12px in a complete logical part | Per-part table and cleanup reports |
| Rear strike/pin layers | All upper/fore/hand fist paint behind torso and head, with internal arm order preserved; front and other clips retain default depths | Actual node depths in `proof/motion_samples.json` |
| Complete motion scope | Seven clips in both views, 458 sampled poses and 294 per-request clip exposure records | `cutout.json`, motion samples, paint plan |
| Hidden paint | 39 filled requests / 34,254 pixels; three empty requests; zero magenta in all 134 runtime images | `hidden_fills/contact_sheet.png`, round4 audit |
| Native art proof | Ready for director capture and judgment | v04 commands below |

There are 23 joints per view, 76 front and 58 rear paint/support nodes, zero
meshes and no unmaterialized logical parts. Additional nodes preserve original
rest depth after ownership transfers and articulate the existing chain paint.
Rigid cloth remains `tabard → tabard`, `coat_near → coat_fist`,
`coat_far → coat_hook`, with all three bones parented to pelvis as in production.
No design TODOs remain. Art status is `hidden_filled_pending_director_review`.

## Material and ownership recipe

`recipes/rig.json.ownership_cleanup` records the director's material thresholds.
The front tabard reference uses pixels at least 4px inside its registered
maquette label. Each view's trousers reference uses the near-thigh core after
excluding pixels within DeltaE76 20 of the tabard median. Medians are RGB medians
converted using the art gate's D65 sRGB-to-Lab function. Measured references:
front tabard `(84,28,24)`, front trousers `(69,54,49.5)`, rear trousers `(53,40,37)`.
The tabard is front-only, so both views use the front reference for classification.

The material transfer precedes component cleanup and hidden fill. Each visible
piece keeps its original depth in `rest_depth_source`, while its new logical
owner determines its bone. `registered/*_original_owners.npy` retains the original
partition; current owners, hidden masks and trousers masks are separately saved.
Fill recomputes cleanup from the source and rejects inconsistent stored masks.

Pelvis/thigh donor pixels exclude coat, tabard and cross-view sources. The
remaining original own-visible pixels and trousers core form the seeded k=6
palette. Hidden interiors use only sampled palette centroids within DeltaE76 12
of the reference. The one-pixel outline remains `(20,16,21)`; its pixels are
included in the final median check. Visible RGBA never changes.

| Filled region | Hidden pixels | Hidden RGB median | DeltaE76 to trousers |
| --- | ---: | --- | ---: |
| `front/thigh_near` | 1,626 | `(47.0, 38.0, 36.0)` | 8.621 |
| `front/thigh_far` | 2,186 | `(58.0, 46.0, 42.0)` | 4.195 |
| `rear/thigh_far` | 2,063 | `(36.0, 26.0, 27.0)` | 7.650 |
| `rear/thigh_near` | 1,283 | `(38.0, 27.0, 27.0)` | 6.764 |
| `rear/pelvis` | 1,720 | `(35.0, 25.0, 26.0)` | 8.101 |
| `front/pelvis` | 2,051 | `(48.0, 34.0, 32.0)` | 9.387 |

## Detached-component report

The complete part mask combines visible pixels and hidden support. Components
use 8-connectivity; the largest is exempt and only components below 12px are
considered. A component moves to the rest-painted neighbour with the most
shared four-connected boundary edges; ties use label order. Moves are computed
from one snapshot. Unattached hidden-only islands may be deleted if the complete
visible partition still covers rest; unattached visible islands stay and are
reported. Neither exceptional case occurred here. Counts below include visible
and hidden pixels; component bounds, targets and visible counts are in the
per-view cleanup JSON files.

| Part | Front pixels moved | Rear pixels moved |
| --- | ---: | ---: |
| `head` | 8 | 5 |
| `torso` | 1 | 3 |
| `pelvis` | 0 | 0 |
| `belt` | 5 | 3 |
| `tabard` | 11 | 1 |
| `coat_near` | 16 | 12 |
| `coat_far` | 0 | 1 |
| `upper_near` | 0 | 0 |
| `fore_near` | 1 | 0 |
| `hand_near` | 0 | 0 |
| `upper_far` | 1 | 0 |
| `fore_far` | 7 | 3 |
| `hand_far` | 0 | 0 |
| `thigh_near` | 0 | 0 |
| `shin_near` | 4 | 0 |
| `foot_near` | 3 | 0 |
| `thigh_far` | 0 | 0 |
| `shin_far` | 13 | 5 |
| `foot_far` | 27 | 35 |
| `chain` | 1 | 8 |
| `hook` | 0 | 0 |

After cleanup, the front far-foot sole is `(113.5,229)` instead of
`(188.5,238)`: the old bottommost measurement selected a detached speck near the
other boot. The cleaned foot contour now supplies the production walk sampler.
Other sole landmarks are unchanged. Fresh planted-support and foot-target
checks pass; the v04 front walk is a relevant director inspection point.

## Motion and layer behavior

The copied production `gaoler_motion.gd` remains byte-identical. The case adapter
maps the maquette chain to production `chain_a`, and adds real `chain_b/c` joints
at production link fractions mapped onto the registered chain-to-hook axis.
The existing visible and hidden chain paint is partitioned at those fractions.
The hook retains its registered endpoint. No motion curves or poses are invented.

Rear `strike` and `manacle_pin` shift the entire fist-arm layer group below the
lowest torso/head paint layer. The same shift applies to every arm piece,
preserving its internal order. Front and other clips retain their prior static
depths. Samples read actual Sprite2D depths, assert these contracts and use the
same order for exposure. Exposure sums all support pieces of a logical part.

| Clip | Duration | Diagnostic frames per view |
| --- | ---: | ---: |
| idle | 1.6 s | 24 |
| walk | 0.64 s | 48 |
| strike | 0.24 s | 31 |
| hit | 0.36 s | 24 |
| death | 1.036 s, settlement at 62% | 32 |
| chain_reel | 0.24 s | 31 |
| manacle_pin | 0.57 s | 39 |

Reel timing uses the existing RunScene 6 × 0.04s attack clock. Pin uses
AttackFxLibrary's 38 × 0.015s air clock. Its 39 endpoint-inclusive samples capture
release at 4/38 and contact at 12/38 exactly. These frame counts are proof defaults.
All seven clips will appear in each view of `cutout_review.mp4`.

## Fill provenance and checks

The unchanged deterministic diffusion defaults are radius 3, palette k=6,
seed 0, k-means cap 256, diffusion cap 4,096, residual tolerance 1e-6,
four-neighbour harmonic diffusion with reflecting borders, 40 own pixels for
the generic palette fallback, and outline `(20,16,21)`. Material thresholds
4px / DeltaE20 / DeltaE12 and component cutoff 12px come from round4 director data.
Border counting, tie order, chain pixel-centre partitioning and new diagnostic
frame counts are recorded procedural choices. Other proof defaults remain
five sheet columns, 28px captions, alpha threshold 128, 0.02px joint tolerance,
512px pose canvas and eight native keyframes per clip. Headless tolerances remain
0.001 rigid basis, 0.2px foot target and 0.02px planted support.

Generic parts still use own visible paint and listed exact same-material
neighbours. The previously approved same-part cross-view fallback applies when
own count is below 40 and no local matching neighbour remains after cleanup:

| Request | Own visible pixels | Paired donor | Donor pixels |
| --- | ---: | --- | ---: |
| `rear/fore_near` | 0 | `front/fore_near` | 508 |
| `rear/hand_near` | 0 | `front/hand_near` | 455 |
| `rear/tabard` | 9 | `front/tabard` | 1713 |

The two hooks and front tabard now have no hidden pixels. Every request retains
an explicit measured record. Current request images deliberately show magenta
as the fill masks; runtime images contain none. `hidden_fills/index.json` records
all palettes, eligible quantization colors, donors, conditioning masks, counts,
solver results and per-output digests, including split chain outputs. Reruns are
identical and refuse to overwrite later manual paint. Original source files are
unchanged (`proof/round4_source_audit.json`).

- Focused tests: 28 tests, 9.889s, OK (`proof/focused_round4.log`).
- Art gate: 49 tests, 13.790s, OK (`proof/art_gate_round4.log`).
- Python full suite: 425 tests in 242.496s, OK (skipped=61), exit 0 (`proof/python_suite_round4.log`).
- Godot full suite: `FULL SUITE RUNTIME: 672.734 seconds (budget 900 seconds)`, `TEST RESULT: PASS`, exit 0 (`proof/godot_suite_round4.log`). Logs retain macOS certificate, scene-tree/resource diagnostics and the ObjectDB exit warning; all program sub-suites pass.
- Fresh self-contained rebuild: all 369 derived files, 458 pose records and 42 request/fill records match exactly (`proof/rebuild_round4.json`).
- Motion: `MAQUETTE_MOTION_SAMPLES: PASS (458 poses)`.
- Exposure: 42 measured requests, zero unknown solos, seven clips per request.
- Validation with `--protect all`: `ok: true`, no errors.
- Rest: front 0, rear 0 differing pixels; audit zero magenta and exact rest depth.
- New full fill sheet inspected as a diagnostic at native presentation size;
  native v04 motion inspection remains the director's step.

## Rebuild and headless verification

Use a fresh case path; the build command deliberately does not overwrite a
completed case. These commands use the exact self-contained source copies:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02
python3 tools/maquette_cutout.py --spec experiments/cutouts/chainbound_gaoler/mq3/source/spec.json --front-job experiments/cutouts/chainbound_gaoler/mq3/source/front --rear-job experiments/cutouts/chainbound_gaoler/mq3/source/rear --renders experiments/cutouts/chainbound_gaoler/mq3/source/maquette --palette experiments/cutouts/chainbound_gaoler/mq3/source/label_palette.json --rig-recipe experiments/cutouts/chainbound_gaoler/mq3/recipes/rig.json --case /private/tmp/rr-02-mq3-rebuild-v04 --task-id rr-02
python3 tools/maquette_cutout.py fill-hidden --case /private/tmp/rr-02-mq3-rebuild-v04 --task-id rr-02 --cross-view-fallback
```

For the current case:

```sh
python3 tests/test_maquette_cutout.py
python3 tests/test_art_identity_gate.py
python3 tools/cutout_workflow.py validate experiments/cutouts/chainbound_gaoler/mq3 --protect all
python3 tools/maquette_cutout.py fill-hidden --case experiments/cutouts/chainbound_gaoler/mq3 --task-id rr-02
```

## Windowed v04 capture and director review

Run from the worktree in a window-server session. The new native-rest manifest
preserves all previous director-supplied results; the v04 directory must be fresh.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02
case_dir="$PWD/experiments/cutouts/chainbound_gaoler/mq3"
capture_dir=/private/tmp/rr-02-mq3-render-v04
python3 tools/visual_probe_runner.py "$case_dir/probes/native_rest.gd" --task-id rr-02 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --expect-size 255x255 --proof-contract "$case_dir/probes/rest_contract.json" --result-manifest "$case_dir/proof/native_rest_round4_result.json" -- --case "$case_dir/cutout.json"
python3 tools/cutout_workflow.py render "$case_dir" --output "$capture_dir" --task-id rr-02
python3 tools/cutout_workflow.py verify-render "$case_dir" --output "$capture_dir"
python3 "$case_dir/probes/proof.py" --case "$case_dir" --native-output "$capture_dir"
```

Expected reel: `/private/tmp/rr-02-mq3-render-v04/videos/cutout_review.mp4`.
The collector requires byte-identical native rest and produces eight-frame
sheets for every rendered clip/view. Inspect the front/rear walk for red smears
and detached specks, rear strike/pin for shoulder occlusion, and the two added
clips for complete scope. Numerical proof is not a substitute for this art
judgment. A gameplay inspection fixture is not applicable before integration.
