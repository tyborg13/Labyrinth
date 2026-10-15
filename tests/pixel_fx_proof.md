# vfx-01 round 4 — GPU lines and unique-frame CPU sampling

Uncommitted implementation on `70a477346`. The director approved round-3 correctness but found that held-frame CPU samples concealed the cost of rebuilding lines during gameplay. This worker has no window-server access. Fresh GPU rasterization, comparison captures and Vulkan timing remain owner-run proof; headless results below do not establish them. Protected style data and the original effect geometry/timing are unchanged.

## Requirements

1. **GPU line rasterization.** `pixel_fx_lines.gd` submits each original zigzag with non-antialiased native `draw_polyline`, in a cropped low-resolution target. Core width is one cell; halo width is three cells. Vertices snap to cell centres, with square endpoint caps to include shared endpoints. The line shader maps colours to the element ramp using Rec.601. A shader-local alpha band identifies eligible opaque cores and bypasses Bayer; halos decode their original alpha and retain the global screen-cell Bayer phase. Nearest compositing keeps two-pixel clusters at 1080p. Production no longer builds raster cells, halo neighbourhood dictionaries or meshes. The only CPU geometry operation transforms and snaps the authored vertices into a preallocated packed array. Parsed ramps are shared and bounded to the six authored element identities, including unknown-element fallback.
2. **CPU sampling.** Each of the 180 off/on pairs uses distinct progress, disjoint from the 45 warmup phases. CPU submission is recorded on the first frame of each held sample; later submissions are reported separately and cannot overwrite it. Off/on order reverses each pair. Existing GPU query settling and board-plus-all-pixel-target timing are preserved. The three 1080p line workloads gate on paired CPU submission deltas: median ≤0.3 ms and p95 ≤1.0 ms. The GPU gate remains ≤1.0 ms paired median at 1080p, with at least 90% positive finite samples per variant; p95 and 4K GPU results are report-only.
3. **Cache memory.** The entire per-owner geometry/mesh cache and `_cached_quads` accounting were deleted with `pixel_fx_line_batch.gd`. There is no historical line cache to evict or account for. Current-frame strokes are cleared on every drawing pass. An empty/non-line pass releases the line viewport, drawing and sprite; an inactive run releases the whole owner. Tests cover both transitions and assert that the removed cache implementation cannot be reintroduced unnoticed. The requested non-decrement mutant no longer has an accounting variable to mutate.
4. **Fading cores.** A source core below the data's `alpha_floor` is omitted before the shader's opaque-core flag is applied. Headless tests cover below/equal/above the floor. The windowed probe also checks actual GPU disappearance below it, full opacity at/above it, and exact one-cell width on a horizontal fixture.

The render probe reads the actual GPU core mask per visible stroke for conduction, chain, tether and lightning. It asserts one 8-connected component, coverage of both endpoints and every zigzag vertex, and a narrow corridor around the round-3 path. Conduction and chain also require connected stroke unions. It checks nearest-scaled clusters and the tether's one-cell Bayer halo. Same-frame round-3 captures use the frozen cell renderer, including its old below-floor core behaviour. Differences are reported rather than byte-equality gated, as the director permits small rasterization changes and requests the new fade. The contract now requires 25 captures, all 1920×1080.

## Changed files

- `scripts/pixel_fx_layer.gd`: GPU line routing and shared parsed ramps; remove production CPU rasterization and cache ownership.
- `scripts/pixel_fx_lines.gd` and `shaders/pixel_fx_lines.gdshader`: native low-resolution strokes, quantization, alpha-band core flag, lazy target lifecycle.
- `scripts/pixel_fx_line_batch.gd`: deleted.
- `tests/pixel_fx_test.gd`: current-frame submission, authored vertices, lazy release, floor boundaries, ramp bounds and benchmark gate coverage.
- `tests/pixel_fx_line_reference.gd`: test-only round-3 raster/reference replay.
- `tests/pixel_fx_benchmark_metrics.gd` and `tests/pixel_fx_performance_benchmark.gd`: unique first-frame sampling and median/p95 CPU gates.
- `tests/pixel_fx_render_probe.gd` and its contract: GPU connectivity, core/halo masks, same-frame reference captures and fade/width proof.
- `tests/pixel_fx_proof.md`: this handoff.

## Observed validation

- Pixel tests: `PIXEL FX TEST RESULT: PASS (11672 checks, 0 failures)`.
- Elemental tests: `ELEMENTAL SPELL FX TEST RESULT: PASS`.
- Hash equivalence: `TEST RESULT: PASS`; 4,230 equivalence cases.
- UI identity lint: `Ran 25 tests in 2.979s` / `OK`.
- Compare, render and benchmark scripts passed headless `--check-only`; this does not execute their GPU assertions.
- `APPROVED STYLE VALUES UNCHANGED: PASS`; compare/render/benchmark contracts contain 229/25/20 unique required captures.
- Full Godot suite: `FULL SUITE RUNTIME: 696.086 seconds (budget 900 seconds)` / `TEST RESULT: PASS`; runner exit 0.
- Final isolated CPU benchmark: `PIXEL FX CPU BENCHMARK: PASS (GPU budget pending; CPU report only)`; runner exit 0. All three 1080p CPU gates pass, with `submission_budget_verified: true` and no harness errors.
- `UNIQUE FIRST-FRAME AUDIT: PASS (20 rows, 180 pairs each)`; all recorded submissions use frame 0 and all 180 progress values are distinct within each variant.

