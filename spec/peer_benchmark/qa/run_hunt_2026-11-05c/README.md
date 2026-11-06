# qa-60 whole-run release hunt

Base: `5a9a3da25` (`codex/qa-60`), including Merge perf-56. The director owns commits, review, inspection fixtures and publication. Changes remain uncommitted. No art, tuning, copy, analytics or save formats are changed.

The final outcome and acceptance accounting are in `result.md` and `coverage.json`. Raw commands, runner logs, traces, summaries and analytics remain under `/private/tmp/labyrinth_codex/qa-60/`. Sources are preserved as text under `proof-sources/`, with SHA-256 digests. Restore them from this worktree:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && python3 - <<'PY_RESTORE'
from pathlib import Path
import shutil
source = Path('spec/peer_benchmark/qa/run_hunt_2026-11-05c/proof-sources')
destination = Path('/private/tmp/labyrinth_codex/qa-60')
destination.mkdir(parents=True, exist_ok=True)
for item in source.rglob('*.txt'):
    relative = item.relative_to(source)
    target = destination / relative.with_name(relative.name.removesuffix('.txt'))
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(item, target)
PY_RESTORE
```

Use fresh output directories for repetitions. To reproduce the original release findings, run on the recorded base before applying this unit's local correction. The campaign driver preserves qa-56's sequential 45-minute default and no-embrace launch windows, seed 4 and two processes, then drains active runs. The default campaign is discovery evidence: its first two seeds loaded observer v1 during the cold-import tail, and its other seven seeds loaded v2. Discovery exposed the missing retained HUD-value decoration, so v3 now independently requires the approved forecast transformation as well as HP/damage-forecast checks. The first two no-embrace seeds began before the boss overlay oracle switched from its legacy tint to the shared owner-dissolve clock. All 15 qualifying hunts use the frozen v4 oracle: later no-embrace seeds and fresh default-policy top-ups. Eleven discovery runs remain separate from that minimum. The original minimum helper was already running at its earlier 17-total threshold; the final minimum coordinator waits for it, then tops up to 15 v3 hunts. Restored `ensure_minimum.py` uses a conservative 24-total threshold, followed by the same final coordinator. The qualified minimum coordinator then excludes the two early no-embrace seeds and requires 15 frozen-oracle runs plus a victory. Every raw discovery run remains reported.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && python3 /private/tmp/labyrinth_codex/qa-60/run_campaigns.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && python3 /private/tmp/labyrinth_codex/qa-60/ensure_minimum.py > /private/tmp/labyrinth_codex/qa-60/minimum.log 2>&1
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && python3 /private/tmp/labyrinth_codex/qa-60/ensure_final_minimum.py > /private/tmp/labyrinth_codex/qa-60/final-minimum.log 2>&1
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && python3 /private/tmp/labyrinth_codex/qa-60/ensure_qualified_minimum.py
```

The original presentation observer and uncached-rebuild checks run at every decision and terminal state, covering settled room, reward, shop, purge and direct-resume changes. Scratch rebuilds restore the exact original containers, including perf-56's index sources. Separate probes cover the real menu Continue transition and actual shop purchase/purge confirmation/Exhaust. No observer changes the hunt's inputs or RNG.

The release observer compares retained HUD command arguments with freshly built visible units, counts exactly one bar per disclosed living/dying actor, checks HP/forecast/owner alpha, and samples death animations between decisions. The expected HUD units include the approved fx-04 forecast values and pulse metadata. Bosses retain their existing separate overlay; it receives HP, forecast bounds/visibility, lethal-state, death-alpha and removal checks. NPCs, preview ghosts and actors withheld by existing Umbra disclosure retain their production exclusions. The controller candidate set is compared with pointer targets for card confirmation, shortcuts, orientation, movement and surface aiming. Player-turn fights with unlocked input must retain a visible, populated turn rail. These are model and retained-command checks; headless execution does not prove GPU pixels, cadence or audio.

Focused negative controls detect duplicated bars, stale HP, corrupted retained forecasts, a hidden rail, missing controller candidates and corrupted boss-forecast bounds. The health lifecycle fixture explicitly reaches dissolve progress 1 and removes the actor. The retained-transition regression changes an existing room to a fight while keeping the grid/layer identities, changing exits and terrain. It checks every retained layer and the resulting bar command counts.

