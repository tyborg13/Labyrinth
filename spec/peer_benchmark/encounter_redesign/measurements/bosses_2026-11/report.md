# Guardians, dragons and matched standard rooms — 2026-11-16

Measured release `d6952d8a66254b0cf9172f0ea616fd628cc037b2`. Zekarion is **the task-start release Zekarion**, before the separate rework unit; no rework data was applied. The local release ref advanced to `f3c2d2b97ea25ab52a8a7af9cf50ac58232e13a6` during the task; the measured data remain the owner-prepared baseline above.

Target N=64 per boss/control cohort (8 ladder-entry loadouts × 8 combat seeds). Budget target N=48 (8 loadouts × 6 combat seeds). **Achieved table N=24** (8 loadouts × 3 complete combat-seed blocks). The initial-batch projection exceeded the remaining 90-minute budget, so the authorized N=48 fallback was used.

Completed 580 raw fights; complete requested sample: **False**. Tables include 576 fights from the common complete prefix; 4 unfinished-block observations remain in the raw archive but are excluded from comparisons. Wall time including setup, the discarded recovery/section-entry attempt, corrected measured fights and archival: **5294.8 seconds (88.25 minutes)**. At most 4 engine workers; limit 90 minutes. Pilot: 24 fights in 210.3 seconds; remaining N=64 projection with scheduling margin: 15234.3 seconds.

## Scope and matching

The five elemental dragons are permuted across sections s0–s4 by the production run seed; Noctyrax is in s5. Guardians follow that section's dragon identity and their native map rooms can occupy different depth tiers. There is no single fixed section/tier for an elemental boss. This report measures each boss across the eight ladders' native placements, with eight corresponding ladder-entry loadouts. A cohort pools those placements; it is **not** an N=64 estimate for every possible boss × section × tier combination. The placement table below makes that distinction explicit. Sections are zero-based here (s0 is the first section).

Each seed's first Guardian in production map-step/lane order and its actual dragon room are used. Each has a standard-room control from the same map and section, at the same clamped native depth tier. The first standard room in map-step/lane order at that tier is selected. All identities, arenas, enemies, room geometry, stats, loot and effects come from release production factories. No boss identity is pinned or transplanted. Controls retain the standard room's native element/biome. Tier 3 dragon controls use native depth band 3; dragons themselves are at depth step 4. This matches tier and section, not absolute depth or enemy roster.

## Boss versus standard-room summary

Positive gaps mean the bot won more often against the boss. Controls are paired by ladder seed, section, tier and combat-repeat index; gaps are percentage points. These are comparisons conditional on the sampled placements and ladder-entry loadouts.

| Boss | Kind | Boss wins/N | Boss win rate | Matched standard wins/N | Standard win rate | Gap (pp) |
|---|---|---:|---:|---:|---:|---:|
| ashen_reaver | guardian | 14/24 | 58.3% | 17/24 | 70.8% | -12.5 |
| craghide | guardian | 22/24 | 91.7% | 22/24 | 91.7% | +0.0 |
| gallows_roc | guardian | 14/24 | 58.3% | 10/24 | 41.7% | +16.7 |
| iskaldra | boss | 13/24 | 54.2% | 7/24 | 29.2% | +25.0 |
| last_lamplighter | guardian | 19/24 | 79.2% | 14/24 | 58.3% | +20.8 |
| noctyrax | boss | 13/24 | 54.2% | 7/24 | 29.2% | +25.0 |
| rimejaw | guardian | 14/24 | 58.3% | 14/24 | 58.3% | +0.0 |
| storm_cantor | guardian | 20/24 | 83.3% | 16/24 | 66.7% | +16.7 |
| tharokh | boss | 15/24 | 62.5% | 16/24 | 66.7% | -4.2 |
| vaeloryx | boss | 13/24 | 54.2% | 10/24 | 41.7% | +12.5 |
| vyraketh | boss | 11/24 | 45.8% | 12/24 | 50.0% | -4.2 |
| zekarion | boss | 10/24 | 41.7% | 11/24 | 45.8% | -4.2 |

