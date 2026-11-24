# txt-38 verification

## 1. Corrected move text

| Creature and move | Before | After |
| --- | --- | --- |
| Burrow Grub, Erupt | `Erupt 6 · Push 1 · Rubble · Expose 2 · Self: Expose 2` | `Erupt 6 · Push 1 · Rubble · Self: Expose 2` |
| Wick Shade, Snuff | `Move 2 · Snuff refuge` | `Move 2 · Snuff brazier` |
| Last Lamplighter, Snuff | `Summon Wick Shade · Snuff refuge` | `Summon Wick Shade · Snuff brazier` |
| Gust Shrike, Dive | `Move 4 · Melee 4 · Push 1 · Along approach +1` | `Move 4 · Melee 4 · Push 1 · Within 1 of its path` |

The before and after Grimoire and pre-battle Known Moves controls displayed the strings above. The combat plate used the same revised chips. Erupt's special combat tooltip stayed `This enemy emerges on the Marked tile or the nearest open tile.` The previous combat plate carried a bare Expose 2, so it now labels the one Expose token `Self:`. The only other authored `self_expose` is Ashen Reaver's Executioner's Fall. Its row already printed one `Self: Expose 3` and matched before and after. [Erupt builder, lines 1313–1318](../../scripts/action_icon_library.gd#L1313) · [Self rider, lines 2185–2198](../../scripts/action_icon_library.gd#L2185)

