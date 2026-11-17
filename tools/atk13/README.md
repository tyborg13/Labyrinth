# atk-13 proof tooling

Audit only. No production code/data/assets/tests or atk-06 defaults changed.
`audit.gd` subclasses atk-06, retaining its real scene, forecasts, destination
queries and in-run pairing. The added oracle records statuses and per-action
sources, excludes planning copies, and checks its trace against production.

All output is task-local under `/private/tmp/labyrinth_codex/atk-13/`.
The harness targets **naturally generated** Cantor rooms at local tiers 1–3;
it preserves the fresh profile/loadout and global section scaling. Seeded walks
use movement/PASS without hero attacks. `health=0` preserves ordinary Health;
`health=9999` is the inherited high-Health walk setting.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-13 && python3 tools/atk13/audit.py run --label census --count 5 --health 9999 --turns 36
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-13 && python3 tools/atk13/audit.py run --label real-health --count 2 --health 0 --turns 36
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-13 && python3 tools/atk13/audit.py report --label all --include-label census real-health
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-13 && python3 tools/atk13/check.py
```

`cost.json` records each exact Godot-runner command and wall cost. Partial runs
never enter reports. Do not reuse a running label/output directory in another
process. `check.py` requires completed runs, at least 20 visible and executed
occurrences of each Cantor intent per tier, production/oracle trace identity,
complete harm accounting and saved reproductions. It is a focused proof check,
not a new `tests/test*.py` module or a default-suite addition.

Reproduction (add `--tile x,y` to move before ending):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-13 && python3 tools/godot_task_runner.py --task-id atk-13 --stream -- godot --headless --path . --script tools/atk13/replay.gd -- --save-dir /private/tmp/labyrinth_codex/atk-13/audit/census/tier-1-seed-1305-hp9999/repro/1305-9
```

Focused controlled mechanics and inspection of the existing loop raster:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-13 && python3 tools/godot_task_runner.py --task-id atk-13 --stream -- godot --headless --path . --script tools/atk13/mechanics.gd -- --state /private/tmp/labyrinth_codex/atk-13/audit/census/tier-1-seed-1305-hp9999/repro/1305-1/combat_state.txt --output-dir /private/tmp/labyrinth_codex/atk-13/mechanics
```

This stages copies of a real saved board, labels the output synthetic, crosses
the fuel-age boundary explicitly, and tests primary Shock, off-field Chain,
projection omissions and assisted/unassisted Arc. Existing loop frames are
only decoded into temporary PNGs; no art or game recording is generated.

Headless capture component/semantic checks (no real renderer/pointer claim):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-13 && python3 tools/atk13/capture_checks.py
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-13 && python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/atk-13/python-audit
```

The playback branch was also run headlessly with `--view playback`; it completed and logged the production caption/effect timeline. The capture sidecars explicitly identify headless semantics. Native execution
uses real pointers; headless checks exercise the corresponding production
signals/fields. Pre-battle and rule-loop panels are the real components,
mounted at named proof-only positions so the viewport captures them. Native
pixel bounds, occlusion, taste and audio still require owner inspection.

Native commands, for the design owner with a window server:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-13 && python3 tools/atk13/capture_plan.py --label census > /private/tmp/labyrinth_codex/atk-13/capture_commands.sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-13 && sh /private/tmp/labyrinth_codex/atk-13/capture_commands.sh
```

These 19 commands cover 7 intents × body/portrait hover, 2 pre-battle panels,
the rule HUD, its approved loop and one native playback timeline. The shell
wrapper calls `visual_probe_runner.py`, the existing native Metal launcher,
cel look, 1920×1080, 100% scale, proof contract and manifests. No windowed run
was attempted by the implementation worker. No inspection fixture install is
needed; each capture resumes its audited save in an isolated runner HOME.

Export text and build the report after the audit has finished:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-13 && python3 tools/godot_task_runner.py --task-id atk-13 --stream -- godot --headless --path . --script tools/atk13/capture.gd -- --save-dir /private/tmp/labyrinth_codex/atk-13/audit/census/tier-1-seed-1305-hp9999/repro/1305-1 --view text --out /private/tmp/labyrinth_codex/atk-13/text.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-13 && python3 tools/atk13/write_report.py
```

`inventory.py` prints the complete static move/rule table without modifying
catalogs. `write_report.py` requires a fresh aggregate (it refuses stale counts).
The report separates known numerical truth, status/effect disclosure, generic
red, source-owned red, and unexecuted native proof.

Chosen debug defaults are named in the scripts and listed in the report. No
TODO_DESIGN placeholder was needed; no new player-facing value was chosen.
