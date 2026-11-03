# rr-39 implementation handoff

Feedback 3 changes remain uncommitted on `codex/rr-39`, based on the owner's `179866762` commit. This final fix changes only the retained comparison, its exact empty-mask witness and tests/proof. Runtime, native tie policy, art, motion and density records are unchanged. The pre-existing deletion of `rr37/proof/native_gates.json` was preserved. No commit, peer review, publication or windowed run was performed by this worker.

## Acceptance status

0. **Director underlay and rear hem.** The complete 2,622-pixel front rest footprint is partitioned into exact director-painted torso and far-cloak coverage, including true negative space. The seven boot texels restored beneath the lower spear follow the existing far-foot attachment. Both raw rests have 0-pixel mismatch. Raw source texels outside the footprint are hash-checked against rr-37. Old procedural recipes no longer supply this footprint. The original hidden-torso presentation anchor is retained when the storage crop changes; this avoids unrelated 2-pixel shoulder pockets in cast/death. Rear source UV `[106,205]` now follows the near cloak's hem edge, with the far cloth's own continuation beneath it; rest identity is unchanged.

   **Feedback 1 complete:** applied the authorized `rr39_density_partitions.patch`. The optional hash-bound density hook runs only for declared `source_partitions`. All processed front parts preserve **0 changed texels outside the footprint** against the immutable rr-37 production fixture, use exact source texels inside it, and reproduce the director underlay including air. Both source rests and both production rest assemblies differ by 0 pixels. Fresh headless Godot rest poses also match at 0 pixels; production rest records are re-sealed with explicit `native_pixels:false` CPU evidence in `proof/rest_equivalence.json`. Fresh windowed certification remains the director's next step. The all-unit density command returns `CHECK-OK`; all 2,088 non-Lancer output files are byte-identical and their density/identity records are unchanged.

1. **One production renderer and posed sockets.** Removed the legacy board pool, constructor preparation, RunScene action preparation/clock/effect decoration and legacy strike sampler routing. Existing snapshot/scale probe APIs delegate to the v2 roster. Optional integration `effect_anchors` routes cast/pin/jab/lunge through the selected v2 rig's painted, snapped spear node. Trail sampling uses that same presentation and restores exact live node transforms/textures. Both views and both reflections pass the one-renderer and 2-board-pixel contact checks. The existing full-suite Lancer entrypoint now exercises the v2 roster and protected director clocks instead of the retired renderer's old clip names and clocks; lifecycle, facing, visibility, reduced motion, HUD/padding, echoes and death remain covered. No full suite was run.

2. **Uncovered breadth.** `tools/humanoid_cutout/uncovered_surfaces.py` is an optional figure-agnostic gate with caller-supplied owners, moving occluders, required surfaces and provenance. It transports the entire vacated footprint independently of receiving crops, alpha and mesh support. Actual-colour and tiny-component checks include that complete footprint. The reviewer's `[378,311]`, RGBA `[75,15,3,255]` remnant fails. The immutable rr-37 native fixture retains 19 frames: all 17 selected failures are rejected and both rest controls stay clean. Director paint has its own exact source certificates; ordinary procedural donors remain subject to the existing interior/outline restrictions.

3. **Rerunnable density stage.** The stage owns `proof/logs/density-result.json` and now explicitly passes `--overwrite-result-manifest`. The regression executes the real shell stage twice with stub programs/manifests and verifies all 16 calls, including rest recording, shadow refresh, density check and seal. Default task isolation is rr-39.

## Files changed

