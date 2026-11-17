# Four difficulty tiers by section — 2026-11-16

Measured HEAD `d4c918afc0a34bb969ca9cab3d3e262794354cbc`. No tuning, game code, data or test changes. Policy SHA-256 `c90b92005d67d7ea0137e7c35a508bdc8b10d1eee34d70bf7fa4a5d434aa5d82`.

Fresh fights: **1170 raw**, **1170 in complete native-room blocks**. Total measurement wall time **5956.5 seconds (99.28 minutes)**; at most **4 engine workers**. Selected sections: [0, 2, 4]. Target N=64 for each selected section × difficulty tier; normal rooms additionally target N=64 at each native depth band. Non-priority sections retain only the one-loadout/one-repeat pilot (N=1 per non-normal tier, N=3 pooled normals), which is diagnostic rather than a section estimate. Per-kind objective sample sizes are below.

**9/9 priority-section tier comparisons fall outside their director bands at the point estimate.** The tables retain uncertainty, per-kind sample sizes and depth-matched baselines; these are relative bot results, not human win probabilities.

## A. Win rates and director bands

Normal = current Kill All combat rooms. Objective = every enabled special kind (Warband, Umbral Snare, Last Light, Ember Hoarder), pooled for the section target; per-kind results are retained. Guardian and dragon identities are native to each seeded map. Local depth band t1–t3 is distinct from these four difficulty tiers; dragons occupy local step 4 and are matched to clamped t3, as in meas-07. No tier is transplanted between sections.

Each non-normal fight is paired with the first normal room at the same section, clamped depth band, ladder seed and combat-repeat index. The s3/seed7 map has no normal t2 room (including hidden mysteries); if collected, its t2 objective outcomes are retained but have no matched control and are excluded only from gap calculations. No room is fabricated. The normal comparator is reweighted to exactly that target cohort’s depth/loadout mix. Thus the comparator in the gap table can differ between objective, Guardian and dragon rows, and from the equally depth-weighted pooled normal row. Shared controls are reused rather than presented as independent extra fights. Gap = target win rate − matched normal win rate, in percentage points. Outside-band distance is zero inside the inclusive band, otherwise the positive distance to its nearest edge. These distances describe point estimates, not statistically established band violations. Objective band [−15,−5]; Guardian [−25,−15]; dragon [−35,−25].

| Section | Tier | Wins/N | Win rate [95% Wilson] | Median turns | Median gross Health lost |
|---|---|---|---|---|---|
| s0 | normal | 164/192 | 85.4% [79.7, 89.7] | 7 | 7 |
| s0 | objective | 57/64 | 89.1% [79.1, 94.6] | 4 | 5 |
| s0 | guardian | 64/64 | 100.0% [94.3, 100.0] | 6 | 9.5 |
| s0 | boss | 50/64 | 78.1% [66.6, 86.5] | 7 | 16 |
| s1 | normal | 1/3 | 33.3% [6.1, 79.2] | 8 | 24 |
| s1 | objective | 1/1 | 100.0% [20.7, 100.0] | 4 | 4 |
| s1 | guardian | 1/1 | 100.0% [20.7, 100.0] | 4 | 14 |
| s1 | boss | 0/1 | 0.0% [0.0, 79.3] | 15 | 26 |
| s2 | normal | 118/192 | 61.5% [54.4, 68.1] | 5 | 17.5 |
| s2 | objective | 51/64 | 79.7% [68.3, 87.7] | 4 | 8 |
| s2 | guardian | 51/64 | 79.7% [68.3, 87.7] | 6.5 | 15 |
| s2 | boss | 26/64 | 40.6% [29.5, 52.9] | 5 | 24 |
| s3 | normal | 1/3 | 33.3% [6.1, 79.2] | 3 | 24 |
| s3 | objective | 0/1 | 0.0% [0.0, 79.3] | 4 | 26 |
| s3 | guardian | 0/1 | 0.0% [0.0, 79.3] | 4 | 24 |
| s3 | boss | 0/1 | 0.0% [0.0, 79.3] | 4 | 24 |
| s4 | normal | 92/192 | 47.9% [41.0, 55.0] | 5 | 21 |
| s4 | objective | 45/64 | 70.3% [58.2, 80.1] | 4 | 15 |
| s4 | guardian | 23/64 | 35.9% [25.3, 48.2] | 4 | 24 |
| s4 | boss | 23/64 | 35.9% [25.3, 48.2] | 4 | 24 |
| s5 | normal | 2/3 | 66.7% [20.8, 93.9] | 6 | 17 |
| s5 | objective | 1/1 | 100.0% [20.7, 100.0] | 4 | 0 |
| s5 | guardian | 1/1 | 100.0% [20.7, 100.0] | 5 | 11 |
| s5 | boss | 1/1 | 100.0% [20.7, 100.0] | 5 | 11 |


| Section | Tier | Paired N | Matched normal win rate | Gap (pp) | Outside band (pp) |
|---|---|---|---|---|---|
| s0 | objective | 64 | 79.7% | +9.4 | 14.4 |
| s0 | guardian | 64 | 84.4% | +15.6 | 30.6 |
| s0 | boss | 64 | 76.6% | +1.6 | 26.6 |
| s1 | objective | 1 | 100.0% | +0.0 | 5.0 |
| s1 | guardian | 1 | 100.0% | +0.0 | 15.0 |
| s1 | boss | 1 | 0.0% | +0.0 | 25.0 |
| s2 | objective | 64 | 46.9% | +32.8 | 37.8 |
| s2 | guardian | 64 | 60.9% | +18.8 | 33.8 |
| s2 | boss | 64 | 31.2% | +9.4 | 34.4 |
| s3 | objective | 1 | 0.0% | +0.0 | 5.0 |
| s3 | guardian | 1 | 0.0% | +0.0 | 15.0 |
| s3 | boss | 1 | 0.0% | +0.0 | 25.0 |
| s4 | objective | 64 | 35.9% | +34.4 | 39.4 |
| s4 | guardian | 64 | 40.6% | -4.7 | 10.3 |
| s4 | boss | 64 | 23.4% | +12.5 | 37.5 |
| s5 | objective | 1 | 100.0% | +0.0 | 5.0 |
| s5 | guardian | 1 | 0.0% | +100.0 | 115.0 |
| s5 | boss | 1 | 0.0% | +100.0 | 125.0 |


### Objective kind and native depth detail

| Section | Objective kind | Wins/N | Win rate [95% Wilson] | Median turns | Median gross Health lost | Paired N | Matched normal | Gap (pp) | Outside band (pp) |
|---|---|---|---|---|---|---|---|---|---|
| s0 | warband | 9/16 | 56.2% [33.2, 76.9] | 12.5 | 6.5 | 16 | 87.5% | -31.2 | 16.2 |
| s0 | umbral_snare | 9/9 | 100.0% [70.1, 100.0] | 2 | 0 | 9 | 77.8% | +22.2 | 27.2 |
| s0 | last_light | 17/17 | 100.0% [81.6, 100.0] | 4 | 6 | 17 | 82.4% | +17.6 | 22.6 |
| s0 | ember_hoarder | 22/22 | 100.0% [85.1, 100.0] | 4 | 5.5 | 22 | 72.7% | +27.3 | 32.3 |
| s1 | warband | 1/1 | 100.0% [20.7, 100.0] | 4 | 4 | 1 | 100.0% | +0.0 | 5.0 |
| s1 | umbral_snare | 0 | — | — | — | 0 | — | — | — |
| s1 | last_light | 0 | — | — | — | 0 | — | — | — |
| s1 | ember_hoarder | 0 | — | — | — | 0 | — | — | — |
| s2 | warband | 11/22 | 50.0% [30.7, 69.3] | 7 | 21 | 22 | 45.5% | +4.5 | 9.5 |
| s2 | umbral_snare | 10/12 | 83.3% [55.2, 95.3] | 2 | 1 | 12 | 58.3% | +25.0 | 30.0 |
| s2 | last_light | 21/21 | 100.0% [84.5, 100.0] | 4 | 6 | 21 | 38.1% | +61.9 | 66.9 |
| s2 | ember_hoarder | 9/9 | 100.0% [70.1, 100.0] | 5 | 11 | 9 | 55.6% | +44.4 | 49.4 |
| s3 | warband | 0 | — | — | — | 0 | — | — | — |
| s3 | umbral_snare | 0 | — | — | — | 0 | — | — | — |
| s3 | last_light | 0 | — | — | — | 0 | — | — | — |
| s3 | ember_hoarder | 0/1 | 0.0% [0.0, 79.3] | 4 | 26 | 1 | 0.0% | +0.0 | 5.0 |
| s4 | warband | 7/15 | 46.7% [24.8, 69.9] | 5 | 20 | 15 | 40.0% | +6.7 | 11.7 |
| s4 | umbral_snare | 9/12 | 75.0% [46.8, 91.1] | 2 | 7.5 | 12 | 58.3% | +16.7 | 21.7 |
| s4 | last_light | 11/17 | 64.7% [41.3, 82.7] | 4 | 14 | 17 | 35.3% | +29.4 | 34.4 |
| s4 | ember_hoarder | 18/20 | 90.0% [69.9, 97.2] | 4 | 13.5 | 20 | 20.0% | +70.0 | 75.0 |
| s5 | warband | 0 | — | — | — | 0 | — | — | — |
| s5 | umbral_snare | 0 | — | — | — | 0 | — | — | — |
| s5 | last_light | 0 | — | — | — | 0 | — | — | — |
| s5 | ember_hoarder | 1/1 | 100.0% [20.7, 100.0] | 4 | 0 | 1 | 100.0% | +0.0 | 5.0 |


