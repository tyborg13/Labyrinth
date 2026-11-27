# txt-42 rules copy truth report

The implementation is uncommitted on `codex/txt-42`. The initial pass changed 16 live copy fields. Feedback 1 updated three of the four lines retained after that pass. The player’s Meteorfall sentence passed unchanged.

## Initial pass

### Before and after

| Requirement and surface | Before | After | Headless verdict |
| --- | --- | --- | --- |
| 1. Glossary `cinder_marks` | When this attack lands, each unit on a Marked tile takes X damage, and each Marked tile becomes Fire. | When this attack lands, you and your Illusions on Marked tiles take X damage, and each Marked tile becomes Fire. | PASS. Vyraketh hit the marked hero and Illusion for 4 each. The marked enemy took 0. Four marks became Fire, including an empty tile. |
| 1. Grimoire `combat:cinder_marks` body 0 | When this attack lands, each unit on a Marked tile takes X damage, and each Marked tile becomes Fire. | When this attack lands, you and your Illusions on Marked tiles take X damage, and each Marked tile becomes Fire. | PASS. The same Vyraketh witness applies. |
| 1. Grimoire Meteorfall sentence in body 1 | At the start of your next turn, each unit on a Marked tile takes damage, and each Marked tile becomes Fire. | Retained verbatim | PASS. The marked hero, Illusion and enemy each lost 8 at the next player turn start. The unmarked enemy lost 0. All three marks became Fire. |
| 2. Glossary `surface_electrified` | A Lightning card's hit on an Electrified tile also hits each enemy on connected Electrified tiles. | A Lightning card's hit on an Electrified tile also hits each visible enemy on connected Electrified tiles. | PASS. Jolt dealt 2 to the primary and connected visible enemies. The connected hidden and disconnected enemies took 0. |
| 2. Grimoire `keyword:surface_electrified` body 0 | A Lightning card's hit on an Electrified tile also hits each enemy on connected Electrified tiles. | A Lightning card's hit on an Electrified tile also hits each visible enemy on connected Electrified tiles. | PASS. The same Jolt witness applies. |
| 3. Glossary `charge` | At 3 Charge, this enemy's next attack is Arc Lash. Shock removes 1 Charge. | At 3 Charge, this enemy's next attack is Arc Lash. Becoming Shocked removes 1 Charge. | PASS. The third Charge selects Arc Lash. Fresh Shock takes Charge to 2, and repeated Shock leaves it at 2. |
| 4. Grimoire `keyword:upheaval` body 1 | The tile stays flat if the unit cannot be moved. Destroy an Outcrop to open a route. | The tile stays flat if the unit cannot be moved. A Marked tile holding a trap stays flat. Destroy an Outcrop to open a route. | PASS. An immovable occupant and a trap held their marks flat. Destroying an Outcrop made its tile a legal Move target. |
| 5. Grimoire `combat:boss_eclipse` body 0 | Last Eclipse hits you and your Illusions on Marked tiles, then starts Eclipse for 2 turns. | Retained verbatim | FAIL. Eclipse is active at both marked hits and on the first upcoming player turn. The second player turn starts clear. |
| 6. Grimoire `combat:hollow_gale` body 0 | Hollow Gale damages each unit within 2 tiles of Vaeloryx, then Pushes each unit hit away. | Retained verbatim | FAIL. The hero and Illusion each lost 6, and the enemy lost 0. The hero moved one tile. The hit Illusion stayed in place with a free landing tile. |
| 7. Glossary `splits` | When this enemy dies, this enemy splits into smaller enemies on adjacent tiles. | When this enemy dies, this enemy splits into smaller enemies on free adjacent tiles. | PASS. With 4, 1 and 0 free adjacent tiles, the Ooze spawned 2, 1 and 0 Cinder Droplets on free adjacent tiles. |
| 7. Split trait format | On death, this enemy splits into %d %s within %d tile%s. | On death, this enemy splits into up to %d %s on free tiles within %d tile%s. | PASS. The same death-spawn witness verifies the bound and the landing condition. |
| 8. Grimoire `basic:rewards` body 0 | After combat, take 1 of 3 cards, or skip to heal 3. | Retained verbatim | FAIL. A Warband offers 4 cards and a Guardian awards a trophy without cards. Ember Hoarder and Last Light also offer 4 cards, and dragons award a separate milestone without card choices. |
| 9. Glossary `targeting` | Targets must be visible and within Range. Ranged attacks also need line of sight. | Attack targets must be visible and within Range. Ranged attacks also need line of sight. | PASS. Arc Flash required visibility, Range and line of sight. Beacon and Walk could pick hidden tiles. Skybolt exercised the explicit line-of-sight exception. |
| 10. Grimoire `combat:fatigue` body 0 | Drawing from an empty draw pile shuffles your discard into your draw pile and costs Health. | Drawing from an empty draw pile shuffles your discard into your draw pile and costs Health. With both piles empty, drawing does nothing. | PASS. Recycling two discards drew one card for 2 Health. Empty draw and discard piles produced no card, Health cost or reshuffle. |
| 11. Curator’s Patience skill description | After choosing a relic, save one unchosen relic for your next relic offer. | After choosing a relic, save one unchosen relic for your next Relic room. | PASS. The saved relic appeared in the next Relic room. Guardian and dragon rewards kept it pending. |
| 11. Glossary `skill_curators_patience` | After choosing a relic, save one unchosen relic for your next relic offer. | After choosing a relic, save one unchosen relic for your next Relic room. | PASS. The same relic-offer witness applies. |
| 11. Curator’s Patience dialog detail | This relic will replace one choice in your next relic offer. | Retained verbatim | FAIL. The saved relic can roll naturally in the next Relic room. At seed 73037 that left every choice unchanged. |
| 12. Glossary `swap` | Trade places with a visible enemy or one of your illusions. | Trade places with a visible enemy or one of your visible Illusions. | PASS. Changing Winds swaps with a visible enemy or Illusion. Both Illusion-swapping cards rejected the hidden Illusion. |
| 12. Grimoire `combat:swap` body 0 | Trade places with a visible enemy or one of your illusions. | Trade places with a visible enemy or one of your visible Illusions. | PASS. The same Swap witness applies. |
| 12. Glossary `illusion_swap` | Trade places with one of your illusions. | Trade places with one of your visible Illusions. | PASS. Empty Husk and Changing Winds swapped with the Illusion in clear visibility and refused it in Eclipse. |
| 12. Grimoire `keyword:illusion_swap` body 0 | Trade places with one of your illusions. | Trade places with one of your visible Illusions. | PASS. The same Swap Illusion witness applies. |

