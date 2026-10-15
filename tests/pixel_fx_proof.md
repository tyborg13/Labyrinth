# vfx-01 round 3 — line batching and benchmark validity

Uncommitted implementation on `82cd1dd99`. The director approved round-2 visuals and reported Vulkan paired GPU medians ≤0.45 ms for all 1080p workloads. This worker has no window-server access; the new rendered equivalence check and Vulkan rerun remain owner-run proof. All director data and production effect geometry/timing are unchanged.

## Requirements

1. **Line CPU cost.** `LineCanvas` now submits one indexed `ArrayMesh` surface for every core and halo in its existing layer. It preserves the previous halo-then-core order within each stroke, stroke order, exact one-cell quads, ramp colours, opaque cores, and Bayer positions. There are no per-cell draw calls. A cache owned by `PixelFxLayer` retains rasterized arc shapes keyed by authored points plus their screen transform; fading/recolouring reuses geometry. Complete meshes are keyed by ordered shape IDs, original colours and element. Unchanged submissions reuse the mesh, including when the review toggle recreates viewports. Geometry changes invalidate the shape key. Cache limits are 1,024 shapes, 32 meshes and 65,536 mesh quads per owner, with LRU eviction; the active canvas keeps its submitted resource alive across eviction. No additional nodes, viewports, shader, or update throttling.
2. **False timestamp failure.** An empty child viewport may report zero while the summed board/pixel sample is valid. Validation now happens per workload/resolution row: each off/on variant needs at least 162 of 180 finite, positive summed GPU samples. Missing samples are excluded from GPU statistics; paired deltas use pairs with two valid samples. Exactly 90% passes, fewer fails, and a row with no queries fails cleanly. The GPU verdict uses paired medians, with ≤1.0 ms at 1080p and report-only 4K/p95. Each row prints its verdict and valid counts. Window focus is recorded as secondary-report metadata. Lightning, chain and tether additionally gate on the requested ≤0.3 ms 1080p median CPU submission delta. GPU validity and CPU gate verdicts remain separate report fields.

The benchmark adds chain and tether at both resolutions. Fixed SubViewport sizes, actual-window-size reporting, board-plus-pixel GPU sum, Vulkan requirement, 45-frame warmup, 180 interleaved pairs, query settling and three deferred submission barriers are preserved. Cache sizes/build counts are collected outside timed samples. Minimum-spec hardware remains out of scope.

## Changed files

- `scripts/pixel_fx_layer.gd`: replace immediate cell drawing with one cached mesh command per line canvas.
- `scripts/pixel_fx_line_batch.gd`: bounded geometry/mesh caches and exact quad batching.
- `tests/pixel_fx_test.gd`: independent old/new cell identity, production lightning/chain/tether/conduction coverage, cache reuse/invalidation/eviction, and GPU-verdict regression tests.
- `tests/pixel_fx_line_reference.gd`: frozen round-2 cell-rendering oracle, used for headless cell maps and real-renderer A/B proof.
- `tests/pixel_fx_benchmark_metrics.gd`: testable valid-sample filtering, paired statistics and row verdict.
- `tests/pixel_fx_performance_benchmark.gd` and its contract: fixed validity check, explicit verdicts, CPU target and chain/tether workloads (20 required images).
- `tests/pixel_fx_render_probe.gd` and its contract: exact rendered RGBA-byte comparisons of the legacy cell drawing and batch for conduction, chain, tether and lightning (20 required images).
- `tests/pixel_fx_proof.md`: this handoff.

## Observed validation

- Pixel tests: `PIXEL FX TEST RESULT: PASS (13297 checks, 0 failures)`, including eviction and zero-query regressions.
- Elemental tests: `ELEMENTAL SPELL FX TEST RESULT: PASS`.
- Hash equivalence: `TEST RESULT: PASS`; 4,230 equivalence cases.
- UI identity lint: `Ran 25 tests in 3.020s` / `OK`.
- Final render and benchmark scripts passed headless `--check-only`; this does not run their GPU assertions.
- `APPROVED STYLE VALUES UNCHANGED: PASS`; both updated proof contracts have 20 unique required captures.
- Replayed the director’s original Vulkan JSON through the new GDScript metrics helper: `RECORDED VULKAN VALIDITY RECHECK: PASS (16 rows, 0 failures)`; every variant has 180/180 valid samples. This validates the false-negative fix on actual recorded data, not new mesh GPU performance. Original report adapter: Apple M5 Pro / Vulkan. Recheck log: `/private/tmp/vfx-01-round3-gpu-report-recheck.log`.
- Full Godot suite: `FULL SUITE RUNTIME: 714.086 seconds (budget 900 seconds)` / `TEST RESULT: PASS`; runner exit 0.
- Final isolated headless benchmark: `PIXEL FX CPU BENCHMARK: PASS (GPU budget pending; CPU report only)`, runner exit 0, 20 rows ×180 pairs, no harness errors. `submission_budget_verified: true`; all three 1080p line workloads pass the ≤0.3 ms gate. Cache bounds pass for every owner.

