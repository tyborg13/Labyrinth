---
name: orchestrate-labyrinth-tasks
description: Run the reviewed Labyrinth task queue by selecting low-collision work, launching app-visible Codex worker threads in isolated worktrees, monitoring progress, and landing user-approved completed work to master. Use when the user asks to run autonomous tasks, parallelize work, execute the queue, start multiple workers, or coordinate background Labyrinth changes.
---

# Orchestrate Labyrinth Tasks

Use this skill to turn reviewed queue items into parallel Codex work. Invoking this skill, or otherwise asking to run queued work in parallel, is explicit authorization for the orchestrator to create one user-visible Codex app/background thread per selected worker task. The orchestrator chooses tasks, creates app-visible worker threads, tracks their branches/worktrees, and only lands completed work to `master` after the user approves.

## Core Rules

- Use reviewed `ready` tasks from `.codex/tasks`, not raw scout ideas.
- Launch implementation work in separate Codex app threads so the user can see each task in the sidebar.
- Treat the user's request to use `$orchestrate-labyrinth-tasks`, run queued work, launch workers, start background tasks, or parallelize the queue as sufficient permission to create those app-visible background threads. Do not require the user to separately say "create background threads" in the same prompt.
- App-visible thread tools are a hard requirement for implementation workers. Before leasing or launching any task, verify that tool discovery exposes callable equivalents for all three operations: `create_thread`, `read_thread`, and `send_message_to_thread`.
- If app-thread tools are missing, stop orchestration before leasing tasks, report exactly which required operations are unavailable, and ask the user to start/enable a Codex session with app thread management exposed. Do not silently fall back to hidden sub-agents, pre-created worktrees, terminal-only workers, or manual user-created threads.
- Each worker thread must use `$parallel-labyrinth-task` and its isolated worktree workflow.
- Worker branches are temporary isolation branches. After user approval, finished work lands on `master` and pushes `master`; do not publish remote task branches as the final result.
- Do not use hidden sub-agents as implementation workers. Hidden sub-agents are appropriate for scout review and implementation peer review.
- Do not push, land, or clean up completed task work until the user explicitly approves.
- Keep queue state current as part of orchestration, not as a later audit. When a worker reports reviewer signoff and inspection handoff, run `tools/labyrinth_task_queue.py complete`; when the user abandons or blocks work, run `mark abandoned` or `mark blocked`; when approved work lands on `master`, run `landed` before cleanup/reporting. If permissions prevent a queue update, report the exact command still needed.
- App-created worktrees may start detached, and worker sandboxes may be unable to write the primary checkout's shared Git metadata. The orchestrator owns the host-side Git/queue bridge: attach/adopt app worktrees before implementation starts, commit scoped completed diffs when workers report Git index permission blocks, and update queue files when workers cannot.

## Host Tool Requirements

A valid worker launch requires all of these host-provided capabilities:

- A callable app-thread creation tool that creates a user-visible Codex thread.
- A callable app-thread read tool that lets the orchestrator monitor that thread.
- A callable app-thread send-message tool that can deliver the worker prompt.
- A returned thread id and a usable clean project worktree path, or enough thread metadata to identify both before queue leasing.

The repository cannot install or grant these host tools. They must be exposed by the Codex app/session before this skill runs. If `tool_search` cannot find them, the correct result is a visible blocker, not an alternate implementation-worker mechanism.

## Queue States

- `proposed`: scout idea that has not passed review.
- `needs_revision`: scout reviewer requested clearer scope, proof, or collision analysis.
- `ready`: scout-reviewed and available for a worker.
- `leased`: assigned to a worker thread but not yet confirmed in progress.
- `in_progress`: worker has adopted or created its isolated worktree.
- `implementation_review`: worker claims complete and is in the mandatory peer-review loop.
- `ready_for_user`: implementation reviewer signed off and the worker supplied an inspection fixture or explicit not-applicable reason; waiting for user inspection.
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

3. Verify and create one Codex app thread per selected task.
   - First use tool discovery for `create_thread`, `read_thread`, and `send_message_to_thread`, or current host tools whose descriptions explicitly provide those same Codex app-thread operations.
   - Confirm the discovered tools are callable in the current session before changing queue state.
   - If any of the three required operations are missing, do not lease tasks, do not create worktrees, and do not spawn sub-agents as implementation workers. Report a blocker with the missing operations and the exact user-side requirement: restart or enable a Codex app/session that exposes app thread management tools.
   - Create user-visible app threads directly rather than asking the user to create worker threads manually. The skill invocation/request to run the queue is the needed instruction to create these background threads.
   - Prefer a short standby initial prompt until the app returns a thread id and worktree path. Do not send the full implementation prompt until the host-side branch/adopt preflight below succeeds.
   - Record the returned app thread id and worktree path. If either is unavailable, stop and report the blocker before leasing.

4. Run the host-side app-worktree preflight before leasing or sending the full task prompt.
   - App-created project worktrees often start on detached `HEAD`; do not ask the worker sandbox to repair that state.
   - In the returned worktree, verify it is clean and at the expected base:

```bash
git -C <thread-worktree-path> status --short --branch
git -C <thread-worktree-path> rev-parse HEAD
git -C <thread-worktree-path> rev-parse master
```

   - If the worktree is detached and clean at the expected base, attach it from the host side:

```bash
git -C <thread-worktree-path> switch -c codex/<task-id> master
```

   - Then run the normal adoption helper from that worktree:

```bash
cd <thread-worktree-path> && python3 tools/parallel_task.py adopt --task-id <task-id> --task "<title>"
cd <thread-worktree-path> && python3 tools/parallel_task.py status
```

   - If the full worker prompt was already sent and the worker reports `needs Git bridge`, run this same preflight/repair, then send a continuation message telling the worker the branch/adopt state is fixed.

