# vfx-01 implementation proof

Implementation is uncommitted on `codex/vfx-01`. The design owner owns review, renderer inspection, the inspection fixture, commits and publication. No peer review, Git mutation or windowed engine run was performed by this worker.

## Changed files

- `data/vfx_pixel_style.json` (new; director data copied exactly).
- `scripts/pixel_fx_layer.gd` and `shaders/pixel_fx_quantize.gdshader` (new).
- `scripts/elemental_spell_fx.gd` and `scripts/combat_board_view.gd` (routing/plumbing only).
- `tests/pixel_fx_fixture.gd` and `tests/pixel_fx_test.gd` (new).
- `tests/pixel_fx_compare_probe.gd` and `tests/pixel_fx_compare_probe_contract.json` (new).
- `tests/pixel_fx_render_probe.gd` and `tests/pixel_fx_render_probe_contract.json` (new).
- `tests/pixel_fx_performance_benchmark.gd` and `tests/pixel_fx_performance_benchmark_contract.json` (new).
- `tests/pixel_fx_proof.md` (this handoff).

## Contract coverage

1. **Grid:** `PixelFxLayer` uses the physical viewport height, the director's rounding rule, a transparent low-resolution SubViewport and nearest compositing. Inverse screen transforms keep the grid at the screen origin under fractional board positioning and zoom. Viewport-only changes invalidate the retained source. Headless checks cover 1080, 1440 and 2160 heights.
2. **Ramp:** the supplied JSON is copied verbatim. The shader selects the nearest Rec.601 luminance from that element's five colors. Unknown elements resolve to neutral. The CPU oracle validates a gradient against all six ramps; the renderer probe checks the real shader and exact output ramp entries.
3. **Alpha:** a fixed 4×4 Bayer matrix (normalized by 16), strict `alpha > threshold`, and the supplied alpha floor/bias produce binary alpha. The shader converts the transparent source viewport's premultiplied RGB back to straight RGB before luminance comparison. The renderer probe checks the actual raster, binary alpha, repeated frames and constant 2×2 clusters.
4. **Depth/blend:** procedural entry points submit their unchanged drawing into the same retained floor/back/front hosts. Consecutive calls only share a target if their element and blend agree. Current elemental primitives use normal blend; an additive source uses the second shader variant and a separate target. Existing tile nodes, ids and unit order are unchanged. Dragon presentation already calls these entry points, so neither its geometry nor `AttackFxLibrary` requires edits. Trap transforms are recorded and replayed without changing the original anchor/scale. Raw geometry/hash callers remain outside the routing path. The focused test covers all five elements, ranged and area impacts, reduced motion, dragons, overlapping traps, clearing, toggling, resize, source blend detection, and same-process-frame draw submission.
5. **Review toggle:** the JSON remains the runtime default and is enabled. Probes use an in-memory override to pair identical presentations without editing the protected data. There is no player setting.

Gameplay, action timing, analytics, saves, input and asset files are unchanged. No art, font or audio asset was created or downloaded. No TODO_DESIGN placeholders were needed.

## Observed headless validation

- `tests/pixel_fx_test.gd`: `PIXEL FX TEST RESULT: PASS (9838 checks, 0 failures)`.
- `tests/elemental_spell_fx_test.gd`: `ELEMENTAL SPELL FX TEST RESULT: PASS`.
- `tests/elemental_fx_hash_equivalence_test.gd`: `TEST RESULT: PASS`; 4,230 hash-equivalence cases.
- Full Godot suite: `TEST RESULT: PASS`; final complete run: `FULL SUITE RUNTIME: 761.927 seconds (budget 900 seconds)`, runner exit 0. The earlier complete run also passed in 687.709 seconds.
- Python discovery: `Ran 397 tests in 231.775s`, `OK (skipped=61)`. Skips are optional audio environments/modules; no dependencies were installed.
- UI identity lint: `Ran 25 tests in 2.722s`, `OK` (also included in Python discovery).
- Comparison, renderer-oracle and performance scripts pass `--headless --check-only` through the Godot runner. This is parser validation, not renderer proof.
- Source comparison: `PRE-PIXELATION SOURCE EQUIVALENCE: PASS (only five routing guards and one preload differ)`.
- All three new JSON proof contracts parse successfully; `git diff --check` passes.

Logs are in `/private/tmp/vfx-01-pixel-final.log`, `/private/tmp/vfx-01-elemental.log`, `/private/tmp/vfx-01-full-godot-final.log`, `/private/tmp/vfx-01-python.log` and `/private/tmp/vfx-01-performance-final-isolated.log`.

The corrected CPU benchmark reported `PIXEL FX CPU BENCHMARK: PASS (GPU budget pending)`. Its largest observed increases were +0.131 ms median and +0.950 ms p95. These CPU numbers do not establish the renderer frame budget. Its JSON is under the isolated runner's `user://probes/pixel_fx_performance/performance.json`; the absolute path is printed in the performance log. An intermediate benchmark attempt waited on a render-frame signal that the dummy renderer does not emit and timed out at 300 seconds. The headless path now uses deferred draw-queue barriers and completes normally.

## Proof for the design owner

These commands are **not run** in the worker sandbox. They require macOS window-server access. Each uses the mandatory real-renderer runner. Keep each run's new result manifest; use a fresh filename if rerunning.

