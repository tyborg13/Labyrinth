# int-06 integration repair

Implementation stays uncommitted on `codex/int-06`. No publication, task-queue edit, peer review, or windowed run was performed. The starting checkout was clean at `a420283fa`.

## Requirement and merge audit

Archived revisions were executed as separate projects inside this worktree, through the mandatory task runner. The corresponding first-parent and merge logs are retained under `/private/tmp/labyrinth_codex/int-06/history/`. Shared art/font files were linked read-only; scripts, tests, scenes, data and specifications came from the selected revision. The supplemental manifest audit used smaller archived projects with the same original assertion. A newly introduced test can discover zero tests on its first parent; this is recorded as absence, not a passing regression assertion.

| # | Test / acceptance criterion | Introducing merge | Cause | Repair and evidence |
|---|---|---|---|---|
| 1 | Protected `summon_minions` copy and text budget | sum-01 `92ffbfc39` | The approved glossary change outpaced the tt-01 approved-copy registry. Parent budget tests pass; merge rejects the old approval. | Store the exact director-approved copy, its 19-word count, and a sum-01 decision citation. Glossary and full rules are untouched. Godot: `SHORT CARD TOOLTIPS TEST RESULT: PASS (845 checks, 0 failures)`. Python copy/budget checks pass. |
| 2 | No automatic Time panel on card surfaces | card-02 `f621c0737` | Inspection now reads the bound widget's effective summary rows. The test still required the old call spelling. Parent passes; merge fails that assertion. | Assert `Icons.tooltip_entries_for_rows(widget.display_summary_rows())`, retaining the no-Time checks. The shared row-to-tooltip behavior is unchanged. |
| 3 | Threat marker avoids a pill when an alternate is clear | pt15-01 `6a91cde92` | The test demanded a left-side flip; the approved policy slides on the preferred side first. Parent passes; merge fails only that side expectation. | Require a different, clear placement with no fallback overlay; retain whole-obstacle intersection checks. Product placement code is unchanged. `BOARD STATUS PLATES TEST RESULT: PASS (33511 assertions; 0 failures)`. |
| 4 | Register both pt15 suites | pt15-01 `6a91cde92` | The owner-feet wrapper was not in the full-suite manifest, so neither nested library was reachable. Parent audit passes; merge names both missing suites. | Register `pt15_01_owner_feet_check.gd`, which calls owner-feet and its sole-cache suite. `PT15 OWNER FEET RESULT: PASS (55 assertions; 0 failures)`. Registration audit passes. |
| 5 | Preserve every program and required order | first card-02 `f621c0737`, then sum-01/card-01/bos-01 and enc-04 additions | card-02 first invalidates the prefix count (135 versus 131); later additions also disrupt the required suffix. | Preserve the original 131-program prefix and `POST_SNARE_PROGRAMS` tail. Independently guard card-01/card-02's seven entries and a separate eight-entry integration block. All 199 supplemental programs remain, including the aimed-switch and enc-04 tests. |
| 6 | Explain and re-pin only approved golden differences | sum-01 `92ffbfc39`; bos-01 `09afac9ba`; combined enc-03/enc-04 merge | sum-01 adds `pending_summon_card_plays=0` to 54 rooms / 108 snapshots. bos-01's one Thornwall room was already pinned. Seed 421 retained that pair without its new Slag intents. | Extend the enc-04 audit with an exact prior-hash reconstruction before any write. Removing only the zero counter and using pre-enc-03 Slag data for seed 421 reproduces **every** frozen hash. Re-pin only six combat/save hashes; maps and rooms remain byte-identical. `INT06 GOLDEN AUDIT: prior_matches_frozen=true`; `ENCOUNTER MEASUREMENT: PASS (2662 checks; 0 failures)`. No unexplained field was accepted. |
| 7 | Unequal locked-wind inputs must never reuse a stale forecast | sum-01 `92ffbfc39` | This was an intentional whole-state **hash collision** fixture, not a hash-uniqueness assertion. The added counter changes its precomputed hashes. The wind test passes at sum-01's first parent and fails at its merge, before bos-01. | Re-find the collision nonces and retain the exact collision assertion and A/B/A forecast checks. Add a direction-only hash/invalidation check for bos-01. Existing product caching already compares complete owned inputs. `SPX07 WIND COLLISION RESULT: hash=2595233815; hero (2,3) -> (8,8) -> (2,3); locked direction invalidates`. The focused wrapper also reports the separate base formatter error described below. |
| 8 | Spend a one-shot attack bonus exactly once | card-02 `f621c0737` | Extraction moved modifier consumption to a shared helper whose private engine did not own the scene engine's synthetic/legacy effect cache. Parent passes; merge hits the original spend-once assertion. | Pass the scene's combat engine to the shared consumption helper. Existing display callers retain the default engine. Preserve every original sequence/skip/unavailable/selected-prefix assertion. `TEST RESULT: PASS board surface presentation`, with no script/assertion failures. |
| 9 | Unchanged-text refresh stays below 2 ms | Test introduced by card-02; suspected card-01 `2f47eca0d` compared on both sides | Both card-01 parent and merge show timing spikes while retaining zero extra projections/signals; unchanged refresh exits before applying widget text or wrapping. Initial 60-unique Bleed medians: parent 855 µs, merge 813 µs. | Preserve the 2,000 µs threshold and existing layout cache. Standalone serial comparison: the original 60-unique Bleed case passes on both sides (parent median/max 797/1405 µs; merge 837/1445 µs), with zero projections/signals. The merge fails only an unrelated unchanged pile-signature outlier (65 µs median, 9060 µs max); card-01 changes neither refresh helper. The standalone working-tree comparison has three strict maximum failures (Bleed max 2053 µs), retained as timing-instability evidence. The final full-run child then passes every unchanged 2000 µs guard: `CARD DISPLAY CACHE PERFORMANCE RESULT: PASS (0 failures)`; 60-unique Bleed median/max is 948/1325 µs. No threshold is changed. No visual or wrapping change is made. |
| 10 | Continue starts zero hero-attributed rig/image/thread work | pt15-01 `6a91cde92` | New cache-hit and named-shape returns bypassed the injected instrumentation's finish hook. Its open attribution scope charged later renderer work to hero coverage. The parent's zero-runtime mutation control passes; the merge's control fails. Historical whole-module runs also expose the old moving-branch baseline problem. | Wrap the entire private instrumented call so every return closes the scope. Keep all zero-work assertions and all three forbidden-work mutants. Pin accepted baseline bytes to `a420283fa`, with only the precise int-06 caller change allowed. Candidate Continue: `rig=0 image=0 thread=0`; full-run module completes without failures. |
| 11 | Scoped mq-17/mq-18 inventories and foreign-file protection | mq-17 `525f8fb26`, mq-18 `27c6a19f3`, integrating mq-16 `1372c31f4`'s shared renderer | Current-tree globs add `blender/render_plan.py`; mq-16 also changes `blender/render.py`, invalidating receipts sealed on each unit's earlier base. The programs are absent on their respective first parents and fail when introduced. | Derive required inventory membership from each signed unit-end Git inventory. Keep declared own native inputs live; keep foreign/shared and validation-only receipt bytes historical. Preserve current compiled-spec, native-report, delivered-pixel and digest checks. Protect every sealed foreign source, all shared builder/root modules (including additions), and independently discovered foreign figures within each unit's own commit range. Add own-native-source and in-range foreign-edit mutations. mq-17's original 41 tests plus the new source mutation pass; mq-18's 32 tests pass, including stale source, opaque lantern glass, failed comparison, bad digest and missing-entry mutations. |
| 12 | Lamplighter feet and near/far depth turn | mq-18 `27c6a19f3` | Its narrow torso solo does not overlap either arm: the generic probe sees 0/0 despite correct geometry. Parent rear-turn suite passes; merge fails for the new Lamplighter delivery. | Add delivery metadata choosing the existing central mantle solo. Existing genuine near/far label pixels then measure front 1541/2 and rear 0/1202. Keep feet and strict depth inequalities. A front-pasted-as-rear mutation still fails the depth predicate, and invalid metadata is rejected. No geometry, label colours, images or paint-over inputs change. Rear-turn suite: 19 tests, `OK`. |

