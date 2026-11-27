# txt-42 round 3

Round 3 resolves the Last Eclipse duration gate and completes round 2 on `4f8d660a3`. This comparison uses the merged worktree as the starting point. The edits are uncommitted.

| Line | Kind | Old text | New text |
| --- | --- | --- | --- |
| 1. Electrified glossary | 1 | A Lightning card's hit on an Electrified tile also hits each visible enemy on connected Electrified tiles. | A Lightning card's hit on an Electrified tile also hits each visible enemy on connected Electrified tiles. |
| 1. Electrified Grimoire | 1 | A Lightning card's hit on an Electrified tile also hits each visible enemy on connected Electrified tiles. | A Lightning card's hit on an Electrified tile also hits each visible enemy on connected Electrified tiles. |
| 2. Cinder Marks glossary | 1 | When this attack lands, you and your Illusions on Marked tiles take X damage, and each Marked tile becomes Fire. | When this attack lands, you and your Illusions on Marked tiles take X damage, and each Marked tile becomes Fire. |
| 2. Cinder Marks Grimoire | 1 | When this attack lands, you and your Illusions on Marked tiles take X damage, and each Marked tile becomes Fire. | When this attack lands, you and your Illusions on Marked tiles take X damage, and each Marked tile becomes Fire. |
| 3. Hollow Gale Grimoire | 1 | Hollow Gale damages you and your Illusions on Marked tiles and Pushes you 1 tile away from Vaeloryx. | Hollow Gale damages you and your Illusions on Marked tiles, then Pushes you 1 tile away from Vaeloryx. |
| 3. Hollow Gale diagram key | 1 | Hollow Gale damages you and your Illusions on Marked tiles and Pushes you 1 tile away from Vaeloryx. | Hollow Gale damages you and your Illusions on Marked tiles, then Pushes you 1 tile away from Vaeloryx. |
| 3. Hollow Gale diagram value | 1 | @pattern(body_area:2) Hollow Gale damages you and your Illusions on Marked tiles and Pushes you 1 tile away from Vaeloryx. | @pattern(body_area:2) Hollow Gale damages you and your Illusions on Marked tiles, then Pushes you 1 tile away from Vaeloryx. |
| 4. Last Eclipse Grimoire | 1 | Last Eclipse starts Eclipse through your next turn, then hits you and your Illusions on Marked tiles. | Last Eclipse starts Eclipse for your next turn, then hits you and your Illusions on Marked tiles. |
| 4. Last Eclipse intent, filled | 1 | This enemy starts Eclipse for your next 2 turns, then hits you and your Illusions on Marked tiles. | This enemy starts Eclipse for your next turn, then hits you and your Illusions on Marked tiles. |
| 4. Last Eclipse Known Moves, filled | 1 | Marked: Ranged 8 · Eclipse 2, then Summon Veilbound Acolyte | Marked: Ranged 8 · Eclipse 1, then Summon Veilbound Acolyte |
| 5. Swap glossary | 1 | Trade places with a visible enemy or one of your visible Illusions. | Trade places with a visible enemy or one of your visible Illusions. |
| 5. Swap Grimoire | 1 | Trade places with a visible enemy or one of your visible Illusions. | Trade places with a visible enemy or one of your visible Illusions. |
| 5. Swap Illusion glossary | 1 | Trade places with one of your visible Illusions. | Trade places with one of your visible Illusions. |
| 5. Swap Illusion Grimoire | 1 | Trade places with one of your visible Illusions. | Trade places with one of your visible Illusions. |
| 6. Targeting glossary | 1 | Attack targets must be visible and within Range. Ranged attacks also need line of sight. | Attack targets must be visible and within Range. Ranged attacks also need line of sight. |
| 7. Curator’s Patience glossary | 1 | After choosing a relic, save one unchosen relic for your next Relic room. | After choosing a relic, save one unchosen relic for your next Relic room. |
| 7. Curator’s Patience skill | 1 | After choosing a relic, save one unchosen relic for your next Relic room. | After choosing a relic, save one unchosen relic for your next Relic room. |
| 7. Curator’s Patience dialog | 1 | This relic will appear in your next Relic room. | This relic will appear in your next Relic room. |
| 8. Rewards glossary | 3 | After most combats, take a card or skip to heal 3. | After combat, choose a reward. |
| 8. Rewards Grimoire | 3 | After you survive combat, take 1 of 3 cards, or skip to heal 3. A Warband offers 4 cards, as do Ember Hoarder and Last Light combats when you meet the goal. Guardians and dragons give relics instead of cards. | After combat, choose a reward. |
| 8. Rewards details Grimoire | 3 | A magic card you gain goes straight into your deck. Purge removes a card. | A magic card you gain goes straight into your deck. Purge removes a card. |
| 9. Charge glossary | 3 | At 3 Charge, this enemy's next attack is Arc Lash. Becoming Shocked removes 1 Charge. | At 3 Charge, this enemy's next attack is Arc Lash. |
| 9. Charge Grimoire | 3 | At 3 Charge, this enemy's next attack is Arc Lash. Shock removes 1 Charge. | At 3 Charge, this enemy's next attack is Arc Lash. |
| 9. Storm Capacitor’s Shock sentence | 3 | Shock drains its Charge. | Becoming Shocked removes 1 Charge. |
| 10. Splits glossary | 2 | When this enemy dies, this enemy splits into smaller enemies on free adjacent tiles. | When this enemy dies, this enemy splits into smaller enemies on adjacent tiles. |
| 10. Splits trait format | 2 | On death, this enemy splits into up to %d %s on free tiles within %d tile%s. | On death, this enemy splits into %d %s within %d tile%s. |
| 11. Fatigue Grimoire | 2 | Drawing from an empty draw pile shuffles your discard into your draw pile and costs Health. With both piles empty, drawing does nothing. | Drawing from an empty draw pile shuffles your discard into your draw pile and costs Health. |
| 12. Upheaval details Grimoire | 2 | The tile stays flat if the unit cannot be moved. A Marked tile holding a trap stays flat. Destroy an Outcrop to open a route. | The tile stays flat if the unit cannot be moved. Destroy an Outcrop to open a route. |