| Section | Native depth band | Tier | Wins/N | Win rate [95% Wilson] | Median turns | Median gross Health lost | Paired N | Matched normal | Gap (pp) | Outside band (pp) |
|---|---|---|---|---|---|---|---|---|---|---|
| s0 | t1 | normal | 61/64 | 95.3% [87.1, 98.4] | 4 | 4 | — | baseline | 0.0 | 0.0 |
| s0 | t2 | normal | 54/64 | 84.4% [73.6, 91.3] | 7 | 8 | — | baseline | 0.0 | 0.0 |
| s0 | t2 | objective | 20/26 | 76.9% [57.9, 89.0] | 4 | 6 | 26 | 76.9% | +0.0 | 5.0 |
| s0 | t2 | guardian | 64/64 | 100.0% [94.3, 100.0] | 6 | 9.5 | 64 | 84.4% | +15.6 | 30.6 |
| s0 | t3 | normal | 49/64 | 76.6% [64.9, 85.3] | 10.5 | 10.5 | — | baseline | 0.0 | 0.0 |
| s0 | t3 | objective | 37/38 | 97.4% [86.5, 99.5] | 4 | 4.5 | 38 | 81.6% | +15.8 | 20.8 |
| s0 | t3 | boss | 50/64 | 78.1% [66.6, 86.5] | 7 | 16 | 64 | 76.6% | +1.6 | 26.6 |
| s1 | t1 | normal | 1/1 | 100.0% [20.7, 100.0] | 5 | 18 | — | baseline | 0.0 | 0.0 |
| s1 | t1 | objective | 1/1 | 100.0% [20.7, 100.0] | 4 | 4 | 1 | 100.0% | +0.0 | 5.0 |
| s1 | t1 | guardian | 1/1 | 100.0% [20.7, 100.0] | 4 | 14 | 1 | 100.0% | +0.0 | 15.0 |
| s1 | t2 | normal | 0/1 | 0.0% [0.0, 79.3] | 11 | 26 | — | baseline | 0.0 | 0.0 |
| s1 | t3 | normal | 0/1 | 0.0% [0.0, 79.3] | 8 | 24 | — | baseline | 0.0 | 0.0 |
| s1 | t3 | boss | 0/1 | 0.0% [0.0, 79.3] | 15 | 26 | 1 | 0.0% | +0.0 | 25.0 |
| s2 | t1 | normal | 62/64 | 96.9% [89.3, 99.1] | 4 | 7 | — | baseline | 0.0 | 0.0 |
| s2 | t1 | objective | 4/5 | 80.0% [37.6, 96.4] | 5 | 10 | 5 | 100.0% | -20.0 | 5.0 |
| s2 | t1 | guardian | 15/16 | 93.8% [71.7, 98.9] | 4.5 | 11 | 16 | 100.0% | -6.2 | 8.8 |
| s2 | t2 | normal | 36/64 | 56.2% [44.1, 67.7] | 5 | 22 | — | baseline | 0.0 | 0.0 |
| s2 | t2 | objective | 12/13 | 92.3% [66.7, 98.6] | 4 | 8 | 13 | 69.2% | +23.1 | 28.1 |
| s2 | t2 | guardian | 36/48 | 75.0% [61.2, 85.1] | 7 | 18.5 | 48 | 47.9% | +27.1 | 42.1 |
| s2 | t3 | normal | 20/64 | 31.2% [21.2, 43.4] | 7 | 24 | — | baseline | 0.0 | 0.0 |
| s2 | t3 | objective | 35/46 | 76.1% [62.1, 86.1] | 4 | 8 | 46 | 34.8% | +41.3 | 46.3 |
| s2 | t3 | boss | 26/64 | 40.6% [29.5, 52.9] | 5 | 24 | 64 | 31.2% | +9.4 | 34.4 |
| s3 | t1 | normal | 1/1 | 100.0% [20.7, 100.0] | 13 | 8 | — | baseline | 0.0 | 0.0 |
| s3 | t2 | normal | 0/1 | 0.0% [0.0, 79.3] | 3 | 26 | — | baseline | 0.0 | 0.0 |
| s3 | t2 | objective | 0/1 | 0.0% [0.0, 79.3] | 4 | 26 | 1 | 0.0% | +0.0 | 5.0 |
| s3 | t2 | guardian | 0/1 | 0.0% [0.0, 79.3] | 4 | 24 | 1 | 0.0% | +0.0 | 15.0 |
| s3 | t3 | normal | 0/1 | 0.0% [0.0, 79.3] | 3 | 24 | — | baseline | 0.0 | 0.0 |
| s3 | t3 | boss | 0/1 | 0.0% [0.0, 79.3] | 4 | 24 | 1 | 0.0% | +0.0 | 25.0 |
| s4 | t1 | normal | 48/64 | 75.0% [63.2, 84.0] | 4 | 14 | — | baseline | 0.0 | 0.0 |
| s4 | t1 | objective | 3/3 | 100.0% [43.9, 100.0] | 4 | 6 | 3 | 100.0% | +0.0 | 5.0 |
| s4 | t1 | guardian | 14/24 | 58.3% [38.8, 75.5] | 6.5 | 24 | 24 | 70.8% | -12.5 | 2.5 |
| s4 | t2 | normal | 29/64 | 45.3% [33.7, 57.4] | 5 | 21.5 | — | baseline | 0.0 | 0.0 |
| s4 | t2 | objective | 12/16 | 75.0% [50.5, 89.8] | 4 | 16.5 | 16 | 31.2% | +43.8 | 48.8 |
| s4 | t2 | guardian | 7/16 | 43.8% [23.1, 66.8] | 2 | 20 | 16 | 25.0% | +18.8 | 33.8 |
| s4 | t3 | normal | 15/64 | 23.4% [14.7, 35.1] | 6 | 25 | — | baseline | 0.0 | 0.0 |
| s4 | t3 | objective | 30/45 | 66.7% [52.1, 78.6] | 4 | 15 | 45 | 33.3% | +33.3 | 38.3 |
| s4 | t3 | guardian | 2/24 | 8.3% [2.3, 25.8] | 4 | 28 | 24 | 20.8% | -12.5 | 2.5 |
| s4 | t3 | boss | 23/64 | 35.9% [25.3, 48.2] | 4 | 24 | 64 | 23.4% | +12.5 | 37.5 |
| s5 | t1 | normal | 1/1 | 100.0% [20.7, 100.0] | 3 | 6 | — | baseline | 0.0 | 0.0 |
| s5 | t2 | normal | 1/1 | 100.0% [20.7, 100.0] | 7 | 17 | — | baseline | 0.0 | 0.0 |
| s5 | t2 | objective | 1/1 | 100.0% [20.7, 100.0] | 4 | 0 | 1 | 100.0% | +0.0 | 5.0 |
| s5 | t3 | normal | 0/1 | 0.0% [0.0, 79.3] | 6 | 20 | — | baseline | 0.0 | 0.0 |
| s5 | t3 | guardian | 1/1 | 100.0% [20.7, 100.0] | 5 | 11 | 1 | 0.0% | +100.0 | 115.0 |
| s5 | t3 | boss | 1/1 | 100.0% [20.7, 100.0] | 5 | 11 | 1 | 0.0% | +100.0 | 125.0 |


## B. How scaling works today

