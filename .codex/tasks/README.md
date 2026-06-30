# Labyrinth Autonomous Task Queue

This directory holds the repo-local scaffolding for autonomous Labyrinth work.

- Runtime queue items live in `queue/*.json` and are intentionally ignored by git.
- Completed queue items may be archived in `archive/*.json` and are also ignored.
- Reusable JSON shapes live in `templates/`.
- Use `python3 tools/labyrinth_task_queue.py --help` for queue operations.

The queue is deliberately plain JSON so scouts, orchestrators, and worker threads can inspect and repair state without a background service.

For a local Jira-style visual board of live queue state, run:

```bash
python3 tools/labyrinth_task_queue.py board
```

The board reads the same primary-worktree queue root as the CLI, includes archived terminal tasks by default, and auto-refreshes while the server is running. Use `--once-json` for a quick machine-readable snapshot without starting the browser server.

Worker Godot commands should go through the task-local wrapper so parallel runs do not share `user://` state:

```bash
python3 tools/godot_task_runner.py --task-id <task-id> --timeout 180 --stream -- godot --headless --path . --script tests/run_tests.gd
```

`--timeout` is in seconds and defaults to 300; pass `--timeout 0` only for an intentionally unbounded local run. `--stream` tees command output live while preserving captured output for the wrapper's Godot failure-marker scan.

Reviewed tasks move through this shape:

```text
proposed -> ready -> leased -> in_progress -> implementation_review -> ready_for_user -> approved_to_land -> done
```

Scouts should use `$scout-labyrinth-tasks` to generate and reviewer-gate tasks. Orchestrators should use `$orchestrate-labyrinth-tasks` to pick low-collision `ready` tasks, create app-visible worker threads, and land user-approved work on `master`.

Before a task is marked `ready_for_user`, the worker must complete the normal implementation review gate, then create a task-local inspection fixture or explain why no playable fixture applies. Use:

```bash
python3 tools/inspection_fixture.py --scenario <scenario> --summary "<what Continue opens>" <fixture-options>
```

The command writes `progression.json` and `current_run.save` inside a stable task-local Godot user directory and prints the launch command the user can run from the task worktree. Pass those details to `tools/labyrinth_task_queue.py complete` with `--inspection-scenario`, `--inspection-run-id`, `--inspection-summary`, and `--inspection-launch`. For tooling/data-only changes, use `--inspection-not-applicable "<reason>"`.

Queue state updates are part of the worker/orchestrator contract, not optional reporting polish. Before a queued task turn ends:

- After implementation reviewer `SIGNOFF` plus fixture or not-applicable handoff, run `python3 tools/labyrinth_task_queue.py complete <task-id> ...`.
- After the user approves publication and the task lands on `master`, run `python3 tools/labyrinth_task_queue.py landed <task-id> --commit <master-commit>`.
- If the user abandons the work or the worker cannot continue, run `python3 tools/labyrinth_task_queue.py mark <task-id> abandoned|blocked|rejected --note "<why>"`.
- If permissions or host tooling prevent the update, report the exact queue command that still needs to be run and the reason it was not applied.

Implementation workers require host-exposed Codex app thread tools. Before leasing tasks, the orchestrator must have callable equivalents for `create_thread`, `read_thread`, and `send_message_to_thread`. If those tools are missing from the current Codex session, orchestration should stop with a blocker instead of using hidden sub-agents as implementation workers.
