# enc-03 — matched revision-7 Slag Mortar measurements

Replays every fire Warband and every generated standard fight containing a Slag Mortar within meas-02’s 200-record baseline per tier/cohort. Identical seed, room, travel direction, policy v2, deck and limits before/after; no roster substitutions. These are baseline subsets, not 200 new fire fights per tier. Lob counts include mark and landing actions (also reported separately). Brace counts resolved block steps; Scatter counts resolved ranged attacks; Retreat counts actual movement steps labelled Retreat, including the retained captain keep_distance move. Preview branches never contribute. HP lost is cumulative damage_received. P10/P90 use nearest rank.

| Tier | Cohort | Phase | N | Win rate | HP lost median (P10–P90) | Turns median (P10–P90) | Lob (mark/land) | Brace | Scatter | Retreat |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | warband | before | 34 | 79.4% | 14.0 (5–26) | 6.5 (5–11) | 104 (63/41) | 133 | 1 | 135 |
| 1 | warband | after | 34 | 79.4% | 15.0 (5–24) | 5.0 (3–7) | 117 (70/47) | 3 | 1 | 55 |
| 1 | standard | before | 4 | 50.0% | 24.5 (7–26) | 6.0 (5–11) | 7 (5/2) | 9 | 1 | 3 |
| 1 | standard | after | 4 | 50.0% | 24.5 (7–26) | 6.0 (5–9) | 14 (6/8) | 0 | 1 | 0 |
| 2 | warband | before | 29 | 62.1% | 14 (2–26) | 8 (2–14) | 99 (62/37) | 127 | 0 | 134 |
| 2 | warband | after | 29 | 62.1% | 18 (2–26) | 6 (2–8) | 126 (72/54) | 1 | 0 | 55 |
| 2 | standard | before | 5 | 40.0% | 24 (8–26) | 9 (4–11) | 18 (10/8) | 13 | 0 | 7 |
| 2 | standard | after | 5 | 40.0% | 24 (12–26) | 10 (4–12) | 34 (14/20) | 0 | 0 | 0 |
| 3 | warband | before | 33 | 45.5% | 24 (8–26) | 4 (2–13) | 75 (46/29) | 137 | 0 | 144 |
| 3 | warband | after | 33 | 33.3% | 24 (9–26) | 3 (2–11) | 156 (76/80) | 1 | 0 | 36 |
| 3 | standard | before | 8 | 25.0% | 25.0 (20–26) | 5.5 (3–12) | 27 (16/11) | 24 | 0 | 10 |
| 3 | standard | after | 8 | 25.0% | 24.0 (10–26) | 4.5 (3–30) | 69 (24/45) | 2 | 1 | 0 |

Historical baseline check: 40 of 113 fresh before replays differ from the stored revision-7 outcomes in at least one of win, HP lost, turns, decisions or preview count. The table compares fresh before/after replays under the same current integration; it does not substitute historical outcomes for the before arm. Raw records retain the historical baseline row for every room. The policy SHA-256 matches meas-02 exactly.

Turn-capped runs count as losses. Nonzero caps: tier 1 warband before: 1; tier 3 warband after: 1; tier 3 standard after: 1. Action mix counts emitted resolver steps, including missed attacks; it does not count damage contacts. The ordinary-fight samples contain 4, 5 and 8 rooms per arm, so their rates have small denominators.
