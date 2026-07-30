---
name: parallel-labyrinth-task
description: Run Escape the Umbra coding tasks as isolated Codex worktree tasks. Use when Codex is asked to implement, modify, test, visually QA, commit, push, or clean up Labyrinth project work that should not clobber other active tasks; especially for fresh Codex tasks/threads, background work, parallel work, Godot visual probes, and the inspect-before-push loop.
---

# Parallel Labyrinth Task

Use this skill to turn an ordinary Labyrinth coding request into an isolated task branch/worktree workflow.

## Invariants

- Start each fresh substantive task from the tip of `master` in its own worktree/branch.
- Record an acceptance/proof/risk contract and pass the worker-owned Git preflight before implementation.
- Work only inside that task worktree after it exists.
- Keep Godot runtime state parallel-safe by setting `LABYRINTH_TASK_ID` or using `tools/visual_probe_runner.py`.
- Commit finished work, get explicit signoff from a peer-review sub-agent, create a user-inspection fixture or document why none applies, then stop for user inspection.
- Do not present work as ready for user inspection until peer review has signed off and the inspection-fixture step is complete; if review cannot be obtained, report a blocker instead of a done handoff.
- Do not push, land, or clean up until the user explicitly approves that committed task branch.
- After approval, land the task branch onto `master`, push `master`, then remove the task worktree.
- Any user-facing task runner, visual probe, inspection launch, or other worktree-local command must be a single copy-paste command that starts with `cd <task-worktree> && ...`.
- If the task came from `.codex/tasks` with a queue id, keep the queue record in sync before ending each lifecycle turn. Use `tools/labyrinth_task_queue.py complete` for ready-for-user handoff, `tools/labyrinth_task_queue.py landed` after approved publish to `master`, and `tools/labyrinth_task_queue.py mark <task-id> abandoned|blocked|rejected` when work is stopped. If the worker cannot update the queue because of permissions or missing host access, report the exact command the orchestrator must run.
- In app-created worktrees, `parallel_task.py preflight` must prove branch, object-database, and index writes from the worker sandbox before implementation. If adoption, preflight, staging, or commit fails with Git metadata permissions, stop and report the exact blocked command; do not create alternate Git directories, detached-HEAD commits, or ad hoc metadata workarounds.

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

## During Work

Use the risk-tier proof rules in `spec/development_workflow.md`. Peer review remains mandatory at every tier; the tier controls focused/full/visual proof breadth.

Begin in the task worktree:

```bash
cd <task-worktree>
memento brief <paths-you-expect-to-touch>
python3 tools/parallel_task.py status
python3 tools/parallel_task.py env
```

For normal Godot or test commands, use the task-local Godot runner:

```bash
cd <task-worktree> && python3 tools/godot_task_runner.py --task-id <task-id> --timeout 180 --stream -- godot --headless --path . --script tests/run_tests.gd
```

The runner gives each Godot process an isolated temp `HOME`, a safe `--log-file`, and a unique `LABYRINTH_TASK_ID` so default `user://` state does not collide across parallel tasks. It terminates commands after 300 seconds by default, accepts `--timeout <seconds>` to tune that limit, accepts `--timeout 0` for intentionally unbounded local runs, and `--stream` tees output live while preserving captured output for Godot failure-marker scanning.

For visual probes, use the validated runner instead of invoking probe scripts directly:

```bash
cd <task-worktree> && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy tests/ui_probe.gd --task-id <task-id>
cd <task-worktree> && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy tests/motion_probe.gd --task-id <task-id>
```

The visual runner uses the same temp-home isolation, disables Steam, assigns a unique `user://` namespace per process, serializes non-headless GUI renderer access, defaults macOS capture to ANGLE with native fallback, rejects generated `.import`/`.uid` noise, and validates emitted PNGs. It defaults to one attempt, a 30-second total process timeout, an 8-second startup watchdog, and a 30-second GUI-lease wait. A startup or execution timeout fails immediately instead of retrying another backend; `--timeout`, `--startup-timeout`, `--gui-lease-timeout`, and `--attempts` remain configurable for known probe behavior. Use repeatable `--expect-size`, `--proof-contract`, and `--result-manifest` for exact-resolution and semantic proof. If a completed probe fails under the default renderer, retry with an explicit backend such as:

