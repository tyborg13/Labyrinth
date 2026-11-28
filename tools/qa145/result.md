# qa-145 save failure recovery

Base `c234028b2` on `codex/qa-145`. The changes are uncommitted.

The [round 4 results](#round-4-on-07e4f0b1f) include the current native capture command.

## Acceptance

1. Dragon reward Continue and Complete Ascent use the latest checkpoint result for that milestone. A saved reward loaded from disk can show the tooltip. The failure flag and tooltip state live in the scene.
2. A failed victory checkpoint publishes the existing `SAVE_FAILURE_NOTICE` through the run log on the reward screen. The won state stays in memory and the preceding fight checkpoint stays on disk. The next successful save of the revealed reward clears the notice.
3. A failed Save & Quit releases the title guard, restores scene processing and GUI input, and shows the existing departure notice. The regression test blocks the run checkpoint and then the profile write separately before allowing the retry to reach title. It observes exactly one staged card-play event across the attempts.
4. All six fel-28 checkpoint comparisons matched. The window-close preparation, title departure, save/resume, crash replay, and deferred analytics checks passed. The save format and ordered writer are the existing ones.

## Failure injection

The test uses the gfix-24/25 pattern from `tests/save_resume_boundary_test.gd` and makes the writer's `.tmp` location a directory. It removes the blocker before retrying. The earlier durable fight is inspected without flushing the pending writes.

### Base

```text
QA145 TOOLTIP failed=Your rewards have been saved. saved=Your rewards have been saved.
QA145 VICTORY_NOTICE shown=false retry_saved=true
QA145 SAVE_QUIT failed_stays=false input_ok=false retry_leaves=false analytics_dupes=0
QA145 FAIL cases=0
```

The runner returned 1. [Base log](/private/tmp/labyrinth_codex/qa145.56e0Vk/before-settled.log)

### Working tree

```text
QA145 TOOLTIP failed= saved=Your rewards have been saved.
QA145 VICTORY_NOTICE shown=true retry_saved=true
QA145 SAVE_QUIT failed_stays=true input_ok=true retry_leaves=true analytics_dupes=0
QA145 PASS cases=3
```

The runner returned 0. [Working-tree log](/private/tmp/labyrinth_codex/qa145.56e0Vk/after-settled.log)

An interim probe found a fixture startup write racing the blocker. The final probe drains the fixture checkpoint before injection.

### Commands

Run from the task worktree. The baseline uses a scratch project with the source files listed below materialized from the base and the rest linked to this worktree. The new test runs unchanged in both projects.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-145
qa145_base="$PWD/tools/qa145/.baseline"
mkdir -p "$qa145_base/scripts" "$qa145_base/.godot"
touch "$qa145_base/.gdignore"
python3 - <<'PY'
from pathlib import Path
import subprocess

root = Path.cwd()
base = root / "tools/qa145/.baseline"
owned = {"run_scene.gd", "run_persistence.gd", "application_shutdown.gd", "section_transition.gd"}
for item in root.iterdir():
    if item.name.startswith(".") or item.name in {"scripts", "output"}:
        continue
    (base / item.name).symlink_to(item, target_is_directory=item.is_dir())
for sub in ("scripts", ".godot"):
    for item in (root / sub).iterdir():
        target = base / sub / item.name
        if sub == "scripts" and item.name in owned:
            target.write_bytes(subprocess.check_output(["git", "show", "c234028b2:scripts/" + item.name]))
        else:
            target.symlink_to(item, target_is_directory=item.is_dir())
PY

python3 tools/godot_task_runner.py --task-id qa-145 --stream -- godot --headless --path tools/qa145/.baseline --script res://tests/save_failure_recovery_test.gd
python3 tools/godot_task_runner.py --task-id qa-145 --stream -- godot --headless --path . --script tests/save_failure_recovery_test.gd
```

## Success regressions

| Command target | Result |
| --- | --- |
| `tests/save_resume_boundary_test.gd` | `TEST RESULT: PASS — committed save/resume boundary matrix` |
| `tests/main_menu_resume_test.gd` | `TEST RESULT: PASS — main menu resume safety` |
| `tests/save_pipeline_performance_test.gd` | `TEST RESULT: PASS — save pipeline compatibility and cleanup` |
| `tests/application_shutdown_test.gd` | `QA84 APPLICATION SHUTDOWN TEST RESULT: PASS (18 assertions; 0 failures)` |
| `tests/perf/background_persistence_test.gd` | `PERF03 CHECKPOINT CRASH SAFETY: PASS (3 transaction boundaries)` and `PERF03 DEFERRED PERSISTENCE RESULT: PASS (0 failures)` |
| `tests/deferred_skill_analytics_test.gd -- --simulate-draw` | `TEST RESULT: PASS` (84 checks, zero errors) |
| `tests/dragon_rewards_test.gd` | `Dragon rewards, gifts, wallet recovery and relic hooks passed.` |
| `tests/dragon_reward_feedback_test.gd` | `Dragon reward feedback logic: PASS` |
| `tests/departed_run_cleanup_test.gd` | `DEPARTED CLEANUP RESULT: {"cases":3,"draining_at_menu":true,"errors":[],"native":false,"orphans":0}` |
| `tools/gfix40/departure.gd -- main_menu` | `GFIX40 main_menu: 9 checks, 0 failures` |
| `tools/gfix40/departure.gd -- application` | `GFIX40 application: 11 checks, 0 failures` |
| Escape profile-promotion crash and relaunch | `TERMINAL CRASH: escape bank=720 checkpoint=reward held=720` and `TEST RESULT: PASS — escape terminal crash recovery` |
| Defeat checkpoint-promotion crash and relaunch | `TERMINAL CRASH: defeat terminal checkpoint promoted` and `TEST RESULT: PASS — defeat terminal crash recovery` |
| Python default group | `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 37.704s`, `OK` |
| Program-suite registry checks after adding the test | `Ran 42 tests in 40.666s`, `OK` |
| Rules text lint in Python default group | `PASS: Rules text lint (16 existing hits)` |
| UI identity lint | `Ran 25 tests in 7.182s`, `OK` |
| Godot metadata import | Exit 0, generated `tests/save_failure_recovery_test.gd.uid` |

[Regression logs](/private/tmp/labyrinth_codex/qa145.56e0Vk)

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-145
qa145_godot() {
  python3 tools/godot_task_runner.py --task-id qa-145 --stream -- godot --headless --path . "$@"
}
for qa145_case in save_resume_boundary main_menu_resume save_pipeline_performance application_shutdown perf/background_persistence dragon_rewards dragon_reward_feedback departed_run_cleanup; do
  qa145_godot --script "tests/${qa145_case}_test.gd"
done
qa145_godot --script tests/deferred_skill_analytics_test.gd -- --simulate-draw
for qa145_case in main_menu application; do
  LABYRINTH_GFIX40_OUT=/private/tmp/labyrinth_codex/qa145.56e0Vk/gfix40 qa145_godot --script tools/gfix40/departure.gd -- "$qa145_case"
done
for qa145_phase in crash relaunch; do
  qa145_godot --script tests/main_menu_resume_test.gd -- "--terminal-$qa145_phase" --path=escape --output=/private/tmp/labyrinth_codex/qa145.56e0Vk/terminal/escape-profile
  qa145_godot --script tests/main_menu_resume_test.gd -- "--terminal-$qa145_phase" --path=defeat --output=/private/tmp/labyrinth_codex/qa145.56e0Vk/terminal/defeat --after-terminal-checkpoint
done
python3 tools/run_python_suite.py --shards 4 --changed-since c234028b2 --output-dir /private/tmp/labyrinth_codex/qa145.56e0Vk/python
python3 -m unittest discover -s tests -p test_program_suite_runner.py
python3 tests/test_ui_identity_lint.py
python3 tools/godot_task_runner.py --task-id qa-145 --allow-editor-scan --stream -- godot --headless --path . --import
git diff --check
```

The terminal crash phases deliberately killed their fixture processes, and the runner returned 247 in both cases. The first escape invocation used the defeat-only checkpoint hook and reported `TEST RESULT: FAIL — process survived the terminal checkpoint write for escape`. The first deferred-skill invocation omitted `--simulate-draw` and reported `TEST RESULT: FAIL` after waiting for rendered frames. The commands above use the existing applicable modes.

### fel-28 comparisons

```text
FEL28 shadow quit_death_save before=reward after=reward PASS
FEL28 shadow quit_victory_save before=reward after=reward PASS
FEL28 shadow quit_reveal_save before=reward after=reward PASS
FEL28 enemy_turn quit_death_save before=combat after=combat PASS
FEL28 enemy_turn quit_victory_save before=combat after=combat PASS
FEL28 enemy_turn quit_reveal_save before=reward after=reward PASS
FEL28 PASS cases=6
```

Compared every field in the saved states after removing `run_stats.run_seconds`, the existing fel-28 comparison rule for the sampled wall clock. [Comparisons](/private/tmp/labyrinth_codex/qa145.56e0Vk/fel28-comparisons.log)

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-145
for qa145_build in base after; do
  qa145_project=.
  if [[ "$qa145_build" == base ]]; then qa145_project=tools/qa145/.baseline; fi
  for qa145_case in shadow enemy_turn; do
    for qa145_phase in death victory reveal; do
      qa145_take="/private/tmp/labyrinth_codex/qa145.56e0Vk/$qa145_build/$qa145_case-$qa145_phase"
      mkdir -p "$qa145_take"
      FEL28_CASE="$qa145_case" FEL28_QUIT_AT="$qa145_phase" FEL28_OUTPUT="$qa145_take" \
        python3 tools/godot_task_runner.py --task-id qa-145 --stream -- godot --headless --path "$qa145_project" --script res://tools/fel28/probe.gd
    done
  done
done
```

The first four base takes ran directly in this worktree before production edits. The verified enemy-turn victory and reveal base takes are in `base-verified`.

```bash
python3 - /private/tmp/labyrinth_codex/qa145.56e0Vk <<'PY'
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
matched = 0
for case in ("shadow", "enemy_turn"):
    for phase in ("death", "victory", "reveal"):
        relative = Path(f"{case}-{phase}") / "quit-save.json"
        base = "base-verified" if case == "enemy_turn" and phase != "death" else "base"
        before, after = (json.loads((root / build / relative).read_text()) for build in (base, "after"))
        for state in (before, after):
            state.get("run_stats", {}).pop("run_seconds", None)
        passed = bool(before) and before == after
        matched += passed
        print(f"FEL28 {case} quit_{phase}_save before={before.get('mode')} after={after.get('mode')} {'PASS' if passed else 'FAIL'}")
        if not passed:
            print("FEL28 SAVE DIFFERENCES", *(key for key in sorted(before.keys() | after.keys()) if before.get(key) != after.get(key)))
print(f"FEL28 {'PASS' if matched == 6 else 'FAIL'} cases={matched}")
sys.exit(matched != 6)
PY
```

## Proof for the design owner

The sandbox has no window-server access. Run this command on a desktop to render and verify four 1920×1080 captures at 100% UI scale.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-145
export QA145_CAPTURE_DIR="$(mktemp -d /private/tmp/labyrinth_codex/qa145-native.XXXXXX)"
python3 tools/visual_probe_runner.py tests/save_failure_recovery_test.gd --task-id qa-145 --no-headless --display-driver macos --audio-driver Dummy --timeout 90 --expect-size 1920x1080 --proof-contract tools/qa145/proof_contract.json --result-manifest "$QA145_CAPTURE_DIR/proof.json"
```

The PNGs will be `01-reward-save-failed.png`, `02-reward-save-succeeded.png`, `03-save-quit-failed.png` and `04-save-quit-retried.png` in `$QA145_CAPTURE_DIR`. The probe checks native hover and tooltip visibility, the two notices, pause-menu input and the eventual title transition. Native inspection and the independent judge are design-owner work.

## Files

- `scripts/run_scene.gd` renders the checkpoint outcome and handles recovery after a failed Save & Quit.
- `scripts/run_persistence.gd` returns departure write outcomes and reports reward checkpoint outcomes to the scene.
- `scripts/application_shutdown.gd` releases the failed title departure guard and preserves the desktop-close drain when a close joins the save.
- `tests/save_failure_recovery_test.gd` and its UID cover the three decisions and produce the native captures.
- `tests/headless_test_programs.json` registers the regression alongside the save/resume suite.
- `tools/qa145/proof_contract.json` and this report define and record the proof.

## Chosen defaults

- The headless and native probe use the existing fixture seed `90217`, depth 4, and the fel-28 lethal-fire turn. Those settings affect only the test fixture.
- The probe allows 45 seconds for readiness, rests its pointer at `(8, 8)`, and waits two seconds for a native tooltip.
- The native command allows 90 seconds for boot, combat playback, and four captures. Its pixel contract checks the central `[550, 280, 820, 700]` region with luma range and standard deviation floors of 8 and 2.

## Open items

- No `TODO_DESIGN_*` placeholders. No `BLOCKER_departure_undo`.
- Native captures and their inspection are pending. The full suites are reserved for the design owner's merge.
- The read-only `GIT_OPTIONAL_LOCKS=0 python3 tools/parallel_task.py status` returned `"contract_ready": false` with empty acceptance and proof fields. Verification followed the brief's high-risk contract. The task metadata needs the design owner's check.
- `spec/analytics.md` still describes the earlier Save & Quit failure policy. It is outside this unit's owned files. The Python default group passed and reported that its optional timing cache is read-only.

## Feedback on `5d825b037`

The round below uses `5d825b037` as its base. The original results above describe the earlier round. The analytics specification at this base already describes the policy in effect and remains unchanged.

| Finding | Fix and check |
| --- | --- |
| 1. Save & Quit during Pass playback | Combat continuations wait while the title save is pending. Cancellation resumes the held enemy round and lets it finish its analytics and player-input handoff. The test injects a profile write failure between slices with both skill queues pending. It checks the exact number of enemy actions and sends a second Pass through the restored chip. |
| 2a. Background writes | The ordered writer reports each attempt for the reward identity. The test restores writes and reads the live file directly while awaiting the automatic retry. It verifies the retry-specific Ember change, the saved tooltip and removal of the notice. |
| 2b. Migration and identity | The resumed reward derives its status from the required migration write. Completions for a different run or reward do not affect the open offer. The test blocks a legacy dragon reward migration, inspects the unmigrated file, then verifies the written migration, tooltip and cleared notice. |
| 3. Stale persistent notice | Cancellation refreshes the persistent message from current flags before showing the departure toast. The test allows the run checkpoint while blocking the profile write, then advances the toast clock and checks that the previous victory notice stays cleared. |
| 4a. Guardian trophy | Victory checkpoint feedback includes an unclaimed Guardian trophy in treasure mode. The test reaches the trophy through a Guardian victory and checks the notice through failure and retry. |
| 4b. Event screen | The direct departure toast uses the existing notice panel and raises it above the event. The test checks the event stays open, the departure toast is visible, and ordinary notice suppression returns when the toast expires. |
| 5. Desktop close during title handoff | Successful Save & Quit guards the cursor delay until scene change. The headless test emits the actual close signal during that delay and holds the desktop drain open past it. It checks that title never opens and a second departure save never runs. |
| 6. Regression coverage | The save program inspects the durable retry-specific state without flushing, checks notice expiry, and exercises the cases above. |

### Headless results

```text
QA145 REWARD_IDENTITY isolated=true
QA145 TOOLTIP failed= saved=Your rewards have been saved.
QA145 VICTORY_NOTICE shown=true retry_saved=true
QA145 BACKGROUND_RETRY saved=true notice_cleared=true
QA145 PROFILE_FAILURE stayed=true toast=true stale_notice=false
QA145 SAVE_QUIT failed_stays=true input_ok=true retry_leaves=true analytics_dupes=0
QA145 RESUME_MIGRATION failed_shown=true old_disk=true migrated=true notice_cleared=true
QA145 GUARDIAN trophy=true notice=true recovered=true
QA145 EVENT_DEPARTURE shown=true above_event=true other_notices_suppressed=true
QA145 ENEMY_PLAYBACK cancelled=true queues_pending=true adopted=true input_ok=true enemy_actions=3 expected=3
QA145 PASS cases=3
QA145 CLOSE_DURING_TITLE guarded=true title_changed=false drained=true extra_saves=0 PASS
```

| Focused check | Result |
| --- | --- |
| Save/resume boundary | `TEST RESULT: PASS — committed save/resume boundary matrix` |
| Main-menu resume | `TEST RESULT: PASS — main menu resume safety` |
| Save pipeline | `TEST RESULT: PASS — save pipeline compatibility and cleanup` |
| Application shutdown | `QA84 APPLICATION SHUTDOWN TEST RESULT: PASS (18 assertions; 0 failures)` |
| Shutdown reentrancy | `QA-74 SHUTDOWN REENTRANCY TEST RESULT: PASS (14 assertions; 0 failures)` |
| Background persistence | `PERF03 CHECKPOINT CRASH SAFETY: PASS (3 transaction boundaries)` and `PERF03 DEFERRED PERSISTENCE RESULT: PASS (0 failures)` |
| Deferred combat skill analytics | `TEST RESULT: PASS` with `--simulate-draw` |
| Departed-run cleanup | `DEPARTED CLEANUP RESULT: {"cases":3,"draining_at_menu":true,"errors":[],"native":false,"orphans":0}` |
| Heirloom notifications | `FULL PANEL NOTICE CHECKS: PASS`, `HEIRLOOM NOTIFICATION SAVE AND QUIT CHECKS: PASS`, and `TEST RESULT: PASS` |
| Event view | `Event view suite: 0 failures` |
| Dragon reward checks | `Dragon rewards, gifts, wallet recovery and relic hooks passed.` and `Dragon reward feedback logic: PASS` |
| Forced departure probes | `GFIX40 main_menu: 9 checks, 0 failures` and `GFIX40 application: 11 checks, 0 failures` |
| UI identity lint | `Ran 25 tests in 7.308s` and `OK` |

The forced title probe initially exposed player-card continuations running after the scene detached. The final probe passed after those continuations also joined the pending departure check. The optional standalone deferred **run** skill test requires real draw pulses and reported a headless timeout. Both actual deferred queues were pending in the passing Pass interruption case. [Round logs](/private/tmp/labyrinth_codex/qa145-r1.Z9237g)

### Commands

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-145
qa145_godot() {
  python3 tools/godot_task_runner.py --task-id qa-145 --stream -- godot --headless --path . "$@"
}
qa145_godot --script tests/save_failure_recovery_test.gd
qa145_godot --script tests/save_failure_recovery_test.gd -- --close-during-title
qa145_godot --script tests/save_failure_recovery_test.gd -- --enemy-playback
for qa145_case in save_resume_boundary main_menu_resume application_shutdown shutdown_reentrancy perf/background_persistence departed_run_cleanup heirloom_notification event_view dragon_rewards dragon_reward_feedback save_pipeline_performance; do
  qa145_godot --script "tests/${qa145_case}_test.gd"
done
qa145_godot --script tests/deferred_skill_analytics_test.gd -- --simulate-draw
LABYRINTH_GFIX40_OUT=/private/tmp/labyrinth_codex/qa145-r1.Z9237g/gfix40-final qa145_godot --script tools/gfix40/departure.gd -- main_menu
LABYRINTH_GFIX40_OUT=/private/tmp/labyrinth_codex/qa145-r1.Z9237g/gfix40 qa145_godot --script tools/gfix40/departure.gd -- application
python3 tools/run_python_suite.py --shards 4 --changed-since 5d825b037 --output-dir /private/tmp/labyrinth_codex/qa145-r1.Z9237g/python
python3 -m unittest discover -s tests -p test_approved_content_manifest.py
python3 tools/run_python_suite.py --shards 4 --changed-since 5d825b037 --output-dir /private/tmp/labyrinth_codex/qa145-r1.Z9237g/python-verified
for qa145_module in test_approved_content_manifest test_godot_task_runner test_program_suite_runner; do
  python3 -m unittest discover -s tests -p "$qa145_module.py"
done
python3 tools/run_python_suite.py --shards 1 --changed-since 5d825b037 --output-dir /private/tmp/labyrinth_codex/qa145-r1.Z9237g/python-serial
python3 tests/test_ui_identity_lint.py
git diff --check
```

There are no standalone `tests/run_persistence*` files in this checkout. The save/resume boundary, background persistence, and shutdown tests cover those paths.

The first Python default run reported `Ran 196 tests in 98.255s` and `FAILED (failures=1)`. The approved-content helper hit its 30-second runtime timeout. The module rerun on its own reported `Ran 1 test in 18.470s` and `OK`.

The second four-shard run reported `Ran 196 tests in 173.608s` and `FAILED (failures=6, errors=1)`. Failures were in approved-content (Godot helper deadline), Godot task runner (child startup), and program suite runner (child startup and suite timeouts). The runs used the existing test deadlines.

On the second individual pass, approved-content reported `Ran 1 test in 41.266s` and `FAILED (failures=1)`. Godot task runner reported `Ran 15 tests in 30.892s` and `FAILED (failures=2)`. Program suite runner reported `Ran 42 tests in 155.695s` and `FAILED (failures=3)`. The detailed runner logs are linked above.

The serial default group reported `Ran 196 tests in 216.992s` and `FAILED (failures=2)`. The approved-content helper reached its 30-second limit again. The program-suite runner's hung-child case reached the parent wrapper's 15-second limit and returned 124 where the assertion expected 1. Godot task runner passed in the serial run. [Serial Python log](/private/tmp/labyrinth_codex/qa145-r1.Z9237g/python-serial.log)

### Native event capture

Native captures for this round are pending. The existing proof now includes `05-event-save-quit-failed.png`. The probe's `--capture-only` mode runs the original four surfaces and the event surface at 1920×1080 and 100% UI scale.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-145
export QA145_CAPTURE_DIR="$(mktemp -d /private/tmp/labyrinth_codex/qa145-r1-native.XXXXXX)"
python3 tools/visual_probe_runner.py tests/save_failure_recovery_test.gd --task-id qa-145 --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tools/qa145/proof_contract.json --result-manifest "$QA145_CAPTURE_DIR/proof.json" -- --capture-only
```

The timed headless cases use an ordinary generated fight starting at seed 88100, a separate playback analytics directory, a 100 ms writer delay during Pass, and a 200 ms drain probe during the cursor delay. These values are confined to the test. No design placeholders were needed.

## Round 2 on `9fba7d89d`

1. The departure-failure toast uses the existing log panel above the fully revealed recap. The event and recap share the same departure-toast lifetime. Ordinary notices stay suppressed, and expiry restores the log panel's original drawing order. The test blocks only the profile write, checks the profile stays intact, reopens Camp via Escape, and retries through the real Save and Quit button.
2. A failed title transition cancels the registered handoff, removes its scene-change callback, and disarms the watchdog. The active run restores input, processing, deferred skill work and its gameplay telemetry context. The cursor path logs one application error. The test temporarily substitutes an empty PackedScene at the title's resource-cache path, verifies the retry-specific Ember change is already on disk, and reopens Camp with no departure toast. No scene assets are edited.
3. Every capture prints its path on a bare line as well as the `QA145 CAPTURE` line. The native command supplies an absolute output directory. The sixth capture is `06-recap-save-quit-failed.png`. The path-collector check used six temporary filenames and the real collector.

The changes are uncommitted. Production files are `scripts/run_notification_queue.gd`, `scripts/application_shutdown.gd`, `scripts/cursor_feedback.gd` and `scripts/run_scene.gd`. The regression and native probe are in `tests/save_failure_recovery_test.gd`. The capture contract is `tools/qa145/proof_contract.json`.

### Before and after

`9fba7d89d` exited 1 with the strengthened regression.

```text
QA145 RECAP_DEPARTURE stayed=true shown=false above_recap=false expired=false ordinary_suppressed=true input_ok=true retry_leaves=true
QA145 TITLE_LOAD_FAILURE attempted=true saved=true stayed=false guard_released=false watchdog_disarmed=false input_ok=false quiet=false
```

The working tree exited 0.

```text
QA145 RECAP_DEPARTURE stayed=true shown=true above_recap=true expired=true ordinary_suppressed=true input_ok=true retry_leaves=true
QA145 TITLE_LOAD_FAILURE attempted=true saved=true stayed=true guard_released=true watchdog_disarmed=true input_ok=true quiet=true
QA145 PNG_COLLECTION prefixed_only=0 with_bare_paths=6
```

Both instantiation runs logged `ERROR: CursorFeedback could not change scene to res://scenes/main_menu.tscn (error 20)` once. Godot also emitted its own diagnostics for the deliberately empty PackedScene. [Base log](/private/tmp/labyrinth_codex/qa145-r2.B0Og02/before.log) · [Working-tree log](/private/tmp/labyrinth_codex/qa145-r2.B0Og02/after.log) · [PNG collector log](/private/tmp/labyrinth_codex/qa145-r2.B0Og02/png-parser.log)

### Focused results

| Check | Result |
| --- | --- |
| Complete save failure regression | `QA145 PASS cases=3`, with both round 2 assertions passing |
| Close during handoff | `QA145 CLOSE_DURING_TITLE guarded=true title_changed=false drained=true extra_saves=0 PASS` |
| Save/resume boundary | `TEST RESULT: PASS — committed save/resume boundary matrix` |
| Main-menu resume safety | `TEST RESULT: PASS — main menu resume safety` |
| Application shutdown | `QA84 APPLICATION SHUTDOWN TEST RESULT: PASS (18 assertions; 0 failures)` |
| Shutdown reentrancy | `QA-74 SHUTDOWN REENTRANCY TEST RESULT: PASS (14 assertions; 0 failures)` |
| Background persistence | `PERF03 CHECKPOINT CRASH SAFETY: PASS (3 transaction boundaries)` and `PERF03 DEFERRED PERSISTENCE RESULT: PASS (0 failures)` |
| Departed-run cleanup | `DEPARTED CLEANUP RESULT: {"cases":3,"draining_at_menu":true,"errors":[],"native":false,"orphans":0}` |
| Heirloom notifications | `FULL PANEL NOTICE CHECKS: PASS`, `HEIRLOOM NOTIFICATION SAVE AND QUIT CHECKS: PASS`, `TEST RESULT: PASS` |
| Event view rerun | `Event view fit: 332 pages, 45 events × fresh/rich states`, `Event view suite: 0 failures` |
| Dragon reward checks | `Dragon rewards, gifts, wallet recovery and relic hooks passed.` and `Dragon reward feedback logic: PASS` |
| Save pipeline | `TEST RESULT: PASS — save pipeline compatibility and cleanup` |
| Run-end recap | `RUN END RECAP TEST RESULT: PASS` |
| Deferred combat skill analytics | `TEST RESULT: PASS` with `--simulate-draw` |
| Forced title departure | `GFIX40 main_menu: 9 checks, 0 failures` |
| Forced desktop departure | `GFIX40 application: 11 checks, 0 failures` |
| UI identity lint | `Ran 25 tests in 24.995s` and `OK` |
| Rules text lint | `Ran 3 tests in 0.224s`, `OK`, `PASS: Rules text lint (16 existing hits)` |
| Python default group | `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 72.113s`, `OK` |

The first event-view run reported `Event view suite: 1 failures` at `Expired badge fades out and is removed`. The identical command passed on rerun. The Python run reported a read-only optional timing cache after recording its results. [Round 2 logs](/private/tmp/labyrinth_codex/qa145-r2.B0Og02)

### Headless commands

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-145
qa145_godot() {
  python3 tools/godot_task_runner.py --task-id qa-145 --stream -- godot --headless --path . "$@"
}
qa145_godot --script tests/save_failure_recovery_test.gd -- --round-two
qa145_godot --script tests/save_failure_recovery_test.gd
qa145_godot --script tests/save_failure_recovery_test.gd -- --close-during-title
for qa145_case in save_resume_boundary main_menu_resume application_shutdown shutdown_reentrancy perf/background_persistence departed_run_cleanup heirloom_notification event_view dragon_rewards dragon_reward_feedback save_pipeline_performance; do
  qa145_godot --script "tests/${qa145_case}_test.gd"
done
qa145_godot --script tests/run_end_recap_tests.gd
qa145_godot --script tests/deferred_skill_analytics_test.gd -- --simulate-draw
for qa145_case in main_menu application; do
  LABYRINTH_GFIX40_OUT=/private/tmp/labyrinth_codex/qa145-r2.B0Og02/gfix40 qa145_godot --script tools/gfix40/departure.gd -- "$qa145_case"
done
python3 tests/test_ui_identity_lint.py
python3 tests/test_rules_text_lint.py
python3 tools/run_python_suite.py --shards 1 --changed-since 9fba7d89d --output-dir /private/tmp/labyrinth_codex/qa145-r2.B0Og02/python
git diff --check
```

### Proof for the design owner

Native capture is pending. The following command produces six 1920×1080 PNGs at 100% UI scale and validates the proof contract. The recap fixture waits for the real reveal to finish before opening Camp. The 150-second timeout covers the full six-image probe, including the added recap and successful retry.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-145
export QA145_CAPTURE_DIR="$(mktemp -d /private/tmp/labyrinth_codex/qa145-r2-native.XXXXXX)"
python3 tools/visual_probe_runner.py tests/save_failure_recovery_test.gd --task-id qa-145 --no-headless --display-driver macos --audio-driver Dummy --timeout 150 --expect-size 1920x1080 --proof-contract tools/qa145/proof_contract.json --result-manifest "$QA145_CAPTURE_DIR/proof.json" -- --capture-only
```

The new file is `$QA145_CAPTURE_DIR/06-recap-save-quit-failed.png`. The report manifest is `$QA145_CAPTURE_DIR/proof.json`. The fixture reuses the ordinary combat seed from round 1 and the empty scene is confined to the headless fault injection. No design placeholders were needed.

## Round 3 on `d80578c4d`

1. The raised departure notice ends 16 px above the highest top of Rise Again, Chronicle, and Main Menu. It moves vertically as a unit, preserving its size and right edge. Expiry or restoration of the original layer returns it to its normal placement.
2. The raised notice and its descendants ignore pointer input over recap and event overlays. Restoring the layer also restores the original mouse behavior. The recap test clicks the centre of Main Menu with the departure notice still visible and verifies the actual button signal and transition to title.
3. Event notices keep their existing position. The recap override is active only for the raised recap departure notice. Text, styling, z order and lifetime use the existing presentation.

Changed files are `scripts/run_notice_placement.gd`, `scripts/run_notification_queue.gd`, `tests/save_failure_recovery_test.gd`, and this report. The test waits two draw frames for container layout before measuring. There are no `TODO_DESIGN` placeholders.

### Baseline and working tree

The same focused regression exited 1 with the two production scripts from `d80578c4d`. The baseline delivered the simulated click, and the geometry and mouse-filter assertions failed. [Baseline log](/private/tmp/labyrinth_codex/qa145-r3.ydBZ2K/before.log)

```text
QA145 RECAP_NOTICE_LAYOUT clear=false gap=-582.40 size_and_right=true ignores_mouse=false
QA145 RECAP_MENU_CLICK reached=true retry_leaves=true
```

The working tree exited 0. [Working-tree log](/private/tmp/labyrinth_codex/qa145-r3.ydBZ2K/after.log)

```text
QA145 RECAP_NOTICE_LAYOUT clear=true gap=16.00 size_and_right=true ignores_mouse=true
QA145 RECAP_DEPARTURE stayed=true shown=true above_recap=true expired=true ordinary_suppressed=true input_ok=true retry_leaves=true
QA145 RECAP_MENU_CLICK reached=true retry_leaves=true
QA145 TITLE_LOAD_FAILURE attempted=true saved=true stayed=true guard_released=true watchdog_disarmed=true input_ok=true quiet=true
```

### Focused results

The default qa-145 run exited 0. [Save failure regression log](/private/tmp/labyrinth_codex/qa145-r3.ydBZ2K/qa145-default-final.log)

```text
QA145 REWARD_IDENTITY isolated=true
QA145 TOOLTIP failed= saved=Your rewards have been saved.
QA145 VICTORY_NOTICE shown=true retry_saved=true
QA145 BACKGROUND_RETRY saved=true notice_cleared=true
QA145 PROFILE_FAILURE stayed=true toast=true stale_notice=false
QA145 SAVE_QUIT failed_stays=true input_ok=true retry_leaves=true analytics_dupes=0
QA145 RESUME_MIGRATION failed_shown=true old_disk=true migrated=true notice_cleared=true
QA145 GUARDIAN trophy=true notice=true recovered=true
QA145 EVENT_DEPARTURE shown=true above_event=true other_notices_suppressed=true
QA145 EVENT_NOTICE_INPUT position_unchanged=true ignores_mouse=true
QA145 RECAP_NOTICE_LAYOUT clear=true gap=16.00 size_and_right=true ignores_mouse=true
QA145 RECAP_DEPARTURE stayed=true shown=true above_recap=true expired=true ordinary_suppressed=true input_ok=true retry_leaves=true
QA145 RECAP_MENU_CLICK reached=true retry_leaves=true
QA145 ENEMY_PLAYBACK cancelled=true queues_pending=true adopted=true input_ok=true enemy_actions=3 expected=3
QA145 TITLE_LOAD_FAILURE attempted=true saved=true stayed=true guard_released=true watchdog_disarmed=true input_ok=true quiet=true
QA145 PASS cases=3
```

| Check | Result |
| --- | --- |
| Close during title handoff | `QA145 CLOSE_DURING_TITLE guarded=true title_changed=false drained=true extra_saves=0 PASS` |
| Heirloom notifications | `FULL PANEL NOTICE CHECKS: PASS`, `HEIRLOOM NOTIFICATION SAVE AND QUIT CHECKS: PASS`, `TEST RESULT: PASS` |
| Run-end recap | `RUN END RECAP TEST RESULT: PASS` |
| UI identity lint | `Ran 25 tests in 4.833s` and `OK` |
| Rules text lint | `Ran 3 tests in 0.056s`, `OK`, and `PASS: Rules text lint (16 existing hits)` |

The first default run compared the hidden event panel against its visible layout before container sizing settled. The final test measures both positions with the same text after layout. Headless renderer cleanup diagnostics appeared on the baseline and on the working tree. [Round 3 logs](/private/tmp/labyrinth_codex/qa145-r3.ydBZ2K)

### Headless commands

```bash
qa145_godot() {
  python3 tools/godot_task_runner.py --task-id qa-145 --stream -- godot --headless --path . "$@"
}
qa145_godot --script tests/save_failure_recovery_test.gd -- --round-two
qa145_godot --script tests/save_failure_recovery_test.gd
qa145_godot --script tests/save_failure_recovery_test.gd -- --close-during-title
qa145_godot --script tests/heirloom_notification_test.gd
qa145_godot --script tests/run_end_recap_tests.gd
python3 tests/test_ui_identity_lint.py
python3 tests/test_rules_text_lint.py
git diff --check
```

### Proof for the design owner

Native recapture is pending. The same command produces all six 1920×1080 images at 100% UI scale. Inspect `06-recap-save-quit-failed.png` in the generated capture directory.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-145
export QA145_CAPTURE_DIR="$(mktemp -d /private/tmp/labyrinth_codex/qa145-r2-native.XXXXXX)"
python3 tools/visual_probe_runner.py tests/save_failure_recovery_test.gd --task-id qa-145 --no-headless --display-driver macos --audio-driver Dummy --timeout 150 --expect-size 1920x1080 --proof-contract tools/qa145/proof_contract.json --result-manifest "$QA145_CAPTURE_DIR/proof.json" -- --capture-only
```

## Round 4 on `07e4f0b1f`

1. Recap Main Menu acquires the Save & Quit guard before writing. Both press orders reject a competing action. A failed Main Menu write releases the guard before refreshing the existing notice. A failed title load uses the existing handoff recovery, and a successful transition restores title input and disarms the watchdog.
2. Title-load recovery refreshes the persistent run notice after restoring processing. The regression saves a retry-specific Ember change to disk, confirms the reward tooltip, and checks that the old failure notice is gone when title instantiation fails.
3. The departure queue watches the recap buttons used by notice placement. Opening Chronicle hides the buttons and immediately restores the panel's home rect, draw layer, and recursive mouse behavior. The standard recap still uses the 16 canvas-unit gap.

Changed files are `scripts/run_scene.gd`, `scripts/run_notification_queue.gd`, `scripts/run_notice_placement.gd`, `tests/save_failure_recovery_test.gd`, and `tools/qa145/result.md`. The changes are uncommitted.

### Baseline and working tree

The extended regression ran before the production edits. The baseline exited 1. Its competing save reached a freed run while the title opened with input still locked. [Baseline log](../../.godot/qa145-r4/before.log)

```text
QA145R4 RECAP_DEPARTURE_RACE before=menu_started:true,guarded:false,failed_released:true after=save_ignored:false,title_ready:false,one_transition:true,menu_ignored:false FAIL
QA145R4 REWARD_NOTICE before=failed_notice:true after=stored:true,tooltip_saved:true,stale_notice:true,recovered:true FAIL
QA145R4 CHRONICLE_NOTICE before=raised:true after=opened:true,home:true,layer:false,mouse:false FAIL
```

The working tree exited 0. Both runs logged errors from the intentionally blocked writes and invalid title scene. Both also emitted headless focus and renderer cleanup diagnostics. [Working-tree log](../../.godot/qa145-r4/after.log)

```text
QA145R4 RECAP_DEPARTURE_RACE before=menu_started:true,guarded:true,failed_released:true after=save_ignored:true,title_ready:true,one_transition:true,menu_ignored:true PASS
QA145R4 REWARD_NOTICE before=failed_notice:true after=stored:true,tooltip_saved:true,stale_notice:false,recovered:true PASS
QA145R4 CHRONICLE_NOTICE before=raised:true after=opened:true,home:true,layer:true,mouse:true PASS
QA145R4 PASS findings=3
```

### Earlier save and recap regressions

The round 3 focused rerun exited 0. [Round 3 rerun log](../../.godot/qa145-r4/round-three-lines.log)

```text
QA145 RECAP_NOTICE_LAYOUT clear=true gap=16.00 size_and_right=true ignores_mouse=true
QA145 RECAP_DEPARTURE stayed=true shown=true above_recap=true expired=true ordinary_suppressed=true input_ok=true retry_leaves=true
QA145 RECAP_MENU_CLICK reached=true retry_leaves=true
QA145 TITLE_LOAD_FAILURE attempted=true saved=true stayed=true guard_released=true watchdog_disarmed=true input_ok=true quiet=true
```

The default save failure regression exited 0. [Save failure regression log](../../.godot/qa145-r4/save-failure-recovery.log)

```text
QA145 REWARD_IDENTITY isolated=true
QA145 TOOLTIP failed= saved=Your rewards have been saved.
QA145 VICTORY_NOTICE shown=true retry_saved=true
QA145 BACKGROUND_RETRY saved=true notice_cleared=true
QA145 PROFILE_FAILURE stayed=true toast=true stale_notice=false
QA145 SAVE_QUIT failed_stays=true input_ok=true retry_leaves=true analytics_dupes=0
QA145 RESUME_MIGRATION failed_shown=true old_disk=true migrated=true notice_cleared=true
QA145 GUARDIAN trophy=true notice=true recovered=true
QA145 EVENT_DEPARTURE shown=true above_event=true other_notices_suppressed=true
QA145 EVENT_NOTICE_INPUT position_unchanged=true ignores_mouse=true
QA145 RECAP_NOTICE_LAYOUT clear=true gap=16.00 size_and_right=true ignores_mouse=true
QA145 RECAP_DEPARTURE stayed=true shown=true above_recap=true expired=true ordinary_suppressed=true input_ok=true retry_leaves=true
QA145 RECAP_MENU_CLICK reached=true retry_leaves=true
QA145 ENEMY_PLAYBACK cancelled=true queues_pending=true adopted=true input_ok=true enemy_actions=3 expected=3
QA145 TITLE_LOAD_FAILURE attempted=true saved=true stayed=true guard_released=true watchdog_disarmed=true input_ok=true quiet=true
QA145 PASS cases=3
```

### Other focused checks

| Check | Exact result |
| --- | --- |
| Close during title handoff | `QA145 CLOSE_DURING_TITLE guarded=true title_changed=false drained=true extra_saves=0 PASS` |
| Shutdown reentrancy | `QA-74 SHUTDOWN REENTRANCY TEST RESULT: PASS (14 assertions; 0 failures)` |
| Application shutdown | `QA84 APPLICATION SHUTDOWN TEST RESULT: PASS (18 assertions; 0 failures)` |
| Heirloom notifications | `FULL PANEL NOTICE CHECKS: PASS`, `HEIRLOOM NOTIFICATION SAVE AND QUIT CHECKS: PASS`, `TEST RESULT: PASS` |
| Run-end recap | `RUN END RECAP TEST RESULT: PASS` |
| UI identity lint | `Ran 25 tests in 27.331s`, `OK` |
| Rules text lint | `Ran 3 tests in 0.774s`, `OK`, `PASS: Rules text lint (16 existing hits)` |
| Python default group | `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 70.567s`, `OK` |
| Diff whitespace check | `git diff --check` exited 0 with no output |

The Python runner recorded its results and reported that the optional Git timing cache is read-only. [Focused logs](../../.godot/qa145-r4/) · [Python results](../../.godot/qa145-r4/python/summary.json)

### Commands

The `--round-four` command was run on both the baseline and the working tree with the same test.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-145
qa145_godot() {
  python3 tools/godot_task_runner.py --task-id qa-145 --stream -- godot --headless --path . "$@"
}
qa145_godot --script tests/save_failure_recovery_test.gd -- --round-four
qa145_godot --script tests/save_failure_recovery_test.gd -- --round-two
qa145_godot --script tests/save_failure_recovery_test.gd
qa145_godot --script tests/save_failure_recovery_test.gd -- --close-during-title
qa145_godot --script tests/shutdown_reentrancy_test.gd
qa145_godot --script tests/application_shutdown_test.gd
qa145_godot --script tests/heirloom_notification_test.gd
qa145_godot --script tests/run_end_recap_tests.gd
python3 tests/test_ui_identity_lint.py
python3 tests/test_rules_text_lint.py
python3 tools/run_python_suite.py --shards 4 --changed-since 07e4f0b1f --output-dir .godot/qa145-r4/python
git diff --check
```

### Chosen defaults and open items

- The test reuses the 200 ms handoff delay to hold disk I/O across the competing departure. The Chronicle test freezes the existing notification clock while checking synchronous restoration. No player-facing defaults or `TODO_DESIGN_*` placeholders were added.
- Native verification is pending. The sandbox has no window-server access. The read-only task status still reports `contract_ready: false` with empty acceptance and proof fields. This round follows the high-risk proof in the brief.

### Proof for the design owner

Use the same native probe as round 3. It writes six 1920×1080 PNGs at 100% UI scale and a `proof.json` manifest in `$QA145_CAPTURE_DIR`. The judged frames are expected to look the same, including `06-recap-save-quit-failed.png`. The visible changes occur when entering Chronicle with a raised toast and when a successfully saved reward returns from a failed title load. Those states are exercised by the headless repros.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-145
export QA145_CAPTURE_DIR="$(mktemp -d /private/tmp/labyrinth_codex/qa145-r2-native.XXXXXX)"
python3 tools/visual_probe_runner.py tests/save_failure_recovery_test.gd --task-id qa-145 --no-headless --display-driver macos --audio-driver Dummy --timeout 150 --expect-size 1920x1080 --proof-contract tools/qa145/proof_contract.json --result-manifest "$QA145_CAPTURE_DIR/proof.json" -- --capture-only
```
