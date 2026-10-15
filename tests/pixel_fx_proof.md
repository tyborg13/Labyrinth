# vfx-01 feedback 1 — implementation proof

These fixes are uncommitted on top of director commit `3c19f5e6f`. The approved `data/vfx_pixel_style.json` is unchanged (`alpha_floor: 0.3`, `alpha_bias: 0.12`). The design owner owns windowed proof, inspection, review, commits and publication. This worker did not run a windowed engine, commit or peer review.

## Changed files

- `scripts/pixel_fx_layer.gd`, `shaders/pixel_fx_quantize.gdshader`: cropped targets, global Bayer origin, native texture slots, CPU oracle precision.
- `scripts/elemental_spell_fx.gd`: appended conservative geometry-bound helper; every existing drawing function is byte-for-byte unchanged from HEAD.
- `scripts/combat_board_view.gd`: surface and telegraph painter slots, interleaved trap textures, crop plumbing.
- `tests/pixel_fx_fixture.gd`, `tests/pixel_fx_test.gd`: approved-data assertions, depth, stretch, resize, bounds and fan coverage.
- `tests/pixel_fx_compare_probe.gd`, `tests/pixel_fx_compare_probe_contract.json`: conduction and ice-break pairs.
- `tests/pixel_fx_render_probe.gd`, `tests/pixel_fx_render_probe_contract.json`: floor boundaries and cropped Bayer semantics.
- `tests/pixel_fx_performance_benchmark.gd`, `tests/pixel_fx_performance_benchmark_contract.json`: twelve-tile breath, 4K reporting and corrected on-state captures.
- `tests/pixel_fx_proof.md`: this handoff.

## Feedback coverage

1. **Tests read data.** The test reads the JSON independently, derives half-alpha Bayer population from its floor/bias and checks immediately below/above the floor at the lowest Bayer threshold. The CPU oracle rounds the uploaded bias and threshold to float32, matching Color/shader precision for exact-threshold comparisons. GPU alpha bands use adjacent RGBA8 values around the approved floor; the probe asserts both their raw alpha and resulting visibility.
2. **Depth.** Each tile's retained ground stays below `SurfaceGround`; `SurfaceFeedbackPixels` follows it, below the original host's path, props and units. Both children deliberately use `show_behind_parent`; tests also check their sibling order against every visible retained ground layer. Surface feedback, conduction and breaks are pixel-styled; breaking and arriving elements keep separate ramps and original order. Telegraphs have a retained pass immediately before the effects host. Trap activation textures occupy native-resolution slots between their corresponding pixel runs. Existing tile hosts, IDs, scene maps, procedural geometry, timings, input, analytics and saves are preserved.
3. **Cost.** Each run unions conservative local geometry bounds, transforms to screen coordinates, rounds outward to grid cells, adds one cell of margin and clips to the viewport. Composites retain nearest filtering; the shader receives the crop's screen-cell origin so Bayer phase cannot shift with a crop. Conduction allocates targets only for tiles owning floor-path segments; the other tiles retain no pixel targets. These are safe analytical bounds, not a GPU alpha readback or a tight per-frame raster trim. A test checks the boxes against actual command bounds over eight phases, both depth passes and motion modes. The 1080p twelve-tile fan uses **422,568** low-resolution texels across 24 layers versus **12,441,600** for full-screen targets (96.6% fewer). The benchmark measures both 1920×1080 and 3840×2160; only 1080p is gated at +1.0 ms median/p95, while 4K is reported.
4. **Window scaling.** Tests use `size_2d_override` plus `size_2d_override_stretch` and verify physical grid size and transform cancellation with board zoom/fractional pan. The existing viewport-only resize test verifies that retained hosts redraw without changing board logical size.
5. **Rec.601 / resize.** CPU red/green/blue impulses and the shader constants pin `(0.299, 0.587, 0.114)`. Tests cover the resize signal connection and its resulting grid refresh. The new cropped GPU fixture checks exact one-cell padding and screen-anchored dithering.

The command-bounds API is test-only: Godot's [4.6.1 implementation](https://github.com/godotengine/godot/blob/4.6.1-stable/servers/rendering/rendering_server.cpp#L1675) returns empty bounds in exported builds. Production uses the portable analytical boxes.

## Observed validation

