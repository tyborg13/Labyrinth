## Starting A Task

If an orchestrator is creating a Codex app task, it should first run `parallel_task.py prepare-worker` and create the app worktree from the returned branch `starting_state`. In that new clean app worktree, adopt the checkout before editing:

```bash
python3 tools/parallel_task.py adopt --task "<short task description>"
```

`adopt` fast-forwards the current clean worktree to the local `master` tip, renames the branch to `codex/<task-id>` when needed, and writes private task metadata. To use the remote tracking branch explicitly, pass `--fetch --base origin/master`.

Record the acceptance contract supplied by the user or queue, then run the combined worker-owned preflight:

```bash
python3 tools/parallel_task.py contract --risk-tier <low|standard|high> --acceptance "<observable result>" --required-proof "<proof>" --inspection-expectation "<fixture or not-applicable reason>"
python3 tools/parallel_task.py preflight
```

`preflight` refreshes the index, writes a real Git object, adds/removes a temporary index entry, proves the index tree was restored, and creates/removes a temporary `refs/heads/codex/*` ref. If adoption or preflight fails with ref/index/object permission errors, stop before editing and ask the orchestrator to recreate the app task from the branch returned by `prepare-worker`. Do not plan on a host-side commit bridge for a new worker.

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
