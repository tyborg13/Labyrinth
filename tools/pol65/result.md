# pol-65 boss health header

## Feedback 1

1. At 1280×800, the title hides in the five formerly blocked fights. Their refitted overlays leave 24 px on each side. The debug boss overlay is 673 px wide and the other four are 612 px wide. Every boss name fits on one line at its existing size.
2. The fit decision includes the large title's intrinsic text width even while the label is hidden. The 120-frame idle samples found zero layout calls.
3. The Depth and Umbra lines stay visible and move up by 44 px. The relic slot follows its existing anchor.
4. The same run restored the title on resize and on the dragon reward screen after winning the fight in all five cases. Terminal recap screens retain their existing HUD visibility policy.
5. All five names fit after the title hides. The board fit area, rendered rect, origin and tile width match round 0 for all seven fights, including when compared under each budget capture order.

Vaeloryx and Noctyrax retain their 1280×800 round 0 geometry and titles. All fourteen 1920×1080 rows retain their round 0 geometry and titles. The map button remains governed by section-map availability. The debug `boss` fixture has no section map and shows three top-right buttons. The six dragon fixtures show four.

## Checks

- `POL-65 FEEDBACK CHECK: PASS (21 layouts, 7 board matches in both capture orders, 5 restores and reward exits, 0 calls over 1680 idle frames)`. [Feedback measurements](/private/tmp/labyrinth_codex/pol-65/feedback1/final/rects.json) · [Round 0 deck measurements](/private/tmp/labyrinth_codex/pol-65/feedback1/round0/rects.json) · [Round 0 budget and resize baseline](/private/tmp/labyrinth_codex/pol-65/feedback1/resize-baseline/rects.json)
- `POL-65 RECT REPORT: PASS (21 original-baseline comparisons)`. [Original baseline and round 0 rects](/private/tmp/labyrinth_codex/pol-65/census.D5fTnp/measurements/rects.json)
- `BOSS HEALTH PREVIEW TEST: PASS (0 failures)`. [Log](/private/tmp/labyrinth_codex/pol-65/feedback1/boss_health_preview.log)
- `COMBAT HUD BUTTONS TEST: PASS`. [Log](/private/tmp/labyrinth_codex/pol-65/feedback1/combat_hud_buttons.log)
- `COMBAT HUD BADGES TEST: PASS`. [Log](/private/tmp/labyrinth_codex/pol-65/feedback1/combat_hud_badges.log)
- `POL-65 FOCUSED BOSS AND BOARD HUD: PASS (1014 assertions, 0 failures)`. [Log](/private/tmp/labyrinth_codex/pol-65/feedback1/focused-hud.log)
- UI identity lint reported `Ran 25 tests in 6.989s` and `OK`. [Log](/private/tmp/labyrinth_codex/pol-65/feedback1/ui-identity.log)
- `TYPED ARRAY SCAN: 2 scripts; 0 new; 0 pre-existing`. [Log](/private/tmp/labyrinth_codex/pol-65/feedback1/typed-array.log)

## Proof for the design owner

Use the existing native launcher from a desktop session. It runs the real renderer before and after at 1280×800 and after at 1920×1080. It prints the PNG folders and writes exact-size proof manifests. Feedback 1 was verified headless and still needs native capture.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-65 && /private/tmp/labyrinth_codex/pol-65/native.sh
```

To repeat the headless layout, resize and reward checks against the existing census fixtures:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-65 && python3 tools/pol65/measure.py /private/tmp/labyrinth_codex/pol-65/census.BQfun6 --feedback-output /private/tmp/labyrinth_codex/pol-65/feedback1-owner
```

The headless restore probe resolves the encounter on an isolated copy of the live checkpoint by setting enemy HP to zero. It uses the game's combat completion and reward presentation. The reward check waits up to the census input deadline of 12 seconds for two stable title rects with the reward panel visible. No `TODO_DESIGN_*` placeholders.

## Before and after rects

All edges and rects are in output pixels. Each pair reads before → after. Rects use `(x, y, width, height)` and display up to two decimal places. The desktop tables retain the original `scn-02` comparison at `a51185609`.

