# qa-70 demo whole-run hunt

Worktree: `/Users/borgerding/workspace/Labyrinth.worktrees/qa-70`, branch `codex/qa-70`, base/HEAD `ddf534d55`. The sole code change is one fixture call in `tests/demo_boundary_test.gd:282`, retargeted to the existing `loaded_room_state.gd` helper; all assertions are preserved. No product source, scene, data or asset changed. The director owns commit, review, fixture and publication. Raw evidence and task-local tools stay at `/private/tmp/labyrinth_codex/qa-70/`.

The brief's `spec/peer_benchmark/director_tools/whole_run/` is absent; qa-64's scratch scripts were deleted. The archived qa-56 `proof-sources/*.txt` drivers were restored outside Git and retargeted. Their `qa56_` trace-event names remain. The observer compares board/layer submissions, scratch board/chrome/visibility caches with exact original references restored, hand definitions/rows/Time, independent forecast engines, ordered rail, per-unit Health, map nodes/routes, visible bound card definitions/rows/art/Time, event state/choice preview lines, and visible shop content/price/affordability. Separate engines inherit production through its custom-engine branch, bypassing the shared standard-plan memo. State hashes check observation does not mutate committed run/combat/preview data. A poisoned board/stage/forecast/rail/Health control and an unchanged-input-prefix control validate the instrumentation.

Opening hunt Health is refreshed into presentation before the first observation. Reward cards with no override rows are compared through `display_summary_rows()`, which includes their ordinary definition rows. Those are observer corrections, not product fixes. Original smoke/control logs retain the initial empty-override-row alarms and the initial control's incorrect assumption that the first sorted actor was the player. Corrected controls and campaign ledgers remain separate.

The finite campaigns are six default seeds 4–9, six `--no-embrace` seeds 4–9, and three ladder seeds 4–6. Every decision and terminal checkpoint receives model comparisons. The ladder uses the existing frozen `encounter_bot.gd` policy, one committed card or dodge/pass per projected scene checkpoint. It uses the existing `run_curve_ladder.gd` explicit victory transition for losses/turn caps, recording each one. These are offline ladder transitions, not claims of natural wins or UI combat-input coverage. Route, dialogue and reward inputs use the production scene paths.

## Commands and evidence

Every command starts in this task's worktree. Godot children use the required runner/task ID; `run_hunt_task.py` overrides the checked-in launcher's hard-coded qa-18 ID without editing it.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-70 && python3 tools/godot_task_runner.py --task-id qa-70 --timeout 1800 --stream -- godot --headless --path . --import
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-70 && python3 tools/cel_look.py build --if-stale
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-70 && python3 /private/tmp/labyrinth_codex/qa-70/run_campaigns.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-70 && python3 /private/tmp/labyrinth_codex/qa-70/aggregate.py
```

The cold import completed before campaigns and final focused checks. The first inherited observer control was exploratory while import was still completing; the final expanded poisoning control was run after bootstrap. The initial cold import emitted the inherited certificate and duplicate-UID diagnostics. Cel generated output remains ignored and uncommitted; its existing touch-canvas mismatch list and NumPy warnings are retained in `cel.log`.

Individual fresh replay (add `--no-embrace` for that campaign; use `run_demo_ladder.gd` for the ladder):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-70 && LABYRINTH_DEMO=1 python3 /private/tmp/labyrinth_codex/qa-70/run_hunt_task.py --runs 1 --processes 1 --seed 4 --script /private/tmp/labyrinth_codex/qa-70/run_demo.gd --output-dir /private/tmp/labyrinth_codex/qa-70/repeat-default-seed4
```

`--stop-after N` bounds a replay. Seed alone does not promise an identical timing-sensitive UI trace; each original `trace.jsonl`, command and final state is retained. Campaign `findings.json` and `report.md` preserve all engine markers, including the inherited platform certificate error. `aggregate.json` summarizes terminal checks, model comparisons, natural/forced ladder wins and source hashes. The initial 90-decision smoke and 45-decision ladder smoke are excluded from the 15 required campaign runs. `input-equivalence.json` compares the first 40 normalized actions with the original unobserved hunt.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-70 && LABYRINTH_DEMO=1 python3 tools/godot_task_runner.py --task-id qa-70 --stream -- godot --headless --path . --script /private/tmp/labyrinth_codex/qa-70/validate_demo_observer.gd -- --seed 4 --output-dir /private/tmp/labyrinth_codex/qa-70/repeat-observer
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-70 && python3 tools/godot_task_runner.py --task-id qa-70 --stream -- godot --headless --path . --script tests/demo_boundary_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-70 && python3 tools/godot_task_runner.py --task-id qa-70 --stream -- godot --headless --path . --script tests/demo_end_panel_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-70 && python3 tools/godot_task_runner.py --task-id qa-70 --stream -- godot --headless --path . --script tests/demo_end_panel_probe.gd -- --validate-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-70 && python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/qa-70/python-audit-repeat
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-70 && python3 tools/run_python_suite.py --shards 4 --output-dir /private/tmp/labyrinth_codex/qa-70/python-default-repeat
```

No full suites ran. The Python default group was rerun after the one-line fixture repair. No new repository Python test module needs resource registration. Audit: 56 modules; default selection: 20 modules. The optional timing-cache write is denied by read-only Git metadata; the suite result is independent of that write.

The two-process persistence probe first quits through the real Exit to Desktop menu action; a second process uses the real main-menu Continue transition and compares the complete saved run and combat, then fresh presentation. Its save files and `before.var` remain in `persistence/`. To repeat, use new output directories and preserve `persistence/` between the following ordered commands:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-70 && LABYRINTH_DEMO=1 python3 tools/godot_task_runner.py --task-id qa-70 --stream -- godot --headless --path . --script /private/tmp/labyrinth_codex/qa-70/quit_mid_demo.gd -- --seed 4 --output-dir /private/tmp/labyrinth_codex/qa-70/repeat-quit
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-70 && LABYRINTH_DEMO=1 python3 tools/godot_task_runner.py --task-id qa-70 --stream -- godot --headless --path . --script /private/tmp/labyrinth_codex/qa-70/continue_mid_demo.gd -- --seed 4 --output-dir /private/tmp/labyrinth_codex/qa-70/repeat-continue
```