Logs: `/private/tmp/vfx-01-round4-{pixel,elemental,hash,ui-lint,compare-parse,render-parse,performance-parse,full-godot,baseline-cpu,candidate-cpu,performance-cpu}.log`. The baseline was measured from clean `70a477346` with the corrected unique-progress harness before production edits. The runs below use the same headless Godot 4.6.1 harness on this machine, 180 pairs and 45 warmup frames. No samples were removed as outliers. The final 20-row run started after the full suite exited, with no other worker-owned engine jobs running.

| Workload / viewport | Round-3 unique-frame submission Δ median / p95 | First GPU-path CPU run Δ median / p95 | Final isolated run Δ median / p95 |
|---|---:|---:|---:|
| Lightning / 1080p | +4.236 / +5.744 ms | +0.0545 / +2.195 ms | +0.0955 / +0.406 ms |
| Chain / 1080p | +0.444 / +1.188 ms | +0.0445 / +1.214 ms | +0.0275 / +0.525 ms |
| Tether / 1080p | +0.119 / +0.697 ms | +0.0995 / +1.652 ms | +0.0660 / +0.428 ms |
| Lightning / 4K | — | — | +0.0435 / +0.510 ms |
| Chain / 4K | — | — | +0.0065 / +0.259 ms |
| Tether / 4K | — | — | +0.0635 / +0.270 ms |

The first candidate passed medians but **failed all three p95 gates**. Its raw off-mode timings also contain substantial variation. This observation does not waive the gate; both runs remain above. The final isolated run passes without sampling/gate changes or discarded outliers. Headless GPU samples are zero and `gpu_budget_verified` is false, as required. These results establish CPU submission cost, not GPU performance or frame delivery on a real renderer.

The final raw report is `/private/tmp/labyrinth-godot-home/vfx-01-1792096476904908000-45782/Library/Application Support/Escape the Umbra Parallel vfx-01-1792096476904908000-45782/probes/pixel_fx_performance/performance.json`.

The supplied `scratchpad/review_vfx_chr/v3/` directory was not present in this worktree or the other registered worktrees. The existing round-3 render manifest at `/private/tmp/labyrinth-inspection-manifests/vfx-01-round3-render.json` was available; its four core captures were inspected. They are prior proof, not round-4 output.

## Proof for the design owner

Run from this worktree. These windowed commands have **not** been run by this worker. Run the benchmark in isolation. The runners print absolute isolated output directories and write the named manifests.

Full on/off comparison (229 images, including conduction and ice break):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/vfx-01 && python3 tools/visual_probe_runner.py --task-id vfx-01 --no-headless --display-driver macos --audio-driver Dummy --rendering-method mobile --rendering-driver vulkan --timeout 240 --startup-timeout 45 --proof-contract tests/pixel_fx_compare_probe_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/vfx-01-round4-compare.json tests/pixel_fx_compare_probe.gd
```

Captures: `user://probes/pixel_fx_compare/` (on/off full frames, 3× crops, contact sheets).

GPU line connectivity, ramp/Bayer/depth checks and round-3 reference comparison:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/vfx-01 && python3 tools/visual_probe_runner.py --task-id vfx-01 --no-headless --display-driver macos --audio-driver Dummy --rendering-method mobile --rendering-driver vulkan --timeout 240 --startup-timeout 45 --proof-contract tests/pixel_fx_render_probe_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/vfx-01-round4-render.json tests/pixel_fx_render_probe.gd
```

Captures: `user://probes/pixel_fx_render/{conduction,chain,tether,lightning}_{solid_core,legacy_cells,core_mask}.png`, `line_alpha_floor.png`, plus existing gradient/depth/Bayer fixtures. Success: `PIXEL FX RENDER PROBE: PASS`.

Vulkan benchmark (20 rows, 1080p and 4K, GPU queries plus first-submission CPU gates):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/vfx-01 && python3 tools/visual_probe_runner.py --task-id vfx-01 --no-headless --display-driver macos --audio-driver Dummy --rendering-method mobile --rendering-driver vulkan --timeout 1200 --startup-timeout 45 --proof-contract tests/pixel_fx_performance_benchmark_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/vfx-01-round4-performance.json tests/pixel_fx_performance_benchmark.gd
```

Captures/report: `user://probes/pixel_fx_performance/<workload>_{1080,2160}p_on.png` and `performance.json`. Required success: `PIXEL FX GPU BENCHMARK: PASS`, with all three 1080p CPU gates also passing.

Headless unique-frame timing reproduction (full 20-row report; append `--line-workloads-only --1080-only` for just the three requested CPU targets):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/vfx-01 && python3 tools/godot_task_runner.py --task-id vfx-01 --timeout 600 --stream -- godot --headless --path . --script tests/pixel_fx_performance_benchmark.gd -- --submission-only
```

## Chosen defaults and open proof

No `TODO_DESIGN` placeholders or new assets. One-/three-cell widths, the floor rule and CPU thresholds come from the director. Implementation-only alpha encoding uses halo alpha ×0.5 and a core flag at alpha 1 (threshold 0.75) in the dedicated line shader. Probe-only mask modes are 0/1/2 for normal/core/halo. Proof phases `(pair + 0.5)/180` and warmup phases `(frame + 0.25)/45` are disjoint; floor proof offsets are ±0.0001. The horizontal width fixture runs (200,200) → (480,200). Existing line fixture positions/progress are unchanged. Render timeout is 240 seconds for per-stroke readback checks; benchmark timeout stays 1200 seconds for the existing 20 rows. Minimum-spec hardware remains out of scope.

Fresh GPU continuity/halo/fade proof, director inspection and Vulkan budget verification remain pending the owner commands. The owner retains commit, peer review, inspection and publication. All changes remain uncommitted.
