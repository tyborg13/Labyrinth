# Chainbound gaoler mq3 — round 9

Round9 addresses the peer review on top of the director's round8 commit
`dc06de8b7`. Changes remain uncommitted. No windowed capture, peer review or
agent delegation was attempted. Native v09 proof is reserved for the director.

## Round9 review fixes

1. **Runtime values:** the value gate assembles the actual hidden-material PNGs
   using layout offsets and registered hidden masks. It checks exact coverage,
   measures runtime L*, and independently requires preview/runtime RGBA agreement.
   Native frames use physical hidden-owner IDs to report visible hidden L* and
   reject colors outside that runtime node's palette. The full-region median
   remains the threshold basis because per-frame exposure biases the distribution.
   RGB 220 now reports runtime L* **87.76**, preview L* **15.96**, and fails;
   changing both runtime and preview to RGB 220 also fails.
2. **Round8 retained:** categorical masks remain external data, all 504 real
   screenshots retain normal validation, and the configurable capture timeout is
   900 seconds by default. The headless writer/collector/timeout regressions remain.
3. **Complete rebuild:** all clean build/fill outputs were promoted together,
   including both ownership recipes (532 front / 227 rear corrected assignments),
   `build_report.json` and the baseline. The
   report now agrees with the actual **83 front / 62 rear** paint nodes. The new
   `probes/rebuild.py` compares every generated file and the exact inventory in
   `proof/derived_files.json`; no image, recipe or JSON is excluded. Its only
   exclusions are three execution transcripts with runner IDs/paths. The focused
   regression performs a clean rebuild and proves corruption of either ownership
   recipe, the report or baseline fails comparison; orphaned assets also fail.
4. **Actual camera transforms:** `--view-transforms` accepts per-facing object and
   orthographic camera metadata without rewriting the source spec. Projection
   and depth use the same transform. A wing/tail fixture exports joints
   independently at **135°/315°**, checks projection and reversed depth, builds
   twice identically, and rejects the legacy camera for those exported joints.
5. **Authored motion data:** `rear_torso_lean` is carried from the recipe into
   generated layouts. The sampler reads the authored 0.07 rad × hit and
   [0,−3] px × prep values. Changing that recipe and regenerating a layout is
   tested through Godot; front/walk behavior stays fixed. With the director's
   unchanged values, all **458 sampled poses remain exactly identical**.
6. **Headless command:** `--case` now uses the absolute `$PWD/.../cutout.json` path.

All approved source files and all runtime images are byte-identical to round8.
The rebuild changes provenance and generated metadata, not the approved paint.
No new `TODO_DESIGN` remains. Chosen defaults: explicit affine/camera metadata
schema, three named transcript exclusions, and regression-only mutations. No
new player-visible values, timing, paint or production integration were added.

## Round9 verification

- Focused: `Ran 43 tests in 94.957s` / `OK`.
- Art gate: `Ran 49 tests in 18.792s` / `OK`.
- Visual runner: `Ran 16 tests in 0.323s` / `OK`.
- Python full: `Ran 440 tests in 383.720s` / `OK (skipped=61)`.
- Godot full: `FULL SUITE RUNTIME: 830.349 seconds (budget 900 seconds)` /
  `TEST RESULT: PASS`.
- Clean rebuild: `GAOLER REBUILD: PASS (882 files)`; every generated artifact
  matches. `proof/round9_rebuild.json` records all hashes and exclusions.
- Protected case validation: `ok: true`, no errors; rest assembly differs
  by **0 pixels** in each view. CPU gates: **458 frames**, seven pixel totals
  all **0**, value failures **0**.
- Runtime mutation: `RUNTIME FILL MUTATION: REJECTED (458 refreshed poses; exact
  rest; one runtime value failure)`. All **2,070** hidden rear-thigh pixels
  disagree with the stale preview. Runtime L* **87.760888**, preview **15.956441**.
  See `proof/round9_runtime_fill_mutation.json`; the mutation was confined to an
  isolated temporary fixture.
