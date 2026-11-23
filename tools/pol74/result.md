# pol-74 Scavenger inspection

The before run used `codex/pol-70` at `a753ba8a5d15ab03ae9887bab453ef7674229b8f`. The after run used the uncommitted `codex/pol-74` worktree. Both opened the production shop from RunScene at 1920×1080, 100% UI scale and `LABYRINTH_CEL_LOOK=all`. The table records headless visibility, content and transformed card width in viewport pixels. Native rendering is pending.

| Case | Before panel shown | Before panel content | Before card width | After panel shown | After panel content | After card width |
| --- | --- | --- | --- | --- | --- | --- |
| (a) Browse, Magic by mouse | No | — | — | Yes | Flashsteam title and card | 250 px |
| (b) Browse, same Magic by keyboard with mouse away | Yes | Flashsteam title and card, Buy | 250 px | Yes | Flashsteam title and card, Buy | 250 px |
| (c) Browse, Gear by mouse | No | — | — | Yes | Undertaker Plate title, Undertaker Stand card, 1/2 navigator to Grave Sprint | 250 px |
| (d) Browse, Item by mouse | No | — | — | Yes | Crimson Draught title and card | 250 px |
| (e) Sell, Gear by mouse | No | — | — | Yes | Undertaker Plate title, Undertaker Stand card, 1/2 navigator to Grave Sprint | 250 px |
| (f) Sell, Item by mouse | No | — | — | Yes | Crimson Draught title and card | 250 px |

Case (b) was stale. Keyboard focus already met the reading floor of 219 px. Browse still needed all three pointer cases. Godot created its default tooltip in each base hover case. Gear and Item previews match across Browse and Sell. Undertaker Plate's `+126` tag stays on the tile. The selected action reads “Sell.” Hover alone shows the preview. Leaving a ware without a selection hides the panel and leaving a different ware restores a click selection and its granted-card page. Keyboard and controller focus open the panel and retain the shop's existing selection and navigation behavior. The Magic shelf still uses its 177×248 box and the inspection panel uses its existing 250×352 card.

## Tooltip inventory

| Status | Surface | Text |
| --- | --- | --- |
| Removed | Affordable Browse Magic, Gear and Item wares | `<name>\nPrice: <price> Embers` |
| Removed | Sell wares, including the shared Magic tile path | `<name>\nSell value: <value> Embers` |
| Kept | Unaffordable Browse Magic, Gear and Item wares | `<name>\nPrice: <price> Embers — need <shortfall> more`. The exact shortfall appears here only. The zero-Ember fixture confirms `Flashsteam\nPrice: 175 Embers — need 175 more`. |
| Kept | Previous granted card | `Show the previous card granted by this gear.` |
| Kept | Next granted card | `Show the next card granted by this gear.` |
| Kept | Buy action | `Buy the selected ware.` or `You cannot afford this ware.` |
| Kept | Sell action | `Sell the selected owned ware.` |
| Kept | Leave | `Close the shop and return to the room's doors.` |
| Kept | Purge service | `Remove a spell from your deck.` or `You have no spells to purge.` |

