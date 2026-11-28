# pol-85 D-pad repeat

## D-pad census

References in this table are to the starting revision `3124de009`. Ordinary Godot Control navigation follows the directional focus graph, including authored neighbors. A fresh press keeps that graph at region boundaries and wraps.

| Starting route | Screen and region | Repeat | Never repeat |
| --- | --- | --- | --- |
| `scripts/run_scene.gd:2799,2881,2903` | Combat hand and guided playable subset | Left/right through cards | Up to board, hand wrap |
| `scripts/run_scene.gd:3013` | Combat board and targeting candidates | Cardinal focus steps among tiles and targets | Off-board transfer to hand or HUD |
| `scripts/run_scene.gd:2729,3013` | Room board | Cardinal focus steps among doors and pickups | Activation, leaving the board |
| `scripts/labyrinth_map_view.gd:669,726` | Large map | Cardinal map cursor steps | Room activation and zoom commands |
| `scripts/section_map_panel.gd:472,1145,1189` | Section map | Door nodes, tab strip focus, legend items | Transfers between nodes, tabs, legend and actions, page activation |
| `scripts/main_menu.gd:318,355,1384` | Title | Menu buttons and demo links within their respective regions | Initial focus acquisition, links/menu transfer |
| `scripts/new_descent_panel.gd:125,290` | New descent | Native navigation within depth controls or footer buttons | Depth/footer transfer, depth and Begin activation |
| `scripts/settings_panel.gd:189,475,556,636,947,1079` | Settings | Rows, keycaps, volume sliders, demo links, confirmation buttons | Rebind capture, opening a popup or crossing into confirmation |
| `scripts/controller_option_navigation.gd:28,66` | Settings option popup | Up/down through selectable items | Selection, dismissal and wrap |
| `scripts/grimoire_panel.gd:376,815,876,976,1153` | Grimoire | Browse navigation and search result lists | Search editing and transfers between search, navigation, detail and Close |
| `scripts/chronicle_panel.gd:508,647,679` | Chronicle | Up/down through records, cardinal movement along detail tiles | Detail/record/Close transfers and bumper paging |
| `scripts/event_view.gd:409,436,470` | Event | Up/down through choices | Wrap, choice confirmation, result continuation |
| `scripts/heirloom_view.gd:92,114` | Heirloom | Left/right through cards | Card-to-Leave transitions and wrap |
| `scripts/opening_boon_overlay.gd:303,323` | Opening boon | Card row | Action/inspection transfers and card wrap |
| `scripts/scavenger_shop_view.gd:1577,1640` | Shops | Offers within shelves, pack grids, filters and card-navigation controls | Shelf/grid-to-actions transfer, mode/page activation, sale/purchase |
| `scripts/graftwright_view.gd:672,920` | Graftwright | Spatial focus within the current choice region | Region transfers, inspect and choice activation |
| `scripts/run_scene.gd:3604,11049,15479,15743,17229,29926,30517,32048` | Run GUI including Character, deck/piles, rewards, skill tree and pre-battle | Native focus within a list, grid or button group | Wrap, transfers to headers/actions, bumper tab switches, confirm |
| `scripts/skill_tree_view.gd:1347`, `scripts/pre_battle_view.gd:338`, `scripts/ember_hearth_presentation.gd:39`, `scripts/contextual_combat_prompt.gd:550` | Skill and decision panels | Native focus within nodes or choices | Node/action transfers and confirmation |
| `scripts/magic_purge_overlay.gd:466,489`, `scripts/magic_purge_confirmation.gd:159` | Purge | Card rows or confirmation buttons | Card/action transfers, dismissal and wrap |
| `scripts/run_end_recap_overlay.gd:508,881`, `scripts/demo_end_panel.gd:126`, `scripts/modal_menu_focus.gd:81` | Recap, demo end, pause menu | Native buttons within the current page or action group | Modal/screen changes and initial focus acquisition |
| `scripts/run_scene.gd:2513`, `scripts/movement_target_keyboard.gd:9` | Combat shortcut routing | Keyboard target navigation retains its own cadence | D-pad does not repeat keyboard-only aim rotation or targeting shortcuts |

## Acceptance

1. The census above covers native GUI focus graphs and the explicit D-pad routes. For ordered card groups, the repeat guard uses display order. For spatial controls and cursors, it uses the next existing focus edge or cursor endpoint.
2. The digital hold clock in `controller_axis_repeat.gd` uses the existing 0.40 s delay and 0.12 s interval. It sends marked D-pad presses through the owning viewport. The press stops at release, takeover, a focus/screen change, or an invalid next edge. Ordinary taps still use their original routes at the edges. RunScene advances the digital clock in its physics tick so it works when dialogue's idle processing is disabled.
3. The stick paths still use their existing axis handling and repeat cadence. Keyboard events retain their normal dispatch and echo. Board repeats call the existing cardinal candidate route with its existing target rules and geometry. The unit adds no assets, input bindings, settings, or rules text.

