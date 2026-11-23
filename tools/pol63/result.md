# pol-63 proof

All three findings reproduced on base `060674b1a` and were fixed. Headless runs use the census fixtures and Continue checkpoint path with the cel look and 100% UI scale. The director’s original PNGs are in `/private/tmp/labyrinth_codex/scn-01/20261123T103226618634Z/`.

## 1. Objective titles and subtitles

The panel, intro, tooltip and pre-battle objective line now read the same display title. The intro and HUD use uppercase, and the pre-battle heading adds the existing `OBJECTIVE ·` prefix. The subtitle drops redundant leader names for Warbands and Guardians. Dragon Health, concealment, Hoarder timing, and the other objective details use the existing wording. Generic `Defeat the Leader` encounters still identify the unnamed target in the subtitle.

The table shows the actual panel text. Frames are Godot process frames at 1920×1080, listed before → after. Title widths are required/available pixels inside the title label. Each new title fit on one line above its subtitle at both sizes. The headless proof also measured the widest point of the intro title at both sizes.

| Scenario | Seed | Frames | Before title | Before subtitle | After title | After subtitle | 1920×1080 | 1280×800 |
| --- | ---: | --- | --- | --- | --- | --- | ---: | ---: |
| warband_earth | 7262026 | 137 → 135 | DEFEAT THE THORNMOTHER | The Thornmother · 20/20 Health | DEFEAT THE THORNMOTHER | 20/20 Health | 271/293 | 271/293 |
| warband_fire | 7262026 | 136 → 136 | DEFEAT THE SLAGMASTER | The Slagmaster · 28/28 Health | DEFEAT THE SLAGMASTER | 28/28 Health | 249/270 | 249/270 |
| warband_air | 7262026 | 136 → 135 | DEFEAT THE STORMCALLER | The Stormcaller · 27/27 Health | DEFEAT THE STORMCALLER | 27/27 Health | 259/281 | 259/281 |
| warband_ice | 7262026 | 137 → 34 | DEFEAT THE RIME ORACLE | The Rime Oracle · 21/21 Health | DEFEAT THE RIME ORACLE | 21/21 Health | 249/269 | 249/269 |
| warband_lightning | 7262026 | 136 → 33 | DEFEAT THE DYNAMO | The Dynamo · 37/37 Health | DEFEAT THE DYNAMO | 37/37 Health | 206/260 | 206/260 |
| warband_shadow | 7262026 | 137 → 35 | DEFEAT THE HOLLOW PRIOR | The Hollow Prior · 28/28 Health | DEFEAT THE HOLLOW PRIOR | 28/28 Health | 268/290 | 268/290 |
| guardian_ashen_reaver | 7262026 | 129 → 134 | DEFEAT ASHEN REAVER | Ashen Reaver · 53/53 Health | DEFEAT THE ASHEN REAVER | 53/53 Health | 269/291 | 269/291 |
| guardian_rimejaw | 7262026 | 134 → 135 | DEFEAT RIMEJAW | Rimejaw · 54/54 Health | DEFEAT THE RIMEJAW | 54/54 Health | 209/260 | 209/260 |
| guardian_storm_cantor | 7262026 | 129 → 137 | DEFEAT STORM CANTOR | Storm Cantor · 97/97 Health | DEFEAT THE STORM CANTOR | 97/97 Health | 271/294 | 271/294 |
| guardian_gallows_roc | 7262026 | 136 → 136 | DEFEAT GALLOWS ROC | Leader concealed | DEFEAT THE GALLOWS ROC | Leader concealed | 258/280 | 258/280 |
| guardian_craghide | 7262026 | 137 → 136 | DEFEAT CRAGHIDE | Craghide · 51/51 Health | DEFEAT THE CRAGHIDE | 51/51 Health | 220/260 | 220/260 |
| guardian_last_lamplighter | 7262026 | 136 → 136 | DEFEAT LAST LAMPLIGHTER | Leader concealed | DEFEAT THE LAST LAMPLIGHTER | Leader concealed | 309/334 | 309/334 |
| dragon_tharokh | 7262026 | 134 → 134 | DEFEAT THAROKH, THE WORLDSPINE | 98/98 Health | DEFEAT THAROKH | 98/98 Health | 174/260 | 174/260 |
| dragon_vyraketh | 7262027 | 135 → 136 | DEFEAT VYRAKETH, THE CINDER CROWN | 71/71 Health | DEFEAT VYRAKETH | 71/71 Health | 184/260 | 184/260 |
| dragon_vaeloryx | 7262031 | 135 → 135 | DEFEAT VAELORYX, THE HOLLOW GALE | 68/68 Health | DEFEAT VAELORYX | 68/68 Health | 181/260 | 181/260 |
| dragon_iskaldra | 7262028 | 136 → 135 | DEFEAT ISKALDRA, THE RIME TYRANT | 84/84 Health | DEFEAT ISKALDRA | 84/84 Health | 176/260 | 176/260 |
| dragon_zekarion | 7262029 | 136 → 136 | DEFEAT ZEKARION, THE RAGING TEMPEST | 84/84 Health | DEFEAT ZEKARION | 84/84 Health | 178/260 | 178/260 |
| dragon_noctyrax | 7262026 | 135 → 135 | DEFEAT NOCTYRAX, THE LAST ECLIPSE | 122/122 Health | DEFEAT NOCTYRAX | 122/122 Health | 184/260 | 184/260 |
| ember_hoarder | 7262026 | 135 → 138 | DEFEAT THE HOARDER | Before it escapes · 27/27 Health | DEFEAT THE HOARDER | Before it escapes · 27/27 Health | 214/260 | 214/260 |
| last_light | 7262026 | 137 → 137 | SURVIVE UNTIL DAWN | Dawn in 66 · Reinforcements in 16 | SURVIVE UNTIL DAWN | Dawn in 66 · Reinforcements in 16 | 215/260 | 215/260 |
| snare | 7262026 | 136 → 137 | REACH THE EXIT | Reach any of 3 marked thresholds | REACH THE EXIT | Reach any of 3 marked thresholds | 157/260 | 157/260 |
| combat_idle | 7262026 | 135 → 134 | DEFEAT ALL ENEMIES | 4 enemies remaining | DEFEAT ALL ENEMIES | 4 enemies remaining | 201/260 | 201/260 |