Logs: `/private/tmp/vfx-01-round3-{pixel,elemental,hash,ui-lint,render-parse,performance-parse,full-godot,baseline-cpu,performance-cpu}.log`. Baseline was captured from the clean round-2 HEAD before implementation. The baseline and final CPU runs used Godot 4.6.1 headless on this same machine, the same benchmark phases/warmup/pair counts and no other engine benchmark. These are submission timings, not real-renderer frame delivery or GPU timings.

| Workload / viewport | Baseline submission Δ median / p95 | Batched submission Δ median / p95 |
|---|---:|---:|
| Lightning / 1080p | +1.933 / +3.390 ms | +0.0825 / +0.466 ms |
| Lightning / 4K | +2.549 / +5.078 ms | +0.0915 / +0.680 ms |
| Chain / 1080p | — (new workload) | +0.0665 / +0.499 ms |
| Chain / 4K | — (new workload) | +0.0360 / +0.441 ms |
| Tether / 1080p | — (new workload) | +0.0265 / +0.561 ms |
| Tether / 4K | — (new workload) | -0.0105 / +0.400 ms |

The full report includes each paired sample and secondary frame-interval median/p95. Final lightning frame-interval deltas are +0.0705 / +0.468 ms at 1080p and +0.0530 / +0.756 ms at 4K. Across the entire board, the final cache holds 563 shapes (28,868 core cells and 62,456 halo cells) and 77 meshes (65,676 quads); all **per-owner** limits pass. Rasterization and mesh-build counts stop increasing after the first resolution because the logical cell shapes are unchanged. Scene node and viewport counts are unchanged by batching. These counters describe retained geometry; they are not a process-memory measurement.

The final raw report is `/private/tmp/labyrinth-godot-home/vfx-01-1792093961134811000-34536/Library/Application Support/Escape the Umbra Parallel vfx-01-1792093961134811000-34536/probes/pixel_fx_performance/performance.json`. The first candidate run is retained as `/private/tmp/vfx-01-round3-performance-cpu-initial.log`; the table above uses the final run with CPU gates/cache counters. Both candidate runs meet the target. Headless GPU sample counts are correctly zero, and `gpu_budget_verified` remains false.

## Proof for the design owner

Run the Vulkan benchmark without other benchmarks. Expected success line: `PIXEL FX GPU BENCHMARK: PASS`; the output also shows per-row GPU verdicts and the 1080p CPU submission target. The timeout is extended from 960 to 1200 seconds for 20 rather than 16 rows; it is not a launch retry.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/vfx-01 && python3 tools/visual_probe_runner.py --task-id vfx-01 --no-headless --display-driver macos --audio-driver Dummy --rendering-method mobile --rendering-driver vulkan --timeout 1200 --startup-timeout 45 --proof-contract tests/pixel_fx_performance_benchmark_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/vfx-01-round3-performance.json tests/pixel_fx_performance_benchmark.gd
```

Captures/report: `user://probes/pixel_fx_performance/<workload>_{1080,2160}p_on.png` and `performance.json`; the runner prints the isolated absolute directory.

Exact rendered pixel identity (1920×1080, 100% UI scale):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/vfx-01 && python3 tools/visual_probe_runner.py --task-id vfx-01 --no-headless --display-driver macos --audio-driver Dummy --rendering-method mobile --rendering-driver vulkan --timeout 180 --startup-timeout 45 --proof-contract tests/pixel_fx_render_probe_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/vfx-01-round3-render.json tests/pixel_fx_render_probe.gd
```

Captures: `user://probes/pixel_fx_render/{conduction,chain,tether,lightning}_{solid_core,legacy_cells}.png`, plus the existing gradient/depth/Bayer fixtures. The probe asserts byte-for-byte equality of each legacy/batched image before passing, in addition to the original core/halo semantic checks. These commands were not run by this worker.

Headless timing reproduction:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/vfx-01 && python3 tools/godot_task_runner.py --task-id vfx-01 --timeout 600 --stream -- godot --headless --path . --script tests/pixel_fx_performance_benchmark.gd -- --submission-only
```

## Defaults and open proof

No `TODO_DESIGN` placeholders, assets, player-facing values, or timing changes. Implementation-only cache caps are listed above. New proof-only defaults: 0.3 ms submission threshold and 90% nonzero GPU coverage come directly from the director; chain/tether use their existing fixtures and benchmark progress sequence; lightning identity uses the existing 180-pixel fixture at progress 0.52, centered at (600,400), with `LINE_FIXTURE.lightning_zigzag` vertices (300,500), (450,320), (550,390), (900,300). Render timeout 180 seconds allows the old/new captures; benchmark timeout 1200 seconds allows the added rows.

Fresh rendered byte identity and Vulkan timings remain pending the owner commands. The owner retains commit, peer review, inspection and publication. This worker leaves all changes uncommitted.