### Witness notes

- **Cinder Marks card gate passed.** The card tooltip inventory found Meteorfall using its contextual player copy, “Next turn before you Draw, deal 8 damage and leave Fire on each Marked tile.” No inspected card showed the generic Cinder Marks glossary definition.
- **Last Eclipse.** The damage trace confirms the proposed ordering. The active stage on cast, the first player turn and the second player turn was `eclipse, eclipse, clear`, with counters `2, 1, 0`. The “next 2 turns” clause blocked the replacement.
- **Rewards.** Ordinary combat and Umbral Snare offer 3 cards and skip heals 3. Warband, successful Ember Hoarder and successful Last Light offer 4 cards and skip heals 3. The Guardian offered only `ashen_brand`, so the proposed Guardian suffix is true. The fire dragon awarded `crowncoal_heart`, 6 Health and 1 Moltshard with zero card choices in the fixture. The full proposed Rewards paragraph, even with the Guardian suffix, leaves the other four-card rewards and the dragon card exception undisclosed. Body 0 was retained as a unit.
- **Curator’s Patience.** A deferred `thawing_charm` entered the next Relic room’s offer and cleared the pending ID. The Guardian offered `ashen_brand` and the dragon awarded `crowncoal_heart`, with the deferred ID still pending after either route. At seed 73037, saving `static_soles` replaced one choice, while saving `hourglass_splinter` left the three choices unchanged because that relic already rolled. The proposed dialog detail promises replacement in both situations.
- **Other copy outside this unit.** The Charge intent tooltip and Grimoire Charge page have their own wording. The in-scope glossary definition also feeds the live Charge badge. Historical `spl-01` and `txt-35` probes retain their revision-specific Splits text. The live trait is checked by the txt-42 proof.

### Checks

