# Crowded real boards

Run-hunt seeds and outcomes — 1 (fight_limit), 8 (fight_limit), 12 (victory).

The cohort contains 12 checkpoints. The source campaign reached all four fight kinds.

Section numbers are zero-based.
Old score = stacked tiles + covered tiles + 2 × covered units.
New score = 3 × covered units + covered tiles + piece stacks.
A piece stack has at least two contents, including a unit or board object.
Tied scores favor more living enemies on the board, then more visible pillars.
Tile coverage uses occ-02's 15% floor-diamond test against production rest-pose sprite masks.
Unit coverage uses the union of later silhouettes in painter order, with a strict 25% threshold.
Fixture source campaign — `fel01-round0-diagnostic-9999`.

## Selection rules

- At most one state per boss. 2 distinct bosses among 2 boss states.
- At most 3 dragon and Guardian states combined. Dragon count 2, Guardian count 0.
- At least 7 normal or objective states. Normal count 9, objective count 1.
- One state per fight, identified by seed and room. Selected 12 distinct fights.
- At most 3 states per section. The largest section contribution is 3.

| Section | Normal | Objective | Guardian | Dragon |
|---:|---:|---:|---:|---:|
| 0 | 10 | 2 | 0 | 3 |
| 1 | 7 | 1 | 3 | 3 |
| 2 | 11 | 2 | 1 | 2 |
| 3 | 7 | 1 | 0 | 2 |
| 4 | 9 | 1 | 0 | 1 |
| 5 | 4 | 0 | 1 | 1 |

| Fixture | Seed | Section | Fight | Kind | Boss | Turn | Piece stacks | Covered tiles | Covered units | Old score | New score | Enemies | Pillars | Hover |
|---|---:|---:|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| [01-s0-seed1-0-4_0-t9](fixtures/01-s0-seed1-0-4_0-t9/score.json) | 1 | 0 | 0-4_0 | dragon | tharokh | 9 | 11 | 17 | 0 | 35 | 28 | 1 | 4 | (4, 5) |
| [02-s0-seed12-0-1_3-t7](fixtures/02-s0-seed12-0-1_3-t7/score.json) | 12 | 0 | 0-1_3 | normal | — | 7 | 3 | 15 | 2 | 22 | 24 | 3 | 4 | (3, 3) |
| [03-s2-seed8-2-11_-9-t64](fixtures/03-s2-seed8-2-11_-9-t64/score.json) | 8 | 2 | 2-11_-9 | objective | — | 64 | 1 | 20 | 1 | 23 | 24 | 0 | 4 | (3, 6) |
| [04-s0-seed8-0--3_2-t5](fixtures/04-s0-seed8-0--3_2-t5/score.json) | 8 | 0 | 0--3_2 | normal | — | 5 | 3 | 14 | 2 | 21 | 23 | 4 | 4 | (4, 4) |
| [05-s2-seed1-2-9_-7-t2](fixtures/05-s2-seed1-2-9_-7-t2/score.json) | 1 | 2 | 2-9_-7 | normal | — | 2 | 1 | 10 | 4 | 19 | 23 | 3 | 4 | (5, 2) |
| [06-s2-seed1-2-11_-10-t5](fixtures/06-s2-seed1-2-11_-10-t5/score.json) | 1 | 2 | 2-11_-10 | normal | — | 5 | 2 | 13 | 2 | 19 | 21 | 4 | 4 | (4, 3) |
| [07-s4-seed1-4-19_-19-t4](fixtures/07-s4-seed1-4-19_-19-t4/score.json) | 1 | 4 | 4-19_-19 | normal | — | 4 | 2 | 9 | 3 | 18 | 20 | 3 | 2 | (2, 5) |
| [08-s1-seed8-1-5_-4-t5](fixtures/08-s1-seed8-1-5_-4-t5/score.json) | 8 | 1 | 1-5_-4 | normal | — | 5 | 1 | 13 | 2 | 18 | 20 | 1 | 4 | (5, 5) |
| [09-s3-seed12-3-16_0-t15](fixtures/09-s3-seed12-3-16_0-t15/score.json) | 12 | 3 | 3-16_0 | dragon | zekarion | 15 | 5 | 9 | 2 | 32 | 20 | 1 | 2 | (6, 4) |
| [10-s3-seed12-3-13_-2-t4](fixtures/10-s3-seed12-3-13_-2-t4/score.json) | 12 | 3 | 3-13_-2 | normal | — | 4 | 2 | 14 | 1 | 18 | 19 | 1 | 4 | (4, 4) |
| [11-s4-seed12-4-19_-14-t4](fixtures/11-s4-seed12-4-19_-14-t4/score.json) | 12 | 4 | 4-19_-14 | normal | — | 4 | 4 | 8 | 2 | 16 | 18 | 4 | 1 | (3, 5) |
| [12-s1-seed1-1-7_-3-t3](fixtures/12-s1-seed1-1-7_-3-t3/score.json) | 1 | 1 | 1-7_-3 | normal | — | 3 | 3 | 9 | 2 | 16 | 18 | 3 | 2 | (3, 7) |