| Knob | Exact code/data anchor | Current behavior |
|---|---|---|
| Map section/depth bands and route fight budgets | `scripts/section_map_graph.gd:15` | FIGHT_COUNTS, ROOM_COUNTS, _depth_bands; global depth = section×4 + native band. Map weighting, fallback maps, guaranteed Guardians, optional mysteries and special substitutions determine what is encountered. |
| Dragon and biome roster order | `scripts/dragon_boss_library.gd:66` | Seeded permutation of five elemental dragons in s0–s4; Noctyrax in s5. Biome changes normal token groups, Warband escorts, Snare pressure and Last Light attackers. Guardian identity follows the dragon. |
| Normal tier and route fight number | `scripts/encounter_tables.gd:258` | k counts cleared combat/special/Guardian rooms in this section (including resolved mysteries), not dragons. effective tier=min(native depth tier, min(3,1+(k−1)/2)); persisted fight_number retains the entry choice. |
| Normal compositions, weights and caps | `data/encounters.json:237` | /tiers, /element_regulars, /biome_groups, /rules: global max 7; tier caps 3/5/6; k caps 3/3/4/5/5/6, last repeats. Recent-history exclusion 2; weighted tokens must fit, concrete units trim from the end. Current tier-3 k≥6 can exceed five. |
| Count selection and legacy fallback | `scripts/room_generator.gd:674` | Boss/Guardian rosters bypass normal caps. Legacy normal pools have 3/4/5 units by local depth. Element-locked groups add roster alternatives, not extra units. Invalid table data or exempt rooms use these legacy pools. |
| Normal table legacy-save exception | `scripts/encounter_tables.gd:173` | Old rooms without persisted k retain the old picker and global seven-unit cap; modern per-tier/per-k caps are bypassed. |
| Trap damage by local depth and section | `scripts/room_generator.gd:35` | Local bands 1/2/3/4 use 6/7/8/5, plus section additions 0/1/1/2/2/3. Trap counts and positions use seeded geometry; Guardian arenas can replace traps. |
| Special-room Umbra exceptions | `scripts/combat_engine.gd:288` | The automatic section Umbra baseline applies to combat, Guardian and boss layouts, plus shadow Snare. Other special layouts default clear unless they set an explicit override; Last Light explicitly sets sight-radius-3 Umbra. Warband and Hoarder therefore do not automatically inherit normal-room section darkness. |
| Fatigue and fight length | `scripts/combat_engine.gd:8130` | Deck cycles increase fatigue damage from base 2 by cycles−1; optional Umbra Depth18 adds1. This is turn/deck-dependent, not a tier/section multiplier; Survive duration and enemy healing can expose it more often. |
| Health: shared local-depth and section scaling | `scripts/room_generator.gd:655` | ceil(base×local), then ceil(result×(1+0.08×section)), plus flat bonus 0×section. Local factors: band 1=.85, band 2=1, band 3=1.12, boss band 4=1. Applies to initial enemies before special overrides. |
| Health: combat spawns | `scripts/combat_engine.gd:9403` | Duplicate shared local/section Health formula used for reinforcements, splits and summons; keep both implementations coherent if tuned later. |
| Damage and support by section | `scripts/combat_engine.gd:115` | Damage flat additions s0–s5: 0/1/1/2/2/3; support: 0/0/1/1/2/2. Local damage deltas are both 0; local support band 1 is −1, band 3 is 0. These are fixed-point runtime units, not multipliers. |
| Damage action applicability and exemptions | `scripts/combat_engine.gd:9413` | scale_damage=false opts standard attacks out. ATTACK_ACTION_TYPES, lightning_strikes and BOSS_DAMAGE_ACTION_TYPES receive damage additions; lob_land center/arm fields have a separate path. Block/Stoneskin/guard/heal/raised-terrain Health receive support additions. |
| Fixed-point base stats and intrinsic difficulty | `scripts/game_data.gd:937` | data/enemies.json /<id>/max_hp and /<id>/intents/*/actions (damage, healing, statuses, summons, durations, time_cost), defenses, initiative and movement; fixed-point conversion is global representation, not section tuning. No separate general elite-roll or captain-roll scaler was found. |
| Guardian roster, initial helpers and arenas | `scripts/guardian_library.gd:4` | DEFINITIONS helpers (overridden by enemy guardian_initial_helpers), plus one Guardian. Authored pillars, surfaces and rule instances are identity-specific; starting lightning_wisp/wick_shade helpers are marked summoned. Other attendants count normally. |
| Guardian reinforcement and phase picks | `scripts/guardian_combat_rules.gd:295` | Guardian helpers use live caps (two total and guardian_cap per type), replacement/special intents, and production battlefield mechanics. These later arrivals are separate from starting counts. |
| Dragon initial rosters | `scripts/room_generator.gd:120` | Zekarion has two starting lightning wisps; Noctyrax two Veilbound Acolytes. Others use data/enemies.json /<dragon>/dragon_helpers. These starting wisps are not automatically flagged summoned by the Guardian-only helper path. |
| Special placement and scarcity | `data/special_encounters.json:4` | /placement chooses 2 or 3 distinct kinds per section, caps route specials at 2, excludes adjacent Guardians and requires a route without specials; enabled and first_layout_revision gate kinds. All four enabled kinds are inventoried. |
| Warband size, captain and command | `scripts/warband_room_rules.gd:12` | 1 captain + first tier+2 ordered escorts: total 4/5/6. Captain selection is authored by biome, not an elite random roll. /types/warband/captain: Health ×1.25, Stoneskin 2/3/4; Command +1 printed damage in radius 2; variant orders add distinct battlefield effects. |
| Warband live damage command | `scripts/warband_combat_rules.gd:48` | Converts the authored +1 to fixed-point at use; only living non-captains in a living captain’s radius qualify. Placement and keep-away/formation rules also change difficulty. |
| Snare size, stats and sealing clock | `scripts/snare_room_rules.gd:100` | 1 jailer + door_count−1 Sealbinders + biome start_hunters. Ice starts 3 hunters: three exits yield 6 units. Jailer Health ×2, Stoneskin 2/3/4; binders override scaled Health with SEALBINDER_HP=4. Doors seal on authored 2/4 turns (two-exit exception 3); non-Ice hunters arrive later up to hunters_max=3. |
| Snare biome pressure | `scripts/snare_pressure_rules.gd:8` | /types/umbral_snare/variants/*/pressure: rubble, spreading fire, headwind, ice, lightning and shadow pressure. Pressure fields, battlefield instance and per-turn timing are biome-specific. |
| Last Light roster and duration | `scripts/last_light_rules.gd:35` | 2 Wick Shades + two biome attackers =4 starters. /types/last_light/time_target_by_depth=60/66/72; sight_radius=3; three braziers. Survive waves later add enemies independently of the starting cap. |
| Hoarder roster, relative Health and escape | `scripts/hoarder_room_rules.gd:31` | /types/ember_hoarder: one Hoarder +3 Ember Ticks =4 starters. configure overrides Hoarder Health to 3×its brood’s final scaled Tick Health; escape clock by tier 5/4/4. Capturing and escaping are both combat victories once remaining foes are gone; bonus goal_met is distinct from won. |
| Generic legacy objectives | `scripts/combat_objective_rules.gd:44` | Revision≥6 normal rooms are Kill All. Older saved maps: the highest-scaled-Health enemy becomes leader (first in roster on ties), then leader Health ×1.5 and Stoneskin 2+tier; Reach Exit adds 1/2/2 enemies and terrain +3; Survive targets 42/46/50 and wave interval 16 (new random Survive picks parked). Guardian/dragon leader scaling is ×1 and +0 Stoneskin. |
| Omen count and combat effects | `scripts/run_engine.gd:2539` | Hunted adds one ordinary enemy after normal cap/placement, only combat rooms; specials/Guardians/dragons excluded. Active omens also affect initial block, Stoneskin, Expose, sight/Umbra, card plays, movement and fire; data/events.json /omens is authoritative. |
| Extra-enemy placement bypass | `scripts/room_generator.gd:355` | Additions sample legacy type pools and available floor, bypassing normal table caps. A five-unit normal plus Hunted becomes six; six becomes seven if space permits. |
| Umbra stage and visibility progression | `scripts/combat_engine.gd:86` | Section baseline advances through clear/fringe/advancing/pressing/deep/heart; s0 fringe begins at local step 2. Radii 99/6/5/4/3/2; eclipse radius 1. Omens, Light, relics, boss eclipse and room overrides modify effective visibility; normal shared section pressure is independent of roster count. |
| Optional Umbra Depth difficulty | `scripts/depth_rules.gd:49` | data/depths.json /levels: cumulative unlock mode independent of run section. Regular/Guardian/dragon Health percentages 110/110/108, damage flat bonuses 1/2/2; Guardian weight ×1.6; initiative −1, extra helper +1, Noctyrax Health ×1.25 and damage +2. Further changes cover sight, fatigue, starting Health/omen, healing and reward/economy. This measurement uses depth 0. |
| Umbra Depth helper and Health application order | `scripts/room_generator.gd:315` | Apply optional Guardian helper before DepthRules.enemy_hp. Hoarder, Snare and Last Light configure after this pass, so their overrides matter. Spawned helper paths and summoned classification have separate DepthRules treatment. |
| Summons and other mid-fight arrivals | `scripts/combat_engine.gd:6738` | data/enemies.json intents summon count/minion_type/summon_cap, guardian_cap; _spawn_due_survival_reinforcements uses objective clock/pool; _trigger_enemy_death_spawn splits (data/enemies.json /<id>/death_spawn); Snare hunters and Snuff Shade arrivals have their own rules. These do not enter the starting-count distribution. |
| Battlefield phases and modifiers | `scripts/battlefield_rules/dispatcher.gd:17` | data/battlefield_rules.json /rules and /instances specify damage, range, cadence, duration, surfaces and half-Health phase replacements for boss/Guardian/Warband/Snare identities. The unchanged bot bypasses committed.accept’s half-Health checks; interpret results as relative policy measurements. |


### Starting enemy-count distributions

Count census: eight production seeded maps, every direct encounter node, plus resolved combat mysteries in the supplemental census. Each node is counted once in each fixed-k scenario, and once per reachable k in native_prefix, never once per combat repeat. These are unweighted node distributions for those maps and controlled fight schedules, not human route probabilities or an exhaustive distribution over all map seeds. Counts are enemy entries, not occupied footprint tiles. All enemies actually present at room start are shown first; game `summoned=true` flags are then separated so the director’s summon exclusion can be assessed. Starting Ice Snare hunters and starting dragon wisps are not automatically excluded as summons. Mid-fight arrivals never enter these tables.

Two fixed scheduling scenarios expose the count-cap dependency: **first_eligible** sets k=1/3/5 by depth band, matching the fights; **late_k6** sets k=6 at every room as a count sensitivity check. The latter is a counterfactual at early bands and is not claimed to be a reachable sixth fight in every room. **native_prefix** additionally propagates all possible completed-fight counts over the section DAG (including hidden combat mysteries) and retains a real incoming direction witnessing each k. It reports equally weighted node/k cases; path multiplicity and encounter histories are not natural-route probability weights. The depth-band column remains the native band; raw effective_encounter_tier records the roster tier after the k clamp. Histories remain empty; archived active omens apply. Umbra Depth is zero.