The Hoarder originally used `DEFEAT THE EMBER HOARDER BEFORE IT ESCAPES!` in the intro and the same sentence in title case pre-battle. Both now use the existing HUD title `Defeat the Hoarder`. Last Light originally used `Survive Until Dawn!` outside the HUD. It now uses the existing HUD title `Survive Until Dawn` on those surfaces as well. The saved and analytics objective names retain their existing source. The proof reads the production pre-battle chip for each combat fixture and the actual pre-battle screen for the plain fixture.

## 2. Relic Cache placard

The centered label is the board status placard. `RunScene._board_status_label()` passed `Relic` to `CombatBoardView._draw_status_text()`, which drew the text and its flanking rules. In `--scenario treasure --seed 7262026` the base placard was `Relic` at frame 182, with a 73×34 board-local text rect. At frame 48 the placard text and bounds are empty. The room title is still `Relic Cache` and the banner is still `CLAIM YOUR TREASURE`.

The placard producer has two nonempty outputs on the base, `Relic` in treasure and `Choose Door` in its room fallback. The census and headless state audit found no second visible duplicate over a banner. Reward, campfire, Graftwright, event, pre-battle, victory and defeat supply an empty placard. The Scavenger fixture retains the underlying `Choose Door` instruction behind its shop while the census image shows the shop's own signage. The waypoint’s direct door navigation can already suppress the fallback. The room instruction remains available on its existing branch.



## 3. Settled opening dock after director feedback

