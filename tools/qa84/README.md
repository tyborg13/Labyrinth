# qa-84 quit cleanup

`application_shutdown.gd` installs one one-shot `Window.tree_exiting` callback
from the existing SteamService autoload. The root emits this after its children
exit, so RunPersistence, RunScene telemetry, PerformanceTelemetry and SteamService
keep their original exit ordering. The callback makes a final save-then-analytics
barrier, then releases the retained callbacks while GDScript scripts are alive.
It covers direct `SceneTree.quit()`, desktop Quit, native close, and startup errors.
It does not run when a scene or a service test double is removed.

A failed final write still leaves the preceding durable checkpoint/history intact.
The last barrier returns failure. Pending closures are released only after that
attempt; ordinary gameplay failure/retry queues are unchanged. No persistence
format, save policy, event schema, or player-facing value changes.

## Holder audit

The audit covered production `scripts/**/*.gd`, `assets/**/*.gd`, all static
initializers and writes, and every autoload signal subscription. The task report
also contains a machine-readable inventory of all 256 static declarations.

| Holder (file:line) | Retention path | Release site |
|---|---|---|
| `scripts/opening_boon_recovery.gd:10` | `profile_writer` defaults to another script's `Store.save_data`; tests can replace it with a lambda | `release_shutdown_callables():12` |
| `scripts/demo_end_panel.gd:18` | `shell_open` normally references native OS; demo driver replaces it with a script lambda | `release_shutdown_callables():21` |
| `scripts/demo_end_panel.gd:19` | `store_page_override_for_test`, populated by the inherited demo driver | `release_shutdown_callables():21` |
| `scripts/card_display_bindings.gd:14` | `_contexts[*].projections[*].identity` retains a resolver when `variant == null` (`:32`) | Existing `reset_cache():116`, called by shutdown |
| `scripts/card_display_bindings.gd:15` | `_definitions` owns the same resolver identities (`:50`) | Existing `reset_cache():116` |
| `scripts/card_display_bindings.gd:16` | `_definition_order` owns the same definition entries (`:52`) | Existing `reset_cache():116` |
| `scripts/progression_store.gd:65` | `_run_writer._pending[*].job`; bound static `_save_queued_run_state_at` submitted at `:588`, including failed writes | `application_shutdown.gd:26`, after final barrier at `:22` |
| `scripts/analytics_store.gd:11` | `_writer._pending[*].job`; bound static `_append_queued_batch` submitted at `:332` | `application_shutdown.gd:27`, after final barrier |
| `scripts/analytics_store.gd:12` | `_writers_by_directory` keeps inactive namespace writers, including failed jobs | `application_shutdown.gd:28–30`, every namespace flushed first |
| `scripts/card_summary_measurements.gd:6` | Weak font registry tracks native `Font.changed` subscriptions to static `_font_changed.bind(id)` (`:26`). Theme/TextServer ownership may outlive a scene | `release_shutdown_connections():8`; disconnect before clearing registry |
| `scripts/presentation_clock.gd:12` | `_ticker` points to root-owned MovieTicker whose `sync` (`:23`) references static `_sync_movie_frame` | `release_shutdown_callables():15`; disable process, empty callback, drop pointer |

The original external demo driver is available locally at
`/private/tmp/labyrinth_codex/perf-105/census-v2/project/tools/hitch_census/demo/session.gd:25–26`.
It injects the two DemoEndPanel lambdas. The quit probe reproduces those holders
without copying that driver or its input/visual configuration.

No const Callable collections or autoload-to-lambda subscriptions were found.
The four autoloads' subscriptions are named methods:

| Source | Subscription | Lifetime |
|---|---|---|
| `scripts/steam_service.gd:131,337,341` | Steam floating-keyboard/stats callbacks to the service | Node destruction disconnects callbacks; service's existing final persistence/store work is unchanged |
| `scripts/input_router.gd:47` | Input joypad connection callback | Autoload Node destruction |
| `scripts/cursor_feedback.gd:73` | Root Window focus callback | Autoload Node destruction; existing exit guard precedes native cursor restoration |
| `scripts/performance_telemetry.gd:149` | Child HTTPRequest completion callback | Child/Node destruction, after existing shutdown flush |