## 01-s0-seed1-0-4_0-t9

| Tile | Visible contents | Piece stack | Occluding sprites |
|---|---|---|---|
| (1, 3) | surface rubble | — | terrain:2,4 (32.0%) |
| (1, 4) | boss area telegraph 1 | — | terrain:2,5 (32.0%) |
| (2, 3) | surface rubble, boss area telegraph 1 | — | terrain:3,4 (32.0%) |
| (2, 4) | terrain outcrop_8, boss area telegraph 1 | yes | terrain:3,5 (32.0%) |
| (3, 3) | surface rubble, boss area telegraph 1 | — | unit:player (51.2%) |
| (2, 5) | terrain outcrop_5, boss area telegraph 1 | yes | unit:enemy_1 (61.3%) |
| (3, 4) | terrain outcrop_9, boss area telegraph 1 | yes | unit:player (18.8%), unit:enemy_1 (56.6%) |
| (5, 2) | loot loot_item_0_5_2, surface rubble | yes | — |
| (2, 6) | boss area telegraph 1 | — | unit:enemy_1 (16.4%) |
| (3, 5) | terrain outcrop_6, boss area telegraph 1 | yes | unit:enemy_1 (90.2%) |
| (4, 4) | player [player], surface rubble, boss area telegraph 1 | yes | — |
| (5, 3) | surface rubble | — | terrain:6,4 (32.0%) |
| (3, 6) | surface rubble, boss area telegraph 1 | — | unit:enemy_1 (77.7%) |
| (4, 5) | surface rubble, boss area telegraph 1, battlefield hazard | — | unit:enemy_1 (61.7%) |
| (5, 4) | surface rubble, boss area telegraph 1 | — | terrain:6,5 (32.0%) |
| (4, 6) | Tharokh, the Worldspine [enemy_1], surface rubble | yes | — |
| (5, 5) | surface rubble, boss area telegraph 1, battlefield hazard | — | pillar:7,7 (19.1%) |
| (6, 4) | terrain outcrop_10, boss area telegraph 1 | yes | — |
| (4, 7) | Tharokh, the Worldspine [enemy_1], surface rubble | yes | — |
| (5, 6) | Tharokh, the Worldspine [enemy_1], surface rubble | yes | pillar:7,7 (30.1%) |
| (6, 5) | terrain outcrop_7, boss area telegraph 1 | yes | pillar:7,7 (30.5%) |
| (6, 6) | boss area telegraph 1 | — | pillar:7,7 (95.3%) |

## 02-s0-seed12-0-1_3-t7

