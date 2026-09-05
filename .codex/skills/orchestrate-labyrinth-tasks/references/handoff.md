# Review, inspection, and publication

7. Require implementation peer review before user handoff.
   - The worker's `$parallel-labyrinth-task` flow requires a reviewer sub-agent.
   - The worker must resolve reviewer findings and only report back after reviewer `SIGNOFF`.
   - After reviewer `SIGNOFF`, the worker must run `tools/inspection_fixture.py` for a playable inspection state, or provide a clear not-applicable reason for tooling/data-only changes.
   - Mark the queue item `ready_for_user` only by consuming the worker's verified handoff file. Do not reconstruct applicable fixture evidence with direct `complete --inspection-*` flags.

```bash
python3 tools/labyrinth_task_queue.py handoff <task-id> --reviewer "<reviewer>" --signoff "<summary>" --proof "<tests/probes/screenshots>" --commit <head-commit> --inspection-manifest <fixture-manifest>
# Then run the exact `complete <task-id> --handoff-file ...` command printed by `handoff` from the primary checkout.
```

For changes without a useful playable inspection state:

```bash
python3 tools/labyrinth_task_queue.py handoff <task-id> --reviewer "<reviewer>" --signoff "<summary>" --proof "<tests/probes/screenshots>" --commit <head-commit> --inspection-not-applicable "<reason>"
# Then run the exact `complete <task-id> --handoff-file ...` command printed by `handoff` from the primary checkout.
```

8. Wait for user approval.
   - Present branch, worktree, commit, reviewer signoff, proof, inspection fixture launch command or not-applicable reason, and residual risks.
   - Do not land or push until the user explicitly says to push, land, publish, merge, or otherwise gives approval.
   - If the user abandons the task, mark it immediately:

```bash
python3 tools/labyrinth_task_queue.py mark <task-id> abandoned --note "<user-facing reason>"
```

9. Land approved work to `master`.
   - Ask the worker thread that owns the worktree to run the approved publish step, or run it yourself in that worktree if the worker is unavailable.
   - `python3 tools/parallel_task.py push` lands the task branch to `origin/master`; it does not push a remote task branch.
   - If `master` moved, `push` integrates it and compares the stable effective task patch. An unchanged task patch preserves review and approval; a changed patch or conflict stops publication for renewed proof, review, and approval.

```bash
python3 tools/parallel_task.py authorize-publish --reviewer "<reviewer>" --user-approval "<approval reference>"
python3 tools/parallel_task.py push
python3 tools/labyrinth_task_queue.py landed <task-id> --commit <master-commit> --archive
python3 tools/parallel_task.py cleanup --delete-branch
```
