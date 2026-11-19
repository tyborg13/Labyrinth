# txt-16 house-style report

This report records round 0. See the [feedback 1 report](txt_16_feedback_1_report.md) for the restored caps and current verification.

The worktree is based on `codex/release` at `a869b8ba3`. The owner supplied `tools/qa112` in the task setup commit. Its contents match the `codex/qa-112` branch byte for byte.

## Acceptance

1. **Health** is the resource name in the objective count, inspection, terrain hover, Empower costs, reward Skip and payout, Ember Hearth, opening boons, Continue card, and the other audited surfaces. In all-caps text, the term is `HEALTH`.
2. **Enemy / enemies** appears in the Umbra count, combat copy, UI, and reference text. The Chronicle also displays the new term for already-recorded Chain Reaction feats. It reads the original saved record.
3. **Glossary capitalization** applies when the copy names the resource, terrain, action, or status. Walking costs use **Movement**, obstacle behavior uses “blocks movement,” and the prose about leaving the lantern bearer his light uses the ordinary noun. The line-by-line production diff below records the decisions.
4. **Numbers** use the Unicode minus for signed losses and compact fractions. The guardian ring already uses an en dash. The tutorial’s “2 to 1” remains because it describes a change of state.
5. **US spelling** is in the Lob tooltip and diagram, Hanged Knight, abandoned forge, Patient Surgeon, and Last Hearth.
6. **Punctuation and whitespace** use straight quotes, three-dot speech punctuation with a space before the next word, and single-space separators in reward text and other audited surfaces. The audit exceptions below document extraction artifacts.
7. **Case by surface** is applied to the audited buttons and headings. Event choice text already used sentence case with game terms such as Embers capitalized. `Reforge your armor` uses the approved spelling. The card-panel header remains `If Target at Half Health`.
8. **Leader objective hover** displays the title alone for Zekarion and includes the authored description when available. A focused test also covers the known-enemy counts for zero, one, and two visible enemies.
9. **Bound Magicks** and the **[M]** map shortcut retain their existing copy.

The changed JSON files retain their structure and non-string values. The three pattern-copy key changes track their matching player-facing sentences so the same diagrams still resolve.

## Before and after

| Surface | Before | After |
| --- | --- | --- |
| Zekarion objective heading | `DEFEAT ZEKARION, THE RAGING TEMPEST` | `Defeat Zekarion, the Raging Tempest` |
| Zekarion live objective | `111/111 HP` | `111/111 Health` |
| Zekarion objective hover | `Defeat Zekarion, the Raging Tempest\n` | `Defeat Zekarion, the Raging Tempest` |
| Enemy inspection | `HP 11/11` | `Health 11/11` |
| Reward Skip | `SKIP & RECOVER  +3 HP   14 → 17` | `Skip & Recover · +3 Health · 14 → 17` |
| Ember Hearth result | `+6 HP` | `+6 Health` |
| Vitality | `+6 max HP.` | `+6 max Health.` |
| Ossuary Gamblers choice | `Stake 50 Embers` | `Stake 50 Embers` |
| Ossuary Gamblers Health strip | `99 / 99` | `99/99` |
| Settings | `Restore defaults`, `Reset all`, `Off — full motion` | `Restore Defaults`, `Reset All`, `Off — Full Motion` |

## Verification

`tools/qa112/audit.py` reported:

```text
QA112 EVENT PAGES: 90 choice pages, 236 result pages
QA112 COPY EXPORT: 6141 records, 3 seeded combats, 1 Zekarion fixture
QA112 INVENTORY: 2677 data, 3138 source, 3652 formatted, 3583 observed
QA112 SCAN: 15929 matches across 420 class/check/variant rows
```

The runtime sample has zero matches for Health shorthand, foe wording, UK spellings, curly quotes, ASCII minus signs, and spaced fractions. Player-visible spacing has no remaining matches after examining the extraction artifacts described below. The audit exports are in `/tmp/txt-16-proof/complete-audit` with the before and after logs one directory up. The scene probe prints the isolated path to `observations.json`.

| Focused check | Result line |
| --- | --- |
| Text-budget Python suite | `Ran 6 tests` / `OK` |
| Short-card Python suite | `Ran 5 tests` / `OK` |
| Card-panel Python suite | `Ran 4 tests` / `OK` |
| UI identity lint | `Ran 25 tests` / `OK` |
| Headless audit scenes | `TEXT AUDIT CAPTURE HEADLESS VALIDATION RESULT: PASS (28 fixtures)` |
| Glossary | `GLOSSARY TEST RESULT: PASS (6530 checks, 0 failures)` |
| Short card tooltips | `SHORT CARD TOOLTIPS TEST RESULT: PASS (768 checks, 0 failures)` |
| Card panel | `CARD PANEL TEXT TEST RESULT: PASS (2181 definitions, 7537 panels, 7770 checks, 0 failures)` |
| Grimoire | `GRIMOIRE PERFORMANCE RESULT: PASS` |
| Event rules | `Event rules suite: 0 failures` |
| Event view | `Event view suite: 0 failures` |
| Pre-battle semantics | `PRE-BATTLE SEMANTICS TEST: PASS` |
| Guided tutorial | `CONTEXTUAL COMBAT TUTORIAL TEST: PASS` |
| Run score | `RUN SCORE TEST RESULT: PASS` |
| Dragon rewards | `Dragon rewards, gifts, wallet recovery and relic hooks passed.` |
| Affected objective, card, special encounter, damage feedback and turn clock suites | `TXT16 AFFECTED SUITES: PASS (9230 checks, 0 failures)` |
| Empower blocked tooltip | `TXT16 EMPOWER COPY: PASS (10 checks, 0 failures)` |
| Zekarion native probe parser check | Exit 0 from Godot `--check-only` |

## Audit exceptions

- The source scanner flags three internal Health shorthand tokens used in node names or lookup code and one historical Chronicle wording match used to display old records with the new wording.
- The sole ASCII-minus source match is the authoring diagnostic “expected explicit -1 or 1.” The range match is a regex digit class. Neither is player copy.
- The unmodified qa-112 extractor reports 222 double spaces and 25 triple spaces from event rich text. The logged strings are views such as `Lose 5  .` and `The   is one stage deeper` where Godot’s parsed text omits the inline Health or Umbra icon and the scanner counts the surrounding spaces together. Actual text has an icon in those positions.
- The scanner’s 10 observed trailing-space matches come from dropping `[I]` during markup cleanup. The raw label reads `DETAILS [I]` with no trailing space. Source trailing matches include fragments that add a space before the following label or token.
- Inline markup IDs, save fields, debug and authoring copy, glyph warmup ellipses, and keyboard shortcut tokens retain their functions. No player-facing change required changing a rules claim.

## Open issues

- Native renderer execution and visual inspection remain with the design owner. No PNGs were produced in the headless sandbox.
- Some successful Godot checks logged the platform CA-certificate diagnostic and teardown resource warnings. The dragon reward suite also exercised injected persistence failures before its pass line.
- No TODO_DESIGN placeholders were needed.

## Chosen defaults

- Reward and Hearth fixture Health deficit is 10. The production heal amounts determine the displayed result.
- Headless Hearth proof waits up to 3 seconds for the production result.
- Native Zekarion proof allows 5 seconds for the objective intro to settle and 2 seconds for the hover popup. The existing seed, depth and viewport settings are reused.

## Proof for the design owner

Both commands use the native renderer at 1920×1080 and 100% UI scale.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/txt-16 && LABYRINTH_DRAGON_PROBE_BOSS=zekarion LABYRINTH_DRAGON_PROBE_PHASE=objective LABYRINTH_DRAGON_PROBE_SIZE=1920x1080 python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/txt_16_zekarion_proof.json tests/dragon_boss_probe.gd --task-id txt-16

cd /Users/borgerding/workspace/Labyrinth.worktrees/txt-16 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/text_audit_capture_probe_contract.json tests/text_audit_capture_probe.gd --task-id txt-16
```

The Zekarion probe writes `20_zekarion_ready.png` and `20_zekarion_objective_hover.png` in `user://dragon_boss_probe_v4/1920x1080`. The reward witness is `user://probes/text_audit/1920x1080/02_card_reward.png`. Windowed capture and inspection are pending.

## Changed files

<details>
<summary>File list</summary>

- `data/card_panel_text.json`
- `data/cards.json`
- `data/demo.json`
- `data/enemies.json`
- `data/events.json`
- `data/glossary.json`
- `data/grimoire.json`
- `data/opening_boons.json`
- `data/pattern_rule_text.json`
- `data/special_encounters.json`
- `data/upgrades.json`
- `scenes/main_menu.tscn`
- `scripts/action_icon_library.gd`
- `scripts/board_surface_presentation.gd`
- `scripts/card_empower_controller.gd`
- `scripts/card_keyword_rules.gd`
- `scripts/card_widget.gd`
- `scripts/chronicle_panel.gd`
- `scripts/combat_board_view.gd`
- `scripts/combat_engine.gd`
- `scripts/combat_hud_utility_refresh.gd`
- `scripts/combat_objective_hud.gd`
- `scripts/combat_objective_rules.gd`
- `scripts/contextual_combat_prompt.gd`
- `scripts/contextual_combat_tutorial.gd`
- `scripts/defense_relic_rules.gd`
- `scripts/dialogue_engine.gd`
- `scripts/event_health_strip.gd`
- `scripts/game_data.gd`
- `scripts/grimoire_library.gd`
- `scripts/guardian_library.gd`
- `scripts/main_menu.gd`
- `scripts/maneuver_rules.gd`
- `scripts/pre_battle_inspection_view.gd`
- `scripts/pre_battle_view.gd`
- `scripts/retained_pass_preview.gd`
- `scripts/run_end_recap_overlay.gd`
- `scripts/run_engine.gd`
- `scripts/run_scene.gd`
- `scripts/run_score_rules.gd`
- `scripts/scavenger_shop_view.gd`
- `scripts/section_map_panel.gd`
- `scripts/settings_panel.gd`
- `scripts/skill_tree_view.gd`
- `scripts/status_tick_feedback.gd`
- `tests/card_keywords_w3_probe.gd`
- `tests/combat_objective_probe.gd`
- `tests/contextual_combat_tutorial_test.gd`
- `tests/controller_screen_sweep.gd`
- `tests/demo_end_panel_test.gd`
- `tests/dragon_boss_probe.gd`
- `tests/fixtures/card_panel_examples.json`
- `tests/fixtures/card_panel_grimoire_facts.json`
- `tests/health_cost_preview_probe.gd`
- `tests/helpers/brs01_catalog.gd`
- `tests/pre_battle_view_test.gd`
- `tests/reward_decision_support_probe.gd`
- `tests/run_score_test.gd`
- `tests/run_tests.gd`
- `tests/selection_prompt_probe.gd`
- `tests/settings_probe.gd`
- `tests/short_card_tooltips_test.gd`
- `tests/skill_ui_test.gd`
- `tests/suites/card_keywords_suite.gd`
- `tests/suites/card_keywords_w3_suite.gd`
- `tests/suites/combat_objective_suite.gd`
- `tests/suites/empower_seal_suite.gd`
- `tests/suites/en02_enemies_suite.gd`
- `tests/suites/fix_12_reactions_suite.gd`
- `tests/suites/fix_14_bleed_suite.gd`
- `tests/suites/hoarder_suite.gd`
- `tests/suites/last_light_suite.gd`
- `tests/suites/mim01_suite.gd`
- `tests/suites/pre_battle_ui_suite.gd`
- `tests/suites/special_encounter_suite.gd`
- `tests/suites/tooltip_consistency_suite.gd`
- `tests/suites/turn_clock_hud_suite.gd`
- `tests/test_card_panel_text.py`
- `tests/test_short_card_tooltips.py`
- `tests/text_audit_capture_probe.gd`
- `tests/text_budget_test.py`
- `tests/txt_16_report.md`
- `tests/txt_16_zekarion_proof.json`

</details>

## Production copy before and after

<details>
<summary>Line-by-line diff</summary>

