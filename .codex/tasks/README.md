# Labyrinth Autonomous Task Queue

This directory holds the repo-local scaffolding for autonomous Labyrinth work.

- Runtime queue items live in `queue/*.json` and are intentionally ignored by git.
- Completed queue items may be archived in `archive/*.json` and are also ignored.
- Reusable JSON shapes live in `templates/`.
- Use `python3 tools/labyrinth_task_queue.py --help` for queue operations.

The queue is deliberately plain JSON so scouts, orchestrators, and worker threads can inspect and repair state without a background service.

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
