# rd-02 — rounds 1 and 2 handoff

All changes are uncommitted. This worker ran headless checks only. Native images,
MovieWriter output and the Mac rendering budget require the owner's window-server
run below. No full suites, peer review or publication were performed.

## Files and implementation

- `scripts/board_unit_team_outlines.gd`: new retained unit-body canvases, live team
  rims, palette/visibility rules, death alpha and x-ray precedence.
- `scripts/board_occlusion_silhouettes.gd`: x-ray manager and per-unit alpha hook.
- `scripts/board_occlusion_silhouettes.gdshader`: shared live-pose outline shader.
- `scripts/board_occlusion_sources.gd`: board painter order, rest-mask sources and
  exact current body/cutout drawing sources.
- `scripts/board_occlusion_alpha.gd`: cached quarter-resolution alpha occupancy
  and coverage union. No rectangle-only coverage remains.
- `scripts/combat_board_view.gd`: small lifecycle, pose/depth-slot dispatch and
  multiplier hooks. Other units' hover, aim, rings and HUD code are untouched.
- `tools/rd02/`: certified fixture generation, headless proofs, native capture and
  timing scripts, contracts, movie wrappers/checks, disposable release export and
  this handoff. Godot sources/shader include UID sidecars.

No art, fonts, icons, audio, balance data, save format or analytics changed.

## Numbered acceptance criteria

1. **Who / coverage:** every living visible combat unit gets a normal team rim.
   NPC props, preview echoes, dead actors introduced without a prior rim, burrowed,
   Umbra-clipped and unrevealed units do not. A prior living rim continues through
   its existing death fade. X-rays retain the unit 30%/22% and object 40%/30%
   thresholds, using rest alpha >0.5 in cached 25% masks. Objects only count later
   units; units count later units and tall props, even faded props.
2. **Look / depth:** normal rims are 2 px times zoom, ALLY/DANGER at 80%, without
   fill or glow, in each unit's original painter slot. Each original body renderer
   now draws in its own retained canvas, followed by its rim, before the next
   unit or SceneTile. The body uses the original cel material and drawing method.
   X-rays remain above Foreground and all SceneTiles, below Telegraphs/Effects/Hud,
   at the approved 85% (units) / 70% TEXT (objects), fading over 0.15 seconds.
   The ptf-09 target border remains in its accepted floor-decal slot.
3. **States / integration:** live viewport textures trace segmented rigs; sprite
   frame/atlas updates trace plain actors. Body hit/status tint never enters the
   rim shader. Placement uses the exact drawn origin, including blink overrides
   and impact shake. Death alpha uses the production owner-fade function. Existing
   Kindle glows stay behind their original whole-tile canvas; death-effect nodes
   keep their existing ownership/order. Exposed hook:

   ```gdscript
   board_view.set_unit_outline_alpha_multiplier(actor_key, 0.5) # default 1.0
   ```

   A presentation dictionary `unit_outline_alpha_multipliers` also supplies values;
   an explicit setter override takes precedence. Both rims use the multiplier.
   No rd-03 focus behavior is implemented.
4. **Cost / live poses:** geometry and shader bindings are retained. Idle rig
   pixels update through the existing live viewport texture, with no outline
   command rebuild or coverage query for animation phase alone. Position,
   footprint, clip/facing set, visibility and registration changes invalidate
   coverage; identical geometry reuses results. Shared shadow caches are retained.
   The native workload asserts **8 team rims and exactly 2 x-rays**. A disables
   both passes and uses the original body draw path; B enables both. Three
   interleaved pairs print immediately and persist before later capture steps.
   Each side prints steady frame median/p99, renderer CPU/GPU medians and update
   counters. The native gate is <=0.6 ms added median and <=1.5 ms added p99 for
   each pair. **Native cost remains unverified.** If it fails, the report prints
   `TODO_DESIGN_outline_cost` with the pair numbers; there is no visual fallback.
5. **Compatibility / regressions:** headless proofs cover cel on/off, compact
   1280x800 and zoom. The focused existing board, actor/cutout and intent suites
   pass. The release check builds an actual release application with a packed
   certified fight and boots it headlessly. Native pixels remain owner proof.

During an x-ray transition, the normal shader contributes residual edge alpha
`max(0, (normal_alpha - xray_alpha) * mask) / (1 - xray_alpha * mask)`.
Alpha-over with the identical x-ray kernel yields `max(normal_alpha, xray_alpha)`
at each edge sample. At full x-ray opacity the normal rim is suppressed. This
avoids a double-bright edge without changing width, palette or fade values.

## Observed alpha coverage

These are x-ray states; the new normal team rim is present in every living,
visible unit case, including the mostly unobscured hero.