| Scenario | Section | Tier | Cases | All start min/median/max | All >5 | Non-summoned min/median/max | Non-summoned >5 | Flagged summons min/median/max |
|---|---|---|---|---|---|---|---|---|
| first_eligible | s0 | normal | 98 | 3/4/5 | 0.0% | 3/4/5 | 0.0% | 0/0/0 |
| first_eligible | s0 | objective | 20 | 2/4/6 | 10.0% | 2/4/6 | 10.0% | 0/0/0 |
| first_eligible | s0 | guardian | 18 | 3/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/1 |
| first_eligible | s0 | boss | 8 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| first_eligible | s1 | normal | 115 | 2/3/5 | 0.0% | 2/3/5 | 0.0% | 0/0/0 |
| first_eligible | s1 | objective | 19 | 2/4/6 | 5.3% | 2/4/6 | 5.3% | 0/0/0 |
| first_eligible | s1 | guardian | 16 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| first_eligible | s1 | boss | 8 | 2/2.5/3 | 0.0% | 2/2.5/3 | 0.0% | 0/0/0 |
| first_eligible | s2 | normal | 126 | 3/3/5 | 0.0% | 3/3/5 | 0.0% | 0/0/0 |
| first_eligible | s2 | objective | 22 | 2/4/6 | 18.2% | 2/4/6 | 18.2% | 0/0/0 |
| first_eligible | s2 | guardian | 20 | 3/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/1 |
| first_eligible | s2 | boss | 8 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| first_eligible | s3 | normal | 132 | 2/4/5 | 0.0% | 2/4/5 | 0.0% | 0/0/0 |
| first_eligible | s3 | objective | 20 | 2/4/6 | 10.0% | 2/4/6 | 10.0% | 0/0/0 |
| first_eligible | s3 | guardian | 22 | 3/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/1 |
| first_eligible | s3 | boss | 8 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| first_eligible | s4 | normal | 128 | 2/4/5 | 0.0% | 2/4/5 | 0.0% | 0/0/0 |
| first_eligible | s4 | objective | 20 | 2/4/6 | 15.0% | 2/4/6 | 15.0% | 0/0/0 |
| first_eligible | s4 | guardian | 21 | 3/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/1 |
| first_eligible | s4 | boss | 8 | 2/2/3 | 0.0% | 2/2/3 | 0.0% | 0/0/0 |
| first_eligible | s5 | normal | 144 | 2/4/5 | 0.0% | 2/4/5 | 0.0% | 0/0/0 |
| first_eligible | s5 | objective | 19 | 2/4/6 | 15.8% | 2/4/6 | 15.8% | 0/0/0 |
| first_eligible | s5 | guardian | 23 | 2/2/2 | 0.0% | 1/1/1 | 0.0% | 1/1/1 |
| first_eligible | s5 | boss | 8 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| late_k6 | s0 | normal | 98 | 3/4/6 | 12.2% | 3/4/6 | 12.2% | 0/0/0 |
| late_k6 | s0 | objective | 20 | 2/4/6 | 10.0% | 2/4/6 | 10.0% | 0/0/0 |
| late_k6 | s0 | guardian | 18 | 3/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/1 |
| late_k6 | s0 | boss | 8 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| late_k6 | s1 | normal | 115 | 2/3/6 | 10.4% | 2/3/6 | 10.4% | 0/0/0 |
| late_k6 | s1 | objective | 19 | 2/4/6 | 5.3% | 2/4/6 | 5.3% | 0/0/0 |
| late_k6 | s1 | guardian | 16 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| late_k6 | s1 | boss | 8 | 2/2.5/3 | 0.0% | 2/2.5/3 | 0.0% | 0/0/0 |
| late_k6 | s2 | normal | 126 | 3/3/6 | 14.3% | 3/3/6 | 14.3% | 0/0/0 |
| late_k6 | s2 | objective | 22 | 2/4/6 | 18.2% | 2/4/6 | 18.2% | 0/0/0 |
| late_k6 | s2 | guardian | 20 | 3/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/1 |
| late_k6 | s2 | boss | 8 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| late_k6 | s3 | normal | 132 | 2/4/6 | 13.6% | 2/4/6 | 13.6% | 0/0/0 |
| late_k6 | s3 | objective | 20 | 2/4/6 | 10.0% | 2/4/6 | 10.0% | 0/0/0 |
| late_k6 | s3 | guardian | 22 | 3/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/1 |
| late_k6 | s3 | boss | 8 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| late_k6 | s4 | normal | 128 | 2/4/6 | 20.3% | 2/4/6 | 20.3% | 0/0/0 |
| late_k6 | s4 | objective | 20 | 2/4/6 | 15.0% | 2/4/6 | 15.0% | 0/0/0 |
| late_k6 | s4 | guardian | 21 | 3/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/1 |
| late_k6 | s4 | boss | 8 | 2/2/3 | 0.0% | 2/2/3 | 0.0% | 0/0/0 |
| late_k6 | s5 | normal | 144 | 2/4/6 | 13.9% | 2/4/6 | 13.9% | 0/0/0 |
| late_k6 | s5 | objective | 19 | 2/4/6 | 15.8% | 2/4/6 | 15.8% | 0/0/0 |
| late_k6 | s5 | guardian | 23 | 2/2/2 | 0.0% | 1/1/1 | 0.0% | 1/1/1 |
| late_k6 | s5 | boss | 8 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| native_prefix | s0 | normal | 142 | 2/4/5 | 0.0% | 2/4/5 | 0.0% | 0/0/0 |
| native_prefix | s0 | objective | 33 | 2/4/6 | 12.1% | 2/4/6 | 12.1% | 0/0/0 |
| native_prefix | s0 | guardian | 24 | 3/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/1 |
| native_prefix | s0 | boss | 24 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| native_prefix | s1 | normal | 179 | 2/4/6 | 2.2% | 2/4/6 | 2.2% | 0/0/0 |
| native_prefix | s1 | objective | 39 | 2/4/6 | 5.1% | 2/4/6 | 5.1% | 0/0/0 |
| native_prefix | s1 | guardian | 28 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| native_prefix | s1 | boss | 31 | 2/2/3 | 0.0% | 2/2/3 | 0.0% | 0/0/0 |
| native_prefix | s2 | normal | 161 | 3/4/6 | 4.3% | 3/4/6 | 4.3% | 0/0/0 |
| native_prefix | s2 | objective | 36 | 2/4/6 | 16.7% | 2/4/6 | 16.7% | 0/0/0 |
| native_prefix | s2 | guardian | 29 | 3/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/1 |
| native_prefix | s2 | boss | 24 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| native_prefix | s3 | normal | 214 | 2/4/6 | 2.8% | 2/4/6 | 2.8% | 0/0/0 |
| native_prefix | s3 | objective | 39 | 2/4/6 | 12.8% | 2/4/6 | 12.8% | 0/0/0 |
| native_prefix | s3 | guardian | 38 | 3/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/1 |
| native_prefix | s3 | boss | 24 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| native_prefix | s4 | normal | 186 | 2/4/6 | 4.3% | 2/4/6 | 4.3% | 0/0/0 |
| native_prefix | s4 | objective | 35 | 2/4/6 | 17.1% | 2/4/6 | 17.1% | 0/0/0 |
| native_prefix | s4 | guardian | 31 | 3/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/1 |
| native_prefix | s4 | boss | 24 | 2/2/3 | 0.0% | 2/2/3 | 0.0% | 0/0/0 |
| native_prefix | s5 | normal | 241 | 2/4/6 | 7.9% | 2/4/6 | 7.9% | 0/0/0 |
| native_prefix | s5 | objective | 35 | 2/4/6 | 14.3% | 2/4/6 | 14.3% | 0/0/0 |
| native_prefix | s5 | guardian | 36 | 2/2/2 | 0.0% | 1/1/1 | 0.0% | 1/1/1 |
| native_prefix | s5 | boss | 32 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |


