# vfx-01 round 2 — implementation proof

Uncommitted changes on `b1ff413f7`. The director's existing style values, including `alpha_floor: 0.3`, `alpha_bias: 0.12` and every ramp colour, are unchanged. Only the requested surface-to-ramp mapping was added to the data. No windowed run, commit, publication, or peer review was performed by this worker.

## Requirement coverage

1. **Surface colour fallback.** An empty prepared `feedback_element` now falls back to the event's surface before selecting the ramp. Tests call `CombatOutcomeFeedback.prepare` with a primary spell on the same tile, then check the actual retained run for fire, ice, water, electrified and rubble. Expectations come from the JSON mapping.
2. **Connected line cores.** Conduction, chain hops and their tributaries, lightning bolts/ground discharges, and tether beams use one shared cell rasterizer. It passes through every original path vertex with a one-cell, 8-connected Bresenham core. The core uses the nearest Rec.601 ramp colour at full alpha; only its one-cell halo uses the existing alpha floor/Bayer rules. Both use the same physical screen grid, including cropped targets, board transforms and viewport stretch. A small cell canvas in the existing run's painter slot prevents the approved positive alpha bias from punching holes in even full-alpha cores. It adds no render target. Halo colours reuse sixteen Bayer outcomes per run/colour; fully discarded halos skip neighbourhood construction. The original procedural paths and the off-state drawing remain intact. Headless tests check production paths, endpoints, every zigzag vertex, same-frame submission and one connected component across tile joins/chain tributaries. The render probe additionally checks fully opaque 2×2 cores, exact conduction width and the tether's one-cell Bayer halo.
3. **GPU benchmark.** The harness keeps a fixed logical board and explicitly sizes its SubViewport to 1920×1080 or 3840×2160. It records the actual native window size without resizing it or asserting equality. A real run requires Vulkan. GPU cost is the sum of `RenderingServer.viewport_get_measured_render_time_gpu` for the board and every nested pixel viewport, with timing enabled before drawing. Each off/on pair uses the same authored phase; pairs alternate AB/BA order. A sample holds its phase for `RenderingDevice.get_frame_delay() + 2` frames so queued GPU queries belong to that variant, and is read on the next process tick because Godot handles timestamps after `frame_post_draw`. Every pixel target is redrawn during these held frames. Missing GPU timestamps fail validation. Only the **paired GPU median increase ≤1.0 ms per 1080p workload** gates the benchmark. GPU p95 and all 4K numbers are reported; CPU submission (including all three deferred draw queues) and delivered frame intervals are secondary. Minimum-spec hardware is out of scope.
4. **Lazy surface nodes.** A tile creates `SurfaceGround` and `SurfaceFeedbackPixels` only while it owns active surface feedback or a conduction segment. They are hidden and freed when feedback finishes, clears or becomes invisible. Idle ground returns to its original synchronous draw slot. Tests verify zero such nodes on an initial 9×9 idle board, after each feedback type expires, and after clearing effects. Active retained ground remains below feedback, and props/units remain above it.
5. **Dead additive path removed.** The additive argument, runtime-generated shader, material detection, snapshot field and unreachable additive proof cases are removed. Production uses the existing normal-blend shader.
6. **Mapping in data.** `surface_ramps` contains fire→fire, ice→ice, electrified→lightning, rubble→earth and water→neutral. Water preserves the previous neutral fallback because no water ramp exists. Runtime and test expectations both read the mapping. All pre-existing data values compare equal to HEAD.
7. **Collision and generic glows.** Both remain pixel-styled. The new collision regression also covers an empty element; the run-key sentinel supports it correctly after removal of the additive suffix.

