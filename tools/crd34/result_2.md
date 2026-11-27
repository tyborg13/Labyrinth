# crd-34 round 2

The shared card hover checks the rendered face for the Sweeping Strike icon or words. Sentence faces use the same terms and icons that vrb-01 reads. When a card uses generated icon rows, including after an upgrade changes the face shape, the hover checks those rows. The remaining panels keep their order. [Hover builder](../../scripts/card_keyword_hover.gd#L39)

The release check enabled vrb-01's existing `sentence_panels` flag in memory for Stoke and White Silence on `c6d0e65fc`. Neither received a Ranged panel in the stack. Rockburst served as a control and produced **Ranged** “Deal 4 damage to a target within Range and line of sight.” Stoke and White Silence still have their existing native inline damage tooltips. The released Ranged icon carries the card's contextual sentence there, including Stoke's Fire bonus. [Release policy receipt](/private/tmp/labyrinth_codex/crd-34/round2.noIHen/release-policy.log)

## Complete release-to-final hover diff

The crd-33 exporter covered 309 card IDs across catalog, projected hand, and legacy starter views. These five cards are the complete diff against `c6d0e65fc`. Against the merged round-one checkout `9c1d5e713`, the only changes are removal of the remaining Sweeping Strike panel from Stoke and White Silence. [Export comparison](/private/tmp/labyrinth_codex/crd-34/round2.noIHen/compare.log)

| Card and surface | Release | Final |
| --- | --- | --- |
| **Stoke** · keyword stack | **Sweeping Strike** — Hit each visible enemy that meets the named condition.<br>**Sweeping Strike** — Deal 2 damage to each enemy you can see.<br>**Fire** — A unit entering Fire takes 2 damage, and a unit starting on Fire takes 3. | **Fire** — A unit entering Fire takes 2 damage, and a unit starting on Fire takes 3. |
| **White Silence** · keyword stack | **Ice** — Hit each visible enemy on Ice.<br>**Sweeping Strike** — Hit each visible enemy that meets the named condition.<br>**Sweeping Strike** — Deal 8 damage to each enemy you can see on Ice.<br>**Stagger** — Delay the target's next turn by 6 Time. | **Ice** — A unit entering Ice or starting a turn on Ice gains Expose 2.<br>**Stagger** — Delay the target's next turn by 6 Time. |
| **Searing Light** · keyword stack | **Light** — Hit each visible enemy in Light.<br>**Sweeping Strike** — Hit each visible enemy that meets the named condition. | **Light** — An enemy starting a turn in Light gains Expose 2.<br>**Sweeping Strike** — Hit each visible enemy that meets the named condition. |
| **Revealing Glare** · keyword stack | **Light** — Hit each visible enemy in Light.<br>**Range** — Only enemies within this distance of you.<br>**Expose** — The next hit that damages an Exposed unit deals 3 more damage.<br>**Draw** — Draw 1 card. | **Light** — An enemy starting a turn in Light gains Expose 2.<br>**Range** — Only enemies within this distance of you.<br>**Expose** — The next hit that damages an Exposed unit deals 3 more damage.<br>**Draw** — Draw 1 card. |
| **Empty Husk** · inline target hover, body only | Any of your illusions on the board. | Any of your visible Illusions on the board. |

Empty Husk's keyword stack contains **Swap Illusion** “Trade places with one of your illusions.” and **Block** “Give your Block to the Illusion as extra Health.” Searing Light retains its Sweeping Strike panel because its icon rows show the icon. [Final base export](/private/tmp/labyrinth_codex/crd-34/round2.noIHen/after.json)

### Upgraded cards

The release and final supplemental exports covered 1,877 first-step options across 285 IDs. All 27 variant differences belong to the same five cards. The table lists the affected copy for each set of upgrades. [Release upgrade export](/private/tmp/labyrinth_codex/crd-34/round2.noIHen/upgrades-release.json) · [Final upgrade export](/private/tmp/labyrinth_codex/crd-34/round2.noIHen/upgrades-after.json)

| Card and options | Release | Final |
| --- | --- | --- |
| **Stoke**, Damage +1, +2 or +3 | Generic **Sweeping Strike** plus **Sweeping Strike** “Deal 3 damage to each enemy you can see.”, “Deal 4 damage to each enemy you can see.”, or “Deal 5 damage to each enemy you can see.” | **Fire** only, with the same sentence as the base card. |
| **Stoke**, Add Move 1, Add Block 3 or Add Draw 1 | Generic **Sweeping Strike** plus **Sweeping Strike** “Deal 2 damage to each enemy you can see.” | The face falls back to icon rows and shows Sweeping Strike. The stack keeps “Deal 2 damage to each enemy you can see.” |
| **White Silence**, Damage +1, +2 or +3 | Generic **Sweeping Strike** plus **Sweeping Strike** “Deal 9 damage to each enemy you can see on Ice.”, “Deal 10 damage to each enemy you can see on Ice.”, or “Deal 11 damage to each enemy you can see on Ice.” The **Ice** sentence was “Hit each visible enemy on Ice.” | **Ice** and **Stagger** only, with the same sentences as the base card. |
| **White Silence**, Add Move 1, Add Block 3 or Add Draw 1 | Generic **Sweeping Strike** plus **Sweeping Strike** “Deal 8 damage to each enemy you can see on Ice.” The **Ice** sentence was “Hit each visible enemy on Ice.” | The face falls back to icon rows and shows Sweeping Strike. The stack keeps “Deal 8 damage to each enemy you can see on Ice.” and uses the final **Ice** sentence above. |
| **Searing Light**, all 6 options | **Light** — Hit each visible enemy in Light. | **Light** — An enemy starting a turn in Light gains Expose 2. Every option shows and retains the generic **Sweeping Strike** panel. |
| **Revealing Glare**, all 7 options | **Light** — Hit each visible enemy in Light. | **Light** — An enemy starting a turn in Light gains Expose 2. Its three damage options show and retain the generic **Sweeping Strike** panel. |
| **Empty Husk**, Add Block 3 or Add Draw 1 | Inline target hover — Any of your illusions on the board. | Inline target hover — Any of your visible Illusions on the board. |

The generic **Sweeping Strike** sentence is “Hit each visible enemy that meets the named condition.”

## Template markers after the release merge

No standalone `X`, brace placeholder such as `{r}`, or unexpanded `%s`, `%d` or `%f` appeared in the native condition-icon path. Release and final each had 47 rendered `SurfaceCondition` groups on 47 cards, with zero unresolved markers. The catalog, hand and legacy snapshots also returned zero native condition markers. The merged renderer routes these condition explanations through the keyword stack. [Condition control receipt](/private/tmp/labyrinth_codex/crd-34/round2.noIHen/upgrades-after.log)

The native export still contains pre-existing raw `X` in the following ordinary inline tooltips. Those tooltip strings were outside the condition-icon change in release. The keyword stacks had zero unresolved markers.

| Panel | Cards with a raw `X` in the native export |
| --- | --- |
| Light | Cinderburst, Guiding Flare, Lantern Shot, Seek the Light, Shattered Reflection, Spark Dart, Storm Beacon |
| Stagger | Rite of Hoarfrost |
| Expose | Serrated Slip, Skate |
| Illusion | Shattered Reflection |

## Verification

```text
CRD32 EXPORT: 309 catalog IDs; 9 source lists
CRD32 RUNTIME: 309 card IDs; 330 successful plays; 56 named scenarios; 45 sampled areas
CRD34 AUDIT: 309 IDs; 57 frozen False, 47 release False, 46 merged False, 46 final False; 0 new False
CRD34 UPGRADE DIFF: 1877 options across 285 IDs; 27 differences on the same five IDs
CRD34 FACE CONTROLS: words=true, two damage upgrades=false, damage and added Move=true
CRD34 NATIVE CONDITION MARKERS: release 0, merged 0, final 0
PASS: Rules text lint (16 existing hits)
Ran 5 tests in 0.011s
OK
Ran 25 tests in 4.502s
OK
GLOSSARY TEST RESULT: PASS (6166 checks, 0 failures)
VRB01 PANEL AND GRIMOIRE CHECKS: 3538 checks, 0 failures
TEST RESULT: PASS
CRD34 DRY RUN: PASS (1920x1080, 100% UI scale, 0 PNGs, 0 failures)
```

The merged baseline Glossary check reported `GLOSSARY TEST RESULT: FAIL (6170 checks, 4 failures)` from the old Stoke and White Silence panel count and order pins. The focused fixture now expects Fire for Stoke and Ice followed by Stagger for White Silence. [Snapshot values](../../tests/fixtures/approved_glossary_structure.gd#L72)

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/crd-34
scratch=/private/tmp/labyrinth_codex/crd-34/round2.noIHen
release=/Users/borgerding/workspace/Labyrinth.worktrees/release
python3 tools/godot_task_runner.py --task-id crd-34 --stream -- godot --headless --path "$release" --script tools/crd33/dump_cards.gd -- "$scratch/release-before.json"
python3 tools/godot_task_runner.py --task-id crd-34 --stream -- godot --headless --path . --script tools/crd33/dump_cards.gd -- "$scratch/after.json"
python3 tools/godot_task_runner.py --task-id crd-34 --stream -- godot --headless --path . --script tools/crd33/runtime_checks.gd -- "$scratch/runtime.json"
python3 tools/godot_task_runner.py --task-id crd-34 --stream -- godot --headless --path "$release" --script "$scratch/release_policy.gd"
python3 tools/godot_task_runner.py --task-id crd-34 --stream -- godot --headless --path "$release" --script "$scratch/variants.gd" -- "$scratch/upgrades-release.json"
python3 tools/godot_task_runner.py --task-id crd-34 --stream -- godot --headless --path . --script "$scratch/variants.gd" -- "$scratch/upgrades-after.json"
python3 tools/godot_task_runner.py --task-id crd-34 --stream -- godot --headless --path . --script "$scratch/face_controls.gd"
python3 -B "$scratch/compare.py" "$scratch"
python3 tests/test_rules_text_lint.py
python3 tests/test_short_card_tooltips.py
python3 tests/test_ui_identity_lint.py
python3 tools/godot_task_runner.py --task-id crd-34 --stream -- godot --headless --path . --script tests/glossary_test.gd
python3 tools/godot_task_runner.py --task-id crd-34 --stream -- godot --headless --path . --script tools/vrb01/panel_check.gd
bash tools/crd34/native.sh --dry-run
```

## Proof for the design owner

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/crd-34 && bash tools/crd34/native.sh
```

The command prints `stoke.png`, `white_silence.png`, `sleet_squall.png`, and `empty_husk.png` under a fresh `/private/tmp/labyrinth_codex/crd-34/native.*/` directory. Windowed captures are pending. The proof keeps the round-one fixture and checks Empty Husk's tooltip body, as rendered by the merged native tooltip panel. [Dry-run log](/private/tmp/labyrinth_codex/crd-34/native.1b0g8n/probe.log)

Round-two edits are the [hover builder](../../scripts/card_keyword_hover.gd#L39), [snapshot fixture](../../tests/fixtures/approved_glossary_structure.gd#L72), [native probe](capture.gd), and this report. The test-only face controls use an in-memory sentence with the words “Sweeping Strike,” two Damage +1 upgrades, and a Damage +1 paired with Add Move 1. No design placeholders. The work remains uncommitted on `codex/crd-34`.
