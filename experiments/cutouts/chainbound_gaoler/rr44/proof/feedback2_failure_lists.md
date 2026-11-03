# rr-44 final full-suite failure lists

The application/runtime implementation was unchanged during the follow-ups. All actual checkout changes remain uncommitted; the real Git index is unchanged.

## Python full run

```text
Ran 2137 tests in 2341.731s
FAILED (failures=1, skipped=66)
```

Errors: 0. Complete failure list:

- `test_godot_sidecars.GodotSidecarRepositoryTests.test_tracked_sources_have_sidecars_and_sidecars_have_sources`

The full run checks the real cached Git inventory, which lacks the round-1 metadata. Thirty-four missing sidecars and three report-only `.gdignore` markers are supplied. The same unchanged test passes on the complete temporary proposed index: `Ran 1 test in 4.803s` / `OK`. No shared index or object database was modified.

## Godot full run

```text
MAIN BODY RUNTIME: 537.214 seconds
MAIN BODY ASSERTIONS: 495687
FULL SUITE RUNTIME: 901.609 seconds (budget 900 seconds)
TEST RESULT: FAIL (58 failure(s))
```

173 child programs passed; 57 failed. Of those, 54 reached the shared deadline, two reached their individual 180s deadlines, and one had menu-input assertions. The remaining failure is the global runtime-budget assertion. Complete root failure list:

```text
Program sub-suite failed: suites/sfx_sync_0_program (exit 124) (timed out)
Program sub-suite failed: suites/sfx_sync_1_program (exit 124) (timed out)
Program sub-suite failed: main_menu_input_test (exit 1)
Program sub-suite failed: prepared_other_character_view_test (exit 124) (timed out)
Program sub-suite failed: retained_character_inventory_equivalence_test (exit 124) (timed out)
Program sub-suite failed: encounter_measurement_test (exit 124) (timed out)
Program sub-suite failed: rr17/runtime_test (exit 124) (timed out)
Program sub-suite failed: rr18/runtime_test (exit 124) (timed out)
Program sub-suite failed: special_encounter_test (exit 124) (timed out)
Program sub-suite failed: special_encounter_legend_test (exit 124) (timed out)
Program sub-suite failed: warband_orders_test (exit 124) (timed out)
Program sub-suite failed: warband_wind_lock_test (exit 124) (timed out)
Program sub-suite failed: wbv_markers_test (exit 124) (timed out)
Program sub-suite failed: warband_orders_probe (exit 124) (timed out)
Program sub-suite failed: warband_test (exit 124) (timed out)
Program sub-suite failed: warband_ui_test (exit 124) (timed out)
Program sub-suite failed: snare_test (exit 124) (timed out)
Program sub-suite failed: snare_ui_test (exit 124) (timed out)
Program sub-suite failed: pass_preview_prewarm_test (exit 124) (timed out)
Program sub-suite failed: petrify_tooltip_test (exit 124) (timed out)
Program sub-suite failed: perf/analytics_restart_test (exit 124) (timed out)
Program sub-suite failed: perf/background_persistence_test (exit 124) (timed out)
Program sub-suite failed: perf/deferred_deadline_test (exit 124) (timed out)
Program sub-suite failed: perf/transition_failure_0_test (exit 124) (timed out)
Program sub-suite failed: perf/transition_failure_1_test (exit 124) (timed out)
Program sub-suite failed: perf/transition_failure_2_test (exit 124) (timed out)
Program sub-suite failed: perf/transition_failure_3_test (exit 124) (timed out)
Program sub-suite failed: perf/combat_frame_scenarios (exit 124) (timed out)
Program sub-suite failed: cache_switch_regression_test (exit 124) (timed out)
Program sub-suite failed: engine_cache_directories_test (exit 124) (timed out)
Program sub-suite failed: battlefield_rules_probe (exit 124) (timed out)
Program sub-suite failed: el02_evidence (exit 124) (timed out)
Program sub-suite failed: element_retrofit_test (exit 124) (timed out)
Program sub-suite failed: element_retrofit_probe (exit 124) (timed out)
Program sub-suite failed: en03_enemies_probe (exit 124) (timed out)
Program sub-suite failed: en05_enemies_probe (exit 124) (timed out)
Program sub-suite failed: en06_enemies_probe (exit 124) (timed out)
Program sub-suite failed: el04_rule_views_test (exit 124) (timed out)
Program sub-suite failed: enemy_no_action_test (exit 124) (timed out)
Program sub-suite failed: fix_11_test (exit 124) (timed out)
Program sub-suite failed: fix_11_probe (exit 124) (timed out)
Program sub-suite failed: fix_12_probe (exit 124) (timed out)
Program sub-suite failed: fix_14_test (exit 124) (timed out)
Program sub-suite failed: fix_14_matrix_test (exit 124) (timed out)
Program sub-suite failed: fix_12_arrival_test (exit 124) (timed out)
Program sub-suite failed: fix_12_reactions_0_test (exit 124) (timed out)
Program sub-suite failed: fix_12_reactions_1_test (exit 124) (timed out)
Program sub-suite failed: fix_12_cascades_test (exit 124) (timed out)
Program sub-suite failed: fix_12_feedback_test (exit 124) (timed out)
Program sub-suite failed: fix_12_bleed_test (exit 124) (timed out)
Program sub-suite failed: short_card_tooltips_test (exit 124) (timed out)
Program sub-suite failed: card_panel_text_test (exit 124) (timed out)
Program sub-suite failed: board_status_plates_test (exit 124) (timed out)
Program sub-suite failed: status_capture_probe (exit 124) (timed out)
Program sub-suite failed: status_plates_performance_probe (exit 124) (timed out)
Program sub-suite failed: rr38/runtime_checks (exit 124) (timed out)
Program sub-suite failed: heirloom_notification_test (exit 124) (timed out)
Full suite stays under 15 minutes
```

