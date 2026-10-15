# UX-04 implementation handoff

Changes are uncommitted on `codex/ux-04`. The design owner owns commit, review, inspection fixture and publication. Protected staged text inputs were read, never edited.

## Requirement coverage

1. All 145 live approved glossary rows are installed, including the six text-only entries and 29 approved skill definitions. The three deleted rows and dead registry labels are removed. Approved aliases plus legacy display spellings remain resolvable. `chain_discharge` resolves to Charge. Enemy definition copies and step/threat labels use the glossary.
2. Approved renames are applied at the blast radius, with IDs and rules preserved. The Briar Weaver intent remains Thornwall. Item Consume remains distinct from ground Expend. Worldbreak names an Outcrop or Worldspine you raised, as the director's follow-up specifies.
3. `@term` supplies icon plus live name, `@kw` supplies the word without an icon, and `|Form` preserves the authored inflection. Both word forms use native RichTextLabel glossary hints. Unknown keys fail validation. Token words use `InlineIconText.KEYWORD_COLOR = UiPalette.GOLD_BRIGHT`, inherit host typography, and have no hint underline. Card rules and event text use the same renderer.
4. All 100 active relic names/descriptions exactly match the protected JSON. The 12 retired rows are unchanged. No card/relic mechanics, IDs, or existing save/analytics keys were changed.
5. Time artwork on duration chips is retained with Turns tooltips. The Movement meter uses its own entry and production framed tooltip. Hollow Gale's two existing actions carry presentation-only `glossary_key: gale_force`; their action types, damage, targeting and timing are unchanged.
6. `text_budget_test.py` enforces glossary ≤20 words and active relic ≤25 words, counting each token as one word. It checks exact approved copy and explicit concepts across data and scripts. `test_text_budget.py` includes it in normal discovery. Coverage also checks rendered card rows, status icons and enemy action identities. The Consume-prose TODO is removed.
7. Text pins were updated to exact approved wording without relaxing mechanics or layout assertions. The eleven card body-line expectations changed by renamed heading recognition are explicitly enumerated in `glossary_test.gd`. The card pixel probe renders the frozen legacy layout and current layout with the same approved copy for exact RGBA comparison; it separately preserves the historical-copy capture. Quick Stab's changed panels are Time and Melee. Pixel equality is pending windowed execution.

## Initial implementation validation

Commands ran from this worktree. Every Godot launch used `python3 tools/godot_task_runner.py --task-id ux-04 --stream -- godot --headless --path . --script <script>`; the full suite adds `--timeout 900` before `--`. Logic-only probe runs add `-- --verify-logic` (and the glossary probe adds `--compare-original-card`).

