# QA-107 layout sweep

Base `codex/release` at `525b2933dd8ec92e24a130ed915e734433e11a94`. The sweep is a tools-only audit. Its witnesses record headless layout geometry and live tooltip creation. Native renderer confirmation is pending.

## Method and reproduction

The driver uses the live hitch-census tour and fixture builder, with extra visits through existing screen openers. Each base snapshot walks visible Controls and records text metrics, bounding rectangles, clipping, texture slots, and overlap candidates. Pointer motion goes through Godot's GUI input path. A hover snapshot requires a newly opened or changed tooltip surface. The report groups evidence by state and relative control path.

Rects use `[x, y, width, height]` in logical viewport coordinates. Font measurements and available text space use the control's local units. A Label can report one visible line while clipping that line horizontally. An exact-size PNG requires the native renderer and is expected under the isolated run's `user://qa107/` directory. The probe prints its absolute path.

### Full headless replay

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-107 && QA107_PROFILE=desktop python3 tools/godot_task_runner.py --task-id qa-107 --timeout 720 --stream -- godot --headless --path . --script tools/qa107/layout_sweep.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-107 && QA107_PROFILE=deck python3 tools/godot_task_runner.py --task-id qa-107 --timeout 720 --stream -- godot --headless --path . --script tools/qa107/layout_sweep.gd
```

Pass the two printed `QA107 WITNESS` paths to `python3 tools/qa107/group_findings.py` for coverage and grouped candidates. `QA107_STATE` selects one state and `QA107_HOVER` optionally selects a recorded hover key within it. Use `QA107_OUTPUT` for a specific output directory. Use a fresh output directory per run when retaining captures.

### Interpretation

- **S1** means unreadable or blocking. **S2** means a visible glitch. **S3** means cosmetic. Geometric evidence supports the ranking and the native command gives the design owner a way to make the visual call.
- Intentional title face, rim and shadow layers, recap glow copies, circular map-node hit envelopes, board and map paint overscan, and normal scroll clipping are excluded from the ranked report. Modal scrims and tooltip ownership keep unrelated layers out of sibling overlap comparisons. Hover pop-ups may cover Pass and the dock under the owner rule.
- Coverage is bounded by the tour fixtures, the additional states below, and exposed pointer positions. Scroll and pan permutations, controller-only inspection modes and every possible loadout or seed are outside this sample. Procedurally painted board and icon elements are sampled through their tooltip hit regions where exposed. Texture checks apply to Control texture properties.

## Ranked findings

### S1 · Deck boss and dragon hand names clip to 1 layout unit

Resting cards in the boss and dragon fixtures have a 219 × 40 local label box with only 1 × 40 available after the title style insets. The names need 63–118 units. The same headless check found no title overrun in the corresponding desktop fixtures. In both cases enter the encounter at 115% UI scale and leave the hand at rest.

The path prefix is `UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll/HandCenter/HandTuckMargin/HandBox/`. Each listed slot ends in `/CardScaleFrame/CardWidget/Margin/VBox/TopRow/Title`. Every row uses `clip_text=true` and the ellipsis overrun mode, and reports 1 visible line / 1 total line.

| State | Slot | Label text | Shaped width | Label rect |
| --- | --- | --- | ---: | --- |
| `boss` | `Control[0]` | Warded Advance | 118 | `[652.0, 739.1, 183.7, 42.8]` |
| `boss` | `Control[1]` | Low Sweep | 76 | `[697.6, 732.8, 183.0, 38.0]` |
| `boss` | `Control[2]` | Shrapnel Bomb | 106 | `[743.4, 729.6, 182.2, 33.3]` |
| `boss` | `Control[3]` | Shadow Step | 89 | `[788.3, 732.8, 183.0, 38.0]` |
| `dragon` | `Control[0]` | Butcher Chop | 93 | `[640.4, 739.1, 183.4, 42.8]` |
| `dragon` | `Control[1]` | Sidestep Slash | 100 | `[692.1, 732.8, 182.9, 38.0]` |
| `dragon` | `Control[2]` | Frostbolt | 63 | `[743.4, 729.6, 182.2, 33.3]` |
| `dragon` | `Control[3]` | Molten Reach | 94 | `[794.8, 732.8, 182.9, 38.0]` |

Proof for the design owner. The PNG names are `qa107-deck-boss.png` and `qa107-deck-dragon.png`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-107 && QA107_PROFILE=deck QA107_STATE=boss QA107_HOVER='' python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1280x800 --proof-contract tools/qa107/proof-deck.json tools/qa107/layout_sweep.gd --task-id qa-107
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-107 && QA107_PROFILE=deck QA107_STATE=dragon QA107_HOVER='' python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1280x800 --proof-contract tools/qa107/proof-deck.json tools/qa107/layout_sweep.gd --task-id qa-107
```

