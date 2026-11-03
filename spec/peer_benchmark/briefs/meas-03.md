# meas-03 — How strong is Skybolt, and what would each drawback cost it? (measurement only)

## Header
- **Owner, 2026-10-22:** "Is the power level of [Skybolt] not obscene, even for a legendary? ... an infinite range
  shock seems pretty bonkers. We may need to give it a drawback if we want it to have that kind of upside."
- **Skybolt** (`data/cards.json` `skybolt`; legendary, 7 Time): ranged 7 Lightning damage at range 99, ignoring line of
  sight. It conducts, `shock: 1` and `shock_all_hits`, so every enemy it hits is Shocked (on its next turn it can only
  Move or Blink).
  - Heuristic score 6.38: the highest in the 126-card reward pool. Legendary median 4.58; best rare 5.60.
- **What exists:** meas-02's cohorts and the policy-v2 bot (`tools/encounter_measurement_bot.gd`, deck presets per
  tier), revision-7 data in `spec/peer_benchmark/encounter_redesign/measurements/revision7/`.
- **Base:** `codex/peer-benchmark`. **Owned:** the measurement bot/sweep tools and their tests (additive options only),
  new `spec/peer_benchmark/balance/skybolt/` (report + data). No gameplay or data change on the branch: variants are
  measurement-only overrides applied in memory.

## Change (director decisions)
1. **A deck-override option** for the measurement bot: start from the tier preset, then add one named card, or a card
   with in-memory field overrides. It must not change `policy_sha256` or the policy itself. If the bot never plays a
   card well (e.g. it can't target an out-of-range enemy), stop and report it as `TODO_DESIGN_bot_<what>`.
2. **Arms** (each added to the preset deck as one extra card):
   - `none` (preset only);
   - `skybolt` as it is today;
   - `wildfire_halo` (the median legendary) and `stormstring_shot` (a strong lightning rare) as reference points;
   - Skybolt variants:
     - V1 Shock only the primary target (`shock_all_hits: false`);
     - V2 Exhaust (`burn: true`);
     - V3 range 5 with line of sight (`range: 5`, no `ignore_los`);
     - V4 Time 9;
     - V5 V1 + Exhaust.
3. **Cohorts:** revision 7, tiers 2 and 3: `standard`, `warband`, `guardian`, and `boss` at tier 3 only. 150 runs per
   arm per cohort/tier, with the same seeds across arms (paired). First seed 1.
4. **Per arm, report:**
   - win rate, turns and HP lost (median, P10-P90), plus the paired win-rate and HP deltas against `none`, with 95% CIs;
   - Skybolt-specific: casts per fight, enemies hit per cast (conduction), enemy attacks cancelled by its Shock per cast,
     kills by it, and how often it hit a target beyond range 5 or out of sight.
5. **Report** `spec/peer_benchmark/balance/skybolt/report.md`: one table per cohort/tier plus the Skybolt-specific
   table. One short paragraph of comparisons only, no recommendation.

## Keep
The bot policy, deck presets (other than the one added card), every gameplay rule and number.

## Proof
Tool tests for the override option (deck contents, in-memory only, policy hash unchanged), the existing bot/sweep tests,
and the report. No full suites.

## Out of scope
Changing Skybolt or any card. The director decides from the report and asks the owner.