Autoload signals consumed by scenes likewise connect named instance methods, not
lambdas; freeing their target Nodes disconnects them before script cleanup.
Steam's editor-only `store_shell_open_for_test` metadata can hold a test Callable;
it is Node-owned, not script-static, and is destroyed with the service.

Other static dictionaries contain JSON data, geometry, textures, styles, weak
references, or pure memo inputs/results. Preview memoizers and BoardPathDrawCache
execute their compute/build Callables immediately and do not retain them.
Static preview CombatEngine instances leave their optional performance sink empty.
Gear-rest `_jobs` holds root-owned Nodes, not reference-counted ownership; node
destruction releases signal continuations. WorkerThreadPool's native callback
ownership cannot be cleared directly; AssetLoader's existing OwnedSourceTask
PREDELETE/drain waits finish its jobs. Font/Theme/TextServer and Input/Steam are
engine objects that must remain engine-owned; the font subscription above is the
retained static callback requiring explicit disconnection.

## Reproduction

The probe resumes a real combat scene, installs the inherited demo-driver static
lambdas, populates a resolver-identity cache, and creates a synthetic defeat with
the existing RunEngine. It then quits directly with final save/analytics work
pending. This is a populated-holder reproduction, not a full controller-route
playthrough. `--combat` retains the live-combat state instead.

Every launch goes through the mandatory task runner with isolated HOME and saves.
Logs distinguish reaching the quit point from launch/parser failure, and record
whether the root hook released the holders. The loop counts SIGABRT (including
the runner's POSIX exit-code wrapping) and new matching DiagnosticReports files.
Crash-report totals include every new matching file. Parent-PID attribution
separates this loop's reports from other concurrently running Godot processes;
unreadable/unattributed reports fail the loop instead of silently passing.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-84 && python3 tools/qa84/repro.py --headless --iterations 30 --output-dir /private/tmp/labyrinth_codex/qa-84/headless-owner
```

## Proof for the design owner

Run the native editor-binary loop (no `--editor` scan):

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-84 && python3 tools/qa84/repro.py --godot /opt/homebrew/bin/godot --iterations 30 --output-dir /private/tmp/labyrinth_codex/qa-84/native-editor
```

The ordinary production demo release is built with:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-84 && python3 tools/export_game.py --task-id qa-84 --preset 'Steam Demo macOS' --output '/private/tmp/labyrinth_codex/qa-84/release/Escape the Umbra Demo.app'
```

Official release templates reject `--script`, `--path` and `--main-pack`. To drive
the same state in the real release template, build the disposable instrumented
app. Its product scripts/assets/presets are copied unchanged; only a proof scene,
its probe script, and the copy's application entry point are added/changed.
The build metadata records that instrumentation. Use a fresh output directory.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-84 && python3 tools/qa84/build_release_probe.py --output-dir /private/tmp/labyrinth_codex/qa-84/release-probe
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-84 && python3 tools/qa84/repro.py --app '/private/tmp/labyrinth_codex/qa-84/release-probe/Escape the Umbra Demo.app' --iterations 30 --output-dir /private/tmp/labyrinth_codex/qa-84/native-release
```

These are shutdown reproductions, not visual capture probes. No windowed run,
capture, inspection fixture, or native play session is run by the implementation
engineer. A successful native loop requires 30 armed launches, exit 0 throughout,
`released=true pending=false`, and no owned or unattributed crash reports. Repeat with
`--combat` and distinct output directories if live-combat quit coverage is wanted.

## Chosen defaults

All are proof/test-only; product tuning remains unchanged:

- `FIXTURE_SEED = 83`; dismissed tutorial fixture uses existing test version 2.
- `READY_FRAME_LIMIT = 3600`; `SETTLE_FRAMES = 3`.
- `DEFAULT_ITERATIONS = 30`; `LAUNCH_TIMEOUT_SECONDS = 180`.
- `REPORT_SETTLE_SECONDS = 5` after native runs or signalled exits for CrashReporter publication.
- Shutdown test `CHECKPOINT = 84`, dummy font measurement size 20.
- Proof root is the prescribed 1920×1080 with fresh default settings (100% scale).

No TODO_DESIGN placeholders. See `/private/tmp/labyrinth_codex/qa-84/result.md`
for observed results, exact log paths, export status and outstanding native proof.