### S2 · Deck Warband hand truncates Whirlwind Slash

At 115% UI scale in `warband`, the resting `HandBox/Control[2]/CardScaleFrame/CardWidget/Margin/VBox/TopRow/Title` label is `[743.8, 729.6, 181.4, 33.3]`. “Whirlwind Slash” measures 116 local units against 79.88 available. The 218 × 40 local box clips its single visible line horizontally and uses the ellipsis mode. The desktop Warband snapshot had no title overrun candidate.

Proof for the design owner. The PNG name is `qa107-deck-warband.png`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-107 && QA107_PROFILE=deck QA107_STATE=warband QA107_HOVER='' python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1280x800 --proof-contract tools/qa107/proof-deck.json tools/qa107/layout_sweep.gd --task-id qa-107
```

### S2 · Reach the Exit rule drops its last line

In `reach_exit`, `UiLayer/UiRoot/BattlefieldRuleHud/HBoxContainer[0]/VBoxContainer[1]/HBoxContainer[2]/RuleSentence` wraps the authored sentence to four lines at both scales. The 260 × 54 local box exposes three lines with a 73-unit content height and a three-line cap. This crops the end of “After each of your turns, a marked tile on your way out rises as an Outcrop unless something immovable is on it.” The Turn Order Upheaval tooltip opened with the complete sentence in both runs.

| Profile | Label rect | Visible / total lines |
| --- | --- | --- |
| Desktop | `[99.0, 450.4, 260.0, 54.0]` | 3 / 4 |
| Deck | `[98.0, 762.2, 260.0, 54.0]` | 3 / 4 |

Proof for the design owner. The PNG names are `qa107-desktop-reach_exit.png` and `qa107-deck-reach_exit.png`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-107 && QA107_PROFILE=desktop QA107_STATE=reach_exit QA107_HOVER='' python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tools/qa107/proof-desktop.json tools/qa107/layout_sweep.gd --task-id qa-107
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-107 && QA107_PROFILE=deck QA107_STATE=reach_exit QA107_HOVER='' python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1280x800 --proof-contract tools/qa107/proof-deck.json tools/qa107/layout_sweep.gd --task-id qa-107
```

### S3

No cosmetic finding remained after triage. The Character empty-slot textures and the drawn Character and Pre-battle close glyphs were intentional. The boss and tutorial overlay candidates intersected the unused width of left-aligned room labels. The Graftwright card inspection is a modal over the bench, and the Scavenger replaces the room HUD beneath it.

## Coverage

Desktop used 1920 × 1080 at 100% UI scale and a 1920 × 1080 logical viewport. Deck used 1280 × 800 at 115% and a 1669.57 × 1043.48 logical viewport. Each count below is an observed state or tooltip opening. The same source may occur in different states.

| States | States per profile | Desktop opens | Deck opens |
| --- | ---: | ---: | ---: |
| Title, title Settings, and title Chronicle | 3 | 0 | 0 |
| Start, map, menu, Settings, Gear, six Grimoire sections, and search | 13 | 215 | 203 |
| Pre-battle and pinned enemy inspection | 2 | 27 | 27 |
| Combat, three pile dialogs, both tutorial entries, boss, Guardian, dragon, Snare, Warband, Last Light, Ember Hoarder, Reach the Exit, and stocked combat | 15 | 253 | 272 |
| Rewards, campfire, and treasure | 3 | 19 | 19 |
| Character, stocked inventory, and all three tabs in both states | 8 | 185 | 173 |
| Scavenger and pack, Graftwright intro, bench and pickers, plus stocked pair and card inspection | 12 | 16 | 16 |
| Event choice and result | 2 | 1 | 1 |
| Victory, defeat, and their Chronicle overlays | 4 | 40 | 40 |
| **Total** | **62** | **756** | **751** |