| Certified case | Target | Alpha coverage | X-ray |
|---|---|---:|---|
| Original hero/Warden/stump regression | player | 10.7468% | off |
| Original Zekarion regression | player | 49.2714% | on |
| Original Vyraketh regression | player | 61.9308% | on |
| Warband pillar | enemy_1 | 55.8511% | on |
| Zekarion production arena | player | 57.1157% | on |
| Vyraketh production arena | player | 41.3662% | on |
| Section I ordinary fight | player | 22.9508% | off |

## Headless proof and results

All logs below are in `/private/tmp/labyrinth_codex/rd-02/`.

```sh
for RD02_CEL in off all; do
  LABYRINTH_CEL_LOOK="$RD02_CEL" python3 tools/godot_task_runner.py --task-id rd-02 --stream -- godot --headless --path . --script tools/rd02/silhouette_proof.gd
done
python3 tools/godot_task_runner.py --task-id rd-02 --stream -- godot --headless --path . --script tools/rd02/focused_checks.gd
python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/rd-02/feedback2-python-default
python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/rd-02/feedback2-audit
python3 tests/test_ui_identity_lint.py
python3 tools/rd02/check_movie_wrapper.py
python3 tools/rd02/check_owner_sequence.py
python3 tools/godot_task_runner.py --task-id rd-02 --stream -- godot --headless --path . --script tools/rd02/movie_clock_proof.gd -- --fixed-fps 30
python3 tools/godot_task_runner.py --task-id rd-02 --stream -- godot --headless --path . --script tools/rd02/performance.gd
python3 tools/rd02/export_check.py --output-dir /private/tmp/labyrinth_codex/rd-02/release-01 --reuse
```

`silhouette_proof.gd` checks threshold boundaries/hysteresis, alpha union, strict
opacity, mask/geometry cache reuse, phase-vs-pose-set invalidation, both palettes,
normal body/rim pose and placement equality, painter depth, hidden/dead/unrevealed
filtering, prop/object rules, x-ray precedence throughout fades, multiplier,
blink, death fade, compact zoom and tool-off baseline restoration.

Observed result lines:

```text
RD02 SILHOUETTE PROOF: PASS (2246 checks, 0 failures) [off and all]
RD02 FOCUSED: PASS (5472 checks, 0 failures)
Python default: Ran 189 tests in 50.499s / OK (20 modules)
ISOLATION AUDIT: 56 modules
UI identity: Ran 25 tests in 10.163s / OK
RD02 MOVIE WRAPPER: PASS (engine and script fixed-fps=30; write-movie present; both delimiter forms)
RD02 MOVIE CLOCK: PASS (script-visible 30 fps, four fixed clock steps; no MovieWriter/headless pixels)
RD02 OWNER SEQUENCE: PASS (stills -> A/B -> movie; simulated later failures preserve pair output; Metal/mobile)
RD02 PERFORMANCE: PASS (A/B, B/A, A/B; headless; no GPU claims for headless)
```

The Python tests passed; the optional learned timing-cache write was denied by
read-only Git metadata, as expected for this sandbox. No test assertion was edited.
New Python checks are tools, not new `tests/test*.py` modules; the resource audit
was still run. Platform CA-certificate warnings occur in headless Godot startup.

Capture setup commands were also run headlessly with `--check-only`:
`standard`, `warband`, `zekarion_arena`, `vyraketh_arena` (cel all), the Zekarion
arena compact setup, and `walk --clip`. Each still setup reports
`RD02 REAL CAPTURE: PASS (..., 2 samples)`; the walk reports
`RD02 REAL CAPTURE: PASS (walk, 90 samples)`, including normal -> x-ray -> normal
and production walk-pose assertions. These produce semantics, not renderer images,
in `feedback2/headless/<case>/semantics.json`. Logs use `feedback2-capture-*.log`
and `feedback2-walk.log`; no owner's native captures were replaced.

The final release log is `feedback2-release.log`:

```text
CEL_PACK_TEST paths=3076 failures=0
RD02 RELEASE TEMPLATE: PASS (0 failures)
RD02 RELEASE SOURCE HASHES: PASS (6 current runtime files)
```

All six current runtime files match `release-01/source-hashes.json`. The app is
`release-01/RD02.app`; its boot was headless using the actual release binary.

Headless-only A/B diagnostics (added median / p99 in ms):

| Pair | Order | Median | p99 |
|---|---|---:|---:|
| 1 | A/B | 0.047 | 0.076 |
| 2 | B/A | 0.071 | 3.643 |
| 3 | A/B | 0.065 | 0.049 |

B steady frame medians were 6.758, 6.760 and 6.773 ms; B p99 values were
9.451, 13.126 and 9.503 ms. Each leg reports 0 retained-rim command changes and
0 coverage recomputes during its 180 samples; live rig pixels still animate.
These ran without a renderer, alongside other headless verification, so their
timing and outlier do not measure or pass the native rendering budget. The
report correctly labels them `RD02 COST: UNVERIFIED (headless)`.

