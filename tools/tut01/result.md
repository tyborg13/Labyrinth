# tut-01 implementation and proof

## Accepted copy

With gear on the step, the walk prompt uses “You begin each turn with 2 Movement. Use 1 to step onto the gear.” A pre-move release save keeps its off-step gear and displays “You begin each turn with 2 Movement. Use 1 to move onto the glowing tile.” Both pointer and controller definitions use the matching copy. The new authored lesson uses “Gear and items appear on tiles. Step onto them before the fight ends, or they crumble.” The witness finished the fight with both pickups unclaimed. Victory marked both entries missed and neither entered the loadout.

```text
TUT-01 release step: tile=(4, 4) floor=stone gear=sawtooth_knife gear_tile=(1, 3) claimed=false found_log=false first_combat_won=false
TUT-01 branch step: tile=(4, 4) floor=stone gear=sawtooth_knife gear_tile=(4, 4) claimed=true found_log=true first_combat_won=false
TUT-01 crumble: outcome=victory gear=sawtooth_knife item=crimson_draught missed=["equipment", "item"] notice=Unclaimed gear crumbles into dust.
```

## Changed files

1. [scripts/run_engine.gd](../../scripts/run_engine.gd#L3043) places the reserved equipment at the authored step and validates that the tile is stone without a surface or trap. The reserved equipment ID, reserve flag and save fields are preserved. Combat movement claims the pickup through the normal engine path.
2. [scripts/contextual_combat_tutorial.gd](../../scripts/contextual_combat_tutorial.gd#L248) contains the exact move copy and the new authored definition at lesson 2 of 11. The release wording is selected when the step has no gear. The authored lesson numbers after the move advance by one. The version-1 table and the legacy-starter text provided by `phase_definition` retain their release values.
3. [Move copy selection](../../scripts/run_scene.gd#L7786) reads the unclaimed gear at the destination. [Checkpoint reconciliation](../../scripts/run_scene.gd#L7849) checks whether the loot lesson is pending before enemy inspection, and [prompt presentation](../../scripts/run_scene.gd#L7977) allows the read-only lesson without a spotlight. [The movement handoff](../../scripts/run_scene.gd#L21959) stages the pending marker in the tutorial scenario when feedback ends and the movement milestone commits. [Continue](../../scripts/run_scene.gd#L8351) clears the marker, records `floor_loot_read` through the existing `guided_tutorial_step_completed` event, and shows enemy inspection.
4. [tests/contextual_combat_tutorial_test.gd](../../tests/contextual_combat_tutorial_test.gd#L32) updates the curriculum counts and move sentence. [tests/gear_02_rules_test.gd](../../tests/gear_02_rules_test.gd#L174) expects gear on the scripted destination.
5. [witness.gd](witness.gd) records the release and branch pickup comparison, the victory loot resolution, and release-save reconstruction. [native.sh](native.sh), [native_capture.gd](native_capture.gd) and [proof_contract.json](proof_contract.json) drive the captures and exercise both move sentences, the pickup checkpoint, Continue Run during the lesson, and Continue from the lesson.

## Receipts

The release witness ran before production edits at `e3b27e209cd2f4a9e6ccc2e971d4b0a23c581e1a`. It wrote release checkpoint fixtures under `.godot/tut01/release-saves/`. Each of the 23 release phase IDs reconstructed to the same committed phase on both revisions. Transient phases resumed at their release action boundaries.

```text
TUT-01 move copy (fresh run): You begin each turn with 2 Movement. Use 1 to step onto the gear.
TUT-01 branch save: during pickup -> select_player
TUT-01 branch save: during the loot lesson -> floor_loot
TUT-01 Continue Run during lesson: floor_loot
TUT-01 branch save: after Continue -> inspect_enemy
TUT-01 DRY RUN: PASS
TUT-01 move copy (release save): You begin each turn with 2 Movement. Use 1 to move onto the glowing tile.
TUT-01 RELEASE MOVE COPY: PASS
```

| Check | Observed result |
| --- | --- |
| Release `witness.gd -- --capture-release` | `TUT-01 release saves checked: 23` and `TUT-01 RELEASE WITNESS: PASS` |
| Branch `witness.gd` | `TUT-01 release saves checked: 23` and `TUT-01 BRANCH WITNESS: PASS` |
| `tests/contextual_combat_tutorial_test.gd` | `CONTEXTUAL COMBAT TUTORIAL TEST: PASS` |
| `tests/guided_combat_tutorial_integration_test.gd` | `GUIDED COMBAT TUTORIAL INTEGRATION TEST: PASS` |
| `tests/gear_02_rules_test.gd` | `GEAR-02 RULES: PASS (566 checks, 0 failures)` |
| `tests/test_rules_text_lint.py` | `Ran 3 tests in 0.087s`, `OK` and `PASS: Rules text lint (16 existing hits)` |
| `tests/test_ui_identity_lint.py` | `Ran 25 tests in 6.439s` and `OK` |
| Python default group, initial round | `Ran 196 tests in 37.485s` and `OK`. Report under `.godot/tut01/python-default/`. |

The saved release move can be exercised again through Continue Run with the checkpoint fixture above.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/tut-01 && LABYRINTH_CEL_LOOK=all python3 tools/godot_task_runner.py --task-id tut-01 --stream -- godot --headless --path . --script tools/tut01/native_capture.gd -- --dry-run --release-move
```

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/tut-01 && tools/tut01/native.sh
```

The windowed command uses `LABYRINTH_CEL_LOOK=all`, 1920×1080 at 100% UI scale, and a runner-isolated fresh profile. The expected PNGs are `.godot/tut01/native/01_move_step.png`, `.godot/tut01/native/02_pickup_feedback.png`, and `.godot/tut01/native/03_loot_on_the_floor.png`. The windowed run is pending on the design owner's machine.

## Chosen defaults

- The witness and visual proof use seed `90211`. The crumble fixture uses `crimson_draught`, a one-Health crawler for the final hit, and the other crawler's tile for the unclaimed floor item.
- The save fixtures use a synthetic doorway at `(0, 2)` for the path prompt. The visual probe has a 20-second wait for each asynchronous state and a 60-second renderer-run cap. It captures at the first sampled frame where the pickup banner and icon reach at least 90% opacity.

## Open issues

- The older, out-of-scope [windowed tutorial probe](../../tests/contextual_combat_tutorial_probe.gd#L269) still expects enemy inspection immediately after the move. The task-local probe covers the inserted lesson.
- The initial-round Python runner finished successfully and reported that the read-only Git common directory prevented its optional timing-cache update.

There are no new `TODO_DESIGN` placeholders. All changes are uncommitted.
