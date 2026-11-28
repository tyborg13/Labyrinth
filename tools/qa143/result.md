# qa-143 enemy-round analytics on Continue

## Root cause confirmed on release

On `e20cebc191`, the live enemy round holds a locked combat snapshot with the
compact `resume_enemy_phase` marker. Live resolution collects the activation
steps, installs the final checkpoint, then calls
`_analytics_log_enemy_phase_events`. Continue feeds the same activation
resolver into `_combat_commit_checkpoints` and retains its combat commits.
The action and status projections were discarded, so Continue reached the
next player turn without calling the phase writer. At seed 141010, decision 30,
the live round recorded seven actions and each pre-final save recorded zero
after Continue.

## Scope and acceptance

1. Continue retains resolver projections across the existing checkpoint
   loop and passes them to the existing batch writer after the final checkpoint.
2. The batch comes from the compact continuation marker. The completed
   checkpoint control checks that the previously written phase and surface
   rows remain identical after Continue and that no round rows are appended.
3. This uses the existing buffered writer. A hard stop between the checkpoint
   and append can still lose the batch. The projections are kept in memory, so
   interrupting Continue itself can also lose steps from resumed slices that
   the existing checkpoint loop had already committed.
4. Production edits are confined to the enemy checkpoint consumer and its
   call to the existing writer. The headless controls compare the next input
   boundary's room, mode, turn, position, Health, enemy Health and intents,
   initiative queue, and hand.

The design brief is the acceptance contract for this implementation. The local
task metadata points to `codex/release` and has empty acceptance and proof
fields. The design owner has the worktree metadata and publication steps.

## Files

- `scripts/run_scene.gd` retains the resumed phase's non-commit steps and
  player-turn-start snapshot. The resume loop sends the completed phase to
  the existing writer before restoring input.
- `tools/qa143/replay.gd` and its UID capture the save and Continue boundaries.
- `tools/qa143/checkpoint_controls.py` compares the on-disk analytics and
  the next input boundary.
- `tools/qa143/result.md` records the proof and commands.

## Release controls

```text
QA143 RELEASE seed=141010 d=30 save=before uninterrupted=7 resumed=0 dupes=0 PASS
QA143 RELEASE seed=141010 d=30 save=mid uninterrupted=7 resumed=0 dupes=0 PASS
QA143 RELEASE seed=141010 d=30 save=after uninterrupted=7 resumed=0 dupes=0 PASS
QA143 RELEASE seed=141010 d=30 save=written uninterrupted=7 resumed=7 dupes=0 PASS
QA143 CHECKPOINT seed=141010 d=30 written=8 appended_on_continue=0 PASS
QA143 RELEASE seed=141002 d=236 save=mid uninterrupted=7 resumed=0 dupes=0 PASS
```

The first status-seed attempt waited for a specific melee trail and hit the
runner's 240-second timeout. The matched retry saved during `post-action settle`
after an enemy action. Decision 30 still saved during the active Skitter Strike
trail at `(3, 5)` → `(4, 5)`. Its other saves were during the opening banner,
at the hero hand-off before the final checkpoint, and at the next legal player
input after the completed checkpoint.

[Matched release results](/private/tmp/labyrinth_codex/qa-143/release-matched.log) ·
[Release traces and JSONL](/private/tmp/labyrinth_codex/qa-143/release-matched) ·
[Initial status probe log](/private/tmp/labyrinth_codex/qa-143/release/seed-141002-d236-mid/godot.log)

## Candidate controls

```text
QA143 LIVE seed=141010 d=30 rows=50 PASS
QA143 ROUND seed=141010 d=30 save=before uninterrupted=7 resumed=7 dupes=0 PASS
QA143 ROUND seed=141010 d=30 save=mid uninterrupted=7 resumed=7 dupes=0 PASS
QA143 ROUND seed=141010 d=30 save=after uninterrupted=7 resumed=7 dupes=0 PASS
QA143 ROUND seed=141010 d=30 save=written uninterrupted=7 resumed=7 dupes=0 PASS
QA143 CHECKPOINT seed=141010 d=30 written=8 appended_on_continue=0 PASS
QA143 LIVE seed=141002 d=236 rows=440 PASS
QA143 ROUND seed=141002 d=236 save=mid uninterrupted=7 resumed=7 dupes=0 PASS
QA143 PHASE status=1 turn_start=1 PASS
QA143 ANALYTICS RESUME PASS rounds=5
```

The uninterrupted comparison includes every JSONL row from run start through
the target round's next input, preserving row order, sequence numbers, and
all data except timestamps and generated identities. The resumed phase
comparison also accounts for the sequence counter restarting when a new
RunScene is installed. It verifies the same event order, context, and
payloads for actions, status ticks, and `player_turn_started`. The status
fixture included Tunnel Crawler's 3-damage Fire tick at turn start. The
surface receipt comparison checks payloads and order across existing resume
checkpoint writes. The completed-checkpoint lane compares the round's raw
rows before and after Continue.

[Candidate results](/private/tmp/labyrinth_codex/qa-143/candidate.log) ·
[Candidate traces and JSONL](/private/tmp/labyrinth_codex/qa-143/candidate)

## Focused checks

