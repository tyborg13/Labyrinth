# area-02 feedback 2 and 3

1. Rule beats resolve on the live board. Same-turn ground placements and removals feed Lightning Storm, Frostbite and Wildfire at resolution. Wildfire's toward-you direction also reads current positions. Continue strips the retired Pass fields from hero-turn and foes-turn draft saves, then uses the saved live board when the next beat fires. The saved cadence, beat counters and marks are preserved. Beat analytics use the original payload without the draft snapshot clock.
2. Gust uses its installed direction and live occupants. A first Call or a re-aim can blow during that foes' turn. The pending Call's announced direction remains available to the existing next-beat preview.
3. The four storms retain Chain 0. Cantor damage is 4, Zekarion damage is 6 and its half-Health override merges damage 7 with Chain 0. All other numeric data is identical to feedback 1.
4. Upheaval filters illegal candidates and checks routes during marking. At the rise, individual marks can be blocked by walls, impassable terrain, traps, guardian braziers, or occupants a throw cannot move. The minimum-omission search is gone. The focused breakout fixture raises all four surrounding Outcrops, then targets, breaks and walks through one. The four approved sentences use “is on”. Tharokh's half-Health sentence carries the same caveat with its existing cadence.
5. Rule red reads the displayed board during both phases. The Pass simulation no longer injects future rule red on the hero tile, and ordinary foe-owned red remains. The Cantor playback probe checks the red at Pass, checks newly visible Bell Tender tiles on their first board update, then checks all live strike tiles.
6. Pass uses its existing information-limited simulation with the live rule resolver and the committed-action boundary for ending the activation. The audit evaluates the displayed Health row against committed Health loss, accounting for the separately displayed Fatigue cost, and checks every displayed Safe claim. It also compares visible forecasts' final Health.

## Truth audit

Each instance used three natural fights. The oracle reads the board at the beat and compares strike, catch, freeze, rise and Blink destinations to the actual resolver receipts. Gust checks its installed direction. The forecasts use the production Pass source and row display, then compare with committed turns. Across 1,190 visible forecasts, 40 displayed Safe and all were correct. The 431 information-limited forecasts kept their existing unknown treatment. In 206 of those, the shown Health subtotal differed from the eventual loss. Five fully visible Rimejaw spans originally reached the preview limit. Renewing the Frostbite span only when Health reaches a new low made all five exact. The final audit hit no forecast limits.

| Instance | Beats | Visible Passes | Hidden Passes | Impassable | Immovable unit | Trap | Brazier |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| stormcaller | 198 | 72 | 0 | 0 | 0 | 0 | 0 |
| slagmaster | 101 | 63 | 9 | 0 | 0 | 0 | 0 |
| oracle | 141 | 72 | 0 | 0 | 0 | 0 | 0 |
| dynamo | 40 | 72 | 0 | 0 | 0 | 0 | 0 |
| thornmother | 104 | 72 | 0 | 21 | 5 | 0 | 0 |
| prior | 118 | 12 | 60 | 0 | 0 | 0 | 0 |
| snare_earth | 57 | 57 | 0 | 0 | 0 | 0 | 0 |
| snare_fire | 72 | 72 | 0 | 0 | 0 | 0 | 0 |
| snare_air | 72 | 72 | 0 | 0 | 0 | 0 | 0 |
| snare_ice | 72 | 72 | 0 | 0 | 0 | 0 | 0 |
| snare_lightning | 72 | 72 | 0 | 0 | 0 | 0 | 0 |
| snare_shadow | 72 | 21 | 51 | 0 | 0 | 0 | 0 |
| last_light | 9 | 0 | 6 | 0 | 0 | 0 | 0 |
| gale_herald | 153 | 62 | 10 | 0 | 0 | 0 | 0 |
| ashen_reaver | 7 | 7 | 9 | 0 | 0 | 0 | 0 |
| rimejaw | 310 | 56 | 4 | 0 | 0 | 0 | 0 |
| storm_cantor | 70 | 3 | 29 | 0 | 0 | 0 | 0 |
| gallows_roc | 72 | 59 | 13 | 0 | 0 | 0 | 0 |
| craghide | 105 | 67 | 5 | 0 | 1 | 0 | 0 |
| last_lamplighter | 72 | 47 | 25 | 0 | 0 | 0 | 0 |
| vyraketh | 16 | 4 | 13 | 0 | 0 | 0 | 0 |
| tharokh | 36 | 58 | 14 | 0 | 16 | 0 | 0 |
| iskaldra | 103 | 37 | 35 | 0 | 0 | 0 | 0 |
| vaeloryx | 196 | 25 | 46 | 0 | 0 | 0 | 0 |
| zekarion | 43 | 36 | 30 | 0 | 0 | 0 | 0 |
| noctyrax | 48 | 0 | 72 | 0 | 0 | 0 | 0 |

All instance mismatch counts are zero. The focused fixtures also exercise traps and braziers, plus wall, Anchored, burrowed, multi-tile and no-landing cases. Natural blocker receipts have before/after reproductions. The Cantor capture starts with four visible red tiles and shows two newly visible Bell Tender tiles turning red before Peal strikes the full 18-tile field. Seed 1 at initiative clock 0 forecasts and realizes 73 Health loss over the visible foes’ turn.

Truth receipts, per-instance logs, the aggregate `summary.json`, save fixtures and reproductions are under `/private/tmp/labyrinth_codex/area-02/f2/truth`. The headless sidecar is `/private/tmp/labyrinth_codex/area-02/f2/headless-captures/cantor.json`.

