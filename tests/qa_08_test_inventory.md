# qa-08 test inventory

All 733 current matching scripts are classified by `tools/test_registration_audit.py`. Registrations include the shared scheduler, inherited/nested suite calls, explicit encounter partitions, and the Python-owned scheduler fixture. Native exclusions and owned quarantines remain exact path entries. Current program results refer to final idle run 3; the earlier EN06 load timeout remains explicit. Other standalone observations are historical audit evidence.

| Script | Classification | Registration / exclusion / quarantine evidence | Observed execution or earlier audit |
|---|---|---|---|

| `tests/acolyte_cutout_asset_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/acolyte_cutout_gameplay_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/acolyte_cutout_pack_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.265s) |

| `tests/acolyte_cutout_test.gd` | full suite | shared wrapper: tests/suites/acolyte_cutout_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/acolyte_cutout_test.gd.log) (3.304s) |

| `tests/action_step_tracker_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/actor_presentation_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/actor_presentation_test.gd` | full suite | shared wrapper: tests/suites/actor_presentation_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/actor_presentation_test.gd.log) (4.639s) |

| `tests/actor_weapon_clearance_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/ambient_particle_batch_equivalence_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/aoe_targeting_preview_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/asset_loading_performance_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/audio_routing_test.gd` | full suite | shared wrapper: tests/suites/audio_routing_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/audio_routing_test.gd.log) (3.962s) |

| `tests/balance_pacing_test.gd` | full suite | shared wrapper: tests/suites/balance_pacing_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/balance_pacing_test.gd.log) (9.201s) |

| `tests/banked_play_meter_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/beautify_feel_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/bestiary_lineup_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/bile_bloomer_cutout_asset_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/bile_bloomer_cutout_gameplay_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/bile_bloomer_cutout_pack_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.262s) |

| `tests/bile_bloomer_cutout_test.gd` | full suite | shared wrapper: tests/suites/bile_bloomer_cutout_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/bile_bloomer_cutout_test.gd.log) (11.471s) |

| `tests/biome_gallery_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/biome_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (3.642s) |

| `tests/blink_rift_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/board_backdrop_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/board_cursor_input_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/board_density_consumer_test.gd` | full suite | shared wrapper: tests/suites/board_density_consumer_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/board_density_consumer_test.gd.log) (3.236s) |

| `tests/board_density_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/board_hover_coalescing_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (4.892s) |

| `tests/board_startup_assets_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/board_startup_manifest_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/board_surface_cache_equivalence_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/board_surface_content_regression_test.gd` | full suite | shared wrapper: tests/suites/enemy_intent_preview_suite.gd::run, tests/suites/inline_icon_description_suite.gd::run, tests/suites/move_attack_shortcut_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/board_surface_content_regression_test.gd.log) (4.475s) |

| `tests/board_surface_content_smoke_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (3.571s) |

| `tests/board_surface_core_test.gd` | full suite | shared wrapper: tests/suites/board_surface_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/board_surface_core_test.gd.log) (1.179s) |

| `tests/board_surface_data_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.197s) |

| `tests/board_surface_dense_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/board_surface_electric_equivalence_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/board_surface_inspection_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/board_surface_loop_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/board_surface_material_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/board_surface_movement_regression_test.gd` | full suite | shared wrapper: tests/suites/move_attack_shortcut_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/board_surface_movement_regression_test.gd.log) (4.341s) |

| `tests/board_surface_presentation_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (8.068s) |

| `tests/board_surface_probe_migration_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (6.362s) |

| `tests/board_surface_static_equivalence_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/board_surface_visual_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/board_transition_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/boot_splash_export_test.gd` | quarantined | export-workflow; qa-12; Missing invocation fixture: explicitly requires an exported PCK and an empty project. A source-tree launch fails its precondition; no exported artifact was provided. Requires an export workflow, not an assertion rewrite. (output/qa-08/quarantine-check/boot_splash_export_test.gd.log) | [FAIL, exit 1](../output/qa-08/quarantine-check/boot_splash_export_test.gd.log) (0.399s) |

| `tests/boot_splash_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/button_system_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/campfire_choice_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/canvas_pipeline_loading_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/card_completion_native_trace_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/card_completion_stall_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/card_drag_overlay_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/card_drag_play_test.gd` | full suite | shared wrapper: tests/suites/card_drag_play_suite.gd::run, tests/suites/card_drag_play_suite.gd::run_live | [PASS, exit 0](../output/qa-08/orphans/card_drag_play_test.gd.log) (37.977s) |

| `tests/card_draw_hand_flow_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/card_draw_hand_flow_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (12.173s) |

| `tests/card_draw_sfx_test.gd` | full suite | shared wrapper: tests/suites/attack_sfx_suite.gd::run, tests/suites/attack_sfx_suite.gd::run_live | [PASS, exit 0](../output/qa-08/orphans/card_draw_sfx_test.gd.log) (11.705s) |

| `tests/card_keywords_test.gd` | full suite | shared wrapper: tests/suites/card_keywords_suite.gd::run, tests/suites/card_keywords_suite.gd::run_live | [PASS, exit 0](../output/qa-08/orphans/card_keywords_test.gd.log) (10.854s) |

| `tests/card_keywords_visual_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/card_keywords_w3_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/card_keywords_w3_test.gd` | full suite | shared wrapper: tests/suites/card_keywords_w3_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/card_keywords_w3_test.gd.log) (4.571s) |

| `tests/card_mechanics_surfaces_test.gd` | full suite | shared wrapper: tests/suites/card_mechanics_surfaces_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/card_mechanics_surfaces_test.gd.log) (4.985s) |

| `tests/card_play_confirmation_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/card_pool_overhaul_contact_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/card_pool_overhaul_test.gd` | full suite | shared wrapper: tests/suites/card_pool_overhaul_suite.gd::run, tests/suites/card_pool_overhaul_suite.gd::run_live | [PASS, exit 0](../output/qa-08/orphans/card_pool_overhaul_test.gd.log) (9.489s) |

| `tests/card_pool_polish_combat_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/card_pool_polish_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/card_presentation_cache_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (3.638s) |

| `tests/card_presentation_export_test.gd` | quarantined | export-workflow; qa-12; Missing invocation fixture: requires an actual exported/imported texture PCK and an empty project. A source-only pack would not test the exported texture-import contract. Requires export integration. (output/qa-08/quarantine-check/card_presentation_export_test.gd.log) | [FAIL, exit 1](../output/qa-08/quarantine-check/card_presentation_export_test.gd.log) (0.402s) |

| `tests/card_proxy_pool_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (3.953s) |

| `tests/card_rarity_polish_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/card_role_emblem_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/card_targeting_audit_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/card_targeting_audit_test.gd` | full suite | shared wrapper: tests/suites/card_targeting_audit_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/card_targeting_audit_test.gd.log) (28.837s) |

| `tests/card_targeting_rework_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/card_time_badge_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/cbt_01_enclosed_test.gd` | full suite | shared wrapper: tests/run_tests.gd::_test_run_scene_block_card_offers_stay_when_enclosed | Covered by invoked full-suite entrypoint |

| `tests/cbt_01_probe.gd` | windowed probe | Native 1920x1080 capture and OS-cursor proof; semantic/enclosed cases run in the full suite. | Not run (native) |

| `tests/cbt_01_test.gd` | full suite | shared wrapper: tests/suites/cbt_01_suite.gd::run, tests/suites/cbt_01_suite.gd::run_live | Covered by invoked full-suite entrypoint |

| `tests/chain_attack_test.gd` | full suite | shared wrapper: tests/suites/chain_attack_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/chain_attack_test.gd.log) (1.163s) |

| `tests/chain_attack_visual_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/chainbound_gaoler_cutout_asset_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/chainbound_gaoler_cutout_gameplay_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/chainbound_gaoler_cutout_pack_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.281s) |