- Historical v07 renderer diagnostic: **458 frames**, **3,741** hidden-owner
  measurements covering **172,198** visible hidden pixels; all seven totals and
  value failures **0**, with both exact rest/owner/provenance calibrations.
  All **504** real screenshots validate; **1,840** masks are data. See
  `proof/round9_v07_runtime_fill_diagnostic.json`. This uses saved v07 pixels;
  it cannot satisfy the fresh v09 capture/input-binding requirements.

The initial focused failure was a test fixture attempting to segment into an
existing temporary output directory. It is retained in
`proof/focused_round9_initial.log` and fixed by recreating that fixture directory.
It was not a failure of the complete rebuild comparison. The immutable source,
runtime image, sampled pose, baseline and scope audit is recorded in
`proof/round9_audit.json`. All 113 source files, all 145 runtime paint nodes
and all 458 sampled poses are unchanged; the protected baseline is exact.
`git diff --check` passes. Existing NumPy Lab warnings and Godot certificate/
resource-exit diagnostics remain in the logs; no assertion was weakened.

Complete rebuild check (run from the repository root):

```sh
python3 experiments/cutouts/chainbound_gaoler/mq3/probes/rebuild.py --case "$PWD/experiments/cutouts/chainbound_gaoler/mq3" --report "$PWD/experiments/cutouts/chainbound_gaoler/mq3/proof/round9_rebuild.json"
```

## Round8 history

Round8 changed native proof transport and timeout; it preserved runtime paint,
layouts and motion from the director-approved v07 reel. The following results
are historical and do not claim current native v09 proof.

## Round8 director requirements

1. **Data versus screenshots:** RGBA frames and overview screenshots remain under
   the visual runner's isolated `user://` directory. The four data surfaces
   (owners, arm, body, rest_dark) are PNGs in an external temporary directory,
   supplied through `--data-output`. Each runner attempt uses a unique data
   subdirectory, so fallback attempts cannot mix captures. The runner still
   validates every real screenshot's variation and size; the required count is
   derived from the clips: 460 RGBA frames plus 44 overviews.
   A user-directory `data/` subfolder alone would not work because discovery is
   recursive. The global runner and its screenshot checks are unchanged.
2. **Collection and timeout:** the accepted screenshot folder's transport sidecar
   identifies its own data directory. The collector checks every referenced file,
   copies screenshots and masks together, and writes `motion_gate_capture/sha256.json`.
   Masks are under `data/` with portable relative paths; temporary absolute paths
   are excluded. All prior native pixel/ID/provenance/coverage gates still run.
   `--native-timeout` accepts positive finite seconds and defaults to **900** for
   460 five-surface poses under load. Startup watchdog and GUI lease stay intact.
   A missing completed capture now reports the required `--capture-native` step.

The focused regression uses Godot headlessly to exercise the production image
writer with test fixtures, then runs the real screenshot discovery/validator:
blank masks survive as data, while a blank real RGBA screenshot fails. Additional
coverage checks accepted-attempt collection, hashes, missing masks and timeout
forwarding. `--check-poses` continues to exercise all 460 actual capture poses.

## Round8 verification

- Focused suite: `Ran 40 tests in 17.901s` / `OK`.
- Visual runner suite: `Ran 16 tests in 0.300s` / `OK`.
- Python full suite: `Ran 437 tests in 298.914s` / `OK (skipped=61)`.
- Godot full suite: `FULL SUITE RUNTIME: 747.999 seconds (budget 900 seconds)` / `TEST RESULT: PASS`.
- Case validation: `ok: true`, no errors; only the two authorized probe hashes
  changed in the protected baseline. Paint, layout and motion hashes are unchanged.

- Read-only historical v07 bundle: all **504 real screenshots** pass the unchanged
  visual validator; **1,840 data masks** are excluded. The original rest-dark
  variation rejection is reproduced. All **458 native pixel frames** pass the
  existing gates and match the v07 reel; both rest RGBA/ID/provenance calibrations
  are exact. See `proof/round8_v07_raw_native_diagnostic.json`. This is historical
  evidence from the director's saved capture, **not current v08 native proof**.