\`\`\`diff
diff --git a/data/card_panel_text.json b/data/card_panel_text.json
index 6c120c9f3..300e50589 100644
--- a/data/card_panel_text.json
+++ b/data/card_panel_text.json
@@ -42 +42 @@
-    "legacy": "The illusion gains all your Block as extra health. You lose that Block.",
+    "legacy": "The illusion gains all your Block as extra Health. You lose that Block.",
@@ -53 +53 @@
-    "text": "Destroy an adjacent outcrop or Worldspine you raised.",
+    "text": "Destroy an adjacent Outcrop or Worldspine you raised.",
@@ -59,2 +59,2 @@
-    "text": "Destroy an outcrop, crate or other terrain in range and sight.",
-    "legacy": "Destroy an outcrop, crate or other terrain within range and sight.",
+    "text": "Destroy an Outcrop, crate or other terrain in range and sight.",
+    "legacy": "Destroy an Outcrop, crate or other terrain within range and sight.",
@@ -97,2 +97,2 @@
-    "text": "Raises an outcrop with this much Health that blocks movement and sight.",
-    "legacy": "Raises an outcrop with this much health on empty floor. It blocks movement and sight and leaves Rubble when destroyed.",
+    "text": "Raises an Outcrop with this much Health that blocks movement and sight.",
+    "legacy": "Raises an Outcrop with this much Health on empty floor. It blocks movement and sight and leaves Rubble when destroyed.",
@@ -104 +104 @@
-    "legacy": "Places a powder keg with this much health on empty floor. It blocks movement, not sight.",
+    "legacy": "Places a powder keg with this much Health on empty floor. It blocks movement, not sight.",
@@ -110 +110 @@
-    "legacy": "Raises a Worldspine with this much health on each empty tile around the target. Spires block movement, not sight, and leave Rubble when destroyed.",
+    "legacy": "Raises a Worldspine with this much Health on each empty tile around the target. Spires block movement, not sight, and leave Rubble when destroyed.",
@@ -116 +116 @@
-    "text": "Place the outcrop within this range.",
+    "text": "Place the Outcrop within this range.",
@@ -155 +155 @@
-    "legacy": "Crystal Mantle\nEach direct hit against you breaks one layer instead of dealing damage. Fire, Bleed, collisions, traps and health costs bypass it.",
+    "legacy": "Crystal Mantle\nEach direct hit against you breaks one layer instead of dealing damage. Fire, Bleed, collisions, traps and Health costs bypass it.",
@@ -240 +240 @@
-    "legacy": "If Target at Half Health\nApplies if the target is at or below half health before the hit.",
+    "legacy": "If Target at Half Health\nApplies if the target is at or below half Health before the hit.",
@@ -270 +270 @@
-    "legacy": "Skate\nThis turn, moving onto Ice costs no movement and Ice doesn't Chill you.",
+    "legacy": "Skate\nThis turn, moving onto Ice costs no Movement and Ice doesn't Chill you.",
@@ -420 +420 @@
-    "legacy": "Leaves an illusion with this much health where you stood."
+    "legacy": "Leaves an illusion with this much Health where you stood."
@@ -423,2 +423,2 @@
-    "text": "The destination must be next to an enemy, outcrop or crate.",
-    "legacy": "The destination must be next to an enemy, outcrop or crate."
+    "text": "The destination must be next to an enemy, Outcrop or crate.",
+    "legacy": "The destination must be next to an enemy, Outcrop or crate."
@@ -451,2 +451,2 @@
-    "text": "Raises an outcrop with this much HP at an empty ground target.",
-    "legacy": "Raises an outcrop with this much HP at an empty ground target."
+    "text": "Raises an Outcrop with this much Health at an empty ground target.",
+    "legacy": "Raises an Outcrop with this much Health at an empty ground target."
@@ -515 +515 @@
-    "legacy": "Empower cost: pay {n} health after the card resolves."
+    "legacy": "Empower cost: pay {n} Health after the card resolves."
diff --git a/data/cards.json b/data/cards.json
index 014ec1724..f4f5497a3 100644
--- a/data/cards.json
+++ b/data/cards.json
@@ -39 +39 @@
-    "description": "Move 2, gain 3 block, and gain 1 Card Play.",
+    "description": "Move 2, gain 3 Block, and gain 1 Card Play.",
@@ -147 +147 @@
-    "description": "Deal 3 damage and push each enemy hit 1 tile.",
+    "description": "Deal 3 damage and Push each enemy hit 1 tile.",
@@ -252 +252 @@
-    "description": "Exhaust. Heal 2 and gain 2 block.",
+    "description": "Exhaust. Heal 2 and gain 2 Block.",
@@ -273 +273 @@
-    "description": "Move 2, then strike for 9. Empower (1 HP): deal 4 more.",
+    "description": "Move 2, then strike for 9. Empower (1 Health): deal 4 more.",
@@ -403 +403 @@
-    "description": "Gain Truesight for 2 turns, gain 4 block, and draw 1.",
+    "description": "Gain Truesight for 2 turns, gain 4 Block, and draw 1.",
@@ -453 +453 @@
-    "description": "Gain 4 stoneskin and place a lasting light at range 3.",
+    "description": "Gain 4 Stoneskin and place a lasting Light at range 3.",
@@ -588 +588 @@
-    "description": "Move 2, then gain 7 block.",
+    "description": "Move 2, then gain 7 Block.",
@@ -634 +634 @@
-    "description": "Gain 7 block, then draw 1.",
+    "description": "Gain 7 Block, then draw 1.",
@@ -680 +680 @@
-    "description": "Lose 1 health. Draw 4 and gain 5 Block.",
+    "description": "Lose 1 Health. Draw 4 and gain 5 Block.",
@@ -701 +701 @@
-    "description": "Strike an adjacent enemy for 14. Empower (2 HP): deal 8 more and Pierce.",
+    "description": "Strike an adjacent enemy for 14. Empower (2 Health): deal 8 more and Pierce.",
@@ -736 +736 @@
-    "description": "Blink 4, gain 5 block, then gain 2 vision for 2 turns.",
+    "description": "Blink 4, gain 5 Block, then gain 2 vision for 2 turns.",
@@ -954 +954 @@
-    "description": "Exhaust. Heal 3 and gain 2 stoneskin.",
+    "description": "Exhaust. Heal 3 and gain 2 Stoneskin.",
@@ -975 +975 @@
-    "description": "Exhaust. Gain 12 block and heal 2.",
+    "description": "Exhaust. Gain 12 Block and heal 2.",
@@ -2014 +2014 @@
-    "description": "Deal 2 at range 3 and push each enemy hit 1 away from the center. The enemy on the center is pushed away from you.",
+    "description": "Deal 2 at range 3 and Push each enemy hit 1 away from the center. The enemy on the center is pushed away from you.",
@@ -2191 +2191 @@
-    "description": "Create a 4-health illusion on Rubble at range 3, then gain 4 Block and 2 Stoneskin.",
+    "description": "Create a 4-Health illusion on Rubble at range 3, then gain 4 Block and 2 Stoneskin.",
@@ -2469 +2469 @@
-    "description": "Gain 6 Block, then bash an adjacent enemy for 3 and push 1.",
+    "description": "Gain 6 Block, then bash an adjacent enemy for 3 and Push 1.",
@@ -2493 +2493 @@
-    "description": "Hook a target at range 2 for 2, pull 2, then gain 5 block.",
+    "description": "Hook a target at range 2 for 2, pull 2, then gain 5 Block.",
@@ -2517 +2517 @@
-    "description": "Create a 3-health illusion next to an enemy within range 3. That enemy is Exposed 3.",
+    "description": "Create a 3-Health illusion next to an enemy within range 3. That enemy is Exposed 3.",
@@ -2537 +2537 @@
-    "description": "Move 2, then gain 6 block.",
+    "description": "Move 2, then gain 6 Block.",
@@ -2558 +2558 @@
-    "description": "Lose 1 health. Gain 6 Stoneskin, then draw 1.",
+    "description": "Lose 1 Health. Gain 6 Stoneskin, then draw 1.",
@@ -2621 +2621 @@
-    "description": "Blink 2, then kick an adjacent enemy for 4 and push 2.",
+    "description": "Blink 2, then kick an adjacent enemy for 4 and Push 2.",
@@ -2646 +2646 @@
-    "description": "Blink 3, then gain 4 block.",
+    "description": "Blink 3, then gain 4 Block.",
@@ -2736 +2736 @@
-    "description": "Strike an adjacent enemy for 10, or 15 if it is at or below half health.",
+    "description": "Strike an adjacent enemy for 10, or 15 if it is at or below half Health.",
@@ -2793 +2793 @@
-    "description": "Snare a target at range 2 for 3 and immobilize, then gain 4 block.",
+    "description": "Snare a target at range 2 for 3 and immobilize, then gain 4 Block.",
@@ -2818 +2818 @@
-    "description": "Create a 2-health illusion at range 2, then gain 4 block.",
+    "description": "Create a 2-Health illusion at range 2, then gain 4 Block.",
@@ -2840 +2840 @@
-    "description": "Move 3, then gain 3 block.",
+    "description": "Move 3, then gain 3 Block.",
@@ -2912 +2912 @@
-    "description": "Strike for 4, bleed 1, then draw 1.",
+    "description": "Strike for 4, Bleed 1, then draw 1.",
@@ -3003 +3003 @@
-    "description": "Hook for 6 at range 2, pull 1, and bleed 1.",
+    "description": "Hook for 6 at range 2, pull 1, and Bleed 1.",
@@ -3085 +3085 @@
-    "description": "Exhaust. Lose 1 health. Strike for 10, then Detonate 10 on those tiles.",
+    "description": "Exhaust. Lose 1 Health. Strike for 10, then Detonate 10 on those tiles.",
@@ -3204 +3204 @@
-    "description": "Gain 5 block, then pierce an adjacent enemy for 3 and sunder 2.",
+    "description": "Gain 5 Block, then pierce an adjacent enemy for 3 and sunder 2.",
@@ -3301 +3301 @@
-    "description": "Create a 3-health illusion at range 3, gain 4 block, then draw 1.",
+    "description": "Create a 3-Health illusion at range 3, gain 4 Block, then draw 1.",
@@ -3327 +3327 @@
-    "description": "Create a 4-health illusion within range 3. Enemies that damage it take that much damage too.",
+    "description": "Create a 4-Health illusion within range 3. Enemies that damage it take that much damage too.",
@@ -3373 +3373 @@
-    "description": "Gain 9 block, then pull 2 at range 3 for 2 and expose 4.",
+    "description": "Gain 9 Block, then pull 2 at range 3 for 2 and expose 4.",
@@ -3398 +3398 @@
-    "description": "Exhaust. Heal 2 and gain 5 block.",
+    "description": "Exhaust. Heal 2 and gain 5 Block.",
@@ -3580 +3580 @@
-    "description": "Blink 3, leaving a 4-health illusion where you stood, then draw 1.",
+    "description": "Blink 3, leaving a 4-Health illusion where you stood, then draw 1.",
@@ -3602 +3602 @@
-    "description": "Swap places with one of your illusions. Your Block moves onto it as extra health.",
+    "description": "Swap places with one of your illusions. Your Block moves onto it as extra Health.",
@@ -3940 +3940 @@
-    "description": "Exhaust. Lose 1 health. Place Fire on 2 tiles at range 3, draw 2, and gain 1 Card Play.",
+    "description": "Exhaust. Lose 1 Health. Place Fire on 2 tiles at range 3, draw 2, and gain 1 Card Play.",
@@ -4033 +4033 @@
-    "description": "Pull 2 at range 2 for 4 and Bleed 2. Empower (1 HP): Expose 4 and Sunder 4.",
+    "description": "Pull 2 at range 2 for 4 and Bleed 2. Empower (1 Health): Expose 4 and Sunder 4.",
@@ -4261 +4261 @@
-    "description": "Consume. Blink 2 and gain 2 block.",
+    "description": "Consume. Blink 2 and gain 2 Block.",
@@ -4429 +4429 @@
-    "description": "Gain 4 block, then strike for 7.",
+    "description": "Gain 4 Block, then strike for 7.",
@@ -4522 +4522 @@
-    "description": "Deal 4 at range 3 and push 2.",
+    "description": "Deal 4 at range 3 and Push 2.",
@@ -4794 +4794 @@
-    "description": "Bash an adjacent enemy for 6 Ice damage and push 2.",
+    "description": "Bash an adjacent enemy for 6 Ice damage and Push 2.",
@@ -4815 +4815 @@
-    "description": "Deal 3 at range 3 and push 2 in any direction.",
+    "description": "Deal 3 at range 3 and Push 2 in any direction.",
@@ -5028 +5028 @@
-    "description": "Raise an outcrop within range 2, then gain 3 Stoneskin.",
+    "description": "Raise an Outcrop within range 2, then gain 3 Stoneskin.",
@@ -5095 +5095 @@
-    "description": "Strike an adjacent enemy for 4 and push 2.",
+    "description": "Strike an adjacent enemy for 4 and Push 2.",
@@ -5225 +5225 @@
-    "description": "Blink 3, then strike an adjacent enemy for 5 and push 1.",
+    "description": "Blink 3, then strike an adjacent enemy for 5 and Push 1.",
@@ -5329 +5329 @@
-    "description": "Consume. Create a 5-health illusion within range 3.",
+    "description": "Consume. Create a 5-Health illusion within range 3.",
@@ -5372 +5372 @@
-    "description": "Raise an outcrop next to you, then gain 5 Block.",
+    "description": "Raise an Outcrop next to you, then gain 5 Block.",
@@ -5418 +5418 @@
-    "description": "Raise a 3-health outcrop on an empty tile within range 3, then draw 1.",
+    "description": "Raise a 3-Health Outcrop on an empty tile within range 3, then draw 1.",
@@ -5440 +5440 @@
-    "description": "Raise an outcrop next to you, then gain 6 Stoneskin.",
+    "description": "Raise an Outcrop next to you, then gain 6 Stoneskin.",
@@ -5555 +5555 @@
-    "description": "Move 2, then bash an adjacent enemy for 5 and push 2.",
+    "description": "Move 2, then bash an adjacent enemy for 5 and Push 2.",
@@ -5657 +5657 @@
-    "description": "Create a 2-health illusion next to you, then draw 1.",
+    "description": "Create a 2-Health illusion next to you, then draw 1.",
@@ -5747 +5747 @@
-    "description": "Strike an adjacent enemy for 5 and push 2.",
+    "description": "Strike an adjacent enemy for 5 and Push 2.",
@@ -5879 +5879 @@
-    "description": "Exhaust. Lose 1 health. Draw 3, gain 2 Card Plays, and gain 3 block.",
+    "description": "Exhaust. Lose 1 Health. Draw 3, gain 2 Card Plays, and gain 3 Block.",
@@ -6182 +6182 @@
-    "description": "Raise outcrops on 3 tiles within range 2, then gain 3 Stoneskin. Empower (Exhaust): 5 tiles.",
+    "description": "Raise Outcrops on 3 tiles within range 2, then gain 3 Stoneskin. Empower (Exhaust): 5 tiles.",
@@ -6466 +6466 @@
-    "description": "Create a 3-health illusion within range 3, then draw 1. Empower (+2 Time): 5 health instead.",
+    "description": "Create a 3-Health illusion within range 3, then draw 1. Empower (+2 Time): 5 Health instead.",
@@ -6502 +6502 @@
-    "description": "Draw 1 and gain 1 Card Play. Empower (1 HP): draw 2 instead.",
+    "description": "Draw 1 and gain 1 Card Play. Empower (1 Health): draw 2 instead.",
@@ -6595 +6595 @@
-    "description": "Strike an adjacent enemy for 5. Follow-up: deal 3 more and push 1.",
+    "description": "Strike an adjacent enemy for 5. Follow-up: deal 3 more and Push 1.",
@@ -6719 +6719 @@
-    "description": "Rite: gain 1 extra independent movement each turn. Your Push and Pull move targets 1 tile farther.",
+    "description": "Rite: gain 1 extra independent Movement each turn. Your Push and Pull move targets 1 tile farther.",
@@ -7162 +7162 @@
-    "description": "Deal 3 across 3 tiles at range 2 and push each target 1 away from you. Empower (+2 Time): push 2 instead.",
+    "description": "Deal 3 across 3 tiles at range 2 and Push each target 1 away from you. Empower (+2 Time): Push 2 instead.",
@@ -7210 +7210 @@
-    "description": "Create a 3-health illusion within range 3 and Electrify its tile. Enemies that damage it take 4 Lightning damage and are Shocked.",
+    "description": "Create a 3-Health illusion within range 3 and Electrify its tile. Enemies that damage it take 4 Lightning damage and are Shocked.",
@@ -7355 +7355 @@
-    "description": "Create a 5-health illusion within range 3. While it lives, you may fire ranged attacks from its tile.",
+    "description": "Create a 5-Health illusion within range 3. While it lives, you may fire ranged attacks from its tile.",
@@ -7683 +7683 @@
-    "description": "Gain 5 Block, then push 1.",
+    "description": "Gain 5 Block, then Push 1.",
@@ -7729 +7729 @@
-    "description": "Blink to a tile next to an enemy, outcrop or crate within range 4.",
+    "description": "Blink to a tile next to an enemy, Outcrop or crate within range 4.",
@@ -7831 +7831 @@
-    "description": "Create 2-health illusions, then gain 3 Block.",
+    "description": "Create 2-Health illusions, then gain 3 Block.",
@@ -7937 +7937 @@
-    "description": "Create a 4-health illusion within range 3, then leave Ice.",
+    "description": "Create a 4-Health illusion within range 3, then leave Ice.",
@@ -7956 +7956 @@
-    "description": "Deal 3 damage. Then Detonate 8 on Fire within 1 tile of you, including yours. You take no damage from it. Empower (2 HP): Detonate within 2 tiles.",
+    "description": "Deal 3 damage. Then Detonate 8 on Fire within 1 tile of you, including yours. You take no damage from it. Empower (2 Health): Detonate within 2 tiles.",
@@ -8220 +8220 @@
-    "description": "Consume. Place a 3-health keg within range 2. When destroyed, it deals 6 damage.",
+    "description": "Consume. Place a 3-Health keg within range 2. When destroyed, it deals 6 damage.",
@@ -8333 +8333 @@
-    "description": "Destroy an outcrop or crate within range 3 to deal 6, then leave Rubble.",
+    "description": "Destroy an Outcrop or crate within range 3 to deal 6, then leave Rubble.",
@@ -8540 +8540 @@
-    "description": "Move 3, then draw 1. This turn, Ice costs you no movement and doesn't Chill you.",
+    "description": "Move 3, then draw 1. This turn, Ice costs you no Movement and doesn't Chill you.",
@@ -8816 +8816 @@
-    "description": "Exhaust. Raise 4-health Worldspines within range 3. At the start of each of your turns, they deal 3 damage.",
+    "description": "Exhaust. Raise 4-Health Worldspines within range 3. At the start of each of your turns, they deal 3 damage.",
diff --git a/data/demo.json b/data/demo.json
index e47e21845..fc2f59ade 100644
--- a/data/demo.json
+++ b/data/demo.json
@@ -10 +10 @@
-    "end_title": "Thanks for playing the demo",
+    "end_title": "Thanks for Playing the Demo",
@@ -15 +15 @@
-    "feedback": "Share feedback",
+    "feedback": "Share Feedback",
diff --git a/data/enemies.json b/data/enemies.json
index cfcdd1bb7..4d01b029a 100644
--- a/data/enemies.json
+++ b/data/enemies.json
@@ -1870 +1870 @@
-        "name": "Executioner\u2019s Fall",
+        "name": "Executioner's Fall",
diff --git a/data/events.json b/data/events.json
index 5b0391edb..b034195f1 100644
--- a/data/events.json
+++ b/data/events.json
@@ -268 +268 @@
-   "body": "A knight in good armour turns slowly on a chain above a pit. The chain groans with every turn, loud enough to carry far down the halls.",
+   "body": "A knight in good armor turns slowly on a chain above a pit. The chain groans with every turn, loud enough to carry far down the halls.",
@@ -587 +587 @@
-     "label": "Reforge your armour",
+     "label": "Reforge your armor",
@@ -1627 +1627 @@
-     "result": "He is very good. You try not to think about where he practised.",
+     "result": "He is very good. You try not to think about where he practiced.",
@@ -2367 +2367 @@
-   "body": "A hearth burns in the dark with nobody beside it, and for the first time in a long while you are warm. You could stay. Everyone here stayed, you realise, looking at the shapes around the fire.",
+   "body": "A hearth burns in the dark with nobody beside it, and for the first time in a long while you are warm. You could stay. Everyone here stayed, you realize, looking at the shapes around the fire.",
diff --git a/data/glossary.json b/data/glossary.json
index 84122cf9a..514f60665 100644
--- a/data/glossary.json
+++ b/data/glossary.json
@@ -63 +63 @@
-    "definition": "When it dies, it splits into smaller foes next to it.",
+    "definition": "When it dies, it splits into smaller enemies next to it.",
@@ -111 +111 @@
-    "definition": "Costs 2 movement to leave.",
+    "definition": "Costs 2 Movement to leave.",
@@ -407 +407 @@
-    "definition": "This turn, Ice costs no movement and doesn't Chill you.",
+    "definition": "This turn, Ice costs no Movement and doesn't Chill you.",
diff --git a/data/grimoire.json b/data/grimoire.json
index edee691e3..42c0fd77f 100644
--- a/data/grimoire.json
+++ b/data/grimoire.json
@@ -114 +114 @@
-        "Undo move (Z) takes back free movement until you play a card, unless the move revealed or triggered something.",
+        "Undo move (Z) takes back free Movement until you play a card, unless the move revealed or triggered something.",
@@ -131 +131 @@
-        "Each played card adds its printed time to the acting unit's turn delay.",
+        "Each played card adds its printed Time to the acting unit's turn delay.",
@@ -165,2 +165,2 @@
-        "Non-piercing damage is applied to Block first, then Stoneskin, then health.",
-        "Block clears before that actor\u2019s turn-start Fire damage. Stoneskin persists and can absorb it.",
+        "Non-piercing damage is applied to Block first, then Stoneskin, then Health.",
+        "Block clears before that actor's turn-start Fire damage. Stoneskin persists and can absorb it.",
@@ -179 +179 @@
-        "Lethal health loss spends one Defiance to restore 25% max health and continue the same combat.",
+        "Lethal Health loss spends one Defiance to restore 25% max Health and continue the same combat.",
@@ -193 +193 @@
-        "Targets must be visible and within Range. Ranged attacks also need line of sight; walls and outcrops block it."
+        "Targets must be visible and within Range. Ranged attacks also need line of sight; walls and Outcrops block it."
@@ -204 +204 @@
-        "Each reshuffle increments fatigue. Fatigue deals direct health loss that bypasses block.",
+        "Each reshuffle increments fatigue. Fatigue deals direct Health loss that bypasses Block.",
@@ -225,2 +225,2 @@
-        "Outcrop cards raise crag outcrops on empty floor. An outcrop blocks movement and line of sight, can be attacked like other terrain, and leaves Rubble when destroyed.",
-        "A tile is legal only when the raise keeps every floor tile connected, so an outcrop can never seal the hero, an enemy, a pickup or an exit away. A Worldspine cage is the one exception: it may seal the single tile it surrounds.",
+        "Outcrop cards raise crag Outcrops on empty floor. An Outcrop blocks movement and line of sight, can be attacked like other terrain, and leaves Rubble when destroyed.",
+        "A tile is legal only when the raise keeps every floor tile connected, so an Outcrop can never seal the hero, an enemy, a pickup or an exit away. A Worldspine cage is the one exception: it may seal the single tile it surrounds.",
@@ -228 +228 @@
-        "Rockburst and Worldbreak destroy terrain to blast the enemies next to it, or the line beyond an outcrop you raised.",
+        "Rockburst and Worldbreak destroy terrain to blast the enemies next to it, or the line beyond an Outcrop you raised.",
@@ -265 +265 @@
-        "Umbra stages grow more severe deeper in the labyrinth. Radiance effects create light, extend your vision, reveal hidden enemies, or reduce the room's Umbra stage.",
+        "Umbra stages grow more severe deeper in the labyrinth. Radiance effects create Light, extend your vision, reveal hidden enemies, or reduce the room's Umbra stage.",
@@ -298 +298 @@
-        "Walks across reachable tiles using the displayed movement allowance. Walking out of Rubble costs 2 movement instead of 1.",
+        "Walks across reachable tiles using the displayed Movement allowance. Walking out of Rubble costs 2 Movement instead of 1.",
@@ -309 +309 @@
-        "Teleports to a destination without crossing the tiles between. Landing triggers the destination\u2019s ground and traps.",
+        "Teleports to a destination without crossing the tiles between. Landing triggers the destination's ground and traps.",
@@ -395 +395 @@
-        "The cost is paid when the card finishes: extra Time added to your next turn, health paid after the card resolves (Block does not prevent it), or Exhaust.",
+        "The cost is paid when the card finishes: extra Time added to your next turn, Health paid after the card resolves (Block does not prevent it), or Exhaust.",
@@ -423 +423 @@
-        "Empty Husk swaps you with one of your illusions and moves your Block onto it as extra health. Shattered Reflection destroys one of your illusions to blast each enemy next to it. Both count as normal arrivals and destruction for illusion effects.",
+        "Empty Husk swaps you with one of your illusions and moves your Block onto it as extra Health. Shattered Reflection destroys one of your illusions to blast each enemy next to it. Both count as normal arrivals and destruction for illusion effects.",
@@ -434 +434 @@
-        "Prevents Move and Blink (and the hero\u2019s swaps) on the affected character\u2019s next turn."
+        "Prevents Move and Blink (and the hero's swaps) on the affected character's next turn."
@@ -456 +456 @@
-        "A foe defeated by Retaliate pays its normal rewards but does not refund a Card Play.",
+        "An enemy defeated by Retaliate pays its normal rewards but does not refund a Card Play.",
@@ -521 +521 @@
-        "Deals its displayed damage before each movement or attack action. Clears after the affected character\u2019s next turn.",
+        "Deals its displayed damage before each movement or attack action. Clears after the affected character's next turn.",
@@ -542 +542 @@
-        "Cancels the affected character\u2019s next non-movement action.",
+        "Cancels the affected character's next non-movement action.",
@@ -582 +582 @@
-        "Forces the target away from the attack\u2019s origin in one straight line for the displayed distance. It never turns or slides around anything.",
+        "Forces the target away from the attack's origin in one straight line for the displayed distance. It never turns or slides around anything.",
@@ -584 +584 @@
-        "If a wall, crate, outcrop, character or illusion stops it early, it collides.",
+        "If a wall, crate, Outcrop, character or illusion stops it early, it collides.",
@@ -586 +586 @@
-        "in an area push each enemy moves along its own straight line; stopped lines collide."
+        "In an area Push each enemy moves along its own straight line; stopped lines collide."
@@ -595 +595 @@
-        "Forces the target toward the attack\u2019s origin in one straight line for the displayed distance. It never turns or slides around anything.",
+        "Forces the target toward the attack's origin in one straight line for the displayed distance. It never turns or slides around anything.",
@@ -608 +608 @@
-        "When forced movement is stopped by a wall, crate, outcrop, character or illusion, the target takes 2 damage for each tile it didn't move, and so does whatever it hit. Walls take nothing.",
+        "When forced movement is stopped by a wall, crate, Outcrop, character or illusion, the target takes 2 damage for each tile it didn't move, and so does whatever it hit. Walls take nothing.",
@@ -639 +639 @@
-        "Creates light that reveals nearby Umbra within the displayed radius. Its duration counts down on player turns.",
+        "Creates Light that reveals nearby Umbra within the displayed radius. Its duration counts down on player turns.",
@@ -649 +649 @@
-        "Expands the light around you for the displayed number of turns.",
+        "Expands the Light around you for the displayed number of turns.",
@@ -669 +669 @@
-        "Reduces the room\u2019s Umbra stage for the rest of combat.",
+        "Reduces the room's Umbra stage for the rest of combat.",
@@ -679,2 +679,2 @@
-        "Fast close-range predator that closes distance and opens bleed wounds.",
-        "Its intents favor short movement paths followed by melee bleed attacks."
+        "Fast close-range predator that closes distance and opens Bleed wounds.",
+        "Its intents favor short movement paths followed by melee Bleed attacks."
@@ -689 +689 @@
-        "Ranged caster with dust bolt attacks, self-defense actions, and health-draining effects.",
+        "Ranged caster with dust bolt attacks, self-defense actions, and Health-draining effects.",
@@ -699 +699 @@
-        "Mobile ranged skirmisher with pierce and bleed attacks.",
+        "Mobile ranged skirmisher with pierce and Bleed attacks.",
@@ -709,2 +709,2 @@
-        "Durable front-line guard with heavy melee attacks, block gains, and close area strikes.",
-        "It can absorb damage through defenses before its health is exposed."
+        "Durable front-line guard with heavy melee attacks, Block gains, and close area strikes.",
+        "It can absorb damage through defenses before its Health is exposed."
@@ -848 +848 @@
-        "Skate: this turn, moving onto Ice costs no movement and Ice doesn't Chill you.",
+        "Skate: this turn, moving onto Ice costs no Movement and Ice doesn't Chill you.",
@@ -883 +883 @@
-        "Each direct damaging hit breaks one Crystal Mantle layer instead of damaging health. Cheap hits can clear layers before a heavy strike.",
+        "Each direct damaging hit breaks one Crystal Mantle layer instead of damaging Health. Cheap hits can clear layers before a heavy strike.",
@@ -886 +886 @@
-        "Crystal Mantle cards give you the same layers: each direct hit against you breaks one layer instead of dealing damage. Fire, Bleed, collisions, traps and health costs bypass it. Your layers last until broken or the combat ends.",
+        "Crystal Mantle cards give you the same layers: each direct hit against you breaks one layer instead of dealing damage. Fire, Bleed, collisions, traps and Health costs bypass it. Your layers last until broken or the combat ends.",
@@ -1000 +1000 @@
-        "A Lightning hit that touches it spreads to every foe on connected Electrified tiles. Chain relays through it."
+        "A Lightning hit that touches it spreads to every enemy on connected Electrified tiles. Chain relays through it."
@@ -1009 +1009 @@
-        "Walking out of Rubble costs 2 movement instead of 1. With movement remaining, the first step is always allowed."
+        "Walking out of Rubble costs 2 Movement instead of 1. With Movement remaining, the first step is always allowed."
@@ -1167 +1167 @@
-        "This turn, stepping onto Ice costs no movement, and Ice doesn't make you Chilled."
+        "This turn, stepping onto Ice costs no Movement, and Ice doesn't make you Chilled."
diff --git a/data/opening_boons.json b/data/opening_boons.json
index 9c432dad9..0b16b2455 100644
--- a/data/opening_boons.json
+++ b/data/opening_boons.json
@@ -67 +67 @@
-      "text": "+6 max @kw(health|HP).",
+      "text": "+6 max @kw(health|Health).",
@@ -78 +78 @@
-      "text": "Lose 5 max @kw(health|HP). Choose 1 of 5 rare spells.",
+      "text": "Lose 5 max @kw(health|Health). Choose 1 of 5 rare spells.",
@@ -85 +85 @@
-      "text": "<Relic effect> Start at half @kw(health|HP).",
+      "text": "<Relic effect> Start at half @kw(health|Health).",
diff --git a/data/pattern_rule_text.json b/data/pattern_rule_text.json
index 2cca525d3..cd3ff2834 100644
--- a/data/pattern_rule_text.json
+++ b/data/pattern_rule_text.json
@@ -39 +39 @@
-    "A tile is legal only when the raise keeps every floor tile connected, so an outcrop can never seal the hero, an enemy, a pickup or an exit away. A Worldspine cage is the one exception: it may seal the single tile it surrounds.": "@pattern(neighbors:origin) A tile is legal only when the raise keeps every floor tile connected, so an outcrop can never seal the hero, an enemy, a pickup or an exit away. A Worldspine cage is the one exception: it may seal the single tile it surrounds.",
+    "A tile is legal only when the raise keeps every floor tile connected, so an Outcrop can never seal the hero, an enemy, a pickup or an exit away. A Worldspine cage is the one exception: it may seal the single tile it surrounds.": "@pattern(neighbors:origin) A tile is legal only when the raise keeps every floor tile connected, so an Outcrop can never seal the hero, an enemy, a pickup or an exit away. A Worldspine cage is the one exception: it may seal the single tile it surrounds.",
@@ -42 +42 @@
-    "Rockburst and Worldbreak destroy terrain to blast the enemies next to it, or the line beyond an outcrop you raised.": "@pattern(neighbors:origin) @pattern(beyond:3:origin) Rockburst and Worldbreak destroy terrain to blast the enemies next to it, or the line beyond an outcrop you raised.",
+    "Rockburst and Worldbreak destroy terrain to blast the enemies next to it, or the line beyond an Outcrop you raised.": "@pattern(neighbors:origin) @pattern(beyond:3:origin) Rockburst and Worldbreak destroy terrain to blast the enemies next to it, or the line beyond an Outcrop you raised.",
@@ -45 +45 @@
-    "Creates light that reveals nearby Umbra within the displayed radius. Its duration counts down on player turns.": "Creates light that reveals nearby Umbra out to the displayed distance. Its duration counts down on player turns.",
+    "Creates Light that reveals nearby Umbra within the displayed radius. Its duration counts down on player turns.": "Creates Light that reveals nearby Umbra out to the displayed distance. Its duration counts down on player turns.",
diff --git a/data/special_encounters.json b/data/special_encounters.json
index 4489c850d..cd26e0338 100644
--- a/data/special_encounters.json
+++ b/data/special_encounters.json
@@ -291 +291 @@
-    "reward_line": "The Hoarder's hoard: +%d embers"
+    "reward_line": "The Hoarder's hoard: +%d Embers"
@@ -313,2 +313,2 @@
-   "objective_title": "Survive until dawn!",
-   "objective_hud_title": "Survive until dawn",
+   "objective_title": "Survive Until Dawn!",
+   "objective_hud_title": "Survive Until Dawn",
diff --git a/data/upgrades.json b/data/upgrades.json
index 2af46e85d..a7de07a19 100644
--- a/data/upgrades.json
+++ b/data/upgrades.json
@@ -8 +8 @@
-    "description": "Generated card-part upgrades can increase movement, blink, and attack range."
+    "description": "Generated card-part upgrades can increase Movement, blink, and attack range."
@@ -12 +12 @@
-    "description": "Generated card-part upgrades can increase block, stoneskin, healing, and draw."
+    "description": "Generated card-part upgrades can increase Block, Stoneskin, healing, and draw."
diff --git a/scenes/main_menu.tscn b/scenes/main_menu.tscn
index 881c04a99..c9931a094 100644
--- a/scenes/main_menu.tscn
+++ b/scenes/main_menu.tscn
@@ -132 +132 @@ layout_mode = 2
-text = "DEPTH 3  ·  IN COMBAT"
+text = "DEPTH 3 · IN COMBAT"
@@ -136 +136 @@ layout_mode = 2
-text = "HP 185 / 260  ·  HELD 74 EMBERS"
+text = "HEALTH 185/260 · HELD 74 EMBERS"
@@ -153 +153 @@ autowrap_mode = 2
-text = "LV 1  |  EMBERS 0  |  BOUND 0"
+text = "LV 1 · EMBERS 0 · BOUND 0"
@@ -189 +189 @@ layout_mode = 2
-text = "DEPTH 3  ·  IN COMBAT"
+text = "DEPTH 3 · IN COMBAT"
@@ -193 +193 @@ layout_mode = 2
-text = "HP 185 / 260  ·  HELD 74 EMBERS"
+text = "HEALTH 185/260 · HELD 74 EMBERS"
diff --git a/scripts/action_icon_library.gd b/scripts/action_icon_library.gd
index a57f8b3b1..8004583f2 100644
--- a/scripts/action_icon_library.gd
+++ b/scripts/action_icon_library.gd
@@ -763 +763 @@ static func token_value_text(token: Dictionary) -> String:
-	return str(int(value)) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else str(value)
+	return str(int(value)).replace("-", "−") if typeof(value) in [TYPE_INT, TYPE_FLOAT] else str(value)
@@ -879 +879 @@ static func _modifier_tooltip_lines(token: Dictionary) -> PackedStringArray:
-			label_text = "%+d" % int(modifier.get("amount", 0))
+			label_text = ("%+d" % int(modifier.get("amount", 0))).replace("-", "−")
@@ -885 +885 @@ static func _modifier_tooltip_lines(token: Dictionary) -> PackedStringArray:
-			line = "%s  %s" % [line, detail]
+			line = "%s · %s" % [line, detail]
@@ -983 +983 @@ static func keyword_rows_for_card(card: Dictionary, state: Dictionary = {}) -> A
-			row.append(token_for("health_cost", "-%d" % int(cost.get("health", 0)), "neutral", PanelText.copy("empower_health", {"n": int(cost.get("health", 0))})))
+			row.append(token_for("health_cost", "−%d" % int(cost.get("health", 0)), "neutral", PanelText.copy("empower_health", {"n": int(cost.get("health", 0))})))
@@ -1009 +1009 @@ static func tokens_for_keyword_bonus(printed_actions: Array, spec: Dictionary, t
-			tokens.append(token_for(_keyword_field_icon(action, field), "%+d" % int(added[field_var]), tone))
+			tokens.append(token_for(_keyword_field_icon(action, field), ("%+d" % int(added[field_var])).replace("-", "−"), tone))
@@ -1065 +1065 @@ static func keyword_rider_rows(action: Dictionary) -> Array:
-				row.append(token_for(_damage_icon_for_action(action, _damage_bonus_fallback_icon(action)), "%+d" % int(bonus.get("damage", 0)), "condition"))
+				row.append(token_for(_damage_icon_for_action(action, _damage_bonus_fallback_icon(action)), ("%+d" % int(bonus.get("damage", 0))).replace("-", "−"), "condition"))
@@ -1067 +1067 @@ static func keyword_rider_rows(action: Dictionary) -> Array:
-				row.append(token_for("stagger", "%+d" % int(bonus.get("stagger", 0)), "condition"))
+				row.append(token_for("stagger", ("%+d" % int(bonus.get("stagger", 0))).replace("-", "−"), "condition"))
@@ -1097 +1097 @@ static func surface_family_rider_rows(action: Dictionary) -> Array:
-			row.append(token_for(_damage_icon_for_action(action, _damage_bonus_fallback_icon(action)), "%+d" % bonus, "condition"))
+			row.append(token_for(_damage_icon_for_action(action, _damage_bonus_fallback_icon(action)), ("%+d" % bonus).replace("-", "−"), "condition"))
@@ -1130 +1130 @@ const STATE_CONDITION_COPY: Dictionary = {
-	"half_hp": {"icon": "health", "prefix": "≤½", "text": "if Target at half health:", "panel": "if_half_health"},
+	"half_hp": {"icon": "health", "prefix": "≤½", "text": "if target at half Health:", "panel": "if_half_health"},
@@ -1147 +1147 @@ static func scale_bonus_token(action: Dictionary) -> Dictionary:
-	var suffix: String = "%+d each (max %d)" % [int(scale.get("damage", 1)), int(scale.get("max", 0))]
+	var suffix: String = ("%+d each (max %d)" % [int(scale.get("damage", 1)), int(scale.get("max", 0))]).replace("-", "−")
@@ -1218 +1218 @@ static func cost_rows_for_card(card: Dictionary) -> Array:
-		row.append(token_for("health_cost", "-%d" % health_cost))
+		row.append(token_for("health_cost", "−%d" % health_cost))
@@ -1225 +1225 @@ static func lob_text(action: Dictionary) -> String:
-	return "%s · %d / %d" % [name, int(action["center_damage"]), int(action["arm_damage"])]
+	return "%s · %d/%d" % [name, int(action["center_damage"]), int(action["arm_damage"])]
@@ -1235 +1235 @@ static func lob_diagram_text(action: Dictionary) -> String:
-	var detail: String = "%d in each centre, %d around them, and they become Fire." % [center, arm] if count > 1 else "%d in the centre, %d around it, and they become Fire." % [center, arm]
+	var detail: String = "%d in each center, %d around them, and they become Fire." % [center, arm] if count > 1 else "%d in the center, %d around it, and they become Fire." % [center, arm]
@@ -1238 +1238 @@ static func lob_diagram_text(action: Dictionary) -> String:
-	return "%s Marks these tiles%s. Next turn: %s" % [lob_pattern(action), ", centred on you and 2 tiles away" if count > 1 else ", centred on you", detail]
+	return "%s Marks these tiles%s. Next turn: %s" % [lob_pattern(action), ", centered on you and 2 tiles away" if count > 1 else ", centered on you", detail]
@@ -1257 +1257 @@ static func tokens_for_action(action: Dictionary, options: Dictionary = {}) -> A
-			var detail: String = ("%d in each centre, %d around them." if int(action.get("lob_cross_count", 1)) > 1 else "%d in the centre, %d around it.") % damage
+			var detail: String = ("%d in each center, %d around them." if int(action.get("lob_cross_count", 1)) > 1 else "%d in the center, %d around it.") % damage
@@ -1290 +1290 @@ static func tokens_for_action(action: Dictionary, options: Dictionary = {}) -> A
-				tokens.append(token_for("health_cost", "-%d" % health_cost))
+				tokens.append(token_for("health_cost", "−%d" % health_cost))
@@ -1298 +1298 @@ static func tokens_for_action(action: Dictionary, options: Dictionary = {}) -> A
-				tokens.append(token_for("health_cost", "-%d" % health_cost))
+				tokens.append(token_for("health_cost", "−%d" % health_cost))
@@ -1462 +1462 @@ static func tokens_for_action(action: Dictionary, options: Dictionary = {}) -> A
-				tokens.append(pattern_detail(text_token("%d-tile line beyond" % line_length, "neutral", {"tooltip": "Hits each enemy in the %d tiles beyond the outcrop, away from you." % line_length, "diagram_tooltip": PatternText.diagram("beyond", line_length, "origin") + " Hits each enemy on these tiles beyond the outcrop, away from you."}), "beyond", "origin", line_length))
+				tokens.append(pattern_detail(text_token("%d-tile line beyond" % line_length, "neutral", {"tooltip": "Hits each enemy in the %d tiles beyond the Outcrop, away from you." % line_length, "diagram_tooltip": PatternText.diagram("beyond", line_length, "origin") + " Hits each enemy on these tiles beyond the Outcrop, away from you."}), "beyond", "origin", line_length))
@@ -1519 +1519 @@ static func tokens_for_action(action: Dictionary, options: Dictionary = {}) -> A
-				tokens.append(text_token("All outcrops · within %d" % int(action.get("range",1)), "warning", "Surviving outcrops rupture every floor tile within the shown distance."))
+				tokens.append(text_token("All Outcrops · within %d" % int(action.get("range",1)), "warning", "Surviving Outcrops rupture every floor tile within the shown distance."))
@@ -1536 +1536 @@ static func tokens_for_action(action: Dictionary, options: Dictionary = {}) -> A
-			tokens.append(_token_for_action_field(action, "eclipse", "duration", int(action.get("duration", 0)), "neutral", "Forces Eclipse for this many player turns. Radiance and light protect affected tiles."))
+			tokens.append(_token_for_action_field(action, "eclipse", "duration", int(action.get("duration", 0)), "neutral", "Forces Eclipse for this many player turns. Radiance and Light protect affected tiles."))
@@ -1673 +1673 @@ static func _append_maneuver_rider_tokens(tokens: Array, action: Dictionary) ->
-		tokens.append(text_token("beside foe/terrain" if adjacent_to.has("terrain") else "beside a foe", "neutral", PanelText.copy("unchanged_the_destination_must_be_next_to_an_enemy_outcrop_or_crate") if adjacent_to.has("terrain") else "The destination must be next to an enemy."))
+		tokens.append(text_token("beside enemy/terrain" if adjacent_to.has("terrain") else "beside an enemy", "neutral", PanelText.copy("unchanged_the_destination_must_be_next_to_an_enemy_outcrop_or_crate") if adjacent_to.has("terrain") else "The destination must be next to an enemy."))
@@ -1686 +1686 @@ static func _append_maneuver_rider_tokens(tokens: Array, action: Dictionary) ->
-		tokens.append(text_token("if no foe adjacent:", "neutral", PanelText.copy("unchanged_applies_if_no_enemy_is_next_to_you_after_the_blink")))
+		tokens.append(text_token("if no enemy adjacent:", "neutral", PanelText.copy("unchanged_applies_if_no_enemy_is_next_to_you_after_the_blink")))
@@ -1766 +1766 @@ static func _append_next_attack_tokens(tokens: Array, action: Dictionary) -> voi
-		var suffix: String = "%+d each (max %d)" % [int(per_tile.get("damage", 1)), int(per_tile.get("max", 0))]
+		var suffix: String = ("%+d each (max %d)" % [int(per_tile.get("damage", 1)), int(per_tile.get("max", 0))]).replace("-", "−")
@@ -1834 +1834 @@ static func plain_text_for_tokens(tokens: Array, include_diagrams: bool = false)
-	return "  ".join(parts)
+	return " · ".join(parts)
@@ -2028 +2028 @@ static func tokens_for_surface_bonus(action: Dictionary) -> Array:
-		tokens.append(token_for(icon, "%+d" % amount, "condition"))
+		tokens.append(token_for(icon, ("%+d" % amount).replace("-", "−"), "condition"))
diff --git a/scripts/board_surface_presentation.gd b/scripts/board_surface_presentation.gd
index 796022288..ba9c7d1e1 100644
--- a/scripts/board_surface_presentation.gd
+++ b/scripts/board_surface_presentation.gd
@@ -56 +56 @@ static func tooltip_entries(state: Dictionary, tile: Vector2i) -> Array[Dictiona
-		entries.append({"icon": "surface_rubble", "title": "Rubble", "description": "Walking out of Rubble costs 2 movement."})
+		entries.append({"icon": "surface_rubble", "title": "Rubble", "description": "Walking out of Rubble costs 2 Movement."})
diff --git a/scripts/card_empower_controller.gd b/scripts/card_empower_controller.gd
index 9fe47f14b..a5e500400 100644
--- a/scripts/card_empower_controller.gd
+++ b/scripts/card_empower_controller.gd
@@ -46 +46 @@ static func tooltip(scene: Node, index: int) -> String:
-	if blocked > 0: return "Not enough health: Empower costs %d HP." % blocked
+	if blocked > 0: return "Not enough Health: Empower costs %d Health." % blocked
@@ -81 +81 @@ static func sync_widgets(scene: Node) -> void:
-			detail = "Not enough health: Empower costs %d HP." % blocked if blocked > 0 else _tooltip_for_card(scene, index, card)
+			detail = "Not enough Health: Empower costs %d Health." % blocked if blocked > 0 else _tooltip_for_card(scene, index, card)
diff --git a/scripts/card_keyword_rules.gd b/scripts/card_keyword_rules.gd
index ff251c039..c9b78598e 100644
--- a/scripts/card_keyword_rules.gd
+++ b/scripts/card_keyword_rules.gd
@@ -148 +148 @@ static func _record_modifier(action: Dictionary, source: String, field: String,
-		"label": "%+d" % amount if amount != 0 else "",
+		"label": ("%+d" % amount).replace("-", "−") if amount != 0 else "",
@@ -165 +165 @@ static func empower_cost_label(cost: Dictionary) -> String:
-		return "%d HP" % int(cost.get("health", 0))
+		return "%d Health" % int(cost.get("health", 0))
diff --git a/scripts/card_widget.gd b/scripts/card_widget.gd
index c0dca20c6..5beb58c34 100644
--- a/scripts/card_widget.gd
+++ b/scripts/card_widget.gd
@@ -1403,3 +1403,3 @@ func _refresh_time_badge(card: Dictionary) -> void:
-	if int(card.get("_rite_time_discount", 0)) > 0: detail += "\nRite: -%d" % int(card["_rite_time_discount"])
-	if int(card.get("_relic_time_discount", 0)) > 0: detail += "\n%s: -%d" % [str(GameData.relic_def(str(card.get("_relic_time_discount_relic", ""))).get("name", "Relic")), int(card["_relic_time_discount"])]
-	if int(card.get("_quicken_discount", 0)) > 0: detail += "\nQuickened: -%d" % int(card["_quicken_discount"])
+	if int(card.get("_rite_time_discount", 0)) > 0: detail += "\nRite: −%d" % int(card["_rite_time_discount"])
+	if int(card.get("_relic_time_discount", 0)) > 0: detail += "\n%s: −%d" % [str(GameData.relic_def(str(card.get("_relic_time_discount_relic", ""))).get("name", "Relic")), int(card["_relic_time_discount"])]
+	if int(card.get("_quicken_discount", 0)) > 0: detail += "\nQuickened: −%d" % int(card["_quicken_discount"])
diff --git a/scripts/chronicle_panel.gd b/scripts/chronicle_panel.gd
index 02becec07..e2440c790 100644
--- a/scripts/chronicle_panel.gd
+++ b/scripts/chronicle_panel.gd
@@ -385 +385 @@ func _build_detail(record: Dictionary) -> void:
-			var text := _label("%s — %s" % [feat["title"], feat["detail"]], 17, Palette.GOLD_BRIGHT)
+			var text := _label("%s — %s" % [feat["title"], preload("res://scripts/run_score_rules.gd").feat_detail_for_display(str(feat["title"]), str(feat["detail"]))], 17, Palette.GOLD_BRIGHT)
diff --git a/scripts/combat_board_view.gd b/scripts/combat_board_view.gd
index 19f92cb4c..1e5d89c75 100644
--- a/scripts/combat_board_view.gd
+++ b/scripts/combat_board_view.gd
@@ -9489 +9489 @@ func _terrain_tooltip_text(terrain: Dictionary) -> String:
-	var text: String = "%s\n%d/%d HP" % [
+	var text: String = "%s\n%d/%d Health" % [
diff --git a/scripts/combat_engine.gd b/scripts/combat_engine.gd
index 1b42fb05e..4e009551e 100644
--- a/scripts/combat_engine.gd
+++ b/scripts/combat_engine.gd
@@ -735 +735 @@ func arm_carry_the_guard(state: Dictionary) -> Dictionary:
-	_log(next_state, "%s is armed to carry block remaining at turn end." % SkillTreeLibrary.display_name(skill_id))
+	_log(next_state, "%s is armed to carry Block remaining at turn end." % SkillTreeLibrary.display_name(skill_id))
@@ -1701 +1701 @@ func _apply_player_action(state: Dictionary, action: Dictionary, target_tile: Ve
-			_log(next_state, "Gained %d block." % int(resolved_action.get("amount", 0)))
+			_log(next_state, "Gained %d Block." % int(resolved_action.get("amount", 0)))
@@ -1707 +1707 @@ func _apply_player_action(state: Dictionary, action: Dictionary, target_tile: Ve
-			_log(next_state, "Gained %d stoneskin." % int(resolved_action.get("amount", 0)))
+			_log(next_state, "Gained %d Stoneskin." % int(resolved_action.get("amount", 0)))
@@ -1711 +1711 @@ func _apply_player_action(state: Dictionary, action: Dictionary, target_tile: Ve
-			_log(next_state, "Recovered %d health." % heal_amount)
+			_log(next_state, "Recovered %d Health." % heal_amount)
@@ -2313 +2313 @@ func prepare_player_activation_end(state: Dictionary) -> Dictionary:
-			_mark_skill_used(next_state, guard_id, "%s carries remaining block forward as stoneskin." % SkillTreeLibrary.display_name(guard_id))
+			_mark_skill_used(next_state, guard_id, "%s carries remaining Block forward as Stoneskin." % SkillTreeLibrary.display_name(guard_id))
@@ -3632 +3632 @@ func _raise_player_outcrops(state: Dictionary, action: Dictionary, target_tile:
-		_log(state, "Raised %d outcrop%s." % [raised, "" if raised == 1 else "s"])
+		_log(state, "Raised %d Outcrop%s." % [raised, "" if raised == 1 else "s"])
@@ -4972 +4972 @@ func _resolve_enemy_action(state: Dictionary, enemy_index: int, action: Dictiona
-			_log(next_state, "%s braces for %d block." % [
+			_log(next_state, "%s braces for %d Block." % [
@@ -4982 +4982 @@ func _resolve_enemy_action(state: Dictionary, enemy_index: int, action: Dictiona
-			_log(next_state, "%s hardens for %d stoneskin." % [
+			_log(next_state, "%s hardens for %d Stoneskin." % [
@@ -4989 +4989 @@ func _resolve_enemy_action(state: Dictionary, enemy_index: int, action: Dictiona
-			_log(next_state, "%s recovers %d health." % [
+			_log(next_state, "%s recovers %d Health." % [
@@ -5003 +5003 @@ func _resolve_enemy_action(state: Dictionary, enemy_index: int, action: Dictiona
-				_log(next_state, "%s stitches %s for %d health." % [
+				_log(next_state, "%s stitches %s for %d Health." % [
@@ -5022 +5022 @@ func _resolve_enemy_action(state: Dictionary, enemy_index: int, action: Dictiona
-				_log(next_state, "%s guards all other enemies for %d block." % [
+				_log(next_state, "%s guards all other enemies for %d Block." % [
@@ -5036 +5036 @@ func _resolve_enemy_action(state: Dictionary, enemy_index: int, action: Dictiona
-				_log(next_state, "%s guards %s for %d block." % [
+				_log(next_state, "%s guards %s for %d Block." % [
@@ -5253 +5253,2 @@ func _clear_remaining_enemies_for_leader_objective(state: Dictionary, leader_id:
-		_log(next_state, "The leader falls. %d bound foe(s) collapse without reward." % cleared_count)
+		var fallen: String = "enemy collapses" if cleared_count == 1 else "enemies collapse"
+		_log(next_state, "The leader falls. %d bound %s without reward." % [cleared_count, fallen])
@@ -6643 +6644 @@ func _mark_light_target_skill_trigger(state: Dictionary, action: Dictionary) ->
-	_record_skill_event(state, skill_id, "%s exposes a foe in Light." % SkillTreeLibrary.display_name(skill_id))
+	_record_skill_event(state, skill_id, "%s exposes an enemy in Light." % SkillTreeLibrary.display_name(skill_id))
@@ -8367 +8368 @@ func _draw_cards_in_place(state: Dictionary, count: int) -> Dictionary:
-				_mark_skill_used(next_state, reserve_id, "%s survives Fatigue at %d health." % [SkillTreeLibrary.display_name(reserve_id), reserve_health])
+				_mark_skill_used(next_state, reserve_id, "%s survives Fatigue at %d Health." % [SkillTreeLibrary.display_name(reserve_id), reserve_health])
@@ -8377 +8378 @@ func _draw_cards_in_place(state: Dictionary, count: int) -> Dictionary:
-			_log(next_state, "Fatigue costs %d health." % fatigue_damage)
+			_log(next_state, "Fatigue costs %d Health." % fatigue_damage)
@@ -11200 +11201 @@ func _conditional_attack_modifiers_for_action(state: Dictionary, action: Diction
-					detail = "No block or stoneskin"
+					detail = "No Block or Stoneskin"
@@ -11208 +11209 @@ func _conditional_attack_modifiers_for_action(state: Dictionary, action: Diction
-					detail = "At half health or less with no defense"
+					detail = "At half Health or less with no defense"
@@ -11212 +11213 @@ func _conditional_attack_modifiers_for_action(state: Dictionary, action: Diction
-					detail = "At half health or less"
+					detail = "At half Health or less"
@@ -11239 +11240 @@ func _conditional_attack_modifiers_for_action(state: Dictionary, action: Diction
-					detail = "While standing on %s" % str(effect["player_surface"]).capitalize() if effect.has("player_surface") else "While you have block"
+					detail = "While standing on %s" % str(effect["player_surface"]).capitalize() if effect.has("player_surface") else "While you have Block"
@@ -11519 +11520 @@ func _trigger_activation_end_relics(state: Dictionary) -> Dictionary:
-		_log(next_state, "%s carries %d block forward as stoneskin." % [_relic_effect_source_name(effect), stoneskin_gain])
+		_log(next_state, "%s carries %d Block forward as Stoneskin." % [_relic_effect_source_name(effect), stoneskin_gain])
@@ -11742 +11743 @@ func _trigger_defiance(state: Dictionary, cause: String, hp_before: int) -> Dict
-		"DEFIANCE restores %d health. %d remaining." % [
+		"DEFIANCE restores %d Health. %d remaining." % [
@@ -11945 +11946 @@ func _heal_player(state: Dictionary, amount: int) -> Dictionary:
-		_log(next_state, "%s hardens %d excess healing into stoneskin." % [_relic_effect_source_name(effect), converted])
+		_log(next_state, "%s hardens %d excess healing into Stoneskin." % [_relic_effect_source_name(effect), converted])
diff --git a/scripts/combat_hud_utility_refresh.gd b/scripts/combat_hud_utility_refresh.gd
index b83f323eb..4a0414f6f 100644
--- a/scripts/combat_hud_utility_refresh.gd
+++ b/scripts/combat_hud_utility_refresh.gd
@@ -46 +46 @@ static func reconcile(scene: Control, remaining: int, capacity: int, skills: Arr
-	summary.text = "%d READY / %d" % [ready, skills.size()] if compact else "%d READY  ·  %d OWNED" % [ready, skills.size()]
+	summary.text = "%d/%d READY" % [ready, skills.size()] if compact else "%d READY · %d OWNED" % [ready, skills.size()]
diff --git a/scripts/combat_objective_hud.gd b/scripts/combat_objective_hud.gd
index a2ea2e36c..c6c39c14b 100644
--- a/scripts/combat_objective_hud.gd
+++ b/scripts/combat_objective_hud.gd
@@ -70 +70 @@ func set_combat_state(state: Dictionary) -> bool:
-	var title_text: String = CombatObjectiveRules.hud_title_for_objective(objective).to_upper()
+	var title_text: String = CombatObjectiveRules.hud_title_for_objective(objective)
@@ -72 +72,4 @@ func set_combat_state(state: Dictionary) -> bool:
-	var next_tooltip: String = "%s\n%s" % [CombatObjectiveRules.title_for_objective(objective), CombatObjectiveRules.description_for_objective(objective)]
+	var next_tooltip: String = CombatObjectiveRules.title_for_objective(objective)
+	var description: String = CombatObjectiveRules.description_for_objective(objective).strip_edges()
+	if not description.is_empty():
+		next_tooltip += "\n" + description
@@ -82 +85 @@ func set_combat_state(state: Dictionary) -> bool:
-	_intro_title.text = CombatObjectiveRules.title_for_objective(objective).to_upper()
+	_intro_title.text = CombatObjectiveRules.title_for_objective(objective)
@@ -451 +454 @@ func opening_glyph_preparation_jobs(state: Dictionary) -> Array[Dictionary]:
-	var title: String = CombatObjectiveRules.title_for_objective(objective).to_upper()
+	var title: String = CombatObjectiveRules.title_for_objective(objective)
@@ -467 +470 @@ func opening_glyph_preparation_jobs(state: Dictionary) -> Array[Dictionary]:
-	for entry: Dictionary in [{"label": kicker, "text": kicker.text}, {"label": _title, "text": CombatObjectiveRules.hud_title_for_objective(objective).to_upper()}, {"label": _detail, "text": _live_detail(state, objective)}]:
+	for entry: Dictionary in [{"label": kicker, "text": kicker.text}, {"label": _title, "text": CombatObjectiveRules.hud_title_for_objective(objective)}, {"label": _detail, "text": _live_detail(state, objective)}]:
@@ -531,2 +534,2 @@ func _live_detail(state: Dictionary, objective: Dictionary) -> String:
-					return "%d/%d HP" % [hp, int(enemy.get("max_hp", hp))]
-				return "%s · %d/%d HP" % [enemy_name, hp, int(enemy.get("max_hp", hp))]
+					return "%d/%d Health" % [hp, int(enemy.get("max_hp", hp))]
+				return "%s · %d/%d Health" % [enemy_name, hp, int(enemy.get("max_hp", hp))]
@@ -556 +559 @@ func _live_detail(state: Dictionary, objective: Dictionary) -> String:
-				return "%d known foe%s remaining" % [live_count, "s" if live_count != 1 else ""]
+				return "%d known enem%s remaining" % [live_count, "ies" if live_count != 1 else "y"]
diff --git a/scripts/combat_objective_rules.gd b/scripts/combat_objective_rules.gd
index f5dec844d..acd5efa12 100644
--- a/scripts/combat_objective_rules.gd
+++ b/scripts/combat_objective_rules.gd
@@ -279,3 +279,6 @@ static func description_for_objective(objective: Dictionary) -> String:
-	var title: String = title_for_objective(objective)
-	if type == KILL_LEADER and title != display_name(type):
-		return ""
+	if type == KILL_LEADER:
+		if objective.has("objective_description"):
+			return str(objective["objective_description"])
+		# A saved generic description can be stale. Use authored copy or the current rules.
+		if title_for_objective(objective) != display_name(type):
+			return ""
diff --git a/scripts/contextual_combat_prompt.gd b/scripts/contextual_combat_prompt.gd
index 454fa8903..c2a6048d7 100644
--- a/scripts/contextual_combat_prompt.gd
+++ b/scripts/contextual_combat_prompt.gd
@@ -106 +106 @@ func configure(
-	_progress_label.text = "GUIDED RUN  •  %d / %d" % [
+	_progress_label.text = "GUIDED RUN • %d/%d" % [
diff --git a/scripts/contextual_combat_tutorial.gd b/scripts/contextual_combat_tutorial.gd
index 5a49f7823..41207a7c3 100644
--- a/scripts/contextual_combat_tutorial.gd
+++ b/scripts/contextual_combat_tutorial.gd
@@ -136,2 +136,2 @@ const PHASES: Dictionary = {
-		"pointer_text": "Point to a foe to reveal its next action.",
-		"controller_text": "Focus a foe to reveal its next action.",
+		"pointer_text": "Point to an enemy to reveal its next action.",
+		"controller_text": "Focus an enemy to reveal its next action.",
@@ -143,2 +143,2 @@ const PHASES: Dictionary = {
-		"pointer_text": "The preview shows what this foe will do on its turn.",
-		"controller_text": "The preview shows what this foe will do on its turn.",
+		"pointer_text": "The preview shows what this enemy will do on its turn.",
+		"controller_text": "The preview shows what this enemy will do on its turn.",
@@ -201,2 +201,2 @@ const PHASES: Dictionary = {
-		"pointer_text": "Use movement, cards, enemy intent, and Pass to defeat the remaining enemy.",
-		"controller_text": "Use movement, cards, enemy intent, and Pass to defeat the remaining enemy.",
+		"pointer_text": "Use Movement, cards, enemy intent, and Pass to defeat the remaining enemy.",
+		"controller_text": "Use Movement, cards, enemy intent, and Pass to defeat the remaining enemy.",
@@ -245,2 +245,2 @@ const AUTHORED_PHASES: Dictionary = {
-		"pointer_text": "You begin each turn with 2 movement. Use 1 to move onto the glowing tile.",
-		"controller_text": "You begin each turn with 2 movement. Use 1 to move onto the glowing tile.",
+		"pointer_text": "You begin each turn with 2 Movement. Use 1 to move onto the glowing tile.",
+		"controller_text": "You begin each turn with 2 Movement. Use 1 to move onto the glowing tile.",
diff --git a/scripts/defense_relic_rules.gd b/scripts/defense_relic_rules.gd
index b639ae192..1109c72c0 100644
--- a/scripts/defense_relic_rules.gd
+++ b/scripts/defense_relic_rules.gd
@@ -83 +83 @@ static func pay_health_cost(engine: RefCounted, state: Dictionary, amount: int,
-		engine._log(state, "Paid %d health and %d Stoneskin for %s." % [cost, skin_spent, source_name])
+		engine._log(state, "Paid %d Health and %d Stoneskin for %s." % [cost, skin_spent, source_name])
@@ -85 +85 @@ static func pay_health_cost(engine: RefCounted, state: Dictionary, amount: int,
-		engine._log(state, "Paid %d health to Empower %s." % [cost, source_name.trim_prefix("Empower ")])
+		engine._log(state, "Paid %d Health to Empower %s." % [cost, source_name.trim_prefix("Empower ")])
@@ -87 +87 @@ static func pay_health_cost(engine: RefCounted, state: Dictionary, amount: int,
-		engine._log(state, "Paid %d health for %s." % [cost, source_name])
+		engine._log(state, "Paid %d Health for %s." % [cost, source_name])
diff --git a/scripts/dialogue_engine.gd b/scripts/dialogue_engine.gd
index 28245f9a9..0117a538b 100644
--- a/scripts/dialogue_engine.gd
+++ b/scripts/dialogue_engine.gd
@@ -98 +98 @@ func _emaciated_man_dialogue(npc: Dictionary, room: Dictionary, run_state: Dicti
-			"text": "Hehehe. You're back...so soon."
+			"text": "Hehehe. You're back... so soon."
@@ -106 +106 @@ func _emaciated_man_dialogue(npc: Dictionary, room: Dictionary, run_state: Dicti
-			"text": "Maybe this time's the one. Then again...probably not."
+			"text": "Maybe this time's the one. Then again... probably not."
diff --git a/scripts/event_health_strip.gd b/scripts/event_health_strip.gd
index c3b5197ef..2b0cb5033 100644
--- a/scripts/event_health_strip.gd
+++ b/scripts/event_health_strip.gd
@@ -77 +77 @@ func _update() -> void:
-		_numbers.text = "%d / %d" % [_number_hp, _number_cap]
+		_numbers.text = "%d/%d" % [_number_hp, _number_cap]
@@ -132 +132 @@ func beat(kind: String, amount: int, reduced: bool, resolved_hp: float = -1, res
-	_spawn_number(("%+d max" if kind == "max_hp" else "%+d") % amount, Palette.GOLD if kind == "max_hp" and amount > 0 else Palette.DANGER if amount < 0 else Palette.ALLY, reduced)
+	_spawn_number((("%+d max" if kind == "max_hp" else "%+d") % amount).replace("-", "−"), Palette.GOLD if kind == "max_hp" and amount > 0 else Palette.DANGER if amount < 0 else Palette.ALLY, reduced)
diff --git a/scripts/game_data.gd b/scripts/game_data.gd
index 5952065b2..4278d92f7 100644
--- a/scripts/game_data.gd
+++ b/scripts/game_data.gd
@@ -1334 +1334 @@ static func _relic_modifier_label(effect: Dictionary, field: String, before_valu
-	return "%+d %s" % [amount, field.replace("_", " ")]
+	return "%s %s" % [("%+d" % amount).replace("-", "−"), field.replace("_", " ")]
diff --git a/scripts/grimoire_library.gd b/scripts/grimoire_library.gd
index 5c295142c..b387e8c07 100644
--- a/scripts/grimoire_library.gd
+++ b/scripts/grimoire_library.gd
@@ -988 +988 @@ static func _card_entry_body(card: Dictionary) -> Array:
-		notes.append("Spends every current Card Play; repeats actions and health cost per play, but pays Time once")
+		notes.append("Spends every current Card Play; repeats actions and Health cost per play, but pays Time once")
diff --git a/scripts/guardian_library.gd b/scripts/guardian_library.gd
index 53a600da9..afa3faeea 100644
--- a/scripts/guardian_library.gd
+++ b/scripts/guardian_library.gd
@@ -113 +113 @@ static func intent_notes(intent: Dictionary) -> String:
-			if str(action.get("type",""))=="raise_terrain": notes.append("Up to two outcrops; each fuels Groundsplit.")
+			if str(action.get("type",""))=="raise_terrain": notes.append("Up to two Outcrops; each fuels Groundsplit.")
@@ -116 +116 @@ static func intent_notes(intent: Dictionary) -> String:
-		notes.append("Relights braziers and dismisses Snuff’s Shades, even when skipped.")
+		notes.append("Relights braziers and dismisses Snuff's Shades, even when skipped.")
diff --git a/scripts/main_menu.gd b/scripts/main_menu.gd
index c604d0623..9a84282f0 100644
--- a/scripts/main_menu.gd
+++ b/scripts/main_menu.gd
@@ -621 +621 @@ func _reload_progression() -> void:
-	footer_label.text = "LV %d  |  EMBERS %d  |  SKILLS %d/%d" % [
+	footer_label.text = "LV %d · EMBERS %d · SKILLS %d/%d" % [
@@ -664,2 +664,2 @@ func _build_saved_run_preview(run_state: Dictionary) -> Dictionary:
-		"location": "DEPTH %d  ·  %s" % [depth, str(SAVED_RUN_MODE_LABELS[str(mode_value)])],
-		"stats": "HP %d / %d  ·  HELD %d EMBERS" % [player_hp, player_max_hp, held_embers]
+		"location": "DEPTH %d · %s" % [depth, str(SAVED_RUN_MODE_LABELS[str(mode_value)])],
+		"stats": "HEALTH %d/%d · HELD %d EMBERS" % [player_hp, player_max_hp, held_embers]
diff --git a/scripts/maneuver_rules.gd b/scripts/maneuver_rules.gd
index 753606bf6..5a00ae757 100644
--- a/scripts/maneuver_rules.gd
+++ b/scripts/maneuver_rules.gd
@@ -34 +34 @@ const FLAG_INFO: Dictionary = {
-		"description": "This turn, moving onto Ice costs no movement and Ice doesn't Chill you."},
+		"description": "This turn, moving onto Ice costs no Movement and Ice doesn't Chill you."},
diff --git a/scripts/pre_battle_inspection_view.gd b/scripts/pre_battle_inspection_view.gd
index b5b22fbd3..18ba31bb7 100644
--- a/scripts/pre_battle_inspection_view.gd
+++ b/scripts/pre_battle_inspection_view.gd
@@ -88 +88 @@ static func build(host: Node, enemy: Dictionary, interactive: bool = false) -> C
-	var hp_label := View.label("HP %d/%d" % [hp, int(enemy.get("max_hp", hp))], 17, Palette.DANGER_BRIGHT)
+	var hp_label := View.label("Health %d/%d" % [hp, int(enemy.get("max_hp", hp))], 17, Palette.DANGER_BRIGHT)
@@ -116 +116 @@ static func build(host: Node, enemy: Dictionary, interactive: bool = false) -> C
-	content.add_child(View.section("KNOWN MOVES"))
+	content.add_child(View.section("Known Moves", "", "PreBattleKNOWNMOVESLabel"))
@@ -171 +171 @@ static func build_move(host: Node, intent: Dictionary, source: Dictionary = {},
-	var summary: String = ActionIcons.plain_text_for_rows(own_rows, true).replace("\n", "  /  ")
+	var summary: String = ActionIcons.plain_text_for_rows(own_rows, true).replace("\n", " · ")
diff --git a/scripts/pre_battle_view.gd b/scripts/pre_battle_view.gd
index 9a62a9657..35ce51098 100644
--- a/scripts/pre_battle_view.gd
+++ b/scripts/pre_battle_view.gd
@@ -264 +264 @@ static func _begin_foes(host: Node, combat: Dictionary, state: Dictionary, jobs:
-	var header := section("FOES", str(enemies.size()), "PreBattleFoesDivider")
+	var header := section("Enemies", str(enemies.size()), "PreBattleFoesDivider")
@@ -293,2 +293,2 @@ static func _finish_foes(host: Node, state: Dictionary, foes: Control, header: C
-		"pointer_text": "Hover or select a foe to read its moves",
-		"controller_text": "Focus or select a foe to read its moves",
+		"pointer_text": "Hover or select an enemy to read its moves",
+		"controller_text": "Focus or select an enemy to read its moves",
@@ -486 +486 @@ static func build_kit(host: Node, future_state: Dictionary = {}) -> Control:
-	kit.add_child(section("YOUR KIT"))
+	kit.add_child(section("Your Kit", "", "PreBattleYOURKITLabel"))
@@ -667 +667 @@ static func build_health(host: Node, future_state: Dictionary = {}) -> Control:
-	values.add_child(label("%d / %d" % [int(state.get("player_hp", 0)), int(state.get("player_max_hp", 0))], 19, Palette.ALLY))
+	values.add_child(label("%d/%d" % [int(state.get("player_hp", 0)), int(state.get("player_max_hp", 0))], 19, Palette.ALLY))
diff --git a/scripts/retained_pass_preview.gd b/scripts/retained_pass_preview.gd
index b4ada7b78..87c2cb63d 100644
--- a/scripts/retained_pass_preview.gd
+++ b/scripts/retained_pass_preview.gd
@@ -87 +87 @@ static func build(scene: Control) -> Button:
-	action_label.text = "CARD COST\nDEFIANCE -%d" % card_defiance_spent if card_defiance_spent > 0 else "PASS"
+	action_label.text = "CARD COST\nDEFIANCE −%d" % card_defiance_spent if card_defiance_spent > 0 else "PASS"
@@ -145 +145 @@ static func refresh(scene: Control) -> void:
-	action.text = "CARD COST\nDEFIANCE -%d" % spent if spent > 0 else "PASS"
+	action.text = "CARD COST\nDEFIANCE −%d" % spent if spent > 0 else "PASS"
diff --git a/scripts/run_end_recap_overlay.gd b/scripts/run_end_recap_overlay.gd
index 69cd1fec1..9b2d36eb1 100644
--- a/scripts/run_end_recap_overlay.gd
+++ b/scripts/run_end_recap_overlay.gd
@@ -51 +51 @@ const LABEL_DETAIL_GAP: float = 8.0
-const CHRONICLE_LINK_TEXT: String = "VIEW IN THE CHRONICLE ›"
+const CHRONICLE_LINK_TEXT: String = "View in the Chronicle ›"
@@ -596 +596 @@ func _add_score_row(data: Dictionary, parent: VBoxContainer, width: float) -> vo
-	var detail_text: String = str(data.get("detail", ""))
+	var detail_text: String = RunScoreRules.feat_detail_for_display(label_text, str(data.get("detail", "")))
diff --git a/scripts/run_engine.gd b/scripts/run_engine.gd
index 938bc0c1d..0d36f5247 100644
--- a/scripts/run_engine.gd
+++ b/scripts/run_engine.gd
@@ -1487 +1487 @@ func _retreat_through_last_door(run_state: Dictionary) -> Dictionary:
-	var return_notice: String = "Last Door returns you to the previous chamber at %d health." % return_health
+	var return_notice: String = "Last Door returns you to the previous chamber at %d Health." % return_health
diff --git a/scripts/run_scene.gd b/scripts/run_scene.gd
index 260133589..f5209ff0d 100644
--- a/scripts/run_scene.gd
+++ b/scripts/run_scene.gd
@@ -1131 +1131 @@ const RELIC_OFFER_DESCRIPTION_MIN_HEIGHT: float = 130.0
-const REWARD_CHOICE_TITLE_TEXT: String = "GROW YOUR POWER"
+const REWARD_CHOICE_TITLE_TEXT: String = "Grow Your Power"
@@ -1138 +1138 @@ const REWARD_CARD_HOVER_SCALE: float = 1.10
-const RELIC_CHOICE_TITLE_TEXT: String = "CLAIM YOUR TREASURE"
+const RELIC_CHOICE_TITLE_TEXT: String = "Claim Your Treasure"
@@ -4417 +4417 @@ func _build_skill_status_popover() -> void:
-	_skill_status_summary.text = "0 READY  ·  0 OWNED"
+	_skill_status_summary.text = "0 READY · 0 OWNED"
@@ -4462 +4462 @@ func _build_skill_status_popover() -> void:
-	_skill_status_previous_page.text = "←  PREV"
+	_skill_status_previous_page.text = "← Prev"
@@ -4479 +4479 @@ func _build_skill_status_popover() -> void:
-	_skill_status_next_page.text = "NEXT  →"
+	_skill_status_next_page.text = "Next →"
@@ -6428 +6428 @@ func _rebuild_grimoire_overlay(scroll_to_selection: bool = false) -> void:
-			"%s  %d" % [str(section.get("title", section_id)), section_entries.size()],
+			"%s · %d" % [str(section.get("title", section_id)), section_entries.size()],
@@ -6454 +6454 @@ func _rebuild_grimoire_overlay(scroll_to_selection: bool = false) -> void:
-				"%s  %d" % [_grimoire_group_title(group_entries, group_id), group_entries.size()],
+				"%s · %d" % [_grimoire_group_title(group_entries, group_id), group_entries.size()],
@@ -11247 +11247 @@ func _refresh_relic_bar() -> void:
-				frame.tooltip_text += "\nStored Time: %d / %d" % [held,capacity]
+				frame.tooltip_text += "\nStored Time: %d/%d" % [held,capacity]
@@ -11422 +11422 @@ func _update_defiance_badge(frame: Control, remaining: int, capacity: int) -> vo
-		"DEFIANCE %d / %d\nLethal health loss spends 1 to restore 25%% max health.\n"
+		"DEFIANCE %d/%d\nLethal Health loss spends 1 to restore 25%% max Health.\n"
@@ -11537 +11537 @@ func _build_skill_sigil(skill_ids: Array[String], presentation: Dictionary = {})
-		"%d READY / %d" % [ready_count, skill_ids.size()]
+		"%d/%d READY" % [ready_count, skill_ids.size()]
@@ -11539 +11539 @@ func _build_skill_sigil(skill_ids: Array[String], presentation: Dictionary = {})
-		else "%d READY  ·  %d OWNED" % [ready_count, skill_ids.size()]
+		else "%d READY · %d OWNED" % [ready_count, skill_ids.size()]
@@ -11720 +11720 @@ func _refresh_skill_status_popover(skill_ids: Array[String], refresh_statuses: b
-		_skill_status_page_label.text = "%d / %d" % [_skill_status_page + 1, _skill_status_page_count()]
+		_skill_status_page_label.text = "%d/%d" % [_skill_status_page + 1, _skill_status_page_count()]
@@ -11745 +11745 @@ func _refresh_skill_status_popover(skill_ids: Array[String], refresh_statuses: b
-		_skill_status_summary.text = "%d READY  ·  %d OWNED" % [ready_count, _skill_status_skill_ids.size()]
+		_skill_status_summary.text = "%d READY · %d OWNED" % [ready_count, _skill_status_skill_ids.size()]
@@ -13624 +13624 @@ func _refresh_player_movement_meter() -> void:
-	_movement_meter_count.text = "%d / %d Movement" % [remaining, capacity]
+	_movement_meter_count.text = "%d/%d Movement" % [remaining, capacity]
@@ -13626,2 +13626,2 @@ func _refresh_player_movement_meter() -> void:
-	var pointer_text: String = tooltip_prefix + "%d of %d movement remaining. Click your character, then a destination tile." % [remaining, capacity]
-	var controller_text: String = tooltip_prefix + "%d of %d movement remaining. Select your character, then a destination tile." % [remaining, capacity]
+	var pointer_text: String = tooltip_prefix + "%d of %d Movement remaining. Click your character, then a destination tile." % [remaining, capacity]
+	var controller_text: String = tooltip_prefix + "%d of %d Movement remaining. Select your character, then a destination tile." % [remaining, capacity]
@@ -14180 +14180 @@ func _update_action_context_risk() -> void:
-		risk_text = "%s · DEFIANCE -%d · %s HP · %d LEFT%s" % [
+		risk_text = "%s · DEFIANCE −%d · %s HEALTH · %d LEFT%s" % [
@@ -14191 +14191 @@ func _update_action_context_risk() -> void:
-			values.append("-%d SKIN" % int(summary.get("stoneskin_loss", 0)))
+			values.append("−%d SKIN" % int(summary.get("stoneskin_loss", 0)))
@@ -14193 +14193 @@ func _update_action_context_risk() -> void:
-			values.append("-%d BLOCK" % int(summary.get("block_loss", 0)))
+			values.append("−%d BLOCK" % int(summary.get("block_loss", 0)))
@@ -14195 +14195 @@ func _update_action_context_risk() -> void:
-			values.append("-%d HP" % int(summary.get("hp_loss", 0)))
+			values.append("−%d HEALTH" % int(summary.get("hp_loss", 0)))
@@ -14510 +14510 @@ func _refresh_umbra_subtitle() -> void:
-	umbra_subtitle.tooltip_text = "%s Umbra\n%s\nTiles outside your vision or a light source are obscured. Hidden enemies cannot be targeted and conceal their intents.\nRadiance can reveal them or drive the Umbra back." % [
+	umbra_subtitle.tooltip_text = "%s Umbra\n%s\nTiles outside your vision or a Light source are obscured. Hidden enemies cannot be targeted and conceal their intents.\nRadiance can reveal them or drive the Umbra back." % [
@@ -14648 +14648 @@ func _begin_quick_wits_card_selection(skill_id: String) -> void:
-	_begin_hand_skill_card_selection(skill_id, valid_indices, "QUICK WITS  ·  CHOOSE A CARD TO DISCARD")
+	_begin_hand_skill_card_selection(skill_id, valid_indices, "QUICK WITS · CHOOSE A CARD TO DISCARD")
@@ -15443 +15443 @@ func _pass_preview_damage_entries(losses: Dictionary) -> Array[Dictionary]:
-			"text": "-%d" % stoneskin_loss,
+			"text": "−%d" % stoneskin_loss,
@@ -15450 +15450 @@ func _pass_preview_damage_entries(losses: Dictionary) -> Array[Dictionary]:
-			"text": "-%d" % block_loss,
+			"text": "−%d" % block_loss,
@@ -15457 +15457 @@ func _pass_preview_damage_entries(losses: Dictionary) -> Array[Dictionary]:
-			"text": "-%d" % defiance_spent,
+			"text": "−%d" % defiance_spent,
@@ -15472 +15472 @@ func _pass_preview_damage_entries(losses: Dictionary) -> Array[Dictionary]:
-			"text": "-%d" % hp_loss,
+			"text": "−%d" % hp_loss,
@@ -15516 +15516 @@ func _pass_preview_risk_tooltip(summary: Dictionary) -> String:
-		lines.append("+%d more foes act twice." % (repeated.size() - 2))
+		lines.append("+%d more enemies act twice." % (repeated.size() - 2))
@@ -15518 +15518 @@ func _pass_preview_risk_tooltip(summary: Dictionary) -> String:
-		lines.append("Foes hidden in the Umbra may act first.")
+		lines.append("Enemies hidden in the Umbra may act first.")
@@ -15520 +15520 @@ func _pass_preview_risk_tooltip(summary: Dictionary) -> String:
-		lines.append("A new foe acts before you.")
+		lines.append("A new enemy acts before you.")
@@ -15870 +15870 @@ func _add_dragon_reward_stack() -> void:
-		_dragon_reward_label(content, "DragonRewardPayout", "+%d Embers    ·    +%d HP recovered" % [int(reward["ember_amount"]), int(reward["healed_amount"])], UiTypography.SIZE_BODY_LARGE, Color("f4d598"))
+		_dragon_reward_label(content, "DragonRewardPayout", "+%d Embers · +%d Health recovered" % [int(reward["ember_amount"]), int(reward["healed_amount"])], UiTypography.SIZE_BODY_LARGE, Color("f4d598"))
@@ -16096 +16096 @@ func _finish_reward_choice_stack(stack: VBoxContainer, heal_amount: int, focusab
-			"REROLL",
+			"Reroll",
@@ -16187 +16187 @@ func _reward_recover_button(heal_amount: int, choice_state: Dictionary = {}) ->
-	var tooltip: String = "Leave every offered card behind and recover %d HP." % effective_heal
+	var tooltip: String = "Leave every offered card behind and recover %d Health." % effective_heal
@@ -16189 +16189 @@ func _reward_recover_button(heal_amount: int, choice_state: Dictionary = {}) ->
-		tooltip = "Choose whether one offered card follows you to the next reward. Health is already full." if fully_wasted else "Recover %d HP, then choose whether one offered card follows you to the next reward." % effective_heal
+		tooltip = "Choose whether one offered card follows you to the next reward. Health is already full." if fully_wasted else "Recover %d Health, then choose whether one offered card follows you to the next reward." % effective_heal
@@ -16194 +16194 @@ func _reward_recover_button(heal_amount: int, choice_state: Dictionary = {}) ->
-		"SKIP  •  HEALTH FULL" if fully_wasted else "SKIP & RECOVER  +%d HP   %d → %d" % [effective_heal, current_hp, result_hp],
+		"Skip · Health Full" if fully_wasted else "Skip & Recover · +%d Health · %d → %d" % [effective_heal, current_hp, result_hp],
@@ -16594 +16594 @@ func _campfire_choice_chips(choice_id: String, enabled: bool) -> Array:
-			chips.append({"text": "+%d HP" % gain if gain > 0 else "FULL HEALTH", "tone": "benefit"})
+			chips.append({"text": "+%d Health" % gain if gain > 0 else "FULL HEALTH", "tone": "benefit"})
@@ -16610 +16610 @@ func _campfire_choice_chips(choice_id: String, enabled: bool) -> Array:
-			chips.append({"text": "-1 SPELL", "tone": "cost"} if enabled else {"text": "NO SPELLS", "tone": "disabled"})
+			chips.append({"text": "−1 SPELL", "tone": "cost"} if enabled else {"text": "NO SPELLS", "tone": "disabled"})
@@ -16890 +16890 @@ func _on_campfire_choice_gui_input(event: InputEvent, choice_id: String, panel:
-			await _play_campfire_result("+%d HP" % gain if gain > 0 else "Full health", gain > 0)
+			await _play_campfire_result("+%d Health" % gain if gain > 0 else "Full Health", gain > 0)
@@ -20967 +20967 @@ func _movement_risk_chips_for_states(before_state: Dictionary, after_state: Dict
-			chips.append({"tile": risk_tile, "label": "%d movement · Rubble" % trade_cost, "kind": "status"})
+			chips.append({"tile": risk_tile, "label": "%d Movement · Rubble" % trade_cost, "kind": "status"})
@@ -20971 +20971 @@ func _movement_risk_chips_for_states(before_state: Dictionary, after_state: Dict
-			chips.append({"tile": risk_tile, "label": "%d movement · Rubble" % cost, "kind": "status"})
+			chips.append({"tile": risk_tile, "label": "%d Movement · Rubble" % cost, "kind": "status"})
@@ -20984 +20984 @@ func _movement_player_delta_chips(before_state: Dictionary, after_state: Diction
-		chips.append({"tile": tile, "label": "-%d HP" % hp_loss, "kind": "danger"})
+		chips.append({"tile": tile, "label": "−%d Health" % hp_loss, "kind": "danger"})
@@ -20987 +20987 @@ func _movement_player_delta_chips(before_state: Dictionary, after_state: Diction
-		chips.append({"tile": tile, "label": "-%d Block" % block_loss, "kind": "danger"})
+		chips.append({"tile": tile, "label": "−%d Block" % block_loss, "kind": "danger"})
@@ -20990 +20990 @@ func _movement_player_delta_chips(before_state: Dictionary, after_state: Diction
-		chips.append({"tile": tile, "label": "-%d Guard" % stoneskin_loss, "kind": "danger"})
+		chips.append({"tile": tile, "label": "−%d Guard" % stoneskin_loss, "kind": "danger"})
@@ -21305 +21305 @@ func _force_aim_rotate_tooltip() -> String:
-	return "Change pull direction" if pulling else "Change push direction"
+	return "Change pull direction" if pulling else "Change Push direction"
@@ -22289 +22289 @@ func _refresh_large_map_navigation_hint() -> void:
-	_large_map_navigation_hint.text = "DRAG / TWO-FINGER PAN  •  SCROLL / PINCH TO ZOOM  •  M TO CLOSE"
+	_large_map_navigation_hint.text = "DRAG / TWO-FINGER PAN • SCROLL / PINCH TO ZOOM • M TO CLOSE"
@@ -23755 +23755 @@ func _fatigue_floating_texts_for_events(display_state: Dictionary, fatigue_event
-			"-%d" % total_damage,
+			"−%d" % total_damage,
@@ -23840 +23840 @@ func _animate_turn_start_fire(display_state: Dictionary, burn: Dictionary) -> vo
-	texts.append(FloatingCombatText.damage_entry(tile, "-%d" % lost, Color("f39779"), {
+	texts.append(FloatingCombatText.damage_entry(tile, "−%d" % lost, Color("f39779"), {
@@ -24233 +24233 @@ func _animate_player_action_step(before_state: Dictionary, after_state: Dictiona
-			var light_text: String = "Truesight" if action_type == "truesight" else "Umbra -%d" % int(action.get("amount", 1)) if action_type == "dispel_umbra" else "Vision +%d" % int(action.get("amount", 0))
+			var light_text: String = "Truesight" if action_type == "truesight" else "Umbra −%d" % int(action.get("amount", 1)) if action_type == "dispel_umbra" else "Vision +%d" % int(action.get("amount", 0))
@@ -26666 +26666 @@ func _floating_texts_for_step(step: Dictionary) -> Array[Dictionary]:
-						"-%d" % int(step.get("hp_loss", 0)),
+						"−%d" % int(step.get("hp_loss", 0)),
@@ -26674 +26674 @@ func _floating_texts_for_step(step: Dictionary) -> Array[Dictionary]:
-						"text": "-%d B" % int(step.get("block_loss", 0)),
+						"text": "−%d B" % int(step.get("block_loss", 0)),
@@ -26683 +26683 @@ func _floating_texts_for_step(step: Dictionary) -> Array[Dictionary]:
-						"text": "-%d S" % int(step.get("stoneskin_loss", 0)),
+						"text": "−%d S" % int(step.get("stoneskin_loss", 0)),
@@ -26735 +26735 @@ func _status_damage_floating_texts(step: Dictionary) -> Array[Dictionary]:
-			"-%d" % int(step.get("amount", 0)),
+			"−%d" % int(step.get("amount", 0)),
@@ -26764 +26764 @@ func _floating_texts_for_target_losses(target_losses: Array, status_text: String
-				"-%d" % int(loss.get("hp_loss", 0)),
+				"−%d" % int(loss.get("hp_loss", 0)),
@@ -26772 +26772 @@ func _floating_texts_for_target_losses(target_losses: Array, status_text: String
-				"text": "-%d B" % int(loss.get("block_loss", 0)),
+				"text": "−%d B" % int(loss.get("block_loss", 0)),
@@ -26781 +26781 @@ func _floating_texts_for_target_losses(target_losses: Array, status_text: String
-				"text": "-%d S" % int(loss.get("stoneskin_loss", 0)),
+				"text": "−%d S" % int(loss.get("stoneskin_loss", 0)),
@@ -26834 +26834 @@ func _floating_texts_for_terrain_losses(terrain_losses: Array) -> Array[Dictiona
-			"-%d" % hp_loss,
+			"−%d" % hp_loss,
@@ -27483 +27483 @@ func _player_loss_floating_texts(before_state: Dictionary, after_state: Dictiona
-			"-%d" % hp_loss,
+			"−%d" % hp_loss,
@@ -27491 +27491 @@ func _player_loss_floating_texts(before_state: Dictionary, after_state: Dictiona
-			"text": "-%d B" % block_loss,
+			"text": "−%d B" % block_loss,
@@ -27500 +27500 @@ func _player_loss_floating_texts(before_state: Dictionary, after_state: Dictiona
-			"text": "-%d S" % stoneskin_loss,
+			"text": "−%d S" % stoneskin_loss,
@@ -27528 +27528 @@ func _player_damage_floating_texts(before_state: Dictionary, after_state: Dictio
-				"-%d" % hp_loss,
+				"−%d" % hp_loss,
@@ -27536 +27536 @@ func _player_damage_floating_texts(before_state: Dictionary, after_state: Dictio
-				"text": "-%d B" % block_loss,
+				"text": "−%d B" % block_loss,
@@ -27545 +27545 @@ func _player_damage_floating_texts(before_state: Dictionary, after_state: Dictio
-				"text": "-%d S" % stoneskin_loss,
+				"text": "−%d S" % stoneskin_loss,
@@ -29590 +29590 @@ func _open_pile_view(pile_kind: String) -> void:
-		"%s  ·  Choose a Card to Return" % SkillTreeLibrary.display_name(_combat_skill_card_selection_skill_id)
+		"%s · Choose a Card to Return" % SkillTreeLibrary.display_name(_combat_skill_card_selection_skill_id)
@@ -30654 +30654 @@ func _skill_reset_button_text() -> String:
-		return "Reset Skills  ·  1 Moltshard"
+		return "Reset Skills · 1 Moltshard"
@@ -30656 +30656 @@ func _skill_reset_button_text() -> String:
-		return "Reset Skills  ·  Start a Run"
+		return "Reset Skills · Start a Run"
@@ -30658 +30658 @@ func _skill_reset_button_text() -> String:
-		return "Reset Skills  ·  No Skills Learned"
+		return "Reset Skills · No Skills Learned"
@@ -30660 +30660 @@ func _skill_reset_button_text() -> String:
-		return "Reset Skills  ·  Need 1 Moltshard"
+		return "Reset Skills · Need 1 Moltshard"
@@ -30663 +30663 @@ func _skill_reset_button_text() -> String:
-		return "Reset Skills  ·  Unavailable in Combat"
+		return "Reset Skills · Unavailable in Combat"
@@ -30665,2 +30665,2 @@ func _skill_reset_button_text() -> String:
-		return "Reset Skills  ·  Run Complete"
-	return "Reset Skills  ·  Finish Current Action"
+		return "Reset Skills · Run Complete"
+	return "Reset Skills · Finish Current Action"
@@ -30738 +30738 @@ func _build_equipped_items_section() -> Control:
-	section.add_child(Menu.section("ITEMS", "%d / %d" % [mini(equipped_items.size(), GameData.item_loadout_limit()), GameData.item_loadout_limit()]))
+	section.add_child(Menu.section("ITEMS", "%d/%d" % [mini(equipped_items.size(), GameData.item_loadout_limit()), GameData.item_loadout_limit()]))
@@ -31154 +31154 @@ func _new_item_card_tile(card_id: String, source_kind: String, index: int, can_c
-		Menu.empty_row(empty, "Empty item slot")
+		Menu.empty_row(empty, "Empty Item Slot")
@@ -34673 +34673 @@ func _friendly_damage_preview_chips(state: Dictionary, losses: Dictionary, movem
-			chips.append({"tile": tile, "actor_key": key, "label": "%s: −%d HP" % [name, int(loss["hp_loss"])], "kind": "danger"})
+			chips.append({"tile": tile, "actor_key": key, "label": "%s: −%d Health" % [name, int(loss["hp_loss"])], "kind": "danger"})
diff --git a/scripts/run_score_rules.gd b/scripts/run_score_rules.gd
index 13d17cb6b..5e01a804f 100644
--- a/scripts/run_score_rules.gd
+++ b/scripts/run_score_rules.gd
@@ -24,0 +25,4 @@ var play_seconds: float = 0.0
+# Historical Chronicle records keep the wording stored when the feat was earned.
+static func feat_detail_for_display(title: String, detail: String) -> String:
+	return detail.replace(" foes", " enemies") if title == "Chain Reaction" else detail
+
@@ -113 +117 @@ static func score(run_state: Dictionary, outcome: String) -> Dictionary:
-		_append(feats, "chain_reaction", "Chain Reaction", "%d foes slain by one card" % kills, 25)
+		_append(feats, "chain_reaction", "Chain Reaction", "%d enemies slain by one card" % kills, 25)
diff --git a/scripts/scavenger_shop_view.gd b/scripts/scavenger_shop_view.gd
index 71b798635..eb1a323da 100644
--- a/scripts/scavenger_shop_view.gd
+++ b/scripts/scavenger_shop_view.gd
@@ -768 +768 @@ func _sync_dialogue() -> void:
-	_dialogue_words.text = "“Cards, steel, little miracles in bottles. Spend your Embers, or show me what you've brought to sell.”"
+	_dialogue_words.text = "\"Cards, steel, little miracles in bottles. Spend your Embers, or show me what you've brought to sell.\""
@@ -956 +956 @@ func _populate_sell_page() -> void:
-	_sell_heading.text = "YOUR PACK" if page_count == 1 else "YOUR PACK  ·  %d / %d" % [_sell_page + 1, page_count]
+	_sell_heading.text = "YOUR PACK" if page_count == 1 else "YOUR PACK · %d/%d" % [_sell_page + 1, page_count]
@@ -1378 +1378 @@ func _render_detail_card() -> void:
-		_detail_card_counter.text = "%d / %d" % [_detail_card_index + 1, _detail_card_ids.size()]
+		_detail_card_counter.text = "%d/%d" % [_detail_card_index + 1, _detail_card_ids.size()]
diff --git a/scripts/section_map_panel.gd b/scripts/section_map_panel.gd
index 98108dbb3..df7eca2d6 100644
--- a/scripts/section_map_panel.gd
+++ b/scripts/section_map_panel.gd
@@ -411 +411 @@ func _refresh() -> void:
-	_progress.text = "SECTION %s / VI  ·  %d / %d ROOMS EXPLORED%s" % [_roman(viewed_section), visited, int(info.get("room_count", 11)), "  ·  HISTORY" if viewed_section < Graph.active_section(run_state) else ""]
+	_progress.text = "SECTION %s/VI · %d/%d ROOMS EXPLORED%s" % [_roman(viewed_section), visited, int(info.get("room_count", 11)), " · HISTORY" if viewed_section < Graph.active_section(run_state) else ""]
@@ -945,2 +945,2 @@ static func type_description(type: String) -> String:
-		"combat": return "Defeat every foe."
-		"guardian": return "A tough foe holds this room. Richer rewards."
+		"combat": return "Defeat every enemy."
+		"guardian": return "A tough enemy holds this room. Richer rewards."
@@ -1028 +1028 @@ func _refresh_actions() -> void:
-	_scout.text = "Cancel Scout" if scout_targeting else "Scout · %d / 2" % uses
+	_scout.text = "Cancel Scout" if scout_targeting else "Scout · %d/2" % uses
diff --git a/scripts/settings_panel.gd b/scripts/settings_panel.gd
index d663cf063..e3ab1c71d 100644
--- a/scripts/settings_panel.gd
+++ b/scripts/settings_panel.gd
@@ -171 +171 @@ func _build_header() -> Control:
-	title.text = "SETTINGS"
+	title.text = "Settings"
@@ -260 +260 @@ func _build_accessibility_section() -> Control:
-	rows.add_child(_setting_row("Board health bars", "", health_option))
+	rows.add_child(_setting_row("Board Health Bars", "", health_option))
@@ -314 +314 @@ func _build_footer() -> Control:
-	confirm.text = "Reset all"
+	confirm.text = "Reset All"
@@ -338 +338 @@ func _build_footer() -> Control:
-	restore.text = "Restore defaults"
+	restore.text = "Restore Defaults"
@@ -532 +532 @@ func _update_reduced_motion_button(button: Button) -> void:
-	button.text = "On — less motion" if button.button_pressed else "Off — full motion"
+	button.text = "On — Less Motion" if button.button_pressed else "Off — Full Motion"
diff --git a/scripts/skill_tree_view.gd b/scripts/skill_tree_view.gd
index 8588df07f..8af1a6aac 100644
--- a/scripts/skill_tree_view.gd
+++ b/scripts/skill_tree_view.gd
@@ -1099 +1099 @@ func _build_detail_panel() -> Control:
-	_detail_content.add_child(CharacterMenuView.section("SKILL DETAILS"))
+	_detail_content.add_child(CharacterMenuView.section("Skill Details"))
@@ -1190 +1190 @@ func _refresh_summary() -> void:
-	_summary_label.text = "LEARNED %d  ·  POINTS %d" % [_owned_ids.size(), _unspent_points]
+	_summary_label.text = "LEARNED %d · POINTS %d" % [_owned_ids.size(), _unspent_points]
@@ -1299 +1299 @@ func _refresh_detail() -> void:
-	_detail_activation.text = "TIMING  ·  %s" % SkillTreeLibrary.activation_kind(_focused_id).to_upper()
+	_detail_activation.text = "TIMING · %s" % SkillTreeLibrary.activation_kind(_focused_id).to_upper()
@@ -1323 +1323 @@ func _refresh_detail_action(state: String) -> void:
-		_detail_action.text = "Learn  ·  1 Point"
+		_detail_action.text = "Learn · 1 Point"
@@ -1502 +1502 @@ func _node_state_text(skill_id: String, state: String) -> String:
-			return "+  AVAILABLE"
+			return "+ AVAILABLE"
@@ -1504 +1504 @@ func _node_state_text(skill_id: String, state: String) -> String:
-			return "X  EXCLUSIVE"
+			return "X EXCLUSIVE"
@@ -1506 +1506 @@ func _node_state_text(skill_id: String, state: String) -> String:
-			return "-  LOCKED"
+			return "- LOCKED"
@@ -1522 +1522 @@ func _detail_status_text(skill_id: String, state: String) -> String:
-	return "%s  ·  %s  ·  %s" % [tier, _node_state_text(skill_id, state), activation]
+	return "%s · %s · %s" % [tier, _node_state_text(skill_id, state), activation]
@@ -1540 +1540 @@ func _requirements_text(skill_id: String) -> String:
-		parts.append("%s  %s" % [
+		parts.append("%s · %s" % [
@@ -1545 +1545 @@ func _requirements_text(skill_id: String) -> String:
-		parts.append("NONE  Root skill")
+		parts.append("NONE · Root skill")
@@ -1549 +1549 @@ func _requirements_text(skill_id: String) -> String:
-		parts.append("%s  %d other skills learned" % ["READY" if other_skill_count >= minimum_owned else "NEED", minimum_owned])
+		parts.append("%s · %d other skills learned" % ["READY" if other_skill_count >= minimum_owned else "NEED", minimum_owned])
@@ -1551 +1551 @@ func _requirements_text(skill_id: String) -> String:
-		parts.append("LIMIT  One keystone per build")
+		parts.append("LIMIT · One keystone per build")
@@ -1561 +1561 @@ func _unlocks_text(skill_id: String) -> String:
-	return "LEADS TO\n%s" % "  ·  ".join(names)
+	return "LEADS TO\n%s" % " · ".join(names)
diff --git a/scripts/status_tick_feedback.gd b/scripts/status_tick_feedback.gd
index 24f2afb31..0029eb278 100644
--- a/scripts/status_tick_feedback.gd
+++ b/scripts/status_tick_feedback.gd
@@ -39 +39 @@ static func player_losses(scene: Control, before: Dictionary, after: Dictionary,
-			status_entry["text"] = "-%d%s" % [tick, suffix]
+			status_entry["text"] = "−%d%s" % [tick, suffix]
@@ -43 +43 @@ static func player_losses(scene: Control, before: Dictionary, after: Dictionary,
-			entry["text"] = "-%d%s" % [loss - tick, suffix]
+			entry["text"] = "−%d%s" % [loss - tick, suffix]
\`\`\`

</details>

## Exact test re-pins

The staged director files and historical before snapshots still serve as the baseline. The diff lists the expectation changes against that baseline.

<details>
<summary>Exact-string expectations and fixtures</summary>

\`\`\`diff
diff --git a/tests/card_keywords_w3_probe.gd b/tests/card_keywords_w3_probe.gd
index 142343356..c9b1ea090 100644
--- a/tests/card_keywords_w3_probe.gd
+++ b/tests/card_keywords_w3_probe.gd
@@ -94 +94 @@ func _run() -> void:
-		expect(badge != null and str(badge.tooltip_text).contains("Quickened: -2"), "The Time badge explains the Quicken discount")
+		expect(badge != null and str(badge.tooltip_text).contains("Quickened: −2"), "The Time badge explains the Quicken discount")
diff --git a/tests/combat_objective_probe.gd b/tests/combat_objective_probe.gd
index a89daffa4..5c0125745 100644
--- a/tests/combat_objective_probe.gd
+++ b/tests/combat_objective_probe.gd
@@ -92 +92 @@ func _capture_leader(instance: Node, fixture: Dictionary) -> void:
-	_assert_live_hud(instance, "KILL THE LEADER", "HP")
+	_assert_live_hud(instance, CombatObjectiveRules.hud_title_for_objective(objective), "Health")
@@ -130 +130 @@ func _capture_survive(instance: Node, fixture: Dictionary) -> void:
-	_assert_live_hud(instance, "SURVIVE", "Reinforcements in 8")
+	_assert_live_hud(instance, "Survive", "Reinforcements in 8")
@@ -149 +149 @@ func _capture_exit(instance: Node, fixture: Dictionary) -> void:
-	_assert_live_hud(instance, "REACH THE EXIT", "marked threshold")
+	_assert_live_hud(instance, "Reach the Exit", "marked threshold")
diff --git a/tests/contextual_combat_tutorial_test.gd b/tests/contextual_combat_tutorial_test.gd
index 98e119e33..37512c253 100644
--- a/tests/contextual_combat_tutorial_test.gd
+++ b/tests/contextual_combat_tutorial_test.gd
@@ -52 +52 @@ func _test_curriculum_catalog() -> void:
-	_assert(str(choose_move.get("pointer_text", "")) == "You begin each turn with 2 movement. Use 1 to move onto the glowing tile.", "The destination prompt should teach the movement allowance before the action")
+	_assert(str(choose_move.get("pointer_text", "")) == "You begin each turn with 2 Movement. Use 1 to move onto the glowing tile.", "The destination prompt should teach the movement allowance before the action")
diff --git a/tests/controller_screen_sweep.gd b/tests/controller_screen_sweep.gd
index d3c32090b..dc5f8f4df 100644
--- a/tests/controller_screen_sweep.gd
+++ b/tests/controller_screen_sweep.gd
@@ -231 +231 @@ func _menu_screens() -> void:
-	var restore: Button = _button_text(panel, "Restore defaults")
+	var restore: Button = _button_text(panel, "Restore Defaults")
diff --git a/tests/demo_end_panel_test.gd b/tests/demo_end_panel_test.gd
index 12f664225..f64f1d4ac 100644
--- a/tests/demo_end_panel_test.gd
+++ b/tests/demo_end_panel_test.gd
@@ -188 +188 @@ func _test_quiet_link() -> void:
-	link.text = "VIEW IN THE CHRONICLE ›"
+	link.text = "View in the Chronicle ›"
diff --git a/tests/fixtures/card_panel_examples.json b/tests/fixtures/card_panel_examples.json
index c079da38e..7ff0aaae2 100644
--- a/tests/fixtures/card_panel_examples.json
+++ b/tests/fixtures/card_panel_examples.json
@@ -43 +43 @@
-        "text": "Raises an outcrop with this much Health that blocks movement and sight."
+        "text": "Raises an Outcrop with this much Health that blocks movement and sight."
@@ -152 +152 @@
-        "text": "Destroy an outcrop, crate or other terrain in range and sight."
+        "text": "Destroy an Outcrop, crate or other terrain in range and sight."
@@ -161 +161 @@
-        "text": "Destroy an adjacent outcrop or Worldspine you raised."
+        "text": "Destroy an adjacent Outcrop or Worldspine you raised."
@@ -416 +416 @@
-        "text": "Place the outcrop within this range."
+        "text": "Place the Outcrop within this range."
diff --git a/tests/fixtures/card_panel_grimoire_facts.json b/tests/fixtures/card_panel_grimoire_facts.json
index 421669d5b..c37506f34 100644
--- a/tests/fixtures/card_panel_grimoire_facts.json
+++ b/tests/fixtures/card_panel_grimoire_facts.json
@@ -34 +34 @@
-      "Outcrop cards raise crag outcrops on empty floor. An outcrop blocks movement and line of sight, can be attacked like other terrain, and leaves Rubble when destroyed."
+      "Outcrop cards raise crag Outcrops on empty floor. An Outcrop blocks movement and line of sight, can be attacked like other terrain, and leaves Rubble when destroyed."
@@ -41 +41 @@
-      "Crystal Mantle cards give you the same layers: each direct hit against you breaks one layer instead of dealing damage. Fire, Bleed, collisions, traps and health costs bypass it. Your layers last until broken or the combat ends."
+      "Crystal Mantle cards give you the same layers: each direct hit against you breaks one layer instead of dealing damage. Fire, Bleed, collisions, traps and Health costs bypass it. Your layers last until broken or the combat ends."
@@ -112 +112 @@
-      "in an area push each enemy moves along its own straight line; stopped lines collide."
+      "In an area Push each enemy moves along its own straight line; stopped lines collide."
diff --git a/tests/health_cost_preview_probe.gd b/tests/health_cost_preview_probe.gd
index 986271ab2..a9f236dc8 100644
--- a/tests/health_cost_preview_probe.gd
+++ b/tests/health_cost_preview_probe.gd
@@ -111 +111 @@ func _check_case(config: Dictionary) -> void:
-			if risk != null and risk.is_visible_in_tree() and risk.text == "CARD COST\nDEFIANCE -1": break
+			if risk != null and risk.is_visible_in_tree() and risk.text == "CARD COST\nDEFIANCE −1": break
@@ -113 +113 @@ func _check_case(config: Dictionary) -> void:
-		expect(risk != null and risk.is_visible_in_tree() and risk.text == "CARD COST\nDEFIANCE -1", "The visible confirmation risk discloses the payment's spent Defiance")
+		expect(risk != null and risk.is_visible_in_tree() and risk.text == "CARD COST\nDEFIANCE −1", "The visible confirmation risk discloses the payment's spent Defiance")
diff --git a/tests/helpers/brs01_catalog.gd b/tests/helpers/brs01_catalog.gd
index f677dfc37..f3638b6cc 100644
--- a/tests/helpers/brs01_catalog.gd
+++ b/tests/helpers/brs01_catalog.gd
@@ -8 +8,2 @@ static func matches(staged: String, live: String) -> bool:
-	expected = expected.replace('"last_light": {\n', '"last_light": {\n   "objective_title": "Survive until dawn!",\n   "objective_hud_title": "Survive until dawn",\n')
+	expected = expected.replace('"last_light": {\n', '"last_light": {\n   "objective_title": "Survive Until Dawn!",\n   "objective_hud_title": "Survive Until Dawn",\n')
+	expected = expected.replace("+%d embers", "+%d Embers")
diff --git a/tests/pre_battle_view_test.gd b/tests/pre_battle_view_test.gd
index e8ff33811..3f80721c8 100644
--- a/tests/pre_battle_view_test.gd
+++ b/tests/pre_battle_view_test.gd
@@ -144 +144 @@ func _run_input_proof() -> void:
-	_expect(hint.visible and hint.text == "Focus or select a foe to read its moves", "Foe hint switches to visible controller wording")
+	_expect(hint.visible and hint.text == "Focus or select an enemy to read its moves", "Foe hint switches to visible controller wording")
@@ -146 +146 @@ func _run_input_proof() -> void:
-	_expect(hint.visible and hint.text == "Hover or select a foe to read its moves", "Foe hint switches back to unchanged pointer wording")
+	_expect(hint.visible and hint.text == "Hover or select an enemy to read its moves", "Foe hint switches back to unchanged pointer wording")
diff --git a/tests/reward_decision_support_probe.gd b/tests/reward_decision_support_probe.gd
index 03b1779f7..930d78a52 100644
--- a/tests/reward_decision_support_probe.gd
+++ b/tests/reward_decision_support_probe.gd
@@ -451 +451 @@ func _assert_reward_layout(
-	if title == null or title.text != "GROW YOUR POWER" or not title.visible:
+	if title == null or title.text != "Grow Your Power" or not title.visible:
@@ -470 +470 @@ func _assert_reward_layout(
-		if reroll_button.text != "REROLL":
+		if reroll_button.text != "Reroll":
@@ -507 +507 @@ func _assert_reward_layout(
-		if recover_button.text != "SKIP  •  HEALTH FULL":
+		if recover_button.text != "Skip · Health Full":
@@ -510 +510 @@ func _assert_reward_layout(
-		if not recover_button.text.contains("SKIP & RECOVER"):
+		if not recover_button.text.contains("Skip & Recover"):
@@ -569 +569 @@ func _assert_relic_layout(instance: Node, resolution: Vector2i, ui_scale: float)
-	if title == null or title.text != "CLAIM YOUR TREASURE" or not title.visible:
+	if title == null or title.text != "Claim Your Treasure" or not title.visible:
diff --git a/tests/run_score_test.gd b/tests/run_score_test.gd
index b139ce610..08ee8c2d2 100644
--- a/tests/run_score_test.gd
+++ b/tests/run_score_test.gd
@@ -212 +212 @@ func _assert_recap_presentation(overlay: Control, outcome: String) -> void:
-	_assert(chronicle.get_parent() == column and chronicle.position.x == 0 and chronicle.position.y > embers.position.y and chronicle.text == "VIEW IN THE CHRONICLE ›", "The Chronicle is a link in the recap column, below the summary")
+	_assert(chronicle.get_parent() == column and chronicle.position.x == 0 and chronicle.position.y > embers.position.y and chronicle.text == "View in the Chronicle ›", "The Chronicle is a link in the recap column, below the summary")
diff --git a/tests/run_tests.gd b/tests/run_tests.gd
index 866c15986..1cade486f 100644
--- a/tests/run_tests.gd
+++ b/tests/run_tests.gd
@@ -2538 +2538 @@ func _test_bleed_status_badges_and_trigger_floats() -> void:
-		_assert(str(bleed_float.get("text", "")) == "-50", "Bleed trigger float should still show the damage number")
+		_assert(str(bleed_float.get("text", "")) == "−50", "Bleed trigger float should still show the damage number")
@@ -6524 +6524 @@ func _test_run_scene_pass_preview_chip_updates() -> void:
-	_assert_pass_preview_chip(instance, ["-5"], false, false, "danger pass")
+	_assert_pass_preview_chip(instance, ["−5"], false, false, "danger pass")
@@ -6551 +6551 @@ func _test_run_scene_pass_preview_chip_updates() -> void:
-	_assert_pass_preview_chip(instance, ["-%d" % wait_lapping_live], false, false, "Wait lapping pass at +19")
+	_assert_pass_preview_chip(instance, ["−%d" % wait_lapping_live], false, false, "Wait lapping pass at +19")
@@ -6561 +6561 @@ func _test_run_scene_pass_preview_chip_updates() -> void:
-	_assert_pass_preview_chip(instance, ["-4", "-5"], false, false, "layered pass")
+	_assert_pass_preview_chip(instance, ["−4", "−5"], false, false, "layered pass")
@@ -6566 +6566 @@ func _test_run_scene_pass_preview_chip_updates() -> void:
-	_assert_pass_preview_chip(instance, ["-1", "4"], false, false, "Defiance plus follow-up damage pass")
+	_assert_pass_preview_chip(instance, ["−1", "4"], false, false, "Defiance plus follow-up damage pass")
@@ -6572 +6572 @@ func _test_run_scene_pass_preview_chip_updates() -> void:
-	_assert(defiance_risk_text.contains("DEFIANCE -1") and defiance_risk_text.contains("4 HP") and defiance_risk_text.contains("0 LEFT"), "Action-context risk should show both the spent charge and resulting HP")
+	_assert(defiance_risk_text.contains("DEFIANCE −1") and defiance_risk_text.contains("4 HEALTH") and defiance_risk_text.contains("0 LEFT"), "Action-context risk should show both the spent charge and resulting HP")
@@ -6599 +6599 @@ func _test_run_scene_pass_preview_chip_updates() -> void:
-	_assert_pass_preview_chip(instance, ["-%d" % repeat_live], false, false, "repeat-activation pass")
+	_assert_pass_preview_chip(instance, ["−%d" % repeat_live], false, false, "repeat-activation pass")
@@ -7193 +7193 @@ func _test_run_scene_reward_heal_choice_sits_below_cards() -> void:
-		_assert(recover_button.text.contains("SKIP & RECOVER"), "Recover should explicitly communicate that every card is skipped")
+		_assert(recover_button.text.contains("Skip & Recover"), "Recover should explicitly communicate that every card is skipped")
@@ -7300 +7300 @@ func _test_run_scene_reward_decision_support_matches_claims() -> void:
-	_assert(recover_button != null and recover_button.text.contains("SKIP & RECOVER"), "The secondary health action should make its skip consequence explicit")
+	_assert(recover_button != null and recover_button.text.contains("Skip & Recover"), "The secondary health action should make its skip consequence explicit")
@@ -7334 +7334 @@ func _test_run_scene_reward_decision_support_matches_claims() -> void:
-	_assert(recover_button != null and recover_button.text == "SKIP  •  HEALTH FULL", "Full-health skip should say health is full and promise no healing")
+	_assert(recover_button != null and recover_button.text == "Skip · Health Full", "Full-health skip should say health is full and promise no healing")
@@ -7427 +7427 @@ func _test_run_scene_selection_prompts_clear_after_pick() -> void:
-	_assert(prompt_title != null and prompt_title.visible and prompt_title.text == "GROW YOUR POWER", "Card reward selection should use the Grow your power prompt")
+	_assert(prompt_title != null and prompt_title.visible and prompt_title.text == "Grow Your Power", "Card reward selection should use the Grow your power prompt")
@@ -7445 +7445 @@ func _test_run_scene_selection_prompts_clear_after_pick() -> void:
-	_assert(prompt_title != null and prompt_title.visible and prompt_title.text == "CLAIM YOUR TREASURE", "Relic selection should keep the treasure prompt")
+	_assert(prompt_title != null and prompt_title.visible and prompt_title.text == "Claim Your Treasure", "Relic selection should keep the treasure prompt")
@@ -7515 +7515 @@ func _test_run_scene_fatigue_damage_visual_event() -> void:
-		found_damage_number = found_damage_number or str(text_entry.get("text", "")) == "-2"
+		found_damage_number = found_damage_number or str(text_entry.get("text", "")) == "−2"
@@ -10057,2 +10057,2 @@ func _test_settings_persistence_audio_and_presentation_preferences() -> void:
-	var restore_button: Button = _button_with_text(menu_settings_panel, "Restore defaults")
-	_assert(restore_button != null, "Settings should expose Restore defaults")
+	var restore_button: Button = _button_with_text(menu_settings_panel, "Restore Defaults")
+	_assert(restore_button != null, "Settings should expose Restore Defaults")
@@ -10060,2 +10060,2 @@ func _test_settings_persistence_audio_and_presentation_preferences() -> void:
-		_assert_button_text_centered(restore_button, "Settings Restore defaults")
-		_assert(str(restore_button.get_meta("button_variant", "")) == UiSkin.VARIANT_DESTRUCTIVE, "Restore defaults should use the destructive themed variant")
+		_assert_button_text_centered(restore_button, "Settings Restore Defaults")
+		_assert(str(restore_button.get_meta("button_variant", "")) == UiSkin.VARIANT_DESTRUCTIVE, "Restore Defaults should use the destructive themed variant")
@@ -10064 +10064 @@ func _test_settings_persistence_audio_and_presentation_preferences() -> void:
-	_assert(confirmation_panel != null and confirmation_panel.visible, "Restore defaults should require a deliberate confirmation step")
+	_assert(confirmation_panel != null and confirmation_panel.visible, "Restore Defaults should require a deliberate confirmation step")
@@ -10066,2 +10066,2 @@ func _test_settings_persistence_audio_and_presentation_preferences() -> void:
-	var confirm_restore: Button = _button_with_text(confirmation_panel, "Reset all")
-	_assert(confirm_restore != null, "Restore confirmation should expose an explicit Reset all action")
+	var confirm_restore: Button = _button_with_text(confirmation_panel, "Reset All")
+	_assert(confirm_restore != null, "Restore confirmation should expose an explicit Reset All action")
diff --git a/tests/selection_prompt_probe.gd b/tests/selection_prompt_probe.gd
index 402fc473d..a037e0bab 100644
--- a/tests/selection_prompt_probe.gd
+++ b/tests/selection_prompt_probe.gd
@@ -49 +49 @@ func _capture_reward_prompt(instance: Node) -> void:
-	_assert_prompt_ready(instance, "GROW YOUR POWER")
+	_assert_prompt_ready(instance, "Grow Your Power")
@@ -63 +63 @@ func _capture_treasure_prompt(instance: Node) -> void:
-	_assert_prompt_ready(instance, "CLAIM YOUR TREASURE")
+	_assert_prompt_ready(instance, "Claim Your Treasure")
diff --git a/tests/settings_probe.gd b/tests/settings_probe.gd
index 624459697..474a5d071 100644
--- a/tests/settings_probe.gd
+++ b/tests/settings_probe.gd
@@ -127,2 +127,2 @@ func _capture_main_menu_settings(scale: float, suffix: String) -> void:
-		var restore_button: Button = _button_with_text(panel, "Restore defaults")
-		_require(restore_button != null, "Restore defaults should be present in the settings footer")
+		var restore_button: Button = _button_with_text(panel, "Restore Defaults")
+		_require(restore_button != null, "Restore Defaults should be present in the settings footer")
@@ -132 +132 @@ func _capture_main_menu_settings(scale: float, suffix: String) -> void:
-		_require(confirmation != null and confirmation.visible, "Restore defaults should open a confirmation step")
+		_require(confirmation != null and confirmation.visible, "Restore Defaults should open a confirmation step")
diff --git a/tests/short_card_tooltips_test.gd b/tests/short_card_tooltips_test.gd
index d35613764..6eb905bbb 100644
--- a/tests/short_card_tooltips_test.gd
+++ b/tests/short_card_tooltips_test.gd
@@ -37,0 +38,6 @@ const TRP01_TRAP_BODY: Array = [
+const HOUSE_STYLE_GRIMOIRE := {
+	"skate": "This turn, stepping onto Ice costs no Movement, and Ice doesn't make you Chilled.",
+	"surface_electrified": "A Lightning hit that touches it spreads to every enemy on connected Electrified tiles. Chain relays through it.",
+	"targeting": "Targets must be visible and within Range. Ranged attacks also need line of sight; walls and Outcrops block it.",
+}
+
@@ -61,0 +68,2 @@ func _run() -> void:
+	superseding["surface_rubble"] = "Costs 2 Movement to leave."
+	superseding["skate"] = "This turn, Ice costs no Movement and doesn't Chill you."
@@ -90 +98 @@ func _run() -> void:
-			_expect((entry.get("body", []) as Array).has(UMBRA_AREA_BODY if id == "umbra" else change["old"]), "Full rules remain in their expected owning topic: " + id + " -> " + owner)
+			_expect((entry.get("body", []) as Array).has(UMBRA_AREA_BODY if id == "umbra" else HOUSE_STYLE_GRIMOIRE.get(id, change["old"])), "Full rules remain in their expected owning topic: " + id + " -> " + owner)
@@ -111 +119 @@ func _test_new_entry_schema(changes: Dictionary, entry_map: Dictionary) -> void:
-		var expected_body: Array = [changes[term]["old"]]
+		var expected_body: Array = [HOUSE_STYLE_GRIMOIRE.get(term, changes[term]["old"])]
diff --git a/tests/skill_ui_test.gd b/tests/skill_ui_test.gd
index dc35851b8..3ddef0b6f 100644
--- a/tests/skill_ui_test.gd
+++ b/tests/skill_ui_test.gd
@@ -1120 +1120 @@ func _test_reward_reroll(instance: Node) -> void:
-		_expect(reroll_button.text == "REROLL", "Reward reroll should use the compact secondary-action label")
+		_expect(reroll_button.text == "Reroll", "Reward reroll should use the compact secondary-action label")
diff --git a/tests/suites/card_keywords_suite.gd b/tests/suites/card_keywords_suite.gd
index 46332f313..ee676f3c3 100644
--- a/tests/suites/card_keywords_suite.gd
+++ b/tests/suites/card_keywords_suite.gd
@@ -167 +167 @@ static func _test_rules_helpers(expect: Callable) -> void:
-	expect.call(CardKeywordRules.empower_cost_label({"time": 2}) == "+2 Time" and CardKeywordRules.empower_cost_label({"health": 1}) == "1 HP" and CardKeywordRules.empower_cost_label({"exhaust": true}) == "Exhaust", "Empower cost labels name each cost")
+	expect.call(CardKeywordRules.empower_cost_label({"time": 2}) == "+2 Time" and CardKeywordRules.empower_cost_label({"health": 1}) == "1 Health" and CardKeywordRules.empower_cost_label({"exhaust": true}) == "Exhaust", "Empower cost labels name each cost")
diff --git a/tests/suites/card_keywords_w3_suite.gd b/tests/suites/card_keywords_w3_suite.gd
index e6ad86c28..c48e8c496 100644
--- a/tests/suites/card_keywords_w3_suite.gd
+++ b/tests/suites/card_keywords_w3_suite.gd
@@ -515 +515 @@ static func _test_presentation_contracts(engine: CombatEngine, expect: Callable)
-	expect.call(thorn_rows.size() == 2 and thorn_cost_row.size() == 2 and str((thorn_cost_row[0] as Dictionary).get("icon", "")) == "rite" and str((thorn_cost_row[1] as Dictionary).get("icon", "")) == "health_cost" and str((thorn_cost_row[1] as Dictionary).get("value", "")) == "-2", "A Rite card leads with a labelled Rite keyword row and its health cost")
+	expect.call(thorn_rows.size() == 2 and thorn_cost_row.size() == 2 and str((thorn_cost_row[0] as Dictionary).get("icon", "")) == "rite" and str((thorn_cost_row[1] as Dictionary).get("icon", "")) == "health_cost" and str((thorn_cost_row[1] as Dictionary).get("value", "")) == "−2", "A Rite card leads with a labelled Rite keyword row and its health cost")
@@ -551 +551 @@ static func _test_run_scene_hand_display(engine: CombatEngine, expect: Callable)
-	expect.call(not _token_with_icon(rite_rows, "rite").is_empty() and str(_token_with_icon(rite_rows, "health_cost").get("value", "")) == "-2" and rite_rows.size() == 2 and str(((rite_rows[1] as Array)[0] as Dictionary).get("value", "")).begins_with("Enemies that hit you"), "A Rite card in hand shows its Rite keyword and health cost, then its rules text")
+	expect.call(not _token_with_icon(rite_rows, "rite").is_empty() and str(_token_with_icon(rite_rows, "health_cost").get("value", "")) == "−2" and rite_rows.size() == 2 and str(((rite_rows[1] as Array)[0] as Dictionary).get("value", "")).begins_with("Enemies that hit you"), "A Rite card in hand shows its Rite keyword and health cost, then its rules text")
diff --git a/tests/suites/combat_objective_suite.gd b/tests/suites/combat_objective_suite.gd
index 6356bd155..74b5cb4d1 100644
--- a/tests/suites/combat_objective_suite.gd
+++ b/tests/suites/combat_objective_suite.gd
@@ -321 +321 @@ static func _test_boss_live_detail_keeps_facts_without_repeating_name(expect: Ca
-		var facts: String = "%d/%d HP" % [hp, hp]
+		var facts: String = "%d/%d Health" % [hp, hp]
@@ -324 +324 @@ static func _test_boss_live_detail_keeps_facts_without_repeating_name(expect: Ca
-		expect.call(title.text == CombatObjectiveRules.hud_title_for_objective(objective).to_upper(), enemy_type + " retains its exact objective title")
+		expect.call(title.text == CombatObjectiveRules.hud_title_for_objective(objective), enemy_type + " retains its exact objective title")
@@ -327 +327 @@ static func _test_boss_live_detail_keeps_facts_without_repeating_name(expect: Ca
-		expect.call(detail.text.ends_with("0/%d HP" % hp), enemy_type + " retains the zero-health fact during defeat presentation")
+		expect.call(detail.text.ends_with("0/%d Health" % hp), enemy_type + " retains the zero-health fact during defeat presentation")
@@ -333 +333,15 @@ static func _test_boss_live_detail_keeps_facts_without_repeating_name(expect: Ca
-	expect.call((hud.find_child("ObjectiveLiveDetail", true, false) as Label).text == "Before it escapes · 1/2 HP", "Hoarder live detail keeps its existing non-name copy")
+	expect.call((hud.find_child("ObjectiveLiveDetail", true, false) as Label).text == "Before it escapes · 1/2 Health", "Hoarder live detail keeps its existing non-name copy")
+	var dragon: Dictionary = {"type": CombatObjectiveRules.KILL_LEADER, "leader_id": 1, "leader_type": "zekarion"}
+	var dragon_state: Dictionary = {"objective": dragon, "enemies": []}
+	var dragon_title: String = CombatObjectiveRules.title_for_objective(dragon)
+	hud.set_combat_state(dragon_state)
+	expect.call(hud.tooltip_text == dragon_title, "Named leader hover with no description ends at the title")
+	dragon["objective_description"] = "An authored objective sentence."
+	hud.set_combat_state(dragon_state)
+	expect.call(hud.tooltip_text == dragon_title + "\nAn authored objective sentence.", "Named leader hover includes its authored description")
+	for count: int in [0, 1, 2]:
+		var enemies: Array = [{"id": 1, "hp": 1}, {"id": 2, "hp": 1}]
+		hud.set_combat_state({"objective": {"type": CombatObjectiveRules.KILL_ALL}, "enemies": enemies, "visible_enemy_ids": range(1, count + 1)})
+		var detail := hud.find_child("ObjectiveLiveDetail", true, false) as Label
+		var expected: String = "enemy" if count == 1 else "enemies"
+		expect.call(detail.text == "%d known %s remaining" % [count, expected], "Umbra objective uses the known enemy count")
diff --git a/tests/suites/empower_seal_suite.gd b/tests/suites/empower_seal_suite.gd
index a1cf1648a..53d10d2a9 100644
--- a/tests/suites/empower_seal_suite.gd
+++ b/tests/suites/empower_seal_suite.gd
@@ -170 +170 @@ static func _blocked_and_lock(tree: SceneTree, expect: Callable, fixtures: Scrip
-	expect.call(_seal(scene).tooltip_text == "Not enough health: Empower costs 2 HP." and not _seal(scene).get_node("Badge").visible, "Blocked seal gives the exact health explanation and hides the hint")
+	expect.call(_seal(scene).tooltip_text == "Not enough Health: Empower costs 2 Health." and not _seal(scene).get_node("Badge").visible, "Blocked seal gives the exact health explanation and hides the hint")
diff --git a/tests/suites/en02_enemies_suite.gd b/tests/suites/en02_enemies_suite.gd
index ac499dd74..f4605c2f7 100644
--- a/tests/suites/en02_enemies_suite.gd
+++ b/tests/suites/en02_enemies_suite.gd
@@ -348 +348 @@ static func _additional_boundaries(engine: RefCounted, expect: Callable) -> void
-	expect.call(feedback.size() == 2 and feedback[0]["text"] == "-2" and feedback[1]["text"] == "-5", "Mechanic feedback retains player and friendly-fire damage numbers")
+	expect.call(feedback.size() == 2 and feedback[0]["text"] == "−2" and feedback[1]["text"] == "−5", "Mechanic feedback retains player and friendly-fire damage numbers")
diff --git a/tests/suites/fix_12_reactions_suite.gd b/tests/suites/fix_12_reactions_suite.gd
index fb1f72251..bcd348b71 100644
--- a/tests/suites/fix_12_reactions_suite.gd
+++ b/tests/suites/fix_12_reactions_suite.gd
@@ -116 +116 @@ static func run_playback(tree: SceneTree, scene: Control, expect: Callable, supp
-			expect.call(crawler.size() == 1 and crawler[0]["phase"] == "retaliate" and crawler[0]["entry"]["text"] == "-2", "Mimic collateral crawler popup appears once on Retaliate")
+			expect.call(crawler.size() == 1 and crawler[0]["phase"] == "retaliate" and crawler[0]["entry"]["text"] == "−2", "Mimic collateral crawler popup appears once on Retaliate")
diff --git a/tests/suites/fix_14_bleed_suite.gd b/tests/suites/fix_14_bleed_suite.gd
index e217a9d67..7ee620938 100644
--- a/tests/suites/fix_14_bleed_suite.gd
+++ b/tests/suites/fix_14_bleed_suite.gd
@@ -30 +30 @@ static func check_status_tick_feedback(scene: Control, expect: Callable) -> void
-	expect.call(bleed.size() == 1 and bleed[0].get("icon", "") == "bleed" and bleed[0]["text"] == "-3", "An actual hero Bleed payment carries the Bleed cause icon")
+	expect.call(bleed.size() == 1 and bleed[0].get("icon", "") == "bleed" and bleed[0]["text"] == "−3", "An actual hero Bleed payment carries the Bleed cause icon")
@@ -34 +34 @@ static func check_status_tick_feedback(scene: Control, expect: Callable) -> void
-	expect.call(mixed_floats.size() == 2 and mixed_floats[0]["text"] == "-3" and mixed_floats[0].get("icon", "") == "bleed" and mixed_floats[1]["text"] == "-2" and not mixed_floats[1].has("icon"), "Mixed damage attributes only the actual Bleed payment, preserving the total loss")
+	expect.call(mixed_floats.size() == 2 and mixed_floats[0]["text"] == "−3" and mixed_floats[0].get("icon", "") == "bleed" and mixed_floats[1]["text"] == "−2" and not mixed_floats[1].has("icon"), "Mixed damage attributes only the actual Bleed payment, preserving the total loss")
diff --git a/tests/suites/hoarder_suite.gd b/tests/suites/hoarder_suite.gd
index b6b22da67..c9a46e6e1 100644
--- a/tests/suites/hoarder_suite.gd
+++ b/tests/suites/hoarder_suite.gd
@@ -35 +35 @@ const EXPECTED_EMBLEM: String = "res://assets/art/icons/map/ember_hoarder.png"
-const EXPECTED_REWARD_LINE: String = "The Hoarder's hoard: +%d embers"
+const EXPECTED_REWARD_LINE: String = "The Hoarder's hoard: +%d Embers"
diff --git a/tests/suites/last_light_suite.gd b/tests/suites/last_light_suite.gd
index 20a2f1bf2..32873811a 100644
--- a/tests/suites/last_light_suite.gd
+++ b/tests/suites/last_light_suite.gd
@@ -150 +150 @@ static func _test_layouts(expect: Callable) -> void:
-						"copy": objective["name"] == "Survive until dawn!" and objective["description"] == "Survive until dawn." and Objectives.title_for_objective(objective) == "Survive until dawn!" and Objectives.description_for_objective(objective) == "Survive until dawn.",
+						"copy": objective["name"] == "Survive Until Dawn!" and objective["description"] == "Survive until dawn." and Objectives.title_for_objective(objective) == "Survive Until Dawn!" and Objectives.description_for_objective(objective) == "Survive until dawn.",
diff --git a/tests/suites/mim01_suite.gd b/tests/suites/mim01_suite.gd
index 9f6feabac..d165f94f3 100644
--- a/tests/suites/mim01_suite.gd
+++ b/tests/suites/mim01_suite.gd
@@ -195 +195 @@ static func run_live(tree: SceneTree, expect: Callable) -> void:
-	expect.call(hero_damage.size() == 1 and str(hero_damage[0].get("text", "")) == "-3", "Retaliate uses the existing hero hit feedback once")
+	expect.call(hero_damage.size() == 1 and str(hero_damage[0].get("text", "")) == "−3", "Retaliate uses the existing hero hit feedback once")
diff --git a/tests/suites/pre_battle_ui_suite.gd b/tests/suites/pre_battle_ui_suite.gd
index 8a0f773a7..c154cdbde 100644
--- a/tests/suites/pre_battle_ui_suite.gd
+++ b/tests/suites/pre_battle_ui_suite.gd
@@ -113 +113 @@ static func _test_enemy_detail_semantics(host: Node, expect: Callable) -> void:
-	expect.call(hp_label != null and hp_label.text.begins_with("HP ") and hp_label.get_theme_color("font_color").is_equal_approx(HP_COLOR), "Detailed enemy HP should be isolated on a red line")
+	expect.call(hp_label != null and hp_label.text.begins_with("Health ") and hp_label.get_theme_color("font_color").is_equal_approx(HP_COLOR), "Detailed enemy HP should be isolated on a red line")
diff --git a/tests/suites/special_encounter_suite.gd b/tests/suites/special_encounter_suite.gd
index 8aa3a9e3f..169677b9a 100644
--- a/tests/suites/special_encounter_suite.gd
+++ b/tests/suites/special_encounter_suite.gd
@@ -30 +30,4 @@ static func approved_catalog_text() -> String:
-	return staged.replace(STAGED_THORNMOTHER_SENTENCE, APPROVED_THORNMOTHER_SENTENCE)
+	var approved: String = staged.replace(STAGED_THORNMOTHER_SENTENCE, APPROVED_THORNMOTHER_SENTENCE)
+	approved = approved.replace('"objective_title": "Survive until dawn!"', '"objective_title": "Survive Until Dawn!"')
+	approved = approved.replace('"objective_hud_title": "Survive until dawn"', '"objective_hud_title": "Survive Until Dawn"')
+	return approved.replace("The Hoarder's hoard: +%d embers", "The Hoarder's hoard: +%d Embers")
diff --git a/tests/suites/tooltip_consistency_suite.gd b/tests/suites/tooltip_consistency_suite.gd
index b22872d27..21a5cedaa 100644
--- a/tests/suites/tooltip_consistency_suite.gd
+++ b/tests/suites/tooltip_consistency_suite.gd
@@ -225 +225 @@ static func _test_tooltip_entry_modifier_merging(expect: Callable) -> void:
-		var expected_lines: String = "Empower +4\nRelic +1  Fixture relic" if ordered_tokens[0] == empowered else "Relic +1  Fixture relic\nEmpower +4"
+		var expected_lines: String = "Empower +4\nRelic +1 · Fixture relic" if ordered_tokens[0] == empowered else "Relic +1 · Fixture relic\nEmpower +4"
diff --git a/tests/suites/turn_clock_hud_suite.gd b/tests/suites/turn_clock_hud_suite.gd
index 4b31f6153..6c5a4542a 100644
--- a/tests/suites/turn_clock_hud_suite.gd
+++ b/tests/suites/turn_clock_hud_suite.gd
@@ -111 +111 @@ static func run(tree: SceneTree, expect: Callable, capture_dir: String = "") ->
-	check.call(line == "+10  •  -%d" % live_loss, "pass_lap_known_damage: exact lead and full damage, no 2ND MOVE suffix: %s" % line)
+	check.call(line == "+10  •  −%d" % live_loss, "pass_lap_known_damage: exact lead and full damage, no 2ND MOVE suffix: %s" % line)
@@ -114 +114 @@ static func run(tree: SceneTree, expect: Callable, capture_dir: String = "") ->
-	check.call(risk_text == "WAIT +10 · -%d HP" % live_loss, "The action context states the full known HP damage: %s" % risk_text)
+	check.call(risk_text == "WAIT +10 · −%d HEALTH" % live_loss, "The action context states the full known HP damage: %s" % risk_text)
@@ -396 +396 @@ static func _assert_badge_tooltip(scene: Node, expect: Callable) -> void:
-	expect.call(badge.tooltip_text.ends_with("\nQuickened: -1"), "The Time badge preserves modifier lines")
+	expect.call(badge.tooltip_text.ends_with("\nQuickened: −1"), "The Time badge preserves modifier lines")
diff --git a/tests/test_card_panel_text.py b/tests/test_card_panel_text.py
index 8699ab314..2d32358ca 100644
--- a/tests/test_card_panel_text.py
+++ b/tests/test_card_panel_text.py
@@ -30,0 +31 @@ class CardPanelTextTest(unittest.TestCase):
+        outcrop_rows = {"raise_outcrop", "terrain_burst_any", "terrain_burst_own", "range_outcrop"}
@@ -33 +34,4 @@ class CardPanelTextTest(unittest.TestCase):
-                self.assertEqual(templates[key]["text"], rows[key]["text"])
+                expected = rows[key]["text"]
+                if key in outcrop_rows:
+                    expected = expected.replace("outcrop", "Outcrop")
+                self.assertEqual(templates[key]["text"], expected)
@@ -56 +60,6 @@ class CardPanelTextTest(unittest.TestCase):
-                self.assertEqual(facts[row["id"]]["paragraphs"], [row["grimoire"].split(": ", 1)[1]])
+                expected = row["grimoire"].split(": ", 1)[1]
+                if row["id"] == "raise_outcrop":
+                    expected = expected.replace(" outcrop", " Outcrop")
+                if row["id"] == "title_sentence_push_area":
+                    expected = expected.replace("in an area push", "In an area Push")
+                self.assertEqual(facts[row["id"]]["paragraphs"], [expected])
diff --git a/tests/test_short_card_tooltips.py b/tests/test_short_card_tooltips.py
index 5585aa43d..498ac97a0 100644
--- a/tests/test_short_card_tooltips.py
+++ b/tests/test_short_card_tooltips.py
@@ -16,0 +17,5 @@ EXPECTATIONS = ROOT / "tests/fixtures/short_card_tooltips_expectations.json"
+HOUSE_STYLE_GRIMOIRE = {
+    "skate": "This turn, stepping onto Ice costs no Movement, and Ice doesn\'t make you Chilled.",
+    "surface_electrified": "A Lightning hit that touches it spreads to every enemy on connected Electrified tiles. Chain relays through it.",
+    "targeting": "Targets must be visible and within Range. Ranged attacks also need line of sight; walls and Outcrops block it.",
+}
@@ -38,0 +44,2 @@ class ShortCardTooltipsTest(unittest.TestCase):
+        self.superseding["surface_rubble"] = "Costs 2 Movement to leave."
+        self.superseding["skate"] = "This turn, Ice costs no Movement and doesn't Chill you."
@@ -92 +99 @@ class ShortCardTooltipsTest(unittest.TestCase):
-                    self.assertIn(UMBRA_AREA_BODY if change["id"] == "umbra" else change["old"], entries[owner]["body"],
+                    self.assertIn(UMBRA_AREA_BODY if change["id"] == "umbra" else HOUSE_STYLE_GRIMOIRE.get(change["id"], change["old"]), entries[owner]["body"],
@@ -118 +125 @@ class ShortCardTooltipsTest(unittest.TestCase):
-                expected_body = [changes[term]["old"]]
+                expected_body = [HOUSE_STYLE_GRIMOIRE.get(term, changes[term]["old"])]
diff --git a/tests/text_budget_test.py b/tests/text_budget_test.py
index ad28da666..97ebfb9c2 100644
--- a/tests/text_budget_test.py
+++ b/tests/text_budget_test.py
@@ -98,0 +99,2 @@ class TextBudgetTest(unittest.TestCase):
+        short_copy["surface_rubble"] = "Costs 2 Movement to leave."
+        short_copy["skate"] = "This turn, Ice costs no Movement and doesn't Chill you."
@@ -101 +103 @@ class TextBudgetTest(unittest.TestCase):
-                          "definition": "When it dies, it splits into smaller foes next to it."}
+                          "definition": "When it dies, it splits into smaller enemies next to it."}
\`\`\`

</details>
