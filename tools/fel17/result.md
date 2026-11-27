# fel-17 · Combat Objective pop-up removal

Baseline `codex/fel-08` at `f51ec65312010f94e09e229d452471c85c65e3af`. Risk tier low. The three-case native comparison is the inspection proof.

## Acceptance criteria

1. The combat Objective has empty tooltip text, no custom tooltip builder, and explicit `FOCUS_NONE`. The fel-08 witness sends viewport mouse motion to the panel and observes no embedded tooltip. The fel-17 dry run verifies one pop-up before and zero after in the three combat cases. See focus order below. [HUD](../../scripts/combat_objective_hud.gd#L60) · [Witness](../fel08/objective_witness.gd#L77)
2. The existing icon, title, live detail, layout, animation, fade, and hover cursor still come from the same code. The settled panel uses `MOUSE_FILTER_STOP`. The hand-flow check exercised the intro and settled widget. The dry run matched title, live detail, and panel bounds in all three fights. [HUD setup](../../scripts/combat_objective_hud.gd#L85) · [Hand flow](../../tests/card_draw_hand_flow_test.gd#L384)
3. The audit below records the old copy and where its information can be read during combat. It introduces no new wording.
4. The existing suite and combat probes now check for absence. The pre-battle heading assertions in Snare and BRS01 continue to exercise the pre-battle tooltip. No new test program or suite was added. [Snare](../../tests/snare_probe.gd#L84) · [BRS01](../../tests/brs01_probe.gd#L164)

## Focus order

| Input | Before, `codex/fel-08` | After, `codex/fel-17` |
| --- | --- | --- |
| Keyboard | The active combat controls follow the existing Godot focus traversal for the current state. The Objective `PanelContainer` uses default `FOCUS_NONE`. | The same traversal skips the Objective, now with explicit `FOCUS_NONE`. |
| Controller | Spatial navigation chooses among board tiles, active commands, and eligible HUD controls. The normal HUD candidate list is contextual actions, Map, Loadout, Grimoire, Menu, visible piles and Pass, turn-order portraits and Details, then relic controls. | The same spatial navigation and candidate order apply. The Objective is absent from both lists. |

The pre-battle heading is a separate focusable control. Its keyboard and controller tooltip still belongs to that heading. [Combat controller candidates](../../scripts/run_scene.gd#L3132) · [HUD candidate order](../../scripts/run_scene.gd#L3218) · [Pre-battle heading](../../scripts/pre_battle_objective_heading.gd#L9)

## Information audit

The baseline HUD used `hud_title_for_objective()` for the popup heading and `description_for_objective(objective, false)` for the body. Thus the combat tooltip omitted both Snare pressure and Warband Order. The Snare reward line was added by the pre-battle heading. The in-combat Map overlay is listed separately where it offers matching or equivalent copy. Standard map revisions 6 and later describe ordinary combat as Defeat All. Older revisions can show a current ordinary room's resolved objective body, including Reach Exit, generic leader, or saved Survive. [Resolvers](../../scripts/combat_objective_rules.gd#L254) · [Map descriptions](../../scripts/section_map_panel.gd#L986) · [Pre-battle heading builder](../../scripts/pre_battle_view.gd#L233)

| Combat case | Pop-up heading on `codex/fel-08` | Pop-up sentence on `codex/fel-08` | Where the sentence's information can be read during combat |
| --- | --- | --- | --- |
| Kill All, including onboarding and an escaped Hoarder's remaining fight | `DEFEAT ALL ENEMIES` | `Defeat each enemy.` | The permanent heading and live enemy count give the goal. Ordinary combat room previews or the combat legend in the Map can show the exact sentence. The Hoarder room preview remains the special-room copy after the switch, so its permanent heading and count are the applicable goal. |
| Reach Exit, one | `REACH THE EXIT` | `Reach a marked tile to escape.` | The panel says `Reach the marked tile`. The exit door pop-up says `Reach the marked tile in front to escape.` The threshold pop-up says `Reach this tile to clear the encounter.` An older ordinary-room Map preview can repeat the exact sentence. |
| Reach Exit, several | `REACH THE EXIT` | `Reach a marked tile to escape.` | The panel says `Reach any of 2 marked tiles` or uses the current count. Each visible eligible door or threshold supplies the same local instructions as the single-exit case. An older ordinary-room Map preview can repeat the exact sentence. |
| Umbral Snare | `REACH THE EXIT` | `Reach a marked tile to escape.` | The Objective count and the open door and threshold pop-ups give the route. The Sealbinder intent or seal chip gives the door timer, how to keep a door open, and the reward per open door. The Battlefield panel gives the separate pressure rule. The special-room Map preview uses `The doors are sealing. Get out before they close.` |
| Generic Survive, supported in saved encounters | `SURVIVE` | `Survive until the marked time.` | The Objective title and `Dawn in N` display the goal and live time, plus reinforcement timing. An older ordinary-room Map preview can repeat the exact sentence when it carries the saved objective. |
| Last Light | `SURVIVE UNTIL DAWN` | `Survive until dawn.` | The Objective heading gives the same instruction and the live line counts down to dawn. The Map preview also says `Survive until dawn in the dark. Keep the braziers lit.` The Battlefield panel gives the separate Shadowstep rule. |
| Generic leader, including an ordinary leader with a name in the live line | `DEFEAT THE LEADER` | `Defeat the marked leader.` | The permanent title plus the visible leader's name and Health and the board's gold leader crest identify the target. An older ordinary-room Map preview can repeat the exact sentence. |
| Generic leader, follower outcome | `DEFEAT THE LEADER` | `The rest flee.` | The Objective, Battlefield and board badges give no advance instruction for this outcome. The older ordinary-room Map preview can repeat the exact sentence. |
| Warband | `DEFEAT THE THORNMOTHER`, `DEFEAT THE SLAGMASTER`, `DEFEAT THE STORMCALLER`, `DEFEAT THE RIME ORACLE`, `DEFEAT THE DYNAMO`, or `DEFEAT THE HOLLOW PRIOR` | `Defeat the captain to make each follower flee.` | The permanent title and the captain's board crest identify whom to defeat. The Battlefield panel gives the captain's Order, and Command tells about the damage bonus. The Map's special-room preview says `Kill the captain and the rest flee.` During the fight, the followers' flight and `The warband breaks!` follow the defeat. |
| Ember Hoarder, at large | `DEFEAT THE HOARDER` | `Catch the Hoarder before it slips away.` | The Objective says `Before it escapes` beside Health. The Slip Away Battlefield panel states `The Hoarder slips away with its hoard after your 4th turn.` or uses `5th` at tier 1. The Map preview says `Catch the Ember Hoarder before it slips away with its hoard.` |
| Guardian | `DEFEAT THE ASHEN REAVER`, `DEFEAT THE RIMEJAW`, `DEFEAT THE STORM CANTOR`, `DEFEAT THE GALLOWS ROC`, `DEFEAT THE CRAGHIDE`, or `DEFEAT THE LAST LAMPLIGHTER` | Heading only | The permanent title names the Guardian. The live line gives Health when visible. |
| Dragon | `DEFEAT THAROKH`, `DEFEAT VYRAKETH`, `DEFEAT VAELORYX`, `DEFEAT ISKALDRA`, `DEFEAT NOCTYRAX`, or `DEFEAT ZEKARION` | Heading only | The permanent title names the dragon and the live line gives Health when visible. |
| Authored named-leader override, supported by the resolver | The authored heading, rendered uppercase | The value of `objective_description`, when present. The suite fixture supplies `An authored objective sentence.` | No stock encounter supplies this field for a non-special named leader. Arbitrary authored body copy had no general destination on the combat board. The test sentence is fixture-only. |

Audit sources. [Live Objective detail](../../scripts/combat_objective_hud.gd#L512) · [Exit and door copy](../../scripts/board_tile_tooltip.gd#L60) · [Threshold and leader markers](../../scripts/combat_board_view.gd#L8554) · [Leader crest](../../scripts/combat_board_view.gd#L10800) · [Seal intent](../../scripts/snare_room_rules.gd#L135) · [Warband and special-room copy](../../data/special_encounters.json#L29) · [Hoarder switch and timer](../../scripts/hoarder_room_rules.gd#L120) · [Guardian and dragon names](../../data/enemies.json#L940)

**Sentences with no verbatim replacement on the live combat screen.** `Defeat each enemy.`, `Reach a marked tile to escape.`, `Survive until the marked time.`, `Survive until dawn.`, `Defeat the marked leader.`, `The rest flee.`, `Defeat the captain to make each follower flee.`, and `Catch the Hoarder before it slips away.` The exact Map coverage is marked in the table. Including the overlay, the Warband and Hoarder sentences still use different wording, Last Light repeats its instruction as a heading, and Snare still uses the alternate exit wording. The generic leader follower outcome has no advance equivalent on the combat board. Warband has an advance equivalent in the special-room Map preview, outside the board view.

## Changed assertions and probe expectations

| File and line | Before | After |
| --- | --- | --- |
| [combat_objective_suite.gd 338 → 337](../../tests/suites/combat_objective_suite.gd#L337) | `hud.tooltip_text == dragon_title` | `hud.tooltip_text.is_empty() and hud.focus_mode == Control.FOCUS_NONE` |
| [combat_objective_suite.gd 341 → 340](../../tests/suites/combat_objective_suite.gd#L340) | `hud.tooltip_text == dragon_title + "\nAn authored objective sentence."` | `hud.tooltip_text.is_empty() and hud.focus_mode == Control.FOCUS_NONE` even with the authored description present. |
| [card_draw_hand_flow_test.gd 393](../../tests/card_draw_hand_flow_test.gd#L393) | `objective_hud.mouse_filter == Control.MOUSE_FILTER_STOP` under the old tooltip interaction description. | Keeps that condition and adds `objective_hud.tooltip_text.is_empty()` and `objective_hud.focus_mode == Control.FOCUS_NONE`. |
| [objective_witness.gd 88–90](../fel08/objective_witness.gd#L88) | The combat hover text's second line was `Reach a marked tile to escape.` | Tooltip text is empty, `focus_mode` is `FOCUS_NONE`, and the HUD is absent from controller header candidates. |
| [objective_witness.gd 105–108](../fel08/objective_witness.gd#L105) | The hovered HUD owned an inset popup with `REACH THE EXIT` and the objective sentence. | The same viewport hover reaches the HUD without opening a visible `TooltipPanel` window. |
| [objective_witness.gd 121–123 and 129–132](../fel08/objective_witness.gd#L121) | Six representative combat HUDs built inset popups with the exact expected title and body. | The HUD title checks remain. Each HUD must have empty tooltip text and `FOCUS_NONE`. |
| [PLA01 capture.gd 179–181](../pla01/capture.gd#L179) | The `warband_objective` shot manufactured a pinned panel from `hud.tooltip_text`. | The existing shot shows the combat HUD without a fabricated panel and records a failure if tooltip text or focus returns. |

## Proof results

| Check | Observed result |
| --- | --- |
| `tests/int11_integration_test.gd`, the existing runner for `CombatObjectiveSuite` | `INT11 INTEGRATION: PASS (407 checks; 0 failures)` |
| `tests/card_draw_hand_flow_test.gd` | `CARD DRAW HAND FLOW TEST RESULT: PASS` |
| `tools/fel08/witness.gd` including `objective_witness.gd` | `FEL08 DOOR WITNESS PASS combat=7 room=1 threshold=unchanged`<br>`FEL08 OBJECTIVE NO POPUP exits=1 hover=true focus=none`<br>`FEL08 OBJECTIVE NO POPUP exits=2 hover=true focus=none`<br>`FEL08 OBJECTIVE WITNESS PASS status_counts=1,2 fresh=true continued=true`<br>`FEL08 DRY RUN PASS pillars=2 controls=2` · [Runner log](captures/witness.vwVJev/runner.log) |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 4.979s`<br>`OK` |
| `python3 tests/test_rules_text_lint.py` | `Ran 3 tests in 0.063s`<br>`OK`<br>`PASS: Rules text lint (16 existing hits)` |
| `tests/brs01_probe.gd -- --check-only` | `BRS01 PROBE CONTRACT: PASS (25 objective cases; 1920x1080; 100% UI scale)`<br>`EN01 PROBE HEADLESS CONTRACT RESULT: PASS` |
| `tests/brs01_probe.gd -- --hover-check-only` | `BRS02 TOOLTIP ROUTING RESULT: FAIL (4 failures)` on both this branch and `codex/fel-08`. [Baseline log](captures/brs01-before.log) · [Branch log](captures/brs01-after.log) |
| `bash tools/fel17/native.sh --dry-run` | `FEL17 PREPARE PASS fixtures=3`<br>`FEL08 BA DRY PASS cases=3` on both sides<br>`FEL17 CASE PASS one-exit before=1 after=0 title_detail_bounds=matched`<br>`FEL17 CASE PASS two-exits before=1 after=0 title_detail_bounds=matched`<br>`FEL17 CASE PASS warband before=1 after=0 title_detail_bounds=matched`<br>`FEL17 DRY PASS cases=3` · [Before log](captures/dry.dmZZWx/release/runner.log) · [After log](captures/dry.dmZZWx/branch/runner.log) |
| Pair compositor, using an archived 1920×1080 frame as stand-in input | `FEL17 COMPOSITOR SMOKE PASS pairs=3 sheet=1280x1302 archived_inputs=true` |
| `--check-only --script tools/pla01/capture.gd` | Godot parser check exited 0. |

BRS01's identical baseline and branch failures are `Exact Hoarder pre-battle heading`, `Hoarder heading tooltip uses full title`, `Actual hover panel shows Burst trait`, and `Native Capacitor panel shows the approved numeric move rows`. The Snare probe requires a native renderer at startup. Hand flow exited 0 after printing an ObjectDB leak warning and `ERROR: 2 resources still in use at exit`. The full suites are reserved for merge.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-17 && bash tools/fel17/native.sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-17 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --task-id fel-17 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 tests/snare_probe.gd -- --pre-battle-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-17 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py --task-id fel-17 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 tests/brs01_probe.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-17 && LABYRINTH_CEL_LOOK=all PLA01_OUT="$PWD/tools/fel17/captures/pla01.$(date +%s)" python3 tools/visual_probe_runner.py --task-id fel-17 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 tools/pla01/capture.gd
```

The native wrapper archives `codex/fel-08` into a temporary project and uses this worktree's prepared import cache and cel variants for that project. It writes three original 1920×1080 frames per side in `tools/fel17/captures/native.*/{release,branch}/`, three matched `*-pair.png` crops and `contact-sheet.png`. The production pointer route uses synthetic viewport mouse motion, held at the panel for 1.0 s without moving the OS pointer. Windowed captures and visual inspection are pending because the sandbox has no macOS window-server access.

## Chosen defaults

- The one-exit case reuses the fel-08 Bleak Passage save. The two-exit case uses the fel-08 `first_seal` Wildfire Snare with its existing proof visibility bonus. The Warband case uses the repository fixture's default air, tier 2 fight against the Stormcaller.
- The wrapper inherits the fel-08 capture timeout of 240 seconds and its board-settle and viewport-pointer placement. The proof compares bounds within 0.25 pixels to allow for float rounding.
- The contact sheet stacks the three fel-08-style matched crops vertically in case order.

**TODO_DESIGN placeholders** · None.

**Open issues** · The owner still needs to inspect the native comparison and decide whether to surface the audited copy. BRS01's four existing hover-routing failures remain. All changes are uncommitted.
