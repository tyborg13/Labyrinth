# Whole-run difficulty curve — meas-06, 2026-11

Measurement only. Paired seeds 1–78, **N=78 per policy**; default progression, section maps, 24 starting Health, source art. Completed before truncation: {'best': 97, 'random': 96, 'none': 78}; discarded from comparisons: {'best': 19, 'random': 18, 'none': 0}. Wall time 3664.6 seconds; launch budget 3600 seconds, at most 3 workers. An in-flight run may finish after the launch deadline. All completed runs, including any truncated suffix, remain in the raw archive.

Source HEAD `8174a1a0a6acd3be6851a7ab43c4964aa5dc9da3` with the uncommitted measurement harness fingerprinted in `contract.json`. Combat policy v2 unchanged: `policy_sha256=c90b92005d67d7ea0137e7c35a508bdc8b10d1eee34d70bf7fa4a5d434aa5d82`. Map revision [7]; heuristic scores are the production scorer's unrounded totals in `card_scores.json`.

## Reach

| Policy | Section | Entering | Died there | Escaped |
|---|---:|---:|---:|---:|
| best | 0 | 78 | 70 | 0 |
| best | 1 | 8 | 8 | 0 |
| best | 2 | 0 | 0 | 0 |
| best | 3 | 0 | 0 | 0 |
| best | 4 | 0 | 0 | 0 |
| best | 5 | 0 | 0 | 0 |
| random | 0 | 78 | 72 | 0 |
| random | 1 | 6 | 6 | 0 |
| random | 2 | 0 | 0 | 0 |
| random | 3 | 0 | 0 | 0 |
| random | 4 | 0 | 0 | 0 |
| random | 5 | 0 | 0 | 0 |
| none | 0 | 78 | 71 | 0 |
| none | 1 | 7 | 6 | 0 |
| none | 2 | 1 | 1 | 0 |
| none | 3 | 0 | 0 | 0 |
| none | 4 | 0 | 0 | 0 |
| none | 5 | 0 | 0 | 0 |

Escaped is a whole-run escape after the final dragon; died includes the separately counted 30-turn-cap deaths. Section entry is recorded once, at the production section transition, before the next room choice.

## Entry medians

| Policy | Section | Health | Max Health | Deck size | Relics | Equipment |
|---|---:|---:|---:|---:|---:|---:|
| best | 0 | 24 | 24 | 16 | 0 | 5 |
| best | 1 | 7.5 | 24 | 20 | 3 | 5 |
| best | 2 | — | — | — | — | — |
| best | 3 | — | — | — | — | — |
| best | 4 | — | — | — | — | — |
| best | 5 | — | — | — | — | — |
| random | 0 | 24 | 24 | 16 | 0 | 5 |
| random | 1 | 9 | 22 | 20 | 3 | 5 |
| random | 2 | — | — | — | — | — |
| random | 3 | — | — | — | — | — |
| random | 4 | — | — | — | — | — |
| random | 5 | — | — | — | — | — |
| none | 0 | 24 | 24 | 16 | 0 | 5 |
| none | 1 | 14 | 20 | 16 | 3 | 5 |
| none | 2 | 13 | 24 | 18 | 7 | 5 |
| none | 3 | — | — | — | — | — |
| none | 4 | — | — | — | — | — |
| none | 5 | — | — | — | — | — |

Equipment counts occupied equipment slots, excluding the unequipped inventory. A dash means no observations.

## Fights

Each kind cell is wins/fights (win rate). Median Health lost is gross combat damage received, including lethal overkill; net Health change is also retained per fight in the raw data.

