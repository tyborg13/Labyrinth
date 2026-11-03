# Dragons from growing-deck ladder loadouts — meas-06 feedback 2

**N=24 fights per section**, truncated to the same ordered prefix of complete four-RNG ladder loadouts. Target: 25 saved ladders × 4 RNG seeds = 100 per section; it was not reached because the 40-minute budget included required ladder recovery. Retained complete loadouts: [1, 2, 3, 4, 5, 6]. Recovered ladder seeds: [1, 2, 3, 4, 5, 6, 7, 8, 9]. Raw counts before truncation: {'0': 32, '1': 32, '2': 32, '3': 31, '4': 30, '5': 30}; excluded counts: {'0': 8, '1': 8, '2': 8, '3': 7, '4': 6, '5': 6}.

New measured fights stop launching at 2400 seconds; at most 3 workers. Elapsed including active recovery/fight completion: 2485.9 seconds. All earlier reports and artifacts are unchanged.

## Per section

| Section | Wins/fights | Win rate [95% Wilson CI] | Median Health lost | Turns median [P10, P90] | Median Health left in wins | Caps |
|---:|---:|---|---:|---|---:|---:|
| 0 | 20/24 | 83.3% [64.1, 93.3] | 16 | 6.5 [4.3, 12.5] | 12 | 0 |
| 1 | 14/24 | 58.3% [38.8, 75.5] | 21 | 7.5 [3, 13] | 13.5 | 0 |
| 2 | 12/24 | 50.0% [31.4, 68.6] | 24 | 6 [4, 9.7] | 7.5 | 0 |
| 3 | 12/24 | 50.0% [31.4, 68.6] | 24 | 4 [3, 6] | 6.5 | 0 |
| 4 | 10/24 | 41.7% [24.5, 61.2] | 24 | 3 [2, 6.7] | 10.5 | 0 |
| 5 | 15/24 | 62.5% [42.7, 78.8] | 20 | 7 [3.6, 10] | 9 | 0 |

## Per section and real dragon

| Section | Dragon id / element | Wins/fights | Win rate [95% Wilson CI] | Median Health lost | Turns median [P10, P90] | Median Health left in wins | Caps |
|---:|---|---:|---|---:|---|---:|---:|
| 0 | iskaldra / ice | 3/4 | 75.0% [30.1, 95.4] | 14 | 7.5 [5.6, 8] | 12 | 0 |
| 0 | tharokh / earth | 3/4 | 75.0% [30.1, 95.4] | 13.5 | 16.5 [10.5, 20.4] | 17 | 0 |
| 0 | vaeloryx / air | 7/8 | 87.5% [52.9, 97.8] | 17 | 6.5 [5.7, 8.3] | 8 | 0 |
| 0 | vyraketh / fire | 3/4 | 75.0% [30.1, 95.4] | 20 | 3.5 [3, 4.7] | 6 | 0 |
| 0 | zekarion / lightning | 4/4 | 100.0% [51.0, 100.0] | 10.5 | 6 [5.3, 6.7] | 14.5 | 0 |
| 1 | iskaldra / ice | 0/4 | 0.0% [0.0, 49.0] | 26 | 10.5 [5.9, 14.4] | — | 0 |
| 1 | tharokh / earth | 5/8 | 62.5% [30.6, 86.3] | 18 | 9.5 [8, 13.3] | 15 | 0 |
| 1 | vaeloryx / air | 2/4 | 50.0% [15.0, 85.0] | 20.5 | 3 [2.3, 3.7] | 13 | 0 |
| 1 | vyraketh / fire | 7/8 | 87.5% [52.9, 97.8] | 17 | 5.5 [3.7, 7.3] | 11 | 0 |
| 2 | tharokh / earth | 7/12 | 58.3% [32.0, 80.7] | 22.5 | 8.5 [5.1, 15.4] | 6 | 0 |
| 2 | zekarion / lightning | 5/12 | 41.7% [19.3, 68.0] | 24 | 5.5 [3.1, 6.9] | 9 | 0 |
| 3 | iskaldra / ice | 5/12 | 41.7% [19.3, 68.0] | 24 | 4.5 [4, 6.9] | 14 | 0 |
| 3 | vaeloryx / air | 2/4 | 50.0% [15.0, 85.0] | 21.5 | 4 [3.3, 4] | 6.5 | 0 |
| 3 | vyraketh / fire | 3/4 | 75.0% [30.1, 95.4] | 22 | 3.5 [3, 5.4] | 2 | 0 |
| 3 | zekarion / lightning | 2/4 | 50.0% [15.0, 85.0] | 24 | 3 [2, 5.4] | 3.5 | 0 |
| 4 | iskaldra / ice | 1/4 | 25.0% [4.6, 69.9] | 27 | 4.5 [3, 6.7] | 16 | 0 |
| 4 | vaeloryx / air | 3/8 | 37.5% [13.7, 69.4] | 24 | 3 [2.7, 6.3] | 18 | 0 |
| 4 | vyraketh / fire | 5/8 | 62.5% [30.6, 86.3] | 17 | 4 [2.4, 5.3] | 9 | 0 |
| 4 | zekarion / lightning | 1/4 | 25.0% [4.6, 69.9] | 28 | 2 [2, 5.5] | 12 | 0 |
| 5 | noctyrax / shadow | 15/24 | 62.5% [42.7, 78.8] | 20 | 7 [3.6, 10] | 9 | 0 |

