# qa-147 won-combat analytics

The starting revision was `1e56b4fbfa4aa5640401969d2bcdcf89cbeed22f` on `codex/qa-147`. Changes are uncommitted. The design owner's task brief file was preserved.

## Root cause

At the base revision, the live combat-to-reward transition emitted the two rows with plain `write_event` at `scripts/run_scene.gd:33951–34002`. A won checkpoint could already be on disk when the first VICTORY frame appeared. Save & Quit or a process kill could interrupt before the transition, and Continue had no saved receipts for that fight. A kill earlier in an enemy phase left a valid combat continuation. The continuation could finish and install the reward without calling the live transition at all. At seed 144201, decision 1, Whirlwind Slash produced a `reward` checkpoint and the same ready reward on Continue, with 0 closing rows. The uninterrupted control recorded 1 of each.

## Acceptance criteria

1. Won checkpoints retain one `combat_ended` and one `reward_offered` row per combat. The headless matrix covers uninterrupted play, Save & Quit and the production window-close signal at all three boundaries, SIGKILL on both sides of the won write, card and turn-start wins, enemy Fire and Burst wins, and Guardian and dragon rewards. The duplicate checks repeat Continue from the same first-VICTORY checkpoint and Save & Quit across consecutive sessions.
2. The checkpoint builder stages the pair in the existing progression outbox, in event order. Live delivery uses the existing durable analytics writer. Title and Continue replay use the same keys. Enemy-phase Continue delivers the pair after consuming its saved continuation. A newer profile still supplies progression when it supersedes the embedded profile. The won receipts survive that revision choice.
3. Both receipts use the original snapshot payload builders. The keys are `combat_ended|<combat_id>` and `reward_offered|<combat_id>`. Before this change the live reward offer had no key. Recovery recognizes older physical rows by combat ID. The payload schema and order of the two events stay the same.
4. Defeat and run-ending receipt writers retain their existing paths. The final dragon keeps its existing combat-end snapshot and reward-transition ordering. Its reward offer now shares the saved outbox with the combat end.
5. The receipt rule is documented beside the final-dragon rule in `spec/analytics.md`.
6. Implementation changes are confined to analytics snapshots, outbox ownership, and delivery. The probe crosses the existing presentation and departure boundaries. Native captures are pending design-owner execution.

## Before on 1e56b4fbf

```text
QA147 card_control combat_ended=1 reward_offered=1 PASS
QA147 card_save_victory combat_ended=0 reward_offered=0 FAIL
QA147 card_save_intro combat_ended=1 reward_offered=1 PASS
QA147 card_save_ready combat_ended=1 reward_offered=1 PASS
QA147 card_close_victory combat_ended=0 reward_offered=0 FAIL
QA147 card_close_intro combat_ended=1 reward_offered=1 PASS
QA147 card_close_ready combat_ended=1 reward_offered=1 PASS
QA147 card_kill_after_write combat_ended=0 reward_offered=0 FAIL
QA147 fire_kill_after_write combat_ended=0 reward_offered=0 FAIL
QA147 fire_kill_before_write combat_ended=0 reward_offered=0 FAIL
QA147 burst_kill_before_write combat_ended=0 reward_offered=0 FAIL
QA147 turn_start_save_victory combat_ended=0 reward_offered=0 FAIL
QA147 guardian_close_ready combat_ended=1 reward_offered=1 PASS
QA147 dragon_save_victory combat_ended=0 reward_offered=0 FAIL
QA147 final_dragon_save_victory combat_ended=1 reward_offered=0 FAIL
QA147 continue_twice combat_ended=0 reward_offered=0 FAIL
QA147 save_twice combat_ended=0 reward_offered=0 FAIL
QA147 FAIL cases=17
```

The seed, input, and cut were recorded in the first-frame departure log.

```text
QA147 INPUT seed=144201 decision=1 action=whirlwind_slash
QA147 CUT save_victory disk_mode=reward
QA147 READY combat
```

[Before artifacts](/private/tmp/labyrinth_codex/qa147-before-2) · [First-frame Save & Quit log](/private/tmp/labyrinth_codex/qa147-before-2/card_save_victory/initial.log)

## After

An initial candidate reported `QA147 PASS cases=17`. The stricter run also required an empty ledger at each SIGKILL boundary, observed the actual Burst journal, and restored the pre-departure checkpoint for both Continue attempts. Its first pass finished 14 cases and timed out in three probe processes. Both timed-out Continue attempts had the expected ledger rows on disk. The two Continue checks and the initial Save & Quit probe were retried serially.

```text
QA147 card_close_ready combat_ended=1 reward_offered=1 FAIL
QA147 continue_twice combat_ended=1 reward_offered=1 FAIL
QA147 save_twice combat_ended=0 reward_offered=0 FAIL
QA147 FAIL cases=17
```

The serial rerun reported `QA147 PASS cases=3`. The final matrix below combines those three verified cases with the 14 passing cases from the stricter run. Each accepted case has exactly two keyed physical rows in the required order. For the 13 rows also emitted on base, comparison covered the full payload and stable context. Generated identities, sequence numbers, timestamps, and receipt keys were excluded from the base comparison.

```text
QA147 card_control combat_ended=1 reward_offered=1 PASS
QA147 card_save_victory combat_ended=1 reward_offered=1 PASS
QA147 card_save_intro combat_ended=1 reward_offered=1 PASS
QA147 card_save_ready combat_ended=1 reward_offered=1 PASS
QA147 card_close_victory combat_ended=1 reward_offered=1 PASS
QA147 card_close_intro combat_ended=1 reward_offered=1 PASS
QA147 card_close_ready combat_ended=1 reward_offered=1 PASS
QA147 card_kill_after_write combat_ended=1 reward_offered=1 PASS
QA147 fire_kill_after_write combat_ended=1 reward_offered=1 PASS
QA147 fire_kill_before_write combat_ended=1 reward_offered=1 PASS
QA147 burst_kill_before_write combat_ended=1 reward_offered=1 PASS
QA147 turn_start_save_victory combat_ended=1 reward_offered=1 PASS
QA147 guardian_close_ready combat_ended=1 reward_offered=1 PASS
QA147 dragon_save_victory combat_ended=1 reward_offered=1 PASS
QA147 final_dragon_save_victory combat_ended=1 reward_offered=1 PASS
QA147 continue_twice combat_ended=1 reward_offered=1 PASS
QA147 save_twice combat_ended=1 reward_offered=1 PASS
QA147 PASS cases=17
QA147 MATCHED payload_and_context=13 keyed_cases=17
```

