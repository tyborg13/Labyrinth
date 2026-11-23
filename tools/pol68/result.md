# pol-68 Steam Deck layout proof

## 1. Shipping scaling path

At 1280×800 the census attaches the game scene directly to the shipping root Window. Godot reads `canvas_items` and `expand` from the game project. The probe sets the output size and loads the requested UI scale through the isolated settings store. The headless and macOS paths use the same Window calculation and input coordinates. The director's 1920×1080 captures also use that path.

| Output | UI scale | Logical viewport from Godot | Canvas stretch |
| --- | ---: | ---: | ---: |
| 1280×800 | 100% | 1920 × 1200 | 0.6666667 |
| 1280×800 | 115% | 1669.5653 × 1043.4783 | 0.7666667 |
| 1920×1080 | 100% | 1920 × 1080 | 1.0 |

The geometry comparison checks all recorded title and combat Control edges against the real 1280×800 captures at 115%, with a 1 px limit on each edge. The headless measurements are available. The macOS captures and the comparison against them remain pending a desktop session.

## 2–3. Deck findings and layout

The table shows `[x, y, width, height]` in output pixels. For each row the base and pol-68 rectangles match to the precision shown. The scope for the viewport check is the flagged foreground surface. The legacy `layout_hits` records use logical Control pixels under Window stretch. The `control_rects` and `dialogue_paint_rects` records are in output pixels. Raw hit records include board layers, scroll content, full-screen scrims and transparent texture regions.

| Screen and Control | 100%, before = after | 115%, before = after | Finding |
| --- | --- | --- | --- |
| Title and New Run loading, `MenuColumn` | [48.00, 258.40, 281.60, 358.67] | [51.20, 287.87, 291.33, 412.47] | Artifact at both scales |
| Title and New Run loading, `QuitButton` | [48.00, 565.07, 281.60, 52.00] | [51.20, 640.53, 291.33, 59.80] | Artifact at both scales |
| Pre-battle, `PreBattleFrame` | [220.67, 116.00, 838.67, 566.99] | [157.17, 73.60, 964.47, 652.04] | Artifact at both scales |
| Opening dialogue, `DialogueDialog` | [126.67, 636.00, 1000.00, 146.67] | [49.67, 611.40, 1150.00, 168.67] | Horizontal artifact at both scales. Bottom paint finding below |
| Character, `EquipmentLoadoutList` | [156.00, 236.67, 280.00, 378.67] | [82.80, 211.60, 322.00, 435.47] | Artifact at both scales. The existing scroll view contains the list |
| Hearth, choice row | [212.00, 608.00, 856.00, 146.67] | [147.58, 578.83, 984.40, 168.67] | Artifact at both scales |

The flagged title, loading, pre-battle, Character and Hearth surfaces report zero `outside_viewport` hits at both scales. Their measured rectangles satisfy the 16 px margin. No spacing change is needed for them.

The dialogue frame, text and visible portrait fit. The portrait's texture Control starts at x = −73.00 px at 115%. After applying the texture alpha and the bust shader's frame window, its painted left edge is x = 97.97 px. The painted portrait is `[168.67, 566.67, 222.67, 200.00]` at 100% and `[97.97, 531.67, 256.07, 230.00]` at 115%.

| Dialogue paint | 100%, before = after | 115%, before = after |
| --- | --- | --- |
| Ink band | [157.33, 636.00, 959.33, 163.33] | [84.93, 611.40, 1103.23, 187.83] |
| Portrait shadow | [145.33, 590.67, 280.00, 210.67] | [71.13, 559.27, 322.00, 242.27] |

`TODO_DESIGN_dialogue_deck` records the shadow's 1.33 px and 1.53 px painted bottom overflow and the band’s 15.33 px and 15.23 px shortfall against the required bottom inset. The band and shadow follow a bottom-seated composition. Shrinking the authored vertical inset seats the paint closer to the edge, and the affected surface has no scroll list. The dialogue retains its authored layout under the brief's stop rule. [Placeholder data](design_todos.json)

