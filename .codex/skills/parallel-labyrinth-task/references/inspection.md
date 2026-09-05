## Done For Inspection

When implementation and verification are complete:

1. Review `git status --short` in the task worktree.
2. Exclude scratch artifacts that should not ship.
3. Commit the task:

```bash
python3 tools/parallel_task.py commit -m "<concise task summary>"
```

If staging or commit is blocked by shared Git metadata permissions despite the starting smoke check, stop and report the exact blocked command plus the explicit task files that should be staged. Treat this as an infrastructure regression for the orchestrator to diagnose before launching more workers under the same creation mode. Do not report ready-for-user until the branch has a real commit, reviewer signoff, and an inspection fixture or not-applicable reason.

4. Run the [peer review gate](review.md).

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