## Last Eclipse duration and consumers

The resolver clamps the action duration to at least 1 on cast. The turn-start tick subtracts one before the player acts. The presentation token applies that same calculation to count upcoming player turns in Eclipse. The authored duration stays at 2, and the resolver and tick are unchanged. The original gate logged a tooltip promising two player turns while the engine recorded `eclipse, eclipse, clear` at cast and the next two turn starts. The same witness now agrees with the filled token. [Cast](../../scripts/combat_engine.gd#L7225), [Turn start](../../scripts/combat_engine.gd#L5677), [Intent](../../scripts/action_icon_library.gd#L1633)

| Consumer | Filled copy |
| --- | --- |
| Noctyrax’s live Last Eclipse intent and Known Move tooltip | This enemy starts Eclipse for your next turn, then hits you and your Illusions on Marked tiles. |
| Grimoire Last Eclipse rules page | Last Eclipse starts Eclipse for your next turn, then hits you and your Illusions on Marked tiles. |
| Grimoire creature moves and the data-built bestiary table from txt-34 | Marked: Ranged 8 · Eclipse 1, then Summon Veilbound Acolyte |
| Pre-battle Known Moves inspection | Marked: Ranged 8 · Eclipse 1, then Summon Veilbound Acolyte |
| Pre-battle lineup tag | Last Eclipse |

Noctyrax is the sole authored enemy using the action. The glossary template fills normally for plural counts. Headless cases with cast counters 3 and 4 sustained Eclipse for 2 and 3 upcoming turns and printed those exact plural counts. The test-only counter 1 has no upcoming Eclipse turn and shows the existing Eclipse label without a count. The singular uses the same template without the digit. Both move tables fill the authored summary’s count from the production token. [Known Moves](../../scripts/known_move_text.gd#L44), [Grimoire creature moves](../../scripts/grimoire_creature_page.gd#L66), [Pre-battle inspection](../../scripts/pre_battle_inspection_view.gd#L178)

## Rewards and the three release reversions

- Every fresh victory branch in the settlement code opens a reward surface. The witnesses covered standard card rewards, each enabled special encounter, a missed Hoarder objective followed by victory, and Snare escapes before and after sealing. They covered both a Guardian trophy claim and its ordinary-card fallback when the trophy is already owned. Both a normal dragon and the final dragon opened their milestone reward. Last Light and Snare defeats remained defeat, so the prior defeat cases no longer test a victory reward promise. [Victory settlement](../../scripts/run_engine.gd#L1305), [Reward branches](../../scripts/run_engine.gd#L1410)
- **Splits.** Cinder Ooze produces zero children when there is no free tile within 1 tile. [Empty spawn list](../../scripts/combat_engine.gd#L8677)
- **Fatigue.** Drawing with both piles empty costs 0 Health and draws no card. [Empty discard check](../../scripts/combat_engine.gd#L8294)
- **Upheaval.** A trap remains on a Marked tile and the tile stays flat. The trap blocks the raise. [Trap blocker](../../scripts/battlefield_rules/upheaval_rise.gd#L16)
- **Charge.** Fresh Shock removed one Charge and repeated Shock left Charge at 2. The Storm Capacitor lore now states the transition precisely. The EN-06 badge pins still use release’s threshold-only tooltip.
- **Hollow Gale.** The marked hero lost 6 Health before Push resolved and moved one tile. The marked Illusion took damage and stayed in place. The new sentence retains the area diagram.

## Focused proof

| Check | Exact result |
| --- | --- |
| Truth witnesses | `TXT42 WITNESSES: PASS (37 observations, 0 false claims)` |
| Rules-text lint | `PASS: Rules text lint (16 existing hits)` |
| Dragon copy fixtures | `TXT42 DRAGON COPY PINS: 45 checks, 0 failures` |
| Godot short card tooltips | `SHORT CARD TOOLTIPS TEST RESULT: PASS (704 checks, 0 failures)` |
| Python short card tooltips | `Ran 5 tests in 0.009s`, `OK` |
| Card panels | `CARD PANEL TEXT TEST RESULT: PASS (2210 definitions, 7748 panels, 15725 checks, 0 failures)` |
| Python card panels | `Ran 4 tests in 0.004s`, `OK` |
| EN-06 | `EN06 ENEMIES TEST RESULT: PASS (136 checks, 0 failures)` |
| Splits trait | `SPL01 SEMANTICS: PASS (17 checks, 0 failures)` with `LABYRINTH_CEL_LOOK=all`. The initial invocation omitted that setting and failed the Cel Look assertion. |
| Grimoire search | `GRIMOIRE SEARCH PROBE RESULT: PASS` |
| Light and Vision | `LIGHT AND VISION RULES: 75 checks, 0 failures`, `TEST RESULT: PASS` |
| UI identity lint | `Ran 25 tests in 4.192s`, `OK` |
| Parser | The task runner’s `--check-only` runs for `action_icon_library.gd` and `known_move_text.gd` exited 0. |
| Scope | `TXT42 ROUND 3 SCOPE: PASS (release Splits trait and merge pins, Eclipse engine, retired topics)` |
| Capture dry run | `TXT42 NATIVE PROBE: PASS (headless dry-run, 9 surfaces)`. The live Grimoire and pre-battle Noctyrax move rows also passed their exact filled-summary checks. |
| Older move-table probe | `TXT35 UI PROOF: FAIL (headless, 12 capture states)` on both `4f8d660a3` and this worktree. The seven remaining failures below reproduced on the baseline. The baseline’s two additional Cinder Ooze copy failures cleared with the release reversion. |

The witness log is at `/private/tmp/labyrinth-godot-home/txt-42-1795783949239520000-99670/godot.log`. The full suites and the Worldspine wrapper were outside this proof round.

The older move-table probe’s remaining assertion messages are reproduced here. [Worktree log](/private/tmp/labyrinth-godot-home/txt-42-1795784004960593000-99783/godot.log), [Baseline log](/private/tmp/labyrinth-godot-home/txt-42-1795784061821065000-99934/godot.log)

- `Grimoire renders the exact summary Cinder Marks 7: Ranged 4 · Fire, then Ranged 4 · Range 4`
- `Grimoire renders the exact summary Each Cinder Mark: Burst 8, then Move 2 · Melee 6`
- `Grimoire renders the exact summary Move 2 · Melee 8, then Cinder Marks 7: Ranged 3 · Fire`
- `Grimoire renders the exact summary Lightning Strikes 9: Ranged 5 · Electrified`
- `Known Moves renders Meteorfall`
- `Known Moves renders Crownfire`
- `Known Moves renders Cinder Maw`

## Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/txt-42 && tools/txt42/native.sh
```

The native script prints nine PNG paths. The renderer uses Cel Look `all` and a 1920×1080 viewport at 100% UI scale. It covers the Rewards, Electrified, Last Eclipse, Hollow Gale and Charge pages, the Splits hover, the live Last Eclipse intent hover, the normal victory reward with its +3 Health skip control, and Curator’s Patience. Native capture awaits the design owner’s run. [Dry-run log and prospective paths](/private/tmp/labyrinth_codex/txt-42-native/proof.QtkKdX/capture.log)

The new fixture settings are the cast counters 1–4, a five-second reward readiness limit and a 3-pixel tooltip hit-region sample. The probe reuses the existing combat boards, seeds and viewport.

## Files changed

- Copy and the authored move-summary template in `data/enemies.json`, `data/glossary.json`, `data/grimoire.json` and `data/pattern_rule_text.json`.
- Duration formatting and presentation in `scripts/action_icon_library.gd`, `scripts/glossary.gd` and `scripts/known_move_text.gd`, plus release’s wording in `scripts/enemy_mechanics/split_trait_text.gd`.
- Existing exact expectations in `tests/fixtures/pla02_grimoire_pages.json`, `tests/fixtures/txt20_rules_copy.json`, `tests/grimoire_search_probe.gd`, `tests/light_vision_rules_test.gd`, both short-card-tooltip tests and `tools/txt35/pages.gd`.
- Task-local witnesses, capture probe, contract and report in `tools/txt42/`.
