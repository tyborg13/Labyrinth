# Encounter measurement baseline (spx-01)

Revision 6, policy version 2, integration HEAD `64345c31e73a14e2666b3b04d32102bde582f381`. 200 natural rooms per standard Defeat All and Warband cohort per tier; all outcomes are included in percentiles. The exact tooling hash is in `measurements/revision6/baseline.json`. This bounded greedy bot measures current production rules. No gameplay or policy tuning changed in this integration update.

Run `python3 tools/encounter_sweep.py --revision 6` then `python3 tools/encounter_bot.py --baseline --revision 6`. Gzipped raw records, summary JSON and composition tables are in `measurements/revision6/`. Per-process logs and uncompressed working records stay under `/private/tmp/spx-01-measurement-logs/`. Replay with `python3 tools/encounter_bot.py --revision 6 --cohort COHORT --seed SEED --tier TIER --coord=X,Y --runs 1 --output-dir /private/tmp/spx-01-replay`.

[Revision-5 policy v2](baseline_policy_v2_revision5.md) and [policy v1](baseline_policy_v1.md) retain the earlier nine-cohort reports. Their original gzipped records and summaries remain unchanged in `measurements/`. To measure the supported legacy generator today, add `--revision 5` to both tools; select bot cohorts with `--objective kill_all`, `kill_leader` or `reach_exit`. Legacy reruns default to `measurements/revision5/`, preserving historical evidence. Current standard rooms never roll leader or exit objectives; Warband supplies Defeat the Leader. Reach Exit is not a current cohort, so its escape share is not applicable.

## Sampling and definitions

For each seed, generate all six real sections using the selected saved map revision. For each cohort/tier/biome choose one actual node at index `seed % candidate_count` in generation order, and use its first incoming map edge. Standard nodes have type `combat`; Warband nodes have type `special` and `special_type=warband`. A missing bin is skipped and continues with later seeds until it has 2,000 distinct seeds. The Warband variant is the actual section biome. No room type, tier, roster, variant or objective is forced. An earlier combat is marked cleared in the isolated measurement input to avoid the onboarding override; encounter history is empty. RunEngine produces each layout, including equipment drops and spx-03 Warband formation. Biomes follow the actual section boss. Bot cohorts scan these samples in ascending seed and production section order, retaining the first 200 matches; biome counts are in baseline.json.

The golden oracle is pinned to the supported revision-5 generator, retaining the original seed hashes rather than replacing them with spx-02/03 revision-6 output. Its purpose is to detect measurement side effects. The real ProgressionStore save/load regression still exercises current revision-6 runs. Separate sweep checks cover both revisions, and dodge/defense and three-objective determinism use explicit test arenas independent of map rolls. Headless proof and exact commands are in `measurements/feedback_3_proof.json`; no windowed proof applies.

Turns count hero activations, starting at 1, with lethal enemy phases attributed to the preceding hero turn. HP lost is cumulative actual HP damage (production damage_received); net HP loss is also retained. Kills and HP removed use production enemies_killed and damage_dealt, excluding fleeing/objective-cleared followers and including summons killed inside a transition. First death is the first committed transition increasing enemies_killed; null means none. One-turn escape share uses all Reach Exit runs as denominator, counting activation-1 victories. P10/P90 use nearest rank; medians average the middle pair. Turn-capped runs count as losses and retain their flag.

## Combat baseline

| Tier | Cohort | Objective | N | Win rate | Turns median (P10–P90) | HP lost median (P10–P90) | One-turn escapes |
|---|---|---|---:|---:|---:|---:|---:|
| 1 | standard | kill_all | 200 | 66.5% | 5 (3–9) | 13 (0–26) | — |
| 1 | warband | kill_leader | 200 | 82.5% | 7 (4–14) | 11 (2–24) | — |
| 2 | standard | kill_all | 200 | 40.5% | 5 (3–9) | 24 (7–26) | — |
| 2 | warband | kill_leader | 200 | 71.0% | 8 (3–14) | 16.5 (2–26) | — |
| 3 | standard | kill_all | 200 | 27.0% | 5 (3–13) | 24 (12–26) | — |
| 3 | warband | kill_leader | 200 | 37.5% | 7 (3–19) | 24 (9–26) | — |

Tier-1 Defeat All target (≥70% wins, median HP lost ≤8): NOT MET. The earlier revision-5 policy v2 baseline measured 64% wins and 15 median HP lost; policy v1 measured 12.5% and 24. Those historical rooms differ from this revision-6 cohort. A failed target leaves the policy unqualified for encounter-band calibration.

