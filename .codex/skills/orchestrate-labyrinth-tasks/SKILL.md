---
name: orchestrate-labyrinth-tasks
description: Run reviewed Labyrinth queue tasks in app-visible workers and coordinate inspection and approved publication.
---

# Orchestrate Labyrinth Tasks

Run scout-reviewed `ready` tasks in separate app-visible Codex tasks. A request to run the queue authorizes creating those worker tasks. Hidden subagents are for scout/peer review, not implementation workers.

Before preparing or leasing work, verify callable app equivalents of `create_thread`, `read_thread`, and `send_message_to_thread`. If any is missing, report the missing operation and stop dispatch; do not substitute another worker mechanism.

Select tasks by concrete touched paths, generated outputs, and shared state. Use `prepare-worker` before app creation, pass its returned branch starting state, and require worker-owned `adopt`, `contract`, and `preflight` before implementation or leasing.

Load references by phase:

- [Dispatch](references/dispatch.md): queue states, collision checks, host requirements, branch creation, leasing, and monitoring.
- [Worker prompt](references/worker-prompt.md): include scope, acceptance, proof, and isolated-worktree requirements when creating a worker.
- [Handoff](references/handoff.md): peer signoff, verified fixture or not-applicable reason, queue completion, user inspection, and approved publication.

Keep queue state current whenever a task changes lifecycle state. The orchestrator owns queue JSON and consumes the worker's single verified `complete --handoff-file` command. Report the exact command if blocked.

Workers must finish required proof and peer review before user handoff. Do not push, land, or clean up until the user explicitly approves. Bind approval to the reviewed HEAD and publish to `master` through `$parallel-labyrinth-task`.

Report meaningful changes: running tasks and their status, ready tasks with review/proof/inspection, blockers with next actions, and queue capacity or collisions when relevant. Prefer compact app status/wait tools; do not repeatedly fetch full task histories.