### 1280×800 · 100%

The before values are from round 0. The free span leaves 24 output px on each side. Needed width includes the one-line name and 18 px of padding on each side.

| Shot | Title hidden | Title edge | Readout left | First button left | Free span | Needed | Overlay rect | Name rect | Frame rect |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `boss` | Yes | 381 → 137 | 858 | 1050 | 429 → 673 | 481 | (290, 18, 700, 134) → (161, 18, 673, 134) | (308, 18, 664, 36) → (179, 18, 637, 36) | (290, 28, 700, 80.77) → (161, 28, 673, 77.65) |
| `dragon_tharokh` | Yes | 399 → 137 | 797 | 974 | 350 → 612 | 407 | (290, 18, 700, 134) → (161, 18, 612, 134) | (308, 18, 664, 36) → (179, 18, 576, 36) | (290, 28, 700, 80.77) → (161, 28, 612, 70.62) |
| `dragon_vyraketh` | Yes | 330 → 137 | 797 | 974 | 419 → 612 | 452 | (290, 18, 700, 134) → (161, 18, 612, 134) | (308, 18, 664, 36) → (179, 18, 576, 36) | (290, 28, 700, 80.77) → (161, 28, 612, 70.62) |
| `dragon_vaeloryx` | No | 298 → 298 | 797 | 974 | 451 → 451 | 420 | (322, 18, 451, 134) → (322, 18, 451, 134) | (340, 18, 415, 36) → (340, 18, 415, 36) | (322, 28, 451, 52.04) → (322, 28, 451, 52.04) |
| `dragon_iskaldra` | Yes | 445 → 137 | 797 | 974 | 304 → 612 | 418 | (290, 18, 700, 134) → (161, 18, 612, 134) | (308, 18, 664, 36) → (179, 18, 576, 36) | (290, 28, 700, 80.77) → (161, 28, 612, 70.62) |
| `dragon_zekarion` | Yes | 381 → 137 | 797 | 974 | 368 → 612 | 481 | (290, 18, 700, 134) → (161, 18, 612, 134) | (308, 18, 664, 36) → (179, 18, 576, 36) | (290, 28, 700, 80.77) → (161, 28, 612, 70.62) |
| `dragon_noctyrax` | No | 294 → 294 | 793 | 974 | 451 → 451 | 420 | (318, 18, 451, 134) → (318, 18, 451, 134) | (336, 18, 415, 36) → (336, 18, 415, 36) | (318, 28, 451, 52.04) → (318, 28, 451, 52.04) |

### Title stack and relic slot at 1280×800

The hidden room title retains its last rect, shown here for reference. The Depth and Umbra lines remain visible and each moves up 44 px. The relic slot follows its existing anchor by the same amount.

| Shot | RoomTitle (visible → hidden) | RoomSubtitle | UmbraSubtitle | Relic slot |
| --- | --- | --- | --- | --- |
| `boss` | (10, 10, 554, 40) → (10, 10, 371, 40) | (10, 54, 554, 20) → (10, 10, 554, 20) | (10, 78, 554, 22) → (10, 34, 554, 22) | (10, 104, 371, 52) → (10, 60, 371, 52) |
| `dragon_tharokh` | (10, 10, 514, 40) → (10, 10, 389, 40) | (10, 54, 514, 20) → (10, 10, 514, 20) | (10, 78, 514, 22) → (10, 34, 514, 22) | (10, 104, 389, 52) → (10, 60, 389, 52) |
| `dragon_vyraketh` | (10, 10, 514, 40) → (10, 10, 320, 40) | (10, 54, 514, 20) → (10, 10, 514, 20) | (10, 78, 514, 22) → (10, 34, 514, 22) | (10, 104, 320, 52) → (10, 60, 320, 52) |
| `dragon_iskaldra` | (10, 10, 514, 40) → (10, 10, 435, 40) | (10, 54, 514, 20) → (10, 10, 514, 20) | (10, 78, 514, 22) → (10, 34, 514, 22) | (10, 104, 435, 52) → (10, 60, 435, 52) |
| `dragon_zekarion` | (10, 10, 514, 40) → (10, 10, 371, 40) | (10, 54, 514, 20) → (10, 10, 514, 20) | (10, 78, 514, 22) → (10, 34, 514, 22) | (10, 104, 371, 52) → (10, 60, 371, 52) |