| Scenario | Section | Depth band | Tier/kind | Cases | All start min/median/max | All >5 | Non-summoned min/median/max | Non-summoned >5 | Flagged summons min/median/max |
|---|---|---|---|---|---|---|---|---|---|
| first_eligible | s0 | t1 | normal | 43 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| first_eligible | s0 | t2 | normal | 25 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s0 | t2 | warband | 3 | 5/5/5 | 0.0% | 5/5/5 | 0.0% | 0/0/0 |
| first_eligible | s0 | t2 | last_light | 2 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s0 | t2 | ember_hoarder | 3 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s0 | t2 | guardian | 15 | 3/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/1 |
| first_eligible | s0 | t3 | normal | 30 | 4/5/5 | 0.0% | 4/5/5 | 0.0% | 0/0/0 |
| first_eligible | s0 | t3 | warband | 2 | 6/6/6 | 100.0% | 6/6/6 | 100.0% | 0/0/0 |
| first_eligible | s0 | t3 | umbral_snare | 3 | 2/2/5 | 0.0% | 2/2/5 | 0.0% | 0/0/0 |
| first_eligible | s0 | t3 | last_light | 3 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s0 | t3 | ember_hoarder | 4 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s0 | t3 | guardian | 3 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| first_eligible | s0 | t3 | boss | 8 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| first_eligible | s1 | t1 | normal | 60 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| first_eligible | s1 | t1 | warband | 2 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s1 | t1 | last_light | 2 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s1 | t1 | guardian | 4 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| first_eligible | s1 | t2 | normal | 12 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s1 | t2 | last_light | 1 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s1 | t2 | ember_hoarder | 3 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s1 | t2 | guardian | 3 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| first_eligible | s1 | t3 | normal | 43 | 4/5/5 | 0.0% | 4/5/5 | 0.0% | 0/0/0 |
| first_eligible | s1 | t3 | warband | 1 | 6/6/6 | 100.0% | 6/6/6 | 100.0% | 0/0/0 |
| first_eligible | s1 | t3 | umbral_snare | 4 | 2/2/5 | 0.0% | 2/2/5 | 0.0% | 0/0/0 |
| first_eligible | s1 | t3 | last_light | 4 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s1 | t3 | ember_hoarder | 2 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s1 | t3 | guardian | 9 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| first_eligible | s1 | t3 | boss | 8 | 2/2.5/3 | 0.0% | 2/2.5/3 | 0.0% | 0/0/0 |
| first_eligible | s2 | t1 | normal | 66 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| first_eligible | s2 | t1 | warband | 1 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s2 | t1 | ember_hoarder | 1 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s2 | t1 | guardian | 3 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| first_eligible | s2 | t2 | normal | 17 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s2 | t2 | warband | 2 | 5/5/5 | 0.0% | 5/5/5 | 0.0% | 0/0/0 |
| first_eligible | s2 | t2 | last_light | 2 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s2 | t2 | guardian | 9 | 3/3/3 | 0.0% | 2/2/3 | 0.0% | 0/1/1 |
| first_eligible | s2 | t3 | normal | 43 | 4/5/5 | 0.0% | 4/5/5 | 0.0% | 0/0/0 |
| first_eligible | s2 | t3 | warband | 4 | 6/6/6 | 100.0% | 6/6/6 | 100.0% | 0/0/0 |
| first_eligible | s2 | t3 | umbral_snare | 5 | 2/2/2 | 0.0% | 2/2/2 | 0.0% | 0/0/0 |
| first_eligible | s2 | t3 | last_light | 5 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s2 | t3 | ember_hoarder | 2 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s2 | t3 | guardian | 8 | 3/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/1 |
| first_eligible | s2 | t3 | boss | 8 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| first_eligible | s3 | t1 | normal | 59 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| first_eligible | s3 | t1 | warband | 2 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s3 | t1 | last_light | 1 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s3 | t1 | ember_hoarder | 1 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s3 | t1 | guardian | 4 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| first_eligible | s3 | t2 | normal | 13 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s3 | t2 | last_light | 3 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s3 | t2 | ember_hoarder | 2 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s3 | t2 | guardian | 4 | 3/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/1 |
| first_eligible | s3 | t3 | normal | 60 | 4/5/5 | 0.0% | 4/5/5 | 0.0% | 0/0/0 |
| first_eligible | s3 | t3 | warband | 2 | 6/6/6 | 100.0% | 6/6/6 | 100.0% | 0/0/0 |
| first_eligible | s3 | t3 | umbral_snare | 3 | 2/2/5 | 0.0% | 2/2/5 | 0.0% | 0/0/0 |
| first_eligible | s3 | t3 | last_light | 3 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s3 | t3 | ember_hoarder | 3 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s3 | t3 | guardian | 14 | 3/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/1 |
| first_eligible | s3 | t3 | boss | 8 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| first_eligible | s4 | t1 | normal | 61 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| first_eligible | s4 | t1 | last_light | 1 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s4 | t1 | guardian | 3 | 3/3/3 | 0.0% | 2/2/3 | 0.0% | 0/1/1 |
| first_eligible | s4 | t2 | normal | 16 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s4 | t2 | warband | 2 | 5/5/5 | 0.0% | 5/5/5 | 0.0% | 0/0/0 |
| first_eligible | s4 | t2 | last_light | 2 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s4 | t2 | ember_hoarder | 1 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s4 | t2 | guardian | 4 | 3/3/3 | 0.0% | 2/2.5/3 | 0.0% | 0/0.5/1 |
| first_eligible | s4 | t3 | normal | 51 | 5/5/5 | 0.0% | 5/5/5 | 0.0% | 0/0/0 |
| first_eligible | s4 | t3 | warband | 3 | 6/6/6 | 100.0% | 6/6/6 | 100.0% | 0/0/0 |
| first_eligible | s4 | t3 | umbral_snare | 4 | 2/2/5 | 0.0% | 2/2/5 | 0.0% | 0/0/0 |
| first_eligible | s4 | t3 | last_light | 2 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s4 | t3 | ember_hoarder | 5 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s4 | t3 | guardian | 14 | 3/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/1 |
| first_eligible | s4 | t3 | boss | 8 | 2/2/3 | 0.0% | 2/2/3 | 0.0% | 0/0/0 |
| first_eligible | s5 | t1 | normal | 60 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| first_eligible | s5 | t1 | guardian | 10 | 2/2/2 | 0.0% | 1/1/1 | 0.0% | 1/1/1 |
| first_eligible | s5 | t2 | normal | 30 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s5 | t2 | warband | 2 | 5/5/5 | 0.0% | 5/5/5 | 0.0% | 0/0/0 |
| first_eligible | s5 | t2 | umbral_snare | 2 | 2/2/2 | 0.0% | 2/2/2 | 0.0% | 0/0/0 |
| first_eligible | s5 | t2 | ember_hoarder | 3 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s5 | t2 | guardian | 8 | 2/2/2 | 0.0% | 1/1/1 | 0.0% | 1/1/1 |
| first_eligible | s5 | t3 | normal | 54 | 4/5/5 | 0.0% | 4/5/5 | 0.0% | 0/0/0 |
| first_eligible | s5 | t3 | warband | 3 | 6/6/6 | 100.0% | 6/6/6 | 100.0% | 0/0/0 |
| first_eligible | s5 | t3 | umbral_snare | 5 | 2/2/2 | 0.0% | 2/2/2 | 0.0% | 0/0/0 |
| first_eligible | s5 | t3 | last_light | 4 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| first_eligible | s5 | t3 | guardian | 5 | 2/2/2 | 0.0% | 1/1/1 | 0.0% | 1/1/1 |
| first_eligible | s5 | t3 | boss | 8 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| late_k6 | s0 | t1 | normal | 43 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| late_k6 | s0 | t2 | normal | 25 | 4/4/5 | 0.0% | 4/4/5 | 0.0% | 0/0/0 |
| late_k6 | s0 | t2 | warband | 3 | 5/5/5 | 0.0% | 5/5/5 | 0.0% | 0/0/0 |
| late_k6 | s0 | t2 | last_light | 2 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| late_k6 | s0 | t2 | ember_hoarder | 3 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| late_k6 | s0 | t2 | guardian | 15 | 3/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/1 |
| late_k6 | s0 | t3 | normal | 30 | 4/5/6 | 40.0% | 4/5/6 | 40.0% | 0/0/0 |
| late_k6 | s0 | t3 | warband | 2 | 6/6/6 | 100.0% | 6/6/6 | 100.0% | 0/0/0 |
| late_k6 | s0 | t3 | umbral_snare | 3 | 2/2/5 | 0.0% | 2/2/5 | 0.0% | 0/0/0 |
| late_k6 | s0 | t3 | last_light | 3 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| late_k6 | s0 | t3 | ember_hoarder | 4 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| late_k6 | s0 | t3 | guardian | 3 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| late_k6 | s0 | t3 | boss | 8 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| late_k6 | s1 | t1 | normal | 60 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| late_k6 | s1 | t1 | warband | 2 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| late_k6 | s1 | t1 | last_light | 2 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| late_k6 | s1 | t1 | guardian | 4 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| late_k6 | s1 | t2 | normal | 12 | 4/4/5 | 0.0% | 4/4/5 | 0.0% | 0/0/0 |
| late_k6 | s1 | t2 | last_light | 1 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| late_k6 | s1 | t2 | ember_hoarder | 3 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| late_k6 | s1 | t2 | guardian | 3 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| late_k6 | s1 | t3 | normal | 43 | 4/5/6 | 27.9% | 4/5/6 | 27.9% | 0/0/0 |
| late_k6 | s1 | t3 | warband | 1 | 6/6/6 | 100.0% | 6/6/6 | 100.0% | 0/0/0 |
| late_k6 | s1 | t3 | umbral_snare | 4 | 2/2/5 | 0.0% | 2/2/5 | 0.0% | 0/0/0 |
| late_k6 | s1 | t3 | last_light | 4 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| late_k6 | s1 | t3 | ember_hoarder | 2 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| late_k6 | s1 | t3 | guardian | 9 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| late_k6 | s1 | t3 | boss | 8 | 2/2.5/3 | 0.0% | 2/2.5/3 | 0.0% | 0/0/0 |
| late_k6 | s2 | t1 | normal | 66 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| late_k6 | s2 | t1 | warband | 1 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| late_k6 | s2 | t1 | ember_hoarder | 1 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| late_k6 | s2 | t1 | guardian | 3 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| late_k6 | s2 | t2 | normal | 17 | 4/4/5 | 0.0% | 4/4/5 | 0.0% | 0/0/0 |
| late_k6 | s2 | t2 | warband | 2 | 5/5/5 | 0.0% | 5/5/5 | 0.0% | 0/0/0 |
| late_k6 | s2 | t2 | last_light | 2 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| late_k6 | s2 | t2 | guardian | 9 | 3/3/3 | 0.0% | 2/2/3 | 0.0% | 0/1/1 |
| late_k6 | s2 | t3 | normal | 43 | 4/5/6 | 41.9% | 4/5/6 | 41.9% | 0/0/0 |
| late_k6 | s2 | t3 | warband | 4 | 6/6/6 | 100.0% | 6/6/6 | 100.0% | 0/0/0 |
| late_k6 | s2 | t3 | umbral_snare | 5 | 2/2/2 | 0.0% | 2/2/2 | 0.0% | 0/0/0 |
| late_k6 | s2 | t3 | last_light | 5 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| late_k6 | s2 | t3 | ember_hoarder | 2 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| late_k6 | s2 | t3 | guardian | 8 | 3/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/1 |
| late_k6 | s2 | t3 | boss | 8 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| late_k6 | s3 | t1 | normal | 59 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| late_k6 | s3 | t1 | warband | 2 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| late_k6 | s3 | t1 | last_light | 1 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| late_k6 | s3 | t1 | ember_hoarder | 1 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| late_k6 | s3 | t1 | guardian | 4 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| late_k6 | s3 | t2 | normal | 13 | 4/4/5 | 0.0% | 4/4/5 | 0.0% | 0/0/0 |
| late_k6 | s3 | t2 | last_light | 3 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| late_k6 | s3 | t2 | ember_hoarder | 2 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| late_k6 | s3 | t2 | guardian | 4 | 3/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/1 |
| late_k6 | s3 | t3 | normal | 60 | 4/5/6 | 30.0% | 4/5/6 | 30.0% | 0/0/0 |
| late_k6 | s3 | t3 | warband | 2 | 6/6/6 | 100.0% | 6/6/6 | 100.0% | 0/0/0 |
| late_k6 | s3 | t3 | umbral_snare | 3 | 2/2/5 | 0.0% | 2/2/5 | 0.0% | 0/0/0 |
| late_k6 | s3 | t3 | last_light | 3 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| late_k6 | s3 | t3 | ember_hoarder | 3 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| late_k6 | s3 | t3 | guardian | 14 | 3/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/1 |
| late_k6 | s3 | t3 | boss | 8 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| late_k6 | s4 | t1 | normal | 61 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| late_k6 | s4 | t1 | last_light | 1 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| late_k6 | s4 | t1 | guardian | 3 | 3/3/3 | 0.0% | 2/2/3 | 0.0% | 0/1/1 |
| late_k6 | s4 | t2 | normal | 16 | 4/4.5/5 | 0.0% | 4/4.5/5 | 0.0% | 0/0/0 |
| late_k6 | s4 | t2 | warband | 2 | 5/5/5 | 0.0% | 5/5/5 | 0.0% | 0/0/0 |
| late_k6 | s4 | t2 | last_light | 2 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| late_k6 | s4 | t2 | ember_hoarder | 1 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| late_k6 | s4 | t2 | guardian | 4 | 3/3/3 | 0.0% | 2/2.5/3 | 0.0% | 0/0.5/1 |
| late_k6 | s4 | t3 | normal | 51 | 5/6/6 | 51.0% | 5/6/6 | 51.0% | 0/0/0 |
| late_k6 | s4 | t3 | warband | 3 | 6/6/6 | 100.0% | 6/6/6 | 100.0% | 0/0/0 |
| late_k6 | s4 | t3 | umbral_snare | 4 | 2/2/5 | 0.0% | 2/2/5 | 0.0% | 0/0/0 |
| late_k6 | s4 | t3 | last_light | 2 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| late_k6 | s4 | t3 | ember_hoarder | 5 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| late_k6 | s4 | t3 | guardian | 14 | 3/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/1 |
| late_k6 | s4 | t3 | boss | 8 | 2/2/3 | 0.0% | 2/2/3 | 0.0% | 0/0/0 |
| late_k6 | s5 | t1 | normal | 60 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| late_k6 | s5 | t1 | guardian | 10 | 2/2/2 | 0.0% | 1/1/1 | 0.0% | 1/1/1 |
| late_k6 | s5 | t2 | normal | 30 | 4/5/5 | 0.0% | 4/5/5 | 0.0% | 0/0/0 |
| late_k6 | s5 | t2 | warband | 2 | 5/5/5 | 0.0% | 5/5/5 | 0.0% | 0/0/0 |
| late_k6 | s5 | t2 | umbral_snare | 2 | 2/2/2 | 0.0% | 2/2/2 | 0.0% | 0/0/0 |
| late_k6 | s5 | t2 | ember_hoarder | 3 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| late_k6 | s5 | t2 | guardian | 8 | 2/2/2 | 0.0% | 1/1/1 | 0.0% | 1/1/1 |
| late_k6 | s5 | t3 | normal | 54 | 4/5/6 | 37.0% | 4/5/6 | 37.0% | 0/0/0 |
| late_k6 | s5 | t3 | warband | 3 | 6/6/6 | 100.0% | 6/6/6 | 100.0% | 0/0/0 |
| late_k6 | s5 | t3 | umbral_snare | 5 | 2/2/2 | 0.0% | 2/2/2 | 0.0% | 0/0/0 |
| late_k6 | s5 | t3 | last_light | 4 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| late_k6 | s5 | t3 | guardian | 5 | 2/2/2 | 0.0% | 1/1/1 | 0.0% | 1/1/1 |
| late_k6 | s5 | t3 | boss | 8 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| native_prefix | s0 | t1 | normal | 43 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| native_prefix | s0 | t2 | normal | 39 | 2/4/5 | 0.0% | 2/4/5 | 0.0% | 0/0/0 |
| native_prefix | s0 | t2 | warband | 3 | 5/5/5 | 0.0% | 5/5/5 | 0.0% | 0/0/0 |
| native_prefix | s0 | t2 | last_light | 3 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| native_prefix | s0 | t2 | ember_hoarder | 4 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| native_prefix | s0 | t2 | guardian | 19 | 3/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/1 |
| native_prefix | s0 | t3 | normal | 60 | 3/4/5 | 0.0% | 3/4/5 | 0.0% | 0/0/0 |
| native_prefix | s0 | t3 | warband | 4 | 6/6/6 | 100.0% | 6/6/6 | 100.0% | 0/0/0 |
| native_prefix | s0 | t3 | umbral_snare | 5 | 2/2/5 | 0.0% | 2/2/5 | 0.0% | 0/0/0 |
| native_prefix | s0 | t3 | last_light | 6 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| native_prefix | s0 | t3 | ember_hoarder | 8 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| native_prefix | s0 | t3 | guardian | 5 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| native_prefix | s0 | t3 | boss | 24 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| native_prefix | s1 | t1 | normal | 63 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| native_prefix | s1 | t1 | warband | 2 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| native_prefix | s1 | t1 | last_light | 2 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| native_prefix | s1 | t1 | guardian | 4 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| native_prefix | s1 | t2 | normal | 20 | 3/4/5 | 0.0% | 3/4/5 | 0.0% | 0/0/0 |
| native_prefix | s1 | t2 | last_light | 2 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| native_prefix | s1 | t2 | ember_hoarder | 7 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| native_prefix | s1 | t2 | guardian | 4 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| native_prefix | s1 | t3 | normal | 96 | 2/5/6 | 4.2% | 2/5/6 | 4.2% | 0/0/0 |
| native_prefix | s1 | t3 | warband | 2 | 6/6/6 | 100.0% | 6/6/6 | 100.0% | 0/0/0 |
| native_prefix | s1 | t3 | umbral_snare | 10 | 2/2/5 | 0.0% | 2/2/5 | 0.0% | 0/0/0 |
| native_prefix | s1 | t3 | last_light | 10 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| native_prefix | s1 | t3 | ember_hoarder | 4 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| native_prefix | s1 | t3 | guardian | 20 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| native_prefix | s1 | t3 | boss | 31 | 2/2/3 | 0.0% | 2/2/3 | 0.0% | 0/0/0 |
| native_prefix | s2 | t1 | normal | 67 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| native_prefix | s2 | t1 | warband | 2 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| native_prefix | s2 | t1 | ember_hoarder | 1 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| native_prefix | s2 | t1 | guardian | 3 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| native_prefix | s2 | t2 | normal | 20 | 3/4/5 | 0.0% | 3/4/5 | 0.0% | 0/0/0 |
| native_prefix | s2 | t2 | warband | 3 | 5/5/5 | 0.0% | 5/5/5 | 0.0% | 0/0/0 |
| native_prefix | s2 | t2 | last_light | 3 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| native_prefix | s2 | t2 | guardian | 13 | 3/3/3 | 0.0% | 2/2/3 | 0.0% | 0/1/1 |
| native_prefix | s2 | t3 | normal | 74 | 4/5/6 | 9.5% | 4/5/6 | 9.5% | 0/0/0 |
| native_prefix | s2 | t3 | warband | 6 | 6/6/6 | 100.0% | 6/6/6 | 100.0% | 0/0/0 |
| native_prefix | s2 | t3 | umbral_snare | 8 | 2/2/2 | 0.0% | 2/2/2 | 0.0% | 0/0/0 |
| native_prefix | s2 | t3 | last_light | 10 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| native_prefix | s2 | t3 | ember_hoarder | 3 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| native_prefix | s2 | t3 | guardian | 13 | 3/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/1 |
| native_prefix | s2 | t3 | boss | 24 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| native_prefix | s3 | t1 | normal | 61 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| native_prefix | s3 | t1 | warband | 3 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| native_prefix | s3 | t1 | last_light | 1 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| native_prefix | s3 | t1 | ember_hoarder | 2 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| native_prefix | s3 | t1 | guardian | 5 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |
| native_prefix | s3 | t2 | normal | 20 | 3/4/5 | 0.0% | 3/4/5 | 0.0% | 0/0/0 |
| native_prefix | s3 | t2 | last_light | 6 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| native_prefix | s3 | t2 | ember_hoarder | 3 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| native_prefix | s3 | t2 | guardian | 4 | 3/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/1 |
| native_prefix | s3 | t3 | normal | 133 | 3/5/6 | 4.5% | 3/5/6 | 4.5% | 0/0/0 |
| native_prefix | s3 | t3 | warband | 5 | 6/6/6 | 100.0% | 6/6/6 | 100.0% | 0/0/0 |
| native_prefix | s3 | t3 | umbral_snare | 6 | 2/3.5/5 | 0.0% | 2/3.5/5 | 0.0% | 0/0/0 |
| native_prefix | s3 | t3 | last_light | 7 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| native_prefix | s3 | t3 | ember_hoarder | 6 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| native_prefix | s3 | t3 | guardian | 29 | 3/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/1 |
| native_prefix | s3 | t3 | boss | 24 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| native_prefix | s4 | t1 | normal | 66 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| native_prefix | s4 | t1 | last_light | 1 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| native_prefix | s4 | t1 | guardian | 3 | 3/3/3 | 0.0% | 2/2/3 | 0.0% | 0/1/1 |
| native_prefix | s4 | t2 | normal | 25 | 3/4/5 | 0.0% | 3/4/5 | 0.0% | 0/0/0 |
| native_prefix | s4 | t2 | warband | 4 | 5/5/5 | 0.0% | 5/5/5 | 0.0% | 0/0/0 |
| native_prefix | s4 | t2 | last_light | 2 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| native_prefix | s4 | t2 | ember_hoarder | 1 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| native_prefix | s4 | t2 | guardian | 6 | 3/3/3 | 0.0% | 2/2.5/3 | 0.0% | 0/0.5/1 |
| native_prefix | s4 | t3 | normal | 95 | 4/5/6 | 8.4% | 4/5/6 | 8.4% | 0/0/0 |
| native_prefix | s4 | t3 | warband | 6 | 6/6/6 | 100.0% | 6/6/6 | 100.0% | 0/0/0 |
| native_prefix | s4 | t3 | umbral_snare | 6 | 2/2/5 | 0.0% | 2/2/5 | 0.0% | 0/0/0 |
| native_prefix | s4 | t3 | last_light | 6 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| native_prefix | s4 | t3 | ember_hoarder | 9 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| native_prefix | s4 | t3 | guardian | 22 | 3/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/1 |
| native_prefix | s4 | t3 | boss | 24 | 2/2/3 | 0.0% | 2/2/3 | 0.0% | 0/0/0 |
| native_prefix | s5 | t1 | normal | 64 | 2/3/3 | 0.0% | 2/3/3 | 0.0% | 0/0/0 |
| native_prefix | s5 | t1 | guardian | 11 | 2/2/2 | 0.0% | 1/1/1 | 0.0% | 1/1/1 |
| native_prefix | s5 | t2 | normal | 52 | 3/4/5 | 0.0% | 3/4/5 | 0.0% | 0/0/0 |
| native_prefix | s5 | t2 | warband | 3 | 5/5/5 | 0.0% | 5/5/5 | 0.0% | 0/0/0 |
| native_prefix | s5 | t2 | umbral_snare | 3 | 2/2/2 | 0.0% | 2/2/2 | 0.0% | 0/0/0 |
| native_prefix | s5 | t2 | ember_hoarder | 5 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| native_prefix | s5 | t2 | guardian | 11 | 2/2/2 | 0.0% | 1/1/1 | 0.0% | 1/1/1 |
| native_prefix | s5 | t3 | normal | 125 | 4/5/6 | 15.2% | 4/5/6 | 15.2% | 0/0/0 |
| native_prefix | s5 | t3 | warband | 5 | 6/6/6 | 100.0% | 6/6/6 | 100.0% | 0/0/0 |
| native_prefix | s5 | t3 | umbral_snare | 11 | 2/2/2 | 0.0% | 2/2/2 | 0.0% | 0/0/0 |
| native_prefix | s5 | t3 | last_light | 8 | 4/4/4 | 0.0% | 4/4/4 | 0.0% | 0/0/0 |
| native_prefix | s5 | t3 | guardian | 14 | 2/2/2 | 0.0% | 1/1/1 | 0.0% | 1/1/1 |
| native_prefix | s5 | t3 | boss | 32 | 3/3/3 | 0.0% | 3/3/3 | 0.0% | 0/0/0 |


