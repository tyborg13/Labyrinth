# Product pass and on-demand checks

The pass protects rules, saves, progression, known bugs and active runner integrity.
It includes the KEEP Godot programs/main-body calls and 19 Python modules,
including one approved-asset manifest/production-only rig-load smoke.

From the task worktree, run the two passes serially:

```sh
python3 tools/godot_task_runner.py --task-id <task-id> --stream -- godot --headless --script tests/run_tests.gd
LABYRINTH_TASK_ID=<task-id> python3 tools/run_python_suite.py --shards 4 --all-groups
```

Neither Python defaults nor `--all-groups` runs on-demand groups.
Authoring, timing, sound, soak and workflow checks are explicitly selected:

```sh
LABYRINTH_TASK_ID=<task-id> python3 tools/run_python_suite.py --on-demand rig ui sound timing tools --shards 4
python3 tools/program_suite_runner.py --task-id <task-id> --on-demand timing soak sound tools --result-file /private/tmp/labyrinth_codex/<task-id>/on-demand.json
```

Use `--on-demand all` for every headless on-demand group. Use `--suite <name>`
for one Godot program. Existing windowed probes remain callable through
`tools/visual_probe_runner.py`; they require the design owner's window server.
`--perf` remains the explicit speed-threshold mode on a quiet machine.
The Python registry lists the groups and their modules; the Godot registry
lists programs with `on_demand: true` and their group. Discovery audits all
Python resource declarations before selecting any group.

New tests join the pass only for rules, saves, progression, or a failing-first
regression of a real bug. Everything else stays with its unit or goes on demand.
Register shared Python writes in `tools/python_suite_resources.json` even for
on-demand modules. Registry entries must point at existing files; registration
no longer requires every unit-local test to join a pass.
Approved asset changes require owner approval and an explicit manifest update.
The manifest has no automatic pin updater. The approved cut and accepted gaps
are in `spec/peer_benchmark/test_cut_list_2026-10-31.md`.
