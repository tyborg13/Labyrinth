# fel-11 · Exit presentation

## Reproduction

The initial headless run against the unchanged worktree reproduced all three defects in a generated two-door Umbral Snare. The sandbox has no macOS window-server access. Native reproduction and visual inspection are pending. The baseline capture command below reads the original scripts from `7ba6cacac36037ca11967a6205cb6562f18e54ae`, the pinned `codex/release` base.

1. **Sealed boundary.** After three production player/enemy rounds, the timed exit was sealed. The baseline still emitted gold fill, the exit pulse, and a controller chevron. The objective label builder included every exit, and the board used that label map for all three operations. The active-door builder also admitted the sealed door through map exit options. The dark body, violet threshold, and absence of a medallion, countdown, teal ring, and threshold icon already worked.
2. **Map.** The sealed destination reported `Show exit`. Activating the node closed the map and highlighted the sealed door. The panel gated the action on map availability and the objective type, so the seal changed neither its action nor its refresh signature.
3. **Win.** The unselected door emitted gold fill, pulse, a medallion, the threshold ring and icon, and a countdown chip from the first `VICTORY` frame through reward and escape. Reward and escape already narrowed the active doors, but the label, icon, threshold, and chip paint used the full combat objective. The live intro also submitted the board before the reward state became current.

## Acceptance

1. The sealed boundary door leaves the board's active set, label map, and icon map. The locked-door set keeps its body visible with the existing dark Umbra tint. Its threshold emits only the existing violet fill at 0.30 opacity. Neither countdown nor controller chevron is painted. Both open doors, the jailer after the seal, and the Sealbinder's kept-open exit matched baseline paint.
2. The section map refresh signature tracks open objective destinations. Its activation check and controller action use that set alongside the existing room availability. The sealed node is inspectable, and activation leaves the map open. The jailer still highlights its board door through the same action.
3. Board submission uses the pending escape's selected door at the first `VICTORY` frame, on stage refresh during the intro, and in reward and escape. The selected door keeps its marks until opening. The other door draws as a plain closed door without a medallion, fill, pulse, chip, or threshold markers. The witness verifies the pending escape retains the combat board and live continuation reaches the selected destination, `(18, -12)`.
4. All three ordinary Reach the Exit combat doors, all three room-mode doors, and the selected door's opening paint matched baseline. Game rules, copy, save formats, and analytics code were untouched.

## Files

- [run_scene.gd](../../scripts/run_scene.gd) filters the board inputs and passes the pending escape selection during board submission.
- [combat_board_view.gd](../../scripts/combat_board_view.gd) gates Snare-specific paint on the selected escape door.
- [section_map_panel.gd](../../scripts/section_map_panel.gd) uses open combat exits for map action availability.
- [fixtures.gd](fixtures.gd), [witness.gd](witness.gd), [native.sh](native.sh), and [proof_contract.json](proof_contract.json) define the fixture, observations, paired runner, and native proof requirements.

## Checks run

`tools/fel11/native.sh --dry-run` exited 0 for both takes. Its logs and sampled paint data are in `.godot/fel11-proof/dry.Px5jC5/`. The paired dry run creates zero PNGs.

```text
FEL11 BASE HEADLESS: 0 failures, 0 PNGs
FEL11 sealed map destination: Inspect
FEL11 sealed boundary: gold=false pulse=false chevron=false active=false violet=[(0.6039, 0.4863, 0.9412, 0.3)]
FEL11 VICTORY first frame alternative: gold=false pulse=false medallion=false threshold_fx=[] chip=
FEL11 reward alternative: gold=false pulse=false medallion=false threshold_fx=[] chip=
FEL11 escape alternative: gold=false pulse=false medallion=false threshold_fx=[] chip=
FEL11 continuation: door=(4, 0) destination=(18, -12) mode=treasure
FEL11 controls: 3 ordinary combat exits, 3 ordinary room exits
FEL11 BRANCH HEADLESS: 0 failures, 0 PNGs
```

Each Godot check ran headless through `tools/godot_task_runner.py --task-id fel-11 --stream`.

| Check | Result line |
| --- | --- |
| `tests/board_tile_tooltip_test.gd` | `BOARD TILE TOOLTIPS: PASS checks=233 failures=0` |
| `tests/board_tile_tooltip_route_test.gd` | `BOARD TILE TOOLTIP ROUTES: PASS (12 capture states; real X input; native popup layout; headless, no pixels)` |
| `tests/board_tile_tooltip_live_test.gd` | `BOARD TILE TOOLTIP LIVE: PASS (held mouse, idle controller, occupied tile, all mutation domains)` |
| `tests/section_map_flow_probe.gd -- --reach-exit-only` | `SECTION MAP REACH EXIT PROBE TEST RESULT: PASS` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 5.660s`, `OK` |
| `python3 tests/test_rules_text_lint.py` | `PASS: Rules text lint (16 existing hits)` |

## Proof for the design owner

Run either or both commands on a Mac with window-server access.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-11 && tools/fel11/native.sh --reproduce
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-11 && tools/fel11/native.sh
```

The runner uses `LABYRINTH_CEL_LOOK=all`, 1920×1080, and 100% UI scale. It focuses the map node through Godot and never moves the OS pointer. The map image records the focused destination and its action styling. The log records the action label and the witness attempts activation. The output directory is printed at startup under `.godot/fel11-proof/native.*/`. The pair command writes `base-` and `branch-` PNGs for `snare-open`, `snare-sealed`, `sealed-destination-map`, and `escape-reward`, along with each take's log and visual proof manifest.

## Chosen defaults

- The witness starts from the existing Snare inspection fixture, seed 83, Fire tier 2, with the fixture's 100 Health. It keeps two existing outgoing connections before generating combat, reveals their destination metadata for the map, and uses the unlimited proof-visibility setting. For the win, it sets up the hero one legal step before the jailer threshold and then uses the live movement and escape paths.
- The ordinary combat control uses the last legacy objective revision, 5, and the first Reach the Exit seed below 128 for the fixture room. Its three-connection layout also supplies the cleared room-mode control.
- The probe allows 10 seconds for readiness and three frames for view settling. Each windowed take has 180 seconds for script loading, captures, and the live transition sequences.

## TODO_DESIGN placeholders

None.

## Open issues

- Native captures and visual inspection are pending because the sandbox has no window-server access.
- Godot emitted the macOS certificate diagnostic in headless runs and reported one resource still in use at exit in both witness takes. The tooltip suite reported missing glossary definitions for `bramble` and `ice_pillar`. The listed checks exited successfully.
