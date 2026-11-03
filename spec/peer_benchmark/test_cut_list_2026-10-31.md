# test-03 — proposed ordinary-pass retirement list

Analysis only · 2026-10-31 · branch `codex/test-03` · source HEAD `3bb79120f643391a8089d4f564692dfcee3f567e`. No tracked files were changed; nothing was deleted; no suites, tests, imports of test modules, Godot, probes, Git writes or peer review were run. The design owner must approve this inventory before implementation.

**Proposal: retire 181 Python module invocations and 124 Godot child invocations; consolidate 27 Python modules, 29 Godot programs and 30 main-body call sites into one manifest-driven test; move 34 Python modules and 25 currently timed Godot programs outside every pass. Keep the 348 existing windowed entries and the one existing Godot perf-only entry ON DEMAND.**

At four shards/child slots, the recorded-duration replay is **8:56.880**, or **9:26.880 with a 30-second implementation/variance reserve**. This meets the under-10-minute target on the supplied timings with 33.120 seconds of headroom. It is a forecast, not an observed result. A 10% slowdown of retained Godot children would yield 10:15.744 including the reserve; there is no evidence here for a machine-independent guarantee.

## 1. Totals and timing method

| Metric | Now, supplied evidence | After proposal, ordinary pass |
|---|---:|---:|
| Python discovered module files | 260 | 19 = 18 KEEP + 1 replacement |
| Python unittest executions | 2,491 | 178 = 177 KEEP + 1 manifest/roster test |
| Python attributed module work, summed across shards | 5710.992 s | 104.048 s, including the replacement budget |
| Python wall time at four shards | 25:36.185 observed | 0:33.028 forecast |
| Godot scheduled test-entry files | 310 = 309 children + `tests/run_tests.gd` | 132 = 131 children + main |
| Godot helper used by the Python replacement | Included in existing per-creature tests | 1 additional entry file, counted only in the Python 30 s budget |
| Named main-body suite calls | 86 | 76 KEEP; 2 MERGE; 8 RETIRE |
| Inline main-body `_test_*` calls | 223 | 147 KEEP; 28 MERGE; 48 RETIRE |
| Initial main-body catalog assertions | 6 | 6 KEEP |
| Godot tests/assertions | 310 execution roots; main reports 499,578 assertions; no complete per-case count | 132 Godot-pass roots, plus 1 nested asset-smoke root; exact assertion count unmeasured |
| Godot child work, summed | 4042.565 s | 1904.691 s |
| Godot main body, concurrent with children | 4:12.814 observed | Conservatively unchanged at 4:12.814 |
| Godot wall time, excluding initial import | 13:56.650 observed | 8:08.641 forecast with four child slots |
| Godot initial import/bootstrap | 15.211 s observed before the full-suite timer | Same 15.211 s allowance |
| Godot wall including import | 14:11.861 observed | 8:23.852 forecast |
| Sequential whole pass, including import | 39:48.046 | 8:56.880 forecast; 9:26.880 reserved plan |

“Files” above means selected test entry files, not every helper, fixture, archived script or source file under `tests/`. The tables classify 260 timed Python modules, 309 timed Godot child programs, all 86 direct main suites, all 223 inline main tests, all 348 windowed entries, and the untimed perf entry. Helpers inherit their caller’s scope; their source cannot be deleted while a KEEP caller still imports it. Physical repository file totals after deletion cannot be stated from entry counts: several RETIRE files supply helpers to KEEP programs. This analysis itself leaves the physical tree unchanged.

The Godot runner has no uniform unittest-style test-case total. Its log mixes assertion counts, generated sample counts and programs; summing those would invent a “test count.” For example, `full_scene_cutouts_program` alone reports 646,910 transform/data assertions. These are not 646,910 independently named gameplay tests. The report therefore gives exact scheduled roots and main call counts, and reports the assertion-count limit explicitly.

Disposition totals for the supplied timed inventory:

| Category | Python files | Python executions | Python module-seconds | Godot children | Godot child-seconds | Named main suites | Inline main tests |
|---|---:|---:|---:|---:|---:|---:|---:|
| KEEP | 18 | 177 | 74.048 | 131 | 1904.691 | 76 | 147 |
| MERGE | 27 | 90 | 119.803 | 29 | 108.611 | 2 | 28 |
| RETIRE | 181 | 1702 | 5186.716 | 124 | 1340.030 | 8 | 48 |
| ON DEMAND | 34 | 522 | 330.426 | 25 | 689.233 | 0 | 0 |

The after-counts include only KEEP plus the replacement. MERGE does not mean “run old files too.” ON DEMAND is outside the ordinary pass, outside `--all-groups`, and outside automatic pre-playtest full passes; it remains explicitly callable for the relevant work or pre-release inspection. RETIRE means remove the invocation/assertion policy and delete a file only after its live imports are accounted for. Approved art, authoring inputs, existing fixtures needed for saves, and provided design-owner files are not deletion candidates.

Timing calculation and evidence limits:

- Python: the four recorded shard durations are 1423.024, 1433.414, 1319.862, 1534.760 seconds. The summary is 1536.185 seconds. Retained modules use the existing resource/import audit; there are no connected retained-module write/import groups. The only retained resource declaration is `test_godot_sidecars` → `capacitor`, with no other retained writer. LPT replay, including a 30 s merged-module budget, gives shard loads 31.603, 30.000, 21.638, 20.806 seconds. Add 1.425 s of observed launch/summary overhead.
- Godot: `PROGRAM SUITE RUNTIME` appears exactly 309 times and sums to 4042.565 seconds; `MAIN BODY RUNTIME` is 252.814 s; `FULL SUITE RUNTIME` is 836.650 s; retries are empty. The main starts the child pool before executing its own assertions. Do not add main duration to child makespan. FIFO replay of retained children in their current order on four slots gives 488.641, 468.615, 483.949, 463.486 s, so use `max(main, slowest child lane)` plus import. No savings are credited for removing main suites or for removing visual assertions within mixed KEEP programs.
- The observed Godot pass did not document a four-slot limit. Its aggregate work/wall ratio requires at least five overlapping child slots; the runner permits up to six, depending on CPU count. The forecast deliberately replays four child slots. Python `--shards 4` does not configure Godot’s child count. This is an arithmetic replay, not a new performance measurement.
- All category-table seconds are existing elapsed module/child durations, not exclusive CPU times and not independently subtractable wall savings. Main-suite and windowed timings are **— = unmeasured**, not zero. Three decimal places preserve input accounting; values that round to 0.000 are small measured values, not omitted rows.
- `test_mq13_delivery` discovers 10 imported `DeliveryValidationTests` in addition to its own 5 executions; `test_text_budget` discovers 6 imported executions. Those 16 are attributed to the discovering modules. `test_steam_performance_stats_schema.py` discovers **0** unittest executions: its assertions live under `main()`. The input records 66 skips, zero errors and zero failures; the 2,491 count includes skips. The owner’s ~88 stale failures over prior audits are brief-provided context, not another audit performed here.

### If the owner’s measured pass still misses ten minutes

This list does not miss the target in the replay, but its reserved headroom is only 33.120 s. A measured excess of `x` wall seconds would require roughly `4*x` child-seconds to leave the critical pool, or a reduction on the actual slowest Python shard; removing tiny tests elsewhere will not help.

The next available cut is sampling breadth, not another round of gameplay-test deletion: move the two exhaustive 200-seed revision-3/4 legacy-hash programs (53.349 measured child-seconds combined) ON DEMAND **only after** keeping explicit revision-3/4 pre-change hash/save cases in the existing KEEP save/map suite. Keep the current revision-5/6 migration cases too. That replacement’s duration is unknown; do not subtract all 53.349 s as verified savings. If more margin is needed, reduce the 64-seed revision-4 route sweep in `section_map_v2_test.gd` (40.209 s today) to targeted legacy save/route cases, leaving exhaustive sampling ON DEMAND. These changes lose coverage of uncommon old-save seeds and need the owner’s approval. Do not meet a stopwatch by removing combat, reward, migration or analytics semantics. A new timing pass after approved implementation is required to confirm the target; none is authorized in this unit.

## 2. Complete sorted inventory

Table keys: Python “tests” are recorded executions, including skips. Godot “—” means no comparable per-case count. A `tests/run_tests.gd::_test_*` row classifies that call site; it is not another physical file. Rows with — seconds share the single measured main-body total, so no individual timing is invented. RETIRE is globally sorted by measured seconds descending, then unmeasured call sites.

### KEEP

