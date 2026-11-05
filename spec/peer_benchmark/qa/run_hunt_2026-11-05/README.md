# qa-45 whole-run cache hunt

The design owner supplied this worktree and contract. The worker leaves all
changes uncommitted. Review, inspection-fixture preparation, commits and
publication remain with the owner. The perf-46 refresh jobs in
`scripts/run_scene.gd` and perf-47 future-route search in
`scripts/combat_engine.gd` are protected. No player-visible design value or asset
is authored by this unit.

Evidence root: `/private/tmp/labyrinth_codex/qa-45/`.
The launcher imports the unchanged `tools/run_hunt.py` and substitutes task ID
`qa-45` and task-local replay paths. The sequential coordinator uses a fresh
campaign seed **4**, **45-minute** launch windows and **2** processes per
campaign, default before `--no-embrace`. In-flight seeds drain after each cutoff.

The observer inherits the production hunt. Before every decision it compares
retained board units, submission inputs and live layer state, hand identities,
Time badges, summary-card inputs, boss HP and forecast inputs. Visible map
nodes are checked against room data, routes and action availability. These are
headless model checks: they do not establish pixel equivalence. The deeper
census replay also observes one-frame hover/map side views, recomputes forecasts
on a separate engine with owned state, and checks visible forecast-line values.
`observer-revisions.json` identifies the corrected instrumentation and the two
seeds that loaded the original observer. Its original errors are retained and
triaged. The corrected 90-decision seed-4 confirmation and default-5 census replay are script-error-free; exact and map-wrapper-normalized input comparisons are retained separately.

## Reproduce

Restore the exact diagnostic sources (the `.txt` snapshots stay out of Godot's
script inventory):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && python3 - <<'PY_RESTORE'
from pathlib import Path
import shutil
source = Path('spec/peer_benchmark/qa/run_hunt_2026-11-05/proof-sources')
destination = Path('/private/tmp/labyrinth_codex/qa-45')
destination.mkdir(parents=True, exist_ok=True)
for item in source.glob('*.txt'):
    shutil.copyfile(item, destination / item.name.removesuffix('.txt'))
PY_RESTORE
```

The original evidence paths are occupied; use fresh output directories for new
runs. Exact observed child commands are in every seed's `command.json`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && python3 /private/tmp/labyrinth_codex/qa-45/run_campaigns.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && python3 /private/tmp/labyrinth_codex/qa-45/run_replays.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && python3 /private/tmp/labyrinth_codex/qa-45/compare_replays.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && python3 tools/run_python_suite.py --shards 4 --output-dir /private/tmp/labyrinth_codex/qa-45/python-default
```

## Proof for the design owner

This sandbox has no window-server access. No windowed command was attempted.
The native replay uses the same seeded hunt inputs and records five real
1920×1080 views at 100% UI scale, with combat state and board presentation beside
each PNG in `native-observations.json`. Inspect those views against that state;
the native model checker also compares retained health, watch-value and map-route
draw inputs with their current owners. The image contract checks presence, size
and nonblank content, not semantic correctness. The native script is parser-checked headlessly.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-45 && python3 tools/visual_probe_runner.py --task-id qa-45 --no-headless --display-driver macos --audio-driver Dummy --timeout 1800 --startup-timeout 60 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/run_hunt_2026-11-05/native-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/qa-45/native-proof.json /private/tmp/labyrinth_codex/qa-45/run_hunt_native.gd -- --seed 4 --no-embrace true --stop-after 600 --output-dir /private/tmp/labyrinth_codex/qa-45/native-captures
```

Use fresh result/output paths on reruns. Missing view categories fail the proof
contract. A seed may diverge in asynchronous presentation timing between
headless and native execution; retained decision context makes that visible.
No inspection-fixture command was requested by the brief; the owner prepares
any inspection fixture.

## Chosen defaults

- `TASK_ID = "qa-45"` and the evidence/report paths above: task-local isolation.
- The hunt's Health override, speed, viewport, frame settling, policy, RNG and
  watchdog defaults are inherited unchanged. Campaign seed 4 is specified.
- `PROOF_CATEGORIES`: combat, changed health, selected preview, hover preview and
  map. Native capture happens before decisions or during existing side views;
  it adds no gameplay input.
- Native proof `stop_after = 600`, process timeout `1800` seconds and startup
  timeout `60` seconds: diagnostic bounds for a production-scene replay with
  renderer warmup. Its five-image contract uses minimum luma range `8` and
  standard deviation `2` solely to reject blank captures, as qa-23 did.

- `OBSERVER_CONFIRM_STOP = 90`: replays past the first observer errors at decisions 47 and 88. `REPLAY_PROCESSES = 2` caps the census replays; replay selection takes the first section-5 seed per campaign, then seed-order fallbacks if needed.
- `CENSUS_TERMINAL_SECTION = 5`: the replay stops after the required section-5 census and its current action settle, matching qa-30’s bounded-census scope.
- `CLEANUP_SAMPLE_FRAMES = 4`: sample after scene deletion and before the inherited eight-frame shutdown. Detached summary-tree owners are counted at each replay room entry.
- `SHUTDOWN_TAIL_LINES = 150`: retain the verbose shutdown tail. Any campaign seed with an ObjectDB warning also gets a full replay of the unchanged hunt under `--verbose`, queued behind the two census replays with the same two-process ceiling.
- `TRACE_TAIL_BYTES = 30000`: bounded status-log tail, diagnostic only.

No TODO_DESIGN placeholders are required: the hunt makes no design decisions.

## Shutdown replay limitation

The baseline ObjectDB warning in default seed 9 remains open. The original-hunt
verbose control, corrected-observer verbose control and exact-observer
non-verbose control all fork at decision 168 and finish on a fight budget. Their
per-case execution JSON records every command. None supplies same-input after
proof for the original victory/shutdown. No warning is hidden and no production
guard or design value is changed. The separate map-handler-equivalence metric
retains all strict trace differences; it only recognizes the existing wrapper
that closes the large map and calls the compact-map handler.


Large diagnostics (replay-diagnostics, objectdb-triage, runtime-markers, replay-input-comparison JSON) were kept outside Git at `/private/tmp/labyrinth_codex/qa-45/evidence-large/`.