| Policy | Section | Fights | Standard | Guardian | Dragon | Warband | Snare | Hoarder | Last Light | Median Health lost |
|---|---:|---:|---|---|---|---|---|---|---|---:|
| best | 0 | 289 | 192/244 (78.7%) | 7/10 (70.0%) | 8/21 (38.1%) | 0/1 (0.0%) | 5/5 (100.0%) | 3/4 (75.0%) | 4/4 (100.0%) | 6 |
| best | 1 | 16 | 8/15 (53.3%) | — | — | — | 0/1 (0.0%) | — | — | 4.5 |
| best | 2 | 0 | — | — | — | — | — | — | — | — |
| best | 3 | 0 | — | — | — | — | — | — | — | — |
| best | 4 | 0 | — | — | — | — | — | — | — | — |
| best | 5 | 0 | — | — | — | — | — | — | — | — |
| random | 0 | 294 | 199/249 (79.9%) | 6/9 (66.7%) | 6/20 (30.0%) | 0/1 (0.0%) | 4/5 (80.0%) | 2/5 (40.0%) | 5/5 (100.0%) | 6 |
| random | 1 | 10 | 4/9 (44.4%) | — | — | — | 0/1 (0.0%) | — | — | 5.5 |
| random | 2 | 0 | — | — | — | — | — | — | — | — |
| random | 3 | 0 | — | — | — | — | — | — | — | — |
| random | 4 | 0 | — | — | — | — | — | — | — | — |
| random | 5 | 0 | — | — | — | — | — | — | — | — |
| none | 0 | 316 | 218/271 (80.4%) | 9/10 (90.0%) | 7/22 (31.8%) | — | 4/5 (80.0%) | 4/5 (80.0%) | 3/3 (100.0%) | 7 |
| none | 1 | 24 | 16/22 (72.7%) | — | 1/1 (100.0%) | — | 1/1 (100.0%) | — | — | 8.5 |
| none | 2 | 1 | 0/1 (0.0%) | — | — | — | — | — | — | 19 |
| none | 3 | 0 | — | — | — | — | — | — | — | — |
| none | 4 | 0 | — | — | — | — | — | — | — | — |
| none | 5 | 0 | — | — | — | — | — | — | — | — |

### Fixed-deck reference (copied from decisions.md, 2026-11-01)

These are fixed-deck standard-fight win rates from meas-04, not whole-run reach rates.

| Tier | s0 | s1 | s2 | s3 | s4 | s5 (shadow) |
|---|---|---|---|---|---|---|
| 1 | 97% | 94% | 92% | 54% | 44% | 18% |
| 2 | 94% | 77% | 38% | 9% | 8% | 0% |
| 3 | 78% | 35% | 18% | 9% | 6% | 2% |

## Comparisons

`best` loses reach fastest at 0→1 (70 runs); its section 2→3 drop cannot be assessed because no run entered section 2. `random` loses reach fastest at 0→1 (72 runs); its section 2→3 drop cannot be assessed because no run entered section 2. `none` loses reach fastest at 0→1 (71 runs); its section 2→3 reach drop is present (1→0).

## Cap deaths and uncovered rooms

| Policy | 30-turn-cap deaths | Uncovered room kind: count |
|---|---:|---|
| best | 12 | graftwright: 9, start: 86 |
| random | 13 | graftwright: 8, start: 84 |
| none | 13 | graftwright: 8, start: 86 |

## Production-transition notes

- Map moves follow the REPL's `move_to_room`; any `pre_battle` state uses `begin_pre_battle_combat`, and exits use `continue_pending_escape`. Dragon rewards use `continue_dragon_reward`; no scene-only transition was required.
- Hearth `rest` in the REPL banks Embers and ends the run. To implement the brief's healing-and-continue intent, this harness uses the REPL's `linger`: `leave_campfire(state, CAMPFIRE_LINGER_HEAL)` (production 4 Health). It is used only below 70% Health. There is no production card-upgrade transition. Production purge removes spells, excluding equipment cards. The catalog has no Strike card and the brief does not identify which starter spells are Strike-tier: `TODO_DESIGN_HEARTH_STRIKE_TIER_CARD_IDS` remains empty. At higher Health the harness therefore leaves. This unresolved mapping limits the measured policy; no removal identity was invented.
- `none` skips card rewards using production `skip_reward_for_heal`, so ordinary skipped fight rewards grant their production 3 Health. The `none` draft also selects no merchant card; every policy can buy at most one equipment piece for an empty slot. Event-granted automatic cards remain production effects for every policy.
- Event eligibility uses the same deterministic production transaction as the event preview: gross current-Health cost must be strictly below 25%, and resulting deck size cannot shrink. The first eligible available choice wins, then leave/last available. Equipment from events or combat is equipped at the next legal loadout opportunity if its slot is empty or its rarity is higher.
- Combat uses the unchanged policy's `choose` and `best_dodge` with its existing bounds, on the actual carried combat state. The loop preserves the frozen helper's turn-cap semantics (up to 30 hero turns). A cap is classified as death in measurement data without inventing a production defeat transition.
- Start-room NPCs and Graftwright services are outside the policy; leave unused and count by room kind. Unknown map rooms rank as events. Below 50% Health, merchants under 60 Embers rank after the listed choices; a sole mandatory exit is always entered.

## First 10 best-run death decks