| File / call site | Kind | Seconds | Tests | One-line reason |
|---|---|---:|---:|---|
| `tests/test_card_heuristic_illusions_terrain.py` | Python | 0.000 | 7 | Balance scorer must price the live card mechanics and progression assumptions consistently with data/. |
| `tests/test_card_heuristic_keywords.py` | Python | 0.000 | 5 | Balance scorer must price the live card mechanics and progression assumptions consistently with data/. |
| `tests/test_card_heuristic_maneuver.py` | Python | 0.001 | 10 | Balance scorer must price the live card mechanics and progression assumptions consistently with data/. |
| `tests/test_card_heuristic_progression_context.py` | Python | 0.042 | 1 | Balance scorer must price the live card mechanics and progression assumptions consistently with data/. |
| `tests/test_card_heuristic_surfaces.py` | Python | 0.000 | 6 | Balance scorer must price the live card mechanics and progression assumptions consistently with data/. |
| `tests/test_card_heuristic_wave4_surfaces.py` | Python | 0.001 | 11 | Balance scorer must price the live card mechanics and progression assumptions consistently with data/. |
| `tests/test_card_panel_text.py` | Python | 0.002 | 4 | Content validation: approved card/relic/glossary sentences, token syntax, schema and complete rules remain truthful. |
| `tests/test_element_rule_contract.py` | Python | 0.001 | 2 | Content validation: shipped battlefield-rule sentences/numbers and removal of inert mechanics. |
| `tests/test_godot_sidecars.py` | Python | 4.518 | 19 | Export integrity: missing/stale Godot imports and UIDs can break shipped resources (exception E2). |
| `tests/test_godot_task_runner.py` | Python | 5.736 | 15 | Active test infrastructure: isolate children, preserve failures, cancel owned processes and reject false green passes (exception E1). |
| `tests/test_icon_identity_policy.py` | Python | 0.100 | 10 | Content validation: all live data actions resolve to the correct distinct icon identity. |
| `tests/test_program_suite_runner.py` | Python | 31.603 | 37 | Active test infrastructure: isolate children, preserve failures, cancel owned processes and reject false green passes (exception E1). |
| `tests/test_python_suite_runner.py` | Python | 14.271 | 17 | Active test infrastructure: isolate children, preserve failures, cancel owned processes and reject false green passes (exception E1). |
| `tests/test_python_suite_runner_feedback.py` | Python | 17.120 | 12 | Active test infrastructure: isolate children, preserve failures, cancel owned processes and reject false green passes (exception E1). |
| `tests/test_relic_pt13_01.py` | Python | 0.012 | 2 | Live Black Sun Dial data must grant +3 per Expend, capped at +9; keep the content assertion despite the pt13 name. |
| `tests/test_runner_cancellation.py` | Python | 0.557 | 8 | Active test infrastructure: isolate children, preserve failures, cancel owned processes and reject false green passes (exception E1). |
| `tests/test_short_card_tooltips.py` | Python | 0.014 | 5 | Content validation: approved card/relic/glossary sentences, token syntax, schema and complete rules remain truthful. |
| `tests/test_text_budget.py` | Python | 0.069 | 6 | Content validation: approved card/relic/glossary sentences, token syntax, schema and complete rules remain truthful. |
| `tests/battlefield_fuel_test.gd` | Godot program | 5.195 | — | Held boss announcement and forecast must match the committed action, including half-Health switch and Lob adjacency. |
| `tests/board_status_plates_test.gd` | Godot program | 15.373 | — | Actual status names/counts and battlefield beat/preview state must remain truthful; keep mixed layout pins at full cost. |
| `tests/board_surface_content_smoke_test.gd` | Godot program | 2.468 | — | Hidden states, losses, cancelled surface actions and damage previews must agree with resolver without leaking enemies. |
| `tests/board_surface_data_test.gd` | Godot program | 1.680 | — | Hidden states, losses, cancelled surface actions and damage previews must agree with resolver without leaking enemies. |
| `tests/board_surface_presentation_test.gd` | Godot program | 6.832 | — | Hidden states, losses, cancelled surface actions and damage previews must agree with resolver without leaking enemies. |
| `tests/board_tile_tooltip_live_test.gd` | Godot program | 9.151 | — | All effects under a tile remain inspectable on mouse/controller; held stacks invalidate after state changes without moving the cursor. |
| `tests/board_tile_tooltip_route_test.gd` | Godot program | 26.094 | — | All effects under a tile remain inspectable on mouse/controller; held stacks invalidate after state changes without moving the cursor. |
| `tests/board_tile_tooltip_test.gd` | Godot program | 5.471 | — | All effects under a tile remain inspectable on mouse/controller; held stacks invalidate after state changes without moving the cursor. |
| `tests/bos01_aimed_switch_test.gd` | Godot program | 4.031 | — | Held boss announcement and forecast must match the committed action, including half-Health switch and Lob adjacency. |
| `tests/bos01_route_cases.gd` | Godot program | 2.663 | — | Held boss announcement and forecast must match the committed action, including half-Health switch and Lob adjacency. |
| `tests/bos01_rule_scene_test.gd` | Godot program | 10.290 | — | Held boss announcement and forecast must match the committed action, including half-Health switch and Lob adjacency. |
| `tests/bos01_rules_test.gd` | Godot program | 4.697 | — | Held boss announcement and forecast must match the committed action, including half-Health switch and Lob adjacency. |
| `tests/boss_health_preview_test.gd` | Godot program | 6.616 | — | Named playtest-13 bug: boss turn-order refresh erased the damage preview; keep live redraw/lookup assertions (B3). |
| `tests/brs01_test.gd` | Godot program | 25.649 | — | Burst effects/intent and objective instructions represent every real enemy-phase/hidden cascade; keep semantics even under a unit name. |
| `tests/cache_switch_regression_test.gd` | Godot program | 6.892 | — | Cache switching must preserve Steam/offline initialization and user settings (E2); do not lose preferences during cache-mode changes. |
| `tests/card_display_overrides_test.gd` | Godot program | 18.284 | — | Displayed card damage/cost/health modifiers and base definitions must match playable rules without mutating state. |
| `tests/card_draw_hand_flow_test.gd` | Godot program | 11.118 | — | Opening deal, draw counts and hand input stay in correct pre-battle/combat phase. |
| `tests/card_legibility_test.gd` | Godot program | 13.996 | — | Named readability bugs: Sabatons rows shrank and 240 card faces overflowed; retain glyph/vertical clipping and no-shrink coverage (B4). |
| `tests/card_panel_text_test.gd` | Godot program | 2.755 | — | Glossary coverage/tokens and true card rules prevent misleading player information; keep mixed file at its full cost. |
| `tests/card_summary_fit_test.gd` | Godot program | 23.667 | — | Named readability bugs: Sabatons rows shrank and 240 card faces overflowed; retain glyph/vertical clipping and no-shrink coverage (B4). |
| `tests/card_summary_fit_unit_test.gd` | Godot program | 4.483 | — | Named readability bugs: Sabatons rows shrank and 240 card faces overflowed; retain glyph/vertical clipping and no-shrink coverage (B4). |
| `tests/cel_look_test.gd` | Godot program | 4.085 | — | Asset loader chooses current cel/original textures with preserved alpha; prevents missing or incorrectly filtered production assets. |
| `tests/chronicle_test.gd` | Godot program | 8.396 | — | Chronicle definitions/deltas and saved records accurately represent the completed run. |
| `tests/combat_board_navigation_test.gd` | Godot program | 2.736 | — | Board hit testing, panning, wheel/controller selection and legal tiles remain aligned with the visible board. |
| `tests/combat_hud_badges_test.gd` | Godot program | 10.606 | — | HUD mouse/keyboard/controller routes, modal suppression and actual badge counts preserve input and information. |
| `tests/combat_hud_buttons_test.gd` | Godot program | 10.496 | — | HUD mouse/keyboard/controller routes, modal suppression and actual badge counts preserve input and information. |
| `tests/combat_hud_dialogue_input_test.gd` | Godot program | 6.458 | — | HUD mouse/keyboard/controller routes, modal suppression and actual badge counts preserve input and information. |
| `tests/combat_music_integration_test.gd` | Godot program | 7.399 | — | Sound-bank playback, inheritance, mute/bus settings and current music routing preserve actual audible behavior; detailed waveform/onset timing is on demand. |
| `tests/contextual_combat_tutorial_test.gd` | Godot program | 0.846 | — | Tutorial milestones/profile migrations and actual modal input gating preserve progression. |
| `tests/departed_run_cleanup_test.gd` | Godot program | 8.031 | — | Abandoned/new runs cannot retain state or work from the departed run. |
| `tests/dragon_committed_patterns_test.gd` | Godot program | 8.297 | — | Dragon mechanics, saved commitments, reaction/cascade damage and reward/trophy effects are live gameplay despite feedback names. |
| `tests/dragon_feedback_mechanics_test.gd` | Godot program | 7.776 | — | Dragon mechanics, saved commitments, reaction/cascade damage and reward/trophy effects are live gameplay despite feedback names. |
| `tests/dragon_reward_feedback_test.gd` | Godot program | 1.539 | — | Dragon mechanics, saved commitments, reaction/cascade damage and reward/trophy effects are live gameplay despite feedback names. |
| `tests/dragon_rewards_test.gd` | Godot program | 9.578 | — | Dragon mechanics, saved commitments, reaction/cascade damage and reward/trophy effects are live gameplay despite feedback names. |
| `tests/dragon_trophy_feedback_test.gd` | Godot program | 1.257 | — | Dragon mechanics, saved commitments, reaction/cascade damage and reward/trophy effects are live gameplay despite feedback names. |
| `tests/dragon_wallet_ack_test.gd` | Godot program | 8.044 | — | Wallet/dialogue acknowledgment and persistence cannot silently replay an already committed reward. |
| `tests/el04_rule_views_test.gd` | Godot program | 15.556 | — | Actual status names/counts and battlefield beat/preview state must remain truthful; keep mixed layout pins at full cost. |
| `tests/element_retrofit_test.gd` | Godot program | 12.498 | — | Held boss announcement and forecast must match the committed action, including half-Health switch and Lob adjacency. |
| `tests/en01_enemies_test.gd` | Godot program | 5.162 | — | Live enemy action selection, resolver outcomes, intent agreement and save conversion; unit naming does not make combat coverage disposable. |
| `tests/en03_enemies_test.gd` | Godot program | 22.052 | — | Live enemy action selection, resolver outcomes, intent agreement and save conversion; unit naming does not make combat coverage disposable. |
| `tests/en05_elemental_test.gd` | Godot program | 4.282 | — | Live enemy action selection, resolver outcomes, intent agreement and save conversion; unit naming does not make combat coverage disposable. |
| `tests/en05_live_integration_test.gd` | Godot program | 6.273 | — | Live enemy action selection, resolver outcomes, intent agreement and save conversion; unit naming does not make combat coverage disposable. |
| `tests/en06_enemies_test.gd` | Godot program | 7.877 | — | Live enemy action selection, resolver outcomes, intent agreement and save conversion; unit naming does not make combat coverage disposable. |
| `tests/enc03_slag_test.gd` | Godot program | 4.667 | — | Held boss announcement and forecast must match the committed action, including half-Health switch and Lob adjacency. |
| `tests/enc04_forecast_test.gd` | Godot program | 56.788 | — | Held boss announcement and forecast must match the committed action, including half-Health switch and Lob adjacency. |
| `tests/encounter_analytics_test.gd` | Godot program | 4.855 | — | Analytics event context/schema and crash-safe append-only delivery must remain correct. |
| `tests/enemy_no_action_test.gd` | Godot program | 23.585 | — | No-action reasons derive from the resolver and cannot fabricate losses or leak hidden actors; includes fix-11 missing/misleading callouts. |
| `tests/event_feedback_test.gd` | Godot program | 36.226 | — | Event choices/hover/focus and disabled requirements must match real effects; preserve all outcomes, skip behavior and once-only feedback despite the feedback filename. |
| `tests/event_rules_test.gd` | Godot program | 83.010 | — | Event selection/effects/requirements, exact rewards, old saves and recent-history persistence validate data/ and player outcomes. |
| `tests/event_view_test.gd` | Godot program | 40.360 | — | Event choices/hover/focus and disabled requirements must match real effects; preserve all outcomes, skip behavior and once-only feedback despite the feedback filename. |
| `tests/fix18/draw_origin_test.gd` | Godot program | 8.360 | — | Named Continue bug: Seer/Mirror/Gaoler/Lancer drew off their tiles; exercise real Continue, resize, movement and layout (B7). |
| `tests/fix18/entry_paths_test.gd` | Godot program | 10.793 | — | Named Continue bug: Seer/Mirror/Gaoler/Lancer drew off their tiles; exercise real Continue, resize, movement and layout (B7). |
| `tests/fix_12_arrival_test.gd` | Godot program | 6.370 | — | Named double-loss bug: arrival/reaction/Bleed/cascade damage must appear once on its owning step with correct intermediate state and analytics (B6). |
| `tests/fix_12_bleed_test.gd` | Godot program | 5.852 | — | Named double-loss bug: arrival/reaction/Bleed/cascade damage must appear once on its owning step with correct intermediate state and analytics (B6). |
| `tests/fix_12_cascades_test.gd` | Godot program | 5.855 | — | Named double-loss bug: arrival/reaction/Bleed/cascade damage must appear once on its owning step with correct intermediate state and analytics (B6). |
| `tests/fix_12_feedback_test.gd` | Godot program | 5.815 | — | Named double-loss bug: arrival/reaction/Bleed/cascade damage must appear once on its owning step with correct intermediate state and analytics (B6). |
| `tests/fix_12_reactions_0_test.gd` | Godot program | 5.701 | — | Named double-loss bug: arrival/reaction/Bleed/cascade damage must appear once on its owning step with correct intermediate state and analytics (B6). |
| `tests/fix_12_reactions_1_test.gd` | Godot program | 5.763 | — | Named double-loss bug: arrival/reaction/Bleed/cascade damage must appear once on its owning step with correct intermediate state and analytics (B6). |
| `tests/fix_14_matrix_test.gd` | Godot program | 4.318 | — | Named double-loss bug: arrival/reaction/Bleed/cascade damage must appear once on its owning step with correct intermediate state and analytics (B6). |
| `tests/fix_14_test.gd` | Godot program | 12.986 | — | Named double-loss bug: arrival/reaction/Bleed/cascade damage must appear once on its owning step with correct intermediate state and analytics (B6). |
| `tests/flurry_retirement_test.gd` | Godot program | 13.340 | — | No retired Flurry content and actual card/keyword/rules semantics remain coherent with data/. |
| `tests/glossary_test.gd` | Godot program | 8.631 | — | Glossary coverage/tokens and true card rules prevent misleading player information; keep mixed file at its full cost. |
| `tests/graftwright_console_test.gd` | Godot program | 1.967 | — | Graftwright and magic-deck operations, reserve migration and affordable modal confirmation preserve ownership/input. |
| `tests/guardian_rules_test.gd` | Godot program | 4.458 | — | Held boss announcement and forecast must match the committed action, including half-Health switch and Lob adjacency. |
| `tests/guided_combat_tutorial_integration_test.gd` | Godot program | 7.183 | — | Tutorial milestones/profile migrations and actual modal input gating preserve progression. |
| `tests/heirloom_notification_test.gd` | Godot program | 9.960 | — | Boon/heirloom choices, transactions and save-failure recovery must neither duplicate nor lose equipment. |
| `tests/hero_facing_gameplay_test.gd` | Godot program | 12.823 | — | Hero facing/start/save/actions and incoming-hit orientation must match committed gameplay state. |
| `tests/hero_facing_snap_golden_test.gd` | Godot program | 5.937 | — | Hero facing/start/save/actions and incoming-hit orientation must match committed gameplay state. |
| `tests/hero_facing_test.gd` | Godot program | 3.897 | — | Hero facing/start/save/actions and incoming-hit orientation must match committed gameplay state. |
| `tests/hoarder_test.gd` | Godot program | 16.710 | — | Warband orders, commitments, gust restrictions, Snare/Last Light/Hoarder victory and reward rules. |
| `tests/int11_integration_test.gd` | Godot program | 11.036 | — | Current status/Marked/Retaliate/objective mechanics, timing of actual effects and legacy conversions; protect player outcomes. |
| `tests/last_light_test.gd` | Godot program | 16.667 | — | Warband orders, commitments, gust restrictions, Snare/Last Light/Hoarder victory and reward rules. |
| `tests/magic_deck_input_test.gd` | Godot program | 31.719 | — | Graftwright and magic-deck operations, reserve migration and affordable modal confirmation preserve ownership/input. |
| `tests/magic_deck_test.gd` | Godot program | 5.191 | — | Graftwright and magic-deck operations, reserve migration and affordable modal confirmation preserve ownership/input. |
| `tests/main_menu_input_test.gd` | Godot program | 19.083 | — | Continue/New Run input and corrupt-save recovery; gameplay must remain accessible without replacing a valid save. |
| `tests/main_menu_resume_test.gd` | Godot program | 7.055 | — | Continue/New Run input and corrupt-save recovery; gameplay must remain accessible without replacing a valid save. |
| `tests/mim01_test.gd` | Godot program | 11.122 | — | Current status/Marked/Retaliate/objective mechanics, timing of actual effects and legacy conversions; protect player outcomes. |
| `tests/movement_undo_test.gd` | Godot program | 15.147 | — | Movement undo and legal move/bleed/hidden-collision outcomes must preserve committed state. |
| `tests/mrk01_marked_test.gd` | Godot program | 4.272 | — | Current status/Marked/Retaliate/objective mechanics, timing of actual effects and legacy conversions; protect player outcomes. |
| `tests/music_continuity_test.gd` | Godot program | 34.462 | — | Sound-bank playback, inheritance, mute/bus settings and current music routing preserve actual audible behavior; detailed waveform/onset timing is on demand. |
| `tests/opening_boon_recovery_test.gd` | Godot program | 10.945 | — | Boon/heirloom choices, transactions and save-failure recovery must neither duplicate nor lose equipment. |
| `tests/opening_boon_test.gd` | Godot program | 22.860 | — | Boon/heirloom choices, transactions and save-failure recovery must neither duplicate nor lose equipment. |
| `tests/original_music_test.gd` | Godot program | 10.308 | — | Sound-bank playback, inheritance, mute/bus settings and current music routing preserve actual audible behavior; detailed waveform/onset timing is on demand. |
| `tests/perf/analytics_restart_test.gd` | Godot program | 1.772 | — | Analytics event context/schema and crash-safe append-only delivery must remain correct. |
| `tests/perf/background_persistence_test.gd` | Godot program | 0.997 | — | Analytics event context/schema and crash-safe append-only delivery must remain correct. |
| `tests/perf/deferred_deadline_test.gd` | Godot program | 2.991 | — | Deferred persistence must eventually flush saves/events and failed saves must not starve analytics; keep functional waits, timing threshold stays opt-in. |
| `tests/performance_telemetry_test.gd` | Godot program | 0.549 | — | Analytics event context/schema and crash-safe append-only delivery must remain correct. |
| `tests/petrify_tooltip_test.gd` | Godot program | 3.879 | — | Petrify badge/turn-order tooltip must state actual turns/block rules. |
| `tests/player_defeat_continuity_test.gd` | Godot program | 26.238 | — | Lethal resolver steps must present one defeat on the owning direct/trap action and unlock terminal flow. |
| `tests/player_movement_outcome_test.gd` | Godot program | 11.086 | — | Movement undo and legal move/bleed/hidden-collision outcomes must preserve committed state. |
| `tests/pre_battle_semantics_test.gd` | Godot program | 14.071 | — | Pre-battle visible enemies/moves/rules match the real encounter, including known mechanics. |
| `tests/pt15_01_owner_feet_check.gd` | Godot program | 4.081 | — | Named owner bug: intent chips cover their owning soles; keep bounded solver assertions without Python mutation sweeps (B5). |
| `tests/rr46/depth_check.gd` | Godot program | 9.517 | — | Moving actors must stay routed to visible hosts and sort by actual ground depth (E5); retain cache/occupant regression and transfer rr47 missing-callback assertion here before retiring its Python driver. |
| `tests/run_end_recap_tests.gd` | Godot program | 8.571 | — | Progression, score, exactly-once run-end accounting and persistent personal bests. |
| `tests/run_score_test.gd` | Godot program | 8.301 | — | Progression, score, exactly-once run-end accounting and persistent personal bests. |
| `tests/save_resume_boundary_test.gd` | Godot program | 8.555 | — | Transactional save replacement, corrupt recovery, legacy migration and terminal/campfire failure recovery. |
| `tests/section_map_v2_test.gd` | Godot program | 40.209 | — | Map saved-revision generation and reachable routes; historical hashes of saved revision 5/6 protect migration, not a finished optimization. |
| `tests/section_transition_test.gd` | Godot program | 51.980 | — | Section transition preserves payout, enters the next threshold once and recovers failed/legacy entry; retain full mixed-file cost. |
| `tests/sfx_bank_test.gd` | Godot program | 10.118 | — | Sound-bank playback, inheritance, mute/bus settings and current music routing preserve actual audible behavior; detailed waveform/onset timing is on demand. |
| `tests/sfx_sync_bank_test.gd` | Godot program | 1.159 | — | Sound-bank playback, inheritance, mute/bus settings and current music routing preserve actual audible behavior; detailed waveform/onset timing is on demand. |
| `tests/short_card_tooltips_test.gd` | Godot program | 19.368 | — | Glossary coverage/tokens and true card rules prevent misleading player information; keep mixed file at its full cost. |
| `tests/skill_progression_analytics_test.gd` | Godot program | 4.057 | — | Analytics event context/schema and crash-safe append-only delivery must remain correct. |
| `tests/snare_test.gd` | Godot program | 19.184 | — | Warband orders, commitments, gust restrictions, Snare/Last Light/Hoarder victory and reward rules. |
| `tests/snare_ui_test.gd` | Godot program | 4.630 | — | Semantic captain/rule/door information must agree with encounter state; keep full mixed-file cost. |
| `tests/special_encounter_test.gd` | Godot program | 50.285 | — | Encounter composition/placement prevents unreachable starts, invalid layouts and authored encounter-content violations. |
| `tests/sta01_mechanics_test.gd` | Godot program | 1.887 | — | Current status/Marked/Retaliate/objective mechanics, timing of actual effects and legacy conversions; protect player outcomes. |
| `tests/suites/encounter_placement_0_program.gd` | Godot program | 40.004 | — | Encounter composition/placement prevents unreachable starts, invalid layouts and authored encounter-content violations. |
| `tests/suites/encounter_placement_1_program.gd` | Godot program | 38.193 | — | Encounter composition/placement prevents unreachable starts, invalid layouts and authored encounter-content violations. |
| `tests/suites/encounter_placement_summary_program.gd` | Godot program | 33.342 | — | Encounter composition/placement prevents unreachable starts, invalid layouts and authored encounter-content violations. |
| `tests/suites/encounter_rules_program.gd` | Godot program | 23.110 | — | Encounter composition/placement prevents unreachable starts, invalid layouts and authored encounter-content violations. |
| `tests/suites/full_scene_audio_program.gd` | Godot program | 17.888 | — | Sound-bank playback, inheritance, mute/bus settings and current music routing preserve actual audible behavior; detailed waveform/onset timing is on demand. |
| `tests/suites/full_scene_card_drag_program.gd` | Godot program | 40.184 | — | Live input routing and actual player choices: movement/targeting, drag, controllers, card costs, hidden-state previews and reward acquisition. |
| `tests/suites/full_scene_choices_program.gd` | Godot program | 34.595 | — | Live input routing and actual player choices: movement/targeting, drag, controllers, card costs, hidden-state previews and reward acquisition. |
| `tests/suites/full_scene_clock_program.gd` | Godot program | 28.747 | — | Live input routing and actual player choices: movement/targeting, drag, controllers, card costs, hidden-state previews and reward acquisition. |
| `tests/suites/full_scene_controls_program.gd` | Godot program | 65.027 | — | Live input routing and actual player choices: movement/targeting, drag, controllers, card costs, hidden-state previews and reward acquisition. |
| `tests/suites/full_scene_interaction_program.gd` | Godot program | 59.775 | — | Live input routing and actual player choices: movement/targeting, drag, controllers, card costs, hidden-state previews and reward acquisition. |
| `tests/suites/full_scene_navigation_program.gd` | Godot program | 17.461 | — | Live input routing and actual player choices: movement/targeting, drag, controllers, card costs, hidden-state previews and reward acquisition. |
| `tests/suites/section_map_legacy_hashes_0_program.gd` | Godot program | 27.938 | — | Saved revision-3/4 maps must remain byte-identical to pre-change fixtures across 200 seeds; this is save compatibility, not a finished-refactor oracle. |
| `tests/suites/section_map_legacy_hashes_1_program.gd` | Godot program | 25.411 | — | Saved revision-3/4 maps must remain byte-identical to pre-change fixtures across 200 seeds; this is save compatibility, not a finished-refactor oracle. |
| `tests/suites/section_map_performance_program.gd` | Godot program | 18.664 | — | Named shipped freeze: section-map seed 1792271957 could hang assignment; deterministic search budget/rejection/fallback protects run creation (B2). |
| `tests/suites/section_map_v5_program.gd` | Godot program | 13.180 | — | Map saved-revision generation and reachable routes; historical hashes of saved revision 5/6 protect migration, not a finished optimization. |
| `tests/summon_card_play_test.gd` | Godot program | 4.685 | — | Summoned deaths cannot grant unintended card plays; regression cases verify real resolver and reward rules. |
| `tests/surface_analytics_batch_test.gd` | Godot program | 4.086 | — | Analytics event context/schema and crash-safe append-only delivery must remain correct. |
| `tests/surface_feedback_ui_test.gd` | Godot program | 7.795 | — | Active/conditional surface text and drag target information cannot promise an unavailable effect. |
| `tests/surface_parent_review_test.gd` | Godot program | 3.583 | — | Progression/surface-save migration, paid techniques and legacy tutorial release protect existing runs. |
| `tests/surface_save_migration_test.gd` | Godot program | 1.256 | — | Progression/surface-save migration, paid techniques and legacy tutorial release protect existing runs. |
| `tests/threats_at_rest_test.gd` | Godot program | 31.544 | — | Threat/intents and hidden information must describe actual danger; includes pt14 source regressions without Python mutation sweeps. |
| `tests/warband_orders_test.gd` | Godot program | 18.964 | — | Warband orders, commitments, gust restrictions, Snare/Last Light/Hoarder victory and reward rules. |
| `tests/warband_test.gd` | Godot program | 41.459 | — | Warband orders, commitments, gust restrictions, Snare/Last Light/Hoarder victory and reward rules. |
| `tests/warband_ui_test.gd` | Godot program | 16.327 | — | Semantic captain/rule/door information must agree with encounter state; keep full mixed-file cost. |
| `tests/warband_wind_lock_test.gd` | Godot program | 5.262 | — | Warband orders, commitments, gust restrictions, Snare/Last Light/Hoarder victory and reward rules. |
| `tests/suites/audio_routing_suite.gd` | main suite | — | — | Music/SFX/UI buses and mute settings affect audible production playback; preserve existing routing semantics. |
| `tests/suites/balance_pacing_suite.gd` | main suite | — | — | Fixed-point save migration, live Defiance and run pacing rules. |
| `tests/suites/battlefield_rules_suite.gd` | main suite | — | — | Live battlefield rules rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/board_surface_suite.gd` | main suite | — | — | Live board surface rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/card_drag_play_suite.gd` | main suite | — | — | Live card drag play rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/card_keywords_suite.gd` | main suite | — | — | Live card keywords rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/card_keywords_w3_suite.gd` | main suite | — | — | Live card keywords w3 rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/card_mechanics_surfaces_suite.gd` | main suite | — | — | Live card mechanics surfaces rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/card_playability_summary_suite.gd` | main suite | — | — | Live card playability summary rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/card_pool_overhaul_suite.gd` | main suite | — | — | Live card pool overhaul rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/cbt_01_suite.gd` | main suite | — | — | Live cbt 01 rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/chain_attack_suite.gd` | main suite | — | — | Live chain attack rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/combat_objective_suite.gd` | main suite | — | — | Live combat objective rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/combat_outcome_feedback_suite.gd` | main suite | — | — | Damage/reward/outcome semantic events must represent committed combat outcomes. |
| `tests/suites/controller_input_suite.gd` | main suite | — | — | Live controller input rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/cursor_feedback_suite.gd` | main suite | — | — | Target context and suppression keep mouse feedback consistent with allowed input. |
| `tests/suites/depth_rules_suite.gd` | main suite | — | — | Live depth rules rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/dragon_boss_suite.gd` | main suite | — | — | Live dragon boss rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/dragon_pressure_mechanics_suite.gd` | main suite | — | — | Live dragon pressure mechanics rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/dragon_spire_routes_suite.gd` | main suite | — | — | Live dragon spire routes rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/en01_enemies_suite.gd` | main suite | — | — | Live en01 enemies rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/en02_enemies_suite.gd` | main suite | — | — | Live en02 enemies rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/en03_enemies_suite.gd` | main suite | — | — | Live en03 enemies rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/en04_enemies_suite.gd` | main suite | — | — | Live en04 enemies rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/en05_enemies_suite.gd` | main suite | — | — | Live en05 enemies rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/en06_enemies_suite.gd` | main suite | — | — | Live en06 enemies rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/enemy_intent_compass_suite.gd` | main suite | — | — | Intent family/primary action symbols must identify actual attacks/support actions. |
| `tests/suites/enemy_intent_continuity_suite.gd` | main suite | — | — | Live enemy intent continuity rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/enemy_intent_preview_suite.gd` | main suite | — | — | Live enemy intent preview rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/enemy_pathfinding_suite.gd` | main suite | — | — | Live enemy pathfinding rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/enemy_surface_acceptance_suite.gd` | main suite | — | — | Live enemy surface acceptance rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/enemy_tactical_ai_suite.gd` | main suite | — | — | Live enemy tactical ai rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/fix_03_suite.gd` | main suite | — | — | B1: owner-confirmed Fatigue amplification; preserve health-loss bypass plus truthful SPENT/token feedback. |
| `tests/suites/floating_combat_text_suite.gd` | main suite | — | — | Amounts and ownership of loss/gain popups must match resolver; retain mixed motion pins at no invented savings. |
| `tests/suites/forced_movement_suite.gd` | main suite | — | — | Live forced movement rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/glossary_coverage_suite.gd` | main suite | — | — | Validate data/ glossary concepts and complete rule coverage. |
| `tests/suites/graftwright_suite.gd` | main suite | — | — | Live graftwright rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/grimoire_search_suite.gd` | main suite | — | — | Live grimoire search rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/ground_targeting_suite.gd` | main suite | — | — | Live ground targeting rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/guardian_suite.gd` | main suite | — | — | Live guardian rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/illusion_terrain_suite.gd` | main suite | — | — | Live illusion terrain rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/initiative_order_suite.gd` | main suite | — | — | Live initiative order rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/inline_icon_description_suite.gd` | main suite | — | — | Known concepts and token syntax must resolve without unfilled player-visible text. |
| `tests/suites/item_pickup_suite.gd` | main suite | — | — | Live item pickup rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/lethal_preview_suite.gd` | main suite | — | — | Cumulative lethal preview must match outcomes and leave a target visible until resolution. |
| `tests/suites/magic_deck_suite.gd` | main suite | — | — | Live magic deck rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/maneuver_suite.gd` | main suite | — | — | Live maneuver rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/map_ui_suite.gd` | main suite | — | — | Controller/keyboard map navigation and route bearings must agree with connections. |
| `tests/suites/mim01_suite.gd` | main suite | — | — | Live mim01 rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/move_attack_approach_suite.gd` | main suite | — | — | Live move attack approach rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/move_attack_shortcut_suite.gd` | main suite | — | — | Live move attack shortcut rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/player_movement_suite.gd` | main suite | — | — | Live player movement rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/pre_battle_ui_suite.gd` | main suite | — | — | Enemy and loadout information, hover-source lifetime and ability semantics must be truthful. |
| `tests/suites/radiance_package_suite.gd` | main suite | — | — | Live radiance package rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/reach_rebalance_suite.gd` | main suite | — | — | Live reach rebalance rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/relic_suite.gd` | main suite | — | — | Live relic rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/relic_u1_suite.gd` | main suite | — | — | Live relic u1 rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/relic_u2_suite.gd` | main suite | — | — | Live relic u2 rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/relic_u3_suite.gd` | main suite | — | — | Live relic u3 rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/relic_u4_suite.gd` | main suite | — | — | Live relic u4 rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/relic_u5_suite.gd` | main suite | — | — | Live relic u5 rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/relic_u6_suite.gd` | main suite | — | — | Live relic u6 rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/relic_u7_suite.gd` | main suite | — | — | Live relic u7 rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/relic_u8_suite.gd` | main suite | — | — | Live relic u8 rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/run_score_suite.gd` | main suite | — | — | Live run score rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/scavenger_shop_suite.gd` | main suite | — | — | Live scavenger shop rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/section_map_suite.gd` | main suite | — | — | Live section map rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/section_map_v7_suite.gd` | main suite | — | — | Current routes and saved revision-5/6 map digests preserve navigation/migration; do not treat save compatibility as disposable equivalence. |
| `tests/suites/skill_combat_suite.gd` | main suite | — | — | Live skill combat rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/skill_run_suite.gd` | main suite | — | — | Live skill run rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/skill_tree_suite.gd` | main suite | — | — | Live skill tree rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/steam_service_suite.gd` | main suite | — | — | Steam/offline initialization and retained settings must not block starting or resuming a run. |
| `tests/suites/surface_core_review_suite.gd` | main suite | — | — | Live hazard/hidden-state/lethal/paid-technique rules; review name does not make it historical proof. |
| `tests/suites/tooltip_consistency_suite.gd` | main suite | — | — | Card/equipment/keyword details must state actual effects and remain inspectable. |
| `tests/suites/turn_clock_wait_suite.gd` | main suite | — | — | Live turn clock wait rules/data, saved state, player input or truthful outcomes. |
| `tests/suites/umbra_action_animation_suite.gd` | main suite | — | — | Live umbra action animation rules/data, saved state, player input or truthful outcomes. |
| `tests/run_tests.gd::_test_air_trap_tooltip_is_damage_only` | main inline | — | — | Live air trap tooltip is damage only rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_aoe_hits_multiple_targets` | main inline | — | — | Live aoe hits multiple targets rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_attacking_trap_creates_delayed_cardinal_fire` | main inline | — | — | Live attacking trap creates delayed cardinal fire rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_bleed_expose_and_sunder_keywords` | main inline | — | — | Live bleed expose and sunder keywords rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_bleed_status_badges_and_trigger_floats` | main inline | — | — | Live bleed status badges and trigger floats rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_boss_room_spawns_zekarion_with_wisps` | main inline | — | — | Live boss room spawns zekarion with wisps rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_boss_victory_restores_player_health` | main inline | — | — | Live boss victory restores player health rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_card_play_action_grants_bonus_play` | main inline | — | — | Live card play action grants bonus play rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_card_time_scale_changes_player_reentry_order` | main inline | — | — | Live card time scale changes player reentry order rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_cards_do_not_define_multiple_player_attacks` | main inline | — | — | Live cards do not define multiple player attacks rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_chain_hits_clustered_enemies` | main inline | — | — | Live chain hits clustered enemies rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_chainbound_gaoler_intent_icons_and_previews` | main inline | — | — | Live chainbound gaoler intent icons and previews rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_chainbound_gaoler_profile_and_mechanics` | main inline | — | — | Live chainbound gaoler profile and mechanics rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_cinder_droplet_death_suppresses_rewards` | main inline | — | — | Live cinder droplet death suppresses rewards rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_cinder_droplet_does_not_resplit` | main inline | — | — | Live cinder droplet does not resplit rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_cinder_ooze_split_skips_blocked_board` | main inline | — | — | Live cinder ooze split skips blocked board rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_cinder_ooze_splits_deterministically` | main inline | — | — | Live cinder ooze splits deterministically rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_close_aoe_hits_adjacent_targets` | main inline | — | — | Live close aoe hits adjacent targets rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_combat_board_draw_order_tracks_moving_unit_world_position` | main inline | — | — | Moving/large units must use their true world/footprint draw host so an actor does not disappear behind the wrong layer; E5 retains rig-v2 callback cases separately. |
| `tests/run_tests.gd::_test_combat_board_surfaces_illusion_preview_units` | main inline | — | — | Live combat board surfaces illusion preview units rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_combat_board_surfaces_illusion_units` | main inline | — | — | Live combat board surfaces illusion units rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_combat_finish_generates_reward_state` | main inline | — | — | Live combat finish generates reward state rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_combat_log_is_bounded` | main inline | — | — | Live combat log is bounded rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_consumable_item_card_is_destroyed_after_play` | main inline | — | — | Live consumable item card is destroyed after play rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_element_locked_enemy_spawn_rules` | main inline | — | — | Live element locked enemy spawn rules rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_elemental_room_rewards_follow_affinity` | main inline | — | — | Live elemental room rewards follow affinity rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_emaciated_man_does_not_unlock_card_upgrade_dialogue` | main inline | — | — | Live emaciated man does not unlock card upgrade dialogue rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_empty_treasure_room_falls_back_to_room_mode` | main inline | — | — | Live empty treasure room falls back to room mode rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_enemy_aoe_blocker_damages_incidental_terrain` | main inline | — | — | Live enemy aoe blocker damages incidental terrain rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_enemy_aoe_damages_incidental_terrain` | main inline | — | — | Live enemy aoe damages incidental terrain rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_enemy_attacks_profitable_trap_without_self_damage` | main inline | — | — | Live enemy attacks profitable trap without self damage rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_enemy_bleed_intents_apply_and_surface_icons` | main inline | — | — | Live enemy bleed intents apply and surface icons rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_enemy_block_applies_on_actor_turn_only` | main inline | — | — | Live enemy block applies on actor turn only rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_enemy_breaks_blocking_terrain` | main inline | — | — | Live enemy breaks blocking terrain rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_enemy_close_aoe_still_hits_player` | main inline | — | — | Live enemy close aoe still hits player rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_enemy_death_grants_card_play_and_embers` | main inline | — | — | Live enemy death grants card play and embers rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_enemy_intent_shortcut_and_threat_union` | main inline | — | — | Live enemy intent shortcut and threat union rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_enemy_intents_ignore_room_element` | main inline | — | — | Live enemy intents ignore room element rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_enemy_moves_toward_breakable_chokepoint` | main inline | — | — | Live enemy moves toward breakable chokepoint rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_enemy_pathfinding_avoids_traps` | main inline | — | — | Live enemy pathfinding avoids traps rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_enemy_phase_preserves_preview_cycle` | main inline | — | — | Live enemy phase preserves preview cycle rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_enemy_pierce_intents_surface_icons` | main inline | — | — | Live enemy pierce intents surface icons rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_enemy_target_ties_prefer_illusions_deterministically` | main inline | — | — | Live enemy target ties prefer illusions deterministically rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_enemy_threat_tiles_assume_player_can_vacate_current_tile` | main inline | — | — | Live enemy threat tiles assume player can vacate current tile rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_enemy_threat_tiles_exclude_nonexistent_radial_trap_damage` | main inline | — | — | Live enemy threat tiles exclude nonexistent radial trap damage rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_enemy_threat_tiles_follow_intent` | main inline | — | — | Live enemy threat tiles follow intent rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_equipment_collection_to_equip_deck_flow` | main inline | — | — | Live equipment collection to equip deck flow rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_equipment_data_rarity_and_starter_deck` | main inline | — | — | Live equipment data rarity and starter deck rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_equipment_run_state_and_reward_cards` | main inline | — | — | Live equipment run state and reward cards rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_fatigue_draws_cost_health_and_burn_removes_card` | main inline | — | — | Live fatigue draws cost health and burn removes card rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_flurry_repeats_and_spends_snapshotted_card_plays` | main inline | — | — | Live flurry repeats and spends snapshotted card plays rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_forced_movement_uses_selected_straight_line` | main inline | — | — | Live forced movement uses selected straight line rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_freeze_and_shock_control_turn_flow` | main inline | — | — | Live freeze and shock control turn flow rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_frostglass_lancer_line_thrust_preview_and_resolution` | main inline | — | — | Live frostglass lancer line thrust preview and resolution rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_grave_surgeon_data_and_pool_role` | main inline | — | — | Live grave surgeon data and pool role rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_grave_surgeon_support_actions_scale` | main inline | — | — | Live grave surgeon support actions scale rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_grimoire_data_and_unlocks` | main inline | — | — | Live grimoire data and unlocks rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_guard_ally_targets_threatened_ally` | main inline | — | — | Live guard ally targets threatened ally rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_hand_draw_caps_at_seven` | main inline | — | — | Live hand draw caps at seven rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_harrier_has_moving_ranged_attack` | main inline | — | — | Live harrier has moving ranged attack rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_heal_ally_falls_back_to_self` | main inline | — | — | Live heal ally falls back to self rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_heal_ally_no_target_noops` | main inline | — | — | Live heal ally no target noops rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_heal_ally_targets_most_injured_ally` | main inline | — | — | Live heal ally targets most injured ally rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_healing_cards_are_burned_and_downweighted` | main inline | — | — | Live healing cards are burned and downweighted rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_hidden_enemy_movement_collision_does_not_leak_position` | main inline | — | — | Live hidden enemy movement collision does not leak position rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_hidden_enemy_status_steps_do_not_leak_identity_or_tile` | main inline | — | — | Live hidden enemy status steps do not leak identity or tile rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_illusion_action_creates_decoy_and_redirects_enemy` | main inline | — | — | Live illusion action creates decoy and redirects enemy rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_immobilize_cards_stay_in_allowed_elements` | main inline | — | — | Live immobilize cards stay in allowed elements rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_immobilize_control_turn_flow` | main inline | — | — | Live immobilize control turn flow rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_initiative_advances_enemy_turns_until_player_reacts` | main inline | — | — | Live initiative advances enemy turns until player reacts rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_initiative_order_starts_with_active_player_and_fast_enemies` | main inline | — | — | Live initiative order starts with active player and fast enemies rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_intermediate_boss_opens_next_sequence` | main inline | — | — | Live intermediate boss opens next sequence rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_keyword_icon_library_surfaces_tooltips` | main inline | — | — | Live keyword icon library surfaces tooltips rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_large_enemy_threat_tiles_use_footprint` | main inline | — | — | Live large enemy threat tiles use footprint rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_legacy_stats_do_not_change_combat_numbers` | main inline | — | — | Live legacy stats do not change combat numbers rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_lightning_strikes_damage_incidental_terrain` | main inline | — | — | Live lightning strikes damage incidental terrain rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_lightning_strikes_threat_tiles_are_previewed` | main inline | — | — | Live lightning strikes threat tiles are previewed rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_lightning_trap_wake_never_banks_obsolete_control` | main inline | — | — | Live lightning trap wake never banks obsolete control rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_lightning_trap_wake_preserves_current_turn_actions` | main inline | — | — | Live lightning trap wake preserves current turn actions rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_loaded_run_repairs_stranded_room_visibility` | main inline | — | — | Live loaded run repairs stranded room visibility rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_low_movement_enemies_advance_without_outpacing_crawlers` | main inline | — | — | Live low movement enemies advance without outpacing crawlers rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_missed_equipment_resolution_and_persistence` | main inline | — | — | Live missed equipment resolution and persistence rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_move_paths_only_cross_required_traps` | main inline | — | — | Live move paths only cross required traps rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_out_of_range_elemental_enemy_attack_skips_step` | main inline | — | — | Live out of range elemental enemy attack skips step rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_pickup_tooltips_describe_effects` | main inline | — | — | Live pickup tooltips describe effects rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_pierce_cards_stay_in_allowed_elements` | main inline | — | — | Live pierce cards stay in allowed elements rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_pierce_ignores_defenses` | main inline | — | — | Live pierce ignores defenses rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_player_aoe_damages_incidental_terrain` | main inline | — | — | Live player aoe damages incidental terrain rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_player_block_absorbs_full_enemy_phase` | main inline | — | — | Live player block absorbs full enemy phase rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_player_restriction_badges_show_turn_lock` | main inline | — | — | Live player restriction badges show turn lock rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_progression_save_and_purchase` | main inline | — | — | Live progression save and purchase rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_radiance_actions_reveal_and_reduce_umbra` | main inline | — | — | Live radiance actions reveal and reduce umbra rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_radiance_cards_and_icons_are_integrated` | main inline | — | — | Live radiance cards and icons are integrated rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_recovery_marker_expires_after_next_run` | main inline | — | — | Live recovery marker expires after next run rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_recovery_marker_flow` | main inline | — | — | Live recovery marker flow rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_relic_data_rarity_and_offer_weights` | main inline | — | — | Live relic data rarity and offer weights rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_room_generation_adds_pickups_and_destructible_terrain` | main inline | — | — | Live room generation adds pickups and destructible terrain rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_room_generation_avoids_adjacent_columns` | main inline | — | — | Live room generation avoids adjacent columns rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_room_generation_blocks_door_tiles` | main inline | — | — | Live room generation blocks door tiles rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_room_generation_enemy_spawns_keep_player_halo` | main inline | — | — | Live room generation enemy spawns keep player halo rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_room_generation_is_deterministic` | main inline | — | — | Live room generation is deterministic rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_room_generation_keeps_spawn_reachable` | main inline | — | — | Live room generation keeps spawn reachable rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_room_generation_populates_elemental_traps` | main inline | — | — | Live room generation populates elemental traps rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_room_generation_scales_enemy_density` | main inline | — | — | Live room generation scales enemy density rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_room_generation_uses_perimeter_walls_only` | main inline | — | — | Live room generation uses perimeter walls only rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_room_icon_library_covers_door_room_types` | main inline | — | — | Live room icon library covers door room types rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_rotated_line_aoe_uses_selected_orientation` | main inline | — | — | Live rotated line aoe uses selected orientation rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_rubble_and_stoneskin_behaviors` | main inline | — | — | Live rubble and stoneskin behaviors rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_run_engine_campfire_linger_heals_and_continues` | main inline | — | — | Live run engine campfire linger heals and continues rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_run_map_last_loop_room_opens_outward` | main inline | — | — | Live run map last loop room opens outward rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_run_map_merchant_room_spacing_and_density` | main inline | — | — | Live run map merchant room spacing and density rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_run_map_never_moves_back_toward_center` | main inline | — | — | Live run map never moves back toward center rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_run_map_recovery_marker_keeps_two_room_choices_like_category` | main inline | — | — | Live run map recovery marker keeps two room choices like category rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_run_map_relic_room_spacing_and_density` | main inline | — | — | Live run map relic room spacing and density rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_run_map_repeats_depth_sequences` | main inline | — | — | Live run map repeats depth sequences rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_run_map_ring_links_and_outward_quarter` | main inline | — | — | Live run map ring links and outward quarter rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_run_map_room_types` | main inline | — | — | Live run map room types rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_run_map_seals_departed_rooms` | main inline | — | — | Live run map seals departed rooms rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_run_map_two_room_choices_are_like_category_different_type` | main inline | — | — | Live run map two room choices are like category different type rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_run_scene_frostglass_lancer_line_threat_overlay` | main inline | — | — | Live run scene frostglass lancer line threat overlay rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_run_scene_surfaces_defeated_enemy_death_units` | main inline | — | — | Live run scene surfaces defeated enemy death units rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_run_scene_surfaces_destroyed_terrain_units` | main inline | — | — | Live run scene surfaces destroyed terrain units rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_run_scene_terrain_damage_previews_use_terrain_keys` | main inline | — | — | Live run scene terrain damage previews use terrain keys rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_run_state_save_and_load` | main inline | — | — | Live run state save and load rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_second_sequence_uses_scaled_zekarion_placeholder` | main inline | — | — | Live second sequence uses scaled zekarion placeholder rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_shale_bloomer_intents_show_rubble_and_expose_icons` | main inline | — | — | Live shale bloomer intents show rubble and expose icons rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_shale_bloomer_rubble_and_expose_intents_apply_to_player` | main inline | — | — | Live shale bloomer rubble and expose intents apply to player rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_special_rooms_use_corner_pillar_layout` | main inline | — | — | Live special rooms use corner pillar layout rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_start_room_spawns_emaciated_man` | main inline | — | — | Live start room spawns emaciated man rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_starting_deck_uses_hamstring_shot_over_bone_dart` | main inline | — | — | Live starting deck uses hamstring shot over bone dart rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_status_badges_surface_countdowns` | main inline | — | — | Live status badges surface countdowns rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_statuses_tick_on_affected_actor_turn` | main inline | — | — | Live statuses tick on affected actor turn rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_summoned_enemy_death_does_not_grant_card_play` | main inline | — | — | Live summoned enemy death does not grant card play rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_summoned_wisps_receive_preview_intents` | main inline | — | — | Live summoned wisps receive preview intents rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_support_intent_rows_name_target` | main inline | — | — | Live support intent rows name target rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_surface_icons_explain_card_requirements` | main inline | — | — | Live surface icons explain card requirements rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_tailwind_fletching_modifies_existing_forced_movement` | main inline | — | — | Live tailwind fletching modifies existing forced movement rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_terrain_blocks_movement_without_blocking_line_of_sight` | main inline | — | — | Live terrain blocks movement without blocking line of sight rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_terrain_health_bars_are_contextual` | main inline | — | — | Live terrain health bars are contextual rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_trap_wake_preserves_incidental_terrain` | main inline | — | — | Live trap wake preserves incidental terrain rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_two_card_turn_draw_flow` | main inline | — | — | Live two card turn draw flow rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_umbra_curve_tracks_dragon_sections` | main inline | — | — | Live umbra curve tracks dragon sections rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_umbra_hides_targets_intents_and_turn_order_identity` | main inline | — | — | Live umbra hides targets intents and turn order identity rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_warden_bulwark_guards_all_other_enemies` | main inline | — | — | Live warden bulwark guards all other enemies rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_zekarion_ignores_shock_status` | main inline | — | — | Live zekarion ignores shock status rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_zekarion_overload_preserves_declared_counterplay` | main inline | — | — | Live zekarion overload preserves declared counterplay rule/outcome or content invariant. |
| `tests/run_tests.gd::_test_zekarion_summons_wisps_when_alone` | main inline | — | — | Live zekarion summons wisps when alone rule/outcome or content invariant. |

