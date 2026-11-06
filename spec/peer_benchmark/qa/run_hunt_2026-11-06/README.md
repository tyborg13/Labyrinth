# qa-64 whole-run release hunt

Base: `7e6e4e23b`, branch `codex/qa-64`. Tools, source revisions, contracts and all raw evidence stay outside Git at `/private/tmp/labyrinth_codex/qa-64/`. Only this README and the short result report belong in the repository. No product values, assets or rules were authored for this task. The director owns Git, review, inspection and publication.

The qa-56 tools were restored from `../run_hunt_2026-11-05b/proof-sources/` into that external directory and retargeted to this worktree. `presentation_observer.gd` adds event/reward/texture, Scavenger (including ordered pack copies), rail and per-unit Health/forecast comparisons. `uncached_engine.gd` inherits the production engine through its custom-engine branch, avoiding the static standard-plan memo without clearing or warming it. Fresh trees use separate viewports. Original cache references are restored after scratch rebuilds. Fresh card builds also isolate and restore the shared CardDisplay projection caches and their engine; comparisons include card definitions, summary rows, Time values and art identities. Read-only state hashes and poisoned-cache controls verify the observer.

The two inherited campaigns use seed 4, two processes and sequential 45-minute launch windows, draining active runs after each cutoff. The launcher rejects occupied output directories. Initial commands:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-64 && python3 tools/godot_task_runner.py --task-id qa-64 --timeout 1800 --stream -- godot --headless --path . --import
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-64 && python3 /private/tmp/labyrinth_codex/qa-64/run_campaigns.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-64 && python3 /private/tmp/labyrinth_codex/qa-64/run_supplement.py
```

To repeat an individual campaign, use `run_hunt_task.py --minutes 45 --processes 2 --seed 4 --output-dir <fresh-absolute-directory> --script /private/tmp/labyrinth_codex/qa-64/run_hunt_cache_observed.gd`, adding `--no-embrace` for the second campaign. All Godot children run through `tools/godot_task_runner.py --task-id qa-64 --stream`.

The focused scripts are `validate_observer.gd`, `menu_continue_probe.gd`, `purchase_purge_probe.gd` and `event_entry_probe.gd`. Run each through:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-64 && python3 /private/tmp/labyrinth_codex/qa-64/run_hunt_task.py --runs 1 --processes 1 --seed 4 --output-dir <fresh-absolute-directory> --script /private/tmp/labyrinth_codex/qa-64/<script-name>
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-64 && python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/qa-64/python-audit-repeat
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-64 && python3 tools/run_python_suite.py --shards 4 --output-dir /private/tmp/labyrinth_codex/qa-64/python-default-repeat
```

These select the Python default group (19 modules), with no full Godot suite or on-demand groups. No repository Python test module was added.

## Proof for the design owner

