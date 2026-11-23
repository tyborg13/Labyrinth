# gfix-44 release-gate investigation

Base `e2cca11a1` on `codex/gfix-44`. Risk tier medium for two UI lifecycle fixes. The tutorial and combat playback changes are test-only. All changes are uncommitted.

## Root causes

- **Tutorial map.** `3960bb9f5` (pol-60) changed the RunScene field from `ColorRect` to `LargeMapBackdrop` for the room-title fade. Assigning a plain `ColorRect` through `Object.set` left the harness field null. RunScene therefore kept using the doorway surface while the harness panel was visible. The production-scene path probe passed on the base using the real backdrop. The fixture now uses the production type and supplies the empty Label its visibility callback expects. The original assertions, copy, padding, and legacy map checks remain.
- **BRS02.** `65e9b7fb4` (pla-04r3) changed the Burst from a square to a cross. `aa4db4519` (pla-07 r1) replaced the fixture's Bleed trigger with Fire, and `66011d459` (pla-07 merge) placed its Ticks for the cross. Enemy 4 at `(4, 6)` and enemy 5 at `(1, 7)` survive the earlier crosses. Fire takes each from 1 to 0 Health at activation start, before its own Burst snapshot. The resolver's surface journal recorded sequences 9 and 11 with `trigger=start` and `health_lost=1`. Playback showed a single `−1` with `icon=surface_fire` on each actor's zero-Health frame. The hero's path remained `[60, 56, 52]`. The check now includes visible activation Fire losses from the resolver journal alongside the Burst losses in Director Pass, and still compares the exact per-actor multiset of pop-up values. The old check accounted for one initiating hit before the first Burst and missed subsequent Fire losses between Bursts.
- **Keyword stack.** `8fa3840e6` (kw-01) bound the stack as argument 2 on a static signal callback. The run host freed its shared stack before the outliving card triggers exited. Godot rejected the freed bound object while converting it to `Control`, before the existing validity check could run. At `scripts/card_keyword_hover.gd:22`, the connection now targets `hide_for` on the stack, so freeing the receiver removes the connection and a live receiver still dismisses the exiting trigger's own stack.
- **Native tooltip ornament.** `be2520354` introduced the ornament-owned coroutine. `3ae4aa4b2` (qa-72) preserved its two layout waits using a captured SceneTree and tree-membership checks. Godot could still reject the resume before executing those checks if the popup freed the ornament. At `scripts/themed_inset_ornament.gd:188` the call passes the tree and ornament explicitly. At line 191 the coroutine is static. Lines 194–198 retain both frame waits and check the ornament's validity before touching it. The final layout call still uses the wrapper's existing tree-membership and queued-deletion check.

## Assertion and script-error ledger