[Serial retry artifacts](/private/tmp/labyrinth_codex/qa147-after-serial) · [Verified case and comparison results](/private/tmp/labyrinth_codex/qa147-verified.log)

[Initial candidate artifacts](/private/tmp/labyrinth_codex/qa147-after-1) · [Stricter run and timeout logs](/private/tmp/labyrinth_codex/qa147-after-final)

## Focused results

```text
WON CHECKPOINT RECEIPTS: save_quit_at_victory ["combat_ended", "reward_offered"]
WON CHECKPOINT RECEIPTS: kill_after_write ["combat_ended", "reward_offered"]
TEST RESULT: PASS — committed save/resume boundary matrix
DEPARTED CLEANUP RESULT: {"cases":3,"draining_at_menu":true,"errors":[],"native":false,"orphans":0}
TEST RESULT: PASS — main menu resume safety
ENCOUNTER CALLER METADATA: PASS (UI/headless; combat, Guardian, boss; start/end/rewards)
ENCOUNTER ANALYTICS: PASS (0 failures)
TEST RESULT: PASS surface analytics batch and partial append recovery
TEST RESULT: PASS
TEST RESULT: PASS
Dragon rewards, gifts, wallet recovery and relic hooks passed.
DRAGON WALLET ACK TEST: PASS (108 checks)
TEST RESULT: PASS — save pipeline compatibility and cleanup
TERMINAL CRASH: defeat terminal checkpoint promoted
QA147 TERMINAL crash_exit=247
DEFEAT REPLAY COORDINATES: {"x":-1.0,"y":-1.0}
DEFEAT CLOSING EVENTS: ["combat_ended", "run_ended"]
TEST RESULT: PASS — defeat terminal crash recovery
```

The two unqualified PASS lines are the skill progression and deferred combat skill analytics tests. The existing deferred **run** skill test requires native draw frames. Its headless attempt reported `Timed out waiting for native rendered frames; use a real renderer, not --headless.` The native command is below.

[Focused Godot logs](/private/tmp/labyrinth_codex/qa147-focused) · [Defeat crash and relaunch logs](/private/tmp/labyrinth_codex/qa147-terminal-defeat)

## Python default group

The first run selected 23 modules and reported `Ran 196 tests in 35.200s` and `OK`. The final parallel rerun selected the same modules and reported `Ran 196 tests in 81.247s` followed by `FAILED (failures=1)`. The existing `test_real_parent_prints_whole_logs_in_manifest_order` runner test timed out at its 15-second process cap. Its test and timeout settings were preserved.

The isolated module rerun finished with `Ran 42 tests in 74.515s` and `OK`. The default group's rules-text lint reported `PASS: Rules text lint (16 existing hits)`. The sandbox rejected the optional Git timing-cache write. The suite output and summaries were written to their requested directories.

[First default results](/private/tmp/labyrinth_codex/qa147-python-default/summary.json) · [Final parallel log](/private/tmp/labyrinth_codex/qa147-python-final.log) · [Isolated module log](/private/tmp/labyrinth_codex/qa147-python-runner-isolated.log)

## Commands

All commands start in the assigned worktree. Each matrix case writes its expanded engine invocations and environment to `*-command.json`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-147 &&
python3 tools/qa147/run_cases.py --output-dir /private/tmp/labyrinth_codex/qa147-before-2 --jobs 3
python3 tools/qa147/run_cases.py --output-dir /private/tmp/labyrinth_codex/qa147-after-1 --jobs 3
python3 tools/qa147/run_cases.py --output-dir /private/tmp/labyrinth_codex/qa147-after-final --jobs 3
python3 tools/qa147/run_cases.py --output-dir /private/tmp/labyrinth_codex/qa147-after-serial --only card_close_ready --only continue_twice --only save_twice --jobs 1
PYTHONDONTWRITEBYTECODE=1 python3 tools/run_python_suite.py --shards 4 --changed-since 1e56b4fbf --output-dir /private/tmp/labyrinth_codex/qa147-python-default
PYTHONDONTWRITEBYTECODE=1 python3 tools/run_python_suite.py --shards 4 --changed-since 1e56b4fbf --output-dir /private/tmp/labyrinth_codex/qa147-python-final
PYTHONDONTWRITEBYTECODE=1 python3 tools/run_python_suite.py --shards 1 --pattern test_program_suite_runner.py --output-dir /private/tmp/labyrinth_codex/qa147-python-runner-isolated
git --no-optional-locks diff --check
```

The ledger comparison reads the physical rows already captured by the case runner.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-147 &&
PYTHONDONTWRITEBYTECODE=1 python3 - <<'PY'
import json
from pathlib import Path
from tools.qa147.run_cases import CASES

root = Path("/private/tmp/labyrinth_codex")
types = ["combat_ended", "reward_offered"]
generated = {
    "event_id", "run_id", "session_id", "install_id", "combat_id", "sequence",
    "idempotency_key", "ts_msec", "ts_unix_msec", "timestamp_utc", "written_at",
}
matched = 0
for case in CASES:
    relative = Path(case) / "result.json"
    path = root / "qa147-after-serial" / relative
    if not path.exists():
        path = root / "qa147-after-final" / relative
    current = json.loads(path.read_text())
    assert current["boundary_verified"], case
    assert [row["event_type"] for row in current["rows"]] == types, case
    assert [row["idempotency_key"] for row in current["rows"]] == [
        event + "|" + current["combat_id"] for event in types
    ], case
    base = json.loads((root / "qa147-before-2" / relative).read_text())
    for old in base["rows"]:
        row = next(record for record in current["rows"] if record["event_type"] == old["event_type"])
        assert {key: value for key, value in old.items() if key not in generated} == {
            key: value for key, value in row.items() if key not in generated
        }, (case, old["event_type"])
        matched += 1
    print(f"QA147 {case} combat_ended=1 reward_offered=1 PASS")
print(f"QA147 PASS cases={len(CASES)}")
print(f"QA147 MATCHED payload_and_context={matched} keyed_cases={len(CASES)}")
PY
```