Observed opens include hand and reward cards, owned and offered relics, Nail Bomb and other item pickups, enemy intent and Charge status, Battlefield rules, Grimoire controls, map rooms, Scavenger offers, Graftwright card rules, event choice details, and victory recap details. Campfire opened four shared HUD tooltips. Its choice controls produced hover feedback without a separate popup in the sampled state. Defeat had no score-detail popup in this fixture, and its Chronicle opened 19 tooltips at each scale.

At the sampled points, 65 desktop and 46 Deck candidates were shadowed by other input owners. A further 158 desktop and 154 Deck candidates reached a source with no new popup. Those totals include hover-emphasis callbacks. The raw witnesses distinguish empty triggers, non-empty triggers, successful opens, and shadowed input routes.

The census labels one state `guided_tutorial`, but its fixture builder completes the tutorial for timing. The supplemental `guided_tutorial_authored` uses the normal inspection fixture profile and verified the active authored prompt. Legacy Blacksmith and Arcanist room types migrate to the Scavenger and have no separate current merchant screen.

## Verification

The broad runs each completed 60 states before rejecting a supplemental enemy ID. The isolated fixture now uses the catalog's `storm_capacitor` ID. Focused replays covered the corrected fixture and the supplemental authored tutorial on both profiles. The witness audit verified that all 62 state names match across the two profiles and that each counted open produced a snapshot.

```text
QA107 RESULT: FAIL profile=desktop states=60 opened=719 candidates=8440 errors=1
QA107 RESULT: FAIL profile=deck states=60 opened=711 candidates=8523 errors=1
QA107 RESULT: PASS profile=desktop states=1 opened=22 candidates=0 errors=0
QA107 RESULT: PASS profile=deck states=1 opened=23 candidates=0 errors=0
QA107 RESULT: PASS profile=desktop states=1 opened=15 candidates=1 errors=0
QA107 RESULT: PASS profile=deck states=1 opened=17 candidates=0 errors=0
QA107 WITNESS AUDIT: PASS profile=desktop states=62 opened=756 shadowed=65 no_popup=158
QA107 WITNESS AUDIT: PASS profile=deck states=62 opened=751 shadowed=46 no_popup=154
QA107 GROUPER: PASS both profiles, six runs
QA107 PROOF CONTRACT: PASS deck 1280x800
QA107 PROOF CONTRACT: PASS desktop 1920x1080
```

The raw JSONL and command logs are in the local `output/qa107/broad/`, `output/qa107/combat-details/`, and `output/qa107/tutorial/` directories. The broad runs also emitted the macOS system certificate warning and existing Godot anchor-size warnings from the production right-column layout. Native captures remain pending with the design owner. The unit adds no permanent test modules.

## Chosen defaults

- Census seed 83. Fixtures use the existing Grimoire term “burn”, three Burn stacks, Nail Bomb, Crimson Draught, Pale Spark, Iron Lung, Ember Lens, Boiled Leather, and Glassbone Cuirass as test inputs.
- Layout settling uses 0.45 seconds plus eight frames and a four-second animation guard. Hover uses nine default sample points plus exposed hit regions, the configured Godot tooltip delay plus 0.10 seconds, and three final frames. Native capture is capped at 60 FPS.
- Geometry uses a two-unit tolerance, 12% overlap area threshold, and 2.5% alpha cutoff for suppressed presentation layers. The reducer gives its strongest horizontal clipping candidates S1 when under 10% of the measured width fits. Actual tooltip margins use the production constants.
- The broad headless runner allows 720 seconds for the hover census. Focused native replay allows 120 seconds for fixture initialization and capture.

No `TODO_DESIGN` placeholders were needed.