Risk tier is medium per the brief. Native inspection is the Steam Deck-family hand and Grimoire recording. The worktree stays uncommitted for the design owner.

## Commands

Run from the worktree root.

```bash
python3 tools/godot_task_runner.py --task-id pol-85 --stream -- godot --headless --path . --script tools/pol85/repeat_probe.gd
python3 tools/godot_task_runner.py --task-id pol-85 --stream -- godot --headless --path . --fixed-fps 60 --script tools/pol85/repeat_probe.gd -- --movie-check
python3 tools/godot_task_runner.py --task-id pol-85 --stream -- godot --headless --path . --script tests/controller_screen_sweep.gd -- --regressions-only --output-dir /private/tmp/labyrinth_codex/pol85-controller-regression
python3 tools/godot_task_runner.py --task-id pol-85 --timeout 600 --stream -- godot --headless --path . --script tests/controller_screen_sweep.gd -- --navigation-only --output-dir /private/tmp/labyrinth_codex/pol85-controller-sweep
python3 tools/godot_task_runner.py --task-id pol-85 --stream -- godot --headless --path . --script tests/combat_board_navigation_test.gd
python3 tools/godot_task_runner.py --task-id pol-85 --stream -- godot --headless --path . --script tests/suites/full_scene_navigation_program.gd
python3 tests/test_ui_identity_lint.py
python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir /private/tmp/labyrinth_codex/pol85-python-final
```

## Capture feedback 1

The new capture uses saved fight `04-s0-seed8-0--3_2-t5` from the fel-01 checkpoints. It follows the saved-run resume and witness checks used by fel-19/fel-22 and the checkpoint workflow in fel-20. Sealed Hall has five cards in hand and five enemies in its saved state. The seed-12 fight used by fel-22 has four cards in its saved hand. Each build checks the saved witness before filming and uses a separate runtime copy of the same checkpoint.

The Grimoire part keeps Central Waypoint and the original Shock entry. Both parts use viewport-only inputs. The hand holds right for 90 frames and the Grimoire holds down for 120 frames at 60 fps. The encoder cuts each segment at its own recorded frame boundary and places the release panel on the left and the branch panel on the right. Each panel is 960×540. PIL renders the labels below the room title, and the pair carries audio from the after take.

This round touches `tools/pol85/capture.sh`, `repeat_probe.gd`, `movie_probe.gd` and its UID, `pair.py`, and this report.

### Feedback 1 verification

```bash
python3 tools/godot_task_runner.py --task-id pol-85 --stream -- godot --headless --path . --script tools/pol85/repeat_probe.gd
bash tools/pol85/capture.sh --dry-run
```

```text
POL85 DPAD REPEAT PASS targets=179
POL85 CHECKPOINT before room=Sealed Hall cards=5 enemies=5
POL85 NATIVE hand before steps=1 expected=4
POL85 NATIVE grimoire before steps=1 expected=15
POL85 CHECKPOINT after room=Sealed Hall cards=5 enemies=5
POL85 NATIVE hand after steps=4 expected=4
POL85 NATIVE grimoire after steps=15 expected=15
POL85 TIMELINE PASS hand=135 grimoire=165 fps=60
POL85 DRY RUN PASS before=hand,grimoire after=hand,grimoire
```

The tested release worktree was at `e028832ed`. The two dry-run logs and timelines are under `/private/tmp/labyrinth_codex/pol85/dry.giAQix/`. The hold log is `/private/tmp/labyrinth_codex/pol85/feedback1-holds.log`. An offline encode using the old supplied recordings returned `POL85 NATIVE PAIR PASS 1920x540 with audio` under `/private/tmp/labyrinth_codex/pol85/pair-smoke.DLC7VE/`.

## Proof for the design owner

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-85 && bash tools/pol85/capture.sh \
  /Users/borgerding/workspace/Labyrinth.worktrees/release \
  /private/tmp/labyrinth_codex/pol85/sealed-hall-pair