### Every count path that can exceed five

The exhaustive token expansion audit below enumerates each authored normal composition, every supported room element and biome-group choice, then applies production token-preserving concrete trimming. The attached `crowded_catalog.jsonl.gz` retains all qualifying element/biome combinations. Modes explicitly separate Hunted and legacy Reach Exit additions; current k6plus is the maximum-cap normal schedule and current_with_hunted also covers qualifying k4/5 rooms. IDs not listed cannot exceed five under that mode. Additions assume available floor positions. All six terrain TEMPLATE_LIBRARY layouts are count-neutral; any can host an oversized normal/legacy roster.

| Normal composition ID | Depth tier | Picker | Maximum |
|---|---|---|---|
| t1_biome_element | 1 | legacy_picker | 6 |
| t1_biome | 1 | legacy_picker_hunted | 6 |
| t1_biome_element | 1 | legacy_picker_hunted | 7 |
| t1_biome | 1 | legacy_reach_exit | 6 |
| t1_biome_element | 1 | legacy_reach_exit | 7 |
| t1_element | 1 | legacy_reach_exit_hunted | 6 |
| t1_biome | 1 | legacy_reach_exit_hunted | 7 |
| t1_biome_element | 1 | legacy_reach_exit_hunted | 8 |
| t1_warden_biome | 1 | legacy_reach_exit_hunted | 6 |
| t2_element | 2 | current_with_hunted | 6 |
| t2_biome_warden | 2 | current_with_hunted | 6 |
| t2_biome_element | 2 | current_with_hunted | 6 |
| t2_element_pair | 2 | current_with_hunted | 6 |
| t2_biome_support | 2 | current_with_hunted | 6 |
| t2_biome_warden | 2 | legacy_picker | 6 |
| t2_biome_element | 2 | legacy_picker | 7 |
| t2_element_pair | 2 | legacy_picker | 6 |
| t2_biome_support | 2 | legacy_picker | 6 |
| t2_element | 2 | legacy_picker_hunted | 6 |
| t2_biome_warden | 2 | legacy_picker_hunted | 7 |
| t2_biome_element | 2 | legacy_picker_hunted | 8 |
| t2_element_pair | 2 | legacy_picker_hunted | 7 |
| t2_biome_support | 2 | legacy_picker_hunted | 7 |
| t2_warden_pack | 2 | legacy_reach_exit | 6 |
| t2_surgeon_line | 2 | legacy_reach_exit | 6 |
| t2_element | 2 | legacy_reach_exit | 7 |
| t2_biome_warden | 2 | legacy_reach_exit | 8 |
| t2_biome_element | 2 | legacy_reach_exit | 9 |
| t2_element_pair | 2 | legacy_reach_exit | 8 |
| t2_biome_support | 2 | legacy_reach_exit | 8 |
| t2_warden_pack | 2 | legacy_reach_exit_hunted | 7 |
| t2_surgeon_line | 2 | legacy_reach_exit_hunted | 7 |
| t2_element | 2 | legacy_reach_exit_hunted | 8 |
| t2_biome_warden | 2 | legacy_reach_exit_hunted | 9 |
| t2_biome_element | 2 | legacy_reach_exit_hunted | 10 |
| t2_element_pair | 2 | legacy_reach_exit_hunted | 9 |
| t2_biome_support | 2 | legacy_reach_exit_hunted | 9 |
| t3_element | 3 | current_k6plus | 6 |
| t3_biome_element | 3 | current_k6plus | 6 |
| t3_biome_swarm | 3 | current_k6plus | 6 |
| t3_element_pair | 3 | current_k6plus | 6 |
| t3_biome_support | 3 | current_k6plus | 6 |
| t3_full_line | 3 | current_with_hunted | 6 |
| t3_double_warden | 3 | current_with_hunted | 6 |
| t3_element | 3 | current_with_hunted | 7 |
| t3_biome_element | 3 | current_with_hunted | 7 |
| t3_biome_swarm | 3 | current_with_hunted | 7 |
| t3_element_pair | 3 | current_with_hunted | 7 |
| t3_biome_support | 3 | current_with_hunted | 7 |
| t3_element | 3 | legacy_picker | 6 |
| t3_biome_element | 3 | legacy_picker | 7 |
| t3_biome_swarm | 3 | legacy_picker | 7 |
| t3_element_pair | 3 | legacy_picker | 7 |
| t3_biome_support | 3 | legacy_picker | 7 |
| t3_full_line | 3 | legacy_picker_hunted | 6 |
| t3_double_warden | 3 | legacy_picker_hunted | 6 |
| t3_element | 3 | legacy_picker_hunted | 7 |
| t3_biome_element | 3 | legacy_picker_hunted | 8 |
| t3_biome_swarm | 3 | legacy_picker_hunted | 8 |
| t3_element_pair | 3 | legacy_picker_hunted | 8 |
| t3_biome_support | 3 | legacy_picker_hunted | 8 |
| t3_full_line | 3 | legacy_reach_exit | 7 |
| t3_double_warden | 3 | legacy_reach_exit | 7 |
| t3_element | 3 | legacy_reach_exit | 8 |
| t3_biome_element | 3 | legacy_reach_exit | 9 |
| t3_biome_swarm | 3 | legacy_reach_exit | 9 |
| t3_element_pair | 3 | legacy_reach_exit | 9 |
| t3_biome_support | 3 | legacy_reach_exit | 9 |
| t3_full_line | 3 | legacy_reach_exit_hunted | 8 |
| t3_double_warden | 3 | legacy_reach_exit_hunted | 8 |
| t3_element | 3 | legacy_reach_exit_hunted | 9 |
| t3_biome_element | 3 | legacy_reach_exit_hunted | 10 |
| t3_biome_swarm | 3 | legacy_reach_exit_hunted | 10 |
| t3_element_pair | 3 | legacy_reach_exit_hunted | 10 |
| t3_biome_support | 3 | legacy_reach_exit_hunted | 10 |