The previous implementation captured the home before the board's HUD-aware fit was applied. The board already had the correct grid, but the first bounds described the provisional board at about 143 px wide. Both original Continue homes and both door-entry homes remained at the provisional height after the board grew to about 1,097 px wide. The earlier census hover recalculation had therefore found the correct placement for the plain fight.

The home now captures after the opening hand layout and after the board receives the current fit exclusions for that encounter and display. The fit pass can still read provisional HUD geometry. The dock has no canvas visibility layer until the final placement is available, so that geometry cannot render. The chips appear at the settled home and the authored intro travels to it. Later combat updates reuse that home. The existing rule, Undo reserve, and viewport bounds still apply. [Godot CanvasItem visibility layers](https://docs.godotengine.org/en/4.6/classes/class_canvasitem.html#class-canvasitem-property-visibility-layer)

### Entry measurements

All rows use seed 7262026 at 1920×1080 and 100% UI scale. The plain fight uses the four-enemy census fixture. The Guardian is Ashen Reaver with Wildfire. For door entry, the probe opens the real incoming door and presses the pre-battle Start button. Start uses the same saved battle snapshot as Continue so the board, occupants and opening hand match. The approach coordinates are `(0, 0) → (1, −1)` and `(6, −6) → (6, −2)`, respectively.

| Fight and entry | Capture frame before → after | Rendered board bounds before → after | Board fit applied at capture before → after |
| --- | ---: | --- | --- |
| `combat_idle_continue` | 0 → 5 | (888.00, -19.33, 142.50, 40.94) → (411.39, 125.50, 1097.21, 593.15) | No → Yes |
| `combat_idle_door` | 35 → 102 | (888.00, -19.33, 142.50, 40.94) → (411.39, 125.50, 1097.21, 593.15) | No → Yes |
| `guardian_continue` | 0 → 5 | (887.50, -19.07, 143.00, 40.61) → (411.85, 156.60, 1096.29, 550.07) | No → Yes |
| `guardian_door` | 96 → 101 | (887.50, -18.49, 143.00, 40.52) → (411.85, 156.60, 1096.29, 550.07) | No → Yes |

Rectangles are `(x, y, width, height)` in viewport pixels. Each row lists Objective / Battlefield Rule / Card Plays / Movement. During the normal entry intro, the centered animation is independent of the dock. The first row for that path therefore shows only the chips. The first docked objective row records the complete stack after the intro lands.

| Fight and entry | Phase | Frames before → after | Before feedback O / R / P / M | After feedback O / R / P / M |
| --- | --- | --- | --- | --- |
| `combat_idle_continue` | first visible | 0 → 6 | (100.40, 520.45, 350.00, 70.00) / — / (100.40, 598.45, 228.00, 58.00) / (100.40, 664.45, 228.00, 58.00) | (49.39, 648.66, 350.00, 70.00) / — / (49.39, 726.66, 228.00, 58.00) / (49.39, 792.66, 228.00, 58.00) |
| `combat_idle_continue` | first docked objective | 0 → 6 | (100.40, 520.45, 350.00, 70.00) / — / (100.40, 598.45, 228.00, 58.00) / (100.40, 664.45, 228.00, 58.00) | (49.39, 648.66, 350.00, 70.00) / — / (49.39, 726.66, 228.00, 58.00) / (49.39, 792.66, 228.00, 58.00) |
| `combat_idle_continue` | settled idle | 6 → 6 | (100.40, 520.45, 350.00, 70.00) / — / (100.40, 598.45, 228.00, 58.00) / (100.40, 664.45, 228.00, 58.00) | (49.39, 648.66, 350.00, 70.00) / — / (49.39, 726.66, 228.00, 58.00) / (49.39, 792.66, 228.00, 58.00) |
| `combat_idle_door` | first visible | 36 → 103 | — / — / (100.40, 598.45, 228.00, 58.00) / (100.40, 664.45, 228.00, 58.00) | — / — / (49.39, 726.66, 228.00, 58.00) / (49.39, 792.66, 228.00, 58.00) |
| `combat_idle_door` | first docked objective | 64 → 191 | (100.40, 520.45, 350.00, 70.00) / — / (100.40, 598.45, 228.00, 58.00) / (100.40, 664.45, 228.00, 58.00) | (49.39, 648.66, 350.00, 70.00) / — / (49.39, 726.66, 228.00, 58.00) / (49.39, 792.66, 228.00, 58.00) |
| `combat_idle_door` | settled idle | 81 → 244 | (100.40, 520.45, 350.00, 70.00) / — / (100.40, 598.45, 228.00, 58.00) / (100.40, 664.45, 228.00, 58.00) | (49.39, 648.66, 350.00, 70.00) / — / (49.39, 726.66, 228.00, 58.00) / (49.39, 792.66, 228.00, 58.00) |
| `guardian_continue` | first visible | 0 → 6 | (25.00, 520.45, 381.00, 70.00) / (25.00, 423.45, 381.00, 89.00) / (25.00, 598.45, 228.00, 58.00) / (25.00, 664.45, 228.00, 58.00) | (24.00, 636.68, 381.00, 70.00) / (24.00, 539.68, 381.00, 89.00) / (24.00, 714.68, 228.00, 58.00) / (24.00, 780.68, 228.00, 58.00) |
| `guardian_continue` | first docked objective | 0 → 6 | (25.00, 520.45, 381.00, 70.00) / (25.00, 423.45, 381.00, 89.00) / (25.00, 598.45, 228.00, 58.00) / (25.00, 664.45, 228.00, 58.00) | (24.00, 636.68, 381.00, 70.00) / (24.00, 539.68, 381.00, 89.00) / (24.00, 714.68, 228.00, 58.00) / (24.00, 780.68, 228.00, 58.00) |
| `guardian_continue` | settled idle | 6 → 6 | (25.00, 520.45, 381.00, 70.00) / (25.00, 423.45, 381.00, 89.00) / (25.00, 598.45, 228.00, 58.00) / (25.00, 664.45, 228.00, 58.00) | (24.00, 636.68, 381.00, 70.00) / (24.00, 539.68, 381.00, 89.00) / (24.00, 714.68, 228.00, 58.00) / (24.00, 780.68, 228.00, 58.00) |
| `guardian_door` | first visible | 97 → 102 | — / — / (24.00, 598.45, 228.00, 58.00) / (24.00, 664.45, 228.00, 58.00) | — / — / (24.00, 714.68, 228.00, 58.00) / (24.00, 780.68, 228.00, 58.00) |
| `guardian_door` | first docked objective | 280 → 281 | (24.00, 520.45, 381.00, 70.00) / (24.00, 423.45, 381.00, 89.00) / (24.00, 598.45, 228.00, 58.00) / (24.00, 664.45, 228.00, 58.00) | (24.00, 636.68, 381.00, 70.00) / (24.00, 539.68, 381.00, 89.00) / (24.00, 714.68, 228.00, 58.00) / (24.00, 780.68, 228.00, 58.00) |
| `guardian_door` | settled idle | 342 → 342 | (24.00, 520.45, 381.00, 70.00) / (24.00, 423.45, 381.00, 89.00) / (24.00, 598.45, 228.00, 58.00) / (24.00, 664.45, 228.00, 58.00) | (24.00, 636.68, 381.00, 70.00) / (24.00, 539.68, 381.00, 89.00) / (24.00, 714.68, 228.00, 58.00) / (24.00, 780.68, 228.00, 58.00) |

### Input and turn traces

The left stack held the settled idle rectangles above on both entry paths. The probe checked every rendered frame from the first complete dock through the first enemy turn and following deal. The table identifies the sampled frames for each state. Full tuples, board bounds, and hand bounds for every sample are in `/private/tmp/labyrinth_codex/pol-63/review-settled/state.json`.

**Plain fight**

| Input state | Continue frame | Door entry frame | Stack position |
| --- | ---: | ---: | --- |
| `idle` | 30 | 268 | Settled idle |
| `pointer_hover:pale_spark` | 54 | 292 | Settled idle |
| `pointer_hover:quick_stab` | 78 | 316 | Settled idle |
| `pointer_hover:guarded_step` | 102 | 340 | Settled idle |
| `pointer_hover:sidestep_slash` | 126 | 364 | Settled idle |
| `keyword_popup` | 150 | 388 | Settled idle |
| `unhover` | 175 | 413 | Settled idle |
| `pointer_selected` | 201 | 439 | Settled idle |
| `number_key_aim` | 230 | 468 | Settled idle |
| `controller_focus` | 259 | 497 | Settled idle |
| `controller_selected` | 285 | 523 | Settled idle |
| `enemy_turn` | 292 | 530 | Settled idle |
| `after_enemy_turn` | 593 | 833 | Settled idle |

**Ashen Reaver**

| Input state | Continue frame | Door entry frame | Stack position |
| --- | ---: | ---: | --- |
| `idle` | 30 | 366 | Settled idle |
| `pointer_hover:chain_bolt` | 54 | 390 | Settled idle |
| `pointer_hover:stone_plate` | 78 | 414 | Settled idle |
| `pointer_hover:shadow_step` | 102 | 438 | Settled idle |
| `pointer_hover:cleaver_hook` | 126 | 462 | Settled idle |
| `pointer_hover:patch_up` | 150 | 486 | Settled idle |
| `keyword_popup` | 174 | 510 | Settled idle |
| `unhover` | 199 | 535 | Settled idle |
| `pointer_selected` | 225 | 561 | Settled idle |
| `number_key_aim` | 254 | 590 | Settled idle |
| `controller_focus` | 283 | 619 | Settled idle |
| `controller_selected` | 313 | 649 | Settled idle |
| `enemy_turn` | 320 | 656 | Settled idle |
| `after_enemy_turn` | 749 | 1072 | Settled idle |

The original entry measurements are in `review-before-motion/` and `review-before-door-stable/` under the proof root. The final four-path run reported `POL63 STATE PROOF: PASS; 70 rows; 0 failures`. Normal entry used Pale Spark in the plain fight and Shadow Step in the Guardian fight to test number-key aiming. The two keyword pop-ups came from Quick Stab and Chain Bolt.


## Original implementation verification

All logs are under `/private/tmp/labyrinth_codex/pol-63/`.

| Check | Exact result |
| --- | --- |
| Focused Godot combat objective, dragon, Guardian, Hoarder, Last Light, Snare and Warband suites | `POL63 FOCUSED RESULT: 226428 assertions; 0 failures` |
| Pre-battle view | `PRE-BATTLE VIEW TEST: PASS` and `TEST RESULT: PASS` |
| Warband UI | `Warband UI semantics: 0 failures` |
| Snare UI | `Snare UI/fixture suite: 0 failures` |
| Treasure presentation | `TREASURE PRESENTATION PROBE: PASS` |
| Movement Undo suite, including live dock behavior | `POL63 MOVEMENT UNDO SUITE: 508 assertions; 0 failures` |
| UI identity lint | `Ran 25 tests in 6.083s` and `OK` |
| Rules text lint | `PASS: Rules text lint (455 existing hits)` |
| Windows typed-array scan compared to base | `TYPED ARRAY CHANGED FILES: 9 files; 0 new candidates; 102 existing candidates` |
| Python default input group | `Ran 192 tests in 40.572s` and `FAILED (failures=1)` |
| State proof on the revised waypoint case | `POL63 STATE PROOF: PASS; 1 rows; 0 failures` |
| Census dry-run | `CENSUS RESULT: PASS; 14/14 shots succeeded; 0 capped` before and after at 1920×1080. `CENSUS RESULT: PASS; 6/6 shots succeeded; 0 capped` after at 1280×800. |

The original state comparison recorded `POL63 STATE PROOF: FAIL; 81 rows; 1 failures` because the waypoint probe expected a placard where direct door navigation suppresses it. The revised waypoint proof closes the introductory dialogue before the census settle check. At frame 59, it observed active direct door navigation and an empty placard on the waypoint. All remaining cases in the state comparison settled and passed their checks. Evidence is in `before-all/state.json`, `before/state.json` (the treasure and Guardian baselines), `after-all/state.json` and `waypoint-final/state.json`.

The Python default failure is `Missing tracked Godot sidecars (2)` for `tools/scn01/census.gd.uid` and `tools/scn01/census_input.gd.uid`. Both paths are absent from tracked base `060674b1a`. The runner also reported that its shared timing history could not be written under read-only Git metadata.

The existing combat objective probe reported `COMBAT OBJECTIVE PROBE HEADLESS RESULT: FAIL` with the same six assertions on base and after. The assertions cover generic leader preview wording, three side-utility-lane checks, Reach Exit encounter density, and its reward overlay. The combat hand flanks probe reported `ERROR: normal pass/meter proof should build all dock controls` on both revisions. The standalone Movement Undo capture probe logged dock geometry, then reached `error: command timed out after 300 seconds.` while waiting for the renderer's capture boundary. The separate headless Movement Undo suite passed its dock assertions.


## Director verification

The feedback round only ran the focused checks and the requested entry and census proofs. Logs are under `/private/tmp/labyrinth_codex/pol-63/`.

| Check | Exact result |
| --- | --- |
| Door and Continue input traces | `POL63 STATE PROOF: PASS; 70 rows; 0 failures` |
| Objective suites | `POL63 FOCUSED RESULT: 226428 assertions; 0 failures` |
| Pre-battle view | `PRE-BATTLE VIEW TEST: PASS` and `TEST RESULT: PASS` |
| Movement Undo | `POL63 MOVEMENT UNDO SUITE: 508 assertions; 0 failures` |
| UI identity | `Ran 25 tests in 5.093s` and `OK` |
| Typed-array scan for this round | `TYPED ARRAY CHANGED FILES: 4 files; 0 new candidates; 101 existing candidates` |
| Census dry-run | `CENSUS RESULT: PASS; 14/14 shots succeeded; 0 capped` before and after at 1920×1080. `CENSUS RESULT: PASS; 6/6 shots succeeded; 0 capped` after at 1280×800. |
| Settled-entry census dry-run | `POL63 STATE PROOF: PASS; 20 rows; 0 failures` |

The plain fight also re-established its painted dock after a live 1920×1080 to 1280×800 resize, then after a fixed-size 100% to 115% scale change. Exact lines from `review-display-settled.log`:

```text
POL63 RESIZE: [P: (49.39429, 648.6595), S: (350.0, 70.0)] -> [P: (24.0, 550.0), S: (350.0, 70.0)]
POL63 UI SCALE: 1.00 -> 1.15; objective [P: (24.0, 547.0711), S: (350.0, 70.0)]
```

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-63 && /private/tmp/labyrinth_codex/pol-63/native.sh
```

The launcher prints each output folder. It uses the clean sibling `scn-01` worktree at `060674b1a` for the original baseline and this worktree for the revised census. The new `settled-entry` folder contains separate 1920×1080 captures and rect logs for the plain fight and Ashen Reaver through each entry path. The visual runner checks every capture against its per-shot PNG contract. Windowed rendering is pending for the design owner.

The completed dry-run manifests, entry rect logs, and planned capture names are under `/private/tmp/labyrinth_codex/pol-63/census.VZEnbxfM/`. The director’s original base PNGs are under `/private/tmp/labyrinth_codex/scn-01/20261123T103226618634Z/`.

## Chosen defaults

- The proof uses the census's three headless jobs and samples each input state for 24 frames. Entry comparison allows 0.01 px for floating-point transforms.
- The entry probe enables full motion to exercise the intro. It uses an actual incoming route and the original combat snapshot on both paths. A predecessor grid too small for its configured door uses the same full-size fixture geometry for the approach.
- The resize proof uses the two requested sizes and the existing 115% preset for the scale check.

No `TODO_DESIGN_*` placeholders.

## Director feedback 2 — 30-frame dock deadline

The first provisional placement starts one deadline shared by Continue and the door-entry intro. Each frame attempts placement while the home is missing. The first framed placement wins. At retry 30, the same calculation captures the current geometry and releases the wait so the stack can paint and the authored intro can proceed. A display change during the wait keeps the original deadline. An encounter change cancels the wait and releases its frame subscription.

Native operation retries before drawing. Headless gameplay can retry on process frames when it has no renderer. The deadline proof submits dummy renderer frames and uses the native pre-draw signal, so it can count the exact frame when the stack first paints. [Godot RenderingServer frame signals](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#signals)

### Forced fallback

The probe forces the framing predicate false for the entire combat and checks for one retry on every frame through capture. Both runs use the plain four-enemy fight, seed 7262026, at 1920×1080 and 100% UI scale. Frame numbers are local to each run.

| Path | First attempt | Home captured and chips first visible | Retries | First complete dock | First card resolved |
| --- | ---: | ---: | ---: | --- | --- |
| Continue | 0 | 30 | 30 consecutive | Frame 30, restored combat | Frame 136 |
| Door entry | 99 | 129 | 30 consecutive | Frame 216, intro settled | Frame 376 |

On door entry, the intro was already in its appearing phase on frame 129. On each path, the probe pressed the first-slot shortcut, aimed Pale Spark at (4, 4), and clicked. Card Plays spent increased from 0 to 1 and Pale Spark left the hand.

### Normal framing

Each entry used the framed home. The normal 1920×1080 and 100% UI-scale rerun matched all 16 measured stack rows per path from feedback 1, including the input and enemy-turn rows. The maximum coordinate difference was 0.000000 px.

| Display | Path | First attempt | Framed home captured | Frames to capture | Frames to first paint | Objective top-left |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| 1920×1080, 100% | Continue | 0 | 6 | 6 | 7 | (49.39, 648.66) |
| 1920×1080, 100% | Door entry | 99 | 103 | 4 | 5 | (49.39, 648.66) |
| 1280×800, 100% | Continue | 0 | 6 | 6 | 7 | (24.00, 547.07) |
| 1280×800, 100% | Door entry | 99 | 103 | 4 | 5 | (24.00, 547.07) |
| 1920×1080, 115% | Continue | 0 | 6 | 6 | 7 | (49.39, 648.66) |
| 1920×1080, 115% | Door entry | 94 | 98 | 4 | 5 | (49.39, 648.66) |

The headless command was `python3 tools/pol63/state_proof.py after --dock-deadline --out /private/tmp/labyrinth_codex/pol-63/deadline-verified`. Use a fresh output path for a repeat. It reported `POL63 STATE PROOF: PASS; 60 rows; 0 failures`. The output contains the first-paint and settled rects, every retry frame, and the committed first-card state.

| Focused check | Exact result |
| --- | --- |
| Objective suites | `POL63 FOCUSED RESULT: 226428 assertions; 0 failures` |
| Movement Undo | `POL63 MOVEMENT UNDO SUITE: 508 assertions; 0 failures` |
| UI identity | `Ran 25 tests in 6.189s` and `OK` |
| Typed-array scan | `TYPED ARRAY CHANGED FILES: 3 files; 0 new candidates; 101 existing candidates` |

The 115% case uses the 1920×1080 fixture surface. The other proof defaults are carried over from feedback 1. No `TODO_DESIGN_*` placeholders were needed.