| `tests/chainbound_gaoler_cutout_test.gd` | full suite | shared wrapper: tests/suites/chainbound_gaoler_cutout_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/chainbound_gaoler_cutout_test.gd.log) (3.906s) |

| `tests/chainbound_gaoler_motion_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (0.573s) |

| `tests/chainbound_gaoler_style_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/character_menu_polish_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/character_overlay_assertions_test.gd` | full suite | shared wrapper: tests/run_tests.gd::_test_run_scene_character_stats_overlay_opens | [PASS, exit 0](../output/qa-08/orphans/character_overlay_assertions_test.gd.log) (10.652s) |

| `tests/character_overlay_retention_flow_test.gd` | full suite | shared wrapper: tests/run_tests.gd::_test_run_scene_character_stats_overlay_opens | [PASS, exit 0](../output/qa-08/orphans/character_overlay_retention_flow_test.gd.log) (10.772s) |

| `tests/character_review_fixes_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/choice_material_polish_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/chronicle_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/chronicle_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (8.534s) |

| `tests/cinder_droplet_cutout_asset_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/cinder_droplet_cutout_gameplay_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/cinder_droplet_cutout_pack_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.263s) |

| `tests/cinder_droplet_cutout_pose_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/cinder_droplet_cutout_test.gd` | full suite | shared wrapper: tests/suites/cinder_droplet_cutout_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/cinder_droplet_cutout_test.gd.log) (3.840s) |

| `tests/cinder_ooze_cutout_asset_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/cinder_ooze_cutout_gameplay_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/cinder_ooze_cutout_pack_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.260s) |

| `tests/cinder_ooze_cutout_test.gd` | full suite | shared wrapper: tests/suites/cinder_ooze_cutout_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/cinder_ooze_cutout_test.gd.log) (3.829s) |

| `tests/click_first_combat_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/combat_analytics_context_equivalence_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (5.464s) |

| `tests/combat_art_treatment_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/combat_board_navigation_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/combat_board_navigation_test.gd` | quarantined | needs-design; design-01; Zoom anchoring fails the <=1 px geometry contract. Other navigation checks pass. Needs framing/zoom investigation with renderer proof; changing the expected coordinates here would choose player-visible behavior. (output/qa-08/quarantine-check/combat_board_navigation_test.gd.log) | [FAIL, exit 1](../output/qa-08/quarantine-check/combat_board_navigation_test.gd.log) (5.372s) |

| `tests/combat_board_render_equivalence_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/combat_boundary_equivalence_test.gd` | quarantined | stale-reference; qa-09; Frozen OriginalRunEngine/OriginalCombatEngine copies disagree with current checkpoints (12 assertions), and the display fixture no longer consumes its one-shot modifier. Requires updating the independent reference to the current save/deck/clock contracts; assertions retained. (output/qa-08/quarantine-check/combat_boundary_equivalence_test.gd.log) | [FAIL, exit 1](../output/qa-08/quarantine-check/combat_boundary_equivalence_test.gd.log) (11.991s) |

| `tests/combat_feel_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/combat_feel_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (31.602s) |

| `tests/combat_ground_marker_depth_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/combat_hand_flanks_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/combat_hud_badges_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/combat_hud_badges_test.gd` | quarantined | needs-design; design-01; Fixture expects INTENTS [I]/INTENTS ON [I] and the former controller-tooltip contract. These expectations predate the current HUD presentation. Needs the design owner's current UI contract; no copy or layout changed. (output/qa-08/quarantine-check/combat_hud_badges_test.gd.log) | [FAIL, exit 1](../output/qa-08/quarantine-check/combat_hud_badges_test.gd.log) (16.118s) |

| `tests/combat_hud_buttons_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/combat_hud_buttons_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (11.625s) |

| `tests/combat_hud_dialogue_input_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (7.403s) |

| `tests/combat_interaction_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/combat_lighting_density_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/combat_lighting_variants_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/combat_motion_timing_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/combat_motion_timing_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (11.137s) |

| `tests/combat_music_integration_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (8.938s) |

| `tests/combat_objective_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/committed_hand_queries_test.gd` | quarantined | stale-reference; qa-09; One mixed revealed/hidden forecast fixture no longer reports unrevealed_before_player; prepared and synchronous results still compare equal. Requires rebuilding the scheduled hidden-enemy fixture without weakening that assertion. (output/qa-08/quarantine-check/committed_hand_queries_test.gd.log) | [FAIL, exit 1](../output/qa-08/quarantine-check/committed_hand_queries_test.gd.log) (12.081s) |

| `tests/contextual_combat_tutorial_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/contextual_combat_tutorial_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (0.718s) |

| `tests/contextual_creature_keypose_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/contextual_creature_motion_test.gd` | quarantined | legacy-cutout; qa-10; Non-shipped historical experiment inputs under output/contextual-animation-polish/creatures/cases/crawler are absent (motion.gd, baseline_motion.gd and JSON). The script errors and never reaches quit. Needs a reproducible fixture or migration to the current approved rig. (output/qa-08/quarantine-check/contextual_creature_motion_test.gd.log) | [TIMEOUT, exit 124](../output/qa-08/quarantine-check/contextual_creature_motion_test.gd.log) (180.068s) |

| `tests/contextual_cutout_gameplay_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/contextual_cutout_test.gd` | full suite | shared wrapper: tests/suites/contextual_cutout_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/contextual_cutout_test.gd.log) (20.086s) |

| `tests/controller_compat_1080_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/controller_desktop_1080_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/crawler_cutout_asset_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/crawler_cutout_gameplay_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/crawler_cutout_pack_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.334s) |

| `tests/crawler_cutout_test.gd` | full suite | shared wrapper: tests/suites/crawler_cutout_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/crawler_cutout_test.gd.log) (3.356s) |

| `tests/crawler_recolour_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/cursor_feedback_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/cursor_feedback_test.gd` | full suite | shared wrapper: tests/suites/cursor_feedback_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/cursor_feedback_test.gd.log) (3.432s) |

| `tests/cutout_pose_application_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (4.827s) |

| `tests/cutout_rig_data_test.gd` | quarantined | legacy-cutout; qa-10; Legacy Lightning Wisp motion reads crown, which the promoted maquette layout no longer contains. The test can print PASS after this script error; the task runner correctly fails it. Requires migration to the production maquette runtime. (output/qa-08/quarantine-check/cutout_rig_data_test.gd.log) | [FAIL, exit 1](../output/qa-08/quarantine-check/cutout_rig_data_test.gd.log) (0.938s) |

| `tests/cutout_submission_equivalence_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (4.712s) |

| `tests/cutout_workflow_input_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/death_transition_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/death_transition_test.gd` | windowed probe | Enemy-round feedback waits for frame_post_draw (explicit headless rejection). | Not run (native) |

| `tests/defeat_cleanup_overlap_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/deferred_reconciliation_queue_test.gd` | windowed probe | Asserts one queue step per rendered frame; requires native frame_post_draw. | Not run (native) |

