---
name: parallel-labyrinth-task
description: Implement, verify, review, and publish Labyrinth changes in isolated task worktrees.
---

# Parallel Labyrinth Task

Use an isolated `codex/<task-id>` worktree based on current local `master` for substantive implementation. Preserve unrelated checkout changes. An app-created worktree must be clean and adopted before editing; every worker records its acceptance/proof/risk/inspection contract and passes Git preflight.

Complete authorized implementation, relevant verification, fixes, commit, separate peer review, and inspection handoff. Do not stop at an unverified first draft or request repeated permission for local work. Do not push, land, or clean up until the user explicitly approves that committed task branch.

Read only the reference for the current phase:

| Phase | Reference |
| --- | --- |
| Create/adopt a task and prove Git writes | [Start](references/start.md) |
| Run tests, Godot, visual probes, or playtests | [Execution](references/execution.md) |
| Review a stable committed branch; resolve findings | [Peer review](references/review.md) |
| Commit and prepare the verified fixture or not-applicable handoff | [Inspection](references/inspection.md) |
| User has approved publication; authorize HEAD, land, push, clean up | [Publication](references/publication.md) |

Use [development workflow contracts](../../../spec/development_workflow.md) for risk-tier proof breadth. Peer review remains mandatory at every tier. Do not present a task as ready until the reviewer signs off and inspection evidence or a concrete not-applicable reason is complete.

Keep runtime state isolated with the Godot and visual-probe runners. User-facing task-local launch commands must start with `cd <task-worktree> && ...`. Report exact permission failures; do not invent alternate Git metadata or detached-HEAD workarounds.

For queued work, the orchestrator owns queue JSON. Package one verified handoff for `complete --handoff-file`; record `landed` after publication and `mark abandoned|blocked|rejected` when work stops. Report the exact command if a queue update is blocked.