The 1920×1080 before/after comparison matched 2,391 Control paths across the ten scoped shots. The UI edges matched exactly outside the two required badge subtrees. The largest movement under the settling board camera was 0.0008 px. The comparator reported `RECT COMPARISON: PASS; 0 mismatches`.

## 4. Top-bar badges

Both labels now use 14 px. The existing font-metric fitting preserves 1 px left and right padding, 4 px top padding and 5 px bottom padding. Each badge grows by 1 px in width and 2 px in height for the measured digits. The registered top and right edges stay fixed.

| Badge at 1920×1080 | Before | After | Top-right anchor |
| --- | --- | --- | --- |
| Grimoire | [1813, 9, 20, 23] | [1812, 9, 21, 25] | [1833, 9] |
| Loadout | [1738, 9, 19, 23] | [1737, 9, 20, 25] | [1757, 9] |

- Base fixture, `CENSUS RESULT: PASS; 1/1 shots succeeded; 0 capped`. [Manifest](/private/tmp/labyrinth_codex/pol-68/badges-before/manifest.json)
- Updated fixture, `CENSUS RESULT: PASS; 1/1 shots succeeded; 0 capped`. [Manifest](/private/tmp/labyrinth_codex/pol-68/badges-after/manifest.json)

## 5. Large-map room hit areas

On the scrolling map, the actual button hit test is a circle with the room's visual radius plus 10 logical px. The 122×122 bounds in the old census are the Controls' allocation. The map probe checked the census seed's first section using the production room panels and `_has_point`, for travel and Scout targeting in revisions 7 and 6. At both still and peak pulse, it found no point where one seal is drawn and the button that would win can activate a different room. Classified as a geometric overlap artifact for the tested configuration.

- `MAP HIT PROBE: no misrouted activation in revisions 7 and 6; pulse peak=false; 105 overlapping pairs, 113626 sampled points`. [Log](/private/tmp/labyrinth_codex/pol-68/map-still-final.log)
- `MAP HIT PROBE: no misrouted activation in revisions 7 and 6; pulse peak=true; 105 overlapping pairs, 113626 sampled points`. [Log](/private/tmp/labyrinth_codex/pol-68/map-peak-final.log)

## Proof for the design owner

Run in a logged-in macOS session. The launcher prints its output root and writes separate folders for the baseline Deck, updated Deck and updated desktop PNGs. It takes the title, New Run confirmation, depth picker, loading cover, both opening dialogue paths, pre-battle, Character, Hearth and combat shots. It validates exact PNG dimensions and visible image content through the visual runner, then compares the title and combat geometry against the headless shipping Window. The baseline defaults to the prepared sibling checkout on `codex/pol-67`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-68 && /private/tmp/labyrinth_codex/pol-68/native.sh
```

Capture both badges in one desktop frame for the UI identity review.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-68 && LABYRINTH_CEL_LOOK=all python3 tools/scn01/census.py --root-window --rects --no-contact-sheet --size 1920x1080 --plan tools/pol68/badge_shot.json
```

## Headless census

The launcher's final dry run exited 0. Every scoped batch reported `CENSUS RESULT: PASS; 10/10 shots succeeded; 0 capped`. The Deck foreground audit reported `DECK FOREGROUND RECT COMPARISON: PASS` with 301 identical scoped Control rectangles at each scale and zero outside-viewport hits in those scopes. The native batch wrapper also ran one base title shot with the headless display. [Launcher log](/private/tmp/labyrinth_codex/pol-68/director-final.log) · [Deck check](/private/tmp/labyrinth_codex/pol-68/deck-rects-final.log) · [Batch route log](/private/tmp/labyrinth_codex/pol-68/native-batch-headless/title.log)

| Output and UI scale | Before manifest | After manifest |
| --- | --- | --- |
| 1280×800, 100% | [Base](/private/tmp/labyrinth_codex/pol-68/director-final/before-1280x800-100/manifest.json) | [Task](/private/tmp/labyrinth_codex/pol-68/director-final/after-1280x800-100/manifest.json) |
| 1280×800, 115% | [Base](/private/tmp/labyrinth_codex/pol-68/director-final/before-1280x800-115/manifest.json) | [Task](/private/tmp/labyrinth_codex/pol-68/director-final/after-1280x800-115/manifest.json) |
| 1920×1080, 100% | [Base](/private/tmp/labyrinth_codex/pol-68/director-final/before-1920x1080-100/manifest.json) | [Task](/private/tmp/labyrinth_codex/pol-68/director-final/after-1920x1080-100/manifest.json) |