Also KEEP the six initial catalog-load assertions in `tests/run_tests.gd::_initialize` (`cards`, `enemies`, `npcs`, `relics`, `equipment`, `upgrades`). They are bootstrap assertions rather than a separately timed suite or `_test_*` function. The root driver and its storage-isolation setup remain.

### MERGE

| File / call site | Kind | Seconds | Tests | One-line reason |
|---|---|---:|---:|---|
| `tests/test_boot_splash.py` | Python | 0.073 | 7 | Pin current approved art/rig inventory in one manifest; discard per-round regeneration, source-history and proof gates. |
| `tests/test_card_time_watch_asset.py` | Python | 0.002 | 2 | Pin current approved art/rig inventory in one manifest; discard per-round regeneration, source-history and proof gates. |
| `tests/test_chopin_death_music.py` | Python | 0.039 | 5 | Pin current approved art/rig inventory in one manifest; discard per-round regeneration, source-history and proof gates. |
| `tests/test_empower_sfx.py` | Python | 0.002 | 3 | Pin current approved art/rig inventory in one manifest; discard per-round regeneration, source-history and proof gates. |
| `tests/test_en05_assets.py` | Python | 0.048 | 3 | Pin current approved art/rig inventory in one manifest; discard per-round regeneration, source-history and proof gates. |
| `tests/test_gear_visual_assets.py` | Python | 80.751 | 3 | Pin current approved art/rig inventory in one manifest; discard per-round regeneration, source-history and proof gates. |
| `tests/test_glacial_mirror_registration.py` | Python | 0.015 | 4 | Pin current approved art/rig inventory in one manifest; discard per-round regeneration, source-history and proof gates. |
| `tests/test_item_card_art_quality.py` | Python | 0.676 | 3 | Pin current approved art/rig inventory in one manifest; discard per-round regeneration, source-history and proof gates. |
| `tests/test_labyrinth_font_family.py` | Python | 0.359 | 7 | Pin current approved art/rig inventory in one manifest; discard per-round regeneration, source-history and proof gates. |
| `tests/test_main_menu_umbra_assets.py` | Python | 0.002 | 4 | Pin current approved art/rig inventory in one manifest; discard per-round regeneration, source-history and proof gates. |
| `tests/test_old_castle_full_arrangement.py` | Python | 0.000 | 6 | Pin current approved art/rig inventory in one manifest; discard per-round regeneration, source-history and proof gates. |
| `tests/test_old_castle_main_menu_arrangement.py` | Python | 0.000 | 10 | Pin current approved art/rig inventory in one manifest; discard per-round regeneration, source-history and proof gates. |
| `tests/test_original_soundtrack_assets.py` | Python | 0.080 | 3 | Pin current approved art/rig inventory in one manifest; discard per-round regeneration, source-history and proof gates. |
| `tests/test_process_biome_art.py` | Python | 13.797 | 6 | Pin current approved art/rig inventory in one manifest; discard per-round regeneration, source-history and proof gates. |
| `tests/test_process_event_art.py` | Python | 23.394 | 3 | Pin current approved art/rig inventory in one manifest; discard per-round regeneration, source-history and proof gates. |
| `tests/test_rr46_preserve_arc_thrall.py` | Python | 0.047 | 1 | One current approved-input manifest replaces ten family-specific checks of the same pin format. |
| `tests/test_rr46_preserve_briar_weaver.py` | Python | 0.013 | 1 | One current approved-input manifest replaces ten family-specific checks of the same pin format. |
| `tests/test_rr46_preserve_chainbound_gaoler.py` | Python | 0.038 | 1 | One current approved-input manifest replaces ten family-specific checks of the same pin format. |
| `tests/test_rr46_preserve_frostglass_lancer.py` | Python | 0.029 | 1 | One current approved-input manifest replaces ten family-specific checks of the same pin format. |
| `tests/test_rr46_preserve_gale_herald.py` | Python | 0.020 | 1 | One current approved-input manifest replaces ten family-specific checks of the same pin format. |
| `tests/test_rr46_preserve_glacial_mirror.py` | Python | 0.013 | 1 | One current approved-input manifest replaces ten family-specific checks of the same pin format. |
| `tests/test_rr46_preserve_gloam_stalker.py` | Python | 0.027 | 1 | One current approved-input manifest replaces ten family-specific checks of the same pin format. |
| `tests/test_rr46_preserve_hoarfrost_seer.py` | Python | 0.038 | 1 | One current approved-input manifest replaces ten family-specific checks of the same pin format. |
| `tests/test_rr46_preserve_hollow_mimic.py` | Python | 0.012 | 1 | One current approved-input manifest replaces ten family-specific checks of the same pin format. |
| `tests/test_rr46_preserve_slag_mortar.py` | Python | 0.015 | 1 | One current approved-input manifest replaces ten family-specific checks of the same pin format. |
| `tests/test_special_encounter_assets.py` | Python | 0.008 | 5 | Pin current approved art/rig inventory in one manifest; discard per-round regeneration, source-history and proof gates. |
| `tests/test_visual_pass_4_assets.py` | Python | 0.305 | 6 | Pin current approved art/rig inventory in one manifest; discard per-round regeneration, source-history and proof gates. |
| `tests/acolyte_cutout_pack_test.gd` | Godot program | 1.205 | — | One manifest-driven roster export/load smoke replaces a separate pack builder/fixture per creature; preserve missing-resource detection. |
| `tests/bile_bloomer_cutout_pack_test.gd` | Godot program | 1.200 | — | One manifest-driven roster export/load smoke replaces a separate pack builder/fixture per creature; preserve missing-resource detection. |
| `tests/chainbound_gaoler_cutout_pack_test.gd` | Godot program | 1.772 | — | One manifest-driven roster export/load smoke replaces a separate pack builder/fixture per creature; preserve missing-resource detection. |
| `tests/cinder_droplet_cutout_pack_test.gd` | Godot program | 1.164 | — | One manifest-driven roster export/load smoke replaces a separate pack builder/fixture per creature; preserve missing-resource detection. |
| `tests/cinder_ooze_cutout_pack_test.gd` | Godot program | 1.157 | — | One manifest-driven roster export/load smoke replaces a separate pack builder/fixture per creature; preserve missing-resource detection. |
| `tests/crawler_cutout_pack_test.gd` | Godot program | 1.146 | — | One manifest-driven roster export/load smoke replaces a separate pack builder/fixture per creature; preserve missing-resource detection. |
| `tests/cutout_rig_data_test.gd` | Godot program | 0.791 | — | Current approved rig/presentation registration and roster availability move to one manifest-driven loader; discard historic per-clip/equivalence detail. |
| `tests/enemy_cutout_roster_pack_test.gd` | Godot program | 2.048 | — | One manifest-driven whole-roster export/load smoke replaces independent enemy/guardian package fixtures. |
| `tests/frostglass_lancer_cutout_pack_test.gd` | Godot program | 1.788 | — | One manifest-driven roster export/load smoke replaces a separate pack builder/fixture per creature; preserve missing-resource detection. |
| `tests/graftwright_cutout_pack_test.gd` | Godot program | 0.847 | — | One manifest-driven roster export/load smoke replaces a separate pack builder/fixture per creature; preserve missing-resource detection. |
| `tests/grave_surgeon_cutout_pack_test.gd` | Godot program | 1.206 | — | One manifest-driven roster export/load smoke replaces a separate pack builder/fixture per creature; preserve missing-resource detection. |
| `tests/grb01_ground_contact_test.gd` | Godot program | 3.444 | — | Director ground-contact scale/alpha/geometry pins; copy current approved registration values to MERGE. |
| `tests/guardian_cutout_pack_test.gd` | Godot program | 0.896 | — | One manifest-driven whole-roster export/load smoke replaces independent enemy/guardian package fixtures. |
| `tests/gust_shrike_cutout_pack_test.gd` | Godot program | 1.240 | — | One manifest-driven roster export/load smoke replaces a separate pack builder/fixture per creature; preserve missing-resource detection. |
| `tests/harrier_cutout_pack_test.gd` | Godot program | 1.271 | — | One manifest-driven roster export/load smoke replaces a separate pack builder/fixture per creature; preserve missing-resource detection. |
| `tests/iskaldra_cutout_pack_test.gd` | Godot program | 1.151 | — | One manifest-driven roster export/load smoke replaces a separate pack builder/fixture per creature; preserve missing-resource detection. |
| `tests/maquette_cutout_test.gd` | Godot program | 16.798 | — | Current approved rig/presentation registration and roster availability move to one manifest-driven loader; discard historic per-clip/equivalence detail. |
| `tests/noctyrax_cutout_pack_test.gd` | Godot program | 1.123 | — | One manifest-driven roster export/load smoke replaces a separate pack builder/fixture per creature; preserve missing-resource detection. |
| `tests/protagonist_cutout_pack_test.gd` | Godot program | 1.624 | — | One manifest-driven roster export/load smoke replaces a separate pack builder/fixture per creature; preserve missing-resource detection. |
| `tests/scavenger_cutout_pack_test.gd` | Godot program | 0.705 | — | One manifest-driven roster export/load smoke replaces a separate pack builder/fixture per creature; preserve missing-resource detection. |
| `tests/static_facing_test.gd` | Godot program | 2.291 | — | Current approved rig/presentation registration and roster availability move to one manifest-driven loader; discard historic per-clip/equivalence detail. |
| `tests/stone_warden_cutout_pack_test.gd` | Godot program | 1.145 | — | One manifest-driven roster export/load smoke replaces a separate pack builder/fixture per creature; preserve missing-resource detection. |
| `tests/suites/full_scene_creature_cutouts_program.gd` | Godot program | 22.780 | — | Current approved rig/presentation registration and roster availability move to one manifest-driven loader; discard historic per-clip/equivalence detail. |
| `tests/suites/full_scene_cutouts_program.gd` | Godot program | 33.659 | — | Current approved rig/presentation registration and roster availability move to one manifest-driven loader; discard historic per-clip/equivalence detail. |
| `tests/tharokh_cutout_pack_test.gd` | Godot program | 1.139 | — | One manifest-driven roster export/load smoke replaces a separate pack builder/fixture per creature; preserve missing-resource detection. |
| `tests/vaeloryx_cutout_pack_test.gd` | Godot program | 1.290 | — | One manifest-driven roster export/load smoke replaces a separate pack builder/fixture per creature; preserve missing-resource detection. |
| `tests/veilbound_acolyte_cutout_pack_test.gd` | Godot program | 1.143 | — | One manifest-driven roster export/load smoke replaces a separate pack builder/fixture per creature; preserve missing-resource detection. |
| `tests/vyraketh_cutout_pack_test.gd` | Godot program | 1.275 | — | One manifest-driven roster export/load smoke replaces a separate pack builder/fixture per creature; preserve missing-resource detection. |
| `tests/zekarion_cutout_pack_test.gd` | Godot program | 1.313 | — | One manifest-driven roster export/load smoke replaces a separate pack builder/fixture per creature; preserve missing-resource detection. |
| `tests/suites/actor_presentation_suite.gd` | main suite | — | — | Approved current actor scale/registration/roster pins move to the shared manifest; detailed layout choreography is retired. |
| `tests/suites/board_density_consumer_suite.gd` | main suite | — | — | Current trap/chest dimensions and registration pins move to the shared approved-asset manifest. |
| `tests/run_tests.gd::_test_bile_bloomer_art_loads_for_board` | main inline | — | — | Current approved texture/portrait/rig/animation registration pin moves to one manifest-driven roster test. |
| `tests/run_tests.gd::_test_bile_bloomer_turn_order_portrait_loads` | main inline | — | — | Current approved texture/portrait/rig/animation registration pin moves to one manifest-driven roster test. |
| `tests/run_tests.gd::_test_campfire_bonfire_assets_keep_clean_alpha_edges` | main inline | — | — | Current approved texture/portrait/rig/animation registration pin moves to one manifest-driven roster test. |
| `tests/run_tests.gd::_test_chainbound_gaoler_board_art_is_taller_and_centered` | main inline | — | — | Current approved texture/portrait/rig/animation registration pin moves to one manifest-driven roster test. |
| `tests/run_tests.gd::_test_cinder_enemies_have_turn_order_portraits` | main inline | — | — | Current approved texture/portrait/rig/animation registration pin moves to one manifest-driven roster test. |
| `tests/run_tests.gd::_test_cinder_enemies_use_final_raster_art` | main inline | — | — | Current approved texture/portrait/rig/animation registration pin moves to one manifest-driven roster test. |
| `tests/run_tests.gd::_test_column_torch_idle_sheets_load_and_are_clean` | main inline | — | — | Current approved texture/portrait/rig/animation registration pin moves to one manifest-driven roster test. |
| `tests/run_tests.gd::_test_combat_board_keeps_equipment_data_off_player_sprite` | main inline | — | — | Current approved texture/portrait/rig/animation registration pin moves to one manifest-driven roster test. |
| `tests/run_tests.gd::_test_combat_board_loads_defense_heal_cast_frames` | main inline | — | — | Current approved texture/portrait/rig/animation registration pin moves to one manifest-driven roster test. |
| `tests/run_tests.gd::_test_combat_board_loads_door_icons_for_room_types` | main inline | — | — | Current approved texture/portrait/rig/animation registration pin moves to one manifest-driven roster test. |
| `tests/run_tests.gd::_test_combat_board_loads_elemental_projectile_atlas` | main inline | — | — | Current approved texture/portrait/rig/animation registration pin moves to one manifest-driven roster test. |
| `tests/run_tests.gd::_test_door_opening_sheet_loads_as_directional_frames` | main inline | — | — | Current approved texture/portrait/rig/animation registration pin moves to one manifest-driven roster test. |
| `tests/run_tests.gd::_test_elemental_trap_animation_sheets_load_and_respect_reduced_motion` | main inline | — | — | Current approved texture/portrait/rig/animation registration pin moves to one manifest-driven roster test. |
| `tests/run_tests.gd::_test_emaciated_man_uses_matching_idle_sheet` | main inline | — | — | Current approved texture/portrait/rig/animation registration pin moves to one manifest-driven roster test. |
| `tests/run_tests.gd::_test_enemy_art_offset_shifts_sprite_vertically` | main inline | — | — | Current approved texture/portrait/rig/animation registration pin moves to one manifest-driven roster test. |
| `tests/run_tests.gd::_test_enemy_art_scale_preserves_center` | main inline | — | — | Current approved texture/portrait/rig/animation registration pin moves to one manifest-driven roster test. |
| `tests/run_tests.gd::_test_enemy_shadow_dissolve_unifies_full_roster` | main inline | — | — | Current approved texture/portrait/rig/animation registration pin moves to one manifest-driven roster test. |
| `tests/run_tests.gd::_test_final_art_idle_shadows_keep_silhouettes_for_every_frame` | main inline | — | — | Current approved texture/portrait/rig/animation registration pin moves to one manifest-driven roster test. |
| `tests/run_tests.gd::_test_final_art_units_use_registered_cutouts` | main inline | — | — | Current approved texture/portrait/rig/animation registration pin moves to one manifest-driven roster test. |
| `tests/run_tests.gd::_test_lightning_wisp_uses_registered_cutout_art` | main inline | — | — | Current approved texture/portrait/rig/animation registration pin moves to one manifest-driven roster test. |
| `tests/run_tests.gd::_test_merchant_assets_load_for_board` | main inline | — | — | Current approved texture/portrait/rig/animation registration pin moves to one manifest-driven roster test. |
| `tests/run_tests.gd::_test_player_uses_promoted_cutout_art` | main inline | — | — | Current approved texture/portrait/rig/animation registration pin moves to one manifest-driven roster test. |
| `tests/run_tests.gd::_test_terrain_destruction_sheets_load_for_full_prop_roster` | main inline | — | — | Current approved texture/portrait/rig/animation registration pin moves to one manifest-driven roster test. |
| `tests/run_tests.gd::_test_trial_enemy_art_uses_registered_cutouts` | main inline | — | — | Current approved texture/portrait/rig/animation registration pin moves to one manifest-driven roster test. |
| `tests/run_tests.gd::_test_turn_order_portraits_cover_enemy_roster` | main inline | — | — | Current approved texture/portrait/rig/animation registration pin moves to one manifest-driven roster test. |
| `tests/run_tests.gd::_test_turn_order_uses_explicit_portraits_for_new_enemy_types` | main inline | — | — | Current approved texture/portrait/rig/animation registration pin moves to one manifest-driven roster test. |
| `tests/run_tests.gd::_test_unit_shadow_uses_alpha_silhouette` | main inline | — | — | Current approved texture/portrait/rig/animation registration pin moves to one manifest-driven roster test. |
| `tests/run_tests.gd::_test_zekarion_uses_registered_cutout_art` | main inline | — | — | Current approved texture/portrait/rig/animation registration pin moves to one manifest-driven roster test. |

