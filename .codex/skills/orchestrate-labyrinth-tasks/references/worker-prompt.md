## Worker Thread Prompt

When sending the full worker prompt at thread creation, use this shape:

```text
Use $parallel-labyrinth-task for this Labyrinth task.

Queue id: <task-id>
Title: <title>
Priority: <priority>

Task proposal:
<proposal JSON or concise equivalent>

Parallel-safety notes:
<parallel_safety JSON or concise equivalent>

Before editing, adopt the prepared branch, record the supplied contract, and prove Git writes:
python3 tools/parallel_task.py adopt --task-id <task-id> --task "<title>"
python3 tools/parallel_task.py contract --risk-tier <tier> --acceptance "<criterion>" --required-proof "<proof>" --inspection-expectation "<fixture or reason>"
python3 tools/parallel_task.py preflight

If it is not on `codex/<task-id>` or preflight fails, stop before editing and report the exact blocked command. Do not invent alternate Git metadata workarounds.

Implement only this task's scope using the risk-tier proof rules in `spec/development_workflow.md`. Commit the finished branch yourself, run the mandatory peer-review gate, resolve findings, then create and verify a user-inspection fixture or explain why none applies. Package the final state with `labyrinth_task_queue.py handoff` and provide its single `complete --handoff-file` command. Stop for user inspection; do not push or clean up.

Do not push or clean up. After user approval, the work must land on master, not a remote task branch.
```
