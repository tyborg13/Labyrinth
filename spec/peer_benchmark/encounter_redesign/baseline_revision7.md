# Encounter measurement baseline — revision 7 (meas-02)

Integration HEAD `d96eadf4f3d3b98085b444bc28b5d456b8716163`; map revision 7; policy v2, `policy_sha256=c90b92005d67d7ea0137e7c35a508bdc8b10d1eee34d70bf7fa4a5d434aa5d82`. 200 runs per standard/Warband/Guardian tier, 50 per dragon (2,100 total), first seed 1, 6 workers. The policy file, search limits, deck presets, gameplay and balance are unchanged. Revision-6 evidence and baseline.md remain unchanged.

Values are median (nearest-rank P10–P90), including losses and capped runs. Turns count hero activations; HP lost is cumulative production damage_received, including damage later healed. A turn cap is a loss. Dragon rooms retain their natural depth band 4 and use the requested tier-3 deck; tier 3 below denotes that deck comparison, not a change to their room tier.

| Tier / deck | Cohort | Dragon | Objective | N | Win rate | Turns median (P10–P90) | HP lost median (P10–P90) | Turn caps |
|---|---|---|---|---:|---:|---:|---:|---:|
| 1 | standard | — | kill_all | 200 | 63.5% | 5 (3–8) | 15 (0–26) | 3 |
| 1 | warband | — | kill_leader | 200 | 81.0% | 7 (4–13) | 9 (0–24) | 12 |
| 2 | standard | — | kill_all | 200 | 43.0% | 5 (3–10) | 24 (7–26) | 6 |
| 2 | warband | — | kill_leader | 200 | 68.5% | 8 (4–17) | 12 (0–25) | 10 |
| 3 | standard | — | kill_all | 200 | 30.5% | 6 (3–12) | 24 (12–26) | 3 |
| 3 | warband | — | kill_leader | 200 | 43.5% | 8 (3–21) | 24 (7–26) | 13 |
| 1 | guardian | — | kill_leader | 200 | 46.5% | 4 (2–7) | 24 (3–24) | 0 |
| 2 | guardian | — | kill_leader | 200 | 49.0% | 5 (3–8) | 24 (3–26) | 1 |
| 3 | guardian | — | kill_leader | 200 | 47.5% | 5 (2–8) | 24 (4–24) | 0 |
| 3 | boss | tharokh | kill_leader | 50 | 74.0% | 8 (6–10) | 16.5 (5–24) | 0 |
| 3 | boss | vyraketh | kill_leader | 50 | 36.0% | 5 (4–8) | 24 (15–24) | 0 |
| 3 | boss | vaeloryx | kill_leader | 50 | 50.0% | 7 (5–9) | 24 (10–25) | 0 |
| 3 | boss | iskaldra | kill_leader | 50 | 50.0% | 6.5 (5–9) | 24 (11–26) | 0 |
| 3 | boss | zekarion | kill_leader | 50 | 14.0% | 3 (2–7) | 24 (18–24) | 0 |
| 3 | boss | noctyrax | kill_leader | 50 | 0.0% | 5 (3–7) | 24 (24–24) | 0 |

Tier 1, Warband / standard / Guardian: 81.0% / 63.5% / 46.5% wins, 7 / 5 / 4 median turns, 9 / 15 / 24 median HP lost. Tier 2, Warband / standard / Guardian: 68.5% / 43.0% / 49.0% wins, 8 / 5 / 5 median turns, 12 / 24 / 24 median HP lost. Tier 3, Warband / standard / Guardian: 43.5% / 30.5% / 47.5% wins, 8 / 6 / 5 median turns, 24 / 24 / 24 median HP lost. With the same tier-3 deck, the six dragons together have 37.3% wins, 6 median turns and 24 median HP lost.

For each seed the sweep generates all six production sections and selects one actual room per cohort/tier/biome at `seed % candidate_count` in generation order, using its first incoming map edge. Standard selects combat nodes, Warband selects special/warband nodes, Guardian selects guardian nodes, and boss selects each section’s dragon node. Guardian tiers are their rooms’ own depth bands (1–3). Objectives and rosters come from RunEngine unchanged. The bot takes the first matching rooms in ascending seed and production section order; each dragon is filtered by its own boss_id. An earlier combat is marked cleared only in the isolated measurement input to bypass onboarding; encounter history is empty. Ordinary combat and Warband are remeasured with spx-07 spread spawns and locked wind. The existing revealed-intent preview and committed engine transitions handle Guardian/dragon mechanics without an added policy hook.

The composition sweep accepts 200 distinct seeds per cohort/tier/biome (12,000 rooms). The complete composition table and role mix are in [measurements/revision7/composition.md](measurements/revision7/composition.md). The Guardian and boss rows follow. Spawn HP sums generated max_hp; leader distance is Manhattan distance from entry to the leader spawn anchor, with ties counted as closest.