| Command or case | Result |
| --- | --- |
| `python3 tools/godot_task_runner.py --task-id txt-42 --stream -- godot --headless --path . --script res://tools/txt42/witnesses.gd` | `TXT42 WITNESSES: PASS (23 observations, 5 false claims)`. The five FAIL rows are the confirmed counterexamples mapped to the four retained replacements. |
| `python3 tests/test_rules_text_lint.py` | `Ran 3 tests in 0.063s`, `OK`, `PASS: Rules text lint (16 existing hits)`. |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 7.734s`, `OK`. |
| `python3 tests/test_card_panel_text.py` | `Ran 4 tests in 0.007s`, `OK`. |
| Headless `tests/card_panel_text_test.gd` | `CARD PANEL TEXT TEST RESULT: PASS (2210 definitions, 7772 panels, 15773 checks, 0 failures)`. The length check permits 17 words for the exact approved Electrified body. All other panels keep their existing tests and limits. |
| Headless `tests/short_card_tooltips_test.gd` | `SHORT CARD TOOLTIPS TEST RESULT: PASS (707 checks, 0 failures)`. |
| Headless `tests/board_tile_tooltip_test.gd` | `BOARD TILE TOOLTIPS: PASS checks=233 failures=0`. The test logged missing glossary definitions for `bramble` and `ice_pillar`. |
| Headless `tests/en06_enemies_test.gd` | `EN06 ENEMIES TEST RESULT: PASS (136 checks, 0 failures)`. |
| Headless `tests/grimoire_search_probe.gd` | `GRIMOIRE SEARCH PROBE RESULT: PASS`. |
| Headless `tests/worldspine_rules_test.gd` | `dragon_feedback1_suite.gd: 84 checks, 0 failures`. Whole wrapper: `TRN-01 RULES RESULT: FAIL (2254 checks, 4 failures)`. |
| Worldspine feedback with original HEAD copy overlaid | `TRN-01 RULES RESULT: FAIL (14 checks, 4 failures)`. The same two FB1.1 Ember Tick damage and forecast failures and two FB1.2 Stoneskin ordering failures reproduced with the original copy. |
| Python default group, `tools/run_python_suite.py --shards 4 --changed-since HEAD` | `SELECTED MODULES: 23 of 59`, `Ran 196 tests in 37.338s`, `OK`. Updating the timing cache under Git metadata returned `Operation not permitted`. The suite exited 0. |
| `tools/txt42/native.sh --dry-run` | `TXT42 NATIVE PROBE: PASS (headless dry-run, 5 surfaces)`. |
| Capture contract and task-local sidecars | `TXT42 CAPTURE CONTRACT: PASS (5 required 1920x1080 PNGs)`, `TXT42 SIDECARS: PASS (6 unique script UIDs)`. |

Witness log: `/private/tmp/labyrinth-godot-home/txt-42-1795538925553549000-73238/godot.log`. Worldspine baseline log: `/private/tmp/labyrinth-godot-home/txt-42-1795538986404773000-73478/godot.log`. Python report: `/private/tmp/labyrinth_codex/txt-42-python.h7cqJj/summary.json`. Headless Godot emitted the macOS certificate-store diagnostic in these runs.

### Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/txt-42 && tools/txt42/native.sh
```

The script runs the native visual probe with Cel Look `all`, a 1920×1080 game viewport and 100% UI scale. It prints each PNG separately below `/private/tmp/labyrinth_codex/txt-42-native/proof.XXXXXX/captures/` and saves the validation manifest beside that directory.

The headless dry-run logged the following prospective paths. Native captures are pending because this sandbox lacks macOS WindowServer access.

```text
/private/tmp/labyrinth_codex/txt-42-native/proof.EGEzxy/captures/rewards_1920x1080.png
/private/tmp/labyrinth_codex/txt-42-native/proof.EGEzxy/captures/electrified_1920x1080.png
/private/tmp/labyrinth_codex/txt-42-native/proof.EGEzxy/captures/last_eclipse_1920x1080.png
/private/tmp/labyrinth_codex/txt-42-native/proof.EGEzxy/captures/splits_hover_1920x1080.png
/private/tmp/labyrinth_codex/txt-42-native/proof.EGEzxy/captures/curators_patience_1920x1080.png
```

### Chosen defaults

- Witnesses reuse txt-40’s seed `73021`, 80 Health, 10,000-Ember skill-learning purse, 100-point lethal margin and coordinates from a 9×9 fixture. Reward checks use 12 starting Health and named linear-room coordinates. The generated Snare uses seed 1 from its suite. The Curator natural-repeat comparison scans up to 64 seeds.
- Named witness coordinates isolate marked and unmarked occupants, conduction visibility, blocked spawn and Outcrop tiles, and an unobstructed Hollow Gale landing. These values exist only in the proof fixtures.
- The native fixture uses reduced motion, a 1.5-second chip hover and a 5-second Relic offer readiness limit. The visual runner receives 90 seconds for the five captures, including opening the Relic room and waiting for the native tooltip popup.

### Files changed

- Live copy in `data/glossary.json`, `data/grimoire.json`, `data/skills.json` and `scripts/enemy_mechanics/split_trait_text.gd`.
- Exact pins in `tests/fixtures/txt20_rules_copy.json`, `tests/fixtures/pla02_grimoire_pages.json`, `tests/fixtures/bos02_feedback1_grimoire.json`, `tests/board_tile_tooltip_test.gd`, `tests/grimoire_search_probe.gd`, `tests/suites/en06_enemies_suite.gd` and `tests/card_panel_text_test.gd`.
- Headless witnesses, native capture script and contract, script UIDs and this report in `tools/txt42/`.

