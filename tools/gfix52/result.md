# gfix-52 implementation receipts

## 1. Release root causes

Release and the original worktree HEAD were both `e3b27e209cd2f4a9e6ccc2e971d4b0a23c581e1a`. The first run used that untouched gameplay code. The comparison run used the same task-local witnesses on both versions. The comparison project under `.godot/gfix52/release-project/` used the release copy of `run_engine.gd` and linked the shared project files and imports.

- **Last Door.** Both room entry paths record the room being left. Section-map edges are stored only on the room the player left. Release required the reverse edge in both the defeat gate and the retreat resolver. Release printed `GFIX-52 last_door_section_map | FAIL | ready=true fight=(1, -1) previous=(0, 0) reverse_link=false mode=defeat current=(1, -1) Health=0`.
- **Deferred Choice.** Release drew the ordinary choices before checking the pending card. When the roll already included that card, insertion returned early and reward finalization cleared the pending value. Release printed `GFIX-52 deferred_natural_repeat | FAIL | saved=flame_jet natural=["flame_jet", "hearth_rush", "rite_of_the_storm"] deferred=["flame_jet", "hearth_rush", "rite_of_the_storm"] pending=''`.

The direct release baseline also reproduced txt-40's original `wildfire_halo` overlap. The matching comparison uses an overlap outside the insertion slot so the replacement is observable in the final offer. The original overlap can produce identical final choices when the saved card would already be placed in the last slot.

## 2. Last Door retreat and save

