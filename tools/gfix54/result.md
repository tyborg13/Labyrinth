# gfix-54 condition-icon hovers

## 1. Release receipt and reachability

The first scan used the untouched production files at `e3b27e209`, the shared HEAD of `codex/release` and `codex/gfix-54`. It replayed crd-34's distinct card/icon marker check over catalog, projected hand and legacy card views. It also queried the native-enabled CardWidget at each affected icon's center.

The icon's `MOUSE_FILTER_IGNORE` lets the CardWidget own the pointer. The CardWidget walks the summary controls by geometry and reads their tooltip properties without testing their mouse filters. On release it read `ActionIcons.tooltip(condition_icon)`, which asks the glossary for a template without a value. The icon's `tooltip_loop_route` recorded the term and icon for popup rendering. It still returned the stored text. Interactive pinned card and equipment previews can take this route. The combat hand disables native icon tooltips and routes pointer and controller focus to its keyword column. The receipt confirmed the enabled query returned the placeholder for all twelve icons and the disabled query returned an empty string. [Widget query](../../scripts/card_widget.gd#L778) · [Pinned inspection](../../scripts/run_scene.gd#L4880) · [Interactive card preview](../../scripts/item_preview_builders.gd#L121) · [Hand configuration](../../scripts/run_scene.gd#L16415) · [Release scan](../../output/gfix54/release-scan.log)

| Release native title and body | Cards |
| --- | --- |
| Light · Light reveals within X tiles for the rest of combat and gives enemies starting in Light Expose 2. | Blinding Bash, Dazzle, Hallowed Strike, Revealing Glare, Searing Light, Sunlance |
| Move · Walk up to X tiles. | Couched Lance, Headlong, Iron Wheel |
| Stagger · Delay the target's next turn by X Time. | Hobnail Drive |
| Retaliate · Until the holder's next turn, melee hits and hits from adjacent tiles deal X damage back. | Reflected Threat |
| Illusion · A decoy with X Health that enemies target when at least as close as you. | Refraction |

## 2. Condition-icon copy

The condition icon uses the same copy selection and amount filling as the keyword panel and carries the token's term and icon for tooltip-loop routing. Headlong resolves the shared Move panel from its live rows, so the movement range comes from the Move action. If a projected variant lacks that action, the rider already has authored Next Attack copy. The keyword panels retain their existing content and behavior. [Shared copy](../../scripts/action_icon_library.gd#L655) · [Headlong token](../../scripts/action_icon_library.gd#L1857) · [Widget icon](../../scripts/card_widget.gd#L2036)

| Cards | Resolved native hover body |
| --- | --- |
| Blinding Bash, Dazzle, Hallowed Strike, Sunlance | This bonus applies if the target stands in Light. |
| Revealing Glare, Searing Light | Hit each visible enemy in Light. |
| Couched Lance, Iron Wheel | Deal +1 damage per tile you moved this turn, up to +5. |
| Headlong | Walk up to 4 tiles. |
| Hobnail Drive | This bonus applies if the target's next turn is Staggered. |
| Reflected Threat | Enemies that damage this Illusion take the same damage. |
| Refraction | This attack also hits each other enemy adjacent to one of your Illusions once. |

## 3. Native hover capture

The historical txt-38 and txt-41 PNGs show the expanded intent on the real board and no tooltip. Both probes injected motion into a standalone SubViewport without a pointer-entry notification. The headless replay held the pointer on the matching Crushing Step chip for the original two seconds. The board owned the pointer and returned its damage text, but both the capture viewport and the root had zero embedded windows. Re-entering the same point after `notify_mouse_entered()` opened the popup in the capture viewport. The historical child-label search also lacked checks for the actual popup's visibility, embedding and bounds. Godot parents the tooltip popup to its owner and registers it with its embedding viewport. [txt-38 PNG](../../../txt-38/output/txt38/native.qGwqfS/gust_shrike_dive_hover_1920x1080.png) · [txt-41 PNG](../../../txt-41/output/txt41/native.bBd56E/warden_crushing_step_hover_1920x1080.png) · [Godot 4.6.1 tooltip implementation](https://github.com/godotengine/godot/blob/4.6.1-stable/scene/main/viewport.cpp#L1475-L1584)

The helper sends one motion at the prepared point, leaving the pointer there through the capture. It polls the capture viewport's embedded subwindows for a visible `TooltipPanel` owned by the actual hovered control. It checks that the popup has nonzero bounds entirely inside the viewport and that a visible label inside it carries the expected line. It rechecks the popup after a rendered frame before saving the viewport's own pixels. The headless path runs the same input and popup checks and prints the planned PNG paths. [Native hover helper](native_hover.gd) · [Proof fixture](native_probe.gd) · [Proof contract](native_contract.json)

The two cards are in the real combat hand. The probe enables the existing native CardWidget path on each witness for its capture, after checking that the production hand defaults to the keyword stack and the icon matches the stack's sentence.

The Warden witness points at the live damage token from the area action in Crushing Step. This release still reports `Deal 6 damage to an adjacent target or a target within the card's Range.` The probe reads the live token and its hit region, so the same launcher uses `Deal 6 damage in this attack's area.` once the separately owned txt-41 change is integrated.

## Receipts

| Check | Exact result | Log |
| --- | --- | --- |
| Release scan | `GFIX54 CONDITION SCAN: PASS (release, 309 cards, 98 rendered condition icons, 12 distinct card/icon placeholders, 12 hover receipts)` | [Release scan](../../output/gfix54/release-scan.log) |
| Branch scan | `GFIX54 CONDITION SCAN: PASS (branch, 309 cards, 98 rendered condition icons, 0 distinct card/icon placeholders, 12 hover receipts)` | [Branch scan](../../output/gfix54/branch-scan.log) |
| Native dry run | `GFIX54 NATIVE PROBE: PASS (headless, 3 embedded popup states)` | [Native dry run](../../output/gfix54/native.R1vwS4/probe.log) |
| `tests/card_panel_text_test.gd` | `CARD PANEL TEXT TEST RESULT: PASS (2210 definitions, 7772 panels, 15773 checks, 0 failures)` | [Card panel text](../../output/gfix54/card-panel-text.log) |
| `tests/short_card_tooltips_test.gd` | `SHORT CARD TOOLTIPS TEST RESULT: PASS (707 checks, 0 failures)` | [Short card tooltips](../../output/gfix54/short-card-tooltips.log) |
| `tests/card_display_overrides_test.gd` | `CARD DISPLAY OVERRIDES TEST RESULT: PASS (16744 checks, 0 failures)` | [Card display overrides](../../output/gfix54/card-display-overrides.log) |
| `tests/board_tile_tooltip_route_test.gd` | `BOARD TILE TOOLTIP ROUTES: PASS (12 capture states; real X input; native popup layout; headless, no pixels)` | [Board tooltip route](../../output/gfix54/board-tile-tooltip-route.log) |
| `python3 tests/test_rules_text_lint.py` | `Ran 3 tests in 0.054s` · `OK` · `PASS: Rules text lint (16 existing hits)` | [Rules text lint](../../output/gfix54/rules-text.log) |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 4.655s` · `OK` | [UI identity lint](../../output/gfix54/ui-identity.log) |
| Python default group | `INPUT GROUP default: always run` · `SELECTED MODULES: 23 of 59` · `Ran 196 tests in 28.771s` · `OK` | [Python default](../../output/gfix54/python-default.log) |

The card panel and short tooltip tests returned the same result on release. The task runner returned exit 0 for the card display check. Godot printed an ObjectDB/resource cleanup diagnostic after its passing result. Some headless runs also emitted a macOS certificate loader diagnostic. The Python runner completed its isolation audit and default group, then reported that the sandbox prevented a timing cache write under Git metadata. No Godot full suite ran.

All Godot receipts used the task-local runner. To replay the branch scan:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-54 && python3 tools/godot_task_runner.py --task-id gfix-54 --stream -- godot --headless --path . --script tools/gfix54/condition_scan.gd
```

The release scan used the same command with `-- --release` before the production files changed.

## Proof for the design owner

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/gfix-54 && bash tools/gfix54/native.sh
```

The launcher uses `LABYRINTH_CEL_LOOK=all`, 1920×1080, and 100% UI scale. It prints the three PNG paths on separate lines and writes `captures.json` and `probe.log` in a fresh `output/gfix54/native.<run>/` directory.

- `revealing_glare_light_hover_1920x1080.png`
- `couched_lance_move_hover_1920x1080.png`
- `warden_crushing_step_hover_1920x1080.png`

The dry run reached all three real popup states and printed planned paths in `output/gfix54/native.R1vwS4/`. Windowed renderer inspection remains pending on the design owner's host. The correct Crushing Step wording requires the txt-41 integration.

## Chosen defaults

- The proof reuses the STA01 arena, seed 41027, Warden at `(2, 4)`, hero at `(6, 4)`, reduced motion, and the existing pre-battle fixture's settle interval. The 250×352 catalog audit card uses crd-32's size.
- The proof parks the pointer at `(4, 4)` between captures and samples the board's existing intent hit regions in 3 px steps. The helper allows 2 seconds for the real popup, and the legacy replay uses the earlier probes' 2 second wait.

There are no design placeholders. Implementation and proof files are uncommitted on `codex/gfix-54`.
