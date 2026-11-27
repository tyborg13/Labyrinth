# crd-34 implementation and proof

## Requirements

1. `tooltip_entries_for_rows` pre-scans for a displayed Sweeping Strike damage token and suppresses the generic definition when the damage sentence supplies the target. Searing Light retains its glossary-only panel. [Builder, lines 605–664](../../scripts/action_icon_library.gd#L605)
2. Fire, Ice and Electrified selector templates use their glossary definitions through the existing `text: null` convention. The Light selector uses “An enemy starting a turn in Light gains Expose 2.” in both template fields. A card with a Light placement panel keeps that panel once, with its radius. The live probe checks all four selectors. [Ground templates, lines 229–252](../../data/card_panel_text.json#L229) · [Light witness and marker audit](result_1.md)
3. Empty Husk's inline target hover uses “Any of your visible Illusions on the board.” in both template fields. The engine rejected the click at `(6, 4)` while the Illusion was hidden and moved the hero to that tile when the Illusion was visible. [Template, lines 450–453](../../data/card_panel_text.json#L450)
4. Groundsplit's glossary and Grimoire both read “This enemy damages you if you stand within 2 tiles of an Outcrop this enemy raised.” The original witness measured 7 hero damage through distance 2 from either owned Outcrop, once in the overlapping area, and 0 at distance 3 or near only the foreign Outcrop. The expanded witness measured 7 damage to the hero, 0 to the Crawler and 7 to the player's Illusion at distance 1. [Definition, lines 487–492](../../data/glossary.json#L487) · [Groundsplit witness](result_1.md)
5. The before and after exports covered 309 IDs, including catalog, projected hand and supported legacy views. Only the five cards below changed. The face comparison matched all five. [Export and claim verifier](audit_report.py)

## Complete list of changed card hovers

Panel order follows the exported keyword stack. On both Light cards, the inline selector wording changes from **Each Enemy in Light** “Hit each visible enemy in Light.” to the one-line heading “An enemy starting a turn in Light gains Expose 2.” Empty Husk's changed inline panel also uses its one-line tooltip as the heading. Its hand stack still has **Swap Illusion** “Trade places with one of your illusions.” and **Block** “Give your Block to the Illusion as extra Health.”

| Card and surface | Before | After |
| --- | --- | --- |
| **Stoke** · keyword stack | **Sweeping Strike** — Hit each visible enemy that meets the named condition.<br>**Sweeping Strike** — Deal 2 damage to each enemy you can see.<br>**Fire** — A unit entering Fire takes 2 damage, and a unit starting on Fire takes 3. | **Sweeping Strike** — Deal 2 damage to each enemy you can see.<br>**Fire** — A unit entering Fire takes 2 damage, and a unit starting on Fire takes 3. |
| **White Silence** · keyword stack | **Ice** — Hit each visible enemy on Ice.<br>**Sweeping Strike** — Hit each visible enemy that meets the named condition.<br>**Sweeping Strike** — Deal 8 damage to each enemy you can see on Ice.<br>**Stagger** — Delay the target's next turn by 6 Time. | **Ice** — A unit entering Ice or starting a turn on Ice gains Expose 2.<br>**Sweeping Strike** — Deal 8 damage to each enemy you can see on Ice.<br>**Stagger** — Delay the target's next turn by 6 Time. |
| **Revealing Glare** · keyword stack | **Light** — Hit each visible enemy in Light.<br>**Range** — Only enemies within this distance of you.<br>**Expose** — The next hit that damages an Exposed unit deals 3 more damage.<br>**Draw** — Draw 1 card. | **Light** — An enemy starting a turn in Light gains Expose 2.<br>**Range** — Only enemies within this distance of you.<br>**Expose** — The next hit that damages an Exposed unit deals 3 more damage.<br>**Draw** — Draw 1 card. |
| **Searing Light** · keyword stack | **Light** — Hit each visible enemy in Light.<br>**Sweeping Strike** — Hit each visible enemy that meets the named condition. | **Light** — An enemy starting a turn in Light gains Expose 2.<br>**Sweeping Strike** — Hit each visible enemy that meets the named condition. |
| **Empty Husk** · inline target hover | Any of your illusions on the board. | Any of your visible Illusions on the board. |

## Groundsplit surfaces

| Surface | Observed copy and source |
| --- | --- |
| Glossary lookup | The Groundsplit icon lookup returns the new sentence. [Glossary](../../data/glossary.json#L487) |
| Craghide combat intent badge | The live badge uses the Groundsplit icon and shows 7. The expanded intent details use the move row's own sentence, “This enemy hits each floor tile within the shown distance of a surviving Outcrop.” [Badge renderer](../../scripts/combat_board_view.gd#L5705) · [Move row](../../scripts/action_icon_library.gd#L1595) |
| Known Moves | The live summary reads “Marked · Melee 7 · Each Outcrop · within 2.” The detail comes from the move row. [Known Moves builder](../../scripts/pre_battle_inspection_view.gd#L147) |
| Grimoire | Craghide's Moves section uses the shared move summary. The separate **Groundsplit** keyword page now matches the glossary sentence. [Creature moves](../../scripts/grimoire_creature_page.gd#L55) · [Keyword page](../../data/grimoire.json#L1066) |

## Receipts

Final exports, runtime receipts and test logs are in `/private/tmp/labyrinth_codex/crd-34/feedback1.PYpNkk/`. The original exporter matched `git show codex/crd-33:tools/crd33/dump_cards.gd` byte for byte. The frozen before export and the first implementation's receipts are in `/private/tmp/labyrinth_codex/crd-34/verify.w9215p/`. The runner loaded the original txt-37 witness from the sibling worktree because the txt-37 ref lacked that file. The expanded unit witness runs from crd-34.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/crd-34
scratch=/private/tmp/labyrinth_codex/crd-34/feedback1.PYpNkk
cp /private/tmp/labyrinth_codex/crd-34/verify.w9215p/before.json "$scratch/before.json"
python3 tools/godot_task_runner.py --task-id crd-34 --stream -- godot --headless --path . --script tools/crd33/dump_cards.gd -- "$scratch/after.json"
python3 tools/godot_task_runner.py --task-id crd-34 --stream -- godot --headless --path . --script tools/crd33/runtime_checks.gd -- "$scratch/runtime.json"
python3 tools/godot_task_runner.py --task-id crd-34 --stream -- godot --headless --path . --script /Users/borgerding/workspace/Labyrinth.worktrees/txt-37/tools/txt37/groundsplit.gd 2>&1 | tee "$scratch/groundsplit.log"
python3 tools/godot_task_runner.py --task-id crd-34 --stream -- godot --headless --path . --script tools/crd34/rules_witness.gd 2>&1 | tee "$scratch/rules-witness.log"
python3 -B tools/crd34/audit_report.py "$scratch"
python3 tools/godot_task_runner.py --task-id crd-34 --stream -- godot --headless --path . --script /private/tmp/labyrinth_codex/crd-34/verify.w9215p/groundsplit_surfaces.gd
python3 tests/test_rules_text_lint.py
python3 tests/test_card_panel_text.py
python3 tests/test_short_card_tooltips.py
python3 tests/text_budget_test.py
python3 tests/test_ui_identity_lint.py
GIT_OPTIONAL_LOCKS=0 python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir "$scratch/python-default"
bash tools/crd34/native.sh --dry-run
```

```text
CRD32 EXPORT: 309 catalog IDs; 9 source lists
CRD32 RUNTIME: 309 card IDs; 330 successful plays; 56 named scenarios; 45 sampled areas
CRD34 AUDIT: 309 IDs, 53 -> 52 distinct False rows, 0 new False
CRD34 DIFF: only empty_husk, revealing_glare, searing_light, stoke, white_silence hover copy changed
CRD34 TRUE empty_husk | Any of your visible Illusions on the board. | Native hover
CRD34 TRUE light | An enemy starting a turn in Light gains Expose 2. | Keyword and inline condition
CRD34 TRUE groundsplit | This enemy damages you if you stand within 2 tiles of an Outcrop this enemy raised. | Glossary
CRD34 TEMPLATES: 983 keyword panels checked, 0 unfilled markers
TXT37 GROUNDSPLIT: PASS (7 live resolutions)
CRD34 CONTROLS: PASS (4 selectors and glossary-only Sweeping Strike)
CRD34 HOVER stoke | 2 panels | 0 clip windows | [P: (940.12, 760.431), S: (306.0, 204.0)]
CRD34 HOVER white_silence | 3 panels | 1 clip windows | [P: (1106.52, 585.0), S: (306.0, 477.0)]
CRD34 HOVER sleet_squall | 5 panels | 2 clip windows | [P: (1272.92, 175.0), S: (306.0, 887.0)]
CRD34 INLINE HOVER empty_husk | Any of your visible Illusions on the board.
CRD34 HOVER empty_husk | 2 panels | 1 clip windows | [P: (1107.12, 673.931), S: (306.0, 361.0)]
CRD34 DRY RUN: PASS (1920x1080, 100% UI scale, 0 PNGs, 0 failures)
```

| Python check | Result |
| --- | --- |
| Rules text lint | `Ran 3 tests in 0.047s` · `OK` · `PASS: Rules text lint (16 existing hits)` |
| Card panel text | `Ran 4 tests in 0.004s` · `OK` |
| Short card tooltips | `Ran 5 tests in 0.011s` · `OK` |
| Text budget | `Ran 6 tests in 0.153s` · `OK` |
| UI identity lint | `Ran 25 tests in 3.853s` · `OK` |
| Baseline default group | `SELECTED MODULES: 23 of 59` · `Ran 196 tests in 33.081s` · `OK` |
| Final default group | `SELECTED MODULES: 23 of 59` · `Ran 196 tests in 26.829s` · `OK` |

The three snapshot tests now use the updated selector and Groundsplit copy. The Python runner reported a permission error writing its timing cache under the shared Git directory after the default group passed.

The headless dry run exited 0. The native screenshot contract remains pending for the design owner. [Dry-run log](/private/tmp/labyrinth_codex/crd-34/native.nidXv0/probe.log)

## Proof for the design owner

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/crd-34 && bash tools/crd34/native.sh
```

The command captures the real combat hand with `LABYRINTH_CEL_LOOK=all` at 1920×1080 and 100% UI scale. It prints one path per PNG under a fresh `/private/tmp/labyrinth_codex/crd-34/native.*/` directory and writes `manifest.json` there. Expected files are `stoke.png`, `white_silence.png`, `sleet_squall.png` and `empty_husk.png`. The probe waits for each hover's clip windows to have frame zero at full opacity, then waits for renderer submission before reading the viewport.

## Chosen defaults

- Reused crd-33's camera, board, enemy positions, Fire, Ice, reduced-motion configuration and layout settle. The Empty Husk shot uses a one-card hand with a visible fixture Illusion at `(4, 4)`, ID 41.
- The Empty Husk proof additionally renders the card's actual inline tooltip beside the hand card, 14 pixels to its left, at the maximum canvas depth. The hit-test and text use the production CardWidget. Text-fit checks use the existing 2-pixel tolerance.
- Proof clip windows hold frame zero for the screenshot and have a 5-second readiness bound per card.

## Files and open issues

- Production files are [action_icon_library.gd](../../scripts/action_icon_library.gd#L605), [card_panel_text.json](../../data/card_panel_text.json#L229), [glossary.json](../../data/glossary.json#L487) and [grimoire.json](../../data/grimoire.json#L1066). Snapshot values are in [txt20_rules_copy.json](../../tests/fixtures/txt20_rules_copy.json) and [pla02_grimoire_pages.json](../../tests/fixtures/pla02_grimoire_pages.json#L296).
- Proof files are [audit_report.py](audit_report.py), [capture.gd](capture.gd) and its UID, [native.sh](native.sh), [native_contract.json](native_contract.json), [rules_witness.gd](rules_witness.gd) and its UID, and both reports.
- The windowed captures remain pending. The marker audit also found pre-existing `X` values on generic legacy condition icons. No design placeholders. The changes are uncommitted on `codex/crd-34` at `c44334d0d`. [Legacy icon findings](result_1.md)