- Runtime: `scripts/combat_board_view.gd`, `scripts/run_scene.gd`, `scripts/enemy_strike_points.gd`; `scripts/maquette_cutout_runtime/{effect_sockets,posed_points,strike_points}.gd` and new stable UIDs. Historical files under `scripts/frostglass_lancer_cutout/` remain available for archived fixtures, with no live production consumer.
- Cut/proof tooling: `rr39_underlay.py`, `rr39_fixture.py`, `rr37_{build,surfaces,materials,uncovered,native_checks,density}.py` and `rr37_proof.sh`; the small historical-fixture loader accepts an optional fixture root. `tools/humanoid_cutout/uncovered_surfaces.py` contains the reusable gate.
- Lancer data: source layouts/pieces/checks/tucks/uncovered certificates/material contract and compact proof records under `rr37/`; native rejection corpus and source hashes under `rr39_fixture/`; corresponding production parts/layouts/integration under `assets/units/frostglass_lancer_cutout/`; only Lancer density registry/output/source records and shadow cache entries.
- Tests: `tests/rr37/{renderer_sockets,runtime_checks,production_capture,sidecars}.gd`; `tests/suites/frostglass_lancer_cutout_suite.gd`; `tests/test_rr39_{lancer,proof_rerun}.py`; affected rr-37 Python harness/provenance assertions. The production source oracle uses the same canvas translation/reflection as the rendered rig so float32 guard half-pixel ties are compared under identical conditions.
- Feedback 1 adds `rr39_density.py`, `tools/humanoid_cutout/density_partitions.py`, the opt-in path in `tools/process_board_density.py`, six hook regressions, explicit headless rest sampling and per-clip uncovered totals. Its Lancer-only registry/output records bind the protected mask and prior production inputs by SHA-256.
- The exact path inventory is in `rr39_CHANGED_FILES.txt`.

## Proof for the design owner