Paired production scene frames for every element, including preview/release/travel/contact/burst/peak/tail/end/clear/reduced-motion and depth frames, plus ranged and area attacks:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/vfx-01 && python3 tools/visual_probe_runner.py --task-id vfx-01 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 45 --proof-contract tests/pixel_fx_compare_probe_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/vfx-01-compare-20261015.json tests/pixel_fx_compare_probe.gd
```

Planned captures: `user://probes/pixel_fx_compare/<element>_<phase>_{off,on}.png`, the corresponding `_crop3x.png`, `<element>_contact_sheet_off_on.png`, and `attack_{ranged,aoe}_{20_travel,40_peak}_{off,on}.png`. `comparison.json` records frame progress, crop coordinates and contact-sheet row order. Full captures and 3× crops are 1920×1080; sheets are 1280×2880, with off on the left and on on the right. The inherited production fixture forces 100% UI scale. No captured PNGs exist yet.

GPU oracle for palette entries, alpha, Bayer stability, nearest sampling, depth and normal/additive compositing:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/vfx-01 && python3 tools/visual_probe_runner.py --task-id vfx-01 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --proof-contract tests/pixel_fx_render_probe_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/vfx-01-render-20261015.json tests/pixel_fx_render_probe.gd
```

Planned captures: `user://probes/pixel_fx_render/<element>_gradient.png` (including neutral) and `<element>_depth_{mix,add}.png`, all 1920×1080.

Matched production-board frame benchmark, with reversed off/on ordering, all five spells, idle and a multi-tile area burst; fails if median or p95 increases by more than 1.0 ms:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/vfx-01 && python3 tools/visual_probe_runner.py --task-id vfx-01 --no-headless --display-driver macos --audio-driver Dummy --timeout 240 --startup-timeout 45 --proof-contract tests/pixel_fx_performance_benchmark_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/vfx-01-performance-20261015.json tests/pixel_fx_performance_benchmark.gd
```

Planned captures/report: `user://probes/pixel_fx_performance/<workload>_on.png` and `performance.json`. Run with the window focused and without other benchmark processes. Headless CPU-only reproduction:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/vfx-01 && python3 tools/godot_task_runner.py --task-id vfx-01 --stream -- godot --headless --path . --script tests/pixel_fx_performance_benchmark.gd -- --submission-only
```

Unchanged pre-pixelation geometry reference comparison:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/vfx-01 && python3 tools/visual_probe_runner.py --task-id vfx-01 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --min-images 32 --expect-size 1920x1080 --result-manifest /private/tmp/labyrinth-inspection-manifests/vfx-01-geometry-20261015.json tests/elemental_spell_geometry_equivalence_probe.gd
```

Planned captures: `user://probes/elemental_geometry_equivalence/*_{reference,candidate}.png`. This probe has no routing host; its geometry/hash and tight pixel-equivalence assertions remain unchanged.

Existing production spell probe:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/vfx-01 && python3 tools/visual_probe_runner.py --task-id vfx-01 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 45 --proof-contract tests/elemental_spell_effects_proof.json --result-manifest /private/tmp/labyrinth-inspection-manifests/vfx-01-existing-spells-20261015.json tests/elemental_spell_effects_probe.gd
```

Planned captures: `user://probes/elemental_spell_effects_v1/*.png`. No inspection-fixture command was requested by this unit; fixture creation remains assigned to the design owner.

## Chosen defaults (proof only)

- Headless transform fixture: position `(37.25, 19.75)`, scale `(1.17, 1.17)`, point `(200, 200)`, size `100`, phase `0.38`, recorded in `TRANSFORM_FIXTURE`.
- Fixture coordinates reuse the existing spell proof: source `(2,4)`, target `(5,4)`, 9×9 board; the additional area fixture uses three cells. Fixtures are named fields in `pixel_fx_fixture.gd`.
- Comparison crop: 640×360, lifted 110 pixels toward the effect, enlarged exactly 3× using nearest. Contact-sheet rows are named in `SHEET_PHASES`; three frames settle each screenshot.
- Renderer oracle: named debug rectangles, color, alpha bands and sample stride of 7; three settle frames. These are test inputs, not authored art or runtime defaults.
- Benchmark: 45 warmup frames and 180 measured frames per round, reused from the existing elemental benchmark; two rounds reverse the variant order. Windowed timing disables vsync and requires window focus. Headless timing excludes the delivery throttle.
- Windowed command timeouts: comparison/existing-spells 180 seconds, oracle/geometry 120 seconds, performance 240 seconds; scene startup watchdog 45 seconds. These accommodate the explicit multi-image/frame workloads.

## Open items

- Real-renderer images, shader execution, visual inspection, and the +1.0 ms frame budget remain unverified because this sandbox has no window-server access. The design owner must run the commands above.
- `parallel_task.py status` reported an empty acceptance/proof contract (`contract_ready: false`), despite the supplied workflow split describing it as already recorded. This worker used the brief as its contract and did not alter owner-managed task metadata.
- The successful full suite emitted the macOS CA-certificate diagnostic, deliberate analytics/save-failure fixture diagnostics, ObjectDB cleanup warnings, and `ERROR: 1 resources still in use at exit`. The resource cleanup diagnostic also occurred in `run_score_test` in both full runs; its baseline status was not established. Runner exit was 0, and no existing assertions were changed.