## Comparisons

Dragon win rates by section 0–5 are 83.3% / 58.3% / 50.0% / 50.0% / 41.7% / 62.5%. The final dragon is 12.5 percentage points higher than section 3 (62.5% versus 50.0%). The final dragon is 20.8 percentage points higher than section 4 (62.5% versus 41.7%). The final and section-3 95% Wilson intervals overlap. The final and section-4 95% Wilson intervals overlap.

## Damage-source limits and existing log evidence

The saved ladder records did not contain full pre-dragon loadouts, dragon identity, or a damage-source ledger. The same ladder seeds and best policy were replayed to recover exact production constructor inputs. Each complete recovered ladder was compared against its original full JSON record, and every original-seed dragon result was checked against the old dragon metrics. No gameplay or damage instrumentation was added.

The retained native combat state has a total Health-loss counter, a 12-line text-log tail and at most 256 surface/rule events. Direct damage does not have an exhaustive source-attributed per-hit ledger in that state. Therefore complete shares for dragon direct attacks / dragon rule / surfaces / helpers are **unavailable for every dragon**. The table below reports only existing counters and retained evidence, not a reconstructed four-way attribution.

| Dragon | Fights | Total Health lost | Native hidden-attack Health lost | Fights with hidden loss | Truncated native event windows | Turn caps |
|---|---:|---:|---:|---:|---:|---:|
| iskaldra | 24 | 502 | 0 | 0 | 0 | 0 |
| noctyrax | 24 | 426 | 0 | 0 | 0 | 0 |
| tharokh | 24 | 446 | 2 | 1 | 0 | 0 |
| vaeloryx | 24 | 437 | 0 | 0 | 0 | 0 |
| vyraketh | 24 | 436 | 0 | 0 | 0 | 0 |
| zekarion | 24 | 504 | 0 | 0 | 0 | 0 |

## Bot caveat — evidence, not counterfactual play

Policy v2 uses revealed-intent previews and bounded greedy search. Measured turn caps: 0; decision-cap flags: 0. Caps are losses. Per-dragon counts appear above. The flags above report whether those bounds were reached; no causal effect of unlogged candidate rejection is inferred.

Noctyrax: 20/24 retained final states have at least one unlit brazier; native retained events contain 13 `dragon_light_restored` events. Native Noctyrax hidden-attack Health loss totals 0. The frozen policy's `gain`, `objective_distance` and `option_score` reward damage, kills, survival/Health and Reach Exit progress; they have no explicit light-restoration term. Native state/logs establish actual darkness/relighting and hidden damage, but do not enumerate available and rejected targets. They cannot establish that a particular target was ignored, or what a sight-aware/target-aware alternative would have achieved.

- Logged example seed 2, section 1, repeat 3, tharokh: native hidden-attack Health loss 2; won=False; turns=10. Raw native log tail and event window are retained in `dragons_runs.jsonl.gz`.