The focused logs are in `/private/tmp/labyrinth_codex/qa147-focused/`. The permanent save test exercises the held reward snapshot used on the first VICTORY frame and the direct startup from the after-write snapshot with a newer profile. The headless matrix supplies the actual Save & Quit and SIGKILL witnesses.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-147 &&
python3 tools/godot_task_runner.py --task-id qa-147 --stream -- godot --headless --path . --script tests/save_resume_boundary_test.gd
python3 tools/godot_task_runner.py --task-id qa-147 --stream -- godot --headless --path . --script tests/departed_run_cleanup_test.gd
python3 tools/godot_task_runner.py --task-id qa-147 --stream -- godot --headless --path . --script tests/main_menu_resume_test.gd
python3 tools/godot_task_runner.py --task-id qa-147 --stream -- godot --headless --path . --script tests/encounter_analytics_test.gd
python3 tools/godot_task_runner.py --task-id qa-147 --stream -- godot --headless --path . --script tests/surface_analytics_batch_test.gd
python3 tools/godot_task_runner.py --task-id qa-147 --stream -- godot --headless --path . --script tests/skill_progression_analytics_test.gd
python3 tools/godot_task_runner.py --task-id qa-147 --stream -- godot --headless --path . --script tests/deferred_skill_analytics_test.gd -- --simulate-draw
python3 tools/godot_task_runner.py --task-id qa-147 --stream -- godot --headless --path . --script tests/dragon_rewards_test.gd
python3 tools/godot_task_runner.py --task-id qa-147 --stream -- godot --headless --path . --script tests/dragon_wallet_ack_test.gd
python3 tools/godot_task_runner.py --task-id qa-147 --stream -- godot --headless --path . --script tests/save_pipeline_performance_test.gd
python3 tools/godot_task_runner.py --task-id qa-147 --stream -- godot --headless --path . --script tests/deferred_run_skill_analytics_test.gd -- --simulate-draw
qa147_crash=/private/tmp/labyrinth_codex/qa147-terminal-defeat
mkdir -p "$qa147_crash"
python3 tools/godot_task_runner.py --task-id qa-147 --stream -- godot --headless --path . --script tests/main_menu_resume_test.gd -- --terminal-crash --after-terminal-checkpoint --path=defeat --output="$qa147_crash"
python3 tools/godot_task_runner.py --task-id qa-147 --stream -- godot --headless --path . --script tests/main_menu_resume_test.gd -- --terminal-relaunch --path=defeat --output="$qa147_crash"
```

## Files changed

- `scripts/run_scene.gd`, `scripts/run_persistence.gd`, `scripts/analytics_snapshots.gd`, `scripts/analytics_store.gd`, and `scripts/progression_store.gd` wire won receipts into commit and recovery.
- `spec/analytics.md` documents the receipt rule.
- `tests/save_resume_boundary_test.gd` adds one permanent regression.
- `tools/qa147/fixture.gd`, `probe.gd`, and their `.uid` sidecars provide the seeded play and interruption witness. `run_cases.py` runs the two-process cuts and checks physical JSONL. `visual_contract.json` validates the native captures, and `result.md` records verification.

## Chosen defaults

The fixture reuses qa-144's seed, board, Health, Whirlwind Slash, Fire placement, and turn-start Meteorfall. The Burst variant uses an Ember Tick on the Fire and a one-Health Crawler adjacent to it. The reward variants use Craghide and Tharokh through the production Guardian and dragon reward logic. Headless proof runs at 120 fixed frames per second and 4× engine speed, with a 40-second probe deadline and a 90-second process timeout. The matrix used three slots and the retries used one. The native probe uses 1920×1080 at 100% UI scale and ordinary engine speed. The direct Continue test uses a profile one revision newer than the saved state. No `TODO_DESIGN` placeholders were needed.

## Open issues

Native captures and the renderer-dependent deferred run-skill test await a window server. The headless defeat relaunch emitted a Grimoire teardown diagnostic after checking the replayed coordinates. Its receipt and save assertions passed.

## Proof for the design owner

Run this on a Mac with a window server. The probe saves the first VICTORY frame and the ready reward after Continue. The capture paths are `$qa147_visual/victory.png` and `$qa147_visual/reward.png`; the runner writes `$qa147_visual/manifest.json`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-147 &&
qa147_visual=$(mktemp -d /private/tmp/labyrinth_codex/qa147-visual.XXXXXX)
QA147_OUTPUT="$qa147_visual" QA147_KIND=card QA147_CUT=save_victory QA147_SAVE_AGAIN=0 LABYRINTH_DEMO=1 \
  python3 tools/visual_probe_runner.py --task-id qa-147 --no-headless \
  --display-driver macos --audio-driver Dummy --expect-size 1920x1080 \
  --proof-contract tools/qa147/visual_contract.json \
  --result-manifest "$qa147_visual/manifest.json" tools/qa147/probe.gd
```

The existing deferred run-skill test uses native frame signals and emits a text verdict.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-147 &&
python3 tools/visual_probe_runner.py --task-id qa-147 --no-headless \
  --display-driver macos --audio-driver Dummy --min-images 0 \
  tests/deferred_run_skill_analytics_test.gd