The initial pass used no design placeholders.

## Feedback 1

| Requirement | Before | After | Headless verdict |
| --- | --- | --- | --- |
| 1. Last Eclipse | Last Eclipse hits you and your Illusions on Marked tiles, then starts Eclipse for 2 turns. | Last Eclipse starts Eclipse through your next turn, then hits you and your Illusions on Marked tiles. | PASS. The marked hero and Illusion each took 8 damage while Eclipse was active. The next turn started in Eclipse and the turn after started clear. |
| 2. Hollow Gale | Hollow Gale damages each unit within 2 tiles of Vaeloryx, then Pushes each unit hit away. | Hollow Gale damages you and your Illusions on Marked tiles and Pushes you 1 tile away from Vaeloryx. | PASS. At distance 2 the hero lost 6 Health and moved 1 tile away. At distance 3 the hero lost 0 and stayed put despite a free landing tile. The in-range Illusion lost 6 and stayed put in both cases. |
| 3. Rewards | After combat, take 1 of 3 cards, or skip to heal 3. | Retained verbatim | FAIL. Dying before Last Light’s dawn and dying in Umbral Snare each ended in defeat with zero card choices. |
| 4. Curator’s Patience dialog | This relic will replace one choice in your next relic offer. | This relic will appear in your next Relic room. | PASS. At seed 73037, Hourglass Splinter rolled naturally and remained in the offer. At seed 73021, Thawing Charm replaced Basalt Calendar. The saved ID cleared on entry in both cases. |

Ember Hoarder offered 3 cards after the Hoarder escaped and the remaining enemies were defeated, and 4 when caught. Surviving Last Light met the goal and offered 4 cards even with zero lit braziers, which removed the dawn healing bonus. Umbral Snare offered 3 cards after escapes with two doors open and with one door open. Each of those standard offers healed 3 on skip. The two defeat counterexamples block the proposed Rewards paragraph as a unit.

The Hollow Gale page’s linked range diagram uses an exact sentence key in the txt-41-owned `data/pattern_rule_text.json`. That key still carries the prior sentence, so the new Grimoire line displays without the inline diagram. The new line is verbatim, and the diagram mapping remains outside the txt-42 changes.

The three edits are in `data/grimoire.json` and `scripts/run_scene.gd`. The matching Grimoire pins are in `tests/fixtures/pla02_grimoire_pages.json` and `tests/fixtures/txt20_rules_copy.json`. The updated witnesses and native dry-run assertions are in `tools/txt42/`. The added fixture inputs were the distance-3 Gale control, Snare’s existing seal thresholds and the two named Curator seeds and relic IDs.

### Focused verification

| Command or case | Result |
| --- | --- |
| Headless `tools/txt42/witnesses.gd` | `TXT42 WITNESSES: PASS (29 observations, 2 false claims)`. Both false claims are Rewards counterexamples. |
| Headless `tools/txt42/witnesses.gd -- --dragon-copy-pins` | `TXT42 DRAGON COPY PINS: 45 checks, 0 failures`. This runs the existing dragon copy checks directly. |
| `python3 tests/test_rules_text_lint.py` | `Ran 3 tests in 0.061s`, `OK`, `PASS: Rules text lint (16 existing hits)`. |
| `python3 tests/test_short_card_tooltips.py` | `Ran 5 tests in 0.015s`, `OK`. |
| Headless `tests/short_card_tooltips_test.gd` | `SHORT CARD TOOLTIPS TEST RESULT: PASS (707 checks, 0 failures)`. |
| `tools/txt42/native.sh --dry-run` | `TXT42 NATIVE PROBE: PASS (headless dry-run, 5 surfaces)`. Prospective PNGs are listed in `/private/tmp/labyrinth_codex/txt-42-native/proof.Mp9PVt/capture.log`. |

Feedback witness log is at `/private/tmp/labyrinth-godot-home/txt-42-1795539600944202000-80503/godot.log`. Native inspection still uses the command under “Proof for the design owner.”

### Pre-existing Worldspine assertions

These are the four failures reproduced against the original copy in the initial pass. Feedback verification ran the dragon copy checks directly and left the Worldspine suite untouched.

1. `FB1.1 live pulse kills the Tick and its burst deals 4 to the hero`
2. `FB1.1 Pass reports the same lethal burst, loss and final plate Health`
3. `FB1.2 Mountain grants Stoneskin before either cast order pulses: ["worldspine", "rite_of_the_mountain"]`
4. `FB1.2 Mountain grants Stoneskin before either cast order pulses: ["rite_of_the_mountain", "worldspine"]`