### Elemental half-Health rule acceptance is missing from this frozen path

Native end states retain 52 configured `at_half_health` rules; 0 have `half_health_switched=true`. Retained native event windows contain 0 `battlefield_rule_switched` events. In 3 fights the configured source dragon remains alive at exactly 1 Health and its switch is still false. Successful kills can clear the rule from the end state, so these counts are end-state evidence, not a count of every threshold crossing.

The code path explains this observation: `scripts/battlefield_rules/committed.gd` calls `HalfHealth.check` on accepted transitions. The byte-frozen policy and `tools/run_curve_combat.gd` call base CombatEngine card/phase methods without that acceptance callback. `data/battlefield_rules.json` configures half-Health changes for Tharokh, Vyraketh, Vaeloryx, Iskaldra and Zekarion; Noctyrax has none. Thus this is a material simulation-fidelity caveat for the elemental fights. No policy/gameplay change or counterfactual effect size is included in this measurement.

- Native example: ladder seed 2, section 0, repeat 3, vaeloryx, dragon Health 1, switch false, won=False, turns=6.
- Native example: ladder seed 3, section 2, repeat 0, tharokh, dragon Health 1, switch false, won=False, turns=16.
- Native example: ladder seed 6, section 1, repeat 2, vaeloryx, dragon Health 1, switch false, won=False, turns=3.

## Recovery, identity and RNG protocol

- On-demand tools: `tools/run_curve_dragons.py` and `.gd`. The existing whole-run driver gained no-op factory/observation hooks; the recovery subclass observes production `CombatEngine.begin_combat_creation` inputs without changing transitions or policy. Captured layouts and full player snapshots include deck ids, relics, equipment, max Health, omens, skills, Defiance and all other production snapshot fields. Native Variant serialization is round-tripped, and reconstructing the original combat from it is asserted identical to the ladder's initial combat state.
- Repeat 0 is the actual recovered original-RNG dragon fight. Repeats 1–3 call the identical production `create_combat` factory with the same captured layout/snapshot and full current max Health, changing only the combat seed input to `ladder_seed + repeat × 1000003`. Original room geometry, section depth/scaling and dragon identity remain fixed. Every record retains dragon id, element, ladder seed, room coordinate, original geometry room seed (production salt 101), combat seed input and derived combat RNG seed.
- Recovery runs can finish after the launch deadline to validate the saved run, but their dragon fights that start after the deadline are excluded from measurements. Additional RNG fights check the same deadline before creation. All finished measured records remain in the raw archive; tables use the complete common seed prefix across all six sections, rounded down to four-repeat blocks so every retained loadout has equal weight.
- The first five sections can contain different elemental dragons across ladder seeds; the final section is Noctyrax/shadow. The per-section/id table separates the observed identities rather than assuming a single elemental dragon per section.
- Wilson intervals are ordinary 95% binomial intervals over fights. Four RNG repeats share a loadout; these are descriptive fight-level intervals, not cluster-adjusted uncertainty over a new population of ladder loadouts. The comparison is conditional on the section-specific grown loadouts and production section scaling; it does not isolate intrinsic dragon strength from those inputs.
- Health lost is the engine's gross `damage_received` increment, not net Health change after healing; the engine caps each actual Health loss at available Health. Turns use the unchanged 30-turn-cap semantics. P10/P90 use linear interpolation at (n−1)×p. Health remaining is measured immediately after a real fight win, before run rewards/healing.

Frozen `policy_sha256=c90b92005d67d7ea0137e7c35a508bdc8b10d1eee34d70bf7fa4a5d434aa5d82`. Collection-source and prior artifact hashes: `dragons_contract.json`; archived collection Python sources: `dragons_collection_tools.json.gz`. Reporting-only refinements after collection are recorded separately in the contract. Recovery loadouts and native typed payloads: `dragons_loadouts.jsonl.gz`. Native fight records: `dragons_runs.jsonl.gz` (248,717 bytes). Sample/truncation metadata: `dragons_sample.json`. No full suites, windowed Godot, new default-group tests or tuning recommendations.