#### Concrete replacement proposal

One proposed module, `tests/test_approved_content_manifest.py`, exposes one data-driven unittest that checks a single expanded `tests/approved_asset_pins.json` and invokes one generic Godot roster/export helper through the required task runner. The new names are proposed implementation locations, not files created by this analysis. Budget the entire driver, hashes and nested Godot helper at 30 seconds on one Python shard; do not register that helper a second time in the Godot pass.

Reuse the 1,061 current approved PNG/rig-JSON pins already present in `tests/approved_asset_pins.json`; extend the same manifest with the currently approved audio/UI/gear/biome/cel outputs that the MERGE and retired round-specific tests protect. Each family row names files/digests, current front/rear layout, texture dimensions and alpha/frame inventory where already approved, runtime resource paths, portrait/scale/registration values, expected clip availability and export roots. The generic helper checks referenced resources load from a production-only pack and both registered facings instantiate with finite transforms. Preserve the playtest-13 elemental-torch regression by checking its approved animated sheet and observable phase advance. Keep the Glacial Mirror’s approved sole registration in the manifest, with the generic placement check; do not drop it with its old Python file.

Hash approved assets/rig data, not gameplay source or historical proof receipts. Do not regenerate assets, replay old maquette builders, reseal certificates, compare per-round source provenance, record current bytes automatically as approval, or update owner-provided values. Existing approved art remains the authority. Unknown newly approved inputs must fail with a named inventory mismatch. During implementation, the new Python module needs a resource-table entry, expected `[]` only after confirming all writes are per-test temporary and all nested runner state is isolated.

### RETIRE