| Tile | Visible contents | Piece stack | Occluding sprites |
|---|---|---|---|
| (1, 2) | surface ice | — | pillar:3,4 (19.1%) |
| (1, 3) | surface ice | — | pillar:3,4 (30.1%) |
| (2, 2) | terrain terrain_2_2 | — | unit:player (51.2%), pillar:3,4 (30.5%) |
| (3, 1) | terrain terrain_3_1 | — | pillar:4,2 (95.3%) |
| (2, 3) | Cinder Droplet [enemy_5], Icefall telegraph | yes | pillar:3,4 (95.3%) |
| (3, 2) | surface fire | — | unit:player (18.8%), pillar:4,2 (31.6%) |
| (4, 1) | terrain terrain_4_1 | — | pillar:4,2 (31.6%), unit:enemy_1 (52.0%) |
| (3, 3) | player [player], surface fire, Icefall telegraph | yes | pillar:3,4 (31.6%) |
| (4, 2) | pillar | — | pillar:6,4 (19.1%) |
| (3, 4) | pillar | — | pillar:4,6 (30.5%) |
| (4, 3) | Tunnel Crawler [enemy_4], Icefall telegraph | yes | pillar:6,4 (30.1%) |
| (5, 2) | Hoarfrost Seer [enemy_1] | — | pillar:6,4 (30.5%) |
| (3, 5) | terrain terrain_3_5 | — | pillar:4,6 (95.3%) |
| (3, 6) | trap trap_3_6 | — | pillar:4,6 (31.6%) |
| (4, 5) | surface fire | — | pillar:4,6 (31.6%) |

- Cinder Droplet [enemy_5] at (2, 3) — 100.0% covered.
- player [player] at (3, 3) — 31.7% covered.

## 03-s2-seed8-2-11_-9-t64

| Tile | Visible contents | Piece stack | Occluding sprites |
|---|---|---|---|
| (1, 2) | surface rubble | — | pillar:2,4 (30.5%) |
| (2, 1) | surface rubble | — | pillar:4,2 (30.1%) |
| (1, 3) | surface rubble | — | pillar:2,4 (95.3%) |
| (2, 2) | surface rubble | — | terrain:3,3 (32.0%) |
| (3, 1) | surface rubble | — | pillar:4,2 (95.3%) |
| (1, 4) | terrain outcrop_22 | — | pillar:2,4 (31.6%) |
| (2, 3) | surface rubble | — | pillar:2,4 (31.6%) |
| (3, 2) | surface rubble | — | pillar:4,2 (31.6%) |
| (2, 4) | pillar | — | pillar:4,6 (19.1%) |
| (4, 2) | pillar | — | pillar:6,4 (19.1%) |
| (2, 5) | surface rubble | — | unit:player (51.2%), pillar:4,6 (30.1%) |
| (3, 4) | surface rubble | — | pillar:4,6 (30.5%) |
| (4, 3) | surface rubble | — | pillar:6,4 (30.1%) |
| (5, 2) | surface rubble | — | pillar:6,4 (30.5%) |
| (3, 5) | surface rubble | — | pillar:4,6 (95.3%) |
| (4, 4) | surface rubble | — | terrain:5,5 (32.0%) |
| (5, 3) | surface rubble | — | pillar:6,4 (95.3%) |
| (3, 6) | player [player], surface rubble | yes | pillar:4,6 (31.6%) |
| (4, 5) | surface rubble | — | pillar:4,6 (31.6%) |
| (5, 4) | battlefield hazard | — | pillar:6,4 (31.6%) |

- player [player] at (3, 6) — 29.8% covered.

## 04-s0-seed8-0--3_2-t5

| Tile | Visible contents | Piece stack | Occluding sprites |
|---|---|---|---|
| (1, 1) | Stone Warden [enemy_4] | — | pillar:2,3 (30.5%) |
| (2, 3) | pillar | — | unit:enemy_5 (61.3%) |
| (3, 3) | surface fire | — | unit:player (51.2%), pillar:5,5 (19.1%) |
| (4, 2) | surface fire | — | pillar:5,2 (31.6%) |
| (2, 5) | terrain terrain_2_5 | — | pillar:3,6 (95.3%) |
| (3, 4) | Dust Acolyte [enemy_5], surface fire | yes | pillar:5,5 (30.1%) |
| (4, 3) | surface fire | — | unit:player (18.8%), unit:enemy_3 (33.2%), pillar:5,5 (30.5%) |
| (2, 6) | terrain terrain_2_6 | — | pillar:3,6 (31.6%) |
| (3, 5) | surface fire | — | pillar:3,6 (31.6%) |
| (4, 4) | player [player], surface electrified | yes | pillar:5,5 (95.3%) |
| (5, 3) | surface fire | — | unit:enemy_3 (18.8%), unit:enemy_1 (64.5%) |
| (3, 6) | pillar | — | terrain:4,7 (29.7%) |
| (4, 5) | surface fire | — | pillar:5,5 (31.6%), terrain:5,6 (29.7%) |
| (5, 4) | Cinder Ooze [enemy_3], surface electrified | yes | pillar:5,5 (31.6%) |