5. Lease the task after the thread exists and the host-side preflight succeeds.

```bash
python3 tools/labyrinth_task_queue.py lease <task-id> --thread-id <codex-thread-id> --branch codex/<task-id> --worktree <thread-worktree-path>
```

6. Send the full task prompt.
   - Give each thread the task JSON, queue id, acceptance criteria, proof requirements, and the instruction to use `$parallel-labyrinth-task`.
   - Tell the worker the app worktree has already been host-adopted when preflight succeeded; the worker should confirm `python3 tools/parallel_task.py status` and `git status --short --branch` before editing.
   - If a worker still sees detached `HEAD` or cannot write Git metadata, it should stop and report `needs Git bridge` with the exact blocked command.

7. Monitor progress.
   - Read worker threads periodically.
   - Use queue `heartbeat` or `mark` when a worker reports meaningful state changes.
   - If a worker stalls or collides with newer work, mark `blocked` with a note rather than silently relaunching duplicate work.
   - Do not leave a task in `leased` after a worker has clearly finished, been abandoned, or landed. Reconcile the queue in the same turn you observe the state transition.
   - If a worker reports that staging or committing is blocked by `.git/worktrees/*/index.lock` or another shared-Git permission error, use the host bridge from that worktree: restore only known incidental generated dirt such as timestamp-only `.codex/memento/shared/current.json`, stage explicit task files instead of `git add .`, commit the task branch, verify `git status --short --branch` is clean, then send the worker the commit hash so it can continue to peer review and fixture handoff.
   - If a worker reports that queue writes are blocked, run the exact `tools/labyrinth_task_queue.py` command from the orchestrator side once the required handoff details are available.

8. Require implementation peer review before user handoff.
   - The worker's `$parallel-labyrinth-task` flow requires a reviewer sub-agent.
   - The worker must resolve reviewer findings and only report back after reviewer `SIGNOFF`.
   - After reviewer `SIGNOFF`, the worker must run `tools/inspection_fixture.py` for a playable inspection state, or provide a clear not-applicable reason for tooling/data-only changes.
   - Mark the queue item `ready_for_user` only when the worker provides the signed-off branch, commit, proof summary, residual risks, and inspection fixture metadata.

```bash
python3 tools/labyrinth_task_queue.py complete <task-id> --reviewer "<reviewer>" --signoff "<summary>" --proof "<tests/probes/screenshots>" --commit <head-commit> --inspection-scenario "<scenario>" --inspection-run-id "<run-id>" --inspection-summary "<what Continue opens>" --inspection-launch "<launch command>"
```

For changes without a useful playable inspection state:

```bash
python3 tools/labyrinth_task_queue.py complete <task-id> --reviewer "<reviewer>" --signoff "<summary>" --proof "<tests/probes/screenshots>" --commit <head-commit> --inspection-not-applicable "<reason>"
```

9. Wait for user approval.
   - Present branch, worktree, commit, reviewer signoff, proof, inspection fixture launch command or not-applicable reason, and residual risks.
   - Do not land or push until the user explicitly says to push, land, publish, merge, or otherwise gives approval.
   - If the user abandons the task, mark it immediately:

```bash
python3 tools/labyrinth_task_queue.py mark <task-id> abandoned --note "<user-facing reason>"
```

10. Land approved work to `master`.
   - Ask the worker thread that owns the worktree to run the approved publish step, or run it yourself in that worktree if the worker is unavailable.
   - `python3 tools/parallel_task.py push` lands the task branch to `origin/master`; it does not push a remote task branch.
   - If `master` moved and is not contained in the task branch, the command refuses. The worker must integrate `master`, rerun relevant proof, repeat implementation peer review, then request approval again if the reviewed diff changed materially.

```bash
python3 tools/parallel_task.py push
python3 tools/labyrinth_task_queue.py landed <task-id> --commit <master-commit> --archive
python3 tools/parallel_task.py cleanup --delete-branch
```

## Worker Thread Prompt

When sending the full worker prompt after host-side preflight, use this shape:

```text
Use $parallel-labyrinth-task for this Labyrinth task.

Queue id: <task-id>
Title: <title>
Priority: <priority>

Task proposal:
<proposal JSON or concise equivalent>

Parallel-safety notes:
<parallel_safety JSON or concise equivalent>

Before editing, confirm the app-created clean worktree was host-adopted:
python3 tools/parallel_task.py status
git status --short --branch

If it is not on `codex/<task-id>`, stop and report `needs Git bridge` with the exact blocked command. Do not invent alternate Git metadata workarounds.

Implement only this task's scope. Commit the finished branch, run the mandatory peer-review gate from $parallel-labyrinth-task, resolve any reviewer feedback, then create a user-inspection fixture with `python3 tools/inspection_fixture.py --scenario <scenario> --summary "<what Continue opens>" ...` or explain why no playable fixture applies. Stop for user inspection after reviewer SIGNOFF and the inspection-fixture step. Provide branch, worktree path, head commit, proof run, screenshots/artifacts if relevant, inspection fixture launch command or not-applicable reason, residual risks, and the reviewer signoff summary.

Do not push or clean up. After user approval, the work must land on master, not a remote task branch.
```

## Status Reporting

When reporting to the user, group tasks by state:

- Running: task id, title, thread, branch, current status, last heartbeat.
- Ready for user: task id, branch, commit, reviewer, proof summary, inspection fixture launch command or not-applicable reason.
- Blocked: blocker, recommended next action.
- Queue health: ready backlog, likely collision risks, and whether more scouting is needed.