| File / call site | Kind | Seconds | Tests | One-line reason |
|---|---|---:|---:|---|
| `tests/test_rr41_feedback1.py` | Python | 449.148 | 7 | Past unit/feedback proof: Independent posed-region boundary and per-cloak ownership mutations. |
| `tests/test_cel_look.py` | Python | 365.701 | 12 | Mutation/rebuild pipeline for approved cel assets; current alpha/load semantics remain in KEEP cel_look_test.gd, approved outputs move to the manifest; export negatives move to on-demand export validation. |
| `tests/test_rr46_playback.py` | Python | 183.809 | 11 | Past unit/feedback proof: Production parity, negative controls and immutable rig/reference inputs. |
| `tests/test_rr38_feedback3.py` | Python | 129.907 | 2 | Past unit/feedback proof: Fresh CPU/native calibration against tracked, hash-bound round-2 witnesses. |
| `tests/owned_combat_creation_equivalence_test.gd` | Godot program | 129.093 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/test_rr07_production.py` | Python | 124.359 | 6 | Past unit/feedback proof: Real RunScene callbacks, plus frozen/contact/coverage mutations for rr-07. |
| `tests/test_pt14_01_coverage.py` | Python | 124.276 | 2 | Duplicate mutation sweeps of the sole/coverage solver; KEEP pt15_01_owner_feet_check.gd and threats_at_rest_test.gd for the playtest sole/readability bugs (B5). |
| `tests/test_maquette_pixel_polish.py` | Python | 119.806 | 13 | Past unit/feedback proof: rr-05 whole-feature, step-clock and temporal-residual mutations. |
| `tests/test_rr41_feedback3.py` | Python | 118.048 | 3 | Past unit/feedback proof: Walking repairs, real near-tie mutations and reproducible rest evidence. |
| `tests/test_board_pixel_density.py` | Python | 113.398 | 48 | Finished density derivation/calibration/pixel-resampling proof and its mutations; preserve current approved output inventory/hashes in the manifest, judge density visually. |
| `tests/test_rr37_feedback1.py` | Python | 110.592 | 5 | Past unit/feedback proof: Director feedback 1: exact rejected native fixtures and production runtime. |
| `tests/test_mq19_maquette.py` | Python | 109.190 | 27 | Past unit/feedback proof: mq-19 portable implementation proof. No native/GUI jobs during discovery. |
| `tests/test_rr37_production.py` | Python | 104.645 | 2 | Past unit/feedback proof: Real resolver-to-production contacts, both views, using temporary evidence. |
| `tests/test_rr44_motion.py` | Python | 101.163 | 6 | Past unit/feedback proof: Fresh Godot evidence and elbow, pendulum and held-follow mutations. |
| `tests/test_rr20_production.py` | Python | 89.856 | 4 | Past unit/feedback proof: Real resolver -> RunScene playback for both views and all copied attack kinds. |
| `tests/test_maquette_cutout.py` | Python | 84.208 | 45 | Past unit/feedback proof: Observable registration, ownership, hidden-material and approved-rest contracts. |
| `tests/test_mim01.py` | Python | 81.615 | 3 | Repeated Retaliate mutation witnesses and private-project driver; KEEP mim01_test.gd for expiry, range, preview and fatal suffix. |
| `tests/test_gait01.py` | Python | 80.735 | 21 | Past unit/feedback proof: Gait compiler contracts, real runtime mutations, and preservation evidence. |
| `tests/test_rr21_production.py` | Python | 78.309 | 3 | Past unit/feedback proof: Real resolver -> board playback acceptance, both front and true rear. |
| `tests/test_rr30_joint_surfaces.py` | Python | 76.742 | 4 | Past unit/feedback proof: Fresh full-sweep joint proof and a construction-disabled source mutation. |
| `tests/test_rr51_gaoler_scale.py` | Python | 75.536 | 14 | Past unit/feedback proof: rr-51: the Chainbound Gaoler at art_scale 1.10 on the hero's density rule. |
| `tests/test_rr39_clean_checkout.py` | Python | 74.868 | 1 | Past unit/feedback proof: Run the focused tie proof from a committed tree without ignored inputs. |
| `tests/test_pt15_01_owner_feet.py` | Python | 74.064 | 3 | Duplicate mutation sweeps of the sole/coverage solver; KEEP pt15_01_owner_feet_check.gd and threats_at_rest_test.gd for the playtest sole/readability bugs (B5). |
| `tests/test_rr49_native.py` | Python | 72.805 | 5 | Past unit/feedback proof: Final rr-44 native truth, current submissions and strict-gate mutations. |
| `tests/test_rr32_production.py` | Python | 72.793 | 3 | Past unit/feedback proof: Actual resolver -> RunScene -> two-view rig/SFX evidence and mutations. |
| `tests/test_rr41_lancer.py` | Python | 71.180 | 7 | Past unit/feedback proof: Protected leg lining, all front frames and restoration of the old bands. |
| `tests/test_rr35_production.py` | Python | 70.052 | 3 | Past unit/feedback proof: Actual resolver-to-production contact and movement proof, both true views. |
| `tests/test_rr12_production.py` | Python | 69.318 | 5 | Past unit/feedback proof: Real RunScene callbacks, plus frozen/contact/coverage mutations for rr-12. |
| `tests/test_rr17_production.py` | Python | 66.586 | 9 | Past unit/feedback proof: Actual RunScene callbacks, sound/VFX contact and strict action regressions. |
| `tests/test_rr42_gaoler.py` | Python | 65.730 | 10 | Past unit/feedback proof: Director paint, air, old-fill mutations and deterministic source partition. |
| `tests/test_rr32_herald.py` | Python | 64.703 | 22 | Past unit/feedback proof: rr32 implementation fidelity, director feedback 1 and strict failure mutations. |
| `tests/test_fix18_draw_origin.py` | Python | 61.449 | 4 | Duplicate Python mutation/proof wrapper; KEEP both real Continue/resize/movement regressions in tests/fix18/. |
| `tests/retained_character_inventory_equivalence_test.gd` | Godot program | 59.317 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/test_card_legibility.py` | Python | 58.604 | 5 | Duplicate Python launch/mutation wrapper; keep Sabatons no-shrink and visible-rule clipping regressions in KEEP card_legibility_test.gd. |
| `tests/prepared_unit_canvas_equivalence_test.gd` | Godot program | 58.077 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/card_display_unmodified_test.gd` | Godot program | 56.546 | — | Finished card-02 no-modifier equivalence sweep: all-card/all-context rendered bytes must equal a newly built baseline. KEEP modified-number/card-display regressions and card-panel content validation; retire the blanket unchanged-output oracle. |
| `tests/test_semantic_maquette_motion.py` | Python | 54.126 | 8 | Past unit/feedback proof: rr-04 authored-key, applied-bone and production freeze regressions. |
| `tests/test_rr21_review.py` | Python | 50.469 | 4 | Past unit/feedback proof: Cold review evidence and stale-capture routing; never claim GPU proof. |
| `tests/protagonist_gear_motion_gameplay_test.gd` | Godot program | 49.513 | — | Per-equipment art/clip/stride integration proof for a completed rig round; current approved gear assets and roster smoke move to MERGE. |
| `tests/test_rr15_action_direction.py` | Python | 48.825 | 8 | Past unit/feedback proof: Real Bone2D direction evidence and mutations, without a window server. |
| `tests/test_rr35_cutout.py` | Python | 47.970 | 22 | Past unit/feedback proof: rr-35 source fidelity, runtime integration and independent negative controls. |
| `tests/test_rr10_humanoid.py` | Python | 45.594 | 20 | Past unit/feedback proof: Two-view v2 evidence and planted regressions. Never launches a GUI. |
| `tests/test_rr43_lancer.py` | Python | 44.471 | 8 | Past unit/feedback proof: rr-43 director replay, exact front preservation and rigid spear mutations. |
| `tests/test_mq24_maquette.py` | Python | 42.738 | 53 | Past unit/feedback proof: mq-24 focused rules, preservation, independent geometry and proof guards. |
| `tests/test_pt14_04_coverage.py` | Python | 42.668 | 5 | Duplicate mutation sweeps of the sole/coverage solver; KEEP pt15_01_owner_feet_check.gd and threats_at_rest_test.gd for the playtest sole/readability bugs (B5). |
| `tests/test_rr47_feedback2.py` | Python | 42.660 | 3 | Past unit/feedback proof: Segment midpoint, exhaustive ground-depth oracle and native sample regressions. |
| `tests/test_rr47_depth.py` | Python | 41.897 | 4 | Retire historical before/after staging, native reconstruction and proof-save contracts; transfer missing_callbacks == 0 for back-row/diagonal movement into KEEP rr46/depth_check.gd (E5). |
| `tests/test_rr37_lancer.py` | Python | 41.408 | 12 | Past unit/feedback proof: rr-37: fresh headless evidence and constructed negative controls. |
| `tests/test_gust_shrike_cutout.py` | Python | 41.278 | 21 | Past unit/feedback proof: rr-03 pipeline failures and exact-registration contracts (no renderer). |
| `tests/test_rr18_humanoid.py` | Python | 41.143 | 20 | Past unit/feedback proof: Mirror source, runtime, preservation and adversarial gate checks; no GUI. |
| `tests/test_mq17_maquette.py` | Python | 40.530 | 46 | Past unit/feedback proof: Focused mq-17 geometry/pose and sealed delivery regressions; no engines. |
| `tests/prepared_other_character_view_test.gd` | Godot program | 40.461 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/perf/transition_failure_2_test.gd` | Godot program | 39.964 | — | Frozen-parent differential of completed persistence extraction; KEEP save_resume_boundary, opening-boon recovery, dragon reward outbox and background persistence for real failure semantics. |
| `tests/test_rr45_lancer.py` | Python | 39.885 | 7 | Past unit/feedback proof: mq-14 shaft depth, every current frame, and immutable bad native pixels. |
| `tests/perf/transition_failure_0_test.gd` | Godot program | 39.823 | — | Frozen-parent differential of completed persistence extraction; KEEP save_resume_boundary, opening-boon recovery, dragon reward outbox and background persistence for real failure semantics. |
| `tests/perf/transition_failure_1_test.gd` | Godot program | 39.620 | — | Frozen-parent differential of completed persistence extraction; KEEP save_resume_boundary, opening-boon recovery, dragon reward outbox and background persistence for real failure semantics. |
| `tests/noncombat_move_equivalence_test.gd` | Godot program | 38.325 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/test_rr29_mimic.py` | Python | 36.253 | 14 | Past unit/feedback proof: rr29 implementation fidelity and negative controls; no renderer claims. |
| `tests/test_rr44_feedback1.py` | Python | 35.508 | 8 | Past unit/feedback proof: Exact ownership/caps, release source and current production regression. |
| `tests/test_rr20_cutout.py` | Python | 34.497 | 12 | Past unit/feedback proof: rr-20 protected inputs, source contracts and negative controls; no GUI. |
| `tests/test_rr44_feedback1_calibration.py` | Python | 31.786 | 3 | Past unit/feedback proof: Director-native round-0 regression, independent of ignored proof logs. |
| `tests/section_map_v5_layout_test.gd` | Godot program | 30.875 | — | Pixel/position/control-size pins for the finished map layout; main KEEP map suites retain routes and controller navigation. |
| `tests/enc03_fixture_test.gd` | Godot program | 29.535 | — | Proof/contract and archived-before snapshot checks of the Slagmaster probe; KEEP live Slag/Lob/forecast rules. |
| `tests/test_mq20_maquette.py` | Python | 28.846 | 32 | Past unit/feedback proof: mq-20 source, native-proof guards and delivery wiring; temporary writes only. |
| `tests/pass_preview_prewarm_test.gd` | Godot program | 28.724 | — | Finished cache/prewarming hit/miss/query-ownership oracle; KEEP card-playability and truthful pass previews. |
| `tests/test_mq21_delivery.py` | Python | 28.662 | 20 | Past unit/feedback proof: Temporary-only sheet, replay binding and bridge deadline tests. |
| `tests/test_rr47_feedback1.py` | Python | 28.301 | 8 | Past unit/feedback proof: Translation-normalized archive guards and actual fight-output discovery. |
| `tests/test_mq18_maquette.py` | Python | 28.275 | 34 | Past unit/feedback proof: mq-18 constraints, native mutations and hash-bound native delivery. |
| `tests/test_rr21_cutout.py` | Python | 27.651 | 14 | Past unit/feedback proof: rr-21 implementation contracts and negative controls; no window server. |
| `tests/test_rr44_feedback2.py` | Python | 27.100 | 13 | Past unit/feedback proof: Director authority, strict painted grips and rest-contact repair regressions. |
| `tests/test_rr38_gaoler.py` | Python | 26.501 | 11 | Past unit/feedback proof: Fresh headless evidence and mutations; never read ignored proof logs. |
| `tests/suites/full_scene_presentation_program.gd` | Godot program | 26.308 | — | One-unit scene/presentation assertions overlap KEEP menu startup, event/enemy semantics; retire layout/motion schedules already judged by eye. |
| `tests/test_rr19_overlap.py` | Python | 24.702 | 9 | Past unit/feedback proof: rr-19: real enemy-phase overlap routing, Git-base parity and clock mutation. |
| `tests/test_rr39_native_ties.py` | Python | 24.130 | 11 | Past unit/feedback proof: Exact native edge candidates; interior defects and disagreements stay strict. |
| `tests/combat_pacing_mutation_test.gd` | Godot program | 23.814 | — | Mutation checks of another test/suite; keep product assertions, remove repeated proof that those assertions can fail. |
| `tests/perf/transition_failure_3_test.gd` | Godot program | 22.766 | — | Frozen-parent differential of completed persistence extraction; KEEP save_resume_boundary, opening-boon recovery, dragon reward outbox and background persistence for real failure semantics. |
| `tests/test_rr28_continuations.py` | Python | 21.797 | 9 | Past unit/feedback proof: rr-28 copies only own treated texels in the clips with joint tears. |
| `tests/test_maquette_certificates.py` | Python | 21.597 | 5 | Past unit/feedback proof: Promotion must reject stale paint, layouts and gate code before copying. |
| `tests/test_rr23_owner_fixes.py` | Python | 21.171 | 8 | Past unit/feedback proof: Regress the approved repaint's terminals, guard priority and air limits. |
| `tests/test_maquette_rear_turn.py` | Python | 20.608 | 19 | Past unit/feedback proof: Inspect delivered pixels: a rear turn exchanges camera-near body sides. |
| `tests/prepared_equipment_combat_test.gd` | Godot program | 20.102 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/test_production_crop_plan.py` | Python | 19.286 | 3 | Proof/contract checks of a probe, not a gameplay regression. |
| `tests/suites/forced_movement_query_dense_program.gd` | Godot program | 18.520 | — | Finished forced-movement query cache/refactor equivalence partition; KEEP ForcedMovementSuite and ManeuverSuite resolve live push/pull/blocker rules. |
| `tests/pre_battle_view_test.gd` | Godot program | 18.308 | — | Approved pre-battle colors, placement and presentation pins; KEEP pre-battle semantic suite retains actual enemy/rule content. |
| `tests/test_rr17_feedback.py` | Python | 18.246 | 6 | Past unit/feedback proof: Director feedback regressions against real production death/action callbacks. |
| `tests/test_rr11_humanoid.py` | Python | 17.974 | 14 | Past unit/feedback proof: Thrall source, production and mutation contracts; never launches a GUI. |
| `tests/test_mq15_maquette.py` | Python | 17.920 | 32 | Past unit/feedback proof: mq-15 authoring, native delivery and isolated fail-closed guard regressions. |
| `tests/test_rr37_feedback3.py` | Python | 17.174 | 11 | Past unit/feedback proof: Hash-bound rejected native proof and the complete uncovered-surface gate. |
| `tests/test_rr43_outline.py` | Python | 17.157 | 5 | Past unit/feedback proof: The supplied house edge changes colour, never partition or inner fills. |
| `tests/test_mq21_maquette.py` | Python | 17.008 | 24 | Past unit/feedback proof: mq-21 resolved geometry, bounded blade solve and independent mutation gates. |
| `tests/start_room_map_test.gd` | Godot program | 16.874 | — | Automatic map presentation/choreography from a past unit; KEEP section-map/run-state and map navigation suites retain reachability/input. |
| `tests/test_rr22_humanoid.py` | Python | 16.342 | 19 | Past unit/feedback proof: Slag Mortar implementation contracts and independent failure mutations. |
| `tests/surface_preview_equivalence_test.gd` | Godot program | 16.320 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/thr01_probe.gd` | Godot program | 16.014 | — | Headless probe plan/fixture/contract invocation; retire this duplicate pass check and retain its real windowed mode ON DEMAND. |
| `tests/prepared_reward_choices_test.gd` | Godot program | 15.745 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/test_rr20_feedback2.py` | Python | 14.627 | 7 | Past unit/feedback proof: rr-20 gait integration, compact provenance and continuation mutations. |
| `tests/test_rr17_cutout.py` | Python | 14.394 | 10 | Past unit/feedback proof: rr-17 exact painting, signed motion, presented pixels and mutation checks. |
| `tests/test_rr38_feedback1.py` | Python | 14.286 | 8 | Past unit/feedback proof: Director feedback 1: motion targets, real-pixel order and hidden rear arm. |
| `tests/test_mq16_maquette.py` | Python | 14.042 | 30 | Past unit/feedback proof: mq-16 source dimensions, exact director pose and native delivery contracts. |
| `tests/enemy_route_allocation_equivalence_test.gd` | Godot program | 13.903 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/test_rr15_reach.py` | Python | 13.777 | 4 | Past unit/feedback proof: Dense unclamped reach diagnostics and regressions for the old rear jab. |
| `tests/card_display_overrides_probe.gd` | Godot program | 13.122 | — | Headless probe plan/fixture/contract invocation; retire this duplicate pass check and retain its real windowed mode ON DEMAND. |
| `tests/test_rr31_finish_seams.py` | Python | 13.059 | 7 | Past unit/feedback proof: Director feedback 2: actual source coverage and non-blocking diagnostics. |
| `tests/test_rr38_feedback2.py` | Python | 12.868 | 6 | Past unit/feedback proof: Own-row continuations, strict seam mutation and accepted empty-node rule. |
| `tests/test_rr39_retained_bindings.py` | Python | 12.816 | 5 | Past unit/feedback proof: Optional zero certificates never weaken retained paint/geometry bindings. |
| `tests/test_rr31_storage.py` | Python | 12.457 | 6 | Past unit/feedback proof: Lossless cover-evidence packaging and real construction-reader compatibility. |
| `tests/test_rr30_mortar.py` | Python | 12.246 | 10 | Past unit/feedback proof: rr30 supplied-input, cut, hinge and hard acceptance contracts. |
| `tests/test_rr27_thrall.py` | Python | 12.243 | 11 | Past unit/feedback proof: rr-27 own-piece joint copies, frozen poses, and study evidence integrity. |
| `tests/dragon_exchange_presentation_test.gd` | Godot program | 12.166 | — | Past dragon exchange/title/banner/animation presentation pins; KEEP actual boss rules, reward ownership and transitions. |
| `tests/scavenger_visual_pass_4_test.gd` | Godot program | 11.926 | — | Unit-3 acceptance pins of shop typography, signage, shelf containment and presentation; KEEP Scavenger purchases and balances. |
| `tests/test_rr41_feedback2.py` | Python | 11.523 | 4 | Past unit/feedback proof: Retained death 82 proves a rigid transform rounding gap, not missing paint. |
| `tests/grimoire_search_rows_equivalence_test.gd` | Godot program | 11.107 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/test_rr10_bone_evidence.py` | Python | 11.067 | 5 | Past unit/feedback proof: Complete sampler evidence and independent torso/head limit mutations. |
| `tests/objective_glyph_equivalence_test.gd` | Godot program | 10.963 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/test_rr26_fragments.py` | Python | 10.555 | 4 | Past unit/feedback proof: Approved-pose preservation and the rr-26 source-edge regressions; no GUI. |
| `tests/retained_character_header_equivalence_test.gd` | Godot program | 10.334 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/static_floor_cache_equivalence_test.gd` | Godot program | 10.270 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/test_rr21_walk.py` | Python | 9.965 | 5 | Past unit/feedback proof: Weaver walk repairs, full-evidence binding and strict negative controls. |
| `tests/prepared_encounter_equivalence_test.gd` | Godot program | 9.900 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/test_rr24_feedback2.py` | Python | 9.820 | 8 | Past unit/feedback proof: Own-paint continuations, layout rest selection and root-relative proof crops. |
| `tests/status_capture_probe.gd` | Godot program | 9.415 | — | Headless probe plan/fixture/contract invocation; retire this duplicate pass check and retain its real windowed mode ON DEMAND. |
| `tests/retained_shop_rows_equivalence_test.gd` | Godot program | 9.095 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/prepared_travel_combat_test.gd` | Godot program | 9.012 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/test_rr17_integration.py` | Python | 9.006 | 5 | Past unit/feedback proof: Feedback 1: declarations are opt-in, prior production death clocks are exact. |
| `tests/test_native_frames.py` | Python | 9.004 | 15 | Past unit/feedback proof: Crop geometry, legacy IO, codecs, consumer metrics and evidence mutations. |
| `tests/surface_query_handoff_test.gd` | Godot program | 8.718 | — | Completed prepared-query coroutine/adoption equivalence proof; KEEP real surface/ability resolution and persistence boundaries. |
| `tests/prepared_card_preview_queries_test.gd` | Godot program | 8.609 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/prepared_equipment_scene_handoff_test.gd` | Godot program | 8.432 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/test_test_registration_audit.py` | Python | 8.112 | 32 | A test of the test-registration guard, including mutations of registration recognition; remove with the main guard, update explicit registries for the approved inventory. |
| `tests/retained_character_loadout_equivalence_test.gd` | Godot program | 7.906 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/committed_hand_queries_test.gd` | Godot program | 7.713 | — | Completed committed-hand query/cache memoization contract; KEEP card playability, targeting and preview correctness. |
| `tests/element_retrofit_probe.gd` | Godot program | 7.690 | — | Headless probe plan/fixture/contract invocation; retire this duplicate pass check and retain its real windowed mode ON DEMAND. |
| `tests/prepared_pre_battle_view_equivalence_test.gd` | Godot program | 7.624 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/warband_orders_probe.gd` | Godot program | 7.595 | — | Headless probe plan/fixture/contract invocation; retire this duplicate pass check and retain its real windowed mode ON DEMAND. |
| `tests/test_proof_runtime_paths.py` | Python | 7.547 | 7 | Proof/contract checks of a probe, not a gameplay regression. |
| `tests/staged_reward_choices_equivalence_test.gd` | Godot program | 7.503 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/test_biome_light_idle.py` | Python | 7.416 | 13 | Owner playtest-13 torches were frozen (B8): move shipped animated-sheet/phase-advance check to the manifest-driven KEEP replacement; retire regeneration, band/seam proof and mutation checks. |
| `tests/card_widget_layout_regression_test.gd` | Godot program | 7.213 | — | Duplicate historic card geometry/layout pins; KEEP card legibility/summary clipping regressions. |
| `tests/pre_battle_deck_fit_test.gd` | Godot program | 7.166 | — | Probe-derived deck containment/layout pins already judged by eye; retain real loadout/choice semantics. |
| `tests/test_rr39_lancer.py` | Python | 7.145 | 5 | Past unit/feedback proof: Director underlay identity, native rejection fixture and broad mutations. |
| `tests/test_proof_render_inputs.py` | Python | 7.023 | 6 | Proof/contract checks of a probe, not a gameplay regression. |
| `tests/test_rr42_feedback2.py` | Python | 7.014 | 8 | Past unit/feedback proof: Retained native calibration and exact tuck ownership; no ignored logs required. |
| `tests/retained_character_deck_equivalence_test.gd` | Godot program | 6.979 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/rr38/runtime_checks.gd` | Godot program | 6.765 | — | Past rig round: historical callbacks, paint, depth or clock pins; current assets/roster move to one manifest, renderer proof stays ON DEMAND. |
| `tests/wbv_markers_test.gd` | Godot program | 6.504 | — | Past Warband board-marker draw geometry/style pins; KEEP orders/Warband semantics and actual captions. |
| `tests/equipment_inventory_readability_test.gd` | Godot program | 6.407 | — | One-unit font/size/inventory-layout readability pins; assets consolidate and owner inspects the real renderer. |
| `tests/structural_route_equivalence_test.gd` | Godot program | 6.386 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/suites/forced_movement_query_surface_ready_program.gd` | Godot program | 6.320 | — | Finished forced-movement query cache/refactor equivalence partition; KEEP ForcedMovementSuite and ManeuverSuite resolve live push/pull/blocker rules. |
| `tests/combat_analytics_context_equivalence_test.gd` | Godot program | 6.257 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/summon_card_play_regression_test.gd` | Godot program | 6.114 | — | Duplicate invocation of the main-body draw/play/death/status/relic/initiative assertions and GuardianSuite cases; keep those assertions in their owning KEEP suites. |
| `tests/test_mq09_maquettes.py` | Python | 5.915 | 17 | Past unit/feedback proof: Batch C source protection, shoulder/turn rules and sealed native delivery. |
| `tests/health_ghost_test.gd` | Godot program | 5.906 | — | Historical health-bar ghost animation/theme pins; real HP and damage-preview semantics remain in KEEP suites. |
| `tests/merchant_stock_equivalence_probe.gd` | Godot program | 5.775 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/test_rr24_thrall.py` | Python | 5.722 | 11 | Past unit/feedback proof: mq7b source, collar, skirt and guard-removal regressions; no GUI. |
| `tests/prepared_shop_glyph_equivalence_test.gd` | Godot program | 5.593 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/pre_battle_true_scale_test.gd` | Godot program | 5.589 | — | Approved pre-battle rendering scale/layout pins already judged by eye. |
| `tests/retained_section_map_equivalence_test.gd` | Godot program | 5.570 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/rr12/runtime_test.gd` | Godot program | 5.345 | — | Past rig round: historical callbacks, paint, depth or clock pins; current assets/roster move to one manifest, renderer proof stays ON DEMAND. |
| `tests/combat_boundary_equivalence_test.gd` | Godot program | 5.195 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/board_surface_probe_migration_test.gd` | Godot program | 5.148 | — | Headless probe plan/fixture/contract invocation; retire this duplicate pass check and retain its real windowed mode ON DEMAND. |
| `tests/dragon_pressure_mechanics_test.gd` | Godot program | 5.019 | — | Duplicate ordinary-pass wrapper of the same rules suite already invoked by tests/run_tests.gd; retain all main-body assertions and reusable source. |
| `tests/pixel_fx_test.gd` | Godot program | 5.012 | — | Approved pixel-treatment, shader and draw-style pins; native rendering/visual judgment remains on demand. |
| `tests/fix_12_probe.gd` | Godot program | 5.004 | — | Headless probe plan/fixture/contract invocation; retire this duplicate pass check and retain its real windowed mode ON DEMAND. |
| `tests/rr07/runtime_test.gd` | Godot program | 4.990 | — | Past rig round: historical callbacks, paint, depth or clock pins; current assets/roster move to one manifest, renderer proof stays ON DEMAND. |
| `tests/test_mq13_delivery.py` | Python | 4.889 | 15 | Past unit/feedback proof: Articulated pose gates cannot be waived by a passing old delivery seal. |
| `tests/test_rr12_delivery.py` | Python | 4.779 | 14 | Past unit/feedback proof: rr-12 input provenance and feature policy; no native-renderer claims. |
| `tests/en05_enemies_test.gd` | Godot program | 4.712 | — | Duplicate ordinary-pass wrapper of the same rules suite already invoked by tests/run_tests.gd; retain all main-body assertions and reusable source. |
| `tests/suites/forced_movement_query_open_program.gd` | Godot program | 4.709 | — | Finished forced-movement query cache/refactor equivalence partition; KEEP ForcedMovementSuite and ManeuverSuite resolve live push/pull/blocker rules. |
| `tests/rr46/paint_checks_test.gd` | Godot program | 4.664 | — | Past rig round: historical callbacks, paint, depth or clock pins; current assets/roster move to one manifest, renderer proof stays ON DEMAND. |
| `tests/suites/forced_movement_query_heart_program.gd` | Godot program | 4.600 | — | Finished forced-movement query cache/refactor equivalence partition; KEEP ForcedMovementSuite and ManeuverSuite resolve live push/pull/blocker rules. |
| `tests/board_hover_coalescing_test.gd` | Godot program | 4.578 | — | Coalesced-event/call-count optimization contract; KEEP HUD and board navigation tests retain observable mouse/controller behavior. |
| `tests/rr17/runtime_test.gd` | Godot program | 4.557 | — | Past rig round: historical callbacks, paint, depth or clock pins; current assets/roster move to one manifest, renderer proof stays ON DEMAND. |
| `tests/dragon_element_rules_probe.gd` | Godot program | 4.518 | — | Headless probe plan/fixture/contract invocation; retire this duplicate pass check and retain its real windowed mode ON DEMAND. |
| `tests/bos01_rules_probe.gd` | Godot program | 4.466 | — | Headless probe plan/fixture/contract invocation; retire this duplicate pass check and retain its real windowed mode ON DEMAND. |
| `tests/test_rr13_continuations.py` | Python | 4.333 | 2 | Past unit/feedback proof: Feedback-3 filled seams, unchanged garment fields and exact source rest. |
| `tests/en05_enemies_probe.gd` | Godot program | 4.291 | — | Headless probe plan/fixture/contract invocation; retire this duplicate pass check and retain its real windowed mode ON DEMAND. |
| `tests/relic_u8_test.gd` | Godot program | 4.280 | — | Duplicate invocation of a live relic suite already executed by tests/run_tests.gd; keep the main-body relic suite and all its assertions. |
| `tests/rr18/runtime_test.gd` | Godot program | 4.254 | — | Past rig round: historical callbacks, paint, depth or clock pins; current assets/roster move to one manifest, renderer proof stays ON DEMAND. |
| `tests/battlefield_rules_probe.gd` | Godot program | 4.219 | — | Headless probe plan/fixture/contract invocation; retire this duplicate pass check and retain its real windowed mode ON DEMAND. |
| `tests/en05_probe_contract_test.gd` | Godot program | 4.214 | — | Headless probe plan/fixture/contract invocation; retire this duplicate pass check and retain its real windowed mode ON DEMAND. |
| `tests/elemental_spell_fx_test.gd` | Godot program | 4.210 | — | Approved spell draw-style, ingredients and geometry smoke; renderer inspection remains ON DEMAND, combat outcomes stay KEEP. |
| `tests/relic_u6_test.gd` | Godot program | 4.171 | — | Duplicate invocation of a live relic suite already executed by tests/run_tests.gd; keep the main-body relic suite and all its assertions. |
| `tests/pre_battle_pinned_hover_test.gd` | Godot program | 4.153 | — | Pinned hover geometry/presentation test; KEEP pre_battle_ui_suite retains source lifetimes and meaningful hover content. |
| `tests/en06_enemies_probe.gd` | Godot program | 4.152 | — | Headless probe plan/fixture/contract invocation; retire this duplicate pass check and retain its real windowed mode ON DEMAND. |
| `tests/pre_battle_review_fixes_test.gd` | Godot program | 4.144 | — | Past review-round strip/tag width/overflow layout pins already judged by eye. |
| `tests/en02_enemies_test.gd` | Godot program | 4.103 | — | Duplicate ordinary-pass wrapper of en02_enemies_suite.run, already executed by the main body; retain the suite and its exact assertions. |
| `tests/en03_enemies_probe.gd` | Godot program | 4.060 | — | Headless probe plan/fixture/contract invocation; retire this duplicate pass check and retain its real windowed mode ON DEMAND. |
| `tests/sta01_enemies_probe.gd` | Godot program | 4.055 | — | Headless probe plan/fixture/contract invocation; retire this duplicate pass check and retain its real windowed mode ON DEMAND. |
| `tests/suites/forced_movement_query_blocked_program.gd` | Godot program | 4.023 | — | Finished forced-movement query cache/refactor equivalence partition; KEEP ForcedMovementSuite and ManeuverSuite resolve live push/pull/blocker rules. |
| `tests/gust_shrike_cutout_test.gd` | Godot program | 4.003 | — | Past Shrike rig action/pose/registration contract; keep combat Dive behavior in en05 suites and current assets in MERGE. |
| `tests/en04_enemies_test.gd` | Godot program | 3.985 | — | Duplicate ordinary-pass wrapper of the same rules suite already invoked by tests/run_tests.gd; retain all main-body assertions and reusable source. |
| `tests/shop_recovery_probe.gd` | Godot program | 3.970 | — | Headless probe plan/fixture/contract invocation; retire this duplicate pass check and retain its real windowed mode ON DEMAND. |
| `tests/relic_u5_test.gd` | Godot program | 3.954 | — | Duplicate invocation of a live relic suite already executed by tests/run_tests.gd; keep the main-body relic suite and all its assertions. |
| `tests/test_rr07_delivery.py` | Python | 3.903 | 14 | Past unit/feedback proof: rr-07 input provenance and feature policy; no native-renderer claims. |
| `tests/test_mq14_lancer.py` | Python | 3.887 | 14 | Past unit/feedback proof: mq-14 native recipe, opt-in contact contract, and sealed delivery regressions. |
| `tests/int11_objective_probe.gd` | Godot program | 3.868 | — | Headless probe plan/fixture/contract invocation; retire this duplicate pass check and retain its real windowed mode ON DEMAND. |
| `tests/test_maquette_owner_proof.py` | Python | 3.777 | 5 | Past unit/feedback proof: Check owner proof ordering and creature isolation with inert command stubs. |
| `tests/test_rr44_gaoler.py` | Python | 3.752 | 8 | Past unit/feedback proof: Protected rr-44 paint, source cuts, painted backing and historical fixture. |
| `tests/cutout_submission_equivalence_test.gd` | Godot program | 3.556 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/card_proxy_pool_test.gd` | Godot program | 3.550 | — | Pool count, reuse and transform pins from finished proxy pooling; KEEP drag/input suites cover successful and cancelled plays. |
| `tests/shadow_triangulation_equivalence_test.gd` | Godot program | 3.521 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/guardian_rules_probe.gd` | Godot program | 3.507 | — | Headless probe plan/fixture/contract invocation; retire this duplicate pass check and retain its real windowed mode ON DEMAND. |
| `tests/test_rr28_shadow.py` | Python | 3.443 | 1 | Past unit/feedback proof: Capacitor shadow records stay exact while other figures evolve. |
| `tests/last_light_probe.gd` | Godot program | 3.433 | — | Headless probe plan/fixture/contract invocation; retire this duplicate pass check and retain its real windowed mode ON DEMAND. |
| `tests/test_native_review_readers.py` | Python | 3.199 | 7 | Past unit/feedback proof: Exercise additional readers found by the repository-wide native IO audit. |
| `tests/test_arc_thrall_proof_validation.py` | Python | 3.189 | 6 | Proof/contract checks of a probe, not a gameplay regression. |
| `tests/test_glacial_mirror_shoulder.py` | Python | 3.084 | 12 | Past unit/feedback proof: mq-08: a bounded shoulder edit, preserved anatomy, complete capture batches. |
| `tests/test_rr40_feedback.py` | Python | 3.046 | 1 | Past unit/feedback proof: The isolated production package must exercise the registered v2 adapter. |
| `tests/cutout_pose_application_test.gd` | Godot program | 3.040 | — | Finished bone-transform setter equivalence oracle; current rig smoke and approved data pins consolidate into MERGE. |
| `tests/test_rr14_anatomy.py` | Python | 2.891 | 9 | Past unit/feedback proof: Schema validation and authored straight-leg direction, including failures. |
| `tests/test_rr35_native_defects.py` | Python | 2.851 | 9 | Past unit/feedback proof: rr36 regression diagnostics using the exact director-rejected native frames. |
| `tests/card_presentation_cache_test.gd` | Godot program | 2.781 | — | Card cache key/alias/copy and invalidation implementation oracle after the finished cache refactor. |
| `tests/test_rr26_hem_attachments.py` | Python | 2.748 | 6 | Past unit/feedback proof: Neighbour inheritance, original-paint coverage and hem-fragment mutations. |
| `tests/test_rr42_feedback3.py` | Python | 2.630 | 1 | Past unit/feedback proof: The candidate regression runs alone using tracked working-tree inputs. |
| `tests/dragon_area_presentation_test.gd` | Godot program | 2.577 | — | Dragon area marker/flare presentation pins already judged by eye; KEEP committed-pattern damage/counterplay. |
| `tests/profile_read_equivalence_test.gd` | Godot program | 2.537 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/test_mq16_proof_guards.py` | Python | 2.528 | 8 | Past unit/feedback proof: Feedback-3 regressions; every mutation/write is in per-test temp storage. |
| `tests/test_rr15_native_cleanup.py` | Python | 2.498 | 7 | Past unit/feedback proof: Native failure fixtures and CPU regressions for Thrall source cleanup. |
| `tests/magic_deck_guard_mutation_test.gd` | Godot program | 2.474 | — | Mutation checks of another test/suite; keep product assertions, remove repeated proof that those assertions can fail. |
| `tests/shop_retained_content_test.gd` | Godot program | 2.463 | — | Retained control-instance/cache-detail identity contract after completed shop caching; KEEP purchases and controller input. |
| `tests/test_rr31_images.py` | Python | 2.286 | 14 | Past unit/feedback proof: Pixel formulas, historical native negatives, contour attribution and budgets. |
| `tests/performance_phase_fast_path_test.gd` | Godot program | 2.266 | — | Finished phase-partitioner fast-path equivalence oracle; KEEP telemetry phase/schema functionality. |
| `tests/prepared_shop_equivalence_test.gd` | Godot program | 2.207 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/test_rr26_consolidation.py` | Python | 2.188 | 2 | Past unit/feedback proof: Consolidated action selection and hash-verified committed pose recovery. |
| `tests/biome_test.gd` | Godot program | 2.140 | — | Approved biome texture/framing/prop selection pins; current approved files move to the manifest, real-renderer inspection checks composition. |
| `tests/summon_card_play_probe.gd` | Godot program | 1.777 | — | Headless probe plan/fixture/contract invocation; retire this duplicate pass check and retain its real windowed mode ON DEMAND. |
| `tests/test_rr10_tucks.py` | Python | 1.747 | 6 | Past unit/feedback proof: Feedback 4 source contracts, all-pose attachments and native seam mutations. |
| `tests/test_rr15_shoulder.py` | Python | 1.734 | 2 | Past unit/feedback proof: Reopen the director's three native shoulder holes with the retained texture. |
| `tests/special_encounter_legend_test.gd` | Godot program | 1.639 | — | Approved map legend/copy placement pins already judged by eye; KEEP encounter data/placement and objective semantics. |
| `tests/test_grb01_floating_roster.py` | Python | 1.603 | 2 | UI layout/style inventory already judged by eye; production input/meaning stays covered by KEEP Godot tests. |
| `tests/test_rr14_foundations.py` | Python | 1.512 | 6 | Past unit/feedback proof: Second anatomy exercises the same compiler, gates, ownership and runtime. |
| `tests/test_rr10_reveal_fills.py` | Python | 1.499 | 2 | Past unit/feedback proof: rr-13 source regressions; native mesh seam acceptance stays windowed. |
| `tests/el02_evidence.gd` | Godot program | 1.482 | — | Headless probe plan/fixture/contract invocation; retire this duplicate pass check and retain its real windowed mode ON DEMAND. |
| `tests/test_mq15_pose_fit.py` | Python | 1.419 | 7 | Past unit/feedback proof: Front-fit regression guards and opt-in non-scaling pose transforms. |
| `tests/test_rr24_policies.py` | Python | 1.386 | 8 | Past unit/feedback proof: Decided Thrall air/ownership rules: paint and tucks can never become air. |
| `tests/owned_cpu_asset_preparation_test.gd` | Godot program | 1.368 | — | Finished CPU-preparation resource ownership/equivalence proof; approved assets move to MERGE. |
| `tests/guardian_cutout_motion_probe.gd` | Godot program | 1.306 | — | Headless probe plan/fixture/contract invocation; retire this duplicate pass check and retain its real windowed mode ON DEMAND. |
| `tests/humanoid_cutout_reaction_motion_probe.gd` | Godot program | 1.283 | — | Headless probe plan/fixture/contract invocation; retire this duplicate pass check and retain its real windowed mode ON DEMAND. |
| `tests/test_mq12_shoulders.py` | Python | 1.268 | 11 | Past unit/feedback proof: mq-12 pose constraints: exercise lengths, protected inputs and real builders. |
| `tests/test_glacial_mirror_regeneration.py` | Python | 1.167 | 8 | Past unit/feedback proof: Fresh and resumed maquette regeneration must retain an input-only snapshot. |
| `tests/test_rr10_layout_parity.py` | Python | 1.160 | 1 | Past unit/feedback proof: Authoring, production and density/rebaker layouts describe the same rig. |
| `tests/surface_relic_test.gd` | Godot program | 1.146 | — | Duplicate ordinary-pass wrapper of the same rules suite already invoked by tests/run_tests.gd; retain all main-body assertions and reusable source. |
| `tests/dragon_spire_routes_test.gd` | Godot program | 1.129 | — | Duplicate ordinary-pass wrapper of the same rules suite already invoked by tests/run_tests.gd; retain all main-body assertions and reusable source. |
| `tests/test_rr16_feedback1.py` | Python | 1.029 | 4 | Past unit/feedback proof: Director regressions for rotation-only supports and nonlinear reach bounds. |
| `tests/test_maquette_native_alpha.py` | Python | 0.992 | 3 | Past unit/feedback proof: Immutable saved native fade captures; no window-server dependency. |
| `tests/test_rr14_bone_guards.py` | Python | 0.987 | 2 | Past unit/feedback proof: Negative IK evidence isolates direction and target from segment lengths. |
| `tests/test_rr10_rope.py` | Python | 0.957 | 6 | Past unit/feedback proof: Exact director rope ownership and cloth-under-tail regressions; headless. |
| `tests/test_rr10_occluded_foot.py` | Python | 0.922 | 5 | Past unit/feedback proof: Feedback 6: exact boot donors, hidden rest and physical regressions. |
| `tests/test_rr10_rear.py` | Python | 0.878 | 4 | Past unit/feedback proof: rr-10 rear, shoulder continuation and frozen-front regressions; no GUI. |
| `tests/skill_tree_view_test.gd` | Godot program | 0.859 | — | Skill-view typography/layout and render-size pins; KEEP skill topology, learning and progression rules. |
| `tests/skill_link_geometry_equivalence_test.gd` | Godot program | 0.840 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/test_rr15_view_keys.py` | Python | 0.805 | 4 | Past unit/feedback proof: Whole-channel view replacement, legacy preservation and real sampling. |
| `tests/ui_components_gallery_fixture_test.gd` | Godot program | 0.746 | — | Proof/contract check of the visual gallery fixture, not product behavior. |
| `tests/test_rr30_proof.py` | Python | 0.689 | 5 | Past unit/feedback proof: Certification failure and exact owner-driver wiring; no windowed execution. |
| `tests/ui_skin_performance_test.gd` | Godot program | 0.688 | — | Finished style-resource sharing/copy-isolation optimization oracle; no player rule changes. |
| `tests/test_rr10_feedback.py` | Python | 0.681 | 4 | Past unit/feedback proof: Feedback proof plumbing and physical mutations; no windowed launch. |
| `tests/scavenger_resource_cache_test.gd` | Godot program | 0.670 | — | Finished shop resource-cache template/reuse oracle; KEEP Scavenger purchases and balances remain. |
| `tests/frostglass_lancer_motion_test.gd` | Godot program | 0.649 | — | Old experimental Lancer pose/time pins; current production inputs consolidate into MERGE. |
| `tests/test_rr31_calibration.py` | Python | 0.623 | 8 | Past unit/feedback proof: Focused calibration provenance, maxima, draw order and mutation checks. |
| `tests/test_mq11_accessories.py` | Python | 0.597 | 22 | Past unit/feedback proof: mq-11 portable geometry, preservation, measurement and bridge contracts. |
| `tests/chainbound_gaoler_motion_test.gd` | Godot program | 0.564 | — | Old experimental Gaoler motion pose/time pins, superseded by the approved production rig manifest. |
| `tests/elemental_fx_hash_equivalence_test.gd` | Godot program | 0.557 | — | Finished optimization/refactor oracle against a frozen builder, cache or submission path; gameplay/save outcomes remain in KEEP tests. |
| `tests/test_maquette_native_raster.py` | Python | 0.557 | 8 | Past unit/feedback proof: Replay director-captured pixels without requiring a window server. |
| `tests/test_rr39_proof_rerun.py` | Python | 0.507 | 1 | Past unit/feedback proof: Execute the real density-stage command list twice; stub only its programs. |
| `tests/combat_preview_memo_test.gd` | Godot program | 0.458 | — | Finished memo ownership/retention/cache-key oracle; KEEP semantic preview agreement in combat suites. |
| `tests/test_mq12_preservation.py` | Python | 0.454 | 1 | Past unit/feedback proof: Current compiled maquette output goldens; no historical source seals. |
| `tests/test_mq15_cloth.py` | Python | 0.442 | 6 | Past unit/feedback proof: Cloth coverage, ragged hems and real chain grip fail-closed regressions. |
| `tests/test_mq15_native_geometry.py` | Python | 0.389 | 4 | Past unit/feedback proof: Review reproductions inspect native arrays, leaving the recipe unchanged. |
| `tests/test_mq11_freshness.py` | Python | 0.372 | 9 | Past unit/feedback proof: Portable input-snapshot and native-triangle replay acceptance regressions. |
| `tests/test_maquette_silhouette.py` | Python | 0.340 | 6 | Past unit/feedback proof: rr-05 orphan and widened-joint mutations on synthetic proof-only pixels. |
| `tests/test_mq11_crack_visibility.py` | Python | 0.305 | 10 | Past unit/feedback proof: Registered crack stroke coverage and hair-depth visibility, without Blender. |
| `tests/test_rr25_mortar_finish.py` | Python | 0.302 | 3 | Past unit/feedback proof: Updated Mortar mask regression and foreign-surface contamination mutations. |
| `tests/test_mq11_validation.py` | Python | 0.282 | 10 | Past unit/feedback proof: Behavioral guards for the director's mq-11 review findings. |
| `tests/test_arc_thrall_maquette_r2.py` | Python | 0.264 | 15 | Past unit/feedback proof: mq-07: exact-length arm correction, capped forearm and unchanged roster. |
| `tests/test_mq11_guard_mutations.py` | Python | 0.246 | 1 | Past unit/feedback proof: Prove the four surviving review mutations now fail behavioral tests in memory. |
| `tests/test_rr22_source_space.py` | Python | 0.246 | 10 | Past unit/feedback proof: Director negative-space rule: source air passes, damaged paint never does. |
| `tests/test_rr34_layering.py` | Python | 0.216 | 4 | Past unit/feedback proof: Herald cloth depth regression; exercise both editable and shipped meshes. |
| `tests/test_mq09_forms.py` | Python | 0.212 | 13 | Past unit/feedback proof: Corrective native forms, including measured director feedback-3 gates. |
| `tests/test_rr20_rest_space.py` | Python | 0.123 | 11 | Past unit/feedback proof: Generic spec §1 source-air and rigid detached-paint mutations. |
| `tests/test_mq14_builder.py` | Python | 0.099 | 5 | Past unit/feedback proof: Effective regressions for mq-14's opt-in generic builder additions. |
| `tests/test_mq13_pose.py` | Python | 0.086 | 8 | Past unit/feedback proof: mq-13 target and preservation checks; no native/render success inferred. |
| `tests/test_rr16_review_fixes.py` | Python | 0.084 | 6 | Past unit/feedback proof: rr-15 adversarial inputs: mode-only metadata, narrow reach and exact pockets. |
| `tests/test_mq13_saved_body.py` | Python | 0.074 | 7 | Past unit/feedback proof: Saved-body mutations must fail before observation, capture or resume reuse. |
| `tests/test_rr20_residue.py` | Python | 0.067 | 7 | Past unit/feedback proof: Director feedback-1 boundaries, same-piece donors and GPU-mask contracts. |
| `tests/test_fix_11_labels.py` | Python | 0.061 | 2 | Source-tree scan for retired labels; KEEP enemy_no_action_test.gd checks actual resolver reasons and captions. |
| `tests/test_rr21_residue.py` | Python | 0.059 | 6 | Past unit/feedback proof: Feedback-1 chroma band, source-preserving cleanup and frame exemptions. |
| `tests/test_transition_differential.py` | Python | 0.049 | 4 | Completed transition-oracle partition guard; the historical differential children are retired after preserving actual save boundaries. |
| `tests/test_button_system_inventory.py` | Python | 0.047 | 3 | UI layout/style inventory already judged by eye; production input/meaning stays covered by KEEP Godot tests. |
| `tests/test_rr10_native_exceptions.py` | Python | 0.040 | 5 | Past unit/feedback proof: Director-reviewed rr-13 exceptions never widen to a clip or another rule. |
| `tests/test_rr18_air_policy.py` | Python | 0.040 | 9 | Past unit/feedback proof: Director-approved air passes; missing stone/tuck/mirror pixels never do. |
| `tests/test_rr37_feedback2.py` | Python | 0.033 | 6 | Past unit/feedback proof: Released spear policy: full item provenance, never a blanket death waiver. |
| `tests/test_player_ui_scrollbars.py` | Python | 0.033 | 2 | UI layout/style inventory already judged by eye; production input/meaning stays covered by KEEP Godot tests. |
| `tests/test_maquette_regressions.py` | Python | 0.022 | 16 | Past unit/feedback proof: Review regressions: capture provenance, weighted labels, curves and facing. |
| `tests/test_rr10_silhouette_gates.py` | Python | 0.018 | 5 | Past unit/feedback proof: Director feedback 3 thresholds and native far-elbow regression proof. |
| `tests/test_rr39_density_partitions.py` | Python | 0.016 | 9 | Past unit/feedback proof: Opt-in density partitions preserve exact, hash-bound registered paint. |
| `tests/test_card_completion_stall.py` | Python | 0.014 | 13 | Proof/contract checks of a probe, not a gameplay regression. |
| `tests/test_rr18_materials.py` | Python | 0.013 | 8 | Past unit/feedback proof: Nearest own-surface continuations, rounded domains and strict green checks. |
| `tests/test_rr30_stretch.py` | Python | 0.013 | 15 | Past unit/feedback proof: Independent affine, folded-triangle, limit and evidence regressions. |
| `tests/test_hero_facing_tools.py` | Python | 0.011 | 3 | Proof/contract checks of a probe, not a gameplay regression. |
| `tests/test_maquette_native_ties.py` | Python | 0.010 | 10 | Past unit/feedback proof: Invalid ties count as changed pixels; held flips and excess changes fail. |
| `tests/test_mq12_motion.py` | Python | 0.009 | 3 | Past unit/feedback proof: Execute the real application with native-API fixtures and reviewed mutations. |
| `tests/test_main_menu_steam_branding.py` | Python | 0.003 | 3 | UI layout/style inventory already judged by eye; production input/meaning stays covered by KEEP Godot tests. |
| `tests/test_rr12_stray.py` | Python | 0.003 | 4 | Past unit/feedback proof: Mutation coverage for the strict eight-pixel presented-frame gate. |
| `tests/test_rr14_continuation_domains.py` | Python | 0.001 | 3 | Past unit/feedback proof: Invoke the generator directly; each constraint has an independent negative. |
| `tests/test_engine_cache_proof.py` | Python | 0.000 | 4 | Proof/contract checks of a probe, not a gameplay regression. |
| `tests/helpers/test_registration_guard.gd` | main suite | — | — | Checks registration of tests, not product behavior; replace recursive completeness policy with explicit approved manifests. |
| `tests/run_tests.gd::_test_boss_health_overlay_caps_divider_density` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_boss_intent_layout_needs_no_global_board_banner` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_boundary_prop_art_uses_single_tile_footprint` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_boundary_wall_corner_tiles_split_into_two_half_segments` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_boundary_wall_segments_use_full_spans_on_straight_edges` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_combat_board_ambient_particles_follow_room_element` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_combat_board_aoe_footprint_timing` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_combat_board_assigns_deterministic_floor_variants` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_combat_board_default_framing_contains_tallest_top_corner_occupant` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_combat_board_hides_outer_walls_without_hiding_visible_doors` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_combat_board_refreshes_top_framing_when_scene_prop_appears_in_cached_room` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_combat_board_refreshes_top_framing_when_tall_occupant_appears_in_cached_room` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_combat_board_zooms_to_rendered_room_bounds` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_default_theme_uses_readable_text_font` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_door_art_uses_source_and_flipped_variant` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_door_frames_slide_toward_each_back_edge` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_dragon_idle_redraw_targets_footprint_draw_layer` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_elemental_room_overlays_are_decorative_and_distinct` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_enemy_hud_does_not_duplicate_owning_actor_obstacle` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_enemy_hud_ignores_subpixel_obstacle_slivers` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_enemy_hud_layout_offsets_away_from_reserved_ui` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_enemy_hud_side_offset_clears_only_vertically_overlapping_pieces` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_enemy_hud_side_selection_is_stable_during_small_layout_changes` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_enemy_hud_small_top_correction_stays_centered` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_enemy_intent_action_rows_use_readable_scale` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_enemy_intent_contour_expands_on_hover_or_toggle` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_enemy_intent_contour_stays_anchored_at_top_edge` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_enemy_intent_contour_uses_right_shoulder` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_enemy_intent_name_reserves_header_line` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_enemy_intent_popup_expands_for_long_titles` | main inline | — | — | Popup width/layout pin already judged by eye; KEEP intent content and targeting semantics. |
| `tests/run_tests.gd::_test_foreground_props_fade_when_covering_behind_objects` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_hand_fan_layout_lifts_center_cards` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_health_bar_segments_use_fixed_point_scale` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_large_map_decision_layer` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_minimap_travel_animation_state` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_minimap_uses_door_icons_and_greys_cleared_rooms` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_original_music_routes` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_pillar_art_fits_bottom_center_without_stretching` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_pillar_moss_overlay_is_anchored_to_pillar_cap` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_pillar_torch_fixtures_mount_on_both_visible_faces` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_room_generation_uses_stone_floor_with_moss_accents` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_standalone_door_art_stays_within_single_tile_footprint` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_support_intent_target_marker_is_text_only` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_ui_skin_button_system` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_ui_typography_system` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_unit_hud_stacks_above_sprite_art` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_visible_doors_use_dedicated_frame` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/run_tests.gd::_test_wall_and_pillar_assets_stay_distinct` | main inline | — | — | UI/board layout, framing, style or animation pin already checked by eye; inspect in owner renderer/pre-release pass. |
| `tests/suites/attack_fx_suite.gd` | main suite | — | — | Authored FX geometry/motion/style pins already judged visually. |
| `tests/suites/attack_sfx_suite.gd` | main suite | — | — | Sound feedback mapping/flip timing already judged during capture. |
| `tests/suites/combat_board_layout_suite.gd` | main suite | — | — | Fixed framing/layout pins already checked by eye. |
| `tests/suites/combat_lighting_profiles_suite.gd` | main suite | — | — | Approved lighting/layout constants already judged visually. |
| `tests/suites/health_bar_theme_suite.gd` | main suite | — | — | Health-bar colors, segments and style pins already checked by eye. |
| `tests/suites/skill_tree_completion_equivalence_suite.gd` | main suite | — | — | Finished completion-cache equivalence oracle; skill-tree topology and purchase rules remain KEEP. |
| `tests/suites/terrain_connectivity_equivalence_suite.gd` | main suite | — | — | Finished connectivity/preparation refactor oracle; room reachability, seeded saves and encounter placement remain KEEP. |

### ON DEMAND

| File / call site | Kind | Seconds | Tests | One-line reason |
|---|---|---:|---:|---|
| `tests/test_art_identity_gate.py` | Python | 65.187 | 111 | Active art-authoring validation tool; run for an art change, outside the ordinary product pass. |
| `tests/test_capture_director.py` | Python | 7.397 | 20 | Active capture/measurement tooling; keep available for a new measurement or recording, outside every product pass. |
| `tests/test_capture_production.py` | Python | 0.238 | 15 | Active capture/measurement tooling; keep available for a new measurement or recording, outside every product pass. |
| `tests/test_classical_soundtrack_pipeline.py` | Python | 0.001 | 7 | Current soundtrack construction tool; run when rendering/replacing a soundtrack, not every product pass. |
| `tests/test_combat_feel_measurements.py` | Python | 0.039 | 3 | Active capture/measurement tooling; keep available for a new measurement or recording, outside every product pass. |
| `tests/test_cutout_workflow.py` | Python | 0.761 | 16 | Active art-authoring validation tool; run for an art change, outside the ordinary product pass. |
| `tests/test_demo_clips.py` | Python | 101.911 | 34 | Active capture/measurement tooling; keep available for a new measurement or recording, outside every product pass. |
| `tests/test_demo_recording.py` | Python | 7.264 | 31 | Active capture/measurement tooling; keep available for a new measurement or recording, outside every product pass. |
| `tests/test_dragon_rule_measurement.py` | Python | 0.029 | 6 | Active capture/measurement tooling; keep available for a new measurement or recording, outside every product pass. |
| `tests/test_encounter_measurement.py` | Python | 2.028 | 18 | Active capture/measurement tooling; keep available for a new measurement or recording, outside every product pass. |
| `tests/test_guardian_rules_measurement.py` | Python | 0.069 | 11 | Active capture/measurement tooling; keep available for a new measurement or recording, outside every product pass. |
| `tests/test_inspection_fixture.py` | Python | 22.565 | 12 | Active developer workflow/fixture tool; retain focused checks when that tool changes, outside product passes. |
| `tests/test_labyrinth_queue_board.py` | Python | 0.005 | 4 | Active developer workflow/fixture tool; retain focused checks when that tool changes, outside product passes. |
| `tests/test_labyrinth_task_queue.py` | Python | 0.514 | 4 | Active developer workflow/fixture tool; retain focused checks when that tool changes, outside product passes. |
| `tests/test_maquette_bleed.py` | Python | 0.448 | 4 | Reusable current art-builder geometry/topology/dispatch validation; retain for authoring-tool changes, outside every product pass. |
| `tests/test_maquette_blender.py` | Python | 0.294 | 20 | Reusable current art-builder geometry/topology/dispatch validation; retain for authoring-tool changes, outside every product pass. |
| `tests/test_maquette_builder_wiring.py` | Python | 0.414 | 5 | Reusable current art-builder geometry/topology/dispatch validation; retain for authoring-tool changes, outside every product pass. |
| `tests/test_maquette_closed_loft.py` | Python | 0.001 | 8 | Reusable current art-builder geometry/topology/dispatch validation; retain for authoring-tool changes, outside every product pass. |
| `tests/test_maquette_geometry.py` | Python | 6.730 | 21 | Reusable current art-builder geometry/topology/dispatch validation; retain for authoring-tool changes, outside every product pass. |
| `tests/test_maquette_hidden_material.py` | Python | 0.429 | 8 | Reusable current art-builder geometry/topology/dispatch validation; retain for authoring-tool changes, outside every product pass. |
| `tests/test_maquette_joint_seams.py` | Python | 2.380 | 15 | Reusable current art-builder geometry/topology/dispatch validation; retain for authoring-tool changes, outside every product pass. |
| `tests/test_output_gdignore.py` | Python | 0.014 | 10 | Active developer workflow/fixture tool; retain focused checks when that tool changes, outside product passes. |
| `tests/test_pace_round_capture.py` | Python | 0.001 | 5 | Active capture/measurement tooling; keep available for a new measurement or recording, outside every product pass. |
| `tests/test_parallel_task.py` | Python | 3.177 | 8 | Active developer workflow/fixture tool; retain focused checks when that tool changes, outside product passes. |
| `tests/test_performance_pass.py` | Python | 0.002 | 15 | Active capture/measurement tooling; keep available for a new measurement or recording, outside every product pass. |
| `tests/test_recolour_lab.py` | Python | 1.117 | 13 | Active art-authoring validation tool; run for an art change, outside the ordinary product pass. |
| `tests/test_rr49_submission.py` | Python | 49.541 | 5 | Current cutout submission/cost/cache timing guards remain available with the rig/performance work; no ordinary-pass invocation. |
| `tests/test_sb02_movement.py` | Python | 27.810 | 2 | Active capture/measurement tooling; keep available for a new measurement or recording, outside every product pass. |
| `tests/test_section_transition_clip.py` | Python | 0.001 | 4 | Active capture/measurement tooling; keep available for a new measurement or recording, outside every product pass. |
| `tests/test_sfx_lab.py` | Python | 0.000 | 39 | Active capture/measurement tooling; keep available for a new measurement or recording, outside every product pass. |
| `tests/test_skybolt_measurement.py` | Python | 26.681 | 6 | Active capture/measurement tooling; keep available for a new measurement or recording, outside every product pass. |
| `tests/test_steam_performance_stats_schema.py` | Python | 0.000 | 0 | Standalone Steam stats schema script currently discovers zero unittest tests; keep as explicit analytics-tool validation. |
| `tests/test_ui_identity_lint.py` | Python | 3.070 | 25 | Visual-language ratchet is an authoring gate for UI changes, not a product-rule regression on every pass. |
| `tests/test_visual_probe_runner.py` | Python | 0.310 | 17 | Active developer workflow/fixture tool; retain focused checks when that tool changes, outside product passes. |
| `tests/card_display_performance_test.gd` | Godot program | 4.652 | — | Timing/performance/redraw/soak workload stays runnable outside every pass; functional rules stay in KEEP suites. |
| `tests/combat_feel_test.gd` | Godot program | 106.153 | — | Timing/performance/redraw/soak workload stays runnable outside every pass; functional rules stay in KEEP suites. |
| `tests/combat_motion_timing_test.gd` | Godot program | 9.697 | — | Timing/performance/redraw/soak workload stays runnable outside every pass; functional rules stay in KEEP suites. |
| `tests/demo_capture_settings_test.gd` | Godot program | 0.611 | — | Current capture/codec/clock or headless-playtest tool; validate when that tool changes, outside the product pass. |
| `tests/demo_clip_clock_test.gd` | Godot program | 0.635 | — | Current capture/codec/clock or headless-playtest tool; validate when that tool changes, outside the product pass. |
| `tests/demo_probe_viewport_test.gd` | Godot program | 3.464 | — | Current capture/codec/clock or headless-playtest tool; validate when that tool changes, outside the product pass. |
| `tests/dragon_pressure_escape_probe.gd` | Godot program | 177.779 | — | Active measurement/diagnostic workload, not an authored combat rule or ordinary product test. |
| `tests/encounter_measurement_test.gd` | Godot program | 33.537 | — | Active measurement/diagnostic workload, not an authored combat rule or ordinary product test. |
| `tests/engine_cache_directories_test.gd` | Godot program | 0.572 | — | Current capture/codec/clock or headless-playtest tool; validate when that tool changes, outside the product pass. |
| `tests/fight_soak_metrics_test.gd` | Godot program | 0.443 | — | Timing/performance/redraw/soak workload stays runnable outside every pass; functional rules stay in KEEP suites. |
| `tests/fight_soak_probe.gd` | Godot program | 1.662 | — | Timing/performance/redraw/soak workload stays runnable outside every pass; functional rules stay in KEEP suites. |
| `tests/fight_soak_test.gd` | Godot program | 65.356 | — | Timing/performance/redraw/soak workload stays runnable outside every pass; functional rules stay in KEEP suites. |
| `tests/grimoire_performance_test.gd` | Godot program | 0.795 | — | Timing/performance/redraw/soak workload stays runnable outside every pass; functional rules stay in KEEP suites. |
| `tests/headless_playtest_progression_test.gd` | Godot program | 1.752 | — | Current capture/codec/clock or headless-playtest tool; validate when that tool changes, outside the product pass. |
| `tests/mv01/path_movement_test.gd` | Godot program | 4.570 | — | Per-frame path speed/spacing/animation timing guard from one movement unit; keep available ON DEMAND. |
| `tests/perf/combat_frame_scenarios.gd` | Godot program | 17.895 | — | Timing/performance/redraw/soak workload stays runnable outside every pass; functional rules stay in KEEP suites. |
| `tests/perf09_scene_redraw_test.gd` | Godot program | 4.384 | — | Timing/performance/redraw/soak workload stays runnable outside every pass; functional rules stay in KEEP suites. |
| `tests/rr46/death_clocks.gd` | Godot program | 22.683 | — | Playback/death timing and speed guards remain callable outside every pass; remove historical mutation/proof drivers from the pass. |
| `tests/rr46/timing.gd` | Godot program | 4.078 | — | Playback/death timing and speed guards remain callable outside every pass; remove historical mutation/proof drivers from the pass. |
| `tests/save_pipeline_performance_test.gd` | Godot program | 1.313 | — | Timing/performance/redraw/soak workload stays runnable outside every pass; functional rules stay in KEEP suites. |
| `tests/sta01_presentation_test.gd` | Godot program | 25.398 | — | Timing/performance/redraw/soak workload stays runnable outside every pass; functional rules stay in KEEP suites. |
| `tests/status_plates_performance_probe.gd` | Godot program | 10.316 | — | Timing/performance/redraw/soak workload stays runnable outside every pass; functional rules stay in KEEP suites. |
| `tests/suites/sfx_sync_0_program.gd` | Godot program | 75.020 | — | Sound contact/onset and duration timing guards remain available for recording/audio changes, outside every pass. |
| `tests/suites/sfx_sync_1_program.gd` | Godot program | 75.163 | — | Sound contact/onset and duration timing guards remain available for recording/audio changes, outside every pass. |
| `tests/suites/sfx_sync_2_program.gd` | Godot program | 41.305 | — | Sound contact/onset and duration timing guards remain available for recording/audio changes, outside every pass. |

#### Existing windowed catalog — all 348 entries remain ON DEMAND

No supplied windowed timing exists, and none of these file paths is one of the 309 timed child paths. Each row is retained because it needs a native renderer or an explicit frame/rendered-state workflow. Existing check-only flags do not turn its picture contract into mandatory every-pass coverage.

| File | Seconds | One-line reason from allowlist |
|---|---:|---|
| `tests/acolyte_cutout_asset_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/acolyte_cutout_gameplay_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/action_step_tracker_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/actor_presentation_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/actor_weapon_clearance_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/ambient_particle_batch_equivalence_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/aoe_targeting_preview_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/asset_loading_performance_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/banked_play_meter_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/beautify_feel_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/bestiary_lineup_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/bile_bloomer_cutout_asset_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/bile_bloomer_cutout_gameplay_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/biome_gallery_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/biome_light_motion_probe.gd` | — | Six native 1920x1080 room animation loops; --headless-check validates routing only, not renderer pixels. |
| `tests/blink_rift_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/board_backdrop_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/board_cursor_input_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/board_density_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/board_startup_assets_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/board_startup_manifest_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/board_surface_cache_equivalence_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/board_surface_dense_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/board_surface_electric_equivalence_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/board_surface_inspection_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/board_surface_loop_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/board_surface_material_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/board_surface_static_equivalence_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/board_surface_visual_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/board_tile_tooltip_probe.gd` | — | srf-01 native 1920x1080/100% paired-surface and mouse/controller stack captures, including reduced motion and native edge bounds; --plan-only checks the fixture headlessly. |
| `tests/board_transition_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/boot_splash_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/boss_health_preview_probe.gd` | — | Real-renderer 1920x1080 boss preview, regular-bar comparison and reduced-motion pixel proof; excluded from headless execution. |
| `tests/brs01_probe.gd` | — | Native 1920x1080 / 100% proof of Burst glows and ribbons, reduced motion, Kindle, Hoarder pre-battle and every objective title; headless semantics execute in tests/brs01_test.gd. |
| `tests/button_system_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/campfire_choice_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/canvas_pipeline_loading_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/card_completion_native_trace_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/card_completion_stall_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/card_drag_overlay_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/card_draw_hand_flow_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/card_keywords_visual_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/card_keywords_w3_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/card_play_confirmation_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/card_pool_overhaul_contact_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/card_pool_polish_combat_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/card_pool_polish_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/card_rarity_polish_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/card_role_emblem_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/card_summary_fit_probe.gd` | — | card-01 real-renderer before/after hover and deck proof at 1920x1080, 100% UI scale; --plan-only validates the same fixtures headless. |
| `tests/card_targeting_audit_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/card_targeting_rework_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/card_time_badge_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/cbt_01_probe.gd` | — | Native 1920x1080 capture and OS-cursor proof; semantic/enclosed cases run in the full suite. |
| `tests/cel_look_probe.gd` | — | 1920x1080 native cel A/B proof; --measure is a manual headless fixture timing path. Loader semantics are in cel_look_test.gd. |
| `tests/chain_attack_visual_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/chainbound_gaoler_cutout_asset_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/chainbound_gaoler_cutout_gameplay_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/chainbound_gaoler_style_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/character_menu_polish_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/character_review_fixes_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/choice_material_polish_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/chronicle_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/cinder_droplet_cutout_asset_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/cinder_droplet_cutout_gameplay_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/cinder_droplet_cutout_pose_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/cinder_ooze_cutout_asset_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/cinder_ooze_cutout_gameplay_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/click_first_combat_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/combat_art_treatment_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/combat_board_navigation_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/combat_board_render_equivalence_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/combat_feel_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/combat_ground_marker_depth_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/combat_hand_flanks_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/combat_hud_badges_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/combat_hud_buttons_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/combat_interaction_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/combat_lighting_density_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/combat_lighting_variants_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/combat_motion_timing_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/combat_objective_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/contextual_combat_tutorial_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/contextual_creature_keypose_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/contextual_cutout_gameplay_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/controller_compat_1080_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/controller_desktop_1080_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/crawler_cutout_asset_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/crawler_cutout_gameplay_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/crawler_recolour_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/cursor_feedback_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/cutout_workflow_input_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/death_transition_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/death_transition_test.gd` | — | Enemy-round feedback waits for frame_post_draw (explicit headless rejection). |
| `tests/defeat_cleanup_overlap_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/deferred_reconciliation_queue_test.gd` | — | Asserts one queue step per rendered frame; requires native frame_post_draw. |
| `tests/deferred_run_skill_analytics_test.gd` | — | Asserts deferred run analytics across production rendered frames. |
| `tests/deferred_skill_analytics_test.gd` | — | Asserts deferred combat analytics across production rendered frames. |
| `tests/defiance_ui_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/destruction_preview_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/dragon_attachment_asset_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/dragon_boss_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/dragon_canceled_area_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/dragon_presentation_feedback_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/dragon_pressure_grimoire_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/dragon_pressure_ice_pursuit_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/dragon_pressure_presentation_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/dragon_pressure_ring_copy_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/dragon_pressure_warning_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/dragon_revision_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/dragon_reward_feedback_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/dragon_reward_tooltip_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/dragon_rewards_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/dragon_shadow_visible_source_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/dragon_trophy_feedback_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/earthen_rampart_rotate_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/elemental_ambient_transition_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/elemental_aoe_attack_visual_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/elemental_ranged_attack_visual_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/elemental_room_overlays_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/elemental_spell_effects_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/elemental_spell_geometry_equivalence_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/elemental_trap_visual_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/ember_reward_feedback_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/empower_sfx_probe.gd` | — | Windowed 1920x1080 charge/uncharge/charge movie with audio; sequence also supports headless --validate-only. |
| `tests/en01_enemies_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/en02_enemies_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/en04_enemies_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/enc03_lob_probe.gd` | — | Native production fire Warband camera/HUD at 1920x1080; check-only path tested headlessly. |
| `tests/encounter_entry_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/encounter_framing_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/enemy_cutout_roster_aoe_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/enemy_cutout_roster_gameplay_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/enemy_intent_compass_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/enemy_intent_continuity_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/enemy_intent_preview_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/enemy_intent_top_edge_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/enemy_no_action_probe.gd` | — | Real-renderer fb-01 mid-hold reason captures; excluded from headless execution. |
| `tests/enemy_pathfinding_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/enemy_shadow_dissolve_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/enemy_strike_trail_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/enemy_tactical_ai_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/equipment_inventory_readability_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/equipment_pickup_visibility_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/event_view_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/evt01_event_preview_probe.gd` | — | Design-owner-only 1920x1080 event preview/result captures; requires a real windowed renderer. |
| `tests/evt02_event_feedback_probe.gd` | — | Design-owner-only 1920x1080/100% preview and mid-beat renderer proof; --check-only verifies the authored fixtures headlessly. |
| `tests/fireball_attack_visual_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/fix18/real_fight_capture_probe.gd` | — | Fix-18 test-only fork of pt14-03 real Continue root-window proof; --validate-only records headless geometry without claiming native pixels. |
| `tests/fix_03_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/fixtures/native_font_cache_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/floating_damage_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/floating_text_collision_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/flurry_card_pack_probe.gd` | — | flu-01 owner-only 1920x1080/100% card, badge and focus tooltip proof; --check-only validates the same widgets headlessly. |
| `tests/forced_movement_preview_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/foreground_actor_readability_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/frostglass_lancer_cutout_asset_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/frostglass_lancer_cutout_gameplay_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/frostglass_lancer_style_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/glacial_mirror_board_probe.gd` | — | pt13-06 native 1920x1080 four-facing before/after and Seer comparison; --validate-only separately checks its fixture headlessly. |
| `tests/glossary_tooltip_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/graftwright_feedback_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/graftwright_motion_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/graftwright_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/graftwright_resume_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/grave_surgeon_cutout_asset_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/grave_surgeon_cutout_gameplay_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/grb01_ground_contact_probe.gd` | — | grb-01 real-fight 1920x1080/100% standing and mid-move proof, front/rear and mirrors; --validate-only checks identical fixtures headlessly. |
| `tests/grimoire_focus_return_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/grimoire_search_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/guardian_feedback_playback_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/guardian_gameplay_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/guardian_inspection_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/guardian_map_revision_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/guardian_revision_03_ui_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/guardian_revision_04_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/guardian_ui_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/gust_shrike_cutout_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/hand_card_focus_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/harrier_cutout_asset_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/harrier_cutout_gameplay_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/health_bar_theme_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/health_cost_preview_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/health_ghost_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/hero_facing_gameplay_probe.gd` | — | hf-01 real-fight A/B recording at 1920x1080, 100% UI scale; --check-only validates the plan headless. |
| `tests/hoarder_probe.gd` | — | Native Ember Hoarder proof at 1920x1080, 100% UI scale (pre-battle, rule panel first/last turn, slipped away, catch reward). hoarder_test runs all headless semantics; no window server in implementation sandbox. |
| `tests/illusion_animation_gameplay_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/illusion_terrain_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/int03_targeting_probe.gd` | — | Real-renderer 1920x1080 targeting ownership proof; headless semantics use --validate-only. |
| `tests/intent_chip_placement_probe.gd` | — | Matched 1920x1080 before/after placement captures need the real renderer; semantic setup and all geometry assertions also run headlessly with --check-only. |
| `tests/iskaldra_cutout_asset_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/iskaldra_cutout_gameplay_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/item_card_art_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/item_pickup_deck_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/item_pickup_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/large_target_retained_overlay_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/lethal_preview_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/lightning_wisp_cutout_asset_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/lightning_wisp_cutout_gameplay_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/loadout_acquisition_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/loadout_material_polish_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/locked_hand_cache_lifecycle_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/magic_deck_ui_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/main_menu_branding_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/main_menu_input_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/main_menu_resume_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/main_menu_umbra_button_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/maneuver_board_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/maneuver_cards_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/map_03_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/map_decision_layer_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/map_overlay_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/map_travel_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/merchant_acquisition_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/meteor_marks_board_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/mim01_probe.gd` | — | Owner-only 1920x1080/100% Mimic room and Hollow Prior renderer proof; --check-only verifies fixtures headlessly. |
| `tests/missed_equipment_resolution_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/motion_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/move_attack_approach_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/move_attack_shortcut_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/movement_path_arrow_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/movement_undo_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/mrk01_marked_probe.gd` | — | mrk-01 native 1920x1080/100% real-fight intent/mark/landing and Marked grimoire proof; --check-only validates the same fixtures headlessly. |
| `tests/mv01/fight_probe.gd` | — | Owner-only real Continue/Pass fight recording of three-tile Scuttle and two-tile Gnaw at 1920x1080/100%; --validate-only checks the real fixture and resolver path headlessly. |
| `tests/new_descent_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/noctyrax_cutout_asset_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/noctyrax_cutout_gameplay_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/opening_boon_probe.gd` | — | Native opening-boon capture and controller/pointer proof; opening-boon and recovery programs run headless. |
| `tests/pass_preview_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/pause_overlay_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/perf/hover_equivalence_probe.gd` | — | Native hover pixel-equivalence proof (director-run; reference vs candidate retained layers at 1920x1080). |
| `tests/perf/turn_order_retention_probe.gd` | — | Native 1920x1080 pixel equivalence for retained turn-order controls; headless layout/style/input equivalence runs in perf/combat_frame_scenarios.gd --equivalence-only. |
| `tests/petrify_card_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/pillar_torch_lighting_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/pixel_fx_compare_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/pixel_fx_render_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/player_aim_curve_ownership_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/player_movement_outcome_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/player_movement_visual_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/pre_battle_deck_fit_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/pre_battle_living_foes_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/pre_battle_loadout_refinement_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/pre_battle_material_polish_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/pre_battle_pinned_hover_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/pre_battle_preview_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/pre_battle_review_findings_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/pre_battle_true_scale_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/premium_button_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/premium_card_material_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/protagonist_cutout_continue_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/protagonist_cutout_gameplay_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/protagonist_gear_motion_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/protagonist_gear_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/protagonist_ranged_gameplay_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/reach_rebalance_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/ready_wave_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/relic_choice_sparkle_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/relic_damage_feedback_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/relic_offer_fit_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/relic_rework_visual_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/relic_u2_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/relic_u3_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/relic_u4_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/relic_u5_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/relic_u6_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/relic_u7_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/relic_u8_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/remaining_hitch_native_trace_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/reward_decision_support_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/rr29/native_probe.gd` | — | rr29 real-renderer 1920x1080 cutout capture; Python executes validate-only headlessly. |
| `tests/rr29/production_probe.gd` | — | rr29 production renderer capture at 1920x1080; logic-only branch is headless proof. |
| `tests/rr46/comparison_probe.gd` | — | Native 1920x1080/100% side-by-side production movement playback; --validate-only checks its two path schedules headlessly. |
| `tests/rr46/depth_probe.gd` | — | Native Warband before/after depth frames and actor crops. Headless ordering is registered separately as rr46/depth_check.gd. |
| `tests/rr46/fight_probe.gd` | — | Native persisted fire Warband fight recording; headless validation proves fixture/Continue boot only. Clock and path schedules have separate headless checks. |
| `tests/rr47/route_probe.gd` | — | Native 1920x1080/100% regression-route capture on the same production ID probe; historical runtime and current runtime share the probe. Callback routing is checked headlessly by tests/rr47/routing.gd. |
| `tests/run_end_recap_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/run_sfx_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/save_resume_inspection_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/scavenger_glowup_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/scavenger_motion_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/scavenger_resume_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/scavenger_shop_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/section_map_flow_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/section_map_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/section_map_review_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/section_transition_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/selection_prompt_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/selective_ui_salvage_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/settings_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/sfx_cue_coverage_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/shader_cache_switch_probe.gd` | — | Native two-session shader-cache proof across the Steam user-dir switch (director-run; tests/run_engine_cache_proof.py). |
| `tests/shale_bloomer_art_visual_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/shortcut_risk_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/skill_material_polish_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/skill_tree_visual_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/skill_ui_test.gd` | — | Production skill analytics drain across rendered frames (documented real-renderer test). |
| `tests/snare_probe.gd` | — | Native Snare proof at 1920x1080, 100% UI scale. snare_test and snare_ui_test cover headless mechanics, fixture semantics and chip lifecycle; no window server in implementation sandbox. |
| `tests/special_encounter_probe.gd` | — | Director-run real-renderer spx-02 map states, tooltip/focus, fullest legend and Section VI fog at 1920x1080, 100% UI scale. |
| `tests/start_room_map_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/static_facing_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/status_icon_application_probe.gd` | — | Native 1920x1080 first-status frame timing; status_plates_performance_probe --first-status runs the same 12-unit CPU workload headless. |
| `tests/status_icon_fit_probe.gd` | — | Native 1920x1080 before/after icon sheets at 4x, UI scale 100%; board_status_plates_test executes exhaustive headless icon-fit semantics. |
| `tests/steam_deck_720p_stress_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/steam_deck_compat_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/steam_media_color_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/stone_warden_cutout_asset_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/stone_warden_cutout_gameplay_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/strike_trail_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/surface_feedback_ui_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/surface_redraw_equivalence_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/terrain_destruction_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/text_audit_capture_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/text_rewrite_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/tharokh_cutout_asset_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/tharokh_cutout_gameplay_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/threats_at_rest_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/tooltip_consistency_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/treasure_opening_reel_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/treasure_presentation_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/turn_clock_copy_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/turn_clock_hud_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/turn_order_animation_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/turn_order_portraits_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/turn_order_projection_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/ui02_pixel_identity_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/ui_components_gallery_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/ui_feedback_sfx_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/ui_hover_sfx_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/ui_material_polish_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/ui_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/umbra_action_animation_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/umbra_preview_privacy_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/umbra_visual_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/utility_ui_layout_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/vaeloryx_cutout_asset_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/vaeloryx_cutout_author_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/vaeloryx_cutout_gameplay_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/vaeloryx_feedback_asset_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/veilbound_acolyte_cutout_asset_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/veilbound_acolyte_cutout_gameplay_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/visible_terrain_shortcut_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/vyraketh_cutout_asset_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/vyraketh_cutout_gameplay_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/warband_probe.gd` | — | Native Warband proof at 1920x1080, UI scale 100%; warband_test and warband_ui_test run all headless semantics. |
| `tests/warden_bulwark_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/wave4_icon_identity_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/zekarion_cutout_asset_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |
| `tests/zekarion_cutout_gameplay_probe.gd` | — | Real-renderer capture/interactive proof; excluded from headless execution. |