## Files changed

- Product helper/caller: `scripts/card_display_overrides.gd`, `scripts/run_scene.gd`.
- Approved copy: `spec/peer_benchmark/staged/tt-01/tooltips.json`.
- Golden audit and expectation: `tools/enc04_golden_audit.gd`, `tests/encounter_measurement_test.gd`, `tests/fixtures/encounter_measurement_golden.json`.
- Registration/order: `tests/headless_test_programs.json`, `tests/test_program_suite_runner.py`.
- Existing regressions: `tests/helpers/spx07_cache_ownership_cases.gd`, `tests/suites/board_status_plates_suite.gd`, `tests/test_short_card_tooltips.py`, `tests/test_pt14_04_coverage.py`.
- Maquette validation: `tools/maquette_input_history.py`, `spec/art_identity/maquettes/storm_cantor/regeneration_checks.py`, `spec/art_identity/maquettes/last_lamplighter/regeneration_validation.py`, `tests/test_mq17_maquette.py`, `tests/test_mq18_maquette.py`, `tests/test_int04_preservation.py`, `tests/maquette_preservation.py`.
- Depth proof metadata: `spec/art_identity/maquettes/last_lamplighter/delivery/depth_order_reference.json`, `tests/test_maquette_rear_turn.py`.
- This report: `tests/int06_integration_report.md`.