- Seed 1, section 0: `quick_stab, whirlwind_slash, bloody_lunge, brace, guarded_step, patch_up, shadow_step, sunpath_stride, seek_the_light, lantern_shot, pale_spark, pale_spark, dull_bolt, dull_bolt, waning_pulse, waning_pulse, ball_lightning, earthen_rampart`.
- Seed 2, section 0: `quick_stab, whirlwind_slash, bloody_lunge, brace, guarded_step, patch_up, shadow_step, static_pivot, spur_spark, lantern_shot, pale_spark, pale_spark, dull_bolt, dull_bolt, waning_pulse, waning_pulse, hush_of_winter, icebound_chains, prism_sight, salamander_heart`.
- Seed 3, section 0: `quick_stab, whirlwind_slash, bloody_lunge, brace, guarded_step, patch_up, shadow_step, sidestep_slash, hamstring_shot, lantern_shot, pale_spark, pale_spark, dull_bolt, dull_bolt, waning_pulse, waning_pulse, storm_salvo, crystal_mantle, rockburst`.
- Seed 4, section 0: `riposte_lunge, battle_rhythm, bodkin_arrow, brace, guarded_step, patch_up, shadow_step, sidestep_slash, hamstring_shot, lantern_shot, pale_spark, pale_spark, dull_bolt, dull_bolt, waning_pulse, waning_pulse, skybolt, spike_mantle`.
- Seed 5, section 0: `quick_stab, whirlwind_slash, bloody_lunge, brace, guarded_step, patch_up, shadow_step, sidestep_slash, hamstring_shot, lantern_shot, pale_spark, pale_spark, dull_bolt, dull_bolt, waning_pulse, waning_pulse, fan_the_flames, crystal_mantle`.
- Seed 6, section 0: `quick_stab, whirlwind_slash, bloody_lunge, brace, guarded_step, patch_up, shadow_step, sidestep_slash, hamstring_shot, lantern_shot, pale_spark, pale_spark, dull_bolt, dull_bolt, waning_pulse, waning_pulse`.
- Seed 7, section 0: `windlass_volley, crank_reload, pinning_quarrel, brace, guarded_step, patch_up, shadow_step, sidestep_slash, hamstring_shot, lantern_shot, pale_spark, pale_spark, dull_bolt, dull_bolt, seekers_mark, waning_pulse, salamander_heart, rime_shard`.
- Seed 8, section 0: `quick_stab, whirlwind_slash, bloody_lunge, brace, guarded_step, patch_up, shadow_step, sidestep_slash, hamstring_shot, lantern_shot, pale_spark, pale_spark, dull_bolt, dull_bolt, waning_pulse, waning_pulse, plasma_arc, skybreak_current`.
- Seed 9, section 0: `quick_stab, whirlwind_slash, bloody_lunge, brace, guarded_step, patch_up, shadow_step, sidestep_slash, hamstring_shot, lantern_shot, pale_spark, pale_spark, dull_bolt, dull_bolt, waning_pulse, waning_pulse, glowstone_ward, meteorfall`.
- Seed 10, section 0: `quick_stab, whirlwind_slash, bloody_lunge, brace, guarded_step, patch_up, shadow_step, sidestep_slash, hamstring_shot, lantern_shot, pale_spark, pale_spark, dull_bolt, dull_bolt, waning_pulse, waning_pulse, skybreak_current, cyclone_seal, storm_salvo`.

## Proof and chosen defaults

Focused proof: `tools/run_curve_test.py` runs best/seed 1 twice in isolated task-runner processes, compares complete per-run records, and verifies the frozen policy hash against the revision-7 baseline. Proof artifacts: `determinism.json` and `/private/tmp/labyrinth_codex/meas-06/proof/determinism-{1,2}.log`. No full suites or windowed Godot.

Measurement-only defaults: random draft RNG seed equals the run seed, in a separate RNG stream; score ties and equipment purchase ties keep engine offer order; max 1,000 state transitions is a fault guard that fails the worker rather than classifying a death. Equipment count means occupied slots; gross damage is the fight Health-loss metric. Records flush after every completed run. `TODO_DESIGN_HEARTH_STRIKE_TIER_CARD_IDS` is the sole unresolved design mapping; no new player-visible values.

Raw per-run records: `runs.jsonl.gz` (47,710 bytes; under 5 MB). `contract.json` fingerprints inputs and records acceptance/proof/risk/inspection; `sample.json` records actual sample counts. No tuning recommendations.