- **Warband:** all six biome variants (earth, fire, air, ice, lightning, shadow) at local tier 3: captain +5 escorts =6. Tiers 1/2 start at 4/5. Ordered rosters: `data/special_encounters.json /types/warband/variants/*/escort`.
- **Ice Umbral Snare:** three outgoing eligible exits give jailer +2 Sealbinders +3 initial hunters =6. Two exits give5. Other biomes have no initial hunters and start at the eligible exit count (at most three distinct physical exits in these maps).
- **Hunted normal rooms:** any expanded five-unit normal roster becomes6; a six-unit late roster becomes7, when a placement tile is available. This also applies to legacy/mystery fights resolved as ordinary combat. It bypasses the table cap. No Hunted addition applies to special/Guardian/dragon rooms.
- **Legacy Reach Exit:** each five-unit legacy tier-3 pool listed by `_base_encounter_enemy_type_pool` and `_add_element_locked_enemy_type_pools` can start at7 after +2 blockers; tier2 four-unit pools become6. Legacy encounter-table rosters can also exceed5 before/after the +1/+2 exit additions. These objectives do not generate in current revision≥6 normal rooms, but saved legacy rooms retain them. The three base tier-3 rosters and every fire/earth/ice/air tier-3 alternative qualify; all base and elemental tier-2 four-unit alternatives qualify.
- **No other current authored special/Guardian/dragon initial roster exceeds5:** Hoarder4; Last Light4; Guardians2–3 (optional Umbra Depth19 helper adds1); dragons2–3. These bounds count starting flagged helpers too. Mid-fight summons, splits, hunters and survival reinforcements are separate.

The following are **every hard-coded legacy pool roster** that can exceed5 after Reach Exit and/or Hunted. Array order is retained. A dash means that mode does not exceed5. Tier1 hard-coded pools cannot exceed5 even with both additions. These pools are separate from the token-table IDs above.

| Native tier | Pool | Ordered roster | Source line | Normal + Hunted | Reach Exit | Reach Exit + Hunted |
|---|---|---|---|---|---|---|
| 2 | base | warden, crawler, crawler, harrier | `scripts/room_generator.gd:756` | — | 6 | 7 |
| 2 | base | acolyte, harrier, crawler, grave_surgeon | `scripts/room_generator.gd:757` | — | 6 | 7 |
| 2 | base | warden, acolyte, harrier, crawler | `scripts/room_generator.gd:758` | — | 6 | 7 |
| 3 | base | warden, harrier, acolyte, crawler, grave_surgeon | `scripts/room_generator.gd:762` | 6 | 7 | 8 |
| 3 | base | warden, warden, crawler, crawler, harrier | `scripts/room_generator.gd:763` | 6 | 7 | 8 |
| 3 | base | warden, acolyte, harrier, crawler, grave_surgeon | `scripts/room_generator.gd:764` | 6 | 7 | 8 |
| 2 | fire | cinder_ooze, acolyte, harrier, crawler | `scripts/room_generator.gd:784` | — | 6 | 7 |
| 2 | earth | bile_bloomer, crawler, harrier, acolyte | `scripts/room_generator.gd:786` | — | 6 | 7 |
| 2 | ice | warden, crawler, frostglass_lancer, harrier | `scripts/room_generator.gd:788` | — | 6 | 7 |
| 2 | ice | acolyte, harrier, crawler, frostglass_lancer | `scripts/room_generator.gd:789` | — | 6 | 7 |
| 2 | air | chainbound_gaoler, harrier, crawler, crawler | `scripts/room_generator.gd:791` | — | 6 | 7 |
| 3 | fire | warden, cinder_ooze, harrier, crawler, crawler | `scripts/room_generator.gd:795` | 6 | 7 | 8 |
| 3 | earth | bile_bloomer, warden, harrier, crawler, acolyte | `scripts/room_generator.gd:797` | 6 | 7 | 8 |
| 3 | ice | warden, frostglass_lancer, acolyte, crawler, harrier | `scripts/room_generator.gd:799` | 6 | 7 | 8 |
| 3 | ice | warden, warden, crawler, frostglass_lancer, harrier | `scripts/room_generator.gd:800` | 6 | 7 | 8 |
| 3 | ice | warden, acolyte, harrier, frostglass_lancer, crawler | `scripts/room_generator.gd:801` | 6 | 7 | 8 |
| 3 | air | chainbound_gaoler, acolyte, harrier, crawler, crawler | `scripts/room_generator.gd:803` | 6 | 7 | 8 |


Every terrain template is count-neutral and can host the oversized roster paths: `RoomGenerator.TEMPLATE_LIBRARY[0]`, `[1]`, `[2]`, `[3]`, `[4]`, `[5]`. Their exact authored cells are in `scripts/room_generator.gd:59`; templates do not choose or cap the enemy roster.

Actual oversized nodes in the controlled census (every occurrence, all three scenarios) are retained in `oversized_rooms.jsonl.gz`; the following compact table lists every distinct offending kind/encounter ID by scenario, section and depth band.

| Scenario | Section | Depth band | Kind / encounter | Cases >5 | Maximum |
|---|---|---|---|---|---|
| first_eligible | s0 | t3 | warband | 2 | 6 |
| first_eligible | s1 | t3 | warband | 1 | 6 |
| first_eligible | s2 | t3 | warband | 4 | 6 |
| first_eligible | s3 | t3 | warband | 2 | 6 |
| first_eligible | s4 | t3 | warband | 3 | 6 |
| first_eligible | s5 | t3 | warband | 3 | 6 |
| late_k6 | s0 | t3 | t3_biome_element | 8 | 6 |
| late_k6 | s0 | t3 | t3_biome_support | 1 | 6 |
| late_k6 | s0 | t3 | t3_biome_swarm | 1 | 6 |
| late_k6 | s0 | t3 | t3_element | 2 | 6 |
| late_k6 | s0 | t3 | warband | 2 | 6 |
| late_k6 | s1 | t3 | t3_biome_element | 5 | 6 |
| late_k6 | s1 | t3 | t3_biome_swarm | 3 | 6 |
| late_k6 | s1 | t3 | t3_element | 1 | 6 |
| late_k6 | s1 | t3 | t3_element_pair | 3 | 6 |
| late_k6 | s1 | t3 | warband | 1 | 6 |
| late_k6 | s2 | t3 | t3_biome_element | 8 | 6 |
| late_k6 | s2 | t3 | t3_biome_support | 3 | 6 |
| late_k6 | s2 | t3 | t3_biome_swarm | 3 | 6 |
| late_k6 | s2 | t3 | t3_element | 4 | 6 |
| late_k6 | s2 | t3 | warband | 4 | 6 |
| late_k6 | s3 | t3 | t3_biome_element | 9 | 6 |
| late_k6 | s3 | t3 | t3_biome_support | 4 | 6 |
| late_k6 | s3 | t3 | t3_biome_swarm | 4 | 6 |
| late_k6 | s3 | t3 | t3_element | 1 | 6 |
| late_k6 | s3 | t3 | warband | 2 | 6 |
| late_k6 | s4 | t3 | t3_biome_element | 11 | 6 |
| late_k6 | s4 | t3 | t3_biome_support | 6 | 6 |
| late_k6 | s4 | t3 | t3_biome_swarm | 4 | 6 |
| late_k6 | s4 | t3 | t3_element | 4 | 6 |
| late_k6 | s4 | t3 | t3_element_pair | 1 | 6 |
| late_k6 | s4 | t3 | warband | 3 | 6 |
| late_k6 | s5 | t3 | t3_biome_element | 5 | 6 |
| late_k6 | s5 | t3 | t3_biome_support | 3 | 6 |
| late_k6 | s5 | t3 | t3_biome_swarm | 6 | 6 |
| late_k6 | s5 | t3 | t3_element | 4 | 6 |
| late_k6 | s5 | t3 | t3_element_pair | 2 | 6 |
| late_k6 | s5 | t3 | warband | 3 | 6 |
| native_prefix | s0 | t3 | warband | 4 | 6 |
| native_prefix | s1 | t3 | t3_biome_element | 2 | 6 |
| native_prefix | s1 | t3 | t3_biome_swarm | 2 | 6 |
| native_prefix | s1 | t3 | warband | 2 | 6 |
| native_prefix | s2 | t3 | t3_biome_element | 5 | 6 |
| native_prefix | s2 | t3 | t3_element | 2 | 6 |
| native_prefix | s2 | t3 | warband | 6 | 6 |
| native_prefix | s3 | t3 | t3_biome_element | 3 | 6 |
| native_prefix | s3 | t3 | t3_biome_support | 1 | 6 |
| native_prefix | s3 | t3 | t3_biome_swarm | 2 | 6 |
| native_prefix | s3 | t3 | warband | 5 | 6 |
| native_prefix | s4 | t3 | t3_biome_element | 5 | 6 |
| native_prefix | s4 | t3 | t3_element | 3 | 6 |
| native_prefix | s4 | t3 | warband | 6 | 6 |
| native_prefix | s5 | t3 | t3_biome_element | 3 | 6 |
| native_prefix | s5 | t3 | t3_biome_support | 3 | 6 |
| native_prefix | s5 | t3 | t3_biome_swarm | 6 | 6 |
| native_prefix | s5 | t3 | t3_element | 5 | 6 |
| native_prefix | s5 | t3 | t3_element_pair | 2 | 6 |
| native_prefix | s5 | t3 | warband | 5 | 6 |


