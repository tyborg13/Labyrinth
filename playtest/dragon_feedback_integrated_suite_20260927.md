# Dragon feedback integrated-suite triage — 2026-09-27

The official Godot 4.6.1 task-runner invocation of `tests/run_tests.gd` completed
normally within its default 300-second limit and exited 1 with 40 failures.
It was not timed out or retried with a longer limit.

Run: `dragon-boss-encounters-milestone-rewards-1790534298746688000-30940`.
Full retained log:
`/private/tmp/labyrinth-godot-home/dragon-boss-encounters-milestone-rewards-1790534298746688000-30940/godot.log`.
Exact assertion messages: `/private/tmp/dragon-integrated-suite-20260927-failures.txt`.

## Reward/NPC worker scope

- Four actual copy omissions: Winter's Hourglass spells out the Ice element and
  Time; Stormroad Coil spells out Ranged and Range. The existing icon audit is
  correct. Two data-only description replacements are prepared with the existing
  `element_ice`, `time`, `ranged` and `range` tokens. No registry or identity changes
  are needed. The element token must not be replaced with the distinct Ice surface.
  After the native study ended and the production lease was released, the two
  description strings were corrected. Fresh `trophy-icons-04.json` native proof
  passed all ten captures, which were inspected at original 1920×1080 resolution.
- Twenty-seven shared UI failures: one Pass, nine reward-selection, and seventeen
  campfire assertions inject a new run mode but call only `_refresh_choice_bar`.
  That leaves the opening Emaciated Man dialogue active, which correctly suppresses
  choices while speaking. Normal `_refresh_ui` closes dialogue outside room mode.
  The four affected fixture functions now enter through that production transition
  and assert the dialogue closed; all original UI, input and single-shot checks remain.
- Two obsolete narrative expectations appended the entrance service to the opening
  speech and Umbra warning. The test now checks that completed narrative closes,
  contains no service options, restores the separate Speak action, and does not
  unlock Awaken Power before the first dragon introduction. The warning's durable
  seen-marker assertion remains. Dedicated reward-flow coverage owns first-unlock
  persistence and recurring service behavior.

Changed functions in `tests/run_tests.gd`: `offers_pass_when_hand_dead`,
`selection_prompts_clear_after_pick`, `campfire_choices_use_relic_overlay`,
`campfire_choice_press_is_single_shot`, and `auto_triggers_starting_npc_dialogue`
(all prefixed `_test_run_scene_`). No shared helper was changed.

The other seven failures (electrical specialist/Overload expectations, boss header
geometry, Tempest Breath warning geometry, and Tharokh ranged routing) are assigned
to the cutout review worker in non-overlapping tests. They are not part of this edit.

Tests-only repairs passed `git diff --check`. The presentation worker independently
reviewed the five changed functions and found no blocker: the production mode
boundary closes dialogue synchronously, all original UI/input assertions remain,
and narrative termination matches the separate service flow. That static approval
covers the five test functions. The two copy strings and their fresh native rules
panels were separately reviewed by both the presentation and cutout workers, with
no findings. The successful corrected integrated receipt follows below. The earlier
focused canceled-area, standalone Zekarion, canceled-area native addendum, and
corrected actual-turn-queue native proof remain separately accepted; they do not
turn this integrated failure receipt into a pass.


## Corrected integrated result

The complete `tests/run_tests.gd` rerun passed and the task runner confirmed exit 0
within its default 300-second limit. This run includes both independently reviewed
test-repair sets and the corrected relic descriptions; all 40 prior failures are
resolved without removing their relevant behavior checks.

Run: `dragon-boss-encounters-milestone-rewards-1790536614403264000-33594`.
Log: `/private/tmp/labyrinth-godot-home/dragon-boss-encounters-milestone-rewards-1790536614403264000-33594/godot.log`.
The log ends `TEST RESULT: PASS`. It contains the expected ambiguous legacy-save
migration warning and an ObjectDB cleanup warning, with no test failure or script
error. No timeout override or retry beyond this corrected rerun was used.

```sh
python3 tools/godot_task_runner.py --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --stream -- godot --headless --path . --script tests/run_tests.gd
```

The exclusive Godot/production lease was returned to root after confirmed process
exit. This receipt is integrated regression evidence, not final exact-HEAD peer
review or publication approval.


## Full rerun after final wallet acknowledgment correction

The final native save audit exposed a real pending-outbox resurrection in the
exchange and shared level-up handlers. The [bounded repair and regression](dragon_wallet_ack_review_20260927.md)
retain the expected failing baseline and passing 108-check actual-RunScene test.
After the four-line runtime correction, the complete `tests/run_tests.gd` suite
was rerun once through the mandatory task runner:

```sh
python3 tools/godot_task_runner.py --task-id dragon-boss-encounters-milestone-rewards-and-molt-shard-exchange --run-id dragon-feedback-integrated-after-wallet --stream -- godot --headless --path . --script tests/run_tests.gd
```

Session 63950 completed with verified exit0 within the default 300-second limit.
The retained log `/private/tmp/labyrinth-godot-home/dragon-feedback-integrated-after-wallet/godot.log`
ends `TEST RESULT: PASS`. The known ambiguous legacy conversion and ObjectDB
cleanup warnings remain; there are no test assertions or script errors.
Subsequent production changes are confined to the completed dragon rig data
repairs. Their focused runtime checks, strict production/case parity, independent
cycle inspection, final seven-case source-bound captures and refreshed packaged
resource smoke all pass; see the cutout notes. No publication is approved.