| Check | Exact observed result |
| --- | --- |
| `python3 -m unittest discover -s tests -p 'test_*.py' -v` | `Ran 448 tests in 255.491s` / `OK (skipped=61)` |
| `python3 tests/text_budget_test.py` | `Ran 4 tests in 0.030s` / `OK` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 3.009s` / `OK` |
| `python3 tests/test_icon_identity_policy.py` | `Ran 7 tests in 0.086s` / `OK` |
| `tests/glossary_test.gd` | `GLOSSARY TEST RESULT: PASS (6922 checks, 0 failures)` |
| `tests/inline_icon_description_test.gd` | `INLINE ICON DESCRIPTION TEST RESULT: PASS` |
| `tests/en01_enemies_test.gd` | `EN01 ENEMIES TEST RESULT: PASS` |
| `tests/en02_enemies_test.gd` | `EN02 ENEMIES TEST RESULT: PASS (235 checks, 0 failures)` |
| `tests/en03_enemies_test.gd` | `EN03 ENEMIES TEST RESULT: PASS (210 checks, 0 failures)` |
| `tests/en04_enemies_test.gd` | `EN04 ENEMIES TEST RESULT: PASS (454 checks, 0 failures)` |
| `tests/en05_enemies_test.gd` | `EN05 ENEMIES TEST RESULT: PASS (179 checks, 0 failures)` |
| `tests/en06_enemies_test.gd` | `EN06 ENEMIES TEST RESULT: PASS (176 checks, 0 failures)` |
| `tests/en05_integration_sync_test.gd` | `EN05 INTEGRATION SYNC: PASS (six protected enemy entries; integration shadows preserved; two en-05 additions)` |
| `tests/relic_u1_test.gd` | `RELIC U1 TEST RESULT: PASS` |
| `tests/card_keywords_test.gd` | `CARD KEYWORDS TEST RESULT: PASS` |
| `tests/card_keywords_w3_test.gd` | `CARD KEYWORDS W3 TEST RESULT: PASS` |
| `tests/maneuver_test.gd` | `MANEUVER TEST RESULT: PASS` |
| `tests/turn_clock_hud_test.gd` | `TURN CLOCK HUD TEST RESULT: PASS` |
| `tests/combat_hud_buttons_test.gd` | `COMBAT HUD BUTTONS TEST: PASS` |
| `tests/scavenger_visual_pass_4_test.gd` | `SCAVENGER VISUAL PASS 4: PASS` |
| `tests/run_end_recap_tests.gd` | `RUN END RECAP TEST RESULT: PASS` |
| Temporary `/private/tmp/ux04_remaining_text_pins.gd`: existing pre-battle, turn-clock copy, relic, fix-03 and surface-action suites | `UX04 REMAINING TEXT PINS: PASS (2578 checks, 0 failures)` |
| `tests/text_rewrite_probe.gd -- --verify-logic` | `TEXT REWRITE PROBE LOGIC: PASS (27 checks, 0 failures)` |
| `tests/glossary_tooltip_probe.gd -- --verify-logic --compare-original-card` | `GLOSSARY PROBE LOGIC RESULT: PASS` |
| `tests/run_tests.gd` full Godot suite | `FULL SUITE RUNTIME: 752.441 seconds (budget 900 seconds)` / `TEST RESULT: PASS` (exit 0) |

The glossary layout check also reported `GLOSSARY ALL-RELIC CHOICE LAYOUT: PASS (112 relics, 336 positions, 1920x1080)`, `GLOSSARY ALL-RELIC OWNED FIT: PASS (112 relics, 336 positions, 1920x1080; 0 two-column cases)`, and `GLOSSARY WRAPPED TRAY: PASS (indices 0,4,9,14; 1920x1080)`. These are headless layout checks, not inspected pixel proof.

Validation logs are `/private/tmp/ux04-*.log`; the full outputs are `/private/tmp/ux04-full-python.log` and `/private/tmp/ux04-full-godot.log`. A read-only data comparison confirmed all 309 card rules/IDs, all 112 relic rules/IDs, and all 12 retired relic rows are unchanged. Enemy data differs only in Arc Burst's display name and Hollow Gale's presentation metadata. `git diff --check` passed, and protected staged text inputs are unchanged.

The initial full Godot run reported `TEST RESULT: FAIL (691 failure(s))`, including 651 repeated lowercase-Embers price pins. Those task-induced text pins were corrected; the final run above is the acceptance result. A default-300-second attempt timed out in the large cutout suites, so subsequent full runs use the documented 900-second full-suite budget. One attempted standalone `turn_clock_hud_review_test.gd` launch found no such script; its existing suite is covered by `run_tests.gd`. These attempts did not change project files.

Godot emits a macOS certificate lookup diagnostic in this sandbox. Some suites emit ObjectDB/resource cleanup warnings, run-end recap scene-tree lifecycle errors, and deliberate save/analytics/invalid-data failure-path errors. Test outcome lines are reported independently. No windowed renderer, screenshot, pixel-equality result, visual judge, or peer-review signoff is claimed.

The legacy relic 240-character layout check now measures expanded display text rather than token markup, since the approved Black Sun Dial source contains 270 markup characters. Exact approved source equality and the 25-word token budget are separately enforced. The 240-character bound itself is unchanged. No mechanics or geometric layout assertions were removed.

## Round 1 verification

The round 1 changes are in `scripts/inline_icon_text.gd`, `scripts/event_view_text.gd`, `scripts/card_widget.gd`, `scripts/graftwright_view.gd`, `spec/text_style_guide.md`, `tests/glossary_test.gd`, `tests/suites/inline_icon_description_suite.gd`, `tests/text_rewrite_probe.gd`, and its proof contract. No approved data was rewritten.

- Budgets: `Ran 4 tests in 0.070s` / `OK`.
- UI identity lint: `Ran 25 tests in 3.361s` / `OK`.
- Glossary: `GLOSSARY TEST RESULT: PASS (6924 checks, 0 failures)`.
- Tokens: `INLINE ICON DESCRIPTION TEST RESULT: PASS`.
- Text probe: `TEXT REWRITE PROBE LOGIC: PASS (36 checks, 0 failures)`.
- Full Python: `Ran 448 tests in 257.182s` / `OK (skipped=61)` (exit 0).
- Full Godot: `FULL SUITE RUNTIME: 841.134 seconds (budget 900 seconds)` / `TEST RESULT: PASS` (exit 0).

Round 1 logs are `/private/tmp/ux04-r1-*.log`. The same two windowed commands below now also capture gold keyword samples and the Graftwright result. No windowed run was attempted.

## Proof for the design owner

Run from this task worktree. Both commands use 1920×1080 and 100% UI scale; neither was run windowed in the implementation sandbox. The 120-second glossary timeout is the established all-relic sweep budget.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/ux-04 && python3 tools/visual_probe_runner.py --task-id ux-04 --timeout 120 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/glossary_tooltip_probe_contract.json --result-manifest /private/tmp/ux-04-r1-glossary-proof.json tests/glossary_tooltip_probe.gd -- --size=1920x1080 --compare-original-card
```