| Check | Exact result on release and candidate |
| --- | --- |
| Encounter analytics and analytics contract suite | `ENCOUNTER CALLER METADATA: PASS (UI/headless; combat, Guardian, boss; start/end/rewards)` and `ENCOUNTER ANALYTICS: PASS (0 failures)` |
| Surface batch | `TEST RESULT: PASS surface analytics batch and partial append recovery` |
| Skill progression | `TEST RESULT: PASS` |
| Deferred combat skill analytics | `TEST RESULT: PASS` (84 checks in 11 cases) |
| Save/resume witness | `TEST RESULT: PASS — committed save/resume boundary matrix` |
| Partial-tail restart | `analytics_restart_test write_exit=247 verify_exit=0` and `PERF03 ANALYTICS KILL/RESTART RESULT: PASS (0 failures; verify)` |
| Rules text lint within the Python default group | `PASS: Rules text lint (16 existing hits)` |

Both Python runs printed `INPUT GROUP default: always run` and
`SELECTED MODULES: 23 of 59`. Release printed
`Ran 196 tests in 36.886s` and `OK`. The candidate printed
`Ran 196 tests in 43.227s` and `OK`.

Both builds emitted the sandbox certificate warning
`ERROR: Condition "ret != noErr" is true. Returning: ""` at startup and
`WARNING: ObjectDB instances leaked at exit (run with --verbose for details).`
in the mid-strike and hero hand-off controls. The save/resume matrix logged
its intentional save failures and existing teardown diagnostics on both
builds. Python's learned timing cache was read-only on both runs, so its
timing update reported `Operation not permitted` after the test results.

[Release focused logs](/private/tmp/labyrinth_codex/qa-143/focused-release) ·
[Candidate focused logs](/private/tmp/labyrinth_codex/qa-143/focused-candidate) ·
[Release Python log](/private/tmp/labyrinth_codex/qa-143/python-release.log) ·
[Candidate Python log](/private/tmp/labyrinth_codex/qa-143/python-candidate.log)

## Commands

The release commands ran before the production edit. The second release
command checked the completed lanes from the first run and generated the
adjusted status-seed lane. Each lane's `command.json` records the expanded
Godot command, directory, and environment.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-143
qa143_output=/private/tmp/labyrinth_codex/qa-143
python3 tools/qa143/checkpoint_controls.py --release --output-dir "$qa143_output/release"
mkdir "$qa143_output/release-matched"
for qa143_lane in "$qa143_output"/release/*; do
  if [ -f "$qa143_lane/summary.json" ]; then
    ln -s "$qa143_lane" "$qa143_output/release-matched/${qa143_lane##*/}"
  fi
done
python3 tools/qa143/checkpoint_controls.py --release --reuse-completed --output-dir "$qa143_output/release-matched"
python3 tools/qa143/checkpoint_controls.py --release-output "$qa143_output/release-matched" --output-dir "$qa143_output/candidate"
python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir "$qa143_output/python-release"
python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir "$qa143_output/python-candidate"
```

The following commands ran once on release and once with the fix.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-143
python3 tools/godot_task_runner.py --task-id qa-143 --stream -- godot --headless --path . --script tests/encounter_analytics_test.gd
python3 tools/godot_task_runner.py --task-id qa-143 --stream -- godot --headless --path . --script tests/surface_analytics_batch_test.gd
python3 tools/godot_task_runner.py --task-id qa-143 --stream -- godot --headless --path . --script tests/skill_progression_analytics_test.gd
python3 tools/godot_task_runner.py --task-id qa-143 --stream -- godot --headless --path . --script tests/deferred_skill_analytics_test.gd -- --simulate-draw
python3 tools/godot_task_runner.py --task-id qa-143 --stream -- godot --headless --path . --script tests/save_resume_boundary_test.gd
```

For the partial-tail restart check, the writer and verifier use the same
fixture directory. Between stages the harness waits for `ready.json` and
terminates the fixture's Godot PID from that file with SIGKILL. The recorded
run directories are `focused-release/analytics-restart` and
`focused-candidate/analytics-restart` under `$qa143_output`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-143
qa143_output=/private/tmp/labyrinth_codex/qa-143
qa143_restart="$qa143_output/focused-candidate/analytics-restart"
python3 tools/godot_task_runner.py --task-id qa-143 --stream --timeout 60 -- godot --headless --path . --script tests/perf/analytics_restart_test.gd -- --directory="$qa143_restart" --stage=write
# From a separate shell, send SIGKILL to the Godot PID in ready.json.
python3 tools/godot_task_runner.py --task-id qa-143 --stream --timeout 60 -- godot --headless --path . --script tests/perf/analytics_restart_test.gd -- --directory="$qa143_restart" --stage=verify
```

## Chosen defaults

The replay uses the prior-guided tutorial profile, stock QA Health of 9,999,
fastest combat settings, normal motion, and no Embrace. The Cel look is off
for headless execution. It uses 120 fixed simulation frames per second, 4×
engine time, and a 240-second task-runner timeout per replay. The two seeded
replay families can run in parallel. The partial-tail fixture has a 60-second
runner timeout. No `TODO_DESIGN` placeholders were needed.

## Proof for the design owner

The brief calls for headless proof. The trace and analytics JSONL files are the
captures for this unit.