No window-server access is available to this worker. Run the existing seven stages in order at 1920×1080, 100% UI scale; judge the resulting clips at 2–4×:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-39 && LABYRINTH_TASK_ID=rr-39 sh experiments/cutouts/frostglass_lancer/rr37_proof.sh density
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-39 && LABYRINTH_TASK_ID=rr-39 sh experiments/cutouts/frostglass_lancer/rr37_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-39 && LABYRINTH_TASK_ID=rr-39 sh experiments/cutouts/frostglass_lancer/rr37_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-39 && LABYRINTH_TASK_ID=rr-39 sh experiments/cutouts/frostglass_lancer/rr37_proof.sh sheets
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-39 && LABYRINTH_TASK_ID=rr-39 sh experiments/cutouts/frostglass_lancer/rr37_proof.sh idle
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-39 && LABYRINTH_TASK_ID=rr-39 sh experiments/cutouts/frostglass_lancer/rr37_proof.sh production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-39 && LABYRINTH_TASK_ID=rr-39 sh experiments/cutouts/frostglass_lancer/rr37_proof.sh review
```

These commands invoke the mandatory visual runner and existing proof contracts. Captures are under `rr37/proof/{native,native_rest,contact_sheets,idle_native,production_native/front,production_native/rear}/`. Reels are `rr37/proof/frostglass_lancer_review.mp4` and `rr37/proof/frostglass_lancer_protagonist_idle.mp4`. Native uncovered metrics are under `rr37/proof/production_case/proof/logs/uncovered_surfaces.json`. No inspection-fixture command was requested; the design owner owns that fixture.

Inspected software construction previews (not native acceptance) are under `rr37/proof/feedback3_cpu/`: front cast 4/12, guard 25, lunge 20 and rear lunge 36, including 4× crops. These are regenerated by `PYTHONPATH=tools:experiments/cutouts/frostglass_lancer python3 experiments/cutouts/frostglass_lancer/rr37_feedback3_preview.py`.

## TODO_DESIGN placeholders

None.

## Chosen defaults

No player-facing defaults. Synthetic density test values are named in `tests/test_rr39_density_partitions.py::FIXTURE`: 6×6 mask, 4×4 crop at `[1,1]`, mask slice `[2:4,2:4]`, source RGBA `[40,60,80,255]`, treated RGBA `[70,90,110,255]`, baseline RGBA `[20,30,50,255]`, invalid offsets `[3,3]` and `[-5,1]`. Proof-only fields in `tests/rr37/renderer_sockets.gd`: board tile `(3,3)`, trail window `(0.2,0.8)`, synthetic effect contact `0.42`, fallback point `(12,34)`. Native diagnostic frame selections are named in `rr39_fixture.py::SELECTION`; the exact remnant coordinates/colour and 2px socket tolerance come from the brief. The existing 3px component threshold and 0.0001 transform tolerance are retained. Boot assignment, source crop anchor and rear hem UV are measured from the approved inputs/existing rig rather than new tuning.

## Open issues

- Fresh windowed captures, native rest certification and director 2–4× acceptance remain pending. The offline rest seal explicitly identifies CPU evidence and does not certify native pixels. Historical failed rr-37 native gate records remain historical.
- macOS headless runs emit existing certificate/resource shutdown warnings; art-identity tests emit existing NumPy colour-conversion warnings. Result and exit status must be taken from the specific logs below.

## Round 0 observed verification (retained history)

- Focused rr-37/rr-39: `Ran 40 tests in 657.511s` / `OK`.
- Production raster: `RR37 FRONT PRODUCTION FRAMES: PASS (512 frames; 0 failures; software raster, native runtime poses)` and the corresponding rear line with 512 frames and 0 failures.
- References (Seer, Thrall, Mirror, Capacitor, Weaver, Mimic, Mortar, Herald, Gloam): `Ran 168 tests in 281.321s` / `OK`.
- Runtime/lifecycle/sockets: `RR37 RUNTIME: PASS (265 checks; headless registration, views, portraits and clocks)`.
- Source and exact treated-production numeric gates: both report `RR37 ALL GATES: PASS (0 unique errors; native=False)`.
- SFX programs: `SFX SYNC HARNESS RESULT: PASS (4243 observations, 0 failures)`, `... (3516 observations, 0 failures)`, `... (1688 observations, 0 failures)`.
- Art identity: `Ran 111 tests in 38.144s` / `OK`.
- Registration: `TEST REGISTRATION AUDIT: PASS (814 scripts; full suite=461, quarantined=29, windowed probe=324)`.
- Shadow: `RR37 SHADOW RECORDS: PASS (2 v2 views; every other unit retained)`; runner exit 0.
- Preservation: `RR39 PRESERVATION: PASS (protected art/motion byte-identical; all non-Lancer registry records unchanged)`.
- Density check: exit 1, reporting `rest rebake needed` for both front and rear rest PNGs because rig part pixels changed. This does not certify exact outside-footprint preservation; that separately known 280-texel issue remains open.
- `git diff --check` and shell syntax check passed.

Round 0 commands, log paths/hashes and its then-incomplete acceptance are retained in `rr37/proof/rr39_verification.json`. Feedback 1 results supersede that density limitation and are recorded in `rr37/proof/rr39_feedback1_verification.json`. Temporary logs are `/private/tmp/labyrinth_codex/rr39-*.log`. Earlier failing attempts were corrected (source tuck air, approved painted-ink provenance, identical source/production proof transforms and the moved storage-crop anchor); stale-input runs were rerun. No final assertion was weakened to accept a failure.

## Feedback 1 observed final verification

- Applied the density hook and registered only the Lancer's six hidden/covered front surfaces. Changed bound mask/baseline inputs, out-of-mask partitions, resized outputs and outside-alpha mutations are rejected. Exact source/air inside and prior production outside are verified independently.
- `python3 tools/process_board_density.py --check` (all units): `CHECK-OK`.
- `RR39 NON-LANCER OUTPUTS: PASS (2088 files byte-identical; 0 changed)`; density registry, output and identity records are unchanged for every other unit. Protected director inputs are byte-identical.
- `RR39 DENSITY PARTITION: PASS (0 changed production texels outside footprint; 0 inside; 0 underlay)`.
- `RR39 FRONT REST: source=0px production-assembly=0px (not native capture)`; rear has the same zero counts.
- `RR39 PRODUCTION REST SEAL: PASS (front=0px rear=0px; native-equivalent CPU; windowed proof pending)`.
- Density-focused tests: `Ran 53 tests in 100.795s` / `OK`.
- Focused rr-37/rr-39 tests: `Ran 48 tests in 681.284s` / `OK`.
- `RR37 FRONT PRODUCTION FRAMES: PASS (512 frames; 0 failures; software raster, native runtime poses)` and corresponding rear 512 / 0. All five uncovered metrics are 0 for front cast, lunge, guard, jab and pin, as well as the complete rear sweep including the repaired hem. Per-clip totals are in `rr37/proof/logs/production_frames.json` and the compact feedback verification record.
- Source and treated-production numeric gates: `RR37 ALL GATES: PASS (0 unique errors; native=False)` for each.
- Art identity: `Ran 111 tests in 41.501s` / `OK`.
- `TEST REGISTRATION AUDIT: PASS (814 scripts; full suite=461, quarantined=29, windowed probe=324)`.
- `RR37 SHADOW RECORDS: PASS (2 v2 views; every other unit retained)`; runner exit 0. The cache bytes are unchanged because this repair does not change the rest silhouette.
- Integration file hashes and both explicit CPU rest-evidence hashes are current. `git diff --check` and `sh -n experiments/cutouts/frostglass_lancer/rr37_proof.sh` passed.
- Fresh 4× software previews are under `rr37/proof/feedback3_cpu/`; front guard 25 and rear lunge 36 were inspected. These are construction aids, not native acceptance captures.

Commands, log SHA-256s and per-clip totals are recorded in `rr37/proof/rr39_feedback1_verification.json`. No full suite or windowed command was run. The earlier seven exact windowed stage commands remain the director's proof sequence.

## Feedback 2: native ties and containment guard

1. **Native uncovered ties:** `tools/humanoid_cutout/uncovered_ties.py` evaluates the same four real-source, independent-axis choices and unchanged `SUBTEXEL_TIE_EPSILON` as the rigid native oracle. Mesh sampling is optional; the default CPU diagnostic is unchanged. It considers the registered weights and their actual native UNORM16 representation. Both CPU and native RGBA must match candidates from the same geometry family. The pixel must have exact source silhouette/outline-boundary provenance; destination-distance allowances are absent. A clean CPU gate and a clean normalized native gate are required. Invalid colours, interior colour ties, components, joint pockets and cross-layer CPU disagreements remain failures. Retired source models cannot certify ties against the current approved source hashes. Reports retain per-pixel candidate, geometry, RGBA and tie counts separately from failures.

   The immutable `rr39_tie_fixture/` retains the director's 64 failing native frames and exact isolated layers/references, with original capture/log hashes. No new native pixels were generated or old bindings re-signed. All 64 errors resolve: **33 outline + 31 missing, 0 remaining**. The report is `rr37/proof/rr39_native_ties.json` (`retained_capture:true`, `current_renderer_proof:false`). All 17 rr-37 failure frames are still rejected and both rest controls remain clean; the reviewer's `[378,311]` remnant still fails after native tie resolution.

2. **Containment guard:** the existing guard is unchanged. New absolute-path, `..` and escaping-symlink regressions each use valid input hashes for both the mask and baseline. Disabling the guard in a test-only mutation makes all three regressions fail for both inputs: six expected failures.

Native weight packing follows Godot 4.6's [Polygon2D weight normalization](https://github.com/godotengine/godot/blob/4.6-stable/scene/2d/polygon_2d.cpp#L226), [UNORM16 packing](https://github.com/godotengine/godot/blob/4.6-stable/servers/rendering/rendering_server.cpp#L764) and [skin transform calculation](https://github.com/godotengine/godot/blob/4.6-stable/servers/rendering/renderer_rd/shaders/skeleton.glsl#L141). These are format constants, not design defaults or error tolerances.

Observed final results:

- Focused tests: `Ran 44 tests in 131.033s` / `OK`.
- Strengthened remnant regression: `Ran 1 test in 1.777s` / `OK`.
- `RR39 NATIVE UNCOVERED TIES: PASS (64 resolved: 33 outline, 31 missing; 0 remaining; exact retained native pixels)`.
- `RR39 RR37 NATIVE REJECTION: PASS (17 rejected frames; 2 clean rest controls)`.
- `RR39 PATH GUARD MUTATION: PASS (guard disabled: all 3 regressions fail for both bound inputs; 6 failures)`.
- Source and production numeric gates each report `RR37 ALL GATES: PASS (0 unique errors; native=False)`.
- All-unit density: `CHECK-OK`. Registration: `TEST REGISTRATION AUDIT: PASS (814 scripts; full suite=461, quarantined=29, windowed probe=324)`.
- `RR39 REST EQUIVALENCE: PASS (front=0px rear=0px; native rest records preserved)`. The old CPU report's byte hashes were stale after the director's native rebake. `rr39_density.py --verify-rests` refreshes that CPU report from fresh headless poses, preserving the native records and all existing assertions.
- Production assets, protected director inputs and density registry/output records have no diff from the owner commit. Shell syntax and `git diff --check` pass.
- The 64 exact 6× native diagnostic crops were inspected at `rr37/proof/logs/rr39-feedback2-native-6x.png`; order is `rr39_tie_fixture/before.json`. This is a retained-capture contact sheet, not a fresh capture.

Detailed commands, log hashes and acceptance are in `rr37/proof/rr39_feedback2_verification.json`. No full suite was run. No `TODO_DESIGN` placeholder is needed. Chosen proof defaults are in `tests/test_rr39_native_ties.py::FIXTURE` and the verification record; native skin format constants (four influences, UNORM16 maximum 65535) follow the engine. All other defaults remain as listed above.

### Feedback 2 proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-39 && LABYRINTH_TASK_ID=rr-39 sh experiments/cutouts/frostglass_lancer/rr37_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-39 && LABYRINTH_TASK_ID=rr-39 sh experiments/cutouts/frostglass_lancer/rr37_proof.sh review
```

