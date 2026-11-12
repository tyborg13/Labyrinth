# Hitch census v3 — frame-boundary timing

`trace.gd` is the tools-only observer. Schema 3 now includes `timing_version: 3`;
older schema-3 files without that marker retain their original, invalid peak
monitor attribution and are treated like schemas 1/2 by the reducer.

## Signal boundaries

The observer connects `SceneTree.physics_frame` and `process_frame` in
`_enter_tree`, before gameplay scene creation. Existing autoload listeners can
precede it; these are **signal timestamp boundaries**, not exclusive CPU timers.
Native samples contain absolute integer microseconds:

- `previous_post_draw_us`: preceding sample boundary (null on the first sample).
- `first_physics_frame_us`: first physics signal after that draw, null if absent.
- `process_frame_us`, `pre_draw_us`, `post_draw_us`: this frame's signals.

The derived wall intervals are `pre_process_ms` (previous post-draw to first
physics, or process when no physics step ran), `physics_wall_ms` (first physics
to process, or zero without a step), `process_wall_ms` (process to pre-draw),
and `draw_wall_ms` (pre-draw to post-draw). Input flushing, resumed draw
continuations and frame delay generally sit in pre_process. The first partial
native frame has no complete main-thread split.

`monitor_process_peak_ms` and `monitor_physics_peak_ms` preserve the Godot
TIME_PROCESS/TIME_PHYSICS_PROCESS rolling peaks as diagnostics. They are never
used as per-frame bucket inputs. Render viewport timers, SubViewport candidate
counts and memory deltas retain their original meaning.

After one explicitly marked startup partial sample (`complete_interval=false`),
headless samples run from one process signal to the next. The partial sample
retains startup events without charging them to the first full process interval. A last-priority
observer Node `_process` callback supplies `process_end_us`, so headless
`process_wall_ms` is process signal → end of ordinary Node `_process` dispatch.
It excludes later deferred/message-queue work. Draw/pre_process/physics buckets
are unavailable headlessly. No native timing is invented.

## Phase and bucket contracts

Scene phase maps are emitted only when `phase_frame == frame` natively or
`phase_frame == frame - 1` headlessly. Stale maps become `{}` in both sampler
and reader, including old trace schemas. Completed hook spans are drained into
the current interval and stamped with its matching phase ID; a separate
`hitch_phase_times_us` column retains that subset for inspection.

The reducer uses process/physics/pre_process/draw wall intervals. Recorded
integer driver spans are intersected with each interval; only the driver time
actually inside a bucket is removed from it, then shown separately as driver.
Game latency remains raw boundary interval minus known driver CPU. Old schemas
have **n/a** for these buckets and the explicit warning
“rolling-peak monitors: not frame-accurate”. No remainder is inferred from peaks.

Named rows retain top-five load paths and post_draw/input phases over frames
strictly >50 game ms. “Explained pre_process” is the per-frame capped estimate
`min(pre_process, (load + post_draw + input)/1000)`, averaged over eligible
frames. Timers overlap, including work outside pre_process; this is not an
exclusive causal decomposition. Per-frame `OBJECT_RESOURCE_COUNT` deltas are
reported as an unattributed-load proxy; positive changes and frees are both
retained, and net counts do not represent physical load operations.

## Production hook boundary

Only these six production files differ: `asset_loader.gd`,
`performance_telemetry.gd`, `run_scene.gd`, `encounter_asset_preparation.gd`,
`room_asset_preparation.gd`, and `run_end_preparation.gd`.
Each instrumented script caches the environment gate. On the enabled branch,
a tiny local getter reaches the sink through `/root/PerformanceTelemetry`;
there is no new preload dependency, nor a helper inside export-excluded tools/.
Rules, engine scripts, rigs, migrations and all other production files have
been restored to HEAD; `.gd` script loads are no longer instrumented.