- player [player] at (4, 4) — 69.5% covered.
- Cinder Ooze [enemy_3] at (5, 4) — 40.6% covered.

## 05-s2-seed1-2-9_-7-t2

| Tile | Visible contents | Piece stack | Occluding sprites |
|---|---|---|---|
| (1, 2) | terrain terrain_1_2 | — | unit:enemy_1 (39.5%), pillar:3,4 (19.1%) |
| (1, 3) | terrain terrain_1_3 | — | unit:enemy_1 (17.2%), pillar:3,4 (30.1%) |
| (3, 1) | Arc Thrall [enemy_2] | — | pillar:4,2 (95.3%) |
| (2, 3) | Cinder Ooze [enemy_1] | — | pillar:3,4 (95.3%) |
| (4, 2) | pillar | — | unit:player (18.8%), pillar:6,4 (19.1%) |
| (3, 4) | pillar | — | pillar:4,6 (30.5%) |
| (5, 2) | player [player], surface electrified | yes | unit:enemy_3 (63.7%), pillar:6,4 (30.5%) |
| (4, 5) | trap trap_4_5 | — | pillar:4,6 (31.6%) |
| (5, 4) | terrain terrain_5_4 | — | pillar:6,4 (31.6%) |
| (6, 3) | Arc Thrall [enemy_3] | — | pillar:6,4 (31.6%), terrain:7,4 (29.7%) |

- Arc Thrall [enemy_2] at (3, 1) — 58.9% covered.
- Cinder Ooze [enemy_1] at (2, 3) — 81.5% covered.
- player [player] at (5, 2) — 28.4% covered.
- Arc Thrall [enemy_3] at (6, 3) — 32.9% covered.

## 06-s2-seed1-2-11_-10-t5

| Tile | Visible contents | Piece stack | Occluding sprites |
|---|---|---|---|
| (1, 3) | Cinder Ooze [enemy_3] | — | pillar:2,4 (95.3%) |
| (2, 3) | surface electrified | — | pillar:2,4 (31.6%), unit:enemy_1 (55.9%) |
| (3, 2) | Bone Harrier [enemy_5] | — | pillar:4,2 (31.6%), unit:player (51.2%) |
| (2, 4) | pillar | — | pillar:4,6 (19.1%) |
| (3, 3) | surface fire | — | unit:player (18.8%), unit:enemy_2 (61.3%) |
| (4, 2) | pillar | — | pillar:6,4 (19.1%) |
| (2, 5) | terrain terrain_2_5 | — | pillar:4,6 (30.1%) |
| (3, 4) | Arc Thrall [enemy_1] | — | unit:enemy_2 (15.2%), pillar:4,6 (30.5%) |
| (4, 3) | player [player], surface electrified | yes | pillar:6,4 (30.1%) |
| (3, 5) | terrain terrain_3_5 | — | pillar:4,6 (95.3%) |
| (4, 4) | Arc Thrall [enemy_2], surface fire | yes | — |
| (5, 3) | surface fire | — | pillar:6,4 (95.3%) |
| (4, 5) | terrain terrain_4_5 | — | pillar:4,6 (31.6%) |
| (7, 3) | trap trap_7_3 | — | door:8,4 (59.4%) |

- Cinder Ooze [enemy_3] at (1, 3) — 81.5% covered.
- Bone Harrier [enemy_5] at (3, 2) — 55.0% covered.