```bash
cd <task-worktree> && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --rendering-driver opengl3_angle tests/ui_probe.gd --task-id <task-id>
```

For headless playtests, always use unique output directories:

```bash
cd <task-worktree> && godot --headless --path . --script tools/headless_playtest.gd -- --seed <seed> --output-dir res://playtest/<task-id>/<run-id>
```

## Done For Inspection

When implementation and verification are complete:

1. Review `git status --short` in the task worktree.
2. Exclude scratch artifacts that should not ship.
3. Commit the task:

```bash
python3 tools/parallel_task.py commit -m "<concise task summary>"
```

If staging or commit is blocked by shared Git metadata permissions despite the starting smoke check, stop and report the exact blocked command plus the explicit task files that should be staged. Treat this as an infrastructure regression for the orchestrator to diagnose before launching more workers under the same creation mode. Do not report ready-for-user until the branch has a real commit, reviewer signoff, and an inspection fixture or not-applicable reason.

4. Run the peer review gate below.

After reviewer signoff, prepare the user-inspection fixture:

```bash
python3 tools/inspection_fixture.py --scenario <scenario> --summary "<what Continue opens>" <fixture-options>
```

Use the fixture whenever a playable state can make the change easier to inspect. Common scenarios are `combat`, `reward`, `campfire`, `treasure`, `character`, `boss`, `start`, `victory`, and `defeat`. Add focused options such as `--hand`, `--reward-cards`, `--relics`, `--attuned-magic`, `--magic-inventory`, `--equip`, `--equipment-inventory`, `--player-hp`, or `--room-coord` so the Continue button lands near the changed behavior. If the task is tooling-only, analytics-only, data-only with no meaningful playable state, or otherwise not inspectable in-game, record a concise not-applicable reason instead of forcing a fake fixture.

The fixture must open at the beginning of the inspectable moment, before the user makes the relevant choice or action. The wrapper generates the save, hashes the complete persisted run and progression state, reloads and verifies its embedded contract in a second Godot process, writes a structured manifest, and reports a self-healing launch command that regenerates the pre-action state before opening the game. Use that command for every handoff, including follow-up inspection. The queue handoff and completion commands independently rerun that standard verifier; a hand-authored `verified` field is not evidence.

For Steam-specific user inspection, pass `--allow-steam` to `inspection_fixture.py`. Fixture generation and verification still disable Steam; only the final interactive launch receives the opt-in.

Report the commit hash(es), branch, worktree path, reviewer signoff summary, tests/probes/proofs run, inspection fixture scenario and launch command or not-applicable reason, and any residual risk. Stop there. The user inspects the committed branch and may ask for more changes; if so, continue in the same worktree, create follow-up commits, repeat peer review, and regenerate the inspection fixture before handing it back again.

When reporting an inspection launch command, include the worktree change-directory prefix, for example:

```bash
cd <task-worktree> && python3 tools/inspection_fixture.py --task-id <task-id> --run-id <run-id> --launch --scenario <scenario> --summary "<what opens>" <fixture-options>
```

For queued tasks, package the handoff once after signoff:

```bash
python3 tools/labyrinth_task_queue.py handoff <task-id> --reviewer "<reviewer>" --signoff "<summary>" --proof "<tests/probes/screenshots>" --inspection-manifest <fixture-manifest>
```

For changes without a playable inspection fixture, replace the manifest flag with `--inspection-not-applicable "<reason>"`. The helper writes one JSON handoff and prints the single `complete --handoff-file` command for the orchestrator. Queue JSON remains orchestrator-owned.

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

## Current Thread Exception

If this skill is being installed, repaired, or tested in the shared checkout, keep edits scoped to the parallel-task infrastructure itself. For all ordinary game/content/UI/code tasks after this infrastructure exists, use an isolated task worktree.