## Proof for the design owner

Complete sequence: seven still on/off pairs (four round-2 fixtures plus retained
round-1 regressions), then native A/B, then the three-second movie, then cel-off
and compact pairs. Probe timeout is 300 seconds, native renderer Metal/mobile,
1920x1080 at 100% UI scale. On = both rims; off = both passes disabled, holding
all source pixels and positions constant.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-02
sh tools/rd02/owner_proof.sh
```

Expanded main commands:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-02
python3 tools/rd02/prepare_fixtures.py
for RD02_CASE in standard warband zekarion_arena vyraketh_arena hero zekarion vyraketh; do
  LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --task-id rd-02 --no-headless --display-driver macos --audio-driver Dummy --rendering-driver metal --rendering-method mobile --timeout 300 --startup-timeout 30 --expect-size 1920x1080 --proof-contract tools/rd02/capture_contract.json --overwrite-result-manifest --result-manifest "/private/tmp/labyrinth_codex/rd-02/native-$RD02_CASE.json" tools/rd02/capture.gd -- --case "$RD02_CASE"
done
LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --task-id rd-02 --no-headless --display-driver macos --audio-driver Dummy --rendering-driver metal --rendering-method mobile --timeout 300 --startup-timeout 30 --expect-size 1920x1080 --proof-contract tools/rd02/performance_contract.json --overwrite-result-manifest --result-manifest /private/tmp/labyrinth_codex/rd-02/native-performance.json tools/rd02/performance.gd
python3 tools/rd02/performance_report.py /private/tmp/labyrinth_codex/rd-02/performance_native.json
LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --task-id rd-02 --no-headless --display-driver macos --audio-driver Dummy --rendering-driver metal --rendering-method mobile --timeout 300 --startup-timeout 30 --expect-size 1920x1080 --godot tools/rd02/movie_capture.sh --proof-contract tools/rd02/movie_contract.json --overwrite-result-manifest --result-manifest /private/tmp/labyrinth_codex/rd-02/native-movie.json tools/rd02/capture.gd -- --case walk --clip
python3 tools/rd02/finalize_movie.py
```

The complete shell script retains capture/timing failures and still proceeds to
A/B and the movie. It prints each pair and writes JSON immediately. The wrapper
supplies `--write-movie` and engine `--fixed-fps 30`, plus script-visible FPS for
PresentationClock. The finalizer copies 90 consecutive, unchanged native PNGs,
checks the fixed clock and outline/x-ray sequence, and removes startup frames.

Expected output paths:

- `stills/<case>/{on,off}.png`, `stills/{cel-off,compact}/{on,off}.png`.
- `performance_native.json`, `performance.png`; three pair reports and six steady
  side reports in stdout. The JSON retains runtime/board instrumentation too.
- `clip/walk/frames/walk_000.png` through `walk_089.png`, `movie_manifest.json`:
  3 seconds at 30 fps, from the certified Zekarion arena.

The fixture generator uses `tools/inspection_fixture.py` with task id `rd-02`,
run id `rd-02-<case>`, seed `7262026`, `--umbra-stage clear`, and a verified manifest
`/private/tmp/labyrinth_codex/rd-02/<case>.json`. Print the complete concrete
inspection commands without running an engine:

```sh
python3 tools/rd02/prepare_fixtures.py --dry-run
```

For example, the exact real-arena walk fixture command is:

```sh
python3 tools/inspection_fixture.py --task-id rd-02 --run-id rd-02-walk --manifest /private/tmp/labyrinth_codex/rd-02/walk.json --seed 7262026 --umbra-stage clear --summary 'rd-02 walk silhouette proof' --scenario dragon --dragon-id zekarion --dragon-depth 4 --dragon-case encounter --player-position 3:4
```

## TODO_DESIGN placeholders, chosen defaults and open issues

No unresolved design placeholders or new player-facing values. The conditional
`TODO_DESIGN_outline_cost` report activates only upon a failed native measurement.
Native cost, actual cel/compact pixels and native MovieWriter completion are open
validation items for the owner; headless runs cannot establish them.

Chosen defaults are proof/internal only: certified seed 7262026; actor positions
in `prepare_fixtures.py`; walk path `(3,4)->(3,3)->(3,2)->(3,3)->(3,4)` using the
production movement timing; 24 setup frames; 30 warmup/180 measured frames per A/B
leg; 300/30-second probe/startup limits; compact test viewport 1280x800; blink
fixture offset (80,40), death progress 0.9, test opacity image 32x32 and comparison
epsilon 0.00001. Quarter masks use bilinear alpha reduction before the prescribed
strict >0.5 threshold. The shared rim kernel remains the director-reviewed
16 outer / 8 inner samples; its division guard is 0.00001.
