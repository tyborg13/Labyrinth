# el-02 implementation handoff

All changes are uncommitted on `codex/el-02`, base HEAD `fb0350327a3c4ae0ef0ac8b313ef7ce3d49210bf`. No commit, branch switch, push, peer review, signoff, queue edit or publication action was performed. The design owner retains commit, review, inspection and publication responsibilities.

## Numbered requirements

1. **Warband rules:** all six captain rows install from `battlefield_rules.json` through the dispatcher. Exact panel sentences are copied into the encounter orders. The Dynamo uses the ordinary three-Charge threshold, Oracle/Thornmother special walls are gone, and Barrage's two authored crosses are retained through the data field `lob_crosses: 2`. Prior hiding beyond two tiles remains. Source death, skipped-turn cadence and intent cadence have direct tests.
2. **Snare rules:** all six room rows use `after_player_turn` instances. Earth raises health-3 Outcrops using the existing exit-lane selector and last-exit guard. Fire starts at the entry and spreads away from it; threshold Ice and Umbra rings remain. Lightning Storm consumes the Electrified field produced by ordinary Thrall strikes. Existing pressure IDs remain stable analytics/save identifiers, rather than effect selectors. Repeated/resumed player boundaries cannot fire twice.
3. **Ordinary enemies:** Thornwall stores marks and resolves through Upheaval at the Weaver's next turn; Icefall retains its marked hit and places Ice ground; Thrall Tether retains its name, Time, partner, length and held geometry while using Lightning Strikes and Electrified ground. The generic `scale_damage: false` action dial preserves the Thrall's old local/sequence damage progression; the existing DepthRules pass is unchanged. No tuning was chosen.
4. **Retirement:** runtime terrain/action kinds, glossary identities, registry aliases, badges/tags and Dive traversal/collision special cases are removed. Grimoire keyword topics derive from the revised glossary. The owned save decoder removes legacy Bramble/Ice Pillar terrain even from current-version saves, and converts held legacy actions without changing intent identity or Time. Event/history data is excluded from migration. One test per retired terrain kind and held-action continuation tests pass. **Excluded view cleanup remains for el-04:** `combat_board_view.gd` still contains unreachable Bramble/Ice Pillar texture/tooltip/drawing branches, and `run_scene.gd` still contains the old `tether_beam` animation dispatch. Their owned mechanic drawing adapters and the old SFX exclusion also remain tied to those unreachable paths. These files/renderer decisions were preserved under the brief's view ownership boundary. Live encounters and loaded saves cannot produce those terrain/action kinds.
5. **Icons/copy:** the five final PNGs are copied byte for byte, registered under their rule names, and tested against `staged/element_rules/icons/provenance.json`. The exact five definitions and Gust definition are installed and mirrored. Bramble/Ice Pillar/Tether mirror entries are deleted. Live glossary total is 147. Two dependent definitions use explicit design placeholders (below).
6. **Wildfire dial:** `lasting` and its dead ground-source writer are removed; Fire retains its existing permanent ground behavior.

The Anchored/immobile checks apply to all units without source, leader, guardian, boss or construct exemptions. The old Sealbinder force exemption was removed as required. Shared primitive source ownership, append-only analytics and ordinary reward behavior remain covered by focused tests. Analytics and enemy-context heuristic assumptions/scorer documentation were updated together; card coefficients are unchanged.

## Verification observed

All Godot launches used `tools/godot_task_runner.py --task-id el-02 --stream -- godot --headless --path . --script ...`. No editor scan or native/windowed launch was attempted. The full suite was not run, per the unit brief's explicit merge-time assignment to the director.

| Program | Exact result line |
|---|---|
| element_retrofit_test.gd | ELEMENT RETROFIT TEST RESULT: PASS (393 checks, 0 failures) |
| battlefield_rules_test.gd | BATTLEFIELD RULES TEST RESULT: PASS (535 checks, 0 failures) |
| warband_orders_test.gd | WARBAND ORDERS TEST RESULT: PASS (287 checks, 0 failures) |
| warband_ui_test.gd | Warband UI semantics: 0 failures |
| snare_test.gd | Snare suite: 0 failures |
| snare_ui_test.gd | Snare UI/fixture suite: 0 failures |
| en02_enemies_test.gd | EN02 ENEMIES TEST RESULT: PASS (156 checks, 0 failures) |
| en03_enemies_test.gd | EN03 ENEMIES TEST RESULT: PASS (211 checks, 0 failures) |
| en04_enemies_test.gd | EN04 ENEMIES TEST RESULT: PASS (353 checks, 0 failures) |
| en05_enemies_test.gd | EN05 ENEMIES TEST RESULT: PASS (171 checks, 0 failures) |
| en06_enemies_test.gd | EN06 ENEMIES TEST RESULT: PASS (178 checks, 0 failures) |
| card_keywords_test.gd | CARD KEYWORDS TEST RESULT: PASS |
| glossary_test.gd (includes tooltip consistency) | GLOSSARY TEST RESULT: PASS (7373 checks, 0 failures) |
| suites/full_scene_controls_program.gd | MAIN DOMAIN ASSERTIONS full_scene_controls_program: 376; TEST RESULT: PASS |
| encounter_measurement_test.gd | ENCOUNTER MEASUREMENT: PASS (2662 checks; 0 failures) |
| element_retrofit_mutations.py | EL02 MUTATION RESULT: PASS (12/12 killed; controls pass; exact source restored) |
| el02_golden_diff.py --record | EL02 GOLDEN DIFF: PASS (7 changed rooms; every field is in a Weaver/Seer/Thrall room; maps/layouts unchanged) |

