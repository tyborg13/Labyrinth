# gfix-36 board framing on Continue

## 1. Fresh-run reference

The headless probe starts a new RunScene with seed `7262026`, follows the generated route through live board doors, and finishes combat through the production card and tile handlers. It measures the settled board before reopening any checkpoint. All six reference states had full-size boards. The Central Waypoint is the starting room on these forward-only routes. The cleared plain room is the room left after resolving the combat reward.

All frame cells show fit size / tile width / projected board rectangle `(x, y, width, height)` in pixels. The fit origin is `(0, 0)` unless stated.

| State | Room | Fresh run at 1920×1080 and 100% |
| --- | --- | --- |
| Reward | (1, -1) | 1920 × 738 / 163.93 / (386.23, 202.69, 1147.54, 620.36) |
| Campfire | (-2, 1) | 1920 × 738 / 163.93 / (386.23, 45.88, 1147.54, 623.61) |
| Treasure | (-2, -1) | 1920 × 848 / 184.00 / (316.00, 143.66, 1288.00, 699.94) |
| Scavenger | (2, -1) | 1920 × 848 / 184.00 / (316.00, 161.40, 1288.00, 682.20) |
| Cleared plain room | (1, -1) | 1920 × 738 / 163.93 / (386.23, 202.69, 1147.54, 620.36) |
| Central Waypoint | (0, 0) | 1848 × 676 at (36, 62) / 149.41 / (437.05, 177.93, 1048.14, 608.60) |

## 2. Continue and walk-in comparisons

The direct Continue samples reopen game-written destination checkpoints in a new RunScene. The walk-in samples reopen the cleared predecessor and use its real board door. Across the two tables, the alternate display checks and the second-fight route, 17 comparisons against fresh runs passed the 1 px tolerance. The largest raw delta was 0.000061 px.

### Direct Continue

| State | Before | After |
| --- | --- | --- |
| Reward | 1920 × 1 / 1.00 / (887.50, 503.87, 142.00, 37.86) | 1920 × 738 / 163.93 / (386.23, 202.69, 1147.54, 620.36) |
| Campfire | 1920 × 1 / 1.00 / (887.50, 361.37, 142.00, 39.28) | 1920 × 738 / 163.93 / (386.23, 45.88, 1147.54, 623.61) |
| Treasure | 1920 × 1 / 1.00 / (887.50, 502.37, 142.00, 39.28) | 1920 × 848 / 184.00 / (316.00, 143.66, 1288.00, 699.94) |
| Scavenger | 1920 × 2 / 1.00 / (890.50, 500.95, 142.00, 41.31) | 1920 × 848 / 184.00 / (316.00, 161.40, 1288.00, 682.20) |
| Cleared plain room | 1920 × 2 / 1.00 / (887.50, 501.93, 142.00, 40.32) | 1920 × 738 / 163.93 / (386.23, 202.69, 1147.54, 620.36) |
| Central Waypoint | 1848 × 676 at (36, 62) / 149.41 / (437.05, 177.93, 1048.14, 608.60) | 1848 × 676 at (36, 62) / 149.41 / (437.05, 177.93, 1048.14, 608.60) |

### Walk in after Continue

| State | Before | After |
| --- | --- | --- |
| Reward | 1920 × 738 / 163.93 / (386.23, 202.69, 1147.54, 620.36) | 1920 × 738 / 163.93 / (386.23, 202.69, 1147.54, 620.36) |
| Campfire | 1920 × 2 / 1.00 / (887.50, 361.37, 142.00, 39.28) | 1920 × 738 / 163.93 / (386.23, 45.88, 1147.54, 623.61) |
| Treasure | 1920 × 2 / 1.00 / (887.50, 502.37, 142.00, 39.28) | 1920 × 848 / 184.00 / (316.00, 143.66, 1288.00, 699.94) |
| Scavenger | 1920 × 2 / 1.00 / (890.50, 500.95, 142.00, 41.31) | 1920 × 848 / 184.00 / (316.00, 161.40, 1288.00, 682.20) |
| Cleared plain room | 1920 × 738 / 163.93 / (386.23, 202.69, 1147.54, 620.36) | 1920 × 738 / 163.93 / (386.23, 202.69, 1147.54, 620.36) |
| Central Waypoint | Starting room | Starting room |