- Immutable audit: 339 other protected files, all 145 runtime paint nodes and
  all 113 tracked source files are unchanged. `proof/round8_audit.json` records
  exact results and hashes. `git diff --check` passes.

The original `proof/native_rest_round7_result.json` is preserved. The initial
round8 focused failures (a constant-expression parser issue and a macOS temp-path
alias assertion) are retained under explicit `focused_round8_initial_*` names;
final results are recorded separately. No art was regenerated or repainted.

## Retained round7 implementation

1. **Inter-leg shadow ownership:** source L* < 15 pixels owned by thighs/shins
   within 6px Euclidean distance of the other leg's thigh/shin/foot label, pelvis
   label or tabard label boundary move to `under_shadow`, attached to `pelvis`.
   Decoded label masks are intersected with their registered solos to exclude
   antialiased colour-fringe false labels. This transfers **340** source pixels:
   front thigh_far 4, thigh_near 78, shin_far 107, shin_near 0; rear thigh_far 7,
   thigh_near 144, both shins 0. Vacated pixels join hidden trouser support.
   Their RGBA remains exact. The motion gate excludes transformed near-black
   visible-rest pixels from the **same logical leg part**, then rejects remaining
   8-connected L* < 15 regions larger than 12px. All 458 CPU frames have zero
   failing pixels/regions. Native capture adds a fifth provenance-ID surface so
   the same gate can be evaluated with renderer pixels.
2. **Native rest crash:** the capture path calls `apply_pose("rest", 0.0)` for
   rest, avoiding `show_frame`'s lookup of the nonexistent configured clip.
   `--check-poses` executes the actual five-rig capture pose/mask setup headlessly,
   all 460 poses, rest after strike, matching bone transforms and restored depths.
   The collector runs native motion gates before writing accepted clip sheets or
   verification. Successful collection ends with `MOTION GATES: PASS` followed
   by `MAQUETTE_PROOF: PASS`. The focused regression verifies that a failed gate
   cannot write accepted proof. GPU readback still needs the windowed run.

## Explicit implementation choices

To preserve the director's exact-rest requirement, shadow depth is below both
legs' **visible paint** and above replacement hidden fill. Putting it below the
opaque replacement would erase the original rest shadows. All hidden underlays
retain their relative order below it. Each shadow node follows only the pelvis;
all 458 bone-matrix sets match round6 exactly.

The previous near-black hidden palettes/outline would recreate forbidden moving
patches. Hidden thigh/shin palettes and outlines now use sampled trousers colours
at **L* >= 15**; the outline takes the darkest eligible k=6 centroid. Sparse far
thighs still use same-view near-thigh trousers minus 6 L*, retaining source a*/b*
before sRGB clipping/encoding. Both shins use same-view near-thigh trousers with
zero shift, replacing their earlier mixed boot-cuff/shadow value reference.
Near thighs and pelvis retain their own reference. These choices are recorded in
`recipes/rig.json.occlusion_shadow`, fill provenance and the independent gate.

The original nominal median target and tolerance of 8 remain. The rear far-thigh
reference IQR is entirely below 15 (**3.679–13.796**), so it has **0** hidden pixels
in that original range. Its effective mid-tone gate uses the same reference's
non-shadow tail IQR (**21.190–22.530**), containing **128** hidden pixels. Both ranges
and counts remain reported. This explicitly changes the old mid-tone condition;
it is not a claim that the original condition passes. No texture or alternating
pixels were added to evade the connected-region gate.

## Per-part value report

L* is measured per pixel before taking its median. Reference values below use
current post-transfer ownership. Near-thigh reference medians are 17.840 front
and 17.216 rear; sparse targets are 11.840 and 11.216. All ten median differences
are below 8. Only rear/thigh_far uses the effective mid-tone substitution above.