## Chosen defaults

These affect measurement only. Tier 1 uses GameData.starting_deck(), default equipment, no relics, 24 HP. Tier 2 appends three common reward rolls; tier 3 appends those commons and two rares. Rewards come from the actual coordinate-based reward offer stream on the fixed seed below (coordinates `(roll + 1, 0)`, with each room’s natural element); accepted duplicates are retained. No skills, consumables, omens or Defiance; no Empower. All otherwise equal ties use explicit generation order. Before each card, search the current tile and up to five free-move origins, prioritizing retained movement and then distance to the objective. Multiaction cards use sequential engine resolution with bounded target branches. Rank the shortlist by actual HP removed + 5 per kill + objective progress + potential defense and healing, preferring retained free movement on ties. For each of the top six candidates, search every legal remaining free-movement destination and staying put. Destinations are ordered by objective distance; a surviving zero-damage preview reaches the exact lower bound, so the remaining previews can be pruned. Choose the dodge with the least predicted HP damage (including damage on the path); ties approach the nearest living enemy or designated leader by Manhattan distance, or the nearest exit by grid-only path distance. Evaluate the card against passing with its own best dodge: damage/kills/objective progress + healing + 1.5 × (pass damage − candidate damage). Thus Block and Stoneskin earn only the HP damage the live preview says they prevent this phase; no flat defense bonus is paid. Free exit progress already available when passing is subtracted. A pass or evaluated candidate whose preview survives always displaces a lethal preview, regardless of raw score. The live preview stops at unrevealed follow-up intents; the policy does not inspect those future actions. Commit the card and its approach, then replan; commit the dodge after the final card. Highest positive score wins; otherwise pass and dodge. Search limits deliberately constrain the policy and must be held fixed for future comparisons.

```json
{
  "approach_order": "retained movement, objective distance, engine order",
  "damage_score": "1.5 times (pass-dodge damage minus candidate-dodge damage)",
  "deck_reward_seed": 2102026,
  "defiance": 0,
  "dodge_search": "all remaining free-movement destinations plus stay; objective-sorted zero-damage bound",
  "empower": false,
  "healing_weight": 1.0,
  "hp": 24,
  "incoming_damage_weight": 1.5,
  "kill_score": 5.0,
  "max_action_targets": 3,
  "max_card_branches": 3,
  "max_decisions_per_turn": 12,
  "max_expanded_action_states": 96,
  "max_move_options": 5,
  "max_preview_options": 6,
  "max_turns": 30,
  "objective_progress_weight": 1.0,
  "policy_version": 2,
  "relics": [],
  "reward_roll_limit": 10000,
  "skills": [],
  "survival_first": true,
  "trace": false
}
```

Reward presets:

```json
{
  "1": [
    "quick_stab",
    "whirlwind_slash",
    "bloody_lunge",
    "brace",
    "guarded_step",
    "patch_up",
    "shadow_step",
    "sidestep_slash",
    "hamstring_shot",
    "lantern_shot",
    "pale_spark",
    "pale_spark",
    "dull_bolt",
    "dull_bolt",
    "waning_pulse",
    "waning_pulse"
  ],
  "2": [
    "quick_stab",
    "whirlwind_slash",
    "bloody_lunge",
    "brace",
    "guarded_step",
    "patch_up",
    "shadow_step",
    "sidestep_slash",
    "hamstring_shot",
    "lantern_shot",
    "pale_spark",
    "pale_spark",
    "dull_bolt",
    "dull_bolt",
    "waning_pulse",
    "waning_pulse",
    "updraft",
    "hoarfrost_ward",
    "cold_grasp"
  ],
  "3": [
    "quick_stab",
    "whirlwind_slash",
    "bloody_lunge",
    "brace",
    "guarded_step",
    "patch_up",
    "shadow_step",
    "sidestep_slash",
    "hamstring_shot",
    "lantern_shot",
    "pale_spark",
    "pale_spark",
    "dull_bolt",
    "dull_bolt",
    "waning_pulse",
    "waning_pulse",
    "updraft",
    "hoarfrost_ward",
    "cold_grasp",
    "flashsteam",
    "molten_reach"
  ],
  "common_rewards": [
    "updraft",
    "hoarfrost_ward",
    "cold_grasp"
  ],
  "rare_rewards": [
    "flashsteam",
    "molten_reach"
  ]
}
```