- Pixel tests: `PIXEL FX TEST RESULT: PASS (10822 checks, 0 failures)`; includes 720 nonempty geometry-bound cases.
- Elemental tests: `ELEMENTAL SPELL FX TEST RESULT: PASS`.
- Hash equivalence: `TEST RESULT: PASS`, 4,230 equivalence cases.
- UI lint: `Ran 25 tests in 3.164s` / `OK`.
- All three pixel probe scripts passed headless `--check-only`. This does not execute their GPU assertions.
- JSON proof contracts parse and contain unique required images: comparison 221, render semantics 17, performance 16.
- `APPROVED DATA UNCHANGED: PASS`.
- `EXISTING ELEMENTAL DRAWING SOURCE UNCHANGED: PASS (bounds helper appended)`.
- Python discovery: `Ran 397 tests in 272.345s` / `OK (skipped=61)` (optional audio environments/modules).
- Full Godot suite: `FULL SUITE RUNTIME: 730.711 seconds (budget 900 seconds)` / `TEST RESULT: PASS`; runner exit 0.
- Isolated CPU benchmark: `PIXEL FX CPU BENCHMARK: PASS (GPU budget pending)`; runner exit 0. Maximum increases: 1080p +0.260 ms median / +0.844 ms p95; 4K +0.240 ms median / +0.693 ms p95.

Logs use `/private/tmp/vfx-01-feedback-`: `pixel.log`, `elemental.log`, `hash.log`, `ui-lint.log`, `full-godot.log`, `python.log`, and the three `*-parse.log` files.

The first expanded CPU measurement reported `PIXEL FX CPU BENCHMARK: FAIL (GPU budget pending)`: earth at 1080p had +0.142 ms median / +3.536 ms p95. The run overlapped other checks; it is preserved in `performance.log`, not treated as a pass. Its largest 4K increases were +0.211 ms median / +0.793 ms p95 (air). The subsequent isolated run passed with no worker tests running alongside it; its complete measurements follow. An earlier full-suite run was intentionally interrupted to fix empty conduction allocations; the subsequent final run passed and is the full-suite proof. Headless CPU timings do not establish GPU/frame-budget compliance.

| Viewport | Workload | Off median / p95 (ms) | On median / p95 (ms) | Delta median / p95 (ms) |
|---|---|---:|---:|---:|
| 1920×1080 | idle | 0.204 / 0.275 | 0.183 / 0.251 | -0.021 / -0.024 |
| 1920×1080 | fire | 3.383 / 3.860 | 3.543 / 4.004 | +0.160 / +0.144 |
| 1920×1080 | ice | 3.529 / 4.037 | 3.505 / 3.854 | -0.024 / -0.183 |
| 1920×1080 | lightning | 3.522 / 4.335 | 3.648 / 4.161 | +0.126 / -0.174 |
| 1920×1080 | air | 3.868 / 4.403 | 4.128 / 5.247 | +0.260 / +0.844 |
| 1920×1080 | earth | 3.941 / 4.754 | 3.968 / 4.604 | +0.027 / -0.150 |
| 1920×1080 | fire_aoe | 3.979 / 4.506 | 4.013 / 4.382 | +0.034 / -0.124 |
| 1920×1080 | dragon_fan | 4.054 / 7.220 | 3.944 / 7.080 | -0.110 / -0.140 |
| 3840×2160 | idle | 0.180 / 0.289 | 0.181 / 0.318 | +0.001 / +0.029 |
| 3840×2160 | fire | 3.298 / 4.409 | 3.467 / 4.128 | +0.169 / -0.281 |
| 3840×2160 | ice | 3.216 / 3.732 | 3.288 / 3.769 | +0.072 / +0.037 |
| 3840×2160 | lightning | 3.091 / 3.578 | 3.216 / 4.271 | +0.125 / +0.693 |
| 3840×2160 | air | 3.417 / 3.976 | 3.466 / 3.829 | +0.049 / -0.147 |
| 3840×2160 | earth | 3.556 / 4.213 | 3.427 / 4.076 | -0.129 / -0.137 |
| 3840×2160 | fire_aoe | 3.735 / 4.473 | 3.975 / 4.679 | +0.240 / +0.206 |
| 3840×2160 | dragon_fan | 3.688 / 6.564 | 3.730 / 6.813 | +0.042 / +0.249 |

Final log: `/private/tmp/vfx-01-feedback-performance-isolated.log`. The isolated JSON report is printed under that run's `user://probes/pixel_fx_performance/performance.json`.

## Proof for the design owner

No windowed commands below were attempted. Use the required runner and keep its isolated output path/result manifest. Captures use 100% UI scale; comparison and semantics are 1920×1080. The performance command also requests the explicitly required 3840×2160 window and render target. Use a fresh manifest filename for a subsequent run.