No dragon, Guardian, Gaoler cutout, `tests/rr46/**`, design-owner source measurements, approved dimensions, geometry or artwork was edited. No test module was added. Existing resource declarations remain accurate: mutations write only unique temporary projects. The resource audit discovers 233 modules.

## Proof results

Final full-suite summaries and standalone timings are appended after execution below. The initial concurrent full Godot attempt retained its complete partial log and ended with `error: command timed out after 1100 seconds.` It progressed through real tests; this was not a launch failure. The first Python pass's three fix18 failures are Continue-transition timeouts before actor checks; its card-legibility failure is the existing 60-second process deadline. Two shards finish, while the others exceed the 2400-second shard ceiling; timeout cleanup then raises `PermissionError: [Errno 1] Operation not permitted` in `os.killpg`. The serial rechecks pass: fix18 `Ran 5 tests ... OK`; card legibility `Ran 1 test ... OK`.

Focused logs, complete historical logs, audit snapshots, serialized performance measurements and reproduction scripts are under `/private/tmp/labyrinth_codex/int-06/`. The guarded re-pin proof is `/private/tmp/labyrinth_codex/int-06/golden-repin/snapshots.json`; the original fixture is recoverable from `a420283fa`.

Other observed checks:

- Final full-run display-performance child: `CARD DISPLAY CACHE PERFORMANCE RESULT: PASS (0 failures)` (7.067 seconds); the spend-once presentation child also passes (9.625 seconds).

- Approved Python copy: `Ran 5 tests ... OK`; text budget: `Ran 6 tests ... OK`.
- Registration: `TEST REGISTRATION AUDIT: PASS (898 scripts; full suite=535, quarantined=29, windowed probe=334)`.
- Manifest guard and mutation checks: `Ran 28 tests ... OK`; order-only check also passes after the final manifest reorder.
- Foreign-range mutation suite: `Ran 13 tests ... OK`.
- Art identity gate: `Ran 111 tests ... OK`; UI identity lint: `Ran 25 tests ... OK`.
- Resource isolation: `ISOLATION AUDIT: 233 modules`.

## TODO_DESIGN and chosen defaults

No `TODO_DESIGN` placeholder was added. No player-visible design value was chosen.