The benchmark follows the [RenderingServer GPU timing contract](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-viewport-get-measured-render-time-gpu), [RenderingDevice frame-delay API](https://docs.godotengine.org/en/stable/classes/class_renderingdevice.html#class-renderingdevice-method-get-frame-delay), and the [4.6.1 timestamp processing order](https://github.com/godotengine/godot/blob/4.6.1-stable/servers/rendering/rendering_server_default.cpp#L119).

## Changed files

- `data/vfx_pixel_style.json`: requested surface mapping; approved existing values preserved.
- `scripts/pixel_fx_layer.gd`: connected core/halo cell canvas; normal-only runs; empty-element sentinel.
- `shaders/pixel_fx_quantize.gdshader`: remove obsolete additive-variant comment.
- `scripts/combat_board_view.gd`: fallback, lazy surface slots, conduction routing/lifetime, chain/tether submission.
- `scripts/elemental_spell_fx.gd`: route lightning paths and supply chain/line bounds.
- `scripts/chain_attack_fx.gd`: route the original main/fork paths through the shared cell renderer.
- `scripts/enemy_mechanics/tether_view.gd`: route the existing beam path before the original off-state drawing.
- `tests/pixel_fx_fixture.gd`: chain/tether/collision proof states.
- `tests/pixel_fx_test.gd`: covered surface colours, idle/expired node counts, connected production paths, endpoint/zigzag/same-frame checks; remove additive-only expectations.
- `tests/pixel_fx_compare_probe.gd`, `tests/pixel_fx_compare_probe_contract.json`: add chain/tether off/on frames and 3× nearest crops; preserve conduction and ice break.
- `tests/pixel_fx_render_probe.gd`, `tests/pixel_fx_render_probe_contract.json`: add conduction/chain/tether core semantics and halo verification; remove additive-only cases.
- `tests/pixel_fx_performance_benchmark.gd`: Vulkan viewport timing, paired sampling and fixed render-target sizes. The existing 16-image performance contract is unchanged.
- `tests/pixel_fx_proof.md`: this handoff.

## Observed validation

- Pixel tests: `PIXEL FX TEST RESULT: PASS (11499 checks, 0 failures)`.
- Fan allocation: `PIXEL FX FAN TARGETS: 24 layers, 422568 cropped texels (12441600 full-screen texels)`.
- Elemental tests: `ELEMENTAL SPELL FX TEST RESULT: PASS`.
- Hash equivalence: `TEST RESULT: PASS`; 4,230 equivalence cases.
- UI identity lint: `Ran 25 tests in 2.939s` / `OK`.
- Python discovery: `Ran 397 tests in 243.733s` / `OK (skipped=61)`.
- All three pixel probes passed headless `--check-only`; this does not execute their GPU assertions.
- Contracts: 229 comparison images, 15 render-semantic images, 16 benchmark images; all required patterns are unique.
- `APPROVED STYLE VALUES UNCHANGED: PASS`.
- Final full Godot suite: `FULL SUITE RUNTIME: 769.604 seconds (budget 900 seconds)` / `TEST RESULT: PASS`; runner exit 0. This run includes the halo-cache optimization.
- Isolated headless benchmark: `PIXEL FX CPU BENCHMARK: PASS (GPU budget pending; CPU report only)`; runner exit 0, 16 rows, 180 pairs per row, no harness errors. GPU values in this CPU-only JSON are zero placeholders, not measurements. Maximum CPU submission increases (lightning): 1080p +1.579 ms median / +2.799 ms p95; 4K +1.803 ms median / +2.946 ms p95.

Logs are `/private/tmp/vfx-01-round2-{pixel,elemental,hash,ui-lint,python,full-godot}.log`, plus `compare-parse.log`, `render-parse.log`, `performance-parse.log` and `performance-cpu.log` with the same prefix. One earlier full-suite run was stopped to fix the empty-element collision case; `full-godot-interrupted.log` is not final proof. No pre-existing assertions were rewritten to hide failures. The director’s prior `surface_conduction_off_crop3x.png` / `surface_conduction_on_crop3x.png` reference pair was inspected; it is not fresh proof of these changes.


Earlier diagnostic CPU runs (`performance-cpu-before-cache.log` and `performance-cpu-two-barriers.log`, with the same `/private/tmp/vfx-01-round2-` prefix) used two deferred barriers and did not consistently include the final cell-canvas draw. Their timings are superseded by this final report, which includes all three draw queues. Repeated per-cell halo colour calculations found during those runs were replaced by a sixteen-entry cache. The CPU-only report includes off/on allocation churn and is secondary evidence, not a GPU gate or a claim about real-renderer frame delivery.

| Viewport | Workload | CPU submission Δ median / p95 (ms) | Frame interval Δ median / p95 (ms) |
|---|---|---:|---:|
| 1920×1080 | idle | +0.012 / +0.449 | -0.046 / +1.177 |
| 1920×1080 | fire | +0.086 / +0.829 | +0.034 / +0.795 |
| 1920×1080 | ice | +0.100 / +1.032 | +0.055 / +1.009 |
| 1920×1080 | lightning | +1.579 / +2.799 | +1.579 / +2.803 |
| 1920×1080 | air | +0.124 / +0.763 | +0.092 / +0.745 |
| 1920×1080 | earth | +0.063 / +0.859 | +0.067 / +0.852 |
| 1920×1080 | fire_aoe | +0.177 / +1.229 | +0.136 / +1.200 |
| 1920×1080 | dragon_fan | +0.155 / +0.966 | +0.086 / +0.788 |
| 3840×2160 | idle | +0.035 / +0.700 | -0.049 / +1.866 |
| 3840×2160 | fire | +0.120 / +1.892 | +0.095 / +1.994 |
| 3840×2160 | ice | +0.120 / +0.782 | +0.062 / +0.789 |
| 3840×2160 | lightning | +1.803 / +2.946 | +1.736 / +2.812 |
| 3840×2160 | air | +0.113 / +0.945 | +0.111 / +0.986 |
| 3840×2160 | earth | +0.124 / +0.665 | +0.108 / +0.636 |
| 3840×2160 | fire_aoe | +0.039 / +0.851 | +0.010 / +0.844 |
| 3840×2160 | dragon_fan | +0.300 / +1.575 | +0.147 / +1.453 |

Complete off/on statistics and individual pairs are in `/private/tmp/vfx-01-round2-performance-cpu.log` and the isolated `user://probes/pixel_fx_performance/performance.json` path printed in that log.

## Proof for the design owner

These commands have **not** been run by this worker: the sandbox has no macOS window-server access. Comparison and semantics use a real 1920×1080 SubViewport at 100% UI scale. The benchmark additionally renders a 3840×2160 SubViewport independently of the native window size. Keep the runner's result manifest and isolated capture directory.

Comparison (229 required PNGs):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/vfx-01 && python3 tools/visual_probe_runner.py --task-id vfx-01 --no-headless --display-driver macos --audio-driver Dummy --timeout 240 --startup-timeout 45 --proof-contract tests/pixel_fx_compare_probe_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/vfx-01-round2-compare.json tests/pixel_fx_compare_probe.gd
```

Capture path: `user://probes/pixel_fx_compare/`. Includes `surface_{conduction,ice_break,chain,tether}_{off,on}.png` and `_crop3x.png`, every original elemental frame/crop/contact sheet, and ranged/AoE comparisons. `comparison.json` records the pairs and crops.

Rendered semantics (15 required PNGs):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/vfx-01 && python3 tools/visual_probe_runner.py --task-id vfx-01 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --proof-contract tests/pixel_fx_render_probe_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/vfx-01-round2-render.json tests/pixel_fx_render_probe.gd
```

Capture path: `user://probes/pixel_fx_render/`, including `{conduction,chain,tether}_solid_core.png`, six gradients, five depth fixtures and cropped Bayer proof.

Vulkan GPU benchmark, run without other benchmarks (16 required PNGs plus JSON):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/vfx-01 && python3 tools/visual_probe_runner.py --task-id vfx-01 --no-headless --display-driver macos --audio-driver Dummy --rendering-method mobile --rendering-driver vulkan --timeout 960 --startup-timeout 45 --proof-contract tests/pixel_fx_performance_benchmark_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/vfx-01-round2-performance.json tests/pixel_fx_performance_benchmark.gd
```

Capture path: `user://probes/pixel_fx_performance/<workload>_{1080,2160}p_on.png` and `performance.json`. Workloads are idle, fire, ice, lightning, air, earth, fire AoE and the twelve-tile dragon fan. JSON retains each paired GPU/frame/submission sample, viewport count, aggregate median/p95, driver, actual window sizes and gate result.

Headless harness reproduction (CPU report only):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/vfx-01 && python3 tools/godot_task_runner.py --task-id vfx-01 --timeout 600 --stream -- godot --headless --path . --script tests/pixel_fx_performance_benchmark.gd -- --submission-only
```

The existing raw geometry equivalence proof remains available:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/vfx-01 && python3 tools/visual_probe_runner.py --task-id vfx-01 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --min-images 32 --expect-size 1920x1080 --result-manifest /private/tmp/labyrinth-inspection-manifests/vfx-01-round2-geometry.json tests/elemental_spell_geometry_equivalence_probe.gd
```

No inspection-fixture command was requested; the owner retains that workflow phase.

## TODO_DESIGN placeholders and chosen defaults

No `TODO_DESIGN` placeholder was added. Existing surface fallback semantics were moved into data without inventing a water palette. No art, icons, audio, fonts, gameplay values, wording or animation timing were authored.

Proof-only defaults:

- Chain/tether comparison progress 0.52, fixed ambient clock 0.37; existing conduction/ice-break phases remain 0.38/0.12.
- Rendered line fixture: start (300,500), end (900,300), tile width 180, phase 0.52, deterministic tether key `pixel-proof`. Colours come from the existing effect's core/halo values.
- Benchmark: 45 warmup frames per variant, 180 paired samples per workload/resolution, alternating first variant, GPU queue delay plus two settling frames, screenshot progress 0.62 and three settle frames. CPU-only mode uses one submission frame and reports no GPU proof.
- Comparison timeout 240 seconds for the additional line captures; benchmark timeout 960 seconds accommodates query settling across 5,760 variant samples; startup watchdog remains 45 seconds. Render semantics stays at 120 seconds, headless benchmark at 600 seconds.
- Previous debug crops, grid/resize fixtures and floor-neighbour test constants are unchanged.

The passing full suite still emits the existing CA-certificate, save-fixture, ObjectDB, `1 resources still in use at exit`, and run-end recap `get_node()` outside-active-tree diagnostics. The latter two also appear in the preceding successful `/private/tmp/vfx-01-feedback-full-godot.log`. No assertion failed and the runner exited 0.

## Open proof

Fresh rendered line/halo semantics, screenshots, visual inspection and Vulkan median GPU numbers remain pending the owner's commands. The secondary headless CPU report shows the lightning overhead above; it is not subject to the requested GPU-only median gate. Neither headless parsing nor CPU timing establishes GPU budget compliance. Minimum-spec hardware validation is explicitly out of scope.