| `tests/deferred_run_skill_analytics_test.gd` | windowed probe | Asserts deferred run analytics across production rendered frames. | Not run (native) |

| `tests/deferred_skill_analytics_test.gd` | windowed probe | Asserts deferred combat analytics across production rendered frames. | Not run (native) |

| `tests/defiance_ui_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/demo_capture_settings_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (0.831s) |

| `tests/demo_clip_clock_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (0.836s) |

| `tests/demo_probe_viewport_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (4.201s) |

| `tests/departed_run_cleanup_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (9.581s) |

| `tests/depth_rules_test.gd` | full suite | shared wrapper: tests/suites/depth_rules_suite.gd::run, tests/suites/guardian_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/depth_rules_test.gd.log) (22.840s) |

| `tests/destruction_preview_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/destruction_preview_test.gd` | full suite | shared wrapper: tests/suites/destruction_preview_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/destruction_preview_test.gd.log) (3.803s) |

| `tests/dragon_area_presentation_test.gd` | quarantined | needs-design; design-01; Four Fire/Earth cancellation assertions fail against current committed-pattern behavior. This crosses authored counterplay rules; requires a dedicated encounter investigation/approved fixture update, not altered assertions. (output/qa-08/quarantine-check/dragon_area_presentation_test.gd.log) | [FAIL, exit 1](../output/qa-08/quarantine-check/dragon_area_presentation_test.gd.log) (3.572s) |

| `tests/dragon_attachment_asset_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/dragon_boss_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/dragon_boss_test.gd` | full suite | shared wrapper: tests/suites/dragon_boss_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/dragon_boss_test.gd.log) (8.350s) |

| `tests/dragon_canceled_area_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/dragon_committed_patterns_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (11.205s) |

| `tests/dragon_exchange_presentation_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (13.691s) |

| `tests/dragon_feedback_mechanics_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (10.577s) |

| `tests/dragon_presentation_feedback_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/dragon_pressure_earth_breath_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/dragon_pressure_escape_probe.gd` | quarantined | long-diagnostic; qa-11; This is an exhaustive headless geometry/Time diagnostic, not a renderer probe. Its all-dragon/all-warning BFS sweep timed out first at 45 seconds, then at the normal 180-second program budget (180.050s, exit 124); no assertion verdict. Needs separately budgeted/partitioned diagnostic coverage before suite inclusion. (output/qa-08/quarantine-check/dragon_pressure_escape_probe.gd.log) | [TIMEOUT, exit 124](../output/qa-08/quarantine-check/dragon_pressure_escape_probe.gd.log) (180.086s) |

| `tests/dragon_pressure_grimoire_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/dragon_pressure_ice_pursuit_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/dragon_pressure_mechanics_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (6.137s) |

| `tests/dragon_pressure_presentation_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/dragon_pressure_ring_copy_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/dragon_pressure_warning_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/dragon_revision_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/dragon_reward_feedback_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/dragon_reward_feedback_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.948s) |

| `tests/dragon_reward_tooltip_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/dragon_rewards_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/dragon_rewards_test.gd` | quarantined | stale-reference; qa-09; Confirmed stale singleton-outbox expectation: the diagnostic observes has_run=false and exactly reward_claimed plus run_scored. The run clears and the claim persists; meta-01 added the second legitimate event. Existing assertion retained as requested; migrate the fixture to test the keyed claim independently. (output/qa-08/quarantine-check/dragon_rewards_test.gd.log) | [FAIL, exit 1](../output/qa-08/quarantine-check/dragon_rewards_test.gd.log) (12.886s) |

| `tests/dragon_shadow_visible_source_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/dragon_spire_routes_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.572s) |

| `tests/dragon_trophy_feedback_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/dragon_trophy_feedback_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.417s) |

| `tests/dragon_wallet_ack_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (9.355s) |

| `tests/earthen_rampart_rotate_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/elemental_ambient_transition_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/elemental_aoe_attack_visual_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/elemental_fx_hash_equivalence_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (0.725s) |

| `tests/elemental_ranged_attack_visual_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/elemental_room_overlays_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/elemental_spell_effects_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/elemental_spell_fx_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (3.018s) |

| `tests/elemental_spell_geometry_equivalence_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/elemental_trap_visual_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/ember_hearth_test.gd` | full suite | shared wrapper: tests/suites/ember_hearth_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/ember_hearth_test.gd.log) (13.458s) |

| `tests/ember_reward_feedback_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/ember_reward_feedback_test.gd` | full suite | shared wrapper: tests/suites/ember_reward_feedback_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/ember_reward_feedback_test.gd.log) (5.950s) |

| `tests/en01_enemies_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/en01_enemies_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (6.204s) |

| `tests/en02_enemies_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/en02_enemies_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (6.147s) |

| `tests/en03_enemies_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/en03_enemies_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (8.338s) |

| `tests/en04_enemies_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/en04_enemies_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (6.168s) |

| `tests/en05_elemental_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (4.853s) |

| `tests/en05_enemies_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/en05_enemies_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (5.363s) |

| `tests/en05_integration_sync_test.gd` | quarantined | stale-reference; qa-09; Snapshot assumes the prior Gust Shrike front/rear source hashes and shadow roster. The approved rr-03 cutout promotion changed that presentation, so exact frozen shadow entries/additions no longer match. Needs a new approved baseline. (output/qa-08/quarantine-check/en05_integration_sync_test.gd.log) | [FAIL, exit 1](../output/qa-08/quarantine-check/en05_integration_sync_test.gd.log) (4.237s) |

| `tests/en05_live_integration_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (8.085s) |

| `tests/en05_probe_contract_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (5.541s) |

| `tests/en06_enemies_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/en06_enemies_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (10.891s) ; [earlier load timeout, exit 124, 180.209s](../output/qa-08/integrated-final-load-1.log), root cause open |

| `tests/encounter_entry_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/encounter_framing_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/encounter_tables_test.gd` | full suite | partitioned headless entrypoint: tests/suites/encounter_rules_program.gd, tests/suites/encounter_placement_0_program.gd, tests/suites/encounter_placement_1_program.gd, tests/suites/encounter_placement_summary_program.gd | Covered by invoked full-suite entrypoint |

| `tests/enemy_cutout_roster_aoe_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/enemy_cutout_roster_gameplay_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/enemy_cutout_roster_pack_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (2.165s) |

| `tests/enemy_intent_compass_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/enemy_intent_continuity_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/enemy_intent_continuity_test.gd` | full suite | shared wrapper: tests/suites/enemy_intent_continuity_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/enemy_intent_continuity_test.gd.log) (9.454s) |

| `tests/enemy_intent_preview_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/enemy_intent_preview_test.gd` | full suite | shared wrapper: tests/suites/enemy_intent_preview_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/enemy_intent_preview_test.gd.log) (3.854s) |

| `tests/enemy_intent_top_edge_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/enemy_pathfinding_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/enemy_pathfinding_test.gd` | full suite | shared wrapper: tests/suites/enemy_pathfinding_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/enemy_pathfinding_test.gd.log) (4.086s) |

