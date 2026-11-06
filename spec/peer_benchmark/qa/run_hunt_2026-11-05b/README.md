# qa-56 release cache hunt

Base: `b945f269f4918e69a88730a7a9c07046df2917b0` (`codex/qa-56`), including Merge perf-54 and Merge sd-4 + sd-5. The director owns preflight, commits, review, fixture preparation and publication. All worker changes remain uncommitted. No product, asset, tuning, text, analytics or save format is changed.

Executable hunt tools and raw evidence live outside Git at `/private/tmp/labyrinth_codex/qa-56/`. `proof-sources/*.txt` preserve the exact executable sources for reproduction without adding scripts to the production inventory. Restore them with:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && python3 - <<'PY_RESTORE'
from pathlib import Path
import shutil
source = Path('spec/peer_benchmark/qa/run_hunt_2026-11-05b/proof-sources')
destination = Path('/private/tmp/labyrinth_codex/qa-56')
destination.mkdir(parents=True, exist_ok=True)
for item in source.glob('*.txt'):
    shutil.copyfile(item, destination / item.name.removesuffix('.txt'))
trace = destination / 'campaign-default/seed-000010/trace.jsonl'
trace.parent.mkdir(parents=True, exist_ok=True)
if not trace.exists():
    shutil.copyfile(source.parent / 'source-default-10-trace.jsonl', trace)
PY_RESTORE
```

Run fresh outputs only; the launcher rejects occupied directories. The two inherited qa-45 campaigns use seed 4, two processes and sequential 45-minute launch windows, draining active seeds after each cutoff:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && python3 /private/tmp/labyrinth_codex/qa-56/run_campaigns.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && python3 /private/tmp/labyrinth_codex/qa-56/ensure_minimum.py
```

The minimum-run helper runs additional fresh default seeds only if the two drained campaigns total fewer than 15. Its separate `campaign-default-extra` output preserves the two original launch windows. All completed section-5 runs receive the original strict census checks. `verify_lifetimes.py` independently accounts for detached summary-layout children and verifies their production capacity and release at scene deletion; it does not weaken or replace the strict census assertions. Change all occupied output directory fields for a repeated campaign. Every seed retains `command.json`, runner `godot.log`, `trace.jsonl`, `summary.json`, and `evidence.json`. Campaign reports preserve every runtime marker, exploration limit and coarse tree-growth alarm. The aggregate `cache-differences.json` retains each fresh-rebuild mismatch, including the inherited opening HP override, with seed, decision, exact differing paths and trace location.

The inherited observer checks board visible units, submission source, retained layer state, current hand identity/definition/summary/Time, boss HP, visible map routes/actions and forecast values before every decision. Its deeper observer samples transient side views and independently recomputes forecast summaries. Section-0/5 censuses retain the disjoint hand/pile/proxy/grimoire/character owners and per-tile canvases.

The added observer runs before every decision and at terminal state, therefore after each settled room/reward/shop/purge/Continue change. It also records actual scene, room, UI-scale, zoom, wallet, inventory, purchase and purge changes. Board submission and obstruction caches are forcibly rebuilt against scratch containers; exact original references are restored, preventing diagnostic repairs of a later invalidation miss. Current board state, stage visibility, door/equipment/prop presentation and the current-selection forecast are compared to fresh values. Stage visibility and forecasting use new combat engines. The intentional room-entry framing envelope is retained as a composition input. This is model proof; headless rendering cannot validate retained GPU commands, pixels, animation cadence or audio.

`validate_observer.gd` deliberately poisons board, stage and forecast caches, verifies detection and restoration, then changes/restores scale and zoom through production controls. `menu_continue_probe.gd` covers the actual main-menu Continue and perf-54's overlapping preparation; the inherited hunt resumes RunScene directly. The separate `purchase_purge_probe.gd` reuses `tests/suites/magic_deck_suite.gd`'s shop fixture, buys a generated spell, and confirms a paid purge through its actual overlay/Exhaust before comparing fresh presentation. Supplemental runs preserve their own seeded output/state and do not inflate campaign totals.