Computed proof-only collision constants are `COLLISION_NONCE_A=34690`, `COLLISION_NONCE_B=27505`, `COLLISION_HASH=2595233815`. Delivery proof metadata uses `body_reference_part="mantle"`. `engine=null` is the helper's compatibility default; the scene explicitly supplies its existing engine. Proof outputs use the task's `/private/tmp/labyrinth_codex/int-06/` directory. Final verification limits `OMP_NUM_THREADS`, `OPENBLAS_NUM_THREADS` and `VECLIB_MAXIMUM_THREADS` to 1 in child processes. Supervisor ceilings are 2400 seconds for the full Godot run and 7200 seconds per Python shard, based on observed valid native-test progress at the earlier ceilings; individual test deadlines, the 900-second program budget and the 2000 µs display threshold are unchanged.

## Proof for the design owner and open issues

No windowed commands or inspection-fixture command are required by this brief: item 3 changes only its stale test expectation, and item 9 changes no layout or visuals. Approved Lamplighter front/rear clay, parts and mantle solos were inspected. No new capture was generated.

An isolated run at the untouched base `a420283fa` reproduces `SCRIPT ERROR: Invalid access to property or key 'center_damage'` at `scripts/action_icon_library.gd:1213`, called by pre-battle move inspection. Its log is `/private/tmp/labyrinth_codex/int-06/base-warband.log`. This enc-04 formatter issue predates int-06 and is outside the named b16 repairs; its assertion/code was not weakened or rewritten. Publication remains the design owner's responsibility.

## Full Godot result

The final harness completed: `MAIN BODY RUNTIME: 781.770 seconds`; `MAIN BODY ASSERTIONS: 495758`; `FULL SUITE RUNTIME: 901.557 seconds (budget 900 seconds)`; `TEST RESULT: FAIL (106 failure(s))`.

There are 105 failed child programs: 104 timeouts (102 exhausted the full-suite budget; two SFX children reached their 180-second ceiling), plus `pre_battle_semantics_test` exiting 1. The remaining failure is the unchanged 15-minute suite-budget assertion. Ninety-seven programs never started before budget exhaustion. The main body and pre-battle child also log the base `center_damage` formatter error. This is **not** a zero-failure full proof; focused acceptance results do not replace the missing full-run coverage. No test or suite budget was relaxed.

Full child results: `/private/tmp/labyrinth_codex/int-06/godot-program-report.json`. Failed children with exact statuses/log paths: `/private/tmp/labyrinth_codex/int-06/godot-failures.json`. Full output: `/private/tmp/labyrinth_codex/int-06/godot-final-recheck.log`.

Failed child list (manifest order):