### Board at 1280×800

The fit rect, rendered rect, origin and tile width match exactly in all seven fights. The probe also froze the budget with the boss header already presented and again before presenting the boss name. Comparing the same capture order between round 0 and this round produced exact board geometry matches in all seven.

| Shot | Fit rect | Rendered board rect | Board origin | Tile width |
| --- | --- | --- | --- | --- |
| `boss` | (0, 0, 1280, 734.68) → (0, 0, 1280, 734.68) | (328.07, 167.46, 623.87, 375) → (328.07, 167.46, 623.87, 375) | (640, 208.24) → (640, 208.24) | 89.12 → 89.12 |
| `dragon_tharokh` | (0, 0, 1280, 734.68) → (0, 0, 1280, 734.68) | (308.02, 165.55, 663.95, 399.09) → (308.02, 165.55, 663.95, 399.09) | (640, 208.95) → (640, 208.95) | 94.85 → 94.85 |
| `dragon_vyraketh` | (0, 0, 1280, 734.68) → (0, 0, 1280, 734.68) | (319.94, 166.56, 640.13, 384.77) → (319.94, 166.56, 640.13, 384.77) | (640, 208.40) → (640, 208.40) | 91.45 → 91.45 |
| `dragon_vaeloryx` | (0, 0, 1280, 734.68) → (0, 0, 1280, 734.68) | (321.05, 181.90, 637.90, 383.43) → (321.05, 181.90, 637.90, 383.43) | (640, 223.60) → (640, 223.60) | 91.13 → 91.13 |
| `dragon_iskaldra` | (0, 0, 1280, 734.68) → (0, 0, 1280, 734.68) | (306.87, 165.11, 666.26, 400.48) → (306.87, 165.11, 666.26, 400.48) | (640, 208.66) → (640, 208.66) | 95.18 → 95.18 |
| `dragon_zekarion` | (0, 0, 1280, 734.68) → (0, 0, 1280, 734.68) | (328.07, 167.46, 623.87, 375) → (328.07, 167.46, 623.87, 375) | (640, 208.24) → (640, 208.24) | 89.12 → 89.12 |
| `dragon_noctyrax` | (0, 0, 1280, 734.68) → (0, 0, 1280, 734.68) | (321.48, 169.66, 637.04, 382.92) → (321.48, 169.66, 637.04, 382.92) | (640, 211.31) → (640, 211.31) | 91.01 → 91.01 |

### Restoration on the same run

Each formerly blocked fight was resized to 1920×1080 and back to 1280×800. The title returned at desktop size, and the overlay, name and frame rects matched the fresh desktop baseline. The full measured header after resizing also matched the equivalent round 0 resize. At 1280×800 the title hid again. The probe resolved a victory through the saved combat checkpoint flow and observed the title on the visible dragon reward panel screen.

| Shot | Overlay rect after resize | Title restored at 1920 | Hidden again at 1280 | Next screen | Title visible after fight | Boss overlay after fight |
| --- | --- | --- | --- | --- | --- | --- |
| `boss` | (570, 18, 780, 134) | Yes | Yes | Reward | Tempest God's Perch | Hidden |
| `dragon_tharokh` | (570, 18, 780, 134) | Yes | Yes | Reward | The Worldspine Vault | Hidden |
| `dragon_vyraketh` | (570, 18, 780, 134) | Yes | Yes | Reward | The Cinder Crown | Hidden |
| `dragon_iskaldra` | (570, 18, 780, 134) | Yes | Yes | Reward | The Rime Tyrant's Court | Hidden |
| `dragon_zekarion` | (570, 18, 780, 134) | Yes | Yes | Reward | Tempest God's Perch | Hidden |

### Idle layout calls

