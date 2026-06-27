---
name: parallel-labyrinth-task
description: Run Labyrinth of Ash coding tasks as isolated Codex worktree tasks. Use when Codex is asked to implement, modify, test, visually QA, commit, push, or clean up Labyrinth project work that should not clobber other active tasks; especially for fresh Codex tasks/threads, background work, parallel work, Godot visual probes, and the inspect-before-push loop.
---

# Parallel Labyrinth Task

Use this skill to turn an ordinary Labyrinth coding request into an isolated task branch/worktree workflow.

## Invariants

- Start each fresh substantive task from the tip of `master` in its own worktree/branch.
- Work only inside that task worktree after it exists.
- Keep Godot runtime state parallel-safe by setting `LABYRINTH_TASK_ID` or using `tools/visual_probe_runner.py`.
- Commit finished work, get explicit signoff from a peer-review sub-agent, then stop for user inspection.
- Do not present work as ready for user inspection until peer review has signed off; if review cannot be obtained, report a blocker instead of a done handoff.
- Do not push, land, or clean up until the user explicitly approves that committed task branch.
- After approval, land the task branch onto `master`, push `master`, then remove the task worktree.

## Starting A Task

If the Codex app thread is being created for this task, prefer the app's project `worktree` environment starting from the default branch. In that new clean app worktree, adopt the checkout before editing:

```bash
python3 tools/parallel_task.py adopt --task "<short task description>"
```

`adopt` fast-forwards the current clean worktree to the local `master` tip, renames the branch to `codex/<task-id>` when needed, and writes private task metadata. To use the remote tracking branch explicitly, pass `--fetch --base origin/master`.

If you are already inside a shared checkout and need to create the isolated task yourself, run:

```bash
python3 tools/parallel_task.py start --task "<short task description>"
```

That command creates a `codex/<task-id>` worktree from the local `master` tip under the sibling `Labyrinth.worktrees` directory and prints the new path plus `LABYRINTH_TASK_ID`. To use the remote tracking branch explicitly, pass `--fetch --base origin/master`.

If you need a specific base ref, use:

```bash
python3 tools/parallel_task.py start --base <ref> --task "<short task description>"
```

After the worktree exists, move all implementation, tests, probes, and commits into that worktree. Do not edit the original shared checkout for the task.

## During Work

Begin in the task worktree:

```bash
cd <task-worktree>
memento brief <paths-you-expect-to-touch>
python3 tools/parallel_task.py status
python3 tools/parallel_task.py env
```

For normal Godot or test commands, use the task-local Godot runner:

```bash
python3 tools/godot_task_runner.py --task-id <task-id> --timeout 180 --stream -- godot --headless --path . --script tests/run_tests.gd
```

The runner gives each Godot process an isolated temp `HOME`, a safe `--log-file`, and a unique `LABYRINTH_TASK_ID` so default `user://` state does not collide across parallel tasks. It terminates commands after 300 seconds by default, accepts `--timeout <seconds>` to tune that limit, accepts `--timeout 0` for intentionally unbounded local runs, and `--stream` tees output live while preserving captured output for Godot failure-marker scanning.

For visual probes, use the validated runner instead of invoking probe scripts directly:

```bash
python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --timeout 120 tests/ui_probe.gd --task-id <task-id>
python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --timeout 120 tests/motion_probe.gd --task-id <task-id>
```

The visual runner uses the same temp-home isolation, assigns a unique `user://` namespace per process, validates emitted PNGs, and retries blank or near-blank screenshots. If a probe still fails under the default renderer, retry with an explicit backend such as:

```bash
python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --rendering-driver opengl3_angle tests/ui_probe.gd --task-id <task-id>
```

For headless playtests, always use unique output directories:

```bash
godot --headless --path . --script tools/headless_playtest.gd -- --seed <seed> --output-dir res://playtest/<task-id>/<run-id>
```

## Done For Inspection

When implementation and verification are complete:

1. Review `git status --short` in the task worktree.
2. Exclude scratch artifacts that should not ship.
3. Commit the task:

```bash
python3 tools/parallel_task.py commit -m "<concise task summary>"
```

4. Run the peer review gate below.

After reviewer signoff, report the commit hash(es), branch, worktree path, reviewer signoff summary, tests/probes/proofs run, and any residual risk. Stop there. The user inspects the committed branch and may ask for more changes; if so, continue in the same worktree, create follow-up commits, and repeat peer review before handing it back again.

## Peer Review Gate

Every completed task branch needs a reviewer sub-agent before user handoff. The reviewer must be a separate agent from the one that implemented the change. Spawn the reviewer after the acting agent believes the work is complete and the task branch has a stable commit or follow-up commit to review.

Reviewer handoff must include:

- The user's original task request and any later clarifications.
- The task branch, worktree path, base commit/ref, and current head commit.
- The intended behavior change and changed files.
- The verification evidence: tests, visual probes, screenshots/artifacts, command outputs, and any explanation needed to connect proof to the requirement.
- Known risks, skipped checks, or assumptions.

Use these reviewer instructions, verbatim or equivalently:

```text
You are the required peer reviewer for a Labyrinth task branch. Hold a high bar.

Review the change in totality against the user's actual request, not merely against the implementer's summary. You are not here to be agreeable; you are here to protect correctness and completeness before the user sees the work.

Check all of these areas:
1. Correctness: Does the implementation work, avoid regressions, respect repo patterns, and avoid unsafe or unnecessary changes?
2. Instruction fidelity: Does it do exactly what the user asked for, including all clarifications and implied workflow constraints?
3. Proof sufficiency: Are the tests, visual probes, screenshots, command outputs, and explanations enough to convince you the change works and is complete? If proof is too narrow, stale, missing, or disconnected from the requirement, request more proof.

Return one of:
- SIGNOFF, only after showing your review work in the format below.
- REQUEST_CHANGES, with specific findings ordered by severity, including file/line references or exact missing proof where applicable.

SIGNOFF responses must include all of these sections:
- Requirements checked: restate each material user requirement or clarification and say how the branch satisfies it.
- Files/diff reviewed: list the changed files or major diff areas you inspected, with any relevant line references.
- Proof reviewed: list the tests, probes, screenshots, command outputs, or explanations you relied on, and explain why that proof is sufficient for the change.
- Residual risks: name any remaining risks, assumptions, or skipped checks; write "none found" only if you actually found none.
- Verdict: `SIGNOFF`.

Do not give a bare signoff or one-paragraph approval. Do not sign off if you have unresolved correctness concerns, instruction-fidelity concerns, or proof gaps.
```

If the reviewer returns `REQUEST_CHANGES`, the acting agent must address the findings in the same task worktree, commit the follow-up, rerun relevant verification, and send the updated branch/proof back to a reviewer. This loop continues until the reviewer returns `SIGNOFF`.

If the acting agent disagrees with a reviewer finding, it may respond with evidence and ask the reviewer to reconsider, but it must not suppress the finding or present the work as ready without reviewer signoff.

## Approval, Push To Master, Cleanup

Only after explicit user approval to publish, land the approved task branch on `master`:

```bash
python3 tools/parallel_task.py push
```

`push` publishes to `origin/master`; it does not publish a remote task branch. It fetches remote `master` first and refuses to land if that `master` is not contained in the task branch. If that happens, integrate `master` into the task branch, rerun relevant proof, repeat the peer-review gate if the reviewed diff changed materially, and ask the user for approval again.

Then remove the task worktree:

```bash
python3 tools/parallel_task.py cleanup
```

If cleanup refuses because the branch is not reachable from `master` or because there are local changes, resolve that state instead of forcing by default. Use `--force` or `--no-require-pushed` only when the user explicitly accepts discarding or cleaning up unlanded local worktree state.

## Current Thread Exception

If this skill is being installed, repaired, or tested in the shared checkout, keep edits scoped to the parallel-task infrastructure itself. For all ordinary game/content/UI/code tasks after this infrastructure exists, use an isolated task worktree.