Comparison: all original elemental frames, off/on 3× nearest crops and contact sheets, ranged/AoE attacks, plus conduction and ice break:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/vfx-01 && python3 tools/visual_probe_runner.py --task-id vfx-01 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 45 --proof-contract tests/pixel_fx_compare_probe_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/vfx-01-feedback1-compare.json tests/pixel_fx_compare_probe.gd
```

Planned paths: `user://probes/pixel_fx_compare/`, including `surface_{conduction,ice_break}_{off,on}.png` and matching `_crop3x.png`; `comparison.json` records all pairs. Existing sheets are 1280×2880 with off on the left, on on the right.

GPU semantics: ramp entries, alpha floor neighbors, Bayer stability, cropped screen phase, nearest clusters, and normal/additive depth:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/vfx-01 && python3 tools/visual_probe_runner.py --task-id vfx-01 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --proof-contract tests/pixel_fx_render_probe_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/vfx-01-feedback1-render.json tests/pixel_fx_render_probe.gd
```

Planned paths: `user://probes/pixel_fx_render/<element>_gradient.png`, `<element>_depth_{mix,add}.png`, and `fire_cropped_dither.png`.

Matched frame benchmark: idle, five elements, three-cell AoE and twelve-tile dragon fan, 1080p/4K, both ordering directions:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/vfx-01 && python3 tools/visual_probe_runner.py --task-id vfx-01 --no-headless --display-driver macos --audio-driver Dummy --timeout 480 --startup-timeout 45 --proof-contract tests/pixel_fx_performance_benchmark_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/vfx-01-feedback1-performance.json tests/pixel_fx_performance_benchmark.gd
```

Planned paths: `user://probes/pixel_fx_performance/<workload>_{1080,2160}p_on.png` and `performance.json`. Run focused without other benchmark processes. CPU-only reproduction:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/vfx-01 && python3 tools/godot_task_runner.py --task-id vfx-01 --timeout 600 --stream -- godot --headless --path . --script tests/pixel_fx_performance_benchmark.gd -- --submission-only
```

Unchanged pre-pixelation geometry proof and existing spell proof:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/vfx-01 && python3 tools/visual_probe_runner.py --task-id vfx-01 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --min-images 32 --expect-size 1920x1080 --result-manifest /private/tmp/labyrinth-inspection-manifests/vfx-01-feedback1-geometry.json tests/elemental_spell_geometry_equivalence_probe.gd

cd /Users/borgerding/workspace/Labyrinth.worktrees/vfx-01 && python3 tools/visual_probe_runner.py --task-id vfx-01 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 45 --proof-contract tests/elemental_spell_effects_proof.json --result-manifest /private/tmp/labyrinth-inspection-manifests/vfx-01-feedback1-spells.json tests/elemental_spell_effects_probe.gd
```

Planned paths: `user://probes/elemental_geometry_equivalence/` and `user://probes/elemental_spell_effects_v1/`. No inspection-fixture command was requested; that phase remains assigned to the owner.

## TODO_DESIGN placeholders

None. No assets, ramps, authored geometry or gameplay values were designed or changed.

## Chosen defaults (proof only)

- Surface fixture phases: ice break 0.12 to retain leaving ground; conduction and other feedback 0.38. Fixed ambient clock 0.37. Surface state and poses are named fixture fields.
- Bounds fixture: point (700,600), size 200, eight named phases, release lift (0,80), travel offsets (300,80)/(300,0), both depth/motion modes. Floor epsilon 0.0001.
- Cropped GPU fixture: (103.5,105.25,200,120), alpha floor +0.1; low-threshold floor samples at (100,180)/(100,272). Other rectangles and sample stride retain the initial probe values.
- Benchmark screenshot phase 0.62 and three settle frames. Timing retains 45 warmup/180 sampled frames per round and two rounds. The twelve-cell saved fan is an explicit fixture, not a change to current combat targeting.
- Existing comparison crop: 640×360, lift 110 pixels, 3× nearest; three settle frames. Existing transform fixture remains position (37.25,19.75), scale 1.17.
- Performance timeout 480 seconds windowed / 600 seconds headless for the doubled resolution/workload coverage; other command timeouts remain 180/120 seconds.

## Open issues

- Fresh GPU semantics, windowed captures, visual inspection, and 1080p +1.0 ms frame-budget compliance remain unverified in this sandbox. The 4K GPU result is also pending.
- The initial CPU p95 miss and the passing isolated rerun are both recorded above; real-renderer performance still needs verification.

The successful full suite emitted CA-certificate, intentional save/analytics fixture and ObjectDB diagnostics, including `ERROR: 1 resources still in use at exit` in the run-score child. The run-end recap `get_node()` outside-active-tree errors also occur in the earlier pre-feedback successful log (`/private/tmp/vfx-01-full-godot-final.log`). No existing assertions were changed.