Save-folder routing uses production defaults in a fresh runner HOME after a runner-owned Python child removes only the two runtime-namespace variables. It keeps Steam disabled. Synthetic full-game profile/run sentinels and before/after file hashes/mtimes make full-folder writes observable. Campaign saves deliberately use their external per-seed paths and cannot establish production-folder routing.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-70 && LABYRINTH_DEMO=1 QA70_ROUTING_RESULT=/private/tmp/labyrinth_codex/qa-70/editor-save-routing-repeat.json python3 tools/godot_task_runner.py --task-id qa-70 --run-id editor-routing-repeat --godot-home-root /private/tmp/labyrinth_codex/qa-70/editor-homes --stream -- python3 /private/tmp/labyrinth_codex/qa-70/monitor_native.py godot --headless --path . --script /private/tmp/labyrinth_codex/qa-70/save_routing_probe.gd --log-file /private/tmp/labyrinth_codex/qa-70/editor-engine-repeat.log
```

Export: `export_demo.py` runs cel status after the completed cel build, the exact Steam script's rsync exclusions (including `.godot`, `tests`, `tools`, `spec`), `tools/export_game.py --preset "Steam Demo macOS" --project <sanitized-copy> --task-id qa-70`, then the official release executable headless under `monitor_native.py`. The validated launch uses `--max-fps 60 --quit-after 900` (15 seconds of paced frames), recorded in `export/launch-settled.log`; `export/save-routing-settled.json` contains its file comparison. Exact commands are in `export*-command.json`; all staging, app and logs stay in `export/`. The monitor keeps the runner's isolated HOME but removes the runtime namespace so the exported demo's actual application name controls `user://`. `tools/export_smoke.py --preset "Steam Demo macOS"` was attempted and rejected as an unsupported preset (exit 2); it lists only the three full-game presets. No inventory-smoke success is claimed. Two earlier uncapped `--quit-after 180` launches stopped during asynchronous menu loading and emitted three preload/compile script errors each. Both fonts load from the pack with the expected data lengths; the original, unchanged app has zero script errors with the paced launch. These interrupted-launch diagnostics remain in `export/triage.json`; they do not establish a product defect. An unused font-warmup control app is retained as a diagnostic artifact, and the staged startup source was restored. No startup change is proposed.

## Proof for the design owner

No windowed run was attempted. No worker PNG capture exists. Required real-renderer proof is 1920×1080, 100% UI scale. The following task-local scripts and contracts are prepared; their headless parser checks pass. The first follows a whole ladder run into the actual demo end screen. The second copies the existing approved twelve-state panel probe with only its output destination changed, including clear/overflow, Discord focus, post-Hearth end, menu/settings and keystone teaser states. Inspect actual pixels and controller operation; headless model checks do not establish visual correctness.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-70 && LABYRINTH_DEMO=1 python3 tools/visual_probe_runner.py --task-id qa-70 --no-headless --display-driver macos --audio-driver Dummy --timeout 1800 --startup-timeout 60 --expect-size 1920x1080 --proof-contract /private/tmp/labyrinth_codex/qa-70/native-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/qa-70/native-proof.json /private/tmp/labyrinth_codex/qa-70/run_demo_native.gd -- --seed 4 --no-embrace true --output-dir /private/tmp/labyrinth_codex/qa-70/native-captures
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-70 && python3 tools/visual_probe_runner.py --task-id qa-70 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --proof-contract tests/demo_end_panel_probe_contract.json --result-manifest /private/tmp/labyrinth_codex/qa-70/panel-native-proof.json /private/tmp/labyrinth_codex/qa-70/demo_end_panel_native.gd
```

Expected first captures: `native-captures/{combat,map,demo_end}.png`, paired with `native-observations.json`. Expected second directory: `/private/tmp/labyrinth_codex/qa-70/panel-native/1920x1080/`, files `01_demo_clear.png` through `12_full_build_recap.png` as enumerated by the checked-in contract. Contracts verify image coverage, size and nonblank regions. No inspection-fixture command was requested for this unit; the director owns that handoff.

## Chosen defaults

All choices are diagnostic. Named fields/constants retain: task ID/path qa-70; `FIRST_SEED=4`, `PROCESSES=3`, campaign counts 6/6/3, `MINUTES=75` launch ceiling; inherited per-seed watchdog 4,500 seconds, Health 9,999, ×8 scene time, 120 FPS, eight settle frames, fight limit 400, unchanged-fight limit 50, screen limit 120, browse limit eight, side-action chance 0.10. `TERMINAL_SETTLE_FRAMES=120`; `POISON_HEALTH=-12345` applied to the first sorted live actor; save-routing `FIXTURE_SEED=701104`; input-control prefix 40; native startup duration 900 frames at `NATIVE_SAMPLE_FPS=60` (`NATIVE_QUIT_FRAMES=900`); import/export cap 1,800 seconds. The ladder retains the frozen policy's turn/action/search caps and records every forced victory. Native output destinations/contracts are named in the tools. The sentinel bytes are named `FULL_SENTINELS`; all sentinel writes stay inside isolated HOME. No player-visible default, asset or `TODO_DESIGN` placeholder was needed.