Python results: icon identity **8 tests, OK**; text budget **6 tests, OK**; registration audit regressions **32 tests, OK**; UI identity **25 tests, OK**; heuristic suites **40 tests, OK**; binding catalog contract **2 tests, OK**. `git diff --check` passed. Registration CLI: `TEST REGISTRATION AUDIT: PASS (813 scripts; full suite=460, quarantined=29, windowed probe=324)`.

Headless probe contracts pass for element_retrofit (31 states), battlefield_rules (5), en02 (8), en04 (9), the en03/en05/en06 check-only fixture modes, and the superseding Warband orders probe (31). Every new GDScript entry point is registered, including `--check-only` modes. No real-renderer proof is claimed.

Authoritative logs: `final-runtime-summary.log`, `final-proof-summary.log`, `seeded-probe-summary.log`, `mutations.log`, the individual program `.log` files, `suites/full_scene_controls_program.log`, `glossary_test.log`, `card_keywords_test.log`, and the Python logs. Earlier diagnostic logs are retained and can contain superseded failures.

## Encounter golden and measurement

`golden-structured-diff.json` contains every changed snapshot field with before/after values and room rosters. Only seven rooms containing a Weaver, Seer or Thrall changed. All map and room-layout hashes are unchanged. Raw snapshots and baseline/candidate hashes are alongside that diff. The golden was renewed only after this gate passed, then the measurement compatibility test passed.

The unchanged spx-01 policy completed both before and after sweeps, 36 rows each. `MEASUREMENT.md` reports median turns, HP lost and win rate per variant/tier against the supplied 3–6 turn / 4–8 HP bands. There is one deterministic observation per row (seed 83); 33 of 36 after rows miss at least one band. This is report-only evidence, not a tuning recommendation or statistical win-rate estimate.

## TODO_DESIGN placeholders

- `TODO_DESIGN_text_glossary_flying`: replacement copy was not supplied after removing its Bramble/Ice Pillar sentence. Placeholder is in live glossary and copy mirror.
- `TODO_DESIGN_text_glossary_icefall`: replacement copy was not supplied after removing its Ice Pillar sentence. Placeholder is in live glossary and copy mirror.
- `TODO_DESIGN_text_royal_bramble`: the card name “Royal Bramble” mentions a retired word. Card data was left unchanged as instructed. No relic or skill text mentions the retired keywords.

The Hoarder remains out of scope; its existing descriptive “tether beam” copy was preserved. The Tether intent name itself is explicitly retained by the brief.

## Chosen defaults (non-player implementation/proof only)

- `SAMPLE_SEED = 83`, `RUNS_PER_ROW = 1`, reused production fixture room specs, existing spx-01 decks/policy/24-HP preset and turn cap. Output phase names `before` and `after`.
- `EXPECTED_STATES = 31`; proof uses the existing en02 production camera/capture harness at 1920×1080, UI scale 1.0. `RULE_PROOF_GROUND` seeds Fire at the Warband source tile and Ice/Electrified at the player tile so ground beats have visible work; these are debug-only fixture changes. Existing region-validation thresholds are reused.
- Native capture timeout 180 seconds for the 31-state probe, 60 seconds for the smaller existing probes. No native run was attempted. The measurement timeout is 3600 seconds for the 36-room workload.
- Legacy-save test fields use 17 HP, turn 4, health-3 ordinary terrain and a private `user://el02-legacy.save`; other fixture positions/health reuse the existing suites. Test count floors were reduced only for removed pillar/lifetime/paint checks and replaced by shared-rule tests.

## Proof for the design owner

No capture PNGs exist from this engineer: the supplied sandbox has no window server. The 31-state probe will emit `user://probes/el02/<case>.png`, including each Warband/Snare before/after beat and Weaver/Seer/Thrall states. The runner result manifest records resolved capture paths. Use fresh manifest names on repeated captures. Inspection creation/verification/launch remains assigned to the design owner after commit.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/el-02 && python3 tools/visual_probe_runner.py --task-id el-02 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --proof-contract tests/proof_contracts/element_retrofit.json --result-manifest proof/el-02/render-manifest.json tests/element_retrofit_probe.gd

cd /Users/borgerding/workspace/Labyrinth.worktrees/el-02 && python3 tools/visual_probe_runner.py --task-id el-02 --no-headless --display-driver macos --audio-driver Dummy --timeout 60 --expect-size 1920x1080 --proof-contract tests/proof_contracts/en02_enemies.json --result-manifest proof/el-02/en02-render-manifest.json tests/en02_enemies_probe.gd