| Region | Own visible pixels | Reference median L* | Hidden median L* | Difference | Original mid-tones | Effective mid-tones |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| front/pelvis | 42 | 1.103 | 4.026 | 2.923 | 1367 | 1367 |
| front/thigh_far | 10 | 11.840 | 15.746 | 3.906 | 1676 | 1676 |
| front/thigh_near | 405 | 17.840 | 16.688 | 1.153 | 1304 | 1304 |
| front/shin_far | 448 | 17.840 | 16.688 | 1.153 | 875 | 875 |
| front/shin_near | 909 | 17.840 | 16.688 | 1.153 | 582 | 582 |
| rear/pelvis | 375 | 13.053 | 12.700 | 0.353 | 1082 | 1082 |
| rear/thigh_far | 0 | 11.216 | 15.956 | 4.740 | 0 | 128 |
| rear/thigh_near | 615 | 17.216 | 16.717 | 0.499 | 1046 | 1046 |
| rear/shin_far | 792 | 17.216 | 16.717 | 0.499 | 773 | 773 |
| rear/shin_near | 1455 | 17.216 | 16.717 | 0.499 | 357 | 357 |

## Round7 proof and provenance (historical)

- `focused_round7.log`: Ran 37 tests in 19.144s / OK.
- `art_gate_round7.log`: Ran 49 tests in 15.585s / OK.
- `python_suite_round7.log`: Ran 434 tests in 276.122s / OK (skipped=61).
- `godot_suite_round7.log`: FULL SUITE RUNTIME: 731.835 seconds (budget 900 seconds) / TEST RESULT: PASS.
- `validation_round7.json`: `ok: true`, no errors; 83 front / 62 rear paint
  nodes, 23 joints each, zero meshes.
- `native_pose_check_round7.log`: `MAQUETTE_NATIVE_POSES: PASS`
  (460 poses; five surfaces; GPU readback not exercised), exit 0.
- Fresh headless sampler/exposure: 458 poses, 42 requests, zero unknown solos.
- Rest identity: front **0**, rear **0** differing RGBA pixels.
- Hidden fill: 39 filled requests / **34,735** pixels; three empty requests;
  **0 magenta** in all **145** runtime images and all 458 CPU motion frames.
- CPU gates: **PASS**; scoped tabard colour **0**, detached small pixels **0**,
  new leg dark-region pixels **0**, rear arm outside **0**, visible rear arm **0**,
  magenta **0**, value failures **0**. All 70 colour part/clip totals and maxima
  are zero; `proof/cpu_motion_gates.json` retains every frame and aggregate row.
- All **113** tracked approved source files match round6. Archive
  `provenance/round6/` contains **449** verified prior files, including director
  native v06 sheets/verification. The original working native files are preserved.
- Maximum bone-matrix difference from round6: **0** over all 458 sampled poses.

`proof/cpu_round7_keyframes.png` and `proof/round7_occlusion_shadow_masks.png` were
visually inspected as CPU/source diagnostics. The eight selected review poses
include front walk 0/47, rear walk 27/34, strike, pin and chain_reel; none has a
detached component of any size. `proof/round7_audit.json` records source/archive,
runtime, transform and component checks.

Initial shadow/fill diagnostics are retained under `round7_initial_*` and
`round7_floor_fill_before_midtone_reconciliation.json`; they are not final proof.
`round7_raw_label_fringe_diagnostic.*` records the rejected unfiltered-label
candidate pass, which incorrectly classified distant fringe labels. Only the
final `*_occlusion_shadow.json` masks/counts and overlay reflect current geometry.
NumPy Lab warnings and Godot certificate/resource-exit diagnostics remain in logs.

## Files and procedural defaults

Implementation: `tools/maquette_cutout.py`, `tests/test_maquette_cutout.py`,
`spec/cutout_workflow.md`, and this case's recipe, segmentation/layout/request/fill
artifacts, probes, proof and archive. Production integration and motion curves
are unchanged. Registered `*_pre_shadow_owners.npy` and per-part shadow masks
retain transfer provenance; `*_visible_dark_*.png` bind the new native ID surface.
Physical shadow-node names retain original source depth suffixes, which may differ
from the corrected logical owner listed in transfer counts.