The native stage writes `rr37/proof/native/` and `rr37/proof/production_case/proof/logs/uncovered_surfaces.json`; the review reel is `rr37/proof/frostglass_lancer_review.mp4`. Fresh windowed provenance is the only outstanding proof. No inspection-fixture command was requested.

## Feedback 3: clean-checkout retained bindings

The Medium is fixed in the retained fixture comparison only. `rr39_tie_fixture.py` verifies the exact SHA-256, L mode, 255×255 dimensions and all-zero texels of the original empty certificate witness. It canonicalizes that one hash only for the `painted_*` paths declared by the current two layouts. It does not alter the retained manifest, the generator, or any current-renderer binding policy. Paint, geometry, non-empty certificates, undeclared paths and other binding types remain strict.

`tests/test_rr39_retained_bindings.py` proves all 55 empty omissions are equivalent and all six non-empty omissions fail. It also rejects non-empty certificates replaced by empty claims, changed geometry/paint, and zero hashes on non-certificate or undeclared paths.

`tests/test_rr39_clean_checkout.py` creates a test-owned bare shared clone and a detached worktree of committed HEAD; the task repository's refs and Git metadata are untouched. It asserts a clean tracked checkout and zero ignored input files before running the focused suite. CI/default use tests committed HEAD. Because the worker must leave the final fix uncommitted, this run explicitly overlaid only the five fix files; their hashes are recorded. The child verified 55 actually absent optional certificates. No ignored inputs were copied. Temporary proof repository/worktree cleanup is confined to that test-owned directory.

