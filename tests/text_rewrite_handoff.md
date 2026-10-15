# UX-04 implementation handoff

Round 3 changes are uncommitted on `codex/ux-04`, based on `4840e8503`. Earlier-round results below are historical. The design owner owns commit, review, inspection fixture and publication. Protected staged text inputs were read, never edited.

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

## Round 2 review fixes and verification

1. Long Dawn, Sunpath, and Afterglow now use the exact approved glossary definitions in `data/skills.json`. No duration icon remains in these descriptions, so their Abilities details cannot expose a Time tooltip for turns. The live text probe selects all three abilities, checks the rendered concepts, and hit-tests every remaining icon. Skill IDs, effects, numbers, and all other skill fields are unchanged.
2. `scripts/inline_token_syntax.gd` owns the token grammar used by the renderer, glossary extraction, GDScript coverage, and Python coverage. Unknown keys containing punctuation or whitespace are validated instead of skipped. Malformed delimiters, empty keys/forms, padding, newlines, and nested tokens fail validation. Both coverage paths inject the shared cases into Quick Stab text; the renderer suite also verifies that unresolved keys remain visible and fail validation. Valid multiword names and inflected forms remain supported.
3. The unused `SkillTreeLibrary` preloads were removed from `scripts/action_icon_library.gd` and `tests/glossary_test.gd`.

Observed results on the round 2 working tree:

- Budgets and regression cases: `Ran 6 tests in 0.082s` / `OK`.
- Glossary and coverage: `GLOSSARY TEST RESULT: PASS (6974 checks, 0 failures)`.
- Token rendering: `INLINE ICON DESCRIPTION TEST RESULT: PASS`.
- Text probe logic: `TEXT REWRITE PROBE LOGIC: PASS (56 checks, 0 failures)`.
- Glossary probe logic: `GLOSSARY PROBE LOGIC RESULT: PASS`; all 112 relics pass both 336-position layout sweeps, with zero reported overflow.
- UI identity lint: `Ran 25 tests in 3.174s` / `OK`.
- Full Python: `Ran 450 tests in 252.461s` / `OK (skipped=61)` (exit 0).
- Full Godot: `FULL SUITE RUNTIME: 722.933 seconds (budget 900 seconds)` / `TEST RESULT: PASS` (exit 0).

Logs are `/private/tmp/ux04-r2-*.log`. Protected approved text files and the Git index are unchanged. The only skill data differences are the three approved descriptions. No new TODO_DESIGN placeholders or production tuning values were introduced. The probe reuses the existing two-pixel hover grid, settling count, and viewport; its new fixture consists of the three reviewed ability IDs.

Every round 2 changed file (including every test/probe):

- `data/skills.json`
- `scripts/action_icon_library.gd`
- `scripts/glossary.gd`
- `scripts/inline_icon_text.gd`
- `scripts/inline_token_syntax.gd` (new shared parser)
- `tests/fixtures/inline_token_cases.json` (new shared regression cases)
- `tests/glossary_test.gd`
- `tests/suites/glossary_coverage_suite.gd`
- `tests/suites/inline_icon_description_suite.gd`
- `tests/suites/skill_tree_suite.gd`
- `tests/text_budget_test.py`
- `tests/text_rewrite_probe.gd`
- `tests/text_rewrite_probe_contract.json`
- `tests/text_rewrite_handoff.md`

## Round 3 Unicode whitespace fix and verification

The shared token regex now permits only printable ASCII inside tokens, with U+0020 as the only permitted space. Keys cannot have edge spaces; explicit forms must contain a nonspace. Both validators use this grammar directly, without `\s`, `strip_edges()`, or Python `strip()` to classify token whitespace. Token-start detection also catches non-ASCII separators between a token kind and its opening parenthesis.

The shared fixture contains 193 cases. It covers 32 whitespace/invisible separator code points in the prefix, key, and form, including the two reported U+00A0 mutations. Python and GDScript inject these cases into Quick Stab text and reject every invalid case. The rendering suite separately checks that both reported NBSP inputs remain literal markup with zero concept spans, preventing a blank keyword. Unicode prose outside tokens remains valid. No approved copy, skill data, mechanics, IDs, or production tuning values changed.

Observed results on the round 3 working tree:

- Budgets and shared regression vectors: `Ran 6 tests in 0.081s` / `OK`.
- Glossary and coverage: `GLOSSARY TEST RESULT: PASS (7311 checks, 0 failures)`.
- Token rendering: `INLINE ICON DESCRIPTION TEST RESULT: PASS`.
- Live text probe: `TEXT REWRITE PROBE LOGIC: PASS (56 checks, 0 failures)`.
- UI identity lint: `Ran 25 tests in 3.960s` / `OK`.
- Full Python: `Ran 450 tests in 310.195s` / `OK (skipped=61)` (exit 0).
- Full Godot: `FULL SUITE RUNTIME: 774.177 seconds (budget 900 seconds)` / `TEST RESULT: PASS` (exit 0).

Logs are `/private/tmp/ux04-r3-*.log`. Both reproduction cases contain actual U+00A0 characters after JSON decoding. Protected inputs and the Git index remain unchanged. No TODO_DESIGN placeholders or new production defaults were introduced. Windowed proof remains with the design owner; the capture set is unchanged.

Every round 3 changed file, including every touched test:

- `scripts/inline_token_syntax.gd`
- `tests/fixtures/inline_token_cases.json`
- `tests/suites/glossary_coverage_suite.gd`
- `tests/suites/inline_icon_description_suite.gd`
- `tests/text_budget_test.py`
- `tests/text_rewrite_handoff.md`

## Proof for the design owner

Run from this task worktree. Both commands use 1920×1080 and 100% UI scale; neither was run windowed in the implementation sandbox. The 120-second glossary timeout is the established all-relic sweep budget.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/ux-04 && python3 tools/visual_probe_runner.py --task-id ux-04 --timeout 120 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/glossary_tooltip_probe_contract.json --result-manifest /private/tmp/ux-04-r3-glossary-proof.json tests/glossary_tooltip_probe.gd -- --size=1920x1080 --compare-original-card
```

The probe captures relic choice and owned relic pointer/keyboard/controller states, all-relic layout cases, and card keyword comparisons. It prints `GLOSSARY_PROOF_DIR` with the isolated capture directory. Required files include `relic_choice_hover.png`, `owned_relic_hover.png`, `card_keywords_before.png`, `card_keywords_same_copy.png`, and `card_keywords_after.png`.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/ux-04 && python3 tools/visual_probe_runner.py --task-id ux-04 --timeout 120 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/text_rewrite_probe_contract.json --result-manifest /private/tmp/ux-04-r3-text-proof.json tests/text_rewrite_probe.gd
```

This prints `TEXT_REWRITE_PROOF_DIR` and captures `status_charge.png`, `intent_arc_burst.png`, `movement_meter.png`, `card_time_and_turns.png`, five `grimoire_*.png` pages (Light, Expend, Chilled, Ground Techniques, Card Play), `token_styles.png` (card/relic/event/definition surfaces), `graftwright_result.png`, and the three live Abilities details (`ability_long_dawn.png`, `ability_sunpath.png`, `ability_afterglow.png`). Tooltip panels come from their real live owner's factory; their placement is probe-only. There are no new PNG captures from the headless sandbox. No inspection-fixture command was requested for this implementation unit; the owner prepares that fixture.

## Director decisions and chosen defaults

Both TODO_DESIGN placeholders are resolved by round 1: `InlineIconText.KEYWORD_COLOR` uses `UiPalette.GOLD_BRIGHT` (`#f0cf8a`), with host font/size/weight and no underline; Graftwright result copy is `<Item> destroyed`. `spec/text_style_guide.md` names the shared style. The renderer retains hint hover behavior and the card forwards word hints through its existing tooltip path.
- New probe-only defaults: tooltip position `(1140, 280)`, card position `(700, 320)`, card size `(250, 352)`, eight settle frames, and isolated `user://text_rewrite_*` paths. Card placement and settling reuse existing probe conventions. The proof commands allow 120 seconds. The new token fixture uses width `520`, event position `(1140, 540)`, definition position `(1140, 680)`, a 2-pixel hover-test grid, and debug text `Gain @kw(block). Gain @term(health|Health).`. The Graftwright proof reuses the established `undertaker_plate`/`patched_cloak` fixture. No gameplay or UI tuning defaults were chosen.

## Workflow caveat

During the initial implementation, read-only `parallel_task.py status` reported an empty contract (`acceptance_criteria: []`, `required_proof: []`, empty inspection expectation), despite the brief saying the owner had recorded it. Workflow metadata was left to the design owner as instructed.

## Initial implementation and round 1 file inventory

Every changed or added test from those rounds is included below. The round 2 and round 3 inventories are listed separately above.

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