Hooks do nothing beyond a cached boolean check when LABYRINTH_HITCH_TRACE is
not 1. AssetLoader hooks cover texture/image loading and creation, including
source texture publication. Audio/font loads are not hooked. Load events hold
inclusive count/µs and Godot cache residency at entry (not proof a source-first
call used that cache). Post-draw/input scopes release before the next await
or return. Empty preparation draw-wait wrappers have no work to time; caller
and recap shaping/raster helpers own their useful continuation spans. The
pre-draw hand-pointer callback remains labelled in the post_draw family.
Exact labels and all modified production lines appear in `result.md`.

## Whole-driver coverage settings

Whole runs default to starting Health **9,999** and no Embrace, abandonment,
save/quit, return-to-menu or other voluntary terminal controls, using
run_hunt_policy's existing filter. Overrides are `--starting-health` and
`--allow-voluntary-ends` (driver forms use `--starting-health=<n>`).
These settings affect only census whole runs. The recorded `legal_forward_attack_first_v6`
coverage policy prioritizes offered attacks that hit and focuses the lowest-Health
offered enemy target, advances toward enemies and forward map steps, starts
offered fights directly, and plays defensive/targetless cards when needed to
cycle the hand. Required treasure interactions precede blocked travel, and
exit/leader objectives take precedence over incidental targets. It uses inherited
random choices elsewhere. An unchanged room transition is tried once before
other offered UI/actions are serviced; the attempt set resets after UI use or
a room change. It changes only tool decisions,
never combat/animation speed or gameplay rules. Combat speed is **normal** and
Engine.time_scale is **1.0**. Each fight has run_hunt's **400-decision** limit;
reaching it produces a `fight_limit` receipt rather than silently continuing.
`run.json`, the trace header, the receipt and report header record these values.
Coverage records each visited zero-based section index.

## Redraw observation (perf-109)

With `LABYRINTH_HITCH_TRACE=1`, the observer scans existing CanvasItems and
connects newly added ones to `draw`. Connections use script resource paths,
otherwise `builtin:<class>`; `instance:` events now use that same script-first
key (rather than preferring a scene path). No production code changes.
Schema 3 adds `redraw_version: 1` in the header and these row columns:

- `redraws`: exact draw signal counts per key, including empty dictionaries.
  Repeated `queue_redraw()` requests coalesce; these are executed redraws.
- `redraw_ms_estimate`: per-key signal-gap milliseconds, excluding recorder
  callback time. A pending gap closes at the next draw, known driver phase
  start, pre_draw, or process-frame boundary, whichever is observed first.
- `redraw_span_ms`: first-to-last signal span, zero for zero/one signal.
  Across multiple flushes in a frame this includes intervening work and observer
  callbacks; it is a coverage estimate, not exclusive redraw CPU time.
- `redraw_polygons`: per-key summed `vertices` (`polygon.size()`) and
  `internal_polygons` (`polygons.size()`) for Polygon2D signals.
- `redraw_frame`: same rule as `phase_frame` (native frame, headless frame−1).
  The reader discards stale redraw fields, independently of phase maps.

Godot runs native `NOTIFICATION_DRAW`, emits `draw`, then calls script `_draw()`.
The gap method charges each node's native `NOTIFICATION_DRAW` work to the
**previous key**. Polygon2D nodes are redrawn by the engine, so their triangulation
is charged to whatever drew before them. The vertex/internal-polygon counts
exist to expose that workload independently of misleading time ownership.
The first node's native notification precedes the first timestamp; the final
gap may include unrelated deferred work up to its closing boundary. The
production phase maps contain durations only, so their starts cannot close a
gap without new production instrumentation, which this unit forbids. Driver
starts are available retrospectively and close a pending gap only when the
start follows its timestamp. These estimates never claim exact per-class CPU.

The run receipt's `trace` summary includes `redraw_totals` and
`redraw_frames_with_redraw`, accumulated once per sampled frame (including
loading). An unfinished, unsampled tail is excluded, just like phase rows.
Recorder/lifecycle/startup-scan costs join observer accounting. Disabled traces
connect no CanvasItem signals and scan nothing. Summaries report measured
callback µs/frame, not total native observer slowdown; native A/B calibration
is still needed for that.