| `tests/enemy_route_allocation_equivalence_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (19.440s) |

| `tests/enemy_shadow_dissolve_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/enemy_strike_trail_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/enemy_strike_trail_test.gd` | full suite | shared wrapper: tests/suites/enemy_strike_trail_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/enemy_strike_trail_test.gd.log) (8.888s) |

| `tests/enemy_surface_acceptance_test.gd` | full suite | shared wrapper: tests/suites/enemy_surface_acceptance_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/enemy_surface_acceptance_test.gd.log) (1.213s) |

| `tests/enemy_tactical_ai_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/enemy_tactical_ai_test.gd` | full suite | shared wrapper: tests/suites/enemy_tactical_ai_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/enemy_tactical_ai_test.gd.log) (1.171s) |

| `tests/equipment_inventory_readability_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/equipment_inventory_readability_test.gd` | quarantined | needs-design; design-01; Current equipment card labels fail the fixture's font-size/word-clipping limits (six named equipment pairs). Requires actual UI proof and owner-directed layout/copy decisions; no visual values changed. (output/qa-08/quarantine-check/equipment_inventory_readability_test.gd.log) | [FAIL, exit 1](../output/qa-08/quarantine-check/equipment_inventory_readability_test.gd.log) (8.813s) |

| `tests/equipment_pickup_visibility_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/event_rules_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (21.960s) |

| `tests/event_view_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/event_view_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (33.415s) |

| `tests/fireball_attack_visual_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/fix_03_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/fix_03_test.gd` | full suite | shared wrapper: tests/suites/fix_03_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/fix_03_test.gd.log) (3.785s) |

| `tests/fixtures/native_font_cache_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/floating_damage_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/floating_text_collision_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/flurry_card_pack_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/forced_movement_preview_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/forced_movement_query_equivalence_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (75.393s) |

| `tests/forced_movement_test.gd` | full suite | shared wrapper: tests/suites/forced_movement_suite.gd::run, tests/suites/forced_movement_suite.gd::run_live | [PASS, exit 0](../output/qa-08/orphans/forced_movement_test.gd.log) (8.694s) |

| `tests/foreground_actor_readability_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/frostglass_lancer_cutout_asset_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/frostglass_lancer_cutout_gameplay_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/frostglass_lancer_cutout_pack_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.368s) |

| `tests/frostglass_lancer_cutout_test.gd` | full suite | shared wrapper: tests/suites/frostglass_lancer_cutout_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/frostglass_lancer_cutout_test.gd.log) (3.142s) |

| `tests/frostglass_lancer_motion_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (0.695s) |

| `tests/frostglass_lancer_style_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/glossary_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (10.559s) |

| `tests/glossary_tooltip_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/graftwright_console_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.859s) |

| `tests/graftwright_cutout_pack_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (0.843s) |

| `tests/graftwright_feedback_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/graftwright_motion_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/graftwright_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/graftwright_resume_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/graftwright_test.gd` | full suite | shared wrapper: tests/suites/graftwright_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/graftwright_test.gd.log) (23.981s) |

| `tests/grave_surgeon_cutout_asset_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/grave_surgeon_cutout_gameplay_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/grave_surgeon_cutout_pack_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.279s) |

| `tests/grave_surgeon_cutout_test.gd` | full suite | shared wrapper: tests/suites/grave_surgeon_cutout_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/grave_surgeon_cutout_test.gd.log) (3.828s) |

| `tests/grimoire_focus_return_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/grimoire_performance_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (0.719s) |

| `tests/grimoire_search_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/grimoire_search_rows_equivalence_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (15.300s) |

| `tests/grimoire_search_test.gd` | full suite | shared wrapper: tests/suites/grimoire_search_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/grimoire_search_test.gd.log) (0.356s) |

| `tests/guardian_contract_probe.gd` | full suite | shared wrapper: tests/suites/combat_outcome_feedback_suite.gd::run, tests/suites/ground_targeting_suite.gd::run, tests/suites/guardian_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/guardian_contract_probe.gd.log) (8.880s) |

| `tests/guardian_cutout_motion_probe.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (2.095s) |

| `tests/guardian_cutout_pack_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.047s) |

| `tests/guardian_feedback_playback_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/guardian_gameplay_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/guardian_inspection_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/guardian_map_revision_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/guardian_revision_03_ui_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/guardian_revision_04_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/guardian_ui_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/guided_combat_tutorial_integration_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (7.568s) |

| `tests/gust_shrike_cutout_pack_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.456s) |

| `tests/gust_shrike_cutout_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/gust_shrike_cutout_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (4.934s) |

| `tests/hand_card_focus_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/harrier_cutout_asset_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/harrier_cutout_gameplay_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/harrier_cutout_pack_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.469s) |

| `tests/harrier_cutout_test.gd` | full suite | shared wrapper: tests/suites/harrier_cutout_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/harrier_cutout_test.gd.log) (3.410s) |

| `tests/headless_playtest_progression_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (2.146s) |

| `tests/health_bar_theme_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/health_cost_preview_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/health_ghost_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/health_ghost_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (8.234s) |

| `tests/humanoid_cutout_reaction_motion_probe.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.786s) |

| `tests/illusion_animation_gameplay_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/illusion_terrain_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/illusion_terrain_test.gd` | full suite | shared wrapper: tests/suites/illusion_terrain_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/illusion_terrain_test.gd.log) (4.206s) |

| `tests/initiative_order_test.gd` | full suite | shared wrapper: tests/suites/initiative_order_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/initiative_order_test.gd.log) (3.751s) |

| `tests/inline_icon_description_test.gd` | full suite | shared wrapper: tests/suites/inline_icon_description_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/inline_icon_description_test.gd.log) (0.541s) |

| `tests/iskaldra_cutout_asset_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/iskaldra_cutout_gameplay_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/iskaldra_cutout_pack_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.347s) |

| `tests/iskaldra_cutout_test.gd` | full suite | shared wrapper: tests/suites/iskaldra_cutout_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/iskaldra_cutout_test.gd.log) (3.083s) |

| `tests/item_card_art_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/item_pickup_deck_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/item_pickup_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/item_pickup_test.gd` | full suite | shared wrapper: tests/suites/item_pickup_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/item_pickup_test.gd.log) (5.095s) |

| `tests/large_target_retained_overlay_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/late_stop_peak_test.gd` | full suite | shared wrapper: tests/suites/combat_feel_suite.gd::_test_late_stop_peak | [PASS, exit 0](../output/qa-08/orphans/late_stop_peak_test.gd.log) (3.905s) |

| `tests/lethal_preview_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/lightning_wisp_cutout_asset_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/lightning_wisp_cutout_gameplay_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/lightning_wisp_cutout_pack_test.gd` | quarantined | legacy-cutout; qa-10; The transitive dependency fix exposes the older renderer's crown lookup and old skeleton-count assumptions against the promoted maquette assets. Package build succeeds; verification fails. Needs migration to the actual production maquette renderer, with the original coverage preserved. (output/qa-08/quarantine-check/lightning_wisp_cutout_pack_test.gd.log) | [FAIL, exit 1](../output/qa-08/quarantine-check/lightning_wisp_cutout_pack_test.gd.log) (0.815s) |

| `tests/lightning_wisp_cutout_test.gd` | full suite | shared wrapper: tests/suites/lightning_wisp_cutout_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/lightning_wisp_cutout_test.gd.log) (12.612s) |