## Per-cohort measurements

Intervals are 95% Wilson intervals; half-widths are percentage points. Turns and gross hero Health lost use all fights. Boss Health left uses **only fights ending with hero Health ≤0**, excluding surviving turn-cap losses. A dash means no qualifying death or no boss in a standard room.

| Cohort | Wins/N | Win rate [95% Wilson] | CI half-width (pp) | Median turns | Median hero Health lost | Median boss Health at hero death | Hero deaths | Turn caps |
|---|---:|---|---:|---:|---:|---:|---:|---:|
| ashen_reaver | 14/24 | 58.3% [38.8, 75.5] | 18.35 | 4 | 20.5 | 25 | 10 | 0 |
| craghide | 22/24 | 91.7% [74.2, 97.7] | 11.77 | 7 | 10 | 15.5 | 2 | 0 |
| gallows_roc | 14/24 | 58.3% [38.8, 75.5] | 18.35 | 3 | 17.5 | 26.5 | 10 | 0 |
| iskaldra | 13/24 | 54.2% [35.1, 72.1] | 18.52 | 6.5 | 22.5 | 30 | 11 | 0 |
| last_lamplighter | 19/24 | 79.2% [59.5, 90.8] | 15.61 | 2.5 | 15 | 15 | 5 | 0 |
| noctyrax | 13/24 | 54.2% [35.1, 72.1] | 18.52 | 6 | 19.5 | 21 | 11 | 0 |
| rimejaw | 14/24 | 58.3% [38.8, 75.5] | 18.35 | 3.5 | 21.5 | 11.5 | 10 | 0 |
| standard_for_ashen_reaver | 17/24 | 70.8% [50.8, 85.1] | 17.13 | 5 | 16.5 | — | 7 | 0 |
| standard_for_craghide | 22/24 | 91.7% [74.2, 97.7] | 11.77 | 6.5 | 10 | — | 0 | 2 |
| standard_for_gallows_roc | 10/24 | 41.7% [24.5, 61.2] | 18.35 | 5.5 | 24 | — | 14 | 0 |
| standard_for_iskaldra | 7/24 | 29.2% [14.9, 49.2] | 17.13 | 6 | 24 | — | 17 | 0 |
| standard_for_last_lamplighter | 14/24 | 58.3% [38.8, 75.5] | 18.35 | 3.5 | 13 | — | 8 | 2 |
| standard_for_noctyrax | 7/24 | 29.2% [14.9, 49.2] | 17.13 | 5 | 21 | — | 15 | 2 |
| standard_for_rimejaw | 14/24 | 58.3% [38.8, 75.5] | 18.35 | 5 | 22.5 | — | 10 | 0 |
| standard_for_storm_cantor | 16/24 | 66.7% [46.7, 82.0] | 17.66 | 5 | 16.5 | — | 6 | 2 |
| standard_for_tharokh | 16/24 | 66.7% [46.7, 82.0] | 17.66 | 6 | 22 | — | 8 | 0 |
| standard_for_vaeloryx | 10/24 | 41.7% [24.5, 61.2] | 18.35 | 5 | 24 | — | 13 | 1 |
| standard_for_vyraketh | 12/24 | 50.0% [31.4, 68.6] | 18.57 | 6 | 21.5 | — | 12 | 0 |
| standard_for_zekarion | 11/24 | 45.8% [27.9, 64.9] | 18.52 | 8 | 24 | — | 12 | 1 |
| storm_cantor | 20/24 | 83.3% [64.1, 93.3] | 14.59 | 8.5 | 20 | 20.5 | 4 | 0 |
| tharokh | 15/24 | 62.5% [42.7, 78.8] | 18.07 | 11 | 22 | 34 | 8 | 1 |
| vaeloryx | 13/24 | 54.2% [35.1, 72.1] | 18.52 | 4 | 23 | 21 | 11 | 0 |
| vyraketh | 11/24 | 45.8% [27.9, 64.9] | 18.52 | 4.5 | 23 | 22 | 13 | 0 |
| zekarion | 10/24 | 41.7% [24.5, 61.2] | 18.35 | 4 | 24 | 30.5 | 14 | 0 |