```text
suites/sfx_sync_0_program — exit 124
suites/sfx_sync_1_program — exit 124
pre_battle_semantics_test — exit 1
prepared_unit_canvas_equivalence_test — exit 124 — full suite budget exhausted
protagonist_gear_motion_gameplay_test — exit 124 — full suite budget exhausted
retained_character_header_equivalence_test — exit 124 — full suite budget exhausted
retained_character_loadout_equivalence_test — exit 124 — full suite budget exhausted
save_resume_boundary_test — exit 124 — full suite budget exhausted
scavenger_cutout_pack_test — exit 124 — full suite budget exhausted
scavenger_resource_cache_test — exit 124 — full suite budget exhausted
shadow_triangulation_equivalence_test — exit 124 — full suite budget exhausted
skill_link_geometry_equivalence_test — exit 124 — full suite budget exhausted
skill_progression_analytics_test — exit 124 — full suite budget exhausted
skill_tree_view_test — exit 124 — full suite budget exhausted
staged_reward_choices_equivalence_test — exit 124 — full suite budget exhausted
start_room_map_test — exit 124 — full suite budget exhausted
stone_warden_cutout_pack_test — exit 124 — full suite budget exhausted
structural_route_equivalence_test — exit 124 — full suite budget exhausted
surface_analytics_batch_test — exit 124 — full suite budget exhausted
surface_parent_review_test — exit 124 — full suite budget exhausted
surface_preview_equivalence_test — exit 124 — full suite budget exhausted
surface_relic_test — exit 124 — full suite budget exhausted
surface_save_migration_test — exit 124 — full suite budget exhausted
tharokh_cutout_pack_test — exit 124 — full suite budget exhausted
ui_components_gallery_fixture_test — exit 124 — full suite budget exhausted
ui_skin_performance_test — exit 124 — full suite budget exhausted
vaeloryx_cutout_pack_test — exit 124 — full suite budget exhausted
veilbound_acolyte_cutout_pack_test — exit 124 — full suite budget exhausted
vyraketh_cutout_pack_test — exit 124 — full suite budget exhausted
zekarion_cutout_pack_test — exit 124 — full suite budget exhausted
prepared_other_character_view_test — exit 124 — full suite budget exhausted
retained_character_inventory_equivalence_test — exit 124 — full suite budget exhausted
shop_retained_content_test — exit 124 — full suite budget exhausted
static_floor_cache_equivalence_test — exit 124 — full suite budget exhausted
maquette_cutout_test — exit 124 — full suite budget exhausted
owned_cpu_asset_preparation_test — exit 124 — full suite budget exhausted
encounter_analytics_test — exit 124 — full suite budget exhausted
encounter_measurement_test — exit 124 — full suite budget exhausted
rr07/runtime_test — exit 124 — full suite budget exhausted
rr12/runtime_test — exit 124 — full suite budget exhausted
rr17/runtime_test — exit 124 — full suite budget exhausted
rr18/runtime_test — exit 124 — full suite budget exhausted
special_encounter_test — exit 124 — full suite budget exhausted
special_encounter_legend_test — exit 124 — full suite budget exhausted
warband_orders_test — exit 124 — full suite budget exhausted
warband_wind_lock_test — exit 124 — full suite budget exhausted
wbv_markers_test — exit 124 — full suite budget exhausted
warband_orders_probe — exit 124 — full suite budget exhausted
warband_test — exit 124 — full suite budget exhausted
warband_ui_test — exit 124 — full suite budget exhausted
snare_test — exit 124 — full suite budget exhausted
snare_ui_test — exit 124 — full suite budget exhausted
summon_card_play_test — exit 124 — full suite budget exhausted
summon_card_play_regression_test — exit 124 — full suite budget exhausted
summon_card_play_probe — exit 124 — full suite budget exhausted
pt15_01_owner_feet_check — exit 124 — full suite budget exhausted
bos01_aimed_switch_test — exit 124 — full suite budget exhausted
enc03_slag_test — exit 124 — full suite budget exhausted
enc03_fixture_test — exit 124 — full suite budget exhausted
enc04_forecast_test — exit 124 — full suite budget exhausted
pass_preview_prewarm_test — exit 124 — full suite budget exhausted
petrify_tooltip_test — exit 124 — full suite budget exhausted
perf/analytics_restart_test — exit 124 — full suite budget exhausted
perf/background_persistence_test — exit 124 — full suite budget exhausted
perf/deferred_deadline_test — exit 124 — full suite budget exhausted
perf/transition_failure_0_test — exit 124 — full suite budget exhausted
perf/transition_failure_1_test — exit 124 — full suite budget exhausted
perf/transition_failure_2_test — exit 124 — full suite budget exhausted
perf/transition_failure_3_test — exit 124 — full suite budget exhausted
perf/combat_frame_scenarios — exit 124 — full suite budget exhausted
cache_switch_regression_test — exit 124 — full suite budget exhausted
engine_cache_directories_test — exit 124 — full suite budget exhausted
battlefield_rules_probe — exit 124 — full suite budget exhausted
el02_evidence — exit 124 — full suite budget exhausted
element_retrofit_test — exit 124 — full suite budget exhausted
element_retrofit_probe — exit 124 — full suite budget exhausted
en03_enemies_probe — exit 124 — full suite budget exhausted
en05_enemies_probe — exit 124 — full suite budget exhausted
en06_enemies_probe — exit 124 — full suite budget exhausted
el04_rule_views_test — exit 124 — full suite budget exhausted
enemy_no_action_test — exit 124 — full suite budget exhausted
fix_11_test — exit 124 — full suite budget exhausted
fix_11_probe — exit 124 — full suite budget exhausted
fix_12_probe — exit 124 — full suite budget exhausted
fix_14_test — exit 124 — full suite budget exhausted
fix_14_matrix_test — exit 124 — full suite budget exhausted
fix_12_arrival_test — exit 124 — full suite budget exhausted
fix_12_reactions_0_test — exit 124 — full suite budget exhausted
fix_12_reactions_1_test — exit 124 — full suite budget exhausted
fix_12_cascades_test — exit 124 — full suite budget exhausted
fix_12_feedback_test — exit 124 — full suite budget exhausted
fix_12_bleed_test — exit 124 — full suite budget exhausted
short_card_tooltips_test — exit 124 — full suite budget exhausted
card_panel_text_test — exit 124 — full suite budget exhausted
board_status_plates_test — exit 124 — full suite budget exhausted
status_capture_probe — exit 124 — full suite budget exhausted
status_plates_performance_probe — exit 124 — full suite budget exhausted
rr38/runtime_checks — exit 124 — full suite budget exhausted
heirloom_notification_test — exit 124 — full suite budget exhausted
fix18/draw_origin_test — exit 124 — full suite budget exhausted
fix18/entry_paths_test — exit 124 — full suite budget exhausted
bos01_route_cases — exit 124 — full suite budget exhausted
bos01_rules_test — exit 124 — full suite budget exhausted
bos01_rule_scene_test — exit 124 — full suite budget exhausted
bos01_rules_probe — exit 124 — full suite budget exhausted
```