cd /Users/borgerding/workspace/Labyrinth.worktrees/el-02 && python3 tools/visual_probe_runner.py --task-id el-02 --no-headless --display-driver macos --audio-driver Dummy --timeout 60 --expect-size 1920x1080 --proof-contract tests/en04_enemies_probe_contract.json --result-manifest proof/el-02/en04-render-manifest.json tests/en04_enemies_probe.gd

cd /Users/borgerding/workspace/Labyrinth.worktrees/el-02 && python3 tools/inspection_fixture.py --task-id el-02 --run-id el-02-warband-earth --scenario warband --warband-biome earth --warband-tier 2 --seed 83 --manifest proof/el-02/inspection-warband-earth.json --launch

cd /Users/borgerding/workspace/Labyrinth.worktrees/el-02 && python3 tools/inspection_fixture.py --task-id el-02 --run-id el-02-snare-lightning --scenario snare --snare-biome lightning --snare-tier 2 --seed 83 --manifest proof/el-02/inspection-snare-lightning.json --launch
```

## Files changed

The following inventory excludes the proof logs/artifacts in this folder:

- `assets/art/icons/frostbite.png`
- `assets/art/icons/lightning_storm.png`
- `assets/art/icons/shadowstep.png`
- `assets/art/icons/upheaval.png`
- `assets/art/icons/wildfire.png`
- `data/battlefield_rules.json`
- `data/enemies.json`
- `data/glossary.json`
- `data/special_encounters.json`
- `scripts/action_icon_library.gd`
- `scripts/battlefield_rules/dispatcher.gd`
- `scripts/battlefield_rules/outcomes.gd`
- `scripts/battlefield_rules/shadowstep.gd`
- `scripts/battlefield_rules/upheaval.gd`
- `scripts/battlefield_rules/wildfire.gd`
- `scripts/board_surface_rules.gd`
- `scripts/combat_engine.gd`
- `scripts/combat_preview_known_losses.gd`
- `scripts/enemy_intent_compass.gd`
- `scripts/enemy_mechanics/bramble.gd`
- `scripts/enemy_mechanics/capacitor.gd`
- `scripts/enemy_mechanics/capacitor_view.gd`
- `scripts/enemy_mechanics/dive.gd`
- `scripts/enemy_mechanics/icefall.gd`
- `scripts/enemy_mechanics/lob.gd`
- `scripts/enemy_mechanics/tether.gd`
- `scripts/enemy_mechanics/wind.gd`
- `scripts/intent_badges.gd`
- `scripts/pre_battle_threat_tags.gd`
- `scripts/progression_store.gd`
- `scripts/snare_pressure_rules.gd`
- `scripts/warband_combat_rules.gd`
- `spec/analytics.md`
- `spec/card_balance_heuristic.md`
- `spec/icon_identity_policy.md`
- `spec/peer_benchmark/staged/text/glossary_rewrite.json`
- `tests/el02_evidence.gd`
- `tests/el02_golden_diff.py`
- `tests/element_retrofit_mutations.py`
- `tests/element_retrofit_probe.gd`
- `tests/element_retrofit_test.gd`
- `tests/en02_enemies_probe.gd`
- `tests/en02_enemies_test.gd`
- `tests/en03_enemies_probe.gd`
- `tests/en04_bramble_probe_contract.json`
- `tests/en04_enemies_probe.gd`
- `tests/en04_enemies_probe_contract.json`
- `tests/en04_enemies_test.gd`
- `tests/en05_enemies_probe.gd`
- `tests/en06_enemies_probe.gd`
- `tests/fixtures/encounter_measurement_golden.json`
- `tests/headless_test_programs.json`
- `tests/helpers/spx07_cache_ownership_cases.gd`
- `tests/proof_contracts/element_retrofit.json`
- `tests/proof_contracts/en02_enemies.json`
- `tests/snare_probe.gd`
- `tests/suites/battlefield_rules_feedback_suite.gd`
- `tests/suites/battlefield_rules_suite.gd`
- `tests/suites/element_retrofit_suite.gd`
- `tests/suites/en02_enemies_suite.gd`
- `tests/suites/en02_enemy_integration_suite.gd`
- `tests/suites/en03_enemies_suite.gd`
- `tests/suites/en04_enemies_suite.gd`
- `tests/suites/en05_enemies_suite.gd`
- `tests/suites/snare_pressure_boundary_suite.gd`
- `tests/suites/snare_pressure_suite.gd`
- `tests/suites/snare_suite.gd`
- `tests/suites/warband_orders_suite.gd`
- `tests/test_element_rule_contract.py`
- `tests/test_icon_identity_policy.py`
- `tests/text_budget_test.py`
- `tests/warband_orders_probe.gd`
- `tests/warband_orders_test.gd`
- `tests/windowed_test_allowlist.json`
- `tools/card_heuristic.py`