**95% interval half-width >12 points:** `ashen_reaver`, `gallows_roc`, `iskaldra`, `last_lamplighter`, `noctyrax`, `rimejaw`, `standard_for_ashen_reaver`, `standard_for_gallows_roc`, `standard_for_iskaldra`, `standard_for_last_lamplighter`, `standard_for_noctyrax`, `standard_for_rimejaw`, `standard_for_storm_cantor`, `standard_for_tharokh`, `standard_for_vaeloryx`, `standard_for_vyraketh`, `standard_for_zekarion`, `storm_cantor`, `tharokh`, `vaeloryx`, `vyraketh`, `zekarion`.

## Native placement breakdown

Each entry below is `ladder seed: section/tier`. Every listed placement contributes the same number of combat seeds. The eight loadout identities are run seeds 1–8; deck contents may coincide.

| Boss | Native placements |
|---|---|
| ashen_reaver | 1: s4/t2; 2: s4/t3; 3: s1/t1; 4: s1/t1; 5: s3/t2; 6: s0/t2; 7: s2/t2; 8: s3/t1 |
| craghide | 1: s0/t2; 2: s1/t2; 3: s2/t2; 4: s2/t1; 5: s1/t3; 6: s2/t1; 7: s0/t2; 8: s2/t2 |
| gallows_roc | 1: s3/t2; 2: s0/t2; 3: s0/t2; 4: s4/t3; 5: s4/t1; 6: s1/t1; 7: s1/t2; 8: s4/t3 |
| iskaldra | 1: s1/t3; 2: s3/t3; 3: s4/t3; 4: s3/t3; 5: s0/t3; 6: s3/t3; 7: s3/t3; 8: s1/t3 |
| last_lamplighter | 1: s5/t3; 2: s5/t1; 3: s5/t1; 4: s5/t1; 5: s5/t2; 6: s5/t1; 7: s5/t1; 8: s5/t1 |
| noctyrax | 1: s5/t3; 2: s5/t3; 3: s5/t3; 4: s5/t3; 5: s5/t3; 6: s5/t3; 7: s5/t3; 8: s5/t3 |
| rimejaw | 1: s1/t1; 2: s3/t3; 3: s4/t2; 4: s3/t1; 5: s0/t2; 6: s3/t1; 7: s3/t3; 8: s1/t3 |
| storm_cantor | 1: s2/t2; 2: s2/t2; 3: s3/t2; 4: s0/t2; 5: s2/t2; 6: s4/t1; 7: s4/t1; 8: s0/t2 |
| tharokh | 1: s0/t3; 2: s1/t3; 3: s2/t3; 4: s2/t3; 5: s1/t3; 6: s2/t3; 7: s0/t3; 8: s2/t3 |
| vaeloryx | 1: s3/t3; 2: s0/t3; 3: s0/t3; 4: s4/t3; 5: s4/t3; 6: s1/t3; 7: s1/t3; 8: s4/t3 |
| vyraketh | 1: s4/t3; 2: s4/t3; 3: s1/t3; 4: s1/t3; 5: s3/t3; 6: s0/t3; 7: s2/t3; 8: s3/t3 |
| zekarion | 1: s2/t3; 2: s2/t3; 3: s3/t3; 4: s0/t3; 5: s2/t3; 6: s4/t3; 7: s4/t3; 8: s0/t3 |

## Protocol and limits

