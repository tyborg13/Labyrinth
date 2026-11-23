# gfix-42 candidate 7 results

All 14 reported assertion failures reproduced at `7b3176ac6` and passed after updating stale test expectations. The test changes are uncommitted on `codex/gfix-42`.

## 1. Before and after

Each command below was run from the task worktree before and after the test changes.

| Command | Candidate 7 | After |
| --- | --- | --- |
| `python3 tools/godot_task_runner.py --task-id gfix-42 --stream -- godot --headless --path . --script tests/glossary_test.gd` | `GLOSSARY TEST RESULT: FAIL (6218 checks, 4 failures)` | `GLOSSARY TEST RESULT: PASS (6218 checks, 0 failures)` |
| `python3 tools/godot_task_runner.py --task-id gfix-42 --stream -- godot --headless --path . --script tests/board_tile_tooltip_test.gd` | `BOARD TILE TOOLTIPS: FAIL checks=233 failures=8` | `BOARD TILE TOOLTIPS: PASS checks=233 failures=0` |
| `python3 tools/godot_task_runner.py --task-id gfix-42 --stream -- godot --headless --path . --script tests/character_menu_polish_probe.gd` | `ERROR: Points enable the native primary Learn action` | `CHARACTER MENU POLISH: PASS` |
| `python3 tools/godot_task_runner.py --task-id gfix-42 --stream -- godot --headless --path . --script tests/character_review_fixes_probe.gd` | `ERROR: Character uses the shared close socket` | `CHARACTER REVIEW FIXES: PASS` |

Logs for [Glossary before](/private/tmp/labyrinth_codex/gfix-42-glossary_test-baseline.log) and [Glossary after](/private/tmp/labyrinth_codex/gfix-42-glossary_test-after.log), [Board tooltips before](/private/tmp/labyrinth_codex/gfix-42-board_tile_tooltip_test-baseline.log) and [Board tooltips after](/private/tmp/labyrinth_codex/gfix-42-board_tile_tooltip_test-after.log), [Character menu before](/private/tmp/labyrinth_codex/gfix-42-character_menu_polish_probe-baseline.log) and [Character menu after](/private/tmp/labyrinth_codex/gfix-42-character_menu_polish_probe-verified.log), [Character review before](/private/tmp/labyrinth_codex/gfix-42-character_review_fixes_probe-baseline.log) and [Character review after](/private/tmp/labyrinth_codex/gfix-42-character_review_fixes_probe-after.log).

## 2. Assertion classifications