| Other registered entry | Seconds | Disposition / reason |
|---|---:|---|
| `tests/relic_u7_test.gd` (`group: perf`) | — | ON DEMAND; already outside the supplied ordinary Godot run, retain explicit perf invocation. |

### Registry aliases and source retention

| Registry/base entry | Classification of executed children |
|---|---|
| `tests/forced_movement_query_equivalence_test.gd` | RETIRE all five `suites/forced_movement_query_*_program.gd` children, individually timed above; no extra umbrella runtime to add. |
| `tests/section_map_v5_test.gd` | KEEP `section_map_v5_program` and both revision-3/4 `section_map_legacy_hashes_*` programs; timings are above. |
| `tests/encounter_tables_test.gd` | KEEP all four `encounter_rules`, `encounter_placement_0`, `encounter_placement_1`, `encounter_placement_summary` programs; timings are above. |

Implementation must update `tools/program_suite_runner.py::BASE_SUITES`, `tests/headless_test_programs.json`, partition routes in `tools/test_execution_sources.py`, direct main-suite calls, `tools/python_suite_groups.json`, and `tools/python_suite_resources.json` together. Current Python groups contain default 49, rig 196, tools 14 and cel 1 modules. Moving checks to a group named “tools” or “rig” is insufficient: `--all-groups` still discovers them. Put ON DEMAND checks behind explicit non-default entrypoints outside ordinary discovery/selection. Keep all existing windowed allowlist entries. Retiring the recursive registration test/guard requires replacing its “all tests must run in every full pass” policy with this explicit approved inventory; do not conceal exclusions with skips or weakened assertions.

