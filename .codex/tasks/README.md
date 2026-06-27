# Labyrinth Autonomous Task Queue

This directory holds the repo-local scaffolding for autonomous Labyrinth work.

- Runtime queue items live in `queue/*.json` and are intentionally ignored by git.
- Completed queue items may be archived in `archive/*.json` and are also ignored.
- Reusable JSON shapes live in `templates/`.
- Use `python3 tools/labyrinth_task_queue.py --help` for queue operations.

The queue is deliberately plain JSON so scouts, orchestrators, and worker threads can inspect and repair state without a background service.

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
