# pol-78 · Pass on the first combat frame

Candidate 7 already held the three docks as the hand shrank. Normal and Reach the Exit fights still showed Pass 106 px left of its settled position on the first visible frame after Start. The Ashen Reaver fight had no jump. After the fix, all three fights held their full-hand rects from the first visible frame through the opening deal, every hand size down to zero, and the next turn's deal.

## Measurement

The probe used the production Start, card selection, confirmation and Pass handlers in an exact 1920×1080 SubViewport at 100% UI scale. Each fixture starts with five cards. Five separate plays empty the hand, then Pass triggers the next turn's natural two-card deal. Coordinates below are `(x, y, width, height)` in screen pixels, rounded to two decimals. Repeated rows are grouped. Empty banked cells indicate the one-line Card Plays treatment.

| Fight | Sample, hand size | Pass | Card Plays plaque | Count | Banked | Movement | Objective dock |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Normal | First visible Pass, before | (1532, 870, 270, 100) | — | — | — | — | — |
| Normal | First visible Pass, after | (1638, 870, 270, 100) | — | — | — | — | — |
| Normal | Rest at 5, 4, 3, 2, 1, 0. Opening mid-deal (5) and turn 2 mid-deal and rest (2). Both runs. | (1638, 870, 270, 100) | (24, 725.77, 228, 58) | (74, 725.77, 166, 58) | — | (24, 791.77, 228, 58) | (24, 647.77, 350, 70) |
| Objective | First visible Pass, before | (1532, 870, 270, 100) | — | — | — | — | — |
| Objective | First visible Pass, after | (1638, 870, 270, 100) | — | — | — | — | — |
| Objective | Rest at 5, 4, 3, 2, 1, 0. Opening mid-deal (5) and turn 2 mid-deal and rest (2). Both runs. | (1638, 870, 270, 100) | (24, 713.98, 228, 58) | (74, 713.98, 166, 58) | — | (24, 779.98, 228, 58) | (24, 635.98, 350, 70) |
| Guardian | First visible Pass, both runs | (1638, 870, 270, 100) | — | — | — | — | — |
| Guardian | Rest at 5, 4, 3, 2, 1, 0. Opening mid-deal (5) and turn 2 mid-deal and rest (2). Both runs. | (1638, 870, 270, 100) | (24, 714.68, 228, 58) | (74, 718.68, 166, 25) | (74, 745.68, 166, 20) | (24, 780.68, 228, 58) | (24, 636.68, 381, 70) |

The first visible Pass precedes the left dock's first paint. On that first paint, both counters and the dock home already match their full-hand rects in each fight. The JSON also records the Objective card's existing intro as it travels to the dock. Maximum drift compares the dock home and the other visible controls on every sampled frame, and the Objective card itself after its intro.

## Cause and fix

The old hand-size dependency came from reading the live resting fan in `a0dfb145c:scripts/run_scene.gd:5039` and `:10243`. The existing envelope in `scripts/combat_hud_layout.gd:30` and framed home in `scripts/run_scene.gd:11475` already address that source of drift. The remaining jump came from `647b49092:scripts/combat_hud_right_column.gd:44`, where the first placement used the union of the pile children before the discard child had received its horizontal position.

- `scripts/run_scene.gd:7623–7624, 7626–7630, 7632, 7636` share the existing pile dock calculation as a rect. Pile placement takes its size and position directly from that rect.
- `scripts/combat_hud_right_column.gd:44–46` reads that same destination rect before the child sort. Pass lands right-aligned, 10 px above the piles, in the existing 270×100 hit rect. The rail uses the same Pass top.
- `tools/pol78/measure.gd`, `native.sh`, and `proof.json` record the fight states, check the 1 px tolerance on the after phase, and capture nine validated frames per phase.

## Acceptance

1. Pass and the left dock retain the observed full-hand rects. The three cases each held those rects at all six settled hand sizes and through both deals. The hand continues to use the existing fan and fit code.
2. The first visible Pass is already at the settled rect. The layout writes its position synchronously. The Objective intro and its destination use the existing presentation.
3. The recorded card, badge and Objective home rects show no intersections introduced by the fix. Deal cards pass over the Pass rect in both runs as they leave the draw pile. An additional Zekarion check compared the live boss bar `(570, 18, 780, 134)` with Pass, both meters and the Objective. All four cleared it. No design placeholder applies.
4. The production edits only place the existing controls. The current HUD button and forecast checks passed, including the keyboard Pass shortcut and controller HUD state.

## Chosen defaults

- The inspection builder's seed 7262026 and Ashen Reaver fixture, with seed 3 for the existing Reach the Exit route.
- An all-Brace probe hand sized to the encounter's five-card maximum and enough ordinary plays to empty it. The Guardian carries one banked play under Measured Breath to expose the second counter. The next deal uses the encounter's ordinary draw count.
- Pointer parked centrally at (960, 540), three settled frames per hand sample, a 30-second readiness limit, and a 180-second native runner process limit. Headless advances draw-frame callbacks using process frames. Native uses the real draw callbacks.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-78 && /private/tmp/labyrinth_codex/pol-78/native.sh
```

This runs the visual probe runner with `LABYRINTH_CEL_LOOK=all`, the macOS display driver, and CoreAudio. The before phase stages the exact candidate commit and its existing generated assets and imports. Each phase prints absolute paths for `normal_{max,3,1,0}.png`, `objective_{max,3,1,0}.png`, and `guardian_max.png`, with its own `rects.json` and `manifest.json` under the printed output directory. Windowed capture and visual inspection remain pending because the implementation sandbox has no macOS window-server access.

## Headless results

Before and after frame tables:

- `/private/tmp/labyrinth_codex/pol-78/headless.Ln9oBn/before/rects.json`
- `/private/tmp/labyrinth_codex/pol-78/headless.Ln9oBn/after/rects.json`

```text
POL-78 normal maximum dock drift: 106.000 px
POL-78 objective maximum dock drift: 106.000 px
POL-78 guardian maximum dock drift: 0.000 px
POL-78 HEADLESS PASS — /private/tmp/labyrinth_codex/pol-78/headless.Ln9oBn/before/rects.json
POL-78 normal maximum dock drift: 0.000 px
POL-78 objective maximum dock drift: 0.000 px
POL-78 guardian maximum dock drift: 0.000 px
POL-78 HEADLESS PASS — /private/tmp/labyrinth_codex/pol-78/headless.Ln9oBn/after/rects.json
POL-78 NATIVE DRY RUN PASS — /private/tmp/labyrinth_codex/pol-78/headless.Ln9oBn
POL-78 RECT COMPARISON: PASS
POL-78 BOSS CLEARANCE: PASS
COMBAT HUD BUTTONS TEST: PASS
COMBAT HUD BADGES TEST: PASS
PTF08 FOCUSED RESULT: PASS (761 assertions, 0 failures)
```

- `python3 tests/test_ui_identity_lint.py` reported `Ran 25 tests in 6.116s` and `OK`.
- The Python default group reported `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 29.706s` and `OK`. The sandbox blocked writing the optional timing cache.
- Godot logged the macOS certificate lookup diagnostic. The forecast suite and disposable boss probe also logged shutdown leak diagnostics. Each listed check exited successfully.
