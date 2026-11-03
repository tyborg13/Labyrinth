# spx-09 measurement: Ember Hoarder beside the Warband and Umbral Snare

Revision 7, meas-02 bot (policy v2, `policy_sha256=c90b92005d67d7ea0137e7c35a508bdc8b10d1eee34d70bf7fa4a5d434aa5d82`), 150 runs per cohort/tier, first seed 1, source HEAD `28e738838b4928fc21873a02c27835b54489c18a` plus the uncommitted int-09 integration (both specials enabled). Values are median (nearest-rank P10–P90), including losses and capped runs. HP lost is cumulative damage_received. Numbers only; tuning is the director's.

| Tier | Cohort | Objective | N | Win rate | Turns | HP lost | Turn caps | Catch rate | Caught turn | Escapes (won after) |
|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | ember_hoarder | kill_leader | 150 | 89.3% | 5 (3–5) | 12 (5–24) | 0 | 5.3% | 3.5 (2–5) | 84.0% (100.0%) |
| 1 | warband | kill_leader | 150 | 76.7% | 7 (4–30) | 10 (1–24) | 16 | — | — | — |
| 1 | umbral_snare | reach_exit | 150 | 82.7% | 3 (1–4) | 2.5 (0–24) | 0 | — | — | — |
| 2 | ember_hoarder | kill_leader | 150 | 92.0% | 4 (4–4) | 11 (4–23) | 0 | 6.7% | 3 (2–4) | 88.7% (97.0%) |
| 2 | warband | kill_leader | 150 | 61.3% | 9 (4–30) | 10 (0–24) | 33 | — | — | — |
| 2 | umbral_snare | reach_exit | 150 | 78.7% | 3 (2–5) | 4 (0–24) | 0 | — | — | — |
| 3 | ember_hoarder | kill_leader | 150 | 90.7% | 4 (3–4) | 12 (4–24) | 0 | 5.3% | 3.5 (2–4) | 86.7% (98.5%) |
| 3 | warband | kill_leader | 150 | 44.7% | 9 (3–30) | 22 (6–26) | 16 | — | — | — |
| 3 | umbral_snare | reach_exit | 150 | 80.7% | 3 (2–5) | 4 (0–24) | 1 | — | — | — |

The Hoarder's objective is recorded as the room's starting objective (kill_leader); after it slips away the same fight continues as Defeat All. Catch rate counts fights where the Hoarder died; caught turn is the hero turn of the catch (catches only). Escapes count fights where it slipped away; the bracket is the share of those still won as Defeat All.

Reproduce: `python3 spec/peer_benchmark/encounter_redesign/measurements/spx-09/measure.py --task-id int-09 --workers 2` from the task worktree.
