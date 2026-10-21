# Encounter measurement baseline (spx-01)

Measured against integration HEAD `857c0139bd355b73a92c15249c8a62a607937a26` with additive analytics changes only. 200 natural rooms per objective per tier; all outcomes are included in percentiles. This is a bounded greedy bot baseline, not a model of expert play. No encounter, objective, reward, map, combat or save rules change.

Run `python3 tools/encounter_sweep.py` then `python3 tools/encounter_bot.py --baseline` from this worktree. Raw room records are in `measurements/composition.jsonl.gz`; `composition.json` and `baseline.json` contain summaries. The nine `bot-t*-*.json` files retain every outcome, seed, room coordinate and entrance, plus deck ids and policy defaults. Per-process logs retain exact runner commands. Replay a recorded room with `python3 tools/encounter_bot.py --seed SEED --tier TIER --objective OBJECTIVE --coord=X,Y --runs 1 --output-dir /private/tmp/spx-01-replay`.

Verification results, exact commands and the import-timeout note are in [the proof manifest](measurements/proof.json). Windowed captures and an inspection fixture are not applicable to this measurement-only unit.

## Sampling and definitions

For each seed, generate all six real sections. For each tier/biome choose one actual standard combat node at index `seed % candidate_count` in generation order, and use its first incoming map edge. A missing tier is skipped and that bin continues with later seeds until it has 2,000 distinct seeds. An earlier combat is marked cleared in the isolated measurement input to avoid the onboarding objective override; encounter history is empty. The layout is produced by RunEngine, including equipment drops. Biomes follow the section's actual boss, including shuffled elemental section order. No objective is forced. Bot groups scan these samples in ascending seed and production section order, retaining the first 200 matching rooms; biome counts are in baseline.json.

Turns count hero activations, starting at 1, with lethal enemy phases attributed to the preceding hero turn. HP lost is cumulative actual HP damage (the production damage_received counter); net HP loss is also retained. Kills and HP removed use the production enemies_killed and damage_dealt counters, excluding objective-cleared followers and including summoned units killed inside a single transition. First death is the first committed card/move/phase transition that increases enemies_killed; null means none. One-turn escape share uses all Reach Exit runs as denominator, counting victories on activation 1. P10/P90 use nearest rank; medians average the middle pair. Turn-capped runs count as losses and retain their cap flag.

## Combat baseline

| Tier | Objective | N | Win rate | Turns median (P10–P90) | HP lost median (P10–P90) | One-turn escapes |
|---|---|---:|---:|---:|---:|---:|
| 1 | kill_all | 200 | 12.5% | 3 (2–6) | 24 (19–24) | — |
| 1 | kill_leader | 200 | 20.0% | 3 (2–6) | 24 (9–24) | — |
| 1 | reach_exit | 200 | 39.5% | 3 (2–4) | 24 (0–24) | 4.5% |
| 2 | kill_all | 200 | 3.5% | 3 (2–5) | 24 (24–24) | — |
| 2 | kill_leader | 200 | 9.0% | 3 (2–5) | 24 (24–24) | — |
| 2 | reach_exit | 200 | 23.5% | 3 (2–4) | 24 (7–24) | 1.0% |
| 3 | kill_all | 200 | 0.0% | 3 (2–5) | 24 (24–24) | — |
| 3 | kill_leader | 200 | 1.5% | 3 (2–5) | 24 (24–24) | — |
| 3 | reach_exit | 200 | 19.0% | 2.5 (2–4) | 24 (10–24) | 3.5% |

## Chosen defaults

These affect measurement only. Tier 1 uses GameData.starting_deck(), default equipment, no relics, 24 HP. Tier 2 appends three common reward rolls; tier 3 appends those commons and two rares. Rewards come from the actual coordinate-based reward offer stream on the fixed seed below (coordinates `(roll + 1, 0)`, with each room’s natural element); accepted duplicates are retained. No skills, consumables, omens or Defiance; no Empower. All ties use explicit generation order. Non-exit movement shortlists prioritize distance to a living enemy; exit shortlists prioritize exit distance closed. Optional free moves happen before a card; movement-only choices support exits. Multiaction cards use sequential engine resolution with bounded target branches. Search first ranks candidates by HP removed + 5 per kill + leader damage + unblocked exit distance closed; it evaluates the exact revealed-intent preview penalty for the best bounded shortlist. That preview respects card Time, the end tile and defenses. The bot chooses the highest positive score, otherwise passes. Equal scores retain the first option. Search limits deliberately constrain the policy and must be held fixed for future comparisons.