| `tests/loadout_acquisition_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/loadout_material_polish_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/locked_hand_cache_lifecycle_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/magic_deck_character_regression_test.gd` | full suite | shared wrapper: tests/run_tests.gd::_test_run_scene_campfire_choices_use_relic_overlay, tests/run_tests.gd::_test_run_scene_character_stats_overlay_opens, tests/run_tests.gd::_test_run_scene_debug_boss_fixture_boots, tests/run_tests.gd::_test_run_scene_reward_decision_support_matches_claims, tests/suites/ember_hearth_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/magic_deck_character_regression_test.gd.log) (18.289s) |

| `tests/magic_deck_guard_mutation_test.gd` | full suite | shared wrapper: tests/sfx_sync_sources.gd::compile_script, tests/suites/magic_deck_suite.gd::unowned_purge_checks | [PASS, exit 0](../output/qa-08/orphans/magic_deck_guard_mutation_test.gd.log) (1.669s) |

| `tests/magic_deck_input_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (14.820s) |

| `tests/magic_deck_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (5.815s) |

| `tests/magic_deck_ui_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/main_menu_branding_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/main_menu_input_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/main_menu_input_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (21.449s) |

| `tests/main_menu_resume_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/main_menu_resume_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (7.838s) |

| `tests/main_menu_umbra_button_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/maneuver_board_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/maneuver_cards_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/maneuver_test.gd` | full suite | shared wrapper: tests/suites/maneuver_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/maneuver_test.gd.log) (3.824s) |

| `tests/map_decision_layer_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/map_overlay_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/map_travel_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/maquette_cutout/integration_test.gd` | full suite | shared wrapper: tests/suites/contextual_cutout_suite.gd::run, tests/suites/enemy_strike_trail_suite.gd::run, tests/suites/pre_battle_ui_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/maquette_cutout_integration_test.gd.log) (30.687s) |

| `tests/maquette_cutout/movement_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/maquette_cutout/runtime_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/maquette_cutout_test.gd` | full suite | shared wrapper: tests/maquette_cutout/runtime_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/maquette_cutout_test.gd.log) (17.826s) |

| `tests/merchant_acquisition_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/merchant_stock_equivalence_probe.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (8.879s) |

| `tests/meteor_marks_board_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/missed_equipment_resolution_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/motion_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/move_attack_approach_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/move_attack_shortcut_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/movement_path_arrow_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/movement_undo_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/movement_undo_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (19.484s) |

| `tests/music_continuity_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (35.292s) |

| `tests/new_descent_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/noctyrax_cutout_asset_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/noctyrax_cutout_gameplay_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/noctyrax_cutout_pack_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.469s) |

| `tests/noctyrax_cutout_test.gd` | full suite | shared wrapper: tests/suites/noctyrax_cutout_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/noctyrax_cutout_test.gd.log) (3.061s) |

| `tests/noncombat_move_equivalence_test.gd` | quarantined | stale-reference; qa-09; Independent original movement reference omits new run_stats/Chronicle fields and differs on some encounter transitions. The log records 1,920 cases and exact differing keys. Requires a coordinated reference update for current run/encounter flow. (output/qa-08/quarantine-check/noncombat_move_equivalence_test.gd.log) | [FAIL, exit 1](../output/qa-08/quarantine-check/noncombat_move_equivalence_test.gd.log) (40.323s) |

| `tests/objective_glyph_equivalence_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (12.750s) |

| `tests/opening_boon_probe.gd` | windowed probe | Native opening-boon capture and controller/pointer proof; opening-boon and recovery programs run headless. | Not run (native) |

| `tests/opening_boon_recovery_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (12.085s) |

| `tests/opening_boon_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (15.480s) |

| `tests/original_music_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (11.302s) |

| `tests/owned_combat_creation_equivalence_test.gd` | quarantined | long-diagnostic; qa-11; Exhaustive run/tutorial/relic preparation matrix exceeds the existing 180-second program budget (exit 124, no final result). Initial 45-second timeout was rerun at the normal budget. Needs matrix partitioning/performance investigation; no success or gameplay-bug claim. (output/qa-08/quarantine-check/owned_combat_creation_equivalence_test.gd.log) | [TIMEOUT, exit 124](../output/qa-08/quarantine-check/owned_combat_creation_equivalence_test.gd.log) (180.092s) |

| `tests/owned_cpu_asset_preparation_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.958s) |

| `tests/pass_preview_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/pause_overlay_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/performance_phase_fast_path_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (3.598s) |

| `tests/performance_telemetry_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (0.624s) |

| `tests/pillar_torch_lighting_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/pixel_fx_compare_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/pixel_fx_render_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/pixel_fx_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (7.029s) |

| `tests/player_aim_curve_ownership_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/player_defeat_continuity_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (32.903s) |

| `tests/player_movement_outcome_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/player_movement_outcome_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (12.382s) |

| `tests/player_movement_test.gd` | full suite | shared wrapper: tests/suites/player_movement_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/player_movement_test.gd.log) (1.107s) |

| `tests/player_movement_visual_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/pre_battle_deck_fit_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/pre_battle_deck_fit_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (8.570s) |

| `tests/pre_battle_living_foes_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/pre_battle_living_foes_test.gd` | full suite | shared wrapper: tests/suites/combat_objective_suite.gd::run, tests/suites/pre_battle_living_foes_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/pre_battle_living_foes_test.gd.log) (7.737s) |

| `tests/pre_battle_loadout_refinement_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/pre_battle_material_polish_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/pre_battle_pinned_hover_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/pre_battle_pinned_hover_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (5.759s) |

| `tests/pre_battle_preview_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/pre_battle_review_findings_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/pre_battle_review_fixes_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (5.792s) |

| `tests/pre_battle_semantics_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (15.570s) |

| `tests/pre_battle_true_scale_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/pre_battle_true_scale_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (7.020s) |

| `tests/pre_battle_view_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (20.176s) |

| `tests/premium_button_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/premium_card_material_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/prepared_card_preview_queries_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (10.590s) |

| `tests/prepared_encounter_equivalence_test.gd` | quarantined | stale-reference; qa-09; Frozen pre_battle_factory_reference no longer matches the complete current combat factory and invalidation inputs after run-flow changes. Twenty-four cases fail reference/state comparisons. Needs independent reference migration. (output/qa-08/quarantine-check/prepared_encounter_equivalence_test.gd.log) | [FAIL, exit 1](../output/qa-08/quarantine-check/prepared_encounter_equivalence_test.gd.log) (17.869s) |

| `tests/prepared_equipment_combat_test.gd` | quarantined | stale-reference; qa-09; Same frozen pre-battle factory mismatch across 144 equipment cases (1,625 checks). Updating only expected booleans would hide the migration; dedicated factory-reference work required. (output/qa-08/quarantine-check/prepared_equipment_combat_test.gd.log) | [FAIL, exit 1](../output/qa-08/quarantine-check/prepared_equipment_combat_test.gd.log) (25.228s) |

| `tests/prepared_equipment_scene_handoff_test.gd` | quarantined | stale-reference; qa-09; Prepared equipment scene callback/factory differs from the frozen original complete state (38 checks). Shares the outdated factory reference and requires end-to-end reference/ownership investigation. (output/qa-08/quarantine-check/prepared_equipment_scene_handoff_test.gd.log) | [FAIL, exit 1](../output/qa-08/quarantine-check/prepared_equipment_scene_handoff_test.gd.log) (11.724s) |

| `tests/prepared_other_character_view_test.gd` | quarantined | possible-bug; bug-01; Completes at the normal budget: 45 cases/1,116 checks, zero visual differences, one input-capture/cancellation ownership assertion fails. This is a potential real invalidation bug; requires a focused character-view ownership fix. (output/qa-08/quarantine-check/prepared_other_character_view_test.gd.log) | [FAIL, exit 1](../output/qa-08/quarantine-check/prepared_other_character_view_test.gd.log) (64.243s) |

| `tests/prepared_pre_battle_view_equivalence_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (10.019s) |