The table uses final line numbers. Each map row was reproduced in both tutorial commands. [Exact result lines and commands](#before-and-after-commands) follow.

| File | Before assertion or script error | Classification | Commit and unit | Change | After |
| --- | --- | --- | --- | --- | --- |
| `tests/suites/guided_combat_tutorial_suite.gd:962,1041` | Each path border should match a selectable map-room rect with the existing 8 px padding [initial] | Stale fixture | `3960bb9f5` pol-60 | Test backdrop, same file:946–950 | Both tutorial commands PASS |
| `tests/suites/guided_combat_tutorial_suite.gd:963` | The open map must not permit the board's hidden doors | Stale fixture | `3960bb9f5` pol-60 | Test backdrop, same file:946–950 | Both tutorial commands PASS |
| `tests/suites/guided_combat_tutorial_suite.gd:978,1041` | Each path border should match a selectable map-room rect with the existing 8 px padding [after scroll] | Stale fixture | `3960bb9f5` pol-60 | Test backdrop, same file:946–950 | Both tutorial commands PASS |
| `tests/suites/guided_combat_tutorial_suite.gd:979` | Path borders should follow the scrolling map | Stale fixture | `3960bb9f5` pol-60 | Test backdrop, same file:946–950 | Both tutorial commands PASS |
| `tests/suites/guided_combat_tutorial_suite.gd:987,1041` | Each path border should match a selectable map-room rect with the existing 8 px padding [after UI scale] | Stale fixture | `3960bb9f5` pol-60 | Test backdrop, same file:946–950 | Both tutorial commands PASS |
| `tests/suites/guided_combat_tutorial_suite.gd:990` | The open-map lesson should use the exact approved copy | Stale fixture | `3960bb9f5` pol-60 | Test backdrop, same file:946–950 | Both tutorial commands PASS |
| `tests/suites/guided_combat_tutorial_suite.gd:997,1041` | Each path border should match a selectable map-room rect with the existing 8 px padding [after reopen] | Stale fixture | `3960bb9f5` pol-60 | Test backdrop, same file:946–950 | Both tutorial commands PASS |
| `tests/suites/guided_combat_tutorial_suite.gd:998` | Reopening should restore map copy in the same call | Stale fixture | `3960bb9f5` pol-60 | Test backdrop, same file:946–950 | Both tutorial commands PASS |
| `tests/suites/guided_combat_tutorial_suite.gd:1001` | The map should continue suppressing other lessons | Stale fixture | `3960bb9f5` pol-60 | Test backdrop, same file:946–950 | Both tutorial commands PASS |
| `tests/suites/guided_combat_tutorial_suite.gd:1018` | Legacy maps should expose and highlight their selectable destination | Stale fixture | `3960bb9f5` pol-60 | Test backdrop, same file:946–950 | Both tutorial commands PASS |
| `tests/suites/guided_combat_tutorial_suite.gd:1022` | Legacy zoom should update the border on the same frame | Stale fixture | `3960bb9f5` pol-60 | Test backdrop, same file:946–950 | Both tutorial commands PASS |
| `tests/brs02_test.gd:466` | director_pass reduced=false enemy_4 damage popups expected=[] actual=[1] | Stale pin | `65e9b7fb4` pla-04r3, `aa4db4519` pla-07 r1, `66011d459` pla-07 merge | Test Fire journal, same file:148–155,457–466 | `BRS02 FOCUSED RESULT: PASS (226 checks; 0 failures)` |
| `tests/brs02_test.gd:466` | director_pass reduced=false enemy_5 damage popups expected=[] actual=[1] | Stale pin | `65e9b7fb4` pla-04r3, `aa4db4519` pla-07 r1, `66011d459` pla-07 merge | Test Fire journal, same file:148–155,457–466 | `BRS02 FOCUSED RESULT: PASS (226 checks; 0 failures)` |
| `tests/brs02_test.gd:466` | director_pass reduced=true enemy_4 damage popups expected=[] actual=[1] | Stale pin | `65e9b7fb4` pla-04r3, `aa4db4519` pla-07 r1, `66011d459` pla-07 merge | Test Fire journal, same file:148–155,457–466 | `BRS02 FOCUSED RESULT: PASS (216 checks; 0 failures)` |
| `tests/brs02_test.gd:466` | director_pass reduced=true enemy_5 damage popups expected=[] actual=[1] | Stale pin | `65e9b7fb4` pla-04r3, `aa4db4519` pla-07 r1, `66011d459` pla-07 merge | Test Fire journal, same file:148–155,457–466 | `BRS02 FOCUSED RESULT: PASS (216 checks; 0 failures)` |
| `tests/helpers/card_legibility_audit.gd:66` | Keyword teardown error 1, display overrides log:29 | Product regression | `8fa3840e6` kw-01 | `scripts/card_keyword_hover.gd:22` | Display overrides PASS, zero matching errors |
| `tests/helpers/card_legibility_audit.gd:66` | Keyword teardown error 2, display overrides log:34 | Product regression | `8fa3840e6` kw-01 | `scripts/card_keyword_hover.gd:22` | Display overrides PASS, zero matching errors |
| `tests/helpers/card_legibility_audit.gd:66` | Keyword teardown error 3, display overrides log:39 | Product regression | `8fa3840e6` kw-01 | `scripts/card_keyword_hover.gd:22` | Display overrides PASS, zero matching errors |
| `tests/helpers/card_legibility_viewport.gd:54` | Keyword teardown error 1, legibility log:20 | Product regression | `8fa3840e6` kw-01 | `scripts/card_keyword_hover.gd:22` | Legibility regressions PASS, zero matching errors |
| `tests/helpers/card_legibility_viewport.gd:54` | Keyword teardown error 2, legibility log:27 | Product regression | `8fa3840e6` kw-01 | `scripts/card_keyword_hover.gd:22` | Legibility regressions PASS, zero matching errors |
| `tests/helpers/card_legibility_viewport.gd:54` | Keyword teardown error 3, legibility log:34 | Product regression | `8fa3840e6` kw-01 | `scripts/card_keyword_hover.gd:22` | Legibility regressions PASS, zero matching errors |
| `tests/helpers/card_legibility_viewport.gd:54` | Keyword teardown error 4, legibility log:41 | Product regression | `8fa3840e6` kw-01 | `scripts/card_keyword_hover.gd:22` | Legibility regressions PASS, zero matching errors |
| `tests/helpers/card_legibility_viewport.gd:54` | Keyword teardown error 5, legibility log:48 | Product regression | `8fa3840e6` kw-01 | `scripts/card_keyword_hover.gd:22` | Legibility regressions PASS, zero matching errors |
| `tests/helpers/card_legibility_viewport.gd:54` | Keyword teardown error 6, legibility log:55 | Product regression | `8fa3840e6` kw-01 | `scripts/card_keyword_hover.gd:22` | Legibility regressions PASS, zero matching errors |
| `scripts/themed_inset_ornament.gd:196` | Ornament resume error 1, BRS01 log:14 | Product regression | `be2520354`, lifecycle follow-up `3ae4aa4b2` qa-72 | Product, same file:188,191–198 | `BRS01 FOCUSED RESULT: PASS (4885 checks; 0 failures)`, zero matching errors |
| `scripts/themed_inset_ornament.gd:196` | Ornament resume error 2, BRS01 log:16 | Product regression | `be2520354`, lifecycle follow-up `3ae4aa4b2` qa-72 | Product, same file:188,191–198 | `BRS01 FOCUSED RESULT: PASS (4885 checks; 0 failures)`, zero matching errors |

## Before and after commands

Logs are in `.godot/gfix44-proof/`. The BRS02 normal baseline log includes the temporary resolver and playback trace. All quoted after-results were observed with exit code 0. No after-log contained a `SCRIPT ERROR:` line or either targeted teardown error.

```sh
python3 tools/godot_task_runner.py --task-id gfix-44 --stream -- godot --headless --path . --script tests/guided_combat_tutorial_integration_test.gd
python3 tools/godot_task_runner.py --task-id gfix-44 --stream -- godot --headless --path . --script tests/suites/full_scene_interaction_followup_program.gd
python3 tools/godot_task_runner.py --task-id gfix-44 --stream -- godot --headless --path . --script tests/brs02_test.gd -- --motion-part-0
python3 tools/godot_task_runner.py --task-id gfix-44 --stream -- godot --headless --path . --script tests/suites/brs02_reduced_program.gd
python3 tools/godot_task_runner.py --task-id gfix-44 --stream -- godot --headless --path . --script tests/card_display_overrides_test.gd
python3 tools/godot_task_runner.py --task-id gfix-44 --stream -- godot --headless --path . --script tests/card_legibility_test.gd -- --regressions-only
python3 tools/godot_task_runner.py --task-id gfix-44 --stream -- godot --headless --path . --script tests/brs01_test.gd
```

| Command | Before | After |
| --- | --- | --- |
| `guided_combat_tutorial_integration_test.gd` | `GUIDED COMBAT TUTORIAL INTEGRATION TEST: FAIL (11)` | `GUIDED COMBAT TUTORIAL INTEGRATION TEST: PASS` |
| `full_scene_interaction_followup_program.gd` | `TEST RESULT: FAIL (11 failure(s))` | `TEST RESULT: PASS` |
| `brs02_test.gd -- --motion-part-0` | `BRS02 FOCUSED RESULT: FAIL (226 checks; 2 failures)` | `BRS02 FOCUSED RESULT: PASS (226 checks; 0 failures)` |
| `brs02_reduced_program.gd` | `BRS02 FOCUSED RESULT: FAIL (216 checks; 2 failures)` | `BRS02 FOCUSED RESULT: PASS (216 checks; 0 failures)` |
| `card_display_overrides_test.gd` | `CARD DISPLAY OVERRIDES TEST RESULT: PASS (16744 checks, 0 failures)`, keyword teardown error ×3 | `CARD DISPLAY OVERRIDES TEST RESULT: PASS (16744 checks, 0 failures)` |
| `card_legibility_test.gd -- --regressions-only` | `CARD LEGIBILITY TEST RESULT: PASS (3 definitions, 3 contexts, 9 samples, 242 checks, 0 failures)`, keyword teardown error ×6 | `CARD LEGIBILITY TEST RESULT: PASS (3 definitions, 3 contexts, 9 samples, 242 checks, 0 failures)` |
| `brs01_test.gd` | `BRS01 FOCUSED RESULT: PASS (4885 checks; 0 failures)`, ornament resume error ×2 | `BRS01 FOCUSED RESULT: PASS (4885 checks; 0 failures)` |

Exact teardown lines:

```text
ERROR: Error calling from signal 'tree_exiting' to callable: 'GDScript::_hide': Cannot convert argument 2 from Object to Object.
ERROR: Resumed function '_tighten_native_tooltip_after_layout()' after await, but class instance is gone. At script: res://scripts/themed_inset_ornament.gd:196
```

The initial unpartitioned `tests/brs02_test.gd` reproduction also returned `BRS02 FOCUSED RESULT: FAIL (442 checks; 4 failures)`. The after-partitions cover those same 442 checks.

### Supporting checks

For each Godot script below, use `python3 tools/godot_task_runner.py --task-id gfix-44 --stream -- godot --headless --path . --script` with the listed arguments.

| Script arguments | Observed result |
| --- | --- |
| `tests/contextual_combat_tutorial_probe.gd -- --path-only --logic-only` | Baseline `UI-25 PATH PROBE: PASS (full, 1920x1080, 100%; logic only; no captures)`. The semantic JSON is at the path printed in `before-tutorial-path.log`, under `probes/ui-25/full-1920x1080/semantic-proof.json`. |
| `tests/contextual_combat_tutorial_test.gd` | `CONTEXTUAL COMBAT TUTORIAL TEST: PASS` |
| `tests/brs02_probe.gd -- --check-only` | `BRS02 PROBE CONTRACT: PASS (1920x1080; 100% UI scale; normal and reduced motion)` |
| `tests/board_tile_tooltip_probe.gd -- --plan-only` | Baseline `BOARD TILE TOOLTIP PROBE PLAN: PASS (1920x1080, UI scale 1.0; three pairs; mouse/controller; native edge bounds; normal/reduced)` |
| `tests/board_tile_tooltip_route_test.gd` | Before and after `BOARD TILE TOOLTIP ROUTES: PASS (12 capture states; real X input; native popup layout; headless, no pixels)` |
| `tests/board_tile_tooltip_test.gd` | Older supplied release log `BOARD TILE TOOLTIPS: FAIL checks=233 failures=8`. The worktree includes gfix-42's revised content pins. The local after-run returned `BOARD TILE TOOLTIPS: PASS checks=233 failures=0`. |

- `GIT_OPTIONAL_LOCKS=0 python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir .godot/gfix44-proof/python-default` selected `INPUT GROUP default: always run` and `SELECTED MODULES: 23 of 59`. Output ended with `Ran 196 tests in 29.179s` and `OK`. Rules text lint within that run returned `PASS: Rules text lint (16 existing hits)`.
- `python3 tests/test_ui_identity_lint.py` returned `Ran 25 tests in 5.484s` and `OK`.
- The visual runner's contract validator accepted the two expected keyword capture names and dimensions with synthetic metadata. `GFIX44 KEYWORD VISUAL CONTRACT: PASS (schema and exact capture names and sizes; no pixels)`.

## Proof for the design owner

Run at 1920×1080 and 100% UI scale. These commands reuse the existing native probes. No windowed captures were attempted in the worker sandbox.

**Post-combat reward cards.** Capture the idle reward choices and the keyword stack beside the hovered first card. The fixture command prepares inputs for the existing keyword capture script. The capture script checks whether the stack is visible. Output is under the visual runner's isolated `user://gfix44-keyword-hover/` as `reward_rest.png` and `reward_hover.png`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-44 && python3 tools/inspection_fixture.py --task-id gfix-44 --run-id gfix44-reward-visual --manifest .godot/gfix44-proof/keyword-reward-fixture.json --scenario reward
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-44 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --task-id gfix-44 --proof-contract tools/gfix44/keyword_hover_proof.json --result-manifest .godot/gfix44-proof/keyword-visual.json tools/kw01/capture.gd -- --manifest .godot/gfix44-proof/keyword-reward-fixture.json --case reward --index 0 --out user://gfix44-keyword-hover
```

**Native board-tile tooltip.** The probe opens the native stacked tooltip on mixed ground and at viewport edges, moves off the tile, and reopens the tooltip. It also covers the controller route. Output is under the isolated `user://probes/board_surfaces/`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-44 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --task-id gfix-44 --proof-contract tests/board_tile_tooltip_probe_contract.json --result-manifest .godot/gfix44-proof/board-tooltip-visual.json tests/board_tile_tooltip_probe.gd
```

## Chosen defaults and open issues

- **Chosen defaults.** An empty in-tree Label for the harness backdrop, first reward card (index `0`) for native inspection, and proof output paths.
- **Design placeholders.** None.
- **Host diagnostics.** Both headless baselines and after-runs emit `ERROR: Condition "ret != noErr" is true. Returning: ""` from macOS certificate loading. Card display and card legibility also emit `WARNING: ObjectDB instances leaked at exit (run with --verbose for details).` and `ERROR: 1 resources still in use at exit (run with --verbose for details).` before and after. Full-scene follow-up has the same ObjectDB warning before and after. The Python run could not update the Git-common-dir learned timing cache because it is read-only in this sandbox.
- **Extra audit attempt.** An initial card legibility invocation used an unrecognized `--sample-only` flag and entered the default catalog audit. It timed out at 300 seconds with exit 124. The release gate's actual `--regressions-only` command reproduced all six corresponding keyword errors and passed after the fix.
- **Other release-gate failures.** The supplied log also lists Warband Orders, pre-battle semantics, encounter analytics, element retrofit, BOS01 rule scene, glossary, board-tile tooltip content, guardian rules, and the main suite rollup. It also includes teardown messages from `_warm_grimoire_after_first_frame()` and `_refresh_controller_modal_after_layout()`. The local board-tile content check passed with the existing gfix-42 pins and still logged missing glossary definitions for `bramble` and `ice_pillar`. Those warnings and the remaining release-gate issues are outside this unit.