## 07-s4-seed1-4-19_-19-t4

| Tile | Visible contents | Piece stack | Occluding sprites |
|---|---|---|---|
| (2, 2) | surface fire | — | pillar:3,3 (95.3%) |
| (1, 4) | Tunnel Crawler [enemy_4] | — | unit:player (51.2%), pillar:3,6 (19.1%) |
| (2, 3) | surface fire | — | pillar:3,3 (31.6%) |
| (1, 5) | Lob telegraph | — | unit:player (18.8%), pillar:3,6 (30.1%) |
| (2, 4) | surface fire, Lob telegraph | — | unit:enemy_3 (66.8%), pillar:3,6 (30.5%) |
| (3, 3) | pillar | — | unit:enemy_1 (70.3%) |
| (2, 5) | player [player], Lob telegraph | yes | unit:enemy_3 (18.0%), pillar:3,6 (95.3%) |
| (2, 6) | Lob telegraph | — | pillar:3,6 (31.6%) |
| (3, 5) | Chainbound Gaoler [enemy_3], Lob telegraph | yes | pillar:3,6 (31.6%) |

- Tunnel Crawler [enemy_4] at (1, 4) — 43.4% covered.
- player [player] at (2, 5) — 67.9% covered.
- Chainbound Gaoler [enemy_3] at (3, 5) — 33.5% covered.

## 08-s1-seed8-1-5_-4-t5

| Tile | Visible contents | Piece stack | Occluding sprites |
|---|---|---|---|
| (3, 2) | terrain terrain_3_2 | — | pillar:3,3 (31.6%) |
| (5, 1) | loot loot_item_0_5_1 | — | pillar:5,2 (31.6%) |
| (4, 3) | terrain terrain_4_3 | — | pillar:6,5 (19.1%) |
| (3, 5) | surface ice | — | pillar:3,6 (31.6%) |
| (4, 4) | surface fire | — | unit:player (51.2%), pillar:6,5 (30.1%) |
| (5, 3) | surface fire | — | pillar:6,5 (30.5%) |
| (2, 7) | trap trap_2_7 | — | door:4,8 (18.0%) |
| (4, 5) | surface fire | — | unit:player (18.8%) |
| (5, 4) | surface fire | — | pillar:6,5 (95.3%) |
| (3, 7) | terrain terrain_3_7 | — | door:4,8 (59.4%) |
| (5, 5) | player [player], surface fire | yes | pillar:6,5 (31.6%) |
| (6, 4) | surface fire | — | pillar:6,5 (31.6%) |
| (7, 3) | Cinder Ooze [enemy_1] | — | door:8,4 (59.4%) |

- player [player] at (5, 5) — 29.8% covered.
- Cinder Ooze [enemy_1] at (7, 3) — 33.4% covered.

## 09-s3-seed12-3-16_0-t15

| Tile | Visible contents | Piece stack | Occluding sprites |
|---|---|---|---|
| (6, 1) | surface electrified, battlefield hazard | — | pillar:7,1 (31.6%) |
| (5, 3) | surface electrified, battlefield hazard | — | unit:player (51.2%), unit:enemy_1 (41.8%) |
| (4, 5) | surface electrified, battlefield hazard | — | unit:enemy_1 (46.5%) |
| (5, 5) | loot loot_item_0_5_5 | — | unit:enemy_1 (84.4%), pillar:7,7 (19.1%) |
| (6, 4) | player [player], surface electrified, battlefield hazard | yes | unit:enemy_1 (71.5%) |
| (5, 6) | surface electrified, battlefield hazard | — | unit:enemy_1 (24.2%), pillar:7,7 (30.1%) |
| (6, 5) | Zekarion, the Raging Tempest [enemy_1], surface fire | yes | pillar:7,7 (30.5%) |
| (6, 6) | Zekarion, the Raging Tempest [enemy_1], surface fire | yes | pillar:7,7 (95.3%) |
| (7, 5) | Zekarion, the Raging Tempest [enemy_1], surface fire | yes | — |
| (7, 6) | Zekarion, the Raging Tempest [enemy_1], surface fire | yes | pillar:7,7 (31.6%) |

