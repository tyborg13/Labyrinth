# crd-33 verification

## 1. Damage hovers

`ActionIconLibrary` in [action_icon_library.gd](../../scripts/action_icon_library.gd) builds the hover from the effective damage amount and target selector. The relevant lines are 643–653 for keyword panels, 735–751 for tooltip text, 1913–1953 for damage targets, and 2099–2118 for the surface bonus. `CardWidget` in [card_widget.gd](../../scripts/card_widget.gd) carries the token's copy to inline damage icons at lines 1602–1619 and 1658–1675.

| Card | Before | After |
| --- | --- | --- |
| Stoke, base hit | Deal 2 damage to a target within Range and line of sight. | Deal 2 damage to each enemy you can see. |
| Stoke, bonus icon hover | Deal 3 damage to a target within Range and line of sight. | On Fire: +3 damage. |
| White Silence | Deal 8 damage to a target within Range and line of sight. | Deal 8 damage to each enemy you can see on Ice. |
| Sleet Squall, follow-up hit | Deal 3 damage to a target within Range and line of sight. | Deal 3 damage to the target. |

Stoke's Fire bonus hover now repeats the existing Fire bonus line from its face. The card export compared all 309 IDs, including catalog, projected hand and supported legacy views. The four rows above are True and no other card's export changed. Every other hover sentence on the three cards and the three card faces matched the baseline. The full audit matched the 57 frozen crd-32 False rows before the fix and found 53 after, with zero new False rows.

The rule covers unbounded visible and visible-on-Ice strikes, and direct damage that reuses the previous target. An inherited aim tile is an origin for an area or Burst, as with Cyclone Seal and Rockburst. Their area and Burst damage select their own victims.

```text
CRD32 WITNESS sleet_squall {"clicked":"(5, 4)","damage":3,"distance_at_hit":5,"enemy_after_push":"(7, 4)","hero":"(2, 4)"}
CRD32 WITNESS white_silence {"blocking_wall":"(4, 4)","damage":8,"enemy":"(7, 4)","hero":"(2, 4)","line_of_sight":false,"selector_control":{"damage":[8,0,0],"ice":["(3, 4)","(7, 4)"],"visible":[true,true,false]}}
CRD32 WITNESS stoke {"damage":[2,5],"enemies":["(7, 4)","(7, 5)"],"fire":["(7, 5)"],"hero":"(2, 4)","line_of_sight":[false,false],"selector_control":{"damage":[2,0],"ice":[],"visible":[true,false]}}
```

## 2. Skybolt and Empty Husk