Existing fill defaults remain: radius 3, k=6, seed 0, sparse threshold 40, recorded
Telea/diffusion method, and the original outline for parts outside the four leg
owners. The new leg outline policy is explicit above. The native five-surface
probe timeout now defaults to 900 seconds, configurable with `--native-timeout`. No `TODO_DESIGN` remains in current case/fill data.

## Reproduce headless verification

```sh
python3 tests/test_maquette_cutout.py
python3 tests/test_art_identity_gate.py
python3 tests/test_visual_probe_runner.py
python3 -m unittest discover -s tests -p 'test_*.py' -v
python3 tools/godot_task_runner.py --task-id rr-02 --stream --timeout 900 -- godot --headless --path . --script tests/run_tests.gd
python3 tools/cutout_workflow.py validate experiments/cutouts/chainbound_gaoler/mq3 --protect all
python3 experiments/cutouts/chainbound_gaoler/mq3/probes/motion_gates.py --case experiments/cutouts/chainbound_gaoler/mq3 --cpu
python3 tools/godot_task_runner.py --task-id rr-02 --stream -- godot --headless --path . --script experiments/cutouts/chainbound_gaoler/mq3/probes/native_motion.gd -- --case "$PWD/experiments/cutouts/chainbound_gaoler/mq3/cutout.json" --check-poses
```

## Windowed proof for the director

Run from this worktree in a window-server session, using a fresh capture directory.
Overview/rest captures are 1920×1080 at 100% UI scale. The motion probe captures
512×512 RGBA, physical paint-node IDs, raw arm/body masks and visible-rest-dark
provenance IDs for all 458 motion frames plus two rest calibrations. The collector
requires current input/output hashes, complete unique frame coverage, exact rest
ownership/provenance calibration and byte-exact RGBA agreement with the primary
verified reel. CPU diagnostics cannot satisfy it. Use a larger `native_timeout`
when the render host is under heavier load; it changes only the capture deadline.
Run each command only after the preceding command succeeds.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-02
case_dir="$PWD/experiments/cutouts/chainbound_gaoler/mq3"
capture_dir=/private/tmp/rr-02-mq3-render-v09
native_timeout=900
python3 tools/visual_probe_runner.py "$case_dir/probes/native_rest.gd" --task-id rr-02 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --expect-size 255x255 --proof-contract "$case_dir/probes/rest_contract.json" --result-manifest "$case_dir/proof/native_rest_round9_result.json" -- --case "$case_dir/cutout.json"
python3 tools/cutout_workflow.py render "$case_dir" --output "$capture_dir" --task-id rr-02
python3 tools/cutout_workflow.py verify-render "$case_dir" --output "$capture_dir"
python3 "$case_dir/probes/motion_gates.py" --case "$case_dir" --capture-native "$capture_dir" --task-id rr-02 --native-timeout "$native_timeout"
python3 "$case_dir/probes/proof.py" --case "$case_dir" --native-output "$capture_dir"
```

Expected final successful collector output:

```text
MOTION GATES: PASS (... Native renderer pixels ...)
MAQUETTE_PROOF: PASS (... native rest RGBA identical; motion gates passed)
```

Reel: `/private/tmp/rr-02-mq3-render-v09/videos/cutout_review.mp4`.
Native counts: `/private/tmp/rr-02-mq3-render-v09/motion_gates.json`.
Ownership/masks: `/private/tmp/rr-02-mq3-render-v09/motion_gate_capture/`.
The collector writes accepted eight-frame clip/view sheets under
`proof/native_keyframes/` only after the gates pass; `proof/native_motion_gates.json`
records the actual native gate result, including failure. Native v09 capture and
its successful gate/collector markers remain outstanding. The successful markers
above are expected output, not an observed native v09 result.