Windowed runs are unavailable in the worker sandbox; none was attempted. All three scripts require a real renderer, 1920×1080 and 100% UI scale. Inspect captured pixels against the paired state, especially health/forecast and rail ordering, reward art, hover rewards, and Scavenger wares. Contracts check image coverage, dimensions and nonblank content; they do not establish visual correctness.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-64 && python3 tools/visual_probe_runner.py --task-id qa-64 --no-headless --display-driver macos --audio-driver Dummy --timeout 1800 --startup-timeout 60 --expect-size 1920x1080 --proof-contract /private/tmp/labyrinth_codex/qa-64/native-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/qa-64/native-proof.json /private/tmp/labyrinth_codex/qa-64/run_hunt_native.gd -- --seed 4 --no-embrace true --stop-after 600 --output-dir /private/tmp/labyrinth_codex/qa-64/native-captures
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-64 && python3 tools/visual_probe_runner.py --task-id qa-64 --no-headless --display-driver macos --audio-driver Dummy --timeout 1800 --startup-timeout 60 --expect-size 1920x1080 --proof-contract /private/tmp/labyrinth_codex/qa-64/event-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/qa-64/event-native-proof.json /private/tmp/labyrinth_codex/qa-64/event_entry_native.gd -- --seed 4 --output-dir /private/tmp/labyrinth_codex/qa-64/event-native-captures
```

Expected first-command captures: `native-captures/{combat,changed_health,selected_preview,hover_preview,map}.png` and `native-observations.json`. Expected second-command captures: `event-native-captures/{map_open_event,map_reopen_event_0,map_reopen_event_1,event_entry,scavenger_entry,travel_after_event,travel_after_scavenger}.png` plus `hover_<event>_<choice>.png`, each with state JSON. Catalog hover fixtures render and capture their own 1920×1080 viewport. Actual worker PNG captures: none. The brief requests no inspection-fixture command; that workflow remains with the director.

The seed-4 dummy-texture occurrence also has a pinned trace replay. Its worker replay reissued 557 method-equivalent actions and matched the transition checkpoint without reproducing the diagnostic. This establishes no fix. Owner-only targeted renderer command:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-64 && python3 tools/visual_probe_runner.py --task-id qa-64 --no-headless --display-driver macos --audio-driver Dummy --timeout 1800 --startup-timeout 60 --expect-size 1920x1080 --proof-contract /private/tmp/labyrinth_codex/qa-64/texture-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/qa-64/texture-native-proof.json /private/tmp/labyrinth_codex/qa-64/texture_trace_native.gd -- --seed 4 --stop-after 557 --output-dir /private/tmp/labyrinth_codex/qa-64/texture-native-captures
```

Expected target: `texture-native-captures/scavenger_after_556.png`, paired with `native-observations.json`. The event contract explicitly names 132 required captures, including 125 distinct authored hover choices; the generated-entry hover is one repeated choice.

## Chosen defaults

All new choices are diagnostic. External tool/evidence paths use task ID `qa-64`. The inherited hunt retains seed 4, two processes, 45-minute launch windows, 9,999 starting Health, ×8 scene time, 120 FPS, eight settle frames, 400 fight decisions and the existing unchanged-state/browse guards. Census sections remain 0/5, tree factor 1.25, two required comparisons and four cleanup frames.

New probe constants are `ENTRY_SEEDS=32`, `PREPARATION_SETTLE_FRAMES=120` and `TRANSITION_SETTLE_FRAMES=600`. Controls use 90 decisions; trace bounds 557 and 608 come from the observed cases. Synthetic terrain uses named `dead`/`alive` IDs on tile `(2,2)`, Health 0/3 and poisoned Health 2. Other negative controls use stale-unit/forecast dictionary entries, Health −12,345, rail Health −987 and the inherited stage radius −12,345. Fresh trees use private 1920×1080 viewports. Native proofs inherit 1,800-second process and 60-second startup caps, luma range 8 and stdev 2. Test fixtures otherwise reuse the repository’s authored rich-event and paid-purge fixtures.

`run_supplement.py` targets 17 total runs, leaving 15 after the two initial default observer revisions. The original minimum-run waiters were intentionally interrupted before launching any seed, and six fresh defaults (seed 10 onward, two processes, 75-minute launch ceiling) were started after both primary launch windows closed while the last no-embrace run drained. Maximum overlap is three headless processes, then two. `supplement-schedule.json` records the exact commands and scheduling decision. All raw authoring attempts and failures remain outside Git, including the initial node-ordinal, pre-readiness, terrain-identity and JSON numeric-representation comparisons. Final controls retain exact numeric values and structure.

No `TODO_DESIGN` placeholder or player-facing default was needed. No product code, asset, gameplay number, name, wording, save or analytics format changed.

The engine-only `dummy_texture_stress.gd` diagnostic uses named defaults `MAX_PATHS=32`, `BATCHES=6`, `WORKERS=8` and `MAIN_ALLOCATIONS_PER_FRAME=4`, loading existing production card textures. It completed without missing resources, null-record errors or RID-exit warnings. This control did not reproduce the campaign finding. Engine source links and the limits of the causal inference are retained in `engine-texture-investigation.json`; no engine or game workaround was applied.