```

The windowed command writes `pair.mp4` and the raw takes, timeline, stills, and visual manifest for each build. Release step-count mismatches are recorded and the take continues. Native Sealed Hall rendering and audio await an owner run with window-server access.

## Files changed

- Shared routing and clock in `scripts/controller_axis_repeat.gd`, `scripts/controller_gui_navigation.gd`, and `scripts/controller_option_navigation.gd`.
- Custom input routes in `scripts/run_scene.gd`, `scripts/chronicle_panel.gd`, `scripts/event_view.gd`, `scripts/heirloom_view.gd`, and `scripts/labyrinth_map_view.gd`.
- Native focus regions in `scripts/character_menu_view.gd`, `scripts/demo_end_panel.gd`, `scripts/graftwright_view.gd`, `scripts/grimoire_panel.gd`, `scripts/magic_purge_overlay.gd`, `scripts/main_menu.gd`, `scripts/new_descent_panel.gd`, `scripts/opening_boon_overlay.gd`, `scripts/pre_battle_view.gd`, `scripts/run_end_recap_overlay.gd`, `scripts/scavenger_shop_view.gd`, `scripts/section_map_panel.gd`, `scripts/settings_panel.gd`, and `scripts/skill_tree_view.gd`.
- `tools/pol85/repeat_probe.gd` and UID, `capture.sh`, `movie_godot.sh`, `proof_contract.json`, and this report.

## Chosen defaults

- The headless probe uses 10 ms ticks and the existing screen-sweep seed and fixtures. The supplemental ten-item popup tests the full seven-step cadence. The 50% volume start exposes seven increments in both directions. The handoff uses a stick sample of 0.80. The four-card Heirloom and unlocked Grimoire are proof-only fixtures.
- The combat board-to-hand fixture hides intervening HUD controls to expose the existing bottom-edge input path. The capture uses 60 fps, 30 settle frames per scene and 15 tail frames.
- The capture uses Godot MovieWriter and the existing local ffmpeg installation, with native Metal, H.264/AAC delivery, and the visual runner's image contract. The navigation sweep has a 600 s allowance for its full controller inventory.

`TODO_DESIGN` placeholders are empty.

## Initial implementation results

| Check | Result | Evidence |
| --- | --- | --- |
| Production-screen hold probe | `POL85 DPAD REPEAT PASS targets=179` | `/private/tmp/labyrinth_codex/pol85/headless-verified.log` |
| Fixed-frame capture rehearsal | `POL85 TARGET movie/hand dir=right steps=4 expected=4 PASS` and `POL85 TARGET movie/grimoire dir=down steps=15 expected=15 PASS` | `/private/tmp/labyrinth_codex/pol85/movie-final.log` |
| Controller regression sweep, including ControllerInputSuite | `REGRESSION HUD_REBUILD: PASS`, `REGRESSION ANALOG_VOLUME: PASS`, `REGRESSION ANALOG_SELECTION: PASS`, `CONTROLLER SCREEN SWEEP: PASS (0 findings)` | `/private/tmp/labyrinth_codex/pol85-controller-regression/regressions_after.json` |
| Full controller navigation sweep | `CONTROLLER SCREEN SWEEP: PASS (0 findings)` | `/private/tmp/labyrinth_codex/pol85-controller-sweep/sweep_after.json` |
| Board navigation | `COMBAT BOARD NAVIGATION TEST: PASS` | Godot task-runner console |
| Focused full-scene navigation program | `MAIN DOMAIN ASSERTIONS full_scene_navigation_program: 37` and `TEST RESULT: PASS` | `/private/tmp/labyrinth_codex/pol85/navigation-suite-final.log` |
| UI identity lint | `Ran 25 tests in 24.553s` and `OK` | Python console |
| Rules text lint within the Python default group | `PASS: Rules text lint (16 existing hits)` | `/private/tmp/labyrinth_codex/pol85/python-default.log` |
| Python default group | `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 175.778s`, `FAILED (failures=5, errors=1)` | `/private/tmp/labyrinth_codex/pol85/python-default.log` and `/private/tmp/labyrinth_codex/pol85-python-final/summary.json` |

The hold probe checks the expected destination at every 10 ms tick, including the press, the first repeat at 0.40 s, the 0.12 s intervals through 1.00 s, and release. It includes held region transfers, wrap cases, shorter routes, direction takeover, stick takeover, focus loss, modal reset, and Chronicle keyboard echo. The fixed-frame rehearsal also checks the clocks through the engine's normal frame callbacks.

## Open issues

- The focused full-scene navigation program exited zero after an ObjectDB leak warning at engine shutdown.
- Native rendering, audio, and the MP4 artifact await the owner command above.
- The Python default group hit 15–30 s Godot child timeouts in `test_program_suite_runner` and `test_approved_content_manifest`. The cancellation fixture in `test_godot_task_runner` reported `AssertionError: False is not true : Child did not start`. The runner's learned-timing write also hit the sandbox's read-only Git metadata. Existing assertions stayed intact. Baseline status for those failures was unverified.
- `git show codex/fel-18:tools/fel18/result.md` reported the path missing from the ref. The census report was present and readable in the existing fel-18 worktree.
- `parallel_task.py status` reported empty acceptance, proof, and inspection fields. The brief above is the implementation contract. Task metadata is owned by the design owner.