| Tier / deck | Biome | Cohort / objective | N | Units | Spawn HP | Leader distance | Closest |
|---|---|---|---:|---:|---:|---:|---:|
| 1 | air | guardian / kill_leader | 200 | 3 (3–3) | 50.5 (46–55) | 4 (4–4) | 100.0% |
| 1 | earth | guardian / kill_leader | 200 | 3 (3–3) | 59 (56–67) | 4 (4–4) | 100.0% |
| 1 | fire | guardian / kill_leader | 200 | 3 (3–3) | 57 (49–59) | 4 (4–4) | 100.0% |
| 1 | ice | guardian / kill_leader | 200 | 3 (3–3) | 52 (49–59) | 4 (4–4) | 100.0% |
| 1 | lightning | guardian / kill_leader | 200 | 3 (3–3) | 54 (49–59) | 4 (4–4) | 100.0% |
| 1 | shadow | guardian / kill_leader | 200 | 2 (2–2) | 60 (60–60) | 4 (4–4) | 100.0% |
| 2 | air | guardian / kill_leader | 200 | 3 (3–3) | 54 (46–62) | 4 (4–4) | 100.0% |
| 2 | earth | guardian / kill_leader | 200 | 3 (3–3) | 66 (56–75) | 4 (4–4) | 100.0% |
| 2 | fire | guardian / kill_leader | 200 | 3 (3–3) | 59 (50–67) | 4 (4–4) | 100.0% |
| 2 | ice | guardian / kill_leader | 200 | 3 (3–3) | 58 (49–66) | 4 (4–4) | 100.0% |
| 2 | lightning | guardian / kill_leader | 200 | 3 (3–3) | 58 (49–66) | 4 (4–4) | 100.0% |
| 2 | shadow | guardian / kill_leader | 200 | 2 (2–2) | 68 (68–68) | 4 (4–4) | 100.0% |
| 3 | air | boss / kill_leader | 200 | 1 (1–1) | 68 (58–77) | 4 (4–4) | 100.0% |
| 3 | air | guardian / kill_leader | 200 | 3 (3–3) | 62 (53–71) | 4 (4–4) | 100.0% |
| 3 | earth | boss / kill_leader | 200 | 1 (1–1) | 75 (64–85) | 4 (4–4) | 100.0% |
| 3 | earth | guardian / kill_leader | 200 | 3 (3–3) | 76 (64–86) | 4 (4–4) | 100.0% |
| 3 | fire | boss / kill_leader | 200 | 1 (1–1) | 70 (60–80) | 4 (4–4) | 100.0% |
| 3 | fire | guardian / kill_leader | 200 | 3 (3–3) | 69.5 (57–76) | 4 (4–4) | 100.0% |
| 3 | ice | boss / kill_leader | 200 | 1 (1–1) | 72 (62–82) | 4 (4–4) | 100.0% |
| 3 | ice | guardian / kill_leader | 200 | 3 (3–3) | 66 (56–75) | 4 (4–4) | 100.0% |
| 3 | lightning | boss / kill_leader | 200 | 3 (3–3) | 84 (72–96) | 4 (4–4) | 0.0% |
| 3 | lightning | guardian / kill_leader | 200 | 3 (3–3) | 66 (56–75) | 4 (4–4) | 100.0% |
| 3 | shadow | boss / kill_leader | 200 | 3 (3–3) | 113 (113–113) | 4 (4–4) | 0.0% |
| 3 | shadow | guardian / kill_leader | 200 | 2 (2–2) | 77 (77–77) | 4 (4–4) | 100.0% |

Raw gzipped bot records, composition JSONL and summary JSON are in [measurements/revision7/](measurements/revision7/); baseline.json records hashes for the unchanged policy and measurement drivers. All summaries can be recomputed from those records. Per-run records retain room coordinate, entrance, biome, section, objective and identity for replay.

Reproduce from this worktree:

```bash
cd <task-worktree> && python3 tools/encounter_sweep.py --revision 7 --seeds 200 --first-seed 1
cd <task-worktree> && python3 tools/encounter_bot.py --baseline --revision 7 --runs 200 --boss-runs 50 --seed 1 --workers 6
cd <task-worktree> && python3 tools/encounter_bot.py --baseline --revision 7 --report-only
```

Replay a recorded room using `cd <task-worktree> && python3 tools/encounter_bot.py --revision 7 --cohort COHORT --tier TIER --seed SEED --coord=X,Y --runs 1 --output-dir /private/tmp/meas-02-replay`; for a dragon also pass `--boss-id DRAGON --tier 3`. All engine launches use godot_task_runner.py with task id meas-02. No windowed proof or inspection fixture applies: this unit changes offline measurement tools and reports only.

Measurement defaults remain the existing policy-v2 defaults: 24 HP, starting equipment, no relics, skills, consumables, omens, Defiance or Empower. Tier 1 uses the starting deck; tier 2 adds the same three common reward rolls, tier 3 the same two rares. The full unchanged defaults and deck presets are retained in every raw bot file. Seed scans remain capped at 100,000; process timeout remains 7,200 seconds. Newly selected measurement-only values are `TASK_ID="meas-02"`, `--seeds 200` for composition and the separate measurement-driver filename. Test fixtures retain SMALL_SWEEP_MAX_SEED=100 and the existing policy arena.

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