Do not delete shared assertion bodies just because a wrapper is RETIRE. Examples: `tests/run_tests.gd` is the base of KEEP full-scene programs; `card_display_overrides_test.gd` remains KEEP although its all-unmodified subclass retires; `en02/en04/en05` rule suites remain in the main body when redundant child wrappers leave; `summon_card_play_regression_test` re-invokes existing main/Guardian assertions and adds no unique product assertion. Likewise, keeping a file as a helper does not permit executing its retired whole-suite entrypoint indirectly. Audit those call paths when implementing, rather than relying on filename discovery.

## 3. Protection actually lost

This proposal accepts real gaps. An approved asset manifest catches changed/missing approved files and a basic resource/rig-load failure; it cannot prove the final rendered game still looks right. The following bugs can reach a playtest and depend on the owner’s inspection or an explicit pre-release/on-demand pass:

- A shared animation, layer-order, draw-submission, clipping or shader change can leave all approved files unchanged while producing a floating foot, a detached limb, an inside-out spear, a hidden chain, a rear-view hole, a transient seam, a wrong dissolve or a frozen action. The retired rr/mq per-frame/native witnesses and mutation gates often caught exactly these. Generic load/finite-transform smoke is much weaker than frame-by-frame playback/paint proof. The named Continue, sole, missing-host and card readability regressions listed below survive; exhaustive art correctness does not.
- New maquette authoring or regeneration can produce malformed geometry, stale proof, wrong ownership, missing labels, an invalid certificate or an unreproducible old delivery without an ordinary-pass failure. Some reusable authoring validators remain ON DEMAND; historical per-round gates retire. A manifest rejects unapproved current output changes, but it does not certify that newly approved art was built correctly. Review sheets/native playback must do that work.
- UI can drift in font size, colors, exact gaps, card/strip widths, board framing, legend styling, popup placement, occlusion, small caption legibility or shop shelf layout. The remaining rules/input tests may pass while a panel looks poor. The compact known clipping/no-shrink cases survive; blanket pixel/layout sameness does not. UI/art identity lint remains an explicit change gate rather than an every-pass requirement.
- Sound can be late, too long, doubled perceptually, poorly mixed or visibly out of sync while cue existence, routing and mute settings still pass. The sound contact/onset programs, measurement tools and native recordings become ON DEMAND. Exact feel, hit-stop, motion durations and movement-speed smoothness also leave the ordinary pass. A global timing/restore defect not reached by the surviving input tests could stall or feel wrong until a play session.
- Frame pacing, redraw counts, warm-cache cost, submission speed, node growth over a long fight, rare lifetime leaks and retained-widget churn can regress without an ordinary-pass failure. Soak, timing and count guards remain ON DEMAND. Short semantic input tests do not substitute for a 20-round lifetime soak.
- Optimized caches, preparation cancellation and retained views can diverge from a frozen reference on an uncommon inventory, loadout, room, hover history or cancellation boundary. Ordinary KEEP behavior/save/preview tests still protect their explicit cases; they no longer cover thousands of cross-product equivalence states. A stale display or a lost late transition outside those cases may first show up in play.
- Recording, proof and workflow tools can misframe a capture, silently omit an artifact, accept stale evidence, lose a caption/audio alignment, or fail after a future tool change. Their focused tests are no longer continuously exercised. The active suite runner/isolation tests are exceptions and remain in the ordinary pass; other developer-tool regressions are left to focused tool work and pre-release use.
- New tests can be omitted from a registry without the recursive registration/mutation guard failing. This is intentional: every new unit test no longer earns permanent full-pass membership. The design owner must assign it to KEEP, MERGE, RETIRE or ON DEMAND and review the explicit inventory. This trades mechanical completeness of test registration for a bounded product pass.

