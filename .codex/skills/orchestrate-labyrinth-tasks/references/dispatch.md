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
- App-visible worker threads are valid for autonomous implementation only after the worker itself passes `parallel_task.py preflight`, which performs reversible object-database, index, and task-branch ref writes. Queue JSON may remain orchestrator-owned; worker handoff is transferred as one independently verified JSON file.

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
   - Before `create_thread`, run:

```bash
python3 tools/parallel_task.py prepare-worker --task-id <task-id> --task "<title>"
```

   - Pass the returned `starting_state` to `create_thread`. This avoids detached-head adoption and branch-ref repair.
   - Send the full worker prompt at creation time. Its first actions must be `adopt`, `contract`, and `preflight`; it continues to implementation only after they succeed. This removes the standby/bootstrap round trip while keeping the capability gate worker-owned.
   - Record the returned thread id and worktree path. If either is unavailable, or the worker reports preflight failure, do not lease the task. Abandon/recreate the thread or report the host limitation; do not use a planned host-side commit bridge.

4. Lease the task after the thread exists and the worker reports successful `preflight`.

```bash
python3 tools/labyrinth_task_queue.py lease <task-id> --thread-id <codex-thread-id> --branch codex/<task-id> --worktree <thread-worktree-path>
```

5. Confirm the task contract from the creation prompt.
   - Give each thread the task JSON, queue id, risk tier, acceptance criteria, proof requirements, and the instruction to use `$parallel-labyrinth-task`.
   - The worker records those fields with `parallel_task.py contract`; high-risk tasks also declare the playable inspection target or why it is not applicable.
   - The worker owns normal task-branch staging/commits and packages final queue details with `labyrinth_task_queue.py handoff`; the orchestrator consumes its single `complete --handoff-file` command.

6. Monitor progress.
   - Read worker threads periodically.
   - Use queue `heartbeat` or `mark` when a worker reports meaningful state changes.
   - If a worker stalls or collides with newer work, mark `blocked` with a note rather than silently relaunching duplicate work.
   - Do not leave a task in `leased` after a worker has clearly finished, been abandoned, or landed. Reconcile the queue in the same turn you observe the state transition.
   - If a worker reports that staging or committing is blocked after `preflight` passed, treat it as a host/sandbox regression. Pause the task and only use a host-side commit bridge as an emergency unblock for already-completed work. Do not launch additional workers under that creation mode until diagnosed.
   - When a worker reports its handoff file, run the exact single `complete --handoff-file` command from the primary checkout.