| Assertion site | Exact failing line | Class | Product commit | Updated expectation | After result line |
| --- | --- | --- | --- | --- | --- |
| [glossary_test.gd](../../tests/glossary_test.gd#L74) | `ERROR: Keyword panel count unchanged: meteorfall` | Stale | `b966ccdeb` (txt-28) | [Fixture line 103](../../tests/fixtures/approved_glossary_structure.gd#L103) pins 3 panels after the separate Ranged panel was retired. | `GLOSSARY TEST RESULT: PASS (6218 checks, 0 failures)` |
| [glossary_test.gd](../../tests/glossary_test.gd#L76) | `ERROR: Keyword panel order unchanged: meteorfall/1` | Stale | `b966ccdeb` (txt-28) | [Fixture line 103](../../tests/fixtures/approved_glossary_structure.gd#L103) pins Range immediately after Cinder Marks. | `GLOSSARY TEST RESULT: PASS (6218 checks, 0 failures)` |
| [glossary_test.gd](../../tests/glossary_test.gd#L76) | `ERROR: Keyword panel order unchanged: meteorfall/2` | Stale | `b966ccdeb` (txt-28) | [Fixture line 103](../../tests/fixtures/approved_glossary_structure.gd#L103) pins Fire immediately after Range. | `GLOSSARY TEST RESULT: PASS (6218 checks, 0 failures)` |
| [glossary_test.gd](../../tests/glossary_test.gd#L199) | `ERROR: Hover displays relic plus deduplicated definitions` | Stale | `145368ad0` (txt-26) | Line 199 pins a visible relic followed by Health Cost, Stoneskin, Health, Empower in first-mention order, each once. | `GLOSSARY TEST RESULT: PASS (6218 checks, 0 failures)` |
| [board_tile_tooltip_test.gd](../../tests/board_tile_tooltip_test.gd#L76), Fire ground | `ERROR: Trap last, exact copy and loop metadata` | Stale | `35b683909` (txt-27) | [Lines 203–205](../../tests/board_tile_tooltip_test.gd#L203) pin the new display line in the exact Earth Trap entry at the end of the Fire/Rubble stack. | `BOARD TILE TOOLTIPS: PASS checks=233 failures=0` |
| [board_tile_tooltip_test.gd](../../tests/board_tile_tooltip_test.gd#L76), Ice ground | `ERROR: Trap last, exact copy and loop metadata` | Stale | `35b683909` (txt-27) | [Lines 203–205](../../tests/board_tile_tooltip_test.gd#L203) pin the new display line in the exact Earth Trap entry at the end of the Ice/Rubble stack. | `BOARD TILE TOOLTIPS: PASS checks=233 failures=0` |
| [board_tile_tooltip_test.gd](../../tests/board_tile_tooltip_test.gd#L76), Electrified ground | `ERROR: Trap last, exact copy and loop metadata` | Stale | `35b683909` (txt-27) | [Lines 203–205](../../tests/board_tile_tooltip_test.gd#L203) pin the new display line in the exact Earth Trap entry at the end of the Electrified/Rubble stack. | `BOARD TILE TOOLTIPS: PASS checks=233 failures=0` |
| [board_tile_tooltip_test.gd](../../tests/board_tile_tooltip_test.gd#L144) | `ERROR: Trap icon, copy and tooltip loop: fire` | Stale | `35b683909` (txt-27) | [Lines 203–205](../../tests/board_tile_tooltip_test.gd#L203) pin the approved ground sentence and cross diagram in the full Fire entry. | `BOARD TILE TOOLTIPS: PASS checks=233 failures=0` |
| [board_tile_tooltip_test.gd](../../tests/board_tile_tooltip_test.gd#L144) | `ERROR: Trap icon, copy and tooltip loop: ice` | Stale | `35b683909` (txt-27) | [Lines 203–205](../../tests/board_tile_tooltip_test.gd#L203) pin the approved ground sentence and cross diagram in the full Ice entry. | `BOARD TILE TOOLTIPS: PASS checks=233 failures=0` |
| [board_tile_tooltip_test.gd](../../tests/board_tile_tooltip_test.gd#L144) | `ERROR: Trap icon, copy and tooltip loop: lightning` | Stale | `35b683909` (txt-27) | [Lines 203–205](../../tests/board_tile_tooltip_test.gd#L203) pin the approved ground sentence and cross diagram in the full Lightning entry. | `BOARD TILE TOOLTIPS: PASS checks=233 failures=0` |
| [board_tile_tooltip_test.gd](../../tests/board_tile_tooltip_test.gd#L144) | `ERROR: Trap icon, copy and tooltip loop: earth` | Stale | `35b683909` (txt-27) | [Lines 203–205](../../tests/board_tile_tooltip_test.gd#L203) pin the approved ground sentence and cross diagram in the full Earth entry. | `BOARD TILE TOOLTIPS: PASS checks=233 failures=0` |
| [board_tile_tooltip_test.gd](../../tests/board_tile_tooltip_test.gd#L144) | `ERROR: Trap icon, copy and tooltip loop: air` | Stale | `35b683909` (txt-27), using `2d766d929` (txt-20) markup | [Lines 203–205](../../tests/board_tile_tooltip_test.gd#L203) pin the approved Push sentence and its authored cross markup in the full Air entry. | `BOARD TILE TOOLTIPS: PASS checks=233 failures=0` |
| [character_menu_polish_probe.gd](../../tests/character_menu_polish_probe.gd#L154) | `ERROR: Points enable the native primary Learn action` | Stale | `45ad29580` (txt-16) | Line 154 keeps the enabled-state check and matches the exact single-spaced `Learn · 1 Point` label. | `CHARACTER MENU POLISH: PASS` |
| [character_review_fixes_probe.gd](../../tests/character_review_fixes_probe.gd#L41) | `ERROR: Character uses the shared close socket` | Stale | `c14d4e359` (sd-11) | Line 41 verifies the node is an instance of the shared socket type, including the derived Character drawing script. The probe still exercises focus, hover, and pointer activation. | `CHARACTER REVIEW FIXES: PASS` |

- **Meteorfall.** txt-28 assigns the damage chip's explanation to Cinder Marks and suppresses its separate keyword panel. The fixture independently pins the panel count, order, and all three body-line counts. [Product tokens](../../scripts/action_icon_library.gd#L1466), [txt-28 F17–F19](../txt28/result.md).
- **Iron Lung.** txt-26 moves the first Stoneskin mention ahead of Health and Empower. The stack orders unique glossary entries by first appearance, so the bare `Health` in the revised first sentence appears before Empower and the later explicit Health token deduplicates. [Approved copy](../../data/relics.json#L5), [relic stack](../../scripts/card_focus_tooltip_stack.gd#L101), [deduplication](../../scripts/glossary.gd#L149).
- **Traps.** `git blame` attributes the tile entry's `display_description` to txt-27 and the Air diagram mapping to txt-20. Full entry equality still checks each original semantic description, the rendered line with markup, the `traps` icon and loop term, and the exact `trap` source kind and element. The separate raw copy assertions passed on candidate 7 and after the change. [Tile entry builder](../../scripts/board_tile_tooltip.gd#L19), [Air mapping](../../data/pattern_rule_text.json#L12), [txt-27 acceptance 9](../txt27/result.md#acceptance).
- **Character.** `git log -S` traces the single-spaced Learn button to txt-16 and the Character close socket subclass to sd-11. The subclass inherits the shared input implementation and overrides drawing. The Known Moves assertion still verifies its direct use of the shared script. [Learn state](../../scripts/skill_tree_view.gd#L1318), [Character factory](../../scripts/character_menu_view.gd#L126), [socket subclass](../../scripts/character_socket.gd#L14), [Known Moves assertion](../../tests/character_review_fixes_probe.gd#L181).

### Trap recordings

`TRAP LOOP RECEIPTS: PASS (5 routes and recorded outcomes)`. The routes `trap_fire`, `trap_ice`, `trap_lightning`, `trap_earth`, and `trap_air` match the exact `traps` term and element. The receipt and asset hashes agree and all five receipts have `requires_native_rerecord` set to `false`. Each recorded trigger deals the existing depth-1 damage of 6 on the center tile. Fire, Ice, Electrified, and Rubble cover the center and four adjacent tiles. Air pushes the adjacent Crawler one tile and leaves zero ground tiles. The board test's 7 damage is its existing fixture value. The copy changes require no re-recording. [Registry](../../data/tooltip_loops.json#L264), [production trap rules](../../scripts/combat_engine.gd#L7827), [recorded behavior](../trp01/TRP01.md).

## 3. Scope and files

Changes are confined to [glossary_test.gd](../../tests/glossary_test.gd), its [approved structure adapter](../../tests/fixtures/approved_glossary_structure.gd), [board_tile_tooltip_test.gd](../../tests/board_tile_tooltip_test.gd), [character_menu_polish_probe.gd](../../tests/character_menu_polish_probe.gd), [character_review_fixes_probe.gd](../../tests/character_review_fixes_probe.gd), and this report. The original historical panel capture and approved fixture JSON were read as inputs. All four test programs retain their assertions. No product, asset, or test registration files changed.

## Additional proof

| Command | Observed result |
| --- | --- |
| `python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/gfix-42-python` | `INPUT GROUP default: always run`, `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 33.977s`, `OK` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 6.735s`, `OK` |
| `python3 tests/test_rules_text_lint.py` | `Ran 3 tests in 0.063s`, `OK`, `PASS: Rules text lint (16 existing hits)` |
| `git diff --check` | Exit 0 |

[Python default log](/private/tmp/labyrinth_codex/gfix-42-python.log), [UI identity log](/private/tmp/labyrinth_codex/gfix-42-ui-identity.log), [rules text log](/private/tmp/labyrinth_codex/gfix-42-rules-text.log).

## Proof for the design owner

This unit changed test expectations only. The brief's product-change condition for a windowed command and captures does not apply. The headless Character probes report `HEADLESS ASSERTIONS ONLY; NO SCREENSHOTS` and produced no capture paths.

## TODO_DESIGN placeholders

None.

## Chosen defaults

None. The probes retain their existing fixtures, timing, 1920×1080 viewport, and 100% UI scale.

## Open issues

No additional test failures surfaced. Godot logged the macOS certificate lookup error on the baseline and final runs. The glossary pass logged one resource still in use at exit. The baseline and final logs also include the glossary probe's above-row overflow diagnostic and the board probe's missing Bramble and Ice Pillar definitions. The Python run passed with its Git timing cache write denied by the sandbox. Initial runs exposed missing local imports. The final proof used existing engine cache artifacts after comparing the approved source and import sidecar bytes.