Calls to `_layout_boss_health_overlay` over 120 settled idle frames per fight and size at 100% UI scale. The peak was zero in every sample.

| Shot | 1280×800 calls / frames | 1920×1080 calls / frames |
| --- | --- | --- |
| `boss` | 0 / 120 | 0 / 120 |
| `dragon_tharokh` | 0 / 120 | 0 / 120 |
| `dragon_vyraketh` | 0 / 120 | 0 / 120 |
| `dragon_vaeloryx` | 0 / 120 | 0 / 120 |
| `dragon_iskaldra` | 0 / 120 | 0 / 120 |
| `dragon_zekarion` | 0 / 120 | 0 / 120 |
| `dragon_noctyrax` | 0 / 120 | 0 / 120 |

### 1920×1080 · 100%

| Shot | Title right | Readout left | First button left | Overlay rect | Name rect | Frame rect | Free / needed | Result |
| --- | ---: | ---: | ---: | --- | --- | --- | ---: | --- |
| `boss` | 349.00 → 349.00 | 1517.00 → 1517.00 | 1690.00 → 1690.00 | (570.00, 18.00, 780.00, 134.00) → (570.00, 18.00, 780.00, 134.00) | (588.00, 18.00, 744.00, 36.00) → (588.00, 18.00, 744.00, 36.00) | (570.00, 28.00, 780.00, 90.00) → (570.00, 28.00, 780.00, 90.00) | 1120.00 / 481.00 | Preserved |
| `dragon_tharokh` | 367.00 → 367.00 | 1452.00 → 1452.00 | 1613.00 → 1613.00 | (570.00, 18.00, 780.00, 134.00) → (570.00, 18.00, 780.00, 134.00) | (588.00, 18.00, 744.00, 36.00) → (588.00, 18.00, 744.00, 36.00) | (570.00, 28.00, 780.00, 90.00) → (570.00, 28.00, 780.00, 90.00) | 1037.00 / 407.00 | Preserved |
| `dragon_vyraketh` | 303.00 → 303.00 | 1452.00 → 1452.00 | 1613.00 → 1613.00 | (570.00, 18.00, 780.00, 134.00) → (570.00, 18.00, 780.00, 134.00) | (588.00, 18.00, 744.00, 36.00) → (588.00, 18.00, 744.00, 36.00) | (570.00, 28.00, 780.00, 90.00) → (570.00, 28.00, 780.00, 90.00) | 1101.00 / 452.00 | Preserved |
| `dragon_vaeloryx` | 274.00 → 274.00 | 1452.00 → 1452.00 | 1613.00 → 1613.00 | (570.00, 18.00, 780.00, 134.00) → (570.00, 18.00, 780.00, 134.00) | (588.00, 18.00, 744.00, 36.00) → (588.00, 18.00, 744.00, 36.00) | (570.00, 28.00, 780.00, 90.00) → (570.00, 28.00, 780.00, 90.00) | 1130.00 / 420.00 | Preserved |
| `dragon_iskaldra` | 409.00 → 409.00 | 1452.00 → 1452.00 | 1613.00 → 1613.00 | (570.00, 18.00, 780.00, 134.00) → (570.00, 18.00, 780.00, 134.00) | (588.00, 18.00, 744.00, 36.00) → (588.00, 18.00, 744.00, 36.00) | (570.00, 28.00, 780.00, 90.00) → (570.00, 28.00, 780.00, 90.00) | 995.00 / 418.00 | Preserved |
| `dragon_zekarion` | 349.00 → 349.00 | 1452.00 → 1452.00 | 1613.00 → 1613.00 | (570.00, 18.00, 780.00, 134.00) → (570.00, 18.00, 780.00, 134.00) | (588.00, 18.00, 744.00, 36.00) → (588.00, 18.00, 744.00, 36.00) | (570.00, 28.00, 780.00, 90.00) → (570.00, 28.00, 780.00, 90.00) | 1055.00 / 481.00 | Preserved |
| `dragon_noctyrax` | 271.00 → 271.00 | 1449.00 → 1449.00 | 1614.00 → 1614.00 | (570.00, 18.00, 780.00, 134.00) → (570.00, 18.00, 780.00, 134.00) | (588.00, 18.00, 744.00, 36.00) → (588.00, 18.00, 744.00, 36.00) | (570.00, 28.00, 780.00, 90.00) → (570.00, 28.00, 780.00, 90.00) | 1130.00 / 420.00 | Preserved |

