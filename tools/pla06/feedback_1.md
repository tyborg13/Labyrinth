# pla-06 feedback 1

Baseline `b83f9d4fa`. The changes in this round are uncommitted. The [round-zero implementation report](implementation_report.md) has the 25-card behavior, face, and score tables. This round changes no card faces or printed card numbers.

## Director rulings

| # | Implementation | Headless coverage |
| --- | --- | --- |
| 1 | [Ice save migration](../../scripts/ice_contact_rules.gd#L51) converts saved Rime Bolt and Refraction riders using the current on-Ice Stagger data, including committed actions. Other `chilled` riders are dropped. | [Saved intent test](../../tests/ice_stagger_merge_rules_test.gd#L434) resolves migrated Rime Bolt, checks the Refraction plan, and preserves saved damage. |
| 2 | [Frozen activation migration](../../scripts/ice_contact_rules.gd#L35) restores plays recorded as forfeited and preserves paid plays and other restrictions. | [Retired statuses test](../../tests/ice_stagger_merge_rules_test.gd#L415) checks availability and a second load. |
| 3 | [Shatter and Shatter Swing](../../data/cards.json#L8604) retain their round-zero behavior. | [Shatter tests](../../tests/ice_stagger_merge_rules_test.gd#L363) check damage and zero Stagger. |
| 4 | [Direct enemy hits](../../scripts/combat_engine.gd#L5189) consume Expose and add the amount to damage. Crownfire’s [Burst](../../scripts/combat_engine.gd#L12251) and [Lob Landing](../../scripts/enemy_mechanics/marked_strike.gd#L252) use that path. | [Enemy area hits test](../../tests/ice_stagger_merge_rules_test.gd#L262) checks exact damage and Expose consumption for both. |
| 5 | [Limited-Umbra preview](../../scripts/run_scene.gd#L35215) reads the disclosed resolution for the hero’s Ice Expose. | [Fringe preview test](../../tests/ice_stagger_merge_rules_test.gd#L299) compares preview and committed movement, including existing Expose and Hobnail Cleats. |
| 6 | [Combat opening](../../scripts/combat_engine.gd#L994), [survival reinforcements](../../scripts/combat_engine.gd#L6220), and [Snare hunters](../../scripts/snare_room_rules.gd#L241) use Ice contact. Existing summons use the entry resolver. | [Opening and spawn test](../../tests/ice_stagger_merge_rules_test.gd#L280) checks opening hero and enemy, survival reinforcement, and a regular enemy summon. |
| 7 | [Battlefield Stagger](../../scripts/combat_engine.gd#L6283) uses a [separate cap path](../../scripts/card_keyword_rules.gd#L213). | [Frostbite checks](../../tests/ice_stagger_merge_rules_test.gd#L482) compare actual queued delays in both source orders. |
| 8 | [Cold Mirror](../../data/relics.json#L528) and [Crystal Mantle](../../data/cards.json#L7414) retain the hero’s Frost Armor. | [Player Frost Armor test](../../tests/ice_stagger_merge_rules_test.gd#L463) checks both sources. |
| 9 | [Shatterglass Prism](../../data/relics.json#L312) leaves Rubble when the hero’s Ice attack Staggers an enemy on Ice. [Surface Relic](focused_suites.gd#L9) is registered in the focused runner. | [Prism and Vial tests](../../tests/suites/surface_relic_suite.gd#L64) check the new trigger on a surviving enemy and absence of a trigger off Ice. |
| 10 | [Rimecatcher Vial](../../scripts/surface_relic_rules.gd#L234) accepts Push attacks. Relocation uses the Ice under the enemy at impact, before displacement. Targetless Ice attacks can choose the direction at confirmation. | [Rimecatcher tests](../../tests/suites/surface_relic_suite.gd#L75) cover Frostbolt, Cold Shoulder, and White Silence. |
| 11 | [Icebound Chains](../../data/cards.json#L1452) keeps its Vision copy and Truesight implementation pending the shared cutover. | The dedicated rules test covers the card’s Stagger and face fit covers the printed row. Vision integration belongs to the candidate merge. |
| 12 | [Ice Expose analytics](../../scripts/ice_contact_rules.gd#L16) records an application only when Expose increases. The [analytics specification](../../spec/analytics.md#L1421) lists the additive fields. | [Expose analytics test](../../tests/ice_stagger_merge_rules_test.gd#L246) checks entry, turn start without a spend, and reapplication after a spend. |

## Copy changes

- **Ice glossary and Grimoire**
  - Old `A unit that enters or starts its turn here is Exposed 2.`
  - New `Units gain Expose 2 when entering Ice or starting a turn on Ice.`
- **Frostbite glossary**
  - Old `On its beat, an Ice hit strikes everyone standing on Ice.`
  - New `Frostbite hits everyone standing on Ice when the battlefield rule triggers.`
- **Expose glossary and Grimoire**
  - Old `Its next damaging hit takes that much more damage.`
  - New `This unit takes that much extra damage from the next damaging hit.`
- **Retaliate Grimoire**
  - Old `Block and Stoneskin absorb it; Expose does not add to it.`
  - New `Block and Stoneskin absorb Retaliate damage without an Expose bonus.`
- **Collision Grimoire**
  - Old `Block and Stoneskin absorb it; Expose doesn't add to it.`
  - New `Block and Stoneskin absorb Collision damage without an Expose bonus.`
- **Ice Wards Grimoire**
  - Old `Ice placed this way Exposes an enemy only when it starts a turn on or enters the Ice.`
  - New `Ice placed this way Exposes an enemy on entry or at the start of the enemy’s turn.`
- **Shatterglass Prism description**
  - Old `When you kill a @term(stagger|Staggered) enemy with an attack, leave @term(surface_rubble) on its tile and each tile next to it.`
  - New `When your @term(element_ice) attack @term(stagger|Staggers) an enemy on @term(surface_ice), leave @term(surface_rubble) under and beside the struck enemy.`
- **Shatterglass Prism diagram**
  - Old `When you kill a @term(stagger|Staggered) enemy with an attack, leave @term(surface_rubble) on these tiles centered on it.`
  - New `When your @term(element_ice) attack @term(stagger|Staggers) an enemy on @term(surface_ice), leave @term(surface_rubble) on the marked tiles.`
- **Rimecatcher Vial description**
  - Old `When your @term(element_ice) attack @term(stagger|Staggers) an enemy on @term(surface_ice), you can move that @term(surface_ice) to a tile next to it.`
  - New `When your @term(element_ice) attack @term(stagger|Staggers) an enemy on @term(surface_ice), you can move the Ice 1 tile.`
- **Breaking Wheel description**
  - Old `When an enemy collides on ground, @kw(surface_consume) it. @term(surface_fire): 3 more damage. @term(surface_ice): @kw(stagger) 6. @term(surface_electrified): @term(shock) it and enemy blockers. @term(surface_rubble): @kw(stagger) 3.`
  - New `Enemy collision: @kw(surface_consume) the ground. @term(surface_fire): 3 more damage. @term(surface_ice): @kw(stagger) 6. @term(surface_electrified): @term(shock) enemy and enemy blockers. @term(surface_rubble): @kw(stagger) 3.`
- **Conditional card row**
  - Old `if it kills:`
  - New `if the hit kills:`
- **Spill Ice tooltip**
  - Old `Choose where to place the Ice Expended by Freeze.`
  - New `Choose a direction for Ice moved by Rimecatcher Vial.`

## Proof for the design owner

From the worktree, run the renderer probe at 1920×1080 and 100% UI scale. Frames are written to `.godot/pla06-feedback-1/native`, including `ice_move_preview.png` and `ice_enemy_turn_start.png`.

```sh
PLA03_OUT="$PWD/.godot/pla06-feedback-1/native" PLA03_SECTIONS=faces,ice \
  PLA03_CARDS=hush_of_winter,white_silence,threadbare_guard,rite_of_hoarfrost,frozen_bite,hoarfrost_ward,rime_step,smelling_salts \
  LABYRINTH_CEL_LOOK=all taskpolicy -c background python3 tools/visual_probe_runner.py \
  res://tools/pla03/sentence_face_probe.gd --task-id pla-06 --no-headless \
  --expect-size 1920x1080 --proof-contract tools/pla06/proof_contract.json \
  --timeout 300 --result-manifest .godot/pla06-feedback-1/native-result.json
```

## Design and verification limits

No new `TODO_DESIGN` placeholders. The existing `TODO_DESIGN_shared_vision_cutover` is for the candidate merge. The native capture and input check for the targetless Spill Ice control are pending.

## Chosen defaults

Test-only positions, Health and turn times are supplied by the dedicated rules and Surface Relic fixtures. The probe reuses the round-zero fixture.

## Verification

| Check | Observed result |
| --- | --- |
| Dedicated rules | `ICE STAGGER MERGE RULES: 121 checks, 0 failures` |
| Focused suites | `PLA06 FOCUSED: 3020 checks, 0 failures` and `SUITE surface_relic: 0 failures` |
| Face fit | `FACE FIT CHECKS: 10197 checks, 0 failures` |
| Glossary | `GLOSSARY TEST RESULT: PASS (6565 checks, 0 failures)` |
| Card panels | `CARD PANEL TEXT TEST RESULT: PASS (2231 definitions, 8050 panels, 8266 checks, 0 failures)` |
| Short tooltips | `SHORT CARD TOOLTIPS TEST RESULT: PASS (734 checks, 0 failures)` |
| Python `--changed-since codex/pla-04` | `Ran 188 tests in 127.807s` and `FAILED (failures=3)` |
| Python text budget and short tooltips | `Ran 6 tests` and `Ran 5 tests`, both `OK` |
| UI and icon identity | `Ran 25 tests` and `Ran 10 tests`, both `OK` |
| Typed arrays | `TYPED ARRAY SCAN: 18 scripts; 0 new; 0 pre-existing` |
| Headless visual probe | `80` `DRY SHOT` lines and `TEST RESULT: PASS`. The manifest records Expose 2 for the hero's move and the enemy's turn start. |

The final Python run includes the round-zero Black Sun Dial copy assertion, five missing pla-04 sidecars, and the 30-second approved-content smoke timeout. The first run passed approved content and the process-cleanup test reported `Child did not start`. Logs are `.godot/pla06-feedback-1/python-verified.log` and `.godot/pla06-feedback-1/python.log`. Godot reported macOS certificate lookup errors, and the passing glossary and short-tooltip checks emitted teardown warnings. The dry-run manifest is `.godot/pla06-feedback-1/dry/manifest.json`.

## Files changed

- `data/glossary.json`
- `data/grimoire.json`
- `data/pattern_rule_text.json`
- `data/relics.json`
- `scripts/action_icon_library.gd`
- `scripts/board_attack_rules.gd`
- `scripts/card_keyword_rules.gd`
- `scripts/combat_engine.gd`
- `scripts/enemy_mechanics/capacitor.gd`
- `scripts/enemy_mechanics/death_burst.gd`
- `scripts/enemy_mechanics/marked_strike.gd`
- `scripts/enemy_mechanics/reflect.gd`
- `scripts/ice_contact_rules.gd`
- `scripts/run_scene.gd`
- `scripts/snare_room_rules.gd`
- `scripts/surface_card_rules.gd`
- `scripts/surface_relic_rules.gd`
- `spec/analytics.md`
- `tests/fixtures/pla06_ice_copy.json`
- `tests/ice_stagger_merge_rules_test.gd`
- `tests/run_tests.gd`
- `tests/suites/relic_suite.gd`
- `tests/suites/surface_relic_suite.gd`
- `tools/pla06/feedback_1.md`
- `tools/pla06/focused_suites.gd`