No proposed loss of saved-run migrations, combat damage/targeting, current status timing, hidden-information rules, progression/ownership, event/reward outcomes or analytics schema is intentional. Those remain KEEP. That does not mean every possible such bug is still covered: retirement removes state-space breadth and frozen-reference comparisons. If implementation discovers a unique assertion for a real playtest bug in a RETIRE file, transfer that assertion into its KEEP owner before deleting the invocation; do not simply rely on the category name.

## 4. Exceptions and named bugs that survive

The naming rules are not deletion globs. These are deliberate exceptions or explicit transfers, supported by current assertion bodies and Git history:

| ID / apparent retirement rule | Bug or protection | KEEP assertion / destination | History evidence |
|---|---|---|---|
| B1 — `fix_*` | Fatigue damage was incorrectly amplified by Expose/Chilled/Frozen and could consume defensive state. | `tests/suites/fix_03_suite.gd::_test_fatigue` checks exact health loss, preserved defenses and unchanged real attack amplification; keep SPENT/token semantic checks too. | `8d22d2756`, `3ede04408` (2026-10-15), owner-confirmed bug after playtest 9. |
| B2 — performance suite | Map generation could freeze on seed 1792271957. A watchdog alone would merely hide the hang. | `tests/suites/section_map_performance_program.gd` keeps deterministic node budget, cutoff/rejection and fallback assertions. Its actual wall-clock benchmark remains ON DEMAND. | `004580a30`, `6d678c22c` (2026-10-17), fix-05. |
| B3 — UI/layout unit | Boss health previews disappeared when turn-order refresh redrew the overlay without preview state. | `tests/boss_health_preview_test.gd` live pulse/redraw/lookup and reduced-motion cases remain. | `dd0210874`, `58a4ec337` (2026-10-26), owner playtest 13. |
| B4 — UI layout pins | Sabatons scaling rows shrank rules type; card summary rows overflowed parchment, including 240 faces found by the fit sweep. | KEEP `card_legibility_test`, `card_summary_fit_unit_test`, `card_summary_fit_test` for no-shrink, whole-glyph wrapping and vertical/horizontal bounds. Retire the Python launch/mutation duplicate. | `d63d005f0`, `102995e00`, `514ad8ea8`, `2f47eca0d` (2026-10-26/27). |
| B5 — `pt*` and UI pins | Intent chips covered their own unit’s soles; Glacial Mirror registration used the wrong foot anchor. | KEEP `pt15_01_owner_feet_check`, `threats_at_rest_test` and their solver/source cases. Preserve Mirror registration in the merged manifest. Retire Python mutation/sweep drivers. | `0cb3b5ce5`, `b23b04906`, `7bd049ec2`, `6a91cde92` (2026-10-26/27), owner live/sole cases and playtest-13 follow-ups. |
| B6 — `fix_*`, `*feedback*` | Tether arrival injury, copied Mimic reactions, deferred death cascades and Bleed could be doubled, attributed to the wrong action, or remove a landed hit when the attacker died. | KEEP `fix_12_arrival/reactions_0/reactions_1/cascades/feedback/bleed`, `fix_14_test` and `fix_14_matrix_test`: presented loss totals and intermediate snapshots match the owning resolver steps and analytics. Current fixtures have been ported to the current mechanics; do not resurrect retired Tether/Mirror behavior. | `add29f46a`, `ab26ffd05`, `e8f6f0dc8`, `0b71b528f`, and current port `be6dbfbf7` (2026-10-24/25/31). These follow the owner’s Tether follow-up; not every subsequent matrix mutation was a separate shipped bug. |
| B7 — `fix18` | After Continue, Seer/Mirror/Gaoler/Lancer could draw off their own tiles because presentation origins were baked before final layout. | KEEP `tests/fix18/draw_origin_test.gd` and `entry_paths_test.gd` through real Continue, resize, movement and layout. Retire only the duplicate Python mutation wrapper. | `ebcb74843`, `bfb41c06a`, `64c6a6d26` (2026-10-27), owner Continue regression. |
| B8 — `pt13`/old asset round | Element-room torches no longer animated. | Transfer approved animated-sheet and phase-advance assertion from `test_biome_light_idle` into the one manifest/roster test before retiring its regeneration/mutation suite. | `994f86532`, `3e237a6f4` (2026-10-26), owner playtest 13. |
| E1 — tests of test/workflow tools; `*feedback*` | A stale shard result, zero-exit script error, broken cancellation or shared-path scheduling bug can claim success without actually checking the product. | KEEP `test_godot_task_runner`, `test_program_suite_runner`, `test_python_suite_runner`, `test_python_suite_runner_feedback`, `test_runner_cancellation`. This is an explicit infrastructure exception to the narrow player-facing KEEP definition; it costs 69.287 module-seconds and makes the smaller pass trustworthy. | Current tests exercise fresh invocation IDs, real failures/timeouts, child-tree ownership and shared-resource scheduling; this is not claimed as a shipped player bug. |
| E2 — developer-workflow integrity | Missing/stale imports or UIDs can break an export; cache switching can lose settings or initialize Steam incorrectly. | KEEP `test_godot_sidecars`, main `steam_service_suite`, and `cache_switch_regression_test`. These protect playable startup/resources/preferences, even though much of their surface looks like tooling. | Current source and the runner’s import/bootstrap checks; not claimed as an observed playtest bug. |
| E3 — “equivalence” hashes | Saved revision-3/4 maps must regenerate the same room identities; existing revision-5/6 saves must stay compatible too. | KEEP both legacy-hash children, `section_map_v2_test`, `section_map_v5_program`, main `section_map_suite` and `section_map_v7_suite`. Do not confuse saved-world compatibility with a finished cache refactor. | `section_map_v5_suite::_test_legacy_hashes` compares pre-change revision-3/4 fixtures; `section_map_v7_suite::test_saved_revisions_regenerate` checks revisions 5/6. |
| E4 — `pt13`, `*feedback*`, narrow unit names | Black Sun Dial’s actual +3/+9 rule, dragon trophies/rewards, event outcome previews, Burst playback, Marked, Retaliate, Snare and current surface review cases affect real rules or displayed outcomes. | KEEP their live data/semantic assertions (`test_relic_pt13_01`, `dragon_*feedback*_test`, `event_feedback_test`, `brs01_test`, `mrk01_marked_test`, `mim01_test`, `surface_parent_review_test`, `surface_core_review_suite`, etc.) at their full file costs. Retire frozen proof contracts and mutation drivers around them. | Assertion contents, not filename shape, establish the live protection. The retirement proposal does not claim each was a separate shipped bug. |
| E5 — `rr*`, depth/layout pins | Real rig-v2 movement could route onto a culled back-row host and disappear; rr-47 corrected 110 missing callbacks. This was caught during rr-46 review/integration, not asserted here to have shipped in a playtest. | KEEP `rr46/depth_check.gd` and the main moving-world-position assertion. Transfer the compact `missing_callbacks == 0` back-row/diagonal regression from `test_rr47_depth` / `tests/rr47/routing.gd` into that KEEP depth program before retiring historical staging/native reconstruction and proof-save checks. | `cded9621a`, `b7a34062b`, `66b06637a` (2026-10-28). This is an explicit extra keep because invisible enemies can mislead the player about an occupied tile. |
| B9 — pinned-hover layout test | Pre-battle inspection crashed when its pinned hover source was freed. | The exact `PreBattleUiSuite.test_pinned_hover_source_lifetimes` assertion already runs in the KEEP main-body suite. RETIRE only the duplicate `pre_battle_pinned_hover_test.gd` wrapper. | `5ced9679e` (2026-10-04); current suite run invokes the same method as the standalone wrapper. |

The B1–B9 and E5 transfers/keeps are required before any removal. The E1 infrastructure exception is a policy recommendation, not a reinterpretation of the owner’s KEEP definition. No finding relies on matching `rr`, `mq`, `pt`, `fix` or `feedback` alone.

## Acceptance, evidence and handoff

| Requirement | Status / evidence |
|---|---|
| Read timing and registries | All four shard result files, summary/plan/audit, `godot.log`, both Godot registries, Python groups/resources, entrypoints, owning assertions/helpers and Git histories inspected. |
| Classify every requested item | 260 Python + 309 timed Godot + 86 named main suites + 223 inline tests, plus 6 bootstrap assertions, 348 windowed entries and one perf-only entry; alias expansion documented. |
| Totals / under ten minutes | Recorded-duration replay and budgets above; no measured post-change claim. Exact Python count reconciles to 2,491. Godot case-count limitation explicit. |
| Tables with seconds/reasons, retirement sorted | Every measured row has its input duration; RETIRE sorted across Python/Godot descending, unmeasured main rows last. |
| Lost protection / exceptions | Sections 3–4 name both practical gaps and surviving known-bug assertions. |
| No tracked edits / suites / windows / pushes | Repository remained clean on `codex/test-03`; output and analysis arithmetic only under `/private/tmp/labyrinth_codex/test-03/`. No test/engine commands executed. |

Evidence inputs: `/private/tmp/labyrinth_codex/test03/pysuite/shard-1-result.json` through `shard-4-result.json` (`modules`, `ids`, counts); `summary.json` (wall time); `isolation-audit.json` (imports/writes); `godot.log` (import/main/program/full timings). Registry sources: `tests/headless_test_programs.json`, `tests/windowed_test_allowlist.json`, `tools/python_suite_groups.json`, `tools/python_suite_resources.json`. Python fields transcribed from supplied JSON and exact Godot result lines read from the existing log (none generated by this task):

```text
Supplied Python shard: 473 tests; duration=1423.024469875s; failures=0; errors=0
Supplied Python shard: 690 tests; duration=1433.413669750s; failures=0; errors=0
Supplied Python shard: 643 tests; duration=1319.861534541s; failures=0; errors=0
Supplied Python shard: 685 tests; duration=1534.759636292s; failures=0; errors=0
GODOT IMPORT RESULT: PASS (15.211 seconds)
MAIN BODY RUNTIME: 252.814 seconds
MAIN BODY ASSERTIONS: 499578
PROGRAM SUITE RETRIES: []
FULL SUITE RUNTIME: 836.650 seconds
TEST RESULT: PASS
```

Analysis reconciliation (plain JSON/source arithmetic; no test suite):

```text
INVENTORY: 260/260 Python modules; 309/309 timed Godot programs; 86/86 named main suites; 223/223 inline main calls; 348/348 windowed entries; 1/1 perf-only entry classified.
PYTHON EXECUTIONS: 2491/2491 attributed, including 16 imported-class executions.
REGISTRIES: 260/260 Python resource and input-group modules reconciled; all classified source paths exist.
FORECAST: Godot=503.852s; Python=33.028s; reserve=30.000s; whole pass=566.880s.
```

**Proof for the design owner:** inspect this report and approve or amend the category list. No renderer capture, screenshot path, windowed command or inspection fixture is applicable to an analysis-only report; none was requested in this unit. The later implementation owner runs the approved suites to measure the result, as a separate task. This task adds no probe or test module and therefore requires no Python suite resource-table edit/audit invocation.

**TODO_DESIGN placeholders:** none. No missing player-facing design was implemented or invented.

**Chosen defaults (analysis-only):** `MODEL_SHARDS = 4`; `MERGED_MANIFEST_MODULE_SECONDS_BUDGET = 30.0`; `IMPLEMENTATION_AND_VARIANCE_RESERVE_SECONDS = 30.0`; main-body forecast remains at the observed 252.814 s; Python overhead uses the observed summary minus longest-shard difference. FIFO Godot order and resource-aware Python LPT reproduce the existing scheduler policies. These values affect only this arithmetic, not the game or its test fixtures.

**Open issues:** the proposed manifest/driver and transfers are not implemented; replacement runtime and final Godot assertion count are unmeasured; native visual/performance acceptance remains the owner’s on-demand/pre-release work; sampling fallback needs a separate decision if the measured approved pass exceeds ten minutes. Approval of the list is the next step, not publication.