The probe captures relic choice and owned relic pointer/keyboard/controller states, all-relic layout cases, and card keyword comparisons. It prints `GLOSSARY_PROOF_DIR` with the isolated capture directory. Required files include `relic_choice_hover.png`, `owned_relic_hover.png`, `card_keywords_before.png`, `card_keywords_same_copy.png`, and `card_keywords_after.png`.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/ux-04 && python3 tools/visual_probe_runner.py --task-id ux-04 --timeout 120 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/text_rewrite_probe_contract.json --result-manifest /private/tmp/ux-04-r1-text-proof.json tests/text_rewrite_probe.gd
```

This prints `TEXT_REWRITE_PROOF_DIR` and captures `status_charge.png`, `intent_arc_burst.png`, `movement_meter.png`, `card_time_and_turns.png`, five `grimoire_*.png` pages (Light, Expend, Chilled, Ground Techniques, Card Play), `token_styles.png` (card/relic/event/definition surfaces), and `graftwright_result.png`. Tooltip panels come from their real live owner's factory; their placement is probe-only. There are no new PNG captures from the headless sandbox. No inspection-fixture command was requested for this implementation unit; the owner prepares that fixture.

## Director decisions and chosen defaults

Both TODO_DESIGN placeholders are resolved by round 1: `InlineIconText.KEYWORD_COLOR` uses `UiPalette.GOLD_BRIGHT` (`#f0cf8a`), with host font/size/weight and no underline; Graftwright result copy is `<Item> destroyed`. `spec/text_style_guide.md` names the shared style. The renderer retains hint hover behavior and the card forwards word hints through its existing tooltip path.
- New probe-only defaults: tooltip position `(1140, 280)`, card position `(700, 320)`, card size `(250, 352)`, eight settle frames, and isolated `user://text_rewrite_*` paths. Card placement and settling reuse existing probe conventions. The proof commands allow 120 seconds. The new token fixture uses width `520`, event position `(1140, 540)`, definition position `(1140, 680)`, a 2-pixel hover-test grid, and debug text `Gain @kw(block). Gain @term(health|Health).`. The Graftwright proof reuses the established `undertaker_plate`/`patched_cloak` fixture. No gameplay or UI tuning defaults were chosen.

## Workflow caveat