- The final sample uses the existing `tools/run_curve_dragons.py` loadout library: saved ladder seeds 1–8, with each section's pre-dragon production constructor snapshot recovered by that tool. These are fight-entry loadouts after that section's route, rewards and services, not section-entry decks. The original typed snapshot values are preserved; current release card, equipment, relic, enemy, room and combat definitions apply to every measured fight. The archive hash is in the contract. The original eight ladder records are included as fixture provenance, not claimed as newly recovered current-release runs.
- Measured fights use those archived ladder-entry snapshots independently, with full current maximum Health. Native Variant serialization is round-tripped and hashed. Production RunEngine layout construction supplies equipment drops, omens and encounter-table behavior; CombatEngine supplies the combat state. Standard controls use the first eligible fight number at their tier (1, 3 or 5), empty encounter history, and completed-combat context for later sections or tiers, avoiding first-fight onboarding objectives there. Layout travel direction is the production default `Vector2i.ZERO`; room geometry/loot is fixed per placement across RNG repeats. These are controlled entry-loadout fights, not complete in-run difficulty or win probabilities for humans.
- Combat seed input is `ladder_seed + repeat × 1000003`; native geometry uses the map/run seed. The raw records retain both inputs, the derived combat RNG seed, room seed/coordinate, section, tier, identity, end-state enemy Health, native battlefield rule and decision/cap flags. Health lost is the gross production `damage_received` increment, including damage subsequently healed, rather than net Health change. The unchanged 30-turn cap counts as a loss; a capped surviving hero is not a hero death.
- Wilson intervals treat fights as independent binomial observations. Repeated seeds share loadouts and room geometry, so these descriptive fight-level intervals are not cluster-adjusted uncertainty across future decks, rooms or players. Pooled elemental comparisons also mix the eight sampled natural section placements; the matching controls use exactly the same placement weights. No tuning recommendations or inferred causal effects are included.
- Frozen policy SHA-256: `c90b92005d67d7ea0137e7c35a508bdc8b10d1eee34d70bf7fa4a5d434aa5d82`. Decision-cap fights: 0; turn-cap fights: 11. The existing bot calls base CombatEngine transitions; it does not use the presentation/accepted-transition dispatcher. In particular, `scripts/battlefield_rules/committed.gd` invokes the half-Health rule check outside this frozen bot path. The measurement therefore shares the prior ladder's simulation-fidelity limitation for those rules; no bot behavior was changed to compensate.

## Reproduction and evidence

Exact expanded worker commands, timings and log paths: [commands.json](commands.json). Source hashes, acceptance criteria, budget decision, elapsed time and archive hashes: [contract.json](contract.json). Raw fights: [runs.jsonl.gz](runs.jsonl.gz). Full typed constructor payloads: [inputs.jsonl.gz](inputs.jsonl.gz). Archived ladder-entry snapshots: [entry_loadouts.jsonl.gz](entry_loadouts.jsonl.gz). Original ladder fixture records: [ladders.jsonl.gz](ladders.jsonl.gz). Worker output: [worker_logs.jsonl.gz](worker_logs.jsonl.gz).

From the task worktree, a fresh reproduction is:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/meas-07 && python3 tools/meas07/collect.py --scratch-dir /private/tmp/labyrinth_codex/meas07-reproduction --output-dir /private/tmp/labyrinth_codex/meas07-reproduction-report --archived-loadouts
```

If the pilot selected N=48, the same-deadline budget check for restoring N=64 is:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/meas-07 && python3 tools/meas07/complete64.py --scratch-dir /private/tmp/labyrinth_codex/meas07-reproduction --output-dir /private/tmp/labyrinth_codex/meas07-reproduction-report
```

The corrected collection used `--scratch-dir /private/tmp/labyrinth_codex/meas07-ladder-entry --archived-loadouts`. An initial section-entry protocol was stopped and excluded; its diagnostics are preserved separately in `discarded_section_entry/`. The wall-time clock starts before that attempt's fresh recovery, so the correction does not reset the 90-minute machine budget. Prior fight outcomes are not reused in the final sample; only the existing dragon tool's immutable loadout fixtures are reused. All engine invocations go through `tools/godot_task_runner.py --task-id meas-07 --stream`. No windowed proof, renderer capture or inspection fixture applies to this measurement-only unit; no game files or tests changed.
