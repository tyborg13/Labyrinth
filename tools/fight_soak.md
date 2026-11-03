# Fight lifetime soak (perf-08)

`fight_soak.gd` loads the production inspection fixture and RunScene, selects one
card per hero iteration with the committed encounter bot policy, exercises hand hover and board
`_gui_input` motion, commits the selected card through RunScene's production
presentation/analytics path, and passes through the normal enemy scheduler.
A terminal bout restarts the identical fixture. It never changes HP, card data,
AI, tuning, art, or effects to keep a fight alive. Each invocation executes at
least 20 hero iterations and 20 enemy phases. The report counts bouts and cards
so a vacuous workload is visible. The normal soak keeps a continuous fight;
`--replay-policy-cycles` additionally replays the fixture after its hand is spent or the bot declines a card.
The default-suite regression enables that mode and requires 20 committed cards,
keeping hand/hover/preview churn active for every requested cycle.

Run serially from the task worktree:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-08 && env -u LABYRINTH_CEL_LOOK python3 tools/godot_task_runner.py --task-id perf-08 --stream -- godot --headless --path . --script tools/fight_soak.gd -- --scenario warband --warband-biome earth --warband-tier 2 --warband-case encounter --output-dir /private/tmp/labyrinth_codex/perf-08/warband-off
```

Other cases: `--scenario dragon --dragon-id vyraketh`,
`--scenario guardian --guardian-id craghide`, and `--scenario combat`. Repeat
with `env LABYRINTH_CEL_LOOK=all`. This base contains no cel implementation.
`report.json` contains raw phase samples, node/script/class/name histograms and
diffs, all requested Performance monitors, CPU section counters, and teardown
counts. `rounds.tsv` is the per-round table. The headless dummy renderer cannot
prove native rendering or real frame pacing. It receives the synthetic
post-draw boundary already used by the section-transition test so real
production coroutines can finish. Its reported intervals are scheduler
intervals. Headless animation time is accelerated eightfold; use
`--headless-time-scale 1` for the original presentation clock.

The default-suite entry is `tests/fight_soak_test.gd`. Its plateau gate uses
counts only: at most two orphans every round and after destruction, a late
node/object range of 128/256, and late minimum drift of at most 16/32.
Full-hand replay compares matching late fixture turns instead, with strict
node/object delta ranges of 16/32; normal hand-size cycles do not mask growth. The first
half warms finite card pools. This permits normal temporary rail/feedback
variation but rejects a steadily rising floor. `fight_soak_metrics_test.gd`
checks the gate against synthetic stable and leaking histories. The production
Warband census is strictly empty of orphans; the tolerance covers test harness
nodes rather than granting a per-round leak budget.

The original report's shutdown flush runs inside PerformanceTelemetry._exit_tree.
Its 5,611 orphans match the nodes detached during SceneTree destruction
(5,621 live nodes became ten attached nodes). All interval
samples and `exit_to_desktop` had zero orphans. Shutdown alone is not evidence of
an allocation leak. The soak checks again after RunScene destruction instead.

The measured retention source was `CombatPreviewMemo.resolve`: each of 128
entries in the rule forecast/tile/ghost memos deep-copied all game catalogs.
The creating inputs are `battlefield_rules/dispatcher.gd::forecast_inputs`,
called by `forecast`, `battlefield_rule_view.gd::presentation_for` and
`move_ghosts`. Equal privately owned input components now share their snapshot.
The entry limit, FIFO eviction, complete collision checks, nested mutation
invalidation, and caller-owned result copies remain unchanged.
`combat_preview_memo_test.gd` checks those semantics and ensures 128 changing
board inputs retain one copy of an unchanged catalog.

For native proof, use `tests/fight_soak_probe.gd` through
`tools/visual_probe_runner.py`, with `--timeout 300 --expect-size 1920x1080
--proof-contract tests/fight_soak_probe_contract.json`. It captures completed
rounds 1, 10 and 20 at 100% UI scale. Native intervals are bracketed by real
`frame_post_draw`; policy search, census, serialization and PNG readback are
outside measured samples. Readback is followed by untimed settling. The report
records foreground focus samples, engine/debug build, renderer, machine, and
phase CPU counters. Discard native frame-pacing evidence if unfocused samples
are present. The CPU ranking covers the board's `_process` and `_draw` sections
and the existing scene/engine timers; it is not a global script profiler. Scene
timers are the current telemetry window. TIME_PROCESS is reported exactly as
Godot exposes it, including its monitor refresh cadence; do not read those
samples as a fresh CPU timer for each frame.

Debug-only defaults: fixture seed 7262026 (the existing inspection seed),
Craghide Guardian, one bot-selected card per hero iteration followed by pass,
fixture replay on an empty hand or bot pass in the regression (continuous fights in reports),
20 rounds minimum, eight settling frames, six idle sampling
frames per round, 120 FPS cap, headless time scale 8, at most twice the requested
rounds to reach the enemy-phase minimum, 1920×1080 windowed proof, and the count
bounds above, including matching-turn node/object delta bounds of 16/32 for
full-hand replay. The proof contract samples the [18,18,1884,1044] region, with
luma range at least 16 and standard deviation at least 3; capture rounds are
1, 10 and 20. Native runs retain the production animation clock. No player
perceives these tool settings.