```json
{
  "deck_reward_seed": 2102026,
  "defiance": 0,
  "empower": false,
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
  "relics": [],
  "reward_roll_limit": 10000,
  "skills": []
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

The sweep starts at seed 1 and accepts 2,000 seeds per tier/biome. Golden seeds are 1, 19 and 421. Baselines start at seed 1; the Python driver uses six concurrent isolated Godot processes. The offline measurement timeout is 7,200 seconds per process; ordinary tests retain the project caps.

## Composition sweep

Values are median (nearest-rank P10–P90). Base HP sums enemy-definition max_hp before scaling; spawn HP sums generated max_hp including leader bonuses. Roles use ai_profile.role, with missing roles labelled unspecified. Leader distance is Manhattan distance from the entry to the enemy spawn anchor; ties count as closest. Exit paths retain grid walls/pillars and ignore actors, destructible terrain, traps and surfaces. Free turns = ceil(path / 2).

| Tier | Biome | Objective | N | Units | Base HP | Spawn HP | Leader distance | Closest | Exit path | Free turns |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | air | kill_all | 1004 | 3 (3–4) | 36 (34–42) | 39 (33–44) | — | — | — | — |
| 1 | air | kill_leader | 472 | 3 (3–4) | 38 (34–41) | 46 (39–52) | 4 (3–6) | 43.6% | — | — |
| 1 | air | reach_exit | 524 | 4 (4–5) | 50 (48–56) | 53 (44–60) | — | — | 6 (6–8) | 3 (3–4) |
| 1 | earth | kill_all | 1012 | 3 (3–4) | 36 (34–38) | 38 (32–44) | — | — | — | — |
| 1 | earth | kill_leader | 495 | 3 (3–4) | 36 (34–38) | 45 (38–51) | 4 (3–6) | 42.8% | — | — |
| 1 | earth | reach_exit | 493 | 4 (4–5) | 50 (48–52) | 52 (44–59) | — | — | 6 (6–8) | 3 (3–4) |
| 1 | fire | kill_all | 957 | 3 (3–4) | 36 (34–46) | 39 (33–48) | — | — | — | — |
| 1 | fire | kill_leader | 468 | 3 (3–4) | 36 (34–42) | 46 (39–57) | 5 (3–7) | 43.2% | — | — |
| 1 | fire | reach_exit | 575 | 4 (4–5) | 50 (48–56) | 53 (45–64) | — | — | 6 (6–8) | 3 (3–4) |
| 1 | ice | kill_all | 987 | 3 (3–4) | 36 (34–43) | 39 (32–48) | — | — | — | — |
| 1 | ice | kill_leader | 494 | 3 (3–4) | 36 (34–43) | 46 (38–57) | 4 (3–6) | 43.7% | — | — |
| 1 | ice | reach_exit | 519 | 4 (4–5) | 50 (48–57) | 53 (45–61) | — | — | 6 (6–8) | 3 (3–4) |
| 1 | lightning | kill_all | 1000 | 3 (3–4) | 38 (34–52) | 42 (33–52) | — | — | — | — |
| 1 | lightning | kill_leader | 513 | 3 (3–4) | 38 (35–50) | 50 (39–62) | 4 (3–7) | 40.7% | — | — |
| 1 | lightning | reach_exit | 487 | 4 (4–5) | 52 (48–64) | 56 (45–67) | — | — | 6 (6–8) | 3 (3–4) |
| 1 | shadow | kill_all | 986 | 3 (3–4) | 36 (34–40) | 46 (43–52) | — | — | — | — |
| 1 | shadow | kill_leader | 532 | 3 (3–4) | 36 (34–40) | 55 (52–61) | 4 (3–6) | 44.2% | — | — |
| 1 | shadow | reach_exit | 482 | 4 (4–5) | 50 (48–54) | 63.5 (60–69) | — | — | 6 (6–8) | 3 (3–4) |
| 2 | air | kill_all | 1061 | 4 (4–5) | 50 (46–60) | 63 (51–73) | — | — | — | — |
| 2 | air | kill_leader | 445 | 4 (4–5) | 50 (46–57) | 71 (57–84) | 5 (3–7) | 31.7% | — | — |
| 2 | air | reach_exit | 494 | 6 (6–7) | 80 (74–88) | 95 (78–111) | — | — | 6 (6–8) | 3 (3–4) |
| 2 | earth | kill_all | 988 | 4 (4–5) | 50 (48–56) | 60 (50–71) | — | — | — | — |
| 2 | earth | kill_leader | 495 | 4 (4–5) | 50 (48–56) | 70 (57–82) | 5 (3–7) | 34.7% | — | — |
| 2 | earth | reach_exit | 517 | 6 (6–7) | 78 (72–86) | 94 (78–109) | — | — | 6 (6–8) | 3 (3–4) |
| 2 | fire | kill_all | 1013 | 5 (4–6) | 50 (46–60) | 61 (50–73) | — | — | — | — |
| 2 | fire | kill_leader | 485 | 5 (4–5) | 50 (46–60) | 70 (57–85) | 4 (3–7) | 34.0% | — | — |
| 2 | fire | reach_exit | 502 | 7 (6–8) | 80 (72–92) | 97 (80–113) | — | — | 6 (6–8) | 3 (3–4) |
| 2 | ice | kill_all | 1009 | 4 (4–5) | 50 (47–63) | 62 (51–76) | — | — | — | — |
| 2 | ice | kill_leader | 488 | 4 (4–5) | 50 (48–61) | 71 (59–88) | 4 (3–7) | 35.9% | — | — |
| 2 | ice | reach_exit | 503 | 6 (6–7) | 80 (72–89) | 95 (80–111) | — | — | 6 (6–8) | 3 (3–4) |
| 2 | lightning | kill_all | 987 | 5 (4–5) | 56 (47–66) | 64 (53–83) | — | — | — | — |
| 2 | lightning | kill_leader | 505 | 5 (4–5) | 56 (48–64) | 73 (61–96) | 5 (3–7) | 29.5% | — | — |
| 2 | lightning | reach_exit | 508 | 7 (6–7) | 82 (73–94) | 99 (82–120) | — | — | 6 (6–8) | 3 (3–4) |
| 2 | shadow | kill_all | 974 | 4 (4–6) | 50 (47–57) | 71 (67–82) | — | — | — | — |
| 2 | shadow | kill_leader | 525 | 4 (4–5) | 50 (47–57) | 81 (77–95) | 5 (3–7) | 36.2% | — | — |
| 2 | shadow | reach_exit | 501 | 6 (6–8) | 78 (72–85) | 111 (102–122) | — | — | 6 (6–8) | 3 (3–4) |
| 3 | air | kill_all | 990 | 5 (5–6) | 66 (58–74) | 93 (77–107) | — | — | — | — |
| 3 | air | kill_leader | 511 | 5 (5–6) | 66 (58–74) | 105 (88–121) | 5 (3–7) | 30.3% | — | — |
| 3 | air | reach_exit | 499 | 7 (7–8) | 94 (84–102) | 130 (108–151) | — | — | 6 (6–8) | 3 (3–4) |
| 3 | earth | kill_all | 1012 | 5 (4–6) | 66 (56–74) | 89 (73–107) | — | — | — | — |
| 3 | earth | kill_leader | 465 | 5 (4–6) | 66 (54–72) | 103 (85–121) | 5 (3–7) | 28.6% | — | — |
| 3 | earth | reach_exit | 523 | 7 (6–8) | 92 (82–102) | 126 (106–148) | — | — | 6 (6–8) | 3 (3–4) |
| 3 | fire | kill_all | 1020 | 6 (5–7) | 66 (54–76) | 92 (77–109) | — | — | — | — |
| 3 | fire | kill_leader | 492 | 6 (5–7) | 66 (54–78) | 106 (88–122) | 5 (3–7) | 26.6% | — | — |
| 3 | fire | reach_exit | 488 | 8 (7–9) | 94 (84–104) | 130 (107–151) | — | — | 6 (6–8) | 3 (3–4) |
| 3 | ice | kill_all | 994 | 5 (5–6) | 67 (57–79) | 93 (76–111) | — | — | — | — |
| 3 | ice | kill_leader | 504 | 5 (5–6) | 67 (57–74) | 107 (87–124) | 5 (3–7) | 27.8% | — | — |
| 3 | ice | reach_exit | 502 | 7 (7–8) | 94 (84–105) | 130 (107–154) | — | — | 6 (6–8) | 3 (3–4) |
| 3 | lightning | kill_all | 981 | 6 (5–6) | 70 (62–84) | 98 (79–118) | — | — | — | — |
| 3 | lightning | kill_leader | 497 | 6 (5–6) | 69 (62–84) | 110 (88–131) | 5 (3–7) | 30.2% | — | — |
| 3 | lightning | reach_exit | 522 | 8 (7–8) | 98 (90–110) | 134.5 (113–160) | — | — | 6 (6–8) | 3 (3–4) |
| 3 | shadow | kill_all | 995 | 5 (5–7) | 66 (54–74) | 110 (91–123) | — | — | — | — |
| 3 | shadow | kill_leader | 519 | 5 (5–6) | 66 (53–74) | 125 (105–138) | 5 (3–7) | 29.3% | — | — |
| 3 | shadow | reach_exit | 486 | 7 (7–9) | 92 (81–100) | 153 (135–166) | — | — | 6 (6–8) | 3 (3–4) |

Role mix is a share of all units in the group. Leader types are room counts.

| Tier | Biome | Objective | Role mix | Leader types |
|---|---|---|---|---|
| 1 | air | kill_all | artillery 6.5%, controller 9.7%, frontliner 35.0%, protector 2.4%, skirmisher 44.1%, support 2.3% | — |
| 1 | air | kill_leader | artillery 6.0%, controller 9.4%, frontliner 36.1%, protector 2.3%, skirmisher 44.3%, support 2.0% | bile_bloomer: 25, chainbound_gaoler: 35, cinder_ooze: 2, crawler: 280, frostglass_lancer: 9, gale_herald: 76, harrier: 10, warden: 35 |
| 1 | air | reach_exit | artillery 5.5%, controller 29.0%, frontliner 29.0%, protector 2.3%, skirmisher 32.0%, support 2.1% | — |
| 1 | earth | kill_all | artillery 6.2%, controller 6.4%, frontliner 37.8%, protector 2.4%, skirmisher 44.6%, support 2.6% | — |
| 1 | earth | kill_leader | artillery 7.5%, controller 6.2%, frontliner 37.7%, protector 2.1%, skirmisher 44.0%, support 2.5% | bile_bloomer: 30, briar_weaver: 42, burrow_grub: 11, chainbound_gaoler: 35, cinder_ooze: 7, crawler: 329, frostglass_lancer: 7, harrier: 1, warden: 33 |
| 1 | earth | reach_exit | artillery 5.4%, controller 26.7%, frontliner 29.5%, protector 2.3%, skirmisher 34.6%, support 1.4% | — |
| 1 | fire | kill_all | artillery 9.9%, controller 2.2%, frontliner 50.4%, protector 1.9%, skirmisher 33.3%, support 2.3% | — |
| 1 | fire | kill_leader | artillery 10.0%, controller 1.7%, frontliner 52.0%, protector 2.0%, skirmisher 32.3%, support 2.0% | bile_bloomer: 29, chainbound_gaoler: 22, cinder_ooze: 8, crawler: 309, frostglass_lancer: 16, harrier: 8, slag_mortar: 44, warden: 32 |
| 1 | fire | reach_exit | artillery 7.8%, controller 22.2%, frontliner 40.7%, protector 2.1%, skirmisher 25.9%, support 1.4% | — |
| 1 | ice | kill_all | artillery 12.2%, controller 11.0%, frontliner 33.7%, protector 5.9%, skirmisher 35.4%, support 1.8% | — |
| 1 | ice | kill_leader | artillery 12.4%, controller 8.4%, frontliner 36.1%, protector 5.7%, skirmisher 35.3%, support 2.1% | bile_bloomer: 35, chainbound_gaoler: 26, cinder_ooze: 15, crawler: 329, frostglass_lancer: 5, glacial_mirror: 57, harrier: 1, hoarfrost_seer: 6, warden: 20 |
| 1 | ice | reach_exit | artillery 9.7%, controller 29.6%, frontliner 26.6%, protector 4.5%, skirmisher 28.2%, support 1.4% | — |
| 1 | lightning | kill_all | artillery 10.2%, controller 4.4%, frontliner 28.1%, protector 2.1%, skirmisher 53.3%, support 2.0% | — |
| 1 | lightning | kill_leader | artillery 9.2%, controller 3.8%, frontliner 28.6%, protector 1.5%, skirmisher 54.8%, support 2.1% | arc_thrall: 10, bile_bloomer: 23, chainbound_gaoler: 30, cinder_ooze: 14, crawler: 325, frostglass_lancer: 6, harrier: 5, storm_capacitor: 81, warden: 19 |
| 1 | lightning | reach_exit | artillery 9.1%, controller 24.2%, frontliner 22.9%, protector 1.9%, skirmisher 40.3%, support 1.6% | — |
| 1 | shadow | kill_all | artillery 5.9%, controller 2.0%, frontliner 39.2%, protector 2.5%, skirmisher 48.0%, support 2.3% | — |
| 1 | shadow | kill_leader | artillery 6.2%, controller 2.1%, frontliner 38.9%, protector 1.7%, skirmisher 48.7%, support 2.3% | bile_bloomer: 36, chainbound_gaoler: 37, cinder_ooze: 11, crawler: 340, frostglass_lancer: 12, gloam_stalker: 11, harrier: 1, hollow_mimic: 54, warden: 30 |
| 1 | shadow | reach_exit | artillery 6.1%, controller 23.1%, frontliner 30.8%, protector 1.6%, skirmisher 36.9%, support 1.6% | — |
| 2 | air | kill_all | artillery 12.7%, controller 9.0%, frontliner 32.3%, protector 7.0%, skirmisher 33.9%, support 5.1% | — |
| 2 | air | kill_leader | artillery 13.8%, controller 9.6%, frontliner 31.6%, protector 6.5%, skirmisher 32.5%, support 5.9% | bile_bloomer: 41, chainbound_gaoler: 31, crawler: 165, gale_herald: 80, warden: 128 |
| 2 | air | reach_exit | artillery 12.3%, controller 20.8%, frontliner 27.3%, protector 8.7%, skirmisher 27.6%, support 3.3% | — |
| 2 | earth | kill_all | artillery 13.3%, controller 5.7%, frontliner 33.9%, protector 6.8%, skirmisher 34.8%, support 5.5% | — |
| 2 | earth | kill_leader | artillery 13.6%, controller 5.4%, frontliner 33.1%, protector 6.5%, skirmisher 36.2%, support 5.2% | bile_bloomer: 43, briar_weaver: 42, chainbound_gaoler: 39, crawler: 233, warden: 138 |
| 2 | earth | reach_exit | artillery 13.1%, controller 18.7%, frontliner 27.9%, protector 10.0%, skirmisher 26.5%, support 3.7% | — |
| 2 | fire | kill_all | artillery 15.4%, controller 2.3%, frontliner 46.0%, protector 6.3%, skirmisher 24.5%, support 5.5% | — |
| 2 | fire | kill_leader | artillery 15.1%, controller 1.7%, frontliner 46.3%, protector 6.7%, skirmisher 25.0%, support 5.1% | bile_bloomer: 43, chainbound_gaoler: 31, crawler: 217, slag_mortar: 70, warden: 124 |
| 2 | fire | reach_exit | artillery 14.2%, controller 15.2%, frontliner 36.5%, protector 8.8%, skirmisher 22.1%, support 3.3% | — |
| 2 | ice | kill_all | artillery 18.2%, controller 8.0%, frontliner 30.7%, protector 11.4%, skirmisher 26.4%, support 5.3% | — |
| 2 | ice | kill_leader | artillery 18.4%, controller 9.5%, frontliner 29.6%, protector 10.6%, skirmisher 27.2%, support 4.7% | bile_bloomer: 58, chainbound_gaoler: 40, crawler: 203, glacial_mirror: 76, warden: 111 |
| 2 | ice | reach_exit | artillery 16.2%, controller 21.1%, frontliner 25.2%, protector 11.4%, skirmisher 22.3%, support 3.7% | — |
| 2 | lightning | kill_all | artillery 16.3%, controller 3.9%, frontliner 25.1%, protector 6.6%, skirmisher 42.8%, support 5.3% | — |
| 2 | lightning | kill_leader | artillery 15.7%, controller 3.9%, frontliner 25.4%, protector 7.1%, skirmisher 43.3%, support 4.6% | bile_bloomer: 47, chainbound_gaoler: 32, crawler: 214, storm_capacitor: 83, warden: 129 |
| 2 | lightning | reach_exit | artillery 14.5%, controller 16.6%, frontliner 21.3%, protector 9.1%, skirmisher 35.1%, support 3.3% | — |
| 2 | shadow | kill_all | artillery 11.8%, controller 2.3%, frontliner 35.4%, protector 7.0%, skirmisher 38.5%, support 4.9% | — |
| 2 | shadow | kill_leader | artillery 11.9%, controller 2.5%, frontliner 35.2%, protector 7.2%, skirmisher 38.0%, support 5.3% | bile_bloomer: 38, chainbound_gaoler: 41, crawler: 235, hollow_mimic: 42, warden: 169 |
| 2 | shadow | reach_exit | artillery 14.0%, controller 15.7%, frontliner 28.0%, protector 8.3%, skirmisher 30.3%, support 3.7% | — |
| 3 | air | kill_all | artillery 17.4%, controller 11.2%, frontliner 24.1%, protector 20.5%, skirmisher 23.9%, support 3.0% | — |
| 3 | air | kill_leader | artillery 17.2%, controller 11.2%, frontliner 24.0%, protector 20.5%, skirmisher 24.8%, support 2.3% | warden: 511 |
| 3 | air | reach_exit | artillery 16.1%, controller 20.1%, frontliner 21.2%, protector 18.7%, skirmisher 21.9%, support 2.1% | — |
| 3 | earth | kill_all | artillery 18.3%, controller 7.8%, frontliner 23.4%, protector 21.7%, skirmisher 25.7%, support 3.2% | — |
| 3 | earth | kill_leader | artillery 18.5%, controller 6.8%, frontliner 24.3%, protector 21.1%, skirmisher 25.5%, support 3.8% | warden: 465 |
| 3 | earth | reach_exit | artillery 17.8%, controller 17.8%, frontliner 21.9%, protector 19.6%, skirmisher 20.9%, support 2.0% | — |
| 3 | fire | kill_all | artillery 19.9%, controller 2.5%, frontliner 40.9%, protector 18.8%, skirmisher 14.9%, support 3.0% | — |
| 3 | fire | kill_leader | artillery 20.4%, controller 2.6%, frontliner 40.7%, protector 18.6%, skirmisher 15.1%, support 2.6% | lightning_wisp: 3, slag_mortar: 104, warden: 385 |
| 3 | fire | reach_exit | artillery 18.6%, controller 13.3%, frontliner 34.0%, protector 18.1%, skirmisher 14.0%, support 2.0% | — |
| 3 | ice | kill_all | artillery 23.8%, controller 11.6%, frontliner 21.7%, protector 24.7%, skirmisher 15.2%, support 3.0% | — |
| 3 | ice | kill_leader | artillery 23.6%, controller 11.9%, frontliner 22.1%, protector 24.0%, skirmisher 15.6%, support 2.8% | glacial_mirror: 85, warden: 419 |
| 3 | ice | reach_exit | artillery 20.6%, controller 20.8%, frontliner 19.9%, protector 21.9%, skirmisher 14.5%, support 2.2% | — |
| 3 | lightning | kill_all | artillery 20.9%, controller 5.4%, frontliner 15.9%, protector 19.1%, skirmisher 36.3%, support 2.6% | — |
| 3 | lightning | kill_leader | artillery 21.0%, controller 5.0%, frontliner 15.8%, protector 19.0%, skirmisher 37.0%, support 2.3% | storm_capacitor: 119, warden: 378 |
| 3 | lightning | reach_exit | artillery 19.8%, controller 15.4%, frontliner 16.0%, protector 17.2%, skirmisher 29.5%, support 2.1% | — |
| 3 | shadow | kill_all | artillery 17.7%, controller 3.4%, frontliner 27.2%, protector 19.7%, skirmisher 29.0%, support 3.0% | — |
| 3 | shadow | kill_leader | artillery 17.0%, controller 2.5%, frontliner 26.4%, protector 20.1%, skirmisher 30.9%, support 3.0% | lightning_wisp: 4, warden: 515 |
| 3 | shadow | reach_exit | artillery 16.7%, controller 13.8%, frontliner 23.7%, protector 17.7%, skirmisher 26.3%, support 1.9% | — |