```

## Round 1

The design owner reported that the round-0 native VICTORY and reward captures passed and that the ledger held one row of each kind in order. The two P2 findings were reproduced on `b691c25c8`. [Static review](/private/tmp/labyrinth_codex/review/qa-147-b691c25c8.md)

- The first probe resolves a Reach the Exit win, claims its reward, and saves in the destination event room while analytics writes are blocked. Title replay also fails. Continue selects a newer profile and saves again while its outbox delivery is blocked. The next replay recovers the pair from that later save. The receipt merge now applies across modes and also retains outstanding win receipts when the profile takes precedence or terminal settlement takes over.
- The second probe freezes the real Save & Quit path at its save-in-progress await, then invokes the combat transition callback that follows VICTORY. The callback now exits before live analytics delivery. The active departure save leaves the pair staged for title or Continue replay and keeps the existing delivery path for other receipts. Repeated replay leaves exactly one ordered pair.

Recovery starts with the stored payloads of staged receipts, as agreed for P3. The implementation changes are confined to receipt handling.

```text
QA147R1 later_checkpoint before=retained:0,rows:0 after=retained:2,rows:2 PASS
QA147R1 departing_transition before=live_writes:1,pre_continue:2,rows:2 after=live_writes:0,pre_continue:0,rows:2 PASS
QA147R1 PASS findings=2
WON CHECKPOINT RECEIPTS: save_quit_at_victory ["combat_ended", "reward_offered"]
WON CHECKPOINT RECEIPTS: kill_after_write ["combat_ended", "reward_offered"]
WON RECEIPT DELIVERY: {"finding":"later_checkpoint","mode":"event","passed":true,"retained":2,"rows":["combat_ended","reward_offered"]}
WON RECEIPT DELIVERY: {"before_continue":0,"finding":"departing_transition","live_writes":0,"passed":true,"rows":["combat_ended","reward_offered"]}
TEST RESULT: PASS — committed save/resume boundary matrix
Ran 25 tests in 5.082s
OK
```

Round-0 interruption matrix rerun.

```text
QA147 card_control combat_ended=1 reward_offered=1 PASS
QA147 card_save_victory combat_ended=1 reward_offered=1 PASS
QA147 card_save_intro combat_ended=1 reward_offered=1 PASS
QA147 card_save_ready combat_ended=1 reward_offered=1 PASS
QA147 card_close_victory combat_ended=1 reward_offered=1 PASS
QA147 card_close_intro combat_ended=1 reward_offered=1 PASS
QA147 card_close_ready combat_ended=1 reward_offered=1 PASS
QA147 card_kill_after_write combat_ended=1 reward_offered=1 PASS
QA147 fire_kill_after_write combat_ended=1 reward_offered=1 PASS
QA147 fire_kill_before_write combat_ended=1 reward_offered=1 PASS
QA147 burst_kill_before_write combat_ended=1 reward_offered=1 PASS
QA147 turn_start_save_victory combat_ended=1 reward_offered=1 PASS
QA147 guardian_close_ready combat_ended=1 reward_offered=1 PASS
QA147 dragon_save_victory combat_ended=1 reward_offered=1 PASS
QA147 final_dragon_save_victory combat_ended=1 reward_offered=1 PASS
QA147 continue_twice combat_ended=1 reward_offered=1 PASS
QA147 save_twice combat_ended=1 reward_offered=1 PASS
QA147 PASS cases=17
```

[Round-0 rerun log](/private/tmp/labyrinth_codex/qa147-r1-round0.log) · [Checkpoint and ledger artifacts](/private/tmp/labyrinth_codex/qa147-r1-round0)

The Python runner selected the default group.

```text
INPUT GROUP default: always run
SELECTED MODULES: 23 of 59
Ran 196 tests in 34.850s
OK
```

[Python default log](/private/tmp/labyrinth_codex/qa147-r1-python.log)

[Reviewed revision probe logs](/private/tmp/labyrinth_codex/qa147-r1-base) · [Fixed probe logs](/private/tmp/labyrinth_codex/qa147-r1-fixed) · [Comparison log](/private/tmp/labyrinth_codex/qa147-r1-fixed.log) · [Save regression log](/private/tmp/labyrinth_codex/qa147-r1-checks/save.log)

Round 1 changed `scripts/run_scene.gd`, `scripts/run_persistence.gd`, `scripts/progression_store.gd`, `spec/analytics.md`, and `tests/save_resume_boundary_test.gd`. The existing save test now calls both boundary probes. The proof tools are `tools/qa147/round1.gd`, its UID sidecar, and `tools/qa147/round1.py`. The fixture uses seed 88100, a one-revision profile advance, and the existing 1920×1080 save-test viewport. New typed arrays follow the Windows assignment rule. No design placeholders were needed.

### Round 1 commands

The first two engine commands ran on `b691c25c8` before the production changes. Each returned exit 1 with a reproduced finding.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-147 &&
qa147_baseline=/private/tmp/labyrinth_codex/qa147-r1-base
mkdir -p "$qa147_baseline"
python3 tools/godot_task_runner.py --task-id qa-147 --stream -- godot --headless --path . --script tools/qa147/round1.gd -- later_checkpoint > "$qa147_baseline/later_checkpoint.log" 2>&1
python3 tools/godot_task_runner.py --task-id qa-147 --stream -- godot --headless --path . --script tools/qa147/round1.gd -- departing_transition > "$qa147_baseline/departing_transition.log" 2>&1
python3 tools/qa147/round1.py --before "$qa147_baseline" --output-dir /private/tmp/labyrinth_codex/qa147-r1-fixed
python3 tools/godot_task_runner.py --task-id qa-147 --stream -- godot --headless --path . --script tests/save_resume_boundary_test.gd
python3 tools/qa147/run_cases.py --output-dir /private/tmp/labyrinth_codex/qa147-r1-round0 --jobs 2
python3 tests/test_ui_identity_lint.py
PYTHONDONTWRITEBYTECODE=1 python3 tools/run_python_suite.py --shards 4 --changed-since b691c25c8 --output-dir /private/tmp/labyrinth_codex/qa147-r1-python
```