| `tests/prepared_reward_choices_test.gd` | quarantined | stale-reference; qa-09; Missing GameData preload fixed in its workload dependency. It now completes and exposes stale full-state comparisons with the independent reward reference across 20 cases (no pixel differences). Requires reference/committed-analytics reconciliation. (output/qa-08/quarantine-check/prepared_reward_choices_test.gd.log) | [FAIL, exit 1](../output/qa-08/quarantine-check/prepared_reward_choices_test.gd.log) (20.064s) |

| `tests/prepared_shop_equivalence_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (2.410s) |

| `tests/prepared_shop_glyph_equivalence_test.gd` | quarantined | needs-design; design-01; Headless path still asserts that cancellation/show/detach crossed real native outline rendering. Needs headless cancellation semantics separated from actual-renderer proof; assertions retained. (output/qa-08/quarantine-check/prepared_shop_glyph_equivalence_test.gd.log) | [FAIL, exit 1](../output/qa-08/quarantine-check/prepared_shop_glyph_equivalence_test.gd.log) (8.368s) |

| `tests/prepared_travel_combat_test.gd` | quarantined | stale-reference; qa-09; Complete travel preview/Begin/fallback comparisons disagree with pre_battle_factory_reference (24 cases). Same outdated independent factory reference; no production factory changed in this unit. (output/qa-08/quarantine-check/prepared_travel_combat_test.gd.log) | [FAIL, exit 1](../output/qa-08/quarantine-check/prepared_travel_combat_test.gd.log) (10.799s) |

| `tests/prepared_unit_canvas_equivalence_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (13.527s) |

| `tests/profile_read_equivalence_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (2.878s) |

| `tests/program_suite_runner_test.gd` | full suite | Python full suite: tests/test_program_suite_runner.py::ProgramSuiteRunnerTests.run_godot_fixture | Covered by invoked full-suite entrypoint |

| `tests/protagonist_cutout_continue_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/protagonist_cutout_gameplay_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/protagonist_cutout_pack_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.678s) |

| `tests/protagonist_cutout_test.gd` | full suite | shared wrapper: tests/suites/protagonist_cutout_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/protagonist_cutout_test.gd.log) (5.142s) |

| `tests/protagonist_full_gear_motion_test.gd` | full suite | shared wrapper: tests/suites/protagonist_full_gear_motion_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/protagonist_full_gear_motion_test.gd.log) (5.975s) |

| `tests/protagonist_gear_carry_test.gd` | full suite | shared wrapper: tests/suites/protagonist_gear_carry_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/protagonist_gear_carry_test.gd.log) (7.064s) |

| `tests/protagonist_gear_motion_gameplay_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (52.255s) |

| `tests/protagonist_gear_motion_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/protagonist_gear_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/protagonist_gear_test.gd` | full suite | shared wrapper: tests/suites/protagonist_gear_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/protagonist_gear_test.gd.log) (16.281s) |

| `tests/protagonist_ranged_gameplay_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/protagonist_ranged_test.gd` | full suite | shared wrapper: tests/suites/protagonist_ranged_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/protagonist_ranged_test.gd.log) (4.951s) |

| `tests/radiance_package_test.gd` | full suite | shared wrapper: tests/suites/radiance_package_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/radiance_package_test.gd.log) (1.177s) |

| `tests/reach_rebalance_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/reach_rebalance_test.gd` | full suite | shared wrapper: tests/suites/reach_rebalance_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/reach_rebalance_test.gd.log) (1.618s) |

| `tests/ready_wave_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/relic_choice_sparkle_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/relic_damage_feedback_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/relic_offer_fit_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/relic_rework_visual_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/relic_test.gd` | full suite | shared wrapper: tests/suites/relic_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/relic_test.gd.log) (4.161s) |

| `tests/relic_u1_test.gd` | full suite | shared wrapper: tests/suites/relic_u1_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/relic_u1_test.gd.log) (24.195s) |

| `tests/relic_u2_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/relic_u2_test.gd` | full suite | shared wrapper: tests/suites/relic_u2_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/relic_u2_test.gd.log) (11.596s) |

| `tests/relic_u3_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/relic_u3_test.gd` | full suite | shared wrapper: tests/suites/relic_u3_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/relic_u3_test.gd.log) (4.389s) |

| `tests/relic_u4_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/relic_u4_test.gd` | full suite | shared wrapper: tests/suites/relic_u4_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/relic_u4_test.gd.log) (4.401s) |

| `tests/relic_u5_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/relic_u5_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (5.506s) |

| `tests/relic_u6_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/relic_u6_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (5.902s) |

| `tests/relic_u7_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/relic_u7_test.gd` | full suite | shared wrapper: tests/suites/relic_u7_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/relic_u7_test.gd.log) (4.390s) |

| `tests/relic_u8_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/relic_u8_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (5.347s) |

| `tests/remaining_hitch_native_trace_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/retained_character_deck_equivalence_test.gd` | quarantined | stale-reference; qa-09; Fixture directly indexes the retired magic slot dictionary after deck-01 removed magic slots. Script error prevents completion. Requires migration to the approved spells-in-deck flow. (output/qa-08/quarantine-check/retained_character_deck_equivalence_test.gd.log) | [TIMEOUT, exit 124](../output/qa-08/quarantine-check/retained_character_deck_equivalence_test.gd.log) (180.119s) |

| `tests/retained_character_header_equivalence_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (13.505s) |

| `tests/retained_character_inventory_equivalence_test.gd` | quarantined | possible-bug; bug-01; Normal-budget rerun completes: 117 cases and zero visual differences, but authoritative-state preservation assertions fail during equipment definition changes/boundary opens. Potential real ownership/mutation regression; dedicated fix required. (output/qa-08/quarantine-check/retained_character_inventory_equivalence_test.gd.log) | [FAIL, exit 1](../output/qa-08/quarantine-check/retained_character_inventory_equivalence_test.gd.log) (92.452s) |

| `tests/retained_character_loadout_equivalence_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (10.416s) |

| `tests/retained_section_map_equivalence_test.gd` | quarantined | stale-reference; qa-09; Both current panel and old reference fixture are accessed through the removed _event_panel property. Script errors invalidate the printed errors=[]/exit-zero marker; task runner correctly rejects it. Requires fixture/API migration. (output/qa-08/quarantine-check/retained_section_map_equivalence_test.gd.log) | [FAIL, exit 1](../output/qa-08/quarantine-check/retained_section_map_equivalence_test.gd.log) (5.776s) |

| `tests/retained_shop_rows_equivalence_test.gd` | quarantined | stale-reference; qa-09; Fixture indexes a missing sell:frostbolt row. deck-01 changed spells to the new purge/deck flow, so the legacy sell-row fixture no longer reaches its assertion boundary. Requires migration to that flow. (output/qa-08/quarantine-check/retained_shop_rows_equivalence_test.gd.log) | [TIMEOUT, exit 124](../output/qa-08/quarantine-check/retained_shop_rows_equivalence_test.gd.log) (180.103s) |

