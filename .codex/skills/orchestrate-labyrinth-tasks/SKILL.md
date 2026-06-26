---
name: orchestrate-labyrinth-tasks
description: Run the reviewed Labyrinth task queue by selecting low-collision work, launching app-visible Codex worker threads in isolated worktrees, monitoring progress, and landing user-approved completed work to master. Use when the user asks to run autonomous tasks, parallelize work, execute the queue, start multiple workers, or coordinate background Labyrinth changes.
---

# Orchestrate Labyrinth Tasks

Use this skill to turn reviewed queue items into parallel Codex work. The orchestrator chooses tasks, creates app-visible worker threads, tracks their branches/worktrees, and only lands completed work to `master` after the user approves.

## Core Rules

- Use reviewed `ready` tasks from `.codex/tasks`, not raw scout ideas.
- Launch implementation work in separate Codex app threads whenever possible, so the user can see each task in the sidebar.
- Each worker thread must use `$parallel-labyrinth-task` and its isolated worktree workflow.
- Worker branches are temporary isolation branches. After user approval, finished work lands on `master` and pushes `master`; do not publish remote task branches as the final result.
- Do not use hidden sub-agents as implementation workers. Hidden sub-agents are appropriate for scout review and implementation peer review.
- Do not push, land, or clean up completed task work until the user explicitly approves.

## Queue States

- `proposed`: scout idea that has not passed review.
- `needs_revision`: scout reviewer requested clearer scope, proof, or collision analysis.
- `ready`: scout-reviewed and available for a worker.
- `leased`: assigned to a worker thread but not yet confirmed in progress.
- `in_progress`: worker has adopted or created its isolated worktree.
- `implementation_review`: worker claims complete and is in the mandatory peer-review loop.
- `ready_for_user`: implementation reviewer signed off; waiting for user inspection.
- `approved_to_land`: user approved landing to `master`.
- `done`: landed on `master` and optionally archived.
- `blocked`, `rejected`, `abandoned`: explicit terminal or pause states with notes.

## Orchestration Workflow

1. Inspect the queue and active work.

```bash
python3 tools/labyrinth_task_queue.py list
python3 tools/labyrinth_task_queue.py select --limit <N> --json
```

2. Choose tasks with collision-aware judgment.
   - Prefer high-priority tasks with low `conflict_score`.
   - Read conflicts from concrete path overlap and `avoid_parallel_with`, not broad collision groups.
   - It is acceptable to run multiple tasks in the same broad area when their likely touched files and shared state risks are distinct.
   - Avoid launching two tasks that both expect to change the same singleton, shared JSON file, generated asset path, visual probe output, or test harness behavior.

3. Create one Codex app thread per selected task.
   - Use the Codex app thread tools, starting with project discovery if needed.
   - If thread tools are not already loaded, use tool discovery for `create_thread`, `read_thread`, and `send_message_to_thread`.
   - Create user-visible threads rather than sub-agent-only workers.
   - Once the user has asked to run parallel queued work, do not ask the user to create worker threads manually; create the worker threads directly.
   - Give each thread the task JSON, queue id, acceptance criteria, proof requirements, and the instruction to use `$parallel-labyrinth-task`.
   - Tell the worker to adopt the app-created worktree with `python3 tools/parallel_task.py adopt --task-id <task-id> --task "<title>"` before editing.

4. Lease the task after the thread exists.

```bash
python3 tools/labyrinth_task_queue.py lease <task-id> --thread-id <codex-thread-id> --branch codex/<task-id> --worktree <thread-worktree-path>
```

5. Monitor progress.
   - Read worker threads periodically.
   - Use queue `heartbeat` or `mark` when a worker reports meaningful state changes.
   - If a worker stalls or collides with newer work, mark `blocked` with a note rather than silently relaunching duplicate work.

6. Require implementation peer review before user handoff.
   - The worker's `$parallel-labyrinth-task` flow requires a reviewer sub-agent.
   - The worker must resolve reviewer findings and only report back after reviewer `SIGNOFF`.
   - Mark the queue item `ready_for_user` only when the worker provides the signed-off branch, commit, proof summary, and residual risks.

```bash
python3 tools/labyrinth_task_queue.py complete <task-id> --reviewer "<reviewer>" --signoff "<summary>" --proof "<tests/probes/screenshots>" --commit <head-commit>
```

7. Wait for user approval.
   - Present branch, worktree, commit, reviewer signoff, proof, and residual risks.
   - Do not land or push until the user explicitly says to push, land, publish, merge, or otherwise gives approval.

8. Land approved work to `master`.
   - Ask the worker thread that owns the worktree to run the approved publish step, or run it yourself in that worktree if the worker is unavailable.
   - `python3 tools/parallel_task.py push` lands the task branch to `origin/master`; it does not push a remote task branch.
   - If `master` moved and is not contained in the task branch, the command refuses. The worker must integrate `master`, rerun relevant proof, repeat implementation peer review, then request approval again if the reviewed diff changed materially.

```bash
python3 tools/parallel_task.py push
python3 tools/labyrinth_task_queue.py landed <task-id> --commit <master-commit> --archive
python3 tools/parallel_task.py cleanup --delete-branch
```

## Worker Thread Prompt

When creating a worker thread, include a prompt with this shape:

```text
Use $parallel-labyrinth-task for this Labyrinth task.

Queue id: <task-id>
Title: <title>
Priority: <priority>

Task proposal:
<proposal JSON or concise equivalent>

Parallel-safety notes:
<parallel_safety JSON or concise equivalent>

Before editing, adopt the app-created clean worktree:
python3 tools/parallel_task.py adopt --task-id <task-id> --task "<title>"

Implement only this task's scope. Commit the finished branch, run the mandatory peer-review gate from $parallel-labyrinth-task, resolve any reviewer feedback, and stop for user inspection after reviewer SIGNOFF. Provide branch, worktree path, head commit, proof run, screenshots/artifacts if relevant, residual risks, and the reviewer signoff summary.

Do not push or clean up. After user approval, the work must land on master, not a remote task branch.
```

## Status Reporting

When reporting to the user, group tasks by state:

- Running: task id, title, thread, branch, current status, last heartbeat.
- Ready for user: task id, branch, commit, reviewer, proof summary.
- Blocked: blocker, recommended next action.
- Queue health: ready backlog, likely collision risks, and whether more scouting is needed.