The sweep starts at seed 1 and accepts 2,000 seeds per cohort/tier/biome. Golden seeds are 1, 19 and 421 at revision 5. Seed scanning is bounded at 100,000 seeds per process; an unfilled cohort fails explicitly. Baselines start at seed 1; the Python driver uses 6 concurrent isolated Godot processes. The offline measurement timeout is 7,200 seconds per process; ordinary tests retain the project caps. New test-only defaults are `SMALL_SWEEP_MAX_SEED=100` and `POLICY_FIXTURE.determinism_enemy_hp=8`; they affect fixture coverage only. Completed bot rooms checkpoint after each room. Interrupted JSONL sweep output retains complete rows and trims the incomplete final row. Rebuild Markdown from finished measurements with `--baseline --report-only`.

## Composition sweep

Values are median (nearest-rank P10–P90). Base HP sums enemy-definition max_hp before scaling; spawn HP sums generated max_hp including leader bonuses. Roles use ai_profile.role, with missing roles labelled unspecified. Leader distance is Manhattan distance from the entry to the enemy spawn anchor; ties count as closest. Exit paths retain grid walls/pillars and ignore actors, destructible terrain, traps and surfaces. Free turns = ceil(path / 2).

| Tier | Biome | Cohort / Objective | N | Units | Base HP | Spawn HP | Leader distance | Closest | Exit path | Free turns |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | air | standard / kill_all | 2000 | 3 (3–4) | 37 (34–42) | 39 (32–44) | — | — | — | — |
| 1 | air | warband / kill_leader | 2000 | 4 (4–4) | 46 (46–46) | 52 (48–58) | 6 (5–7) | 0.0% | — | — |
| 1 | earth | standard / kill_all | 2000 | 3 (3–4) | 36 (34–38) | 38 (32–44) | — | — | — | — |
| 1 | earth | warband / kill_leader | 2000 | 4 (4–4) | 44 (44–44) | 51 (49–58) | 6 (5–7) | 0.0% | — | — |
| 1 | fire | standard / kill_all | 2000 | 3 (3–4) | 36 (34–42) | 39 (33–48) | — | — | — | — |
| 1 | fire | warband / kill_leader | 2000 | 4 (4–4) | 34 (34–34) | 43 (42–50) | 6 (5–7) | 0.0% | — | — |
| 1 | ice | standard / kill_all | 2000 | 3 (3–4) | 36 (34–43) | 39 (32–48) | — | — | — | — |
| 1 | ice | warband / kill_leader | 2000 | 4 (4–4) | 44 (44–44) | 51 (48–58) | 6 (5–7) | 0.0% | — | — |
| 1 | lightning | standard / kill_all | 2000 | 3 (3–4) | 38 (35–50) | 41 (33–52) | — | — | — | — |
| 1 | lightning | warband / kill_leader | 2000 | 4 (4–4) | 48 (48–48) | 58 (54–65) | 7 (7–7) | 0.0% | — | — |
| 1 | shadow | standard / kill_all | 2000 | 3 (3–4) | 36 (34–40) | 46 (43–52) | — | — | — | — |
| 1 | shadow | warband / kill_leader | 2000 | 4 (4–4) | 33 (33–33) | 48 (48–48) | 6 (5–7) | 0.0% | — | — |
| 2 | air | standard / kill_all | 2000 | 4 (4–5) | 52 (46–60) | 62.5 (51–73) | — | — | — | — |
| 2 | air | warband / kill_leader | 2000 | 5 (5–5) | 51 (51–51) | 67 (55–74) | 6 (5–7) | 0.0% | — | — |
| 2 | earth | standard / kill_all | 2000 | 4 (4–5) | 50 (48–56) | 60 (50–71) | — | — | — | — |
| 2 | earth | warband / kill_leader | 2000 | 5 (5–5) | 56 (56–56) | 67 (60–80) | 6 (5–7) | 0.0% | — | — |
| 2 | fire | standard / kill_all | 2000 | 5 (4–6) | 50 (46–60) | 62 (50–76) | — | — | — | — |
| 2 | fire | warband / kill_leader | 2000 | 5 (5–5) | 46 (46–46) | 60 (51–68) | 6 (5–7) | 0.0% | — | — |
| 2 | ice | standard / kill_all | 2000 | 4 (4–5) | 50 (47–61) | 61.5 (51–76) | — | — | — | — |
| 2 | ice | warband / kill_leader | 2000 | 5 (5–5) | 49 (49–49) | 59 (52–70) | 6 (5–7) | 0.0% | — | — |
| 2 | lightning | standard / kill_all | 2000 | 5 (4–5) | 56 (47–66) | 64 (52–83) | — | — | — | — |
| 2 | lightning | warband / kill_leader | 2000 | 5 (5–5) | 53 (53–53) | 65 (59–81) | 7 (7–7) | 0.0% | — | — |
| 2 | shadow | standard / kill_all | 2000 | 4 (4–6) | 50 (47–56) | 71 (67–80) | — | — | — | — |
| 2 | shadow | warband / kill_leader | 2000 | 5 (5–5) | 37 (37–37) | 59 (59–59) | 6 (5–7) | 0.0% | — | — |
| 3 | air | standard / kill_all | 2000 | 5 (5–6) | 66 (58–74) | 92 (75–109) | — | — | — | — |
| 3 | air | warband / kill_leader | 2000 | 6 (6–6) | 56 (56–56) | 83 (70–96) | 6 (5–7) | 0.0% | — | — |
| 3 | earth | standard / kill_all | 2000 | 5 (4–6) | 66 (54–74) | 89 (73–106) | — | — | — | — |
| 3 | earth | warband / kill_leader | 2000 | 6 (6–6) | 70 (70–70) | 103 (85–117) | 6 (5–7) | 0.0% | — | — |
| 3 | fire | standard / kill_all | 2000 | 6 (5–7) | 66 (54–76) | 92 (77–109) | — | — | — | — |
| 3 | fire | warband / kill_leader | 2000 | 6 (6–6) | 52 (52–52) | 81 (67–90) | 6 (5–7) | 0.0% | — | — |
| 3 | ice | standard / kill_all | 2000 | 5 (5–6) | 67 (54–79) | 94 (76–111) | — | — | — | — |
| 3 | ice | warband / kill_leader | 2000 | 6 (6–6) | 61 (61–61) | 91 (75–102) | 6 (5–7) | 0.0% | — | — |
| 3 | lightning | standard / kill_all | 2000 | 6 (5–6) | 69 (62–82) | 97.5 (79–116) | — | — | — | — |
| 3 | lightning | warband / kill_leader | 2000 | 6 (6–6) | 59 (59–59) | 90 (76–102) | 7 (7–7) | 0.0% | — | — |
| 3 | shadow | standard / kill_all | 2000 | 5 (5–7) | 66 (54–74) | 110 (91–123) | — | — | — | — |
| 3 | shadow | warband / kill_leader | 2000 | 6 (6–6) | 41 (41–41) | 76 (76–76) | 6 (5–7) | 0.0% | — | — |