The first-fight route starts from a resumed Central Waypoint. A second route resumes the cleared fight at `(1, -1)` and enters the next fight at `(0, 1)`. Its reward and cleared room each measured `1920 × 738 / 162.25 / (392.13, 206.16, 1135.73, 601.55)` on the fresh run and both walk-in runs. [Reference](/private/tmp/labyrinth_codex/gfix-36/second-fight-reference.log) · [Before](/private/tmp/labyrinth_codex/gfix-36/second-fight-before.log) · [After](/private/tmp/labyrinth_codex/gfix-36/second-fight-after.log)

### Control modes

Both worktrees loaded the same isolated checkpoints. The probe sampled the defeat reframe at its production endpoint and records projected board coordinates to 0.01 px. The two measurement reports match in all seven cases.

| State | Before and after at 1920×1080 and 100% |
| --- | --- |
| Plain combat | 1920 × 738 / 163.93 / (386.23, 97.41, 1147.54, 620.36) |
| Guardian combat | 1920 × 738 / 156.61 / (411.85, 156.60, 1096.29, 550.07) |
| Dragon combat | 1920 × 738 / 119.71 / (541.00, 164.00, 838.00, 503.71) |
| Pre-battle | 1920 × 1 / 1.00 / (890.50, 503.87, 142.00, 37.78) |
| Event | 1920 × 1 / 1.00 / (887.50, 501.32, 144.50, 40.33) |
| Victory | 1920 × 1 / 1.00 / (887.50, 502.37, 142.00, 39.28) |
| Defeat | 1920 × 1 / 1.00 / (622.00, 506.60, 7.00, 3.50) |

Exact result `GFIX36 CONTROLS: PASS — 7 exact matches`. [Before measurements](/private/tmp/labyrinth_codex/gfix-36/controls-measured/before/measurements.json) · [After measurements](/private/tmp/labyrinth_codex/gfix-36/controls-measured/after/measurements.json)

## 3. Root cause and repair

Live combat measures the hand while its controls are laid out and keeps that budget after victory. The old deferred capture accepted only `combat` and `room`. A fresh Continue into a choice skipped capture and read the default desktop hand top of zero. In a resumed `room`, Godot skipped the hidden hand during container sorting, so a capture could freeze its initial 10 px position and pass a 2 px fit to the board. The next room could inherit that budget.

Before a combat budget exists for the run, RunScene reconstructs the reservation for room and board-backed reward presentation from the checkpoint's room and predecessor. A cleared encounter or its immediate choice uses the combat reserve. A room reached after the hand has sunk uses the existing victory sink distance. The reconstruction measures the anchored layout, shifts the existing utility exclusions for the combat header, and uses the authored compact fan and rail measurements where needed. The same rules cover ordinary rooms and merchant rooms. Once combat can be measured, the existing capture supplies the budget through the live sequence. The waypoint keeps its established rectangle. The budget lives in the scene, so older checkpoints use the same recovery path with their existing room metadata. [RunScene](../../scripts/run_scene.gd#L3844) · [HUD budget](../../scripts/board_hud_budget.gd)

## 4. Alternate displays

The 115% run applies the actual Window content scale. That yields a logical viewport of 1669.57 × 939.13 at 1920×1080 output, so the projection coordinates in those rows are logical pixels.

| Output | State | Fresh run | Before Continue | After Continue |
| --- | --- | --- | --- | --- |
| 1280×800 at 100% | Campfire | 1280 × 734.68 / 119.00 / (223.50, 2.67, 833.00, 452.68) | 1280 × 792 / 176.58 / (21.97, -121.36, 1236.07, 671.72) | 1280 × 734.68 / 119.00 / (223.50, 2.67, 833.00, 452.68) |
| 1280×800 at 100% | Treasure | 1280 × 792 / 171.14 / (41.00, 31.35, 1198.01, 651.04) | 1280 × 792 / 176.58 / (21.97, 19.64, 1236.07, 671.72) | 1280 × 792 / 171.14 / (41.00, 31.35, 1198.01, 651.04) |
| 1920×1080 at 115% | Campfire | 1669.57 × 597 / 129.87 / (380.24, 48.76, 909.08, 494.03) | 1669.57 × 1 / 1.00 / (762.28, 290.87, 142.00, 39.28) | 1669.57 × 597 / 129.87 / (380.24, 48.76, 909.08, 494.03) |
| 1920×1080 at 115% | Treasure | 1669.57 × 707 / 156.67 / (286.42, 132.08, 1096.72, 595.99) | 1669.57 × 1 / 1.00 / (762.28, 431.93, 142.00, 39.28) | 1669.57 × 707 / 156.67 / (286.42, 132.08, 1096.72, 595.99) |