The last six rows cover controls outside the ware tiles. The existing styled card keyword glossary and Shift-pinned inspection remain available. Shelf card descendants are pointer-passive and the keyword binding suppresses the card's individual native tooltip route. A headless geometry check found that the rightmost fixture spell, Dawnstep, opens the 250 px card while its existing glossary overlaps the upper face by about 197×121 px. The glossary uses its authored placement.

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/pol-74 && /private/tmp/labyrinth_codex/pol-74/native.sh
```

The launcher runs both revisions through the visual probe and task-local Godot runners. It checks each full frame at 1920×1080 and each 2× inspection crop at 840×1444. The PNGs are pending. The launcher prints each absolute path when the corresponding image is saved.

```text
/private/tmp/labyrinth_codex/pol-74/before/a_magic_hover.png
/private/tmp/labyrinth_codex/pol-74/before/a_magic_hover_panel_2x.png
/private/tmp/labyrinth_codex/pol-74/before/b_magic_focus.png
/private/tmp/labyrinth_codex/pol-74/before/c_gear_hover.png
/private/tmp/labyrinth_codex/pol-74/before/d_item_hover.png
/private/tmp/labyrinth_codex/pol-74/before/e_pack_gear_hover.png
/private/tmp/labyrinth_codex/pol-74/before/e_pack_gear_hover_panel_2x.png
/private/tmp/labyrinth_codex/pol-74/before/f_pack_item_hover.png
/private/tmp/labyrinth_codex/pol-74/after/a_magic_hover.png
/private/tmp/labyrinth_codex/pol-74/after/a_magic_hover_panel_2x.png
/private/tmp/labyrinth_codex/pol-74/after/b_magic_focus.png
/private/tmp/labyrinth_codex/pol-74/after/c_gear_hover.png
/private/tmp/labyrinth_codex/pol-74/after/d_item_hover.png
/private/tmp/labyrinth_codex/pol-74/after/e_pack_gear_hover.png
/private/tmp/labyrinth_codex/pol-74/after/e_pack_gear_hover_panel_2x.png
/private/tmp/labyrinth_codex/pol-74/after/f_pack_item_hover.png
```

The prior census reference was inspected at `/private/tmp/labyrinth_codex/pol-67/20261123T131016691207Z/1920x1080/64_scavenger_sell_hover.png` and at its 1280×800 counterpart. It shows the duplicated Undertaker Plate tooltip over the tile name with no inspection panel.

## Checks

| Command or probe | Observed result |
| --- | --- |
| `native.sh --dry-run before` | `POL74 SHOP READABILITY BEFORE: PASS` |
| `native.sh --dry-run after` | `POL74 SHOP READABILITY AFTER: PASS` |
| Focused `scavenger_shop_suite.gd` through a temporary harness | `SCAVENGER SHOP SUITE: PASS (5845 checks, 0 failures)` |
| `tests/scavenger_shop_probe.gd` on base | `SCAVENGER SHOP PROBE: PASS` |
| `tests/scavenger_shop_probe.gd` on the worktree | `SCAVENGER SHOP PROBE: FAIL` at the legacy `Sell ·` assertion. Exact line `ERROR: Sell drawer selection should produce one explicit Sell For action`. The probe continued through sale and reported no other assertion failures. |
| `tests/scavenger_shop_probe.gd -- --closed-shop-only` | `SCAVENGER CLOSED SHOP LIFETIME: PASS` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 4.893s` and `OK` |
| `python3 tests/test_rules_text_lint.py` | `Ran 3 tests in 0.082s`, `OK` and `PASS: Rules text lint (16 existing hits)` |

Raw logs are in `/private/tmp/labyrinth_codex/pol-74/`. The additional `cubby-probe.log` records all three Magic cubbies opening the panel and ends with `POL74 SHOP READABILITY AFTER: PASS`. The macOS headless runs logged certificate-store access errors. Local headless runs also logged missing generated burst-effect texture caches. The visual probe runner performs its normal import-cache check before native capture.

## Chosen defaults

- The proof uses seed 73491 and a 720-Ember wallet. The stock is Flashsteam, Icicle Lance, Dawnstep, Undertaker Plate, Dust Tabi, Duelist Rapier, Crimson Draught, Nail Bomb and Jaw Trap. Crimson Draught is in the pack and Undertaker Plate is added to the fixture inventory at the switch to Sell because owned Gear is excluded from Browse stock. A separate headless shortfall check uses a zero-Ember wallet.
- The proof uses neutral pointer position (600, 950) and waits 0.8 s after fixture entry and hover. The headless dry runs simulate 60 fps and the 2× crops use nearest-neighbor scaling. The native proof uses the runner's default timeouts of 8 s for startup and 30 s each for execution and the GUI lease.

## Open items

- Native screenshots and visual inspection require the design owner's windowed environment.
- The existing shop probe assertion at `tests/scavenger_shop_probe.gd:291` expects the old priced Sell label. It remains outside this unit's file ownership.
- No TODO_DESIGN placeholders were needed.