## Focused checks

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && python3 /private/tmp/labyrinth_codex/qa-56/run_hunt_task.py --runs 1 --processes 1 --seed 4 --output-dir /private/tmp/labyrinth_codex/qa-56/observer-validation-fresh --script /private/tmp/labyrinth_codex/qa-56/validate_observer.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && python3 /private/tmp/labyrinth_codex/qa-56/run_hunt_task.py --runs 1 --processes 1 --seed 4 --output-dir /private/tmp/labyrinth_codex/qa-56/menu-continue-fresh --script /private/tmp/labyrinth_codex/qa-56/menu_continue_probe.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && python3 /private/tmp/labyrinth_codex/qa-56/run_hunt_task.py --runs 1 --processes 1 --seed 4 --output-dir /private/tmp/labyrinth_codex/qa-56/purchase-purge-fresh --script /private/tmp/labyrinth_codex/qa-56/purchase_purge_probe.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/qa-56/python-audit-fresh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && python3 tools/run_python_suite.py --shards 4 --output-dir /private/tmp/labyrinth_codex/qa-56/python-default-fresh
```

## Proof for the design owner

No windowed command was attempted because the worker has no window-server access. The native replay script captures five real 1920×1080 views at 100% UI scale and pairs them with combat/board/presentation JSON. The native ledger retains the inherited 24→9999 opening Health override. A nine-case positive/negative classifier permits only that exact start-room difference at decisions 0–4; other fields, other Health values, later sections and extra occurrences fail. Inspect those pixels against state; the image contract validates image presence, dimensions and nonblank content only.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && python3 tools/visual_probe_runner.py --task-id qa-56 --no-headless --display-driver macos --audio-driver Dummy --timeout 1800 --startup-timeout 60 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/run_hunt_2026-11-05b/native-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/qa-56/native-proof.json /private/tmp/labyrinth_codex/qa-56/run_hunt_native.gd -- --seed 4 --no-embrace true --stop-after 600 --output-dir /private/tmp/labyrinth_codex/qa-56/native-captures
```

The dummy-texture finding has a second, targeted native trace replay. Its source is the default seed-10 campaign trace; anonymous action 296 is explicitly reconstructed as Purge because source action 297 enters that picker. Actual control bindings are logged. The trace stops on context divergence; a blocked replay does not establish non-reproduction.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-56 && python3 tools/visual_probe_runner.py --task-id qa-56 --no-headless --display-driver macos --audio-driver Dummy --timeout 1800 --startup-timeout 60 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/run_hunt_2026-11-05b/texture-native-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/qa-56/texture-native-proof.json /private/tmp/labyrinth_codex/qa-56/run_hunt_native_trace.gd -- --seed 10 --stop-after 774 --output-dir /private/tmp/labyrinth_codex/qa-56/texture-native-captures
```

Targeted expected image: `texture-native-captures/scavenger_after_773.png`, paired with `native-observations.json`. Native appearance and the source of the dummy-backend diagnostic remain open until inspected.

Expected captures: `native-captures/combat.png`, `changed_health.png`, `selected_preview.png`, `hover_preview.png`, `map.png`, and `native-observations.json`. Actual worker captures: none. No inspection-fixture command was requested by the brief; the owner retains that workflow.

## Chosen defaults and TODO_DESIGN

No design placeholders or player-facing values were introduced. Diagnostic defaults: task ID `qa-56` and the report/evidence paths; inherited qa-45 seed 4, 45-minute windows, two campaign processes, Health 9,999, 8× time, 120 FPS and eight settle frames; 90-decision smoke/control bound; section-0/5 census sampling; four-frame cleanup sample; 30,000-byte status tail. Scale validation chooses the next existing option, restores it, uses the existing `BOARD_ZOOM_STEP` and resets navigation. Poison values are a named stale-unit entry, stage radius -12345 and a named stale-forecast dictionary in the diagnostic only. Native proof forces the existing windowed display option to hold the required size, and inherits five categories, 600-decision bound, 1800-second timeout, 60-second startup timeout, minimum luma range 8 and stdev 2. The purchase/purge supplement inherits fixture seed 1016, wallet 1000 and room (2,1), chooses the first generated magic offer and first owned spell, and allows 600 frames for Exhaust to finish. The minimum-run helper polls completion every 10 seconds; any needed top-up uses two processes and the inherited 75-minute maximum launch ceiling. Trace replay uses the recorded default-10 input file, context checks, logged control bindings, one reconstructed Purge choice at action 296, and a stop after action 774 (the reported transition plus one action). Targeted native capture reuses the native dimensions/timeouts and nonblank thresholds. The classifier fixture uses the authored opening Health 24 versus inherited hunt Health 9999, opening decisions 0–4, tile (4,7), a synthetic floor/wrong_grid pair, corrupt Health -1, and known/extra occurrence counts 5/6 plus one other group; these are diagnostic negative controls only. Progress polling uses 50 seconds. No bound alters game design.


The large trace `source-default-10-trace.jsonl` was kept outside Git at `/private/tmp/labyrinth_codex/qa-56/evidence-large/`.