- [run_engine.gd](../../scripts/run_engine.gd#L1363) resolves a retreat direction once. The [return resolver](../../scripts/run_engine.gd#L1515) uses the recorded predecessor and retains the reciprocal path's direction. For a section edge, it uses the stored outward link from the visited predecessor in the same section, with the reverse travel direction arriving at the door the player left through. The map generator and checkpoint format require no edits.
- Ordinary travel seals the room just left. The retreat reopens that seal, keeps the fled room uncleared and available, spends the current sequence use, and follows the existing save and analytics boundary. A missing predecessor or a sealed predecessor whose entry edge has disappeared leaves an ordinary terminal defeat at the fight's location and Last Door ready. Boss defeats remain terminal. [Permanent regression](../../tests/suites/skill_run_suite.gd#L407)
- Candidate printed `GFIX-52 last_door_section_map | PASS | ready=true fight=(1, -1) previous=(0, 0) reverse_link=false mode=room current=(0, 0) Health=1`.
- Release wrote `.godot/gfix52/release-section.save` via the production writer before editing. It is a 187108-byte in-combat checkpoint with SHA-256 `7e81fb5564e6c5d8b443062fb21b1fedceb8c3428591cc5d061356f49ac512b0`. The candidate loaded it through the resume loader, repaired the state, and printed `GFIX-52 load_release_section_save | PASS | revision=7 resumed=combat current=(1, -1) previous=(0, 0) ready=true after_loss=room returned=(0, 0) Health=1`.
- The capture dry run took the first ordinary route from a fresh descent and let enemies defeat the player through normal Pass input. The live checkpoint loaded at the starting room with the charge spent. The local log had one combat defeat and one Last Door trigger. The probe printed `GFIX-52 live_retreat | passes=5 fight=(1, -1) returned=(0, 0) Health=1 HUD=1/24 saved=true skill_receipts=1`.

## 3. Deferred Choice insertion

- [run_engine.gd](../../scripts/run_engine.gd#L2879) excludes the pending card before drawing elemental, general, and rarity-floor choices. The existing insertion helper still chooses the slot, keeps deck-element preference, and lets Warband offers repair their rarity floor while protecting the saved card. The live combat offer and texture prewarm use the same generator.
- Candidate printed `GFIX-52 deferred_natural_repeat | PASS | saved=flame_jet natural=["flame_jet", "hearth_rush", "rite_of_the_storm"] deferred=["firebrand_volley", "stoke", "flame_jet"] pending=''`. The [permanent regression](../../tests/suites/skill_run_suite.gd#L142) covers natural overlaps on both a three-card ordinary offer and a four-card Warband offer.

## Feedback 1. Deferred Choice in event rewards

The Moth-Eaten Library's Search choice already used Deferred Choice when the chooser opened. With `petrify` pending, both the natural roll and the pre-fix offer were `["petrify", "root_snare", "quarry_step"]`. Continue cleared the pending card. The expanded witness printed `GFIX-52 deferred_event_natural_repeat | FAIL` before the event change.

[event_rules.gd](../../scripts/event_rules.gd#L405) now removes the saved ID from the authored card-choice pools before the draw, preserving the event's element and rarity filters. The existing insertion path supplies the same offer to the choice preview, hover, and chooser on Continue. The result-page checkpoint and `map_event_resolved` retain the generated roll. Continue applies the existing replacement slot and clears the pending card. If the pool runs out of alternatives, the saved card fills a vacant slot to preserve the offer size. Direct card grants use the same rolls as before.

```text
GFIX-52 deferred_event_natural_repeat | PASS | event=moth_library saved=petrify natural=["petrify", "root_snare", "quarry_step"] generated=["rite_of_the_mountain", "root_snare", "quarry_step"] preview=["rite_of_the_mountain", "root_snare", "petrify"] reward=["rite_of_the_mountain", "root_snare", "petrify"] pending=''
```

The [existing Deferred Choice regression](../../tests/suites/skill_run_suite.gd#L175) now checks the preview and hover, the committed roll and receipt, the pending card on the result page, and Continue after serializing and repairing the result checkpoint. The fixture uses the existing suite seed and room. No new design values or save fields were introduced.

Feedback 1 logs are under `.godot/gfix52/feedback-1/`. These checks ran headless through the task runner.

| Check | Exact summary |
| --- | --- |
| Witnesses before event fix | `GFIX-52 WITNESSES: FAIL (1 failures)`, exit 1 |
| Witnesses after event fix, including release-save load | `GFIX-52 WITNESSES: PASS (0 failures)`, exit 0 |
| `run_skill_rules.gd` | `SKILL RUN RULES: PASS (139 checks, 0 failures)`, exit 0 |
| `tests/event_rules_test.gd` | `Event rules suite: 0 failures`, exit 0 |
| `tests/event_rules_test.gd -- --empty-card-pools-only` | `Event empty card preview suite: 0 failures`, exit 0 |
| `tests/event_feedback_test.gd` | `Event feedback suite: 0 failures`, exit 0 |
| `tests/deck_element_reward_test.gd` | `DECK ELEMENT REWARDS: 0 failures`, exit 0 |

## Round 0 checks

Logs are under `.godot/gfix52/`. The two witnesses are kept in [witnesses.gd](witnesses.gd). Each Godot check used the task runner and the Python run selected only the default group.

| Check | Exact summary |
| --- | --- |
| Release witnesses | `GFIX-52 WITNESSES: FAIL (2 failures)`, exit 1 |
| Candidate witnesses with release-save load | `GFIX-52 WITNESSES: PASS (0 failures)`, exit 0 |
| `run_skill_rules.gd` | `SKILL RUN RULES: PASS (135 checks, 0 failures)`, exit 0 |
| `tests/deck_element_reward_test.gd` | `DECK ELEMENT REWARDS: 0 failures`, exit 0 |
| `tests/player_defeat_continuity_test.gd` | `PLAYER DEFEAT CONTINUITY: PASS`, exit 0 |
| `tests/dragon_rewards_test.gd` | `Dragon rewards, gifts, wallet recovery and relic hooks passed.`, exit 0 |
| `tests/section_transition_test.gd` | `SECTION TRANSITION RESULT: 0 failures`, exit 0 |
| `sh tools/gfix52/native.sh --dry-run` | `GFIX-52 RETREAT CAPTURE DRY RUN: PASS`, exit 0 |
| Python default | `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 29.489s`, `OK`, exit 0 |
| Rules text lint within Python default | `PASS: Rules text lint (16 existing hits)` |
| `tests/deferred_run_skill_analytics_test.gd` headless attempt | `Timed out waiting for native rendered frames; use a real renderer, not --headless.`, zero assertions, exit 1 |

Godot emitted the macOS system CA certificate diagnostic during headless startup on both versions. The Python runner's optional timing-cache update hit the read-only Git metadata after tests passed.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-52 && sh tools/gfix52/native.sh
```

The run uses `LABYRINTH_CEL_LOOK=all` and the visual probe runner at 1920×1080 and 100% UI scale. It prints the PNG path on its own line. The expected PNG is `.godot/gfix52/native/last_door_retreat.png`. The runner writes `.godot/gfix52/native/manifest.json`. Window-server access is required for these files. The headless dry run produced gameplay and save receipts only.

The existing renderer-dependent analytics check can be run with:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-52 && python3 tools/godot_task_runner.py --task-id gfix-52 --stream -- godot --display-driver macos --audio-driver Dummy --path . --script tests/deferred_run_skill_analytics_test.gd
```

## Chosen defaults

- The deterministic probes share seed `73021` with the run-skill suite and txt-40. The witness uses the first reward coordinate `(1, 0)`, overlap search depth `2`, fixture victory Health `80`, and resolver damage `100`.
- The live capture uses the first generated route and caps Pass input at 24 attempts. The visual runner allows 120 seconds for scene startup and the played fight. The proof contract checks a central room region for nonblank pixels.
- No `TODO_DESIGN_*` placeholders. The work is uncommitted.