Role mix is a share of all units in the group. Leader types are room counts.

| Tier | Biome | Cohort / Objective | Role mix | Leader types |
|---|---|---|---|---|
| 1 | air | standard / kill_all | artillery 6.5%, controller 9.7%, frontliner 35.4%, protector 2.4%, skirmisher 43.5%, support 2.4% | — |
| 1 | air | warband / kill_leader | controller 50.0%, skirmisher 50.0% | gale_herald: 2000 |
| 1 | earth | standard / kill_all | artillery 6.9%, controller 6.0%, frontliner 37.9%, protector 2.4%, skirmisher 44.3%, support 2.4% | — |
| 1 | earth | warband / kill_leader | controller 25.0%, frontliner 50.0%, protector 25.0% | briar_weaver: 2000 |
| 1 | fire | standard / kill_all | artillery 9.7%, controller 2.0%, frontliner 51.2%, protector 1.9%, skirmisher 32.9%, support 2.2% | — |
| 1 | fire | warband / kill_leader | artillery 25.0%, frontliner 75.0% | slag_mortar: 2000 |
| 1 | ice | standard / kill_all | artillery 12.1%, controller 10.3%, frontliner 34.3%, protector 5.9%, skirmisher 35.5%, support 1.9% | — |
| 1 | ice | warband / kill_leader | controller 25.0%, frontliner 50.0%, protector 25.0% | hoarfrost_seer: 2000 |
| 1 | lightning | standard / kill_all | artillery 10.3%, controller 4.3%, frontliner 28.4%, protector 2.0%, skirmisher 53.1%, support 2.0% | — |
| 1 | lightning | warband / kill_leader | artillery 25.0%, skirmisher 75.0% | storm_capacitor: 2000 |
| 1 | shadow | standard / kill_all | artillery 6.5%, controller 1.9%, frontliner 39.1%, protector 2.1%, skirmisher 48.1%, support 2.2% | — |
| 1 | shadow | warband / kill_leader | skirmisher 100.0% | hollow_mimic: 2000 |
| 2 | air | standard / kill_all | artillery 12.9%, controller 9.5%, frontliner 31.9%, protector 6.9%, skirmisher 33.8%, support 5.0% | — |
| 2 | air | warband / kill_leader | controller 40.0%, frontliner 20.0%, skirmisher 40.0% | gale_herald: 2000 |
| 2 | earth | standard / kill_all | artillery 13.1%, controller 5.9%, frontliner 34.1%, protector 7.2%, skirmisher 34.1%, support 5.5% | — |
| 2 | earth | warband / kill_leader | controller 20.0%, frontliner 40.0%, protector 20.0%, skirmisher 20.0% | briar_weaver: 2000 |
| 2 | fire | standard / kill_all | artillery 15.3%, controller 2.2%, frontliner 46.2%, protector 6.4%, skirmisher 24.7%, support 5.1% | — |
| 2 | fire | warband / kill_leader | artillery 20.0%, frontliner 80.0% | slag_mortar: 2000 |
| 2 | ice | standard / kill_all | artillery 17.8%, controller 9.1%, frontliner 30.5%, protector 10.9%, skirmisher 26.7%, support 5.0% | — |
| 2 | ice | warband / kill_leader | artillery 20.0%, controller 20.0%, frontliner 40.0%, protector 20.0% | hoarfrost_seer: 2000 |
| 2 | lightning | standard / kill_all | artillery 15.7%, controller 3.9%, frontliner 25.4%, protector 7.0%, skirmisher 43.2%, support 4.9% | — |
| 2 | lightning | warband / kill_leader | artillery 20.0%, controller 20.0%, skirmisher 60.0% | storm_capacitor: 2000 |
| 2 | shadow | standard / kill_all | artillery 12.0%, controller 2.7%, frontliner 35.4%, protector 7.0%, skirmisher 37.8%, support 5.2% | — |
| 2 | shadow | warband / kill_leader | frontliner 20.0%, skirmisher 80.0% | hollow_mimic: 2000 |
| 3 | air | standard / kill_all | artillery 17.4%, controller 11.3%, frontliner 23.6%, protector 20.4%, skirmisher 24.6%, support 2.7% | — |
| 3 | air | warband / kill_leader | controller 33.3%, frontliner 33.3%, skirmisher 33.3% | gale_herald: 2000 |
| 3 | earth | standard / kill_all | artillery 18.3%, controller 7.5%, frontliner 24.9%, protector 21.4%, skirmisher 24.8%, support 3.1% | — |
| 3 | earth | warband / kill_leader | artillery 16.7%, controller 16.7%, frontliner 33.3%, protector 16.7%, skirmisher 16.7% | briar_weaver: 2000 |
| 3 | fire | standard / kill_all | artillery 20.0%, controller 2.7%, frontliner 40.3%, protector 18.9%, skirmisher 15.2%, support 2.8% | — |
| 3 | fire | warband / kill_leader | artillery 16.7%, frontliner 83.3% | slag_mortar: 2000 |
| 3 | ice | standard / kill_all | artillery 23.4%, controller 11.6%, frontliner 21.9%, protector 24.8%, skirmisher 15.3%, support 3.0% | — |
| 3 | ice | warband / kill_leader | artillery 16.7%, controller 16.7%, frontliner 33.3%, protector 16.7%, skirmisher 16.7% | hoarfrost_seer: 2000 |
| 3 | lightning | standard / kill_all | artillery 21.0%, controller 5.0%, frontliner 16.6%, protector 19.3%, skirmisher 35.3%, support 2.7% | — |
| 3 | lightning | warband / kill_leader | artillery 16.7%, controller 16.7%, skirmisher 66.7% | storm_capacitor: 2000 |
| 3 | shadow | standard / kill_all | artillery 17.2%, controller 2.6%, frontliner 27.0%, protector 19.8%, skirmisher 30.6%, support 2.7% | — |
| 3 | shadow | warband / kill_leader | frontliner 33.3%, skirmisher 66.7% | hollow_mimic: 2000 |