- player [player] at (6, 4) — 57.1% covered.
- Zekarion, the Raging Tempest [enemy_1] at (6, 5) — 28.3% covered.

## 10-s3-seed12-3-13_-2-t4

| Tile | Visible contents | Piece stack | Occluding sprites |
|---|---|---|---|
| (1, 3) | surface fire | — | pillar:2,4 (95.3%) |
| (1, 4) | surface electrified | — | pillar:2,4 (31.6%) |
| (2, 3) | surface fire | — | pillar:2,4 (31.6%) |
| (3, 2) | loot loot_equipment_static_spurs_3_2, surface fire | yes | pillar:4,2 (31.6%) |
| (2, 4) | pillar | — | pillar:4,6 (19.1%) |
| (3, 3) | surface fire | — | unit:player (51.2%) |
| (4, 2) | pillar | — | pillar:6,4 (19.1%) |
| (3, 4) | surface fire | — | unit:player (18.8%), pillar:4,6 (30.5%) |
| (4, 3) | surface fire | — | pillar:6,4 (30.1%) |
| (3, 5) | surface electrified | — | pillar:4,6 (95.3%) |
| (4, 4) | player [player], surface electrified | yes | unit:enemy_3 (57.8%) |
| (5, 3) | surface fire | — | pillar:6,4 (95.3%) |
| (3, 6) | surface fire | — | pillar:4,6 (31.6%), terrain:4,7 (29.7%) |
| (5, 4) | surface fire | — | pillar:6,4 (31.6%) |

- player [player] at (4, 4) — 28.3% covered.

## 11-s4-seed12-4-19_-14-t4

| Tile | Visible contents | Piece stack | Occluding sprites |
|---|---|---|---|
| (2, 4) | Frostglass Lancer [enemy_1] | — | pillar:4,6 (19.1%) |
| (1, 6) | Dust Acolyte [enemy_5], surface electrified | yes | — |
| (2, 5) | surface ice | — | unit:player (51.2%), pillar:4,6 (30.1%) |
| (2, 6) | surface fire | — | unit:player (18.8%) |
| (3, 5) | Tunnel Crawler [enemy_4], surface fire | yes | pillar:4,6 (95.3%) |
| (2, 7) | loot loot_item_0_2_7, surface ice | yes | door:4,8 (18.0%) |
| (3, 6) | player [player], surface ice | yes | pillar:4,6 (31.6%) |
| (4, 5) | trap trap_4_5 | — | pillar:4,6 (31.6%) |
| (3, 7) | surface fire | — | door:4,8 (59.4%) |

- Tunnel Crawler [enemy_4] at (3, 5) — 100.0% covered.
- player [player] at (3, 6) — 29.8% covered.

## 12-s1-seed1-1-7_-3-t3

| Tile | Visible contents | Piece stack | Occluding sprites |
|---|---|---|---|
| (3, 2) | terrain terrain_3_2 | — | pillar:4,3 (95.3%) |
| (3, 3) | terrain terrain_3_3 | — | pillar:4,3 (31.6%) |
| (3, 4) | terrain terrain_3_4 | — | terrain:4,5 (29.7%), pillar:4,6 (30.5%) |
| (2, 6) | Tunnel Crawler [enemy_3], surface fire | yes | unit:player (18.8%), unit:enemy_1 (57.8%) |
| (3, 5) | terrain terrain_3_5 | — | pillar:4,6 (95.3%) |
| (2, 7) | terrain terrain_2_7 | — | door:4,8 (18.0%) |
| (3, 6) | player [player], surface fire | yes | pillar:4,6 (31.6%) |
| (4, 5) | terrain terrain_4_5 | — | pillar:4,6 (31.6%) |
| (3, 7) | Dust Acolyte [enemy_1], surface fire | yes | door:4,8 (59.4%) |

- Tunnel Crawler [enemy_3] at (2, 6) — 57.5% covered.
- player [player] at (3, 6) — 38.6% covered.