### 1920×1080 · 115%

| Shot | Title right | Readout left | First button left | Overlay rect | Name rect | Frame rect | Free / needed | Result |
| --- | ---: | ---: | ---: | --- | --- | --- | ---: | --- |
| `boss` | 415.15 → 415.15 | 1445.55 → 1445.55 | 1653.70 → 1653.70 | (557.50, 20.70, 805.00, 154.10) → (527.85, 20.70, 805.00, 154.10) | (578.20, 20.70, 763.60, 41.40) → (548.55, 20.70, 763.60, 41.40) | (557.50, 32.20, 805.00, 92.88) → (527.85, 32.20, 805.00, 92.88) | 982.40 / 553.15 | Fit |
| `dragon_tharokh` | 434.70 → 434.70 | 1373.10 → 1373.10 | 1566.30 → 1566.30 | (557.50, 20.70, 805.00, 154.10) → (501.40, 20.70, 805.00, 154.10) | (578.20, 20.70, 763.60, 41.40) → (522.10, 20.70, 763.60, 41.40) | (557.50, 32.20, 805.00, 92.88) → (501.40, 32.20, 805.00, 92.88) | 890.40 / 468.05 | Fit |
| `dragon_vyraketh` | 359.95 → 359.95 | 1373.10 → 1373.10 | 1566.30 → 1566.30 | (557.50, 20.70, 805.00, 154.10) → (464.02, 20.70, 805.00, 154.10) | (578.20, 20.70, 763.60, 41.40) → (484.72, 20.70, 763.60, 41.40) | (557.50, 32.20, 805.00, 92.88) → (464.02, 32.20, 805.00, 92.88) | 965.15 / 519.80 | Fit |
| `dragon_vaeloryx` | 325.45 → 325.45 | 1373.10 → 1373.10 | 1566.30 → 1566.30 | (557.50, 20.70, 805.00, 154.10) → (446.77, 20.70, 805.00, 154.10) | (578.20, 20.70, 763.60, 41.40) → (467.47, 20.70, 763.60, 41.40) | (557.50, 32.20, 805.00, 92.88) → (446.77, 32.20, 805.00, 92.88) | 999.65 / 483.00 | Fit |
| `dragon_iskaldra` | 484.15 → 484.15 | 1373.10 → 1373.10 | 1566.30 → 1566.30 | (557.50, 20.70, 805.00, 154.10) → (526.12, 20.70, 805.00, 154.10) | (578.20, 20.70, 763.60, 41.40) → (546.83, 20.70, 763.60, 41.40) | (557.50, 32.20, 805.00, 92.88) → (526.12, 32.20, 805.00, 92.88) | 840.95 / 480.70 | Fit |
| `dragon_zekarion` | 415.15 → 415.15 | 1373.10 → 1373.10 | 1566.30 → 1566.30 | (557.50, 20.70, 805.00, 154.10) → (491.62, 20.70, 805.00, 154.10) | (578.20, 20.70, 763.60, 41.40) → (512.33, 20.70, 763.60, 41.40) | (557.50, 32.20, 805.00, 92.88) → (491.62, 32.20, 805.00, 92.88) | 909.95 / 553.15 | Fit |
| `dragon_noctyrax` | 320.85 → 320.85 | 1369.65 → 1369.65 | 1567.45 → 1567.45 | (557.50, 20.70, 805.00, 154.10) → (442.75, 20.70, 805.00, 154.10) | (578.20, 20.70, 763.60, 41.40) → (463.45, 20.70, 763.60, 41.40) | (557.50, 32.20, 805.00, 92.88) → (442.75, 32.20, 805.00, 92.88) | 1000.80 / 483.00 | Fit |
