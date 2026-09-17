# Combat art treatment verification — 2026-09-16

## Requirement and result

Implemented shared luminance/color calibration, restrained world grading, ambient/contact shading, coherent cast direction, local diffuse light wash, and directional silhouette rim light. Background integration is explicitly deferred. Rules, input, camera framing, HUD and background assets are unchanged.

Source hashes in `source-hashes.json` identify the runtime/probe revision verified below. Design and intentional approximations are in `../../combat_art_treatment.md`.

## Checks

- Full `tests/run_tests.gd`: **PASS**, process exit 0, no script/shader errors. The suite emits an ObjectDB shutdown warning; no resource error or failed assertion remains.
- `tests/combat_art_treatment_probe.gd`: **PASS**, 8 native Metal captures at 1920×1080 / 100% UI scale. Shared material/source bounds, idle floor-cache retention, direct/cached agreement, legal targeting, partial Umbra coverage, campfire source replacement, advancing normal motion and texture/alpha contracts pass. Sampled backdrop, cards and HUD controls are pixel-identical between fixed-pose off/on captures.
- `tests/enemy_shadow_dissolve_probe.gd`: **PASS**, 13 native 1920×1080 images including the 12-state contact sheet. Early/middle/completion deltas and effect-node lifecycle pass. Inspected intact silhouette, breakup progression and reduced-motion endpoint; no new outline, floor pool or coverage leak.
- Existing submission benchmark: **PASS**, 157 retained layers, 180 samples/phase, no semantic errors.
- `git diff --check`: **PASS**.

All eight scene captures were inspected: off/on gives modest warm unity and stronger foot/base contact while preserving painted details; direct/cached floor agrees; the targeting arrow, legal highlight, HP preview and cards remain legible; the moving actor remains grounded; Umbra conceals the upper silhouette without a rim leaking outside it; fire-element and bonfire fill carry into adjacent actors and stone; normal animation continues. The action-heavy benchmark image was also inspected for elemental feedback, Umbra and crowded actor/HUD layering.

Native screenshots and full logs are preserved outside Git at:

`/Users/borgerding/.codex/visualizations/2026/09/17/01a0acec-2bc4-7051-8564-94947a7a7951/combat-art-treatment/`

Key files: `art_01_before.png`, `art_02_after.png`, `art_04_targeting.png`, `art_06_umbra_clip.png`, `art_07_campfire.png`, `art_08_normal_motion.png`, `action_heavy.png`, `death/enemy_shadow_dissolve_contact_sheet.png`, `visual.log`, `full-suite.log`, `death-proof.log`, and `perf-*-*.log`.

## Matched performance

Godot 4.6.1, Mobile/Metal 4.0, Apple M5 Pro, 1920×1080, existing `combat_board_max_content_active_umbra_v3` workload. Same unchanged benchmark script, assets, project renderer and four phases on baseline `a31807e8523e382b693ba1ec30ef11dafaff3459` and candidate. Sequential order **base, candidate, candidate, base**; 45 warm-up frames then 150 samples per phase per run. No other Godot workload ran during measurement. Complete phase statistics and semantic results are in `performance.json`.

| Phase | Baseline median frame interval (two runs, ms) | Candidate median (ms) | Baseline CPU draw work per phase frame (ms) | Candidate (ms) |
| --- | --- | --- | --- | --- |
| Idle | 8.277 / 8.295 | 8.278 / 8.349 | 0.526 / 0.541 | 0.540 / 0.542 |
| Target interaction | 8.337 / 8.328 | 8.338 / 8.345 | 1.177 / 1.073 | 1.030 / 1.104 |
| Movement | 8.312 / 8.316 | 8.312 / 8.314 | 1.425 / 1.416 | 1.451 / 1.457 |
| Action heavy | 8.301 / 8.355 | 8.325 / 8.331 | 1.909 / 1.892 | 1.975 / 1.978 |

Action-heavy CPU drawing adds about **0.076 ms/frame** using the average of the two runs. Viewport render CPU rises from about 0.076 to 0.094–0.095 ms there. Median draw calls increase by 4 in idle/interaction/movement and 12 in action-heavy. Both versions have 775 nodes and zero orphan nodes; candidate adds seven resource objects and approximately 0.67 MB static memory. Floor cache updates remain zero during measured phases. Both versions sustain approximately 120 Hz typical intervals on this machine. An isolated 25.37 ms candidate frame and 23.38 ms baseline frame did not recur in the matching second phase run; no systematic pacing regression is apparent.

**Benchmark limitation:** all four full benchmark invocations exit 1 solely on the same three existing Umbra MultiMesh-versus-ArrayMesh image equivalence assertions. The unchanged baseline reproduces all three. Other phase/lifecycle/cache assertions pass, so the timed data is retained as a comparison, not reported as a passing benchmark. The new lighting probe independently passes direct/cached equivalence and source-alpha checks. Metal reports no usable GPU duration, so frame pacing and CPU data do not quantify GPU headroom. The stress fixture has one torch column; the dedicated visual fixture covers five, then six with a bonfire. No Windows/Steam Deck claim is made.

## Reproduce

Run from the task worktree, using its task id with the wrappers:

```sh
python3 tools/godot_task_runner.py --task-id unify-combat-art-with-efficient-grading-contact-shading-and-shared-light --stream -- godot --headless --path . --script tests/run_tests.gd
python3 tools/visual_probe_runner.py tests/combat_art_treatment_probe.gd --task-id unify-combat-art-with-efficient-grading-contact-shading-and-shared-light --no-headless --min-images 8 --expect-size 1920x1080
python3 tools/visual_probe_runner.py tests/enemy_shadow_dissolve_probe.gd --task-id unify-combat-art-with-efficient-grading-contact-shading-and-shared-light --no-headless --min-images 13 --expect-size 1920x1080
python3 tools/visual_probe_runner.py tests/render_performance_benchmark.gd --task-id unify-combat-art-with-efficient-grading-contact-shading-and-shared-light --no-headless --min-images 1 --expect-size 1920x1080
```

Use the same final command with `--project <unchanged-baseline-checkout>` for the original revision. Preserve the reported baseline benchmark caveat above.