## Focused follow-ups

The original 180s child and 900s parent budgets are retained. No assertions were rewritten.

- Three original failures rerun sequentially: both SFX children timed out again; menu reported seven assertions.
- The 54 shared-deadline children rerun with three workers: 35 passed, three reached individual deadlines, two failed to compile, and 14 reached the shared deadline again.
- `rr38/runtime_checks`, run directly afterward: `RR38 RUNTIME: PASS (239 checks; headless registration, views, portraits and clocks)`.
- Current menu with a failure-state logging wrapper: `TEST RESULT: PASS — main menu input and startup transitions`. The wrapper calls the unchanged assertions and retains all deadlines. Its source/hash are stored in `feedback2_results.json`.

Complete failed follow-up child list:

| Program | Exit | Reason |
|---|---:|---|
| `prepared_other_character_view_test` | 124 | 180s deadline |
| `retained_character_inventory_equivalence_test` | 124 | 180s deadline |
| `special_encounter_test` | 124 | 180s deadline |
| `enemy_no_action_test` | 124 | full suite budget exhausted |
| `fix_11_test` | 1 | GameData compile error |
| `fix_11_probe` | 1 | GameData compile error |
| `fix_14_test` | 124 | full suite budget exhausted |
| `fix_12_reactions_0_test` | 124 | full suite budget exhausted |
| `fix_12_reactions_1_test` | 124 | full suite budget exhausted |
| `fix_12_cascades_test` | 124 | full suite budget exhausted |
| `fix_12_feedback_test` | 124 | full suite budget exhausted |
| `fix_12_bleed_test` | 124 | full suite budget exhausted |
| `short_card_tooltips_test` | 124 | full suite budget exhausted |
| `card_panel_text_test` | 124 | full suite budget exhausted |
| `board_status_plates_test` | 124 | full suite budget exhausted |
| `status_capture_probe` | 124 | full suite budget exhausted |
| `status_plates_performance_probe` | 124 | full suite budget exhausted |
| `rr38/runtime_checks` | 124 | full suite budget exhausted |
| `heirloom_notification_test` | 124 | full suite budget exhausted |

## Pinned pre-rr-44 comparison

Reference: `e7913f0df5632595aa0a00566b3e06c3882ceba0`. The isolated project restores the maquette runtime, Gaoler production files and its density/shadow records from that base. Sixteen test/consumer sources are byte-identical. The actual checkout is unchanged. Every restored file hash is in `feedback2_pre_rr44_runtime.json`.

| Program | Exit | Observed result |
|---|---:|---|
| `main_menu_input_test` | 1 | one startup fade assertion |
| `fix_11_test` | 1 | undeclared GameData / failed dependent compilation |
| `fix_11_probe` | 1 | undeclared GameData / failed dependent compilation |
| `suites/sfx_sync_0_program` | 124 | 180s deadline |
| `suites/sfx_sync_1_program` | 124 | 180s deadline |

The current menu passed later without an implementation change. Earlier failures remain in the full and sequential records. The standalone fix11 helper at `tests/suites/enemy_no_action_suite.gd:36` and `:128` has the same SHA-256 in the task base and current checkout. Its assertions and source were left unchanged.

All per-program result rows, log paths, hashes and observed compile/assertion lines are retained in `feedback2_results.json` and the adjacent `feedback2_godot_*.json` files. Fresh native proof is still director-owned.