The report's **Redraw** section compares strict >50 / >100 game-ms frames with
ordinary frames (<= each threshold), separately per profile/cache and excluding
loading. It shows top estimated ms/count keys, per-key and overall mean counts,
frames-with-redraw, Polygon2D totals, and summed spans. Older traces are
unmeasured rather than zero. The named catalog adds mean >50 `redraw_span_ms`.
Inclusive phase durations expose neither nesting nor interval endpoints. The
remainder therefore uses the **largest non-input/non-resume phase** as a
conservative outermost proxy, capped by process, and floors each frame before
and after subtracting the span. It cannot reconstruct the union of disjoint
outermost phases, nor separate overlap with redraw work. Report JSON names
both remainders as estimates. `resume_phase_frames` cheaply counts frames with
existing `post_draw:` / `await:` phase labels; repeated resumes of one label
are aggregated by production timers and cannot be counted individually here.

## Headless proof

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-109 && python3 tools/hitch_census/test_report.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-109 && LABYRINTH_HITCH_TRACE=1 python3 tools/godot_task_runner.py --task-id perf-109 --stream -- godot --headless --path . --script tools/hitch_census/observer_check.gd -- --output=/private/tmp/labyrinth_codex/perf-109/observer-on
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-109 && LABYRINTH_HITCH_TRACE=0 python3 tools/godot_task_runner.py --task-id perf-109 --stream -- godot --headless --path . --script tools/hitch_census/observer_check.gd -- --output=/private/tmp/labyrinth_codex/perf-109/observer-off
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-109 && LABYRINTH_HITCH_TRACE=1 python3 tools/godot_task_runner.py --task-id perf-109 --stream -- godot --headless --path . --script tools/hitch_census/hook_check.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-109 && LABYRINTH_HITCH_TRACE=0 python3 tools/godot_task_runner.py --task-id perf-109 --stream -- godot --headless --path . --script tools/hitch_census/hook_check.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-109 && LABYRINTH_HITCH_TRACE=1 python3 tools/godot_task_runner.py --task-id perf-109 --stream -- godot --headless --path . --script tools/hitch_census/headless_whole.gd -- --driver=whole --seed=84 --stop-after=3 --seconds=20 --output=/private/tmp/labyrinth_codex/perf-109/whole-smoke
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-109 && python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/perf-109/python-default
```

The adapter is copied from perf-107, with its diagnostic prefix changed and the existing
`headless_smoke` flag enabled to retain run metadata for the report.
Fresh worktrees require the project's intentional headless import bootstrap
before the whole-driver smoke. Synthetic draw signals are not renderer proof;
headless traces remain excluded from the native catalog. Report fixtures test
the rendered Markdown and native aggregation separately. No full suites.

## Proof for the design owner (not run here)

These commands prepare a fresh immutable copy and run **two native takes**:
seed 84, normal profile, one 240-second cold primer and one 240-second warm
measurement. The primer is retained but excluded from gameplay statistics.
Inherited census load remains 1280×800 Deck pixels, 115% UI scale, cel look all,
normal combat speed, time scale 1, no FPS cap/vsync.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-109 && python3 tools/hitch_census/census.py prepare --output /private/tmp/labyrinth_codex/perf-109/native --import-cache /Users/borgerding/workspace/Labyrinth.worktrees/perf-109/.godot
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-109 && python3 tools/hitch_census/census.py run --output /private/tmp/labyrinth_codex/perf-109/native --drivers whole --seed 84 --seeds 1 --cache warm --profiles normal --seconds 240 --tag redraw --disk-cap-gb 10
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-109 && python3 tools/hitch_census/report.py /private/tmp/labyrinth_codex/perf-109/native --output /private/tmp/labyrinth_codex/perf-109/native/catalog
```

Optional existing screenshot proof, separate from census measurement:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-109 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --project /private/tmp/labyrinth_codex/perf-109/native/project --task-id perf-109 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tools/hitch_census/proof.json --result-manifest /private/tmp/labyrinth_codex/perf-109/visual-proof.json tools/hitch_census/probe.gd -- --output=/private/tmp/labyrinth_codex/perf-109/visual-proof
```

No inspection_fixture.py command applies: no playable presentation changed.