The existing deferred run-skill test remains native-only. The windowed test allowlist identifies it as requiring production rendered frames.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-147 &&
python3 tools/visual_probe_runner.py --task-id qa-147 --no-headless \
  --display-driver macos --audio-driver Dummy --min-images 0 \
  tests/deferred_run_skill_analytics_test.gd
```

## Round 2

Baseline `e85515695` rejected the synced-completion checkpoint as stale before title replay could see its wins. The stale probe found zero closing rows after New Run replaced it. The defeat probe recorded one synchronous write after departure started. Both baseline probes exited 1. [Review of e85515695](/private/tmp/labyrinth_codex/review/qa-147-e85515695.md) · [Baseline logs](/private/tmp/labyrinth_codex/qa147-r2-base)

- Title replay now receives staged win receipts from hidden checkpoints through receipt metadata. Resume eligibility and wallet settlement still use the original checkpoint selection. Save replacement, backup promotion, and clear carry an outgoing win into the profile before removing its last checkpoint copy if the ledger needs it. If the profile write cannot succeed, the outgoing checkpoint stays intact. Subsequent profile saves retain the carried receipts until their ledger rows are durable.
- The live combat transition and resumed enemy-phase callback check departure before invoking defeat or win replay. The shared progression outbox reconciler also checks departure. Terminal settlement continues to carry the pair for startup replay, and the departure writer still saves the profile before the frozen checkpoint.
- Win receipt keys and JSONL payloads use the established contract. Title replay still gets one attempt per visit.

Baseline repro output.

```text
QA147R2 RESULT {"duplicates":0,"finding":"STALE_CHECKPOINT","passed":false,"rows":[],"rows_after":0,"rows_before":0,"staged":false,"title_rows":0}
QA147R2 RESULT {"finding":"DEPARTING_DEFEAT","live_writes":1,"passed":false,"replayed_on_continue":0,"rows":["combat_ended","reward_offered"],"staged_kept":true}
```

Verified before-and-after lines.

```text
QA147R2 STALE_CHECKPOINT rows_before=0 rows_after=2 duplicates=0 PASS
QA147R2 DEPARTING_DEFEAT live_writes=0 staged_kept=true replayed_on_continue=1 PASS
QA147R2 PASS findings=2
```

Additional discard and departure checks.

```text
QA147R2 RESULT {"duplicates":0,"finding":"STALE_OUTAGE","passed":true,"rows":["combat_ended","reward_offered"],"rows_after":2,"rows_before":0,"staged":true,"title_rows":0}
QA147R2 RESULT {"finding":"DEPARTING_ENEMY_RESUME","live_writes":0,"passed":true,"replayed_on_continue":1,"rows":["combat_ended","reward_offered"],"staged_kept":true}
QA147R2 RESULT {"clear_carried":true,"failed_clear_kept_checkpoint":true,"finding":"CHECKPOINT_DISCARD","passed":true,"promotion_carried":true,"rewrite_acked":true,"rewrite_kept":true,"rows":["combat_ended","reward_offered"]}
```

The save/resume regression and UI identity lint passed.

```text
WON CHECKPOINT RECEIPTS: save_quit_at_victory ["combat_ended", "reward_offered"]
WON CHECKPOINT RECEIPTS: kill_after_write ["combat_ended", "reward_offered"]
WON RECEIPT DELIVERY: {"finding":"later_checkpoint","mode":"event","passed":true,"retained":2,"rows":["combat_ended","reward_offered"]}
WON RECEIPT DELIVERY: {"before_continue":0,"finding":"departing_transition","live_writes":0,"passed":true,"rows":["combat_ended","reward_offered"]}
TEST RESULT: PASS — committed save/resume boundary matrix
Ran 25 tests in 7.545s
OK
```

[Final probe logs](/private/tmp/labyrinth_codex/qa147-r2-final) · [Proof summary](/private/tmp/labyrinth_codex/qa147-r2-final-proof.log) · [Focused suite logs](/private/tmp/labyrinth_codex/qa147-r2-final-checks) · [UI identity lint](/private/tmp/labyrinth_codex/qa147-r2-checks/ui-lint.log)

The main menu resume test and round-1 replay passed.

```text
TEST RESULT: PASS — main menu resume safety
QA147R1 later_checkpoint before=retained:0,rows:0 after=retained:2,rows:2 PASS
QA147R1 departing_transition before=live_writes:1,pre_continue:2,rows:2 after=live_writes:0,pre_continue:0,rows:2 PASS
QA147R1 PASS findings=2
```

[Round-1 rerun log](/private/tmp/labyrinth_codex/qa147-r2-final-round1.log)

Round-0 interruption matrix rerun.

```text
QA147 card_control combat_ended=1 reward_offered=1 PASS
QA147 card_save_victory combat_ended=1 reward_offered=1 PASS
QA147 card_save_intro combat_ended=1 reward_offered=1 PASS
QA147 card_save_ready combat_ended=1 reward_offered=1 PASS
QA147 card_close_victory combat_ended=1 reward_offered=1 PASS
QA147 card_close_intro combat_ended=1 reward_offered=1 PASS
QA147 card_close_ready combat_ended=1 reward_offered=1 PASS
QA147 card_kill_after_write combat_ended=1 reward_offered=1 PASS
QA147 fire_kill_after_write combat_ended=1 reward_offered=1 PASS
QA147 fire_kill_before_write combat_ended=1 reward_offered=1 PASS
QA147 burst_kill_before_write combat_ended=1 reward_offered=1 PASS
QA147 turn_start_save_victory combat_ended=1 reward_offered=1 PASS
QA147 guardian_close_ready combat_ended=1 reward_offered=1 PASS
QA147 dragon_save_victory combat_ended=1 reward_offered=1 PASS
QA147 final_dragon_save_victory combat_ended=1 reward_offered=1 PASS
QA147 continue_twice combat_ended=1 reward_offered=1 PASS
QA147 save_twice combat_ended=1 reward_offered=1 PASS
QA147 PASS cases=17
```

[Round-0 rerun log](/private/tmp/labyrinth_codex/qa147-r2-final-round0.log) · [Checkpoint and ledger artifacts](/private/tmp/labyrinth_codex/qa147-r2-final-round0)

The first Python default run reported `FAILED (failures=1)`. The production-only package smoke test could not resolve the new global `AnalyticsStore` references. Explicit script preloads resolved the packaged dependency. The affected module passed in isolation and the default group then passed in full.

```text
SELECTED MODULES: 1 of 1
Ran 1 tests in 12.826s
OK
INPUT GROUP default: always run
SELECTED MODULES: 23 of 59
Ran 196 tests in 28.803s
OK
```

[Initial Python log](/private/tmp/labyrinth_codex/qa147-r2-python.log) · [Isolated package smoke log](/private/tmp/labyrinth_codex/qa147-r2-python-approved.log) · [Passing Python default log](/private/tmp/labyrinth_codex/qa147-r2-python-verified.log)

Both requested round-2 probes produced the same proof lines after the preload fix. [Final confirmation log](/private/tmp/labyrinth_codex/qa147-r2-postpack.log)

The production changes are in `scripts/analytics_store.gd`, `scripts/main_menu.gd`, `scripts/progression_store.gd`, `scripts/run_persistence.gd`, and `scripts/run_scene.gd`. `spec/analytics.md` documents checkpoint receipt preservation. The proof tools are `tools/qa147/round2.gd`, its UID sidecar, and `tools/qa147/round2.py`. The existing round-1 proof now installs the synced profile file directly, matching an external sync. Save and resume suite registration is unchanged. Fixture choices were a 37-Ember bank and distinct combat IDs for the prior win and later defeat. No design placeholders were needed.

### Round 2 commands

Run the two baseline probes with the reviewed production code and the round-2 witness script. Run the candidate probes after applying the production changes.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-147 &&
qa147_base=/private/tmp/labyrinth_codex/qa147-r2-base
mkdir -p "$qa147_base"
for qa147_probe in STALE_CHECKPOINT DEPARTING_DEFEAT; do
  python3 tools/godot_task_runner.py --task-id qa-147 --stream -- godot --headless --path . --script tools/qa147/round2.gd -- "$qa147_probe" > "$qa147_base/$qa147_probe.log" 2>&1
done

qa147_fixed=/private/tmp/labyrinth_codex/qa147-r2-final
mkdir -p "$qa147_fixed"
for qa147_probe in STALE_CHECKPOINT STALE_OUTAGE DEPARTING_DEFEAT DEPARTING_ENEMY_RESUME CHECKPOINT_DISCARD; do
  python3 tools/godot_task_runner.py --task-id qa-147 --stream -- godot --headless --path . --script tools/qa147/round2.gd -- "$qa147_probe" > "$qa147_fixed/$qa147_probe.log" 2>&1
done
python3 tools/qa147/round2.py --before "$qa147_base" --after "$qa147_fixed"
python3 tools/godot_task_runner.py --task-id qa-147 --stream -- godot --headless --path . --script tests/save_resume_boundary_test.gd
python3 tools/godot_task_runner.py --task-id qa-147 --stream -- godot --headless --path . --script tests/main_menu_resume_test.gd
python3 tools/qa147/run_cases.py --output-dir /private/tmp/labyrinth_codex/qa147-r2-final-round0 --jobs 2
python3 tools/qa147/round1.py --before /private/tmp/labyrinth_codex/qa147-r1-base --output-dir /private/tmp/labyrinth_codex/qa147-r2-final-round1
python3 tests/test_ui_identity_lint.py
PYTHONDONTWRITEBYTECODE=1 python3 tools/run_python_suite.py --shards 4 --changed-since e85515695 --output-dir /private/tmp/labyrinth_codex/qa147-r2-python
PYTHONDONTWRITEBYTECODE=1 python3 tools/run_python_suite.py --shards 1 --pattern test_approved_content_manifest.py --output-dir /private/tmp/labyrinth_codex/qa147-r2-python-approved
PYTHONDONTWRITEBYTECODE=1 python3 tools/run_python_suite.py --shards 4 --changed-since e85515695 --output-dir /private/tmp/labyrinth_codex/qa147-r2-python-verified

qa147_postpack=/private/tmp/labyrinth_codex/qa147-r2-postpack
mkdir -p "$qa147_postpack"
for qa147_probe in STALE_CHECKPOINT DEPARTING_DEFEAT; do
  python3 tools/godot_task_runner.py --task-id qa-147 --stream -- godot --headless --path . --script tools/qa147/round2.gd -- "$qa147_probe" > "$qa147_postpack/$qa147_probe.log" 2>&1
done
python3 tools/qa147/round2.py --before "$qa147_base" --after "$qa147_postpack"
```