### Shared section stat schedule

These are existing factors/additions, not proposed tuning. Health first rounds base×local upward, then rounds that integer×section upward; products below are explanatory nominal factors, not a replacement for those two ceilings. The same local schedule applies to normal, objective and Guardian starters before special overrides. Dragons use local step4 (factor1), even though their comparison depth is clamped to t3. Current fixed-point scale is1.

| Section | Section Health factor | Local t1 / t2 / t3 | Dragon local step4 | Damage addition | Support addition | Trap section addition |
|---|---|---|---|---|---|---|
| s0 | 1.00 | 0.85 / 1.00 / 1.12 | 1.00 | 0 | 0 | 0 |
| s1 | 1.08 | 0.85 / 1.00 / 1.12 | 1.00 | 1 | 0 | 1 |
| s2 | 1.16 | 0.85 / 1.00 / 1.12 | 1.00 | 1 | 1 | 1 |
| s3 | 1.24 | 0.85 / 1.00 / 1.12 | 1.00 | 2 | 1 | 2 |
| s4 | 1.32 | 0.85 / 1.00 / 1.12 | 1.00 | 2 | 2 | 2 |
| s5 | 1.40 | 0.85 / 1.00 / 1.12 | 1.00 | 3 | 2 | 3 |


## C. Existing knobs for a stat-only scale

Health already has a shared **local-depth multiplier**, a shared **per-section slope**, base enemy Health, captain/jailer/hoarder relative multipliers and optional Umbra Depth class percentages. Damage currently uses **additive section arrays**, zero local-depth deltas, base action damage, Warband Command and optional Umbra Depth class bonuses; it has **no existing general per-difficulty-tier × section damage-multiplier matrix**. There is likewise no four-difficulty-tier × section Health table. Umbra Depth class selectors distinguish regular/Guardian/dragon, not special-objective tier or section. Normal enemies and special enemies share their base definitions, so base-stat edits alone can affect several tiers.

| Purpose | Exact existing location | Scope / constraint |
|---|---|---|
| Initial Health | `scripts/room_generator.gd:24` | ENEMY_HP_SCALE_PER_SEQUENCE=.08; FLAT_BONUS=0; DEPTH_ONE=.85; DEPTH_THREE=1.12; _scaled_enemy_max_hp applies two ceilings |
| Spawned Health | `scripts/combat_engine.gd:113` | Matching constants and _scaled_enemy_max_hp must stay coherent with RoomGenerator |
| Section damage/support | `scripts/combat_engine.gd:115` | ENEMY_DAMAGE_BONUS_BY_SEQUENCE and ENEMY_SUPPORT_BONUS_BY_SEQUENCE are per-section additions |
| Local damage/support | `scripts/combat_engine.gd:119` | ENEMY_DAMAGE_DELTA_DEPTH_ONE/THREE and ENEMY_SUPPORT_DELTA_DEPTH_ONE/THREE; step2/4 fallback zero |
| Identity base Health / damage | `data/enemies.json:2` | JSON /<id>/max_hp and /<id>/intents/*/actions/*/damage (plus special damage fields); global fixed-point conversion in GameData |
| Warband / Snare / Hoarder | `data/special_encounters.json:31` | JSON /types/warband/captain/hp_multiplier; /types/umbral_snare/jailer/hp_multiplier; /types/ember_hoarder/hoarder/hp_multiplier; Command damage_bonus |
| Optional class Health/damage | `data/depths.json:5` | JSON /levels/*/modifier: enemy_hp_percent, enemy_damage_bonus, boss_enrage; DepthRules.enemy_hp / damage_bonus, not run-section tables |


A later four-tier section matrix would need an explicit tier classifier/context at the existing Health and action-scaling sites, with a defined order relative to captain multipliers and overrides, and consistent spawn propagation. No such matrix, values or design choice is introduced here. Count caps, Warband escort slicing and Hunted additions are independent of these stat knobs.

## Protocol, budget and limitations

Pilot: 36 fights in 144.5s. Remaining full-grid projection with 15% margin: 10468.6s. Selected sections [0, 2, 4]; priority-grid projection 5234.3s. At resume, the full-grid projection exceeded the remaining three-hour budget, so s0/s2/s4 were prioritized; s1/s3/s5 pilot observations remain clearly low-N. Remaining omitted-grid sample: 1126 fights to reach the same repeat target; projected cost 86.6 minutes at pilot throughput with the same margin. This is not a promise of equal workload across sections.

Turn caps (raw): 42; decision-cap fights: 0. Caps count as losses. Median Health lost is the production run_stats.damage_received increment, including damage later healed, over both wins and losses. Turns also include losses. Wilson intervals are fight-level descriptive intervals; seeds share decks and geometry, so these are not cluster-adjusted estimates for future loadouts, rooms or players.

The meas-06 ladder collector (`tools/run_curve_ladder.py`, meas-06 run_curve report) supplies eight saved ladder identities and typed **pre-dragon fight-entry** snapshots per section, reused exactly as in meas-07’s corrected protocol. They are not fresh current-HEAD full-run recoveries or snapshots at every room’s actual arrival time. Current HEAD room/enemy/card/combat factories apply to those fixed fixtures; every measured fight starts at full maximum Health. Thus the report isolates relative fight difficulty conditional on that fixed ladder-entry library, not natural attrition or player win probability. Production choices, deck upgrades, equipment, grafts, items, relics and active omens are retained. No previous fight outcomes are reused. The source ladder continues after loss/cap using an unmeasured forced-victory transition so rewards and deck growth reach later sections; completed_ladder means protocol completion, not survival. This inherited continuation shapes the fixture library.

Selection: first native normal room per depth band; first native Guardian per section; native dragon; objective nodes rotate by (repeat+seed−1) modulo that section’s native objective count in map-step/lane order. The first incoming predecessor in coordinate-string order supplies a real production travel direction. The initial diff-01 planner reused meas-07’s ZERO entrance and failed Snare placement; that discarded planner log is preserved separately. Empty encounter history and k=1/3/5 are controlled contexts, not fully reconstructed routes. Every current normal room asserts Kill All. Raw inputs preserve coordinates, seeds, rosters, constructor payloads and hashes.

Frozen `tools/encounter_bot.gd` and `tools/run_curve_combat.gd` are used unchanged. Their base CombatEngine transitions bypass `scripts/battlefield_rules/committed.gd` acceptance callbacks, including half-Health battlefield phase switches. The meas-07 fidelity caveat therefore also applies to objective/Guardian/dragon rule comparisons. Numbers are relative only; no tuning recommendations or human difficulty conclusions are inferred.

## Proof and reproduction

Exact expanded engine commands, return codes and per-process wall time: [commands.json](commands.json). Collection contract, frozen source hashes and total wall time: [contract.json](contract.json). Fresh outcomes: [runs.jsonl.gz](runs.jsonl.gz). Full native constructor payloads: [inputs.jsonl.gz](inputs.jsonl.gz). Archived fixture provenance: [entry_loadouts.jsonl.gz](entry_loadouts.jsonl.gz). Native-node counts: [inventory.jsonl.gz](inventory.jsonl.gz), extended count sensitivity: [census.jsonl.gz](census.jsonl.gz), every oversized census occurrence: [oversized_rooms.jsonl.gz](oversized_rooms.jsonl.gz), exhaustive table combinations: [crowded_catalog.jsonl.gz](crowded_catalog.jsonl.gz), hard-coded rosters: [legacy_rosters.jsonl.gz](legacy_rosters.jsonl.gz). Logs: [worker_logs.jsonl.gz](worker_logs.jsonl.gz) and [census_logs.jsonl.gz](census_logs.jsonl.gz). Focused check results: [verification.txt](verification.txt). Top-level collection history and resolved setup failures: [collection_history.json](collection_history.json), [discarded_planner.jsonl.gz](discarded_planner.jsonl.gz). Resource audit: [resource_audit.md](resource_audit.md).

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/diff-01 && python3 tools/diff01/collect.py --scratch-dir /private/tmp/labyrinth_codex/diff01-reproduction --output-dir /private/tmp/labyrinth_codex/diff01-reproduction-output --priority-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/diff-01 && python3 tools/diff01/finalize.py --scratch-dir /private/tmp/labyrinth_codex/diff01-reproduction --output-dir /private/tmp/labyrinth_codex/diff01-reproduction-output
cd /Users/borgerding/workspace/Labyrinth.worktrees/diff-01 && python3 tools/diff01/verify.py /private/tmp/labyrinth_codex/diff01-reproduction-output
```

No windowed command, capture or inspection fixture applies: this unit has no visual/player-facing change. No TODO_DESIGN placeholder was needed. Chosen defaults are measurement-only: seeds1–8, repeats0–7, seed stride1000003 (meas-07), first eligible k1/3/5, late-count sensitivity k6, first native normal/Guardian, rotating native specials, coordinate-sorted incoming predecessor, four workers, batch size4, planning timeout600s, count-census timeout300s, audit seed7/section3/band2, unused fallback travel RIGHT, LABYRINTH_CEL_LOOK=off, three-hour wall budget, 120s archival reserve, 15% projection margin and 95% Wilson descriptive intervals (as in meas-07). Combat bounds remain the existing bot’s bounds.
