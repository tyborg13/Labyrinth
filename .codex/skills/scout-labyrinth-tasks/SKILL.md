---
name: scout-labyrinth-tasks
description: Find and reviewer-gate concrete Escape the Umbra improvements for the autonomous task queue.
---

# Scout Labyrinth Tasks

Use this skill to discover useful Labyrinth work without immediately implementing it. The scout produces specific task briefs, then gets a separate scout-reviewer agent to approve, revise, or reject them before they are queued for workers.

## Core Rule

Do not enqueue a task as `ready` until a separate reviewer has signed off that it is worth doing, specific enough to execute, faithful to the user's current goals, and practical to prove.

## Scout Workflow

1. Gather current context.
   - Inspect the repo state and the user's latest priorities.
   - Inspect relevant code, specification sections, and recent changes for the candidate area.
   - Prefer concrete signals: failing tests, TODOs, awkward workflows, visual rough edges, content gaps, balance notes, recent user comments, and nearby code patterns.

2. Draft small, independently executable task briefs.
   - Each task should be coherent enough for one worker thread.
   - Prefer tasks that can be proven with tests, visual probes, screenshots, data diffs, or concise manual inspection.
   - Avoid speculative epics, vague polish, and tasks that require broad product judgment mid-implementation.

3. Assess likely collisions without fixed collision groups.
   - List concrete likely touched files, generated asset paths, singleton scripts, data files, test fixtures, and visual probe artifacts.
   - Mention specific active or queued tasks to avoid only when the risk is concrete.
   - Do not use broad categories like "asset pipeline" as a blocking group; the orchestrator should compare actual paths and shared state risks.

4. Spawn a scout-reviewer sub-agent before queue import.
   - Give the reviewer the user's request, scout notes, candidate JSON, active queue summary, and any evidence used to justify the candidates.
   - Ask the reviewer to hold a high bar and approve only tasks that are valuable, specific, collision-aware, and proofable.

5. Revise or discard candidates until the reviewer approves.
   - Import only approved tasks as `ready`.
   - Put tasks that need more shaping in `proposed` or `needs_revision`.
   - Do not launch worker threads from this skill; use `$orchestrate-labyrinth-tasks` for execution.

## Task JSON

Use `.codex/tasks/templates/scout_batch_template.json` as the starting shape. A reviewed task needs:

- `id`: stable lowercase task id.
- `title`: short human-readable title.
- `priority`: 1-5, where 5 is highest value.
- `proposal.problem`: the concrete problem or opportunity.
- `proposal.why_now`: why this is worth a worker now.
- `proposal.proposed_change`: the smallest coherent change.
- `proposal.impact`: expected player, workflow, maintainability, or performance benefit.
- `proposal.risk`: primary regression or complexity risk.
- `proposal.estimated_size`: small, medium, or large.
- `proposal.risk_tier`: `low`, `standard`, or `high` under `spec/development_workflow.md`; this controls proof breadth, not whether peer review happens.
- `proposal.acceptance_criteria`: observable requirements the worker must satisfy.
- `proposal.required_proof`: tests, probes, screenshots, or explanations expected from the worker.
- `proposal.rejection_conditions`: reasons a reviewer or orchestrator should reject the task.
- `parallel_safety.likely_touched_files`: concrete paths or directories likely to change.
- `parallel_safety.shared_state_risks`: global state, generated files, fixtures, or visual probes that may collide.
- `parallel_safety.safe_parallel_neighbors`: examples of work likely safe to run beside it.
- `parallel_safety.avoid_parallel_with`: specific task ids to avoid, not broad categories.
- `parallel_safety.notes`: concise collision rationale.

## Queue Commands

Initialize or inspect the queue:

```bash
python3 tools/labyrinth_task_queue.py init
python3 tools/labyrinth_task_queue.py list
python3 tools/labyrinth_task_queue.py select --limit 5
```

Validate a draft scout batch before review:

```bash
python3 tools/labyrinth_task_queue.py validate /path/to/scout_batch.json
```

Import reviewer-approved tasks:

```bash
python3 tools/labyrinth_task_queue.py import --file /path/to/scout_batch.json --status ready --reviewer "<reviewer agent>" --review-summary "<why the batch was approved>"
```

The queue refuses `ready` imports without an approved scout review or reviewer metadata.

## Scout Reviewer Prompt

Use these reviewer instructions verbatim or equivalently:

```text
You are the scout-reviewer for autonomous Labyrinth work selection. Hold a high bar.

Review the proposed tasks against the user's actual goals, the current repo context, and the cost of spending independent worker threads on them. You are not reviewing implementation code; you are reviewing whether these are the right tasks to queue.

Check all of these areas:
1. Value and fit: Is each task likely to improve Labyrinth in a way that matches the user's priorities and the current project state?
2. Specificity: Can a worker understand exactly what to change without inventing broad product direction?
3. Instruction fidelity: Does the proposed work respect the user's request for autonomous, parallel, isolated work with final user approval?
4. Proofability: Are acceptance criteria, risk tier, required proof, and inspection expectation strong enough that a reviewer can decide whether the task is complete?
5. Collision awareness: Does the task name concrete likely touched files and shared-state risks, and avoid broad collision groups?
6. Queue quality: Is the task small enough for one worker and distinct from other active or ready tasks?

Return one of:
- APPROVE_READY_TASKS, only for tasks that are valuable, specific, proofable, and collision-aware.
- REQUEST_REVISIONS, with concrete edits needed before queueing.
- REJECT_TASKS, for tasks that are vague, low-value, duplicative, risky, or not worth an autonomous worker.

For every approved task, include:
- Requirements checked: why it fits the user's goals.
- Proof checked: why its required proof is enough.
- Collision checked: concrete path/shared-state reasoning.
- Residual risks: anything the orchestrator or worker should watch.
- Verdict: APPROVE_READY_TASKS.

Do not approve tasks just because they sound plausible. If the value, scope, collision analysis, or proof plan is thin, request revisions.
```