Read-only `parallel_task.py status` reported an empty contract (`acceptance_criteria: []`, `required_proof: []`, empty inspection expectation), despite the brief saying the owner had recorded it. Workflow metadata was left to the design owner as instructed.

## Files changed

Every changed or added test is included in this complete inventory.

- `data/cards.json`
- `data/enemies.json`
- `data/glossary.json`
- `data/grimoire.json`
- `data/relics.json`
- `scenes/run_scene.tscn`
- `scripts/action_icon_library.gd`
- `scripts/board_surface_presentation.gd`
- `scripts/card_widget.gd`
- `scripts/combat_board_view.gd`
- `scripts/combat_engine.gd`
- `scripts/contextual_combat_tutorial.gd`
- `scripts/dialogue_engine.gd`
- `scripts/element_data.gd`
- `scripts/enemy_mechanics/bramble.gd`
- `scripts/enemy_mechanics/bramble_view.gd`
- `scripts/enemy_mechanics/burrow_view.gd`
- `scripts/enemy_mechanics/capacitor.gd`
- `scripts/enemy_mechanics/capacitor_view.gd`
- `scripts/enemy_mechanics/death_burst_view.gd`
- `scripts/enemy_mechanics/icefall.gd`
- `scripts/enemy_mechanics/icefall_view.gd`
- `scripts/enemy_mechanics/lob_view.gd`
- `scripts/enemy_mechanics/mimic_view.gd`
- `scripts/enemy_mechanics/reflect.gd`
- `scripts/enemy_mechanics/wind_view.gd`
- `scripts/event_view_text.gd`
- `scripts/game_data.gd`
- `scripts/glossary.gd`
- `scripts/graftwright_view.gd`
- `scripts/grimoire_library.gd`
- `scripts/inline_icon_text.gd`
- `scripts/maneuver_rules.gd`
- `scripts/pre_battle_threat_tags.gd`
- `scripts/run_end_recap_overlay.gd`
- `scripts/run_engine.gd`
- `scripts/run_scene.gd`
- `scripts/scavenger_shop_view.gd`
- `scripts/surface_relic_rules.gd`
- `spec/enemies/storm_capacitor.md`
- `spec/text_style_guide.md`
- `tests/combat_hud_buttons_test.gd`
- `tests/en05_integration_sync_test.gd`
- `tests/glossary_test.gd`
- `tests/glossary_tooltip_probe.gd`
- `tests/glossary_tooltip_probe_contract.json`
- `tests/run_end_recap_tests.gd`
- `tests/run_tests.gd`
- `tests/scavenger_visual_pass_4_test.gd`
- `tests/suites/card_keywords_w3_suite.gd`
- `tests/suites/card_mechanics_surfaces_suite.gd`
- `tests/suites/depth_rules_suite.gd`
- `tests/suites/en01_enemies_suite.gd`
- `tests/suites/en02_enemies_suite.gd`
- `tests/suites/en03_enemies_suite.gd`
- `tests/suites/en04_enemies_suite.gd`
- `tests/suites/en05_enemies_suite.gd`
- `tests/suites/en06_enemies_suite.gd`
- `tests/suites/fix_03_suite.gd`
- `tests/suites/glossary_coverage_suite.gd`
- `tests/suites/inline_icon_description_suite.gd`
- `tests/suites/maneuver_suite.gd`
- `tests/suites/pre_battle_ui_suite.gd`
- `tests/suites/relic_suite.gd`
- `tests/suites/relic_u1_suite.gd`
- `tests/suites/tooltip_consistency_suite.gd`
- `tests/suites/turn_clock_copy_suite.gd`
- `tests/suites/turn_clock_hud_review_suite.gd`
- `tests/suites/turn_clock_hud_suite.gd`
- `tests/test_icon_identity_policy.py`
- `tests/test_text_budget.py`
- `tests/text_budget_test.py`
- `tests/text_rewrite_handoff.md`
- `tests/text_rewrite_probe.gd`
- `tests/text_rewrite_probe_contract.json`