## Full Python result and final recheck

The final sharded pass completed with all 233 audited modules:

```text
Ran 2240 tests in 2354.611s
FAILED (failures=1, skipped=66)
```

There are no Python errors. The sole failure is `test_sb02_movement.Movement.test_incremental_submission`: `Movement plan exceeds 4000 us: 48924`. This is outside the original int-06 failure list; its movement-planning product code was not edited. The same check passed in the initial attempt. A subsequent isolated recheck, with the same threshold and no source change, reports:

```text
Ran 1 test in 7.943s
OK
```

The full-run failure remains recorded; the isolated pass does not turn the full pass green. Full output is `/private/tmp/labyrinth_codex/int-06/python-final-recheck.log`; its complete result files are in `python-final-recheck/`; the failure/traceback is also extracted to `/private/tmp/labyrinth_codex/int-06/python-failures.json`. The isolated output is `/private/tmp/labyrinth_codex/int-06/sb02-isolated.log`.

All original Python failure groups from the brief pass in this run. The original Godot acceptance checks pass in their focused runs; the final full-run display-performance and spend-once children also pass. Full Godot coverage remains incomplete because its unmodified program budget expires, and the base formatter error remains. The overall zero-failure proof target is **not achieved**.

Final repository audit: `git diff --check` passes; only the 22 files listed above differ from the clean starting checkout. Everything remains uncommitted. No peer review, inspection fixture, publication or queue update was performed, as assigned to the design owner.

Reproducible full-suite commands (supervisor ceilings allow observed native execution; individual assertions/deadlines are unchanged):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/int-06 && OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 python3 tools/godot_task_runner.py --task-id int-06 --timeout 2400 --stream -- godot --headless --path . --script tests/run_tests.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/int-06 && OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 python3 tools/run_python_suite.py --shards 4 --shard-timeout 7200 --output-dir /private/tmp/labyrinth_codex/int-06/python-final-recheck
```

No windowed proof command is required for these changes under the unit brief. All real-renderer capture paths are therefore not applicable; existing approved Lamplighter images were inspected in `spec/art_identity/maquettes/last_lamplighter/delivery/` (`front_clay.png`, `rear_clay.png`, `front_parts.png`, `rear_parts.png`, `front_solo_mantle.png`, `rear_solo_mantle.png`).