- **Skybolt.** Zekarion is immune to Shock. The same conducted hit did 8 damage in both fixtures. The Crawler control gained Shock 1 and Zekarion gained Shock 0. Zekarion's status plate has an **Immune** trait chip with the hover “This enemy is immune to Shock.” The Grimoire renders the same sentence under Traits on Zekarion's page. [Enemy definition](../../data/enemies.json#L1608) · [Shock application](../../scripts/combat_engine.gd#L6725) · [Status plate](../../scripts/combat_board_view.gd#L17774) · [Grimoire traits](../../scripts/grimoire_creature_page.gd#L42)
- **Empty Husk.** Visibility is an explicit targeting rule. The owned Illusion at (6, 4) was rejected while hidden and the same click swapped successfully when visible. The Swap Illusion Grimoire entry says “Swap with one of your visible Illusions, anywhere unless the card shows a Range.” The native hover saying “Any of your illusions on the board.” omits that condition. [Targeting rule](../../scripts/illusion_card_rules.gd#L329) · [Grimoire entry](../../data/grimoire.json#L1045) · [Native hover copy](../../data/card_panel_text.json#L451)

```text
CRD33 WITNESS skybolt/immunity {"conducted_to":"(5, 4)","control_shock":1,"damage_each":8,"grimoire_traits":"This enemy is immune to Shock.","status_plate_trait":"Immune\nThis enemy is immune to Shock.","zekarion_shock":0}
CRD32 WITNESS skybolt {"clicked":"(3, 4)","damage":[8,8],"shock":[1,0],"targets":["crawler","zekarion"]}
CRD32 WITNESS empty_husk {"clicked":"(6, 4)","hero_after_visible_click":"(6, 4)","hidden":true,"hidden_rejection":"Requested tile illegal for illusion_swap; legal tiles []","legal_while_hidden":false}
```

## 3. Quicken

All six sources applied the full reduction to Skybolt, which costs 7 Time normally. The live hand showed exactly what the subsequent play paid, before card selection. Each Brace floor control paid 1 Time, consistent with the pricing clamp. [Quicken pricing](../../scripts/tempo_rules.gd#L52)

| Source | Reduction | Skybolt hand badge before click | Skybolt Time paid |
| --- | ---: | ---: | ---: |
| Spur Spark | 1 | 6 | 6 |
| Charged Orb | 2 | 5 | 5 |
| Galvanize | 2 | 5 | 5 |
| Hourglass Sand | 4 | 3 | 3 |
| Static Rush | 2 | 5 | 5 |
| Stolen Moment | 3 | 4 | 4 |

```text
CRD33 WITNESS quicken/spur_spark {"brace_time_with_quicken":1,"card_unselected":true,"hand_time_before_click":6,"next_card":"skybolt","normal_time":7,"paid_time":6,"quicken":1}
CRD33 WITNESS quicken/charged_orb {"brace_time_with_quicken":1,"card_unselected":true,"hand_time_before_click":5,"next_card":"skybolt","normal_time":7,"paid_time":5,"quicken":2}
CRD33 WITNESS quicken/galvanize {"brace_time_with_quicken":1,"card_unselected":true,"hand_time_before_click":5,"next_card":"skybolt","normal_time":7,"paid_time":5,"quicken":2}
CRD33 WITNESS quicken/hourglass_sand {"brace_time_with_quicken":1,"card_unselected":true,"hand_time_before_click":3,"next_card":"skybolt","normal_time":7,"paid_time":3,"quicken":4}
CRD33 WITNESS quicken/static_rush {"brace_time_with_quicken":1,"card_unselected":true,"hand_time_before_click":5,"next_card":"skybolt","normal_time":7,"paid_time":5,"quicken":2}
CRD33 WITNESS quicken/stolen_moment {"brace_time_with_quicken":1,"card_unselected":true,"hand_time_before_click":4,"next_card":"skybolt","normal_time":7,"paid_time":4,"quicken":3}
```

## 4. Stagger

Crushing Blow's target hover moved the uncapped enemy from Time 12 to 15 and showed a +3 badge. After Petrify applied 6 Stagger to the same enemy, the hover kept the enemy at Time 18 and the same rail slot, with no additional Stagger badge. The Grimoire line reads “Each unit takes up to 6 Stagger per turn.” [Turn-order hover](../../scripts/run_scene.gd#L34435) · [Grimoire cap](../../data/grimoire.json#L385)

```text
CRD33 WITNESS stagger/uncapped {"baseline_slot":1,"baseline_time":12,"card":"crushing_blow","hover_tile":"(3, 4)","legal":true,"preview_delay":3,"preview_slot":2,"preview_time":15,"slot_stagger_badge":3,"stagger_already_applied":0,"time_delta":3}
CRD33 WITNESS stagger/after_petrify {"baseline_slot":3,"baseline_time":18,"card":"crushing_blow","hover_tile":"(3, 4)","legal":true,"preview_delay":0,"preview_slot":3,"preview_time":18,"slot_stagger_badge":0,"stagger_already_applied":6,"time_delta":0}
CRD33 WITNESS stagger/grimoire {"line":"Each unit takes up to 6 Stagger per turn.","present":true}
```

## Receipts

The audit uses the crd-32 widget exporter, play runner, claim classifier and frozen False inventory from `codex/crd-32` at `fc2665186`. The baseline export ran in this worktree at `38a6abf32` before editing the two production scripts. Reports and JSON receipts are in `/private/tmp/labyrinth_codex/crd-33.e6qEXZ/`. The dry-run log is `/private/tmp/labyrinth_codex/crd-33/native.Q5A6rd/probe.log`.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/crd-33
scratch=/private/tmp/labyrinth_codex/crd-33.e6qEXZ
python3 tools/godot_task_runner.py --task-id crd-33 --stream -- godot --headless --path . --script tools/crd33/dump_cards.gd -- "$scratch/after.json"
python3 tools/godot_task_runner.py --task-id crd-33 --stream -- godot --headless --path . --script tools/crd33/runtime_checks.gd -- "$scratch/runtime.json"
python3 -B tools/crd33/verify_audit.py "$scratch/before.json" "$scratch/after.json" "$scratch/runtime.json"
python3 tools/godot_task_runner.py --task-id crd-33 --stream -- godot --headless --path . --script tools/crd33/report_checks.gd
python3 tests/test_rules_text_lint.py
python3 tests/test_short_card_tooltips.py
python3 tests/test_ui_identity_lint.py
python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir "$scratch/python-default-final"
bash tools/crd33/native.sh --dry-run
git diff --check
```

Observed result lines

```text
CRD32 EXPORT: 309 catalog IDs; 9 source lists
CRD32 RUNTIME: 309 card IDs; 330 successful plays; 56 named scenarios; 45 sampled areas
CRD33 TRUE stoke | Deal 2 damage to each enemy you can see. | Keyword hover, Native hover
CRD33 TRUE stoke | On Fire: +3 damage. | Native hover
CRD33 TRUE white_silence | Deal 8 damage to each enemy you can see on Ice. | Keyword hover, Native hover
CRD33 TRUE sleet_squall | Deal 3 damage to the target. | Keyword hover, Native hover
CRD33 AUDIT: 309 IDs, 57 -> 53 distinct False rows, 0 new False
CRD33 CLAIM INSTANCES: 1254 True, 97 False, 2658 UNTESTED
CRD33 DIFF: only sleet_squall, stoke, white_silence hover wording changed
CRD33 REPORT CHECKS: PASS (0 failures)
PASS: Rules text lint (16 existing hits)
Ran 5 tests in 0.008s
OK
Ran 25 tests in 4.270s
OK
SELECTED MODULES: 23 of 59
Ran 196 tests in 28.004s
OK
CRD33 DRY RUN: PASS (1920x1080, 100% UI scale, 0 PNGs, 0 failures)
CRD33 HOVER stoke | Deal 2 damage to each enemy you can see. | [P: (940.12, 712.931), S: (306.0, 299.0)]
CRD33 HOVER white_silence | Deal 8 damage to each enemy you can see on Ice. | [P: (1106.52, 511.0), S: (306.0, 551.0)]
CRD33 HOVER sleet_squall | Deal 3 damage to the target. | [P: (1272.92, 175.0), S: (306.0, 887.0)]
```

`git diff --check` and the protected data/scene/spec/test path comparison exited 0. The headless Godot logs include the macOS certificate lookup diagnostic. The report-only probe also logged one resource still in use at shutdown and exited 0. The Python runner could not write its timing cache under the shared Git directory and exited 0.

## Proof for the design owner

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/crd-33 && bash tools/crd33/native.sh
```

The windowed command opens each hover in the production combat hand with `LABYRINTH_CEL_LOOK=all`, 1920×1080 and 100% UI scale. It prints the paths for `stoke.png`, `white_silence.png`, and `sleet_squall.png` on separate lines under a fresh `/private/tmp/labyrinth_codex/crd-33/native.*/` directory and writes `manifest.json` there. Windowed capture remains pending because this sandbox has no window-server access.

## Chosen defaults

- Reused crd-32's seed-501 combat and neutral exporter fixtures. Visibility controls place the near enemy on the visible side of Heart and the reserve enemy beyond it. The White Silence control puts Ice on the visible hit and the hidden tile, with a visible off-Ice enemy between them.
- Skybolt serves as the 7-Time Quicken control, Brace as the floor control, and Crushing Blow as the second Stagger card after Petrify. A Crawler at Zekarion's conducted tile is the immunity control.
- The capture fixture starts with all three cards against Crawlers, with Fire at (3, 4) and Ice at (5, 4). It uses the standard camera, reduced motion, a five-frame layout settle and a 600-frame startup bound.

## Files and handoff

- Production builders are `scripts/action_icon_library.gd` and `scripts/card_widget.gd`.
- Audit and witness tools are `tools/crd33/{claims.py,dump_cards.gd,fight.gd,pattern_checks.gd,population.gd,runtime_checks.gd,verify_audit.py,witness_cases.gd}`.
- Live proof and report-only tools are `tools/crd33/{capture.gd,live_fight.gd,native.sh,native_contract.json,report_checks.gd,result.md}`.

No design placeholders. The report-only copy findings remain open under the brief. The worktree is uncommitted on `codex/crd-33` at `38a6abf32`.