The brazier flag also supplies a combat chip for Night Coil. That chip changed from `Snuff refuge` to `Snuff brazier` under the non-Eclipse rule. Its authored Grimoire and Known Moves line still says `puts out the nearest brazier`. The three brazier tooltips matched their before strings and referred to the correct moves. The saved `umbra_eclipse` branch still prints `Snuff before hit`. [Brazier builder, lines 2200–2215](../../scripts/action_icon_library.gd#L2200)

Dive's engine route was `(2, 4) → (3, 4) → (4, 4) → (5, 4) → (5, 5)`. The swept shape, live forecast and actual resolved impact shared 16 tiles. Five were on the route, 11 were one orthogonal tile away and zero were farther away. The hero lost 4 Health. Walls and line of sight filter the geometric area on obstructed boards. The chip reads `Within 1 of its path`. The combat tooltip changed from `Hits every tile within this distance of its path.` to the supplied template with `N = 1`, `Hits every tile within 1 tiles of its path.` Vaeloryx's Razor Dive uses a multi-tile body and a translated committed footprint, so its separate wording was retained and audited. [Swept path builder, lines 2123–2132](../../scripts/action_icon_library.gd#L2123) · [Swept geometry](../../scripts/committed_pattern_shapes.gd#L75)

## 2. Move row audit

[ROWS.md](ROWS.md) covers 44 creature pages and 137 move rows. It records 1,100 claims with source evidence, including 100 False, 1 UNTESTED and 999 True. Each row lists the base Time, generated tokens, their individual tooltip claims and any separately authored summary claims. False rows come first. The report inventories vocabulary outside the style guide, including legacy formatter labels that have no current catalog row.

The comparison found four changed Grimoire strings and 133 unchanged. It also checked seven live moves across Known Moves and combat. The only additional chip change was Night Coil's brazier label. The 26 txt-36 pages were loaded through a process-local Grimoire cache override from the ignored copy in `output/txt38/grimoire.json`. The production data files are untouched.

## 3. Grimoire list scroll

In the 44-page headless fixture, neither the mouse wheel nor dragging the scrollbar reached the Last Lamplighter after opening a page. The pointer selected Acolyte before the drag trial and Crawler before the wheel trial. Both selections left the visible scrollbar at maximum 2444 and page size 356. A drag began on the actual thumb, and the first wheel event was dispatched over the list. Both trials ended with maximum and page size at 0 and the bar hidden. The laid-out list and its minimum both remained 2444 px against a 356 px viewport.

The failure is a stale `ScrollContainer` range after the selection-driven browse rebuild. The page handler removes and recreates the list rows, then defers restoration of the old scroll position. The range looks valid until the first scroll input. A diagnostic `queue_sort()` restored the full 2,088 px usable range and the same drag reached the final creature. The precise internal notification that zeros the range remains unverified. Native wheel and thumb behavior are available in the capture probe. [Page selection](../../scripts/grimoire_panel.gd#L1420) · [List rebuild](../../scripts/grimoire_panel.gd#L580) · [Scroll restoration](../../scripts/grimoire_panel.gd#L1206) · [Scroll receipt](../../output/txt38/native.uVy59q/probe.log)

## Test and proof receipts

| Command or evidence | Exact result | Receipt |
| --- | --- | --- |
| `inventory.gd`, before and after | `TXT38 INVENTORY: PASS (44 creature pages, 137 move rows, 7 live controls)` | [Before](../../output/txt38/before.log) · [After](../../output/txt38/after.log) |
| `python3 -B tools/txt38/audit.py output/txt38/before.json output/txt38/after.json` | `TXT38 DIFF: PASS (137 rows, 4 changed page strings, 133 unchanged, 7 live controls)` · `TXT38 AUDIT: 137 rows, 100 False, 1 UNTESTED, 999 True claims` | [Log](../../output/txt38/audit.log) |
| `bash tools/txt38/native.sh --dry-run` | `TXT38 NATIVE PROBE: PASS (headless, 4 capture states)` | [Log](../../output/txt38/native.uVy59q/probe.log) |
| `python3 tests/test_rules_text_lint.py` | `Ran 3 tests in 0.056s` · `OK` · `PASS: Rules text lint (16 existing hits)` | [Log](../../output/txt38/rules-text.log) |
| `python3 tests/test_short_card_tooltips.py` | `Ran 5 tests in 0.018s` · `OK` | [Log](../../output/txt38/short-tooltips.log) |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 5.204s` · `OK` | [Log](../../output/txt38/ui-identity.log) |
| `python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir output/txt38/python` | `INPUT GROUP default: always run` · `SELECTED MODULES: 23 of 59` · `Ran 196 tests in 29.140s` · `OK` | [Log](../../output/txt38/python.log) |
| `tests/sta01_mechanics_test.gd` | `STA01 MECHANICS: PASS (42 checks; 0 failures)` | [Log](../../output/txt38/sta01-mechanics.log) |
| `tests/dragon_committed_patterns_test.gd` | `Dragon committed patterns passed.` | [Log](../../output/txt38/dragon-patterns.log) |
| `tests/dragon_feedback_mechanics_test.gd` | `Dragon feedback mechanics passed.` | [Log](../../output/txt38/dragon-feedback.log) |
| `tests/guardian_rules_test.gd` | `GUARDIAN RULES TEST RESULT: PASS (693 checks, 0 failures)` | [Log](../../output/txt38/guardian.log) |
| `tests/last_light_test.gd` | `Last Light suite: 0 failures` | [Log](../../output/txt38/last-light.log) |

All Godot receipts used `python3 tools/godot_task_runner.py --task-id txt-38 --stream -- godot --headless --path . --script <probe>`. The host emitted `Condition "ret != noErr" is true. Returning: ""` from the macOS certificate loader. The Python run completed with a permission notice when updating the shared timing cache under `.git`. No full suite ran.

## Proof for the design owner

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/txt-38 && bash tools/txt38/native.sh
```

The launcher uses `LABYRINTH_CEL_LOOK=all` and the visual runner with the 1920×1080 contract. The fixture uses 100% UI scale and the production combat scene. The run prints four PNG paths under `output/txt38/native.<run>/` and writes `captures.json` in the same directory. The headless dry run exercised all four capture states and produced no PNGs.

- `burrow_grub_moves_1920x1080.png`
- `wick_shade_moves_1920x1080.png`
- `gust_shrike_moves_1920x1080.png`
- `gust_shrike_dive_hover_1920x1080.png`

## Chosen defaults

- The native probe uses reduced motion to settle captures. The reused STA01 fight fixture supplies seed 41027, a 9×9 arena, the enemy at `(2, 4)` and the hero at `(6, 4)`.
- The Known Moves Wick Shade fixture puts a lit brazier at `(3, 4)`. The scroll probe waits eight layout frames and allows 0.35 seconds after selecting a page, eight thumb-drag steps and up to 180 wheel steps. The native hover probe samples every three pixels and allows two seconds for the tooltip to appear.

## Open issues

- Native renderer output and pointer behavior await the windowed run. Headless proof reproduced a scroll defect, and the audit lists the remaining text findings for the director. The literal Dive tooltip retains `1 tiles` from the approved template and says `every` despite blocking geometry, as recorded in the audit.
- No design placeholders were added. The worktree is on `codex/txt-38` at `38a6abf32`. All edits are uncommitted.