## Reproductions and focused checks

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && python3 /private/tmp/labyrinth_codex/qa-60/run_hunt_task.py --runs 1 --processes 1 --seed 4 --stop-after 43 --output-dir /private/tmp/labyrinth_codex/qa-60/repro-seed4-fresh --script /private/tmp/labyrinth_codex/qa-60/run_hunt_cache_observed.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && python3 tools/godot_task_runner.py --task-id qa-60 --stream -- godot --headless --path . --script /private/tmp/labyrinth_codex/qa-60/retained_state_regression.gd -- --output-dir /private/tmp/labyrinth_codex/qa-60/regression-fresh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && python3 tools/godot_task_runner.py --task-id qa-60 --stream -- godot --headless --path . --script /private/tmp/labyrinth_codex/qa-60/health_lifecycle_probe.gd -- --output-dir /private/tmp/labyrinth_codex/qa-60/health-fresh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && python3 tools/godot_task_runner.py --task-id qa-60 --stream -- godot --headless --path . --script /private/tmp/labyrinth_codex/qa-60/target_observer_validation.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && python3 tools/godot_task_runner.py --task-id qa-60 --stream -- godot --headless --path . --script /private/tmp/labyrinth_codex/qa-60/boss_observer_validation.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/qa-60/python-audit-fresh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && python3 tools/run_python_suite.py --shards 4 --output-dir /private/tmp/labyrinth_codex/qa-60/python-default-fresh
```

## Proof for the design owner

No windowed run was attempted: this worker has no macOS window-server access. Run these commands on the final working tree. Every capture is 1920×1080 at 100% UI scale. Image contracts validate dimensions and nonblank output; inspect the paired state JSON and actual pixels. No inspection-fixture command was requested by the brief; that workflow remains director-owned.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && python3 tools/visual_probe_runner.py --task-id qa-60 --no-headless --display-driver macos --audio-driver Dummy --timeout 1800 --startup-timeout 60 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/run_hunt_2026-11-05c/native-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/qa-60/native-proof.json /private/tmp/labyrinth_codex/qa-60/run_hunt_native.gd -- --seed 4 --no-embrace true --stop-after 600 --output-dir /private/tmp/labyrinth_codex/qa-60/native-captures
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && python3 tools/visual_probe_runner.py --task-id qa-60 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/run_hunt_2026-11-05c/retained-transition-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/qa-60/transition-native-proof.json /private/tmp/labyrinth_codex/qa-60/retained_state_regression.gd -- --output-dir /private/tmp/labyrinth_codex/qa-60/transition-native-captures
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && python3 tools/visual_probe_runner.py --task-id qa-60 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/run_hunt_2026-11-05c/health-lifecycle-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/qa-60/health-native-proof.json /private/tmp/labyrinth_codex/qa-60/health_lifecycle_probe.gd -- --output-dir /private/tmp/labyrinth_codex/qa-60/health-native-captures
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && python3 tools/visual_probe_runner.py --task-id qa-60 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/run_hunt_2026-11-05c/hud-forecast-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/qa-60/forecast-native-proof.json /private/tmp/labyrinth_codex/qa-60/hud_forecast_regression.gd -- --output-dir /private/tmp/labyrinth_codex/qa-60/forecast-native-captures
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-60 && python3 tools/visual_probe_runner.py --task-id qa-60 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --startup-timeout 60 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/run_hunt_2026-11-05c/boss-lifecycle-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/qa-60/boss-native-proof.json /private/tmp/labyrinth_codex/qa-60/boss_observer_validation.gd -- --output-dir /private/tmp/labyrinth_codex/qa-60/boss-native-captures
```

Expected broad captures: `native-captures/{combat,changed_health,selected_preview,hover_preview,map,dissolve,removed_unit,targeting_candidates,second_fight}.png`, paired with `native-observations.json`. Targeting captures record the actual candidate set; they do not claim a simulated controller-input screenshot. The seeded `second_fight` capture targets section 0, room (1,2), the actual retained-state reproduction. The transition fixture emits `transition-native-captures/{room,fight}.png` and `retained-transition.json`. The lifecycle fixture emits `health-native-captures/{living,forecast,dissolve_0.0,dissolve_0.25,dissolve_0.5,dissolve_0.75,dissolve_1.0,removed}.png` and `health-lifecycle.json`. The forecast fixture emits `forecast-native-captures/hud_forecast.png` and `hud-forecast.json`. The boss fixture emits `boss-native-captures/{boss_living,boss_forecast,boss_lethal,boss_dissolve_0.0,boss_dissolve_0.5,boss_dissolve_1.0,boss_removed}.png` and `boss-observer.json`. Actual worker captures: none.

## TODO_DESIGN and chosen defaults

TODO_DESIGN: none. No player-facing value was chosen.

Inherited diagnostic settings remain seed 4, two processes, 45-minute launch windows, Health 9,999, 8× scene time, 120 FPS, eight settle frames, the original policy/fight/screen bounds and the 75-minute per-seed watchdog. The final qualified coordinator requires 15 v4 runs after eleven discovery runs; on this campaign that means at least 26 aggregate hunts. The already-running helpers retain their earlier 17-total and 15-v3 thresholds; the qualified coordinator supplies the difference. Monitoring polls every 50 seconds. The existing staged combat fixture supplies seed 126065, roster and placement. New named proof values are Block 6, a 3-HP wooden-box fixture at (1,1), an exit at (4,8) to (1,0), forecast loss 3, corruption sentinel -12345, target-host seed 60, forecast Freeze 1, and dissolve samples 0/0.25/0.5/0.75/1. Native proof inherits the 600-decision bound, 1800-second timeout, 60-second startup allowance and nonblank thresholds 8/2. The seeded transition proof targets section 0, room (1,2). The full RunScene boss fixture uses windowed mode to hold the required size and a 180-second native timeout. None changes production tuning.

Raw hunt data (JSON ledgers, censuses, indexes) moved out of the repo on 2026-11-05 to `/private/tmp/labyrinth_codex/qa-60/report-raw/`.