## Storm ladder

Each row compares the same 64 natural fights, using the same seeds, room coordinates, entrances, tier, deck presets and bot policy. Before uses the archived final feedback-1 project.

| Instance | Wins before → after | Mean turns before → after (change) | Mean Health lost before → after (change) |
| --- | ---: | ---: | ---: |
| storm_cantor | 17 → 18 | 7.562 → 7.516 (-0.047) | 22.062 → 22.141 (+0.078) |
| zekarion | 24 → 23 | 4.266 → 4.312 (+0.047) | 20.859 → 20.641 (-0.219) |
| dynamo | 23 → 23 | 8.625 → 8.547 (-0.078) | 19.578 → 20.000 (+0.422) |
| snare_lightning | 40 → 40 | 3.172 → 3.172 (+0.000) | 12.562 → 12.562 (+0.000) |

Per-fight records, timing, costs and summaries are under `/private/tmp/labyrinth_codex/area-02/f2/ladder`.

## Focused verification

```text
AREA02 TRUTH: PASS (26 instances; 2359 beats; 0 beat mismatches; 2 Cantor/Bell Tender tiles)
AREA02 PASS FORECAST: 1190 visible; 431 hidden; 0 mismatches; 40 Safe claims
AREA02 LADDER before: PASS (4 instances; N=64 each)
AREA02 LADDER after: PASS (4 instances; N=64 each)
ATK13 CAPTURE area02-cantor: PASS
ATK14 RULES RESULT: PASS (0 failures)
ATK03 FOCUSED RESULT: PASS (1792 assertions, 0 failures)
ATK04 FOCUSED RESULT: PASS (892 assertions, 0 failures)
THREATS AT REST TEST RESULT: PASS (16970 assertions; includes compass suite)
Ran 25 tests in 9.152s
OK
AREA02 CARD HEURISTIC: PASS (309 scores unchanged)
AREA02 RULE DATA: PASS (all non-sentence values unchanged)
```

The focused rules runner includes the battlefield rules, live fuel, Upheaval, Gust, conduction and player Chain suites. The full suites were outside this round’s proof. No new test modules were added.

## Proof for the design owner

The headless Cantor playback emits a semantic JSON sidecar. The native command below uses the existing visual probe runner with the cel look, a 1920×1080 board and 100% UI scale.

```sh
sh tools/area02/native_proof.sh
```

The fixture is `/private/tmp/labyrinth_codex/area-02/f2/truth/fixtures/storm_cantor`. The capture contract requires `cantor_pass.png`, `cantor_tender.png` and `cantor_strike.png` under `/private/tmp/labyrinth_codex/area-02/f2/captures`, with a runner manifest alongside them. The native images remain for the owner to capture.

## Chosen defaults

The truth sampler keeps three natural fights per instance, up to 24 decisions per fight, 9,999 proof HP, 24 spent Time (96 for the Cantor) and a seeded 75% legal-move attempt. The realized forecast span uses the existing 100-activation bound for consecutive Frozen turns. The capture uses the existing 1,800-frame headless limit, 14,400-frame native limit and 16× headless time scale. These are proof-only settings.

No new `TODO_DESIGN` placeholders were needed.

## Files changed

- `data/battlefield_rules.json`
- `scripts/battlefield_rule_view.gd`
- `scripts/battlefield_rules/analytics.gd`
- `scripts/battlefield_rules/dispatcher.gd`
- `scripts/battlefield_rules/frostbite.gd`
- `scripts/battlefield_rules/fuel.gd`
- `scripts/battlefield_rules/geometry.gd`
- `scripts/battlefield_rules/gust.gd`
- `scripts/battlefield_rules/hit.gd`
- `scripts/battlefield_rules/lightning_storm.gd`
- `scripts/battlefield_rules/outcomes.gd`
- `scripts/battlefield_rules/playback.gd`
- `scripts/battlefield_rules/snapshot.gd`
- `scripts/battlefield_rules/upheaval.gd`
- `scripts/battlefield_rules/upheaval_rise.gd`
- `scripts/battlefield_rules/wildfire.gd`
- `scripts/board_attack_rules.gd`
- `scripts/combat_board_view.gd`
- `scripts/combat_engine.gd`
- `scripts/pass_forecast_frozen_turns.gd`
- `scripts/pass_forecast_red_tiles.gd`
- `scripts/pass_forecast_repeats.gd`
- `scripts/snare_pressure_rules.gd`
- `scripts/snare_pressure_view.gd`
- `spec/analytics.md`
- `spec/card_balance_heuristic.md`
- `tests/fixtures/bos02_dragon_sentences.json`
- `tests/fixtures/bos04_dragon_acceptance.json`
- `tests/fixtures/bos04_guardian_acceptance.json`
- `tests/suites/battlefield_conduction_suite.gd`
- `tests/suites/battlefield_fuel_suite.gd`
- `tests/suites/battlefield_rules_feedback_suite.gd`
- `tests/suites/battlefield_rules_suite.gd`
- `tests/suites/battlefield_snapshot_feedback_suite.gd`
- `tools/area02/FEEDBACK_2_3.md`
- `tools/area02/capture.gd`
- `tools/area02/native_proof.sh`
- `tools/area02/safety_audit.gd`
- `tools/atk13/rule_audit.gd`
- `tools/atk13/rule_audit.py`
- `tools/atk13/rule_observer.gd`
- `tools/atk13/rule_truth.gd`
- `tools/card_heuristic.py`

The worktree is uncommitted. Native pixels remain the owner’s inspection item.