The existing deferred run-skill test requires a window server for its native frame signals.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-147 &&
python3 tools/visual_probe_runner.py --task-id qa-147 --no-headless \
  --display-driver macos --audio-driver Dummy --min-images 0 \
  tests/deferred_run_skill_analytics_test.gd
```

## Round 3

### Acceptance

1. Continue, New Run, and Rise Again try to carry uncovered receipts before backup promotion or checkpoint replacement. The disk worker logs one warning per affected run with the count of unique receipts the carry could not save. Promotion and replacement continue through their existing checkpoint transactions. A checkpoint I/O failure still uses its original failure path.
2. The carry checks the successor's win keys before opening the profile for writing. The existing replacement builder puts the pair in the successor checkpoint and preserves its keys and order, including when the Umbra Depth session tolerates a failed profile save. Title boot still leaves the stale file available after a failed replay, and housekeeping still retains the file after a failed carry.
3. The five declined findings remain known multi-fault limits. A synced live profile can hide the only carried pair after an interrupted profile rotation. The Save & Quit drain can retry an already queued batch after departure begins. Title replay can append a run's ending before an earlier hidden win. An earlier defeat row can claim the combat-end key for a later win. Successfully delivered carried receipts can remain in the profile outbox.

The pre-patch checkout was `ee98f7d852f988ea5cdbd99e4cff88cfb92e7ace`. The `CONTINUE`, `NEW_RUN`, and `RISE_AGAIN` cases returned `UNAVAILABLE` at backup promotion. For the depth case, the profile is writable during the existing pre-replacement recovery. A simulated sync then installs the older profile between preparation and commit, so the outgoing checkpoint and staged replacement have the pair when the replacement starts under a tolerated profile write outage. [Round 2 review](/private/tmp/labyrinth_codex/review/qa-147-ee98f7d85.md) · [Baseline runner logs](/private/tmp/labyrinth_codex/qa147-r3-before)

### Chosen defaults

The probe reuses the round-1 seed and chooses the first reachable combat and first legal movement target. The two runs have distinct synthetic run and combat IDs. The depth proof unlocks and selects Depth 1. New Run and Rise Again release the profile blocker at the ordinary profile acknowledgment after promotion. Continue keeps it through the choice. The depth proof blocks profile writes for depth selection and replacement commit. The ledger blocker remains in place throughout each choice. No `TODO_DESIGN` placeholders were needed.

### Round 3 proof

```text
QA147R3 CONTINUE before=UNAVAILABLE after=PLAYABLE_BACKUP PASS
QA147R3 NEW_RUN before=UNAVAILABLE after=REPLACED PASS
QA147R3 RISE_AGAIN before=UNAVAILABLE after=REPLACED PASS
QA147R3 NEW_RUN_DEPTH_SAVE_FAILURE before=INSTALL_FAILED after=REPLACED_WITH_RECEIPTS PASS
QA147R3 PASS cases=4
```

Continue checks the promoted bytes against the original backup and performs a legal combat move after loading. New Run and Rise Again install a new run and record the selected backup's completion. Each promotion logs `WARNING: Could not carry 2 win analytics receipts for run qa147r3_outgoing.` exactly once. The depth case installs a new checkpoint at the selected depth with both original keys, with zero carry warnings. [Probe comparison](/private/tmp/labyrinth_codex/qa147-r3-proof.log) · [Candidate runner logs](/private/tmp/labyrinth_codex/qa147-r3-final)

```text
QA147R1 later_checkpoint before=retained:0,rows:0 after=retained:2,rows:2 PASS
QA147R1 departing_transition before=live_writes:1,pre_continue:2,rows:2 after=live_writes:0,pre_continue:0,rows:2 PASS
QA147R1 PASS findings=2
QA147R2 STALE_CHECKPOINT rows_before=0 rows_after=2 duplicates=0 PASS
QA147R2 DEPARTING_DEFEAT live_writes=0 staged_kept=true replayed_on_continue=1 PASS
QA147R2 PASS findings=2
TEST RESULT: PASS — committed save/resume boundary matrix
TEST RESULT: PASS — main menu resume safety
Ran 25 tests in 16.428s
OK
```

The round-2 supplemental probes also reported `"passed":true` for `STALE_OUTAGE`, `DEPARTING_ENEMY_RESUME`, and `CHECKPOINT_DISCARD`. The last checks that failed housekeeping leaves the checkpoint in place and that a successful carry remains deliverable. [Round 1 logs](/private/tmp/labyrinth_codex/qa147-r3-round1) · [Round 2 logs](/private/tmp/labyrinth_codex/qa147-r3-round2) · [Focused suite logs](/private/tmp/labyrinth_codex/qa147-r3-checks) · [UI identity lint](/private/tmp/labyrinth_codex/qa147-r3-ui-lint.log)

The first round-0 run reported `QA147 FAIL cases=17`. It had timed-out starts and ready-reward witnesses, and one process loaded code during an intermediate edit. The first serial retry verified seven of eight cases. Turn-start Save & Quit reached its cut and appended both rows on that retry, then hit the 90-second process cap before the ready marker. Its quiet rerun passed with the existing timeout. Combining the verified witnesses confirms one row of each kind in order with the original keys for every combat. [Initial matrix](/private/tmp/labyrinth_codex/qa147-r3-round0.log) · [Serial retry](/private/tmp/labyrinth_codex/qa147-r3-round0-retry.log) · [Verified matrix](/private/tmp/labyrinth_codex/qa147-r3-round0-verified.log)

```text
QA147 card_control combat_ended=1 reward_offered=1 PASS
QA147 card_save_victory combat_ended=1 reward_offered=1 PASS
QA147 card_save_intro combat_ended=1 reward_offered=1 PASS
QA147 card_save_ready combat_ended=1 reward_offered=1 PASS
QA147 card_close_victory combat_ended=1 reward_offered=1 PASS
QA147 card_close_intro combat_ended=1 reward_offered=1 PASS
QA147 card_close_ready combat_ended=1 reward_offered=1 PASS
QA147 card_kill_after_write combat_ended=1 reward_offered=1 PASS
QA147 fire_kill_after_write combat_ended=1 reward_offered=1 PASS
QA147 fire_kill_before_write combat_ended=1 reward_offered=1 PASS
QA147 burst_kill_before_write combat_ended=1 reward_offered=1 PASS
QA147 turn_start_save_victory combat_ended=1 reward_offered=1 PASS
QA147 guardian_close_ready combat_ended=1 reward_offered=1 PASS
QA147 dragon_save_victory combat_ended=1 reward_offered=1 PASS
QA147 final_dragon_save_victory combat_ended=1 reward_offered=1 PASS
QA147 continue_twice combat_ended=1 reward_offered=1 PASS
QA147 save_twice combat_ended=1 reward_offered=1 PASS
QA147 PASS cases=17
```

The parallel Python default group selected 23 modules and reported `Ran 196 tests in 43.742s` and `FAILED (failures=1)`. The Godot runner cancellation test reached its child-start deadline and reported `AssertionError: False is not true : Child did not start`. The isolated `test_godot_task_runner.py` rerun reported `Ran 15 tests in 10.559s` and `OK`. The sandbox rejected the optional Git timing-cache write. [Parallel default log](/private/tmp/labyrinth_codex/qa147-r3-python.log) · [Isolated runner log](/private/tmp/labyrinth_codex/qa147-r3-python-runner.log)

The serial default group reported `Ran 196 tests in 348.500s` and `FAILED (failures=3)`. The approved-content smoke returned `error: command timed out after 30 seconds.` The program suite runner returned `error: command timed out after 15 seconds.` in the deliberate-failure and hung-child subtests. Both modules passed in the parallel default run. [Serial default log](/private/tmp/labyrinth_codex/qa147-r3-python-serial.log)

In isolation, `test_program_suite_runner.py` reported `Ran 42 tests in 43.984s` and `OK`. The approved-content smoke again returned `error: command timed out after 30 seconds.`, with `Ran 1 tests in 268.871s` and `FAILED (failures=1)`. Every default-group module has passing evidence across the parallel run and isolated reruns. The two aggregate default runs each reported failures. [Isolated program suite log](/private/tmp/labyrinth_codex/qa147-r3-python-program.log) · [Isolated approved-content log](/private/tmp/labyrinth_codex/qa147-r3-python-approved.log)

### Files changed in round 3

- `scripts/progression_store.gd` makes the receipt carry best-effort for backup promotion and request-driven replacement, and recognizes a successor checkpoint that already contains the pair.
- `spec/analytics.md` records the carry and housekeeping rules.
- `tools/qa147/round3.gd` and its `.uid` exercise the four fault scenarios. `tools/qa147/round3.py` compares the witnesses and checks the warnings. These are task probes outside the permanent test suites.
- `tools/qa147/result.md` records round 3.

### Round 3 commands

The first three baseline probes ran in the `ee98f7d85` checkout before the production edit. The corrected depth baseline ran with that revision's `scripts/progression_store.gd` in a temporary project overlay under `.godot/qa147-r3-baseline`. The overlay linked the other project files and import cache from this worktree.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-147 &&
qa147_logs=/private/tmp/labyrinth_codex
for qa147_case in CONTINUE NEW_RUN RISE_AGAIN NEW_RUN_DEPTH_SAVE_FAILURE; do
  python3 tools/godot_task_runner.py --task-id qa-147 --stream -- godot --headless --path . --script tools/qa147/round3.gd -- "$qa147_case" > "$qa147_logs/qa147-r3-final/$qa147_case.log" 2>&1
done
python3 tools/godot_task_runner.py --task-id qa-147 --stream -- godot --headless --path .godot/qa147-r3-baseline --script tools/qa147/round3.gd -- NEW_RUN_DEPTH_SAVE_FAILURE
python3 tools/qa147/round3.py --before "$qa147_logs/qa147-r3-before" --after "$qa147_logs/qa147-r3-final"
python3 tools/qa147/run_cases.py --output-dir "$qa147_logs/qa147-r3-round0" --jobs 2
python3 tools/qa147/run_cases.py --output-dir "$qa147_logs/qa147-r3-round0-retry" --jobs 1 --only card_close_victory --only card_close_intro --only card_close_ready --only card_kill_after_write --only fire_kill_after_write --only fire_kill_before_write --only burst_kill_before_write --only turn_start_save_victory
python3 tools/qa147/run_cases.py --output-dir "$qa147_logs/qa147-r3-round0-turn-start" --jobs 1 --only turn_start_save_victory
python3 tools/qa147/round1.py --before "$qa147_logs/qa147-r1-base" --output-dir "$qa147_logs/qa147-r3-round1"
for qa147_case in STALE_CHECKPOINT STALE_OUTAGE DEPARTING_DEFEAT DEPARTING_ENEMY_RESUME CHECKPOINT_DISCARD; do
  python3 tools/godot_task_runner.py --task-id qa-147 --stream -- godot --headless --path . --script tools/qa147/round2.gd -- "$qa147_case" > "$qa147_logs/qa147-r3-round2/$qa147_case.log" 2>&1
done
python3 tools/qa147/round2.py --before "$qa147_logs/qa147-r2-base" --after "$qa147_logs/qa147-r3-round2"
python3 tools/godot_task_runner.py --task-id qa-147 --stream -- godot --headless --path . --script tests/save_resume_boundary_test.gd
python3 tools/godot_task_runner.py --task-id qa-147 --stream -- godot --headless --path . --script tests/main_menu_resume_test.gd
python3 tests/test_ui_identity_lint.py
PYTHONDONTWRITEBYTECODE=1 python3 tools/run_python_suite.py --shards 4 --changed-since ee98f7d85 --output-dir "$qa147_logs/qa147-r3-python"
PYTHONDONTWRITEBYTECODE=1 python3 tools/run_python_suite.py --shards 1 --pattern test_godot_task_runner.py --output-dir "$qa147_logs/qa147-r3-python-runner"
PYTHONDONTWRITEBYTECODE=1 python3 tools/run_python_suite.py --shards 1 --changed-since ee98f7d85 --output-dir "$qa147_logs/qa147-r3-python-serial"
PYTHONDONTWRITEBYTECODE=1 python3 tools/run_python_suite.py --shards 1 --pattern test_approved_content_manifest.py --output-dir "$qa147_logs/qa147-r3-python-approved"
PYTHONDONTWRITEBYTECODE=1 python3 tools/run_python_suite.py --shards 1 --pattern test_program_suite_runner.py --output-dir "$qa147_logs/qa147-r3-python-program"
git --no-optional-locks diff --check
```

Round 3's proof is headless. The earlier native capture procedure and the native deferred run-skill command remain above.