## Headless checks

| Check | Exact result | Evidence |
| --- | --- | --- |
| Board framing and hand/input suites | `UX11 FOCUSED ASSERTIONS: 1851` and `TEST RESULT: PASS` | [Log](/private/tmp/labyrinth_codex/gfix-36/board-framing-final.log) |
| Live HUD budget probe with the UX-11 fixture | `UX11 HEADLESS RESULT: FAIL` on both worktrees. Both report `Hand and frozen HUD budget settle before measurement` three times and `Device handoff never reframes the board` twice. | [Base](/private/tmp/labyrinth_codex/gfix-36/hud-budget-base.log) · [After](/private/tmp/labyrinth_codex/gfix-36/hud-budget-final.log) |
| Existing save/Continue suite with new reward assertion | Base `Continue should restore the live post-combat reward fit, got (1920.0, 1.0)` and `TEST RESULT: FAIL — 1 committed save/resume failure(s)`. After `TEST RESULT: PASS — committed save/resume boundary matrix`. | [Base](/private/tmp/labyrinth_codex/gfix-36/save-resume-regression-before.log) · [After](/private/tmp/labyrinth_codex/gfix-36/save-resume-final.log) |
| Main-menu Continue | `TEST RESULT: PASS — main menu resume safety` | [Log](/private/tmp/labyrinth_codex/gfix-36/main-menu-resume-final.log) |
| Python default group | `Ran 192 tests in 43.623s` and `FAILED (failures=1)`. The runner cleanup check reported `Child did not start`. Its isolated recheck gave `Ran 1 test in 3.581s` and `OK`. Rules text lint gave `PASS: Rules text lint (455 existing hits)`. | [Default](/private/tmp/labyrinth_codex/gfix-36/python-default-final.log) · [Recheck](/private/tmp/labyrinth_codex/gfix-36/runner-recheck.log) |
| UI identity lint | `Ran 25 tests in 5.820s` and `OK` | [Log](/private/tmp/labyrinth_codex/gfix-36/ui-identity-final.log) |
| Windows typed arrays | `TYPED ARRAY SCAN: 5 scripts; 0 new; 2 pre-existing` | [Log](/private/tmp/labyrinth_codex/gfix-36/typed-arrays-final.log) |
| Native launcher dry run | `CENSUS RESULT: PASS; 6/6 shots succeeded; 0 capped` for before and after at 1920×1080. `CENSUS RESULT: PASS; 2/2 shots succeeded; 0 capped` for after at 1280×800. | [Log](/private/tmp/labyrinth_codex/gfix-36/native-final.log) |

The sandbox denied the Python timing-cache write under the shared Git directory. Headless runs produced logs and manifests. Native PNGs still need a desktop session.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-36 && /private/tmp/labyrinth_codex/gfix-36/native.sh
```

That command prints the three destination folders. The dry run produced these manifests. [Before 1920×1080](/private/tmp/labyrinth_codex/gfix-36/20261123T114448742659Z/before/manifest.json) · [After 1920×1080](/private/tmp/labyrinth_codex/gfix-36/20261123T114448742659Z/after/manifest.json) · [After 1280×800](/private/tmp/labyrinth_codex/gfix-36/20261123T114448742659Z/after-1280x800/manifest.json)

## Chosen defaults

- The fresh-run probe uses the census seed and room coordinates, an isolated profile with the guided tutorial dismissed, and an extra fight at `(0, 1)`. The last-hit fixture uses Pale Spark against a one-Health target at a legal tile. The probe inherits the scn-02 readiness deadline and frame cap.
- Census dry runs keep the scn-02 180-second watchdog. Control proof uses three headless jobs and records projected bounds to 0.01 px. The save regression allows four headless frames for deferred layout.

No `TODO_DESIGN_*` placeholders.
