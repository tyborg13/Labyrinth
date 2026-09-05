## Approval, Push To Master, Cleanup

Only after explicit user approval to publish, land the approved task branch on `master`:

```bash
python3 tools/parallel_task.py authorize-publish --reviewer "<reviewer>" --user-approval "<approval reference>"
python3 tools/parallel_task.py push
```

`authorize-publish` binds peer signoff and explicit user approval to the exact current HEAD. `push` publishes to `origin/master`; it does not publish a remote task branch. It fetches remote `master` first. When master advanced, it mechanically integrates master and compares the stable effective task patch. If that patch is unchanged, authorization transfers to the mechanical merge commit and push continues. If the task patch changed or the merge conflicts, authorization is invalidated and every later push stays blocked; rerun affected proof and peer review, request approval for the changed branch, and authorize the new HEAD. A dirty primary checkout only skips the optional local-master fast-forward and does not block remote publication.

Then remove the task worktree:

```bash
python3 tools/parallel_task.py cleanup
```

For queued tasks, update the queue after the publish succeeds and before cleanup/reporting:

```bash
python3 tools/labyrinth_task_queue.py landed <task-id> --commit <master-commit>
```

If cleanup refuses because the branch is not reachable from `master` or because there are local changes, resolve that state instead of forcing by default. Use `--force` or `--no-require-pushed` only when the user explicitly accepts discarding or cleaning up unlanded local worktree state.