Observed result lines:

```text
Ran 31 tests in 144.277s
OK
RR39 RETAINED BINDINGS: PASS (55 absent optional zero certificates; geometry and paint strict)
RR39 NATIVE UNCOVERED TIES: PASS (64 resolved: 33 outline, 31 missing; 0 remaining; exact retained native pixels)
RR39 RR37 NATIVE REJECTION: PASS (17 rejected frames; 2 clean rest controls)
RR39 CLEAN CHECKOUT: PASS (HEAD 179866762c802b114974e6702624c9aa698c940d; 0 ignored input files; scoped fix overlay=5 files)
Ran 1 test in 172.764s
OK
```

The separate binding-negative run reports `Ran 5 tests in 3.080s` / `OK`. `git diff --check` passes. Logs, exact commands and fix hashes are in `rr37/proof/rr39_feedback3_verification.json`.

Before the owner commits, the observed command was:

```sh
RR39_CLEAN_FIX_OVERLAY=/private/tmp/labyrinth_codex/rr39-feedback3-fix-overlay PYTHONDONTWRITEBYTECODE=1 python3 -m unittest tests.test_rr39_clean_checkout -v
```

After the owner commits these files, the regression directly tests that committed tree:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest tests.test_rr39_clean_checkout -v
```

No `TODO_DESIGN` placeholder or player-facing default was introduced. Chosen proof defaults are named in `PROOF_DEFAULTS`: Git timeout 180 seconds and child-suite timeout 600 seconds. The negative binding fixture uses 64 zero characters. The PNG witness is measured original data, not a chosen paint value. Director acceptance stands; this test-only round has no open implementation issue.