| `tests/reward_decision_support_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/run_end_recap_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/run_score_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (9.255s) |

| `tests/run_sfx_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/save_pipeline_performance_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (0.889s) |

| `tests/save_resume_boundary_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (11.152s) |

| `tests/save_resume_inspection_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/scavenger_cutout_pack_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (0.877s) |

| `tests/scavenger_glowup_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/scavenger_motion_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/scavenger_regression_test.gd` | full suite | shared wrapper: tests/run_tests.gd::_test_equipment_collection_to_equip_deck_flow, tests/run_tests.gd::_test_equipment_run_state_and_reward_cards, tests/run_tests.gd::_test_merchant_assets_load_for_board, tests/run_tests.gd::_test_run_map_merchant_room_spacing_and_density, tests/run_tests.gd::_test_run_scene_character_stats_overlay_opens | [PASS, exit 0](../output/qa-08/orphans/scavenger_regression_test.gd.log) (19.592s) |

| `tests/scavenger_resource_cache_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (0.940s) |

| `tests/scavenger_resume_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/scavenger_shop_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/scavenger_visual_pass_4_test.gd` | quarantined | stale-reference; qa-09; Controller trade assertion expects the inspected card purchase to appear in the old magic representation. Requires current deck/purchase fixture and native controller proof; no UI/input behavior changed. (output/qa-08/quarantine-check/scavenger_visual_pass_4_test.gd.log) | [FAIL, exit 1](../output/qa-08/quarantine-check/scavenger_visual_pass_4_test.gd.log) (12.595s) |

| `tests/section_map_flow_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/section_map_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/section_map_review_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/section_map_structural_rejection_test.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/section_map_test.gd` | full suite | shared wrapper: tests/suites/section_map_suite.gd::run | [TIMEOUT, exit 124](../output/qa-08/orphans/section_map_test.gd.log) (45.080s) |

| `tests/section_map_v2_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (51.453s) |

| `tests/section_map_v5_layout_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (64.037s) |

| `tests/section_map_v5_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (89.556s) |

| `tests/section_map_variety_probe.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/selection_prompt_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/selective_ui_salvage_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/settings_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/sfx_bank_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (10.827s) |

| `tests/sfx_cue_coverage_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/sfx_sync_bank_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.027s) |

| `tests/shadow_triangulation_equivalence_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (4.860s) |

| `tests/shale_bloomer_art_visual_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/shop_retained_content_test.gd` | quarantined | possible-bug; bug-01; Unchanged pack refresh loses the test's selected page. Concrete retained-shop pagination regression; needs a focused shop update (existing assertions preserved). (output/qa-08/quarantine-check/shop_retained_content_test.gd.log) | [FAIL, exit 1](../output/qa-08/quarantine-check/shop_retained_content_test.gd.log) (2.784s) |

| `tests/shortcut_risk_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/skill_combat_test.gd` | full suite | shared wrapper: tests/suites/skill_combat_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/skill_combat_test.gd.log) (1.293s) |

| `tests/skill_link_geometry_equivalence_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (0.973s) |

| `tests/skill_material_polish_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/skill_progression_analytics_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (5.169s) |

| `tests/skill_run_test.gd` | full suite | shared wrapper: tests/suites/skill_run_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/skill_run_test.gd.log) (6.900s) |

| `tests/skill_tree_test.gd` | full suite | shared wrapper: tests/suites/skill_tree_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/skill_tree_test.gd.log) (3.145s) |

| `tests/skill_tree_view_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.100s) |

| `tests/skill_tree_visual_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/skill_ui_test.gd` | windowed probe | Production skill analytics drain across rendered frames (documented real-renderer test). | Not run (native) |

| `tests/staged_reward_choices_equivalence_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (9.549s) |

| `tests/start_room_map_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/start_room_map_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (18.921s) |

| `tests/static_facing_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/static_facing_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (3.068s) |

| `tests/static_floor_cache_equivalence_test.gd` | quarantined | possible-bug; bug-01; 102 cases/156,715 checks finish; empty-board restored presentation differs between retained/current and reference state. Needs cache presentation/empty-board restoration investigation, including native pixel proof. (output/qa-08/quarantine-check/static_floor_cache_equivalence_test.gd.log) | [FAIL, exit 1](../output/qa-08/quarantine-check/static_floor_cache_equivalence_test.gd.log) (5.991s) |

| `tests/steam_deck_720p_stress_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/steam_deck_compat_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/steam_media_color_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/stone_warden_cutout_asset_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/stone_warden_cutout_gameplay_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/stone_warden_cutout_pack_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.338s) |

| `tests/stone_warden_cutout_test.gd` | full suite | shared wrapper: tests/suites/stone_warden_cutout_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/stone_warden_cutout_test.gd.log) (3.709s) |

| `tests/strike_trail_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/strike_trail_test.gd` | full suite | shared wrapper: tests/suites/strike_trail_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/strike_trail_test.gd.log) (3.774s) |

| `tests/structural_route_equivalence_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (10.412s) |

| `tests/suites/acolyte_cutout_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/actor_presentation_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/attack_fx_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/attack_sfx_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/audio_routing_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/balance_pacing_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/bile_bloomer_cutout_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/biome_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/board_density_consumer_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/board_surface_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/card_drag_play_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/card_keywords_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/card_keywords_w3_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/card_mechanics_surfaces_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/card_playability_summary_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/card_pool_overhaul_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/card_targeting_audit_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/cbt_01_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/chain_attack_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/chainbound_gaoler_cutout_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/chronicle_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/cinder_droplet_cutout_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/cinder_ooze_cutout_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/combat_board_layout_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/combat_feel_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/combat_lighting_profiles_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/combat_motion_timing_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/combat_objective_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/combat_outcome_feedback_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/combat_pacing_regression_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/contextual_cutout_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/controller_input_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/crawler_cutout_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/cursor_feedback_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/depth_rules_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/destruction_preview_privacy_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/destruction_preview_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/dragon_area_presentation_suite.gd` | quarantined | needs-design; design-01; Four Fire/Earth cancellation assertions fail against current committed-pattern behavior. This crosses authored counterplay rules; requires a dedicated encounter investigation/approved fixture update, not altered assertions. (output/qa-08/quarantine-check/dragon_area_presentation_test.gd.log) | [FAIL, exit 1](../output/qa-08/quarantine-check/dragon_area_presentation_test.gd.log) (3.572s) |

| `tests/suites/dragon_boss_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/dragon_exchange_presentation_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/dragon_pressure_mechanics_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/dragon_spire_routes_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/ember_hearth_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/ember_reward_feedback_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/en01_enemies_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/en02_enemies_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/en02_enemy_integration_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/en03_enemies_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/en04_enemies_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/en05_enemies_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/en06_enemies_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/encounter_tables_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/enemy_intent_compass_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/enemy_intent_continuity_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/enemy_intent_preview_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/enemy_pathfinding_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/enemy_strike_trail_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/enemy_surface_acceptance_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/enemy_tactical_ai_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/event_rules_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/event_view_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/fix_03_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/floating_combat_text_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/forced_movement_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/frostglass_lancer_cutout_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/glossary_coverage_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/graftwright_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/grave_surgeon_cutout_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/grimoire_search_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/ground_targeting_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/guardian_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/guided_combat_tutorial_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/harrier_cutout_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/health_bar_theme_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/health_ghost_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/illusion_terrain_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/initiative_order_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/inline_icon_description_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/iskaldra_cutout_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/item_pickup_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/lethal_preview_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/lightning_wisp_cutout_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/live_actor_submission_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/magic_deck_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/maneuver_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/map_ui_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/maquette_presentation_surfaces_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/move_attack_approach_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/move_attack_shortcut_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/movement_undo_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/noctyrax_cutout_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/opening_boon_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/original_music_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/player_movement_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/pre_battle_living_foes_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/pre_battle_ui_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/protagonist_cutout_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/protagonist_full_gear_motion_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/protagonist_gear_carry_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/protagonist_gear_motion_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/protagonist_gear_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/protagonist_ranged_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/radiance_package_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/reach_rebalance_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/relic_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/relic_u1_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/relic_u2_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/relic_u3_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/relic_u4_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/relic_u5_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/relic_u6_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/relic_u7_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/relic_u8_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/run_score_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/run_sfx_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/scavenger_shop_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/section_map_regression_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/section_map_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/section_map_v2_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/section_map_v5_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/sfx_bank_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/skill_combat_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/skill_run_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/skill_tree_completion_equivalence_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/skill_tree_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/start_room_map_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/steam_service_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/stone_warden_cutout_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/strike_trail_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/surface_core_review_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/surface_relic_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/terrain_connectivity_equivalence_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/tharokh_cutout_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/threats_at_rest_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/tooltip_consistency_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/turn_clock_activation_selection_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/turn_clock_banner_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/turn_clock_copy_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/turn_clock_hud_review_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/turn_clock_hud_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/turn_clock_wait_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/ui_button_feedback_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/ui_components_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/umbra_action_animation_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/vaeloryx_cutout_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/veilbound_acolyte_cutout_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/vyraketh_cutout_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/suites/zekarion_cutout_suite.gd` | full suite | called by full-suite execution graph | Covered by invoked full-suite entrypoint |

| `tests/surface_analytics_batch_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (5.486s) |