## Focused checks

- `TEST RESULT: PASS — main menu input and startup transitions`. [Log](/private/tmp/labyrinth_codex/pol-68/focused/main_menu_input_test.log)
- `TEST RESULT: PASS — main menu resume safety`. [Log](/private/tmp/labyrinth_codex/pol-68/focused/main_menu_resume_test.log)
- `PRE-BATTLE VIEW TEST: PASS`. [Log](/private/tmp/labyrinth_codex/pol-68/focused/pre_battle_view_test.log)
- `COMBAT HUD DIALOGUE INPUT TEST: PASS`. [Log](/private/tmp/labyrinth_codex/pol-68/focused/combat_hud_dialogue_input_test.log)
- `TEST RESULT: PASS Ember Hearth visual and input sequence`. [Log](/private/tmp/labyrinth_codex/pol-68/focused/campfire_choice_probe.log)
- `COMBAT HUD BADGES TEST: PASS`. [Log](/private/tmp/labyrinth_codex/pol-68/focused/combat_hud_badges_test.log)
- `Section map v5 suite: 0 failures`. [Log](/private/tmp/labyrinth_codex/pol-68/focused/section_map_v5_test.log)
- UI identity lint, `Ran 25 tests in 8.438s`, `OK`. [Log](/private/tmp/labyrinth_codex/pol-68/ui-identity.log)
- Windows typed arrays, `TYPED ARRAY SCAN: 6 scripts; 0 new; 5 pre-existing`. [Log](/private/tmp/labyrinth_codex/pol-68/typed-arrays-final.log)
- Python default, `INPUT GROUP default: always run`, `Ran 196 tests in 48.182s`, `OK`. Rules text lint reported `PASS: Rules text lint (16 existing hits)`. The optional timing-cache write under shared Git metadata was denied after the tests passed. [Log](/private/tmp/labyrinth_codex/pol-68/python-default.log)

## Open issues

- `pre_battle_deck_fit_probe.gd` reports `TEST RESULT: FAIL Card strips must retain the typography floor` on this branch, the baseline and master. All three runs then reached the 300-second headless watchdog. [Task](/private/tmp/labyrinth_codex/pol-68/focused/pre_battle_deck_fit_probe.log) · [Baseline](/private/tmp/labyrinth_codex/pol-68/focused/pre_battle_deck_fit_base.log) · [Master](/private/tmp/labyrinth_codex/pol-68/focused/pre_battle_deck_fit_master.log)
- The Character review probe reports `ERROR: Character uses the shared close socket` on this branch and its baseline. Master reports `CHARACTER REVIEW FIXES: PASS`. [Task](/private/tmp/labyrinth_codex/pol-68/focused/character_review_fixes_probe.log) · [Baseline](/private/tmp/labyrinth_codex/pol-68/focused/character_review_base.log) · [Master](/private/tmp/labyrinth_codex/pol-68/focused/character_review_master.log)
- Native captures and the title/combat comparison require the director's window server. The headless run emits manifests and logs.
- Some headless logs report missing imported effect textures in the task cache. The layout snapshots reached their state checks. The native visual runner prepares the project's import cache before rendering.

## Chosen defaults

- The census retains seed 7262026. The badge fixture carries one unread `undertaker_plate`, using the existing inventory and unread fixture flags.
- The map audit samples at 1 logical px on the census seed and checks a still seal and peak pulse.
- With rectangle proof enabled, the probe waits for complete dialogue text. The continuously bobbing dialogue diamond is omitted from rectangle comparison.
- The desktop comparison requires exact UI rectangles and allows 0.001 px for Controls under the independently settling board camera. The two requested badge subtrees are reported above.
- The native batch uses a luma range of 8 as its image sanity floor, in addition to state checks and exact framebuffer sizes.
