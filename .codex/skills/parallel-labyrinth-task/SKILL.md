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
- Commit finished work, then stop for user inspection.
- Do not push or clean up until the user explicitly approves that committed task branch.
- After approval, push the task branch and remove the task worktree.

## Starting A Task

If the Codex app thread is being created for this task, prefer the app's project `worktree` environment starting from the default branch. If you are already inside a shared checkout and need to create the isolated task yourself, run:

```bash
python3 tools/parallel_task.py start --task "<short task description>"
```

That command fetches `origin master`, creates a `codex/<task-id>` worktree under the sibling `Labyrinth.worktrees` directory, and prints the new path plus `LABYRINTH_TASK_ID`.

If network is unavailable and the user accepts local `master`, use:

```bash
python3 tools/parallel_task.py start --no-fetch --task "<short task description>"
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
python3 tools/godot_task_runner.py --task-id <task-id> -- godot --headless --path . --script tests/run_tests.gd
```

The runner gives each Godot process an isolated temp `HOME`, a safe `--log-file`, and a unique `LABYRINTH_TASK_ID` so default `user://` state does not collide across parallel tasks.

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

Then report the commit hash, branch, worktree path, tests/probes run, and any residual risk. Stop there. The user inspects the committed branch and may ask for more changes; if so, continue in the same worktree and create follow-up commits.

## Approval, Push, Cleanup

Only after explicit user approval to publish:

```bash
python3 tools/parallel_task.py push
```

Then remove the task worktree:

```bash
python3 tools/parallel_task.py cleanup
```

If cleanup refuses because there are unpushed commits or local changes, resolve that state instead of forcing by default. Use `--force` only when the user explicitly accepts discarding local worktree state.

## Current Thread Exception

If this skill is being installed, repaired, or tested in the shared checkout, keep edits scoped to the parallel-task infrastructure itself. For all ordinary game/content/UI/code tasks after this infrastructure exists, use an isolated task worktree.