| `tests/surface_core_review_test.gd` | full suite | shared wrapper: tests/suites/surface_core_review_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/surface_core_review_test.gd.log) (1.311s) |

| `tests/surface_feedback_ui_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/surface_feedback_ui_test.gd` | quarantined | needs-design; design-01; Legacy Fire-fuel copy assertion fails and an old dictionary-index expectation errors. Requires current approved surfaces/copy fixtures; no player wording or mechanics changed. (output/qa-08/quarantine-check/surface_feedback_ui_test.gd.log) | [FAIL, exit 1](../output/qa-08/quarantine-check/surface_feedback_ui_test.gd.log) (9.578s) |

| `tests/surface_parent_review_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (4.917s) |

| `tests/surface_preview_equivalence_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (26.641s) |

| `tests/surface_query_handoff_test.gd` | quarantined | stale-reference; qa-09; All three handoff modes differ only in analytics; the test compares an engine result to a scene boundary that stages/acknowledges analytics. Needs current committed-analytics reference reconciliation, retaining exact durable-save assertions. (output/qa-08/quarantine-check/surface_query_handoff_test.gd.log) | [FAIL, exit 1](../output/qa-08/quarantine-check/surface_query_handoff_test.gd.log) (10.910s) |

| `tests/surface_redraw_equivalence_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/surface_relic_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.452s) |

| `tests/surface_save_migration_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.541s) |

| `tests/terrain_destruction_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/text_audit_capture_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/text_rewrite_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/tharokh_cutout_asset_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/tharokh_cutout_gameplay_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/tharokh_cutout_pack_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.641s) |

| `tests/tharokh_cutout_test.gd` | full suite | shared wrapper: tests/suites/tharokh_cutout_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/tharokh_cutout_test.gd.log) (3.800s) |

| `tests/threats_at_rest_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/threats_at_rest_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (17.554s) |

| `tests/tooltip_consistency_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/treasure_opening_reel_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/treasure_presentation_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/turn_clock_copy_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/turn_clock_hud_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/turn_clock_hud_test.gd` | full suite | shared wrapper: tests/suites/turn_clock_hud_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/turn_clock_hud_test.gd.log) (28.822s) |

| `tests/turn_clock_wait_test.gd` | full suite | shared wrapper: tests/suites/turn_clock_wait_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/turn_clock_wait_test.gd.log) (4.961s) |

| `tests/turn_order_animation_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/turn_order_portraits_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/turn_order_projection_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/ui02_pixel_identity_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/ui_button_feedback_test.gd` | full suite | shared wrapper: tests/suites/ui_button_feedback_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/ui_button_feedback_test.gd.log) (1.863s) |

| `tests/ui_components_gallery_fixture_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (0.791s) |

| `tests/ui_components_gallery_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/ui_components_test.gd` | full suite | shared wrapper: tests/suites/ui_components_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/ui_components_test.gd.log) (0.787s) |

| `tests/ui_feedback_sfx_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/ui_hover_sfx_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/ui_material_polish_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/ui_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/ui_skin_performance_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (0.855s) |

| `tests/umbra_action_animation_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/umbra_action_animation_test.gd` | full suite | shared wrapper: tests/suites/umbra_action_animation_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/umbra_action_animation_test.gd.log) (4.009s) |

| `tests/umbra_preview_privacy_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/umbra_visual_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/utility_ui_layout_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/vaeloryx_cutout_asset_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/vaeloryx_cutout_author_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/vaeloryx_cutout_gameplay_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/vaeloryx_cutout_pack_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.606s) |

| `tests/vaeloryx_cutout_test.gd` | full suite | shared wrapper: tests/suites/vaeloryx_cutout_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/vaeloryx_cutout_test.gd.log) (5.362s) |

| `tests/vaeloryx_feedback_asset_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/veilbound_acolyte_cutout_asset_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/veilbound_acolyte_cutout_gameplay_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/veilbound_acolyte_cutout_pack_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.392s) |

| `tests/veilbound_acolyte_cutout_test.gd` | full suite | shared wrapper: tests/suites/veilbound_acolyte_cutout_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/veilbound_acolyte_cutout_test.gd.log) (4.657s) |

| `tests/visible_terrain_shortcut_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/visible_terrain_shortcut_test.gd` | full suite | shared wrapper: tests/suites/move_attack_shortcut_suite.gd::run_visible_terrain, tests/suites/move_attack_shortcut_suite.gd::run_visible_terrain_live | [PASS, exit 0](../output/qa-08/orphans/visible_terrain_shortcut_test.gd.log) (7.268s) |

| `tests/vyraketh_cutout_asset_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/vyraketh_cutout_gameplay_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/vyraketh_cutout_pack_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.719s) |

| `tests/vyraketh_cutout_test.gd` | full suite | shared wrapper: tests/suites/vyraketh_cutout_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/vyraketh_cutout_test.gd.log) (3.701s) |

| `tests/warden_bulwark_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/wave4_icon_identity_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/zekarion_cutout_asset_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/zekarion_cutout_gameplay_probe.gd` | windowed probe | Real-renderer capture/interactive proof; excluded from headless execution. | Not run (native) |

| `tests/zekarion_cutout_pack_test.gd` | full suite | program | [PASS, exit 0](../output/qa-08/integrated-final-idle-3.log) (1.736s) |

| `tests/zekarion_cutout_test.gd` | full suite | shared wrapper: tests/suites/zekarion_cutout_suite.gd::run | [PASS, exit 0](../output/qa-08/orphans/zekarion_cutout_test.gd.log) (3.811s) |
