extends SceneTree

const GameData = preload("res://scripts/game_data.gd")
const AnalyticsStore = preload("res://scripts/analytics_store.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const GrimoireLibrary = preload("res://scripts/grimoire_library.gd")
const ElementalIntensityHudArt = preload("res://scripts/elemental_intensity_hud_art.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const RoomGenerator = preload("res://scripts/room_generator.gd")
const SteamServiceSuite = preload("res://tests/suites/steam_service_suite.gd")
const EnemyPathfindingSuite = preload("res://tests/suites/enemy_pathfinding_suite.gd")
const EmberRewardFeedbackSuite = preload("res://tests/suites/ember_reward_feedback_suite.gd")
const PreBattleUiSuite = preload("res://tests/suites/pre_battle_ui_suite.gd")
const CursorFeedbackSuite = preload("res://tests/suites/cursor_feedback_suite.gd")
const DragonBossSuite = preload("res://tests/suites/dragon_boss_suite.gd")
const TooltipConsistencySuite = preload("res://tests/suites/tooltip_consistency_suite.gd")
const InlineIconDescriptionSuite = preload("res://tests/suites/inline_icon_description_suite.gd")
const SkillTreeSuite = preload("res://tests/suites/skill_tree_suite.gd")
const SkillCombatSuite = preload("res://tests/suites/skill_combat_suite.gd")
const SkillRunSuite = preload("res://tests/suites/skill_run_suite.gd")
const RelicSuite = preload("res://tests/suites/relic_suite.gd")
const RadiancePackageSuite = preload("res://tests/suites/radiance_package_suite.gd")
const ElementalIntensitySuite = preload("res://tests/suites/elemental_intensity_suite.gd")
const BalancePacingSuite = preload("res://tests/suites/balance_pacing_suite.gd")
const LethalPreviewSuite = preload("res://tests/suites/lethal_preview_suite.gd")
const FloatingCombatTextSuite = preload("res://tests/suites/floating_combat_text_suite.gd")
const AttackFxSuite = preload("res://tests/suites/attack_fx_suite.gd")
const AttackSfxSuite = preload("res://tests/suites/attack_sfx_suite.gd")
const CombatObjectiveSuite = preload("res://tests/suites/combat_objective_suite.gd")
const GrimoireSearchSuite = preload("res://tests/suites/grimoire_search_suite.gd")
const MoveAttackShortcutSuite = preload("res://tests/suites/move_attack_shortcut_suite.gd")
const MapUiSuite = preload("res://tests/suites/map_ui_suite.gd")
const CombatBoardLayoutSuite = preload("res://tests/suites/combat_board_layout_suite.gd")
const EnemyIntentCompassSuite = preload("res://tests/suites/enemy_intent_compass_suite.gd")
const HealthBarThemeSuite = preload("res://tests/suites/health_bar_theme_suite.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const SegmentedHealthBar = preload("res://scripts/segmented_health_bar.gd")
const LabyrinthMapView = preload("res://scripts/labyrinth_map_view.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const RunSceneScript = preload("res://scripts/run_scene.gd")
const DialogueEngine = preload("res://scripts/dialogue_engine.gd")
const ElementData = preload("res://scripts/element_data.gd")
const HandFanContainer = preload("res://scripts/hand_fan_container.gd")
const MusicLibrary = preload("res://scripts/music_library.gd")
const PathUtils = preload("res://scripts/path_utils.gd")
const RoomIcons = preload("res://scripts/room_icon_library.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const UiTooltipPanel = preload("res://scripts/ui_tooltip_panel.gd")
const CardWidget = preload("res://scripts/card_widget.gd")
const CardWidgetScript = CardWidget
const ACTION_STEP_TRACKER_PATH: String = "UiLayer/UiRoot/ActionStepTracker"
const ACTION_STEP_CHOICE_PATH: String = "UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/ChoiceBar"
const ACTION_STEP_PILES_PATH: String = "UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/PilesBar"
const MAP_RULE_SCAN_DEPTH: int = 8

var _failures: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://labyrinth_progression_test.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_test.save")
	SettingsStore.set_storage_path("user://labyrinth_settings_test.json")
	SettingsStore.clear_storage()
	AnalyticsStore.set_storage_dir("user://labyrinth_analytics_test")
	AnalyticsStore.clear_storage()
	var default_progression: Dictionary = ProgressionStore.default_data()
	_assert(GameData.cards().size() >= 20, "Card data should load")
	_assert(GameData.enemies().size() >= 5, "Enemy data should load")
	_assert(GameData.npcs().size() >= 1, "NPC data should load")
	_assert(GameData.relics().size() >= 5, "Relic data should load")
	_assert(GameData.equipment().size() >= 5, "Equipment data should load")
	_assert(GameData.upgrades().size() >= 3, "Upgrade data should load")
	SteamServiceSuite.run(Callable(self, "_assert"))
	EnemyPathfindingSuite.run(Callable(self, "_assert"))
	PreBattleUiSuite.run(Callable(self, "_assert"))
	CursorFeedbackSuite.run(Callable(self, "_assert"))
	TooltipConsistencySuite.run(Callable(self, "_assert"))
	InlineIconDescriptionSuite.run(Callable(self, "_assert"))
	DragonBossSuite.run(Callable(self, "_assert"))
	SkillTreeSuite.run(Callable(self, "_assert"))
	SkillCombatSuite.run(Callable(self, "_assert"))
	SkillRunSuite.run(Callable(self, "_assert"))
	RelicSuite.run(Callable(self, "_assert"))
	AttackFxSuite.run(Callable(self, "_assert"))
	AttackSfxSuite.run(Callable(self, "_assert"))
	RadiancePackageSuite.run(Callable(self, "_assert"))
	ElementalIntensitySuite.run(Callable(self, "_assert"))
	BalancePacingSuite.run(Callable(self, "_assert"))
	LethalPreviewSuite.run(Callable(self, "_assert"))
	FloatingCombatTextSuite.run(Callable(self, "_assert"))
	CombatObjectiveSuite.run(Callable(self, "_assert"))
	GrimoireSearchSuite.run(Callable(self, "_assert"))
	MoveAttackShortcutSuite.run(Callable(self, "_assert"))
	MapUiSuite.run(Callable(self, "_assert"))
	CombatBoardLayoutSuite.run(Callable(self, "_assert"))
	EnemyIntentCompassSuite.run(Callable(self, "_assert"))
	HealthBarThemeSuite.run(Callable(self, "_assert"))
	ProgressionStore.set_run_storage_path("user://labyrinth_run_test.save")
	_test_grimoire_data_and_unlocks(default_progression)
	_test_music_library_routes_elemental_combat_tracks()
	_test_ui_skin_button_system()
	_test_relic_data_rarity_and_offer_weights()
	_test_equipment_data_rarity_and_starter_deck()
	_test_room_generation_is_deterministic()
	_test_room_generation_keeps_spawn_reachable()
	_test_room_generation_enemy_spawns_keep_player_halo()
	_test_room_generation_blocks_door_tiles()
	_test_room_generation_uses_perimeter_walls_only()
	_test_room_generation_avoids_adjacent_columns()
	_test_room_generation_uses_stone_floor_with_moss_accents()
	_test_elemental_room_overlays_are_decorative_and_distinct()
	_test_room_generation_populates_elemental_traps()
	_test_room_generation_adds_pickups_and_destructible_terrain()
	_test_special_rooms_use_corner_pillar_layout()
	_test_room_generation_scales_enemy_density()
	_test_element_locked_enemy_spawn_rules()
	_test_boss_room_spawns_zekarion_with_wisps()
	_test_second_sequence_uses_scaled_zekarion_placeholder()
	_test_start_room_spawns_emaciated_man()
	_test_fatigue_draws_cost_health_and_burn_removes_card()
	_test_consumable_item_card_is_destroyed_after_play()
	_test_two_card_turn_draw_flow()
	_test_initiative_order_starts_with_active_player_and_fast_enemies()
	_test_initiative_advances_enemy_turns_until_player_reacts()
	_test_card_time_scale_changes_player_reentry_order()
	_test_legacy_stats_do_not_change_combat_numbers()
	_test_combat_log_is_bounded()
	_test_card_play_action_grants_bonus_play()
	_test_flurry_repeats_and_spends_snapshotted_card_plays()
	_test_starting_deck_uses_hamstring_shot_over_bone_dart()
	_test_equipment_run_state_and_reward_cards(default_progression)
	_test_equipment_collection_to_equip_deck_flow(default_progression)
	_test_missed_equipment_resolution_and_persistence(default_progression)
	_test_merchant_room_placement_and_trading(default_progression)
	_test_elemental_intensity_starts_from_room_element()
	_test_elemental_intensity_actions_gate_effects()
	_test_elemental_intensity_icons_surface_card_requirements()
	_test_elemental_intensity_bonus_modifies_single_attack()
	_test_umbra_curve_tracks_dragon_sections()
	_test_umbra_hides_targets_intents_and_turn_order_identity()
	_test_hidden_enemy_status_steps_do_not_leak_identity_or_tile()
	_test_radiance_actions_reveal_and_reduce_umbra()
	_test_hidden_enemy_movement_collision_does_not_leak_position()
	_test_radiance_cards_and_icons_are_integrated()
	_test_cards_do_not_define_multiple_player_attacks()
	_test_illusion_action_creates_decoy_and_redirects_enemy()
	_test_enemy_target_ties_prefer_illusions_deterministically()
	_test_enemy_death_grants_card_play_and_embers()
	_test_summoned_enemy_death_does_not_grant_card_play()
	_test_cinder_ooze_splits_deterministically()
	_test_cinder_ooze_split_skips_blocked_board()
	_test_cinder_droplet_death_suppresses_rewards()
	_test_cinder_droplet_does_not_resplit()
	_test_hand_draw_caps_at_seven()
	_test_pierce_ignores_defenses()
	_test_bleed_expose_and_sunder_keywords()
	_test_enemy_bleed_intents_apply_and_surface_icons()
	_test_bleed_status_badges_and_trigger_floats()
	_test_enemy_pierce_intents_surface_icons()
	_test_bile_bloomer_poison_and_expose_intents_apply_to_player()
	_test_bile_bloomer_intents_surface_poison_and_expose_icons()
	_test_pierce_cards_stay_in_allowed_elements()
	_test_immobilize_cards_stay_in_allowed_elements()
	_test_healing_cards_are_burned_and_downweighted()
	_test_low_movement_enemies_advance_without_outpacing_crawlers()
	_test_harrier_has_moving_ranged_attack()
	_test_chainbound_gaoler_profile_and_mechanics()
	_test_chainbound_gaoler_intent_icons_and_previews()
	_test_grave_surgeon_data_and_pool_role()
	_test_grave_surgeon_support_actions_scale()
	_test_heal_ally_targets_most_injured_ally()
	_test_heal_ally_falls_back_to_self()
	_test_heal_ally_no_target_noops()
	_test_guard_ally_targets_threatened_ally()
	_test_support_intent_rows_name_target()
	_test_support_intent_target_marker_is_text_only()
	_test_turn_order_uses_explicit_portraits_for_new_enemy_types()
	_test_player_block_absorbs_full_enemy_phase()
	_test_enemy_block_applies_on_actor_turn_only()
	_test_aoe_hits_multiple_targets()
	_test_close_aoe_hits_adjacent_targets()
	_test_player_aoe_damages_incidental_terrain()
	_test_rotated_line_aoe_uses_selected_orientation()
	_test_combat_board_orders_line_aoe_preview_tiles()
	_test_forced_movement_uses_selected_straight_line()
	_test_enemy_phase_preserves_preview_cycle()
	_test_elemental_room_rewards_follow_affinity(default_progression)
	_test_chain_hits_clustered_enemies()
	_test_freeze_and_shock_control_turn_flow()
	_test_immobilize_control_turn_flow()
	_test_traps_trigger_and_apply_current_turn_control()
	_test_traps_roll_control_to_next_turn_when_no_plays_remain()
	_test_move_paths_only_cross_required_traps()
	_test_terrain_blocks_movement_without_blocking_line_of_sight()
	_test_attacking_trap_blasts_adjacent_tiles()
	_test_trap_blasts_damage_incidental_terrain()
	_test_enemy_attacks_profitable_trap_without_self_damage()
	_test_enemy_breaks_blocking_terrain()
	_test_enemy_moves_toward_breakable_chokepoint()
	_test_poison_and_stoneskin_behaviors()
	_test_statuses_tick_on_affected_actor_turn()
	_test_out_of_range_elemental_enemy_attack_skips_step()
	_test_enemy_close_aoe_still_hits_player()
	_test_enemy_aoe_damages_incidental_terrain()
	_test_enemy_aoe_blocker_damages_incidental_terrain()
	_test_frostglass_lancer_line_thrust_preview_and_resolution()
	_test_enemy_threat_tiles_follow_intent()
	_test_run_scene_frostglass_lancer_line_threat_overlay()
	_test_enemy_threat_tiles_assume_player_can_vacate_current_tile()
	_test_enemy_threat_tiles_include_enemy_triggered_trap_blasts()
	_test_large_enemy_threat_tiles_use_footprint()
	_test_lightning_strikes_threat_tiles_are_previewed()
	_test_lightning_strikes_damage_incidental_terrain()
	_test_zekarion_tempest_breath_leaves_corner_safety()
	_test_zekarion_summons_wisps_when_alone()
	_test_summoned_wisps_receive_preview_intents()
	_test_zekarion_ignores_shock_status()
	_test_enemy_pathfinding_avoids_traps()
	_test_enemy_intents_ignore_room_element()
	_test_status_badges_surface_countdowns()
	_test_player_restriction_badges_show_turn_lock()
	_test_air_trap_tooltip_is_damage_only()
	_test_pickup_tooltips_describe_effects()
	_test_terrain_health_bars_are_contextual()
	_test_health_bar_segments_use_fixed_point_scale()
	_test_run_scene_terrain_damage_previews_use_terrain_keys()
	_test_enemy_intent_name_reserves_header_line()
	_test_enemy_intent_contour_expands_on_hover_or_toggle()
	_test_enemy_intent_action_rows_use_readable_scale()
	_test_enemy_intent_shortcut_and_threat_union()
	_test_enemy_intent_contour_chooses_a_shoulder_when_clear()
	_test_enemy_hud_small_top_correction_stays_centered()
	_test_enemy_hud_ignores_subpixel_obstacle_slivers()
	_test_enemy_hud_does_not_duplicate_owning_actor_obstacle()
	_test_enemy_hud_side_offset_clears_only_vertically_overlapping_pieces()
	_test_enemy_hud_layout_offsets_away_from_reserved_ui()
	_test_enemy_intent_contour_stays_anchored_at_top_edge()
	_test_enemy_hud_side_selection_is_stable_during_small_layout_changes()
	_test_combat_board_default_framing_contains_tallest_top_corner_occupant()
	_test_combat_board_refreshes_top_framing_when_tall_occupant_appears_in_cached_room()
	_test_combat_board_refreshes_top_framing_when_scene_prop_appears_in_cached_room()
	_test_boss_intent_layout_needs_no_global_board_banner()
	_test_boss_health_overlay_caps_divider_density()
	_test_turn_order_portraits_cover_enemy_roster()
	_test_enemy_art_scale_preserves_center()
	_test_enemy_art_offset_shifts_sprite_vertically()
	_test_chainbound_gaoler_board_art_is_taller_and_centered()
	_test_enemy_intent_popup_expands_for_long_titles()
	_test_unit_shadow_uses_alpha_silhouette()
	_test_player_uses_original_anime_art()
	_test_combat_board_keeps_equipment_data_off_player_sprite()
	_test_combat_board_surfaces_illusion_units()
	_test_combat_board_surfaces_illusion_preview_units()
	_test_trial_enemy_art_uses_matching_idle_sheets()
	_test_bile_bloomer_art_loads_for_board()
	_test_bile_bloomer_turn_order_portrait_loads()
	_test_zekarion_uses_matching_idle_sheet()
	_test_dragon_idle_redraw_targets_footprint_draw_layer()
	_test_lightning_wisp_uses_normal_loop_idle_sheet()
	_test_cinder_enemies_use_final_raster_art()
	_test_cinder_enemies_have_turn_order_portraits()
	_test_final_art_units_use_16_frame_idle_sheets()
	_test_enemy_death_sheets_load_for_full_roster()
	_test_terrain_destruction_sheets_load_for_full_prop_roster()
	_test_elemental_trap_animation_sheets_load_and_respect_reduced_motion()
	_test_final_art_idle_shadows_keep_silhouettes_for_every_frame()
	_test_emaciated_man_uses_matching_idle_sheet()
	_test_merchant_assets_load_for_board()
	_test_unit_hud_stacks_above_sprite_art()
	_test_combat_board_zooms_to_rendered_room_bounds()
	_test_foreground_props_fade_when_covering_behind_objects()
	_test_pillar_art_fits_bottom_center_without_stretching()
	_test_pillar_torch_fixtures_mount_on_both_visible_faces()
	_test_column_torch_idle_sheets_load_and_are_clean()
	_test_campfire_bonfire_assets_keep_clean_alpha_edges()
	_test_pillar_moss_overlay_is_anchored_to_pillar_cap()
	_test_wall_and_pillar_assets_stay_distinct()
	_test_boundary_prop_art_uses_single_tile_footprint()
	_test_boundary_wall_segments_use_full_spans_on_straight_edges()
	_test_boundary_wall_corner_tiles_split_into_two_half_segments()
	_test_door_art_uses_source_and_flipped_variant()
	_test_standalone_door_art_stays_within_single_tile_footprint()
	_test_visible_doors_use_dedicated_frame()
	_test_door_frames_slide_toward_each_back_edge()
	_test_door_opening_sheet_loads_as_directional_frames()
	_test_combat_board_hides_outer_walls_without_hiding_visible_doors()
	_test_combat_board_assigns_deterministic_floor_variants()
	_test_combat_board_loads_elemental_projectile_atlas()
	_test_combat_board_ambient_particles_follow_room_element()
	_test_combat_board_loads_defense_heal_cast_frames()
	_test_combat_board_draw_order_tracks_moving_unit_world_position()
	_test_run_scene_surfaces_defeated_enemy_death_units()
	_test_run_scene_surfaces_destroyed_terrain_units()
	_test_keyword_icon_library_surfaces_tooltips()
	_test_room_icon_library_covers_door_room_types()
	_test_minimap_uses_door_icons_and_greys_cleared_rooms()
	_test_large_map_decision_layer()
	_test_minimap_travel_animation_state()
	_test_combat_board_loads_door_icons_for_room_types()
	_test_run_map_room_types()
	_test_run_map_two_room_choices_are_like_category_different_type()
	_test_run_map_recovery_marker_keeps_two_room_choices_like_category()
	_test_run_map_relic_room_spacing_and_density()
	_test_run_map_merchant_room_spacing_and_density()
	_test_run_map_repeats_depth_sequences()
	_test_run_map_ring_links_and_outward_quarter()
	_test_run_map_seals_departed_rooms()
	_test_run_map_never_moves_back_toward_center()
	_test_run_map_last_loop_room_opens_outward()
	_test_empty_treasure_room_falls_back_to_room_mode()
	_test_run_engine_campfire_linger_heals_and_continues()
	_test_loaded_run_repairs_stranded_room_visibility()
	_test_combat_finish_generates_reward_state()
	_test_intermediate_boss_opens_next_sequence()
	_test_boss_victory_restores_player_health()
	_test_progression_save_and_purchase(default_progression)
	_test_emaciated_man_does_not_unlock_card_upgrade_dialogue()
	_test_recovery_marker_flow()
	_test_recovery_marker_expires_after_next_run()
	_test_run_state_save_and_load()
	_test_hand_fan_layout_lifts_center_cards()
	_test_default_theme_uses_readable_text_font()
	_test_ui_typography_system()
	await _test_main_scenes_instantiate()
	await EmberRewardFeedbackSuite.run(self, Callable(self, "_assert"))
	await MoveAttackShortcutSuite.run_live(self, Callable(self, "_assert"))
	await MapUiSuite.run_live(self, Callable(self, "_assert"))
	await _test_run_scene_combat_log_prominence()
	await _test_run_scene_minimap_click_opens_large_map()
	await _test_run_scene_pre_battle_preview_intercepts_combat_entry()
	await _test_run_scene_pre_battle_five_enemy_layout_compacts()
	await _test_run_scene_debug_boss_fixture_boots()
	await _test_run_scene_offers_pass_during_combat()
	await _test_run_scene_offers_pass_when_hand_dead()
	await _test_run_scene_pass_preview_chip_updates()
	await _test_run_scene_action_selection_buttons_are_large()
	await _test_run_scene_action_selection_keeps_hand_layout_stable()
	await _test_run_scene_combat_interaction_context_paths()
	await _test_run_scene_idle_hand_refresh_clears_card_fx_ghosts()
	await _test_run_scene_ready_wave_marks_only_playable_hand_cards()
	await _test_run_scene_reward_heal_choice_sits_below_cards()
	await _test_run_scene_reward_acquisition_is_single_choice()
	await _test_run_scene_reward_decision_support_matches_claims()
	await _test_run_scene_selection_prompts_clear_after_pick()
	await _test_run_scene_fatigue_damage_visual_event()
	await _test_run_scene_campfire_choices_use_relic_overlay()
	await _test_run_scene_campfire_choice_press_is_single_shot()
	await _test_run_scene_campfire_bonfire_persists_after_leave()
	await _test_run_scene_optional_followup_attack_stays_playable()
	await _test_run_scene_flurry_utility_resolves_without_attack_target()
	await _test_run_scene_action_step_tracker_states()
	await _test_run_scene_move_attack_shortcut_clicks_enemy()
	await _test_run_scene_aoe_aim_rotates_before_click()
	await _test_run_scene_squall_preserves_orientation()
	await _test_run_scene_push_direction_tiles_filter_closer_tiles()
	await _test_run_scene_block_card_skips_dead_move()
	await _test_run_scene_targetless_card_click_requires_confirmation()
	_test_run_scene_fallback_attack_uses_scaled_damage()
	await _test_run_scene_card_play_meter_spends_before_resolution_rewards()
	await _test_run_scene_damage_display_matches_bonus()
	await _test_run_scene_intensity_condition_rows_mark_activity()
	await _test_card_widget_active_intensity_condition_glows()
	await _test_card_widget_flurry_icon_uses_wide_slot()
	await _test_run_scene_ranged_cards_show_range()
	await _test_run_scene_preview_normalizes_untyped_target_tiles()
	await _test_run_scene_illusion_hover_surfaces_preview_unit()
	await _test_run_scene_move_previews_avoid_traps_when_possible()
	await _test_run_scene_umbra_move_shortcuts_do_not_reveal_hidden_targets()
	await _test_run_scene_umbra_preview_effects_do_not_reveal_hidden_state()
	await _test_run_scene_umbra_aoe_centers_allow_hidden_pattern_occupants()
	await _test_run_scene_hovered_enemy_shows_threat_overlay()
	await _test_run_scene_show_all_enemy_intents_and_threats()
	await _test_run_scene_animation_lock_preserves_board_animation_presentation()
	await _test_run_scene_discard_pile_uses_distinct_icon_controls()
	await _test_run_scene_displays_owned_relic_icons()
	await _test_run_scene_relic_header_keeps_relics_and_intensity_tight()
	await _test_run_scene_attack_impact_presentation_drops_projectile_effect()
	await _test_run_scene_auto_triggers_starting_npc_dialogue()
	await _test_run_scene_character_stats_overlay_opens()
	await _test_run_scene_grimoire_entry_click_keeps_nav_scroll_stable()
	await _test_run_scene_logs_local_analytics()
	await _test_settings_persistence_audio_and_presentation_preferences()
	await _test_main_menu_shows_continue_for_saved_run()

	if _failures.is_empty():
		print("TEST RESULT: PASS")
		quit(0)
		return

	for failure: String in _failures:
		push_error(failure)
	print("TEST RESULT: FAIL (%d failure(s))" % _failures.size())
	quit(1)

func _test_ui_skin_button_system() -> void:
	var skin := UiSkin.new()
	var variants: Array[String] = [
		UiSkin.VARIANT_COMPACT,
		UiSkin.VARIANT_STANDARD,
		UiSkin.VARIANT_LARGE,
		UiSkin.VARIANT_DESTRUCTIVE,
		UiSkin.VARIANT_SELECTED,
		UiSkin.VARIANT_ICON
	]
	var states: Array[String] = [
		UiSkin.STATE_NORMAL,
		UiSkin.STATE_HOVER,
		UiSkin.STATE_PRESSED,
		UiSkin.STATE_DISABLED,
		UiSkin.STATE_SELECTED,
		UiSkin.STATE_FOCUS
	]
	for variant: String in variants:
		for state: String in states:
			var style: StyleBox = skin.make_button_style(variant, state)
			_assert(style is StyleBoxFlat, "%s/%s button state should use scalable code-native StyleBoxFlat construction" % [variant, state])
			if style is StyleBoxFlat and state != UiSkin.STATE_FOCUS:
				var flat := style as StyleBoxFlat
				_assert(is_equal_approx(flat.content_margin_left, flat.content_margin_right), "%s/%s button content should stay mathematically centered" % [variant, state])

	var compact_size: Vector2 = skin.button_native_size(UiSkin.BUTTON_HEIGHT_STANDARD, 0.0, UiSkin.VARIANT_COMPACT)
	var standard_size: Vector2 = skin.button_native_size(UiSkin.BUTTON_HEIGHT_STANDARD, 0.0, UiSkin.VARIANT_STANDARD)
	var large_size: Vector2 = skin.button_native_size(UiSkin.BUTTON_HEIGHT_STANDARD, 0.0, UiSkin.VARIANT_LARGE)
	var icon_size: Vector2 = skin.button_native_size(UiSkin.BUTTON_HEIGHT_STANDARD, 0.0, UiSkin.VARIANT_ICON)
	_assert(compact_size.x < standard_size.x and standard_size.x < large_size.x, "Compact, standard, and large buttons should use distinct native proportions")
	_assert(is_equal_approx(icon_size.x, icon_size.y), "Icon buttons should use a native square proportion")

	var button := Button.new()
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.focus_neighbor_left = NodePath("../PreserveLeft")
	button.focus_neighbor_right = NodePath("../PreserveRight")
	skin.apply_button_stylebox_overrides(button, UiSkin.VARIANT_STANDARD)
	_assert(button.focus_mode == Control.FOCUS_NONE, "Button styling should not change focus eligibility")
	_assert(button.focus_neighbor_left == NodePath("../PreserveLeft") and button.focus_neighbor_right == NodePath("../PreserveRight"), "Button styling should not change controller focus traversal")
	_assert(button.alignment == HORIZONTAL_ALIGNMENT_CENTER, "Themed button labels should default to mathematical centering")
	_assert(button.get_node_or_null(UiSkin.BUTTON_ORNAMENT_NAME) != null, "Themed buttons should include the scalable brass edge ornament")
	_assert(str(button.get_meta("button_variant", "")) == UiSkin.VARIANT_STANDARD, "Themed buttons should expose their applied variant for regression inspection")
	for state_name: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		_assert(button.get_theme_stylebox(state_name) is StyleBoxFlat, "Applied %s button state should remain code-native" % state_name)
	button.free()

	var outer_panel := PanelContainer.new()
	var outer_style := skin.make_plain_card_style(Color("201714"), Color("8f6f46"), 19.0)
	outer_panel.add_theme_stylebox_override("panel", outer_style)
	var preserved_child := Control.new()
	preserved_child.name = "PreservedMenuInternals"
	preserved_child.custom_minimum_size = Vector2(240.0, 160.0)
	outer_panel.add_child(preserved_child)
	var baseline_margins := Vector4(
		outer_style.get_content_margin(SIDE_LEFT),
		outer_style.get_content_margin(SIDE_TOP),
		outer_style.get_content_margin(SIDE_RIGHT),
		outer_style.get_content_margin(SIDE_BOTTOM)
	)
	skin.apply_outer_panel_frame(outer_panel, UiSkin.SURFACE_DIALOG)
	var raster_backing_style: StyleBoxFlat = outer_panel.get_theme_stylebox("panel") as StyleBoxFlat
	_assert(raster_backing_style != null, "Outer-only menu framing should preserve the baseline panel fill")
	if raster_backing_style != null:
		_assert(raster_backing_style.bg_color == outer_style.bg_color, "Outer-only menu framing should preserve the baseline panel fill color")
		_assert(
			Vector4(
				raster_backing_style.get_content_margin(SIDE_LEFT),
				raster_backing_style.get_content_margin(SIDE_TOP),
				raster_backing_style.get_content_margin(SIDE_RIGHT),
				raster_backing_style.get_content_margin(SIDE_BOTTOM)
			) == baseline_margins,
			"Outer-only menu framing should preserve all baseline content margins"
		)
		_assert(
			raster_backing_style.border_width_left == 0
			and raster_backing_style.border_width_top == 0
			and raster_backing_style.border_width_right == 0
			and raster_backing_style.border_width_bottom == 0,
			"Outer-only menu framing should remove the legacy outline behind the raster"
		)
	_assert(preserved_child.get_parent() == outer_panel and preserved_child.custom_minimum_size == Vector2(240.0, 160.0), "Outer-only menu framing should preserve baseline internals")
	_assert(outer_panel.get_node_or_null(UiSkin.PANEL_ORNAMENT_NAME) != null, "Outer-only menu framing should add the authored raster border")
	_assert(
		outer_panel.get_node_or_null("%s/%s" % [UiSkin.PANEL_ORNAMENT_NAME, UiSkin.OUTER_PANEL_RENDERER_NAME]) != null,
		"Outer-only menu framing should isolate its renderer from PanelContainer content layout"
	)
	_assert(bool(outer_panel.get_meta("panel_outer_frame_only", false)), "Outer-only menu framing should stay isolated from full panel restyling")
	outer_panel.free()

func _test_grimoire_data_and_unlocks(default_progression: Dictionary) -> void:
	_assert(GrimoireLibrary.sections().size() == 8, "Grimoire should expose the planned navigation sections")
	var entries: Dictionary = GrimoireLibrary.entry_map()
	for required_id: String in ["basic:run", "combat:turn_clock", "combat:summons", "combat:umbra", "keyword:bleed", "keyword:radiance", "keyword:illuminate", "keyword:vision", "keyword:truesight", "keyword:dispel_umbra", "magick:pale_spark", "magick:spark_dart", "equipment:training_sword", "item:crimson_draught", "character:emaciated_man", "enemy:crawler", "enemy:zekarion"]:
		_assert(entries.has(required_id), "Grimoire should include %s" % required_id)
	_assert(entries.has(GrimoireLibrary.equipment_card_entry_id("lantern_shot")), "Equipment-provided Lantern Shot should have a Grimoire card entry")
	for radiance_card_id: String in ["guiding_flare", "dawnstep", "prism_sight", "storm_beacon", "glowstone_ward", "daybreak"]:
		_assert(entries.has(GrimoireLibrary.magick_entry_id(radiance_card_id)), "Every Radiance Magick should have a Grimoire card entry: %s" % radiance_card_id)
	var defaults: Array[String] = GrimoireLibrary.default_entry_ids()
	_assert(defaults.has("basic:run"), "Grimoire defaults should include run basics")
	_assert(defaults.has("keyword:immobilize"), "Grimoire defaults should include starting-deck keywords")
	_assert(not defaults.has("keyword:bleed"), "Bleed should remain context-unlocked instead of static-default")
	_assert(defaults.has("keyword:flurry"), "Flurry should be documented as a default card mechanic")
	var equipment_card_entries: Array[String] = GrimoireLibrary.entry_ids_for_card_id("sawtooth_flurry")
	_assert(not equipment_card_entries.has("magick:sawtooth_flurry"), "Equipment-derived cards should not unlock Magick entries")
	_assert(equipment_card_entries.has("keyword:bleed"), "Cards with bleed should unlock the bleed entry")
	var spark_card_entries: Array[String] = GrimoireLibrary.entry_ids_for_card_id("spark_dart")
	_assert(spark_card_entries.has("magick:spark_dart"), "Elemental reward cards should unlock their Magick entry")
	_assert(spark_card_entries.has("combat:intensity"), "Cards with intensity should unlock the intensity entry")
	_assert(spark_card_entries.has("keyword:radiance") and spark_card_entries.has("keyword:illuminate"), "Radiance riders should unlock their school and Light action entries")
	var static_card_entries: Array[String] = GrimoireLibrary.entry_ids_for_card_id("static_lash")
	_assert(static_card_entries.has("keyword:shock"), "Nested intensity bonus effects should unlock their keyword entry")
	var lantern_entries: Array[String] = GrimoireLibrary.entry_ids_for_card_id("lantern_shot")
	_assert(lantern_entries.has("equipment_card:lantern_shot"), "Starter Lantern Shot should unlock its equipment-provenance card entry")
	_assert(not lantern_entries.has("magick:lantern_shot"), "Equipment-provided Lantern Shot should not be misclassified as a Magick")
	_assert(lantern_entries.has("keyword:radiance") and lantern_entries.has("keyword:illuminate"), "Radiance cards should unlock their school and printed light effects")
	_assert(GrimoireLibrary.entry_ids_for_card_id("dawnstep").has("keyword:vision"), "Dawnstep should unlock Vision")
	_assert(GrimoireLibrary.entry_ids_for_card_id("prism_sight").has("keyword:truesight"), "Prism Sight should unlock Truesight")
	_assert(GrimoireLibrary.entry_ids_for_card_id("daybreak").has("keyword:dispel_umbra"), "Daybreak should unlock Dispel Umbra")
	_assert(GrimoireLibrary.entry_ids_for_card_id("cinder_fusillade").has("keyword:flurry"), "Flurry cards should unlock the Flurry grimoire entry")
	var item_card_entries: Array[String] = GrimoireLibrary.entry_ids_for_card_id("crimson_draught")
	_assert(item_card_entries.has("item:crimson_draught"), "Scavenger consumables should unlock item entries")
	var equipment_entries: Array[String] = GrimoireLibrary.entry_ids_for_equipment_id("sawtooth_knife")
	_assert(equipment_entries.has("equipment:sawtooth_knife"), "Discovered equipment should unlock its equipment entry")
	_assert(equipment_entries.has("keyword:bleed"), "Equipment should unlock keywords from granted cards")
	var lantern_equipment_entries: Array[String] = GrimoireLibrary.entry_ids_for_equipment_id("cracked_lantern")
	_assert(lantern_equipment_entries.has("equipment_card:lantern_shot"), "Cracked Lantern should unlock its Radiance card page under Equipment")
	var npc_entries: Array[String] = GrimoireLibrary.entry_ids_for_npc_ids(["blacksmith"])
	_assert(npc_entries.has("character:blacksmith"), "Seen NPCs should unlock character entries")
	var crawler_entries: Array[String] = GrimoireLibrary.entry_ids_for_enemy_types(["crawler"])
	_assert(crawler_entries.has("enemy:crawler"), "Seeing a crawler should unlock its creature entry")
	_assert(crawler_entries.has("keyword:bleed"), "Enemy bleed intents should unlock the bleed entry")
	var zekarion_entries: Array[String] = GrimoireLibrary.entry_ids_for_enemy_types(["zekarion"])
	_assert(zekarion_entries.has("combat:lightning_strikes"), "Zekarion lightning strikes should unlock a mechanic entry")
	_assert(zekarion_entries.has("combat:summons"), "Zekarion summons should unlock a mechanic entry")
	_assert(zekarion_entries.has("enemy:lightning_wisp"), "Summon intents should unlock their minion creature entry")
	var combat_loot_entries: Array[String] = GrimoireLibrary.entry_ids_for_combat_state({
		"loot": [{"kind": "equipment", "equipment_id": "ward_kite", "pos": Vector2i(3, 3)}],
		"collected_equipment": ["iron_cleaver"]
	})
	_assert(not combat_loot_entries.has("equipment:ward_kite"), "Unclaimed combat equipment should not unlock equipment entries before pickup")
	_assert(combat_loot_entries.has("equipment:iron_cleaver"), "Combat-state collected equipment should unlock equipment entries before run sync")
	_assert(not GrimoireLibrary.entry_ids_for_combat_state({"umbra": {"stage": "clear"}}).has("combat:umbra"), "Clear rooms should not discover the Umbra entry before the mechanic appears")
	_assert(GrimoireLibrary.entry_ids_for_combat_state({"umbra": {"stage": "fringe"}}).has("combat:umbra"), "The first shadowed room should discover the Umbra entry")
	var engine := RunEngine.new()
	var run_state: Dictionary = engine.create_new_run(24680, default_progression)
	_assert((run_state.get(GrimoireLibrary.UNLOCKED_KEY, []) as Array).has("basic:run"), "New runs should carry default Grimoire entries")
	_assert((run_state.get(GrimoireLibrary.UNLOCKED_KEY, []) as Array).has("magick:pale_spark"), "New runs should know starting Magick entries")
	_assert((run_state.get(GrimoireLibrary.UNLOCKED_KEY, []) as Array).has("equipment:training_sword"), "New runs should know starter equipment entries")
	_assert((run_state.get(GrimoireLibrary.UNLOCKED_KEY, []) as Array).has("character:emaciated_man"), "New runs should know the starting NPC entry")
	_assert(not (run_state.get(GrimoireLibrary.UNLOCKED_KEY, []) as Array).has("keyword:bleed"), "New runs should not know Bleed before a visible or owned source has Bleed")
	_assert((run_state.get(GrimoireLibrary.UNREAD_KEY, []) as Array).is_empty(), "Default Grimoire entries should not start unread")
	var run_with_visible_loot: Dictionary = run_state.duplicate(true)
	run_with_visible_loot["combat_state"] = {"loot": [{"kind": "equipment", "equipment_id": "ward_kite", "pos": Vector2i(3, 3)}]}
	var run_visible_loot_entries: Array[String] = GrimoireLibrary.entry_ids_for_run_state(run_with_visible_loot)
	_assert(not run_visible_loot_entries.has("equipment:ward_kite"), "Run-state unclaimed combat loot should not unlock equipment entries")
	var reward_offer_state: Dictionary = run_state.duplicate(true)
	reward_offer_state["pending_reward"] = {"cards": ["spark_dart"]}
	var reward_offer_entries: Array[String] = GrimoireLibrary.entry_ids_for_run_state(reward_offer_state)
	_assert(reward_offer_entries.has("magick:spark_dart"), "Visible reward-offer cards should unlock their Magick entry before selection")
	_assert(reward_offer_entries.has("keyword:illuminate"), "Visible reward-offer cards should unlock their Radiance rider before selection")
	var merchant_offer_state: Dictionary = run_state.duplicate(true)
	merchant_offer_state["current_room"] = Vector2i(2, 1)
	merchant_offer_state["rooms"] = {
		"2,1": {
			"type": "arcanist",
			"merchant_kind": "arcanist",
			"merchant_stock": ["spark_dart", "crimson_draught", "iron_cleaver"],
			"npcs": [{"id": "blacksmith"}]
		}
	}
	var merchant_offer_entries: Array[String] = GrimoireLibrary.entry_ids_for_run_state(merchant_offer_state)
	_assert(merchant_offer_entries.has("magick:spark_dart"), "Visible merchant-offer cards should unlock their Magick entry before purchase")
	_assert(merchant_offer_entries.has("item:crimson_draught"), "Visible scavenger-offer cards should unlock item entries before purchase")
	_assert(merchant_offer_entries.has("equipment:iron_cleaver"), "Visible blacksmith-offer equipment should unlock equipment entries before purchase")
	_assert(merchant_offer_entries.has("character:blacksmith"), "Current-room NPCs should unlock character entries")
	_assert(merchant_offer_entries.has("keyword:illuminate"), "Visible merchant-offer cards should unlock their Radiance rider before purchase")
	var unlock_result: Dictionary = GrimoireLibrary.unlock_entries(run_state, ["magick:spark_dart", "keyword:shock"])
	var added: Array = unlock_result.get("added", [])
	var next_state: Dictionary = unlock_result.get("state", {}) as Dictionary
	_assert(added.size() == 2 and added.has("magick:spark_dart") and added.has("keyword:shock"), "First Magick discovery should report the card and keyword entries")
	_assert(str(next_state.get(GrimoireLibrary.NOTICE_KEY, "")).contains("2 entries"), "Multi-entry Grimoire discovery should create a readable log notice")
	var profile_after_unlock: Dictionary = next_state.get("progression", {}) as Dictionary
	_assert((profile_after_unlock.get(GrimoireLibrary.UNLOCKED_KEY, []) as Array).has("magick:spark_dart"), "Discovered entries should persist into progression data")
	_assert((profile_after_unlock.get(GrimoireLibrary.UNREAD_KEY, []) as Array).has("magick:spark_dart"), "Unread Grimoire discoveries should persist in progression data")
	var later_run_state: Dictionary = engine.create_new_run(24681, profile_after_unlock)
	_assert((later_run_state.get(GrimoireLibrary.UNLOCKED_KEY, []) as Array).has("magick:spark_dart"), "Later runs should inherit persistent Grimoire entries")
	var cleared_unread: Dictionary = GrimoireLibrary.clear_unread(next_state)
	_assert((cleared_unread.get(GrimoireLibrary.UNREAD_KEY, []) as Array).is_empty(), "Clearing Grimoire unread should clear run unread entries")
	_assert(((cleared_unread.get("progression", {}) as Dictionary).get(GrimoireLibrary.UNREAD_KEY, []) as Array).is_empty(), "Clearing Grimoire unread should clear persistent unread entries")
	var repeated: Dictionary = GrimoireLibrary.unlock_entries(next_state, ["keyword:shock"])
	_assert((repeated.get("added", []) as Array).is_empty(), "Repeated Grimoire discoveries should not add duplicates")

func _test_music_library_routes_elemental_combat_tracks() -> void:
	var expected_tracks: Dictionary = {
		ElementData.FIRE: MusicLibrary.FIRE_COMBAT_TRACK_ID,
		ElementData.ICE: MusicLibrary.ICE_COMBAT_TRACK_ID,
		ElementData.LIGHTNING: MusicLibrary.LIGHTNING_COMBAT_TRACK_ID,
		ElementData.AIR: MusicLibrary.AIR_COMBAT_TRACK_ID,
		ElementData.EARTH: MusicLibrary.EARTH_COMBAT_TRACK_ID
	}
	for element_id_var: Variant in expected_tracks.keys():
		var element_id: String = str(element_id_var)
		var entry: Dictionary = MusicLibrary.entry_for_context("combat", {
			"type": "combat",
			"element": element_id
		})
		var expected_track_id: String = str(expected_tracks.get(element_id, ""))
		var path: String = str(entry.get("path", ""))
		_assert(str(entry.get("id", "")) == expected_track_id, "%s combat rooms should use their element music track" % ElementData.name(element_id))
		_assert(FileAccess.file_exists(path), "%s music asset should exist" % expected_track_id)
		_assert(_audio_asset_loads(path), "%s music asset should load as audio" % expected_track_id)
	var room_entry: Dictionary = MusicLibrary.entry_for_context("room", {
		"type": "combat",
		"element": ElementData.FIRE
	})
	_assert(str(room_entry.get("id", "")) == MusicLibrary.FIRE_COMBAT_TRACK_ID, "Uncleared elemental combat rooms should use their element music outside combat mode")
	var cleared_entry: Dictionary = MusicLibrary.entry_for_context("room", {
		"type": "combat",
		"element": ElementData.FIRE,
		"cleared": true
	})
	_assert(str(cleared_entry.get("id", "")) == MusicLibrary.RELIC_ROOM_TRACK_ID, "Cleared combat rooms should still switch to the post-combat room music")
	var generic_entry: Dictionary = MusicLibrary.entry_for_context("combat", {
		"type": "combat",
		"element": ElementData.NONE
	})
	_assert(str(generic_entry.get("id", "")) == MusicLibrary.GENERIC_COMBAT_TRACK_ID, "Neutral combat should keep the generic combat music fallback")
	var boss_entry: Dictionary = MusicLibrary.entry_for_context("combat", {
		"type": "boss",
		"element": ElementData.LIGHTNING,
		"boss_id": "zekarion"
	})
	_assert(str(boss_entry.get("id", "")) == MusicLibrary.ZEKARION_BOSS_TRACK_ID, "Zekarion should keep boss music over elemental music")
	var generic_boss_entry: Dictionary = MusicLibrary.entry_for_context("combat", {
		"type": "boss",
		"element": ElementData.LIGHTNING
	})
	_assert(str(generic_boss_entry.get("id", "")) == MusicLibrary.GENERIC_COMBAT_TRACK_ID, "Boss fallback should not use non-boss elemental combat music")
	for merchant_type: String in ["blacksmith", "arcanist", "scavenger"]:
		var merchant_entry: Dictionary = MusicLibrary.entry_for_context("room", {
			"type": merchant_type,
			"element": ElementData.NONE
		})
		_assert(str(merchant_entry.get("id", "")) == MusicLibrary.RELIC_ROOM_TRACK_ID, "%s rooms should use non-combat room music" % merchant_type.capitalize())

func _audio_asset_loads(path: String) -> bool:
	if path.get_extension().to_lower() == "wav":
		return AudioStreamWAV.load_from_file(path) != null
	return load(path) is AudioStream

func _test_relic_data_rarity_and_offer_weights() -> void:
	var valid_rarities: Dictionary = {
		"common": true,
		"rare": true,
		"epic": true,
		"legendary": true
	}
	_assert(GameData.relics().size() >= 20, "Relic pool should have enough breadth for build choices")
	for relic_id: String in GameData.relic_ids():
		var relic: Dictionary = GameData.relic_def(relic_id)
		var rarity: String = str(relic.get("rarity", ""))
		_assert(valid_rarities.has(rarity), "%s should use the relic rarity set" % relic_id)
		_assert(str(relic.get("accent", "")) == GameData.relic_rarity_accent(rarity), "%s border accent should match relic rarity" % relic_id)
		_assert(not (relic.get("effects", []) as Array).is_empty(), "%s should define reusable relic effects" % relic_id)
		var description: String = str(relic.get("description", ""))
		_assert(not description.contains("{") and not description.contains("}"), "%s description placeholders should be formatted for display" % relic_id)
		var icon_path: String = str(relic.get("icon_path", ""))
		_assert(FileAccess.file_exists(icon_path), "%s relic icon should exist" % relic_id)
	_assert(str(GameData.relic_def("thornmail_brooch").get("description", "")).contains("half that much"), "Thornmail Brooch should explain its conditional stoneskin scaling")
	_assert(str(GameData.relic_def("obsidian_heart").get("description", "")).contains("all remaining @icon(block)"), "Obsidian Heart should explain its end-of-turn block conversion")
	_assert(str(GameData.relic_def("obsidian_heart").get("description", "")).contains("Opening @icon(draw) -1"), "Obsidian Heart should format its negative opening draw through the draw icon")
	_assert(str(GameData.relic_def("black_sun_dial").get("description", "")).contains("deal 12"), "Black Sun Dial should display its legendary all-enemy payoff")
	_assert(GameData.relic_offer_weight("iron_lung") > GameData.relic_offer_weight("ember_lens"), "Common relics should be offered more often than rare relics")
	_assert(GameData.relic_offer_weight("ember_lens") > GameData.relic_offer_weight("bloodglass_knife"), "Rare relics should be offered more often than epic relics")
	_assert(GameData.relic_offer_weight("bloodglass_knife") > GameData.relic_offer_weight("storm_crown"), "Epic relics should be offered more often than legendary relics")

func _test_equipment_data_rarity_and_starter_deck() -> void:
	var valid_rarities: Dictionary = {
		"common": true,
		"rare": true,
		"epic": true,
		"legendary": true
	}
	var slot_counts: Dictionary = {}
	for slot: String in GameData.equipment_slots():
		slot_counts[slot] = 0
	var starter_ids: Array = GameData.starter_equipment_ids()
	_assert(starter_ids.size() == GameData.equipment_slots().size(), "Starter equipment should fill every equipment slot")
	_assert(GameData.equipment().size() >= 20, "Equipment pool should have enough breadth for room drops")
	for equipment_id_var: Variant in GameData.equipment_ids():
		var equipment_id: String = str(equipment_id_var)
		var item: Dictionary = GameData.equipment_def(equipment_id)
		var slot: String = str(item.get("slot", ""))
		var rarity: String = str(item.get("rarity", ""))
		_assert(GameData.equipment_slots().has(slot), "%s should use a valid equipment slot" % equipment_id)
		slot_counts[slot] = int(slot_counts.get(slot, 0)) + 1
		_assert(valid_rarities.has(rarity), "%s should use the relic rarity set" % equipment_id)
		_assert(str(item.get("accent", "")) == GameData.equipment_rarity_accent(rarity), "%s border accent should match equipment rarity" % equipment_id)
		var icon_path: String = str(item.get("icon_path", ""))
		_assert(FileAccess.file_exists(icon_path), "%s equipment icon should exist" % equipment_id)
		var icon_image := Image.new()
		var icon_load_error: Error = icon_image.load(icon_path)
		_assert(icon_load_error == OK and icon_image.get_width() == 96 and icon_image.get_height() == 96, "%s equipment icon should be a 96x96 project asset" % equipment_id)
		var card_ids: Array = GameData.equipment_cards(equipment_id)
		_assert(not card_ids.is_empty(), "%s should contribute at least one card" % equipment_id)
		for card_id_var: Variant in card_ids:
			var card_id: String = str(card_id_var)
			_assert(not GameData.card_def(card_id).is_empty(), "%s should reference an existing card" % equipment_id)
		if bool(item.get("starter", false)):
			_assert(starter_ids.has(equipment_id), "%s should be registered as a starter equipment item" % equipment_id)
			_assert(icon_path.begins_with("res://assets/art/equipment/"), "%s starter equipment should use custom equipment art, not reused relic art" % equipment_id)
	for slot: String in GameData.equipment_slots():
		_assert(int(slot_counts.get(slot, 0)) >= 3, "%s slot should have multiple equipment options" % slot.capitalize())
	_assert(GameData.equipment_cards("windlass_repeater") == ["windlass_volley", "crank_reload", "far_draw"], "Windlass Repeater should package a Flurry payoff with draw/play setup")
	_assert(GameData.equipment_cards("war_dancer_sash") == ["blade_dance", "gathering_rhythm"], "War-Dancer Sash should package a melee Flurry payoff with rhythm setup")
	var rhythm_actions: Array = GameData.card_def("gathering_rhythm").get("actions", [])
	_assert(rhythm_actions.size() == 3 and int((rhythm_actions[2] as Dictionary).get("amount", 0)) == 2, "Gathering Rhythm should grant 2 card plays for a larger Flurry setup turn")
	for reward_card_id: String in ["cinder_fusillade", "storm_salvo", "razor_gale"]:
		_assert(bool(GameData.card_def(reward_card_id).get("flurry", false)), "%s should use the Flurry mechanic" % reward_card_id)
		_assert(bool(GameData.card_def(reward_card_id).get("reward_pool", true)), "%s should enter the collectible spell pool" % reward_card_id)
	for new_card_id: String in ["windlass_volley", "crank_reload", "blade_dance", "gathering_rhythm", "cinder_fusillade", "storm_salvo", "razor_gale"]:
		var art_path: String = str(GameData.card_def(new_card_id).get("art_path", ""))
		var art_image := Image.new()
		var art_error: Error = art_image.load(art_path)
		_assert(art_error == OK and art_image.get_width() == 256 and art_image.get_height() == 144, "%s should ship generated 256x144 card art" % new_card_id)
	var equipped: Dictionary = GameData.starting_equipped_equipment()
	for slot: String in GameData.equipment_slots():
		_assert(not str(equipped.get(slot, "")).is_empty(), "Starting equipment should define %s" % slot)
	var starter_equipment_deck: Array = GameData.compile_deck_cards(equipped, [])
	_assert(starter_equipment_deck.size() == 10, "Starter equipment should still compile to ten gear cards")
	for card_id: String in [
		"quick_stab",
		"guarded_step",
		"shadow_step",
		"hamstring_shot",
		"sidestep_slash",
		"whirlwind_slash",
		"patch_up",
		"bloody_lunge",
		"brace",
		"lantern_shot"
	]:
		_assert(starter_equipment_deck.has(card_id), "Starter equipment should preserve %s in the gear deck" % card_id)
	_assert(GameData.magic_loadout_limit() == 6, "Magic loadout should currently cap at six attuned cards")
	var starting_deck: Array = GameData.starting_deck()
	_assert(starting_deck.size() == starter_equipment_deck.size() + GameData.magic_loadout_limit(), "Full starting deck should add six default magic cards to starter equipment")
	for card_id_var: Variant in GameData.starting_magic_cards():
		_assert(starting_deck.has(str(card_id_var)), "Full starting deck should include default magic card %s" % str(card_id_var))

func _test_room_generation_is_deterministic() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	var room_meta: Dictionary = {
		"coord": Vector2i(1, 0),
		"depth": 1,
		"type": "combat"
	}
	var a: Dictionary = generator.generate_room(17, room_meta, Vector2i(1, 0))
	var b: Dictionary = generator.generate_room(17, room_meta, Vector2i(1, 0))
	_assert(a.get("grid", []) == b.get("grid", []), "Room generation should be deterministic for identical inputs")
	_assert(a.get("player_start", Vector2i(-1, -1)) == b.get("player_start", Vector2i.ZERO), "Player spawn should be deterministic")
	_assert(a.get("enemies", []) == b.get("enemies", []), "Enemy spawn pattern should be deterministic")

func _test_room_generation_keeps_spawn_reachable() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	var room_meta: Dictionary = {
		"coord": Vector2i(2, 1),
		"depth": 3,
		"type": "combat"
	}
	var room: Dictionary = generator.generate_room(99, room_meta, Vector2i(0, -1))
	var grid: Array = room.get("grid", [])
	var spawn: Vector2i = room.get("player_start", Vector2i.ZERO)
	var reachable: Array[Vector2i] = PathUtils.reachable_tiles(grid, spawn, 20, {})
	_assert(reachable.size() >= 14, "Generated rooms should leave a broad reachable footprint from the entry tile")

func _test_room_generation_enemy_spawns_keep_player_halo() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	var sampled_close_spawn: bool = false
	for seed: int in range(40, 70):
		var room: Dictionary = generator.generate_room(seed, {
			"coord": Vector2i(seed % 4, seed % 5),
			"depth": 3,
			"type": "combat"
		}, Vector2i(1, 0))
		var player_start: Vector2i = room.get("player_start", Vector2i.ZERO)
		for enemy_var: Variant in room.get("enemies", []):
			if typeof(enemy_var) != TYPE_DICTIONARY:
				continue
			var enemy: Dictionary = enemy_var
			var distance: int = PathUtils.manhattan(enemy.get("pos", Vector2i(-1, -1)), player_start)
			_assert(distance > RoomGenerator.ENEMY_SPAWN_SAFE_RADIUS, "Enemy spawns should keep the player entry halo clear")
			if distance <= RoomGenerator.ENEMY_SPAWN_SAFE_RADIUS + 2:
				sampled_close_spawn = true
	_assert(sampled_close_spawn, "Enemy spawns should sometimes land near the halo instead of always favoring the far side")

func _test_room_generation_blocks_door_tiles() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	var room_meta: Dictionary = {
		"coord": Vector2i(1, 2),
		"depth": 2,
		"type": "combat",
		"connections": [
			{"door_dir": Vector2i(0, -1), "coord": Vector2i(1, 1)},
			{"door_dir": Vector2i(1, 0), "coord": Vector2i(2, 2)},
			{"door_dir": Vector2i(0, 1), "coord": Vector2i(1, 3)},
			{"door_dir": Vector2i(-1, 0), "coord": Vector2i(0, 2)}
		]
	}
	var room: Dictionary = generator.generate_room(123, room_meta, Vector2i.ZERO)
	var grid: Array = room.get("grid", [])
	var spawn: Vector2i = room.get("player_start", Vector2i.ZERO)
	var reachable: Array[Vector2i] = PathUtils.reachable_tiles(grid, spawn, 20, {})
	var door_tiles: Array[Vector2i] = [
		RoomGenerator.door_tile_for_direction(Vector2i(0, -1)),
		RoomGenerator.door_tile_for_direction(Vector2i(1, 0)),
		RoomGenerator.door_tile_for_direction(Vector2i(0, 1)),
		RoomGenerator.door_tile_for_direction(Vector2i(-1, 0))
	]
	for door_tile: Vector2i in door_tiles:
		_assert(str(grid[door_tile.y][door_tile.x]) == "door", "Connected rooms should stamp door tiles onto the board edge")
		_assert(not PathUtils.is_passable(grid, door_tile), "Door tiles should be impassable terrain")
		_assert(not reachable.has(door_tile), "Door tiles should not appear in reachable movement ranges")
	for enemy_var: Variant in room.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var
		_assert(not door_tiles.has(enemy.get("pos", Vector2i(-1, -1))), "Enemy spawns should avoid door tiles")

func _test_hand_fan_layout_lifts_center_cards() -> void:
	var card_size := Vector2(210.0, 300.0)
	var authored_overlap: float = HandFanContainer.overlap_gap_for_card_width(card_size.x)
	_assert(is_equal_approx(-authored_overlap / card_size.x, 0.20), "The authored combat fan should overlap adjacent cards by 20% of card width")
	var five_card_overlap_ratio: float = HandFanContainer.overlap_ratio_for_hand_size(5)
	var six_card_overlap_ratio: float = HandFanContainer.overlap_ratio_for_hand_size(6)
	var seven_card_overlap_ratio: float = HandFanContainer.overlap_ratio_for_hand_size(7)
	_assert(is_equal_approx(five_card_overlap_ratio, HandFanContainer.DEFAULT_CARD_OVERLAP_RATIO), "A normal five-card hand should preserve the authored overlap")
	_assert(six_card_overlap_ratio > five_card_overlap_ratio and seven_card_overlap_ratio > six_card_overlap_ratio, "Hand-card overlap should increase progressively as hands grow")
	_assert(seven_card_overlap_ratio <= HandFanContainer.MAX_CARD_OVERLAP_RATIO, "Dense hands should retain a capped readable overlap")
	var seven_card_dense_gap: float = HandFanContainer.overlap_gap_for_card_width(card_size.x, seven_card_overlap_ratio)
	var seven_card_default_width: float = HandFanContainer.content_size_for_layout(7, card_size, authored_overlap, true).x
	var seven_card_dense_width: float = HandFanContainer.content_size_for_layout(7, card_size, seven_card_dense_gap, true).x
	_assert(seven_card_dense_width < seven_card_default_width - 100.0, "A seven-card hand should compress materially through overlap instead of shrinking card readability")
	_assert(card_size.x + seven_card_dense_gap >= HandFanContainer.DEFAULT_MIN_EXPOSED_CARD_WIDTH, "Dense hands should preserve a clickable exposed strip on every covered card")
	var left_rect: Rect2 = HandFanContainer.card_rect_for_layout(0, 5, card_size, -28.0, true)
	var center_rect: Rect2 = HandFanContainer.card_rect_for_layout(2, 5, card_size, -28.0, true)
	var right_rect: Rect2 = HandFanContainer.card_rect_for_layout(4, 5, card_size, -28.0, true)
	var content_size: Vector2 = HandFanContainer.content_size_for_layout(5, card_size, -28.0, true)
	_assert(center_rect.position.y < left_rect.position.y, "Hand fan should lift center cards above the edges")
	_assert(left_rect.position.y - center_rect.position.y <= HandFanContainer.DEFAULT_ARCH_HEIGHT + 0.01, "Hand fan should keep its idle vertical stagger within the subtle shared arch")
	_assert(is_equal_approx(left_rect.position.y, right_rect.position.y), "Hand fan should mirror edge lift on both sides")
	_assert(HandFanContainer.card_rotation_for_layout(0, 5, true) < 0.0, "Hand fan should tilt left-side cards outward")
	_assert(HandFanContainer.card_rotation_for_layout(4, 5, true) > 0.0, "Hand fan should tilt right-side cards outward")
	_assert(absf(rad_to_deg(HandFanContainer.card_rotation_for_layout(0, 5, true))) <= 3.01 and absf(rad_to_deg(HandFanContainer.card_rotation_for_layout(4, 5, true))) <= 3.01, "Hand fan idle rotation should remain barely noticeable")
	_assert(content_size.y < right_rect.end.y, "Hand fan should reserve a little less than the full arch height so the outer cards can sink slightly offscreen")
	_assert(right_rect.end.y - content_size.y <= 8.0, "Hand fan should not let outer cards sink far enough to clip their bottom frames")
	_assert(HandFanContainer.card_z_index_for_layout(0, 5) < HandFanContainer.card_z_index_for_layout(4, 5), "Hand fan should stack cards left-to-right so the rightmost card stays uncovered")
	var focused_left: Rect2 = HandFanContainer.emphasized_card_rect_for_layout(1, 5, card_size, -28.0, true, 2, 1.0)
	var focused_center: Rect2 = HandFanContainer.emphasized_card_rect_for_layout(2, 5, card_size, -28.0, true, 2, 1.0)
	var focused_right: Rect2 = HandFanContainer.emphasized_card_rect_for_layout(3, 5, card_size, -28.0, true, 2, 1.0)
	var focused_scale: float = HandFanContainer.card_scale_for_emphasized_layout(2, 2, 1.0)
	var focused_visual_rect := Rect2(
		focused_center.position - focused_center.size * (focused_scale - 1.0) * 0.5,
		focused_center.size * focused_scale
	)
	_assert(focused_scale >= 1.27, "Focused hand cards should become substantially larger than their idle card")
	_assert(focused_visual_rect.position.y < center_rect.position.y - 85.0, "Focused hand cards should rise enough for their rules to read clearly")
	_assert(is_equal_approx(focused_visual_rect.end.y, center_rect.end.y - HandFanContainer.DEFAULT_EMPHASIS_EXTRA_LIFT), "Focused hand cards should grow upward and add a slight full-card lift")
	_assert(focused_left.position.x < HandFanContainer.card_rect_for_layout(1, 5, card_size, -28.0, true).position.x, "Cards left of focus should move away from the focused card")
	_assert(focused_right.position.x > HandFanContainer.card_rect_for_layout(3, 5, card_size, -28.0, true).position.x, "Cards right of focus should move away from the focused card")
	_assert(focused_left.end.x - focused_visual_rect.position.x <= HandFanContainer.DEFAULT_EMPHASIS_REMAINING_OVERLAP + 0.01, "Focused cards should leave only a narrow overlap over their left neighbor")
	_assert(focused_visual_rect.end.x - focused_right.position.x <= HandFanContainer.DEFAULT_EMPHASIS_REMAINING_OVERLAP + 0.01, "Focused cards should leave only a narrow overlap over their right neighbor")
	_assert(is_zero_approx(HandFanContainer.card_rotation_for_emphasized_layout(2, 5, true, 2, 1.0)), "Focused hand cards should settle upright for reading")
	_assert(HandFanContainer.card_z_index_for_emphasized_layout(2, 5, 2, 1.0) > HandFanContainer.card_z_index_for_layout(4, 5), "Focused hand cards should render above the complete hand")
	var compact_available_width: float = 650.0
	var compact_gap: float = HandFanContainer.card_gap_for_available_width(5, card_size, -28.0, compact_available_width)
	var compact_content: Vector2 = HandFanContainer.content_size_for_layout(5, card_size, compact_gap, true)
	_assert(compact_gap < -28.0, "Constrained hands should overlap idle cards more tightly so every card remains reachable")
	_assert(compact_content.x + HandFanContainer.DEFAULT_EMPHASIS_MAX_SIDE_SHIFT * 2.0 <= compact_available_width + 0.01, "Constrained hands should reserve enough width for both sides to move away from focus")
	_assert(card_size.x + compact_gap >= HandFanContainer.DEFAULT_MIN_EXPOSED_CARD_WIDTH, "Responsive overlap should preserve a visible selection strip for every idle card")
	_assert(is_equal_approx(HandFanContainer.card_gap_for_available_width(5, card_size, -28.0, 1400.0), -28.0), "Spacious hands should preserve the authored fan overlap")

func _test_room_generation_uses_perimeter_walls_only() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	for seed: int in [7, 19, 43, 71, 97, 131]:
		var room: Dictionary = generator.generate_room(seed, {
			"coord": Vector2i(seed % 5, seed % 3),
			"depth": 2,
			"type": "combat"
		}, Vector2i.ZERO)
		var grid: Array = room.get("grid", [])
		for y: int in range(1, grid.size() - 1):
			var row: Array = grid[y]
			for x: int in range(1, row.size() - 1):
				var tile: Vector2i = Vector2i(x, y)
				if PathUtils.is_passable(grid, tile):
					continue
				_assert(str(row[x]) == "pillar", "Generated room interiors should use pillars as their only blocking terrain while wall art stays reserved for the perimeter")

func _test_room_generation_avoids_adjacent_columns() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	for seed: int in range(1, 80):
		for room_type: String in ["combat", "boss", "campfire", "treasure"]:
			var room: Dictionary = generator.generate_room(seed, {
				"coord": Vector2i(seed % 6, seed % 5),
				"depth": 2,
				"type": room_type
			}, Vector2i.ZERO)
			var grid: Array = room.get("grid", [])
			for y: int in range(1, grid.size() - 1):
				var row: Array = grid[y]
				for x: int in range(1, row.size() - 1):
					if str(row[x]) != "pillar":
						continue
					if x + 1 < row.size() - 1:
						_assert(str(row[x + 1]) != "pillar", "Generated columns should not be horizontally adjacent")
					if y + 1 < grid.size() - 1:
						_assert(str((grid[y + 1] as Array)[x]) != "pillar", "Generated columns should not be vertically adjacent")

func _test_room_generation_uses_stone_floor_with_moss_accents() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	var room: Dictionary = generator.generate_room(73, {
		"coord": Vector2i(2, 1),
		"depth": 2,
		"type": "combat"
	}, Vector2i(0, -1))
	var grid: Array = room.get("grid", [])
	var moss: Dictionary = room.get("moss", {})
	var floor_moss: Array = moss.get("floor", [])
	var wall_moss: Array = moss.get("wall", [])
	var pillar_moss: Array = moss.get("pillar", [])
	var stone_count: int = 0
	var legacy_moss_count: int = 0
	var ember_count: int = 0
	for y: int in range(grid.size()):
		var row: Array = grid[y]
		for x: int in range(row.size()):
			match str(row[x]):
				"stone":
					stone_count += 1
				"moss":
					legacy_moss_count += 1
				"ember":
					ember_count += 1
	_assert(str(room.get("theme", "")) == "stone", "Rooms should now advertise the stone floor theme by default")
	_assert(ember_count == 0, "Generated floors should no longer use ember tiles")
	_assert(legacy_moss_count == 0, "Generated floors should keep moss decorative instead of using dedicated moss terrain tiles")
	_assert(floor_moss.size() >= 5, "Generated floors should now carry a denser layer of decorative moss overlays")
	_assert(wall_moss.size() + pillar_moss.size() >= 1, "Decorative moss should also reach at least one stone fixture beyond the floor")
	_assert(stone_count > floor_moss.size(), "Stone floor tiles should still make up the majority of the room floor")

func _test_elemental_room_overlays_are_decorative_and_distinct() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	var generated_moss: Dictionary = {}
	var generated_grid: Array = []
	for element_id: String in ElementData.all_elements():
		var room: Dictionary = generator.generate_room(817, {
			"coord": Vector2i(2, 1),
			"depth": 2,
			"type": "combat",
			"element": element_id
		}, Vector2i(0, -1))
		if generated_moss.is_empty():
			generated_moss = (room.get("moss", {}) as Dictionary).duplicate(true)
			generated_grid = (room.get("grid", []) as Array).duplicate(true)
		else:
			_assert(room.get("moss", {}) == generated_moss, "Elemental overlay placement should stay decorative and independent of room mechanics")
			_assert(room.get("grid", []) == generated_grid, "Elemental overlays should not replace or mutate room terrain")

	var board := CombatBoardView.new()
	var fake_variants: Dictionary = {}
	for element_id: String in ElementData.all_elements():
		fake_variants[element_id] = {"floor": [], "wall": [], "pillar": []}
	board.set("_element_overlay_texture_variants", fake_variants)
	for element_id: String in ElementData.all_elements():
		board.set("combat_state", {"room_element": element_id})
		_assert(str(board.call("_element_overlay_family_id")) == element_id, "Each elemental room should select its own decorative overlay family")
		_assert(str(board.call("_element_overlay_family_id", "pillar")) == ElementData.EARTH, "Pillars should retain the established moss treatment in every elemental room")
	board.set("combat_state", {"room_element": ElementData.NONE})
	_assert(str(board.call("_element_overlay_family_id")) == ElementData.EARTH, "Neutral and legacy rooms should preserve the established moss treatment")

	var floor_candidates: Dictionary = {}
	for y: int in range(8):
		for x: int in range(12):
			floor_candidates[Vector2i(x, y)] = true
	board.set("_moss_tiles_by_surface", {"floor": floor_candidates})
	board.set("combat_state", {"room_element": ElementData.EARTH, "room_coord": Vector2i(2, 1)})
	var moss_floor_count: int = 0
	for tile_var: Variant in floor_candidates.keys():
		if bool(board.call("_tile_has_moss", "floor", tile_var)):
			moss_floor_count += 1
	_assert(moss_floor_count == floor_candidates.size(), "Earth rooms should preserve the full established moss floor placement")
	board.set("combat_state", {"room_element": ElementData.FIRE, "room_coord": Vector2i(2, 1)})
	var sparse_floor_tiles: Array[Vector2i] = []
	for tile_var: Variant in floor_candidates.keys():
		var tile: Vector2i = tile_var
		if bool(board.call("_tile_has_moss", "floor", tile)):
			sparse_floor_tiles.append(tile)
	var repeated_sparse_floor_tiles: Array[Vector2i] = []
	for tile_var: Variant in floor_candidates.keys():
		var tile: Vector2i = tile_var
		if bool(board.call("_tile_has_moss", "floor", tile)):
			repeated_sparse_floor_tiles.append(tile)
	_assert(sparse_floor_tiles == repeated_sparse_floor_tiles, "Sparse elemental floor accents should remain deterministic")
	_assert(sparse_floor_tiles.size() >= 48 and sparse_floor_tiles.size() <= 64, "Non-earth floor accents should use a modestly higher density near seven-elevenths of established moss candidates")

	var shared_moss_state: Dictionary = {
		"room_coord": Vector2i(2, 1),
		"moss": generated_moss
	}
	var fire_state: Dictionary = shared_moss_state.duplicate(true)
	fire_state["room_element"] = ElementData.FIRE
	var ice_state: Dictionary = shared_moss_state.duplicate(true)
	ice_state["room_element"] = ElementData.ICE
	_assert(
		str(board.call("_moss_signature_for_state", fire_state)) != str(board.call("_moss_signature_for_state", ice_state)),
		"Retained board layers should invalidate decorative overlays when the room element changes"
	)

	var overlay_path_groups: Array = [
		CombatBoardView.FIRE_FLOOR_OVERLAY_PATHS, CombatBoardView.FIRE_WALL_OVERLAY_PATHS, CombatBoardView.FIRE_PILLAR_OVERLAY_PATHS,
		CombatBoardView.ICE_FLOOR_OVERLAY_PATHS, CombatBoardView.ICE_WALL_OVERLAY_PATHS, CombatBoardView.ICE_PILLAR_OVERLAY_PATHS,
		CombatBoardView.LIGHTNING_FLOOR_OVERLAY_PATHS, CombatBoardView.LIGHTNING_WALL_OVERLAY_PATHS, CombatBoardView.LIGHTNING_PILLAR_OVERLAY_PATHS,
		CombatBoardView.AIR_FLOOR_OVERLAY_PATHS, CombatBoardView.AIR_WALL_OVERLAY_PATHS, CombatBoardView.AIR_PILLAR_OVERLAY_PATHS
	]
	for path_group_var: Variant in overlay_path_groups:
		var path_group: PackedStringArray = path_group_var
		for path_var: Variant in path_group:
			_assert(FileAccess.file_exists(str(path_var)), "Elemental decorative overlay asset should exist: %s" % str(path_var))
	board.free()

func _test_special_rooms_use_corner_pillar_layout() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	var campfire_room: Dictionary = generator.generate_room(91, {
		"coord": Vector2i(2, 0),
		"depth": 2,
		"type": "campfire"
	}, Vector2i(1, 0))
	_assert_corner_pillar_room(campfire_room, "Campfire")
	var treasure_room: Dictionary = generator.generate_room(91, {
		"coord": Vector2i(1, 1),
		"depth": 2,
		"type": "treasure"
	}, Vector2i(0, -1))
	_assert_corner_pillar_room(treasure_room, "Treasure")
	var blacksmith_room: Dictionary = generator.generate_room(91, {
		"coord": Vector2i(2, 1),
		"depth": 2,
		"type": "blacksmith",
		"npcs": [{"id": "blacksmith", "pos": Vector2i(3, 4)}]
	}, Vector2i(0, -1))
	_assert_corner_pillar_room(blacksmith_room, "Blacksmith")
	_assert((blacksmith_room.get("npcs", []) as Array).size() == 1, "Blacksmith rooms should keep their merchant NPC")
	var arcanist_room: Dictionary = generator.generate_room(91, {
		"coord": Vector2i(2, -1),
		"depth": 2,
		"type": "arcanist",
		"npcs": [{"id": "arcanist", "pos": Vector2i(3, 4)}]
	}, Vector2i(0, 1))
	_assert_corner_pillar_room(arcanist_room, "Arcanist")
	_assert((arcanist_room.get("npcs", []) as Array).size() == 1, "Arcanist rooms should keep their merchant NPC")
	var scavenger_room: Dictionary = generator.generate_room(91, {
		"coord": Vector2i(-2, 1),
		"depth": 2,
		"type": "scavenger",
		"npcs": [{"id": "scavenger", "pos": Vector2i(3, 4)}]
	}, Vector2i(0, -1))
	_assert_corner_pillar_room(scavenger_room, "Scavenger")
	_assert((scavenger_room.get("npcs", []) as Array).size() == 1, "Scavenger rooms should keep their merchant NPC")
	var grid: Array = campfire_room.get("grid", [])
	for y: int in range(3, 6):
		for x: int in range(3, 6):
			_assert(str((grid[y] as Array)[x]) == "stone", "The campfire bonfire footprint should remain floor tiles")
	var floor_moss: Array = (campfire_room.get("moss", {}) as Dictionary).get("floor", [])
	for tile: Vector2i in floor_moss:
		_assert(tile.x < 3 or tile.x > 5 or tile.y < 3 or tile.y > 5, "Campfire moss should leave the 3x3 bonfire footprint visually clear")

func _assert_corner_pillar_room(room: Dictionary, label: String) -> void:
	var grid: Array = room.get("grid", [])
	var pillar_tiles: Array[Vector2i] = [Vector2i(2, 2), Vector2i(6, 2), Vector2i(2, 6), Vector2i(6, 6)]
	for pillar_tile: Vector2i in pillar_tiles:
		_assert(str((grid[pillar_tile.y] as Array)[pillar_tile.x]) == "pillar", "%s rooms should place pillars on the second-to-last ring corners" % label)
	for y: int in range(1, grid.size() - 1):
		for x: int in range(1, (grid[y] as Array).size() - 1):
			var tile := Vector2i(x, y)
			if pillar_tiles.has(tile):
				continue
			_assert(str((grid[y] as Array)[x]) == "stone", "%s rooms should keep the rest of the interior clear" % label)

func _open_floor_count_with_blockers(grid: Array, blocked: Dictionary) -> int:
	var count: int = 0
	for y: int in range(grid.size()):
		var row: Array = grid[y]
		for x: int in range(row.size()):
			var tile: Vector2i = Vector2i(x, y)
			if blocked.has(tile):
				continue
			if PathUtils.is_passable(grid, tile):
				count += 1
	return count

func _reachable_floor_count_with_blockers(grid: Array, start: Vector2i, blocked: Dictionary) -> int:
	if blocked.has(start) or not PathUtils.is_passable(grid, start):
		return 0
	var queue: Array[Vector2i] = []
	queue.append(start)
	var visited: Dictionary = {start: true}
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for direction: Vector2i in PathUtils.DIRS_4:
			var next_tile: Vector2i = current + direction
			if visited.has(next_tile) or blocked.has(next_tile):
				continue
			if not PathUtils.is_passable(grid, next_tile):
				continue
			visited[next_tile] = true
			queue.append(next_tile)
	return visited.size()

func _is_playable_edge_band_tile(tile: Vector2i) -> bool:
	return tile.x == 1 or tile.y == 1 or tile.x == RoomGenerator.ROOM_WIDTH - 2 or tile.y == RoomGenerator.ROOM_HEIGHT - 2

func _is_playable_corner_tile(tile: Vector2i) -> bool:
	return (tile.x == 1 or tile.x == RoomGenerator.ROOM_WIDTH - 2) and (tile.y == 1 or tile.y == RoomGenerator.ROOM_HEIGHT - 2)

func _test_room_generation_populates_elemental_traps() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	var trap_count_histogram: Dictionary = {}
	var total_traps: int = 0
	var edge_traps: int = 0
	var corner_traps: int = 0
	for seed: int in range(300, 340):
		var room: Dictionary = generator.generate_room(seed, {
			"coord": Vector2i(seed % 5, seed % 4),
			"depth": 1 + seed % 3,
			"type": "combat",
			"element": "fire"
		}, Vector2i(1, 0))
		var traps: Array = room.get("traps", [])
		trap_count_histogram[traps.size()] = int(trap_count_histogram.get(traps.size(), 0)) + 1
		_assert(traps.size() >= 2 and traps.size() <= 3, "Combat rooms should seed two to three traps")
		var occupied: Dictionary = {room.get("player_start", Vector2i.ZERO): true}
		for enemy_var: Variant in room.get("enemies", []):
			if typeof(enemy_var) != TYPE_DICTIONARY:
				continue
			occupied[(enemy_var as Dictionary).get("pos", Vector2i(-1, -1))] = true
		for loot_var: Variant in room.get("loot", []):
			if typeof(loot_var) != TYPE_DICTIONARY:
				continue
			occupied[(loot_var as Dictionary).get("pos", Vector2i(-1, -1))] = true
		for trap_var: Variant in traps:
			if typeof(trap_var) != TYPE_DICTIONARY:
				continue
			var trap: Dictionary = trap_var
			var pos: Vector2i = trap.get("pos", Vector2i(-1, -1))
			_assert(str(trap.get("element", "")) == "fire", "Generated traps should inherit the room element")
			_assert(int(trap.get("damage", 0)) > 0, "Generated traps should always deal damage")
			_assert(PathUtils.is_passable(room.get("grid", []), pos), "Traps should only spawn on passable floor tiles")
			_assert(not occupied.has(pos), "Traps should avoid player, enemy, and loot placements")
			if _is_playable_edge_band_tile(pos):
				edge_traps += 1
			if _is_playable_corner_tile(pos):
				corner_traps += 1
			total_traps += 1
			occupied[pos] = true
	_assert(trap_count_histogram.has(2) and trap_count_histogram.has(3), "Trap counts should vary between two and three across generated rooms")
	_assert(edge_traps > 0, "Trap placement should allow playable edge-band floor tiles")
	_assert(corner_traps > 0, "Trap placement should allow playable corner floor tiles")
	var depth_one_fire_trap: Dictionary = generator.call("_trap_for_tile", Vector2i(4, 4), ElementData.FIRE, 1)
	var depth_two_fire_trap: Dictionary = generator.call("_trap_for_tile", Vector2i(4, 4), ElementData.FIRE, 2)
	var deep_fire_trap: Dictionary = generator.call("_trap_for_tile", Vector2i(4, 4), ElementData.FIRE, 3)
	var boss_lightning_trap: Dictionary = generator.call("_trap_for_tile", Vector2i(4, 4), ElementData.LIGHTNING, 4)
	var later_sequence_fire_trap: Dictionary = generator.call("_trap_for_tile", Vector2i(4, 4), ElementData.FIRE, 1, 1)
	var lightning_wisp_hp: int = int(GameData.enemy_def("lightning_wisp").get("max_hp", 0))
	_assert(int(depth_one_fire_trap.get("damage", 0)) == GameData.fixed_point_amount(6), "Depth-one traps should hit harder than weak ranged attacks")
	_assert(int(depth_two_fire_trap.get("damage", 0)) == GameData.fixed_point_amount(7), "Depth-two traps should keep climbing with local depth")
	_assert(int(deep_fire_trap.get("damage", 0)) == GameData.fixed_point_amount(8), "Depth-three traps should be a meaningful positional payoff")
	_assert(int(boss_lightning_trap.get("damage", 0)) == GameData.fixed_point_amount(5), "Boss-depth traps should beat weak ranged attacks without one-shotting healthy boss adds")
	_assert(int(boss_lightning_trap.get("damage", 0)) < lightning_wisp_hp, "Boss-depth traps should leave full-health lightning wisps alive")
	_assert(int(later_sequence_fire_trap.get("damage", 0)) == GameData.fixed_point_amount(7), "Later-sequence traps should follow the bounded authored sequence curve")
	_assert(int(depth_two_fire_trap.get("burn", 0)) == GameData.fixed_point_amount(1), "Depth-two fire traps should keep shallow burn pressure")
	_assert(int(deep_fire_trap.get("burn", 0)) > int(depth_two_fire_trap.get("burn", 0)), "Deep fire traps should still ramp their burn pressure")

func _test_room_generation_adds_pickups_and_destructible_terrain() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	for room_type: String in ["combat", "boss", "campfire", "treasure"]:
		var room: Dictionary = generator.generate_room(412, {
			"coord": Vector2i(2, 2),
			"depth": 4 if room_type == "boss" else 2,
			"type": room_type,
			"element": ElementData.FIRE
		}, Vector2i(0, -1))
		var loot_by_kind: Dictionary = {}
		for loot_var: Variant in room.get("loot", []):
			if typeof(loot_var) != TYPE_DICTIONARY:
				continue
			var loot: Dictionary = loot_var
			loot_by_kind[str(loot.get("kind", ""))] = loot
			_assert(PathUtils.is_passable(room.get("grid", []), loot.get("pos", Vector2i(-1, -1))), "Generated pickups should sit on passable floor tiles")
		if room_type == "combat":
			var utility_count: int = int(loot_by_kind.has("healing_vial")) + int(loot_by_kind.has("rusty_shield"))
			_assert(utility_count == 1, "Combat rooms should place exactly one attrition-limited utility pickup")
			if loot_by_kind.has("healing_vial"):
				_assert(int((loot_by_kind.get("healing_vial", {}) as Dictionary).get("amount", 0)) == 2, "Healing vials should heal 2")
			if loot_by_kind.has("rusty_shield"):
				_assert(int((loot_by_kind.get("rusty_shield", {}) as Dictionary).get("amount", 0)) == 3, "Rusty shields should grant 3 block")
		elif room_type == "boss":
			_assert(loot_by_kind.has("healing_vial") and int((loot_by_kind.get("healing_vial", {}) as Dictionary).get("amount", 0)) == 2, "Boss rooms should place one 2-HP healing vial")
			_assert(loot_by_kind.has("rusty_shield") and int((loot_by_kind.get("rusty_shield", {}) as Dictionary).get("amount", 0)) == 3, "Boss rooms should place one 3-block shield")
		else:
			_assert(loot_by_kind.is_empty(), "%s rooms should not place battlefield pickups" % room_type.capitalize())
		_assert(not loot_by_kind.has("ember_cache"), "Generated tile loot should no longer spawn random ember caches")
	var equipment_room: Dictionary = generator.generate_room(412, {
		"coord": Vector2i(2, 2),
		"depth": 2,
		"type": "combat",
		"element": ElementData.FIRE,
		"equipment_drop": "iron_cleaver"
	}, Vector2i(0, -1))
	var equipment_loot: Dictionary = {}
	for loot_var: Variant in equipment_room.get("loot", []):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		var loot: Dictionary = loot_var
		if str(loot.get("kind", "")) == "equipment":
			equipment_loot = loot
			break
	_assert(not equipment_loot.is_empty(), "Combat rooms with an equipment drop should place it as tile loot")
	_assert(str(equipment_loot.get("equipment_id", "")) == "iron_cleaver", "Equipment tile loot should preserve the selected equipment id")
	_assert(PathUtils.is_passable(equipment_room.get("grid", []), equipment_loot.get("pos", Vector2i(-1, -1))), "Equipment tile loot should sit on passable floor tiles")
	var combat_room: Dictionary = generator.generate_room(413, {
		"coord": Vector2i(3, 1),
		"depth": 2,
		"type": "combat",
		"element": ElementData.EARTH
	}, Vector2i(1, 0))
	var occupied: Dictionary = {combat_room.get("player_start", Vector2i.ZERO): true}
	for enemy_var: Variant in combat_room.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		occupied[(enemy_var as Dictionary).get("pos", Vector2i(-1, -1))] = true
	for trap_var: Variant in combat_room.get("traps", []):
		if typeof(trap_var) != TYPE_DICTIONARY:
			continue
		occupied[(trap_var as Dictionary).get("pos", Vector2i(-1, -1))] = true
	for loot_var: Variant in combat_room.get("loot", []):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		occupied[(loot_var as Dictionary).get("pos", Vector2i(-1, -1))] = true
	var terrain_entries: Array = combat_room.get("terrain", [])
	_assert(terrain_entries.size() >= 5 and terrain_entries.size() <= 7, "Combat rooms should scatter five to seven destructible terrain pieces")
	var blocked: Dictionary = {}
	for terrain_var: Variant in terrain_entries:
		if typeof(terrain_var) != TYPE_DICTIONARY:
			continue
		var terrain: Dictionary = terrain_var
		var pos: Vector2i = terrain.get("pos", Vector2i(-1, -1))
		_assert(str(terrain.get("kind", "")) in ["wooden_box", "wooden_crate"], "Generated terrain should be boxes or crates")
		_assert(int(terrain.get("hp", 0)) == 3 and int(terrain.get("max_hp", 0)) == 3, "Generated terrain should have low 3 HP")
		_assert(PathUtils.is_passable(combat_room.get("grid", []), pos), "Generated terrain should sit on passable floor tiles")
		_assert(not occupied.has(pos), "Generated terrain should avoid actors, traps, and pickups")
		occupied[pos] = true
		blocked[pos] = true
	var grid: Array = combat_room.get("grid", [])
	var player_start: Vector2i = combat_room.get("player_start", Vector2i.ZERO)
	_assert(
		_reachable_floor_count_with_blockers(grid, player_start, blocked) == _open_floor_count_with_blockers(grid, blocked),
		"Generated terrain should still leave the open floor connected"
	)
	var edge_pickups: int = 0
	var edge_terrain: int = 0
	var corner_terrain: int = 0
	for seed: int in range(420, 480):
		var sample_room: Dictionary = generator.generate_room(seed, {
			"coord": Vector2i(seed % 7, seed % 5),
			"depth": 2,
			"type": "combat",
			"element": ElementData.FIRE
		}, Vector2i(seed % 3 - 1, 0))
		for loot_var: Variant in sample_room.get("loot", []):
			if typeof(loot_var) != TYPE_DICTIONARY:
				continue
			var loot_pos: Vector2i = (loot_var as Dictionary).get("pos", Vector2i(-1, -1))
			if _is_playable_edge_band_tile(loot_pos):
				edge_pickups += 1
		for terrain_var: Variant in sample_room.get("terrain", []):
			if typeof(terrain_var) != TYPE_DICTIONARY:
				continue
			var terrain_pos: Vector2i = (terrain_var as Dictionary).get("pos", Vector2i(-1, -1))
			if _is_playable_edge_band_tile(terrain_pos):
				edge_terrain += 1
			if _is_playable_corner_tile(terrain_pos):
				corner_terrain += 1
	_assert(edge_pickups > 0, "Generated pickups should be eligible for playable edge-band floor tiles")
	_assert(edge_terrain > 0, "Generated destructible terrain should be eligible for playable edge-band floor tiles")
	_assert(corner_terrain > 0, "Generated destructible terrain should be eligible for playable corner floor tiles")

func _test_room_generation_scales_enemy_density() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	# Keep this depth-scaling fixture objective-neutral: seed 417 resolves each
	# standard coordinate below to Kill All, so leader/exit modifiers cannot
	# distort the density and HP comparisons exercised here.
	var density_seed: int = 417
	var depth_one_room: Dictionary = generator.generate_room(density_seed, {
		"coord": Vector2i(1, 0),
		"depth": 1,
		"type": "combat"
	}, Vector2i(1, 0))
	var depth_three_room: Dictionary = generator.generate_room(density_seed, {
		"coord": Vector2i(2, 1),
		"depth": 3,
		"type": "combat"
	}, Vector2i(1, 0))
	var second_sequence_opening: Dictionary = generator.generate_room(density_seed, {
		"coord": Vector2i(5, 0),
		"depth": 5,
		"type": "combat"
	}, Vector2i(1, 0))
	var second_sequence_deep: Dictionary = generator.generate_room(density_seed, {
		"coord": Vector2i(6, 1),
		"depth": 7,
		"type": "combat"
	}, Vector2i(1, 0))
	var boss_room: Dictionary = generator.generate_room(density_seed, {
		"coord": Vector2i(4, 0),
		"depth": 4,
		"type": "boss"
	}, Vector2i(1, 0))
	_assert((depth_one_room.get("enemies", []) as Array).size() >= 3, "Opening combat rooms should pack at least three enemies")
	_assert((depth_three_room.get("enemies", []) as Array).size() >= 5, "Outer combat rooms should feel denser than the opening ring")
	_assert((second_sequence_opening.get("enemies", []) as Array).size() == (depth_one_room.get("enemies", []) as Array).size(), "Second sequence opening rooms should reset to opening density")
	_assert((second_sequence_deep.get("enemies", []) as Array).size() >= 5, "Second sequence deep rooms should climb back to five-enemy density")
	var opening_enemy: Dictionary = (depth_one_room.get("enemies", []) as Array)[0] as Dictionary
	var deep_enemy: Dictionary = (depth_three_room.get("enemies", []) as Array)[0] as Dictionary
	var second_opening_enemy: Dictionary = (second_sequence_opening.get("enemies", []) as Array)[0] as Dictionary
	var opening_base_hp: int = int(GameData.enemy_def(str(opening_enemy.get("type", ""))).get("max_hp", 0))
	var deep_base_hp: int = int(GameData.enemy_def(str(deep_enemy.get("type", ""))).get("max_hp", 0))
	_assert(int(opening_enemy.get("max_hp", 0)) < opening_base_hp, "Opening-depth enemies should start below their base HP")
	_assert(int(deep_enemy.get("max_hp", 0)) > deep_base_hp, "Outer standard rooms should push enemy HP above base")
	_assert(int(second_opening_enemy.get("max_hp", 0)) > int(opening_enemy.get("max_hp", 0)), "Second sequence enemies should start from a tougher HP baseline")
	_assert((boss_room.get("enemies", []) as Array).size() >= 3, "Boss rooms should include support enemies")

func _test_element_locked_enemy_spawn_rules() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	var normal_enemy_types: Array = ["crawler", "harrier", "acolyte", "warden", "grave_surgeon"]
	var locked_elements: Dictionary = {
		"bile_bloomer": ElementData.EARTH,
		"frostglass_lancer": ElementData.ICE,
		"cinder_ooze": ElementData.FIRE,
		"chainbound_gaoler": ElementData.AIR
	}
	var room_elements: Array[String] = [ElementData.NONE]
	for element_id: String in ElementData.all_elements():
		room_elements.append(element_id)
	for enemy_type_var: Variant in locked_elements.keys():
		var enemy_type: String = str(enemy_type_var)
		var expected_element: String = str(locked_elements.get(enemy_type, ElementData.NONE))
		_assert(str(GameData.enemy_def(enemy_type).get("element", "")) == expected_element, "%s should declare its locked element in enemy data" % enemy_type)

	for depth: int in [1, 2, 3]:
		var expected_density: int = 5
		if depth == 1:
			expected_density = 3
		elif depth == 2:
			expected_density = 4
		var seen_normal: Dictionary = {}
		var base_pool: Array = generator.call("_base_encounter_enemy_type_pool", depth)
		for enemy_type_var: Variant in normal_enemy_types:
			seen_normal[str(enemy_type_var)] = false
		for enemy_types_var: Variant in base_pool:
			var enemy_types: Array = enemy_types_var as Array
			_assert(enemy_types.size() == expected_density, "Base depth-%d enemy pools should keep the normal density curve" % depth)
			for enemy_type_var: Variant in normal_enemy_types:
				var enemy_type: String = str(enemy_type_var)
				if enemy_types.has(enemy_type):
					seen_normal[enemy_type] = true
		for enemy_type_var: Variant in normal_enemy_types:
			var enemy_type: String = str(enemy_type_var)
			_assert(bool(seen_normal.get(enemy_type, false)), "%s should be eligible in depth-%d combat pools" % [enemy_type, depth])

		var seen: Dictionary = {}
		for enemy_type_var: Variant in locked_elements.keys():
			seen[str(enemy_type_var)] = false
		for room_element: String in room_elements:
			var pool: Array = generator.call("_base_encounter_enemy_type_pool", depth)
			generator.call("_add_element_locked_enemy_type_pools", pool, depth, room_element)
			for enemy_types_var: Variant in pool:
				var enemy_types: Array = enemy_types_var as Array
				_assert(enemy_types.size() == expected_density, "Elemental depth-%d enemy pools should keep the normal density curve" % depth)
				_assert(not enemy_types.has("cinder_droplet"), "Cinder Droplets should only come from Cinder Ooze split spawns")
				for enemy_type_var: Variant in locked_elements.keys():
					var enemy_type: String = str(enemy_type_var)
					if not enemy_types.has(enemy_type):
						continue
					seen[enemy_type] = true
					var expected_element: String = str(locked_elements.get(enemy_type, ElementData.NONE))
					_assert(room_element == expected_element, "%s should only appear in %s rooms" % [enemy_type, ElementData.name(expected_element)])
					if enemy_type == "chainbound_gaoler":
						_assert(enemy_types.size() == expected_density, "Chainbound Gaoler rooms should keep normal enemy density")
						_assert(not enemy_types.has("warden"), "Chainbound Gaoler compositions should avoid pairing with the slow heavy anchor")
						_assert(not enemy_types.has("lightning_wisp"), "Chainbound Gaoler should stay out of boss/add control pairings")
		for enemy_type_var: Variant in locked_elements.keys():
			var enemy_type: String = str(enemy_type_var)
			_assert(bool(seen.get(enemy_type, false)), "%s should appear in its matching element depth-%d pool" % [enemy_type, depth])

func _test_boss_room_spawns_zekarion_with_wisps() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	var room: Dictionary = generator.generate_room(100, {
		"coord": Vector2i(4, 0),
		"depth": 4,
		"type": "boss",
		"element": ElementData.LIGHTNING
	}, Vector2i(1, 0))
	var enemies: Array = room.get("enemies", [])
	_assert(enemies.size() == 3, "Depth-four boss room should spawn Zekarion and two wisps")
	var zekarion: Dictionary = enemies[0]
	_assert(str(zekarion.get("type", "")) == "zekarion", "Boss room primary enemy should be Zekarion")
	_assert(zekarion.get("footprint", Vector2i.ZERO) == Vector2i(2, 2), "Zekarion should occupy a 2x2 footprint")
	var occupied: Dictionary = {}
	for tile: Vector2i in _enemy_footprint_tiles_for_test(zekarion):
		occupied[tile] = true
		_assert(PathUtils.is_passable(room.get("grid", []), tile), "Zekarion footprint should be on passable terrain")
	_assert(occupied.size() == 4, "Zekarion footprint should cover four unique squares")
	_assert(str((enemies[1] as Dictionary).get("type", "")) == "lightning_wisp", "Boss room should include lightning wisps")
	_assert(str((enemies[2] as Dictionary).get("type", "")) == "lightning_wisp", "Boss room should include a second lightning wisp")

func _test_second_sequence_uses_scaled_zekarion_placeholder() -> void:
	var generator: RoomGenerator = RoomGenerator.new()
	var first_boss_room: Dictionary = generator.generate_room(100, {
		"coord": Vector2i(4, 0),
		"depth": 4,
		"type": "boss",
		"element": ElementData.LIGHTNING
	}, Vector2i(1, 0))
	var second_boss_room: Dictionary = generator.generate_room(100, {
		"coord": Vector2i(8, 0),
		"depth": 8,
		"type": "boss",
		"element": ElementData.LIGHTNING
	}, Vector2i(1, 0))
	var first_boss: Dictionary = (first_boss_room.get("enemies", []) as Array)[0]
	var second_boss: Dictionary = (second_boss_room.get("enemies", []) as Array)[0]
	_assert(str(second_boss.get("type", "")) == "zekarion", "Second sequence boss should use Zekarion as the placeholder dragon")
	_assert(int(second_boss.get("max_hp", 0)) > int(first_boss.get("max_hp", 0)), "Placeholder Zekarion should scale up at the end of the second sequence")

func _test_start_room_spawns_emaciated_man() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(41, ProgressionStore.default_data())
	var start_room: Dictionary = run_engine.room_metadata(run_state, Vector2i.ZERO)
	var start_layout: Dictionary = run_state.get("current_room_layout", {})
	var room_npcs: Array = start_room.get("npcs", [])
	var layout_npcs: Array = start_layout.get("npcs", [])
	_assert(room_npcs.size() == 1 and str((room_npcs[0] as Dictionary).get("id", "")) == "emaciated_man", "The starting room should seed the Emaciated Man NPC")
	_assert(layout_npcs.size() == 1 and str((layout_npcs[0] as Dictionary).get("name", "")) == "Emaciated Man", "The starting room layout should surface the Emaciated Man for rendering")
	_assert((start_layout.get("enemies", []) as Array).is_empty(), "Rooms with NPCs should not populate enemies")

func _test_fatigue_draws_cost_health_and_burn_removes_card() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(11, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
			"deck_cards": ["patch_up", "quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = state.get("deck", {}).duplicate(true)
	deck["hand"] = ["patch_up"]
	deck["draw"] = []
	deck["discard"] = ["quick_stab"]
	state["deck"] = deck
	var hp_before: int = int((state.get("player", {}) as Dictionary).get("hp", 0))
	state = combat.finish_player_card(state, 0)
	_assert((state.get("deck", {}) as Dictionary).get("burned", []).has("patch_up"), "Burn cards should move to the burned pile")
	state = combat.prepare_next_player_turn(state)
	var hp_after: int = int((state.get("player", {}) as Dictionary).get("hp", 0))
	_assert(hp_after == hp_before - CombatEngine.FATIGUE_BASE_DAMAGE, "Cycling the deck should deal first-cycle fatigue damage")
	_assert((state.get("deck", {}) as Dictionary).get("hand", []).has("quick_stab"), "Discard should reshuffle into the draw and refill hand")

func _test_consumable_item_card_is_destroyed_after_play() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(111, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["crimson_draught", "quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = state.get("deck", {}).duplicate(true)
	deck["hand"] = ["crimson_draught"]
	deck["draw"] = ["quick_stab"]
	deck["discard"] = []
	deck["burned"] = []
	deck["consumed"] = []
	state["deck"] = deck
	state = combat.finish_player_card(state, 0)
	var after_deck: Dictionary = state.get("deck", {})
	_assert((after_deck.get("consumed", []) as Array).has("crimson_draught"), "Consumable item cards should move to the consumed zone after play")
	_assert(not (after_deck.get("discard", []) as Array).has("crimson_draught"), "Consumable item cards should not move to discard")
	_assert(not (after_deck.get("burned", []) as Array).has("crimson_draught"), "Consumable item cards should not move to burned")

func _test_two_card_turn_draw_flow() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(15, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab", "brace", "quick_stab", "quick_stab", "quick_stab", "bone_dart", "patch_up"],
		"relics": [],
		"hand_size": 5,
		"heal_bonus": 0
	})
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["quick_stab", "brace", "quick_stab", "quick_stab", "quick_stab"]
	deck["draw"] = ["bone_dart", "patch_up"]
	deck["discard"] = []
	state["deck"] = deck
	_assert(int(state.get("cards_per_turn", 0)) == 2, "Combat should allow two cards per turn")
	_assert(int(state.get("draw_per_turn", 0)) == 2, "Combat should draw two cards each turn")
	state = combat.finish_player_card(state, 1)
	_assert(int(state.get("cards_played_this_turn", 0)) == 1, "Playing one card should consume one play")
	state = combat.finish_player_card(state, 0)
	_assert(int(state.get("cards_played_this_turn", 0)) == 2, "Playing a second card should spend the full turn")
	state = combat.prepare_next_player_turn(state)
	_assert(int(state.get("cards_played_this_turn", 0)) == 0, "A new turn should reset the play counter")
	_assert(int(state.get("turn", 0)) == 2, "Advancing the player turn should increment the turn counter")
	_assert(((state.get("deck", {}) as Dictionary).get("hand", []) as Array).size() == 5, "A new turn should draw two replacement cards")

func _test_initiative_order_starts_with_active_player_and_fast_enemies() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["enemies"] = [
		{
			"id": 1,
			"type": "warden",
			"pos": Vector2i(5, 2),
			"hp": 20,
			"max_hp": 20,
			"block": 0
		},
		{
			"id": 2,
			"type": "crawler",
			"pos": Vector2i(6, 2),
			"hp": 14,
			"max_hp": 14,
			"block": 0
		}
	]
	var state: Dictionary = combat.create_combat(15130, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab", "brace"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var order: Array[Dictionary] = combat.current_turn_order(state, 8)
	_assert(order.size() >= 3, "Initiative order should include the active player and queued enemies")
	_assert(bool(order[0].get("active", false)) and str(order[0].get("kind", "")) == "player", "The player should still start combat as the active actor")
	var crawler_index: int = -1
	var warden_index: int = -1
	var crawler_count: int = 0
	var warden_count: int = 0
	var future_player_count: int = 0
	var first_future_player_index: int = -1
	for index: int in range(1, order.size()):
		if str(order[index].get("kind", "")) == "player":
			future_player_count += 1
			if first_future_player_index < 0:
				first_future_player_index = index
		if str(order[index].get("type", "")) == "crawler" and crawler_index < 0:
			crawler_index = index
		if str(order[index].get("type", "")) == "warden" and warden_index < 0:
			warden_index = index
		if str(order[index].get("type", "")) == "crawler":
			crawler_count += 1
		if str(order[index].get("type", "")) == "warden":
			warden_count += 1
	_assert(crawler_index > 0, "Speedy enemies should appear in the visible initiative queue")
	_assert(warden_index > crawler_index, "Slow enemies should appear later than speedy enemies")
	_assert(future_player_count >= 1, "The player should see their projected next slot while their current turn is active")
	_assert(first_future_player_index > 0 and bool(order[first_future_player_index].get("projected", false)), "The player's projected next turn should slot into the visible order by timing")
	_assert(crawler_count >= 2 and warden_count >= 2, "Turn order should show each enemy's next queued turn plus its projected follow-up")

func _test_initiative_advances_enemy_turns_until_player_reacts() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(15131, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["whirlwind_slash", "dull_bolt", "patch_up"],
		"relics": [],
		"hand_size": 2,
		"heal_bonus": 0
	})
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["whirlwind_slash", "dull_bolt"]
	deck["draw"] = ["patch_up"]
	deck["discard"] = []
	state["deck"] = deck
	state = combat.finish_player_card(state, 0)
	state = combat.finish_player_card(state, 0)
	_assert(int(state.get("player_turn_time_spent", 0)) == 9, "Played cards should add their time costs to the current player turn")
	var scheduled_state: Dictionary = combat.finish_player_activation(state)
	var scheduled_order: Array[Dictionary] = combat.current_turn_order(scheduled_state, 3)
	_assert(str(scheduled_order[0].get("kind", "")) == "enemy", "Passing should hand control to the next queued enemy before the player returns")
	_assert(not bool(scheduled_order[0].get("active", false)), "The player should no longer remain highlighted after their activation is scheduled out")
	_assert(str(scheduled_order[1].get("kind", "")) == "player", "The player's next slot should be scheduled from base initiative plus card time")
	_assert(int(scheduled_order[1].get("time", 0)) == 18, "A normal two-card turn should schedule the next player turn at initiative 18")
	var phase: Dictionary = combat.advance_to_next_player_turn_with_steps(scheduled_state)
	var after_state: Dictionary = phase.get("state", {})
	_assert(combat.is_player_turn(after_state), "Initiative advancement should stop once the next player turn becomes active")
	_assert(int(after_state.get("initiative_clock", 0)) == 18, "The initiative clock should advance to the player's scheduled return")
	_assert((phase.get("steps", []) as Array).size() >= 1, "Enemy turns resolved before the player should still emit animation steps")
	var saw_turn_order_step: bool = false
	for step_var: Variant in phase.get("steps", []):
		if typeof(step_var) == TYPE_DICTIONARY and str((step_var as Dictionary).get("kind", "")) == "turn_order":
			saw_turn_order_step = true
	_assert(saw_turn_order_step, "Initiative advancement should emit turn-order animation snapshots as actors activate and reslot")
	var next_order: Array[Dictionary] = combat.current_turn_order(after_state, 3)
	_assert(str(next_order[0].get("kind", "")) == "player" and bool(next_order[0].get("active", false)), "The refreshed order should mark the player as the active actor")
	_assert(str(next_order[1].get("kind", "")) == "enemy", "Enemies should immediately reslot for their next future turn after acting")

func _test_card_time_scale_changes_player_reentry_order() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["enemies"] = [
		{
			"id": 1,
			"type": "warden",
			"pos": Vector2i(5, 2),
			"hp": 20,
			"max_hp": 20,
			"block": 0
		}
	]
	var fast_state: Dictionary = combat.create_combat(15134, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["brace"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	fast_state = combat.finish_player_card(fast_state, 0)
	var fast_order: Array[Dictionary] = combat.current_turn_order(combat.finish_player_activation(fast_state), 3)
	_assert(int(GameData.card_def("brace").get("time", 0)) == 1, "Brace should anchor the fast end of the card time scale")
	_assert(str(fast_order[0].get("kind", "")) == "player", "A one-time card should let the player jump ahead of slow enemies")

	var fast_pair_layout: Dictionary = _simple_room_layout()
	fast_pair_layout["enemies"] = [
		{
			"id": 1,
			"type": "acolyte",
			"pos": Vector2i(5, 2),
			"hp": 12,
			"max_hp": 12,
			"block": 0
		}
	]
	var fast_pair_state: Dictionary = combat.create_combat(15138, fast_pair_layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab", "patch_up"],
		"relics": [],
		"hand_size": 2,
		"heal_bonus": 0
	})
	var fast_pair_deck: Dictionary = (fast_pair_state.get("deck", {}) as Dictionary).duplicate(true)
	fast_pair_deck["hand"] = ["quick_stab", "patch_up"]
	fast_pair_deck["draw"] = []
	fast_pair_deck["discard"] = []
	fast_pair_state["deck"] = fast_pair_deck
	fast_pair_state = combat.finish_player_card(fast_pair_state, 0)
	fast_pair_state = combat.finish_player_card(fast_pair_state, 0)
	var fast_pair_order: Array[Dictionary] = combat.current_turn_order(combat.finish_player_activation(fast_pair_state), 3)
	_assert(int(fast_pair_state.get("player_turn_time_spent", 0)) == 4, "Two fast cards should spend a clearly low amount of time")
	_assert(str(fast_pair_order[0].get("kind", "")) == "player", "Two fast cards should let the player lap slower enemies before they act")

	var heavy_state: Dictionary = combat.create_combat(15135, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["bloody_lunge"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	heavy_state = combat.finish_player_card(heavy_state, 0)
	var heavy_order: Array[Dictionary] = combat.current_turn_order(combat.finish_player_activation(heavy_state), 3)
	_assert(int(GameData.card_def("bloody_lunge").get("time", 0)) == 8, "Bloody Lunge should anchor the heavy end of the starter card time scale")
	_assert(str(heavy_order[0].get("kind", "")) == "enemy", "A heavy starter card should let fast enemies act before the player returns")

	var standard_state: Dictionary = combat.create_combat(15136, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["whirlwind_slash", "dull_bolt"],
		"relics": [],
		"hand_size": 2,
		"heal_bonus": 0
	})
	var standard_deck: Dictionary = (standard_state.get("deck", {}) as Dictionary).duplicate(true)
	standard_deck["hand"] = ["whirlwind_slash", "dull_bolt"]
	standard_deck["draw"] = []
	standard_deck["discard"] = []
	standard_state["deck"] = standard_deck
	standard_state = combat.finish_player_card(standard_state, 0)
	standard_state = combat.finish_player_card(standard_state, 0)
	var standard_order: Array[Dictionary] = combat.current_turn_order(combat.finish_player_activation(standard_state), 4)
	_assert(int(standard_state.get("player_turn_time_spent", 0)) == 9, "A normal two-card starter turn should spend about nine time")
	_assert(str(standard_order[0].get("kind", "")) == "enemy", "A fast early enemy should still act once before a normal player return")
	_assert(str(standard_order[1].get("kind", "")) == "player", "A normal two-card starter turn should return before the same fast enemy laps the player")
	_assert(str(standard_order[2].get("kind", "")) == "enemy" and bool(standard_order[2].get("projected", false)), "The fast enemy's projected follow-up should remain visible after the player's standard return")

	var slow_layout: Dictionary = _simple_room_layout()
	slow_layout["enemies"] = [
		{
			"id": 1,
			"type": "lightning_wisp",
			"pos": Vector2i(5, 2),
			"hp": 6,
			"max_hp": 6,
			"block": 0
		}
	]
	var slow_state: Dictionary = combat.create_combat(15137, slow_layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["bloody_lunge", "grave_sprint"],
		"relics": [],
		"hand_size": 2,
		"heal_bonus": 0
	})
	var slow_deck: Dictionary = (slow_state.get("deck", {}) as Dictionary).duplicate(true)
	slow_deck["hand"] = ["bloody_lunge", "grave_sprint"]
	slow_deck["draw"] = []
	slow_deck["discard"] = []
	slow_state["deck"] = slow_deck
	slow_state = combat.finish_player_card(slow_state, 0)
	slow_state = combat.finish_player_card(slow_state, 0)
	var slow_order: Array[Dictionary] = combat.current_turn_order(combat.finish_player_activation(slow_state), 4)
	_assert(int(slow_state.get("player_turn_time_spent", 0)) == 14, "Stacking two slow cards should create a slow turn")
	_assert(str(slow_order[0].get("kind", "")) == "enemy", "The fast enemy should act before a slow player return")
	_assert(str(slow_order[1].get("kind", "")) == "enemy" and bool(slow_order[1].get("projected", false)), "Slow turns should let fast enemies threaten a double-up")
	_assert(str(slow_order[2].get("kind", "")) == "player", "The player should return after the fast enemy's projected follow-up on slow turns")

func _test_legacy_stats_do_not_change_combat_numbers() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var clean_state: Dictionary = combat.create_combat(15132, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var forged_state: Dictionary = clean_state.duplicate(true)
	forged_state["stats"] = {"agility": 99, "ice_magick": 99}
	_assert(combat.player_base_initiative(clean_state) == 9, "The clean combat snapshot should use the fixed base initiative")
	_assert(combat.player_base_initiative(forged_state) == 9, "Retired stat fields must not change player initiative")
	var clean_enemies: Array = clean_state.get("enemies", []) as Array
	var forged_enemies: Array = forged_state.get("enemies", []) as Array
	if not clean_enemies.is_empty() and not forged_enemies.is_empty():
		(clean_enemies[0] as Dictionary)["freeze"] = 1
		(forged_enemies[0] as Dictionary)["freeze"] = 1
		clean_state["enemies"] = clean_enemies
		forged_state["enemies"] = forged_enemies
		var action: Dictionary = {"type": "melee", "damage": 90}
		_assert(
			int(combat.call("_damage_for_enemy_target", forged_state, action, 0)) == int(combat.call("_damage_for_enemy_target", clean_state, action, 0)),
			"Retired elemental allocation fields must not increase damage against frozen enemies"
		)

func _test_combat_log_is_bounded() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(1510, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab", "brace"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	for index: int in range(24):
		combat.call("_log", state, "Line %d" % index)
	var lines: Array = state.get("log", [])
	_assert(lines.size() == CombatEngine.MAX_LOG_LINES, "Combat logs should stay bounded so state copies do not grow over long fights")
	_assert(str(lines[0]) == "Line 12", "Bounded combat logs should keep the most recent entries")
	_assert(str(lines[lines.size() - 1]) == "Line 23", "Bounded combat logs should retain the newest entry")

func _test_card_play_action_grants_bonus_play() -> void:
	var starter_has_draw: bool = false
	var starter_has_card_play: bool = false
	var starter_has_illusion: bool = false
	for card_id: String in GameData.starting_deck():
		var starter_card: Dictionary = GameData.card_def(card_id)
		for action_var: Variant in starter_card.get("actions", []):
			if typeof(action_var) != TYPE_DICTIONARY:
				continue
			var action: Dictionary = action_var as Dictionary
			starter_has_draw = starter_has_draw or str(action.get("type", "")) == "draw"
			starter_has_card_play = starter_has_card_play or str(action.get("type", "")) == "card_play"
			starter_has_illusion = starter_has_illusion or str(action.get("type", "")) == "illusion"
	_assert(starter_has_draw, "The starting deck should include at least one draw card")
	_assert(starter_has_card_play, "The starting deck should include at least one card-play card")
	_assert(starter_has_illusion, "The starting deck should include at least one illusion card")
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(1511, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["guarded_step", "quick_stab", "brace"],
		"relics": [],
		"hand_size": 3,
		"heal_bonus": 0
	})
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["guarded_step", "quick_stab", "brace"]
	deck["draw"] = []
	deck["discard"] = []
	state["deck"] = deck
	_assert(combat.cards_remaining_this_turn(state) == 2, "Combat should start with its base card plays available")
	state = combat.apply_player_action(state, {"type": "card_play", "amount": 1})
	_assert(int(state.get("card_play_bonus_this_turn", 0)) == 1, "Card-play actions should track their temporary bonus separately from death rewards")
	_assert(combat.cards_remaining_this_turn(state) == 3, "Card-play actions should increase current turn capacity before the played card is finished")
	state = combat.finish_player_card(state, 0)
	_assert(combat.cards_remaining_this_turn(state) == 2, "Finishing the card should spend one play while preserving the action bonus")
	state = combat.prepare_next_player_turn(state)
	_assert(int(state.get("card_play_bonus_this_turn", 0)) == 0, "Card-play action bonuses should reset on a new player turn")

func _test_flurry_repeats_and_spends_snapshotted_card_plays() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(15111, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["cinder_fusillade"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["cinder_fusillade"]
	deck["draw"] = []
	deck["discard"] = []
	state["deck"] = deck
	state["player"] = {"pos": Vector2i(2, 4), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	state["enemies"] = [
		{"id": 1, "type": "crawler", "pos": Vector2i(3, 4), "hp": 3, "max_hp": 3, "block": 0, "stoneskin": 0},
		{"id": 2, "type": "crawler", "pos": Vector2i(4, 4), "hp": 20, "max_hp": 20, "block": 0, "stoneskin": 0}
	]
	var actions: Array = combat.card_play_actions("cinder_fusillade", state)
	_assert(actions.size() == 4, "Flurry should repeat its full printed action package once for each of the two base card plays")
	_assert(combat.card_plays_spent_for_actions(actions) == 2, "Repeated Flurry actions should preserve the snapshotted spend count")
	state = combat.apply_player_action(state, actions[0] as Dictionary)
	state = combat.apply_player_action(state, actions[1] as Dictionary, Vector2i(3, 4))
	state = combat.apply_player_action(state, actions[2] as Dictionary)
	state = combat.apply_player_action(state, actions[3] as Dictionary, Vector2i(4, 4))
	state = combat.finish_player_card(state, 0, combat.card_plays_spent_for_actions(actions))
	_assert(int(state.get("cards_played_this_turn", 0)) == 2, "Flurry should spend every card play it snapshotted")
	_assert(int(state.get("player_turn_time_spent", 0)) == 5, "Flurry should pay its top-level time cost only once")
	_assert(combat.cards_remaining_this_turn(state) == 1, "A kill-granted play created during Flurry should remain available after the snapshotted plays are spent")
	_assert(int((state.get("elemental_intensity", {}) as Dictionary).get("fire", 0)) == 2, "Each Flurry copy should resolve its intensity action")
	_assert(int(((state.get("enemies", []) as Array)[1] as Dictionary).get("hp", 0)) == 17, "Each Flurry copy should resolve its attack against the selected target")
	var bonus_state: Dictionary = state.duplicate(true)
	bonus_state["cards_played_this_turn"] = 0
	bonus_state["death_bonus_card_plays_this_turn"] = 0
	bonus_state["card_play_bonus_this_turn"] = 1
	var bonus_actions: Array = combat.card_play_actions("cinder_fusillade", bonus_state)
	_assert(bonus_actions.size() == 6, "Card-play bonuses should directly increase every action in a later Flurry's repeat count")
	var cost_state: Dictionary = combat.create_combat(15113, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["bloody_lunge"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var cost_deck: Dictionary = (cost_state.get("deck", {}) as Dictionary).duplicate(true)
	cost_deck["hand"] = ["bloody_lunge"]
	cost_deck["draw"] = []
	cost_deck["discard"] = []
	cost_state["deck"] = cost_deck
	cost_state["player"] = {"pos": Vector2i(2, 4), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	cost_state = combat.finish_player_card(cost_state, 0, 2)
	_assert(int((cost_state.get("player", {}) as Dictionary).get("hp", 0)) == 22, "A two-copy Flurry commit should pay a printed health cost for both copies")
	_assert(int(cost_state.get("player_turn_time_spent", 0)) == 8, "A two-copy Flurry commit should still pay the printed Time only once")

func _test_starting_deck_uses_hamstring_shot_over_bone_dart() -> void:
	var valid_card_rarities: Dictionary = {
		"common": true,
		"rare": true,
		"epic": true,
		"legendary": true
	}
	var card_rarity_counts: Dictionary = {}
	for card_id_var: Variant in GameData.cards().keys():
		var card_id: String = str(card_id_var)
		var rarity: String = str(GameData.card_def(card_id).get("rarity", ""))
		_assert(valid_card_rarities.has(rarity), "%s should use the shared card rarity set" % card_id)
		card_rarity_counts[rarity] = int(card_rarity_counts.get(rarity, 0)) + 1
	for rarity: String in GameData.CARD_RARITY_TIERS:
		_assert(int(card_rarity_counts.get(rarity, 0)) > 0, "Card data should include %s cards" % rarity)
	var starting_deck: Array = GameData.starting_deck()
	_assert(starting_deck.has("hamstring_shot"), "Hamstring Shot should replace the plain ranged starter in the starting deck")
	_assert(not starting_deck.has("bone_dart"), "Bone Dart should stay out of the starting deck while retired")
	_assert(bool(GameData.card_def("hamstring_shot").get("starter", false)), "Hamstring Shot should be marked as a starter card")
	_assert(str(GameData.card_def("hamstring_shot").get("rarity", "")) == "common", "Starter Hamstring Shot should use common rarity plus starter metadata")
	_assert(not bool(GameData.card_def("bone_dart").get("starter", false)), "Bone Dart should not be marked as an active starter card")
	var reward_pool: Dictionary = GameData.reward_card_pool_by_rarity()
	for rarity: String in GameData.CARD_RARITY_TIERS:
		var cards: Array = reward_pool.get(rarity, [])
		_assert(not cards.has("bone_dart"), "Bone Dart should stay out of reward offers while retired")
		_assert(not cards.has("hamstring_shot"), "Starter Hamstring Shot should stay out of reward offers")
		for magic_card_id: String in ["pale_spark", "dull_bolt", "waning_pulse"]:
			_assert(not cards.has(magic_card_id), "Default attuned magic should stay out of combat reward offers")
	var elemental_reward_pool: Dictionary = GameData.reward_card_pool_by_rarity("", true)
	var elemental_reward_ids: Array = []
	for rarity: String in GameData.CARD_RARITY_TIERS:
		for card_id_var: Variant in elemental_reward_pool.get(rarity, []):
			elemental_reward_ids.append(str(card_id_var))
	_assert(elemental_reward_ids.has("threaded_path"), "Threaded Path should be a live elemental speed reward")
	_assert(GameData.card_element("threaded_path") == ElementData.AIR, "Threaded Path should be an Air reward card")
	_assert((elemental_reward_pool.get("legendary", []) as Array).has("wildfire_halo"), "Elemental rewards should include legendary magic capstones")
	var elemental_reward_times: Dictionary = {}
	for card_id_var: Variant in elemental_reward_ids:
		var card_id: String = str(card_id_var)
		elemental_reward_times[int(GameData.card_def(card_id).get("time", 5))] = true
	for required_time: int in [1, 2, 3, 9, 10]:
		_assert(bool(elemental_reward_times.get(required_time, false)), "Elemental reward pool should include a time-%d card" % required_time)

func _test_equipment_run_state_and_reward_cards(default_progression: Dictionary) -> void:
	var engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = engine.create_new_run(45, default_progression)
	_assert((run_state.get("deck_cards", []) as Array) == GameData.starting_deck(), "Fresh runs should compile their deck from starter equipment plus attuned magic")
	_assert((run_state.get("reward_cards", []) as Array).is_empty(), "Fresh runs should track collected reward magic separately from equipment")
	_assert((run_state.get("attuned_magic_cards", []) as Array) == GameData.starting_magic_cards(), "Fresh runs should start with six bland attuned magic cards")
	_assert((run_state.get("magic_inventory", []) as Array).is_empty(), "Fresh runs should start with no reserve magic")
	_assert((run_state.get("equipment_inventory", []) as Array).is_empty(), "Fresh runs should not duplicate equipped starter gear into inventory")
	_assert((run_state.get("item_inventory", []) as Array).is_empty(), "Fresh runs should start with no consumable item inventory")
	_assert((run_state.get("equipped_items", []) as Array).is_empty(), "Fresh runs should start with no equipped consumable items")
	_assert(engine.loadout_unread_count(run_state) == 0, "Fresh runs should not badge the starter loadout as new")
	_assert(engine.loadout_new_asset_ids(run_state, "equipment").is_empty(), "Fresh runs should not tag starter equipment as new")
	_assert(engine.loadout_new_asset_ids(run_state, "magic").is_empty(), "Fresh runs should not tag starter magic as new")
	_assert(int(run_state.get("equipment_drop_misses", -1)) == 0, "Fresh runs should start equipment pity from zero misses")
	var equipped: Dictionary = run_state.get("equipped_equipment", {}) as Dictionary
	for slot: String in GameData.equipment_slots():
		_assert(not str(equipped.get(slot, "")).is_empty(), "Fresh runs should equip a starter %s" % slot)
	for starter_id_var: Variant in GameData.starter_equipment_ids():
		_assert((run_state.get("collected_equipment", []) as Array).has(str(starter_id_var)), "Fresh runs should mark starter equipment as collected")
	_assert(GameData.item_loadout_limit() == 2, "Item loadout should cap at two equipped consumables")
	var item_card_ids: Array = GameData.item_card_ids()
	_assert(item_card_ids.size() >= 10, "Scavenger item pool should start with at least ten consumables")
	for item_card_id_var: Variant in item_card_ids:
		var item_card_id: String = str(item_card_id_var)
		var item_card: Dictionary = GameData.card_def(item_card_id)
		_assert(bool(item_card.get("item", false)), "%s should be marked as an item card" % item_card_id)
		_assert(GameData.card_consumes_on_play(item_card_id), "%s should be consumed after one play" % item_card_id)
		_assert(not bool(item_card.get("reward_pool", true)), "%s should stay out of normal card rewards" % item_card_id)
		_assert(FileAccess.file_exists(str(item_card.get("art_path", ""))), "%s item card art should exist" % item_card_id)
	var item_reward_pool: Dictionary = GameData.reward_card_pool_by_rarity()
	for rarity: String in GameData.CARD_RARITY_TIERS:
		_assert(not (item_reward_pool.get(rarity, []) as Array).has("crimson_draught"), "Consumable items should not appear in normal reward pools")
	_assert(not GameData.upgradeable_card_ids().has("crimson_draught"), "Consumable items should not appear in the upgrade pool")
	var deck_with_item: Array = GameData.compile_deck_cards(equipped, GameData.starting_magic_cards(), ["crimson_draught"])
	_assert(deck_with_item.has("crimson_draught") and deck_with_item.size() == GameData.starting_deck().size() + 1, "Equipped item cards should compile into the active deck")

	var reward_state: Dictionary = engine.claim_card_reward(run_state, "spark_dart")
	_assert((reward_state.get("reward_cards", []) as Array) == ["spark_dart"], "Claimed card rewards should still append to reward_cards for collection history")
	_assert((reward_state.get("magic_inventory", []) as Array) == ["spark_dart"], "Claimed card rewards should enter reserve magic")
	_assert(engine.loadout_unread_ids(reward_state, "magic") == ["spark_dart"], "Claimed card rewards should mark the Magic loadout tab unread")
	_assert(engine.loadout_new_asset_ids(reward_state, "magic") == ["spark_dart"], "Claimed card rewards should tag the learned spell as new")
	_assert(engine.loadout_unread_count(reward_state) == 1, "A claimed reward spell should add one loadout notification")
	var reward_seen_state: Dictionary = engine.clear_loadout_unread(reward_state, "magic")
	_assert(engine.loadout_unread_count(reward_seen_state) == 0, "Opening Magic should clear its loadout notifications")
	_assert(engine.loadout_asset_is_new(reward_seen_state, "magic", "spark_dart"), "Opening Magic should preserve the spell's NEW tag until that spell is hovered")
	var reward_hovered_state: Dictionary = engine.mark_loadout_asset_seen(reward_seen_state, "magic", "spark_dart")
	_assert(not engine.loadout_asset_is_new(reward_hovered_state, "magic", "spark_dart"), "Hovering a new spell should clear only its asset tag")
	_assert(not (reward_state.get("deck_cards", []) as Array).has("spark_dart"), "Claimed rewards should stay inactive until attuned")
	_assert((reward_state.get("deck_cards", []) as Array).size() == GameData.starting_deck().size(), "Claimed reserve magic should not grow the active deck")
	var attuned_state: Dictionary = engine.swap_magic_card(reward_state, 0, 0)
	_assert(str((attuned_state.get("attuned_magic_cards", []) as Array)[0]) == "spark_dart", "Swapping reserve magic should update the attuned slot")
	_assert((attuned_state.get("magic_inventory", []) as Array).has("pale_spark"), "Swapping magic should move the replaced default card to reserve")
	_assert((attuned_state.get("deck_cards", []) as Array).has("spark_dart"), "Attuned reward magic should enter the active deck")
	_assert((attuned_state.get("deck_cards", []) as Array).size() == GameData.starting_deck().size(), "Attuning magic should keep the active deck capped")
	var blocked_magic_state: Dictionary = reward_state.duplicate(true)
	blocked_magic_state["mode"] = "combat"
	var blocked_magic_swap: Dictionary = engine.swap_magic_card(blocked_magic_state, 0, 0)
	_assert(not (blocked_magic_swap.get("deck_cards", []) as Array).has("spark_dart"), "Magic swaps should be locked during combat")

	var migrated_claim_state: Dictionary = run_state.duplicate(true)
	migrated_claim_state["reward_cards"] = ["spark_dart", "frostbolt", "firebrand_volley", "chain_bolt"]
	migrated_claim_state.erase("attuned_magic_cards")
	migrated_claim_state.erase("magic_inventory")
	migrated_claim_state["pending_reward"] = {"cards": ["static_lash"]}
	migrated_claim_state["mode"] = "reward"
	var migrated_claimed_state: Dictionary = engine.claim_card_reward(migrated_claim_state, "static_lash")
	var migrated_claimed_attuned: Array = migrated_claimed_state.get("attuned_magic_cards", []) as Array
	_assert(str(migrated_claimed_attuned[4]) == "pale_spark", "Claiming magic in older in-progress runs should repair default attuned slots before adding the new reserve card")
	_assert((migrated_claimed_state.get("magic_inventory", []) as Array) == ["static_lash"], "Claiming magic in older in-progress runs should leave the new card in reserve")
	var late_default_swap_state: Dictionary = engine.swap_magic_card(migrated_claimed_state, 0, 4)
	var late_default_attuned: Array = late_default_swap_state.get("attuned_magic_cards", []) as Array
	_assert(str(late_default_attuned[4]) == "static_lash", "Reserve magic should be swappable into late default magic slots")
	_assert((late_default_swap_state.get("magic_inventory", []) as Array).has("pale_spark"), "Swapping into a late default slot should return that default magic to reserve")

	var item_state: Dictionary = run_state.duplicate(true)
	item_state["item_inventory"] = ["crimson_draught", "nail_bomb", "smoke_bomb"]
	item_state = engine.equip_item_card(item_state, 0)
	_assert((item_state.get("equipped_items", []) as Array).has("crimson_draught"), "Equipping an item should move it into equipped item slots")
	_assert(not (item_state.get("item_inventory", []) as Array).has("crimson_draught"), "Equipped item cards should leave item inventory")
	_assert((item_state.get("deck_cards", []) as Array).has("crimson_draught"), "Equipped item cards should enter the active deck")
	item_state = engine.equip_item_card(item_state, 0)
	_assert((item_state.get("equipped_items", []) as Array).has("nail_bomb"), "A second item can be equipped")
	var full_item_state: Dictionary = engine.equip_item_card(item_state, 0)
	_assert(not (full_item_state.get("equipped_items", []) as Array).has("smoke_bomb"), "A third item should not equip while both item slots are full")
	var stowed_item_state: Dictionary = engine.unequip_item_card(item_state, 0)
	_assert(not (stowed_item_state.get("equipped_items", []) as Array).has("crimson_draught"), "Stowing an item should remove it from equipped item slots")
	_assert((stowed_item_state.get("item_inventory", []) as Array).has("crimson_draught"), "Stowed item cards should return to item inventory")
	_assert(not (stowed_item_state.get("deck_cards", []) as Array).has("crimson_draught"), "Stowed item cards should leave the active deck")
	var consumed_item_state: Dictionary = engine.consume_equipped_item_card(item_state, "nail_bomb")
	_assert(not (consumed_item_state.get("equipped_items", []) as Array).has("nail_bomb"), "Consumed item cards should leave equipped item slots")
	_assert(not (consumed_item_state.get("item_inventory", []) as Array).has("nail_bomb"), "Consumed item cards should not return to item inventory")
	_assert(not (consumed_item_state.get("deck_cards", []) as Array).has("nail_bomb"), "Consumed item cards should leave future decks")
	var combat_item_state: Dictionary = item_state.duplicate(true)
	combat_item_state["mode"] = "combat"
	var blocked_item_state: Dictionary = engine.equip_item_card(combat_item_state, 0)
	_assert((blocked_item_state.get("equipped_items", []) as Array) == (item_state.get("equipped_items", []) as Array), "Item loadout changes should be locked during combat")

	var legacy_state: Dictionary = run_state.duplicate(true)
	legacy_state.erase("reward_cards")
	legacy_state.erase("attuned_magic_cards")
	legacy_state.erase("magic_inventory")
	legacy_state.erase("equipment_inventory")
	legacy_state.erase("equipped_equipment")
	legacy_state.erase("collected_equipment")
	legacy_state.erase("equipment_drop_misses")
	var legacy_deck: Array = GameData.compile_deck_cards(GameData.starting_equipped_equipment(), [])
	legacy_deck.append("spark_dart")
	legacy_deck.append("frostbolt")
	legacy_state["deck_cards"] = legacy_deck
	var repaired_state: Dictionary = engine.repair_loaded_run_state(legacy_state)
	_assert((repaired_state.get("reward_cards", []) as Array) == ["spark_dart", "frostbolt"], "Legacy decks should migrate non-equipment cards into reward_cards")
	_assert(str((repaired_state.get("attuned_magic_cards", []) as Array)[0]) == "spark_dart", "Legacy reward migration should preserve the first collected cards as attuned magic")
	_assert(str((repaired_state.get("attuned_magic_cards", []) as Array)[1]) == "frostbolt", "Legacy reward migration should preserve collected reward order")
	_assert((repaired_state.get("attuned_magic_cards", []) as Array).size() == GameData.magic_loadout_limit(), "Legacy reward migration should fill remaining attuned slots with default magic")
	_assert((repaired_state.get("deck_cards", []) as Array).has("spark_dart"), "Legacy reward migration should preserve capped collected cards in the active deck")
	_assert(int(repaired_state.get("equipment_drop_misses", -1)) == RunEngine.EQUIPMENT_DROP_PITY_MISSES, "Loaded runs without equipment pity state should guarantee the next eligible equipment drop")

	var dry_room: Dictionary = {
		"coord": Vector2i(1, 0),
		"depth": 1,
		"type": "combat",
		"element": ElementData.FIRE,
		"cleared": false
	}
	var no_pity_state: Dictionary = run_state.duplicate(true)
	no_pity_state["equipment_drop_misses"] = 0
	_assert(str(engine.call("_equipment_drop_for_room", no_pity_state, dry_room)).is_empty(), "Dry equipment rolls should still miss before pity")
	var pity_state: Dictionary = run_state.duplicate(true)
	pity_state["equipment_drop_misses"] = RunEngine.EQUIPMENT_DROP_PITY_MISSES
	_assert(not str(engine.call("_equipment_drop_for_room", pity_state, dry_room)).is_empty(), "Equipment pity should force a drop after consecutive misses")
	var reset_pity_state: Dictionary = engine.call("_record_equipment_drop_attempt", pity_state, {
		"loot": [{"kind": "equipment", "equipment_id": "iron_cleaver", "pos": Vector2i(3, 3)}]
	})
	_assert(int(reset_pity_state.get("equipment_drop_misses", -1)) == 0, "Placed equipment drops should reset equipment pity")
	var missed_pity_state: Dictionary = engine.call("_record_equipment_drop_attempt", no_pity_state, {"loot": []})
	_assert(int(missed_pity_state.get("equipment_drop_misses", -1)) == 1, "Eligible rooms without equipment should advance equipment pity")

	var collected: Array = (run_state.get("collected_equipment", []) as Array).duplicate()
	collected.append("iron_cleaver")
	run_state["equipment_inventory"] = ["iron_cleaver"]
	run_state["collected_equipment"] = collected
	var swapped_state: Dictionary = engine.equip_equipment(run_state, "iron_cleaver")
	var swapped_equipped: Dictionary = swapped_state.get("equipped_equipment", {}) as Dictionary
	var swapped_inventory: Array = swapped_state.get("equipment_inventory", []) as Array
	var swapped_deck: Array = swapped_state.get("deck_cards", []) as Array
	_assert(str(swapped_equipped.get("weapon", "")) == "iron_cleaver", "Equipping a weapon should update the active slot")
	_assert(swapped_inventory.has("training_sword"), "The replaced equipment should move back into inventory")
	_assert(not swapped_inventory.has("iron_cleaver"), "The newly equipped item should leave inventory")
	_assert(swapped_deck.has("cleaver_hook") and swapped_deck.has("needle_flurry") and swapped_deck.has("butcher_chop"), "Equipping an item should add its cards to the active deck")
	_assert(not swapped_deck.has("whirlwind_slash") and not swapped_deck.has("bloody_lunge"), "Equipping an item should remove the previous slot's unique cards")

	var combat_state: Dictionary = swapped_state.duplicate(true)
	combat_state["mode"] = "combat"
	var combat_inventory: Array = swapped_inventory.duplicate()
	combat_inventory.append("ward_kite")
	combat_state["equipment_inventory"] = combat_inventory
	var combat_collected: Array = (combat_state.get("collected_equipment", []) as Array).duplicate()
	combat_collected.append("ward_kite")
	combat_state["collected_equipment"] = combat_collected
	var blocked_state: Dictionary = engine.equip_equipment(combat_state, "ward_kite")
	_assert(str((blocked_state.get("equipped_equipment", {}) as Dictionary).get("offhand", "")) == str(swapped_equipped.get("offhand", "")), "Equipment should not change during combat")
	_assert((blocked_state.get("equipment_inventory", []) as Array).has("ward_kite"), "Blocked equipment changes should leave inventory intact")

	var available_before: Array = engine.call("_available_equipment_drop_ids", run_state)
	_assert(available_before.has("ward_kite"), "Uncollected equipment should be eligible for future drops")
	var collected_state: Dictionary = run_state.duplicate(true)
	collected_state["collected_equipment"] = GameData.starter_equipment_ids() + ["ward_kite"]
	var available_after: Array = engine.call("_available_equipment_drop_ids", collected_state)
	_assert(not available_after.has("ward_kite"), "Collected equipment should not appear in future drop pools")

func _test_equipment_collection_to_equip_deck_flow(default_progression: Dictionary) -> void:
	var run_engine: RunEngine = RunEngine.new()
	var combat_engine: CombatEngine = CombatEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(74, default_progression)
	var layout: Dictionary = _simple_room_layout()
	var equipment_tile := Vector2i(3, 4)
	layout["loot"] = [{
		"kind": "equipment",
		"equipment_id": "ward_kite",
		"pos": equipment_tile
	}]
	var combat_state: Dictionary = combat_engine.create_combat(74, layout, {
		"hp": int(run_state.get("player_hp", 1)),
		"max_hp": int(run_state.get("player_max_hp", 1)),
		"deck_cards": (run_state.get("deck_cards", []) as Array).duplicate(),
		"relics": [],
		"hand_size": int(run_state.get("hand_size", 5)),
		"heal_bonus": int(run_state.get("heal_bonus", 0)),
		"cards_per_turn": 2,
		"draw_per_turn": 2,
		"card_upgrades": {},
		"card_mods": {}
	})
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	combat_state = combat_engine.apply_player_action(combat_state, {"type": "blink", "range": 99}, equipment_tile)
	_assert((combat_state.get("collected_equipment", []) as Array).has("ward_kite"), "Walking onto equipment loot should record the picked-up equipment in combat state")
	var claimed_loot: Dictionary = _first_loot_of_kind(combat_state, "equipment")
	_assert(bool(claimed_loot.get("claimed", false)), "Equipment loot should be marked claimed after pickup")
	run_state = run_engine.set_combat_state(run_state, combat_state)
	_assert((run_state.get("equipment_inventory", []) as Array).has("ward_kite"), "Collected combat equipment should merge into run inventory")
	_assert((run_state.get("collected_equipment", []) as Array).has("ward_kite"), "Collected combat equipment should be remembered for duplicate-drop exclusion")
	_assert(run_engine.loadout_unread_ids(run_state, "equipment") == ["ward_kite"], "Combat equipment pickups should mark the Gear loadout tab unread")
	_assert(run_engine.loadout_new_asset_ids(run_state, "equipment") == ["ward_kite"], "Combat equipment pickups should tag the collected gear as new")
	_assert(run_engine.loadout_unread_count(run_state) == 1, "A combat equipment pickup should add one loadout notification")
	var pre_equip_deck: Array = run_state.get("deck_cards", []) as Array
	_assert(pre_equip_deck.has("brace") and pre_equip_deck.has("guarded_step"), "Picking up equipment should not rebuild the deck until it is equipped")
	_assert(not pre_equip_deck.has("kite_bash"), "Picked-up equipment cards should stay inactive while the item is only in inventory")
	run_state["mode"] = "room"
	run_state = run_engine.equip_equipment(run_state, "ward_kite")
	var equipped: Dictionary = run_state.get("equipped_equipment", {}) as Dictionary
	var post_equip_deck: Array = run_state.get("deck_cards", []) as Array
	_assert(str(equipped.get("offhand", "")) == "ward_kite", "Equipping collected equipment should update the matching slot")
	_assert((run_state.get("equipment_inventory", []) as Array).has("splintered_shield"), "Equipping collected gear should move the replaced starter item into inventory")
	_assert(post_equip_deck.has("kite_bash") and post_equip_deck.has("warded_advance"), "Equipping collected gear should add its cards to the active deck")
	_assert(not post_equip_deck.has("brace") and not post_equip_deck.has("guarded_step"), "Equipping collected gear should remove the previous slot's cards from the active deck")

func _test_missed_equipment_resolution_and_persistence(default_progression: Dictionary) -> void:
	var run_engine: RunEngine = RunEngine.new()
	var combat_engine: CombatEngine = CombatEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(7401, default_progression)
	var deck_before: Array = (run_state.get("deck_cards", []) as Array).duplicate()
	var layout: Dictionary = _simple_room_layout()
	layout["loot"] = [
		{"id": "missed_gear", "kind": "equipment", "equipment_id": "ward_kite", "pos": Vector2i(5, 3)},
		{"id": "collected_gear", "kind": "equipment", "equipment_id": "iron_cleaver", "pos": Vector2i(3, 4), "claimed": true},
		{"id": "mixed_heal", "kind": "healing_vial", "amount": 40, "pos": Vector2i(4, 3)},
		{"id": "mixed_shield", "kind": "rusty_shield", "amount": 30, "pos": Vector2i(4, 4)},
		{"id": "mixed_embers", "kind": "dropped_embers", "amount": 17, "pos": Vector2i(5, 4)}
	]
	var combat_state: Dictionary = combat_engine.create_combat(7401, layout, {
		"hp": int(run_state.get("player_hp", 1)),
		"max_hp": int(run_state.get("player_max_hp", 1)),
		"deck_cards": deck_before,
		"relics": [],
		"hand_size": int(run_state.get("hand_size", 5)),
		"heal_bonus": int(run_state.get("heal_bonus", 0)),
		"cards_per_turn": 2,
		"draw_per_turn": 2,
		"card_upgrades": {},
		"card_mods": {}
	})
	combat_state["collected_equipment"] = ["iron_cleaver"]
	var enemies: Array = combat_state.get("enemies", []) as Array
	for index: int in range(enemies.size()):
		var enemy: Dictionary = (enemies[index] as Dictionary).duplicate(true)
		enemy["hp"] = 0
		enemies[index] = enemy
	combat_state["enemies"] = enemies
	var visible_entries: Array[String] = GrimoireLibrary.entry_ids_for_combat_state(combat_state)
	_assert(not visible_entries.has(GrimoireLibrary.equipment_entry_id("ward_kite")), "Merely seeing unclaimed equipment should not discover it in the Grimoire")
	_assert(visible_entries.has(GrimoireLibrary.equipment_entry_id("iron_cleaver")), "Collected equipment should still be eligible for Grimoire discovery")

	var resolved_combat: Dictionary = combat_engine.resolve_missed_equipment_after_victory(combat_state)
	_assert((resolved_combat.get("missed_equipment", []) as Array) == ["ward_kite"], "Victory should classify only still-unclaimed equipment as missed")
	_assert(not GrimoireLibrary.entry_ids_for_combat_state(resolved_combat).has(GrimoireLibrary.equipment_entry_id("ward_kite")), "Resolved missed equipment should remain excluded from Grimoire discovery")
	var resolved_loot: Array = resolved_combat.get("loot", []) as Array
	for loot_var: Variant in resolved_loot:
		var loot: Dictionary = loot_var as Dictionary
		if str(loot.get("id", "")) == "missed_gear":
			_assert(bool(loot.get("claimed", false)) and str(loot.get("resolution", "")) == "missed", "Missed equipment should be visibly resolved instead of remaining actionable")
		elif str(loot.get("id", "")) == "collected_gear":
			_assert(str(loot.get("resolution", "")) != "missed", "Already collected equipment should not be replayed or classified as missed")
		elif str(loot.get("id", "")).begins_with("mixed_"):
			_assert(not bool(loot.get("claimed", false)), "Victory should leave non-equipment tactical pickup state unchanged")

	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	run_state = run_engine.set_combat_state(run_state, combat_state)
	_assert((run_state.get("equipment_inventory", []) as Array).count("iron_cleaver") == 1, "Collected gear should be awarded once before victory")
	var reward_state: Dictionary = run_engine.finish_combat(run_state, combat_state)
	_assert(str(reward_state.get("mode", "")) == "reward", "Missed-equipment victory should still reach the normal reward boundary")
	_assert(str(reward_state.get("notice", "")) == RunEngine.MISSED_EQUIPMENT_NOTICE, "Reward state should show the terse missed-gear notice")
	_assert((reward_state.get("equipment_inventory", []) as Array).count("iron_cleaver") == 1, "Finishing combat should not award already collected gear twice")
	_assert(not (reward_state.get("equipment_inventory", []) as Array).has("ward_kite"), "Unclaimed equipment should never enter inventory")
	_assert(not (reward_state.get("collected_equipment", []) as Array).has("ward_kite"), "Unclaimed equipment should never enter collected ownership")
	_assert((reward_state.get("deck_cards", []) as Array) == deck_before, "Missed equipment should never alter the deck")
	_assert(not GrimoireLibrary.entry_ids_for_run_state(reward_state).has(GrimoireLibrary.equipment_entry_id("ward_kite")), "Missed equipment should never enter Grimoire discovery through the reward state")
	var cleared_layout: Dictionary = reward_state.get("current_room_layout", {}) as Dictionary
	var unclaimed_equipment_count: int = 0
	for loot_var: Variant in cleared_layout.get("loot", []):
		var loot: Dictionary = loot_var as Dictionary
		if str(loot.get("kind", "")) == "equipment" and not bool(loot.get("claimed", false)):
			unclaimed_equipment_count += 1
	_assert(unclaimed_equipment_count == 0, "Cleared current_room_layout should contain no stale actionable equipment pickup")
	for mixed_id: String in ["mixed_heal", "mixed_shield", "mixed_embers"]:
		var mixed_loot: Dictionary = {}
		for loot_var: Variant in cleared_layout.get("loot", []):
			if str((loot_var as Dictionary).get("id", "")) == mixed_id:
				mixed_loot = loot_var as Dictionary
				break
		_assert(not mixed_loot.is_empty() and not bool(mixed_loot.get("claimed", false)), "Cleared layout should preserve non-equipment pickup %s unchanged" % mixed_id)

	_assert(ProgressionStore.save_run_state(reward_state), "Reward-boundary missed-equipment state should save")
	var resumed_state: Dictionary = run_engine.repair_loaded_run_state(ProgressionStore.load_saved_run())
	_assert((resumed_state.get("equipment_inventory", []) as Array).count("iron_cleaver") == 1, "Reward-boundary resume should preserve collected gear exactly once")
	_assert(not (resumed_state.get("equipment_inventory", []) as Array).has("ward_kite"), "Reward-boundary resume should not restore missed gear")
	var resumed_layout: Dictionary = resumed_state.get("current_room_layout", {}) as Dictionary
	for loot_var: Variant in resumed_layout.get("loot", []):
		var loot: Dictionary = loot_var as Dictionary
		_assert(str(loot.get("kind", "")) != "equipment" or bool(loot.get("claimed", false)), "Reward-boundary resume should not restore stale equipment pickups")
	ProgressionStore.clear_saved_run()

	AnalyticsStore.clear_storage()
	var analytics_scene: Node = RunSceneScript.new()
	analytics_scene.set("_run_state", reward_state)
	analytics_scene.call("_analytics_log_combat_ended", resolved_combat, "missed_equipment_test")
	var events: Array[Dictionary] = AnalyticsStore.load_all_events()
	var combat_end_events: Array[Dictionary] = _analytics_events_by_type(events, "combat_ended")
	_assert(combat_end_events.size() == 1, "Missed-equipment victory should emit one combat_ended event")
	if not combat_end_events.is_empty():
		var payload: Dictionary = (combat_end_events[0] as Dictionary).get("payload", {}) as Dictionary
		_assert((payload.get("missed_equipment", []) as Array) == ["ward_kite"], "combat_ended should include the additive missed_equipment id list")
		_assert((payload.get("collected_equipment", []) as Array) == ["iron_cleaver"], "combat_ended should keep collected equipment separate from missed equipment")
	analytics_scene.free()

func _test_merchant_room_placement_and_trading(default_progression: Dictionary) -> void:
	var run_engine: RunEngine = RunEngine.new()
	var purchase_budget: int = 600
	var first_level_cost: int = ProgressionStore.next_level_cost(default_progression)
	_assert(run_engine.merchant_buy_cost(RunEngine.MERCHANT_BLACKSMITH, "iron_cleaver") == 150, "Common blacksmith gear should require saving across multiple combats")
	_assert(run_engine.merchant_buy_cost(RunEngine.MERCHANT_BLACKSMITH, "duelist_rapier") > first_level_cost, "Rare blacksmith gear should compete with the first level-up")
	_assert(run_engine.merchant_buy_cost(RunEngine.MERCHANT_BLACKSMITH, "grave_greatsword") == 360, "Epic blacksmith gear should cost multiple early level-up budgets")
	_assert(run_engine.merchant_buy_cost(RunEngine.MERCHANT_BLACKSMITH, "crown_of_thorns") == 540, "Legendary blacksmith gear should be a major ember commitment")
	_assert(run_engine.merchant_buy_cost(RunEngine.MERCHANT_ARCANIST, "spark_dart") == 110, "Common arcanist magic should no longer be affordable from one or two enemy kills")
	_assert(run_engine.merchant_buy_cost(RunEngine.MERCHANT_ARCANIST, "battle_rhythm") == 175, "Rare arcanist magic should nearly match the first level-up")
	_assert(run_engine.merchant_buy_cost(RunEngine.MERCHANT_ARCANIST, "blood_price") == 265, "Epic arcanist magic should exceed the first level-up")
	_assert(run_engine.merchant_buy_cost(RunEngine.MERCHANT_ARCANIST, "wildfire_halo") == 400, "Legendary arcanist magic should demand deep-run savings")
	_assert(run_engine.merchant_buy_cost(RunEngine.MERCHANT_SCAVENGER, "crimson_draught") == 90, "Common Scavenger items should require saving across multiple combats")
	_assert(run_engine.merchant_buy_cost(RunEngine.MERCHANT_SCAVENGER, "mossglass_elixir") == 145, "Rare Scavenger items should create a real level-up tradeoff")
	_assert(run_engine.merchant_buy_cost(RunEngine.MERCHANT_SCAVENGER, "storm_jar") == 220, "Epic Scavenger items should exceed the first level-up")
	_assert(run_engine.merchant_sell_value(RunEngine.MERCHANT_BLACKSMITH, "ward_kite") == 53, "Merchant resale should be useful but well below buy price")
	var blacksmith_state: Dictionary = {}
	var blacksmith_coord: Vector2i = Vector2i(999, 999)
	var arcanist_state: Dictionary = {}
	var arcanist_coord: Vector2i = Vector2i(999, 999)
	var scavenger_state: Dictionary = {}
	var scavenger_coord: Vector2i = Vector2i(999, 999)
	for seed: int in range(1, 90):
		var run_state: Dictionary = run_engine.create_new_run(seed, default_progression)
		if blacksmith_coord.x >= 900:
			var smith_coord: Vector2i = _first_room_coord_of_type(run_engine, run_state, "blacksmith")
			if smith_coord.x < 900:
				blacksmith_coord = smith_coord
				blacksmith_state = run_state
		if arcanist_coord.x >= 900:
			var mage_coord: Vector2i = _first_room_coord_of_type(run_engine, run_state, "arcanist")
			if mage_coord.x < 900:
				arcanist_coord = mage_coord
				arcanist_state = run_state
		if scavenger_coord.x >= 900:
			var scav_coord: Vector2i = _first_room_coord_of_type(run_engine, run_state, "scavenger")
			if scav_coord.x < 900:
				scavenger_coord = scav_coord
				scavenger_state = run_state
		if blacksmith_coord.x < 900 and arcanist_coord.x < 900 and scavenger_coord.x < 900:
			break
	_assert(blacksmith_coord.x < 900, "Generated maps should include blacksmith rooms across sampled seeds")
	_assert(arcanist_coord.x < 900, "Generated maps should include arcanist rooms across sampled seeds")
	_assert(scavenger_coord.x < 900, "Generated maps should include scavenger rooms across sampled seeds")

	blacksmith_state["current_room"] = blacksmith_coord
	blacksmith_state["mode"] = "room"
	blacksmith_state = run_engine.set_held_embers(blacksmith_state, purchase_budget)
	_assert(run_engine.merchant_kind_for_current_room(blacksmith_state) == RunEngine.MERCHANT_BLACKSMITH, "Blacksmith room metadata should identify the equipment merchant")
	var blacksmith_offers: Array = run_engine.merchant_offer_ids(blacksmith_state, RunEngine.MERCHANT_BLACKSMITH)
	_assert(blacksmith_offers.size() == RunEngine.MERCHANT_OFFER_COUNT, "Blacksmiths should stock a compact set of equipment")
	var equipment_slot_index: int = 0
	var equipment_id: String = str(blacksmith_offers[equipment_slot_index])
	var equipment_cost: int = run_engine.merchant_buy_cost(RunEngine.MERCHANT_BLACKSMITH, equipment_id)
	var bought_equipment_state: Dictionary = run_engine.buy_merchant_item(blacksmith_state, RunEngine.MERCHANT_BLACKSMITH, equipment_id)
	_assert(int(bought_equipment_state.get("held_embers", 0)) == purchase_budget - equipment_cost, "Buying equipment should spend held embers")
	_assert((bought_equipment_state.get("equipment_inventory", []) as Array).has(equipment_id), "Bought equipment should enter equipment inventory")
	_assert((bought_equipment_state.get("collected_equipment", []) as Array).has(equipment_id), "Bought equipment should count as collected while owned")
	_assert(not run_engine.merchant_sellable_ids(bought_equipment_state, RunEngine.MERCHANT_BLACKSMITH).has(equipment_id), "Bought equipment should not be immediately sellable in the same blacksmith visit")
	var post_buy_blacksmith_offers: Array = run_engine.merchant_offer_ids(bought_equipment_state, RunEngine.MERCHANT_BLACKSMITH)
	_assert(post_buy_blacksmith_offers.size() == RunEngine.MERCHANT_OFFER_COUNT, "Buying equipment should refill only the purchased blacksmith slot")
	_assert(not post_buy_blacksmith_offers.has(equipment_id), "Owned equipment should leave merchant stock")
	for index: int in range(blacksmith_offers.size()):
		if index == equipment_slot_index:
			_assert(str(post_buy_blacksmith_offers[index]) != equipment_id, "Purchased blacksmith slot should receive a replacement offer")
		else:
			_assert(str(post_buy_blacksmith_offers[index]) == str(blacksmith_offers[index]), "Buying equipment should preserve the other blacksmith offer slots")
	var immediate_resell_state: Dictionary = run_engine.sell_merchant_item(bought_equipment_state, RunEngine.MERCHANT_BLACKSMITH, equipment_id)
	_assert((immediate_resell_state.get("equipment_inventory", []) as Array).has(equipment_id), "Bought equipment should stay owned if an immediate resell is attempted")
	_assert(int(immediate_resell_state.get("held_embers", 0)) == purchase_budget - equipment_cost, "Immediate equipment resell attempts should not refund embers")
	_assert(run_engine.merchant_offer_ids(immediate_resell_state, RunEngine.MERCHANT_BLACKSMITH) == post_buy_blacksmith_offers, "Blocked immediate equipment resell should not reroll blacksmith offers")
	var blacksmith_sell_first_state: Dictionary = blacksmith_state.duplicate(true)
	blacksmith_sell_first_state = run_engine.set_held_embers(blacksmith_sell_first_state, purchase_budget)
	blacksmith_sell_first_state["equipment_inventory"] = ["ward_kite"]
	var collected_before_sale: Array = (blacksmith_sell_first_state.get("collected_equipment", []) as Array).duplicate()
	if not collected_before_sale.has("ward_kite"):
		collected_before_sale.append("ward_kite")
	blacksmith_sell_first_state["collected_equipment"] = collected_before_sale
	var blacksmith_sell_first_offers: Array = run_engine.merchant_offer_ids(blacksmith_sell_first_state, RunEngine.MERCHANT_BLACKSMITH)
	var equipment_sale_value: int = run_engine.merchant_sell_value(RunEngine.MERCHANT_BLACKSMITH, "ward_kite")
	var blacksmith_after_sell_first: Dictionary = run_engine.sell_merchant_item(blacksmith_sell_first_state, RunEngine.MERCHANT_BLACKSMITH, "ward_kite")
	_assert(not (blacksmith_after_sell_first.get("equipment_inventory", []) as Array).has("ward_kite"), "Sold spare equipment should leave inventory")
	_assert(not (blacksmith_after_sell_first.get("collected_equipment", []) as Array).has("ward_kite"), "Sold spare equipment should leave duplicate-exclusion ownership")
	_assert(int(blacksmith_after_sell_first.get("held_embers", 0)) == purchase_budget + equipment_sale_value, "Selling spare equipment should add the sell value to held embers")
	_assert(run_engine.merchant_offer_ids(blacksmith_after_sell_first, RunEngine.MERCHANT_BLACKSMITH) == blacksmith_sell_first_offers, "Selling spare equipment should leave blacksmith offers unchanged")
	var blacksmith_after_sell_first_buy: Dictionary = run_engine.buy_merchant_item(blacksmith_after_sell_first, RunEngine.MERCHANT_BLACKSMITH, str(blacksmith_sell_first_offers[0]))
	_assert(not run_engine.merchant_offer_ids(blacksmith_after_sell_first_buy, RunEngine.MERCHANT_BLACKSMITH).has("ward_kite"), "Sold equipment should not be introduced by a later blacksmith restock")
	var regression_blacksmith_state: Dictionary = {}
	var regression_blacksmith_coord: Vector2i = Vector2i(999, 999)
	var blacksmith_route: Array = []
	for seed: int in range(1, 120):
		var candidate_state: Dictionary = run_engine.create_new_run(seed, default_progression)
		var reachable_blacksmith: Dictionary = _first_reachable_room_of_type(run_engine, candidate_state, RunEngine.MERCHANT_BLACKSMITH)
		if not reachable_blacksmith.is_empty():
			regression_blacksmith_state = candidate_state
			regression_blacksmith_coord = reachable_blacksmith.get("coord", Vector2i(999, 999))
			blacksmith_route = (reachable_blacksmith.get("route", []) as Array).duplicate()
			break
	_assert(not blacksmith_route.is_empty(), "Blacksmith regression route should reach the sampled merchant room")
	var visited_blacksmith_state: Dictionary = regression_blacksmith_state.duplicate(true)
	for step_var: Variant in blacksmith_route:
		var step: Vector2i = step_var
		visited_blacksmith_state = _route_state_after_step(run_engine, visited_blacksmith_state, step)
	var visited_blacksmith_room: Dictionary = run_engine.room_metadata(visited_blacksmith_state, regression_blacksmith_coord)
	_assert(visited_blacksmith_room.has(RunEngine.MERCHANT_STOCK_KEY), "Entering a blacksmith room should persist the first-view stock")
	var first_visit_blacksmith_offers: Array = run_engine.merchant_offer_ids(visited_blacksmith_state, RunEngine.MERCHANT_BLACKSMITH)
	var unrelated_equipment_id: String = ""
	for equipment_id_var: Variant in GameData.equipment_ids():
		var candidate_equipment_id: String = str(equipment_id_var)
		if first_visit_blacksmith_offers.has(candidate_equipment_id):
			continue
		if GameData.equipment_slot(candidate_equipment_id).is_empty():
			continue
		if (visited_blacksmith_state.get("equipped_equipment", {}) as Dictionary).values().has(candidate_equipment_id):
			continue
		unrelated_equipment_id = candidate_equipment_id
		break
	_assert(not unrelated_equipment_id.is_empty(), "Equipment pool should include an item outside first-view blacksmith stock")
	if not unrelated_equipment_id.is_empty():
		var unrelated_owned_state: Dictionary = visited_blacksmith_state.duplicate(true)
		var unrelated_inventory: Array = (unrelated_owned_state.get("equipment_inventory", []) as Array).duplicate()
		unrelated_inventory.append(unrelated_equipment_id)
		unrelated_owned_state["equipment_inventory"] = unrelated_inventory
		_assert(run_engine.merchant_offer_ids(unrelated_owned_state, RunEngine.MERCHANT_BLACKSMITH) == first_visit_blacksmith_offers, "First-view blacksmith stock should persist after unrelated ownership changes")
	var externally_owned_offer_id: String = str(first_visit_blacksmith_offers[0])
	var duplicate_owned_state: Dictionary = run_engine.set_held_embers(visited_blacksmith_state.duplicate(true), purchase_budget)
	var duplicate_inventory: Array = (duplicate_owned_state.get("equipment_inventory", []) as Array).duplicate()
	duplicate_inventory.append(externally_owned_offer_id)
	duplicate_owned_state["equipment_inventory"] = duplicate_inventory
	_assert(not run_engine.merchant_offer_ids(duplicate_owned_state, RunEngine.MERCHANT_BLACKSMITH).has(externally_owned_offer_id), "Stored blacksmith stock should hide equipment the player already owns")
	var duplicate_buy_state: Dictionary = run_engine.buy_merchant_item(duplicate_owned_state, RunEngine.MERCHANT_BLACKSMITH, externally_owned_offer_id)
	_assert(int(duplicate_buy_state.get("held_embers", 0)) == purchase_budget, "Blacksmiths should not sell a stored offer that became owned before purchase")

	arcanist_state["current_room"] = arcanist_coord
	arcanist_state["mode"] = "room"
	arcanist_state = run_engine.set_held_embers(arcanist_state, purchase_budget)
	_assert(run_engine.merchant_kind_for_current_room(arcanist_state) == RunEngine.MERCHANT_ARCANIST, "Arcanist room metadata should identify the magic merchant")
	var arcanist_offers: Array = run_engine.merchant_offer_ids(arcanist_state, RunEngine.MERCHANT_ARCANIST)
	_assert(arcanist_offers.size() == RunEngine.MERCHANT_OFFER_COUNT, "Arcanists should stock a compact set of magic cards")
	var magic_slot_index: int = 0
	var card_id: String = str(arcanist_offers[magic_slot_index])
	var magic_cost: int = run_engine.merchant_buy_cost(RunEngine.MERCHANT_ARCANIST, card_id)
	var pre_magic_deck: Array = (arcanist_state.get("deck_cards", []) as Array).duplicate()
	var bought_magic_state: Dictionary = run_engine.buy_merchant_item(arcanist_state, RunEngine.MERCHANT_ARCANIST, card_id)
	_assert(int(bought_magic_state.get("held_embers", 0)) == purchase_budget - magic_cost, "Buying magic should spend held embers")
	_assert((bought_magic_state.get("reward_cards", []) as Array).has(card_id), "Bought magic should enter reward-card history")
	_assert((bought_magic_state.get("magic_inventory", []) as Array).has(card_id), "Bought magic should enter reserve magic")
	_assert((bought_magic_state.get("deck_cards", []) as Array) == pre_magic_deck, "Bought magic should stay inactive until attuned")
	_assert(not run_engine.merchant_sellable_ids(bought_magic_state, RunEngine.MERCHANT_ARCANIST).has(card_id), "Bought magic should not be immediately sellable in the same arcanist visit")
	var post_buy_arcanist_offers: Array = run_engine.merchant_offer_ids(bought_magic_state, RunEngine.MERCHANT_ARCANIST)
	_assert(post_buy_arcanist_offers.size() == RunEngine.MERCHANT_OFFER_COUNT, "Buying magic should refill only the purchased arcanist slot")
	_assert(not post_buy_arcanist_offers.has(card_id), "Bought magic should leave arcanist stock")
	for index: int in range(arcanist_offers.size()):
		if index == magic_slot_index:
			_assert(str(post_buy_arcanist_offers[index]) != card_id, "Purchased arcanist slot should receive a replacement offer")
		else:
			_assert(str(post_buy_arcanist_offers[index]) == str(arcanist_offers[index]), "Buying magic should preserve the other arcanist offer slots")
	var immediate_magic_resell_state: Dictionary = run_engine.sell_merchant_item(bought_magic_state, RunEngine.MERCHANT_ARCANIST, card_id)
	_assert((immediate_magic_resell_state.get("magic_inventory", []) as Array).has(card_id), "Bought magic should stay in reserve if an immediate resell is attempted")
	_assert((immediate_magic_resell_state.get("reward_cards", []) as Array).has(card_id), "Bought magic should stay in reward-card history if an immediate resell is attempted")
	_assert(int(immediate_magic_resell_state.get("held_embers", 0)) == purchase_budget - magic_cost, "Immediate magic resell attempts should not refund embers")
	_assert(run_engine.merchant_offer_ids(immediate_magic_resell_state, RunEngine.MERCHANT_ARCANIST) == post_buy_arcanist_offers, "Blocked immediate magic resell should not reroll arcanist offers")
	var arcanist_sell_first_state: Dictionary = arcanist_state.duplicate(true)
	arcanist_sell_first_state = run_engine.set_held_embers(arcanist_sell_first_state, purchase_budget)
	arcanist_sell_first_state["magic_inventory"] = ["spark_dart"]
	arcanist_sell_first_state["reward_cards"] = ["spark_dart"]
	var arcanist_sell_first_offers: Array = run_engine.merchant_offer_ids(arcanist_sell_first_state, RunEngine.MERCHANT_ARCANIST)
	var magic_sale_value: int = run_engine.merchant_sell_value(RunEngine.MERCHANT_ARCANIST, "spark_dart")
	var arcanist_after_sell_first: Dictionary = run_engine.sell_merchant_item(arcanist_sell_first_state, RunEngine.MERCHANT_ARCANIST, "spark_dart")
	_assert(not (arcanist_after_sell_first.get("magic_inventory", []) as Array).has("spark_dart"), "Sold reserve magic should leave reserve inventory")
	_assert(not (arcanist_after_sell_first.get("reward_cards", []) as Array).has("spark_dart"), "Sold reserve magic should leave reward-card history")
	_assert(int(arcanist_after_sell_first.get("held_embers", 0)) == purchase_budget + magic_sale_value, "Selling magic should add the sell value to held embers")
	_assert(run_engine.merchant_offer_ids(arcanist_after_sell_first, RunEngine.MERCHANT_ARCANIST) == arcanist_sell_first_offers, "Selling reserve magic should leave arcanist offers unchanged")
	var arcanist_after_sell_first_buy: Dictionary = run_engine.buy_merchant_item(arcanist_after_sell_first, RunEngine.MERCHANT_ARCANIST, str(arcanist_sell_first_offers[0]))
	_assert(not run_engine.merchant_offer_ids(arcanist_after_sell_first_buy, RunEngine.MERCHANT_ARCANIST).has("spark_dart"), "Sold magic should not be introduced by a later arcanist restock")

	scavenger_state["current_room"] = scavenger_coord
	scavenger_state["mode"] = "room"
	scavenger_state = run_engine.set_held_embers(scavenger_state, purchase_budget)
	_assert(run_engine.merchant_kind_for_current_room(scavenger_state) == RunEngine.MERCHANT_SCAVENGER, "Scavenger room metadata should identify the item merchant")
	var scavenger_offers: Array = run_engine.merchant_offer_ids(scavenger_state, RunEngine.MERCHANT_SCAVENGER)
	_assert(scavenger_offers.size() == RunEngine.MERCHANT_OFFER_COUNT, "Scavengers should stock a compact set of item cards")
	var item_slot_index: int = 0
	var item_card_id: String = str(scavenger_offers[item_slot_index])
	_assert(GameData.card_is_item(item_card_id), "Scavenger stock should contain consumable item cards")
	var item_cost: int = run_engine.merchant_buy_cost(RunEngine.MERCHANT_SCAVENGER, item_card_id)
	var pre_item_deck: Array = (scavenger_state.get("deck_cards", []) as Array).duplicate()
	var bought_item_state: Dictionary = run_engine.buy_merchant_item(scavenger_state, RunEngine.MERCHANT_SCAVENGER, item_card_id)
	_assert(int(bought_item_state.get("held_embers", 0)) == purchase_budget - item_cost, "Buying an item should spend held embers")
	_assert((bought_item_state.get("item_inventory", []) as Array).has(item_card_id), "Bought items should enter item inventory")
	_assert((bought_item_state.get("deck_cards", []) as Array) == pre_item_deck, "Bought items should stay inactive until equipped")
	_assert(not run_engine.merchant_sellable_ids(bought_item_state, RunEngine.MERCHANT_SCAVENGER).has(item_card_id), "Bought items should not be immediately sellable in the same scavenger visit")
	var post_buy_scavenger_offers: Array = run_engine.merchant_offer_ids(bought_item_state, RunEngine.MERCHANT_SCAVENGER)
	_assert(post_buy_scavenger_offers.size() == RunEngine.MERCHANT_OFFER_COUNT, "Buying an item should refill only the purchased scavenger slot")
	for index: int in range(scavenger_offers.size()):
		if index == item_slot_index:
			_assert(str(post_buy_scavenger_offers[index]) != item_card_id, "Purchased scavenger slot should receive a replacement offer")
		else:
			_assert(str(post_buy_scavenger_offers[index]) == str(scavenger_offers[index]), "Buying an item should preserve the other scavenger offer slots")
	var immediate_item_resell_state: Dictionary = run_engine.sell_merchant_item(bought_item_state, RunEngine.MERCHANT_SCAVENGER, item_card_id)
	_assert((immediate_item_resell_state.get("item_inventory", []) as Array).has(item_card_id), "Bought items should stay in inventory if an immediate resell is attempted")
	_assert(int(immediate_item_resell_state.get("held_embers", 0)) == purchase_budget - item_cost, "Immediate item resell attempts should not refund embers")
	_assert(run_engine.merchant_offer_ids(immediate_item_resell_state, RunEngine.MERCHANT_SCAVENGER) == post_buy_scavenger_offers, "Blocked immediate item resell should not reroll scavenger offers")
	var scavenger_sell_first_state: Dictionary = scavenger_state.duplicate(true)
	scavenger_sell_first_state = run_engine.set_held_embers(scavenger_sell_first_state, purchase_budget)
	var scavenger_sell_first_offers: Array = run_engine.merchant_offer_ids(scavenger_sell_first_state, RunEngine.MERCHANT_SCAVENGER)
	var item_to_sell: String = ""
	for candidate_item_var: Variant in GameData.item_card_ids():
		var candidate_item_id: String = str(candidate_item_var)
		if not scavenger_sell_first_offers.has(candidate_item_id):
			item_to_sell = candidate_item_id
			break
	_assert(not item_to_sell.is_empty(), "Item pool should include a sellable item outside current scavenger stock")
	scavenger_sell_first_state["item_inventory"] = [item_to_sell, "nail_bomb", item_to_sell]
	var item_sale_value: int = run_engine.merchant_sell_value(RunEngine.MERCHANT_SCAVENGER, item_to_sell)
	var scavenger_after_sell_first: Dictionary = run_engine.sell_merchant_item(scavenger_sell_first_state, RunEngine.MERCHANT_SCAVENGER, item_to_sell)
	var remaining_items: Array = scavenger_after_sell_first.get("item_inventory", []) as Array
	_assert(remaining_items.has(item_to_sell) and remaining_items.has("nail_bomb"), "Selling one duplicate item should remove only one owned copy")
	_assert(int(scavenger_after_sell_first.get("held_embers", 0)) == purchase_budget + item_sale_value, "Selling an item should add the sell value to held embers")
	_assert(run_engine.merchant_offer_ids(scavenger_after_sell_first, RunEngine.MERCHANT_SCAVENGER) == scavenger_sell_first_offers, "Selling items should leave scavenger offers unchanged")
	var scavenger_after_sell_first_buy: Dictionary = run_engine.buy_merchant_item(scavenger_after_sell_first, RunEngine.MERCHANT_SCAVENGER, str(scavenger_sell_first_offers[0]))
	_assert(not run_engine.merchant_offer_ids(scavenger_after_sell_first_buy, RunEngine.MERCHANT_SCAVENGER).has(item_to_sell), "Sold items should not be introduced by a later scavenger restock")

func _test_elemental_intensity_starts_from_room_element() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["element"] = ElementData.FIRE
	var state: Dictionary = combat.create_combat(15121, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["firebrand_volley"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_assert(combat.elemental_intensity(state, ElementData.FIRE) == 1, "Combat should seed the room element with baseline intensity")
	_assert(combat.elemental_intensity(state, ElementData.ICE) == 0, "Combat should not seed off-element intensity")

func _test_elemental_intensity_actions_gate_effects() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["element"] = ElementData.FIRE
	var state: Dictionary = combat.create_combat(15122, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["firebrand_volley"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["player"] = {
		"pos": Vector2i(2, 4),
		"hp": 24,
		"max_hp": 24,
		"block": 0,
		"stoneskin": 0
	}
	state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(3, 4),
		"hp": 14,
		"max_hp": 14,
		"block": 0,
		"stoneskin": 0
	}]
	var gated_action: Dictionary = {
		"type": "melee",
		"damage": 5,
		"range": 1,
		"requires_intensity": {"element": ElementData.FIRE, "amount": 2}
	}
	_assert(not combat.player_action_can_resolve(state, gated_action), "Intensity-gated effects should not resolve below their threshold")
	var unchanged: Dictionary = combat.apply_player_action(state, gated_action, Vector2i(3, 4))
	_assert(int(((unchanged.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) == 14, "Applying an unmet intensity-gated attack should leave state unchanged")
	state = combat.apply_player_action(state, {"type": "intensity", "element": ElementData.FIRE, "amount": 1})
	_assert(combat.elemental_intensity(state, ElementData.FIRE) == 2, "Intensity actions should raise the matching room counter")
	_assert(combat.player_action_can_resolve(state, gated_action), "Intensity-gated effects should resolve after the threshold is met")
	state = combat.apply_player_action(state, gated_action, Vector2i(3, 4))
	_assert(int(((state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) == 9, "Met intensity-gated attacks should deal damage normally")

func _test_elemental_intensity_icons_surface_card_requirements() -> void:
	var intensity_tokens: Array = ActionIcons.tokens_for_action({"type": "intensity", "element": ElementData.FIRE, "amount": 2})
	_assert(not intensity_tokens.is_empty() and str((intensity_tokens[0] as Dictionary).get("kind", "")) == "elemental_intensity", "Intensity actions should render as elemental intensity tokens")
	_assert(ActionIcons.token_value_text(intensity_tokens[0] as Dictionary) == "+2", "Intensity tokens should show the gained amount")
	_assert(str((intensity_tokens[0] as Dictionary).get("tone", "")) == "neutral", "Intensity gain numbers should use the normal number tone")
	var gated_tokens: Array = ActionIcons.tokens_for_action({
		"type": "ranged",
		"damage": 4,
		"range": 5,
		"requires_intensity": {"element": ElementData.FIRE, "amount": 3}
	})
	_assert(not gated_tokens.is_empty() and str((gated_tokens[0] as Dictionary).get("kind", "")) == "intensity_requirement", "Gated actions should lead with an elemental requirement token")
	_assert(ActionIcons.token_value_text(gated_tokens[0] as Dictionary) == "3+:", "Intensity requirements should visually separate the gate with a colon")
	_assert(ActionIcons.plain_text_for_tokens(gated_tokens).begins_with("Fire 3+:"), "Plain card text should expose the elemental intensity threshold")
	var bonus_tokens: Array = ActionIcons.tokens_for_intensity_bonus({
		"type": "ranged",
		"damage": 4,
		"range": 5,
		"intensity_bonus": {"element": ElementData.FIRE, "threshold": 3, "damage": 2, "burn": 1}
	})
	_assert(not bonus_tokens.is_empty() and str((bonus_tokens[0] as Dictionary).get("kind", "")) == "intensity_requirement", "Intensity bonus rows should lead with an elemental requirement token")
	_assert(ActionIcons.plain_text_for_tokens(bonus_tokens).begins_with("Fire 3+:"), "Plain bonus text should expose the elemental intensity threshold")
	_assert(bonus_tokens.size() > 1 and str((bonus_tokens[1] as Dictionary).get("tone", "")) == "neutral", "Intensity bonus effect numbers should use the normal number tone")

func _test_elemental_intensity_bonus_modifies_single_attack() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["element"] = ElementData.FIRE
	var state: Dictionary = combat.create_combat(15123, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["firebrand_volley"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["player"] = {
		"pos": Vector2i(2, 4),
		"hp": 24,
		"max_hp": 24,
		"block": 0,
		"stoneskin": 0
	}
	state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(3, 4),
		"hp": 20,
		"max_hp": 20,
		"block": 0,
		"stoneskin": 0
	}]
	var action: Dictionary = {
		"type": "melee",
		"damage": 5,
		"range": 1,
		"intensity_bonus": {"element": ElementData.FIRE, "threshold": 2, "damage": 4, "burn": 2}
	}
	_assert(not combat.action_intensity_bonus_requirement_met(state, action), "Intensity bonuses should stay inactive below their threshold")
	_assert(combat.final_damage_for_player_action(state, action) == 5, "Inactive intensity bonuses should not inflate damage previews")
	var boosted_state: Dictionary = combat.apply_player_action(state, {"type": "intensity", "element": ElementData.FIRE, "amount": 1})
	_assert(combat.action_intensity_bonus_requirement_met(boosted_state, action), "Intensity bonuses should activate once the threshold is met")
	_assert(combat.final_damage_for_player_action(boosted_state, action) == 9, "Active intensity bonuses should increase damage previews")
	boosted_state = combat.apply_player_action(boosted_state, action, Vector2i(3, 4))
	var enemy: Dictionary = ((boosted_state.get("enemies", []) as Array)[0] as Dictionary)
	_assert(int(enemy.get("hp", 0)) == 11, "Active intensity bonuses should add damage to the same attack")
	_assert(int(enemy.get("burn", 0)) == 2, "Active intensity bonuses should add gated statuses to the same attack")

	var earth_layout: Dictionary = _simple_room_layout()
	earth_layout["element"] = ElementData.EARTH
	var venom_state: Dictionary = combat.create_combat(15124, earth_layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["venom_claw"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	venom_state["player"] = {
		"pos": Vector2i(2, 4),
		"hp": 24,
		"max_hp": 24,
		"block": 0,
		"stoneskin": 0
	}
	venom_state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(3, 4),
		"hp": 20,
		"max_hp": 20,
		"block": 0,
		"stoneskin": 0
	}]
	var venom_card: Dictionary = GameData.card_def("venom_claw")
	var venom_actions: Array = venom_card.get("actions", [])
	venom_state = combat.apply_player_action(venom_state, venom_actions[0] as Dictionary)
	_assert(combat.elemental_intensity(venom_state, ElementData.EARTH) == 2, "Venom Claw should self-enable its Earth 2+ rider in an Earth room")
	_assert(combat.final_damage_for_player_action(venom_state, venom_actions[1] as Dictionary) == 13, "Venom Claw's active Earth rider should increase same-attack damage")
	venom_state = combat.apply_player_action(venom_state, venom_actions[1] as Dictionary, Vector2i(3, 4))
	var venom_enemy: Dictionary = ((venom_state.get("enemies", []) as Array)[0] as Dictionary)
	_assert(int(venom_enemy.get("hp", 0)) == 7, "Venom Claw should apply its conditional damage to the target")
	var venom_poison: Dictionary = venom_enemy.get("poison", {}) as Dictionary
	_assert(int(venom_poison.get("damage", 0)) == 4, "Venom Claw should apply its conditional poison to the target")

func _test_cards_do_not_define_multiple_player_attacks() -> void:
	var attack_types: Array = ["melee", "ranged", "aoe", "push", "pull"]
	for card_id_var: Variant in GameData.cards().keys():
		var card_id: String = str(card_id_var)
		var card: Dictionary = GameData.card_def(card_id)
		var attack_count: int = 0
		for action_var: Variant in card.get("actions", []):
			if typeof(action_var) != TYPE_DICTIONARY:
				continue
			var action: Dictionary = action_var
			if str(action.get("type", "")) in attack_types:
				attack_count += 1
		_assert(attack_count <= 1, "%s should not define multiple player attacks" % card_id)

func _test_illusion_action_creates_decoy_and_redirects_enemy() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(1512, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["shadow_step", "quick_stab", "brace"],
		"relics": [],
		"hand_size": 3,
		"heal_bonus": 0
	})
	state["player"] = {
		"pos": Vector2i(2, 4),
		"hp": 24,
		"max_hp": 24,
		"block": 0,
		"stoneskin": 0
	}
	state["enemies"] = [
		{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(5, 4),
			"hp": 14,
			"max_hp": 14,
			"block": 0,
			"intent": {"name": "Claw", "actions": [{"type": "melee", "damage": 3, "range": 1}]}
		}
	]
	var action := {"type": "illusion", "health": 4, "range": 3}
	_assert(combat.valid_targets_for_player_action(state, action).has(Vector2i(4, 4)), "Illusion actions should target open tiles within placement range")
	state = combat.apply_player_action(state, action, Vector2i(4, 4))
	var illusions: Array = state.get("illusions", [])
	_assert(illusions.size() == 1, "Illusion actions should add a combat actor")
	_assert(int((illusions[0] as Dictionary).get("hp", 0)) == 4, "Created illusions should use the action health")
	_assert(combat.valid_targets_for_player_action(state, {"type": "move", "range": 3}).has(Vector2i(4, 4)), "Friendly illusions should not block player movement")
	var hp_before: int = int((state.get("player", {}) as Dictionary).get("hp", 0))
	var phase: Dictionary = combat.resolve_enemy_phase_with_steps(state)
	var after_state: Dictionary = phase.get("state", {})
	_assert(int((after_state.get("player", {}) as Dictionary).get("hp", 0)) == hp_before, "Enemies should attack a closer illusion instead of the player")
	var after_illusion: Dictionary = (after_state.get("illusions", []) as Array)[0]
	_assert(int(after_illusion.get("hp", 0)) == 1, "Enemy damage should reduce illusion health")
	var saw_illusion_loss_step: bool = false
	for step_var: Variant in phase.get("steps", []):
		if typeof(step_var) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = step_var
		for loss_var: Variant in step.get("target_losses", []):
			if typeof(loss_var) != TYPE_DICTIONARY:
				continue
			var loss: Dictionary = loss_var
			if str(loss.get("key", "")) == "illusion_1" and int(loss.get("hp_loss", 0)) == 3:
				saw_illusion_loss_step = true
	_assert(saw_illusion_loss_step, "Enemy animation steps should report illusion damage as target loss")

func _test_enemy_target_ties_prefer_illusions_deterministically() -> void:
	var saw_player_hit: bool = false
	var saw_illusion_hit: bool = false
	for seed: int in range(400, 432):
		var combat: CombatEngine = CombatEngine.new()
		var state: Dictionary = combat.create_combat(seed, _simple_room_layout(), {
			"hp": 24,
			"max_hp": 24,
			"deck_cards": ["shadow_step"],
			"relics": [],
			"hand_size": 1,
			"heal_bonus": 0
		})
		state["player"] = {
			"pos": Vector2i(3, 4),
			"hp": 24,
			"max_hp": 24,
			"block": 0,
			"stoneskin": 0
		}
		state["enemies"] = [
			{
				"id": 1,
				"type": "crawler",
				"pos": Vector2i(4, 4),
				"hp": 14,
				"max_hp": 14,
				"block": 0,
				"intent": {"name": "Tie Claw", "actions": [{"type": "melee", "damage": 3, "range": 1}]}
			}
		]
		state["illusions"] = [{"id": 1, "pos": Vector2i(5, 4), "hp": 4, "max_hp": 4}]
		state["rng_state"] = seed
		var after_state: Dictionary = combat.resolve_enemy_phase(state)
		if int((after_state.get("player", {}) as Dictionary).get("hp", 0)) < 24:
			saw_player_hit = true
		var illusions: Array = after_state.get("illusions", [])
		if not illusions.is_empty() and int((illusions[0] as Dictionary).get("hp", 0)) < 4:
			saw_illusion_hit = true
		if saw_player_hit and saw_illusion_hit:
			break
	_assert(not saw_player_hit and saw_illusion_hit, "Equal-distance player-side targets should deterministically prefer the illusion so decoys are reliable")

func _test_enemy_death_grants_card_play_and_embers() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(16, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab", "quick_stab"],
		"relics": [],
		"hand_size": 2,
		"heal_bonus": 0
	})
	var player: Dictionary = (state.get("player", {}) as Dictionary).duplicate(true)
	player["pos"] = Vector2i(2, 4)
	state["player"] = player
	var enemies: Array = state.get("enemies", [])
	var enemy: Dictionary = (enemies[0] as Dictionary).duplicate(true)
	enemy["pos"] = Vector2i(3, 4)
	enemy["hp"] = 9
	enemy["block"] = 0
	enemies[0] = enemy
	enemies.append({
		"id": 2,
		"type": "harrier",
		"pos": Vector2i(5, 5),
		"hp": 10,
		"max_hp": 10,
		"block": 0
	})
	state["enemies"] = enemies
	state = combat.apply_player_action(state, {"type": "melee", "damage": 9, "range": 1}, Vector2i(3, 4))
	_assert(int(state.get("death_bonus_card_plays_this_turn", 0)) == 1, "Killing a non-summoned enemy should add one bonus card play this turn")
	_assert(combat.cards_remaining_this_turn(state) == 3, "The new play should increase this turn's play capacity before the killing card is finished")
	_assert(int(state.get("room_embers", 0)) == 8, "Enemy death should still add its ember reward immediately")
	var rewards: Array = state.get("death_rewards", [])
	_assert(rewards.size() == 1 and int((rewards[0] as Dictionary).get("embers", 0)) == 8, "Death rewards should record ember amount for UI collection animation")
	state = combat.finish_player_card(state, 0)
	_assert(combat.cards_remaining_this_turn(state) == 2, "Finishing the killing card should spend one play but keep the death bonus")
	state = combat.prepare_next_player_turn(state)
	_assert(int(state.get("death_bonus_card_plays_this_turn", 0)) == 0, "A new player turn should clear death bonus plays")

func _test_summoned_enemy_death_does_not_grant_card_play() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(17, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var player: Dictionary = (state.get("player", {}) as Dictionary).duplicate(true)
	player["pos"] = Vector2i(2, 4)
	state["player"] = player
	state["enemies"] = [{
		"id": 8,
		"type": "lightning_wisp",
		"summoned": true,
		"pos": Vector2i(3, 4),
		"hp": 6,
		"max_hp": 6,
		"block": 0
	}]
	state = combat.apply_player_action(state, {"type": "melee", "damage": 9, "range": 1}, Vector2i(3, 4))
	_assert(int(state.get("death_bonus_card_plays_this_turn", 0)) == 0, "Killing a summoned enemy should not add a bonus card play")
	_assert(combat.cards_remaining_this_turn(state) == 2, "Summoned deaths should leave base plays unchanged before the killing card is finished")
	var rewards: Array = state.get("death_rewards", [])
	_assert(rewards.size() == 1 and bool((rewards[0] as Dictionary).get("summoned", false)), "Summoned death rewards should still be marked for animation filtering")

func _test_cinder_ooze_splits_deterministically() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(171, _cinder_ooze_room_layout(), {
		"hp": 240,
		"max_hp": 240,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state = combat.apply_player_action(state, {"type": "ranged", "damage": 999, "range": 5}, Vector2i(4, 4))
	var droplets: Array = _enemies_of_type_for_test(state, "cinder_droplet", true)
	_assert(droplets.size() == 2, "Killing Cinder Ooze should spawn up to two Cinder Droplets")
	if droplets.size() >= 2:
		_assert((droplets[0] as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(4, 3), "First Cinder Droplet should use the deterministic north split tile")
		_assert((droplets[1] as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(3, 4), "Second Cinder Droplet should use the deterministic west split tile")
		_assert(int((droplets[0] as Dictionary).get("id", 0)) == 2 and int((droplets[1] as Dictionary).get("id", 0)) == 3, "Split droplets should receive stable new enemy ids")
		_assert(bool((droplets[0] as Dictionary).get("summoned", false)) and bool((droplets[1] as Dictionary).get("summoned", false)), "Split droplets should be marked summoned")
		_assert(not ((droplets[0] as Dictionary).get("intent", {}) as Dictionary).is_empty(), "Split droplets should receive preview intents")
	_assert(int(state.get("room_embers", 0)) == 12, "The original Cinder Ooze should grant its ember reward once")
	_assert(int(state.get("death_bonus_card_plays_this_turn", 0)) == 1, "The original Cinder Ooze should grant one death card play")
	var order: Array[Dictionary] = combat.current_turn_order(state, 8)
	var saw_droplet_turn: bool = false
	for entry: Dictionary in order:
		if str(entry.get("type", "")) == "cinder_droplet":
			saw_droplet_turn = true
			break
	_assert(saw_droplet_turn, "Split droplets should be scheduled into the initiative queue")

func _test_cinder_ooze_split_skips_blocked_board() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(172, _cinder_ooze_room_layout(true), {
		"hp": 240,
		"max_hp": 240,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state = combat.apply_player_action(state, {"type": "ranged", "damage": 999, "range": 5}, Vector2i(4, 4))
	var droplets: Array = _enemies_of_type_for_test(state, "cinder_droplet", false)
	_assert(droplets.is_empty(), "Cinder Ooze should not split onto occupied, blocked, door, or invalid tiles")
	_assert(_enemies_of_type_for_test(state, "harrier", true).size() == 1, "Blocked-board fallback should preserve unrelated live enemies")

func _test_cinder_droplet_death_suppresses_rewards() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(173, _cinder_ooze_room_layout(), {
		"hp": 240,
		"max_hp": 240,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state = combat.apply_player_action(state, {"type": "ranged", "damage": 999, "range": 5}, Vector2i(4, 4))
	state = combat.apply_player_action(state, {"type": "ranged", "damage": 999, "range": 5}, Vector2i(4, 3))
	state = combat.apply_player_action(state, {"type": "ranged", "damage": 999, "range": 5}, Vector2i(3, 4))
	_assert(int(state.get("room_embers", 0)) == 12, "Killing split droplets should not add ember rewards beyond the original Ooze")
	_assert(int(state.get("death_bonus_card_plays_this_turn", 0)) == 1, "Killing split droplets should not add extra death card plays")
	var rewards: Array = state.get("death_rewards", [])
	_assert(rewards.size() == 3, "Ooze plus two droplets should create one reward record each for animation bookkeeping")
	if rewards.size() == 3:
		_assert(int((rewards[0] as Dictionary).get("embers", 0)) == 12 and not bool((rewards[0] as Dictionary).get("summoned", false)), "Original Ooze reward record should pay once")
		_assert(int((rewards[1] as Dictionary).get("embers", 0)) == 0 and bool((rewards[1] as Dictionary).get("summoned", false)), "First droplet reward record should be summoned and emberless")
		_assert(int((rewards[2] as Dictionary).get("embers", 0)) == 0 and bool((rewards[2] as Dictionary).get("summoned", false)), "Second droplet reward record should be summoned and emberless")

func _test_cinder_droplet_does_not_resplit() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(174, _cinder_droplet_room_layout(), {
		"hp": 240,
		"max_hp": 240,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state = combat.apply_player_action(state, {"type": "ranged", "damage": 999, "range": 5}, Vector2i(4, 4))
	_assert(_enemies_of_type_for_test(state, "cinder_droplet", false).size() == 1, "Killing a Cinder Droplet should not append any resplit droplets")

func _test_hand_draw_caps_at_seven() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(151, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab"],
		"relics": [],
		"hand_size": 5,
		"heal_bonus": 0
	})
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab"]
	deck["draw"] = ["quick_stab", "quick_stab", "quick_stab"]
	deck["discard"] = []
	deck["burned"] = []
	state["deck"] = deck
	state["draw_per_turn"] = 3
	state = combat.prepare_next_player_turn(state)
	_assert(((state.get("deck", {}) as Dictionary).get("hand", []) as Array).size() == 7, "Drawing for a new turn should stop once the hand reaches seven cards")

func _test_relic_effect_hooks() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var shield_state: Dictionary = combat.create_combat(1601, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": ["reinforced_shield"],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_assert(int((shield_state.get("player", {}) as Dictionary).get("stoneskin", 0)) == 4, "Start-combat relic effects should apply before the first turn")
	var thorn_state: Dictionary = combat.create_combat(1611, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["stone_plate"],
		"relics": ["thornmail_brooch"],
		"hand_size": 1,
		"heal_bonus": 0
	})
	thorn_state["player"] = {"pos": Vector2i(2, 4), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	thorn_state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(3, 4),
		"hp": 14,
		"max_hp": 14,
		"block": 0,
		"stoneskin": 0
	}]
	thorn_state = combat.apply_player_action(thorn_state, {"type": "stoneskin", "amount": 4})
	_assert(int(((thorn_state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) == 13, "Thornmail Brooch should use natural-unit thorns damage")
	var fire_card: Dictionary = combat.card_def("hearth_rush", {"relics": ["flint_edge"]})
	var fire_base_melee: Dictionary = {}
	for action_var: Variant in fire_card.get("actions", []):
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_var
		if str(action.get("type", "")) != "melee":
			continue
		fire_base_melee = action
	_assert(int(fire_base_melee.get("burn", 0)) == 1, "Elemental relic action mods should augment matching base card actions")
	_assert(int((fire_base_melee.get("intensity_bonus", {}) as Dictionary).get("burn", 0)) == 2, "Elemental relic action mods should preserve matching intensity-gated bonus actions")
	var storm_card: Dictionary = combat.card_def("spark_dart", {"relics": ["storm_crown"]})
	var storm_actions: Array = storm_card.get("actions", [])
	_assert(str((storm_actions[storm_actions.size() - 1] as Dictionary).get("type", "")) == "card_play", "Append-action relic effects should add reusable card actions")
	var frost_state: Dictionary = combat.create_combat(1602, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": ["frost_prism"],
		"hand_size": 1,
		"heal_bonus": 0
	})
	frost_state["player"] = {"pos": Vector2i(2, 4), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	frost_state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(3, 4),
		"hp": 14,
		"max_hp": 14,
		"block": 0,
		"stoneskin": 0,
		"freeze": 1
	}]
	frost_state = combat.apply_player_action(frost_state, {"type": "melee", "damage": 4, "range": 1}, Vector2i(3, 4))
	_assert(int(((frost_state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) == 0, "Target-status relic effects should add damage before existing freeze vulnerability")
	var phoenix_state: Dictionary = combat.create_combat(1603, _simple_room_layout(), {
		"hp": 3,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": ["phoenix_ember"],
		"hand_size": 1,
		"heal_bonus": 0,
		"defiance_capacity": 1,
		"defiance_remaining": 1
	})
	phoenix_state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(3, 4),
		"hp": 14,
		"max_hp": 14,
		"block": 0,
		"stoneskin": 0
	}]
	phoenix_state = combat.call("_damage_player", phoenix_state, 9, true)
	_assert(int((phoenix_state.get("player", {}) as Dictionary).get("hp", 0)) == 6, "Phoenix Ember's added Defiance should restore a quarter of maximum health")
	_assert(int(phoenix_state.get("defiance_remaining", -1)) == 0, "Phoenix Ember's Defiance should spend exactly one charge")
	_assert(int(((phoenix_state.get("enemies", []) as Array)[0] as Dictionary).get("burn", 0)) == 3, "Phoenix Ember should apply its follow-up burn when Defiance triggers")
	var cinder_state: Dictionary = combat.create_combat(1604, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": ["cinderbrand_tongs", "coalheart_crucible"],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var cinder_intensity: Dictionary = combat.elemental_intensities(cinder_state)
	cinder_intensity[ElementData.FIRE] = 3
	cinder_state["elemental_intensity"] = cinder_intensity
	cinder_state["player"] = {"pos": Vector2i(4, 2), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	cinder_state = combat.apply_player_action(cinder_state, {"type": "melee", "damage": 1, "range": 1, "burn": 1}, Vector2i(5, 2))
	_assert(combat.elemental_intensity(cinder_state, ElementData.FIRE) == 2, "Fire threshold relics should be able to consume intensity after crossing")
	_assert(int(cinder_state.get("card_play_bonus_this_turn", 0)) == 1, "Intensity threshold rewards should be able to grant card plays")
	_assert(int(((cinder_state.get("enemies", []) as Array)[0] as Dictionary).get("burn", 0)) == 3, "Intensity threshold rewards should apply all-enemy statuses")
	var cinder_spent: Dictionary = combat.elemental_intensity_counter(cinder_state, "elemental_intensity_spent_total")
	_assert(int(cinder_spent.get(ElementData.FIRE, 0)) == 2, "Combat state should track gross intensity spent by relic payoffs")
	var overflow_state: Dictionary = combat.create_combat(1610, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": ["overflow_censer"],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var overflow_intensity: Dictionary = combat.elemental_intensities(overflow_state)
	overflow_intensity[ElementData.ICE] = 2
	overflow_state["elemental_intensity"] = overflow_intensity
	overflow_state = combat.apply_player_action(overflow_state, {"type": "intensity", "element": ElementData.ICE, "amount": 1})
	_assert(int((overflow_state.get("player", {}) as Dictionary).get("block", 0)) == 5, "Any-element threshold rewards should trigger from matching crossings")
	var voltaic_state: Dictionary = combat.create_combat(1605, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": ["voltaic_tuning_fork"],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var voltaic_intensity: Dictionary = combat.elemental_intensities(voltaic_state)
	voltaic_intensity[ElementData.LIGHTNING] = 2
	voltaic_state["elemental_intensity"] = voltaic_intensity
	var voltaic_deck: Dictionary = (voltaic_state.get("deck", {}) as Dictionary).duplicate(true)
	voltaic_deck["draw"] = ["quick_stab"]
	voltaic_deck["hand"] = []
	voltaic_deck["discard"] = []
	voltaic_deck["burned"] = []
	voltaic_state["deck"] = voltaic_deck
	voltaic_state = combat.apply_player_action(voltaic_state, {"type": "intensity", "element": ElementData.LIGHTNING, "amount": 1})
	_assert(combat.elemental_intensity(voltaic_state, ElementData.LIGHTNING) == 3, "Non-consuming threshold rewards should leave intensity in place")
	_assert(((voltaic_state.get("deck", {}) as Dictionary).get("hand", []) as Array).size() == 1, "Intensity threshold rewards should be able to draw cards")
	var basalt_room: Dictionary = _simple_room_layout()
	basalt_room["element"] = ElementData.NONE
	var basalt_state: Dictionary = combat.create_combat(1606, basalt_room, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["venom_claw", "stone_plate", "quarry_step", "thorn_skewer"],
		"relics": ["basalt_calendar"],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_assert(combat.elemental_intensity(basalt_state, ElementData.EARTH) == 1, "Deck-conditioned relics should be able to seed elemental intensity at combat start")
	var updraft_state: Dictionary = combat.create_combat(1607, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": ["updraft_bottle"],
		"hand_size": 1,
		"heal_bonus": 0
	})
	updraft_state = combat.apply_player_action(updraft_state, {"type": "blink", "range": 2}, Vector2i(3, 4))
	updraft_state = combat.apply_player_action(updraft_state, {"type": "blink", "range": 2}, Vector2i(2, 4))
	_assert(combat.elemental_intensity(updraft_state, ElementData.AIR) == 1, "Blink intensity relics should trigger only once per turn")
	var tectonic_state: Dictionary = combat.create_combat(1608, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": ["tectonic_abacus"],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var tectonic_intensity: Dictionary = combat.elemental_intensities(tectonic_state)
	tectonic_intensity[ElementData.EARTH] = 3
	tectonic_state["elemental_intensity"] = tectonic_intensity
	tectonic_state = combat.apply_player_action(tectonic_state, {"type": "intensity", "element": ElementData.EARTH, "amount": 1})
	_assert(combat.elemental_intensity(tectonic_state, ElementData.EARTH) == 2, "Earth threshold relics should consume their configured intensity")
	_assert(int((tectonic_state.get("player", {}) as Dictionary).get("stoneskin", 0)) == 8, "Earth threshold relics should be able to grant stoneskin")
	var black_sun_state: Dictionary = combat.create_combat(1609, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": ["black_sun_dial"],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var black_sun_intensity: Dictionary = combat.elemental_intensities(black_sun_state)
	black_sun_intensity[ElementData.FIRE] = 4
	black_sun_state["elemental_intensity"] = black_sun_intensity
	var black_sun_deck: Dictionary = (black_sun_state.get("deck", {}) as Dictionary).duplicate(true)
	black_sun_deck["draw"] = ["quick_stab"]
	black_sun_deck["hand"] = []
	black_sun_deck["discard"] = []
	black_sun_deck["burned"] = []
	black_sun_state["deck"] = black_sun_deck
	black_sun_state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(5, 2),
		"hp": 14,
		"max_hp": 14,
		"block": 0,
		"stoneskin": 0
	}]
	black_sun_state = combat.apply_player_action(black_sun_state, {"type": "intensity", "element": ElementData.FIRE, "amount": 1})
	_assert(combat.elemental_intensity(black_sun_state, ElementData.FIRE) == 2, "Any-element consuming relics should spend the triggering element")
	_assert(int(((black_sun_state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) == 10, "Any-element threshold rewards should be able to damage all enemies")
	_assert(((black_sun_state.get("deck", {}) as Dictionary).get("hand", []) as Array).size() == 1, "Any-element threshold rewards should be able to draw")

func _test_tailwind_fletching_modifies_existing_forced_movement() -> void:
	var tailwind_skybreak: Dictionary = GameData.card_def_for_progression("skybreak_current", {"relics": ["tailwind_fletching"]})
	var skybreak_attack: Dictionary = (tailwind_skybreak.get("actions", []) as Array)[1]
	_assert(int(skybreak_attack.get("range", 0)) == 7, "Tailwind should keep its ranged Air range bonus")
	_assert(int(skybreak_attack.get("push", 0)) == 3, "Tailwind should increase existing push on Air ranged attacks")
	_assert(ActionIcons.token_tooltip(ActionIcons.tokens_for_action(skybreak_attack)[2] as Dictionary).contains("Tailwind Fletching"), "Relic-modified push tokens should name Tailwind in their tooltip")
	var tailwind_squall: Dictionary = GameData.card_def_for_progression("squall_shot", {"relics": ["tailwind_fletching"]})
	var squall_action: Dictionary = (tailwind_squall.get("actions", []) as Array)[1]
	_assert(int(squall_action.get("push", 0)) == 2, "Tailwind should increase existing push on Air AOE attacks")
	var tailwind_vacuum: Dictionary = GameData.card_def_for_progression("vacuum_line", {"relics": ["tailwind_fletching"]})
	var vacuum_action: Dictionary = (tailwind_vacuum.get("actions", []) as Array)[0]
	_assert(int(vacuum_action.get("amount", 0)) == 6, "Tailwind should increase existing Air pull action distance")
	var stacked_updraft: Dictionary = GameData.card_def_for_progression("updraft", {"relics": ["tailwind_fletching", "anchor_chain"]})
	var stacked_action: Dictionary = (stacked_updraft.get("actions", []) as Array)[1]
	_assert(int(stacked_action.get("amount", 0)) == 4, "Multiple relics should stack on the same forced-movement number")
	var stacked_tokens: Array = ActionIcons.tokens_for_action(stacked_action)
	var stacked_push_token: Dictionary = (stacked_tokens[stacked_tokens.size() - 1] as Dictionary)
	_assert(str(stacked_push_token.get("icon", "")) == "push", "Forced movement cards should render push after the hit")
	var stacked_tooltip: String = ActionIcons.token_tooltip(stacked_push_token)
	_assert(ActionIcons.token_is_modified(stacked_push_token), "Relic-modified forced movement should carry a dynamic token marker")
	_assert(stacked_tooltip.contains("Tailwind Fletching") and stacked_tooltip.contains("Anchor Chain"), "A token modified by multiple relics should list every source")

func _test_pierce_ignores_defenses() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var melee_state: Dictionary = combat.create_combat(1701, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	melee_state["player"] = {"pos": Vector2i(2, 4), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	melee_state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(3, 4),
		"hp": 14,
		"max_hp": 14,
		"block": 4,
		"stoneskin": 3
	}]
	melee_state = combat.apply_player_action(melee_state, {"type": "melee", "damage": 5, "range": 1, "pierce": true}, Vector2i(3, 4))
	var pierced_enemy: Dictionary = (melee_state.get("enemies", []) as Array)[0]
	_assert(int(pierced_enemy.get("hp", 0)) == 9, "Pierce melee should damage HP through enemy defenses")
	_assert(int(pierced_enemy.get("block", 0)) == 4, "Pierce melee should not remove enemy block")
	_assert(int(pierced_enemy.get("stoneskin", 0)) == 3, "Pierce melee should not remove enemy stoneskin")

	var aoe_state: Dictionary = combat.create_combat(1702, _aoe_test_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["whirlwind_slash"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	aoe_state["player"] = {"pos": Vector2i(4, 4), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	aoe_state["enemies"] = [
		{"id": 1, "type": "crawler", "pos": Vector2i(4, 3), "hp": 14, "max_hp": 14, "block": 2, "stoneskin": 2},
		{"id": 2, "type": "harrier", "pos": Vector2i(5, 4), "hp": 10, "max_hp": 10, "block": 3, "stoneskin": 1}
	]
	var aoe_action: Dictionary = {"type": "aoe", "damage": 4, "range": 0, "pattern": [[0, -1], [1, 0]], "rotate": false, "pierce": true}
	aoe_state = combat.apply_player_action(aoe_state, aoe_action)
	var aoe_enemies: Array = aoe_state.get("enemies", [])
	_assert(int((aoe_enemies[0] as Dictionary).get("hp", 0)) == 10, "Pierce AOE should damage the first target through defenses")
	_assert(int((aoe_enemies[0] as Dictionary).get("block", 0)) == 2, "Pierce AOE should leave first target block intact")
	_assert(int((aoe_enemies[1] as Dictionary).get("hp", 0)) == 6, "Pierce AOE should damage the second target through defenses")
	_assert(int((aoe_enemies[1] as Dictionary).get("stoneskin", 0)) == 1, "Pierce AOE should leave second target stoneskin intact")

	var enemy_state: Dictionary = combat.create_combat(1703, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["brace"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	enemy_state["player"] = {"pos": Vector2i(2, 4), "hp": 24, "max_hp": 24, "block": 6, "stoneskin": 4}
	enemy_state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(3, 4),
		"hp": 14,
		"max_hp": 14,
		"block": 0,
		"stoneskin": 0,
		"intent": {"name": "Needle", "actions": [{"type": "melee", "damage": 5, "range": 1, "pierce": true}]}
	}]
	enemy_state = combat.resolve_enemy_phase(enemy_state)
	var pierced_player: Dictionary = enemy_state.get("player", {})
	_assert(int(pierced_player.get("hp", 0)) == 19, "Enemy pierce attacks should damage player HP through defenses")
	_assert(int(pierced_player.get("block", 0)) == 6, "Enemy pierce attacks should leave player block intact")
	_assert(int(pierced_player.get("stoneskin", 0)) == 4, "Enemy pierce attacks should leave player stoneskin intact")

func _test_bleed_expose_and_sunder_keywords() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var bleed_state: Dictionary = combat.create_combat(1711, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	bleed_state["player"] = {"pos": Vector2i(2, 4), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	bleed_state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(3, 4),
		"hp": 20,
		"max_hp": 20,
		"block": 0,
		"stoneskin": 0,
		"intent": {}
	}]
	bleed_state = combat.apply_player_action(bleed_state, {"type": "melee", "damage": 0, "range": 1, "bleed": 3}, Vector2i(3, 4))
	var marked_enemy: Dictionary = (bleed_state.get("enemies", []) as Array)[0]
	_assert(int(marked_enemy.get("bleed", 0)) == 3, "Bleed attacks should store a physical damage-over-time stack")
	bleed_state = combat.apply_player_action(bleed_state, {"type": "melee", "damage": 0, "range": 1, "bleed": 2}, Vector2i(3, 4))
	marked_enemy = (bleed_state.get("enemies", []) as Array)[0]
	_assert(int(marked_enemy.get("bleed", 0)) == 5, "Bleed applications should stack by damage before the target's next turn")
	marked_enemy["intent"] = {
		"name": "Advance and Bite",
		"actions": [
			{"type": "move_toward", "range": 1},
			{"type": "melee", "damage": 1, "range": 1}
		]
	}
	var bleed_enemies: Array = bleed_state.get("enemies", [])
	bleed_enemies[0] = marked_enemy
	bleed_state["enemies"] = bleed_enemies
	var turn_result: Dictionary = combat.resolve_enemy_turn_with_steps(bleed_state, 0)
	var resolved_bleed_state: Dictionary = turn_result.get("state", bleed_state)
	var bleeding_enemy: Dictionary = (resolved_bleed_state.get("enemies", []) as Array)[0]
	_assert(int(bleeding_enemy.get("hp", 0)) == 15, "Enemy bleed should not trigger for a move action that does not change position")
	_assert(int(bleeding_enemy.get("bleed", 0)) == 0, "Bleed should clear when the affected enemy finishes its next turn")
	_assert(_bleed_action_types_from_steps(turn_result.get("steps", [])) == ["melee"], "Adjacent enemy move+attack should only tick bleed for the attack")

	var moving_bleed_state: Dictionary = combat.create_combat(1716, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	moving_bleed_state["player"] = {"pos": Vector2i(2, 4), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	moving_bleed_state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(5, 4),
		"hp": 20,
		"max_hp": 20,
		"block": 0,
		"stoneskin": 0,
		"bleed": 5,
		"intent": {
			"name": "Advance and Bite",
			"actions": [
				{"type": "move_toward", "range": 2},
				{"type": "melee", "damage": 1, "range": 1}
			]
		}
	}]
	var moving_turn_result: Dictionary = combat.resolve_enemy_turn_with_steps(moving_bleed_state, 0)
	var moved_bleeding_enemy: Dictionary = ((moving_turn_result.get("state", moving_bleed_state) as Dictionary).get("enemies", []) as Array)[0]
	_assert(int(moved_bleeding_enemy.get("hp", 0)) == 10, "Enemy bleed should trigger for each move or attack action that actually resolves")
	_assert(_bleed_action_types_from_steps(moving_turn_result.get("steps", [])) == ["move_toward", "melee"], "Resolved enemy move+attack should surface one bleed step per resolved action")

	var move_block_state: Dictionary = combat.create_combat(1717, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	move_block_state["player"] = {"pos": Vector2i(2, 4), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	move_block_state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(3, 4),
		"hp": 20,
		"max_hp": 20,
		"block": 0,
		"stoneskin": 0,
		"bleed": 5,
		"intent": {
			"name": "Coil",
			"actions": [
				{"type": "move_toward", "range": 1},
				{"type": "block", "amount": 4}
			]
		}
	}]
	var move_block_result: Dictionary = combat.resolve_enemy_turn_with_steps(move_block_state, 0)
	var move_block_enemy: Dictionary = ((move_block_result.get("state", move_block_state) as Dictionary).get("enemies", []) as Array)[0]
	_assert(int(move_block_enemy.get("hp", 0)) == 20, "Enemy bleed should not trigger for no-op movement followed by block")
	_assert(_bleed_action_types_from_steps(move_block_result.get("steps", [])).is_empty(), "No-op enemy move+block should not surface bleed status steps")

	var state: Dictionary = combat.create_combat(1713, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["player"] = {"pos": Vector2i(2, 4), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(3, 4),
		"hp": 20,
		"max_hp": 20,
		"block": 4,
		"stoneskin": 3,
		"intent": {}
	}]
	state = combat.apply_player_action(state, {"type": "melee", "damage": 0, "range": 1, "expose": 4}, Vector2i(3, 4))
	var exposed_enemy: Dictionary = (state.get("enemies", []) as Array)[0]
	_assert(int(exposed_enemy.get("expose", 0)) == 4, "Expose attacks should store a next-hit damage bonus")
	state = combat.apply_player_action(state, {"type": "melee", "damage": 5, "range": 1, "sunder": 6}, Vector2i(3, 4))
	var sundered_enemy: Dictionary = (state.get("enemies", []) as Array)[0]
	_assert(int(sundered_enemy.get("block", 0)) == 0, "Sunder should remove block before damage")
	_assert(int(sundered_enemy.get("stoneskin", 0)) == 0, "Sunder plus follow-up damage should clear the remaining stoneskin")
	_assert(int(sundered_enemy.get("hp", 0)) == 12, "Expose should add to the next hit before clearing")
	_assert(int(sundered_enemy.get("expose", 0)) == 0, "Expose should clear after it boosts a hit")

	var player_state: Dictionary = combat.create_combat(1712, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	player_state["player"] = {"pos": Vector2i(2, 4), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0, "bleed": 4}
	player_state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(4, 4),
		"hp": 20,
		"max_hp": 20,
		"block": 0,
		"stoneskin": 0,
		"intent": {}
	}]
	var block_state: Dictionary = combat.apply_player_action(player_state, {"type": "block", "amount": 3})
	_assert(int((block_state.get("player", {}) as Dictionary).get("hp", 0)) == 24, "Block actions should not trigger player bleed")
	var blink_state: Dictionary = combat.apply_player_action(player_state, {"type": "blink", "range": 2}, Vector2i(3, 4))
	_assert(int((blink_state.get("player", {}) as Dictionary).get("hp", 0)) == 24, "Blink actions should not trigger player bleed")
	var no_move_state: Dictionary = combat.apply_player_action(player_state, {"type": "move", "range": 1}, Vector2i(2, 4))
	_assert(int((no_move_state.get("player", {}) as Dictionary).get("hp", 0)) == 24, "Player bleed should not trigger for a move action that stays in place")
	var move_state: Dictionary = combat.apply_player_action(player_state, {"type": "move", "range": 1}, Vector2i(3, 4))
	_assert(int((move_state.get("player", {}) as Dictionary).get("hp", 0)) == 20, "Resolved move actions should trigger player bleed once")
	var skipped_attack_state: Dictionary = combat.apply_player_action(move_state, {"type": "melee", "damage": 5, "range": 1}, Vector2i(-1, -1))
	_assert(int((skipped_attack_state.get("player", {}) as Dictionary).get("hp", 0)) == 20, "Skipped follow-up attacks should not trigger player bleed")
	var attack_state: Dictionary = combat.apply_player_action(move_state, {"type": "melee", "damage": 5, "range": 1}, Vector2i(4, 4))
	_assert(int((attack_state.get("player", {}) as Dictionary).get("hp", 0)) == 16, "Resolved follow-up attacks should trigger player bleed independently")
	var ended_move_state: Dictionary = combat.finish_player_activation(move_state)
	_assert(int((ended_move_state.get("player", {}) as Dictionary).get("bleed", 0)) == 0, "Player bleed should clear when the player's next turn is finished")

func _test_enemy_bleed_intents_apply_and_surface_icons() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var board := CombatBoardView.new()
	var crawler_skitter: Dictionary = _enemy_intent_by_id("crawler", "skitter_strike")
	var crawler_lunge: Dictionary = _enemy_intent_by_id("crawler", "lunge")
	var harrier_pelt: Dictionary = _enemy_intent_by_id("harrier", "pelt")
	_assert(_intent_has_action_status(crawler_skitter, "melee", "bleed"), "Tunnel Crawler Skitter Strike claws should apply bleed")
	_assert(_intent_has_action_status(crawler_lunge, "melee", "bleed"), "Tunnel Crawler Lunge claws should apply bleed")
	_assert(_intent_has_action_status(harrier_pelt, "ranged", "bleed"), "Bone Harrier Pelt spear should apply bleed")
	_assert(_intent_rows_have_icon(board.call("_intent_rows", crawler_skitter), "bleed"), "Crawler bleed intent rows should show the bleed icon")
	_assert(_intent_rows_have_icon(board.call("_intent_rows", harrier_pelt), "bleed"), "Harrier bleed intent rows should show the bleed icon")
	board.free()

	var crawler_layout: Dictionary = _simple_room_layout()
	crawler_layout["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(3, 4),
		"hp": 140,
		"max_hp": 140,
		"block": 0,
		"stoneskin": 0
	}]
	var crawler_state: Dictionary = combat.create_combat(1714, crawler_layout, {
		"hp": 240,
		"max_hp": 240,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_set_enemy_intent(crawler_state, 0, crawler_skitter)
	var crawler_result: Dictionary = combat.resolve_enemy_turn_with_steps(crawler_state, 0)
	var crawler_player: Dictionary = (crawler_result.get("state", {}) as Dictionary).get("player", {})
	_assert(int(crawler_player.get("bleed", 0)) == GameData.fixed_point_amount(1), "Crawler bleed claws should mark the player")

	var harrier_layout: Dictionary = _simple_room_layout()
	harrier_layout["enemies"] = [{
		"id": 1,
		"type": "harrier",
		"pos": Vector2i(5, 4),
		"hp": 100,
		"max_hp": 100,
		"block": 0,
		"stoneskin": 0
	}]
	var harrier_state: Dictionary = combat.create_combat(1715, harrier_layout, {
		"hp": 240,
		"max_hp": 240,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_set_enemy_intent(harrier_state, 0, harrier_pelt)
	var harrier_result: Dictionary = combat.resolve_enemy_turn_with_steps(harrier_state, 0)
	var harrier_player: Dictionary = (harrier_result.get("state", {}) as Dictionary).get("player", {})
	_assert(int(harrier_player.get("bleed", 0)) == GameData.fixed_point_amount(1), "Harrier bleed spear should mark the player")

func _test_bleed_status_badges_and_trigger_floats() -> void:
	var board := CombatBoardView.new()
	board.call("_load_assets")
	var textures: Dictionary = board.get("_keyword_icon_textures") as Dictionary
	_assert(textures.get("bleed", null) != null, "Combat board should load the bleed icon texture")
	var enemy_badges: Array = board.call("_unit_status_badges", {"bleed": 30})
	_assert(enemy_badges.size() == 1, "Bleeding enemies should surface a status badge")
	if not enemy_badges.is_empty():
		var bleed_badge: Dictionary = enemy_badges[0] as Dictionary
		_assert(str(bleed_badge.get("icon", "")) == "bleed", "Bleed status badge should use the bleed icon")
		_assert(int(bleed_badge.get("count", 0)) == 30, "Bleed status badge should show the current bleed stack")
		_assert(bleed_badge.has("icon_tint"), "Bleed status badge should use a high-contrast icon tint")
	var player_statuses: Dictionary = board.call("_player_display_statuses", {"bleed": 20}, {})
	var player_badges: Array = board.call("_unit_status_badges", player_statuses)
	_assert(not player_badges.is_empty() and str((player_badges[0] as Dictionary).get("icon", "")) == "bleed", "Bleeding player should surface the same bleed badge")
	board.set_combat_state({
		"grid": _simple_grid(),
		"player": {"pos": Vector2i(2, 4), "hp": 120, "max_hp": 120, "block": 0, "stoneskin": 0, "bleed": 20},
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(4, 4),
			"hp": 80,
			"max_hp": 80,
			"block": 0,
			"stoneskin": 0,
			"bleed": 30
		}]
	})
	var visible_units: Array = board.call("_visible_units")
	var visible_player_bleed: bool = false
	var visible_enemy_bleed: bool = false
	for unit_var: Variant in visible_units:
		var unit: Dictionary = unit_var as Dictionary
		if str(unit.get("role", "")) == "player" and int(unit.get("bleed", 0)) == 20:
			visible_player_bleed = true
		if str(unit.get("role", "")) == "enemy" and int(unit.get("bleed", 0)) == 30:
			visible_enemy_bleed = true
	_assert(visible_player_bleed, "Visible player draw data should retain bleed for status badges")
	_assert(visible_enemy_bleed, "Visible enemy draw data should retain bleed for status badges")
	board.free()

	var instance: Node = RunSceneScript.new()
	var bleed_floats: Array = instance.call("_floating_texts_for_step", {
		"kind": "status_damage",
		"label": "Bleed",
		"tile": Vector2i(3, 4),
		"amount": 50
	})
	_assert(bleed_floats.size() == 1, "Bleed trigger should create a floating feedback entry")
	if not bleed_floats.is_empty():
		var bleed_float: Dictionary = bleed_floats[0] as Dictionary
		_assert(str(bleed_float.get("icon", "")) == "bleed", "Bleed trigger float should pop the bleed icon")
		_assert(str(bleed_float.get("text", "")) == "-50", "Bleed trigger float should still show the damage number")
	instance.free()

func _test_enemy_pierce_intents_surface_icons() -> void:
	var board := CombatBoardView.new()
	for enemy_type: String in ["harrier"]:
		var pierce_intents: Array = []
		var non_pierce_attack_count: int = 0
		var enemy_def: Dictionary = GameData.enemy_def(enemy_type)
		for intent_var: Variant in enemy_def.get("intents", []):
			if typeof(intent_var) != TYPE_DICTIONARY:
				continue
			var intent: Dictionary = intent_var
			var has_attack: bool = false
			var has_pierce: bool = false
			for action_var: Variant in intent.get("actions", []):
				if typeof(action_var) != TYPE_DICTIONARY:
					continue
				var action: Dictionary = action_var
				var action_type: String = str(action.get("type", ""))
				if action_type in ["melee", "ranged", "aoe", "push", "pull"]:
					has_attack = true
					if bool(action.get("pierce", false)):
						has_pierce = true
			if has_pierce:
				pierce_intents.append(intent)
			elif has_attack:
				non_pierce_attack_count += 1
		_assert(pierce_intents.size() == 1, "%s should have exactly one pierce attack intent" % str(enemy_def.get("name", enemy_type)))
		_assert(non_pierce_attack_count >= 1, "%s should keep at least one non-pierce attack intent" % str(enemy_def.get("name", enemy_type)))
		if pierce_intents.is_empty():
			continue
		var found_pierce_icon: bool = false
		for row_var: Variant in board.call("_intent_rows", pierce_intents[0]):
			if typeof(row_var) != TYPE_ARRAY:
				continue
			for token_var: Variant in row_var as Array:
				if typeof(token_var) != TYPE_DICTIONARY:
					continue
				if str((token_var as Dictionary).get("icon", "")) == "pierce":
					found_pierce_icon = true
		_assert(found_pierce_icon, "%s pierce intent should render with the pierce icon" % str(enemy_def.get("name", enemy_type)))
	board.free()

func _test_bile_bloomer_poison_and_expose_intents_apply_to_player() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var poison_layout: Dictionary = _simple_room_layout()
	poison_layout["enemies"] = [{
		"id": 1,
		"type": "bile_bloomer",
		"pos": Vector2i(3, 4),
		"hp": 160,
		"max_hp": 160,
		"block": 0
	}]
	var poison_state: Dictionary = combat.create_combat(23101, poison_layout, {
		"hp": 240,
		"max_hp": 240,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_set_enemy_intent(poison_state, 0, _enemy_intent_by_id("bile_bloomer", "bile_burst"))
	var poison_threat: Dictionary = combat.enemy_threat_tiles(poison_state, 0)
	var poison_attack_tiles: Array = poison_threat.get("attack", []) as Array
	_assert(poison_attack_tiles.has(Vector2i(2, 4)), "Bile Burst threat preview should show the player's tile before poison resolves")
	_assert(poison_attack_tiles.has(Vector2i(1, 4)), "Bile Burst should preview the outer cardinal tile in its wider poison diamond")
	_assert(poison_attack_tiles.has(Vector2i(2, 3)), "Bile Burst should preview the outer diagonal tile in its wider poison diamond")
	var bile_burst: Dictionary = _enemy_intent_by_id("bile_bloomer", "bile_burst")
	var bile_burst_actions: Array = bile_burst.get("actions", [])
	var bile_burst_aoe: Dictionary = bile_burst_actions[1] as Dictionary
	_assert((bile_burst_aoe.get("pattern", []) as Array).size() == 12, "Bile Burst should use a radius-2 diamond around the Bloomer")
	var poison_result: Dictionary = combat.resolve_enemy_turn_with_steps(poison_state, 0)
	var poisoned_player: Dictionary = (poison_result.get("state", {}) as Dictionary).get("player", {})
	var poison: Dictionary = poisoned_player.get("poison", {})
	_assert(int(poison.get("damage", 0)) == GameData.fixed_point_amount(2), "Bile Burst should apply poison through its revealed enemy intent")
	_assert(int(poison.get("delay", 0)) == 2, "Bile Burst poison should use the existing delayed poison cadence")

	var expose_layout: Dictionary = _simple_room_layout()
	expose_layout["enemies"] = [{
		"id": 1,
		"type": "bile_bloomer",
		"pos": Vector2i(5, 4),
		"hp": 160,
		"max_hp": 160,
		"block": 0
	}]
	var expose_state: Dictionary = combat.create_combat(23102, expose_layout, {
		"hp": 240,
		"max_hp": 240,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_set_enemy_intent(expose_state, 0, _enemy_intent_by_id("bile_bloomer", "spore_mark"))
	var expose_threat: Dictionary = combat.enemy_threat_tiles(expose_state, 0)
	_assert((expose_threat.get("attack", []) as Array).has(Vector2i(2, 4)), "Spore Mark threat preview should show the player's tile before expose resolves")
	var expose_result: Dictionary = combat.resolve_enemy_turn_with_steps(expose_state, 0)
	var exposed_player: Dictionary = (expose_result.get("state", {}) as Dictionary).get("player", {})
	_assert(int(exposed_player.get("expose", 0)) == GameData.fixed_point_amount(2), "Spore Mark should apply expose through its revealed enemy intent")

func _test_bile_bloomer_intents_surface_poison_and_expose_icons() -> void:
	var board := CombatBoardView.new()
	var poison_intent: Dictionary = _enemy_intent_by_id("bile_bloomer", "bile_burst")
	var expose_intent: Dictionary = _enemy_intent_by_id("bile_bloomer", "spore_mark")
	var found_poison_icon: bool = false
	var found_expose_icon: bool = false
	var poison_tooltip: String = ""
	var expose_tooltip: String = ""
	for poison_row_var: Variant in board.call("_intent_rows", poison_intent):
		if typeof(poison_row_var) != TYPE_ARRAY:
			continue
		for poison_token_var: Variant in poison_row_var as Array:
			if typeof(poison_token_var) != TYPE_DICTIONARY:
				continue
			var poison_token: Dictionary = poison_token_var
			if str(poison_token.get("icon", "")) == "poison":
				found_poison_icon = true
				poison_tooltip = ActionIcons.token_tooltip(poison_token)
	for expose_row_var: Variant in board.call("_intent_rows", expose_intent):
		if typeof(expose_row_var) != TYPE_ARRAY:
			continue
		for expose_token_var: Variant in expose_row_var as Array:
			if typeof(expose_token_var) != TYPE_DICTIONARY:
				continue
			var expose_token: Dictionary = expose_token_var
			if str(expose_token.get("icon", "")) == "expose":
				found_expose_icon = true
				expose_tooltip = ActionIcons.token_tooltip(expose_token)
	_assert(found_poison_icon, "Bile Burst enemy intent rows should surface a poison icon")
	_assert(poison_tooltip.contains("Delayed damage"), "Poison intent icon tooltip should explain delayed damage")
	_assert(found_expose_icon, "Spore Mark enemy intent rows should surface an expose icon")
	_assert(expose_tooltip.contains("next hit"), "Expose intent icon tooltip should explain the next-hit setup")
	board.free()

func _test_pierce_cards_stay_in_allowed_elements() -> void:
	var allowed_elements: Dictionary = {
		"none": true,
		"ice": true,
		"earth": true
	}
	for card_id: String in GameData.cards().keys():
		var card: Dictionary = GameData.card_def(card_id)
		var has_pierce: bool = false
		for action_var: Variant in card.get("actions", []):
			if typeof(action_var) != TYPE_DICTIONARY:
				continue
			if bool((action_var as Dictionary).get("pierce", false)):
				has_pierce = true
				break
		if not has_pierce:
			continue
		var card_element: String = GameData.card_element_from_def(card)
		_assert(bool(allowed_elements.get(card_element, false)), "Pierce cards should currently stay neutral, ice, or earth: %s" % card_id)

func _test_immobilize_cards_stay_in_allowed_elements() -> void:
	var allowed_elements: Dictionary = {
		"none": true,
		"ice": true,
		"earth": true
	}
	for card_id: String in GameData.cards().keys():
		var card: Dictionary = GameData.card_def(card_id)
		var has_immobilize: bool = false
		for action_var: Variant in card.get("actions", []):
			if typeof(action_var) != TYPE_DICTIONARY:
				continue
			var action: Dictionary = action_var as Dictionary
			if bool(action.get("immobilize", false)) or bool((action.get("intensity_bonus", {}) as Dictionary).get("immobilize", false)):
				has_immobilize = true
				break
		if not has_immobilize:
			continue
		var card_element: String = GameData.card_element_from_def(card)
		_assert(bool(allowed_elements.get(card_element, false)), "Immobilize cards should currently stay neutral, ice, or earth: %s" % card_id)

func _test_healing_cards_are_burned_and_downweighted() -> void:
	var patch_up: Dictionary = GameData.card_def("patch_up")
	_assert(bool(patch_up.get("burn", false)), "Starter recovery should burn so recovery is a shorter-term tactical choice")
	_assert(int((patch_up.get("actions", [])[0] as Dictionary).get("amount", 0)) <= 3, "Patch Up should provide only modest tactical recovery")
	var cinch_straps: Dictionary = GameData.card_def("rallying_breath")
	_assert(str(cinch_straps.get("name", "")) == "Cinch Straps", "Boiled Leather should own a defensive strap-tightening card instead of generic healing")
	_assert(not bool(cinch_straps.get("reward_pool", true)), "Equipment-owned neutral utility should stay out of normal reward offers")
	_assert(str(((cinch_straps.get("actions", []) as Array)[0] as Dictionary).get("type", "")) == "block", "Cinch Straps should be armor defense, not a healing reward")
	var glass_mending: Dictionary = GameData.card_def("last_light")
	_assert(str(glass_mending.get("name", "")) == "Glass Mending", "Glassbone Cuirass should own a thematic mending card")
	_assert(not bool(glass_mending.get("reward_pool", true)), "Equipment-owned mending should stay out of normal reward offers")
	_assert(int(((glass_mending.get("actions", []) as Array)[0] as Dictionary).get("amount", 0)) <= 3, "Glass Mending should be modest equipment recovery")

func _test_low_movement_enemies_advance_without_outpacing_crawlers() -> void:
	var crawler_weighted_average: float = _weighted_average_enemy_toward_move("crawler")
	var acolyte_weighted_average: float = _weighted_average_enemy_toward_move("acolyte")
	var warden_weighted_average: float = _weighted_average_enemy_toward_move("warden")
	var crawler_average: float = _average_enemy_toward_move("crawler")
	var acolyte_average: float = _average_enemy_toward_move("acolyte")
	var warden_average: float = _average_enemy_toward_move("warden")
	_assert(_enemy_distinct_toward_move_count("crawler") > 1, "Crawlers should vary their movement budget across intents instead of repeating the same step")
	_assert(_enemy_distinct_toward_move_count("acolyte") > 1, "Acolytes should vary their step sizes instead of always taking the same drift action")
	_assert(_enemy_distinct_toward_move_count("warden") > 1, "Wardens should mix planted turns with heavier steps")
	_assert(is_equal_approx(crawler_average, 3.0), "Crawlers should average three tiles of forward movement across their intents")
	_assert(is_equal_approx(acolyte_average, 2.0), "Acolytes should average two tiles of forward movement across their intents")
	_assert(is_equal_approx(warden_average, 1.0), "Wardens should average one tile of forward movement across their intents")
	_assert(crawler_weighted_average > acolyte_weighted_average, "Crawlers should move more aggressively than acolytes in actual intent frequency")
	_assert(warden_weighted_average < crawler_weighted_average, "Wardens should stay slower than crawlers in actual intent frequency")

func _test_harrier_has_moving_ranged_attack() -> void:
	var found: bool = false
	for intent_var: Variant in GameData.enemy_def("harrier").get("intents", []):
		if typeof(intent_var) != TYPE_DICTIONARY:
			continue
		var has_move_toward: bool = false
		var has_ranged_attack: bool = false
		for action_var: Variant in (intent_var as Dictionary).get("actions", []):
			if typeof(action_var) != TYPE_DICTIONARY:
				continue
			var action: Dictionary = action_var as Dictionary
			if str(action.get("type", "")) == "move_toward" and int(action.get("range", 0)) > 0:
				has_move_toward = true
			if str(action.get("type", "")) == "ranged" and int(action.get("damage", 0)) > 0:
				has_ranged_attack = true
		if has_move_toward and has_ranged_attack:
			found = true
			break
	_assert(found, "Harriers should have at least one ranged attack that advances before firing")

func _test_chainbound_gaoler_profile_and_mechanics() -> void:
	var gaoler_def: Dictionary = GameData.enemy_def("chainbound_gaoler")
	_assert(str(gaoler_def.get("name", "")) == "Chainbound Gaoler", "Chainbound Gaoler enemy data should load by id")
	_assert(int(gaoler_def.get("max_hp", 0)) == 14, "Chainbound Gaoler HP should keep its natural-unit control-anchor profile")
	_assert(int(gaoler_def.get("base_initiative", 0)) == 13, "Chainbound Gaoler should sit between acolyte and warden initiative")
	_assert(int(gaoler_def.get("reward_embers", 0)) == 12, "Chainbound Gaoler should reward mid-depth normal enemy embers")
	_assert(FileAccess.file_exists(str(gaoler_def.get("art_path", ""))), "Chainbound Gaoler should use runtime-visible raster art")
	for intent_id: String in ["chain_reel", "manacle_pin", "cudgel_press", "iron_guard"]:
		_assert(not _enemy_intent_by_id("chainbound_gaoler", intent_id).is_empty(), "Chainbound Gaoler should define %s intent" % intent_id)

	var combat: CombatEngine = CombatEngine.new()
	var pull_state: Dictionary = _chainbound_gaoler_combat_state(9117, Vector2i(2, 4), Vector2i(5, 4), "chain_reel")
	var pull_phase: Dictionary = combat.resolve_enemy_phase_with_steps(pull_state)
	var after_pull: Dictionary = pull_phase.get("state", {})
	var pulled_player: Dictionary = after_pull.get("player", {})
	_assert(pulled_player.get("pos", Vector2i.ZERO) == Vector2i(4, 4), "Chainbound Gaoler Chain Reel should pull the player two tiles inward")
	var saw_pull_step: bool = false
	for step_var: Variant in pull_phase.get("steps", []):
		if typeof(step_var) == TYPE_DICTIONARY and str((step_var as Dictionary).get("kind", "")) == "pull":
			saw_pull_step = true
			break
	_assert(saw_pull_step, "Chainbound Gaoler pull should produce a visible pull animation step")

	var pin_state: Dictionary = _chainbound_gaoler_combat_state(9118, Vector2i(2, 4), Vector2i(4, 4), "manacle_pin")
	var pin_phase: Dictionary = combat.resolve_enemy_phase_with_steps(pin_state)
	var after_pin: Dictionary = pin_phase.get("state", {})
	_assert(bool((after_pin.get("player", {}) as Dictionary).get("immobilize", false)), "Chainbound Gaoler Manacle Pin should apply player immobilize")
	after_pin = combat.prepare_next_player_turn(after_pin)
	_assert(not combat.player_action_can_resolve(after_pin, {"type": "move", "range": 2}), "Gaoler immobilize should block movement on the next player turn")
	_assert(not combat.player_action_can_resolve(after_pin, {"type": "blink", "range": 3}), "Gaoler immobilize should block blink on the next player turn")
	_assert(combat.player_action_can_resolve(after_pin, {"type": "block", "amount": 4}), "Gaoler immobilize should leave non-movement actions playable")

func _test_chainbound_gaoler_intent_icons_and_previews() -> void:
	var board := CombatBoardView.new()
	var pull_intent: Dictionary = _enemy_intent_by_id("chainbound_gaoler", "chain_reel")
	var pin_intent: Dictionary = _enemy_intent_by_id("chainbound_gaoler", "manacle_pin")
	var pull_rows: Array = board.call("_intent_rows", pull_intent)
	var pin_rows: Array = board.call("_intent_rows", pin_intent)
	_assert(_intent_rows_have_icon(pull_rows, "pull"), "Chainbound Gaoler Chain Reel intent row should show the pull icon")
	_assert(_intent_rows_have_icon(pull_rows, "range"), "Chainbound Gaoler Chain Reel intent row should show pull range before it acts")
	_assert(_intent_rows_have_icon(pin_rows, "immobilize"), "Chainbound Gaoler Manacle Pin intent row should show the immobilize icon")
	board.free()

	var combat: CombatEngine = CombatEngine.new()
	var pull_state: Dictionary = _chainbound_gaoler_combat_state(9119, Vector2i(2, 4), Vector2i(5, 4), "chain_reel")
	var pull_threat: Dictionary = combat.enemy_threat_tiles(pull_state, 0)
	_assert((pull_threat.get("attack", []) as Array).has(Vector2i(2, 4)), "Chainbound Gaoler pull preview should mark the player tile before the enemy acts")
	_assert((pull_threat.get("attack", []) as Array).has(Vector2i(4, 4)), "Chainbound Gaoler pull preview should mark tiles inside its chain reach")
	var pin_state: Dictionary = _chainbound_gaoler_combat_state(9120, Vector2i(2, 4), Vector2i(4, 4), "manacle_pin")
	var pin_threat: Dictionary = combat.enemy_threat_tiles(pin_state, 0)
	_assert((pin_threat.get("attack", []) as Array).has(Vector2i(2, 4)), "Chainbound Gaoler immobilize preview should mark the player tile before the enemy acts")

func _test_grave_surgeon_data_and_pool_role() -> void:
	var surgeon_def: Dictionary = GameData.enemy_def("grave_surgeon")
	_assert(str(surgeon_def.get("name", "")) == "Grave Surgeon", "Grave Surgeon enemy data should load")
	_assert(FileAccess.file_exists(str(surgeon_def.get("art_path", ""))), "Grave Surgeon should use project enemy art")
	_assert(int(surgeon_def.get("max_hp", 0)) == 10, "Grave Surgeon HP should stay in support-enemy range")
	_assert(int(surgeon_def.get("reward_embers", 0)) == 11, "Grave Surgeon should reward normal support-enemy embers")
	var support_intent_count: int = 0
	var attack_damage_total: int = 0
	for intent_var: Variant in surgeon_def.get("intents", []):
		if typeof(intent_var) != TYPE_DICTIONARY:
			continue
		for action_var: Variant in (intent_var as Dictionary).get("actions", []):
			if typeof(action_var) != TYPE_DICTIONARY:
				continue
			var action: Dictionary = action_var as Dictionary
			match str(action.get("type", "")):
				"heal_ally", "guard_ally":
					support_intent_count += 1
				"melee", "ranged", "aoe", "push", "pull":
					attack_damage_total += int(action.get("damage", 0))
	_assert(support_intent_count >= 2, "Grave Surgeon should be defined by reusable support actions")
	_assert(attack_damage_total <= 3, "Grave Surgeon's offensive pressure should stay low")
	var generator := RoomGenerator.new()
	var rng := RandomNumberGenerator.new()
	var saw_surgeon: bool = false
	for depth: int in [1, 2, 3]:
		var saw_surgeon_at_depth: bool = false
		for seed: int in range(24):
			rng.seed = seed
			var enemy_types: Array = generator.call("_encounter_enemy_types", "combat", depth, rng)
			if not enemy_types.has("grave_surgeon"):
				continue
			saw_surgeon = true
			saw_surgeon_at_depth = true
			_assert(enemy_types.size() >= 3, "Grave Surgeon should appear in multi-enemy rooms")
			_assert(enemy_types.has("crawler") or enemy_types.has("harrier") or enemy_types.has("warden"), "Grave Surgeon should be paired with front-line enemies")
		_assert(saw_surgeon_at_depth, "Grave Surgeon should appear in depth-%d encounter pools" % depth)
	_assert(saw_surgeon, "Grave Surgeon should appear in all standard encounter depth pools")

func _test_grave_surgeon_support_actions_scale() -> void:
	var suture: Dictionary = _enemy_intent_by_id("grave_surgeon", "triage_suture")
	var brace: Dictionary = _enemy_intent_by_id("grave_surgeon", "field_brace")
	var suture_action: Dictionary = (suture.get("actions", []) as Array)[1]
	var brace_action: Dictionary = (brace.get("actions", []) as Array)[1]
	_assert(str(suture_action.get("type", "")) == "heal_ally", "Triage Suture should use the reusable heal_ally action")
	_assert(str(brace_action.get("type", "")) == "guard_ally", "Field Brace should use the reusable guard_ally action")
	_assert(int(suture_action.get("amount", 0)) == 2, "heal_ally should use authored natural units")
	_assert(int(brace_action.get("amount", 0)) == 3, "guard_ally should use authored natural units")
	var combat := CombatEngine.new()
	var shallow_suture: Dictionary = combat.call("_scale_enemy_intent", suture, 1)
	var shallow_heal: Dictionary = (shallow_suture.get("actions", []) as Array)[1]
	_assert(int(shallow_heal.get("amount", 0)) == 1, "Depth-one support scaling should downshift heal_ally")
	var later_brace: Dictionary = combat.call("_scale_enemy_intent", brace, 10)
	var later_guard: Dictionary = (later_brace.get("actions", []) as Array)[1]
	_assert(int(later_guard.get("amount", 0)) == 4, "Later-sequence support scaling should raise guard_ally on the bounded curve")

func _test_heal_ally_targets_most_injured_ally() -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _support_action_test_state()
	var action: Dictionary = {"type": "heal_ally", "amount": 2, "range": 4}
	var before: Dictionary = state.duplicate(true)
	var resolved: Dictionary = combat.call("_resolve_enemy_action", state, 0, action)
	var enemies: Array = resolved.get("enemies", [])
	_assert(int((enemies[1] as Dictionary).get("hp", 0)) == 6, "heal_ally should target the ally with the most missing HP")
	_assert(int((enemies[2] as Dictionary).get("hp", 0)) == 7, "heal_ally should not heal a less injured ally first")
	_assert(_combat_log_contains(resolved, "Grave Surgeon stitches Tunnel Crawler"), "heal_ally logs should name the supported ally")
	var step: Dictionary = combat.call("_enemy_action_step", before, resolved, 0, action)
	_assert(str(step.get("kind", "")) == "heal", "heal_ally should produce a heal animation step")
	_assert(str(step.get("actor_key", "")) == "enemy_2", "heal_ally step should focus the healed ally")
	_assert(str(step.get("source_actor_key", "")) == "enemy_1", "heal_ally step should preserve the Surgeon as source")

func _test_heal_ally_falls_back_to_self() -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _support_action_test_state()
	var enemies: Array = state.get("enemies", [])
	var surgeon: Dictionary = enemies[0]
	surgeon["hp"] = 5
	enemies[0] = surgeon
	var crawler: Dictionary = enemies[1]
	crawler["hp"] = int(crawler.get("max_hp", 1))
	enemies[1] = crawler
	var harrier: Dictionary = enemies[2]
	harrier["hp"] = int(harrier.get("max_hp", 1))
	enemies[2] = harrier
	state["enemies"] = enemies
	var action: Dictionary = {"type": "heal_ally", "amount": 2, "range": 4}
	var before: Dictionary = state.duplicate(true)
	var resolved: Dictionary = combat.call("_resolve_enemy_action", state, 0, action)
	var resolved_enemies: Array = resolved.get("enemies", [])
	_assert(int((resolved_enemies[0] as Dictionary).get("hp", 0)) == 7, "heal_ally should fall back to the source when it is the only injured ally")
	_assert(_combat_log_contains(resolved, "Grave Surgeon stitches itself"), "Self fallback logs should say itself")
	var step: Dictionary = combat.call("_enemy_action_step", before, resolved, 0, action)
	_assert(str(step.get("actor_key", "")) == "enemy_1", "Self fallback heal step should focus the Surgeon")
	_assert(str(step.get("label", "")) == "Heal Self", "Self fallback heal step should label the self target")

func _test_heal_ally_no_target_noops() -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _support_action_test_state()
	var enemies: Array = state.get("enemies", [])
	for index: int in range(enemies.size()):
		var enemy: Dictionary = enemies[index]
		enemy["hp"] = int(enemy.get("max_hp", 1))
		enemies[index] = enemy
	state["enemies"] = enemies
	var action: Dictionary = {"type": "heal_ally", "amount": 2, "range": 4}
	var resolved: Dictionary = combat.call("_resolve_enemy_action", state, 0, action)
	var resolved_enemies: Array = resolved.get("enemies", [])
	for index: int in range(resolved_enemies.size()):
		var enemy: Dictionary = resolved_enemies[index]
		_assert(int(enemy.get("hp", 0)) == int(enemy.get("max_hp", 1)), "heal_ally should no-op when no live enemy is injured")
	var step: Dictionary = combat.call("_enemy_action_step", state, resolved, 0, action)
	_assert(step.is_empty(), "heal_ally no-op should not produce a presentation step")

func _test_guard_ally_targets_threatened_ally() -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _support_action_test_state()
	var action: Dictionary = {"type": "guard_ally", "amount": 3, "range": 4}
	var before: Dictionary = state.duplicate(true)
	var resolved: Dictionary = combat.call("_resolve_enemy_action", state, 0, action)
	var enemies: Array = resolved.get("enemies", [])
	_assert(int((enemies[1] as Dictionary).get("block", 0)) == 3, "guard_ally should target the ally nearest the player")
	_assert(int((enemies[0] as Dictionary).get("block", 0)) == 0, "guard_ally should not guard itself when a more threatened ally exists")
	_assert(_combat_log_contains(resolved, "Grave Surgeon guards Tunnel Crawler"), "guard_ally logs should name the guarded ally")
	var step: Dictionary = combat.call("_enemy_action_step", before, resolved, 0, action)
	_assert(str(step.get("kind", "")) == "block", "guard_ally should produce a block animation step")
	_assert(str(step.get("actor_key", "")) == "enemy_2", "guard_ally step should focus the guarded ally")
	_assert(str(step.get("source_actor_key", "")) == "enemy_1", "guard_ally step should preserve the Surgeon as source")

func _test_support_intent_rows_name_target() -> void:
	var board := CombatBoardView.new()
	board.combat_state = _support_action_test_state()
	var surgeon_unit := {
		"key": "enemy_1",
		"id": 1,
		"role": "enemy",
		"type": "grave_surgeon",
		"pos": Vector2i(5, 4),
		"hp": 10,
		"max_hp": 10
	}
	var heal_rows: Array = board.call("_intent_rows_for_unit", surgeon_unit, {"actions": [{"type": "heal_ally", "amount": 2, "range": 4}]})
	_assert(heal_rows.size() == 1, "heal_ally should surface an intent row")
	_assert(ActionIcons.plain_text_for_tokens(heal_rows[0] as Array).find("-> Crawler") >= 0, "heal_ally intent row should name the ally target")
	var state: Dictionary = _support_action_test_state()
	var enemies: Array = state.get("enemies", [])
	var surgeon: Dictionary = enemies[0]
	surgeon["hp"] = 5
	enemies[0] = surgeon
	for index: int in range(1, enemies.size()):
		var enemy: Dictionary = enemies[index]
		enemy["hp"] = int(enemy.get("max_hp", 1))
		enemies[index] = enemy
	state["enemies"] = enemies
	board.combat_state = state
	var self_rows: Array = board.call("_intent_rows_for_unit", surgeon_unit, {"actions": [{"type": "heal_ally", "amount": 2, "range": 4}]})
	_assert(ActionIcons.plain_text_for_tokens(self_rows[0] as Array).find("-> Self") >= 0, "heal_ally intent row should say when the Surgeon targets itself")
	board.free()

func _test_support_intent_target_marker_is_text_only() -> void:
	var board := CombatBoardView.new()
	board.combat_state = _support_action_test_state()
	var surgeon_unit := {
		"key": "enemy_1",
		"id": 1,
		"role": "enemy",
		"type": "grave_surgeon",
		"pos": Vector2i(5, 4),
		"hp": 10,
		"max_hp": 10
	}
	var rows: Array = board.call("_intent_rows_for_unit", surgeon_unit, {"actions": [{"type": "heal_ally", "amount": 2, "range": 4}]})
	_assert(rows.size() == 1, "heal_ally should still surface one intent row")
	var tokens: Array = rows[0] as Array
	_assert(tokens.size() == 2, "heal_ally support rows should show the action token and a target marker")
	_assert(str((tokens[0] as Dictionary).get("icon", "")) == "heal", "heal_ally should keep the heal icon as the only action icon")
	_assert(str((tokens[1] as Dictionary).get("kind", "")) == "text", "Support targets should render as text-only markers")
	_assert(not (tokens[1] as Dictionary).has("icon"), "Support target markers should not add a health icon")
	_assert(ActionIcons.plain_text_for_tokens(tokens) == "Heal 2  -> Crawler", "Support target plain text should not include a Health label")
	board.free()

func _test_turn_order_uses_explicit_portraits_for_new_enemy_types() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = run_scene.instantiate()
	var surgeon_path: String = str(instance.call("_turn_order_portrait_path", {"kind": "enemy", "type": "grave_surgeon"}))
	_assert(surgeon_path == "res://assets/art/portraits/grave_surgeon.png", "Turn order should use explicit portraits for new enemies")
	_assert(FileAccess.file_exists(surgeon_path), "Grave Surgeon turn-order portrait should exist")
	var crawler_path: String = str(instance.call("_turn_order_portrait_path", {"kind": "enemy", "type": "crawler"}))
	_assert(crawler_path.find("tunnel_crawler.png") >= 0, "Existing enemies should keep their dedicated turn-order portraits")
	var unknown_path: String = str(instance.call("_turn_order_portrait_path", {"kind": "enemy", "type": "unknown_enemy"}))
	_assert(unknown_path.find("player_reaver.png") >= 0, "Unknown turn-order entries should still fall back safely")
	instance.free()

func _average_enemy_toward_move(enemy_type: String) -> float:
	var enemy_def: Dictionary = GameData.enemy_def(enemy_type)
	var intent_count: int = 0
	var total_move: int = 0
	for intent_var: Variant in enemy_def.get("intents", []):
		if typeof(intent_var) != TYPE_DICTIONARY:
			continue
		var intent: Dictionary = intent_var as Dictionary
		intent_count += 1
		total_move += _intent_toward_move(intent)
	if intent_count <= 0:
		return 0.0
	return float(total_move) / float(intent_count)

func _weighted_average_enemy_toward_move(enemy_type: String) -> float:
	var enemy_def: Dictionary = GameData.enemy_def(enemy_type)
	var total_weight: int = 0
	var weighted_move: int = 0
	for intent_var: Variant in enemy_def.get("intents", []):
		if typeof(intent_var) != TYPE_DICTIONARY:
			continue
		var intent: Dictionary = intent_var as Dictionary
		var weight: int = maxi(1, int(intent.get("weight", 1)))
		total_weight += weight
		weighted_move += weight * _intent_toward_move(intent)
	if total_weight <= 0:
		return 0.0
	return float(weighted_move) / float(total_weight)

func _enemy_distinct_toward_move_count(enemy_type: String) -> int:
	var distinct: Dictionary = {}
	for intent_var: Variant in GameData.enemy_def(enemy_type).get("intents", []):
		if typeof(intent_var) != TYPE_DICTIONARY:
			continue
		distinct[_intent_toward_move(intent_var as Dictionary)] = true
	return distinct.size()

func _intent_toward_move(intent: Dictionary) -> int:
	var total_move: int = 0
	for action_var: Variant in intent.get("actions", []):
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_var as Dictionary
		if str(action.get("type", "")) == "move_toward":
			total_move += int(action.get("range", 0))
	return total_move

func _test_player_block_absorbs_full_enemy_phase() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(18, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["brace"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state = combat.apply_player_action(state, {"type": "block", "amount": 8})
	state["enemies"] = [
		{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(3, 4),
			"hp": 14,
			"max_hp": 14,
			"block": 0,
			"intent": {"name": "Claw", "actions": [{"type": "melee", "damage": 5, "range": 1}]}
		},
		{
			"id": 2,
			"type": "harrier",
			"pos": Vector2i(2, 2),
			"hp": 10,
			"max_hp": 10,
			"block": 0,
			"intent": {"name": "Pelt", "actions": [{"type": "ranged", "damage": 4, "range": 4}]}
		}
	]
	var hp_before: int = int((state.get("player", {}) as Dictionary).get("hp", 0))
	state = combat.resolve_enemy_phase(state)
	var player: Dictionary = state.get("player", {})
	_assert(int(player.get("hp", 0)) == hp_before - 1, "Player block should absorb damage across the whole enemy phase before health is lost")
	_assert(int(player.get("block", 0)) == 0, "Enemy attacks should consume player block before health")

func _test_enemy_block_applies_on_actor_turn_only() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(19, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["enemies"] = [
		{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(3, 4),
			"hp": 14,
			"max_hp": 14,
			"block": 0,
			"intent": {"name": "Coil", "actions": [{"type": "block", "amount": 4}]}
		}
	]
	state = combat._apply_revealed_intent_blocks(state)
	var blocked_enemy: Dictionary = (state.get("enemies", []) as Array)[0]
	_assert(int(blocked_enemy.get("block", 0)) == 0, "Enemy block intents should not become real block before that enemy acts")
	state = combat.apply_player_action(state, {"type": "melee", "damage": 6, "range": 1}, Vector2i(3, 4))
	blocked_enemy = (state.get("enemies", []) as Array)[0]
	_assert(int(blocked_enemy.get("hp", 0)) == 8, "Future enemy block should not mitigate the current player turn")
	_assert(int(blocked_enemy.get("block", 0)) == 0, "Unresolved enemy block intent should remain non-mitigating")
	state["enemies"] = [
		{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(3, 4),
			"hp": 14,
			"max_hp": 14,
			"block": 0,
			"intent": {"name": "Coil", "time": 2, "actions": [{"type": "block", "amount": 4}]}
		}
	]
	var block_turn: Dictionary = combat.resolve_enemy_turn_with_steps(state, 0)
	state = block_turn.get("state", {})
	blocked_enemy = (state.get("enemies", []) as Array)[0]
	_assert(int(blocked_enemy.get("block", 0)) == 4, "Enemy block should apply when that enemy resolves its own block action")
	var enemies: Array = state.get("enemies", [])
	blocked_enemy = (enemies[0] as Dictionary).duplicate(true)
	blocked_enemy["intent"] = {"name": "Claw", "time": 2, "actions": [{"type": "melee", "damage": 1, "range": 1}]}
	enemies[0] = blocked_enemy
	state["enemies"] = enemies
	var next_turn: Dictionary = combat.resolve_enemy_turn_with_steps(state, 0)
	blocked_enemy = ((next_turn.get("state", {}) as Dictionary).get("enemies", []) as Array)[0]
	_assert(int(blocked_enemy.get("block", 0)) == 0, "Enemy block should expire when that enemy's next turn starts")

func _test_aoe_hits_multiple_targets() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(4, _aoe_test_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["cyclone_seal"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var action: Dictionary = GameData.card_def("cyclone_seal").get("actions", [])[0]
	state = combat.apply_player_action(state, action, Vector2i(4, 3))
	var enemies: Array = state.get("enemies", [])
	_assert(int((enemies[0] as Dictionary).get("hp", 0)) < int((enemies[0] as Dictionary).get("max_hp", 0)), "AOE should damage the first target")
	_assert(int((enemies[1] as Dictionary).get("hp", 0)) < int((enemies[1] as Dictionary).get("max_hp", 0)), "AOE should damage the second target in the pattern")

func _test_close_aoe_hits_adjacent_targets() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(41, _aoe_test_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["whirlwind_slash"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["player"] = {"pos": Vector2i(4, 4), "hp": 20, "max_hp": 20, "block": 0, "stoneskin": 0}
	state["enemies"] = [
		{"id": 1, "type": "crawler", "pos": Vector2i(4, 3), "hp": 14, "max_hp": 14, "block": 0},
		{"id": 2, "type": "harrier", "pos": Vector2i(5, 4), "hp": 10, "max_hp": 10, "block": 0},
		{"id": 3, "type": "acolyte", "pos": Vector2i(5, 5), "hp": 12, "max_hp": 12, "block": 0}
	]
	var action: Dictionary = GameData.card_def("whirlwind_slash").get("actions", [])[0]
	state = combat.apply_player_action(state, action)
	var enemies: Array = state.get("enemies", [])
	_assert(int((enemies[0] as Dictionary).get("hp", 0)) == 4, "Close AOE should hit the northern adjacent tile")
	_assert(int((enemies[1] as Dictionary).get("hp", 0)) == 0, "Close AOE should hit the eastern adjacent tile")
	_assert(int((enemies[2] as Dictionary).get("hp", 0)) == 12, "Close AOE should not hit diagonal tiles")

func _test_player_aoe_damages_incidental_terrain() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["player_start"] = Vector2i(4, 4)
	layout["terrain"] = [{
		"id": "aoe_box",
		"kind": "wooden_box",
		"pos": Vector2i(4, 3),
		"hp": 5,
		"max_hp": 5
	}]
	var state: Dictionary = combat.create_combat(41001, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["whirlwind_slash"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state = combat.apply_player_action(state, {
		"type": "aoe",
		"damage": 3,
		"range": 0,
		"pattern": [[0, -1], [1, 0]],
		"rotate": false
	})
	var terrain: Dictionary = (state.get("terrain", []) as Array)[0]
	_assert(int(terrain.get("hp", 0)) == 2, "Player AOE should damage destructible terrain on every affected square without directly targeting it")

func _test_rotated_line_aoe_uses_selected_orientation() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(4101, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["thunderline"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["player"] = {"pos": Vector2i(2, 4), "hp": 20, "max_hp": 20, "block": 0, "stoneskin": 0}
	state["enemies"] = [
		{"id": 1, "type": "crawler", "pos": Vector2i(4, 4), "hp": 20, "max_hp": 20, "block": 0},
		{"id": 2, "type": "harrier", "pos": Vector2i(4, 2), "hp": 20, "max_hp": 20, "block": 0},
		{"id": 3, "type": "acolyte", "pos": Vector2i(6, 4), "hp": 20, "max_hp": 20, "block": 0}
	]
	var action: Dictionary = {"type": "aoe", "damage": 5, "range": 6, "pattern": [[0, 0], [1, 0], [2, 0]], "rotate": true}
	_assert(combat.player_action_needs_orientation(action), "Asymmetric ranged line AOE should ask the player for an orientation")
	var north_action: Dictionary = action.duplicate(true)
	north_action["orientation"] = Vector2i(0, -1)
	var north_tiles: Array[Vector2i] = combat.aoe_tiles_for_player_action(state, north_action, Vector2i(4, 3))
	_assert(north_tiles.has(Vector2i(4, 2)) and north_tiles.has(Vector2i(4, 4)) and not north_tiles.has(Vector2i(6, 4)), "Line AOE preview should rotate around the selected center tile")
	var north_state: Dictionary = combat.apply_player_action(state, north_action, Vector2i(4, 3))
	var north_enemies: Array = north_state.get("enemies", [])
	_assert(int((north_enemies[1] as Dictionary).get("hp", 0)) == 15, "North-oriented line should hit the northern enemy")
	_assert(int((north_enemies[2] as Dictionary).get("hp", 0)) == 20, "North-oriented line should not hit the eastern enemy")
	var east_action: Dictionary = action.duplicate(true)
	east_action["orientation"] = Vector2i(1, 0)
	var east_tiles: Array[Vector2i] = combat.aoe_tiles_for_player_action(state, east_action, Vector2i(5, 4))
	_assert(east_tiles.has(Vector2i(4, 4)) and east_tiles.has(Vector2i(6, 4)) and not east_tiles.has(Vector2i(4, 2)), "East-oriented line should center on the hovered middle tile")
	var east_state: Dictionary = combat.apply_player_action(state, east_action, Vector2i(5, 4))
	var east_enemies: Array = east_state.get("enemies", [])
	_assert(int((east_enemies[1] as Dictionary).get("hp", 0)) == 20, "East-oriented line should not hit the northern enemy")
	_assert(int((east_enemies[2] as Dictionary).get("hp", 0)) == 15, "East-oriented line should hit the eastern enemy")

func _test_combat_board_orders_line_aoe_preview_tiles() -> void:
	var board := CombatBoardView.new()
	var east_tiles: Array = board.call("_ordered_aoe_line_tiles_for_effect", {
		"tiles": [Vector2i(5, 4), Vector2i(4, 4), Vector2i(6, 4)]
	})
	_assert(east_tiles == [Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4)], "Combat board should order horizontal AOE line tiles for the late-drawn guide")
	var north_tiles: Array = board.call("_ordered_aoe_line_tiles_for_effect", {
		"tiles": [Vector2i(4, 3), Vector2i(4, 2), Vector2i(4, 4)]
	})
	_assert(north_tiles == [Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4)], "Combat board should order vertical AOE line tiles for the late-drawn guide")
	var corner_tiles: Array = board.call("_ordered_aoe_line_tiles_for_effect", {
		"tiles": [Vector2i(4, 4), Vector2i(5, 4), Vector2i(4, 5)]
	})
	_assert(corner_tiles.is_empty(), "Combat board should not connect non-line AOE patterns with a line guide")
	board.free()

func _test_forced_movement_uses_selected_straight_line() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(4102, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["updraft"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["player"] = {"pos": Vector2i(2, 4), "hp": 20, "max_hp": 20, "block": 0, "stoneskin": 0}
	state["enemies"] = [
		{"id": 1, "type": "crawler", "pos": Vector2i(4, 4), "hp": 20, "max_hp": 20, "block": 0}
	]
	var push_action: Dictionary = {"type": "push", "amount": 2, "range": 5, "damage": 0, "force_direction": Vector2i(0, -1)}
	_assert(combat.player_action_needs_orientation(push_action), "Push actions should ask the player for a movement direction")
	var push_directions: Array[Vector2i] = combat.force_directions_for_player_action(state, push_action, Vector2i(4, 4))
	_assert(push_directions.has(Vector2i(0, -1)) and push_directions.has(Vector2i(1, 0)) and not push_directions.has(Vector2i(-1, 0)), "Push should only offer directions that move farther from the player")
	var push_preview: Array[Vector2i] = combat.forced_movement_tiles_for_player_action(state, push_action, Vector2i(4, 4))
	_assert(push_preview.size() == 2 and push_preview[0] == Vector2i(4, 3) and push_preview[1] == Vector2i(4, 2), "Push preview should follow a chosen straight line that increases distance")
	var pushed_state: Dictionary = combat.apply_player_action(state, push_action, Vector2i(4, 4))
	var pushed_enemy: Dictionary = (pushed_state.get("enemies", []) as Array)[0]
	_assert(pushed_enemy.get("pos", Vector2i.ZERO) == Vector2i(4, 2), "Push should move the target along the selected away direction")
	var invalid_push_action: Dictionary = {"type": "push", "amount": 1, "range": 5, "damage": 0, "force_direction": Vector2i(-1, 0)}
	_assert(not combat.valid_targets_for_player_action(state, invalid_push_action).has(Vector2i(4, 4)), "Push should reject directions that move the target closer to the player")
	var pull_action: Dictionary = {"type": "pull", "amount": 1, "range": 5, "damage": 0, "force_direction": Vector2i(-1, 0)}
	var pull_directions: Array[Vector2i] = combat.force_directions_for_player_action(state, pull_action, Vector2i(4, 4))
	_assert(pull_directions.size() == 1 and pull_directions.has(Vector2i(-1, 0)), "Pull should only offer directions that move closer to the player")
	var pulled_state: Dictionary = combat.apply_player_action(state, pull_action, Vector2i(4, 4))
	var pulled_enemy: Dictionary = (pulled_state.get("enemies", []) as Array)[0]
	_assert(pulled_enemy.get("pos", Vector2i.ZERO) == Vector2i(3, 4), "Pull should move the target along the selected closer direction")

func _test_enemy_phase_preserves_preview_cycle() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(21, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var before_intent: Dictionary = ((state.get("enemies", []) as Array)[0] as Dictionary).get("intent", {})
	var before_rng_state: int = int(state.get("rng_state", 0))
	state = combat.resolve_enemy_phase(state)
	var after_intent: Dictionary = ((state.get("enemies", []) as Array)[0] as Dictionary).get("intent", {})
	_assert(not before_intent.is_empty(), "Enemies should begin combat with a preview intent")
	_assert(not after_intent.is_empty(), "Enemies should roll another preview intent after acting")
	_assert(int(state.get("rng_state", 0)) != before_rng_state, "Enemy phase should advance deterministic RNG state")

func _test_elemental_room_rewards_follow_affinity(default_progression: Dictionary) -> void:
	var engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = engine.create_new_run(44, default_progression)
	var destination: Vector2i = Vector2i.ZERO
	for coord: Vector2i in engine.available_moves(run_state):
		var room: Dictionary = engine.room_metadata(run_state, coord)
		if str(room.get("type", "")) == "combat":
			destination = coord
			break
	_assert(destination != Vector2i.ZERO, "A fresh run should expose at least one combat room from the waypoint")
	run_state = engine.move_to_room(run_state, destination)
	var room_meta: Dictionary = engine.room_metadata(run_state, destination)
	var room_element: String = str(room_meta.get("element", "none"))
	_assert(room_element != "none", "Standard combat rooms should carry an elemental affinity")
	var combat_state: Dictionary = (run_state.get("combat_state", {}) as Dictionary).duplicate(true)
	combat_state["enemies"] = []
	var reward_state: Dictionary = engine.finish_combat(run_state, combat_state)
	var reward_cards: Array = ((reward_state.get("pending_reward", {}) as Dictionary).get("cards", []) as Array).duplicate()
	_assert(reward_cards.size() == 3, "Combat rewards should still offer three card choices")
	var elemental_count: int = 0
	var neutral_count: int = 0
	for card_id_var: Variant in reward_cards:
		var card_element: String = GameData.card_element(str(card_id_var))
		if card_element == room_element:
			elemental_count += 1
		if card_element == "none":
			neutral_count += 1
		_assert(ElementData.is_elemental(card_element), "Combat card rewards should stay elemental while equipment owns neutral utility")
	_assert(elemental_count >= 2, "Elemental combat rewards should favor at least two cards from the room's element")
	_assert(neutral_count == 0, "Elemental combat rewards should not offer neutral cards")

func _test_chain_hits_clustered_enemies() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _aoe_test_room_layout()
	layout["enemies"] = [
		{"id": 1, "type": "crawler", "pos": Vector2i(4, 3), "hp": 14, "max_hp": 14, "block": 0},
		{"id": 2, "type": "harrier", "pos": Vector2i(5, 3), "hp": 10, "max_hp": 10, "block": 0},
		{"id": 3, "type": "acolyte", "pos": Vector2i(6, 3), "hp": 12, "max_hp": 12, "block": 0}
	]
	var state: Dictionary = combat.create_combat(141, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["chain_bolt"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	for enemy_index: int in range((state.get("enemies", []) as Array).size()):
		var enemy: Dictionary = ((state.get("enemies", []) as Array)[enemy_index] as Dictionary).duplicate(true)
		enemy["block"] = 0
		enemy["intent"] = {}
		(state.get("enemies", []) as Array)[enemy_index] = enemy
	state = combat.apply_player_action(state, {"type": "ranged", "damage": 4, "range": 6, "chain": 2}, Vector2i(4, 3))
	var enemies: Array = state.get("enemies", [])
	_assert(int((enemies[0] as Dictionary).get("hp", 0)) == 10, "Chain attacks should hit the initial target")
	_assert(int((enemies[1] as Dictionary).get("hp", 0)) == 6, "Chain attacks should jump to a nearby second enemy")
	_assert(int((enemies[2] as Dictionary).get("hp", 0)) == 8, "Chain attacks should continue while valid nearby targets remain")

func _test_freeze_and_shock_control_turn_flow() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(155, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["frostbolt"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["enemies"] = [
		{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(4, 4),
			"hp": 14,
			"max_hp": 14,
			"block": 0,
			"intent": {"name": "Claw", "actions": [{"type": "melee", "damage": 5, "range": 2}]}
		}
	]
	state = combat.apply_player_action(state, {"type": "ranged", "damage": 4, "range": 6, "freeze": 1}, Vector2i(4, 4))
	state = combat.apply_player_action(state, {"type": "ranged", "damage": 3, "range": 6}, Vector2i(4, 4))
	var enemy: Dictionary = (state.get("enemies", []) as Array)[0]
	_assert(int(enemy.get("hp", 0)) == 4, "Frozen enemies should take double damage from follow-up hits")
	var hp_before_enemy_turn: int = int((state.get("player", {}) as Dictionary).get("hp", 0))
	var phase_result: Dictionary = combat.resolve_enemy_phase_with_steps(state)
	var after_enemy_phase: Dictionary = phase_result.get("state", {})
	_assert(int((after_enemy_phase.get("player", {}) as Dictionary).get("hp", 0)) == hp_before_enemy_turn, "Frozen enemies should skip their next turn")
	var player_state: Dictionary = combat.create_combat(156, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["guarded_step"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var player: Dictionary = (player_state.get("player", {}) as Dictionary).duplicate(true)
	player["shock"] = 1
	player_state["player"] = player
	player_state = combat.prepare_next_player_turn(player_state)
	_assert(combat.player_action_can_resolve(player_state, {"type": "move", "range": 2}), "Shock should still allow movement actions")
	_assert(not combat.player_action_can_resolve(player_state, {"type": "block", "amount": 4}), "Shock should block non-movement player actions for the turn")

func _test_immobilize_control_turn_flow() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(157, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["root_snare"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["enemies"] = [
		{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(4, 4),
			"hp": 14,
			"max_hp": 14,
			"block": 0,
			"intent": {"name": "Lunge", "actions": [{"type": "move_toward", "range": 2}, {"type": "melee", "damage": 5, "range": 1}]}
		}
	]
	state = combat.apply_player_action(state, {"type": "ranged", "damage": 0, "range": 6, "immobilize": true}, Vector2i(4, 4))
	var phase_result: Dictionary = combat.resolve_enemy_phase_with_steps(state)
	var after_phase: Dictionary = phase_result.get("state", {})
	var rooted_enemy: Dictionary = (after_phase.get("enemies", []) as Array)[0]
	_assert(rooted_enemy.get("pos", Vector2i.ZERO) == Vector2i(4, 4), "Immobilized enemies should skip movement actions for their activation")
	_assert(int((after_phase.get("player", {}) as Dictionary).get("hp", 0)) == 24, "Immobilize should deny attacks that needed movement to reach")

	var adjacent_state: Dictionary = combat.create_combat(158, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["root_snare"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	adjacent_state["enemies"] = [
		{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(3, 4),
			"hp": 14,
			"max_hp": 14,
			"block": 0,
			"intent": {"name": "Claw", "actions": [{"type": "move_toward", "range": 2}, {"type": "melee", "damage": 5, "range": 1}]}
		}
	]
	adjacent_state = combat.apply_player_action(adjacent_state, {"type": "ranged", "damage": 0, "range": 6, "immobilize": true}, Vector2i(3, 4))
	adjacent_state = combat.resolve_enemy_phase(adjacent_state)
	_assert(int((adjacent_state.get("player", {}) as Dictionary).get("hp", 0)) == 19, "Immobilized enemies should still attack if already in range")

	var player_state: Dictionary = combat.create_combat(159, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["guarded_step"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var player: Dictionary = (player_state.get("player", {}) as Dictionary).duplicate(true)
	player["immobilize"] = true
	player_state["player"] = player
	player_state = combat.prepare_next_player_turn(player_state)
	_assert(not combat.player_action_can_resolve(player_state, {"type": "move", "range": 2}), "Immobilize should block player movement actions for the turn")
	_assert(not combat.player_action_can_resolve(player_state, {"type": "blink", "range": 3}), "Immobilize should block player blink actions for the turn")
	_assert(combat.player_action_can_resolve(player_state, {"type": "block", "amount": 4}), "Immobilize should still allow non-movement player actions")

func _test_traps_trigger_and_apply_current_turn_control() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["traps"] = [{
		"id": "trap_3_4",
		"pos": Vector2i(3, 4),
		"element": "lightning",
		"damage": 2,
		"shock": 1
	}]
	var state: Dictionary = combat.create_combat(161, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["quick_stab"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	state["deck"] = deck
	state = combat.apply_player_action(state, {"type": "move", "range": 3}, Vector2i(5, 4))
	_assert((state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(5, 4), "Triggered traps should not halt movement mid-path")
	_assert((state.get("traps", []) as Array).is_empty(), "Triggered traps should be consumed immediately")
	_assert(str(state.get("pending_player_trap_restriction", "")) == "shock", "Trap control should wait until the current card finishes before applying this turn")
	state = combat.finish_player_card(state, 0)
	_assert(bool((state.get("player_turn_restrictions", {}) as Dictionary).get("shocked", false)), "Trap shock should apply to the current turn when a play remains after the card")
	_assert(combat.player_action_can_resolve(state, {"type": "move", "range": 2}), "Trap shock should still leave movement lines playable this turn")
	_assert(not combat.player_action_can_resolve(state, {"type": "block", "amount": 4}), "Trap shock should block non-movement follow-up plays this turn")

func _test_traps_roll_control_to_next_turn_when_no_plays_remain() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["traps"] = [{
		"id": "trap_3_4",
		"pos": Vector2i(3, 4),
		"element": "lightning",
		"damage": 2,
		"shock": 1
	}]
	var state: Dictionary = combat.create_combat(162, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["cards_played_this_turn"] = 1
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["quick_stab"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	state["deck"] = deck
	state = combat.apply_player_action(state, {"type": "move", "range": 3}, Vector2i(5, 4))
	_assert(int((state.get("player", {}) as Dictionary).get("shock", 0)) == 1, "Last-play trap shock should stay on the player for next turn setup")
	state = combat.finish_player_card(state, 0)
	_assert(not bool((state.get("player_turn_restrictions", {}) as Dictionary).get("shocked", false)), "Last-play trap shock should not retroactively lock the finished turn")
	state = combat.prepare_next_player_turn(state)
	_assert(bool((state.get("player_turn_restrictions", {}) as Dictionary).get("shocked", false)), "Last-play trap shock should carry into the next turn")

func _test_move_paths_only_cross_required_traps() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["element"] = ElementData.FIRE
	layout["traps"] = [
		{
			"id": "trap_3_4",
			"pos": Vector2i(3, 4),
			"element": "fire",
			"damage": 2,
			"burn": 1
		},
		{
			"id": "trap_5_4",
			"pos": Vector2i(5, 4),
			"element": "fire",
			"damage": 2,
			"burn": 1
		}
	]
	var state: Dictionary = combat.create_combat(163, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var move_action: Dictionary = {"type": "move", "range": 5}
	var goal: Vector2i = Vector2i(5, 4)
	var path: Array[Vector2i] = combat.path_for_player_action(state, move_action, goal)
	_assert(path.back() == goal, "Move previews should still reach trap destinations when the chosen square is the trap")
	_assert(not path.has(Vector2i(3, 4)), "Move paths should avoid extra traps when only the destination trap is required")
	state = combat.apply_player_action(state, move_action, goal)
	_assert((state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO) == goal, "Trap-aware move resolution should still land on the chosen tile")
	var remaining_traps: Array = state.get("traps", [])
	_assert(remaining_traps.size() == 1 and ((remaining_traps[0] as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(3, 4)), "Only the required destination trap should be consumed")
	_assert(int((state.get("player", {}) as Dictionary).get("hp", 0)) == 22, "Avoiding extra traps should only apply the destination trap's damage")

func _test_terrain_blocks_movement_without_blocking_line_of_sight() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(5, 4),
		"hp": 14,
		"max_hp": 14,
		"block": 0
	}]
	layout["terrain"] = [{
		"id": "terrain_3_4",
		"kind": "wooden_box",
		"pos": Vector2i(3, 4),
		"hp": 3,
		"max_hp": 3
	}]
	var state: Dictionary = combat.create_combat(164, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var move_targets: Array[Vector2i] = combat.valid_targets_for_player_action(state, {"type": "move", "range": 2})
	_assert(not move_targets.has(Vector2i(3, 4)), "Destructible terrain should block movement target tiles")
	var ranged_targets: Array[Vector2i] = combat.valid_targets_for_player_action(state, {"type": "ranged", "damage": 1, "range": 5})
	_assert(ranged_targets.has(Vector2i(5, 4)), "Destructible terrain should not block line of sight")
	state = combat.apply_player_action(state, {"type": "melee", "damage": 3, "range": 1}, Vector2i(3, 4))
	var terrain: Dictionary = (state.get("terrain", []) as Array)[0]
	_assert(int(terrain.get("hp", 0)) == 0, "Player attacks should be able to destroy low-HP terrain")

func _test_attacking_trap_blasts_adjacent_tiles() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["element"] = ElementData.FIRE
	layout["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(4, 4),
		"hp": 10,
		"max_hp": 10,
		"block": 0
	}]
	layout["traps"] = [{
		"id": "trap_3_4",
		"pos": Vector2i(3, 4),
		"element": ElementData.FIRE,
		"damage": 3,
		"burn": 1
	}]
	var state: Dictionary = combat.create_combat(165, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["spark_dart"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state = combat.apply_player_action(state, {"type": "ranged", "damage": 0, "range": 2}, Vector2i(3, 4))
	_assert((state.get("traps", []) as Array).is_empty(), "Attacking a trap should consume and trigger it even for zero attack damage")
	_assert(int((state.get("player", {}) as Dictionary).get("hp", 0)) == 17, "Trap blasts should damage the player on adjacent tiles")
	var enemy: Dictionary = (state.get("enemies", []) as Array)[0]
	_assert(int(enemy.get("hp", 0)) == 7, "Trap blasts should damage enemies on adjacent tiles")

func _test_trap_blasts_damage_incidental_terrain() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["element"] = ElementData.FIRE
	layout["player_start"] = Vector2i(2, 4)
	layout["terrain"] = [{
		"id": "blast_crate",
		"kind": "wooden_crate",
		"pos": Vector2i(4, 4),
		"hp": 3,
		"max_hp": 3
	}]
	layout["traps"] = [{
		"id": "trap_3_4",
		"pos": Vector2i(3, 4),
		"element": ElementData.FIRE,
		"damage": 3,
		"burn": 1
	}]
	var state: Dictionary = combat.create_combat(1651, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["spark_dart"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state = combat.apply_player_action(state, {"type": "ranged", "damage": 0, "range": 2}, Vector2i(3, 4))
	var terrain: Dictionary = (state.get("terrain", []) as Array)[0]
	_assert(int(terrain.get("hp", 0)) == 0, "Trap blasts should destroy destructible terrain on incidental blast squares")

func _test_enemy_attacks_profitable_trap_without_self_damage() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["element"] = ElementData.FIRE
	layout["player_start"] = Vector2i(5, 4)
	layout["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(1, 4),
		"hp": 12,
		"max_hp": 12,
		"block": 0,
		"intent": {"name": "Snipe", "actions": [{"type": "ranged", "damage": 1, "range": 5}]}
	}]
	layout["traps"] = [{
		"id": "trap_4_4",
		"pos": Vector2i(4, 4),
		"element": ElementData.FIRE,
		"damage": 4,
		"burn": 1
	}]
	var state: Dictionary = combat.create_combat(166, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_set_enemy_intent(state, 0, {"name": "Snipe", "actions": [{"type": "ranged", "damage": 1, "range": 5}]})
	var phase: Dictionary = combat.resolve_enemy_phase_with_steps(state)
	var after_state: Dictionary = phase.get("state", {})
	_assert((after_state.get("traps", []) as Array).is_empty(), "Enemies should attack a trap when its blast beats their direct attack")
	_assert(int((after_state.get("player", {}) as Dictionary).get("hp", 0)) == 16, "Enemy-triggered traps should apply their blast damage to the player")
	var steps: Array = phase.get("steps", [])
	_assert(not steps.is_empty() and not ((steps.back() as Dictionary).get("triggered_traps", []) as Array).is_empty(), "Enemy attack animation steps should report triggered traps")

	layout["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(3, 4),
		"hp": 12,
		"max_hp": 12,
		"block": 0,
		"intent": {"name": "Snipe", "actions": [{"type": "ranged", "damage": 1, "range": 5}]}
	}]
	var self_risk_state: Dictionary = combat.create_combat(167, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_set_enemy_intent(self_risk_state, 0, {"name": "Snipe", "actions": [{"type": "ranged", "damage": 1, "range": 5}]})
	var self_risk_after: Dictionary = combat.resolve_enemy_phase(self_risk_state)
	_assert((self_risk_after.get("traps", []) as Array).size() == 1, "Enemies should not attack a trap if its blast would hit themselves")
	_assert(int((self_risk_after.get("player", {}) as Dictionary).get("hp", 0)) == 19, "Enemies should fall back to a direct attack when the trap would be self-damaging")

func _test_enemy_breaks_blocking_terrain() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["player_start"] = Vector2i(5, 4)
	layout["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(2, 4),
		"hp": 12,
		"max_hp": 12,
		"block": 0,
		"intent": {"name": "Break Through", "actions": [{"type": "melee", "damage": 3, "range": 1}]}
	}]
	layout["terrain"] = [{
		"id": "terrain_3_4",
		"kind": "wooden_crate",
		"pos": Vector2i(3, 4),
		"hp": 3,
		"max_hp": 3
	}]
	var state: Dictionary = combat.create_combat(168, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_set_enemy_intent(state, 0, {"name": "Break Through", "actions": [{"type": "melee", "damage": 3, "range": 1}]})
	var phase: Dictionary = combat.resolve_enemy_phase_with_steps(state)
	var after_state: Dictionary = phase.get("state", {})
	var terrain: Dictionary = (after_state.get("terrain", []) as Array)[0]
	_assert(int(terrain.get("hp", 0)) == 0, "Enemies should break destructible terrain blocking their most direct attack path")
	_assert(int((after_state.get("player", {}) as Dictionary).get("hp", 0)) == 20, "Enemy terrain-breaking attacks should not also damage the player")
	var steps: Array = phase.get("steps", [])
	_assert(not steps.is_empty() and not ((steps.back() as Dictionary).get("terrain_losses", []) as Array).is_empty(), "Enemy terrain-breaking steps should report terrain damage")

func _test_enemy_moves_toward_breakable_chokepoint() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = {
		"name": "Crate Chokepoint",
		"coord": Vector2i(1, 0),
		"type": "combat",
		"grid": [
			["wall", "wall", "wall", "wall", "wall", "wall", "wall"],
			["wall", "wall", "wall", "wall", "wall", "wall", "wall"],
			["wall", "wall", "wall", "wall", "wall", "wall", "wall"],
			["wall", "stone", "stone", "stone", "stone", "stone", "wall"],
			["wall", "wall", "wall", "wall", "wall", "wall", "wall"],
			["wall", "wall", "wall", "wall", "wall", "wall", "wall"],
			["wall", "wall", "wall", "wall", "wall", "wall", "wall"]
		],
		"player_start": Vector2i(1, 3),
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(5, 3),
			"hp": 12,
			"max_hp": 12,
			"block": 0
		}],
		"terrain": [{
			"id": "terrain_3_3",
			"kind": "wooden_crate",
			"pos": Vector2i(3, 3),
			"hp": 3,
			"max_hp": 3
		}],
		"loot": []
	}
	var state: Dictionary = combat.create_combat(169, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_set_enemy_intent(state, 0, {
		"name": "Force Passage",
		"actions": [
			{"type": "move_toward", "range": 2},
			{"type": "melee", "damage": 3, "range": 1}
		]
	})
	var phase: Dictionary = combat.resolve_enemy_phase_with_steps(state)
	var after_state: Dictionary = phase.get("state", {})
	var enemy: Dictionary = (after_state.get("enemies", []) as Array)[0]
	var terrain: Dictionary = (after_state.get("terrain", []) as Array)[0]
	_assert(enemy.get("pos", Vector2i.ZERO) == Vector2i(4, 3), "Enemies should move up to destructible terrain when it is the only path forward")
	_assert(int(terrain.get("hp", 0)) == 0, "Enemies should break terrain after closing to a blocked chokepoint")
	_assert(int((after_state.get("player", {}) as Dictionary).get("hp", 0)) == 20, "Breaking a path through terrain should not also hit the player")

func _test_poison_and_stoneskin_behaviors() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(177, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["stone_plate"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state = combat.apply_player_action(state, {"type": "stoneskin", "amount": 6})
	state = combat.prepare_next_player_turn(state)
	_assert(int((state.get("player", {}) as Dictionary).get("stoneskin", 0)) == 6, "Stoneskin should persist across turn resets")
	var poison_state: Dictionary = combat.create_combat(178, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["venom_claw"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	poison_state["enemies"] = [
		{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(3, 4),
			"hp": 14,
			"max_hp": 14,
			"block": 0,
			"intent": {"name": "Wait", "actions": []}
		}
	]
	poison_state = combat.apply_player_action(poison_state, {"type": "melee", "damage": 0, "range": 1, "poison": 4}, Vector2i(3, 4))
	var first_phase: Dictionary = combat.resolve_enemy_phase(poison_state)
	var first_enemy: Dictionary = (first_phase.get("enemies", []) as Array)[0]
	_assert(int(first_enemy.get("hp", 0)) == 14, "Poison should not trigger on the very next turn")
	var second_phase: Dictionary = combat.resolve_enemy_phase(combat.prepare_next_player_turn(first_phase))
	var second_enemy: Dictionary = (second_phase.get("enemies", []) as Array)[0]
	_assert(int(second_enemy.get("hp", 0)) == 10, "Poison should land after waiting two turns")

func _test_statuses_tick_on_affected_actor_turn() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(179, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["venom_claw"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["enemies"] = [
		{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(3, 4),
			"hp": 14,
			"max_hp": 14,
			"block": 0,
			"intent": {"name": "Wait", "time": 1, "actions": []}
		},
		{
			"id": 2,
			"type": "harrier",
			"pos": Vector2i(5, 4),
			"hp": 10,
			"max_hp": 10,
			"block": 0,
			"burn": 3,
			"intent": {"name": "Wait", "time": 1, "actions": []}
		}
	]
	state = combat.apply_player_action(state, {"type": "melee", "damage": 0, "range": 1, "poison": 4}, Vector2i(3, 4))
	var other_turn: Dictionary = combat.resolve_enemy_turn_with_steps(state, 1)
	state = other_turn.get("state", {})
	var enemies: Array = state.get("enemies", [])
	var poisoned_enemy: Dictionary = enemies[0]
	var burned_enemy: Dictionary = enemies[1]
	var poison: Dictionary = poisoned_enemy.get("poison", {}) as Dictionary
	_assert(int(poison.get("delay", 0)) == 2, "Poison should not tick when a different enemy takes a turn")
	_assert(int(poisoned_enemy.get("hp", 0)) == 14, "Poison should only damage the actor that owns it on that actor's turn")
	_assert(int(burned_enemy.get("hp", 0)) == 7, "Burn should tick when the burned enemy's own turn starts")
	_assert(int(burned_enemy.get("burn", 0)) < 3, "Burn countdown should decrement on the burned enemy's own turn")
	var burn_after_own_turn: int = int(burned_enemy.get("burn", 0))
	var poison_turn: Dictionary = combat.resolve_enemy_turn_with_steps(state, 0)
	state = poison_turn.get("state", {})
	enemies = state.get("enemies", [])
	poisoned_enemy = enemies[0]
	burned_enemy = enemies[1]
	poison = poisoned_enemy.get("poison", {}) as Dictionary
	_assert(int(poison.get("delay", 0)) == 1, "Poison should advance at the start of the poisoned enemy's own turn")
	_assert(int(poisoned_enemy.get("hp", 0)) == 14, "Poison should wait through its delay before dealing damage")
	_assert(int(burned_enemy.get("burn", 0)) == burn_after_own_turn, "Burn should not tick again when a different enemy takes a turn")

func _test_enemy_pathfinding_avoids_traps() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(163, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["enemies"] = [
		{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(5, 4),
			"hp": 14,
			"max_hp": 14,
			"block": 0,
			"intent": {"name": "Advance", "actions": [{"type": "move_toward", "range": 2}]}
		}
	]
	state["traps"] = [{
		"id": "trap_4_4",
		"pos": Vector2i(4, 4),
		"element": "fire",
		"damage": 2,
		"burn": 2
	}]
	var destination: Vector2i = combat.call("_best_move_toward", state, 0, Vector2i(2, 4), 2)
	_assert(destination != Vector2i(4, 4), "Enemies should path around traps instead of walking onto them willingly")
	var threat: Dictionary = combat.enemy_threat_tiles(state, 0)
	_assert(not (threat.get("move", []) as Array).has(Vector2i(4, 4)), "Enemy threat previews should omit trap tiles they refuse to path through")

func _test_out_of_range_elemental_enemy_attack_skips_step() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(1781, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["player"] = {
		"pos": Vector2i(1, 6),
		"hp": 24,
		"max_hp": 24,
		"block": 0,
		"stoneskin": 0
	}
	state["enemies"] = [
		{
			"id": 1,
			"type": "harrier",
			"pos": Vector2i(6, 1),
			"hp": 10,
			"max_hp": 10,
			"block": 0,
			"intent": {
				"name": "Cold Snap",
				"actions": [{"type": "ranged", "damage": 3, "range": 2, "freeze": 1}]
			}
		}
	]
	var phase: Dictionary = combat.resolve_enemy_phase_with_steps(state)
	var attack_step_found: bool = false
	for step_var: Variant in phase.get("steps", []):
		var step: Dictionary = step_var
		if str(step.get("kind", "")) in ["melee", "ranged", "aoe", "push", "pull"]:
			attack_step_found = true
			break
	_assert(not attack_step_found, "Enemy attack animations should only enqueue when the attack actually connects")

func _test_enemy_close_aoe_still_hits_player() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["player_start"] = Vector2i(4, 4)
	layout["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(4, 5),
		"hp": 14,
		"max_hp": 14,
		"block": 0
	}]
	var state: Dictionary = combat.create_combat(1782, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_set_enemy_intent(state, 0, {
		"name": "Ground Slam",
		"actions": [{"type": "aoe", "damage": 3, "range": 0, "pattern": [[0, -1]], "rotate": false}]
	})
	var phase: Dictionary = combat.resolve_enemy_phase_with_steps(state)
	var after_state: Dictionary = phase.get("state", {})
	_assert(int((after_state.get("player", {}) as Dictionary).get("hp", 0)) == 21, "Close enemy AOE attacks should still hit the player")
	var steps: Array = phase.get("steps", [])
	_assert(not steps.is_empty() and str((steps.back() as Dictionary).get("kind", "")) == "aoe", "Close enemy AOE hits should still enqueue an impact step")

func _test_enemy_aoe_damages_incidental_terrain() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["player_start"] = Vector2i(4, 4)
	layout["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(4, 5),
		"hp": 14,
		"max_hp": 14,
		"block": 0
	}]
	layout["terrain"] = [{
		"id": "enemy_aoe_box",
		"kind": "wooden_box",
		"pos": Vector2i(5, 4),
		"hp": 3,
		"max_hp": 3
	}]
	var state: Dictionary = combat.create_combat(17821, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_set_enemy_intent(state, 0, {
		"name": "Wide Ground Slam",
		"actions": [{"type": "aoe", "damage": 3, "range": 0, "pattern": [[0, -1], [1, -1]], "rotate": false}]
	})
	var phase: Dictionary = combat.resolve_enemy_phase_with_steps(state)
	var after_state: Dictionary = phase.get("state", {})
	var terrain: Dictionary = (after_state.get("terrain", []) as Array)[0]
	_assert(int(terrain.get("hp", 0)) == 0, "Enemy AOE should destroy destructible terrain on incidental affected squares")
	var steps: Array = phase.get("steps", [])
	_assert(not steps.is_empty() and not ((steps.back() as Dictionary).get("terrain_losses", []) as Array).is_empty(), "Enemy AOE animation steps should report incidental terrain damage")

func _test_enemy_aoe_blocker_damages_incidental_terrain() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["player_start"] = Vector2i(4, 1)
	layout["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(4, 5),
		"hp": 14,
		"max_hp": 14,
		"block": 0
	}]
	layout["terrain"] = [
		{"id": "aoe_blocker", "kind": "wooden_crate", "pos": Vector2i(4, 4), "hp": 3, "max_hp": 3},
		{"id": "aoe_incidental", "kind": "wooden_box", "pos": Vector2i(5, 4), "hp": 3, "max_hp": 3}
	]
	var state: Dictionary = combat.create_combat(17822, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_set_enemy_intent(state, 0, {
		"name": "Blocked Ground Slam",
		"actions": [{"type": "aoe", "damage": 3, "range": 0, "pattern": [[0, -1], [1, -1]], "rotate": false}]
	})
	var phase: Dictionary = combat.resolve_enemy_phase_with_steps(state)
	var after_terrain: Array = (phase.get("state", {}) as Dictionary).get("terrain", [])
	_assert(after_terrain.size() == 2, "Terrain-only enemy AOE fixture should preserve both terrain entries")
	if after_terrain.size() == 2:
		_assert(int((after_terrain[0] as Dictionary).get("hp", 0)) == 0, "Terrain-only enemy AOE should destroy the directly attacked blocker")
		_assert(int((after_terrain[1] as Dictionary).get("hp", 0)) == 0, "Terrain-only enemy AOE should also destroy props on incidental pattern squares")
	_assert(int(((phase.get("state", {}) as Dictionary).get("player", {}) as Dictionary).get("hp", 0)) == 24, "Terrain-only enemy AOE regression should not rely on hitting an actor")
	var terrain_loss_count: int = 0
	for step_var: Variant in phase.get("steps", []):
		if typeof(step_var) != TYPE_DICTIONARY or str((step_var as Dictionary).get("kind", "")) != "aoe":
			continue
		terrain_loss_count = ((step_var as Dictionary).get("terrain_losses", []) as Array).size()
	_assert(terrain_loss_count == 2, "Terrain-only enemy AOE animation step should emit both terrain losses")

func _test_frostglass_lancer_line_thrust_preview_and_resolution() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["player_start"] = Vector2i(6, 4)
	layout["enemies"] = [{
		"id": 1,
		"type": "frostglass_lancer",
		"pos": Vector2i(2, 2),
		"hp": 12,
		"max_hp": 12,
		"block": 0
	}]
	var state: Dictionary = combat.create_combat(1783, layout, {
		"hp": 5,
		"max_hp": 5,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_set_enemy_intent(state, 0, _enemy_intent_by_id("frostglass_lancer", "glass_lunge"))
	var threat: Dictionary = combat.enemy_threat_tiles(state, 0)
	var move_tiles: Array = threat.get("move", [])
	var attack_tiles: Array = threat.get("attack", [])
	_assert(move_tiles.has(Vector2i(2, 4)), "Frostglass Lancer preview should show the sideways setup tile that lines up the thrust")
	_assert(attack_tiles.has(Vector2i(3, 4)) and attack_tiles.has(Vector2i(4, 4)) and attack_tiles.has(Vector2i(5, 4)) and attack_tiles.has(Vector2i(6, 4)), "Frostglass Lancer preview should show the four-tile glass-lance line after setup movement")
	_assert(not attack_tiles.has(Vector2i(6, 3)) and not attack_tiles.has(Vector2i(6, 5)) and not attack_tiles.has(Vector2i(3, 3)), "Frostglass Lancer preview should remain a narrow line without the removed spearhead burst")
	var phase: Dictionary = combat.resolve_enemy_phase_with_steps(state)
	var after_state: Dictionary = phase.get("state", {})
	var after_enemy: Dictionary = ((after_state.get("enemies", []) as Array)[0] as Dictionary)
	_assert(after_enemy.get("pos", Vector2i.ZERO) == Vector2i(2, 4), "Frostglass Lancer should move sideways into a line-thrust lane when that enables a hit")
	_assert(int((after_state.get("player", {}) as Dictionary).get("hp", 0)) == 0, "Frostglass Lancer line thrust should damage the player on the oriented line")
	var last_step: Dictionary = ((phase.get("steps", []) as Array).back() as Dictionary)
	var step_tiles: Array = last_step.get("tiles", [])
	_assert(step_tiles.has(Vector2i(3, 4)) and step_tiles.has(Vector2i(4, 4)) and step_tiles.has(Vector2i(5, 4)) and step_tiles.has(Vector2i(6, 4)) and not step_tiles.has(Vector2i(6, 3)), "Frostglass Lancer impact step should report the narrow four-tile line only")

	var blocked_layout: Dictionary = _simple_room_layout()
	blocked_layout["player_start"] = Vector2i(6, 4)
	var blocked_grid: Array = blocked_layout.get("grid", []).duplicate(true)
	blocked_grid[4][4] = "pillar"
	blocked_layout["grid"] = blocked_grid
	blocked_layout["enemies"] = [{
		"id": 1,
		"type": "frostglass_lancer",
		"pos": Vector2i(2, 2),
		"hp": 12,
		"max_hp": 12,
		"block": 0
	}]
	var blocked_state: Dictionary = combat.create_combat(1784, blocked_layout, {
		"hp": 5,
		"max_hp": 5,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_set_enemy_intent(blocked_state, 0, _enemy_intent_by_id("frostglass_lancer", "glass_lunge"))
	var blocked_threat: Dictionary = combat.enemy_threat_tiles(blocked_state, 0)
	var blocked_attack_tiles: Array = blocked_threat.get("attack", [])
	_assert(not blocked_attack_tiles.has(Vector2i(4, 4)) and not blocked_attack_tiles.has(Vector2i(5, 4)) and not blocked_attack_tiles.has(Vector2i(6, 4)), "Frostglass Lancer blocked-line preview should not include impassable, behind-blocker, or player tiles")
	var blocked_after: Dictionary = combat.resolve_enemy_phase(blocked_state)
	_assert(int((blocked_after.get("player", {}) as Dictionary).get("hp", 0)) == 5, "Frostglass Lancer line thrust should not hit through blocking tiles")

func _test_enemy_intents_ignore_room_element() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var neutral_layout: Dictionary = _simple_room_layout()
	neutral_layout["depth"] = 2
	neutral_layout["element"] = ElementData.NONE
	var neutral_state: Dictionary = combat.create_combat(1785, neutral_layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var neutral_intent: Dictionary = ((neutral_state.get("enemies", []) as Array)[0] as Dictionary).get("intent", {})
	_assert(not neutral_intent.has("element"), "Enemy intents should not inherit neutral room element markers")
	for room_element: String in ElementData.all_elements():
		var elemental_layout: Dictionary = neutral_layout.duplicate(true)
		elemental_layout["element"] = room_element
		var elemental_state: Dictionary = combat.create_combat(1785, elemental_layout, {
			"hp": 24,
			"max_hp": 24,
			"deck_cards": ["quick_stab"],
			"relics": [],
			"hand_size": 1,
			"heal_bonus": 0
		})
		var elemental_intent: Dictionary = ((elemental_state.get("enemies", []) as Array)[0] as Dictionary).get("intent", {})
		_assert(elemental_intent == neutral_intent, "%s rooms should not rewrite generic enemy intents" % ElementData.name(room_element))
		_assert(not elemental_intent.has("element"), "%s rooms should not stamp room element markers onto enemy intents" % ElementData.name(room_element))

	var base_intent: Dictionary = {"weight": 2, "actions": [{"type": "ranged", "damage": 4, "range": 5}]}
	var shallow_intent: Dictionary = combat.call("_scale_enemy_intent", base_intent, 1)
	var depth_two_intent: Dictionary = combat.call("_scale_enemy_intent", base_intent, 2)
	var later_intent: Dictionary = combat.call("_scale_enemy_intent", base_intent, 6)
	var shallow_action: Dictionary = (shallow_intent.get("actions", []) as Array)[0]
	var depth_two_action: Dictionary = (depth_two_intent.get("actions", []) as Array)[0]
	var later_action: Dictionary = (later_intent.get("actions", []) as Array)[0]
	_assert(str(shallow_action.get("type", "")) == "ranged" and int(shallow_action.get("range", 0)) == 5, "Depth scaling should not change enemy attack shape")
	_assert(int(shallow_action.get("damage", 0)) == 4, "Depth-one enemy attacks should retain the authored lethal baseline")
	_assert(int(depth_two_action.get("damage", 0)) == 4, "Depth-two enemy attacks should keep base damage")
	_assert(int(later_action.get("damage", 0)) == 5, "Later sequences should raise enemy attack damage on the bounded curve")

func _test_enemy_threat_tiles_follow_intent() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(179, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["player"] = {
		"pos": Vector2i(2, 4),
		"hp": 24,
		"max_hp": 24,
		"block": 0,
		"stoneskin": 0
	}
	state["enemies"] = [
		{
			"id": 1,
			"type": "harrier",
			"pos": Vector2i(5, 2),
			"hp": 10,
			"max_hp": 10,
			"block": 0,
			"intent": {
				"name": "Pelt",
				"actions": [
					{"type": "move_toward", "range": 2},
					{"type": "ranged", "damage": 4, "range": 3}
				]
			}
		}
	]
	var threat: Dictionary = combat.enemy_threat_tiles(state, 0)
	var move_tiles: Array = threat.get("move", [])
	var attack_tiles: Array = threat.get("attack", [])
	_assert(move_tiles.has(Vector2i(4, 2)), "Threat previews should include forward movement tiles for advancing enemies")
	_assert(move_tiles.has(Vector2i(4, 3)), "Threat previews should include closer diagonal paths when they are reachable")
	_assert(move_tiles.has(Vector2i(6, 2)), "Threat previews should show the enemy's full movement reach instead of only player-directed tiles")
	_assert(attack_tiles.has(Vector2i(2, 4)), "Threat previews should include the player's tile when the intent can connect after moving")
	_assert(attack_tiles.has(Vector2i(4, 2)), "Threat previews should mark tiles attackable from any reachable movement endpoint")

func _test_enemy_threat_tiles_assume_player_can_vacate_current_tile() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = {
		"name": "Vacated Corridor",
		"coord": Vector2i(1, 0),
		"type": "combat",
		"grid": [
			["wall", "wall", "wall", "wall", "wall", "wall", "wall"],
			["wall", "wall", "wall", "wall", "wall", "wall", "wall"],
			["wall", "wall", "wall", "wall", "wall", "wall", "wall"],
			["wall", "stone", "stone", "stone", "stone", "stone", "wall"],
			["wall", "wall", "wall", "wall", "wall", "wall", "wall"],
			["wall", "wall", "wall", "wall", "wall", "wall", "wall"],
			["wall", "wall", "wall", "wall", "wall", "wall", "wall"]
		],
		"player_start": Vector2i(3, 3),
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(1, 3),
			"hp": 12,
			"max_hp": 12,
			"block": 0
		}],
		"loot": []
	}
	var state: Dictionary = combat.create_combat(184, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_set_enemy_intent(state, 0, {
		"name": "Corridor Lunge",
		"actions": [
			{"type": "move_toward", "range": 3},
			{"type": "melee", "damage": 5, "range": 1}
		]
	})
	var threat: Dictionary = combat.enemy_threat_tiles(state, 0)
	_assert(
		(threat.get("attack", []) as Array).has(Vector2i(5, 3)),
		"Threat previews should assume the player can vacate their current tile before enemy movement"
	)
	var moved_state: Dictionary = state.duplicate(true)
	var moved_player: Dictionary = (moved_state.get("player", {}) as Dictionary).duplicate(true)
	moved_player["pos"] = Vector2i(5, 3)
	moved_state["player"] = moved_player
	var after_state: Dictionary = combat.resolve_enemy_phase(moved_state)
	_assert(
		int((after_state.get("player", {}) as Dictionary).get("hp", 0)) < 24,
		"The regression setup should prove the enemy can actually hit that vacated-corridor square"
	)

func _test_enemy_threat_tiles_include_enemy_triggered_trap_blasts() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["player_start"] = Vector2i(2, 4)
	layout["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(1, 4),
		"hp": 12,
		"max_hp": 12,
		"block": 0
	}]
	layout["traps"] = [{
		"id": "trap_4_4",
		"pos": Vector2i(4, 4),
		"element": ElementData.FIRE,
		"damage": 4,
		"burn": 1
	}]
	var state: Dictionary = combat.create_combat(185, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_set_enemy_intent(state, 0, {
		"name": "Fuse Shot",
		"actions": [{"type": "ranged", "damage": 1, "range": 3}]
	})
	var threat: Dictionary = combat.enemy_threat_tiles(state, 0)
	_assert(
		(threat.get("attack", []) as Array).has(Vector2i(5, 4)),
		"Threat previews should include blast tiles from traps an enemy can safely trigger"
	)
	var moved_state: Dictionary = state.duplicate(true)
	var moved_player: Dictionary = (moved_state.get("player", {}) as Dictionary).duplicate(true)
	moved_player["pos"] = Vector2i(5, 4)
	moved_state["player"] = moved_player
	var after_state: Dictionary = combat.resolve_enemy_phase(moved_state)
	_assert((after_state.get("traps", []) as Array).is_empty(), "The regression setup should prove the enemy triggers the trap")
	_assert(
		int((after_state.get("player", {}) as Dictionary).get("hp", 0)) < 20,
		"The regression setup should prove the trap blast can hit the moved player"
	)

func _test_large_enemy_threat_tiles_use_footprint() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(181, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["player"] = {
		"pos": Vector2i(6, 4),
		"hp": 24,
		"max_hp": 24,
		"block": 0,
		"stoneskin": 0
	}
	state["enemies"] = [
		{
			"id": 1,
			"type": "zekarion",
			"pos": Vector2i(4, 3),
			"footprint": Vector2i(2, 2),
			"hp": 72,
			"max_hp": 72,
			"block": 0,
			"intent": {
				"name": "Storm Claw",
				"actions": [{"type": "melee", "damage": 12, "range": 1}]
			}
		}
	]
	var threat: Dictionary = combat.enemy_threat_tiles(state, 0)
	var attack_tiles: Array = threat.get("attack", [])
	_assert(attack_tiles.has(Vector2i(6, 4)), "Large-enemy melee previews should include tiles adjacent to any footprint square")
	_assert(attack_tiles.has(Vector2i(5, 5)), "Large-enemy melee previews should include the footprint's lower edge")
	_assert(not attack_tiles.has(Vector2i(6, 5)), "Large-enemy melee previews should still exclude tiles outside attack range")
	var after_state: Dictionary = combat.resolve_enemy_phase(state)
	_assert(int((after_state.get("player", {}) as Dictionary).get("hp", 0)) < 24, "The large-enemy footprint preview should match actual enemy damage reach")

func _test_lightning_strikes_threat_tiles_are_previewed() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(182, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var action: Dictionary = {"type": "lightning_strikes", "damage": 7, "count": 6, "shock": 1}
	var enemy: Dictionary = {
		"id": 1,
		"type": "zekarion",
		"pos": Vector2i(4, 3),
		"footprint": Vector2i(2, 2),
		"hp": 72,
		"max_hp": 72,
		"block": 0,
		"intent": {
			"name": "Skybreak",
			"actions": [action]
		}
	}
	state["enemies"] = [enemy]
	var threat: Dictionary = combat.enemy_threat_tiles(state, 0)
	var attack_tiles: Array = threat.get("attack", [])
	var expected_tiles: Array = combat.call("_lightning_strike_tiles", state, enemy, action)
	_assert(attack_tiles.size() == expected_tiles.size(), "Lightning strike previews should show the deterministic strike tiles instead of hiding the attack")
	for tile: Vector2i in expected_tiles:
		_assert(attack_tiles.has(tile), "Lightning strike previews should include every deterministic strike tile")

func _test_lightning_strikes_damage_incidental_terrain() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(1821, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var action: Dictionary = {"type": "lightning_strikes", "damage": 4, "count": 6, "shock": 1}
	var enemy: Dictionary = {
		"id": 1,
		"type": "zekarion",
		"pos": Vector2i(4, 3),
		"footprint": Vector2i(2, 2),
		"hp": 720,
		"max_hp": 720,
		"block": 0,
		"intent": {"name": "Skybreak", "actions": [action]}
	}
	state["enemies"] = [enemy]
	var player_pos: Vector2i = (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	var strike_tiles: Array[Vector2i] = combat.call("_lightning_strike_tiles", state, enemy, action)
	var terrain_tile := Vector2i(-1, -1)
	for tile: Vector2i in strike_tiles:
		if tile != player_pos:
			terrain_tile = tile
			break
	_assert(terrain_tile.x >= 0, "Lightning terrain regression fixture should find a non-player strike square")
	state["terrain"] = [{
		"id": "storm_crate",
		"kind": "wooden_crate",
		"pos": terrain_tile,
		"hp": 4,
		"max_hp": 4
	}]
	var after_state: Dictionary = combat.call("_resolve_enemy_intent", state, 0, {"name": "Skybreak", "actions": [action]})
	var terrain: Dictionary = (after_state.get("terrain", []) as Array)[0]
	_assert(int(terrain.get("hp", 0)) == 0, "Deterministic lightning strikes should destroy terrain on incidental strike squares even when no actor occupies them")

func _test_zekarion_tempest_breath_leaves_corner_safety() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(183, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["player"] = {
		"pos": Vector2i(1, 1),
		"hp": 24,
		"max_hp": 24,
		"block": 0,
		"stoneskin": 0
	}
	state["enemies"] = [
		{
			"id": 1,
			"type": "zekarion",
			"pos": Vector2i(4, 3),
			"footprint": Vector2i(2, 2),
			"hp": 72,
			"max_hp": 72,
			"block": 0
		}
	]
	var tempest_breath: Dictionary = _enemy_intent_by_id("zekarion", "tempest_breath")
	_set_enemy_intent(state, 0, tempest_breath)
	var breath_action: Dictionary = ((tempest_breath.get("actions", []) as Array)[1] as Dictionary)
	_assert(int(breath_action.get("range", 0)) == 3, "Zekarion's Tempest Breath should leave more room-scale counterplay")
	var threat: Dictionary = combat.enemy_threat_tiles(state, 0)
	_assert(not (threat.get("attack", []) as Array).has(Vector2i(1, 1)), "Tempest Breath threat preview should leave the opposite corner safe")
	var after_state: Dictionary = combat.resolve_enemy_phase(state)
	_assert(int((after_state.get("player", {}) as Dictionary).get("hp", 0)) == 24, "Tempest Breath should not hit a player outside the previewed threat")

func _test_zekarion_summons_wisps_when_alone() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(44, _zekarion_test_room_layout(), {
		"hp": 24,
		"max_hp": 36,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var enemies: Array = state.get("enemies", [])
	for index: int in range(enemies.size()):
		var enemy: Dictionary = enemies[index]
		if str(enemy.get("type", "")) == "zekarion":
			enemy["intent"] = {"id": "debug_wait", "name": "Wait", "actions": []}
			enemies[index] = enemy
		if str(enemy.get("type", "")) == "lightning_wisp":
			enemy["hp"] = 0
			enemies[index] = enemy
	state["enemies"] = enemies
	var phase: Dictionary = combat.resolve_enemy_phase_with_steps(state)
	var next_state: Dictionary = phase.get("state", {})
	var live_wisps: int = 0
	for enemy_var: Variant in next_state.get("enemies", []):
		var enemy: Dictionary = enemy_var
		if str(enemy.get("type", "")) == "lightning_wisp" and int(enemy.get("hp", 0)) > 0:
			live_wisps += 1
	_assert(live_wisps == 0, "Zekarion should finish his current intent before scheduling a wisp summon")
	var scheduled_summon: bool = false
	for enemy_var: Variant in next_state.get("enemies", []):
		var enemy: Dictionary = enemy_var
		if str(enemy.get("type", "")) == "zekarion":
			scheduled_summon = str((enemy.get("intent", {}) as Dictionary).get("id", "")) == "call_wisps"
	_assert(scheduled_summon, "Zekarion should choose Call Wisps as his next intent when no wisps remain")
	var summon_phase: Dictionary = combat.resolve_enemy_phase_with_steps(next_state)
	var summoned_state: Dictionary = summon_phase.get("state", {})
	live_wisps = 0
	for enemy_var: Variant in summoned_state.get("enemies", []):
		var enemy: Dictionary = enemy_var
		if str(enemy.get("type", "")) == "lightning_wisp" and int(enemy.get("hp", 0)) > 0:
			live_wisps += 1
	_assert(live_wisps == 2, "Zekarion should summon two wisps when his scheduled summon turn executes")

func _test_summoned_wisps_receive_preview_intents() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(45, _zekarion_test_room_layout(), {
		"hp": 24,
		"max_hp": 36,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var enemies: Array = state.get("enemies", [])
	for index: int in range(enemies.size()):
		var enemy: Dictionary = enemies[index]
		if str(enemy.get("type", "")) == "zekarion":
			enemy["intent"] = {
				"id": "call_wisps",
				"name": "Call Wisps",
				"actions": [{"type": "summon_minions", "minion_type": "lightning_wisp", "count": 2}]
			}
			enemies[index] = enemy
		elif str(enemy.get("type", "")) == "lightning_wisp":
			enemy["hp"] = 0
			enemies[index] = enemy
	state["enemies"] = enemies
	var phase: Dictionary = combat.resolve_enemy_phase_with_steps(state)
	var next_state: Dictionary = phase.get("state", {})
	for enemy_var: Variant in next_state.get("enemies", []):
		var enemy: Dictionary = enemy_var
		if str(enemy.get("type", "")) == "lightning_wisp" and int(enemy.get("hp", 0)) > 0:
			_assert(not (enemy.get("intent", {}) as Dictionary).is_empty(), "Summoned wisps should immediately receive a preview intent")

func _test_zekarion_ignores_shock_status() -> void:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(46, _zekarion_test_room_layout(), {
		"hp": 24,
		"max_hp": 36,
		"deck_cards": ["static_lash"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var enemies: Array = state.get("enemies", [])
	for index: int in range(enemies.size()):
		var enemy: Dictionary = enemies[index]
		if str(enemy.get("type", "")) != "zekarion":
			continue
		state = combat.call("_apply_action_keywords_to_enemy", state, index, {"type": "ranged", "shock": 1}, Vector2i(2, 2))
		var zekarion: Dictionary = (state.get("enemies", []) as Array)[index]
		_assert(int(zekarion.get("shock", 0)) == 0, "Zekarion should ignore lightning shock status")
		break

func _test_status_badges_surface_countdowns() -> void:
	var board := CombatBoardView.new()
	var badges: Array = board.call("_unit_status_badges", {
		"burn": 5,
		"freeze": 1,
		"shock": 1,
		"immobilize": true,
		"poison": {"damage": 4, "delay": 2}
	})
	_assert(badges.size() == 5, "Status badges should surface each active status independently")
	_assert(str((badges[0] as Dictionary).get("icon", "")) == "burn", "Burn badges should use the shared burn icon")
	_assert(int((badges[0] as Dictionary).get("count", 0)) == 5, "Burn badges should show their remaining countdown")
	_assert(str((badges[3] as Dictionary).get("icon", "")) == "immobilize", "Immobilize badges should use the shared immobilize icon")
	_assert(str((badges[4] as Dictionary).get("icon", "")) == "poison", "Poison badges should use the shared poison icon")
	_assert(int((badges[4] as Dictionary).get("count", 0)) == 2, "Poison badges should show the turns remaining before it lands")

func _test_player_restriction_badges_show_turn_lock() -> void:
	var board := CombatBoardView.new()
	var statuses: Dictionary = board.call("_player_display_statuses", {"burn": 0, "freeze": 0, "shock": 0, "immobilize": false}, {"frozen": true, "shocked": false, "immobilized": false})
	_assert(int(statuses.get("freeze", 0)) == 1, "Frozen turns should still surface a freeze badge even after the restriction consumes the stored counter")
	statuses = board.call("_player_display_statuses", {"burn": 0, "freeze": 0, "shock": 0, "immobilize": false}, {"frozen": false, "shocked": true, "immobilized": false})
	_assert(int(statuses.get("shock", 0)) == 1, "Shocked turns should still surface a shock badge even after the restriction consumes the stored counter")
	statuses = board.call("_player_display_statuses", {"burn": 0, "freeze": 0, "shock": 0, "immobilize": false}, {"frozen": false, "shocked": false, "immobilized": true})
	_assert(bool(statuses.get("immobilize", false)), "Immobilized turns should still surface an immobilize badge after the restriction consumes the stored condition")

func _test_air_trap_tooltip_is_damage_only() -> void:
	var board := CombatBoardView.new()
	board.combat_state = {"elemental_intensity": {ElementData.AIR: 1}}
	var tooltip: String = str(board.call("_trap_tooltip_text", {
		"element": "air",
		"damage": 3
	}))
	_assert(tooltip.contains("Air Trap"), "Trap tooltips should identify their elemental type")
	_assert(tooltip == "Air Trap\n3 damage", "Trap tooltips should show only the trap name and live scaled damage")
	_assert(not tooltip.contains("Burn") and not tooltip.contains("Freeze") and not tooltip.contains("Shock") and not tooltip.contains("Immobilize") and not tooltip.contains("Poison"), "Air trap tooltips should stay damage-only until the air secondary effect is decided")

func _test_pickup_tooltips_describe_effects() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.combat_state = {"grid": _simple_grid()}
	_assert(
		str(board.call("_loot_tooltip_text", {"kind": "healing_vial", "amount": 4})) == "Healing potion: Heal 4",
		"Potion tooltips should describe the exact healing effect"
	)
	_assert(
		str(board.call("_loot_tooltip_text", {"kind": "rusty_shield", "amount": 4})) == "Rusty shield: Gain 4 block",
		"Rusty shield tooltips should describe the exact block effect"
	)
	_assert(
		str(board.call("_loot_tooltip_text", {"kind": "dropped_embers", "amount": 23})) == "Dropped embers: Reclaim 23",
		"Dropped ember tooltips should show the exact recoverable amount"
	)
	_assert(
		str(board.call("_loot_tooltip_text", {"kind": "equipment", "equipment_id": "iron_cleaver"})) == "equipment:iron_cleaver",
		"Equipment pickup tooltips should route through the shared equipment preview"
	)
	var potion_rect: Rect2 = board.call("_loot_rect_for_tile", Vector2i(3, 3), null, {"kind": "healing_vial"})
	var equipment_rect: Rect2 = board.call("_loot_rect_for_tile", Vector2i(3, 3), null, {"kind": "equipment", "equipment_id": "iron_cleaver"})
	_assert(equipment_rect.size.x > potion_rect.size.x, "Equipment pickups should render larger than ordinary pickups")
	_assert(equipment_rect.end.y < potion_rect.end.y, "Equipment pickups should float above the consumable pickup baseline")
	var low_bob: Vector2 = board.call("_equipment_pickup_bob_offset", 0.0)
	var high_bob: Vector2 = board.call("_equipment_pickup_bob_offset", 1.0)
	_assert(high_bob.y < low_bob.y, "Equipment pickups should bob upward as their visibility pulse rises")
	_assert(high_bob.y < 0.0 and low_bob.y < 0.0, "Equipment pickup bobbing should keep the item visibly lifted above the tile")
	board.combat_state = {
		"grid": _simple_grid(),
		"loot": [{"kind": "equipment", "equipment_id": "iron_cleaver", "pos": Vector2i(3, 3)}]
	}
	_assert(bool(board.call("_presentation_needs_continuous_redraw")), "Unclaimed equipment pickups should animate their visibility beacon")
	board.combat_state = {
		"grid": _simple_grid(),
		"loot": [{"kind": "equipment", "equipment_id": "iron_cleaver", "pos": Vector2i(3, 3), "claimed": true}]
	}
	_assert(not bool(board.call("_presentation_needs_continuous_redraw")), "Claimed equipment pickups should not keep the board animating")
	var terrain_tooltip: String = str(board.call("_terrain_tooltip_text", {
		"kind": "wooden_crate",
		"hp": 2,
		"max_hp": 3
	}))
	_assert(terrain_tooltip.contains("Wooden crate"), "Terrain tooltips should identify the object")
	_assert(terrain_tooltip.contains("2/3 HP"), "Terrain tooltips should show HP")
	_assert(not terrain_tooltip.contains("Blocks movement"), "Client terrain tooltips should stay concise")
	_assert(not terrain_tooltip.contains("Line of sight open"), "Client terrain tooltips should not repeat tactical harness guidance")
	_assert(not terrain_tooltip.contains("Attack to break"), "Client terrain tooltips should avoid instructional text")

func _test_terrain_health_bars_are_contextual() -> void:
	var board := CombatBoardView.new()
	var terrain_tile := Vector2i(3, 4)
	var terrain := {
		"id": "box_a",
		"kind": "wooden_box",
		"pos": terrain_tile,
		"hp": 3,
		"max_hp": 3
	}
	_assert(not bool(board.call("_should_show_terrain_health_bar", terrain)), "Undamaged, unhighlighted terrain should hide its health bar")
	var damaged_terrain: Dictionary = terrain.duplicate(true)
	damaged_terrain["hp"] = 2
	_assert(bool(board.call("_should_show_terrain_health_bar", damaged_terrain)), "Damaged terrain should show its health bar")
	var highlighted_tiles: Array[Vector2i] = []
	highlighted_tiles.append(terrain_tile)
	board.set("attack_tiles", highlighted_tiles)
	_assert(bool(board.call("_should_show_terrain_health_bar", terrain)), "Attack-highlighted terrain should show its health bar")
	var empty_tiles: Array[Vector2i] = []
	board.set("attack_tiles", empty_tiles)
	board.set("presentation", {
		"effect": {
			"preview": true,
			"damage_preview": {
				"terrain_box_a": {
					"hp": 1,
					"hp_loss": 2,
					"lethal": false
				}
			}
		}
	})
	var terrain_preview: Dictionary = board.call("_terrain_damage_preview", terrain)
	_assert(bool(board.call("_should_show_terrain_health_bar", terrain)), "Terrain with a pending damage preview should show its health bar")
	_assert(int(terrain_preview.get("hp", -1)) == 1 and int(terrain_preview.get("hp_loss", 0)) == 2, "Terrain health bars should read terrain damage previews by terrain key")

func _test_health_bar_segments_use_fixed_point_scale() -> void:
	var board := CombatBoardView.new()
	_assert(SegmentedHealthBar.segment_count_for_max_hp(14.0) == 7, "Segmented health bars should default to two natural HP per divider")
	_assert(int(board.call("_health_bar_segment_count", 14)) == 7, "Combat board unit health bars should use the shared natural-unit segment size")
	_assert(int(board.call("_health_bar_segment_count", 3)) == 2, "Low-HP terrain should avoid one segment per HP")
	_assert(int(board.call("_health_bar_segment_count", 1)) == 1, "Tiny health bars should keep at least one filled segment")

func _test_run_scene_terrain_damage_previews_use_terrain_keys() -> void:
	var run_scene_script: Script = load("res://scripts/run_scene.gd")
	_assert(run_scene_script != null, "Run scene script should load for terrain preview coverage")
	if run_scene_script == null:
		return
	var instance: Node = run_scene_script.new()
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["player_start"] = Vector2i(2, 4)
	layout["enemies"] = []
	layout["terrain"] = [{
		"id": "box_a",
		"kind": "wooden_box",
		"pos": Vector2i(3, 4),
		"hp": 3,
		"max_hp": 3
	}]
	var state: Dictionary = combat.create_combat(169, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var preview: Dictionary = instance.call("_preview_damage_for_action", state, {"type": "melee", "damage": 2, "range": 1}, Vector2i(3, 4))
	var terrain_preview: Dictionary = preview.get("terrain_box_a", {}) as Dictionary
	_assert(not terrain_preview.is_empty(), "Run scene attack previews should include terrain damage entries")
	_assert(int(terrain_preview.get("hp", -1)) == 1 and int(terrain_preview.get("hp_loss", 0)) == 2, "Terrain damage previews should project remaining HP and loss")
	var lethal_preview: Dictionary = instance.call("_preview_damage_for_action", state, {"type": "melee", "damage": 4, "range": 1}, Vector2i(3, 4))
	var lethal_terrain_preview: Dictionary = lethal_preview.get("terrain_box_a", {}) as Dictionary
	_assert(bool(lethal_terrain_preview.get("lethal", false)), "Terrain damage previews should mark lethal terrain hits")
	instance.free()

func _test_unit_hud_stacks_above_sprite_art() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	var center := Vector2(320.0, 240.0)
	var unit: Dictionary = {
		"type": "harrier",
		"intent": {
			"name": "Pelt",
			"actions": [
				{"type": "move_toward", "range": 2},
				{"type": "ranged", "damage": 4, "range": 3}
			]
		}
	}
	var health_rect: Rect2 = board.call("_unit_health_bar_rect", unit, center)
	var art_top_y: float = float(board.call("_unit_art_top_y", unit, center))
	_assert(health_rect.position.y + health_rect.size.y <= art_top_y - 5.5, "Unit health bars should sit clear of the sprite art")

func _test_combat_board_zooms_to_rendered_room_bounds() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(1900.0, 790.0)
	board.set("combat_state", {"grid": _simple_grid()})
	var tile_width: float = board.call("_tile_width")
	var top_inner_tile: Vector2 = board.call("_tile_center", Vector2i(1, 1))
	var bottom_inner_tile: Vector2 = board.call("_tile_center", Vector2i(6, 6))
	_assert(tile_width > 176.0, "Combat board should use the enlarged default combat zoom on large stage space")
	_assert(top_inner_tile.y < 220.0, "Combat board layout should use hidden-wall-free bounds and sit higher in the stage")
	_assert(bottom_inner_tile.y < board.size.y - 24.0, "Combat board's playable lower-row centers should remain inside the stage while the hand intentionally overlays its lower edge")

func _test_enemy_intent_name_reserves_header_line() -> void:
	var board := CombatBoardView.new()
	var attack_intent := {
		"name": "Pelt",
		"actions": [{"type": "ranged", "damage": 4, "range": 4}]
	}
	var wait_intent := {
		"name": "Wait",
		"actions": []
	}
	_assert(int(board.call("_enemy_intent_line_count", attack_intent)) == 2, "Named enemy intents should reserve a header line above their action icons")
	_assert(int(board.call("_enemy_intent_line_count", wait_intent)) == 1, "Name-only enemy intents should still render a title line")

func _test_enemy_intent_contour_expands_on_hover_or_toggle() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	var font: Font = load("res://fonts/LabyrinthCrumble-Text.tres")
	var center := Vector2(320.0, 320.0)
	var enemy := {
		"id": 7,
		"type": "harrier",
		"role": "enemy",
		"pos": Vector2i(3, 3),
		"intent": {
			"name": "Pelt",
			"actions": [{"type": "ranged", "damage": 4, "range": 4}]
		}
	}
	var compact_layout: Dictionary = board.call("_enemy_hud_layout", enemy, center, [], font)
	var compact_rows: Array = compact_layout.get("rows", [])
	var compact_rect: Rect2 = compact_layout.get("intent_rect", Rect2())
	_assert(compact_rows.is_empty() and compact_rect.size.is_zero_approx(), "Enemy intent detail should remain completely hidden without enemy hover or focus")
	board.set("_hover_tile", Vector2i(3, 3))
	var hovered_layout: Dictionary = board.call("_enemy_hud_layout", enemy, center, [], font)
	var hovered_rows: Array = hovered_layout.get("rows", [])
	var hovered_rect: Rect2 = hovered_layout.get("intent_rect", Rect2())
	_assert(hovered_rows.size() == 1, "Hovered enemy intent detail should reveal every action row")
	_assert(hovered_rect.size.x > 0.0 and hovered_rect.size.y > 0.0, "Hovered enemy intent detail should occupy measured contour bounds")
	_assert((hovered_layout.get("line_rects", []) as Array).size() == 2, "Hovered enemy intent detail should keep the name and action as independent lines")
	_assert((hovered_layout.get("tether", {}) as Dictionary).is_empty(), "Background-free intent detail should not retain the old panel tether")
	board.set("_hover_tile", Vector2i(-1, -1))
	board.presentation = {"expanded_enemy_actor_keys": ["enemy_7"]}
	var portrait_hover_layout: Dictionary = board.call("_enemy_hud_layout", enemy, center, [], font)
	var portrait_hover_rows: Array = portrait_hover_layout.get("rows", [])
	_assert(portrait_hover_rows.size() == 1, "Turn-order portrait hovers should reveal the matching enemy intent detail")
	board.presentation = {"show_all_enemy_intents": true}
	var toggled_layout: Dictionary = board.call("_enemy_hud_layout", enemy, center, [], font)
	var toggled_rows: Array = toggled_layout.get("rows", [])
	_assert(toggled_rows.size() == 1, "The show-all enemy intent flag should reveal intent detail without hover")

func _test_enemy_intent_action_rows_use_readable_scale() -> void:
	_assert(CombatBoardView.INTENT_POPUP_ICON_SIZE >= 42.0, "Enemy intent action icons should be at least twice the first-pass 21px size")
	_assert(CombatBoardView.INTENT_POPUP_ROW_FONT_SIZE >= 28, "Enemy intent action values should be at least roughly twice the first-pass 15px size")
	_assert(CombatBoardView.INTENT_POPUP_TITLE_FONT_SIZE > CombatBoardView.INTENT_POPUP_ROW_FONT_SIZE, "The Crumble intent name should remain the largest typographic element")
	_assert(CombatBoardView.INTENT_CONTOUR_ROW_HEIGHT >= CombatBoardView.INTENT_POPUP_ICON_SIZE, "Each contour action row should reserve enough height for the enlarged icon")

func _test_enemy_intent_shortcut_and_threat_union() -> void:
	var run_scene := RunSceneScript.new()
	var intent_key := InputEventKey.new()
	intent_key.pressed = true
	intent_key.keycode = KEY_I
	_assert(bool(run_scene.call("_is_enemy_intent_shortcut_event", intent_key)), "I should be the discoverable enemy-intent toggle shortcut")
	intent_key.shift_pressed = true
	_assert(not bool(run_scene.call("_is_enemy_intent_shortcut_event", intent_key)), "Modified text-entry chords should not trigger the enemy-intent toggle")
	var previews: Array[Dictionary] = [
		{"move": [Vector2i(2, 2), Vector2i(3, 2)]},
		{"move": [Vector2i(3, 2), Vector2i(4, 2)]}
	]
	var union: Array[Vector2i] = run_scene.call("_enemy_threat_tiles_union", previews, "move")
	_assert(union == [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)], "Show-all threat aggregation should preserve order while deduplicating overlapping tiles")
	run_scene.free()

func _test_enemy_intent_contour_chooses_a_shoulder_when_clear() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.presentation = {"show_all_enemy_intents": true}
	var font: Font = load("res://fonts/LabyrinthCrumble-Text.tres")
	var center := Vector2(320.0, 320.0)
	var enemy := {
		"type": "harrier",
		"role": "enemy",
		"intent": {
			"name": "Pelt",
			"actions": [{"type": "ranged", "damage": 4, "range": 4}]
		}
	}
	var layout: Dictionary = board.call("_enemy_hud_layout", enemy, center, [], font)
	var line_rects: Array = layout.get("line_rects", []) as Array
	_assert(str(layout.get("side", "")) in ["left", "right"], "Expanded intent detail should choose a concrete shoulder even on a clear board")
	_assert(line_rects.size() == 2, "The intent name and action should remain independently positioned")
	_assert(((line_rects[1] as Rect2).position.y >= (line_rects[0] as Rect2).end.y), "Action detail should descend from the intent name along the sprite contour")
	_assert((layout.get("tether", {}) as Dictionary).is_empty(), "Freeform shoulder text should not draw an ownership tether")

func _test_enemy_hud_small_top_correction_stays_centered() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	var base_rects: Array[Rect2] = []
	base_rects.append(Rect2(Vector2(420.0, 4.0), Vector2(120.0, 40.0)))
	var actor_clear_rect := Rect2(Vector2(450.0, 55.0), Vector2(60.0, 100.0))
	var offset: Vector2 = board.call("_placed_enemy_hud_offset", base_rects, [actor_clear_rect], actor_clear_rect, "enemy_41")
	_assert(is_equal_approx(offset.x, 0.0), "A small top-edge correction should remain centered when it can move down without covering the actor")
	_assert(is_equal_approx(offset.y, 2.0), "A small top-edge correction should move only the exact amount needed to enter the viewport")
	_assert(str((board.get("_enemy_hud_side_by_actor") as Dictionary).get("enemy_41", "")).is_empty(), "A centered top correction should not create side affinity")

func _test_enemy_hud_ignores_subpixel_obstacle_slivers() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	var base_rects: Array[Rect2] = []
	base_rects.append(Rect2(Vector2(420.0, 180.0), Vector2(120.0, 40.0)))
	var actor_clear_rect := Rect2(Vector2(450.0, 240.0), Vector2(60.0, 100.0))
	var sliver := Rect2(Vector2(420.0, 180.0), Vector2(0.5, 2.0))
	var offset: Vector2 = board.call("_placed_enemy_hud_offset", base_rects, [actor_clear_rect, sliver], actor_clear_rect, "enemy_42")
	_assert(offset == Vector2.ZERO, "A one-square-pixel collision sliver should not push an otherwise clear mid-board enemy HUD away from its actor")

func _test_enemy_hud_does_not_duplicate_owning_actor_obstacle() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	var base_rects: Array[Rect2] = []
	base_rects.append(Rect2(Vector2(420.0, 180.0), Vector2(120.0, 40.0)))
	var actor_clear_rect := Rect2(Vector2(539.98125, 160.0), Vector2(60.0, 100.0))
	var reserved_rects: Array[Rect2] = []
	reserved_rects.append(actor_clear_rect)
	var placement_obstacles: Array = board.call("_enemy_hud_placement_obstacles", reserved_rects, actor_clear_rect)
	_assert(placement_obstacles.size() == 1, "The production reserved list should contain the owning actor obstacle exactly once")
	var offset: Vector2 = board.call("_placed_enemy_hud_offset", base_rects, placement_obstacles, actor_clear_rect, "enemy_44")
	_assert(offset == Vector2.ZERO, "A sub-threshold owning-actor overlap should not become material through duplicate obstacle accounting")

func _test_enemy_hud_side_offset_clears_only_vertically_overlapping_pieces() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	var intent_rect := Rect2(Vector2(420.0, -30.0), Vector2(120.0, 30.0))
	var health_rect := Rect2(Vector2(438.0, 0.0), Vector2(84.0, 14.0))
	var base_rects: Array[Rect2] = []
	base_rects.append(intent_rect)
	base_rects.append(health_rect)
	var actor_clear_rect := Rect2(Vector2(450.0, 42.0), Vector2(60.0, 100.0))
	var offset: Vector2 = board.call("_placed_enemy_hud_offset", base_rects, [actor_clear_rect], actor_clear_rect, "enemy_43")
	var shifted_intent := Rect2(intent_rect.position + offset, intent_rect.size)
	var shifted_health := Rect2(health_rect.position + offset, health_rect.size)
	var legacy_full_bounds_shift: float = actor_clear_rect.position.x - 4.0 - intent_rect.end.x
	_assert(absf(offset.x) > 1.0, "A top correction that would cover the actor should still use a side placement")
	_assert(absf(offset.x) < absf(legacy_full_bounds_shift), "Side placement should stay closer by clearing only HUD pieces that vertically overlap the actor")
	_assert(not shifted_intent.intersects(actor_clear_rect, false) and not shifted_health.intersects(actor_clear_rect, false), "The closer side placement should still clear the actor")

func _test_enemy_hud_layout_offsets_away_from_reserved_ui() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.presentation = {"show_all_enemy_intents": true}
	var font: Font = load("res://fonts/LabyrinthCrumble-Text.tres")
	var center := Vector2(320.0, 240.0)
	var enemy := {
		"type": "harrier",
		"role": "enemy",
		"intent": {
			"name": "Pelt",
			"actions": [
				{"type": "move_toward", "range": 2},
				{"type": "ranged", "damage": 4, "range": 3}
			]
		}
	}
	var health_rect: Rect2 = board.call("_unit_health_bar_rect", enemy, center)
	var initial_layout: Dictionary = board.call("_enemy_hud_layout", enemy, center, [], font)
	var initial_side: String = str(initial_layout.get("side", ""))
	var initial_lines: Array = initial_layout.get("line_rects", []) as Array
	var blocking_rect: Rect2 = initial_lines[0] as Rect2
	var layout: Dictionary = board.call("_enemy_hud_layout", enemy, center, [blocking_rect], font)
	_assert(str(layout.get("side", "")) != initial_side, "Expanded enemy intent should use the clearer shoulder when the preferred contour is occupied")
	_assert((layout.get("health_rect", Rect2()) as Rect2) == health_rect, "Enemy health bar should remain anchored above its sprite while intent detail repositions")
	var placed_intent: Rect2 = layout.get("intent_rect", Rect2()) as Rect2
	_assert(not placed_intent.intersects(health_rect, false), "Expanded enemy intent should clear the anchored health bar")
	_assert(not placed_intent.intersects(blocking_rect, false), "Expanded enemy intent should clear reserved intent space")

func _test_enemy_intent_contour_stays_anchored_at_top_edge() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.presentation = {"show_all_enemy_intents": true}
	var font: Font = load("res://fonts/LabyrinthCrumble-Text.tres")
	var center := Vector2(480.0, 215.0)
	var enemy := {
		"type": "harrier",
		"role": "enemy",
		"intent": {
			"name": "Pelt",
			"actions": [{"type": "ranged", "damage": 4, "range": 4}]
		}
	}
	var default_health_rect: Rect2 = board.call("_unit_health_bar_rect", enemy, center)
	var layout: Dictionary = board.call("_enemy_hud_layout", enemy, center, [], font)
	var health_rect: Rect2 = layout.get("health_rect", Rect2())
	var intent_rect: Rect2 = layout.get("intent_rect", Rect2())
	var actor_clear_rect: Rect2 = board.call("_enemy_hud_actor_clear_rect", enemy, center)
	var line_rects: Array = layout.get("line_rects", []) as Array
	var side: String = str(layout.get("side", ""))
	_assert(side in ["left", "right"], "Top-edge intent detail should choose a stable shoulder")
	_assert(health_rect == default_health_rect, "Enemy health should remain directly above its sprite at the top edge")
	_assert(line_rects.size() == 2 and intent_rect.encloses(line_rects[0] as Rect2) and intent_rect.encloses(line_rects[1] as Rect2), "Contour bounds should enclose every independent intent line")
	_assert(intent_rect.position.y >= 6.0 and intent_rect.end.x <= board.size.x - 6.0, "Top-edge contour text should remain inside the board viewport")
	_assert((line_rects[0] as Rect2).position.y <= actor_clear_rect.position.y + 16.0, "The intent name should start at the base sprite's highest shoulder contour")
	_assert((layout.get("tether", {}) as Dictionary).is_empty(), "Contour text should not retain the old panel ownership tether")

func _test_enemy_hud_side_selection_is_stable_during_small_layout_changes() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.presentation = {"show_all_enemy_intents": true}
	var font: Font = load("res://fonts/LabyrinthCrumble-Text.tres")
	var center := Vector2(480.0, 215.0)
	var enemy := {
		"id": 17,
		"key": "enemy_17",
		"type": "harrier",
		"role": "enemy",
		"intent": {
			"name": "Raking Pelt",
			"actions": [{"type": "ranged", "damage": 4, "range": 4}]
		}
	}
	var initial_layout: Dictionary = board.call("_enemy_hud_layout", enemy, center, [], font)
	var initial_side: String = str(initial_layout.get("side", ""))
	var initial_intent_rect: Rect2 = initial_layout.get("intent_rect", Rect2())
	_assert(initial_side in ["left", "right"], "Top-edge HUD placement should remember a concrete side for each enemy")
	var tiny_sliver := Rect2(initial_intent_rect.position, Vector2(0.5, 2.0))
	var near_tie_layout: Dictionary = board.call("_enemy_hud_layout", enemy, center + Vector2(0.35, 0.0), [tiny_sliver], font)
	_assert(str(near_tie_layout.get("side", "")) == initial_side, "Subpixel board motion and a one-pixel collision score change should not flip the enemy HUD side")
	var blocking_rect := Rect2(Vector2(initial_intent_rect.position.x, 0.0), Vector2(initial_intent_rect.size.x, board.size.y))
	var forced_layout: Dictionary = board.call("_enemy_hud_layout", enemy, center, [blocking_rect], font)
	var forced_side: String = str(forced_layout.get("side", ""))
	_assert(forced_side != initial_side, "A materially blocked remembered side should still yield to the clear side")
	var settled_layout: Dictionary = board.call("_enemy_hud_layout", enemy, center + Vector2(-0.35, 0.0), [], font)
	_assert(str(settled_layout.get("side", "")) == forced_side, "Once the HUD changes sides for a real obstruction, nearby clear layouts should remain on that side")

func _test_combat_board_default_framing_contains_tallest_top_corner_occupant() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(1900.0, 790.0)
	var zekarion_def: Dictionary = GameData.enemy_def("zekarion")
	var footprint_data: Array = zekarion_def.get("footprint", [2, 2]) as Array
	var footprint := Vector2i(int(footprint_data[0]), int(footprint_data[1]))
	var state: Dictionary = {
		"room_coord": Vector2i(4, 3),
		"grid": _simple_grid(),
		"player": {"pos": Vector2i(6, 6), "hp": 24, "max_hp": 24},
		"enemies": [{
			"id": 91,
			"type": "zekarion",
			"pos": Vector2i(1, 1),
			"footprint": footprint,
			"hp": int(zekarion_def.get("max_hp", 60)),
			"max_hp": int(zekarion_def.get("max_hp", 60)),
			"intent": {}
		}],
		"illusions": [],
		"npcs": [],
		"terrain": [],
		"loot": [],
		"traps": []
	}
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"board_framing_mode": "combat"})
	var boss_unit: Dictionary = {}
	for unit_var: Variant in board.call("_visible_units") as Array:
		if typeof(unit_var) == TYPE_DICTIONARY and str((unit_var as Dictionary).get("key", "")) == "enemy_91":
			boss_unit = unit_var as Dictionary
			break
	var boss_rect: Rect2 = board.call("_unit_draw_rect", boss_unit)
	var safe_top: float = float(board.call("_board_local_safe_top"))
	var door_frame: Rect2 = board.call("_door_rect_for_tile", Vector2i(1, 1), state.get("grid", []))
	_assert(not boss_unit.is_empty(), "Tallest-occupant framing proof should build the top-corner Zekarion unit")
	_assert(boss_rect.size.y > door_frame.size.y, "Zekarion should remain the taller framing case than the tallest structural prop frame")
	_assert(float(board.get("_board_layout_cache_visual_top_offset")) > 0.0, "Tall top-corner art should activate content-aware default framing")
	_assert(boss_rect.position.y >= safe_top - 0.01, "The tallest shipped top-corner character should remain fully inside the screen-safe top edge")

func _test_combat_board_refreshes_top_framing_when_tall_occupant_appears_in_cached_room() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(1900.0, 790.0)
	var initial_state: Dictionary = {
		"room_coord": Vector2i(4, 3),
		"grid": _simple_grid(),
		"player": {"pos": Vector2i(6, 6), "hp": 24, "max_hp": 24},
		"enemies": [{"id": 92, "type": "harrier", "pos": Vector2i(4, 4), "hp": 20, "max_hp": 20, "intent": {}}],
		"illusions": [],
		"npcs": [],
		"terrain": [],
		"loot": [],
		"traps": []
	}
	var combat_presentation := {"board_framing_mode": "combat"}
	board.set_combat_state(initial_state, [], [], Vector2i(-1, -1), "", "", {}, {}, combat_presentation)
	board.call("_board_origin")
	var initial_offset: float = float(board.get("_board_layout_cache_visual_top_offset"))
	var zekarion_def: Dictionary = GameData.enemy_def("zekarion")
	var footprint_data: Array = zekarion_def.get("footprint", [2, 2]) as Array
	var next_state: Dictionary = initial_state.duplicate(true)
	next_state["enemies"] = [{
		"id": 92,
		"type": "zekarion",
		"pos": Vector2i(1, 1),
		"footprint": Vector2i(int(footprint_data[0]), int(footprint_data[1])),
		"hp": int(zekarion_def.get("max_hp", 60)),
		"max_hp": int(zekarion_def.get("max_hp", 60)),
		"intent": {}
	}]
	board.set_combat_state(next_state, [], [], Vector2i(-1, -1), "", "", {}, {}, combat_presentation)
	var boss_unit: Dictionary = {}
	for unit_var: Variant in board.call("_visible_units") as Array:
		if typeof(unit_var) == TYPE_DICTIONARY and str((unit_var as Dictionary).get("key", "")) == "enemy_92":
			boss_unit = unit_var as Dictionary
			break
	var boss_rect: Rect2 = board.call("_unit_draw_rect", boss_unit)
	var refreshed_offset: float = float(board.get("_board_layout_cache_visual_top_offset"))
	_assert(refreshed_offset > initial_offset, "A tallest occupant introduced after the room cache exists should refresh adaptive top framing")
	_assert(boss_rect.position.y >= float(board.call("_board_local_safe_top")) - 0.01, "A same-room tall-occupant transition should keep the new full sprite onscreen")
	var settled_state: Dictionary = next_state.duplicate(true)
	settled_state["enemies"] = [{"id": 92, "type": "harrier", "pos": Vector2i(4, 4), "hp": 20, "max_hp": 20, "intent": {}}]
	board.set_combat_state(settled_state, [], [], Vector2i(-1, -1), "", "", {}, {}, combat_presentation)
	board.call("_board_origin")
	_assert(is_equal_approx(float(board.get("_board_layout_cache_visual_top_offset")), refreshed_offset), "Same-room visual transitions should retain earned top clearance instead of making the board chatter vertically")

func _test_combat_board_refreshes_top_framing_when_scene_prop_appears_in_cached_room() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(1900.0, 790.0)
	board.call("_load_assets", false)
	var state: Dictionary = {
		"room_coord": Vector2i(4, 3),
		"grid": _simple_grid(),
		"player": {"pos": Vector2i(6, 6), "hp": 24, "max_hp": 24},
		"enemies": [],
		"illusions": [],
		"npcs": [],
		"terrain": [],
		"loot": [],
		"traps": []
	}
	var initial_presentation := {"board_framing_mode": "combat", "scene_props": []}
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, initial_presentation)
	board.call("_board_origin")
	var initial_offset: float = float(board.get("_board_layout_cache_visual_top_offset"))
	var prop := {"kind": "campfire_bonfire", "tile": Vector2i(1, 1), "width_scale": 2.4}
	var next_presentation := {"board_framing_mode": "combat", "scene_props": [prop]}
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, next_presentation)
	var prop_texture: Texture2D = board.call("_texture_for_scene_prop", prop)
	var prop_rect: Rect2 = board.call("_scene_prop_rect", prop_texture, prop)
	_assert(float(board.get("_board_layout_cache_visual_top_offset")) > initial_offset, "A tall scene prop introduced after the room cache exists should refresh adaptive top framing")
	_assert(prop_rect.position.y >= float(board.call("_board_local_safe_top")) - 0.01, "A same-room scene-prop transition should keep the new full prop onscreen")

func _test_boss_intent_layout_needs_no_global_board_banner() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	var font: Font = load("res://fonts/LabyrinthCrumble-Text.tres")
	var boss := {
		"type": "zekarion",
		"role": "enemy",
		"pos": Vector2i(4, 4),
		"footprint": Vector2i(2, 2),
		"boss_bar": true,
		"intent": {
			"name": "Tempest Breath",
			"actions": [
				{"type": "move_toward", "range": 1},
				{"type": "ranged", "damage": 8, "range": 3, "shock": 1}
			]
		}
	}
	var center := Vector2(480.0, 145.0)
	var boss_units: Array[Dictionary] = []
	boss_units.append(boss)
	var reserved_rects: Array = board.call("_fixed_hud_collision_rects", boss_units, font) as Array
	_assert(reserved_rects.is_empty(), "Boss health should no longer reserve a floating rectangle over playable board tiles")
	var compact_layout: Dictionary = board.call("_boss_intent_layout", boss, center, [], font)
	var compact_rect: Rect2 = compact_layout.get("intent_rect", Rect2())
	_assert(compact_rect.size == Vector2.ZERO, "Bosses should use the floor compass without a persistent overhead intent panel")
	board.presentation = {"show_all_enemy_intents": true}
	var expanded_layout: Dictionary = board.call("_boss_intent_layout", boss, center, [], font)
	var expanded_rect: Rect2 = expanded_layout.get("intent_rect", Rect2())
	_assert(expanded_rect.position.y >= 6.0 and expanded_rect.end.y <= board.size.y - 6.0, "Boss intents should remain contained without a global board banner collision")
	_assert(expanded_rect.size.x > 0.0 and expanded_rect.size.y > 0.0, "Boss inspection should still expand the exact intent panel on demand")
	board.free()

func _test_boss_health_overlay_caps_divider_density() -> void:
	var instance: Node = RunSceneScript.new()
	_assert(int(instance.call("_boss_health_segment_count", 120)) == 48, "Deep boss health should cap divider density in the dedicated encounter overlay")
	_assert(int(instance.call("_boss_health_segment_count", 33)) == 17, "Moderate boss health should retain the shared natural-unit segment scale")
	_assert(int(instance.call("_boss_health_segment_count", 1)) == 1, "Tiny boss health should keep at least one segment")
	instance.free()

func _test_enemy_art_scale_preserves_center() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.call("_load_assets")
	var center := Vector2(320.0, 240.0)
	var crawler_unit := {"type": "crawler", "pos": Vector2i(0, 0)}
	var crawler_texture: Texture2D = board.call("_texture_for_unit", crawler_unit)
	var frame_rect: Rect2 = board.call("_unit_frame_rect", center)
	var fitted_rect: Rect2 = board.call("_fitted_unit_rect", crawler_texture, frame_rect)
	var scaled_rect: Rect2 = board.call("_unit_draw_rect_for_center", crawler_unit, center)
	var crawler_scale: float = float(GameData.enemy_def("crawler").get("art_scale", 1.0))
	_assert(is_equal_approx(scaled_rect.size.x, fitted_rect.size.x * crawler_scale), "Crawler art scale should shrink the fitted sprite width")
	_assert(is_equal_approx(scaled_rect.size.y, fitted_rect.size.y * crawler_scale), "Crawler art scale should shrink the fitted sprite height")
	_assert(is_equal_approx(scaled_rect.get_center().x, fitted_rect.get_center().x), "Crawler art scaling should keep the sprite centered horizontally")
	_assert(is_equal_approx(scaled_rect.end.y, fitted_rect.end.y), "Crawler art scaling should keep the sprite feet anchored to the same bottom edge")

func _test_enemy_art_offset_shifts_sprite_vertically() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.call("_load_assets")
	var center := Vector2(320.0, 240.0)
	var acolyte_unit := {"type": "acolyte", "pos": Vector2i(0, 0)}
	var acolyte_texture: Texture2D = board.call("_texture_for_unit", acolyte_unit)
	var frame_rect: Rect2 = board.call("_unit_frame_rect", center)
	var fitted_rect: Rect2 = board.call("_fitted_unit_rect", acolyte_texture, frame_rect)
	var scaled_rect: Rect2 = board.call("_scaled_unit_rect", fitted_rect, board.call("_unit_art_scale", acolyte_unit))
	var draw_rect: Rect2 = board.call("_unit_draw_rect_for_center", acolyte_unit, center)
	var art_offset: Vector2 = board.call("_unit_art_offset", acolyte_unit)
	_assert(is_equal_approx(draw_rect.position.x, scaled_rect.position.x + art_offset.x), "Enemy art offset should shift the sprite horizontally after fitting")
	_assert(is_equal_approx(draw_rect.position.y, scaled_rect.position.y + art_offset.y), "Enemy art offset should shift the sprite vertically after fitting")
	_assert(is_equal_approx(draw_rect.end.y, scaled_rect.end.y + art_offset.y), "Enemy art offset should move the sprite feet by the configured amount")

func _test_turn_order_portraits_cover_enemy_roster() -> void:
	var run_scene_script: Script = load("res://scripts/run_scene.gd")
	var instance: Node = run_scene_script.new()
	var player_path: String = str(instance.call("_turn_order_portrait_path", {"kind": "player", "type": "player"}))
	_assert(FileAccess.file_exists(player_path), "Turn order should resolve a player portrait")
	var used_paths: Dictionary = {player_path: "player"}
	var used_hashes: Dictionary = {hash(FileAccess.get_file_as_bytes(player_path)): "player"}
	for enemy_type: String in GameData.enemies().keys():
		var portrait_path: String = str(instance.call("_turn_order_portrait_path", {
			"kind": "enemy",
			"type": enemy_type
		}))
		_assert(portrait_path != player_path, "%s turn-order portrait should not fall back to the player portrait" % enemy_type)
		_assert(FileAccess.file_exists(portrait_path), "%s turn-order portrait should exist" % enemy_type)
		_assert(portrait_path.begins_with("res://assets/art/portraits/"), "%s turn-order portrait should use the shared portrait registry instead of full-body enemy art" % enemy_type)
		_assert(not used_paths.has(portrait_path), "%s should have a distinct portrait path from %s" % [enemy_type, str(used_paths.get(portrait_path, "another identity"))])
		used_paths[portrait_path] = enemy_type
		var portrait_hash: int = hash(FileAccess.get_file_as_bytes(portrait_path))
		_assert(not used_hashes.has(portrait_hash), "%s should have visually distinct portrait bytes from %s" % [enemy_type, str(used_hashes.get(portrait_hash, "another identity"))])
		used_hashes[portrait_hash] = enemy_type
		var portrait_image: Image = Image.load_from_file(ProjectSettings.globalize_path(portrait_path))
		_assert(portrait_image != null and portrait_image.get_size() == Vector2i(128, 128), "%s portrait should be a native 128x128 raster" % enemy_type)
		var pre_battle_texture: Texture2D = instance.call("_pre_battle_enemy_texture", enemy_type, GameData.enemy_def(enemy_type)) as Texture2D
		_assert(pre_battle_texture != null and pre_battle_texture.get_size() == Vector2(128.0, 128.0), "%s pre-battle preview should use the same 128px portrait mapping as turn order" % enemy_type)
	instance.free()

func _test_chainbound_gaoler_board_art_is_taller_and_centered() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.call("_load_assets")
	var center := Vector2(320.0, 240.0)
	var player_unit := {"type": "player", "pos": Vector2i(0, 0)}
	var gaoler_unit := {"type": "chainbound_gaoler", "pos": Vector2i(0, 0)}
	var warden_unit := {"type": "warden", "pos": Vector2i(0, 0)}
	var player_rect: Rect2 = board.call("_unit_draw_rect_for_center", player_unit, center)
	var gaoler_rect: Rect2 = board.call("_unit_draw_rect_for_center", gaoler_unit, center)
	var warden_rect: Rect2 = board.call("_unit_draw_rect_for_center", warden_unit, center)
	_assert(float(GameData.enemy_def("chainbound_gaoler").get("art_scale", 1.0)) >= 0.9, "Chainbound Gaoler should not look shrunken next to the player")
	_assert(gaoler_rect.size.y > player_rect.size.y * 0.88, "Chainbound Gaoler board art should read nearly as tall as the player")
	_assert(gaoler_rect.size.y < warden_rect.size.y, "Chainbound Gaoler should remain smaller than the heavy Warden anchor")
	_assert(gaoler_rect.end.y < player_rect.end.y - 6.0, "Chainbound Gaoler should be shifted upward from the front edge of the tile")
	board.free()

func _test_enemy_intent_popup_expands_for_long_titles() -> void:
	var board := CombatBoardView.new()
	var font: Font = load("res://fonts/LabyrinthCrumble-Text.tres")
	var width: float = float(board.call("_enemy_intent_popup_width", {
		"name": "Skittering Stonebreaker Strike",
		"actions": [{"type": "melee", "damage": 4, "range": 1}]
	}, [[{"icon": "melee"}, {"icon": "damage", "value": 4}]], font))
	_assert(width > 136.0, "Long enemy intent titles should widen the popup instead of clipping")

func _test_unit_shadow_uses_alpha_silhouette() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.call("_load_assets")
	var unit := {"type": "crawler", "pos": Vector2i(0, 0)}
	var texture: Texture2D = board.call("_texture_for_unit", unit)
	var local_polygons: Array = board.call("_unit_shadow_polygons_for_texture", texture)
	_assert(not local_polygons.is_empty(), "Unit shadows should extract alpha silhouette polygons instead of falling back to a generic ellipse")
	if local_polygons.is_empty():
		board.free()
		return
	var draw_rect: Rect2 = board.call("_unit_draw_rect_for_center", unit, Vector2(320.0, 240.0))
	var bounds: Rect2 = board.call("_unit_shadow_bounds_for_texture", texture)
	var shadow_size: Vector2 = board.call("_unit_shadow_draw_size", texture, draw_rect.size, bounds)
	var foot_point: Vector2 = board.call("_unit_shadow_foot_point", texture, draw_rect, bounds, "crawler")
	_assert(foot_point.y < draw_rect.end.y, "Unit shadow anchor should use opaque feet instead of transparent texture padding")
	var stable_ratio: float = float(board.call("_unit_shadow_stable_bottom_ratio", "crawler", texture, bounds))
	var max_idle_ratio: float = 0.0
	for frame_texture: Texture2D in board.call("_unit_idle_frames", unit):
		var frame_bounds: Rect2 = board.call("_unit_shadow_bounds_for_texture", frame_texture)
		max_idle_ratio = maxf(max_idle_ratio, float(board.call("_unit_shadow_bottom_ratio", frame_texture, frame_bounds)))
	_assert(stable_ratio < max_idle_ratio, "Unit shadow anchor should ignore occasional low-contact idle pixels instead of following every claw/limb frame")
	var projected: PackedVector2Array = board.call(
		"_project_unit_shadow_polygon",
		local_polygons[0],
		shadow_size,
		foot_point
	)
	var min_point: Vector2 = projected[0]
	var max_point: Vector2 = projected[0]
	for point: Vector2 in projected:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	var projected_size: Vector2 = max_point - min_point
	_assert(projected_size.x > draw_rect.size.x * 0.24, "Projected unit shadow should preserve meaningful sprite silhouette width")
	_assert(projected_size.y > draw_rect.size.y * 0.10, "Projected unit shadow should preserve meaningful sprite silhouette depth")
	_assert(min_point.y <= foot_point.y + 1.0, "Projected unit shadow should begin at the opaque feet without a visible vertical gap")
	board.free()

func _test_player_uses_original_anime_art() -> void:
	var board := CombatBoardView.new()
	board.visible = true
	board.call("_load_assets")
	board.combat_state = {
		"player": {"pos": Vector2i(3, 3), "hp": 20, "max_hp": 20}
	}
	board.presentation = {}
	var player_unit := {"key": "player", "role": "player", "type": "player", "pos": Vector2i(3, 3), "hp": 20}
	var idle_frames: Array = board.call("_unit_idle_frames", player_unit)
	var player_texture: Texture2D = board.call("_texture_for_unit", player_unit)
	_assert(idle_frames.size() == 8, "Original anime player art should still load its matching idle sheet")
	_assert(player_texture != null, "Original anime player art should load for board rendering")
	board.free()

func _test_combat_board_keeps_equipment_data_off_player_sprite() -> void:
	var board := CombatBoardView.new()
	board.visible = true
	board.call("_load_assets")
	board.set_combat_state({
		"grid": _simple_grid(),
		"player": {"pos": Vector2i(3, 3), "hp": 20, "max_hp": 20},
		"enemies": []
	}, [], [], Vector2i(-1, -1), "", "", {}, {}, {
		"equipped_equipment": {
			"weapon": "iron_cleaver",
			"offhand": "ward_kite",
			"armor": "boiled_leather",
			"boots": "dust_tabi",
			"trinket": "ember_pendant"
		}
	})
	var presentation: Dictionary = board.get("presentation")
	_assert(str((presentation.get("equipped_equipment", {}) as Dictionary).get("weapon", "")) == "iron_cleaver", "Combat board presentation may preserve equipment data for future sprite art")
	_assert(not board.has_method("_draw_player_equipment_overlays"), "Combat board should not render equipment icon overlays on the player sprite")
	board.free()

func _test_combat_board_surfaces_illusion_units() -> void:
	var board := CombatBoardView.new()
	board.visible = true
	board.call("_load_assets")
	board.combat_state = {
		"grid": _simple_grid(),
		"player": {"pos": Vector2i(2, 4), "hp": 20, "max_hp": 20},
		"illusions": [{"id": 7, "pos": Vector2i(4, 4), "hp": 3, "max_hp": 3}],
		"enemies": []
	}
	board.presentation = {}
	var illusion_unit: Dictionary = {}
	for unit_var: Variant in board.call("_visible_units"):
		if typeof(unit_var) != TYPE_DICTIONARY:
			continue
		var unit: Dictionary = unit_var
		if str(unit.get("role", "")) == "illusion":
			illusion_unit = unit
			break
	_assert(not illusion_unit.is_empty(), "Combat board should include live illusions in visible units")
	_assert(str(illusion_unit.get("key", "")) == "illusion_7", "Illusion units should use stable actor keys")
	_assert(str(illusion_unit.get("type", "")) == "player", "Illusion units should reuse protagonist art")
	_assert(int(illusion_unit.get("hp", 0)) == 3, "Illusion units should expose their health for HUD rendering")
	_assert(board.call("_texture_for_unit", illusion_unit) != null, "Illusions should resolve the player texture for drawing")
	board.free()

func _test_combat_board_surfaces_illusion_preview_units() -> void:
	var board := CombatBoardView.new()
	board.visible = true
	board.call("_load_assets")
	board.combat_state = {
		"grid": _simple_grid(),
		"player": {"pos": Vector2i(2, 4), "hp": 20, "max_hp": 20},
		"illusions": [],
		"enemies": []
	}
	board.presentation = {
		"preview_units": [{
			"key": "illusion_preview",
			"role": "illusion_preview",
			"type": "player",
			"pos": Vector2i(4, 4),
			"hp": 2,
			"max_hp": 2
		}]
	}
	var preview_unit: Dictionary = {}
	for unit_var: Variant in board.call("_visible_units"):
		if typeof(unit_var) != TYPE_DICTIONARY:
			continue
		var unit: Dictionary = unit_var
		if str(unit.get("role", "")) == "illusion_preview":
			preview_unit = unit
			break
	_assert(not preview_unit.is_empty(), "Combat board should include illusion placement previews in visible units")
	_assert(str(preview_unit.get("key", "")) == "illusion_preview", "Illusion preview units should use a stable presentation key")
	_assert(str(preview_unit.get("type", "")) == "player", "Illusion previews should reuse protagonist art")
	_assert(int(preview_unit.get("hp", 0)) == 2, "Illusion previews should carry action health for presentation metadata")
	_assert(board.call("_texture_for_unit", preview_unit) != null, "Illusion previews should resolve the player texture for drawing")
	board.free()

func _test_trial_enemy_art_uses_matching_idle_sheets() -> void:
	var board := CombatBoardView.new()
	board.visible = true
	board.call("_load_assets")
	board.presentation = {}
	for enemy_type: String in ["crawler", "acolyte", "harrier", "warden"]:
		var enemy_unit := {"key": "enemy_%s" % enemy_type, "type": enemy_type}
		var idle_frames: Array = board.call("_unit_idle_frames", enemy_unit)
		var texture: Texture2D = board.call("_texture_for_unit", enemy_unit)
		var first_frame: AtlasTexture = idle_frames[0] as AtlasTexture
		var seventh_frame: AtlasTexture = idle_frames[6] as AtlasTexture
		var eighth_frame: AtlasTexture = idle_frames[7] as AtlasTexture
		var last_frame: AtlasTexture = idle_frames[idle_frames.size() - 1] as AtlasTexture
		_assert(idle_frames.size() == 12, "%s anime trial art should skip the final source frame and ping-pong without duplicated endpoints" % enemy_type)
		_assert((idle_frames[0] as Texture2D).get_size() == Vector2(1020.0, 1020.0), "%s anime trial idle sheet should use 4x2 frames" % enemy_type)
		_assert(first_frame != null and seventh_frame != null and eighth_frame != null and last_frame != null, "%s anime trial idle frames should be atlas-backed slices" % enemy_type)
		_assert(first_frame.region.position == Vector2.ZERO, "%s anime trial idle loop should keep the source frame at the start of the sheet" % enemy_type)
		_assert(seventh_frame.region != eighth_frame.region, "%s anime trial idle loop should not hold the final frame at the turn-around" % enemy_type)
		_assert(first_frame.region != last_frame.region, "%s anime trial idle loop should not hold the first frame at the loop boundary" % enemy_type)
		_assert(is_equal_approx(float(board.call("_unit_idle_frame_seconds", enemy_unit)), 0.1), "%s anime trial idle loop should use the original frame cadence" % enemy_type)
		_assert(texture != null, "%s anime trial art should load for board rendering" % enemy_type)

func _test_bile_bloomer_art_loads_for_board() -> void:
	var board := CombatBoardView.new()
	board.visible = true
	board.call("_load_assets")
	board.presentation = {}
	var bloomer_unit := {"key": "enemy_bile_bloomer", "type": "bile_bloomer"}
	var texture: Texture2D = board.call("_texture_for_unit", bloomer_unit)
	_assert(texture != null, "Bile Bloomer art should load for board rendering")
	_assert(texture.get_size() == Vector2(255.0, 255.0), "Bile Bloomer static sprite should use the standard 255px unit canvas")
	board.free()

func _test_bile_bloomer_turn_order_portrait_loads() -> void:
	var combat := CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["enemies"] = [{
		"id": 1,
		"type": "bile_bloomer",
		"pos": Vector2i(5, 4),
		"hp": 160,
		"max_hp": 160,
		"block": 0
	}]
	var state: Dictionary = combat.create_combat(23103, layout, {
		"hp": 240,
		"max_hp": 240,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var order: Array[Dictionary] = combat.current_turn_order(state, 10)
	var run_scene := RunSceneScript.new()
	var found_bloomer: bool = false
	for entry: Dictionary in order:
		if str(entry.get("type", "")) != "bile_bloomer":
			continue
		found_bloomer = true
		var path: String = str(run_scene.call("_turn_order_portrait_path", entry))
		_assert(path == "res://assets/art/portraits/bile_bloomer.png", "Bile Bloomer turn-order slot should use its enemy portrait instead of the player fallback")
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		_assert(image != null and not image.is_empty(), "Bile Bloomer turn-order portrait should load from disk")
		if image != null and not image.is_empty():
			_assert(image.get_size() == Vector2i(128, 128), "Bile Bloomer turn-order portrait should match the 128px portrait atlas size")
	run_scene.free()
	_assert(found_bloomer, "Bile Bloomer should appear in the visible turn-order queue")

func _test_zekarion_uses_matching_idle_sheet() -> void:
	var board := CombatBoardView.new()
	board.visible = true
	board.call("_load_assets")
	board.presentation = {}
	var boss_unit := {"key": "enemy_zekarion", "type": "zekarion"}
	var idle_frames: Array = board.call("_unit_idle_frames", boss_unit)
	var texture: Texture2D = board.call("_texture_for_unit", boss_unit)
	_assert(idle_frames.size() == 12, "Zekarion should load a matching 4x2 ping-pong idle sheet")
	_assert((idle_frames[0] as Texture2D).get_size() == Vector2(1020.0, 1020.0), "Zekarion idle frames should use 1020px 4x2 source cells")
	_assert(is_equal_approx(float(board.call("_unit_idle_frame_seconds", boss_unit)), 0.1), "Zekarion idle loop should use the boss frame cadence")
	_assert(texture != null, "Zekarion idle art should load for board rendering")

func _test_dragon_idle_redraw_targets_footprint_draw_layer() -> void:
	var board := CombatBoardView.new()
	board.visible = true
	board.call("_load_assets")
	board.presentation = {}
	for boss_type: String in ["tharokh", "vyraketh", "vaeloryx", "iskaldra", "zekarion", "noctyrax"]:
		var definition: Dictionary = GameData.enemy_def(boss_type)
		var footprint_data: Array = definition.get("footprint", [1, 1]) as Array
		var footprint := Vector2i(int(footprint_data[0]), int(footprint_data[1]))
		var origin := Vector2i(3, 4)
		var unit := {
			"key": "enemy_%s" % boss_type,
			"role": "enemy",
			"type": boss_type,
			"pos": origin,
			"footprint": footprint,
			"hp": int(definition.get("max_hp", 1))
		}
		var expected_draw_tile: Vector2i = board.call("draw_tile_for_unit_origin", unit, origin)
		var redraw_tile: Vector2i = board.call("_scene_render_tile_for_unit", unit)
		_assert(not (board.call("_unit_idle_frames", unit) as Array).is_empty(), "%s should retain idle frames for the dragon redraw regression" % boss_type)
		_assert(footprint == Vector2i(2, 2), "%s should retain its authored 2x2 dragon footprint" % boss_type)
		_assert(redraw_tile == expected_draw_tile, "%s idle redraw should invalidate the retained layer that actually draws its full footprint" % boss_type)
		_assert(redraw_tile != origin, "%s regression coverage must distinguish the rendered footprint tile from its origin" % boss_type)
	board.free()

func _test_lightning_wisp_uses_normal_loop_idle_sheet() -> void:
	var board := CombatBoardView.new()
	board.visible = true
	board.call("_load_assets")
	board.presentation = {}
	var wisp_unit := {"key": "enemy_wisp", "type": "lightning_wisp"}
	var idle_frames: Array = board.call("_unit_idle_frames", wisp_unit)
	var texture: Texture2D = board.call("_texture_for_unit", wisp_unit)
	var first_frame: AtlasTexture = idle_frames[0] as AtlasTexture
	var last_frame: AtlasTexture = idle_frames[idle_frames.size() - 1] as AtlasTexture
	_assert(idle_frames.size() == 16, "Lightning wisp should load all 16 source frames without ping-ponging")
	_assert((idle_frames[0] as Texture2D).get_size() == Vector2(1020.0, 1020.0), "Lightning wisp idle frames should use 1020px 4x4 source cells")
	_assert(first_frame != null and last_frame != null, "Lightning wisp idle frames should be atlas-backed slices")
	_assert(first_frame.region.position == Vector2.ZERO, "Lightning wisp normal loop should start at the first source frame")
	_assert(last_frame.region.position == Vector2(3060.0, 3060.0), "Lightning wisp normal loop should include the final source frame")
	_assert(is_equal_approx(float(board.call("_unit_idle_frame_seconds", wisp_unit)), 0.15), "Lightning wisp idle loop should match the downloaded GIF cadence")
	_assert(texture != null, "Lightning wisp idle art should load for board rendering")

func _test_cinder_enemies_use_final_raster_art() -> void:
	var board := CombatBoardView.new()
	board.visible = true
	board.call("_load_assets")
	board.presentation = {}
	for enemy_type: String in ["cinder_ooze", "cinder_droplet"]:
		var enemy_def: Dictionary = GameData.enemy_def(enemy_type)
		var art_path: String = str(enemy_def.get("art_path", ""))
		_assert(art_path.begins_with("res://assets/art/enemies/"), "%s should use final enemy art, not placeholder-era art" % enemy_type)
		_assert(art_path.get_extension().to_lower() == "png", "%s should use runtime-visible raster PNG art" % enemy_type)
		_assert(FileAccess.file_exists(art_path), "%s enemy sprite should exist" % enemy_type)
		var texture: Texture2D = (board.get("_unit_textures") as Dictionary).get(enemy_type, null)
		_assert(texture != null, "%s enemy sprite should load for board rendering" % enemy_type)
		if texture != null:
			_assert(texture.get_size() == Vector2(255, 255), "%s enemy sprite should use the static 255px unit canvas" % enemy_type)
			if enemy_type == "cinder_droplet":
				var center := Vector2(320.0, 240.0)
				var draw_rect: Rect2 = board.call("_unit_draw_rect_for_center", {"type": enemy_type, "pos": Vector2i.ZERO}, center)
				var used_rect: Rect2i = texture.get_image().get_used_rect()
				var visible_center_x: float = draw_rect.position.x + draw_rect.size.x * float(used_rect.position.x + used_rect.size.x * 0.5) / float(texture.get_width())
				var visible_bottom_y: float = draw_rect.position.y + draw_rect.size.y * float(used_rect.position.y + used_rect.size.y) / float(texture.get_height())
				var tile_height: float = float(board.call("_tile_height"))
				_assert(absf(visible_center_x - center.x) <= 1.0, "Cinder Droplet art should stay horizontally centered on its tile")
				_assert(visible_bottom_y <= center.y + tile_height * 0.35, "Cinder Droplet art should not hang below its tile anchor")
	board.free()

func _test_cinder_enemies_have_turn_order_portraits() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	_assert(run_scene != null, "Run scene should load for Cinder turn-order portrait coverage")
	if run_scene == null:
		return
	var instance: Node = run_scene.instantiate()
	var player_path: String = str(instance.call("_turn_order_portrait_path", {"kind": "player"}))
	for enemy_type: String in ["cinder_ooze", "cinder_droplet"]:
		var enemy_def: Dictionary = GameData.enemy_def(enemy_type)
		var entry: Dictionary = {
			"kind": "enemy",
			"team": "enemy",
			"type": enemy_type,
			"name": str(enemy_def.get("name", enemy_type)),
			"time": 9,
			"eta": 9,
			"base_initiative": 6,
			"intent_time_cost": 3,
			"pos": Vector2i(4, 4),
			"actor_key": "test_%s" % enemy_type
		}
		var portrait_path: String = str(instance.call("_turn_order_portrait_path", entry))
		_assert(portrait_path != player_path, "%s turn-order slot should not fall back to the player portrait" % enemy_type)
		_assert(portrait_path.begins_with("res://assets/art/portraits/"), "%s turn-order portrait should live with the generated portrait assets" % enemy_type)
		_assert(FileAccess.file_exists(portrait_path), "%s turn-order portrait asset should exist" % enemy_type)
		var slot: Control = instance.call("_build_turn_order_slot", entry, 0) as Control
		_assert(slot != null, "%s turn-order slot should build" % enemy_type)
		if slot != null:
			# The slot now has a separate frayed TextureRect behind the portrait.
			# Scope this canvas assertion to the portrait crop instead of relying on
			# descendant insertion order.
			var portrait_crop: Control = slot.find_child("TurnOrderPortraitCrop", true, false) as Control
			var texture_root: Node = portrait_crop if portrait_crop != null else slot
			var texture_rects: Array[TextureRect] = _texture_rects_under(texture_root)
			_assert(not texture_rects.is_empty() and texture_rects[0].texture != null, "%s turn-order slot should render its portrait texture" % enemy_type)
			if not texture_rects.is_empty() and texture_rects[0].texture != null:
				_assert(texture_rects[0].texture.get_size() == Vector2(128, 128), "%s turn-order portrait should use the clock portrait canvas" % enemy_type)
			slot.free()
	instance.free()

func _test_final_art_units_use_16_frame_idle_sheets() -> void:
	var board := CombatBoardView.new()
	board.visible = true
	board.call("_load_assets")
	board.presentation = {}
	var unit_types: Array[String] = [
		"cinder_ooze",
		"cinder_droplet",
		"bile_bloomer",
		"chainbound_gaoler",
		"grave_surgeon",
		"frostglass_lancer",
		"arcanist",
		"blacksmith"
	]
	for unit_type: String in unit_types:
		var definition: Dictionary = GameData.enemy_def(unit_type)
		var role: String = "enemy"
		if definition.is_empty():
			definition = GameData.npc_def(unit_type)
			role = "npc"
		var art_path: String = str(definition.get("art_path", ""))
		var idle_path: String = "%s_idle.%s" % [art_path.get_basename(), art_path.get_extension()]
		var unit := {"key": "%s_%s" % [role, unit_type], "role": role, "type": unit_type}
		var idle_frames: Array = board.call("_unit_idle_frames", unit)
		var first_frame: AtlasTexture = idle_frames[0] as AtlasTexture
		var last_frame: AtlasTexture = idle_frames[idle_frames.size() - 1] as AtlasTexture
		_assert(FileAccess.file_exists(idle_path), "%s idle sheet should exist beside the static art" % unit_type)
		_assert(idle_frames.size() == 16, "%s idle sheet should load all 16 advanced-animation frames" % unit_type)
		_assert((idle_frames[0] as Texture2D).get_size() == Vector2(255.0, 255.0), "%s idle frames should use native 255px source cells" % unit_type)
		_assert(first_frame != null and last_frame != null, "%s idle frames should be atlas-backed slices" % unit_type)
		_assert(first_frame.region.position == Vector2.ZERO, "%s idle loop should start at the first source frame" % unit_type)
		_assert(last_frame.region.position == Vector2(765.0, 765.0), "%s idle loop should include the final 4x4 source frame" % unit_type)
		_assert(is_equal_approx(float(board.call("_unit_idle_frame_seconds", unit)), 0.1), "%s idle loop should use the default frame cadence" % unit_type)
	board.free()

func _test_enemy_death_sheets_load_for_full_roster() -> void:
	var board := CombatBoardView.new()
	board.visible = true
	board.call("_load_assets")
	board.combat_state = {
		"grid": _simple_grid(),
		"player": {"pos": Vector2i(2, 4), "hp": 20, "max_hp": 20},
		"enemies": [{
			"id": 99,
			"type": "crawler",
			"pos": Vector2i(4, 4),
			"hp": 0,
			"max_hp": 10,
			"block": 0
		}]
	}
	for enemy_type: String in GameData.enemies().keys():
		var definition: Dictionary = GameData.enemy_def(enemy_type)
		var art_path: String = str(definition.get("art_path", ""))
		var death_path: String = "%s_death.%s" % [art_path.get_basename(), art_path.get_extension()]
		var unit := {
			"key": "enemy_%s_death" % enemy_type,
			"role": "enemy",
			"type": enemy_type,
			"death_animation": true,
			"death_frame": 5,
			"death_progress": 0.42
		}
		var death_frames: Array = board.call("_unit_death_frames", unit)
		_assert(FileAccess.file_exists(death_path), "%s death sheet should exist beside its base art" % enemy_type)
		_assert(death_frames.size() == 16, "%s death sheet should load all 16 shadow-dissolve frames" % enemy_type)
		if death_frames.size() >= 16:
			var first_frame: AtlasTexture = death_frames[0] as AtlasTexture
			var last_frame: AtlasTexture = death_frames[death_frames.size() - 1] as AtlasTexture
			_assert((death_frames[0] as Texture2D).get_size() == Vector2(255.0, 255.0), "%s death frames should use the native 255px unit canvas" % enemy_type)
			_assert(first_frame != null and last_frame != null, "%s death frames should be atlas-backed slices" % enemy_type)
			_assert(first_frame.region.position == Vector2.ZERO, "%s death animation should begin at the first source frame" % enemy_type)
			_assert(last_frame.region.position == Vector2(765.0, 765.0), "%s death animation should include the final 4x4 source frame" % enemy_type)
			_assert(board.call("_texture_for_unit", unit) == death_frames[5], "%s death presentation should select the requested death frame" % enemy_type)
	var death_entry := {
		"key": "enemy_99",
		"id": 99,
		"type": "crawler",
		"name": "Tunnel Crawler",
		"pos": Vector2i(4, 4),
		"death_frame": 3,
		"death_progress": 0.3
	}
	board.presentation = {"death_animation_units": [death_entry]}
	var found_death_unit: bool = false
	for visible_var: Variant in board.call("_visible_units"):
		if typeof(visible_var) != TYPE_DICTIONARY:
			continue
		var visible_unit: Dictionary = visible_var
		if str(visible_unit.get("key", "")) != "enemy_99":
			continue
		found_death_unit = true
		_assert(bool(visible_unit.get("death_animation", false)), "Death presentation units should be marked for dissolve rendering")
		_assert(int(visible_unit.get("hp", 0)) > 0, "Death presentation units should stay drawable even when combat state HP is zero")
	_assert(found_death_unit, "Combat board should surface presentation-only death animation units")
	board.free()

func _test_terrain_destruction_sheets_load_for_full_prop_roster() -> void:
	var board := CombatBoardView.new()
	board.visible = true
	board.call("_load_assets")
	for terrain_kind: String in ["wooden_box", "wooden_crate"]:
		var expected_frame_size: Vector2 = Vector2(128.0, 128.0) if terrain_kind == "wooden_box" else Vector2(120.0, 152.0)
		var expected_last_origin: Vector2 = Vector2(expected_frame_size.x * 3.0, expected_frame_size.y * 3.0)
		var destruction_path: String = "res://assets/art/tiles/%s_destroy.png" % terrain_kind
		var terrain := {
			"id": "%s_test" % terrain_kind,
			"kind": terrain_kind,
			"pos": Vector2i(4, 4),
			"destruction_frame": 5,
			"destruction_progress": 0.42
		}
		var destruction_frames: Array = board.call("_terrain_destruction_frames_for_kind", terrain_kind)
		_assert(FileAccess.file_exists(destruction_path), "%s should have a dedicated destruction sheet beside its base art" % terrain_kind)
		_assert(destruction_frames.size() == 16, "%s destruction sheet should load all 16 advanced-animation frames" % terrain_kind)
		if destruction_frames.size() >= 16:
			var first_frame: AtlasTexture = destruction_frames[0] as AtlasTexture
			var last_frame: AtlasTexture = destruction_frames[destruction_frames.size() - 1] as AtlasTexture
			_assert((destruction_frames[0] as Texture2D).get_size() == expected_frame_size, "%s destruction frames should preserve the native prop canvas" % terrain_kind)
			_assert(first_frame != null and last_frame != null, "%s destruction frames should be atlas-backed slices" % terrain_kind)
			_assert(first_frame.region.position == Vector2.ZERO, "%s destruction animation should begin at the intact source frame" % terrain_kind)
			_assert(last_frame.region.position == expected_last_origin, "%s destruction animation should include the final 4x4 source frame" % terrain_kind)
			_assert(board.call("_terrain_destruction_texture", terrain) == destruction_frames[5], "%s destruction presentation should select the requested frame" % terrain_kind)
		_assert(is_equal_approx(float(board.call("_terrain_destruction_frame_seconds", terrain)), 0.065), "%s destruction animation should use the configured frame cadence" % terrain_kind)
	board.free()

func _test_elemental_trap_animation_sheets_load_and_respect_reduced_motion() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.visible = true
	board.combat_state = {
		"grid": _simple_grid(),
		"player": {"pos": Vector2i(2, 2), "hp": 10, "max_hp": 10},
		"traps": [
			{"id": "fire_test", "element": "fire", "pos": Vector2i(3, 3), "damage": 4, "armed": true}
		]
	}
	board.presentation = {}
	board.call("_load_assets")
	var static_textures: Dictionary = board.get("_trap_textures") as Dictionary
	var idle_registry: Dictionary = board.get("_trap_idle_frames") as Dictionary
	var activation_registry: Dictionary = board.get("_trap_activation_frames") as Dictionary
	var stable_plate_samples: Array[Vector2i] = [Vector2i(20, 38), Vector2i(102, 38), Vector2i(61, 59)]
	for element_id: String in ElementData.all_elements():
		var idle_frames: Array = idle_registry.get(element_id, []) as Array
		var activation_frames: Array = activation_registry.get(element_id, []) as Array
		_assert(idle_frames.size() == 16, "%s trap idle should load all 16 Retro Diffusion frames" % element_id)
		_assert(activation_frames.size() == 16, "%s trap activation should load all 16 Retro Diffusion frames" % element_id)
		if idle_frames.size() == 16:
			_assert((idle_frames[0] as Texture2D).get_size() == Vector2(122.0, 80.0), "%s trap idle should preserve the native 122x80 canvas" % element_id)
		if activation_frames.size() == 16:
			_assert((activation_frames[0] as Texture2D).get_size() == Vector2(122.0, 80.0), "%s trap activation should preserve the native 122x80 canvas" % element_id)
		var base_image: Image = Image.load_from_file(ProjectSettings.globalize_path("res://assets/art/traps/trap_%s.png" % element_id))
		var idle_sheet: Image = Image.load_from_file(ProjectSettings.globalize_path("res://assets/art/traps/trap_%s_idle.png" % element_id))
		var activation_sheet: Image = Image.load_from_file(ProjectSettings.globalize_path("res://assets/art/traps/trap_%s_activation.png" % element_id))
		_assert(not base_image.is_empty(), "%s trap static plate should be readable for animation validation" % element_id)
		_assert(not idle_sheet.is_empty(), "%s trap idle sheet should be readable for animation validation" % element_id)
		_assert(not activation_sheet.is_empty(), "%s trap activation sheet should be readable for animation validation" % element_id)
		if not base_image.is_empty() and not idle_sheet.is_empty():
			for frame_index: int in range(16):
				var frame_origin := Vector2i((frame_index % 4) * 122, (frame_index / 4) * 80)
				for sample: Vector2i in stable_plate_samples:
					_assert(
						idle_sheet.get_pixelv(frame_origin + sample) == base_image.get_pixelv(sample),
						"%s trap idle frame %d should not wobble or recolor the approved plate" % [element_id, frame_index]
					)
		if not activation_sheet.is_empty():
			_assert(activation_sheet.get_region(Rect2i(Vector2i.ZERO, Vector2i(122, 80))).get_used_rect().size != Vector2i.ZERO, "%s trap activation should begin with a visible plate" % element_id)
			for final_frame_index: int in [13, 14, 15]:
				var final_origin := Vector2i((final_frame_index % 4) * 122, (final_frame_index / 4) * 80)
				var final_frame: Image = activation_sheet.get_region(Rect2i(final_origin, Vector2i(122, 80)))
				_assert(final_frame.get_used_rect().size == Vector2i.ZERO, "%s trap activation frame %d should be fully transparent after the trap is consumed" % [element_id, final_frame_index])
	var fire_trap: Dictionary = (board.combat_state.get("traps", []) as Array)[0] as Dictionary
	_assert(bool(board.call("_trap_idle_animation_active", fire_trap)), "Trap idle animation should run for an armed on-board plate")
	board.set("_idle_elapsed", 0.0)
	var first_idle: Texture2D = board.call("_trap_idle_texture", fire_trap)
	var first_key: String = str(board.call("_active_idle_frame_key"))
	board.set("_idle_elapsed", 0.13)
	var second_idle: Texture2D = board.call("_trap_idle_texture", fire_trap)
	var second_key: String = str(board.call("_active_idle_frame_key"))
	_assert(first_idle != null and second_idle != null and first_idle != second_idle, "Trap idle texture should advance through its animation frames")
	_assert(first_key != second_key, "Retained scene redraw gating should notice elemental trap idle frame changes")
	_assert(int(board.call("_trap_activation_frame_index", 0.0, 16)) == 0, "Trap activation should begin at the first generated frame")
	_assert(int(board.call("_trap_activation_frame_index", 0.5, 16)) == 8, "Trap activation should advance proportionally through the one-shot sheet")
	_assert(int(board.call("_trap_activation_frame_index", 1.0, 16)) == 15, "Trap activation should end on the final disappearance frame")
	var base_rect: Rect2 = board.call("_trap_draw_rect", fire_trap.get("pos", Vector2i.ZERO)) as Rect2
	board.combat_state["elemental_intensity"] = {"fire": 0}
	var low_intensity_rect: Rect2 = board.call("_trap_visual_draw_rect", fire_trap) as Rect2
	var low_intensity_modulate: Color = board.call("_trap_visual_modulate", fire_trap)
	board.combat_state["elemental_intensity"] = {"fire": 8}
	var high_intensity_rect: Rect2 = board.call("_trap_visual_draw_rect", fire_trap) as Rect2
	var high_intensity_modulate: Color = board.call("_trap_visual_modulate", fire_trap)
	_assert(low_intensity_rect.size.is_equal_approx(base_rect.size * 0.965), "Low-intensity idle and activation plates should share the established subtle scale reduction")
	_assert(high_intensity_rect.size.is_equal_approx(base_rect.size * 1.18), "High-intensity idle and activation plates should share the capped scale increase")
	_assert(low_intensity_rect.get_center().is_equal_approx(high_intensity_rect.get_center()), "Trap intensity should not shift the shared idle/activation center")
	_assert(is_equal_approx(low_intensity_rect.size.x / low_intensity_rect.size.y, 122.0 / 80.0), "Low-intensity trap geometry should preserve the source aspect ratio")
	_assert(is_equal_approx(high_intensity_rect.size.x / high_intensity_rect.size.y, 122.0 / 80.0), "High-intensity trap geometry should preserve the source aspect ratio")
	_assert(low_intensity_modulate.is_equal_approx(Color.WHITE) and high_intensity_modulate.is_equal_approx(Color.WHITE), "Idle and activation plates should share neutral modulation so the approved muted palette does not snap")
	board.presentation = {"reduced_motion": true}
	_assert(not bool(board.call("_trap_idle_animation_active", fire_trap)), "Reduced motion should stop looping trap idle animation")
	_assert(board.call("_trap_idle_texture", fire_trap) == static_textures.get("fire", null), "Reduced motion should retain the approved static pressure plate")
	_assert(int(board.call("_trap_activation_frame_index", 1.0, 16)) == 7, "Reduced motion should hold one representative activation frame instead of playing the burst")
	board.free()

func _test_final_art_idle_shadows_keep_silhouettes_for_every_frame() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.visible = true
	board.call("_load_assets")
	board.presentation = {}
	var unit_types: Array[String] = [
		"cinder_ooze",
		"cinder_droplet",
		"bile_bloomer",
		"chainbound_gaoler",
		"grave_surgeon",
		"frostglass_lancer",
		"arcanist",
		"blacksmith"
	]
	for unit_type: String in unit_types:
		var unit := {"key": "shadow_%s" % unit_type, "role": "enemy", "type": unit_type, "pos": Vector2i.ZERO}
		if not GameData.npc_def(unit_type).is_empty():
			unit["role"] = "npc"
		var idle_frames: Array = board.call("_unit_idle_frames", unit)
		var draw_rect: Rect2 = board.call("_unit_draw_rect_for_center", unit, Vector2(320.0, 240.0))
		for frame_index: int in range(idle_frames.size()):
			var texture: Texture2D = idle_frames[frame_index] as Texture2D
			var local_polygons: Array = board.call("_unit_shadow_polygons_for_texture", texture)
			_assert(not local_polygons.is_empty(), "%s idle frame %d should keep a silhouette shadow instead of falling back to the old oval" % [unit_type, frame_index])
			var bounds: Rect2 = board.call("_unit_shadow_bounds_for_texture", texture)
			var shadow_size: Vector2 = board.call("_unit_shadow_draw_size", texture, draw_rect.size, bounds)
			var foot_point: Vector2 = board.call("_unit_shadow_foot_point", texture, draw_rect, bounds, unit_type)
			var has_drawable_shadow := false
			for polygon_var: Variant in local_polygons:
				var local_polygon: PackedVector2Array = polygon_var
				var projected: PackedVector2Array = board.call("_project_unit_shadow_polygon", local_polygon, shadow_size, foot_point)
				if bool(board.call("_polygon_can_draw", projected)):
					has_drawable_shadow = true
					break
			_assert(has_drawable_shadow, "%s idle frame %d should project to a drawable silhouette shadow" % [unit_type, frame_index])
	board.free()

func _test_emaciated_man_uses_matching_idle_sheet() -> void:
	var board := CombatBoardView.new()
	board.visible = true
	board.call("_load_assets")
	board.combat_state = {
		"npcs": [{"id": "emaciated_man", "name": "Emaciated Man", "pos": Vector2i(3, 3)}]
	}
	board.presentation = {}
	var npc_unit := {"key": "npc_emaciated_man_0", "role": "npc", "type": "emaciated_man", "pos": Vector2i(3, 3)}
	var idle_frames: Array = board.call("_unit_idle_frames", npc_unit)
	var npc_texture: Texture2D = board.call("_texture_for_unit", npc_unit)
	var acolyte_texture: Texture2D = (board.get("_unit_textures") as Dictionary).get("acolyte", null)
	var first_frame: AtlasTexture = idle_frames[0] as AtlasTexture
	var seventh_frame: AtlasTexture = idle_frames[6] as AtlasTexture
	var eighth_frame: AtlasTexture = idle_frames[7] as AtlasTexture
	var last_frame: AtlasTexture = idle_frames[idle_frames.size() - 1] as AtlasTexture
	_assert(idle_frames.size() == 12, "Emaciated Man anime trial art should skip the final source frame and ping-pong without duplicated endpoints")
	_assert((idle_frames[0] as Texture2D).get_size() == Vector2(1020.0, 1020.0), "Emaciated Man anime trial idle sheet should use 4x2 frames")
	_assert(first_frame != null and seventh_frame != null and eighth_frame != null and last_frame != null, "Emaciated Man idle frames should be atlas-backed slices")
	_assert(first_frame.region.position == Vector2.ZERO, "Emaciated Man idle loop should keep the source frame at the start of the sheet")
	_assert(seventh_frame.region != eighth_frame.region, "Emaciated Man idle loop should not hold the final frame at the turn-around")
	_assert(first_frame.region != last_frame.region, "Emaciated Man idle loop should not hold the first frame at the loop boundary")
	_assert(npc_texture != null, "Emaciated Man static art should load for board rendering")
	_assert(npc_texture != acolyte_texture, "Emaciated Man should not reuse the Dust Acolyte texture")

func _test_foreground_props_fade_when_covering_behind_objects() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.combat_state = {"grid": _simple_grid()}
	var blocker_tile := Vector2i(3, 3)
	var prop_rect: Rect2 = board.call("_prop_rect_for_tile", blocker_tile)
	var behind_unit := {"key": "behind", "type": "player", "pos": Vector2i(3, 2)}
	var foreground_tint: Color = board.call("_foreground_blocker_tint", "pillar", blocker_tile, prop_rect, [behind_unit])
	_assert(foreground_tint.a < 1.0, "Foreground pillars should become translucent when they overlap a character on a farther-back tile")
	var front_unit := {"key": "front", "type": "player", "pos": Vector2i(3, 4)}
	var clear_tint: Color = board.call("_foreground_blocker_tint", "pillar", blocker_tile, prop_rect, [front_unit])
	_assert(is_equal_approx(clear_tint.a, 1.0), "Pillars should not fade for units that will draw in front of them")
	var behind_pickup := {"tile": Vector2i(3, 2), "rect": board.call("_loot_rect_for_tile", Vector2i(3, 2), null)}
	var door_tint: Color = board.call("_foreground_blocker_tint", "door", blocker_tile, prop_rect, [behind_pickup])
	_assert(door_tint.a < 1.0, "Foreground doors should fade when covering pickups on farther-back tiles")
	var behind_trap := {"tile": Vector2i(3, 2), "rect": board.call("_trap_draw_rect", Vector2i(3, 2))}
	var terrain_tint: Color = board.call("_foreground_blocker_tint", "terrain", blocker_tile, prop_rect, [behind_trap])
	_assert(terrain_tint.a < 1.0, "Foreground destructible terrain should fade when covering traps or other tile contents")
	var sliver_rect := Rect2(prop_rect.position + Vector2(prop_rect.size.x - 3.0, prop_rect.size.y - 3.0), Vector2(20.0, 20.0))
	var sliver_entry := {"tile": Vector2i(3, 2), "rect": sliver_rect}
	var sliver_tint: Color = board.call("_foreground_blocker_tint", "pillar", blocker_tile, prop_rect, [sliver_entry])
	_assert(is_equal_approx(sliver_tint.a, 1.0), "Foreground props should stay opaque when covering less than 25% of a farther-back sprite")
	var covered_rect := Rect2(prop_rect.position + Vector2(12.0, 12.0), Vector2(24.0, 24.0))
	var covered_entry := {"tile": Vector2i(3, 2), "rect": covered_rect}
	var covered_tint: Color = board.call("_foreground_blocker_tint", "pillar", blocker_tile, prop_rect, [covered_entry])
	_assert(covered_tint.a < 1.0, "Foreground props should fade when covering at least 25% of a farther-back sprite")
	board.free()

func _test_pillar_art_fits_bottom_center_without_stretching() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.call("_load_assets")
	var pillar_texture: Texture2D = (board.get("_prop_textures") as Dictionary).get("pillar", null)
	var frame_rect: Rect2 = board.call("_prop_rect_for_tile", Vector2i(3, 3))
	var draw_rect: Rect2 = board.call("_prop_draw_rect", pillar_texture, frame_rect)
	_assert(is_equal_approx(draw_rect.get_center().x, frame_rect.get_center().x), "Prop art should stay horizontally centered within its tile frame")
	_assert(is_equal_approx(draw_rect.end.y, frame_rect.end.y), "Prop art should stay bottom-aligned so walls and pillars feel planted on the tile")
	var source_ratio: float = pillar_texture.get_size().x / pillar_texture.get_size().y
	var draw_ratio: float = draw_rect.size.x / draw_rect.size.y
	_assert(is_equal_approx(draw_ratio, source_ratio), "Prop art should preserve its aspect ratio instead of stretching to fill the placeholder frame")
	board.free()

func _test_pillar_torch_fixtures_mount_on_both_visible_faces() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.call("_load_assets")
	var textures: Dictionary = board.get("_prop_textures") as Dictionary
	var left_texture: Texture2D = textures.get("column_torch_left", null)
	var right_texture: Texture2D = textures.get("column_torch_right", null)
	_assert(left_texture != null, "Combat board should load the left-facing column torch fixture")
	_assert(right_texture != null, "Combat board should load the right-facing column torch fixture")
	var pillar_texture: Texture2D = textures.get("pillar", null)
	var pillar_rect: Rect2 = board.call("_prop_draw_rect", pillar_texture, board.call("_prop_rect_for_tile", Vector2i(3, 3)))
	var left_rect: Rect2 = board.call("_pillar_torch_rect", pillar_rect, left_texture, -1.0)
	var right_rect: Rect2 = board.call("_pillar_torch_rect", pillar_rect, right_texture, 1.0)
	_assert(left_rect.get_center().x < pillar_rect.get_center().x, "The left torch should mount on the screen-left visible pillar face")
	_assert(right_rect.get_center().x > pillar_rect.get_center().x, "The right torch should mount on the screen-right visible pillar face")
	_assert(left_rect.size.x >= pillar_rect.size.x * 0.28, "Column torches should be large enough to read at board scale")
	_assert(right_rect.size.x >= pillar_rect.size.x * 0.28, "Column torches should be large enough to read at board scale")
	_assert(left_rect.size.x <= pillar_rect.size.x * 0.34, "Column torches should stay compact enough to mount on the pillar shaft")
	_assert(right_rect.size.x <= pillar_rect.size.x * 0.34, "Column torches should stay compact enough to mount on the pillar shaft")
	_assert(left_rect.get_center().distance_to(right_rect.get_center()) >= pillar_rect.size.x * 0.70, "Column torches should be spread onto their respective pillar sides")
	_assert(left_rect.position.y >= pillar_rect.position.y + pillar_rect.size.y * 0.24, "Column torches should sit on the pillar shaft below the cap")
	_assert(right_rect.position.y >= pillar_rect.position.y + pillar_rect.size.y * 0.24, "Column torches should sit on the pillar shaft below the cap")
	var left_flame_point: Vector2 = board.call("_pillar_torch_flame_point", left_rect, -1.0)
	var right_flame_point: Vector2 = board.call("_pillar_torch_flame_point", right_rect, 1.0)
	_assert(left_rect.has_point(left_flame_point), "Left torch ember origin should sit inside the rendered torch")
	_assert(right_rect.has_point(right_flame_point), "Right torch ember origin should sit inside the rendered torch")
	_assert(left_flame_point.x < left_rect.get_center().x, "Left torch ember origin should sit over the outer flame")
	_assert(right_flame_point.x > right_rect.get_center().x, "Right torch ember origin should sit over the outer flame")
	_assert(left_flame_point.y <= left_rect.position.y + left_rect.size.y * 0.32, "Left torch ember origin should start near the small flame head")
	_assert(right_flame_point.y <= right_rect.position.y + right_rect.size.y * 0.32, "Right torch ember origin should start near the small flame head")
	var left_seed: int = board.call("_pillar_torch_ember_seed", Vector2i(3, 3), "left", 0)
	var early_mote_point: Vector2 = board.call("_pillar_torch_ember_mote_point", left_flame_point, left_seed, 0.08, 0.0, -1.0)
	var late_mote_point: Vector2 = board.call("_pillar_torch_ember_mote_point", left_flame_point, left_seed, 0.82, 0.0, -1.0)
	_assert(late_mote_point.y < early_mote_point.y, "Column torch ember motes should drift upward from the flame")
	board.free()

func _test_column_torch_idle_sheets_load_and_are_clean() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	var grid: Array = _simple_grid()
	grid[3][3] = "pillar"
	board.combat_state = {
		"grid": grid,
		"player": {"pos": Vector2i(2, 2), "hp": 10, "max_hp": 10}
	}
	board.call("_load_assets")
	var idle_frames: Dictionary = board.get("_pillar_torch_idle_frames") as Dictionary
	_assert((idle_frames.get("left", []) as Array).size() == 16, "Left column torch idle sheet should load as a 4x4 animation")
	_assert((idle_frames.get("right", []) as Array).size() == 16, "Right column torch idle sheet should load as a 4x4 animation")
	_assert(bool(board.call("_pillar_torch_idle_animation_active")), "Column torch idle animation should run when a room has pillars")
	_assert(bool(board.call("_pillar_torch_ember_motes_active")), "Column torch ember motes should run when a room has pillars")
	_assert(bool(board.call("_presentation_needs_continuous_redraw")), "Column torch ember motes should use a smooth redraw loop")
	board.set("_idle_elapsed", 0.0)
	var first_left: Texture2D = board.call("_pillar_torch_texture", "left")
	board.set("_idle_elapsed", 0.12)
	var second_left: Texture2D = board.call("_pillar_torch_texture", "left")
	_assert(first_left != null and second_left != null and first_left != second_left, "Column torch texture should advance through idle frames")
	board.set("_idle_elapsed", 0.10)
	var before_torch_tick: String = str(board.call("_active_idle_frame_key"))
	board.set("_idle_elapsed", 0.12)
	var after_torch_tick: String = str(board.call("_active_idle_frame_key"))
	_assert(before_torch_tick != after_torch_tick, "Board redraw gating should notice torch frame changes even when unit frame timing does not align")
	_assert_torch_sheet_has_no_chroma_speckles("res://assets/art/tiles/column_torch_left_idle.png")
	_assert_torch_sheet_has_no_chroma_speckles("res://assets/art/tiles/column_torch_right_idle.png")
	board.free()

func _assert_torch_sheet_has_no_chroma_speckles(path: String) -> void:
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	_assert(image != null and not image.is_empty(), "%s should expose image data for chroma validation" % path)
	if image == null or image.is_empty():
		return
	var chroma_pixels: int = 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var color: Color = image.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			if color.g > 0.12 and color.g > color.r * 1.12 and color.g > color.b * 1.12:
				chroma_pixels += 1
			elif color.r > 0.28 and color.b > 0.24 and color.r > color.g * 1.18 and color.b > color.g * 1.18:
				chroma_pixels += 1
	_assert(chroma_pixels == 0, "%s should not keep visible green or purple chroma-key speckles" % path)

func _test_campfire_bonfire_assets_keep_clean_alpha_edges() -> void:
	_assert_campfire_asset_alpha_samples(
		"res://assets/art/tiles/campfire_bonfire.png",
		Vector2i(992, 640),
		[
			Vector2i(508, 56)
		]
	)
	_assert_campfire_asset_alpha_samples(
		"res://assets/art/tiles/campfire_bonfire_idle.png",
		Vector2i(992, 640),
		[
			Vector2i(508, 56),
			Vector2i(1486, 58),
			Vector2i(2477, 706),
			Vector2i(3478, 702),
			Vector2i(494, 1338),
			Vector2i(499, 1986),
			Vector2i(1490, 1984)
		]
	)

func _assert_campfire_asset_alpha_samples(path: String, frame_size: Vector2i, interior_samples: Array) -> void:
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	_assert(image != null and not image.is_empty(), "%s should expose image data for alpha validation" % path)
	if image == null or image.is_empty():
		return
	for sample_var: Variant in interior_samples:
		var sample: Vector2i = sample_var
		_assert(
			image.get_pixel(sample.x, sample.y).a > 0.06,
			"%s should keep interior flame/smoke pixels opaque after alpha cleanup" % path
		)
	for y: int in range(0, image.get_height(), frame_size.y):
		for x: int in range(0, image.get_width(), frame_size.x):
			_assert(
				image.get_pixel(x, y).a <= 0.06,
				"%s should keep exterior frame corners transparent after alpha cleanup" % path
			)

func _test_pillar_moss_overlay_is_anchored_to_pillar_cap() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.call("_load_assets")
	var pillar_texture: Texture2D = (board.get("_prop_textures") as Dictionary).get("pillar", null)
	var frame_rect: Rect2 = board.call("_prop_rect_for_tile", Vector2i(3, 3))
	var draw_rect: Rect2 = board.call("_prop_draw_rect", pillar_texture, frame_rect)
	var moss_rect: Rect2 = board.call("_pillar_moss_rect", draw_rect)
	_assert(moss_rect.position.y >= draw_rect.position.y + draw_rect.size.y * 0.14, "Pillar moss should sit down on the cap instead of floating above it")
	_assert(moss_rect.get_center().x <= draw_rect.get_center().x - draw_rect.size.x * 0.02, "Pillar moss should be nudged left to stay centered on the cap")
	board.free()

func _test_wall_and_pillar_assets_stay_distinct() -> void:
	var board := CombatBoardView.new()
	board.call("_load_assets")
	var textures: Dictionary = board.get("_prop_textures") as Dictionary
	var pillar_texture: Texture2D = textures.get("pillar", null)
	var wall_texture: Texture2D = textures.get("wall_row", null)
	_assert(pillar_texture != null, "Combat board should load dedicated pillar art")
	_assert(wall_texture != null, "Combat board should load dedicated wall art")
	if pillar_texture == null or wall_texture == null:
		board.free()
		return
	var pillar_ratio: float = pillar_texture.get_size().x / maxf(1.0, pillar_texture.get_size().y)
	var wall_ratio: float = wall_texture.get_size().x / maxf(1.0, wall_texture.get_size().y)
	_assert(pillar_texture.get_size().x >= wall_texture.get_size().x * 1.5, "Pillar art should stay materially broader than wall segments so support columns cannot silently reuse wall art")
	_assert(pillar_ratio >= wall_ratio + 0.15, "Pillar art should keep a distinctly squarer silhouette than wall segments so a wall/pillar asset swap is caught early")
	board.free()

func _test_boundary_prop_art_uses_single_tile_footprint() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.call("_load_assets")
	var textures: Dictionary = board.get("_prop_textures") as Dictionary
	var frame_rect: Rect2 = board.call("_prop_rect_for_tile", Vector2i(3, 0))
	var door_frame_rect: Rect2 = board.call("_door_rect_for_tile", Vector2i(3, 0))
	var tile_width: float = board.call("_tile_width")
	var wall_draw_rect: Rect2 = board.call("_prop_draw_rect", textures.get("wall_row", null), frame_rect)
	var door_draw_rect: Rect2 = board.call("_prop_draw_rect", textures.get("door", null), door_frame_rect)
	_assert(is_equal_approx(wall_draw_rect.get_center().x, frame_rect.get_center().x), "Boundary walls should stay centered within their tile frame")
	_assert(is_equal_approx(wall_draw_rect.end.y, frame_rect.end.y), "Boundary walls should stay planted on the same base line after fitting")
	_assert(wall_draw_rect.size.x <= tile_width * 0.66, "Boundary wall art should fit a single wall tile span instead of reading like a multi-tile module")
	_assert(door_draw_rect.size.x <= door_frame_rect.size.x, "Standalone door art should fit inside its dedicated door frame instead of spilling beyond it")
	_assert(is_equal_approx(door_draw_rect.end.y, door_frame_rect.end.y), "Standalone door art should stay planted on its dedicated floor line after fitting")
	board.free()

func _test_boundary_wall_segments_use_full_spans_on_straight_edges() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.call("_load_assets")
	var grid: Array = _simple_grid()
	var top_wall := Vector2i(3, 0)
	var left_wall := Vector2i(0, 3)
	var textures: Dictionary = board.get("_prop_textures") as Dictionary
	var top_segments: Array = board.call("_boundary_prop_segments", "wall", grid, top_wall)
	var left_segments: Array = board.call("_boundary_prop_segments", "wall", grid, left_wall)
	_assert(top_segments.size() == 1, "Straight top-edge walls should render as a single full-span segment")
	_assert(left_segments.size() == 1, "Straight side-edge walls should render as a single full-span segment")
	var top_segment: Dictionary = _find_boundary_segment(top_segments, "row")
	var left_segment: Dictionary = _find_boundary_segment(left_segments, "col")
	_assert(str(top_segment.get("half", "")) == "full", "Straight top-edge walls should use the full row segment")
	_assert(str(left_segment.get("half", "")) == "full", "Straight side-edge walls should use the full column segment")
	var top_frame: Rect2 = board.call("_prop_rect_for_tile", top_wall)
	var left_frame: Rect2 = board.call("_prop_rect_for_tile", left_wall)
	var full_row_rect: Rect2 = board.call("_prop_draw_rect", textures.get("wall_row", null), top_frame)
	var full_col_rect: Rect2 = board.call("_prop_draw_rect", textures.get("wall_col", null), left_frame)
	var top_draw_rect: Rect2 = top_segment.get("draw_rect", Rect2())
	var left_draw_rect: Rect2 = left_segment.get("draw_rect", Rect2())
	_assert(is_equal_approx(top_draw_rect.position.x, full_row_rect.position.x) and is_equal_approx(top_draw_rect.size.x, full_row_rect.size.x), "Straight top-edge walls should keep the full row-span footprint")
	_assert(is_equal_approx(left_draw_rect.position.x, full_col_rect.position.x) and is_equal_approx(left_draw_rect.size.x, full_col_rect.size.x), "Straight side-edge walls should keep the full column-span footprint")
	board.free()

func _test_boundary_wall_corner_tiles_split_into_two_half_segments() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.call("_load_assets")
	var grid: Array = _simple_grid()
	var textures: Dictionary = board.get("_prop_textures") as Dictionary
	var expectations: Array[Dictionary] = [
		{"tile": Vector2i(0, 0), "row_half": "right", "col_half": "left"},
		{"tile": Vector2i(7, 0), "row_half": "left", "col_half": "left"},
		{"tile": Vector2i(0, 7), "row_half": "right", "col_half": "right"},
		{"tile": Vector2i(7, 7), "row_half": "left", "col_half": "right"}
	]
	for entry: Dictionary in expectations:
		var tile: Vector2i = entry.get("tile", Vector2i.ZERO)
		var segments: Array = board.call("_boundary_prop_segments", "wall", grid, tile)
		_assert(segments.size() == 2, "Corner wall tiles should split into two half segments so both perimeter runs meet in the tile center")
		var row_segment: Dictionary = _find_boundary_segment(segments, "row")
		var col_segment: Dictionary = _find_boundary_segment(segments, "col")
		_assert(str(row_segment.get("half", "")) == str(entry.get("row_half", "")), "Corner row segments should use the inward-facing half of the wall span")
		_assert(str(col_segment.get("half", "")) == str(entry.get("col_half", "")), "Corner column segments should use the inward-facing half of the wall span")
		var frame_rect: Rect2 = board.call("_prop_rect_for_tile", tile)
		var full_row_rect: Rect2 = board.call("_prop_draw_rect", textures.get("wall_row", null), frame_rect)
		var full_col_rect: Rect2 = board.call("_prop_draw_rect", textures.get("wall_col", null), frame_rect)
		var row_draw_rect: Rect2 = row_segment.get("draw_rect", Rect2())
		var col_draw_rect: Rect2 = col_segment.get("draw_rect", Rect2())
		_assert(is_equal_approx(row_draw_rect.size.x, full_row_rect.size.x * 0.5), "Corner row segments should be cut to half-width so they terminate at the tile center")
		_assert(is_equal_approx(col_draw_rect.size.x, full_col_rect.size.x * 0.5), "Corner column segments should be cut to half-width so they terminate at the tile center")
	board.free()

func _test_door_art_uses_source_and_flipped_variant() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.call("_load_assets")
	var textures: Dictionary = board.get("_prop_textures") as Dictionary
	_assert(textures.get("door", null) != null, "Combat board should load the standalone door art")
	_assert(textures.get("door_row", null) == textures.get("door", null), "Bottom-left/top-right doors should use the supplied source orientation directly")
	_assert(textures.get("door_col", null) != null, "Combat board should build a flipped door texture for the opposite diagonal")
	_assert(textures.get("door_col", null) != textures.get("door", null), "Bottom-right/top-left doors should use a flipped variant instead of the identical source sprite")
	_assert(board.call("_floor_texture_key", "door") == "stone", "Door tiles should render on top of the regular stone floor texture")
	board.free()

func _test_standalone_door_art_stays_within_single_tile_footprint() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.call("_load_assets")
	var grid: Array = _simple_grid()
	var textures: Dictionary = board.get("_prop_textures") as Dictionary
	var door_texture: Texture2D = textures.get("door", null)
	var tile := Vector2i(4, 0)
	var door_frame: Rect2 = board.call("_door_rect_for_tile", tile, grid)
	var door_rect: Rect2 = board.call("_prop_draw_rect", door_texture, door_frame)
	var door_offset: Vector2 = board.call("_door_back_edge_offset_for_tile", tile, grid)
	_assert(door_rect.size.x <= door_frame.size.x, "Standalone door art should stay inside its dedicated door frame instead of spilling beyond it")
	_assert(is_equal_approx(door_rect.get_center().x, board.call("_tile_center", tile).x + door_offset.x), "Standalone door art should stay centered on its back-edge door frame")
	board.free()

func _test_visible_doors_use_dedicated_frame() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	var grid: Array = _simple_grid()
	var tile := Vector2i(4, 0)
	var wall_frame: Rect2 = board.call("_prop_rect_for_tile", tile)
	var door_frame: Rect2 = board.call("_door_rect_for_tile", tile, grid)
	var door_offset: Vector2 = board.call("_door_back_edge_offset_for_tile", tile, grid)
	_assert(door_frame.size.x > wall_frame.size.x, "Standalone door art should use its own enlarged frame instead of inheriting wall architecture sizing")
	_assert(door_frame.size.y > wall_frame.size.y, "Standalone door art should use its own enlarged frame instead of inheriting wall architecture sizing")
	_assert(is_equal_approx(door_frame.get_center().x, wall_frame.get_center().x + door_offset.x), "Standalone door art should use the opening tile's mirrored back-edge offset")
	_assert(door_frame.end.y >= wall_frame.end.y - 10.0, "Standalone door art should stay planted near the same floor line as the surrounding architecture")
	board.free()

func _test_door_frames_slide_toward_each_back_edge() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	var grid: Array = _simple_grid()
	var offsets: Dictionary = {
		"top_right": board.call("_door_back_edge_offset_for_tile", Vector2i(4, 0), grid),
		"bottom_right": board.call("_door_back_edge_offset_for_tile", Vector2i(7, 4), grid),
		"bottom_left": board.call("_door_back_edge_offset_for_tile", Vector2i(4, 7), grid),
		"top_left": board.call("_door_back_edge_offset_for_tile", Vector2i(0, 4), grid)
	}
	var top_right: Vector2 = offsets.get("top_right", Vector2.ZERO)
	var bottom_right: Vector2 = offsets.get("bottom_right", Vector2.ZERO)
	var bottom_left: Vector2 = offsets.get("bottom_left", Vector2.ZERO)
	var top_left: Vector2 = offsets.get("top_left", Vector2.ZERO)
	_assert(top_right.x > 0.0 and top_right.y < 0.0, "Top-right doors should slide up-right toward their back edge")
	_assert(bottom_right.x > 0.0 and bottom_right.y > 0.0, "Bottom-right doors should slide down-right toward their back edge")
	_assert(bottom_left.x < 0.0 and bottom_left.y > 0.0, "Bottom-left doors should slide down-left toward their back edge")
	_assert(top_left.x < 0.0 and top_left.y < 0.0, "Top-left doors should slide up-left toward their back edge")
	_assert(is_equal_approx(absf(top_right.x), absf(top_left.x)), "Top door back-edge offsets should share the same horizontal magnitude")
	_assert(is_equal_approx(absf(top_right.y), absf(top_left.y)), "Top door back-edge offsets should share the same vertical magnitude")
	_assert(is_equal_approx(absf(bottom_right.x), absf(bottom_left.x)), "Bottom door back-edge offsets should share the same horizontal magnitude")
	_assert(is_equal_approx(absf(bottom_right.y), absf(bottom_left.y)), "Bottom door back-edge offsets should share the same vertical magnitude")
	_assert(absf(top_right.x) < absf(bottom_right.x), "Top doors should use a slightly smaller back-edge offset than bottom doors")
	_assert(absf(top_right.y) < absf(bottom_right.y), "Top doors should use a slightly smaller back-edge offset than bottom doors")
	board.free()

func _test_door_opening_sheet_loads_as_directional_frames() -> void:
	var board := CombatBoardView.new()
	board.size = Vector2(960.0, 680.0)
	board.call("_load_assets")
	var frames: Array = board.get("_door_opening_frames") as Array
	var flipped_frames: Array = board.get("_door_opening_flipped_frames") as Array
	_assert(frames.size() == 8, "Door opening sheet should load as eight animation frames")
	_assert(flipped_frames.size() == frames.size(), "Door opening animation should build flipped frames for side-edge doors")
	var canvas_size: Vector2i = board.call("_door_opening_frame_canvas_size")
	_assert(canvas_size == Vector2i(256, 383), "Door opening frames should share the max source-frame canvas size")
	var first_frame: Texture2D = frames[0] if not frames.is_empty() else null
	var final_frame: Texture2D = frames[frames.size() - 1] if not frames.is_empty() else null
	_assert(first_frame != null and first_frame.get_size() == Vector2(canvas_size), "Door opening frame textures should all use the shared canvas")
	_assert(final_frame != null and final_frame.get_size() == Vector2(canvas_size), "Final door opening frame should stay on the shared canvas")
	var first_used_rect: Rect2i = board.call("_texture_used_rect", first_frame)
	var final_used_rect: Rect2i = board.call("_texture_used_rect", final_frame)
	_assert(first_used_rect.position == Vector2i(20, 2) and first_used_rect.size == Vector2i(236, 381), "First door opening sprite should keep its real source bounds inside the shared canvas")
	_assert(final_used_rect.position == Vector2i(4, 4) and final_used_rect.size == Vector2i(252, 379), "Final door opening sprite should stay bottom-right anchored inside the shared canvas")
	var grid: Array = _simple_grid()
	var row_tile := Vector2i(4, 0)
	var col_tile := Vector2i(7, 4)
	grid[row_tile.y][row_tile.x] = "door"
	grid[col_tile.y][col_tile.x] = "door"
	board.set_combat_state({"grid": grid}, [], [], Vector2i(-1, -1), "", "", {}, {}, {"door_opening": {"tile": row_tile, "progress": 0.0}})
	var first_source_frame: Texture2D = frames[0] if not frames.is_empty() else null
	_assert(board.call("_door_opening_texture_for_tile", grid, row_tile) == first_source_frame, "Top/bottom door openings should use the source orientation frame")
	board.set_combat_state({"grid": grid}, [], [], Vector2i(-1, -1), "", "", {}, {}, {"door_opening": {"tile": col_tile, "progress": 1.0}})
	var final_flipped_frame: Texture2D = flipped_frames[flipped_frames.size() - 1] if not flipped_frames.is_empty() else null
	_assert(board.call("_door_opening_texture_for_tile", grid, col_tile) == final_flipped_frame, "Side door openings should use the flipped final frame")
	var textures: Dictionary = board.get("_prop_textures") as Dictionary
	var row_static_texture: Texture2D = textures.get("door_row", null)
	var row_static_draw_rect: Rect2 = board.call("_prop_draw_rect", row_static_texture, board.call("_door_rect_for_tile", row_tile, grid))
	var row_static_used_rect: Rect2 = board.call("_texture_used_draw_rect", row_static_texture, row_static_draw_rect)
	var row_opening_draw_rect: Rect2 = board.call("_door_opening_draw_rect", first_source_frame, row_static_texture, row_static_draw_rect, false)
	_assert(is_equal_approx(row_opening_draw_rect.end.x, row_static_used_rect.end.x), "Source door opening frames should keep their stone edge anchored to the static door's right edge")
	_assert(is_equal_approx(row_opening_draw_rect.end.y, row_static_used_rect.end.y), "Door opening frames should stay planted on the static door baseline")
	var row_final_opening_draw_rect: Rect2 = board.call("_door_opening_draw_rect", final_frame, row_static_texture, row_static_draw_rect, false)
	_assert(row_final_opening_draw_rect.is_equal_approx(row_opening_draw_rect), "Source door opening frames should render into one stable draw rect across the animation")
	var row_opening_used_rect: Rect2 = board.call("_texture_used_draw_rect", first_source_frame, row_opening_draw_rect)
	_assert(is_equal_approx(row_opening_used_rect.position.y, row_static_used_rect.position.y), "First opening frame should match the static door visible top edge")
	_assert(is_equal_approx(row_opening_used_rect.end.y, row_static_used_rect.end.y), "First opening frame should match the static door visible bottom edge")
	var col_static_texture: Texture2D = textures.get("door_col", null)
	var col_static_draw_rect: Rect2 = board.call("_prop_draw_rect", col_static_texture, board.call("_door_rect_for_tile", col_tile, grid))
	var col_static_used_rect: Rect2 = board.call("_texture_used_draw_rect", col_static_texture, col_static_draw_rect)
	var col_opening_draw_rect: Rect2 = board.call("_door_opening_draw_rect", final_flipped_frame, col_static_texture, col_static_draw_rect, true)
	_assert(is_equal_approx(col_opening_draw_rect.position.x, col_static_used_rect.position.x), "Flipped door opening frames should keep their stone edge anchored to the static door's left edge")
	_assert(is_equal_approx(col_opening_draw_rect.end.y, col_static_used_rect.end.y), "Flipped door opening frames should stay planted on the static door baseline")
	board.free()

func _test_combat_board_hides_outer_walls_without_hiding_visible_doors() -> void:
	var board := CombatBoardView.new()
	var grid: Array = _simple_grid()
	var wall_tile := Vector2i(0, 3)
	grid[0][4] = "door"
	var door_tile := Vector2i(4, 0)
	board.set_combat_state({"grid": grid}, [], [], Vector2i(-1, -1), "", "", {}, {}, {})
	_assert(board.call("_display_tile_id", "door", door_tile) == "wall", "Inactive perimeter doors should fall back to wall semantics")
	var hidden_tiles: Array = board.call("_tiles_in_draw_order", grid)
	_assert(not hidden_tiles.has(wall_tile), "Boundary wall tiles should drop out of the draw order while outer wall visuals are disabled")
	_assert(not hidden_tiles.has(door_tile), "Inactive perimeter doors should also disappear once they resolve back to boundary walls")
	board.set_combat_state({"grid": grid}, [], [], Vector2i(-1, -1), "", "", {}, {}, {"active_door_tiles": {door_tile: true}})
	_assert(board.call("_display_tile_id", "door", door_tile) == "door", "Active connected doors should render as doors again")
	var active_tiles: Array = board.call("_tiles_in_draw_order", grid)
	_assert(active_tiles.has(door_tile), "Active connected doors should stay in draw order so they remain clickable")
	board.set_combat_state({"grid": grid}, [], [], Vector2i(-1, -1), "", "", {door_tile: "N"}, {}, {})
	_assert(board.call("_display_tile_id", "door", door_tile) == "door", "Usable exits should stay visually present even while the outer wall toggle is off")
	var exit_tiles: Array = board.call("_tiles_in_draw_order", grid)
	_assert(exit_tiles.has(door_tile), "Usable exits should remain in draw order so the player can click them")
	board.set_combat_state({"grid": grid}, [], [], Vector2i(-1, -1), "", "", {door_tile: "N"}, {}, {"pulse_exit_tiles": true})
	_assert(bool(board.call("_presentation_needs_continuous_redraw")), "Pulsing exit doors should keep the board redraw loop active")
	board.set_combat_state({"grid": grid}, [], [], Vector2i(-1, -1), "", "", {}, {}, {"locked_door_tiles": {door_tile: true}})
	_assert(board.call("_display_tile_id", "door", door_tile) == "door", "Locked traversal doors should still render as doors for presentation")
	var locked_tiles: Array = board.call("_tiles_in_draw_order", grid)
	_assert(locked_tiles.has(door_tile), "Locked traversal doors should stay in draw order while visible")
	board.free()

func _test_combat_board_assigns_deterministic_floor_variants() -> void:
	var board := CombatBoardView.new()
	board.call("_load_assets")
	var floor_variants: Dictionary = board.get("_floor_texture_variants")
	var stone_variants: Array = floor_variants.get("stone", [])
	_assert(stone_variants.size() == CombatBoardView.STONE_FLOOR_VARIANT_PATHS.size(), "Combat board should load every approved stone floor variant")
	var state := {"grid": _simple_grid(), "room_coord": Vector2i(2, 1)}
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {})
	var first_lookup: Dictionary = (board.get("_floor_variant_by_tile") as Dictionary).duplicate(true)
	var distinct: Dictionary = {}
	var adjacent_repeats: int = 0
	for y: int in range(1, 7):
		for x: int in range(1, 7):
			var tile := Vector2i(x, y)
			var variant_index: int = int(first_lookup.get(tile, -1))
			distinct[variant_index] = true
			if x > 1 and variant_index == int(first_lookup.get(Vector2i(x - 1, y), -2)):
				adjacent_repeats += 1
			if y > 1 and variant_index == int(first_lookup.get(Vector2i(x, y - 1), -2)):
				adjacent_repeats += 1
	_assert(distinct.size() >= mini(4, stone_variants.size()), "Interior stone floors should spread across the approved variants instead of collapsing to one look")
	_assert(adjacent_repeats <= 6, "Variant assignment should keep immediate stone-floor repeats rare")
	var center_tile := Vector2i(4, 4)
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {})
	var repeated_lookup: Dictionary = board.get("_floor_variant_by_tile")
	_assert(repeated_lookup.get(center_tile, -1) == first_lookup.get(center_tile, -2), "Floor variants should stay deterministic for the same room coordinate")
	board.set_combat_state({"grid": _simple_grid(), "room_coord": Vector2i(3, 1)}, [], [], Vector2i(-1, -1), "", "", {}, {}, {})
	var shifted_lookup: Dictionary = board.get("_floor_variant_by_tile")
	_assert(shifted_lookup != first_lookup, "Different room coordinates should reshuffle the deterministic floor-variant mix")
	board.free()

func _test_combat_board_loads_elemental_projectile_atlas() -> void:
	var board := CombatBoardView.new()
	board.call("_load_assets")
	var neutral_frame: AtlasTexture = board.call("_projectile_texture", ElementData.NONE) as AtlasTexture
	_assert(neutral_frame != null, "Combat board should load a neutral projectile atlas frame")
	var fallback_frame: AtlasTexture = board.call("_projectile_texture", "unknown") as AtlasTexture
	_assert(fallback_frame != null, "Unknown projectile elements should use the neutral atlas frame")
	if neutral_frame != null and fallback_frame != null:
		_assert(
			is_equal_approx(fallback_frame.region.position.y, neutral_frame.region.position.y),
			"Unknown projectile elements should fall back to the neutral atlas row"
		)
	var seen_rows: Dictionary = {}
	for element_id: String in ElementData.all_elements():
		var frame: AtlasTexture = board.call("_projectile_texture", element_id) as AtlasTexture
		_assert(frame != null, "Combat board should load projectile atlas frame for %s" % element_id)
		if frame != null:
			seen_rows[int(round(frame.region.position.y))] = true
	_assert(seen_rows.size() == ElementData.all_elements().size(), "Elemental projectile atlas should provide distinct rows for every element")
	board.free()

func _test_combat_board_ambient_particles_follow_room_element() -> void:
	var board := CombatBoardView.new()
	board.call("_load_assets")
	var neutral_state := {"grid": _simple_grid(), "room_coord": Vector2i(2, 1), "room_element": "none"}
	board.set_combat_state(neutral_state, [], [], Vector2i(-1, -1), "", "", {}, {}, {})
	_assert(not bool(board.call("_ambient_particles_active")), "Neutral rooms should not render elemental ambient particles")
	_assert(not bool(board.call("_presentation_needs_continuous_redraw")), "Neutral rooms with no active presentation should not request continuous redraw")
	var fire_state := {"grid": _simple_grid(), "room_coord": Vector2i(2, 1), "room_element": "fire"}
	board.set_combat_state(fire_state, [], [], Vector2i(-1, -1), "", "", {}, {}, {})
	_assert(bool(board.call("_ambient_particles_active")), "Elemental rooms should activate ambient particles")
	_assert(bool(board.call("_presentation_needs_continuous_redraw")), "Ambient particles should drive a lightweight redraw loop")
	_assert(board.call("_ambient_particle_texture", "fire", 0) != null, "Elemental ambient particles should use the generated raster atlas")
	_assert(board.call("_ambient_fire_soft_texture", 0) != null, "Fire ambient particles should use a softened mote atlas to avoid flat sprite rendering")
	var air_state := {"grid": _simple_grid(), "room_coord": Vector2i(2, 1), "room_element": "air"}
	board.set_combat_state(air_state, [], [], Vector2i(-1, -1), "", "", {}, {}, {})
	var air_wisp_variant: int = int(board.call("_ambient_air_wisp_variant_index", 1200))
	_assert(air_wisp_variant in [1, 3], "Air wind wisps should use directional full-body variants")
	_assert(board.call("_ambient_air_wisp_texture", air_wisp_variant, 16) != null, "Air ambient particles should use a full-body wisp frame instead of path-reveal frames")
	_assert(board.call("_ambient_air_wisp_soft_texture", air_wisp_variant) != null, "Air wind wisps should have a softened body atlas")
	_assert(board.call("_ambient_air_wisp_glow_texture", air_wisp_variant, 16) != null, "Air wind wisps should have matching glow frames")
	var wind_direction: float = float(board.call("_ambient_air_wind_direction"))
	_assert(is_equal_approx(absf(wind_direction), 1.0), "Air wind wisps should share a deterministic left/right wind direction")
	var first_seed: int = int(board.call("_ambient_room_seed", "fire"))
	board.set_combat_state(fire_state, [], [], Vector2i(-1, -1), "", "", {}, {}, {})
	_assert(int(board.call("_ambient_room_seed", "fire")) == first_seed, "Ambient particle seeds should stay stable for the same room coordinate and element")
	board.set_combat_state({"grid": _simple_grid(), "room_coord": Vector2i(3, 1), "room_element": "fire"}, [], [], Vector2i(-1, -1), "", "", {}, {}, {})
	_assert(int(board.call("_ambient_room_seed", "fire")) != first_seed, "Ambient particle seeds should vary across rooms")
	_assert(int(board.call("_ambient_particle_count", "ice", 72)) > int(board.call("_ambient_particle_count", "earth", 72)), "Snow rooms should carry more particles than heavier earth motes")
	_assert(int(board.call("_ambient_particle_count", "lightning", 72)) < int(board.call("_ambient_particle_count", "fire", 72)), "Lightning rooms should stay sparser than fire after density tuning")
	board.free()

func _test_combat_board_loads_defense_heal_cast_frames() -> void:
	var board := CombatBoardView.new()
	board.call("_load_assets")
	var effect_frames: Dictionary = board.get("_effect_frames") as Dictionary
	var frames: Array = effect_frames.get("defense_heal_casts", [])
	_assert(frames.size() == 12, "Defense/heal cast sheet should load twelve effect frames")
	for frame_var: Variant in frames:
		var frame: Texture2D = frame_var as Texture2D
		_assert(frame != null and frame.get_width() == 128 and frame.get_height() == 128, "Defense/heal cast frames should be 128px sprites")
	board.free()

func _test_combat_board_draw_order_tracks_moving_unit_world_position() -> void:
	var board := CombatBoardView.new()
	board.combat_state = {"grid": _simple_grid()}
	var from_tile := Vector2i(2, 2)
	var to_tile := Vector2i(4, 4)
	board.presentation = {
		"unit_world_positions": {
			"enemy_1": board.world_position_for_tile(to_tile)
		},
		"unit_draw_tiles": {
			"enemy_1": to_tile
		}
	}
	var draw_tile: Vector2i = board.call("_effective_unit_tile", {"key": "enemy_1", "pos": from_tile})
	_assert(draw_tile == to_tile, "Moving units should use their presentation draw tile for stable layering during motion")
	var boss_unit := {"key": "enemy_2", "pos": from_tile, "footprint": Vector2i(2, 2)}
	var boss_draw_tile: Vector2i = board.draw_tile_for_unit_origin(boss_unit, to_tile)
	var boss_center: Vector2 = board.world_position_for_unit_origin(boss_unit, to_tile)
	var expected_boss_center: Vector2 = (
		board.world_position_for_tile(to_tile)
		+ board.world_position_for_tile(to_tile + Vector2i(1, 0))
		+ board.world_position_for_tile(to_tile + Vector2i(0, 1))
		+ board.world_position_for_tile(to_tile + Vector2i(1, 1))
	) / 4.0
	_assert(boss_draw_tile == to_tile + Vector2i(1, 1), "Large moving units should draw on the destination footprint's front tile")
	_assert(boss_center.distance_to(expected_boss_center) <= 0.001, "Large moving units should animate from their footprint center, not their anchor tile")
	board.free()

func _test_keyword_icon_library_surfaces_tooltips() -> void:
	var row: Array = ActionIcons.tokens_for_action({"type": "ranged", "damage": 4, "range": 4, "poison": 2})
	_assert(row.size() == 3, "Ranged actions should tokenize into action, range, and status icons")
	_assert(str((row[0] as Dictionary).get("icon", "")) == "ranged", "Ranged action tokens should use the bow icon")
	_assert(str((row[1] as Dictionary).get("icon", "")) == "range", "Ranged action tokens should include the shared range icon")
	_assert(str((row[2] as Dictionary).get("icon", "")) == "poison", "Status keywords should use their shared icon token")
	var immobilize_row: Array = ActionIcons.tokens_for_action({"type": "ranged", "damage": 3, "range": 5, "immobilize": true})
	_assert(str((immobilize_row[2] as Dictionary).get("icon", "")) == "immobilize", "Immobilize should use its shared status icon token")
	_assert(ActionIcons.tooltip("immobilize").contains("movement"), "Immobilize tooltip should explain the movement lock")
	var shove_row: Array = ActionIcons.tokens_for_action({"type": "ranged", "damage": 4, "range": 4, "poison": 2, "push": 1})
	_assert(str((shove_row[shove_row.size() - 1] as Dictionary).get("icon", "")) == "push", "Push riders should render after hit, range, and status tokens")
	var direct_push_row: Array = ActionIcons.tokens_for_action({"type": "push", "damage": 5, "range": 4, "amount": 2})
	_assert(str((direct_push_row[0] as Dictionary).get("icon", "")) == "melee", "Push action rows should show the hit before forced movement")
	_assert(str((direct_push_row[direct_push_row.size() - 1] as Dictionary).get("icon", "")) == "push", "Push action rows should end with forced movement")
	var direct_pull_row: Array = ActionIcons.tokens_for_action({"type": "pull", "damage": 5, "range": 4, "amount": 2})
	_assert(str((direct_pull_row[0] as Dictionary).get("icon", "")) == "melee", "Pull action rows should show the hit before forced movement")
	_assert(str((direct_pull_row[direct_pull_row.size() - 1] as Dictionary).get("icon", "")) == "pull", "Pull action rows should end with forced movement")
	var pierce_row: Array = ActionIcons.tokens_for_action({"type": "ranged", "damage": 6, "range": 5, "pierce": true})
	_assert(pierce_row.size() == 2, "Pierce should replace the ranged damage icon instead of adding another keyword token")
	_assert(str((pierce_row[0] as Dictionary).get("icon", "")) == "pierce", "Pierce attacks should use the pierce damage icon")
	_assert(ActionIcons.tooltip("pierce").contains("block"), "Pierce tooltip should explain defense bypass")
	var blood_row: Array = ActionIcons.tokens_for_action({"type": "melee", "damage": 3, "range": 1, "bleed": 2, "expose": 4, "sunder": 3})
	_assert(str((blood_row[1] as Dictionary).get("icon", "")) == "bleed", "Bleed should render as an attack keyword token")
	_assert(str((blood_row[2] as Dictionary).get("icon", "")) == "expose", "Expose should render as an attack keyword token")
	_assert(str((blood_row[3] as Dictionary).get("icon", "")) == "sunder", "Sunder should render as an attack keyword token")
	_assert(ActionIcons.tooltip("bleed").contains("move or attack"), "Bleed tooltip should explain action-triggered wound damage")
	_assert(ActionIcons.tooltip("expose").contains("next hit"), "Expose tooltip should explain the follow-up damage")
	_assert(ActionIcons.tooltip("sunder").contains("stoneskin"), "Sunder tooltip should explain defense breaking")
	var aoe_row: Array = ActionIcons.tokens_for_action({"type": "aoe", "damage": 5, "range": 0, "pattern": [[0, -1], [1, 0], [0, 1], [-1, 0]]})
	_assert(str((aoe_row[1] as Dictionary).get("kind", "")) == "aoe_pattern", "AOE actions should surface a tile pattern token")
	_assert(bool((aoe_row[1] as Dictionary).get("show_origin", false)), "Close AOE pattern tokens should include the player origin tile")
	_assert(ActionIcons.tooltip("poison").contains("Delayed damage"), "Keyword icon tooltips should include readable descriptions")
	var card_play_row: Array = ActionIcons.tokens_for_action({"type": "card_play", "amount": 1})
	_assert(str((card_play_row[0] as Dictionary).get("icon", "")) == "card_play", "Card-play actions should use the play-meter icon")
	_assert(ActionIcons.tooltip("card_play").contains("card plays"), "Card-play tooltip should explain the temporary play bonus")
	var flurry_cost_rows: Array = ActionIcons.cost_rows_for_card(GameData.card_def("cinder_fusillade"))
	_assert(flurry_cost_rows.size() == 1 and str(((flurry_cost_rows[0] as Array)[0] as Dictionary).get("icon", "")) == "flurry", "Flurry cards should show their dedicated cost icon")
	_assert(ActionIcons.tooltip("flurry").contains("pays Time once"), "Flurry tooltip should distinguish repeated effects from its single time payment")
	var flurry_icon := Image.new()
	var flurry_icon_error: Error = flurry_icon.load(ActionIcons.icon_path("flurry"))
	_assert(flurry_icon_error == OK and flurry_icon.get_width() == 112 and flurry_icon.get_height() == 64, "Flurry should ship its dedicated wide 112x64 action icon")
	var illusion_row: Array = ActionIcons.tokens_for_action({"type": "illusion", "health": 4, "range": 3})
	_assert(str((illusion_row[0] as Dictionary).get("icon", "")) == "illusion", "Illusion actions should use the illusion icon")
	_assert(str((illusion_row[1] as Dictionary).get("icon", "")) == "range", "Illusion actions should show placement range")
	_assert(ActionIcons.tooltip("illusion").contains("stationary copy"), "Illusion tooltip should explain the decoy")
	var cost_rows: Array = ActionIcons.cost_rows_for_card(GameData.card_def("gate_gambit"))
	_assert(cost_rows.size() == 1, "Card costs should render as one leading action row")
	var cost_row: Array = cost_rows[0] as Array
	_assert(str((cost_row[0] as Dictionary).get("icon", "")) == "exhaust", "Exhausting cards should use the exhaust cost icon")
	_assert(str((cost_row[1] as Dictionary).get("icon", "")) == "health_cost", "Health costs should use the health-cost token")
	var consume_cost_rows: Array = ActionIcons.cost_rows_for_card(GameData.card_def("crimson_draught"))
	_assert(consume_cost_rows.size() == 1 and str(((consume_cost_rows[0] as Array)[0] as Dictionary).get("icon", "")) == "consume", "Consumable item cards should show a one-use cost icon")
	_assert(not ActionIcons.tooltip("burn").contains("card"), "Burn status tooltip should not describe card exhaust costs")
	_assert(ActionIcons.tooltip("exhaust").contains("Removes this card"), "Exhaust cost tooltip should describe card removal")
	_assert(ActionIcons.tooltip("consume").contains("once"), "Consume cost tooltip should describe one-time item use")
	var tooltip_panel: PanelContainer = UiTooltipPanel.make_text(ActionIcons.tooltip("poison"))
	_assert(
		tooltip_panel.get_node_or_null(UiSkin.PANEL_INSET_ORNAMENT_NAME) != null
		and not tooltip_panel.find_children("*", "VBoxContainer", true, false).is_empty(),
		"Keyword tooltip text should render as a shaped custom panel instead of the default engine tooltip"
	)
	tooltip_panel.free()

func _test_merchant_assets_load_for_board() -> void:
	var board := CombatBoardView.new()
	board.visible = true
	board.call("_load_assets")
	for npc_id: String in ["blacksmith", "arcanist", "scavenger"]:
		var npc_def: Dictionary = GameData.npc_def(npc_id)
		var art_path: String = str(npc_def.get("art_path", ""))
		_assert(FileAccess.file_exists(art_path), "%s NPC sprite should exist" % npc_id)
		var texture: Texture2D = (board.get("_unit_textures") as Dictionary).get(npc_id, null)
		_assert(texture != null, "%s NPC sprite should load for board rendering" % npc_id)
	var prop_textures: Dictionary = board.get("_scene_prop_textures") as Dictionary
	_assert(prop_textures.get("blacksmith_forge", null) != null, "Blacksmith forge prop should load for board rendering")
	_assert(prop_textures.get("arcanist_table", null) != null, "Arcanist table prop should load for board rendering")
	_assert(prop_textures.get("scavenger_stall", null) != null, "Scavenger stall prop should load for board rendering")
	board.free()

func _test_room_icon_library_covers_door_room_types() -> void:
	var room_cases: Array[Dictionary] = [
		{"room": {"type": "combat", "element": "fire"}, "icon": "fire"},
		{"room": {"type": "combat", "element": "none"}, "icon": "combat"},
		{"room": {"type": "campfire", "element": "none"}, "icon": "campfire"},
		{"room": {"type": "treasure", "element": "none"}, "icon": "treasure"},
		{"room": {"type": "blacksmith", "element": "none"}, "icon": "blacksmith"},
		{"room": {"type": "arcanist", "element": "none"}, "icon": "arcanist"},
		{"room": {"type": "scavenger", "element": "none"}, "icon": "scavenger"},
		{"room": {"type": "boss", "element": "none"}, "icon": "boss"}
	]
	for room_case: Dictionary in room_cases:
		var icon_id: String = RoomIcons.icon_id_for_room(room_case.get("room", {}))
		_assert(icon_id == str(room_case.get("icon", "")), "Door icon ids should distinguish elemental combat and non-combat room destinations")
		_assert(not RoomIcons.icon_path(icon_id).is_empty(), "Every door icon id should resolve to a texture path")
		_assert(RoomIcons.icon_texture(icon_id) != null, "Every door icon id should load a texture")

func _test_minimap_uses_door_icons_and_greys_cleared_rooms() -> void:
	var map_view := LabyrinthMapView.new()
	var combat_icon: Texture2D = map_view.call("_room_icon_texture_for_room", {"type": "combat", "element": "fire"})
	var campfire_icon: Texture2D = map_view.call("_room_icon_texture_for_room", {"type": "campfire", "element": "none"})
	_assert(combat_icon != null, "Minimap combat rooms should use the same elemental door icon textures")
	_assert(campfire_icon != null, "Minimap non-combat rooms should use the same door icon textures")
	var uncleared: Color = map_view.call("_room_fill_color", {"type": "combat", "element": "fire", "cleared": false})
	var cleared: Color = map_view.call("_room_fill_color", {"type": "combat", "element": "fire", "cleared": true})
	var grey := Color("6f6a63")
	var uncleared_distance: float = absf(uncleared.r - grey.r) + absf(uncleared.g - grey.g) + absf(uncleared.b - grey.b)
	var cleared_distance: float = absf(cleared.r - grey.r) + absf(cleared.g - grey.g) + absf(cleared.b - grey.b)
	_assert(cleared_distance < uncleared_distance, "Cleared minimap rooms should read as muted grey instead of using a large X mark")
	map_view.set("interactive", false)
	map_view.set_run_state({
		"mode": "room",
		"current_room": Vector2i.ZERO,
		"rooms": {
			"0,0": {"coord": Vector2i.ZERO, "type": "start", "revealed": true, "cleared": true}
		}
	})
	map_view.size = Vector2(220.0, 188.0)
	_assert(float(map_view.call("_base_node_size")) >= 20.0, "Compact minimap icons should keep a legible minimum node size")
	map_view.set("show_legend", false)
	map_view.set_run_state({
		"mode": "room",
		"current_room": Vector2i.ZERO,
		"rooms": {
			"0,0": {
				"coord": Vector2i.ZERO,
				"type": "start",
				"revealed": true,
				"cleared": true,
				"connections": [{"coord": Vector2i(1, 0)}]
			},
			"1,0": {
				"coord": Vector2i(1, 0),
				"type": "combat",
				"element": "fire",
				"revealed": true,
				"cleared": false,
				"connections": [{"coord": Vector2i.ZERO}]
			}
		}
	})
	var node_size: float = float(map_view.call("_base_node_size"))
	var left_position: Vector2 = map_view.call("_coord_position", Vector2i.ZERO)
	var right_position: Vector2 = map_view.call("_coord_position", Vector2i(1, 0))
	var compact_spacing: float = float(map_view.call("_grid_spacing"))
	var compact_rect: Rect2 = map_view.call("_map_rect")
	_assert(compact_rect.grow(-node_size * 0.55).has_point(left_position), "Compact minimap start medallion should keep visible padding inside the frame")
	_assert(compact_rect.grow(-node_size * 0.55).has_point(right_position), "Compact minimap destination medallion should keep visible padding inside the frame")
	_assert(right_position.distance_to(left_position) >= node_size * 1.05, "Compact minimap adjacent rooms should remain visually distinct")
	map_view.set("interactive", true)
	map_view.set("show_legend", true)
	map_view.size = Vector2(920.0, 580.0)
	var full_left_position: Vector2 = map_view.call("_coord_position", Vector2i.ZERO)
	var full_right_position: Vector2 = map_view.call("_coord_position", Vector2i(1, 0))
	var full_spacing: float = float(map_view.call("_grid_spacing"))
	_assert(full_spacing > compact_spacing, "Full map should open the radial depth bands more confidently than the compact minimap")
	_assert(float(map_view.call("_base_node_size")) >= 48.0, "Full map nodes should read as deliberate large-map controls instead of compact minimap icons")
	_assert(full_right_position.distance_to(full_left_position) >= float(map_view.call("_base_node_size")) * 1.05, "Full map adjacent rooms should remain distinct on the radial route")
	_assert(absf(full_right_position.y - full_left_position.y) < full_spacing * 0.10, "Full map irregularity should remain subtle enough that adjacent depths still connect directly")
	var map_rect: Rect2 = map_view.call("_map_rect")
	var legend_rect: Rect2 = map_view.call("_legend_rect")
	var legend_content_rect: Rect2 = map_view.call("_legend_content_rect")
	_assert(map_rect.end.x + 1.0 <= legend_rect.position.x, "Full map legend should reserve space instead of covering map rooms")
	for room_var: Variant in map_view.call("_visible_rooms"):
		var room: Dictionary = room_var
		if bool(map_view.call("_room_is_onscreen", room)):
			_assert(not (map_view.call("_room_visual_rect", room) as Rect2).intersects(legend_rect, false), "Full map medallions should never render underneath the fixed legend")
	_assert(legend_rect.size.y < map_view.size.y * 0.90, "Full map legend should remain a contained authored subpanel")
	_assert(absf(legend_content_rect.position.x - legend_rect.position.x - (legend_rect.end.x - legend_content_rect.end.x)) <= 0.01, "Legend content should preserve equal left and right insets")
	_assert(legend_content_rect.position.x - legend_rect.position.x >= 28.0, "Legend icons should keep a safe inset from the authored border")
	for route_state: String in ["current", "reachable", "visited", "unavailable"]:
		_assert(map_view.call("_room_frame_texture", route_state) != null, "Map state %s should use an authored medallion frame" % route_state)
	_assert(map_view.call("_map_legend_frame") != null and map_view.call("_map_detail_frame") != null, "Map legend and room detail should use authored raster frames")
	var labels: Dictionary = {}
	for entry_var: Variant in map_view.call("_legend_entries"):
		var entry: Dictionary = entry_var
		labels[str(entry.get("label", ""))] = true
	for expected_label: String in ["Fire", "Ice", "Lightning", "Air", "Earth", "Campfire", "Relic", "Smith", "Arcanist", "Scavenger", "Boss"]:
		_assert(labels.has(expected_label), "Full map legend should include %s" % expected_label)
	_assert(not labels.has("Fight"), "Full map legend should not invent a generic Fight room icon")
	var marker_rooms: Dictionary = {
		"0,0": {
			"coord": Vector2i.ZERO,
			"type": "start",
			"revealed": true,
			"cleared": true
		},
		"3,0": {
			"coord": Vector2i(3, 0),
			"type": "combat",
			"element": "fire",
			"revealed": false,
			"cleared": false,
			"recovery_marker": true,
			"recovery_amount": 23
		}
	}
	map_view.set("interactive", false)
	map_view.set_run_state({"mode": "room", "current_room": Vector2i.ZERO, "rooms": marker_rooms})
	_assert(not _map_visible_coords(map_view).has(Vector2i(3, 0)), "Compact minimap should not reveal distant dropped embers")
	map_view.set("interactive", true)
	_assert(_map_visible_coords(map_view).has(Vector2i(3, 0)), "Full map should show the dropped ember room at its exact coordinate")
	map_view.free()

func _test_large_map_decision_layer() -> void:
	var map_view := LabyrinthMapView.new()
	map_view.set("interactive", true)
	map_view.set("show_legend", true)
	map_view.size = Vector2(920.0, 580.0)

	for fixture_var: Variant in [
		{"label": "early", "min": Vector2i(-1, -1), "max": Vector2i(1, 1)},
		{"label": "mid", "min": Vector2i(-3, -2), "max": Vector2i(3, 2)},
		{"label": "long", "min": Vector2i(-7, -5), "max": Vector2i(7, 5)}
	]:
		var fixture: Dictionary = fixture_var
		var minimum_coord: Vector2i = fixture.get("min", Vector2i.ZERO)
		var maximum_coord: Vector2i = fixture.get("max", Vector2i.ZERO)
		var fixture_state: Dictionary = _map_bounds_fixture(minimum_coord, maximum_coord)
		fixture_state["current_room"] = maximum_coord
		var fixture_rooms: Dictionary = fixture_state.get("rooms", {})
		var current_key: String = "%d,%d" % [maximum_coord.x, maximum_coord.y]
		if fixture_rooms.has(current_key):
			var fixture_current_room: Dictionary = fixture_rooms[current_key]
			fixture_current_room["visited"] = true
			fixture_rooms[current_key] = fixture_current_room
		map_view.set_run_state(fixture_state)
		var map_rect: Rect2 = map_view.call("_map_rect")
		var ring_step_world: float = float(map_view.call("_depth_ring_step")) / float(map_view.call("_camera_zoom_value"))
		var maximum_depth: int = maxi(
			maxi(absi(minimum_coord.x), absi(minimum_coord.y)),
			maxi(absi(maximum_coord.x), absi(maximum_coord.y))
		)
		_assert(map_view.call("_coord_position", maximum_coord).distance_to(map_rect.get_center()) <= 0.01, "%s map should frame the current room instead of compressing the entire run" % str(fixture.get("label", "map")))
		_assert(int(map_view.call("_depth_ring_count")) == maxi(1, maximum_depth), "%s map should preserve one ring for every gameplay depth" % str(fixture.get("label", "map")))
		for room_var: Variant in map_view.call("_visible_rooms"):
			var room: Dictionary = room_var
			var coord: Vector2i = room.get("coord", Vector2i.ZERO)
			var position: Vector2 = map_view.call("_coord_position", coord)
			var depth: int = int(room.get("depth", maxi(absi(coord.x), absi(coord.y))))
			var world_position: Vector2 = map_view.call("_world_position", coord)
			if depth <= 0:
				_assert(world_position.length() <= 0.01, "%s map should anchor depth zero at the labyrinth center" % str(fixture.get("label", "map")))
			else:
				_assert(absf(world_position.length() - float(depth) * ring_step_world) <= ring_step_world * 0.08, "%s room %s should remain on its exact depth ring" % [str(fixture.get("label", "map")), coord])
			if map_rect.grow(-float(map_view.call("_base_node_size")) * 0.52).has_point(position):
				_assert(map_rect.has_point(position), "%s on-screen medallions should remain inside the map field" % str(fixture.get("label", "map")))
		_assert_map_room_medallions_do_not_overlap(map_view, "%s radial map" % str(fixture.get("label", "map")))

	var earlier_visited := Vector2i.ZERO
	var visited := Vector2i(1, 0)
	var current := Vector2i(1, 1)
	var reachable := Vector2i(2, 1)
	var unavailable := Vector2i(1, 2)
	var rooms: Dictionary = {
		"0,0": {"coord": earlier_visited, "depth": 0, "type": "start", "element": "none", "revealed": true, "visited": true, "cleared": true, "connections": [{"coord": visited}]},
		"1,0": {"coord": visited, "depth": 1, "type": "campfire", "element": "none", "revealed": true, "visited": true, "cleared": true, "connections": [{"coord": earlier_visited}, {"coord": current}]},
		"1,1": {"coord": current, "depth": 2, "type": "combat", "element": "fire", "revealed": true, "visited": true, "cleared": true, "connections": [{"coord": visited}, {"coord": reachable}, {"coord": unavailable}]},
		"2,1": {"coord": reachable, "depth": 3, "type": "combat", "element": "ice", "name": "Known Vault", "revealed": true, "visited": false, "cleared": false, "sealed": false, "connections": [{"coord": current}], "reward": "hidden_relic", "enemy_types": ["hidden_enemy"], "risk": 99},
		"1,2": {"coord": unavailable, "depth": 3, "type": "treasure", "element": "none", "revealed": true, "visited": false, "cleared": false, "sealed": true, "connections": [{"coord": current}]}
	}
	map_view.set_run_state({"mode": "room", "current_room": current, "rooms": rooms})
	_assert(str(map_view.call("_node_route_state", rooms["1,1"])) == "current", "Large map should classify the current room explicitly")
	_assert(str(map_view.call("_node_route_state", rooms["2,1"])) == "reachable", "Large map should classify a legal destination explicitly")
	_assert(str(map_view.call("_node_route_state", rooms["1,0"])) == "visited", "Large map should classify traveled rooms explicitly")
	_assert(str(map_view.call("_node_route_state", rooms["1,2"])) == "unavailable", "Large map should classify revealed but unavailable rooms explicitly")
	_assert(str(map_view.call("_connector_route_state", current, reachable)) == "reachable", "Current-to-destination connectors should read as reachable routes")
	_assert(str(map_view.call("_connector_route_state", current, visited)) == "current", "The connector into the current room should retain current-route hierarchy")
	_assert(str(map_view.call("_connector_route_state", visited, earlier_visited)) == "visited", "Previously traveled connectors should retain visited-route hierarchy")
	_assert(str(map_view.call("_connector_route_state", current, unavailable)) == "unavailable", "Sealed or otherwise illegal connectors should retain unavailable-route hierarchy")
	var room_inventory_before: Array[Vector2i] = _map_visible_coords(map_view)
	var world_positions_before: Dictionary = {}
	for coord: Vector2i in room_inventory_before:
		world_positions_before[coord] = map_view.call("_world_position", coord)
	var screen_position_before_pan: Vector2 = map_view.call("_coord_position", current)
	var background_before_pan: Rect2 = map_view.call("_background_screen_rect")
	_assert((map_view.call("_background_labyrinth_center_screen") as Vector2).distance_to(map_view.call("_radial_center")) <= 0.05, "The authored floor's labyrinth center should align with the gameplay depth rings")
	var pan_delta := Vector2(46.0, -24.0)
	map_view.call("pan_camera", pan_delta)
	_assert(_map_visible_coords(map_view) == room_inventory_before, "Panning should never change the persistent room inventory")
	for coord: Vector2i in room_inventory_before:
		_assert((map_view.call("_world_position", coord) as Vector2).distance_to(world_positions_before.get(coord, Vector2.ZERO)) <= 0.001, "Panning should never rebuild or relocate room world coordinates")
	_assert((map_view.call("_coord_position", current) as Vector2).distance_to(screen_position_before_pan + pan_delta) <= 0.05, "Panning should translate every visible room by the requested screen delta")
	var background_after_pan: Rect2 = map_view.call("_background_screen_rect")
	_assert(background_after_pan.position.distance_to(background_before_pan.position + pan_delta) <= 0.05, "The authored background should pan in lockstep with the room map")
	map_view.call("center_on_current", true)
	var camera_map_rect: Rect2 = map_view.call("_map_rect")
	var camera_node_size: float = float(map_view.call("_base_node_size"))
	var current_center: Vector2 = map_view.call("_coord_position", current)
	map_view.call("pan_camera", Vector2(camera_map_rect.position.x - camera_node_size * 0.70 - current_center.x, 0.0))
	_assert(bool(map_view.call("_room_is_onscreen", rooms["1,1"])), "A room should remain rendered while any meaningful part of its medallion remains in view")
	map_view.call("pan_camera", Vector2(-camera_node_size * 0.12, 0.0))
	_assert(not bool(map_view.call("_room_is_onscreen", rooms["1,1"])), "A room should cull only after its medallion has geometrically left the map field")
	map_view.call("center_on_current", true)
	current_center = map_view.call("_coord_position", current)
	var camera_legend_rect: Rect2 = map_view.call("_legend_rect")
	map_view.call("pan_camera", Vector2(camera_legend_rect.position.x - camera_node_size * 0.30 - current_center.x, 0.0))
	_assert(not bool(map_view.call("_room_is_onscreen", rooms["1,1"])), "A medallion should cull coherently instead of appearing underneath the opaque legend")
	_assert(map_view.call("_hover_coord_at_point", map_view.call("_coord_position", current)) == Vector2i(-999, -999), "A room hidden by the legend should not retain an invisible hover target")
	map_view.call("center_on_current", true)
	var unavailable_room: Dictionary = rooms["1,2"]
	var unavailable_visual_rect: Rect2 = map_view.call("_room_visual_rect", unavailable_room)
	var unavailable_center: Vector2 = map_view.call("_coord_position", unavailable)
	var seam_target_x: float = camera_legend_rect.position.x - unavailable_visual_rect.size.x * 0.5 - 1.0
	map_view.call("pan_camera", Vector2(seam_target_x - unavailable_center.x, 0.0))
	_assert(bool(map_view.call("_room_is_onscreen", unavailable_room)), "A blocked medallion should remain rendered when its silhouette is clear of the legend")
	var seam_room_center: Vector2 = map_view.call("_coord_position", unavailable)
	var legend_seam_point := Vector2(camera_legend_rect.position.x + 1.0, seam_room_center.y)
	_assert(map_view.call("_hover_coord_at_point", legend_seam_point) == Vector2i(-999, -999), "The blocked-room hover radius must not leak into the opaque legend")
	var visible_seam_point := Vector2(camera_map_rect.end.x - 1.0, seam_room_center.y)
	_assert(map_view.call("_hover_coord_at_point", visible_seam_point) == unavailable, "The same blocked room should remain inspectable from the unobstructed map field")
	map_view.call("center_on_current", true)
	var curved_route: PackedVector2Array = map_view.call("_route_curve_points", current, reachable)
	var straight_midpoint: Vector2 = map_view.call("_coord_position", current).lerp(map_view.call("_coord_position", reachable), 0.5)
	_assert(curved_route.size() >= 12, "Large-map routes should use sampled curves instead of rigid two-point grid lines")
	_assert(curved_route[curved_route.size() / 2].distance_to(straight_midpoint) <= 18.1, "Large-map routes should stay relatively direct instead of curling into a spiral")

	var reachable_position: Vector2 = map_view.call("_coord_position", reachable)
	var unavailable_position: Vector2 = map_view.call("_coord_position", unavailable)
	_assert(map_view.call("_coord_at_point", reachable_position) == reachable, "Large-map selection should still accept reachable destinations")
	_assert(map_view.call("_coord_at_point", unavailable_position) == Vector2i(-999, -999), "Large-map selection should still reject unavailable destinations")
	_assert(map_view.call("_hover_coord_at_point", unavailable_position) == unavailable, "Hover context may inspect a revealed unavailable room without making it selectable")
	var framed_position: Vector2 = map_view.call("_coord_position", current)
	var hover_before_pinch := InputEventMouseMotion.new()
	hover_before_pinch.position = framed_position
	map_view.call("_gui_input", hover_before_pinch)
	_assert(map_view.get("_hover_coord") == current, "The current room should be hoverable before trackpad zoom")
	var pinch := InputEventMagnifyGesture.new()
	pinch.position = framed_position
	pinch.factor = 1.40
	map_view.call("_gui_input", pinch)
	_assert(is_equal_approx(float(map_view.call("_camera_zoom_value")), 1.40), "Large-map pinch zoom should update the camera zoom")
	_assert(map_view.get("_hover_coord") == Vector2i(-999, -999), "Trackpad pinch should clear a hover card whose room geometry is about to move")
	_assert(map_view.call("_coord_position", current).distance_to(framed_position) <= 0.05, "Trackpad pinch zoom should keep the room beneath the gesture anchored")
	var focus_before_pan: Vector2 = map_view.call("_camera_focus")
	map_view.call("pan_camera", Vector2(72.0, -38.0))
	_assert(map_view.call("_camera_focus") != focus_before_pan, "Large-map drag input should pan the camera")
	map_view.call("center_on_current", true)
	_assert(is_equal_approx(float(map_view.call("_camera_zoom_value")), 1.0), "Reframing the current room should restore the default readable zoom")
	_assert(map_view.call("_coord_position", current).distance_to((map_view.call("_map_rect") as Rect2).get_center()) <= 0.05, "Reframing should return the current room to the local map center")

	var card_data: Dictionary = map_view.call("_hover_card_data", rooms["2,1"])
	var card_keys: Array = card_data.keys()
	card_keys.sort()
	_assert(card_keys == ["depth", "element", "name", "type"], "Map hover cards should expose only known name, type, element, and depth fields")
	_assert(str(card_data.get("name", "")) == "Known Vault", "Map hover card should preserve an already-known room name")
	_assert(str(card_data.get("type", "")) == "Combat" and str(card_data.get("element", "")) == "Ice" and int(card_data.get("depth", -1)) == 3, "Map hover card should report only known destination metadata")

	for edge_coord: Vector2i in [Vector2i(-7, -5), Vector2i(7, 5)]:
		var edge_state: Dictionary = _map_bounds_fixture(Vector2i(-7, -5), Vector2i(7, 5))
		edge_state["current_room"] = edge_coord
		map_view.set_run_state(edge_state)
		map_view.call("center_on_current", true)
		var card_bounds: Rect2 = map_view.call("_hover_card_bounds")
		var hover_rect: Rect2 = map_view.call("_hover_card_rect", edge_coord)
		var node_center: Vector2 = map_view.call("_coord_position", edge_coord)
		var node_half_size: float = float(map_view.call("_base_node_size")) * 0.66
		var node_safe_rect := Rect2(node_center - Vector2.ONE * node_half_size, Vector2.ONE * node_half_size * 2.0).grow(18.0)
		_assert(card_bounds.encloses(hover_rect), "Edge hover card should remain fully inside the large-map drawing bounds")
		_assert(not hover_rect.intersects(node_safe_rect), "Edge hover card should flip away from, rather than cover, its room node")
		_assert(not bool(map_view.call("_hover_card_intersects_other_node", hover_rect, edge_coord)), "Edge hover card should prefer placement that preserves adjacent route nodes")

	map_view.set_run_state({"mode": "room", "current_room": current, "rooms": rooms})
	map_view.set("interactive", false)
	map_view.set("show_legend", false)
	_assert(map_view.call("_hover_coord_at_point", Vector2.ZERO) == Vector2i(-999, -999), "Compact minimap should remain label- and hover-card-free")
	var compact_focus: Array[Vector2i] = map_view.call("_compact_focus_coords")
	_assert(compact_focus.has(current) and compact_focus.has(reachable), "Compact minimap should always retain the current room and legal destinations")
	_assert(compact_focus.size() <= rooms.size(), "Compact minimap focus should never invent rooms outside the revealed run")
	map_view.free()

func _assert_map_room_medallions_do_not_overlap(map_view: LabyrinthMapView, context: String) -> void:
	var visible_rooms: Array[Dictionary] = map_view.call("_visible_rooms")
	var minimum_clearance: float = float(map_view.call("_base_node_size")) * 0.92
	var map_rect: Rect2 = map_view.call("_map_rect")
	for first_index: int in range(visible_rooms.size()):
		var first_coord: Vector2i = visible_rooms[first_index].get("coord", Vector2i.ZERO)
		var first_position: Vector2 = map_view.call("_coord_position", first_coord)
		if not map_rect.grow(float(map_view.call("_base_node_size"))).has_point(first_position):
			continue
		for second_index: int in range(first_index + 1, visible_rooms.size()):
			var second_coord: Vector2i = visible_rooms[second_index].get("coord", Vector2i.ZERO)
			var second_position: Vector2 = map_view.call("_coord_position", second_coord)
			if not map_rect.grow(float(map_view.call("_base_node_size"))).has_point(second_position):
				continue
			_assert(first_position.distance_to(second_position) >= minimum_clearance, "%s room medallions should not overlap (%s and %s)" % [context, first_coord, second_coord])

func _map_bounds_fixture(min_coord: Vector2i, max_coord: Vector2i) -> Dictionary:
	var rooms: Dictionary = {
		"0,0": {"coord": Vector2i.ZERO, "depth": 0, "type": "start", "element": "none", "revealed": true, "visited": true, "cleared": true, "connections": []}
	}
	for coord: Vector2i in [
		min_coord,
		Vector2i(max_coord.x, min_coord.y),
		max_coord,
		Vector2i(min_coord.x, max_coord.y)
	]:
		var key: String = "%d,%d" % [coord.x, coord.y]
		if rooms.has(key):
			continue
		rooms[key] = {"coord": coord, "depth": maxi(absi(coord.x), absi(coord.y)), "type": "combat", "element": "fire", "revealed": true, "visited": false, "cleared": false, "sealed": true, "connections": []}
	return {"mode": "room", "current_room": Vector2i.ZERO, "rooms": rooms}

func _test_minimap_travel_animation_state() -> void:
	var map_view := LabyrinthMapView.new()
	map_view.set("interactive", false)
	map_view.set("show_legend", false)
	map_view.size = Vector2(220.0, 188.0)
	map_view.set_run_state({
		"mode": "room",
		"current_room": Vector2i.ZERO,
		"rooms": {
			"0,0": {
				"coord": Vector2i.ZERO,
				"type": "start",
				"revealed": true,
				"cleared": true,
				"connections": [{"coord": Vector2i(1, 0)}]
			},
			"1,0": {
				"coord": Vector2i(1, 0),
				"type": "combat",
				"element": "fire",
				"revealed": true,
				"cleared": false,
				"connections": [{"coord": Vector2i.ZERO}]
			}
		}
	})
	var start_position: Vector2 = map_view.call("_coord_position", Vector2i.ZERO)
	var destination_position: Vector2 = map_view.call("_coord_position", Vector2i(1, 0))
	_assert(bool(map_view.call("begin_travel_animation", Vector2i.ZERO, Vector2i(1, 0))), "Minimap should start a travel animation between visible connected rooms")
	_assert(bool(map_view.get("_travel_active")), "Minimap should mark travel animation active after a valid move starts")
	_assert(map_view.get("_travel_from_coord") == Vector2i.ZERO, "Travel animation should remember the previous room coordinate")
	_assert(map_view.get("_travel_to_coord") == Vector2i(1, 0), "Travel animation should remember the destination room coordinate")
	map_view.set("_travel_progress", 0.5)
	var token_position: Vector2 = map_view.call("_travel_token_position")
	_assert(token_position.distance_to(start_position) > 1.0, "Travel token should leave the previous room while in transit")
	_assert(token_position.distance_to(destination_position) > 1.0, "Travel token should not instantly snap to the destination")
	_assert(((map_view.get("run_state") as Dictionary).get("current_room", Vector2i.ZERO) == Vector2i.ZERO), "Minimap current-room highlight should remain on the previous room until run state changes")
	map_view.call("clear_travel_animation")
	_assert(not bool(map_view.get("_travel_active")), "Minimap should clear travel animation state after settlement")
	_assert(not bool(map_view.call("begin_travel_animation", Vector2i(-999, -999), Vector2i(1, 0))), "Minimap travel animation should no-op cleanly without a previous room coordinate")
	map_view.free()

func _test_combat_board_loads_door_icons_for_room_types() -> void:
	var board := CombatBoardView.new()
	board.call("_load_assets")
	var textures: Dictionary = board.get("_door_icon_textures") as Dictionary
	for icon_id: String in ["fire", "combat", "campfire", "treasure", "blacksmith", "arcanist", "scavenger", "boss"]:
		_assert(textures.get(icon_id, null) != null, "Combat board should load door icons for elemental and non-combat destinations")
	board.free()

func _map_visible_coords(map_view: LabyrinthMapView) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for room_var: Variant in map_view.call("_visible_rooms"):
		if typeof(room_var) != TYPE_DICTIONARY:
			continue
		coords.append((room_var as Dictionary).get("coord", Vector2i.ZERO))
	return coords

func _first_room_coord_of_type(run_engine: RunEngine, run_state: Dictionary, room_type: String) -> Vector2i:
	for coord: Vector2i in _room_coords_near_to_far():
		if str(run_engine.room_metadata(run_state, coord).get("type", "")) == room_type:
			return coord
	return Vector2i(999, 999)

func _first_reachable_room_of_type(run_engine: RunEngine, run_state: Dictionary, room_type: String) -> Dictionary:
	for coord: Vector2i in _room_coords_near_to_far():
		if str(run_engine.room_metadata(run_state, coord).get("type", "")) != room_type:
			continue
		var route: Array = _find_route_to_coord(run_engine, run_state, coord)
		if route.is_empty():
			continue
		return {
			"coord": coord,
			"route": route
		}
	return {}

func _room_coords_near_to_far() -> Array[Vector2i]:
	var result: Array[Vector2i] = [Vector2i.ZERO]
	for depth: int in range(1, RunEngine.MAX_DEPTH + 1):
		for x: int in range(-depth, depth + 1):
			result.append(Vector2i(x, -depth))
			result.append(Vector2i(x, depth))
		for y: int in range(-depth + 1, depth):
			result.append(Vector2i(-depth, y))
			result.append(Vector2i(depth, y))
	return result

func _test_run_map_room_types() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var progression: Dictionary = ProgressionStore.prepare_for_new_run(ProgressionStore.default_data())
	var run_state: Dictionary = run_engine.create_new_run(13, progression)
	_assert(str(run_engine.room_metadata(run_state, Vector2i.ZERO).get("type", "")) == "start", "Origin should be the start room")
	_assert(str(run_engine.room_metadata(run_state, Vector2i(2, 0)).get("type", "")) == "campfire", "Axis depth-2 rooms should be campfire rooms")
	_assert(str(run_engine.room_metadata(run_state, Vector2i(4, 0)).get("type", "")) == "boss", "Depth-four rooms should punctuate the first sequence with boss territory")
	_assert(str(run_engine.room_metadata(run_state, Vector2i(6, 0)).get("type", "")) == "campfire", "Axis depth-6 rooms should repeat the campfire beat in the second sequence")
	_assert(str(run_engine.room_metadata(run_state, Vector2i(8, 0)).get("type", "")) == "boss", "Depth-eight rooms should punctuate the second sequence with boss territory")

func _test_run_map_two_room_choices_are_like_category_different_type() -> void:
	var run_engine: RunEngine = RunEngine.new()
	for seed: int in range(1, 21):
		var base_state: Dictionary = run_engine.create_new_run(seed, ProgressionStore.default_data())
		for x: int in range(-MAP_RULE_SCAN_DEPTH, MAP_RULE_SCAN_DEPTH + 1):
			for y: int in range(-MAP_RULE_SCAN_DEPTH, MAP_RULE_SCAN_DEPTH + 1):
				var current := Vector2i(x, y)
				if maxi(absi(current.x), absi(current.y)) > MAP_RULE_SCAN_DEPTH:
					continue
				var base_room: Dictionary = run_engine.room_metadata(base_state, current)
				if str(base_room.get("type", "")) == "boss":
					continue
				var connections: Array = base_room.get("connections", [])
				var sealed_variant_count: int = 1 << connections.size()
				for sealed_mask: int in range(sealed_variant_count):
					var run_state: Dictionary = base_state.duplicate(true)
					var rooms: Dictionary = {}
					var current_room: Dictionary = base_room.duplicate(true)
					current_room["revealed"] = true
					current_room["visited"] = true
					current_room["cleared"] = true
					current_room["sealed"] = false
					rooms[_test_room_key(current)] = current_room
					for connection_index: int in range(connections.size()):
						if (sealed_mask & (1 << connection_index)) == 0:
							continue
						var connection: Dictionary = connections[connection_index]
						var sealed_coord: Vector2i = connection.get("coord", Vector2i(999, 999))
						if sealed_coord.x >= 900:
							continue
						var sealed_room: Dictionary = run_engine.room_metadata(base_state, sealed_coord).duplicate(true)
						sealed_room["revealed"] = true
						sealed_room["visited"] = true
						sealed_room["cleared"] = true
						sealed_room["sealed"] = true
						rooms[_test_room_key(sealed_coord)] = sealed_room
					run_state["current_room"] = current
					run_state["mode"] = "room"
					run_state["rooms"] = rooms
					run_engine.call("_reveal_neighbors", run_state, current)
					run_engine.call("_ensure_loop_escape_connection", run_state, current)
					var moves: Array[Vector2i] = run_engine.available_moves(run_state)
					if moves.size() != 2:
						continue
					var first_room: Dictionary = run_engine.room_metadata(run_state, moves[0])
					var second_room: Dictionary = run_engine.room_metadata(run_state, moves[1])
					var message: String = "Two-room choices should match combat/non-combat category and differ in visible type. seed=%d current=%s choices=%s:%s/%s vs %s:%s/%s" % [
						seed,
						str(current),
						str(moves[0]),
						str(first_room.get("type", "")),
						str(first_room.get("element", "")),
						str(moves[1]),
						str(second_room.get("type", "")),
						str(second_room.get("element", ""))
					]
					_assert(_test_map_choice_pair_is_valid(first_room, second_room), message)

func _test_map_choice_pair_is_valid(first_room: Dictionary, second_room: Dictionary) -> bool:
	if _test_map_choice_category(first_room) != _test_map_choice_category(second_room):
		return false
	return _test_map_choice_type_key(first_room) != _test_map_choice_type_key(second_room)

func _test_run_map_recovery_marker_keeps_two_room_choices_like_category() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var current := Vector2i(1, -2)
	var campfire_coord := Vector2i(0, -2)
	var recovery_coord := Vector2i(2, -2)
	var progression: Dictionary = ProgressionStore.prepare_for_new_run(ProgressionStore.default_data())
	progression = ProgressionStore.record_lost_embers(progression, 23, recovery_coord, int(progression.get("run_counter", 0)))
	progression = ProgressionStore.prepare_for_new_run(progression)
	var run_state: Dictionary = run_engine.create_new_run(51, progression)
	var rooms: Dictionary = run_state.get("rooms", {}).duplicate(true)
	var current_room: Dictionary = run_engine.room_metadata(run_state, current).duplicate(true)
	current_room["revealed"] = true
	current_room["visited"] = true
	current_room["cleared"] = true
	current_room["sealed"] = false
	rooms[_test_room_key(current)] = current_room
	run_state["current_room"] = current
	run_state["mode"] = "room"
	run_state["rooms"] = rooms
	run_engine.call("_reveal_neighbors", run_state, current)
	var moves: Array[Vector2i] = run_engine.available_moves(run_state)
	_assert(moves.size() == 2 and moves.has(campfire_coord) and moves.has(recovery_coord), "Recovery regression setup should expose exactly the campfire/recovery two-choice pair")
	var campfire_choice: Dictionary = run_engine.room_metadata(run_state, campfire_coord)
	var recovery_choice: Dictionary = run_engine.room_metadata(run_state, recovery_coord)
	_assert(bool(recovery_choice.get("recovery_marker", false)), "The dropped ember room should keep its recovery marker after pair normalization")
	_assert(str(recovery_choice.get("type", "")) == "combat", "The dropped ember room should stay combat so lost embers remain recoverable")
	_assert(_test_map_choice_pair_is_valid(campfire_choice, recovery_choice), "Recovery combat paired with a campfire should normalize into like-category, different-type choices")
	_assert(str(campfire_choice.get("type", "")) == "combat", "The campfire choice should be converted only when needed to match locked recovery combat")

func _test_map_choice_category(room: Dictionary) -> String:
	var room_type: String = str(room.get("type", "combat"))
	if room_type == "combat" or room_type == "boss":
		return "combat"
	return "non_combat"

func _test_map_choice_type_key(room: Dictionary) -> String:
	var room_type: String = str(room.get("type", "combat"))
	if room_type == "combat":
		return str(room.get("element", "none"))
	if room_type == "boss":
		return "boss"
	return room_type

func _test_room_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

func _test_run_map_relic_room_spacing_and_density() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var total_non_boss_rooms: int = 0
	var total_relic_rooms: int = 0
	var first_signature: String = ""
	var found_different_signature: bool = false
	for seed: int in range(1, 41):
		var run_state: Dictionary = run_engine.create_new_run(seed, ProgressionStore.default_data())
		var signature_parts: Array[String] = []
		for exit_coord: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			_assert(str(run_engine.room_metadata(run_state, exit_coord).get("type", "")) != "treasure", "Relic rooms should never be direct exits from the start")
		for x: int in range(-MAP_RULE_SCAN_DEPTH, MAP_RULE_SCAN_DEPTH + 1):
			for y: int in range(-MAP_RULE_SCAN_DEPTH, MAP_RULE_SCAN_DEPTH + 1):
				var coord := Vector2i(x, y)
				if maxi(absi(coord.x), absi(coord.y)) > MAP_RULE_SCAN_DEPTH:
					continue
				var room: Dictionary = run_engine.room_metadata(run_state, coord)
				var room_type: String = str(room.get("type", "combat"))
				if room_type != "boss":
					total_non_boss_rooms += 1
				if room_type != "treasure":
					continue
				total_relic_rooms += 1
				signature_parts.append("%d,%d" % [coord.x, coord.y])
				for dir: Vector2i in PathUtils.DIRS_4:
					var neighbor: Vector2i = coord + dir
					if maxi(absi(neighbor.x), absi(neighbor.y)) > MAP_RULE_SCAN_DEPTH:
						continue
					_assert(str(run_engine.room_metadata(run_state, neighbor).get("type", "")) != "treasure", "Relic rooms should not be cardinally adjacent")
		signature_parts.sort()
		var signature: String = "|".join(signature_parts)
		if seed == 1:
			first_signature = signature
		elif signature != first_signature:
			found_different_signature = true
	var density: float = float(total_relic_rooms) / float(maxi(1, total_non_boss_rooms))
	_assert(density > 0.20 and density < 0.30, "Relic rooms should average roughly one quarter of non-boss rooms")
	_assert(found_different_signature, "Relic room placement should vary probabilistically by seed")

func _test_run_map_merchant_room_spacing_and_density() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var total_eligible_rooms: int = 0
	var total_merchant_rooms: int = 0
	var merchant_types: Dictionary = {}
	var first_signature: String = ""
	var found_different_signature: bool = false
	for seed: int in range(1, 51):
		var run_state: Dictionary = run_engine.create_new_run(seed, ProgressionStore.default_data())
		var signature_parts: Array[String] = []
		for x: int in range(-MAP_RULE_SCAN_DEPTH, MAP_RULE_SCAN_DEPTH + 1):
			for y: int in range(-MAP_RULE_SCAN_DEPTH, MAP_RULE_SCAN_DEPTH + 1):
				var coord := Vector2i(x, y)
				var depth: int = maxi(absi(coord.x), absi(coord.y))
				if depth > MAP_RULE_SCAN_DEPTH:
					continue
				var room: Dictionary = run_engine.room_metadata(run_state, coord)
				var room_type: String = str(room.get("type", "combat"))
				if depth >= RunEngine.MERCHANT_ROOM_MIN_DEPTH and room_type not in ["boss", "campfire", "treasure"]:
					total_eligible_rooms += 1
				if room_type not in ["blacksmith", "arcanist", "scavenger"]:
					continue
				total_merchant_rooms += 1
				merchant_types[room_type] = true
				signature_parts.append("%d,%d:%s" % [coord.x, coord.y, room_type])
				_assert(depth >= RunEngine.MERCHANT_ROOM_MIN_DEPTH, "Merchant rooms should not appear before depth two")
				var npcs: Array = room.get("npcs", [])
				_assert(npcs.size() == 1 and str((npcs[0] as Dictionary).get("id", "")) == room_type, "Merchant rooms should carry their matching NPC")
				for dir: Vector2i in PathUtils.DIRS_4:
					var neighbor: Vector2i = coord + dir
					if maxi(absi(neighbor.x), absi(neighbor.y)) > MAP_RULE_SCAN_DEPTH:
						continue
					_assert(str(run_engine.room_metadata(run_state, neighbor).get("type", "")) not in ["blacksmith", "arcanist", "scavenger"], "Merchant rooms should never be cardinally adjacent")
		signature_parts.sort()
		var signature: String = "|".join(signature_parts)
		if seed == 1:
			first_signature = signature
		elif signature != first_signature:
			found_different_signature = true
	var density: float = float(total_merchant_rooms) / float(maxi(1, total_eligible_rooms))
	_assert(density > 0.09 and density < 0.18, "Merchant rooms should average a moderate non-combat frequency")
	_assert(merchant_types.has("blacksmith") and merchant_types.has("arcanist") and merchant_types.has("scavenger"), "Merchant generation should include blacksmith, arcanist, and scavenger rooms")
	_assert(found_different_signature, "Merchant room placement should vary probabilistically by seed")

func _test_run_map_repeats_depth_sequences() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(13, ProgressionStore.default_data())
	var depth_four_room: Dictionary = run_engine.room_metadata(run_state, Vector2i(4, 0))
	var has_depth_five_exit: bool = false
	for connection_var: Variant in depth_four_room.get("connections", []):
		var connection: Dictionary = connection_var
		var target: Vector2i = connection.get("coord", Vector2i.ZERO)
		if int(run_engine.room_metadata(run_state, target).get("depth", 0)) == 5:
			has_depth_five_exit = true
			break
	_assert(has_depth_five_exit, "Intermediate boss rooms should open directly into the next depth sequence")
	_assert(str(run_engine.room_metadata(run_state, Vector2i(5, 0)).get("type", "")) != "boss", "Depth five should restart regular room generation instead of remaining boss territory")

func _test_run_map_ring_links_and_outward_quarter() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(13, ProgressionStore.default_data())
	for depth: int in [1, 2, 3, 5, 6, 7]:
		var outward_rooms: int = 0
		var total_rooms: int = 0
		for x: int in range(-depth, depth + 1):
			for y: int in range(-depth, depth + 1):
				var coord := Vector2i(x, y)
				if maxi(absi(coord.x), absi(coord.y)) != depth:
					continue
				total_rooms += 1
				var room: Dictionary = run_engine.room_metadata(run_state, coord)
				var same_depth_links: int = 0
				var outward_links: int = 0
				for connection_var: Variant in room.get("connections", []):
					var connection: Dictionary = connection_var
					var target: Vector2i = connection.get("coord", Vector2i.ZERO)
					_assert(PathUtils.manhattan(coord, target) == 1, "All map links should use literal cardinal adjacency")
					var target_depth: int = maxi(absi(target.x), absi(target.y))
					if target_depth == depth:
						same_depth_links += 1
					elif target_depth == depth + 1:
						outward_links += 1
				_assert(total_rooms <= depth * 8, "Square-ring depth %d should never exceed 8*d rooms" % depth)
				_assert(same_depth_links == 2, "Depth-%d rooms should always link to one room on either side of the ring" % depth)
				if outward_links > 0:
					outward_rooms += 1
		_assert(total_rooms == depth * 8, "Depth-%d should contain exactly %d rooms in the square ring" % [depth, depth * 8])
		_assert(outward_rooms == int(total_rooms / 4), "Exactly one quarter of depth-%d rooms should open to depth %d" % [depth, depth + 1])

func _test_run_map_seals_departed_rooms() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(13, ProgressionStore.default_data())
	run_state = run_engine.move_to_room(run_state, Vector2i(1, 0))
	if str(run_state.get("mode", "")) == "combat":
		var combat_state: Dictionary = run_state.get("combat_state", {}).duplicate(true)
		for enemy_index: int in range((combat_state.get("enemies", []) as Array).size()):
			var enemy: Dictionary = (combat_state.get("enemies", []) as Array)[enemy_index]
			enemy["hp"] = 0
			(combat_state.get("enemies", []) as Array)[enemy_index] = enemy
		run_state = run_engine.finish_combat(run_state, combat_state)
		run_state = run_engine.skip_reward_for_heal(run_state)
	_assert(bool(run_engine.room_metadata(run_state, Vector2i.ZERO).get("sealed", false)), "Leaving the waypoint should seal it forever")
	_assert(not run_engine.available_moves(run_state).has(Vector2i.ZERO), "Backtracking into a sealed room should be impossible")
	var side_destination := Vector2i(999, 999)
	for coord: Vector2i in run_engine.available_moves(run_state):
		if int(run_engine.room_metadata(run_state, coord).get("depth", 0)) == 1:
			side_destination = coord
			break
	_assert(side_destination.x < 900, "Depth-1 rooms should still expose a side route around the ring")
	run_state = run_engine.move_to_room(run_state, side_destination)
	_assert(bool(run_engine.room_metadata(run_state, Vector2i(1, 0)).get("sealed", false)), "Once you leave a ring room it should stay sealed")
	_assert(not run_engine.available_moves(run_state).has(Vector2i(1, 0)), "The room you just left should never remain traversable")

func _test_run_map_never_moves_back_toward_center() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(13, ProgressionStore.default_data())
	run_state = run_engine.move_to_room(run_state, Vector2i(1, 0))
	run_state = run_engine.move_to_room(run_state, Vector2i(2, 0))
	var current_depth: int = int(run_engine.room_metadata(run_state, run_state.get("current_room", Vector2i.ZERO)).get("depth", 0))
	for coord: Vector2i in run_engine.available_moves(run_state):
		_assert(int(run_engine.room_metadata(run_state, coord).get("depth", 0)) >= current_depth, "Available exits should never move back toward easier central rooms")

func _test_run_map_last_loop_room_opens_outward() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(13, ProgressionStore.default_data())
	var current := Vector2i(2, -1)
	var outward := Vector2i(3, -1)
	var rooms: Dictionary = {}
	var current_room: Dictionary = run_engine.room_metadata(run_state, current).duplicate(true)
	current_room["revealed"] = true
	current_room["visited"] = true
	current_room["cleared"] = true
	current_room["sealed"] = false
	rooms["%d,%d" % [current.x, current.y]] = current_room
	var sealed_coords: Array[Vector2i] = []
	sealed_coords.append(Vector2i(2, -2))
	sealed_coords.append(Vector2i(2, 0))
	for sealed_coord: Vector2i in sealed_coords:
		var sealed_room: Dictionary = run_engine.room_metadata(run_state, sealed_coord).duplicate(true)
		sealed_room["revealed"] = true
		sealed_room["visited"] = true
		sealed_room["cleared"] = true
		sealed_room["sealed"] = true
		rooms["%d,%d" % [sealed_coord.x, sealed_coord.y]] = sealed_room
	run_state["current_room"] = current
	run_state["mode"] = "room"
	run_state["rooms"] = rooms
	run_state["current_room_layout"] = run_engine.call("_display_layout_for_room", int(run_state.get("seed", 0)), current_room, Vector2i.ZERO)
	_assert(run_engine.available_moves(run_state).is_empty(), "Regression fixture should strand the loop-closing room before repair")
	run_state = run_engine.repair_loaded_run_state(run_state)
	_assert(run_engine.available_moves(run_state).has(outward), "A loop-closing room with no remaining progressive exits should open an outward escape")
	var repaired_room: Dictionary = run_engine.room_metadata(run_state, current)
	var found_outward_offer: bool = false
	for connection_var: Variant in repaired_room.get("connections", []):
		if typeof(connection_var) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_var
		if connection.get("coord", Vector2i.ZERO) == outward and bool(connection.get("attrition_offer", false)):
			found_outward_offer = true
			break
	_assert(found_outward_offer, "The three-room attrition outward connection should be persisted on the current room")
	var layout: Dictionary = run_state.get("current_room_layout", {})
	var grid: Array = layout.get("grid", [])
	var door_tile: Vector2i = RoomGenerator.door_tile_for_direction(Vector2i(1, 0))
	_assert(not grid.is_empty() and str((grid[door_tile.y] as Array)[door_tile.x]) == "door", "The loop escape should stamp an outward door into the visible room layout")

func _test_empty_treasure_room_falls_back_to_room_mode() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var base_state: Dictionary = run_engine.create_new_run(13, ProgressionStore.default_data())
	base_state["relics"] = GameData.relic_ids().duplicate()
	var treasure_coord := Vector2i(999, 999)
	var source_coord := Vector2i(999, 999)
	for x: int in range(-3, 4):
		for y: int in range(-3, 4):
			var candidate := Vector2i(x, y)
			if candidate == Vector2i.ZERO:
				continue
			if str(run_engine.room_metadata(base_state, candidate).get("type", "")) != "treasure":
				continue
			for sx: int in range(-3, 4):
				for sy: int in range(-3, 4):
					var source := Vector2i(sx, sy)
					var source_room: Dictionary = run_engine.room_metadata(base_state, source)
					for connection_var: Variant in source_room.get("connections", []):
						var connection: Dictionary = connection_var
						if connection.get("coord", Vector2i(999, 999)) != candidate:
							continue
						if int(source_room.get("depth", 0)) > int(run_engine.room_metadata(base_state, candidate).get("depth", 0)):
							continue
						treasure_coord = candidate
						source_coord = source
						break
					if treasure_coord.x < 900:
						break
				if treasure_coord.x < 900:
					break
			if treasure_coord.x < 900:
				break
		if treasure_coord.x < 900:
			break
	_assert(treasure_coord.x < 900 and source_coord.x < 900, "A deterministic seed should expose a connected treasure room for regression coverage")
	var rooms: Dictionary = {}
	var source_room: Dictionary = run_engine.room_metadata(base_state, source_coord)
	source_room["revealed"] = true
	source_room["visited"] = true
	source_room["sealed"] = false
	rooms["%d,%d" % [source_coord.x, source_coord.y]] = source_room
	var treasure_room: Dictionary = run_engine.room_metadata(base_state, treasure_coord)
	treasure_room["revealed"] = true
	rooms["%d,%d" % [treasure_coord.x, treasure_coord.y]] = treasure_room
	base_state["rooms"] = rooms
	base_state["current_room"] = source_coord
	base_state = run_engine.move_to_room(base_state, treasure_coord)
	_assert(str(base_state.get("mode", "")) == "room", "Treasure rooms with no relic choices should fall back to normal room mode")
	_assert((base_state.get("pending_relics", []) as Array).is_empty(), "Empty treasure rooms should not leave stale relic choices behind")
	_assert(not run_engine.available_moves(base_state).is_empty(), "Entering a treasure room should still reveal at least one onward exit")

func _test_run_engine_campfire_linger_heals_and_continues() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(13, ProgressionStore.default_data())
	run_state["mode"] = "campfire"
	run_state["player_hp"] = 19
	run_state["player_max_hp"] = 24
	var healed_state: Dictionary = run_engine.leave_campfire(run_state, 10)
	_assert(str(healed_state.get("mode", "")) == "room", "Lingering at a fire should continue onward")
	_assert(int(healed_state.get("player_hp", 0)) == 24, "Lingering at a fire should heal without exceeding max HP")
	run_state["player_hp"] = 12
	healed_state = run_engine.leave_campfire(run_state, 10)
	_assert(int(healed_state.get("player_hp", 0)) == 22, "Lingering at a fire should heal the configured amount below max HP")

func _test_loaded_run_repairs_stranded_room_visibility() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = {
		"seed": 13,
		"mode": "room",
		"current_room": Vector2i(-1, 2),
		"rooms": {
			"-1,2": {
				"coord": Vector2i(-1, 2),
				"depth": 2,
				"type": "treasure",
				"element": "none",
				"connections": [
					{"coord": Vector2i(0, 2), "door_dir": Vector2i(1, 0), "kind": "lateral"},
					{"coord": Vector2i(-2, 2), "door_dir": Vector2i(-1, 0), "kind": "lateral"}
				],
				"revealed": true,
				"visited": true,
				"cleared": true,
				"sealed": false,
				"npcs": []
			},
			"-2,2": {
				"coord": Vector2i(-2, 2),
				"depth": 2,
				"type": "combat",
				"element": "air",
				"connections": [
					{"coord": Vector2i(-1, 2), "door_dir": Vector2i(1, 0), "kind": "lateral"},
					{"coord": Vector2i(-2, 1), "door_dir": Vector2i(0, -1), "kind": "lateral"},
					{"coord": Vector2i(-3, 2), "door_dir": Vector2i(-1, 0), "kind": "outward"}
				],
				"revealed": true,
				"visited": true,
				"cleared": true,
				"sealed": true,
				"npcs": []
			}
		}
	}
	_assert(run_engine.available_moves(run_state).is_empty(), "Regression fixture should reproduce the stranded-room save state")
	run_state = run_engine.repair_loaded_run_state(run_state)
	_assert(run_engine.available_moves(run_state).has(Vector2i(0, 2)), "Loading a stranded room should restore its missing revealed exit")

func _test_combat_finish_generates_reward_state() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(29, ProgressionStore.default_data())
	var combat_destination: Vector2i = Vector2i.ZERO
	for candidate: Vector2i in run_engine.available_moves(run_state):
		if str(run_engine.room_metadata(run_state, candidate).get("type", "")) == "combat":
			combat_destination = candidate
			break
	_assert(combat_destination != Vector2i.ZERO, "The opening ring should include at least one combat room")
	run_state = run_engine.move_to_room(run_state, combat_destination)
	_assert(str(run_state.get("mode", "")) == "combat", "Entering an uncleared combat room should start combat")
	_assert(run_engine.available_moves(run_state).is_empty(), "Uncleared combat rooms should not reveal or expose adjacent exits on the minimap")
	var combat_state: Dictionary = run_state.get("combat_state", {}).duplicate(true)
	for enemy_index: int in range((combat_state.get("enemies", []) as Array).size()):
		var enemy: Dictionary = (combat_state.get("enemies", []) as Array)[enemy_index]
		enemy["hp"] = 0
		(combat_state.get("enemies", []) as Array)[enemy_index] = enemy
	combat_state["room_embers"] = 12
	run_state = run_engine.finish_combat(run_state, combat_state)
	_assert(str(run_state.get("mode", "")) == "reward", "Winning a non-boss combat should transition to the reward state")
	_assert(run_engine.held_embers(run_state) >= 12, "Combat victory should award held embers to the run")
	_assert((run_state.get("pending_reward", {}) as Dictionary).get("cards", []).size() == 3, "Combat rewards should offer three card choices")
	_assert(not run_engine.available_moves(run_state).is_empty(), "Cleared combat rooms should reveal adjacent exits once the fight ends")

func _test_intermediate_boss_opens_next_sequence() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(29, ProgressionStore.default_data())
	var boss_coord := Vector2i(4, 0)
	run_state["current_room"] = boss_coord
	var rooms: Dictionary = run_state.get("rooms", {}).duplicate(true)
	var boss_room: Dictionary = run_engine.room_metadata(run_state, boss_coord)
	boss_room["revealed"] = true
	boss_room["visited"] = true
	boss_room["cleared"] = false
	rooms["4,0"] = boss_room
	run_state["rooms"] = rooms
	run_state["player_hp"] = 9
	run_state["player_max_hp"] = 36
	var combat_state: Dictionary = _defeated_zekarion_combat_state(4, boss_coord)
	run_state = run_engine.finish_combat(run_state, combat_state)
	_assert(str(run_state.get("mode", "")) == "room", "Defeating a non-final sequence boss should return to room mode")
	_assert(not bool(run_state.get("victory", false)), "The first sequence boss should not end the expanded run")
	_assert(int(run_state.get("player_hp", 0)) == 18, "Defeating an intermediate boss should restore 25% of maximum health")
	var has_next_sequence_move: bool = false
	var exposes_lateral_boss_move: bool = false
	for coord: Vector2i in run_engine.available_moves(run_state):
		var depth: int = int(run_engine.room_metadata(run_state, coord).get("depth", 0))
		if depth == 5:
			has_next_sequence_move = true
		elif depth == 4:
			exposes_lateral_boss_move = true
	_assert(has_next_sequence_move, "Clearing the first boss should reveal a route into depth five")
	_assert(not exposes_lateral_boss_move, "Clearing an intermediate boss should push the route outward instead of farming sideways boss gates")

func _test_boss_victory_restores_player_health() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(29, ProgressionStore.default_data())
	var final_coord := Vector2i(RunEngine.MAX_DEPTH, 0)
	run_state["current_room"] = final_coord
	var rooms: Dictionary = run_state.get("rooms", {}).duplicate(true)
	var final_boss_room: Dictionary = run_engine.room_metadata(run_state, final_coord)
	final_boss_room["revealed"] = true
	final_boss_room["visited"] = true
	final_boss_room["cleared"] = false
	rooms[_test_room_key(final_coord)] = final_boss_room
	run_state["rooms"] = rooms
	run_state["player_hp"] = 9
	run_state["player_max_hp"] = 36
	var final_layout: Dictionary = RoomGenerator.new().generate_room(29, final_boss_room, Vector2i.RIGHT)
	var combat_state: Dictionary = CombatEngine.new().create_combat(29, final_layout, {
		"hp": 9,
		"max_hp": 36,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var enemies: Array = (combat_state.get("enemies", []) as Array).duplicate(true)
	for index: int in range(enemies.size()):
		var enemy: Dictionary = (enemies[index] as Dictionary).duplicate(true)
		if bool(GameData.enemy_def(str(enemy.get("type", ""))).get("boss_bar", false)):
			enemy["hp"] = 0
		enemies[index] = enemy
	combat_state["enemies"] = enemies
	run_state = run_engine.finish_combat(run_state, combat_state)
	_assert(str(run_state.get("mode", "")) == "victory", "Defeating Noctyrax at depth 24 should end the run in victory")
	_assert(int(run_state.get("player_hp", 0)) == 18, "Defeating Noctyrax should apply the same 25% boss-victory recovery")

func _test_progression_save_and_purchase(default_progression: Dictionary) -> void:
	var data: Dictionary = ProgressionStore.add_embers(default_progression, 180)
	_assert(ProgressionStore.save_data(data), "Progression save should succeed")
	var loaded: Dictionary = ProgressionStore.load_data()
	_assert(int(loaded.get("embers", 0)) == 180, "Saved progression embers should reload as held embers")
	_assert(int(loaded.get("level", 0)) == 1, "Progression should start at level one")
	_assert(ProgressionStore.next_level_cost(loaded) == 180, "The first level-up cost should require a meaningful run")
	_assert(ProgressionStore.can_level_up(loaded), "A funded profile should be able to purchase its next level")
	loaded = ProgressionStore.purchase_level(loaded)
	_assert(int(loaded.get("level", 0)) == 2, "Buying a level should permanently raise character level")
	_assert(int(loaded.get("embers", 0)) == 0, "Buying a level should spend held embers")
	_assert(ProgressionStore.selected_skill_ids(loaded).is_empty(), "A level-up should not force a skill choice")
	_assert(ProgressionStore.unspent_skill_points(loaded) == 1, "A level-up should bank exactly one skill point")
	_assert(not ProgressionStore.can_learn_skill(loaded, "borrowed_time"), "Learning should reject skills with unmet prerequisites")
	_assert(ProgressionStore.can_learn_skill(loaded, "quick_wits"), "A legal root should be learnable with the banked point")
	loaded = ProgressionStore.learn_skill(loaded, "quick_wits")
	_assert(ProgressionStore.selected_skill_ids(loaded) == ["quick_wits"] and ProgressionStore.unspent_skill_points(loaded) == 0, "Learning should immediately spend one point and retain the chosen skill")
	_assert(not loaded.has("stats") and not loaded.has("unspent_stat_points"), "The live progression profile should not retain retired stat allocation fields")
	var unchanged_card: Dictionary = GameData.card_def_for_progression("quick_stab", loaded)
	var unchanged_action: Dictionary = (unchanged_card.get("actions", []) as Array)[0]
	_assert(int(unchanged_action.get("damage", 0)) == 11, "Learning a skill should not disguise a permanent raw damage increase")
	loaded = ProgressionStore.set_embers(loaded, 42)
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(9, _simple_room_layout(), {
		"hp": 120,
		"max_hp": 200,
		"deck_cards": ["quick_stab"],
		"skill_ids": ProgressionStore.selected_skill_ids(loaded),
		"level": loaded.get("level", 1),
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	_assert(int(((combat.card_def("quick_stab", combat_state).get("actions", []) as Array)[0] as Dictionary).get("damage", 0)) == 11, "Combat should keep card damage unchanged when it receives a skill snapshot")
	var run_engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(9, loaded)
	_assert(run_engine.held_embers(run_state) == 42, "New runs should carry the current held ember count")
	_assert(ProgressionStore.has_skill(run_state.get("progression", {}), "quick_wits"), "New runs should carry learned skills")

func _test_emaciated_man_does_not_unlock_card_upgrade_dialogue() -> void:
	var dialogue_engine: DialogueEngine = DialogueEngine.new()
	var room: Dictionary = {
		"coord": Vector2i.ZERO,
		"npcs": [{"id": "emaciated_man"}]
	}
	var progression: Dictionary = ProgressionStore.mark_rested_at_fire(ProgressionStore.default_data())
	var dialogue: Dictionary = dialogue_engine.build_room_dialogue(room, {}, progression)
	var lines: Array = dialogue.get("lines", [])
	_assert(lines.size() == 3, "Resting at a fire should no longer unlock a card-upgrade dialogue branch")
	_assert(not bool(dialogue.get("marks_fire_rest_seen", false)), "Fire rests should not create a one-time card-upgrade dialogue marker")
	var options: Array = (lines[lines.size() - 1] as Dictionary).get("options", [])
	_assert(options.is_empty(), "The Emaciated Man should no longer offer permanent card upgrade options")
	progression = ProgressionStore.mark_fire_rest_dialogue_seen(progression)
	dialogue = dialogue_engine.build_room_dialogue(room, {}, progression)
	lines = dialogue.get("lines", [])
	_assert(lines.size() == 3, "Legacy fire-rest markers should still return to the default Emaciated Man dialogue")
	_assert(str((lines[0] as Dictionary).get("text", "")) == "Hehehe. You're back...so soon.", "Runs should still use the default start-room dialogue text")
	options = (lines[lines.size() - 1] as Dictionary).get("options", [])
	_assert(options.is_empty(), "Legacy unlocked progression should not keep the old touch option alive")
	var first_run_progression: Dictionary = ProgressionStore.prepare_for_new_run(ProgressionStore.default_data())
	var first_run_index: int = int(first_run_progression.get("run_counter", 0))
	first_run_progression = ProgressionStore.record_first_umbra_reach(first_run_progression, first_run_index)
	_assert(not ProgressionStore.umbra_warning_is_due(first_run_progression, first_run_index), "Reaching the Umbra should not show the warning during the discovery run")
	_assert(int(first_run_progression.get(ProgressionStore.UMBRA_WARNING_AVAILABLE_RUN_KEY, 0)) == first_run_index + 1, "The first Umbra reach should queue its warning for the following run")
	var repeated_reach: Dictionary = ProgressionStore.record_first_umbra_reach(first_run_progression, first_run_index + 4)
	_assert(int(repeated_reach.get(ProgressionStore.UMBRA_WARNING_AVAILABLE_RUN_KEY, 0)) == first_run_index + 1, "Later shadowed rooms should not postpone the already queued warning")
	var next_run_progression: Dictionary = ProgressionStore.prepare_for_new_run(first_run_progression)
	var next_run_index: int = int(next_run_progression.get("run_counter", 0))
	_assert(ProgressionStore.umbra_warning_is_due(next_run_progression, next_run_index), "The Umbra warning should become due on the next run")
	var warning_dialogue: Dictionary = dialogue_engine.build_room_dialogue(room, {"run_index": next_run_index}, next_run_progression)
	var warning_lines: Array = warning_dialogue.get("lines", [])
	_assert(bool(warning_dialogue.get("marks_umbra_warning_seen", false)), "The one-time Umbra warning should mark itself consumed after dialogue closes")
	_assert(warning_lines.size() == 3, "The Emaciated Man's Umbra warning should contain the requested three lines")
	_assert(str((warning_lines[0] as Dictionary).get("text", "")) == "You reached his shadow. It will only get stronger the further you stray from this place.", "The Umbra warning should preserve its opening line")
	_assert(str((warning_lines[0] as Dictionary).get("bbcode", "")).contains("[i]his[/i] shadow"), "The Umbra warning should italicize his in the first line")
	_assert(str((warning_lines[1] as Dictionary).get("bbcode", "")).contains("[i]his[/i] power"), "The Umbra warning should italicize his in the second line")
	_assert(str((warning_lines[2] as Dictionary).get("text", "")) == "After all this time, I can but provide this small measure of safety. The rest is up to you...", "The Umbra warning should preserve its closing line")
	var seen_progression: Dictionary = ProgressionStore.mark_umbra_warning_seen(next_run_progression)
	_assert(not ProgressionStore.umbra_warning_is_due(seen_progression, next_run_index + 1), "The Umbra warning should never repeat after it has been seen")
	var post_warning_dialogue: Dictionary = dialogue_engine.build_room_dialogue(room, {"run_index": next_run_index + 1}, seen_progression)
	_assert(str(((post_warning_dialogue.get("lines", []) as Array)[0] as Dictionary).get("text", "")) == "Hehehe. You're back...so soon.", "Later runs should return to the Emaciated Man's default dialogue")
	for merchant_id: String in ["blacksmith", "arcanist", "scavenger"]:
		var merchant_dialogue: Dictionary = dialogue_engine.build_room_dialogue({
			"coord": Vector2i(2, 1),
			"npcs": [{"id": merchant_id}]
		}, {}, ProgressionStore.default_data())
		var merchant_lines: Array = merchant_dialogue.get("lines", [])
		_assert(not merchant_lines.is_empty(), "%s should expose default room dialogue" % merchant_id.capitalize())
		_assert(str(merchant_dialogue.get("npc_id", "")) == merchant_id, "%s dialogue should preserve the NPC id for future context branches" % merchant_id.capitalize())

func _test_recovery_marker_flow() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var progression: Dictionary = ProgressionStore.prepare_for_new_run(ProgressionStore.default_data())
	var planning_state: Dictionary = run_engine.create_new_run(51, ProgressionStore.default_data())
	var recovery_coord := Vector2i.ZERO
	for x: int in range(-2, 3):
		for y: int in range(-2, 3):
			var candidate := Vector2i(x, y)
			if candidate == Vector2i.ZERO:
				continue
			if int(run_engine.room_metadata(planning_state, candidate).get("depth", 0)) != 2:
				continue
			if _find_route_to_coord(run_engine, planning_state, candidate).is_empty():
				continue
			recovery_coord = candidate
			break
		if recovery_coord != Vector2i.ZERO:
			break
	_assert(recovery_coord != Vector2i.ZERO, "The map should expose at least one reachable depth-2 room for recovery coverage")
	progression = ProgressionStore.record_lost_embers(progression, 23, recovery_coord, int(progression.get("run_counter", 0)))
	progression = ProgressionStore.prepare_for_new_run(progression)
	var run_state: Dictionary = run_engine.create_new_run(51, progression)
	_assert(int(run_state.get("run_index", 0)) == 2, "Run index should advance when a new run begins")
	var recovery_key: String = "%d,%d" % [recovery_coord.x, recovery_coord.y]
	var staged_room: Dictionary = (run_state.get("rooms", {}) as Dictionary).get(recovery_key, {})
	_assert(bool(staged_room.get("recovery_marker", false)), "The next run should stage the dropped ember room on the map")
	_assert(int(staged_room.get("recovery_amount", 0)) == 23, "The staged dropped ember room should remember the recoverable amount")
	_assert(str(staged_room.get("type", "")) == "combat", "Dropped ember rooms should become combat rooms when they are not boss gates")
	var route: Array = _find_route_to_coord(run_engine, run_state, recovery_coord)
	_assert(not route.is_empty(), "Recovery markers should still be reachable on the next run")
	for route_index: int in range(route.size()):
		var step: Vector2i = route[route_index]
		if route_index == route.size() - 1:
			run_state = run_engine.move_to_room(run_state, step)
		else:
			run_state = _route_state_after_step(run_engine, run_state, step)
	_assert(str(run_state.get("mode", "")) == "combat", "Reaching dropped embers should start the recovery combat")
	_assert(run_engine.held_embers(run_state) == 0, "Entering the recovery room should not auto-restore dropped embers")
	var combat_state: Dictionary = run_state.get("combat_state", {})
	var dropped_loot: Dictionary = _first_loot_of_kind(combat_state, "dropped_embers")
	_assert(not dropped_loot.is_empty(), "Recovery combat should place a dropped ember pile")
	_assert(int(dropped_loot.get("amount", 0)) == 23, "The dropped ember pile should carry the lost amount")
	var combat_engine: CombatEngine = CombatEngine.new()
	combat_state = combat_engine.apply_player_action(combat_state, {"type": "blink", "range": 99}, dropped_loot.get("pos", Vector2i.ZERO))
	run_state = run_engine.set_combat_state(run_state, combat_state)
	_assert(run_engine.held_embers(run_state) == 23, "Reaching the recovery room on the next run should restore lost embers")
	_assert(str(run_state.get("notice", "")).contains("Recovered"), "Recovery should leave a short room notice")
	_assert(ProgressionStore.recovery_marker(run_state.get("progression", {})).is_empty(), "Recovering lost embers should clear the marker")
	_assert(not bool(run_engine.room_metadata(run_state, recovery_coord).get("recovery_marker", false)), "The map marker should clear after pickup")

func _test_recovery_marker_expires_after_next_run() -> void:
	var progression: Dictionary = ProgressionStore.prepare_for_new_run(ProgressionStore.default_data())
	progression = ProgressionStore.record_lost_embers(progression, 14, Vector2i(1, 1), int(progression.get("run_counter", 0)))
	progression = ProgressionStore.prepare_for_new_run(progression)
	_assert(not ProgressionStore.recovery_marker(progression).is_empty(), "The recovery marker should stay active for the immediate next run")
	progression = ProgressionStore.prepare_for_new_run(progression)
	_assert(ProgressionStore.recovery_marker(progression).is_empty(), "Recovery markers should expire after that next run passes")

func _test_run_state_save_and_load() -> void:
	var run_engine: RunEngine = RunEngine.new()
	var progression: Dictionary = ProgressionStore.prepare_for_new_run(ProgressionStore.default_data())
	var run_state: Dictionary = run_engine.create_new_run(41, progression)
	_assert(int(run_state.get("hand_size", 0)) == 5, "New runs should start with a five-card hand")
	_assert(ProgressionStore.save_run_state(run_state), "Run save should succeed")
	var loaded: Dictionary = ProgressionStore.load_saved_run()
	_assert(loaded.get("current_room", Vector2i(99, 99)) == Vector2i.ZERO, "Saved runs should preserve the current room")
	_assert(int(loaded.get("hand_size", 0)) == 5, "Saved runs should preserve the base hand size")
	ProgressionStore.clear_saved_run()
	_assert(not ProgressionStore.has_saved_run(), "Clearing the saved run should remove the save slot")

func _test_default_theme_uses_readable_text_font() -> void:
	var theme: Theme = load("res://themes/default_theme.tres")
	_assert(theme != null, "The project should ship a default UI theme")
	if theme == null:
		return
	var probe := Control.new()
	probe.theme = theme
	root.add_child(probe)
	var font: Font = probe.get_theme_default_font()
	_assert(font != null, "The default theme should expose a default font")
	if font != null:
		_assert(font.resource_path.ends_with("LabyrinthCrumble-Text.tres"), "The default theme should use the readable Labyrinth Crumble text cut")
	_assert(theme.default_font_size >= UiTypography.SIZE_BODY, "The default theme should preserve the shared readable body-text floor")
	probe.queue_free()

func _test_ui_typography_system() -> void:
	_assert(UiTypography.SIZE_CAPTION >= 14, "Utility UI captions should stay at or above the shared readability floor")
	_assert(UiTypography.SIZE_BODY >= 16, "Utility UI body text should stay at or above the shared readability floor")
	_assert(UiTypography.SIZE_TITLE > UiTypography.SIZE_SECTION and UiTypography.SIZE_SECTION > UiTypography.SIZE_BODY, "Shared typography roles should preserve title, section, and body hierarchy")
	_assert(UiTypography.SPACE_TIGHT < UiTypography.SPACE_SMALL and UiTypography.SPACE_SMALL < UiTypography.SPACE_LARGE, "Shared spacing tokens should form a coherent progression")
	var display_font: Font = UiTypography.display_font()
	var ui_font: Font = UiTypography.ui_font()
	var text_font: Font = UiTypography.text_font()
	_assert(display_font != null and display_font.resource_path.ends_with("LabyrinthCrumble-Display.tres"), "Hero roles should use the expressive Labyrinth Crumble display cut")
	_assert(ui_font != null and ui_font.resource_path.ends_with("LabyrinthCrumble-UI.tres"), "Headings and controls should use the restrained Labyrinth Crumble UI cut")
	_assert(text_font != null and text_font.resource_path.ends_with("LabyrinthCrumble-Text.tres"), "Body roles should use the clean Labyrinth Crumble text cut")

func _test_main_scenes_instantiate() -> void:
	var main_menu_scene: PackedScene = load("res://scenes/main_menu.tscn")
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	_assert(main_menu_scene != null, "Main menu scene should load")
	_assert(run_scene != null, "Run scene should load")
	if main_menu_scene == null or run_scene == null:
		return
	var main_menu_instance: Node = main_menu_scene.instantiate()
	root.add_child(main_menu_instance)
	await process_frame
	main_menu_instance.queue_free()
	await process_frame
	var run_scene_instance: Node = run_scene.instantiate()
	root.add_child(run_scene_instance)
	await process_frame
	run_scene_instance.queue_free()
	await process_frame

func _test_run_scene_combat_log_prominence() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for combat-log prominence coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	instance.call("_close_dialogue")
	var log_overlay: PanelContainer = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/StageRoot/LogOverlay") as PanelContainer
	var log_label: RichTextLabel = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/StageRoot/LogOverlay/LogMargin/Log") as RichTextLabel
	var action_banner: Label = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/StageRoot/ActionBanner") as Label
	action_banner.text = "Existing action"
	action_banner.visible = false
	instance.call("_show_combat_log_message", RunEngine.MISSED_EQUIPMENT_NOTICE)
	await process_frame
	var log_style: StyleBoxFlat = log_overlay.get_theme_stylebox("panel") as StyleBoxFlat
	_assert(log_overlay.size.x >= 390.0 and log_overlay.size.y >= 100.0, "Combat log should have a prominent readable footprint")
	_assert(log_style != null and log_style.bg_color.a <= 0.01, "Combat log layout style should remain transparent beneath its authored frame")
	_assert(
		str(log_overlay.get_meta("surface_variant", "")) == UiSkin.SURFACE_HUD
		and log_overlay.get_node_or_null(UiSkin.PANEL_ORNAMENT_NAME) != null,
		"Combat log should use the shared authored HUD frame"
	)
	_assert(log_label.get_theme_font_size("normal_font_size") >= UiTypography.SIZE_BODY_LARGE, "Combat log should use body-large text")
	_assert(log_label.get_theme_constant("outline_size") >= 2, "Combat log text should retain a strong outline against the board")
	_assert(log_overlay.visible and log_label.text == RunEngine.MISSED_EQUIPMENT_NOTICE, "Combat-log messages should be visible and exact")
	_assert(not action_banner.visible and action_banner.text == "Existing action", "Missed-equipment notice should not use or mutate the action banner")
	instance.queue_free()
	await process_frame

func _test_run_scene_minimap_click_opens_large_map() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for minimap click coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var mini_map_overlay: Control = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/StageRoot/MiniMapOverlay") as Control
	var mini_map: Control = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/StageRoot/MiniMapOverlay/MiniMapMargin/MiniMap") as Control
	_assert(mini_map_overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "Minimap overlay should receive clicks")
	_assert(mini_map.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Embedded minimap should not consume clicks before the overlay can open the large map")
	_assert(mini_map_overlay.get_node_or_null(UiSkin.PANEL_ORNAMENT_NAME) != null, "Minimap should use the authored HUD frame")
	instance.call("_close_dialogue")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	instance.call("_on_mini_map_overlay_gui_input", click)
	await process_frame
	var large_map_scrim: ColorRect = instance.get("_large_map_scrim") as ColorRect
	_assert(large_map_scrim != null and large_map_scrim.visible, "Clicking the minimap should open the large map overlay")
	if large_map_scrim != null:
		_assert(large_map_scrim.color.a >= 0.99, "Large map backdrop should hide underlying room header text")
	var large_map_view: Control = instance.get("_large_map_view") as Control
	_assert(large_map_view != null and bool(large_map_view.get("draw_background")), "Large map view should render its subdued authored labyrinth backdrop")
	var large_map_dialog: PanelContainer = instance.get("_large_map_dialog") as PanelContainer
	var close_button: Button = null
	if large_map_dialog != null:
		_assert(
			large_map_dialog.get_node_or_null(UiSkin.PANEL_ORNAMENT_NAME) != null,
			"Large map should use the authored outer raster frame"
		)
		var large_map_style: StyleBoxFlat = large_map_dialog.get_theme_stylebox("panel") as StyleBoxFlat
		_assert(
			large_map_style != null
			and large_map_style.border_width_left == 0
			and large_map_style.border_width_top == 0
			and large_map_style.border_width_right == 0
			and large_map_style.border_width_bottom == 0,
			"Large map should not retain a legacy outline outside its raster frame"
		)
		var navigation_hint: Label = large_map_dialog.find_child("MapNavigationHint", true, false) as Label
		_assert(large_map_dialog.find_child("DepthStrip", true, false) == null, "Large map should not cover the map with a redundant current-depth strip")
		_assert(navigation_hint != null and navigation_hint.text.contains("TWO-FINGER") and navigation_hint.text.contains("PINCH"), "Large map should make its mouse and trackpad navigation discoverable")
		var title: Label = large_map_dialog.find_child("MapTitle", true, false) as Label
		_assert(title != null and title.text == "MAP", "Large map should use the direct player-facing title")
		_assert(large_map_dialog.find_child("MapSubtitle", true, false) == null, "Large map should not add an ornamental fantasy tagline")
		close_button = large_map_dialog.find_child("CloseButton", true, false) as Button
	_assert(close_button != null, "Large map should expose a close button")
	if close_button != null:
		_assert(absf(close_button.custom_minimum_size.x - close_button.custom_minimum_size.y) <= 1.0, "Large map close button should be boxy instead of a wide native button")
	instance.queue_free()
	await process_frame

func _test_run_scene_pre_battle_preview_intercepts_combat_entry() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for pre-battle preview coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	instance.call("_close_dialogue")
	var prepared_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	var equipment_inventory: Array = (prepared_state.get("equipment_inventory", []) as Array).duplicate()
	if not equipment_inventory.has("iron_cleaver"):
		equipment_inventory.append("iron_cleaver")
	prepared_state["equipment_inventory"] = equipment_inventory
	var magic_inventory: Array = (prepared_state.get("magic_inventory", []) as Array).duplicate()
	if not magic_inventory.has("bone_dart"):
		magic_inventory.append("bone_dart")
	prepared_state["magic_inventory"] = magic_inventory
	instance.call("_load_run_state", prepared_state)
	await process_frame
	instance.call("_close_dialogue")

	var run_engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = instance.get("_run_state")
	var combat_coord: Vector2i = Vector2i(999, 999)
	for coord_var: Variant in run_engine.available_moves(run_state):
		if typeof(coord_var) != TYPE_VECTOR2I:
			continue
		var coord: Vector2i = coord_var
		var preview_state: Dictionary = run_engine.move_to_room(run_state.duplicate(true), coord)
		if str(preview_state.get("mode", "")) == "combat" and not (preview_state.get("combat_state", {}) as Dictionary).is_empty():
			combat_coord = coord
			break
	if combat_coord == Vector2i(999, 999):
		_failures.append("Run scene pre-battle preview test needs an available combat room")
		instance.queue_free()
		await process_frame
		return

	await instance.call("_on_map_view_room_selected", combat_coord)
	await process_frame
	var preview_scrim: ColorRect = instance.get("_pre_battle_scrim") as ColorRect
	var preview_panel: PanelContainer = instance.get("_pre_battle_panel") as PanelContainer
	var paused_state: Dictionary = instance.get("_run_state")
	_assert(preview_scrim != null and preview_scrim.visible, "Entering an uncleared combat room should show the committed pre-battle preview")
	_assert(str(paused_state.get("mode", "")) == RunEngine.MODE_PRE_BATTLE, "Pre-battle preview should use a committed pre-battle run mode until Start")
	_assert(paused_state.get("current_room", Vector2i.ZERO) == combat_coord, "Pre-battle preview should move into the selected combat room before showing details")
	_assert((paused_state.get("combat_state", {}) as Dictionary).is_empty(), "Pre-battle preview should not create the real combat state before Start")
	_assert(preview_panel != null and preview_panel.find_child("PreBattleEnemyCard", true, false) != null, "Pre-battle preview should show enemy visual cards")
	_assert(preview_panel != null and preview_panel.find_child("PreBattleDeckBadge", true, false) != null, "Pre-battle preview should show the current deck as visual badges")
	_assert(preview_panel != null and preview_panel.find_child("PreBattleEquipmentRow", true, false) != null, "Pre-battle preview should show the current loadout icons")
	_assert(preview_panel != null and preview_panel.find_child("PreBattleEnemyHealth", true, false) != null, "Pre-battle preview should show enemy health")
	if preview_panel != null:
		var preview_viewport: Vector2 = instance.get_viewport_rect().size
		_assert(preview_panel.custom_minimum_size.x <= preview_viewport.x - UiTypography.SPACE_XXL and preview_panel.custom_minimum_size.y <= preview_viewport.y - UiTypography.SPACE_XXL, "Pre-battle preview should preserve safe viewport margins")
	var threat_summary: Label = preview_panel.find_child("PreBattleThreatSummary", true, false) as Label if preview_panel != null else null
	_assert(threat_summary != null and not threat_summary.text.is_empty(), "Pre-battle enemy cards should summarize already-known tactical threats")
	var attuned_row: HFlowContainer = preview_panel.find_child("PreBattleAttunedRow", true, false) as HFlowContainer if preview_panel != null else null
	var displayed_attuned_cards: Array = _pre_battle_card_ids(preview_panel, "attuned")
	_assert(attuned_row != null and displayed_attuned_cards.size() == (paused_state.get("attuned_magic_cards", []) as Array).size(), "Pre-battle preview should represent every attuned magic card, including counted duplicates")
	_assert(preview_panel != null and preview_panel.find_child("PreBattleIntentRow", true, false) == null, "Pre-battle preview should not reveal enemy opening intents")
	_assert(preview_panel != null and preview_panel.find_child("PreBattleCloseButton", true, false) == null, "Pre-battle preview should not offer a back-out button after room entry")
	var deck_scroll: ScrollContainer = preview_panel.find_child("PreBattleDeckScroll", true, false) as ScrollContainer if preview_panel != null else null
	var displayed_deck_entries: int = 0
	if deck_scroll != null:
		var scroll_rect: Rect2 = deck_scroll.get_global_rect().grow(1.0)
		var deck_flow: HFlowContainer = deck_scroll.find_child("PreBattleDeckFlow", true, false) as HFlowContainer
		var deck_badges: Array = deck_flow.get_children() if deck_flow != null else []
		for badge_var: Variant in deck_badges:
			var visible_badge: Control = badge_var as Control
			if visible_badge == null:
				continue
			displayed_deck_entries += maxi(1, int(visible_badge.get_meta("card_count", 1)))
			_assert(scroll_rect.encloses(visible_badge.get_global_rect()), "Standard pre-battle deck tiles should all be immediately visible without scrolling")
		var deck_bar: VScrollBar = deck_scroll.get_v_scroll_bar()
		_assert(not deck_bar.visible and deck_bar.max_value <= deck_bar.page + 1.0, "Standard pre-battle Active Deck should not need or expose vertical scrolling")
	_assert(displayed_deck_entries == (paused_state.get("deck_cards", []) as Array).size(), "Counted pre-battle deck tiles should represent every card Start will use")
	var deck_badge: Control = null
	if preview_panel != null:
		deck_badge = preview_panel.find_child("PreBattleDeckBadge", true, false) as Control
	var deck_badge_name: Label = null
	if deck_badge != null:
		deck_badge_name = deck_badge.find_child("CardBadgeName", true, false) as Label
	_assert(deck_badge != null and deck_badge.custom_minimum_size.x > deck_badge.custom_minimum_size.y * 3.0, "Pre-battle deck badges should retain a wide, readable tile shape when compacted")
	_assert(deck_badge_name != null and not deck_badge_name.text.is_empty(), "Pre-battle deck badges should show the card name over the card art")
	var exit_destinations: Dictionary = instance.get("_exit_destinations_by_tile")
	_assert(exit_destinations.is_empty(), "Committed pre-battle preview should not expose alternate exits")
	var inspection_sources: Array[Control] = []
	if preview_panel != null:
		for node_name: String in ["PreBattleEnemyCard", "PreBattleEquipmentChip", "PreBattleAttunedBadge", "PreBattleDeckBadge"]:
			var source: Control = preview_panel.find_child(node_name, true, false) as Control
			if source != null:
				inspection_sources.append(source)
	_assert(inspection_sources.size() == 4, "Pre-battle enemy, equipment, attuned magic, and active deck entries should all be inspectable")
	var inspection_kinds: Array[String] = ["enemy", "equipment", "card", "card"]
	for index: int in range(inspection_sources.size()):
		var hover_inspection_var: Variant = inspection_sources[index].call("_make_custom_tooltip", inspection_sources[index].tooltip_text)
		_assert(hover_inspection_var is Control, "Hovering a pre-battle summary entry should build a readable rich inspection")
		if hover_inspection_var is Control:
			var hover_inspection: Control = hover_inspection_var as Control
			_assert(hover_inspection.get_combined_minimum_size().x >= 180.0, "Pre-battle hover inspection should be materially larger than its summary chip")
			hover_inspection.free()
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		inspection_sources[index].call("_gui_input", click)
		await process_frame
		var pinned_inspection: Control = instance.find_child("PinnedPreBattleInspection", true, false) as Control
		_assert(pinned_inspection != null and pinned_inspection.visible, "Clicking a pre-battle summary entry should pin a readable inspection")
		if pinned_inspection != null and index < inspection_kinds.size():
			_assert(str(pinned_inspection.get_meta("inspection_kind", "")) == inspection_kinds[index], "Pinned pre-battle inspection should preserve its content kind")
		for blocked_source: Control in inspection_sources:
			var blocked_hover: Variant = blocked_source.call("_make_custom_tooltip", blocked_source.tooltip_text)
			_assert(blocked_hover is Control and not (blocked_hover as Control).visible, "Pinned pre-battle inspection should disable every underlying enemy, equipment, and card hover panel")
			if blocked_hover is Control:
				(blocked_hover as Control).free()
			var blocked_click := InputEventMouseButton.new()
			blocked_click.button_index = MOUSE_BUTTON_LEFT
			blocked_click.pressed = true
			blocked_source.call("_gui_input", blocked_click)
			_assert(instance.get("_pinned_tooltip_panel") == pinned_inspection, "Pinned pre-battle inspection should reject every underlying enemy, equipment, and card click target")
		_assert(str((instance.get("_run_state") as Dictionary).get("mode", "")) == RunEngine.MODE_PRE_BATTLE, "Inspecting pre-battle details should keep the room committed")
		_assert((instance.get("_exit_destinations_by_tile") as Dictionary).is_empty(), "Inspecting pre-battle details should not reveal exits")
		if index == 0 and pinned_inspection != null:
			var inspection_close: Button = pinned_inspection.find_child("PreBattleInspectionCloseButton", true, false) as Button
			_assert(inspection_close != null and inspection_close.visible, "Focused enemy inspection should provide a dedicated visible X close button")
			var pinned_host: Control = instance.get("_pinned_tooltip_host") as Control
			_assert(pinned_host != null and pinned_host.mouse_filter == Control.MOUSE_FILTER_PASS, "Pinned tooltip host should propagate background pointer input to the stopping scrim")
			var pinned_scrim: Control = instance.get("_pinned_tooltip_scrim") as Control
			_assert(pinned_scrim != null and pinned_scrim.mouse_filter == Control.MOUSE_FILTER_STOP, "Focused pre-battle inspection scrim should own pointer input above every underlying click target")
			if inspection_close != null:
				var close_rect: Rect2 = inspection_close.get_global_rect()
				var inverse_transform_position: Vector2 = instance.get_viewport().get_final_transform().affine_inverse() * close_rect.get_center()
				if not close_rect.has_point(inverse_transform_position):
					var false_close_press := InputEventMouseButton.new()
					false_close_press.button_index = MOUSE_BUTTON_LEFT
					false_close_press.pressed = true
					false_close_press.position = inverse_transform_position
					false_close_press.global_position = inverse_transform_position
					instance.call("_input", false_close_press)
					await process_frame
					_assert((instance.get("_pinned_tooltip_scrim") as Control).visible, "A native click in the inverse-transformed false hit region should remain suppressed")
				var native_close_press := InputEventMouseButton.new()
				native_close_press.button_index = MOUSE_BUTTON_LEFT
				native_close_press.pressed = true
				native_close_press.position = inspection_close.get_global_rect().get_center()
				native_close_press.global_position = native_close_press.position
				instance.call("_input", native_close_press)
				await process_frame
				_assert(not (instance.get("_pinned_tooltip_scrim") as Control).visible, "The focused enemy X button should close for native canvas-space pointer coordinates")
				inspection_sources[index].call("_gui_input", click)
				await process_frame
				pinned_inspection = instance.find_child("PinnedPreBattleInspection", true, false) as Control
				inspection_close = pinned_inspection.find_child("PreBattleInspectionCloseButton", true, false) as Button if pinned_inspection != null else null
				_assert(inspection_close != null and (instance.get("_pinned_tooltip_scrim") as Control).visible, "The enemy inspection should reopen for local viewport pointer-path coverage")
			if inspection_close != null:
				var close_press := InputEventMouseButton.new()
				close_press.button_index = MOUSE_BUTTON_LEFT
				close_press.pressed = true
				close_press.position = inspection_close.get_global_rect().get_center()
				close_press.global_position = close_press.position
				instance.get_viewport().push_input(close_press, true)
				await process_frame
				var close_release := InputEventMouseButton.new()
				close_release.button_index = MOUSE_BUTTON_LEFT
				close_release.pressed = false
				close_release.position = close_press.position
				close_release.global_position = close_press.position
				instance.get_viewport().push_input(close_release, true)
				await process_frame
				_assert(not (instance.get("_pinned_tooltip_scrim") as Control).visible, "The focused enemy X button should close through local viewport pointer routing")
			else:
				instance.call("_close_pinned_tooltip")
		else:
			instance.call("_close_pinned_tooltip")
		await process_frame

	instance.call("_on_pre_battle_equip_pressed")
	await process_frame
	var character_scrim: ColorRect = instance.get("_upgrade_scrim") as ColorRect
	_assert(character_scrim != null and character_scrim.visible, "Pre-battle Equip should open the character loadout overlay")
	_assert(bool(instance.call("_equipment_overlay_can_change")), "Pre-battle loadout should allow equipment changes after room commitment")
	_assert(preview_scrim != null and preview_scrim.visible, "Opening loadout from pre-battle should leave the preview waiting behind it")
	_assert(preview_scrim != null and preview_scrim.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Pre-battle preview should stop intercepting mouse input while loadout is open")
	await instance.call("_equip_equipment_from_overlay", "iron_cleaver")
	var equipment_swapped_state: Dictionary = instance.get("_run_state")
	_assert(str((equipment_swapped_state.get("equipped_equipment", {}) as Dictionary).get("weapon", "")) == "iron_cleaver", "Pre-battle equipment swaps should update the committed run loadout")
	instance.call("_switch_character_overlay_mode", "magic")
	await process_frame
	var reserve_magic: Array = (instance.get("_run_state") as Dictionary).get("magic_inventory", []) as Array
	var bone_dart_index: int = reserve_magic.find("bone_dart")
	_assert(bone_dart_index >= 0, "Pre-battle magic swap coverage should retain the prepared reserve spell")
	if bone_dart_index >= 0:
		await instance.call("_swap_magic_from_overlay", bone_dart_index, 0)
	var magic_swapped_state: Dictionary = instance.get("_run_state")
	_assert(str((magic_swapped_state.get("attuned_magic_cards", []) as Array)[0]) == "bone_dart", "Pre-battle magic swaps should update the committed attunement")
	instance.call("_close_card_upgrade_overlay")
	await process_frame
	_assert(preview_scrim != null and preview_scrim.mouse_filter == Control.MOUSE_FILTER_STOP, "Pre-battle preview should resume intercepting mouse input after loadout closes")
	preview_panel = instance.get("_pre_battle_panel") as PanelContainer
	var refreshed_weapon: Control = _pre_battle_control_with_meta(preview_panel, "PreBattleEquipmentChip", "equipment_id", "iron_cleaver")
	var refreshed_attunement: Control = _pre_battle_control_with_meta(preview_panel, "PreBattleAttunedBadge", "card_id", "bone_dart")
	_assert(refreshed_weapon != null, "Returning from equipment changes should refresh the exact equipped weapon in the pre-battle summary")
	_assert(refreshed_attunement != null, "Returning from magic changes should refresh the exact attuned spell in the pre-battle summary")
	var expected_deck: Array = ((instance.get("_run_state") as Dictionary).get("deck_cards", []) as Array).duplicate()
	var displayed_deck: Array = _pre_battle_card_ids(preview_panel, "deck")
	expected_deck.sort()
	displayed_deck.sort()
	_assert(displayed_deck == expected_deck, "Pre-battle Active Deck should exactly match the refreshed deck Start will use (shown=%s expected=%s)" % [str(displayed_deck), str(expected_deck)])
	var refreshed_preview_state: Dictionary = instance.get("_pre_battle_preview_run_state")
	var refreshed_preview_deck: Array = _combat_deck_card_ids(refreshed_preview_state.get("combat_state", {}) as Dictionary)
	refreshed_preview_deck.sort()
	_assert(refreshed_preview_deck == expected_deck, "Pre-battle combat preview should rebuild from the refreshed loadout")

	await instance.call("_on_pre_battle_start_pressed")
	await process_frame
	var started_state: Dictionary = instance.get("_run_state")
	_assert(preview_scrim != null and not preview_scrim.visible, "Starting combat should close the pre-battle preview")
	_assert(str(started_state.get("mode", "")) == "combat", "Pre-battle Start should enter combat through the normal room move")
	_assert(started_state.get("current_room", Vector2i.ZERO) == combat_coord, "Pre-battle Start should move to the selected combat room")
	_assert(not (started_state.get("combat_state", {}) as Dictionary).is_empty(), "Pre-battle Start should create the real combat state")
	var started_deck: Array = _combat_deck_card_ids(started_state.get("combat_state", {}) as Dictionary)
	started_deck.sort()
	_assert(started_deck == expected_deck, "Pre-battle Start should use the exact equipment- and attunement-refreshed deck")
	var hand_box: Control = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll/HandCenter/HandBox")
	var ready_wave_count: int = 0
	for widget: CardWidget in _card_widgets_under(hand_box):
		if str(widget.get_meta("ready_wave_reason", "")) == "combat_start":
			ready_wave_count += 1
	_assert(ready_wave_count > 0, "Pre-battle Start should ready-wave playable opening hand cards")
	instance.queue_free()
	await process_frame

func _test_run_scene_pre_battle_five_enemy_layout_compacts() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for five-enemy pre-battle layout coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	instance.call("_close_dialogue")
	var enemies: Array = []
	for enemy_type: String in ["warden", "acolyte", "harrier", "crawler", "grave_surgeon"]:
		var enemy_def: Dictionary = GameData.enemy_def(enemy_type)
		var max_hp: int = int(enemy_def.get("max_hp", 1))
		enemies.append({
			"type": enemy_type,
			"hp": max_hp,
			"max_hp": max_hp
		})
	for enemy_count: int in [1, 2, 3, 4, 5]:
		var layout_enemies: Array = enemies.slice(0, enemy_count)
		var enemy_section: Control = instance.call("_build_pre_battle_enemy_section", {"enemies": layout_enemies}, Color("d8b06d")) as Control
		root.add_child(enemy_section)
		await process_frame
		var enemy_flow: Control = enemy_section.find_child("PreBattleEnemyFlow", true, false) as Control
		_assert(enemy_flow != null and enemy_flow.get_child_count() == enemy_count, "%d-enemy pre-battle sections should render every enemy card" % enemy_count)
		if enemy_flow != null:
			var top_row_count: int = 1 if enemy_count == 1 else (2 if enemy_count <= 4 else 3)
			var top_row_y: float = (enemy_flow.get_child(0) as Control).position.y
			for top_index: int in range(top_row_count):
				var top_card: Control = enemy_flow.get_child(top_index) as Control
				_assert(top_card != null and absf(top_card.position.y - top_row_y) <= 1.0, "%d-enemy pre-battle layouts should align the top row" % enemy_count)
			if enemy_count >= 3:
				var bottom_start: int = 2 if enemy_count <= 4 else 3
				var bottom_card: Control = enemy_flow.get_child(bottom_start) as Control
				_assert(bottom_card != null and bottom_card.position.y > top_row_y, "%d-enemy pre-battle layouts should place the lower row below the top row" % enemy_count)
				if enemy_count == 4:
					var first_top: Control = enemy_flow.get_child(0) as Control
					_assert(first_top != null and absf(bottom_card.position.x - first_top.position.x) >= 1.0, "Four-enemy pre-battle layouts should preserve the slight lower-row offset")
				if enemy_count == 5:
					var bottom_second: Control = enemy_flow.get_child(4) as Control
					_assert(bottom_second != null and absf(bottom_second.position.y - bottom_card.position.y) <= 1.0, "Five-enemy pre-battle layouts should center two foes below three")
			for index: int in range(enemy_flow.get_child_count()):
				var card: Control = enemy_flow.get_child(index) as Control
				var threat: Label = card.find_child("PreBattleThreatSummary", true, false) as Label if card != null else null
				_assert(threat != null and not threat.text.is_empty(), "%d-enemy pre-battle cards should retain readable threat summaries" % enemy_count)
				if enemy_count == 5:
					_assert(card != null and card.custom_minimum_size.x <= 200.0 and card.custom_minimum_size.y <= 190.0, "Five-enemy pre-battle cards should switch to the compact fixed size")
		enemy_section.queue_free()
		await process_frame
	var inspection: Control = instance.call("_build_pre_battle_enemy_inspection_panel", enemies[0]) as Control
	root.add_child(inspection)
	await process_frame
	var known_moves: Control = inspection.find_child("PreBattleKnownMoves", true, false) as Control
	var known_move_count: int = known_moves.get_child_count() if known_moves != null else 0
	_assert(known_move_count == (GameData.enemy_def("warden").get("intents", []) as Array).size(), "Enemy inspection should show the full known move repertoire without selecting an opener (shown=%d expected=%d)" % [known_move_count, (GameData.enemy_def("warden").get("intents", []) as Array).size()])
	_assert(inspection.find_child("PreBattleIntentRow", true, false) == null, "Enemy inspection should not expose the hidden opening-intent row")
	inspection.queue_free()
	instance.queue_free()
	await process_frame

func _test_run_scene_debug_boss_fixture_boots() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for debug boss fixture coverage")
		return
	root.set_meta("labyrinth_debug_boss_run", true)
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var run_state: Dictionary = instance.get("_run_state")
	var combat_state: Dictionary = instance.get("_combat_state")
	_assert(bool(run_state.get("debug_boss_run", false)), "Debug boss fixture should mark its run as independent")
	_assert(str(run_state.get("mode", "")) == "combat", "Debug boss fixture should boot directly into combat")
	_assert(str(combat_state.get("room_type", "")) == "boss", "Debug boss fixture should load the boss room")
	_assert(int(run_state.get("player_max_hp", 0)) >= RunEngine.BASE_MAX_HP, "Debug boss fixture should grant plausible late-run max health")
	_assert(int(run_state.get("hand_size", 0)) == 5, "Debug boss fixture should keep the normal hand UI footprint")
	_assert((run_state.get("attuned_magic_cards", []) as Array).size() == GameData.magic_loadout_limit(), "Debug boss fixture should obey the attuned magic cap")
	_assert((run_state.get("magic_inventory", []) as Array).size() > 0, "Debug boss fixture should keep extra progressed cards in reserve magic")
	_assert((run_state.get("deck_cards", []) as Array).has("cinderburst"), "Debug boss fixture should still grant progressed attuned magic")
	var found_boss: Dictionary = {}
	for enemy_var: Variant in combat_state.get("enemies", []):
		var enemy: Dictionary = enemy_var
		if str(enemy.get("type", "")) == "zekarion":
			found_boss = enemy
			break
	_assert(not found_boss.is_empty(), "Debug boss fixture should spawn Zekarion")
	var turn_order_panel: PanelContainer = instance.get("_turn_order_panel") as PanelContainer
	var boss_overlay: Control = instance.get("_boss_health_overlay") as Control
	var turn_order_bar: Control = instance.get("_turn_order_bar") as Control
	var boss_name: Label = instance.get("_boss_health_name") as Label
	var boss_hp: Label = instance.get("_boss_health_hp_label") as Label
	_assert(instance.find_child("BossDossier", true, false) == null, "Boss combat should remove the obsolete turn-clock dossier widget")
	_assert(boss_overlay != null and boss_overlay.visible, "Boss combat should show a dedicated top-center health overlay")
	if boss_overlay != null:
		_assert(boss_overlay.size.x >= 700.0 and boss_overlay.size.x <= 820.0 and boss_overlay.size.y <= 90.0, "The boss overlay should stay wide and shallow at the authored combat size")
		_assert(boss_overlay.get_node_or_null("BossHealthLinework") == null, "The boss name and HP bar should render without an enclosing background box")
	var boss_slots: Array[Control] = []
	if turn_order_bar != null:
		for child: Node in turn_order_bar.get_children():
			if child is Control and child.name != "TurnOrderOverflowBadge":
				boss_slots.append(child as Control)
	var expected_boss_slot_count: int = mini(10, CombatEngine.new().current_turn_order(combat_state, 10).size())
	_assert(boss_slots.size() == expected_boss_slot_count, "Boss combat should retain the same frameless rail with up to ten scheduled portraits")
	if expected_boss_slot_count == 10:
		_assert(turn_order_bar == null or turn_order_bar.find_child("TurnOrderOverflowBadge", false, false) == null, "A ten-slot boss rail should not add a redundant overflow badge")
	var viewport_rect := Rect2(Vector2.ZERO, instance.get_viewport().get_visible_rect().size)
	for slot: Control in boss_slots:
		_assert(viewport_rect.encloses(slot.get_global_rect()), "Every visible boss turn portrait should remain on-screen")
	if boss_overlay != null:
		var overlay_rect: Rect2 = boss_overlay.get_global_rect()
		_assert(viewport_rect.encloses(overlay_rect), "The dedicated boss overlay should remain on-screen")
		_assert(turn_order_panel == null or not overlay_rect.intersects(turn_order_panel.get_global_rect()), "The top-center boss overlay should not overlap the turn rail")
		var title_label: Label = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/TitleBox/RoomTitle") as Label
		var title_font: Font = title_label.get_theme_font("font") if title_label != null else null
		var title_width: float = title_font.get_string_size(title_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_label.get_theme_font_size("font_size")).x if title_font != null and title_label != null else 0.0
		var title_rect := Rect2(title_label.get_global_rect().position, Vector2(title_width, title_label.size.y)) if title_label != null else Rect2()
		_assert(not overlay_rect.intersects(title_rect), "The top-center boss overlay should not cover the visible room title")
		for utility: Control in [instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/StatsLabel") as Control, instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/LoadoutButton") as Control, instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/GrimoireButton") as Control, instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/MenuButton") as Control]:
			_assert(utility == null or not utility.visible or not overlay_rect.intersects(utility.get_global_rect()), "The top-center boss overlay should clear visible utility controls")
		var meter: Control = instance.get("_play_meter") as Control
		var hand: Control = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll") as Control
		_assert(meter == null or not meter.visible or not overlay_rect.intersects(meter.get_global_rect()), "The top-center boss overlay should not overlap the action dock")
		_assert(hand == null or not hand.visible or not overlay_rect.intersects(hand.get_global_rect()), "The top-center boss overlay should not overlap the hand")
	_assert(boss_name != null and boss_name.text.contains("Zekarion"), "The dedicated boss overlay should keep the full boss name readable")
	_assert(boss_hp != null and boss_hp.text == "%d/%d" % [int(found_boss.get("hp", 0)), int(found_boss.get("max_hp", 1))], "The dedicated boss overlay should show exact health")
	var preview_hp: int = maxi(0, int(found_boss.get("hp", 0)) - 50)
	instance.call("_refresh_boss_health_overlay", combat_state, {
		"effect": {
			"damage_preview": {
				"enemy_%d" % int(found_boss.get("id", -1)): {"hp": preview_hp, "hp_loss": 50}
			}
		}
	})
	var preview_band: ColorRect = instance.get("_boss_health_damage_preview") as ColorRect
	_assert(preview_band != null and preview_band.visible and preview_band.anchor_left < preview_band.anchor_right, "Boss damage previews should remain visible in the dedicated health overlay")
	var board: Control = instance.get_node("BoardUnderlay/CombatBoard") as Control
	_assert(board != null and not (board.get("presentation") as Dictionary).has("boss_health_name_min_y"), "The combat board should no longer carry boss-banner positioning state")
	instance.queue_free()
	if root.has_meta("labyrinth_debug_boss_run"):
		root.remove_meta("labyrinth_debug_boss_run")
	await process_frame

func _test_run_scene_offers_pass_during_combat() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for pass-turn coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(76, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["quick_stab"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	_set_run_scene_combat_state_for_test(instance, combat_state)
	instance.call("_refresh_ui")
	for frame_index: int in range(5):
		await process_frame
	instance.call("_refresh_turn_order_bar")
	instance.call("_layout_combat_action_dock")
	instance.call("_layout_choice_button_overlay")
	await process_frame
	var actual_turn_order_bar: Control = instance.get("_turn_order_bar") as Control
	var actual_normal_slots: Array[Control] = []
	if actual_turn_order_bar != null:
		for child: Node in actual_turn_order_bar.get_children():
			if child is Control and child.name != "TurnOrderOverflowBadge":
				actual_normal_slots.append(child as Control)
	_assert(not actual_normal_slots.is_empty(), "A visible normal combat should render at least one turn portrait")
	if not actual_normal_slots.is_empty():
		var grimoire: Control = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/GrimoireButton") as Control
		var menu: Control = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/MenuButton") as Control
		var utility_bottom: float = maxf(grimoire.get_global_rect().end.y if grimoire != null and grimoire.visible else 0.0, menu.get_global_rect().end.y if menu != null and menu.visible else 0.0)
		_assert(actual_normal_slots[0].get_global_rect().position.y >= utility_bottom + 4.0, "The normal rail's first portrait should clear the visible top utility buttons")
	var normal_rail_entries: Array[Dictionary] = []
	for index: int in range(10):
		normal_rail_entries.append({
			"kind": "player" if index % 2 == 0 else "enemy",
			"type": "player" if index % 2 == 0 else "crawler",
			"name": "Reaver" if index % 2 == 0 else "Crawler",
			"pos": Vector2i(3, 3),
			"actor_key": "player" if index % 2 == 0 else "enemy_1",
			"time": index * 3,
			"active": index == 0
	})
	instance.call("_set_turn_order_bar_entries", normal_rail_entries)
	await process_frame
	var turn_order_bar: Control = instance.get("_turn_order_bar") as Control
	var normal_slots: Array[Control] = []
	if turn_order_bar != null:
		for child: Node in turn_order_bar.get_children():
			if child is Control and child.name != "TurnOrderOverflowBadge":
				normal_slots.append(child as Control)
	_assert(normal_slots.size() == 10, "Normal combat should retain its ten-slot turn rail")
	if not normal_slots.is_empty():
		var viewport_rect := Rect2(Vector2.ZERO, instance.get_viewport().get_visible_rect().size)
		for slot: Control in normal_slots:
			_assert(viewport_rect.encloses(slot.get_global_rect()), "Every normal-rail turn portrait should remain on-screen")
	var pass_button: Button = instance.find_child("PassPreviewChip", true, false) as Button
	_assert(pass_button != null and not pass_button.disabled, "Combat UI should always offer its actionable Pass forecast when the player can end the turn manually")
	if pass_button != null:
		_assert(pass_button.focus_mode == Control.FOCUS_ALL and pass_button.get_global_rect().size == Vector2(270.0, 100.0), "Combat Pass forecast should remain one large, keyboard-focusable native control")
	var overlay: Control = instance.get("_pass_preview_overlay") as Control
	_assert(overlay != null and overlay.visible, "Combat Pass forecast should render in its stable overlay host")
	_assert_current_combat_dock_geometry(instance, "Combat Pass forecast")
	instance.queue_free()
	await process_frame

func _test_run_scene_offers_pass_when_hand_dead() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for pass-turn UI coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(77, _dead_hand_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab"],
		"relics": [],
		"hand_size": 5,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	_set_run_scene_combat_state_for_test(instance, combat_state)
	instance.call("_refresh_choice_bar")
	instance.call("_layout_combat_action_dock")
	instance.call("_layout_choice_button_overlay")
	var pass_button: Button = instance.find_child("PassPreviewChip", true, false) as Button
	_assert(pass_button != null and not pass_button.disabled, "Combat UI should offer Pass when the hand has no playable cards")
	if pass_button != null:
		_assert(pass_button.focus_mode == Control.FOCUS_ALL and pass_button.get_global_rect().size == Vector2(270.0, 100.0), "Dead-hand Pass should retain the large native forecast control")
	instance.queue_free()
	await process_frame

func _test_run_scene_pass_preview_chip_updates() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for pass-preview chip coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame

	var danger_state: Dictionary = _pass_preview_chip_state("danger")
	_install_pass_preview_chip_state(instance, danger_state)
	await process_frame
	await process_frame
	var pass_button: Button = instance.find_child("PassPreviewChip", true, false) as Button
	_assert(pass_button != null and not pass_button.disabled, "Pass preview should keep the Pass control available")
	_assert_pass_preview_chip(instance, ["-5"], false, false, "danger pass")
	_assert(instance.find_child("PassPreviewDetail", true, false) == null, "Pass preview should not render the old wordy detail line")
	var summary: Dictionary = instance.call("_pass_preview_summary")
	_assert(int(summary.get("hp_loss", 0)) == 5, "Pass preview helper should return visible health damage")
	_assert(not bool(summary.get("unrevealed_before_player", false)), "Baseline pass preview should not flag hidden actions when player returns first")
	var live_state: Dictionary = instance.get("_combat_state")
	_assert(int((live_state.get("player", {}) as Dictionary).get("hp", 0)) == 24, "Pass preview summary should not damage the live player")
	_assert(int(live_state.get("cards_played_this_turn", 0)) == 0, "Pass preview summary should not spend live card plays")

	_install_pass_preview_chip_state(instance, _pass_preview_chip_state("safe"))
	await process_frame
	await process_frame
	_assert_pass_preview_chip(instance, ["SAFE"], false, false, "safe pass")

	_install_pass_preview_chip_state(instance, _pass_preview_chip_state("layered"))
	await process_frame
	await process_frame
	_assert_pass_preview_chip(instance, ["-4", "-5"], false, false, "layered pass")

	_install_pass_preview_chip_state(instance, _pass_preview_chip_state("defiance_followup"))
	await process_frame
	await process_frame
	_assert_pass_preview_chip(instance, ["-1", "4"], false, false, "Defiance plus follow-up damage pass")
	var defiance_summary: Dictionary = instance.call("_pass_preview_summary")
	_assert(int(defiance_summary.get("defiance_spent", 0)) == 1, "Pass preview should surface the Defiance charge spent by the first lethal hit")
	_assert(int(defiance_summary.get("projected_hp", -1)) == 4 and int(defiance_summary.get("net_hp_change", 0)) == -1, "Pass preview should retain the resulting HP after a later revealed enemy damages restored health")
	instance.call("_update_action_context_risk")
	var defiance_risk_text: String = str((instance.get("_action_step_tracker") as Control).get_meta("risk_text", ""))
	_assert(defiance_risk_text.contains("DEFIANCE -1") and defiance_risk_text.contains("4 HP") and defiance_risk_text.contains("0 LEFT"), "Action-context risk should show both the spent charge and resulting HP")
	var defiance_chip: Control = instance.find_child("PassPreviewChip", true, false) as Control
	_assert(defiance_chip != null and defiance_chip.tooltip_text.contains("4/24 HP") and defiance_chip.tooltip_text.contains("net -1 HP"), "Defiance preview tooltip should explain the projected end state and net HP consequence")

	_install_pass_preview_chip_state(instance, _pass_preview_chip_state("defiance_umbra"))
	await process_frame
	await process_frame
	var mixed_umbra_summary: Dictionary = instance.call("_pass_preview_summary")
	_assert(int(mixed_umbra_summary.get("defiance_spent", 0)) == 1 and bool(mixed_umbra_summary.get("umbra_unknown_before_player", false)), "Mixed revealed/hidden preview should retain the visible Defiance spend and flag the hidden follow-up")
	_assert(int(mixed_umbra_summary.get("projected_hp", -1)) < 0, "Mixed Umbra preview should not expose a falsely precise ending HP")
	instance.call("_update_action_context_risk")
	var mixed_risk_text: String = str((instance.get("_action_step_tracker") as Control).get_meta("risk_text", ""))
	_assert(mixed_risk_text.contains("? HP") and not mixed_risk_text.contains("0 HP"), "Mixed Umbra Defiance risk should show unknown ending HP instead of a false zero")

	_install_pass_preview_chip_state(instance, _pass_preview_chip_state("lethal"))
	await process_frame
	await process_frame
	_assert_pass_preview_chip(instance, ["DEFEAT"], true, false, "lethal pass")

	_install_pass_preview_chip_state(instance, _pass_preview_chip_state("unrevealed"))
	await process_frame
	await process_frame
	_assert_pass_preview_chip(instance, ["UNKNOWN"], false, true, "unrevealed pass")
	var danger_line: Label = instance.find_child("PassPreviewForecastLine", true, false) as Label
	_assert(danger_line != null and danger_line.text.contains("TURN END") and danger_line.text.contains("UNKNOWN"), "Unrevealed follow-up preview should keep its compact uncertainty ribbon")
	var danger_chip: Control = instance.find_child("PassPreviewChip", true, false) as Control
	_assert(danger_chip != null and danger_chip.tooltip_text == "Enemies have unrevealed actions before your next turn, you may take additional damage.", "DANGER! pass preview should expose the unrevealed-action tooltip")

	_install_pass_preview_chip_state(instance, _pass_preview_chip_state("umbra"))
	await process_frame
	await process_frame
	_assert_pass_preview_chip(instance, ["UNKNOWN"], false, true, "Umbra-hidden pass")
	var umbra_summary: Dictionary = instance.call("_pass_preview_summary")
	_assert(bool(umbra_summary.get("umbra_unknown_before_player", false)), "Pass preview should flag a hidden presence acting before the player")
	_assert(int(umbra_summary.get("hp_loss", 0)) == 0, "Pass preview should not leak hidden-intent damage")
	var umbra_line: Label = instance.find_child("PassPreviewForecastLine", true, false) as Label
	_assert(umbra_line != null and umbra_line.text.contains("UNKNOWN"), "Hidden pass preview should explain uncertainty in its compact forecast ribbon")

	_install_pass_preview_chip_state(instance, danger_state)
	await process_frame
	await process_frame
	await _choose_clicked_card_action(instance, 0, "play")
	await process_frame
	await process_frame
	_assert(int(instance.get("_selected_card_index")) == 0, "Selecting Guarded Step should keep the move target pending")
	_assert_action_context_risk(instance, "-5 HP", "danger", "selected move before hover")
	var move_target: Vector2i = _pass_preview_chip_move_target(instance.get("_pending_target_tiles") as Array, Vector2i(3, 4))
	_assert(move_target.x >= 0, "Pass preview move-hover coverage should find a valid Guarded Step target")
	if move_target.x >= 0:
		instance.call("_on_board_tile_hovered", move_target)
		await process_frame
		await process_frame
		_assert_action_context_risk(instance, "DANGER", "warning", "selected move hover")
		var hover_source_state: Dictionary = instance.call("_pass_preview_source_state")
		_assert((hover_source_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO) == move_target, "Pass preview hover source should use the hovered move target")
		_assert(int(hover_source_state.get("cards_played_this_turn", 0)) == 1, "Pass preview hover source should include the selected card commit")
		_assert(int(hover_source_state.get("player_turn_time_spent", 0)) == 3, "Pass preview hover source should include selected card time before forecasting turn order")
		_assert(((hover_source_state.get("deck", {}) as Dictionary).get("hand", []) as Array).size() == 1, "Pass preview hover source should remove the hypothetically committed card")
	live_state = instance.get("_combat_state")
	_assert(int(live_state.get("cards_played_this_turn", 0)) == 0, "Selected-card pass preview should not commit the selected card")
	_assert((live_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(2, 4), "Selected-card move hover should not move the live player")
	_assert(((live_state.get("deck", {}) as Dictionary).get("hand", []) as Array).size() == 2, "Selected-card pass preview should not remove a live hand card")

	var attack_hover_state: Dictionary = _pass_preview_chip_state("danger")
	var attack_enemies: Array = attack_hover_state.get("enemies", [])
	if not attack_enemies.is_empty():
		var attack_enemy: Dictionary = (attack_enemies[0] as Dictionary).duplicate(true)
		attack_enemy["hp"] = 8
		attack_enemy["max_hp"] = 8
		attack_enemies[0] = attack_enemy
		attack_hover_state["enemies"] = attack_enemies
	_install_pass_preview_chip_state(instance, attack_hover_state)
	await process_frame
	await process_frame
	await _choose_clicked_card_action(instance, 1, "play")
	await process_frame
	await process_frame
	_assert(int(instance.get("_selected_card_index")) == 1, "Selecting Quick Stab should keep the attack target pending")
	_assert_action_context_risk(instance, "-5 HP", "danger", "selected attack before hover")
	var attack_target := Vector2i(3, 4)
	_assert((instance.get("_pending_target_tiles") as Array).has(attack_target), "Pass preview attack-hover coverage should find the adjacent enemy target")
	instance.call("_on_board_tile_hovered", attack_target)
	await process_frame
	await process_frame
	_assert_action_context_risk(instance, "SAFE", "safe", "selected attack hover")
	var attack_hover_source_state: Dictionary = instance.call("_pass_preview_source_state")
	_assert(int(attack_hover_source_state.get("cards_played_this_turn", 0)) == 1, "Attack hover source should include the selected card commit")
	_assert(int(attack_hover_source_state.get("player_turn_time_spent", 0)) == 2, "Attack hover source should include Quick Stab time before forecasting turn order")
	_assert(int(((attack_hover_source_state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) <= 0, "Attack hover source should include the confirmed attack effect")
	instance.call("_on_board_tile_hovered", Vector2i(0, 0))
	await process_frame
	await process_frame
	_assert_action_context_risk(instance, "-5 HP", "danger", "selected attack hover cleared")
	live_state = instance.get("_combat_state")
	_assert(int(live_state.get("cards_played_this_turn", 0)) == 0, "Selected attack pass preview should not commit the selected card")
	_assert(int(((live_state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0)) == 8, "Selected attack hover should not damage the live enemy")

	instance.queue_free()
	await process_frame

func _test_run_scene_action_selection_buttons_are_large() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for action-selection button coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	instance.set("_run_state", run_state)
	instance.set("_selected_card_index", 0)
	instance.set("_pending_actions", [{"type": "ranged"}])
	instance.set("_pending_action_index", 0)
	instance.set("_pending_action_can_skip", true)
	instance.call("_refresh_choice_bar")
	await process_frame
	await process_frame
	var context: Control = instance.get("_action_step_tracker") as Control
	var detail_row: Control = instance.get("_action_context_detail_row") as Control
	var status_row: Control = instance.get("_action_context_status_row") as Control
	var skip_button: Button = _button_with_text(context, "Skip")
	var cancel_button: Button = _button_with_text(context, "Cancel")
	_assert(context != null and context.visible, "Action selection should show one coherent context rail")
	_assert(detail_row != null and not detail_row.visible, "Action selection should omit the redundant action-description row")
	_assert(status_row != null and not status_row.visible, "Action selection should omit target-validity and turn-end copy")
	_assert(skip_button != null, "Action context should show Skip when the current action can be skipped")
	_assert(cancel_button != null, "Action context should show Cancel while a card action is selected")
	if skip_button != null:
		_assert_button_uses_variant(skip_button, UiSkin.BUTTON_HEIGHT_STANDARD, UiSkin.VARIANT_COMPACT, "Action-context Skip should use the compact themed variant")
	if cancel_button != null:
		_assert_button_uses_variant(cancel_button, UiSkin.BUTTON_HEIGHT_STANDARD, UiSkin.VARIANT_COMPACT, "Action-context Cancel should use the compact themed variant")
	instance.queue_free()
	await process_frame

func _test_run_scene_action_selection_keeps_hand_layout_stable() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for action-selection layout coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	instance.set("_run_state", run_state)
	instance.set("_selected_card_index", -1)
	instance.set("_pending_actions", [])
	instance.set("_pending_action_index", 0)
	instance.set("_pending_action_can_skip", false)
	instance.call("_refresh_choice_bar")
	instance.call("_refresh_visibility")
	instance.call("_layout_combat_action_dock")
	instance.call("_layout_choice_button_overlay")
	await process_frame
	var hand_scroll: ScrollContainer = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll")
	var left_action_stack: VBoxContainer = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack")
	var choice_bar: HBoxContainer = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/ChoiceBar")
	var piles_bar: HBoxContainer = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/PilesBar")
	var play_meter: Control = instance.get("_play_meter") as Control
	var pass_hand_x: float = hand_scroll.global_position.x
	var pass_action_width: float = left_action_stack.size.x
	var single_action_width: float = UiSkin.new().button_native_size(UiSkin.BUTTON_HEIGHT_ACTION, 0.0, UiSkin.VARIANT_LARGE).x
	var expected_action_width: float = maxf(piles_bar.get_combined_minimum_size().x, single_action_width)
	var two_action_width: float = single_action_width * 2.0 + float(choice_bar.get_theme_constant("separation"))
	_assert(absf(pass_action_width - expected_action_width) <= 1.0, "Combat action controls should keep the original pile/pass layout footprint")
	_assert(pass_action_width < two_action_width - 1.0, "Combat action controls should not permanently reserve the wider Skip/Cancel footprint")
	if play_meter != null and play_meter.visible:
		_assert_current_combat_dock_geometry(instance, "Card-play meter")
	instance.set("_selected_card_index", 0)
	instance.set("_pending_actions", [{"type": "move"}])
	instance.set("_pending_action_index", 0)
	instance.set("_pending_action_can_skip", true)
	instance.call("_refresh_choice_bar")
	instance.call("_refresh_visibility")
	await process_frame
	var targeting_hand_x: float = hand_scroll.global_position.x
	var targeting_action_width: float = left_action_stack.size.x
	_assert(absf(targeting_hand_x - pass_hand_x) <= 1.0, "Move targeting Skip/Cancel controls should not shift the hand area")
	_assert(absf(targeting_action_width - pass_action_width) <= 1.0, "Combat action controls should reserve a stable column width")
	instance.queue_free()
	await process_frame

func _test_run_scene_combat_interaction_context_paths() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for combat interaction context coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame

	_install_combat_interaction_fixture(instance, "quick_stab", Vector2i(2, 5), [Vector2i(6, 5)], 9204)
	await process_frame
	var options: Dictionary = instance.call("_card_play_options_for_index", 0)
	_assert(not bool(options.get("printed_playable", false)), "Far melee cards should show printed play as disabled while dragging")
	_assert(not bool(options.get("attack_playable", false)), "Far melee cards should disable fallback attack when no enemy is adjacent")
	_assert(bool(options.get("move_playable", false)), "Far melee cards should keep fallback move available")
	instance.call("_on_card_pressed", 0)
	await process_frame
	await process_frame
	var context: Control = instance.get("_action_step_tracker") as Control
	var full_choice: Button = context.find_child("CardActionChoicePlay", true, false) as Button
	var attack_choice: Button = context.find_child("CardActionChoiceAttack", true, false) as Button
	var move_choice: Button = context.find_child("CardActionChoiceMove", true, false) as Button
	_assert(context.visible and str(context.get_meta("context_mode", "")) == "choice", "Clicking a card should open its persistent exclusive play-mode selector")
	_assert(int(instance.get("_selected_card_index")) == 0 and int(instance.get("_card_action_choice_index")) == 0, "A Move-only card should enter fallback targeting without another click")
	_assert(str(instance.get("_card_action_choice_mode")) == "move", "A sole legal fallback Move should be pre-selected")
	_assert(full_choice != null and full_choice.disabled and full_choice.toggle_mode and not full_choice.button_pressed and not bool(full_choice.get_meta("active", false)), "Unavailable As Written should remain visibly disabled without stealing selection")
	_assert(attack_choice != null and attack_choice.disabled and attack_choice.toggle_mode and not attack_choice.button_pressed and not bool(attack_choice.get_meta("active", false)), "Attack should be a disabled inactive mode without an adjacent target")
	_assert(move_choice != null and not move_choice.disabled and move_choice.toggle_mode and move_choice.button_pressed and bool(move_choice.get_meta("active", false)), "Move should be the enabled active mode")
	_assert(full_choice != null and attack_choice != null and full_choice.modulate.a >= 0.99 and attack_choice.modulate.a >= 0.99, "Unavailable placards should dim without becoming translucent over the spine")
	_assert(move_choice != null and move_choice.modulate.a >= 0.99, "Available unselected modes should remain fully opaque")
	_assert(full_choice != null and attack_choice != null and move_choice != null and full_choice.button_group == attack_choice.button_group and attack_choice.button_group == move_choice.button_group, "All three play modes should share one exclusive ButtonGroup")
	for choice_button: Button in [full_choice, attack_choice, move_choice]:
		if choice_button != null:
			_assert(choice_button.custom_minimum_size.x >= 300.0 and choice_button.custom_minimum_size.y >= 94.0 and choice_button.custom_minimum_size.y <= 102.0, "Clicked-card play modes should use large overlapping painted placards")
			_assert(bool(choice_button.get_meta("authored_placard_choice", false)) and choice_button.find_child("ModePlacardTexture", true, false) != null, "Clicked-card play modes should use authored raster placards")
			_assert(bool(choice_button.get_meta("embedded_identity_icon", false)) and choice_button.find_child("ModeIcon", true, false) == null, "Each placard should contain its identity icon in the authored art")
			_assert(choice_button.find_child("ModeIndicator", true, false) == null and choice_button.find_child("SelectedDot", true, false) == null, "Brushstroke choices should remove the old radio dot and avoid a stamp selection mark")
	_assert(full_choice != null and str(full_choice.get_meta("mode_icon_key", "")) == "card_play", "PRINTED mode should identify its built-in emblem as a card")
	var selected_glow: TextureRect = move_choice.find_child("SelectedGlow", true, false) as TextureRect if move_choice != null else null
	_assert(move_choice != null and bool(move_choice.get_meta("selected_glow_visible", false)) and selected_glow != null and bool(selected_glow.get_meta("matches_pre_battle_start_glow", false)) and bool(selected_glow.get_meta("follows_placard_alpha", false)), "Auto-selected Move mode should use the soft alpha-following gold glow")
	_assert(context.get_theme_stylebox("panel") is StyleBoxEmpty, "Contextual card play choices should remove the old panel background")
	var placard_spine: TextureRect = context.find_child("ModePlacardSpine", true, false) as TextureRect
	_assert(placard_spine != null and bool(placard_spine.get_meta("connects_placards_only", false)), "The placard stack should have an authored connective spine that does not extend into the dynamic action row")
	instance.call("_on_cancel_requested")
	await process_frame
	_assert(int(instance.get("_card_action_choice_index")) == -1 and int(instance.get("_selected_card_index")) == -1, "Cancel from play-mode choices should return cleanly to idle")
	_assert((((instance.get("_combat_state") as Dictionary).get("deck", {}) as Dictionary).get("hand", []) as Array).size() == 1, "Canceling play-mode choices should not consume the card")
	await _choose_clicked_card_action(instance, 0, "move")
	_assert(int(instance.get("_selected_card_index")) == 0, "Clicked Basic Move should keep the exact chosen hand-card index")
	_assert(str(instance.get("_selected_card_label_override")) == "2 Move", "Clicked Basic Move should keep its concise fallback identity")
	var pending_actions: Array = instance.get("_pending_actions")
	_assert(pending_actions.size() == 1 and str((pending_actions[0] as Dictionary).get("type", "")) == "move", "Clicked Basic Move should preserve its one-step move semantics")
	instance.call("_on_cancel_requested")
	await process_frame
	instance.call("_on_card_drag_started", 0)
	await process_frame
	var overlay: Control = instance.get("_drag_overlay") as Control
	_assert(overlay != null and overlay.visible, "Starting a card drag should show the proxy layer")
	_assert(overlay != null and overlay.get_child_count() == 1, "Card drag should keep only the held-card proxy in its full-screen layer, with no central scrim or zones")
	context = instance.get("_action_step_tracker") as Control
	_assert(context != null and context.visible, "Card drag should show the compact action context")
	_assert(context != null and str(context.get_meta("context_mode", "")) == "drag", "Drag action context should expose its drag state")
	_assert(str(context.get_meta("risk_text", "")) == "FALLBACK ONLY", "Fallback-only drag should not label the unavailable full card as primary")
	var zone_panels: Dictionary = instance.get("_drag_zone_panels")
	var zone_labels: Dictionary = instance.get("_drag_zone_labels")
	var attack_panel: PanelContainer = zone_panels.get("attack", null) as PanelContainer
	var move_panel: PanelContainer = zone_panels.get("move", null) as PanelContainer
	var attack_label: Label = zone_labels.get("attack", null) as Label
	var move_label: Label = zone_labels.get("move", null) as Label
	_assert(not zone_panels.has("play"), "Full-card play should use the live battlefield instead of a Play Card drop panel")
	_assert(attack_label != null and attack_label.text == "BASIC ATTACK", "Fallback attack should remain a distinct compact command")
	_assert(move_label != null and move_label.text == "BASIC MOVE", "Fallback move should remain a distinct compact command")
	_assert(attack_panel != null and attack_panel.custom_minimum_size.x <= 200.0 and attack_panel.custom_minimum_size.y <= 64.0, "Fallback attack should use a compact action-rail target")
	_assert(move_panel != null and move_panel.custom_minimum_size.x <= 200.0 and move_panel.custom_minimum_size.y <= 64.0, "Fallback move should use a compact action-rail target")
	var detail_labels: Dictionary = instance.get("_drag_zone_detail_labels")
	var move_detail: Label = detail_labels.get("move", null) as Label
	_assert(move_detail != null and move_detail.text == "RANGE 2", "Available fallback move zones should keep a concise, non-redundant movement label")
	var hand_box: Control = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll/HandCenter/HandBox")
	var hidden_source: Control = null
	if hand_box.get_child_count() > 0:
		hidden_source = hand_box.get_child(0) as Control
	_assert(hidden_source != null and not hidden_source.visible, "Card drag should hide the source card while the proxy is held")
	var board_view: Control = instance.get_node("BoardUnderlay/CombatBoard") as Control
	_assert(str(instance.call("_drag_zone_at", board_view.get_global_rect().get_center())) == "", "An unavailable full card should not make the battlefield a valid drop target")
	await instance.call("_commit_drag_drop", "")
	await process_frame
	_assert(int(instance.get("_drag_card_index")) == -1 and not overlay.visible, "Dropping outside every valid target should snap the card back and clear drag state")
	hand_box = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll/HandCenter/HandBox")
	var restored_source: Control = hand_box.get_child(0) as Control if hand_box.get_child_count() > 0 else null
	_assert(restored_source != null and restored_source.visible, "Invalid drag drops should restore the source card")
	instance.call("_on_card_drag_started", 0)
	await process_frame
	await instance.call("_commit_drag_drop", "move")
	await process_frame
	_assert(int(instance.get("_selected_card_index")) == 0, "Fallback move drop should select the consumed hand card")
	_assert(str(instance.get("_selected_card_label_override")) == "2 Move", "Fallback move should keep its concise action identity")
	pending_actions = instance.get("_pending_actions")
	_assert(pending_actions.size() == 1 and str((pending_actions[0] as Dictionary).get("type", "")) == "move", "Fallback move should preserve its one-step move semantics")
	instance.call("_on_cancel_requested")
	await process_frame
	_assert(int(instance.get("_selected_card_index")) == -1, "Cancel should clear fallback targeting without consuming the card")
	_assert((((instance.get("_combat_state") as Dictionary).get("deck", {}) as Dictionary).get("hand", []) as Array).size() == 1, "Cancel should leave the hand card unconsumed")

	_install_combat_interaction_fixture(instance, "quick_stab", Vector2i(2, 5), [Vector2i(3, 5)], 9205)
	await process_frame
	instance.call("_on_card_pressed", 0)
	await process_frame
	await process_frame
	pending_actions = instance.get("_pending_actions")
	_assert(int(instance.get("_selected_card_index")) == 0, "One click should immediately select the card's printed action")
	_assert(str(instance.get("_card_action_choice_mode")) == "play", "One click should keep As Written active")
	_assert(str(instance.get("_selected_card_label_override")).is_empty(), "As Written should not carry a fallback label")
	_assert(pending_actions.size() == 1 and int((pending_actions[0] as Dictionary).get("damage", 0)) > int(instance.call("_fallback_attack_damage")), "One-click printed targeting should retain the card's printed damage")
	instance.call("_on_cancel_requested")
	await process_frame
	instance.call("_on_card_drag_started", 0)
	await process_frame
	_assert(str(instance.call("_drag_zone_at", board_view.get_global_rect().get_center())) == "play", "The readable battlefield should be the primary full-card drop path")
	var verb_label: Label = instance.get("_action_context_verb_label") as Label
	_assert(verb_label != null and verb_label.text == "DROP ON BOARD", "The primary drag instruction should remain terse and explicit")
	_assert(_label_text_fits(verb_label), "The primary drag instruction should fit without ellipsis")
	await instance.call("_commit_drag_drop", "play")
	await process_frame
	pending_actions = instance.get("_pending_actions")
	_assert(int(instance.get("_selected_card_index")) == 0 and str(instance.get("_selected_card_label_override")).is_empty(), "Full-card drag should enter printed-card targeting")
	_assert(pending_actions.size() == 1 and int((pending_actions[0] as Dictionary).get("damage", 0)) > int(instance.call("_fallback_attack_damage")), "Full-card drag should retain printed attack values")
	instance.call("_on_cancel_requested")
	await process_frame
	await _choose_clicked_card_action(instance, 0, "attack")
	pending_actions = instance.get("_pending_actions")
	_assert(str(instance.get("_selected_card_label_override")) == "3 Attack", "Clicked Basic Attack should keep its concise fallback identity")
	_assert(pending_actions.size() == 1 and int((pending_actions[0] as Dictionary).get("damage", 0)) == int(instance.call("_fallback_attack_damage")), "Clicked Basic Attack should preserve scaled default damage")
	instance.call("_on_cancel_requested")
	await process_frame

	_install_combat_interaction_fixture(instance, "sidestep_slash", Vector2i(2, 5), [Vector2i(5, 5)], 9206)
	await process_frame
	instance.call("_on_card_drag_started", 0)
	await process_frame
	await instance.call("_commit_drag_drop", "play")
	await process_frame
	pending_actions = instance.get("_pending_actions")
	_assert(pending_actions.size() == 2, "Full-card drag should preserve every printed compound-card step")
	_assert(str((pending_actions[0] as Dictionary).get("type", "")) == "move" and str((pending_actions[1] as Dictionary).get("type", "")) == "melee", "Compound full-card drag should preserve move then attack ordering")
	context = instance.get("_action_step_tracker") as Control
	_assert((context.get_meta("step_statuses", []) as Array).size() == 2, "Compound targeting should compose both steps into the action context")
	instance.call("_on_cancel_requested")
	await process_frame
	await _choose_clicked_card_action(instance, 0, "play")
	_assert(int(instance.get("_selected_card_index")) == 0, "Clicked Full Card should enter the printed compound-card path")
	_assert(int(instance.get("_drag_card_index")) == -1, "Click-to-select should not leave drag state active")
	instance.queue_free()
	await process_frame

func _set_run_scene_combat_state_for_test(instance: Node, combat_state: Dictionary) -> void:
	# Tests bypass RunScene's normal committed-state mutation path. Mirror its
	# cache-ownership contract so each injected scenario receives fresh previews.
	instance.set("_combat_state", combat_state)
	instance.call("_mark_combat_preview_state_changed")

func _install_combat_interaction_fixture(instance: Node, card_id: String, player_pos: Vector2i, enemy_positions: Array, seed: int) -> void:
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var layout: Dictionary = _simple_room_layout()
	layout["player_start"] = player_pos
	var enemies: Array = []
	for index: int in range(enemy_positions.size()):
		enemies.append({
			"id": index + 1,
			"type": "crawler",
			"pos": enemy_positions[index],
			"hp": 140,
			"max_hp": 140,
			"block": 0
		})
	layout["enemies"] = enemies
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(seed, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": [card_id],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = [card_id]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	_set_run_scene_combat_state_for_test(instance, combat_state)
	instance.set("_dialogue_active", false)
	instance.set("_animation_lock", false)
	instance.call("_refresh_ui")

func _test_run_scene_idle_hand_refresh_clears_card_fx_ghosts() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for card FX ghost cleanup coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var card_fx_layer: Control = instance.get("_card_fx_layer") as Control
	_assert(card_fx_layer != null, "Run scene should build a card FX layer")
	if card_fx_layer != null:
		var active_ghost := Control.new()
		active_ghost.name = "ActiveCardFxGhost"
		active_ghost.top_level = true
		card_fx_layer.add_child(active_ghost)
		instance.set("_animation_lock", true)
		instance.call("_refresh_hand_panel")
		_assert(card_fx_layer.get_child_count() == 1, "Hand refresh should not clear card FX while animations are locked")
		instance.set("_animation_lock", false)
		instance.call("_refresh_hand_panel")
		_assert(card_fx_layer.get_child_count() == 0, "Idle hand refresh should clear leftover card FX proxies before later selections")
	instance.queue_free()
	await process_frame

func _test_run_scene_ready_wave_marks_only_playable_hand_cards() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for ready-wave coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["player_start"] = Vector2i(2, 4)
	layout["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(5, 2),
		"hp": 140,
		"max_hp": 140,
		"block": 0
	}]
	var combat_state: Dictionary = combat.create_combat(9401, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab", "brace"],
		"relics": [],
		"hand_size": 2,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["quick_stab", "brace"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	combat_state["cards_played_this_turn"] = 0
	combat_state["death_bonus_card_plays_this_turn"] = 0
	combat_state["card_play_bonus_this_turn"] = 0
	combat_state["player_turn_restrictions"] = {"frozen": false, "shocked": false, "immobilized": true}
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	_set_run_scene_combat_state_for_test(instance, combat_state)
	instance.set("_animation_lock", false)
	instance.call("_queue_hand_ready_wave", "test_ready_wave")
	instance.call("_refresh_hand_panel")
	await process_frame
	var hand_box: Control = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll/HandCenter/HandBox")
	var widgets: Array[CardWidget] = _card_widgets_under(hand_box)
	_assert(widgets.size() >= 2, "Ready-wave test should render both hand cards")
	if widgets.size() >= 2:
		_assert(not widgets[0].has_meta("ready_wave_playable"), "Unplayable cards should not receive ready-wave metadata")
		_assert(widgets[1].has_meta("ready_wave_playable"), "Playable cards should receive ready-wave metadata")
		_assert(str(widgets[1].get_meta("ready_wave_reason", "")) == "test_ready_wave", "Ready-wave metadata should preserve the trigger reason")
		_assert(int(widgets[1].get_meta("ready_wave_order", -1)) == 0, "Ready-wave order should count playable cards only")
		_assert(float(widgets[1].get_meta("ready_wave_delay", -1.0)) == 0.0, "First playable ready-wave card should start without delay")
	instance.set("_animation_lock", true)
	instance.call("_queue_hand_ready_wave", "locked")
	instance.call("_refresh_hand_panel")
	await process_frame
	widgets = _card_widgets_under(hand_box)
	for widget: CardWidget in widgets:
		_assert(not widget.has_meta("ready_wave_playable"), "Animation-locked hand refresh should skip ready-wave metadata")
	instance.queue_free()
	await process_frame

func _test_run_scene_reward_heal_choice_sits_below_cards() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for reward heal-choice coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "reward"
	run_state["player_hp"] = 12
	run_state["player_max_hp"] = 24
	run_state["pending_reward"] = {
		"cards": ["quick_stab", "bone_dart", "sidestep_slash"],
		"heal_amount": RunEngine.REWARD_HEAL,
		"ember_amount": 0
	}
	instance.set("_run_state", run_state)
	instance.call("_refresh_ui")
	await process_frame
	await process_frame
	var choice_bar: HBoxContainer = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/ChoiceBar")
	var hand_box: Control = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll/HandCenter/HandBox")
	var card_row: HBoxContainer = instance.find_child("RewardCardRow", true, false) as HBoxContainer
	var recover_button: Button = instance.find_child("RewardRecoverButton", true, false) as Button
	_assert(not choice_bar.visible and choice_bar.get_child_count() == 0, "Reward healing should not appear in the combat choice bar")
	_assert(hand_box.get_child_count() == 0 and not hand_box.is_visible_in_tree(), "Reward choices should not reuse the combat hand row")
	_assert(card_row != null and card_row.get_child_count() == 3, "Reward presentation should preserve the canonical three-card offer")
	_assert(recover_button != null, "Reward healing should render as the secondary Skip and Recover button")
	if card_row != null and recover_button != null:
		_assert(recover_button.get_global_rect().position.y >= card_row.get_global_rect().end.y, "Skip and Recover should sit beneath the card offer")
		_assert(recover_button.get_global_rect().size.x < card_row.get_global_rect().size.x, "Skip and Recover should remain subordinate to the card row")
		_assert(int(recover_button.get_meta("reward_heal_amount", 0)) == RunEngine.REWARD_HEAL, "Recover should keep the offered heal amount")
		_assert(int(recover_button.get_meta("reward_heal_current_hp", 0)) == 12, "Recover should keep current health context")
		_assert(int(recover_button.get_meta("reward_heal_result_hp", 0)) == 15, "Recover should show the capped post-claim health result")
		_assert(int(recover_button.get_meta("reward_heal_effective", 0)) == RunEngine.REWARD_HEAL, "Injured Recover should show its effective healing")
		_assert(int(recover_button.get_meta("reward_heal_wasted", -1)) == 0, "Injured Recover should not report wasted healing when the full amount fits")
		_assert(recover_button.text.contains("SKIP & RECOVER"), "Recover should explicitly communicate that every card is skipped")
		_assert(recover_button.text.contains("+%d HP" % RunEngine.REWARD_HEAL), "Recover should show the offered healing")
		_assert(recover_button.text.contains("12 → 15"), "Recover should show exact current-to-clamped HP values")
	instance.queue_free()
	await process_frame

func _test_run_scene_reward_acquisition_is_single_choice() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for reward acquisition race coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var reward_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	reward_state["mode"] = "reward"
	reward_state["player_hp"] = 12
	reward_state["player_max_hp"] = 24
	reward_state["pending_reward"] = {
		"cards": ["spark_dart", "frostbolt"],
		"heal_amount": RunEngine.REWARD_HEAL,
		"ember_amount": 0
	}
	instance.set("_run_state", reward_state)
	instance.call("_refresh_ui")
	await process_frame
	await process_frame
	instance.set("_loadout_acquisition_in_progress", true)
	instance.set("_animation_lock", true)
	instance.call("_on_skip_reward_pressed")
	var locked_state: Dictionary = instance.get("_run_state")
	_assert(str(locked_state.get("mode", "")) == "reward", "Recover should not resolve while a reward-card acquisition animation owns the choice")
	_assert(int(locked_state.get("player_hp", 0)) == 12, "A blocked Recover click should not heal during reward-card acquisition")
	var recover_button: Button = instance.find_child("RewardRecoverButton", true, false) as Button
	_assert(recover_button != null, "Reward composition should expose Recover as a button")
	if recover_button != null:
		recover_button.pressed.emit()
	locked_state = instance.get("_run_state")
	_assert(str(locked_state.get("mode", "")) == "reward", "The Recover button input path should also stay blocked during reward-card acquisition")
	instance.call("_on_reward_card_pressed", "frostbolt")
	locked_state = instance.get("_run_state")
	_assert(not (locked_state.get("magic_inventory", []) as Array).has("frostbolt"), "A second reward card should not resolve while another acquisition owns the choice")
	instance.set("_loadout_acquisition_in_progress", false)
	instance.set("_animation_lock", false)
	instance.call("_on_skip_reward_pressed")
	var resolved_state: Dictionary = instance.get("_run_state")
	_assert(str(resolved_state.get("mode", "")) == "room", "Recover should resolve normally after the acquisition lock releases")
	_assert(int(resolved_state.get("player_hp", 0)) == 15, "Exactly one unlocked Recover choice should apply its offered healing")
	_assert(not (resolved_state.get("magic_inventory", []) as Array).has("frostbolt"), "Resolving Recover should leave the mutually exclusive reward spell unclaimed")
	instance.queue_free()
	await process_frame

func _test_run_scene_reward_decision_support_matches_claims() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for reward decision-support coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var engine := RunEngine.new()
	var open_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	open_state["mode"] = "reward"
	open_state["player_hp"] = 12
	open_state["player_max_hp"] = 24
	open_state["attuned_magic_cards"] = ["pale_spark", "dull_bolt", "waning_pulse", "chain_bolt"]
	open_state["magic_inventory"] = ["spark_dart"]
	open_state["reward_cards"] = ["spark_dart"]
	open_state["pending_reward"] = {
		"cards": ["spark_dart", "frostbolt", "firebrand_volley"],
		"heal_amount": RunEngine.REWARD_HEAL,
		"ember_amount": 0
	}
	instance.set("_run_state", open_state)
	instance.call("_refresh_ui")
	await process_frame
	await process_frame
	var reward_stack: VBoxContainer = instance.find_child("RewardChoiceStack", true, false) as VBoxContainer
	var card_row: HBoxContainer = instance.find_child("RewardCardRow", true, false) as HBoxContainer
	var recover_button: Button = instance.find_child("RewardRecoverButton", true, false) as Button
	var selection_backdrop: ColorRect = instance.find_child("SelectionBackdrop", true, false) as ColorRect
	var selection_banner: Control = instance.find_child("SelectionBanner", true, false) as Control
	var hand_row: Control = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow") as Control
	_assert(reward_stack != null and reward_stack.is_visible_in_tree(), "Reward cards and secondary actions should share one centered stage stack")
	_assert(card_row != null and card_row.get_child_count() == 3, "A normal post-combat reward should show exactly three card choices")
	_assert(recover_button != null and recover_button.get_parent().name == "RewardSecondaryActions", "Recover should be a subordinate button beneath the card row")
	_assert(selection_backdrop != null and selection_backdrop.visible and selection_backdrop.color.a >= 0.60, "Card rewards should dim the room behind the decision")
	_assert(selection_banner != null and selection_banner.visible, "Card rewards should put their instruction text on a foreground banner")
	_assert(hand_row != null and not hand_row.visible, "Post-combat rewards should not reuse the combat hand strip")
	var owned_slot: Control = null
	var new_slot: Control = null
	var reward_slots: Array = card_row.get_children() if card_row != null else []
	for slot_var: Node in reward_slots:
		var slot: Control = slot_var as Control
		if slot == null:
			continue
		match str(slot.get_meta("reward_card_id", "")):
			"spark_dart":
				owned_slot = slot
			"frostbolt":
				new_slot = slot
	_assert(owned_slot != null and str(owned_slot.get_meta("reward_status", "")) == "owned", "Already-owned reward magic should carry Owned status")
	_assert(owned_slot != null and _label_with_text(owned_slot, "OWNED") != null, "Owned status should be visible on its reward card")
	_assert(new_slot != null and str(new_slot.get_meta("reward_status", "")) == "new", "Unowned reward magic should display New")
	_assert(new_slot != null and _label_with_text(new_slot, "NEW") != null, "New status should be visible on its reward card")
	_assert(instance.find_child("RewardAttunementContext", true, false) == null, "Reward choices should not render attunement/loadout capacity copy")
	_assert(instance.find_child("RewardDestinationBadge", true, false) == null, "Reward cards should not render destination copy")
	_assert(recover_button != null and recover_button.text.contains("SKIP & RECOVER"), "The secondary health action should make its skip consequence explicit")
	_assert(recover_button != null and recover_button.text.contains("+%d HP" % RunEngine.REWARD_HEAL), "Recover should show the exact offered healing in its button label")
	_assert(recover_button != null and recover_button.text.contains("12 → 15"), "Recover should show the clamped HP projection in its button label")
	_assert(recover_button != null and int(recover_button.get_meta("reward_heal_result_hp", -1)) == 15, "Recover metadata should match the visible HP projection")
	if card_row != null and card_row.get_child_count() > 0:
		var first_card: Control = (card_row.get_child(0) as Control).find_child("CardWidget", true, false) as Control
		_assert(first_card != null and first_card.focus_mode == Control.FOCUS_ALL, "Reward cards should be keyboard/controller focusable")
		_assert(first_card != null and first_card.focus_neighbor_bottom != NodePath(), "Reward card focus should navigate down to the secondary action")
		_assert(recover_button != null and recover_button.focus_neighbor_top != NodePath(), "Recover focus should navigate back to the card row")
	var open_claimed: Dictionary = engine.claim_card_reward(open_state, "frostbolt")
	_assert((open_claimed.get("magic_inventory", []) as Array).count("frostbolt") == 1, "Actual open-capacity claim should add the displayed card to reserve")
	_assert(not (open_claimed.get("attuned_magic_cards", []) as Array).has("frostbolt"), "Actual open-capacity claim should not imply the reward became active")
	var duplicate_claimed: Dictionary = engine.claim_card_reward(open_state, "spark_dart")
	_assert((duplicate_claimed.get("magic_inventory", []) as Array).count("spark_dart") == 2, "Actual duplicate claim should add another reserve copy")

	var full_state: Dictionary = open_state.duplicate(true)
	full_state["player_hp"] = 24
	full_state["attuned_magic_cards"] = ["spark_dart", "frostbolt", "firebrand_volley", "chain_bolt", "threaded_path", "stone_plate"]
	full_state["magic_inventory"] = ["spark_dart"]
	full_state["reward_cards"] = ["spark_dart", "frostbolt", "firebrand_volley", "chain_bolt", "threaded_path", "stone_plate"]
	full_state["pending_reward"] = {
		"cards": ["spark_dart", "white_silence", "wildfire_halo"],
		"heal_amount": RunEngine.REWARD_HEAL,
		"ember_amount": 0
	}
	instance.set("_run_state", full_state)
	instance.call("_refresh_ui")
	await process_frame
	await process_frame
	recover_button = instance.find_child("RewardRecoverButton", true, false) as Button
	card_row = instance.find_child("RewardCardRow", true, false) as HBoxContainer
	_assert(recover_button != null and int(recover_button.get_meta("reward_heal_result_hp", -1)) == 24, "Full-health Recover should show unchanged capped health")
	_assert(recover_button != null and int(recover_button.get_meta("reward_heal_effective", -1)) == 0, "Full-health Recover should show zero effective healing")
	_assert(recover_button != null and int(recover_button.get_meta("reward_heal_wasted", -1)) == RunEngine.REWARD_HEAL, "Full-health Recover should retain accurate clamping metadata")
	_assert(recover_button != null and recover_button.text.contains("+%d HP" % RunEngine.REWARD_HEAL), "Full-health Recover should still show the offered value")
	_assert(recover_button != null and recover_button.text.contains("24 → 24"), "Full-health Recover should concisely show unchanged clamped HP")
	var healed_full: Dictionary = engine.skip_reward_for_heal(full_state)
	var displayed_full_result: int = int(recover_button.get_meta("reward_heal_result_hp", -2)) if recover_button != null else -2
	_assert(int(healed_full.get("player_hp", -1)) == displayed_full_result, "Displayed full-health Recover result should match the actual claim result")
	var full_claimed: Dictionary = engine.claim_card_reward(full_state, "white_silence")
	_assert((full_claimed.get("magic_inventory", []) as Array).has("white_silence"), "Actual full-attunement claim should add the displayed card to reserve")
	_assert((full_claimed.get("attuned_magic_cards", []) as Array) == (full_state.get("attuned_magic_cards", []) as Array), "Actual full-attunement claim should leave active magic unchanged")
	var visible_reward_card_widgets: int = 0
	reward_slots = card_row.get_children() if card_row != null else []
	for slot_var: Node in reward_slots:
		var slot: Control = slot_var as Control
		if slot == null or str(slot.get_meta("reward_card_id", "")).is_empty():
			continue
		var card_widget: Control = slot.find_child("CardWidget", true, false) as Control
		var ownership_badge: Control = slot.find_child("RewardOwnershipBadge", true, false) as Control
		var card_widget_visible: bool = card_widget != null and card_widget.is_visible_in_tree() and card_widget.modulate.a > 0.1 and card_widget.get_global_rect().size.x > 1.0
		_assert(card_widget_visible, "Each reward choice should contain a visibly rendered card widget")
		if card_widget_visible:
			visible_reward_card_widgets += 1
		_assert(ownership_badge != null and ownership_badge.is_visible_in_tree() and card_widget != null and card_widget.get_global_rect().encloses(ownership_badge.get_global_rect()), "Each reward card should visibly contain its ownership badge")
		if ownership_badge == null or card_widget == null:
			continue
		_assert(ownership_badge.get_parent() == card_widget, "Ownership badges should be direct children of the animated card presentation")
		_assert(ownership_badge.mouse_filter == Control.MOUSE_FILTER_IGNORE and _control_descendants_ignore_mouse(ownership_badge), "Ownership badges should never intercept card input")
		_assert(ownership_badge.z_as_relative and ownership_badge.z_index > 0, "Ownership badges should draw above their card while inheriting card z-order")
		var title_label: Control = card_widget.get_node_or_null("Margin/VBox/TopRow/Title") as Control
		var time_badge: Control = card_widget.find_child("TimeCostBadge", true, false) as Control
		_assert(title_label == null or not ownership_badge.get_global_rect().intersects(title_label.get_global_rect()), "Ownership badges should not cover card titles")
		_assert(time_badge == null or not ownership_badge.get_global_rect().intersects(time_badge.get_global_rect()), "Ownership badges should not cover card costs")
		var initial_card_rect: Rect2 = card_widget.get_global_rect()
		var initial_badge_rect: Rect2 = ownership_badge.get_global_rect()
		var initial_badge_anchor: Vector2 = _rect_anchor_within_rect(initial_badge_rect, initial_card_rect)
		var initial_badge_position: Vector2 = ownership_badge.position
		var initial_badge_local_scale: Vector2 = ownership_badge.scale
		card_widget.mouse_entered.emit()
		await create_timer(0.15).timeout
		var hovered_card_rect: Rect2 = card_widget.get_global_rect()
		var hovered_badge_rect: Rect2 = ownership_badge.get_global_rect()
		var card_growth: Vector2 = Vector2(hovered_card_rect.size.x / initial_card_rect.size.x, hovered_card_rect.size.y / initial_card_rect.size.y)
		var badge_growth: Vector2 = Vector2(hovered_badge_rect.size.x / initial_badge_rect.size.x, hovered_badge_rect.size.y / initial_badge_rect.size.y)
		_assert(card_widget.z_index == 20 and ownership_badge.z_index > card_widget.z_index, "Hovered card and badge should rise together above sibling choices")
		_assert(card_growth.x >= 1.085 and card_growth.y >= 1.085, "Reward card rendered bounds should materially enlarge through the production hover signal/tween")
		_assert(ownership_badge.position == initial_badge_position and ownership_badge.scale == initial_badge_local_scale, "Badge local attachment should remain fixed during hover pose changes")
		_assert(card_growth.is_equal_approx(badge_growth), "Ownership badge rendered bounds should enlarge by exactly the card hover ratio")
		_assert(_rect_anchor_within_rect(hovered_badge_rect, hovered_card_rect).distance_to(initial_badge_anchor) <= 0.002, "Ownership badge should preserve its exact rendered anchor within the hovered card")
		_assert(hovered_badge_rect.get_center().distance_to(initial_badge_rect.get_center()) >= 8.0, "Ownership badges should visibly move with hovered cards")
		card_widget.mouse_exited.emit()
		await create_timer(0.15).timeout
		_assert(card_widget.z_index == 0 and card_widget.get_global_rect().is_equal_approx(initial_card_rect) and ownership_badge.get_global_rect().is_equal_approx(initial_badge_rect), "Ownership badge should return exactly with its card")
	_assert(visible_reward_card_widgets == 3, "All three reward card widgets should be visibly rendered in the centered offer row")
	if card_row != null and card_row.get_child_count() == 3:
		var first_rect: Rect2 = (card_row.get_child(0) as Control).get_global_rect()
		var last_rect: Rect2 = (card_row.get_child(card_row.get_child_count() - 1) as Control).get_global_rect()
		var stage_rect: Rect2 = (instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/StageRoot") as Control).get_global_rect()
		_assert(stage_rect.encloses(first_rect) and stage_rect.encloses(last_rect), "The full reward row should fit inside the stage without clipping")
		for slot_var: Node in card_row.get_children():
			var slot: Control = slot_var as Control
			if slot != null:
				_assert(absf(slot.get_global_rect().position.y - first_rect.position.y) <= 1.0, "The three card choices should remain vertically aligned")
	instance.set("_run_state", open_state.duplicate(true))
	instance.call("_on_reward_card_pressed", "frostbolt")
	await process_frame
	var selected_state: Dictionary = instance.get("_run_state") as Dictionary
	_assert(str(selected_state.get("mode", "")) == "room" and (selected_state.get("pending_reward", {}) as Dictionary).is_empty(), "Selecting a card should still resolve the reward choice")
	_assert((selected_state.get("magic_inventory", []) as Array).count("frostbolt") == 1, "Selecting a New card should still acquire exactly one copy")
	instance.queue_free()
	await process_frame

func _test_run_scene_selection_prompts_clear_after_pick() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for selection prompt coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame

	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "reward"
	run_state["pending_reward"] = {
		"cards": ["quick_stab", "bone_dart", "sidestep_slash"],
		"heal_amount": RunEngine.REWARD_HEAL,
		"ember_amount": 0
	}
	instance.set("_run_state", run_state)
	instance.call("_refresh_choice_bar")
	var prompt_overlay: Control = instance.get("_relic_choice_overlay") as Control
	var prompt_title: Label = instance.get("_relic_choice_title") as Label
	var prompt_effect: Control = instance.get("_relic_choice_title_effect") as Control
	var prompt_banner: TextureRect = instance.get("_relic_choice_banner") as TextureRect
	_assert(prompt_overlay != null and prompt_overlay.visible, "Card reward selection should show the shared stage prompt overlay")
	_assert(prompt_title != null and prompt_title.visible and prompt_title.text == "GROW YOUR POWER", "Card reward selection should use the Grow your power prompt")
	_assert(prompt_banner != null and prompt_banner.visible and prompt_banner.texture != null and prompt_banner.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Card reward instruction should sit on a non-interactive raster banner")
	_assert(prompt_effect == null or not prompt_effect.visible, "Card reward prompt should not retain the oversized animated title effect")
	if prompt_title != null:
		_assert(prompt_title.get_theme_font_size("font_size") <= 32, "Selection prompt should use normal banner text rather than oversized display type")
		_assert(prompt_title.get_theme_constant("outline_size") <= 2, "Selection prompt text should use only a restrained readability outline")
	instance.call("_on_reward_card_pressed", "quick_stab")
	await process_frame
	_assert(prompt_overlay != null and not prompt_overlay.visible, "Card reward prompt should clear after picking a reward")
	_assert(prompt_title != null and not prompt_title.visible, "Card reward title should hide after picking a reward")
	_assert(prompt_banner != null and not prompt_banner.visible, "Card reward banner should hide after picking a reward")

	run_state = instance.get("_run_state")
	run_state["mode"] = "treasure"
	run_state["pending_relics"] = ["iron_lung", "ember_lens", "pilgrim_boots"]
	instance.set("_run_state", run_state)
	instance.call("_refresh_choice_bar")
	_assert(prompt_overlay != null and prompt_overlay.visible, "Relic selection should show the shared stage prompt overlay")
	_assert(prompt_title != null and prompt_title.visible and prompt_title.text == "CLAIM YOUR TREASURE", "Relic selection should keep the treasure prompt")
	_assert(prompt_banner != null and prompt_banner.visible, "Relic selection should share the centered instruction banner")
	_assert(prompt_effect == null or not prompt_effect.visible, "Relic selection should use the raster banner without an animated text layer")
	var relic_choice_bar: HBoxContainer = instance.get("_relic_choice_bar") as HBoxContainer
	var first_relic_choice: Control = null
	if relic_choice_bar != null and relic_choice_bar.get_child_count() > 0:
		first_relic_choice = relic_choice_bar.get_child(0) as Control
	var sparkle_layer: Control = null
	if first_relic_choice != null:
		sparkle_layer = first_relic_choice.find_child("RelicChoiceSparkle", true, false) as Control
	_assert(sparkle_layer != null and sparkle_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Relic choice sparkle should not intercept relic choice clicks")
	var source_rect: Rect2 = Rect2()
	if first_relic_choice != null:
		source_rect = first_relic_choice.get_global_rect()
	await instance.call("_on_relic_pressed", "iron_lung", source_rect)
	await process_frame
	_assert(prompt_overlay != null and not prompt_overlay.visible, "Relic prompt should clear after picking a relic")
	_assert(prompt_title != null and not prompt_title.visible, "Relic title should hide after picking a relic")
	_assert(prompt_banner != null and not prompt_banner.visible, "Relic instruction banner should hide after picking a relic")

	run_state = instance.get("_run_state")
	run_state["mode"] = "room"
	instance.set("_run_state", run_state)
	instance.call("_set_relic_choice_title", "BLACKSMITH")
	_assert(prompt_banner != null and not prompt_banner.visible, "Reward raster banner should not leak into merchant titles")
	_assert(prompt_effect != null and prompt_effect.visible, "Merchant titles should retain their prior animated treatment")
	if prompt_title != null:
		_assert(prompt_title.get_theme_font_size("font_size") > 32, "Merchant title typography should remain independent from restrained reward-banner text")

	instance.queue_free()
	await process_frame

func _test_run_scene_fatigue_damage_visual_event() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for fatigue visual coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame

	var combat: CombatEngine = CombatEngine.new()
	var before_state: Dictionary = combat.create_combat(118, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab", "brace"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (before_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = []
	deck["draw"] = []
	deck["discard"] = ["quick_stab"]
	deck["burned"] = []
	deck["cycles"] = 0
	before_state["deck"] = deck
	var after_state: Dictionary = combat.prepare_next_player_turn(before_state)
	var fatigue_events: Array = instance.call("_fatigue_damage_events_between_states", before_state, after_state)
	_assert(fatigue_events.size() == 1, "Fatigue draw should create one visual event when the deck cycles")
	if not fatigue_events.is_empty():
		var event: Dictionary = fatigue_events[0]
		var player_tile: Vector2i = (after_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
		_assert(int(event.get("amount", 0)) == CombatEngine.FATIGUE_BASE_DAMAGE, "First fatigue visual event should carry the first fatigue damage amount")
		_assert(event.get("tile", Vector2i(-1, -1)) == player_tile, "Fatigue visual text should anchor to the player tile")
	var fatigue_texts: Array = instance.call("_fatigue_floating_texts_for_events", after_state, fatigue_events)
	var found_damage_number: bool = false
	var found_fatigue_text: bool = false
	for text_var: Variant in fatigue_texts:
		var text_entry: Dictionary = text_var
		found_damage_number = found_damage_number or str(text_entry.get("text", "")) == "-2"
		found_fatigue_text = found_fatigue_text or str(text_entry.get("text", "")) == "fatigue sets in"
	_assert(found_damage_number, "Fatigue visual should include the normal floating damage number")
	_assert(found_fatigue_text, "Fatigue visual should include the fatigue text callout")
	var fatigue_presentation: Dictionary = instance.call("_fatigue_damage_presentation_for_progress", after_state, fatigue_events, 0.25)
	_assert((fatigue_presentation.get("impact_actor_keys", []) as Array).has("player"), "Fatigue visual should drive the player's damage impact animation")
	_assert(float(fatigue_presentation.get("impact_strength", 0.0)) > 1.0, "Fatigue visual should boost the player damage impact so it reads on the player sprite")
	_assert((fatigue_presentation.get("floating_texts", []) as Array).size() >= 2, "Fatigue damage presentation should show both damage number and fatigue text")
	var overlay: Control = instance.get("_fatigue_edge_overlay") as Control
	_assert(overlay != null, "RunScene should build a full-screen fatigue edge overlay")
	if overlay != null:
		instance.call("_set_fatigue_edge_progress", 0.5)
		await process_frame
		_assert(overlay.visible, "Fatigue edge overlay should appear while the pulse is active")
		instance.call("_set_fatigue_edge_progress", -1.0)
		await process_frame
		_assert(not overlay.visible, "Fatigue edge overlay should hide after the pulse")

	instance.queue_free()
	await process_frame

func _test_run_scene_campfire_choices_use_relic_overlay() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for campfire overlay coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "campfire"
	run_state["progression"] = ProgressionStore.default_data()
	run_state["held_embers"] = 0
	run_state["unbanked_embers"] = 0
	instance.set("_run_state", run_state)
	instance.set("_progression", ProgressionStore.default_data())
	instance.call("_refresh_choice_bar")
	var choice_bar: HBoxContainer = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/ChoiceBar")
	var context_overlay: PanelContainer = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/StageRoot/ContextChoiceOverlay")
	var relic_overlay: Control = instance.get("_relic_choice_overlay") as Control
	var relic_bar: HBoxContainer = instance.get("_relic_choice_bar") as HBoxContainer
	_assert(not choice_bar.visible, "Campfire choices should no longer sit in the bottom choice bar")
	_assert(not context_overlay.visible and _buttons_under(context_overlay).is_empty(), "Campfire choices should no longer use button overlays")
	_assert(relic_overlay != null and relic_overlay.visible, "Campfire choices should use the shared relic-style stage overlay")
	_assert(relic_bar != null and relic_bar.get_child_count() == 3, "Campfire overlay should expose heal, carry, and level-up choice panels")
	_assert(_label_with_text(relic_overlay, "Linger for a moment") != null, "Campfire overlay should label the continue option")
	_assert(_label_with_text(relic_overlay, "Embrace the fire's warmth") != null, "Campfire overlay should label the abandon option")
	_assert(_label_with_text(relic_overlay, "Learn a new skill") != null, "Campfire overlay should label the level-up option")
	_assert(_label_with_text(relic_overlay, "+4 HP") != null, "Campfire linger choice should show a compact heal chip")
	_assert(_label_with_text(relic_overlay, "CONTINUE") == null, "Campfire linger choice should not duplicate continue text in a chip")
	_assert(_label_with_text(relic_overlay, "BANK HELD") == null, "Campfire abandon choice should not duplicate bank text in a chip")
	_assert(_label_with_text(relic_overlay, "END RUN") == null, "Campfire abandon choice should not duplicate end-run text in a chip")
	_assert(_label_with_text(relic_overlay, "NEED 180") != null, "Campfire level-up choice should show the missing ember chip")
	_assert(_label_with_text(relic_overlay, "HELD 0") != null, "Campfire level-up choice should show current held embers when disabled")
	_assert(_label_with_text(relic_overlay, "Need 180 embers") != null, "Campfire level-up choice should be disabled when held embers are short")
	var disabled_strength_panel: Control = null
	if relic_bar != null and relic_bar.get_child_count() > 2:
		disabled_strength_panel = relic_bar.get_child(2) as Control
	_assert(disabled_strength_panel != null and not bool(disabled_strength_panel.get_meta("choice_enabled", true)), "Campfire level-up panel should be marked disabled when held embers are short")
	var linger_panel: PanelContainer = relic_bar.get_child(0) as PanelContainer if relic_bar != null and relic_bar.get_child_count() > 0 else null
	_assert(linger_panel != null and linger_panel.find_child("CampfireChoiceInnerGlow", true, false) is PanelContainer, "Campfire choices should include a subtle inner firelight glow")
	if linger_panel != null:
		_assert(linger_panel.custom_minimum_size == Vector2(264.0, 220.0), "Larger relic-offer cards should not resize the shared campfire choices")
		instance.call("_show_campfire_choice_feedback_pulse", linger_panel, Color("efb35f"))
		await process_frame
		_assert(linger_panel.find_child("CampfireChoicePressPulse", true, false) is PanelContainer, "Campfire choices should show a press feedback pulse")
	var loaded_icon_count: int = 0
	for texture_rect: TextureRect in _texture_rects_under(relic_overlay):
		if texture_rect.texture != null:
			loaded_icon_count += 1
	_assert(loaded_icon_count >= 3, "Campfire choice panels should load generated protagonist icons")
	run_state = instance.get("_run_state")
	run_state["held_embers"] = 180
	run_state["unbanked_embers"] = 180
	run_state["progression"] = ProgressionStore.set_embers(ProgressionStore.default_data(), 180)
	instance.set("_run_state", run_state)
	instance.set("_progression", run_state.get("progression", {}))
	instance.call("_refresh_choice_bar")
	relic_overlay = instance.get("_relic_choice_overlay") as Control
	relic_bar = instance.get("_relic_choice_bar") as HBoxContainer
	_assert(_label_with_text(relic_overlay, "180 EMBERS") != null, "Campfire level-up choice should reveal its cost chip when affordable")
	_assert(_label_with_text(relic_overlay, "NEW SKILL") != null, "Campfire level-up choice should reveal its qualitative benefit when affordable")
	_assert(_label_with_text(relic_overlay, "Spend embers, choose a skill, continue") != null, "Campfire level-up choice should explain the skill choice without changing the flow")
	var enabled_strength_panel: Control = null
	if relic_bar != null and relic_bar.get_child_count() > 2:
		enabled_strength_panel = relic_bar.get_child(2) as Control
	_assert(enabled_strength_panel != null and bool(enabled_strength_panel.get_meta("choice_enabled", false)), "Campfire level-up panel should be enabled when held embers meet the cost")
	instance.queue_free()
	await process_frame

func _test_run_scene_campfire_choice_press_is_single_shot() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for campfire input coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "campfire"
	run_state["progression"] = ProgressionStore.default_data()
	run_state["held_embers"] = 0
	run_state["unbanked_embers"] = 0
	run_state["player_hp"] = 10
	run_state["player_max_hp"] = 24
	instance.set("_run_state", run_state)
	instance.set("_progression", ProgressionStore.default_data())
	instance.call("_refresh_choice_bar")
	var relic_bar: HBoxContainer = instance.get("_relic_choice_bar") as HBoxContainer
	var linger_panel: PanelContainer = relic_bar.get_child(0) as PanelContainer if relic_bar != null and relic_bar.get_child_count() > 0 else null
	_assert(linger_panel != null, "Campfire single-shot test should expose the linger panel")
	if linger_panel == null:
		instance.queue_free()
		await process_frame
		return
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	instance.call("_on_campfire_choice_gui_input", click, "linger", linger_panel, Color("efb35f"))
	instance.call("_on_campfire_choice_gui_input", click, "linger", linger_panel, Color("efb35f"))
	await create_timer(0.14).timeout
	await process_frame
	var next_state: Dictionary = instance.get("_run_state")
	_assert(str(next_state.get("mode", "")) == "room", "Campfire linger press should still leave campfire mode")
	_assert(int(next_state.get("player_hp", 0)) == 14, "Rapid duplicate linger presses should heal only once")
	instance.queue_free()
	await process_frame

func _test_run_scene_campfire_bonfire_persists_after_leave() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for campfire prop coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var run_engine: RunEngine = instance.get("_run_engine")
	var run_state: Dictionary = run_engine.create_new_run(123, ProgressionStore.default_data())
	var campfire_coord := Vector2i(0, 2)
	var campfire_room: Dictionary = run_engine.room_metadata(run_state, campfire_coord)
	_assert(str(campfire_room.get("type", "")) == "campfire", "Depth-2 axis fixture should be a campfire room")
	run_state["current_room"] = campfire_coord
	run_state["mode"] = "room"
	run_state["current_room_layout"] = run_engine.call("_display_layout_for_room", int(run_state.get("seed", 0)), campfire_room, Vector2i.ZERO)
	instance.set("_run_state", run_state)
	instance.call("_refresh_stage_view")
	var board_view: Node = instance.get_node("BoardUnderlay/CombatBoard")
	var scene_props: Array = board_view.get("presentation").get("scene_props", [])
	var found_bonfire: bool = false
	for prop_var: Variant in scene_props:
		if typeof(prop_var) == TYPE_DICTIONARY and str((prop_var as Dictionary).get("kind", "")) == "campfire_bonfire":
			found_bonfire = true
			break
	_assert(found_bonfire, "Campfire bonfire should stay on the board after leaving the campfire choice mode")
	_assert(bool(board_view.call("_campfire_atmosphere_active")), "Campfire bonfire should enable board firelight atmosphere")
	var idle_frames: Array = board_view.call("_scene_prop_idle_frames_for_kind", "campfire_bonfire")
	_assert(idle_frames.size() == 16, "Campfire bonfire should load the full 4x4 idle animation sheet")
	var first_frame: AtlasTexture = null
	var second_frame: AtlasTexture = null
	if idle_frames.size() > 0:
		first_frame = idle_frames[0] as AtlasTexture
	if idle_frames.size() > 1:
		second_frame = idle_frames[1] as AtlasTexture
	_assert(first_frame != null and second_frame != null and first_frame.region != second_frame.region, "Campfire bonfire idle frames should be atlas-backed sprite sheet slices")
	instance.queue_free()
	await process_frame

func _test_run_scene_optional_followup_attack_stays_playable() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for optional follow-up coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(91, _optional_followup_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["sidestep_slash"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["sidestep_slash"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	_set_run_scene_combat_state_for_test(instance, combat_state)
	var preview: Dictionary = instance.call("_card_preview_for_index", 0)
	_assert(bool(preview.get("playable", false)), "Move-attack cards should stay playable even when the follow-up attack has no valid target")
	_assert(not (preview.get("target_tiles", []) as Array).is_empty(), "Optional move-attack cards should still offer movement targets")
	var first_target: Vector2i = (preview.get("target_tiles", []) as Array)[0]
	var next_state: Dictionary = combat.apply_player_action(combat_state, preview.get("action", {}), first_target)
	var next_preview: Dictionary = instance.call(
		"_card_preview_from_state",
		"sidestep_slash",
		next_state,
		GameData.card_def("sidestep_slash").get("actions", []),
		1
	)
	_assert(bool(next_preview.get("complete", false)), "The follow-up attack should auto-skip when it has no valid target")
	instance.queue_free()
	await process_frame

func _test_run_scene_flurry_utility_resolves_without_attack_target() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for Flurry utility coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(15112, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["blade_dance"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["blade_dance"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["player"] = {"pos": Vector2i(1, 7), "hp": 200, "max_hp": 200, "block": 0, "stoneskin": 0}
	combat_state["enemies"] = [
		{"id": 1, "type": "crawler", "pos": Vector2i(7, 1), "hp": 100, "max_hp": 100, "block": 0, "stoneskin": 0}
	]
	_set_run_scene_combat_state_for_test(instance, combat_state)
	var preview: Dictionary = instance.call("_card_preview_for_index", 0)
	_assert(bool(preview.get("complete", false)) and bool(preview.get("playable", false)), "Blade Dance should remain playable for its repeated block when no melee target is in range")
	var preview_player: Dictionary = (preview.get("state", {}) as Dictionary).get("player", {})
	_assert(int(preview_player.get("block", 0)) == GameData.fixed_point_amount(4), "Blade Dance should preview both copies of its printed block without requiring an attack target")
	instance.queue_free()
	await process_frame

func _test_run_scene_action_step_tracker_states() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for action step tracker coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame

	_load_action_step_tracker_fixture(instance, "sidestep_slash", Vector2i(2, 4), [Vector2i(5, 4)])
	await process_frame
	var piles_y_before: float = _control_global_rect(instance, ACTION_STEP_PILES_PATH).position.y
	await _choose_clicked_card_action(instance, 0, "play")
	await process_frame
	_assert_action_step_tracker_statuses(instance, ["current", "remaining"], "Move-attack selection should show current movement and remaining attack")
	_assert_action_step_tracker_layout(instance, piles_y_before, "Move-attack tracker should not shift piles or controls")
	await instance.call("_on_board_tile_clicked", Vector2i(4, 4))
	await process_frame
	_assert_action_step_tracker_statuses(instance, ["done", "current"], "Choosing the move target should advance the tracker to the attack")

	_load_action_step_tracker_fixture(instance, "sidestep_slash", Vector2i(2, 4), [Vector2i(3, 4)])
	await _choose_clicked_card_action(instance, 0, "play")
	await process_frame
	await instance.call("_on_skip_action_pressed")
	await process_frame
	_assert_action_step_tracker_statuses(instance, ["skipped", "current"], "Manual skip should keep a skipped movement placeholder")

	_load_action_step_tracker_fixture(instance, "sidestep_slash", Vector2i(2, 4), [Vector2i(3, 4)], true)
	await _choose_clicked_card_action(instance, 0, "play")
	await process_frame
	_assert_action_step_tracker_statuses(instance, ["skipped", "current"], "Auto-skipped immobilized movement should be visible before the attack")

	_load_action_step_tracker_fixture(instance, "guarded_step", Vector2i(2, 4), [Vector2i(5, 5)])
	await process_frame
	piles_y_before = _control_global_rect(instance, ACTION_STEP_PILES_PATH).position.y
	await _choose_clicked_card_action(instance, 0, "play")
	await process_frame
	_assert_action_step_tracker_statuses(instance, ["current", "remaining", "remaining"], "Targetless follow-up actions should remain visible after the current move step")
	_assert_action_step_tracker_layout(instance, piles_y_before, "Targetless follow-up tracker should occupy overlay space above controls")
	var tracker: Control = instance.get_node_or_null(ACTION_STEP_TRACKER_PATH) as Control
	var tracker_position_before_resolution: Vector2 = tracker.global_position if tracker != null else Vector2.ZERO
	instance.call("_lock_action_step_tracker_position_for_resolution")
	instance.set("_animation_lock", true)
	instance.set("_animating_hand_card_index", 0)
	instance.call("_begin_action_step_resolution_tracker", "guarded_step", (GameData.card_def("guarded_step").get("actions", []) as Array).duplicate(true), [Vector2i(4, 4)])
	instance.call("_refresh_animation_lock_ui")
	await process_frame
	_assert_action_step_tracker_statuses(instance, ["current", "remaining", "remaining"], "Execution should keep tracker visible during the move animation step")
	_assert(tracker != null and tracker.global_position.is_equal_approx(tracker_position_before_resolution), "Execution should keep the tracker at its pre-animation position when the hand reflows")
	instance.call("_set_action_step_resolution_index", 1)
	await process_frame
	_assert_action_step_tracker_statuses(instance, ["done", "current", "remaining"], "Execution should advance tracker to targetless block step")
	_assert(tracker != null and tracker.global_position.is_equal_approx(tracker_position_before_resolution), "Execution tracker should remain fixed through the block step")
	instance.call("_set_action_step_resolution_index", 2)
	await process_frame
	_assert_action_step_tracker_statuses(instance, ["done", "done", "current"], "Execution should advance tracker to targetless card-play step")
	_assert(tracker != null and tracker.global_position.is_equal_approx(tracker_position_before_resolution), "Execution tracker should remain fixed through the card-play step")
	instance.call("_set_action_step_resolution_index", 3)
	await process_frame
	_assert_action_step_tracker_statuses(instance, ["done", "done", "done"], "Execution should show all steps done through final card resolution")
	instance.call("_clear_action_step_resolution_tracker")
	instance.set("_animation_lock", false)
	instance.set("_animating_hand_card_index", -1)

	_load_action_step_tracker_fixture(instance, "quick_stab", Vector2i(2, 4), [Vector2i(3, 4)])
	await _choose_clicked_card_action(instance, 0, "play")
	await process_frame
	tracker = instance.get_node_or_null(ACTION_STEP_TRACKER_PATH) as Control
	_assert(tracker != null and tracker.visible, "Single-action cards should use the same coherent action context")
	_assert_action_step_tracker_statuses(instance, ["current"], "Single-action context should show its current step")
	_assert(str(tracker.get_meta("action_verb", "")).contains("MELEE"), "Single-action context should surface a terse action verb")
	_assert(_button_with_text(tracker, "Cancel") != null, "Single-action context should keep Cancel in the same region")

	instance.queue_free()
	await process_frame

func _load_action_step_tracker_fixture(instance: Node, card_id: String, player_pos: Vector2i, enemy_positions: Array, immobilized: bool = false) -> void:
	instance.call("_reset_card_resolution")
	var layout: Dictionary = _simple_room_layout()
	layout["player_start"] = player_pos
	var enemies: Array = []
	for index: int in range(enemy_positions.size()):
		enemies.append({
			"id": index + 1,
			"type": "crawler",
			"pos": enemy_positions[index],
			"hp": 140,
			"max_hp": 140,
			"block": 0
		})
	layout["enemies"] = enemies
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(9300 + enemy_positions.size(), layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": [card_id],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = [card_id]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	combat_state["cards_played_this_turn"] = 0
	combat_state["death_bonus_card_plays_this_turn"] = 0
	combat_state["card_play_bonus_this_turn"] = 0
	var restrictions: Dictionary = (combat_state.get("player_turn_restrictions", {}) as Dictionary).duplicate(true)
	restrictions["immobilized"] = immobilized
	restrictions["frozen"] = false
	restrictions["shocked"] = false
	combat_state["player_turn_restrictions"] = restrictions
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	_set_run_scene_combat_state_for_test(instance, combat_state)
	instance.set("_dialogue_active", false)
	instance.call("_refresh_ui")

func _assert_action_step_tracker_statuses(instance: Node, expected: Array, message: String) -> void:
	var tracker: Control = instance.get_node_or_null(ACTION_STEP_TRACKER_PATH) as Control
	_assert(tracker != null and tracker.visible, message)
	if tracker == null:
		return
	var statuses: Array = tracker.get_meta("step_statuses", [])
	_assert(statuses.size() == expected.size(), "%s: expected %d steps but got %d" % [message, expected.size(), statuses.size()])
	if statuses.size() != expected.size():
		return
	for index: int in range(expected.size()):
		_assert(str(statuses[index]) == str(expected[index]), "%s: expected %s but got %s" % [message, str(expected), str(statuses)])

func _assert_action_step_tracker_layout(instance: Node, expected_piles_y: float, message: String) -> void:
	var tracker: Control = instance.get_node_or_null(ACTION_STEP_TRACKER_PATH) as Control
	var choice: Control = instance.get_node_or_null(ACTION_STEP_CHOICE_PATH) as Control
	var piles: Control = instance.get_node_or_null(ACTION_STEP_PILES_PATH) as Control
	_assert(tracker != null and choice != null and piles != null, "%s: tracker controls should exist" % message)
	if tracker == null or choice == null or piles == null:
		return
	_assert(absf(piles.global_position.y - expected_piles_y) <= 1.0, "%s: pile row moved from %.1f to %.1f" % [message, expected_piles_y, piles.global_position.y])
	var tracker_rect: Rect2 = tracker.get_global_rect()
	for control: Control in [choice, piles]:
		if control.visible and control.size.x > 0.0 and control.size.y > 0.0:
			_assert(not tracker_rect.intersects(control.get_global_rect()), "%s: tracker should not overlap %s" % [message, control.name])

func _control_global_rect(instance: Node, path: String) -> Rect2:
	var control: Control = instance.get_node_or_null(path) as Control
	if control == null:
		return Rect2()
	return Rect2(control.global_position, control.size)

func _test_run_scene_move_attack_shortcut_clicks_enemy() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for move-attack shortcut coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["player_start"] = Vector2i(2, 5)
	layout["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(5, 5),
		"hp": 14,
		"max_hp": 14,
		"block": 0
	}]
	var combat_state: Dictionary = combat.create_combat(92, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["sidestep_slash"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["sidestep_slash"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	_set_run_scene_combat_state_for_test(instance, combat_state)
	instance.set("_dialogue_active", false)
	var preview: Dictionary = instance.call("_card_preview_for_index", 0)
	await instance.call("_begin_card_preview", 0, preview)
	var enemy_tile := Vector2i(5, 5)
	instance.call("_on_board_tile_hovered", enemy_tile)
	var board_view: Node = instance.get_node("BoardUnderlay/CombatBoard")
	var attack_tiles: Array = board_view.get("attack_tiles")
	_assert(attack_tiles.has(enemy_tile), "Move-attack previews should let the player click a reachable enemy directly")
	_assert(bool(board_view.get("presentation").get("pulse_attack_tiles", false)), "Player attack targets should request pulsing attack highlights")
	var focus_tiles: Array = board_view.get("presentation").get("focus_tiles", [])
	var typed_focus_tiles: bool = not focus_tiles.is_empty()
	for tile_var: Variant in focus_tiles:
		if typeof(tile_var) != TYPE_VECTOR2I:
			typed_focus_tiles = false
			break
	_assert(typed_focus_tiles, "Hovering a shortcut target should produce typed focus tiles instead of crashing preview rendering")
	await instance.call("_on_board_tile_clicked", enemy_tile)
	var final_state: Dictionary = instance.get("_combat_state")
	var player_tile: Vector2i = (final_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	_assert(player_tile == Vector2i(4, 5), "Enemy shortcut clicks should move only the minimum distance needed to attack")
	var enemies: Array = final_state.get("enemies", [])
	var enemy: Dictionary = enemies[0] if not enemies.is_empty() else {}
	_assert(int(enemy.get("hp", 0)) == 8, "Enemy shortcut clicks should still resolve the follow-up attack")
	instance.queue_free()
	await process_frame

func _test_run_scene_aoe_aim_rotates_before_click() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for AOE aim rotation coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(921, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["thunderline"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	combat_state["player"] = {"pos": Vector2i(2, 4), "hp": 20, "max_hp": 20, "block": 0, "stoneskin": 0}
	combat_state["enemies"] = [
		{"id": 1, "type": "crawler", "pos": Vector2i(4, 4), "hp": 20, "max_hp": 20, "block": 0},
		{"id": 2, "type": "harrier", "pos": Vector2i(4, 2), "hp": 20, "max_hp": 20, "block": 0},
		{"id": 3, "type": "acolyte", "pos": Vector2i(6, 4), "hp": 20, "max_hp": 20, "block": 0}
	]
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["thunderline"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	_set_run_scene_combat_state_for_test(instance, combat_state)
	instance.set("_dialogue_active", false)
	var preview: Dictionary = instance.call("_card_preview_for_index", 0)
	await instance.call("_begin_card_preview", 0, preview)
	var action_context: Control = instance.get("_action_step_tracker") as Control
	_assert(_button_with_text(action_context, "Rotate") != null, "Rotatable AOE targeting should compose Rotate into the action context")
	instance.call("_on_board_tile_hovered", Vector2i(5, 4))
	var board_view: Node = instance.get_node("BoardUnderlay/CombatBoard")
	var presentation: Dictionary = board_view.get("presentation")
	var focus_tiles: Array = presentation.get("focus_tiles", [])
	_assert(focus_tiles.has(Vector2i(4, 4)) and focus_tiles.has(Vector2i(6, 4)), "Default line AOE aim should show the full centered east pattern before clicking")
	instance.call("_rotate_aoe_aim", -1)
	instance.call("_on_board_tile_hovered", Vector2i(4, 3))
	presentation = board_view.get("presentation")
	focus_tiles = presentation.get("focus_tiles", [])
	_assert(focus_tiles.has(Vector2i(4, 2)) and focus_tiles.has(Vector2i(4, 4)) and not focus_tiles.has(Vector2i(6, 4)), "Rotating line AOE aim should update the hover pattern before target confirmation")
	await instance.call("_on_board_tile_clicked", Vector2i(4, 3))
	await create_timer(1.5).timeout
	var final_state: Dictionary = instance.get("_combat_state")
	var enemies: Array = final_state.get("enemies", [])
	_assert(int((enemies[1] as Dictionary).get("hp", 0)) < 20, "Rotated Thunderline should hit the selected vertical line")
	_assert(int((enemies[2] as Dictionary).get("hp", 0)) == 20, "Rotated Thunderline should not hit the old horizontal line")
	instance.queue_free()
	await process_frame

func _test_run_scene_squall_preserves_orientation() -> void:
	AnalyticsStore.clear_storage()
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for Squall orientation coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(923, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["squall_shot"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var target_tile := Vector2i(4, 4)
	combat_state["player"] = {"pos": Vector2i(2, 4), "hp": 20, "max_hp": 20, "block": 0, "stoneskin": 0}
	combat_state["enemies"] = [
		{"id": 1, "type": "crawler", "pos": target_tile, "hp": 20, "max_hp": 20, "block": 0},
		{"id": 2, "type": "harrier", "pos": Vector2i(4, 2), "hp": 20, "max_hp": 20, "block": 0},
		{"id": 3, "type": "acolyte", "pos": Vector2i(6, 4), "hp": 20, "max_hp": 20, "block": 0},
		{"id": 4, "type": "crawler", "pos": Vector2i(4, 6), "hp": 20, "max_hp": 20, "block": 0}
	]
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["squall_shot"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["analytics"] = {"combat_id": "test_squall_c001"}
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["deck_cards"] = ["squall_shot"]
	run_state["combat_state"] = combat_state
	run_state["analytics"] = {"run_id": "test_squall", "combat_counter": 1}
	instance.set("_run_state", run_state)
	_set_run_scene_combat_state_for_test(instance, combat_state)
	instance.call("_refresh_ui")
	var preview: Dictionary = instance.call("_card_preview_for_index", 0)
	await instance.call("_begin_card_preview", 0, preview)
	_assert(int(instance.get("_pending_action_index")) == 1 and (instance.get("_pending_target_tiles") as Array).has(target_tile), "Squall Shot should expose its attackable center through one AOE target step")
	_assert((instance.get("_pending_selected_targets") as Array).is_empty(), "Squall should not record a target before its AOE attack commits")
	var board_view: Node = instance.get_node("BoardUnderlay/CombatBoard")
	instance.call("_on_board_tile_hovered", target_tile)
	instance.call("_rotate_aoe_aim", -1)
	instance.call("_on_board_tile_hovered", target_tile)
	var presentation: Dictionary = board_view.get("presentation")
	var focus_tiles: Array = presentation.get("focus_tiles", [])
	_assert(focus_tiles.has(Vector2i(4, 2)) and focus_tiles.has(Vector2i(6, 4)) and not focus_tiles.has(Vector2i(4, 6)), "Rotating north should preview Squall's odd pattern around its single AOE target")
	await instance.call("_on_board_tile_clicked", target_tile)
	await create_timer(1.5).timeout
	var final_state: Dictionary = instance.get("_combat_state")
	var enemies: Array = final_state.get("enemies", [])
	_assert((enemies[0] as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(4, 3), "North-oriented Squall should push its center target north")
	_assert((enemies[1] as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(4, 1), "North-oriented Squall should hit and push the northern arm")
	_assert((enemies[2] as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(6, 3), "North-oriented Squall should hit and push the eastern arm")
	_assert(int((enemies[3] as Dictionary).get("hp", 0)) == 20 and (enemies[3] as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(4, 6), "North-oriented Squall should leave the old southern arm untouched")
	var played_events: Array[Dictionary] = _analytics_events_by_type(AnalyticsStore.load_all_events(), "card_played")
	_assert(((final_state.get("umbra", {}) as Dictionary).get("light_sources", []) as Array).is_empty(), "Squall should not create Light after its Radiance rider is removed")
	_assert(not played_events.is_empty(), "Squall should emit card-play analytics")
	if not played_events.is_empty():
		var payload: Dictionary = (played_events[played_events.size() - 1] as Dictionary).get("payload", {}) as Dictionary
		var actions: Array = payload.get("actions", []) as Array
		var aoe_action: Dictionary = actions[1] as Dictionary if actions.size() > 1 else {}
		var orientation: Dictionary = aoe_action.get("orientation", {}) as Dictionary
		_assert(int(orientation.get("x", 99)) == 0 and int(orientation.get("y", 99)) == -1, "Squall analytics should preserve the chosen AOE orientation")
		var selected_targets: Array = payload.get("selected_targets", []) as Array
		var aoe_target: Dictionary = selected_targets[0] as Dictionary if selected_targets.size() > 0 else {}
		_assert(
			selected_targets.size() == 1
			and int(aoe_target.get("x", -1)) == 4 and int(aoe_target.get("y", -1)) == 4,
			"Squall analytics should record one target for its AOE attack"
		)
	instance.queue_free()
	await process_frame

func _test_run_scene_push_direction_tiles_filter_closer_tiles() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for push direction filtering coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(922, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["updraft"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	combat_state["player"] = {"pos": Vector2i(2, 4), "hp": 20, "max_hp": 20, "block": 0, "stoneskin": 0}
	combat_state["enemies"] = [
		{"id": 1, "type": "crawler", "pos": Vector2i(3, 4), "hp": 100, "max_hp": 100, "block": 0}
	]
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["updraft"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	_set_run_scene_combat_state_for_test(instance, combat_state)
	instance.set("_dialogue_active", false)
	var preview: Dictionary = instance.call("_card_preview_for_index", 0)
	await instance.call("_begin_card_preview", 0, preview)
	await instance.call("_on_board_tile_clicked", Vector2i(3, 4))
	var board_view: Node = instance.get_node("BoardUnderlay/CombatBoard")
	var presentation: Dictionary = board_view.get("presentation")
	var ability_tiles: Array = presentation.get("ability_tiles", [])
	_assert(not ability_tiles.has(Vector2i(2, 4)), "Push direction selection should not show the protagonist tile as a valid closer direction")
	_assert(ability_tiles.has(Vector2i(4, 4)), "Push direction selection should still show directions that move the enemy farther away")
	await instance.call("_on_board_tile_clicked", Vector2i(2, 4))
	_assert(instance.get("_pending_orientation_target_tile") == Vector2i(3, 4), "Clicking an invalid closer push direction should keep direction selection pending")
	await instance.call("_on_board_tile_clicked", Vector2i(4, 4))
	await create_timer(1.5).timeout
	var final_state: Dictionary = instance.get("_combat_state")
	var enemies: Array = final_state.get("enemies", [])
	var enemy: Dictionary = enemies[0] if not enemies.is_empty() else {}
	_assert(enemy.get("pos", Vector2i.ZERO) == Vector2i(5, 4), "Confirming a valid push direction should move the enemy farther from the player")
	instance.queue_free()
	await process_frame

func _test_run_scene_block_card_skips_dead_move() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for dead-move skip coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(93, _dead_hand_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["guarded_step"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["guarded_step"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	_set_run_scene_combat_state_for_test(instance, combat_state)
	var preview: Dictionary = instance.call("_card_preview_for_index", 0)
	_assert(bool(preview.get("playable", false)), "Cards with a self effect should remain playable when their move step has no target")
	_assert(bool(preview.get("complete", false)), "Dead move steps should auto-skip into the card's self effect")
	instance.queue_free()
	await process_frame

func _test_run_scene_targetless_card_click_requires_confirmation() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for targetless click coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(95, _simple_room_layout(), {
		"hp": 12,
		"max_hp": 20,
		"deck_cards": ["patch_up", "quick_stab"],
		"relics": [],
		"hand_size": 2,
		"heal_bonus": 0
	})
	var player: Dictionary = (combat_state.get("player", {}) as Dictionary).duplicate(true)
	player["hp"] = 12
	combat_state["player"] = player
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["patch_up", "quick_stab"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	_set_run_scene_combat_state_for_test(instance, combat_state)
	instance.call("_refresh_ui")
	await _choose_clicked_card_action(instance, 0, "play")
	await process_frame
	var armed_state: Dictionary = instance.get("_combat_state")
	var armed_player: Dictionary = armed_state.get("player", {})
	var context: Control = instance.get("_action_step_tracker") as Control
	var play_button: Button = _button_with_text(context, "Play Card")
	_assert(int(armed_player.get("hp", 0)) == 12 and int(armed_player.get("block", 0)) == 0, "Selecting a targetless card should preview without applying its effects")
	_assert(int(armed_state.get("cards_played_this_turn", 0)) == 0, "Selecting a targetless card should not spend a card play")
	_assert(((armed_state.get("deck", {}) as Dictionary).get("hand", []) as Array) == ["patch_up", "quick_stab"], "Selecting a targetless card should leave the exact hand intact")
	_assert(play_button != null and not play_button.disabled, "A targetless card should expose a clear Play Card confirmation action")
	_assert(str(context.get_meta("action_verb", "")) == "READY · PLAY CARD" and str(context.get_meta("target_state", "")) == "NO TARGET REQUIRED", "Targetless confirmation should explain that no board target is needed")

	await instance.call("_on_card_action_choice_pressed", "move")
	await process_frame
	_assert(str(instance.get("_card_action_choice_mode")) == "move" and int(instance.get("_selected_card_index")) == 0, "An armed targetless card should remain switchable to Basic Move before commitment")
	await instance.call("_on_card_action_choice_pressed", "play")
	await process_frame
	armed_state = instance.get("_combat_state")
	_assert(int(armed_state.get("cards_played_this_turn", 0)) == 0 and int((armed_state.get("player", {}) as Dictionary).get("hp", 0)) == 12, "Switching back to Printed should re-arm the card without committing it")

	instance.call("_on_cancel_requested")
	await process_frame
	_assert(int(instance.get("_selected_card_index")) == -1 and int(instance.get("_card_action_choice_index")) == -1, "Cancel should close targetless confirmation")
	_assert((((instance.get("_combat_state") as Dictionary).get("deck", {}) as Dictionary).get("hand", []) as Array) == ["patch_up", "quick_stab"], "Canceling targetless confirmation should preserve the exact hand")

	await _choose_clicked_card_action(instance, 0, "play")
	instance.call("_on_card_pressed", 1)
	await process_frame
	armed_state = instance.get("_combat_state")
	_assert(int(armed_state.get("cards_played_this_turn", 0)) == 0 and int((armed_state.get("player", {}) as Dictionary).get("hp", 0)) == 12, "Selecting another card should replace targetless confirmation without committing the first card")
	_assert(int(instance.get("_card_action_choice_index")) == 1, "Selecting another card should move the play-mode rail to that card")
	instance.call("_on_cancel_requested")
	await process_frame

	await _choose_clicked_card_action(instance, 0, "play")
	await instance.call("_on_confirm_card_play_pressed")
	await create_timer(1.5).timeout
	var committed_state: Dictionary = instance.get("_combat_state")
	var committed_player: Dictionary = committed_state.get("player", {})
	_assert(int(committed_player.get("hp", 0)) == 14, "Confirming a targetless self card should commit its heal")
	_assert(int(committed_player.get("block", 0)) == 2, "Confirming a targetless self card should commit its block")
	_assert(((committed_state.get("deck", {}) as Dictionary).get("hand", []) as Array) == ["quick_stab"], "Confirming should consume only the armed targetless card")
	instance.queue_free()
	await process_frame

	instance = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	_install_combat_interaction_fixture(instance, "spark_focus", Vector2i(2, 5), [], 96)
	await process_frame
	var intensity_before: Dictionary = ((instance.get("_combat_state") as Dictionary).get("elemental_intensity", {}) as Dictionary).duplicate(true)
	await _choose_clicked_card_action(instance, 0, "play")
	await process_frame
	var intensity_armed_state: Dictionary = instance.get("_combat_state")
	context = instance.get("_action_step_tracker") as Control
	_assert(int(instance.get("_pending_action_index")) >= (instance.get("_pending_actions") as Array).size(), "A no-target Spark Focus should preview through its skipped ranged step")
	_assert((intensity_armed_state.get("elemental_intensity", {}) as Dictionary) == intensity_before, "A no-target intensity card should not raise live intensity before confirmation")
	_assert(_button_with_text(context, "Play Card") != null, "A card whose target step has no valid target should expose Play Card confirmation")
	instance.queue_free()
	await process_frame

func _test_run_scene_fallback_attack_uses_scaled_damage() -> void:
	var run_scene_script: Script = load("res://scripts/run_scene.gd")
	_assert(run_scene_script != null, "Run scene script should load for fallback action coverage")
	if run_scene_script == null:
		return
	var instance: Node = run_scene_script.new()
	var attack_actions: Array = instance.call("_fallback_actions", "attack")
	var attack_action: Dictionary = attack_actions[0] as Dictionary
	_assert(int(attack_action.get("damage", 0)) == 3, "Fallback attack should use the raised natural-unit damage")
	_assert(str(instance.call("_fallback_label", "attack")) == "3 Attack", "Fallback attack drag labels should match natural-unit damage")
	instance.free()

func _test_run_scene_card_play_meter_spends_before_resolution_rewards() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for card play meter spend preview coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(951, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab", "quick_stab"],
		"relics": [],
		"hand_size": 2,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["quick_stab", "quick_stab"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	_set_run_scene_combat_state_for_test(instance, combat_state)
	instance.call("_refresh_ui")
	instance.call("_layout_combat_action_dock")
	instance.call("_layout_choice_button_overlay")
	var count_label: Label = instance.get("_play_meter_count") as Label
	_assert(count_label != null and count_label.text == "2 card plays", "Card play meter should start from available combat plays")
	var banked_badge: Control = instance.get("_play_meter_banked_badge") as Control
	_assert(banked_badge != null and not banked_badge.visible, "Card play meter should hide its banked-play badge when no play is stored")
	_assert(count_label != null and absf(count_label.position.y) <= 1.0 and absf(count_label.size.y - 58.0) <= 1.0, "Default card-play copy should be vertically centered in the full 58px plaque")
	instance.call("_begin_card_play_meter_spend_preview")
	_assert(count_label != null and count_label.text == "1 card plays", "Card play meter should spend the played card immediately")
	var rewarded_state: Dictionary = combat_state.duplicate(true)
	rewarded_state["death_bonus_card_plays_this_turn"] = 1
	_assert(int(instance.call("_card_play_count_for_resolution_state", rewarded_state)) == 2, "Death-reward play previews should add to the already-spent meter count")

	instance.set("_card_play_count_override", -1)
	instance.set("_card_play_resolution_spend", 0)
	instance.set("_card_play_budget_override", {})
	combat_state["skill_ids"] = ["measured_breath", "borrowed_time"]
	combat_state["banked_play_active"] = 1
	combat_state["banked_play_spent_this_activation"] = 0
	combat_state["cards_played_this_turn"] = 0
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	_set_run_scene_combat_state_for_test(instance, combat_state)
	instance.call("_refresh_card_play_meter")
	for settle_frame: int in range(8):
		if int(instance.get("_hand_layout_pending_revision")) != int(instance.get("_hand_layout_revision")):
			break
		await process_frame
	_assert(int(instance.get("_hand_layout_pending_revision")) != int(instance.get("_hand_layout_revision")), "Card-play dock coverage should wait for the bounded asynchronous hand-layout fit")
	var banked_label: Label = instance.get("_play_meter_banked_label") as Label
	_assert(count_label != null and count_label.text == "2 card plays", "The large card-play count should reserve its number for ordinary plays")
	_assert(banked_badge != null and banked_badge.visible and banked_label != null and banked_label.text == "+1 BANKED • NO TIME", "A stored Borrowed Time play should have its own explicit badge")
	_assert(count_label != null and count_label.position.y >= 3.0 and count_label.size.y <= 26.0, "Banked-play state should intentionally split the plaque into count and banked rows")
	var play_meter: Control = instance.get("_play_meter") as Control
	_assert(play_meter != null and play_meter.visible, "Wide banked-play copy should retain the visible card-play dock")
	_assert_current_combat_dock_geometry(instance, "Wide banked-play copy")
	combat_state["cards_played_this_turn"] = 2
	_set_run_scene_combat_state_for_test(instance, combat_state)
	instance.call("_refresh_card_play_meter")
	_assert(count_label != null and count_label.text == "0 card plays" and banked_label != null and banked_label.text == "NEXT • NO TIME", "The banked badge should identify when the no-Time play is next")
	combat_state["cards_played_this_turn"] = 0
	_set_run_scene_combat_state_for_test(instance, combat_state)
	instance.call("_begin_card_play_meter_spend_preview")
	await instance.call("_animate_card_play_reward", 3)
	var rewarded_budget: Dictionary = instance.call("_displayed_card_play_budget") as Dictionary
	_assert(int(rewarded_budget.get("ordinary_remaining", 0)) == 2 and int(rewarded_budget.get("banked_remaining", 0)) == 1, "A play granted during resolution should increase ordinary capacity without recreating the banked slot")
	instance.queue_free()
	await process_frame

func _test_run_scene_damage_display_matches_bonus() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for damage display coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(97, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["sidestep_slash"],
		"relics": ["duelist_whetstone"],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["sidestep_slash"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	_set_run_scene_combat_state_for_test(instance, combat_state)
	var display: Dictionary = instance.call("_card_widget_display", "sidestep_slash", combat_state)
	var summary_rows: Array = display.get("summary_rows", [])
	var modifier_lines: Array = display.get("modifier_lines", [])
	_assert(not summary_rows.is_empty(), "Damage cards should render icon summary rows")
	var damage_token: Dictionary = {}
	for row_var: Variant in summary_rows:
		for token_var: Variant in row_var as Array:
			var token: Dictionary = token_var as Dictionary
			if str(token.get("icon", "")) == "melee":
				damage_token = token
	_assert(not damage_token.is_empty(), "Damage cards should render the attack keyword as an icon")
	_assert(int(damage_token.get("value", 0)) == 8, "Damage cards should show final damage, not base damage, when a conditional modifier applies")
	_assert(str(damage_token.get("tone", "")) == "bonus", "Modified damage tokens should carry bonus styling")
	_assert(modifier_lines.is_empty(), "Damage modifiers should live on the modified token instead of a duplicate card-level tooltip")
	_assert(ActionIcons.token_is_modified(damage_token), "Damage cards should mark dynamically modified tokens")
	_assert(ActionIcons.token_tooltip(damage_token).contains("Duelist Whetstone"), "The damage token tooltip should name the modifier source")
	instance.queue_free()
	await process_frame

func _test_run_scene_intensity_condition_rows_mark_activity() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for intensity display coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var earth_layout: Dictionary = _simple_room_layout()
	earth_layout["element"] = ElementData.EARTH
	var active_state: Dictionary = combat.create_combat(15124, earth_layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["venom_claw"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var active_display: Dictionary = instance.call("_card_widget_display", "venom_claw", active_state)
	var active_token: Dictionary = _first_intensity_requirement_token(active_display.get("summary_rows", []))
	_assert(not active_token.is_empty() and bool(active_token.get("condition_active", false)), "A card that builds enough intensity before its bonus should mark that bonus active")
	var fire_layout: Dictionary = _simple_room_layout()
	fire_layout["element"] = ElementData.FIRE
	var inactive_state: Dictionary = combat.create_combat(15125, fire_layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["venom_claw"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var inactive_display: Dictionary = instance.call("_card_widget_display", "venom_claw", inactive_state)
	var inactive_token: Dictionary = _first_intensity_requirement_token(inactive_display.get("summary_rows", []))
	_assert(not inactive_token.is_empty() and not bool(inactive_token.get("condition_active", false)), "An unmet intensity bonus should not render as active")
	instance.queue_free()
	await process_frame

func _test_card_widget_active_intensity_condition_glows() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	var card_scene: PackedScene = load("res://scenes/card_widget.tscn")
	if run_scene == null or card_scene == null:
		_failures.append("Run scene and CardWidget scene should load for intensity glow coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var earth_layout: Dictionary = _simple_room_layout()
	earth_layout["element"] = ElementData.EARTH
	var active_state: Dictionary = combat.create_combat(15126, earth_layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["venom_claw"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var active_display: Dictionary = instance.call("_card_widget_display", "venom_claw", active_state)
	var widget := card_scene.instantiate() as CardWidget
	widget.custom_minimum_size = Vector2(250.0, 352.0)
	widget.size = Vector2(250.0, 352.0)
	root.add_child(widget)
	await process_frame
	widget.configure("venom_claw", false, false, true, false, false, true, GameData.card_def("venom_claw"))
	widget.set_display_overrides(str(active_display.get("summary_bbcode", "")), active_display.get("modifier_lines", []), active_display.get("summary_rows", []))
	await process_frame
	var glow: Control = widget.get_node_or_null("IntensityActiveGlow") as Control
	_assert(glow != null and glow.visible, "A card with an active elemental intensity condition should show the full-card glow")
	_assert(glow != null and str(glow.get("element_id")) == ElementData.EARTH, "The active intensity glow should use the triggered element")
	var fire_layout: Dictionary = _simple_room_layout()
	fire_layout["element"] = ElementData.FIRE
	var inactive_state: Dictionary = combat.create_combat(15127, fire_layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["venom_claw"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var inactive_display: Dictionary = instance.call("_card_widget_display", "venom_claw", inactive_state)
	widget.set_display_overrides(str(inactive_display.get("summary_bbcode", "")), inactive_display.get("modifier_lines", []), inactive_display.get("summary_rows", []))
	await process_frame
	_assert(glow != null and not glow.visible, "A card below its elemental intensity threshold should hide the full-card glow")
	widget.queue_free()
	instance.queue_free()
	await process_frame

func _test_card_widget_flurry_icon_uses_wide_slot() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	var card_scene: PackedScene = load("res://scenes/card_widget.tscn")
	if run_scene == null or card_scene == null:
		_failures.append("Run scene and CardWidget scene should load for Flurry icon layout coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var widget := card_scene.instantiate() as CardWidget
	widget.custom_minimum_size = Vector2(250.0, 352.0)
	widget.size = Vector2(250.0, 352.0)
	root.add_child(widget)
	await process_frame
	var display: Dictionary = instance.call("_card_widget_display", "blade_dance", {})
	widget.configure("blade_dance", false, false, true, false, false, true, GameData.card_def("blade_dance"))
	widget.set_display_overrides(str(display.get("summary_bbcode", "")), display.get("modifier_lines", []), display.get("summary_rows", []))
	await process_frame
	var summary_box: VBoxContainer = widget.get("_summary_icon_box") as VBoxContainer
	var wide_icon: TextureRect
	var regular_icon: TextureRect
	for texture_rect: TextureRect in _texture_rects_under(summary_box):
		var minimum_size: Vector2 = texture_rect.custom_minimum_size
		if minimum_size.x > minimum_size.y * 1.5:
			wide_icon = texture_rect
		elif regular_icon == null and is_equal_approx(minimum_size.x, minimum_size.y):
			regular_icon = texture_rect
	_assert(wide_icon != null, "Flurry should render in a dedicated wide summary-token slot")
	_assert(regular_icon != null, "Blade Dance should retain regular square action-token slots beside Flurry")
	if wide_icon != null and regular_icon != null:
		var wide_size: Vector2 = wide_icon.custom_minimum_size
		var regular_size: Vector2 = regular_icon.custom_minimum_size
		_assert(wide_size.x >= regular_size.x * 1.75 and wide_size.x <= regular_size.x * 1.85, "Flurry should render at about 1.8x normal token width")
		_assert(wide_size.y <= regular_size.y * 1.10, "Flurry's wide slot should not create a doubled-height row gap")
	widget.queue_free()
	instance.queue_free()
	await process_frame

func _first_intensity_requirement_token(rows: Array) -> Dictionary:
	for row_var: Variant in rows:
		if typeof(row_var) != TYPE_ARRAY:
			continue
		var row: Array = row_var as Array
		for token_var: Variant in row:
			if typeof(token_var) != TYPE_DICTIONARY:
				continue
			var token: Dictionary = token_var
			if str(token.get("kind", "")) == "intensity_requirement":
				return token
	return {}

func _test_run_scene_ranged_cards_show_range() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for ranged-card coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(101, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["bone_dart"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["bone_dart"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	_set_run_scene_combat_state_for_test(instance, combat_state)
	var display: Dictionary = instance.call("_card_widget_display", "bone_dart", combat_state)
	var summary_rows: Array = display.get("summary_rows", [])
	_assert(not summary_rows.is_empty(), "Ranged cards should render icon summary rows")
	var card_row: Array = summary_rows[0] as Array
	_assert(str((card_row[0] as Dictionary).get("icon", "")) == "ranged", "Ranged cards should show the ranged keyword as an icon")
	_assert(str((card_row[1] as Dictionary).get("icon", "")) == "range" and int((card_row[1] as Dictionary).get("value", 0)) == 4, "Ranged cards should show their range with the shared range icon")
	var board := CombatBoardView.new()
	var intent_rows: Array = board.call("_intent_rows", {"actions": [{"type": "ranged", "damage": 4, "range": 4}]})
	_assert(intent_rows.size() == 1 and str(((intent_rows[0] as Array)[1] as Dictionary).get("icon", "")) == "range", "Enemy shot intents should show attack range with the shared range icon")
	instance.queue_free()
	await process_frame

func _test_run_scene_preview_normalizes_untyped_target_tiles() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for untyped preview-target coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(104, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["guarded_step"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["guarded_step"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	_set_run_scene_combat_state_for_test(instance, combat_state)
	var target_tile := Vector2i(3, 4)
	instance.set("_hovered_board_tile", target_tile)
	await instance.call("_begin_card_preview", 0, {
		"card_id": "guarded_step",
		"state": combat_state,
		"actions": [{"type": "move", "range": 1}],
		"action_index": 0,
		"target_tiles": [target_tile],
		"complete": false,
		"playable": true,
		"action": {"type": "move", "range": 1},
		"skip_allowed": false
	})
	instance.call("_refresh_stage_view")
	var active_preview: Dictionary = instance.call("_active_card_preview")
	var active_targets: Array = active_preview.get("target_tiles", [])
	_assert(active_targets.size() == 1 and active_targets[0] == target_tile, "Run scene previews should preserve Vector2i target tiles when dictionaries provide plain arrays")
	var board_view: Node = instance.get_node("BoardUnderlay/CombatBoard")
	var move_tiles: Array = board_view.get("move_tiles")
	_assert(move_tiles.has(target_tile), "Stage refresh should accept untyped preview target arrays and surface them on the combat board")
	instance.queue_free()
	await process_frame

func _test_run_scene_illusion_hover_surfaces_preview_unit() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for illusion hover preview coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(106, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["shadow_step"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["shadow_step"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	_set_run_scene_combat_state_for_test(instance, combat_state)
	instance.set("_dialogue_active", false)
	var preview: Dictionary = instance.call("_card_preview_for_index", 0)
	await instance.call("_begin_card_preview", 0, preview)
	var target_tile := Vector2i(3, 4)
	instance.call("_on_board_tile_hovered", target_tile)
	var board_view: Node = instance.get_node("BoardUnderlay/CombatBoard")
	var presentation: Dictionary = board_view.get("presentation")
	var preview_units: Array = presentation.get("preview_units", [])
	var ability_tiles: Array = presentation.get("ability_tiles", [])
	var attack_tiles: Array = board_view.get("attack_tiles")
	_assert(ability_tiles.has(target_tile), "Illusion target previews should expose green ability target tiles")
	_assert(not attack_tiles.has(target_tile), "Illusion target previews should stay out of attack target highlights")
	_assert(not bool(presentation.get("pulse_attack_tiles", false)), "Illusion target previews should not request attack target pulsing")
	_assert(preview_units.size() == 1, "Hovering a valid illusion target should surface one placement preview unit")
	if not preview_units.is_empty():
		var preview_unit: Dictionary = preview_units[0] as Dictionary
		_assert(str(preview_unit.get("role", "")) == "illusion_preview", "Illusion target hovers should tag preview units distinctly from placed illusions")
		_assert(preview_unit.get("pos", Vector2i.ZERO) == target_tile, "Illusion preview units should appear on the hovered valid tile")
		_assert(int(preview_unit.get("hp", 0)) > 0, "Illusion preview units should expose the pending illusion health")
	instance.call("_on_board_tile_hovered", Vector2i(5, 2))
	presentation = board_view.get("presentation")
	_assert((presentation.get("preview_units", []) as Array).is_empty(), "Hovering an invalid illusion target should hide the placement preview unit")
	instance.queue_free()
	await process_frame

func _test_run_scene_move_previews_avoid_traps_when_possible() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for trap-aware move preview coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["player_start"] = Vector2i(2, 4)
	layout["enemies"] = [
		{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(5, 3),
			"hp": 14,
			"max_hp": 14,
			"block": 0
		}
	]
	layout["traps"] = [{
		"id": "trap_3_4",
		"pos": Vector2i(3, 4),
		"element": "fire",
		"damage": 2,
		"burn": 2
	}]
	var combat_state: Dictionary = combat.create_combat(105, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	_set_run_scene_combat_state_for_test(instance, combat_state)
	instance.set("_hovered_board_tile", Vector2i(5, 4))
	var preview: Dictionary = {
		"card_id": "test_move_attack",
		"state": combat_state,
		"actions": [
			{"type": "move", "range": 5},
			{"type": "melee", "damage": 4, "range": 1}
		],
		"action_index": 0,
		"target_tiles": [Vector2i(5, 4)],
		"complete": false,
		"playable": true,
		"action": {"type": "move", "range": 5},
		"skip_allowed": false
	}
	var path_tiles: Array = instance.call("_path_tiles_for_preview", preview)
	_assert(not path_tiles.has(Vector2i(3, 4)), "Move previews should prefer trap-free paths when the move range can support them")
	var shortcuts: Dictionary = instance.call("_preview_shortcuts_for_current_action", preview)
	var plans: Dictionary = shortcuts.get("plans", {})
	var shortcut_plan: Dictionary = plans.get(Vector2i(5, 3), {})
	var shortcut_path: Array = shortcut_plan.get("path_tiles", [])
	_assert(not shortcut_path.has(Vector2i(3, 4)), "Move-attack previews should reuse the same trap-avoiding movement path")
	var blink_preview: Dictionary = {
		"card_id": "test_blink_attack",
		"state": combat_state,
		"actions": [
			{"type": "blink", "range": 5},
			{"type": "melee", "damage": 4, "range": 1}
		],
		"action_index": 0,
		"target_tiles": [Vector2i(5, 4)],
		"complete": false,
		"playable": true,
		"action": {"type": "blink", "range": 5},
		"skip_allowed": false
	}
	var blink_path: Array[Vector2i] = combat.path_for_player_action(combat_state, {"type": "blink", "range": 5}, Vector2i(5, 4))
	_assert(blink_path == [Vector2i(5, 4)], "Blink paths should be returned as typed Vector2i arrays")
	var blink_shortcuts: Dictionary = instance.call("_preview_shortcuts_for_current_action", blink_preview)
	var blink_plan: Dictionary = (blink_shortcuts.get("plans", {}) as Dictionary).get(Vector2i(5, 3), {})
	var blink_shortcut_path: Array = blink_plan.get("path_tiles", [])
	_assert(blink_shortcut_path == [Vector2i(5, 4)], "Blink-attack shortcut previews should keep the blink destination as a typed path")
	instance.queue_free()
	await process_frame

func _test_run_scene_hovered_enemy_shows_threat_overlay() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for enemy threat overlay coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(102, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	combat_state["enemies"] = [
		{
			"id": 1,
			"type": "harrier",
			"pos": Vector2i(5, 2),
			"hp": 10,
			"max_hp": 10,
			"block": 0,
			"intent": {
				"name": "Pelt",
				"actions": [
					{"type": "move_toward", "range": 2},
					{"type": "ranged", "damage": 4, "range": 3}
				]
			}
		}
	]
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	_set_run_scene_combat_state_for_test(instance, combat_state)
	instance.set("_hovered_board_tile", Vector2i(5, 2))
	instance.call("_refresh_stage_view")
	var board_view: Node = instance.get_node("BoardUnderlay/CombatBoard")
	var move_tiles: Array = board_view.get("move_tiles")
	var attack_tiles: Array = board_view.get("attack_tiles")
	_assert(move_tiles.has(Vector2i(4, 2)), "Hovering an enemy should surface its movement threat tiles on the board")
	_assert(attack_tiles.has(Vector2i(2, 4)), "Hovering an enemy should surface its attack threat tiles on the board")
	_assert(not bool(board_view.get("presentation").get("pulse_attack_tiles", false)), "Enemy threat overlays should keep static attack highlights")
	instance.queue_free()
	await process_frame

func _test_run_scene_show_all_enemy_intents_and_threats() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for show-all enemy intent coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(103, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	combat_state["enemies"] = [
		{
			"id": 1, "type": "harrier", "pos": Vector2i(2, 2), "hp": 10, "max_hp": 10, "block": 0,
			"intent": {"name": "Pelt", "actions": [{"type": "move_toward", "range": 1}, {"type": "ranged", "damage": 4, "range": 3}]}
		},
		{
			"id": 2, "type": "crawler", "pos": Vector2i(5, 2), "hp": 10, "max_hp": 10, "block": 0,
			"intent": {"name": "Skitter", "actions": [{"type": "move_toward", "range": 2}, {"type": "melee", "damage": 3, "range": 1}]}
		}
	]
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	_set_run_scene_combat_state_for_test(instance, combat_state)
	instance.call("_refresh_turn_order_bar")
	instance.call("_set_show_all_enemy_intents", true)
	var board_view: Node = instance.get_node("BoardUnderlay/CombatBoard")
	var presentation: Dictionary = board_view.get("presentation") as Dictionary
	var threat_previews: Array = presentation.get("enemy_threat_previews", []) as Array
	_assert(bool(presentation.get("show_all_enemy_intents", false)), "Show-all mode should reveal every enemy contour without hover")
	_assert(threat_previews.size() == 2, "Show-all mode should submit one projected threat preview for every visible living enemy")
	_assert(not (board_view.get("move_tiles") as Array).is_empty(), "Show-all mode should surface the enemies' combined movement preview")
	_assert(not (board_view.get("attack_tiles") as Array).is_empty(), "Show-all mode should surface the enemies' combined attack preview")
	var toggle: Button = instance.find_child("EnemyIntentToggle", true, false) as Button
	_assert(toggle != null and toggle.button_pressed and toggle.text == "INTENTS ON [I]", "The turn-order rail should expose a pressed, labeled, focusable intent toggle")
	instance.queue_free()
	await process_frame

func _test_run_scene_frostglass_lancer_line_threat_overlay() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for Frostglass Lancer threat overlay coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(105, _simple_room_layout(), {
		"hp": 30,
		"max_hp": 30,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	combat_state["player"] = {
		"pos": Vector2i(6, 4),
		"hp": 30,
		"max_hp": 30,
		"block": 0,
		"stoneskin": 0
	}
	combat_state["enemies"] = [
		{
			"id": 1,
			"type": "frostglass_lancer",
			"pos": Vector2i(2, 2),
			"hp": 130,
			"max_hp": 130,
			"block": 0
		}
	]
	_set_enemy_intent(combat_state, 0, _enemy_intent_by_id("frostglass_lancer", "glass_lunge"))
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	_set_run_scene_combat_state_for_test(instance, combat_state)
	instance.set("_hovered_board_tile", Vector2i(2, 2))
	instance.call("_refresh_stage_view")
	var board_view: Node = instance.get_node("BoardUnderlay/CombatBoard")
	var move_tiles: Array = board_view.get("move_tiles")
	var attack_tiles: Array = board_view.get("attack_tiles")
	_assert(move_tiles.has(Vector2i(2, 4)), "RunScene should surface the Frostglass Lancer's sideways setup movement on board hover")
	_assert(attack_tiles.has(Vector2i(3, 4)) and attack_tiles.has(Vector2i(6, 4)), "RunScene should surface the Frostglass Lancer's four-tile straight-line threat on board hover")
	_assert(not attack_tiles.has(Vector2i(6, 3)) and not attack_tiles.has(Vector2i(6, 5)), "RunScene Frostglass Lancer hover should avoid the removed spearhead burst")
	var portrait_path: String = str(instance.call("_turn_order_portrait_path", {"kind": "enemy", "type": "frostglass_lancer"}))
	_assert(portrait_path == "res://assets/art/portraits/frostglass_lancer.png", "Frostglass Lancer should use its face-focused portrait in the turn-order widget")
	var order_entries: Array = combat.current_turn_order(combat_state, 8)
	var lancer_turn_visible: bool = false
	for entry_var: Variant in order_entries:
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var
		if str(entry.get("kind", "")) == "enemy" and str(entry.get("type", "")) == "frostglass_lancer":
			lancer_turn_visible = true
	_assert(lancer_turn_visible, "Frostglass Lancer should appear in current turn-order entries")
	instance.queue_free()
	await process_frame

func _test_run_scene_animation_lock_preserves_board_animation_presentation() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for animation-lock hover coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(104, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	combat_state["enemies"] = [
		{
			"id": 1,
			"type": "harrier",
			"pos": Vector2i(5, 2),
			"hp": 10,
			"max_hp": 10,
			"block": 0
		}
	]
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	_set_run_scene_combat_state_for_test(instance, combat_state)
	instance.set("_animation_lock", true)
	var board_view: Node = instance.get_node("BoardUnderlay/CombatBoard")
	var animated_state: Dictionary = combat_state.duplicate(true)
	var animated_enemies: Array = (animated_state.get("enemies", []) as Array).duplicate(true)
	var animated_enemy: Dictionary = (animated_enemies[0] as Dictionary).duplicate(true)
	var destination_tile := Vector2i(4, 2)
	animated_enemy["pos"] = destination_tile
	animated_enemies[0] = animated_enemy
	animated_state["enemies"] = animated_enemies
	var moving_presentation: Dictionary = {
		"unit_world_positions": {"enemy_1": board_view.call("world_position_for_tile", Vector2i(4, 1))},
		"unit_draw_tiles": {"enemy_1": destination_tile}
	}
	instance.call("_render_board_state", animated_state, moving_presentation)
	instance.call("_on_board_tile_hovered", Vector2i(3, 3))
	_assert_board_kept_animating_enemy(board_view, destination_tile, "Board hover during animation lock")
	instance.call("_render_board_state", animated_state, moving_presentation)
	instance.call("_on_turn_order_enemy_hovered", Vector2i(5, 2), "enemy_1")
	_assert_board_kept_animating_enemy(board_view, destination_tile, "Turn order hover during animation lock")
	instance.call("_render_board_state", animated_state, moving_presentation)
	instance.set("_hovered_card_index", 0)
	instance.call("_on_card_hover_ended", 0)
	_assert_board_kept_animating_enemy(board_view, destination_tile, "Card hover exit during animation lock")
	instance.call("_render_board_state", animated_state, moving_presentation)
	instance.call("_on_turn_order_enemy_unhovered", Vector2i(5, 2), "enemy_1")
	_assert_board_kept_animating_enemy(board_view, destination_tile, "Turn order unhover during animation lock")
	var preview_state: Dictionary = combat_state.duplicate(true)
	var preview_player: Dictionary = (preview_state.get("player", {}) as Dictionary).duplicate(true)
	var preview_destination_tile := Vector2i(3, 4)
	preview_player["pos"] = preview_destination_tile
	preview_state["player"] = preview_player
	instance.set("_preview_combat_state", preview_state)
	instance.call("_refresh_stage_view")
	var rendered_state: Dictionary = board_view.get("combat_state")
	var rendered_player: Dictionary = rendered_state.get("player", {})
	_assert(rendered_player.get("pos", Vector2i.ZERO) == (combat_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO), "Animation-locked stage refresh should not draw the resolved player preview before the move animation starts")
	instance.queue_free()
	await process_frame

func _test_run_scene_surfaces_defeated_enemy_death_units() -> void:
	var instance := RunSceneScript.new()
	var before_state: Dictionary = {
		"enemies": [{
			"id": 7,
			"type": "chainbound_gaoler",
			"pos": Vector2i(5, 4),
			"footprint": Vector2i(2, 1),
			"hp": 24,
			"max_hp": 90,
			"block": 0
		}]
	}
	var after_state: Dictionary = before_state.duplicate(true)
	var enemies: Array = (after_state.get("enemies", []) as Array).duplicate(true)
	var enemy: Dictionary = (enemies[0] as Dictionary).duplicate(true)
	enemy["pos"] = Vector2i(6, 4)
	enemy["hp"] = 0
	enemies[0] = enemy
	after_state["enemies"] = enemies
	var units: Array = instance.call("_defeated_enemy_units_between_states", before_state, after_state)
	_assert(units.size() == 1, "RunScene should produce a death presentation unit for enemies crossing to zero HP")
	if not units.is_empty():
		var death_unit: Dictionary = units[0]
		_assert(str(death_unit.get("key", "")) == "enemy_7", "Death presentation units should preserve stable enemy actor keys")
		_assert(str(death_unit.get("type", "")) == "chainbound_gaoler", "Death presentation units should preserve enemy type for sheet lookup")
		_assert(death_unit.get("pos", Vector2i.ZERO) == Vector2i(6, 4), "Death presentation units should use the defeated enemy's final tile after forced movement")
		_assert(death_unit.get("footprint", Vector2i.ONE) == Vector2i(2, 1), "Death presentation units should preserve large enemy footprints")
		_assert(bool(death_unit.get("death_animation", false)), "Death presentation units should opt into dissolve rendering")
	var hold_presentation: Dictionary = instance.call("_death_hold_presentation", before_state, after_state, {
		"focus_actor_keys": ["player"],
		"floating_texts": []
	})
	var hold_units: Array = hold_presentation.get("death_animation_units", [])
	_assert(hold_units.size() == 1, "Post-lethal impact presentations should keep a frame-zero death unit visible before the dissolve starts")
	_assert(hold_presentation.get("focus_actor_keys", []) == ["player"], "Death hold presentations should preserve existing impact presentation keys")
	if not hold_units.is_empty():
		var hold_unit: Dictionary = hold_units[0]
		_assert(str(hold_unit.get("key", "")) == "enemy_7", "Death hold units should reuse the defeated enemy actor key")
		_assert(hold_unit.get("pos", Vector2i.ZERO) == Vector2i(6, 4), "Death hold units should keep forced-movement deaths on the final tile")
		_assert(int(hold_unit.get("death_frame", -1)) == 0, "Death hold units should start on the first death frame")
		_assert(is_equal_approx(float(hold_unit.get("death_progress", -1.0)), 0.0), "Death hold units should not advance dissolve progress during impact text")
	instance.free()

func _test_run_scene_surfaces_destroyed_terrain_units() -> void:
	var instance := RunSceneScript.new()
	var before_state: Dictionary = {
		"terrain": [{
			"id": "box_a",
			"kind": "wooden_box",
			"pos": Vector2i(4, 4),
			"hp": 3,
			"max_hp": 3
		}]
	}
	var after_state: Dictionary = before_state.duplicate(true)
	var terrain_entries: Array = (after_state.get("terrain", []) as Array).duplicate(true)
	var terrain: Dictionary = (terrain_entries[0] as Dictionary).duplicate(true)
	terrain["hp"] = 0
	terrain_entries[0] = terrain
	after_state["terrain"] = terrain_entries
	var destroyed: Array = instance.call("_destroyed_terrain_units_between_states", before_state, after_state)
	_assert(destroyed.size() == 1, "RunScene should produce a destruction presentation unit for terrain crossing to zero HP")
	if not destroyed.is_empty():
		var destroyed_prop: Dictionary = destroyed[0]
		_assert(str(destroyed_prop.get("key", "")) == "terrain_box_a", "Terrain destruction units should preserve stable terrain keys")
		_assert(str(destroyed_prop.get("kind", "")) == "wooden_box", "Terrain destruction units should preserve kind for sheet lookup")
		_assert(destroyed_prop.get("pos", Vector2i.ZERO) == Vector2i(4, 4), "Terrain destruction units should stay on the destroyed square")
	var hold_presentation: Dictionary = instance.call("_death_hold_presentation", before_state, after_state, {
		"focus_actor_keys": ["player"],
		"floating_texts": []
	})
	var held_terrain: Array = hold_presentation.get("terrain_destruction_units", [])
	_assert(held_terrain.size() == 1, "Post-lethal impact presentations should keep destroyed terrain visible on frame zero before breakup starts")
	_assert(hold_presentation.get("focus_actor_keys", []) == ["player"], "Terrain destruction holds should preserve existing impact presentation keys")
	if not held_terrain.is_empty():
		var held_prop: Dictionary = held_terrain[0]
		_assert(int(held_prop.get("destruction_frame", -1)) == 0, "Terrain destruction holds should start on the first sheet frame")
		_assert(is_equal_approx(float(held_prop.get("destruction_progress", -1.0)), 0.0), "Terrain destruction holds should not advance during impact text")
	instance.free()

func _test_run_scene_discard_pile_uses_distinct_icon_controls() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for discard pile coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(103, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["quick_stab"]
	deck["draw"] = ["brace", "quick_stab"]
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	_set_run_scene_combat_state_for_test(instance, combat_state)
	instance.call("_refresh_pile_visuals")
	instance.call("_open_pile_view", "discard")
	await process_frame
	var pile_dialog: PanelContainer = instance.get("_pile_dialog")
	var pile_empty_label: Label = instance.get("_pile_dialog_empty")
	_assert(pile_dialog != null and pile_dialog.custom_minimum_size.x <= 540.0 and pile_dialog.custom_minimum_size.y <= 260.0, "The empty discard pile dialog should stay compact")
	var pile_close_button: Button = pile_dialog.find_child("CloseButton", true, false) as Button if pile_dialog != null else null
	_assert(pile_close_button != null and absf(pile_close_button.custom_minimum_size.x - pile_close_button.custom_minimum_size.y) <= 1.0, "The pile dialog close control should be a compact square button")
	_assert(pile_empty_label != null and pile_empty_label.visible and pile_empty_label.text == "No cards in this pile.", "The empty discard pile dialog should use final centered empty copy")
	instance.call("_close_pile_view")
	var hosts: Dictionary = instance.get("_pile_visual_hosts")
	var discard_host: Control = hosts.get("discard", null)
	_assert(discard_host != null and discard_host.get_child_count() == 1 and discard_host.find_child("DiscardPileIcon", true, false) != null, "The empty discard pile should render as its purpose-built discard icon")
	var draw_host: Control = hosts.get("draw", null)
	_assert(draw_host != null and draw_host.find_child("DrawPileIcon", true, false) != null, "The draw pile should render its purpose-built icon")
	var run_scene_script: Script = instance.get_script() as Script
	_assert(run_scene_script != null and str(run_scene_script.get_script_constant_map().get("DRAW_PILE_ICON_TEXTURE_PATH", "")) == "res://assets/art/ui/draw_pile_icon_v2.png", "The draw pile should use the brighter v2 icon asset")
	var badges: Dictionary = instance.get("_pile_badges")
	var draw_badge: Label = badges.get("draw", null)
	var pile_card_size: Vector2 = instance.call("_pile_display_card_size")
	_assert(draw_badge != null and draw_badge.visible and draw_badge.text == "2", "The draw pile should show its remaining card count")
	_assert(draw_badge != null and draw_badge.get_parent() == (instance.get("_pile_content_hosts") as Dictionary).get("draw", null), "The draw count badge should be positioned inside the pile content layer")
	_assert(draw_badge != null and draw_badge.size.x < pile_card_size.x * 0.4 and draw_badge.position.x >= 0.0 and draw_badge.position.y >= 0.0 and draw_badge.position.y + draw_badge.size.y <= pile_card_size.y and pile_card_size.x - (draw_badge.position.x + draw_badge.size.x) >= 0.0 and pile_card_size.x - (draw_badge.position.x + draw_badge.size.x) <= 6.0, "The draw count badge should stay as a small top-right badge (badge %s/%s, pile %s)" % [draw_badge.position if draw_badge != null else Vector2.ZERO, draw_badge.size if draw_badge != null else Vector2.ZERO, pile_card_size])
	var discard_badge: Label = badges.get("discard", null)
	_assert(discard_badge != null and discard_badge.visible and discard_badge.text == "0", "The discard pile should retain its established numeric badge even when empty")
	deck["discard"] = ["quick_stab"]
	combat_state["deck"] = deck
	_set_run_scene_combat_state_for_test(instance, combat_state)
	instance.call("_refresh_pile_visuals")
	instance.call("_open_pile_view", "discard")
	await process_frame
	_assert(pile_dialog != null and pile_dialog.custom_minimum_size.x < 760.0 and pile_dialog.custom_minimum_size.y <= 450.0, "A one-card discard pile dialog should stay compact around its card")
	instance.call("_close_pile_view")
	discard_host = hosts.get("discard", null)
	var discard_icon: Control = discard_host.find_child("DiscardPileIcon", true, false) as Control if discard_host != null else null
	_assert(discard_icon != null and discard_icon.size == Vector2(88.0, 88.0), "A non-empty discard pile should retain its dedicated 88px discard icon")
	_assert(discard_badge != null and discard_badge.visible and discard_badge.text == "1", "The discard icon should keep its numeric count badge")
	instance.queue_free()
	await process_frame

func _test_run_scene_displays_owned_relic_icons() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for relic HUD coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var run_state: Dictionary = instance.get("_run_state")
	run_state["relics"] = ["ember_lens", "pilgrim_boots", "mirror_shard"]
	instance.set("_run_state", run_state)
	instance.call("_refresh_ui")
	var relic_bar: VBoxContainer = instance.get_node("UiLayer/UiRoot/RelicBar")
	var relic_grid: GridContainer = instance.get("_relic_icon_grid") as GridContainer
	_assert(relic_bar.visible, "The run HUD should show relic icons when the player owns relics")
	_assert(relic_grid != null and relic_grid.get_child_count() == 3, "The run HUD should render one icon per owned relic")
	instance.queue_free()
	await process_frame

func _test_run_scene_relic_header_keeps_relics_and_intensity_tight() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for relic/intensity HUD layout coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var relic_ids: Array = [
		"iron_lung",
		"ember_lens",
		"pilgrim_boots",
		"mirror_shard",
		"coffin_nails",
		"reinforced_shield",
		"iron_buckler",
		"flint_edge",
		"phoenix_ember",
		"thornmail_brooch",
		"ion_spool",
		"hourglass_awl"
	]
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(15126, _simple_room_layout(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["quick_stab"],
		"relics": relic_ids,
		"hand_size": 1,
		"heal_bonus": 0
	})
	combat_state["relics"] = relic_ids
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["relics"] = relic_ids
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	_set_run_scene_combat_state_for_test(instance, combat_state)
	instance.call("_refresh_ui")
	await process_frame
	await process_frame
	var relic_bar: VBoxContainer = instance.get_node("UiLayer/UiRoot/RelicBar")
	var relic_grid: GridContainer = instance.get("_relic_icon_grid") as GridContainer
	_assert(relic_bar.visible and relic_grid != null and relic_grid.get_child_count() == relic_ids.size(), "Relic HUD should render all owned relic icons")
	if relic_grid != null and relic_grid.get_child_count() == relic_ids.size():
		var first_row_y: float = (relic_grid.get_child(0) as Control).global_position.y
		var first_row_x: float = (relic_grid.get_child(0) as Control).global_position.x
		_assert(absf(first_row_x - relic_bar.global_position.x) <= 1.0, "The relic block should stay flush with the HUD's screen-left edge even when Defiance precedes Abilities")
		for index: int in range(relic_grid.get_child_count()):
			var child_control: Control = relic_grid.get_child(index) as Control
			if index < 5:
				_assert(child_control != null and absf(child_control.global_position.y - first_row_y) <= 1.0, "The first five relic HUD icons should stay on one horizontal row")
			else:
				_assert(child_control != null and child_control.global_position.y > first_row_y, "Relics beyond five should wrap onto a lower line")
			if index % 5 == 0:
				_assert(child_control != null and absf(child_control.global_position.x - first_row_x) <= 1.0, "Every wrapped relic line should share the first line's left edge")
		var first_row_end: float = (relic_grid.get_child(4) as Control).get_global_rect().end.x
		_assert(absf((first_row_end - first_row_x) - ElementalIntensityHudArt.CLUSTER_SIZE.x) <= 12.0, "Five relics should occupy approximately the elemental intensity widget width")
	var intensity_bar: Control = instance.get("_intensity_bar") as Control
	_assert(intensity_bar != null and intensity_bar.visible, "Combat should show the elemental intensity HUD")
	var intensity_badges: Dictionary = instance.get("_intensity_badges") as Dictionary
	if intensity_bar != null and not intensity_badges.is_empty():
		var first_badge: Control = intensity_badges.get(ElementData.FIRE, null)
		_assert(first_badge.custom_minimum_size.x <= 76.0 and first_badge.custom_minimum_size.y <= 110.0, "Hanging elemental charms should stay compact in the top-left utility lane")
		_assert(intensity_badges.size() == 5, "Combat intensity HUD should show only the five elements")
		_assert(intensity_bar.find_child("AuthoredRailAndChains", false, false) is TextureRect, "Elemental intensity HUD should use the authored rail-and-chains raster")
		var charm_paths: Dictionary = {}
		for element_id: String in ElementData.all_elements():
			var badge: PanelContainer = intensity_badges.get(element_id, null)
			var charm_path: String = str(badge.get_meta("charm_art_path", "")) if badge != null else ""
			_assert(badge != null and badge.get_theme_stylebox("panel") is StyleBoxEmpty, "%s intensity charm should not sit in a generic panel box" % element_id)
			_assert(not charm_path.is_empty() and not charm_paths.has(charm_path), "%s intensity charm should use a distinct authored silhouette" % element_id)
			charm_paths[charm_path] = true
			var placard: TextureRect = badge.find_child("AuthoredNumberPlacard", true, false) as TextureRect
			var value_label: Label = (instance.get("_intensity_labels") as Dictionary).get(element_id, null)
			_assert(placard != null and placard.size.x <= placard.size.y, "%s intensity charm should carry a compact single-digit placard" % element_id)
			_assert(value_label != null and value_label.clip_text and Rect2(placard.position, placard.size).encloses(Rect2(value_label.position, value_label.size)), "%s intensity value should remain contained by its placard" % element_id)
			_assert(absf(ElementalIntensityHudArt.charm_attachment_x(element_id) - ElementalIntensityHudArt.chain_endpoint_x(element_id)) <= 0.5, "%s intensity charm should align with its authored chain" % element_id)
		var top_y: float = first_badge.position.y
		var second_row_y: float = (intensity_badges.get(ElementData.AIR, null) as Control).position.y
		for element_id: String in [ElementData.FIRE, ElementData.ICE, ElementData.LIGHTNING]:
			var badge: Control = intensity_badges.get(element_id, null)
			_assert(absf(badge.position.y - top_y) <= 1.0, "Elemental intensity HUD should keep the first three icons on the top row")
		for element_id: String in [ElementData.AIR, ElementData.EARTH]:
			var badge: Control = intensity_badges.get(element_id, null)
			_assert(absf(badge.position.y - second_row_y) <= 1.0, "Elemental intensity HUD should keep the final two icons on the second row")
		var top_middle: Control = intensity_badges.get(ElementData.ICE, null)
		var bottom_left: Control = intensity_badges.get(ElementData.AIR, null)
		var bottom_right: Control = intensity_badges.get(ElementData.EARTH, null)
		var top_middle_center: float = top_middle.position.x + top_middle.size.x * 0.5
		var bottom_pair_center: float = (bottom_left.position.x + bottom_right.position.x + bottom_right.size.x) * 0.5
		_assert(absf(top_middle_center - bottom_pair_center) <= 1.0, "Room-pressure HUD second row should be centered under the top row")
		var relic_block_bottom: float = float(instance.call("_relic_bar_visible_bottom_y"))
		var gap: float = intensity_bar.global_position.y - relic_block_bottom
		_assert(gap >= 0.0 and gap <= 5.0, "Elemental intensity HUD should sit directly under the complete relic block without a stale layout gap")
		_assert(absf(intensity_bar.global_position.x - relic_grid.global_position.x) <= 1.0, "Relics and elemental intensity should share the same screen-left edge")
		if relic_grid != null:
			for index: int in range(relic_grid.get_child_count()):
				var relic_icon: Control = relic_grid.get_child(index) as Control
				_assert(not relic_icon.get_global_rect().intersects(intensity_bar.get_global_rect()), "The relic block should remain completely above the elemental intensity widget")
	# A new run reuses this RunScene. Clearing a crowded relic inventory must also
	# clear its layout footprint immediately instead of retaining the prior run's
	# lower intensity position until the client restarts.
	var relic_heavy_intensity_y: float = intensity_bar.global_position.y
	var next_run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	var next_combat_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	next_run_state["relics"] = []
	next_combat_state["relics"] = []
	next_run_state["combat_state"] = next_combat_state.duplicate(true)
	instance.set("_run_state", next_run_state)
	_set_run_scene_combat_state_for_test(instance, next_combat_state)
	instance.call("_refresh_ui")
	await process_frame
	await process_frame
	var expected_zero_relic_y: float = (instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/TitleBox/RoomSubtitle") as Control).get_global_rect().end.y + 2.0
	_assert(not relic_bar.visible and relic_grid.get_child_count() == 0, "A new zero-relic run should clear and hide the prior run's relic HUD")
	_assert(intensity_bar.global_position.y < relic_heavy_intensity_y, "A new zero-relic run should move elemental intensity back above its prior crowded position")
	_assert(absf(intensity_bar.global_position.y - expected_zero_relic_y) <= 1.0, "A new zero-relic run should restore elemental intensity directly below the compact header (actual=%.1f expected=%.1f)" % [intensity_bar.global_position.y, expected_zero_relic_y])
	instance.queue_free()
	await process_frame

func _test_run_scene_attack_impact_presentation_drops_projectile_effect() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for attack impact presentation coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var impact_presentation: Dictionary = instance.call("_attack_impact_presentation", {
		"focus_actor_keys": ["player"],
		"focus_tiles": [Vector2i(5, 2)],
		"effect": {"kind": "ranged", "from": Vector2i(2, 4), "to": Vector2i(5, 2)},
		"effect_progress": 1.0,
		"impact_actor_keys": ["enemy_1"],
		"floating_texts": [{"tile": Vector2i(5, 2), "text": "-4"}]
	})
	_assert(not impact_presentation.has("effect"), "Attack impact presentation should not keep a completed projectile effect while redraw-driven impact text animates")
	_assert(not impact_presentation.has("effect_progress"), "Attack impact presentation should clear completed effect progress during impact text")
	_assert((impact_presentation.get("impact_actor_keys", []) as Array).has("enemy_1"), "Attack impact presentation should preserve hit flash actors")
	_assert((impact_presentation.get("floating_texts", []) as Array).size() == 1, "Attack impact presentation should preserve floating combat text")
	instance.queue_free()
	await process_frame

func _test_run_scene_auto_triggers_starting_npc_dialogue() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for NPC dialogue coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var dialogue_active: bool = bool(instance.get("_dialogue_active"))
	var speaker_label: Label = instance.get("_dialogue_name_label")
	var text_label: RichTextLabel = instance.get("_dialogue_text_label")
	var dialogue_dialog: PanelContainer = instance.get("_dialogue_dialog")
	var dialogue_footer: HBoxContainer = instance.get("_dialogue_footer")
	_assert(dialogue_active, "Starting in the waypoint should auto-trigger the friendly NPC dialogue")
	_assert(speaker_label != null and speaker_label.text == "Emaciated Man", "The start-room dialogue should identify the Emaciated Man as the speaker")
	_assert(text_label != null and text_label.text == "Hehehe. You're back...so soon.", "The opening NPC line should match the scripted default dialogue")
	_assert(dialogue_dialog != null and dialogue_dialog.custom_minimum_size.x <= 1200.0, "The opening NPC dialogue should stay narrower than the full viewport")
	_assert(dialogue_dialog != null and dialogue_dialog.custom_minimum_size.y <= 160.0, "The opening NPC dialogue should use a compact spoken-line panel")
	_assert(dialogue_footer != null and dialogue_footer.custom_minimum_size.y <= 40.0, "The opening NPC dialogue should not reserve choice-button height for a hint-only footer")
	instance.call("_complete_current_dialogue_line")
	instance.call("_advance_dialogue")
	_assert(int(instance.get("_dialogue_line_index")) == 1, "Advancing after the first line should move to the second line")
	_assert(text_label != null and text_label.text == "His creations got the best of you again.", "The second NPC line should preserve its trailing period")
	instance.call("_complete_current_dialogue_line")
	instance.call("_advance_dialogue")
	_assert(text_label != null and text_label.text == "Maybe this time's the one. Then again...probably not.", "The final NPC line should preserve its trailing period")
	instance.call("_complete_current_dialogue_line")
	instance.call("_advance_dialogue")
	_assert(not bool(instance.get("_dialogue_active")), "Advancing after the last NPC line should close the dialogue overlay")
	var first_run_progression: Dictionary = ProgressionStore.prepare_for_new_run(ProgressionStore.default_data())
	first_run_progression = ProgressionStore.record_first_umbra_reach(first_run_progression, int(first_run_progression.get("run_counter", 0)))
	var next_run_progression: Dictionary = ProgressionStore.prepare_for_new_run(first_run_progression)
	var warning_run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	warning_run_state["run_index"] = int(next_run_progression.get("run_counter", 0))
	warning_run_state["progression"] = next_run_progression.duplicate(true)
	instance.set("_progression", next_run_progression)
	instance.set("_run_state", warning_run_state)
	instance.set("_last_auto_dialogue_key", "")
	instance.call("_refresh_ui")
	_assert(bool(instance.get("_dialogue_active")), "A run after the first Umbra reach should auto-trigger the Emaciated Man's warning")
	_assert(text_label != null and text_label.text.contains("[i]his[/i] shadow"), "The opening warning line should render his with italic BBCode")
	for _line_index: int in range(3):
		instance.call("_complete_current_dialogue_line")
		instance.call("_advance_dialogue")
	_assert(not bool(instance.get("_dialogue_active")), "Advancing through the Umbra warning should close the dialogue overlay")
	var consumed_progression: Dictionary = instance.get("_progression") as Dictionary
	_assert(bool(consumed_progression.get(ProgressionStore.UMBRA_WARNING_SEEN_KEY, false)), "Closing the Umbra warning should persist its one-time seen marker")
	instance.queue_free()
	await process_frame

func _test_run_scene_character_stats_overlay_opens() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for character stats UI coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var progression: Dictionary = ProgressionStore.add_embers(
		ProgressionStore.default_data(),
		180
	)
	var run_state: Dictionary = instance.get("_run_state")
	run_state["progression"] = progression
	run_state["held_embers"] = 180
	run_state["unbanked_embers"] = 180
	instance.set("_run_state", run_state)
	instance.set("_progression", progression)
	instance.call("_close_dialogue")
	var loadout_button: Button = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/LoadoutButton") as Button
	var loadout_badge: PanelContainer = instance.get("_loadout_badge") as PanelContainer
	var loadout_badge_label: Label = instance.get("_loadout_badge_label") as Label
	_assert(loadout_button != null and loadout_button.icon != null, "The top-right HUD should expose an icon-only character loadout button")
	_assert(loadout_button.tooltip_text == "Character Loadout", "The loadout header button should identify its destination")
	run_state["equipment_inventory"] = ["ward_kite"]
	var notification_collected_equipment: Array = (run_state.get("collected_equipment", []) as Array).duplicate()
	if not notification_collected_equipment.has("ward_kite"):
		notification_collected_equipment.append("ward_kite")
	run_state["collected_equipment"] = notification_collected_equipment
	run_state["magic_inventory"] = ["spark_dart"]
	run_state[RunEngine.UNREAD_LOADOUT_EQUIPMENT_KEY] = ["ward_kite"]
	run_state[RunEngine.UNREAD_LOADOUT_MAGIC_KEY] = ["spark_dart"]
	run_state[RunEngine.NEW_LOADOUT_EQUIPMENT_KEY] = ["ward_kite"]
	run_state[RunEngine.NEW_LOADOUT_MAGIC_KEY] = ["spark_dart"]
	instance.set("_run_state", run_state)
	instance.call("_refresh_loadout_badge")
	_assert(loadout_badge != null and loadout_badge.visible, "New gear or magic should show a loadout notification badge")
	_assert(loadout_badge_label != null and loadout_badge_label.text == "2", "The loadout badge should count unseen gear and magic")
	instance.call("_on_loadout_button_pressed")
	await process_frame
	_assert(str(instance.get("_progression_overlay_mode")) == "equipment", "The loadout button should prioritize the unread Gear tab")
	var gear_seen_state: Dictionary = instance.get("_run_state")
	_assert((gear_seen_state.get(RunEngine.UNREAD_LOADOUT_EQUIPMENT_KEY, []) as Array).is_empty(), "Opening Gear should clear new equipment notifications")
	_assert((gear_seen_state.get(RunEngine.UNREAD_LOADOUT_MAGIC_KEY, []) as Array) == ["spark_dart"], "Opening Gear should preserve unseen Magic notifications")
	_assert((gear_seen_state.get(RunEngine.NEW_LOADOUT_EQUIPMENT_KEY, []) as Array) == ["ward_kite"], "Opening Gear should preserve the new gear's item-level tag")
	_assert(loadout_badge.visible and loadout_badge_label.text == "1", "The loadout badge should remain for an unseen spell")
	var gear_new_tag: Control = (instance.get("_upgrade_scrim") as Node).find_child("LoadoutNewTag", true, false) as Control
	_assert(gear_new_tag != null and str(gear_new_tag.get_meta("asset_id", "")) == "ward_kite", "New equipment should show a NEW tag in the Gear inventory")
	instance.call("_on_loadout_asset_hovered", "equipment", "ward_kite")
	_assert(not ((instance.get("_run_state") as Dictionary).get(RunEngine.NEW_LOADOUT_EQUIPMENT_KEY, []) as Array).has("ward_kite"), "Hovering new equipment should clear its persistent NEW state")
	_assert(gear_new_tag != null and not gear_new_tag.visible, "Hovering new equipment should immediately hide its NEW tag")
	var unread_magic_tab: Button = _button_with_text(instance.get("_upgrade_scrim") as Node, "Magic")
	_assert(unread_magic_tab != null and unread_magic_tab.find_child("MagicLoadoutTabBadge", true, false) != null, "The unopened Magic tab should show its own notification badge")
	instance.call("_close_card_upgrade_overlay")
	instance.call("_on_loadout_button_pressed")
	await process_frame
	_assert(str(instance.get("_progression_overlay_mode")) == "magic", "The loadout button should route directly to Magic when only spells are unseen")
	_assert(not loadout_badge.visible, "Opening Magic should clear the final loadout notification")
	var magic_new_tag: Control = (instance.get("_upgrade_scrim") as Node).find_child("LoadoutNewTag", true, false) as Control
	_assert(magic_new_tag != null and str(magic_new_tag.get_meta("asset_id", "")) == "spark_dart", "New spells should show a NEW tag in Learned Magic")
	instance.call("_on_loadout_asset_hovered", "magic", "spark_dart")
	_assert(not ((instance.get("_run_state") as Dictionary).get(RunEngine.NEW_LOADOUT_MAGIC_KEY, []) as Array).has("spark_dart"), "Hovering a new spell should clear its persistent NEW state")
	_assert(magic_new_tag != null and not magic_new_tag.visible, "Hovering a new spell should immediately hide its NEW tag")
	instance.call("_close_card_upgrade_overlay")
	instance.call("_open_card_upgrade_overlay")
	await process_frame
	var upgrade_scrim: ColorRect = instance.get("_upgrade_scrim")
	var character_dialog: PanelContainer = instance.get("_upgrade_dialog")
	var stats_dialog_size: Vector2 = character_dialog.custom_minimum_size if character_dialog != null else Vector2.ZERO
	var stats_dialog_actual_size: Vector2 = character_dialog.size if character_dialog != null else Vector2.ZERO
	if character_dialog != null:
		var character_viewport: Vector2 = instance.get_viewport_rect().size
		_assert(character_dialog.custom_minimum_size.x <= character_viewport.x - UiTypography.SAFE_MARGIN * 2.0 and character_dialog.custom_minimum_size.y <= character_viewport.y - UiTypography.SAFE_MARGIN * 2.0, "Character dialog should preserve safe viewport margins")
	_assert(upgrade_scrim != null and upgrade_scrim.visible, "Opening the character menu should show the Skills overlay")
	_assert(upgrade_scrim.z_index >= 1200 and not upgrade_scrim.z_as_relative, "The character overlay should render above combat hand cards")
	_assert(_label_with_text(upgrade_scrim, "Character") != null, "The character overlay should use the Character title")
	var level_resource: Label = upgrade_scrim.find_child("ProgressionLevelLabel", true, false) as Label
	var point_resource: Label = upgrade_scrim.find_child("ProgressionSkillPointsLabel", true, false) as Label
	var moltshard_resource: Label = upgrade_scrim.find_child("ProgressionMoltshardsLabel", true, false) as Label
	_assert(level_resource != null and level_resource.text == "LEVEL  1", "The character overlay should prominently show progression level")
	_assert(point_resource != null and point_resource.text == "POINTS  0", "The character overlay should prominently show banked skill points")
	_assert(moltshard_resource != null and moltshard_resource.text == "MOLTSHARDS  0", "The character overlay should prominently show reset resources")
	_assert(upgrade_scrim.find_child("CharacterSkillTree", true, false) != null, "The character overlay should render the data-driven skill tree")
	_assert(_label_with_text(upgrade_scrim, "Quick Wits") != null, "The skill tree should show its root abilities")
	_assert(_label_with_text(upgrade_scrim, "Might") == null and _label_with_text(upgrade_scrim, "Fire Magick") == null, "The Skills overlay should not expose retired stat allocation rows")
	instance.call("_switch_character_overlay_mode", "equipment")
	await process_frame
	_assert(character_dialog != null and character_dialog.custom_minimum_size == stats_dialog_size, "Switching from Skills to Gear should keep the character dialog size stable")
	var character_body_frame: Control = character_dialog.find_child("CharacterBodyFrame", true, false) as Control if character_dialog != null else null
	var gear_body_rect: Rect2 = character_body_frame.get_global_rect().grow(1.0) if character_body_frame != null else Rect2()
	_assert(character_body_frame != null, "The character menu should provide a fixed body frame for every tab")
	for panel_name: String in ["EquipmentLoadoutPanel", "EquipmentInventoryPanel", "CurrentDeckPanel"]:
		var gear_panel: Control = character_body_frame.find_child(panel_name, true, false) as Control if character_body_frame != null else null
		_assert(gear_panel != null and gear_body_rect.encloses(gear_panel.get_global_rect()), "The Gear %s should fit inside the fixed character body" % panel_name)
	_assert(character_body_frame != null and character_body_frame.find_child("EquipmentLoadoutScroll", true, false) is ScrollContainer, "The Gear loadout should scroll internally instead of stretching the character body")
	_assert(_button_with_text(upgrade_scrim, "Gear") != null, "The character menu should expose a Gear tab")
	_assert(_button_with_text(upgrade_scrim, "Magic") != null, "The character menu should expose a Magic tab")
	_assert(_button_with_text(upgrade_scrim, "Skills") != null, "The character menu should expose a Skills tab")
	_assert(_button_with_text(upgrade_scrim, "Stats") == null, "The character menu should not expose the retired Stats tab")
	_assert(_label_with_text(upgrade_scrim, "Loadout") != null, "The gear overlay should show equipped slots")
	_assert(_label_with_text(upgrade_scrim, "Inventory") != null, "The gear overlay should show inventory")
	_assert(_label_with_text(upgrade_scrim, "Deck") != null, "The gear overlay should show deck cards")
	_assert(_label_with_text(upgrade_scrim, "Attuned Magic 6/6") != null, "The gear overlay should include active attuned magic in the current deck")
	_assert(_label_with_text(upgrade_scrim, "Rewards") == null, "The gear overlay should not use the old Rewards deck heading")
	_assert(_label_with_text(upgrade_scrim, "Pale Spark") != null, "The gear overlay should show default attuned magic cards")
	var equipment_art: TextureRect = upgrade_scrim.find_child("EquipmentCharacterArt", true, false) as TextureRect
	_assert(equipment_art != null and equipment_art.texture != null, "The gear overlay should keep protagonist art visible")
	_assert(character_dialog != null and character_dialog.size == stats_dialog_actual_size, "Switching from Skills to Gear should keep the visible character dialog size stable")
	_assert(_label_with_text(upgrade_scrim, "Quick Stab, +2") == null, "Equipped loadout slots should not show a granted-card summary subline")
	var gear_run_state: Dictionary = instance.get("_run_state")
	var collected_equipment: Array = (gear_run_state.get("collected_equipment", []) as Array).duplicate()
	if not collected_equipment.has("iron_cleaver"):
		collected_equipment.append("iron_cleaver")
	gear_run_state["equipment_inventory"] = ["iron_cleaver"]
	gear_run_state["collected_equipment"] = collected_equipment
	gear_run_state["reward_cards"] = ["spark_dart", "frostbolt", "firebrand_volley", "chain_bolt", "static_lash"]
	gear_run_state["attuned_magic_cards"] = ["spark_dart", "frostbolt", "firebrand_volley", "chain_bolt", "pale_spark", "pale_spark"]
	gear_run_state["magic_inventory"] = ["static_lash"]
	gear_run_state["item_inventory"] = ["crimson_draught", "nail_bomb"]
	gear_run_state["equipped_items"] = []
	instance.set("_run_state", gear_run_state)
	instance.call("_rebuild_progression_overlay")
	_assert(_label_with_text(upgrade_scrim, "Iron Cleaver") != null, "The gear overlay should render carried equipment")
	_assert(_label_with_text(upgrade_scrim, "Crimson Draught") != null, "The gear overlay should render carried consumable items")
	_assert(_label_with_text(upgrade_scrim, "Items 0/2") != null, "The gear overlay deck should show item loadout capacity")
	_assert(_label_with_text(upgrade_scrim, "Learned Magic") == null, "The gear overlay should not show the magic reserve panel")
	_assert(_label_with_text(upgrade_scrim, "Static Lash") == null, "The gear overlay deck should not show inactive reserve magic")
	_assert((instance.get("_magic_inventory_tiles") as Dictionary).is_empty(), "The gear overlay should not create reserve magic drag targets")
	_assert((instance.get("_magic_attuned_tiles") as Dictionary).is_empty(), "The gear overlay should not create attuned magic drag targets")
	_assert(upgrade_scrim.find_child("EquipmentLoadoutList", true, false) != null, "The gear overlay should keep the left loadout in its scrollable panel list")
	var item_inventory_tiles: Dictionary = instance.get("_item_inventory_tiles")
	var item_equipped_tiles: Dictionary = instance.get("_item_equipped_tiles")
	var item_tile: Control = item_inventory_tiles.get(0, null) as Control
	_assert(item_tile != null and item_tile.tooltip_text == "card:crimson_draught", "Item inventory tiles should own card-preview tooltips")
	var item_art_chip: Control = item_tile.find_child("ItemCardArtChip", true, false) as Control if item_tile != null else null
	_assert(item_art_chip != null and item_art_chip.find_child("ItemCardArtIcon", true, false) is TextureRect, "Item inventory tiles should use cropped card art as an icon")
	_assert(item_art_chip != null and item_art_chip.find_child("CardBadgeName", true, false) == null, "Item art chips should not overlay two-letter text labels")
	_assert(item_tile != null and _button_with_text(item_tile, "Equip") == null and _button_with_text(item_tile, "Stow") == null, "Item tiles should use drag/drop instead of equip or stow buttons")
	var item_tile_tooltip: Control = item_tile.call("_make_custom_tooltip", item_tile.tooltip_text) as Control if item_tile != null else null
	if item_tile_tooltip != null:
		root.add_child(item_tile_tooltip)
		await process_frame
		_assert(_card_widget_count_under(item_tile_tooltip) == 1, "Item inventory hover should show a real CardWidget preview")
		item_tile_tooltip.queue_free()
	else:
		_failures.append("Item inventory hover should show a real CardWidget preview")
	var item_target_slot: Control = item_equipped_tiles.get(0, null) as Control
	var item_press := InputEventMouseButton.new()
	item_press.button_index = MOUSE_BUTTON_LEFT
	item_press.pressed = true
	item_press.position = item_tile.get_global_rect().get_center() if item_tile != null else Vector2.ZERO
	item_press.global_position = item_press.position
	if item_tile != null:
		item_tile.call("_gui_input", item_press)
	await process_frame
	_assert(str(instance.get("_item_drag_card_id")) == "crimson_draught", "Pressing an item inventory tile should start a visible item drag")
	var item_drop_position: Vector2 = item_target_slot.get_global_rect().get_center() if item_target_slot != null else Vector2.ZERO
	instance.call("_update_item_overlay_drag", item_drop_position)
	instance.call("_release_item_overlay_drag", item_drop_position)
	await process_frame
	await process_frame
	await create_timer(0.20).timeout
	var item_equipped_state: Dictionary = instance.get("_run_state")
	_assert((item_equipped_state.get("equipped_items", []) as Array).has("crimson_draught"), "Dragging from item inventory to an item slot should equip the item")
	_assert((item_equipped_state.get("deck_cards", []) as Array).has("crimson_draught"), "Equipped item cards should enter the active deck from the overlay")
	_assert(not (item_equipped_state.get("item_inventory", []) as Array).has("crimson_draught"), "Dragging from item inventory should remove that copy from item inventory")
	item_equipped_tiles = instance.get("_item_equipped_tiles")
	var equipped_item_tile: Control = item_equipped_tiles.get(0, null) as Control
	var stow_press := InputEventMouseButton.new()
	stow_press.button_index = MOUSE_BUTTON_LEFT
	stow_press.pressed = true
	stow_press.position = equipped_item_tile.get_global_rect().get_center() if equipped_item_tile != null else Vector2.ZERO
	stow_press.global_position = stow_press.position
	if equipped_item_tile != null:
		equipped_item_tile.call("_gui_input", stow_press)
	await process_frame
	var item_inventory_panel: Control = instance.get("_item_inventory_drop_panel") as Control
	var stow_position: Vector2 = item_inventory_panel.get_global_rect().get_center() if item_inventory_panel != null else Vector2.ZERO
	instance.call("_update_item_overlay_drag", stow_position)
	instance.call("_release_item_overlay_drag", stow_position)
	await process_frame
	await process_frame
	await create_timer(0.20).timeout
	var item_stowed_state: Dictionary = instance.get("_run_state")
	_assert(not (item_stowed_state.get("equipped_items", []) as Array).has("crimson_draught"), "Dragging an equipped item to inventory should empty the item loadout")
	_assert((item_stowed_state.get("item_inventory", []) as Array).has("crimson_draught"), "Dragging an equipped item to inventory should return the item to inventory")
	_assert(not (item_stowed_state.get("deck_cards", []) as Array).has("crimson_draught"), "Dragging an equipped item out should remove the item card from the active deck")
	instance.call("_switch_character_overlay_mode", "magic")
	await process_frame
	_assert(character_dialog != null and character_dialog.custom_minimum_size == stats_dialog_size, "Switching from Gear to Magic should keep the character dialog size stable")
	_assert(character_dialog != null and character_dialog.size == stats_dialog_actual_size, "Switching from Gear to Magic should keep the visible character dialog size stable")
	_assert(_label_with_text(upgrade_scrim, "Attuned Magic") != null, "The magic overlay should show attuned spell slots")
	_assert(_label_with_text(upgrade_scrim, "Learned Magic") != null, "The magic overlay should show learned reserve spells")
	_assert(_label_with_text(upgrade_scrim, "Deck") != null, "The magic overlay should show the current deck")
	_assert(_label_with_text(upgrade_scrim, "Static Lash") != null, "The magic overlay should render reserve magic cards")
	var magic_inventory_tiles: Dictionary = instance.get("_magic_inventory_tiles")
	var magic_attuned_tiles: Dictionary = instance.get("_magic_attuned_tiles")
	var reserve_tile: Control = magic_inventory_tiles.get(0, null) as Control
	var attuned_tile: Control = magic_attuned_tiles.get(4, null) as Control
	_assert(reserve_tile != null and _control_descendants_ignore_mouse(reserve_tile), "Reserve magic card tile children should be passive for stable hover and drag")
	_assert(attuned_tile != null and _control_descendants_ignore_mouse(attuned_tile), "Attuned magic card tile children should be passive for stable hover and drag")
	_assert(reserve_tile != null and reserve_tile.find_child("CardBadgeArt", true, false) is TextureRect, "Reserve magic card tiles should use card art as their visual background")
	_assert(attuned_tile != null and attuned_tile.find_child("CardBadgeArt", true, false) is TextureRect, "Attuned magic card tiles should use card art as their visual background")
	var magic_press := InputEventMouseButton.new()
	magic_press.button_index = MOUSE_BUTTON_LEFT
	magic_press.pressed = true
	magic_press.position = reserve_tile.get_global_rect().get_center() if reserve_tile != null else Vector2.ZERO
	magic_press.global_position = magic_press.position
	if reserve_tile != null:
		reserve_tile.call("_gui_input", magic_press)
	await process_frame
	_assert(str(instance.get("_magic_drag_card_id")) == "static_lash", "Pressing a learned magic tile should start a visible magic drag")
	var magic_release := InputEventMouseButton.new()
	magic_release.button_index = MOUSE_BUTTON_LEFT
	magic_release.pressed = false
	magic_release.position = attuned_tile.get_global_rect().get_center() if attuned_tile != null else Vector2.ZERO
	magic_release.global_position = magic_release.position
	if attuned_tile != null:
		attuned_tile.call("_gui_input", magic_release)
	await process_frame
	await process_frame
	await create_timer(0.20).timeout
	var magic_state: Dictionary = instance.get("_run_state")
	_assert(str((magic_state.get("attuned_magic_cards", []) as Array)[4]) == "static_lash", "Swapping from the magic overlay should attune reserve magic into late default slots")
	_assert((magic_state.get("magic_inventory", []) as Array).has("pale_spark"), "Swapping from the magic overlay should move replaced default magic to reserve")
	_assert((magic_state.get("deck_cards", []) as Array).has("static_lash"), "Swapping from the magic overlay should rebuild the active deck with attuned magic")
	magic_state["attuned_magic_cards"] = ["spark_dart", "frostbolt", "firebrand_volley", "chain_bolt", "pale_spark", "pale_spark"]
	magic_state["magic_inventory"] = ["static_lash"]
	instance.set("_run_state", magic_state)
	instance.call("_rebuild_progression_overlay")
	await process_frame
	magic_inventory_tiles = instance.get("_magic_inventory_tiles")
	magic_attuned_tiles = instance.get("_magic_attuned_tiles")
	reserve_tile = magic_inventory_tiles.get(0, null) as Control
	attuned_tile = magic_attuned_tiles.get(4, null) as Control
	if reserve_tile != null:
		magic_press.position = reserve_tile.get_global_rect().get_center()
		magic_press.global_position = magic_press.position
		reserve_tile.call("_gui_input", magic_press)
	await process_frame
	var double_release_position: Vector2 = attuned_tile.get_global_rect().get_center() if attuned_tile != null else Vector2.ZERO
	instance.call("_update_magic_overlay_drag", double_release_position)
	instance.call("_release_magic_overlay_drag", double_release_position)
	instance.call("_release_magic_overlay_drag", double_release_position)
	await process_frame
	await create_timer(0.30).timeout
	magic_state = instance.get("_run_state")
	_assert(str((magic_state.get("attuned_magic_cards", []) as Array)[4]) == "static_lash", "Duplicate magic release events should not swap the same spells back")
	_assert((magic_state.get("magic_inventory", []) as Array).has("pale_spark"), "Duplicate magic release events should leave the replaced default in learned magic")
	magic_state["attuned_magic_cards"] = ["spark_dart", "frostbolt", "firebrand_volley", "chain_bolt", "pale_spark", "pale_spark"]
	magic_state["magic_inventory"] = ["static_lash"]
	instance.set("_run_state", magic_state)
	instance.call("_rebuild_progression_overlay")
	await process_frame
	magic_inventory_tiles = instance.get("_magic_inventory_tiles")
	magic_attuned_tiles = instance.get("_magic_attuned_tiles")
	reserve_tile = magic_inventory_tiles.get(0, null) as Control
	attuned_tile = magic_attuned_tiles.get(4, null) as Control
	var overlap_press := InputEventMouseButton.new()
	overlap_press.button_index = MOUSE_BUTTON_LEFT
	overlap_press.pressed = true
	overlap_press.position = reserve_tile.get_global_rect().get_center() if reserve_tile != null else Vector2.ZERO
	overlap_press.global_position = overlap_press.position
	if reserve_tile != null:
		reserve_tile.call("_gui_input", overlap_press)
	await process_frame
	var off_target_release_position: Vector2 = Vector2.ZERO
	if attuned_tile != null:
		var attuned_rect: Rect2 = attuned_tile.get_global_rect()
		off_target_release_position = attuned_rect.position + Vector2(-16.0, attuned_rect.size.y * 0.5)
	instance.call("_update_magic_overlay_drag", off_target_release_position)
	await process_frame
	_assert(instance.call("_magic_tile_at", off_target_release_position).is_empty(), "The off-target magic release fixture should put the cursor outside the target tile")
	instance.call("_release_magic_overlay_drag", off_target_release_position)
	await process_frame
	await process_frame
	await create_timer(0.20).timeout
	magic_state = instance.get("_run_state")
	_assert(str((magic_state.get("attuned_magic_cards", []) as Array)[4]) == "static_lash", "Magic drop should resolve by held-card overlap when the cursor is just outside the target slot")
	magic_state["attuned_magic_cards"] = ["spark_dart", "frostbolt", "firebrand_volley", "chain_bolt", "pale_spark", "pale_spark"]
	magic_state["magic_inventory"] = ["static_lash"]
	instance.set("_run_state", magic_state)
	instance.call("_rebuild_progression_overlay")
	await process_frame
	magic_inventory_tiles = instance.get("_magic_inventory_tiles")
	magic_attuned_tiles = instance.get("_magic_attuned_tiles")
	reserve_tile = magic_inventory_tiles.get(0, null) as Control
	attuned_tile = magic_attuned_tiles.get(4, null) as Control
	var attuned_press := InputEventMouseButton.new()
	attuned_press.button_index = MOUSE_BUTTON_LEFT
	attuned_press.pressed = true
	attuned_press.position = attuned_tile.get_global_rect().get_center() if attuned_tile != null else Vector2.ZERO
	attuned_press.global_position = attuned_press.position
	if attuned_tile != null:
		attuned_tile.call("_gui_input", attuned_press)
	await process_frame
	var inventory_panel: Control = instance.get("_magic_inventory_drop_panel") as Control
	var panel_release_position: Vector2 = Vector2.ZERO
	if inventory_panel != null:
		var inventory_panel_rect: Rect2 = inventory_panel.get_global_rect()
		panel_release_position = inventory_panel_rect.position + Vector2(inventory_panel_rect.size.x * 0.52, inventory_panel_rect.size.y * 0.58)
	instance.call("_update_magic_overlay_drag", panel_release_position)
	await process_frame
	_assert(instance.call("_magic_tile_at", panel_release_position).is_empty(), "The magic panel release fixture should put the cursor in learned-panel whitespace")
	instance.call("_release_magic_overlay_drag", panel_release_position)
	await process_frame
	await process_frame
	await create_timer(0.20).timeout
	magic_state = instance.get("_run_state")
	_assert(str((magic_state.get("attuned_magic_cards", []) as Array)[4]) == "static_lash", "Dragging an attuned spell into learned-panel whitespace should swap with the nearest learned magic")
	instance.call("_switch_character_overlay_mode", "equipment")
	await process_frame
	var source_rect: Rect2 = instance.call("_equipment_inventory_icon_rect", "iron_cleaver")
	var tile_map: Dictionary = instance.get("_equipment_inventory_tiles")
	var source_tile: Control = tile_map.get("iron_cleaver", null) as Control
	_assert(source_tile != null and _control_descendants_ignore_mouse(source_tile), "Equipment inventory tile children should be passive so icon and text share one hover/drag target")
	var source_icon_chip: Control = source_tile.find_child("EquipmentIconChip", true, false) as Control if source_tile != null else null
	_assert(source_icon_chip != null and source_icon_chip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Equipment inventory icon should be a passive part of the parent tile")
	_assert(source_icon_chip != null and source_icon_chip.tooltip_text.is_empty(), "Equipment inventory icon should not own a separate hover tooltip from its parent tile")
	_assert(source_icon_chip != null and absf(source_icon_chip.size.x - source_icon_chip.size.y) <= 1.0, "Equipment inventory icon should stay square inside the single drag tile")
	instance.call("_begin_equipment_overlay_drag", "iron_cleaver", source_rect, source_tile, source_rect.get_center())
	await process_frame
	var equipment_fx_layer: Control = instance.get("_equipment_fx_layer")
	var held_proxy: Control = null
	if equipment_fx_layer != null:
		held_proxy = equipment_fx_layer.find_child("EquipmentHeldProxy", true, false) as Control
	_assert(held_proxy != null and held_proxy.find_child("EquipmentGhostTexture", true, false) is TextureRect, "Equipment drag should show a lifted in-scene gear icon")
	_assert(held_proxy != null and held_proxy.modulate.a < 0.9, "Equipment drag icon should be translucent enough to read as held")
	_assert(source_tile == null or source_tile.modulate.a < 0.5, "Equipment drag should dim the source inventory tile")
	_assert(held_proxy != null and _label_with_text(held_proxy, "Iron Cleaver") == null, "Equipment held drag should be icon-first instead of a text plaque")
	instance.call("_cancel_equipment_overlay_drag", false)
	await process_frame
	var equipment_tooltip: Control = instance.call("_build_equipment_tooltip_panel", "iron_cleaver") as Control
	root.add_child(equipment_tooltip)
	await process_frame
	_assert(_card_widget_count_under(equipment_tooltip) == GameData.equipment_cards("iron_cleaver").size(), "Equipment hover should show real CardWidget previews for every granted card")
	for widget: CardWidget in _card_widgets_under(equipment_tooltip):
		_assert(widget.size.x > 0.0 and absf((widget.size.y / widget.size.x) - (352.0 / 250.0)) < 0.01, "Equipment tooltip card previews should preserve the real card aspect ratio")
	equipment_tooltip.queue_free()
	var merchant_equipment_row: Control = instance.call("_build_merchant_item_row", "blacksmith", "iron_cleaver", false) as Control
	if merchant_equipment_row != null:
		root.add_child(merchant_equipment_row)
	await process_frame
	_assert(merchant_equipment_row != null and merchant_equipment_row.tooltip_text == "equipment:iron_cleaver", "Blacksmith merchant rows should reuse the equipment tooltip trigger")
	var merchant_equipment_tooltip: Control = merchant_equipment_row.call("_make_custom_tooltip", merchant_equipment_row.tooltip_text) as Control if merchant_equipment_row != null else null
	if merchant_equipment_tooltip != null:
		root.add_child(merchant_equipment_tooltip)
		await process_frame
	_assert(_card_widget_count_under(merchant_equipment_tooltip) == GameData.equipment_cards("iron_cleaver").size(), "Blacksmith merchant hover should show real CardWidget previews for every granted equipment card")
	if merchant_equipment_tooltip != null:
		merchant_equipment_tooltip.queue_free()
	if merchant_equipment_row != null:
		merchant_equipment_row.queue_free()
	var merchant_magic_row: Control = instance.call("_build_merchant_item_row", "arcanist", "spark_dart", false) as Control
	if merchant_magic_row != null:
		root.add_child(merchant_magic_row)
		merchant_magic_row.position = Vector2(120.0, 180.0)
		merchant_magic_row.size = Vector2(520.0, 72.0)
	await process_frame
	_assert(merchant_magic_row != null and merchant_magic_row.tooltip_text == "card:spark_dart", "Arcanist merchant rows should reuse the card tooltip trigger")
	var merchant_magic_tooltip: Control = merchant_magic_row.call("_make_custom_tooltip", merchant_magic_row.tooltip_text) as Control if merchant_magic_row != null else null
	if merchant_magic_tooltip != null:
		root.add_child(merchant_magic_tooltip)
		await process_frame
		_assert(_card_widget_count_under(merchant_magic_tooltip) == 1, "Arcanist merchant hover should show a real CardWidget preview")
	else:
		_failures.append("Arcanist merchant hover should show a real CardWidget preview")
	if merchant_magic_tooltip != null:
		merchant_magic_tooltip.queue_free()
	var merchant_item_row: Control = instance.call("_build_merchant_item_row", "scavenger", "crimson_draught", false) as Control
	if merchant_item_row != null:
		root.add_child(merchant_item_row)
	await process_frame
	_assert(merchant_item_row != null and merchant_item_row.tooltip_text == "card:crimson_draught", "Scavenger merchant rows should reuse the card tooltip trigger")
	_assert(str(instance.call("_merchant_item_detail", "scavenger", "crimson_draught")).begins_with("Item | "), "Scavenger merchant details should identify item cards")
	var merchant_item_tooltip: Control = merchant_item_row.call("_make_custom_tooltip", merchant_item_row.tooltip_text) as Control if merchant_item_row != null else null
	if merchant_item_tooltip != null:
		root.add_child(merchant_item_tooltip)
		await process_frame
		_assert(_card_widget_count_under(merchant_item_tooltip) == 1, "Scavenger merchant hover should show a real CardWidget preview")
	else:
		_failures.append("Scavenger merchant hover should show a real CardWidget preview")
	if merchant_item_tooltip != null:
		merchant_item_tooltip.queue_free()
	if merchant_item_row != null:
		merchant_item_row.queue_free()
	if merchant_magic_row != null:
		var mouse_motion := InputEventMouseMotion.new()
		mouse_motion.position = Vector2(20.0, 7.0)
		mouse_motion.global_position = mouse_motion.position
		Input.parse_input_event(mouse_motion)
		await process_frame
		instance.call("_on_merchant_row_mouse_entered", "arcanist", "spark_dart", merchant_magic_row)
		var tooltip_text_before_pin: String = merchant_magic_row.tooltip_text
		var tooltip_mouse_anchor: Vector2 = instance.call("_current_mouse_position")
		_assert(tooltip_mouse_anchor.y > 40.0, "Pinned merchant tooltip test should use a non-clamped mouse anchor")
		var shift_event := InputEventKey.new()
		shift_event.keycode = KEY_SHIFT
		shift_event.physical_keycode = KEY_SHIFT
		shift_event.pressed = true
		instance.call("_input", shift_event)
		await process_frame
		var pinned_scrim: Control = instance.get("_pinned_tooltip_scrim")
		var pinned_panel: Control = instance.get("_pinned_tooltip_panel")
		_assert(pinned_scrim != null and pinned_scrim.visible, "Pressing Shift while hovering a merchant item should pin the item tooltip")
		_assert(merchant_magic_row.tooltip_text.is_empty(), "Pinned merchant tooltips should suppress the row's normal hover tooltip while focused")
		if pinned_panel != null:
			var expected_pin_position: Vector2 = tooltip_mouse_anchor + Vector2(12.0, 0.0)
			var viewport_size: Vector2 = instance.get_viewport_rect().size
			expected_pin_position.x = clampf(expected_pin_position.x, 10.0, maxf(10.0, viewport_size.x - pinned_panel.size.x - 10.0))
			expected_pin_position.y = clampf(expected_pin_position.y, 10.0, maxf(10.0, viewport_size.y - pinned_panel.size.y - 10.0))
			_assert(_card_widget_count_under(pinned_panel) == 1, "Pinned arcanist tooltip should keep the card preview focused")
			_assert(pinned_panel.global_position.distance_to(expected_pin_position) < 3.0, "Pinned merchant tooltip should stay where the hover preview appeared instead of jumping to a side panel")
			for widget: CardWidget in _card_widgets_under(pinned_panel):
				_assert(widget.mouse_filter == Control.MOUSE_FILTER_STOP, "Pinned merchant card previews should route hover to the real card widget for nested icon tooltips")
		else:
			_failures.append("Pinned arcanist tooltip should keep the card preview focused")
		var close_shift_event := InputEventKey.new()
		close_shift_event.keycode = KEY_SHIFT
		close_shift_event.physical_keycode = KEY_SHIFT
		close_shift_event.pressed = true
		instance.call("_input", close_shift_event)
		await process_frame
		_assert(pinned_scrim != null and not pinned_scrim.visible, "Pressing Shift again should close a pinned merchant tooltip")
		_assert(merchant_magic_row.tooltip_text == tooltip_text_before_pin, "Closing a pinned merchant tooltip should restore the row's normal hover tooltip")
		merchant_magic_row.queue_free()
	_assert(str(instance.call("_merchant_item_detail", "blacksmith", "crown_of_thorns")) == "Trinket | Legendary", "Blacksmith merchant details should spell out Legendary")
	var card_tooltip: Control = instance.call("_build_card_tooltip_panel", "cleaver_hook") as Control
	root.add_child(card_tooltip)
	await process_frame
	_assert(_card_widget_count_under(card_tooltip) == 1, "Deck card hover should show a real CardWidget preview")
	for widget: CardWidget in _card_widgets_under(card_tooltip):
		_assert(widget.size.x > 0.0 and absf((widget.size.y / widget.size.x) - (352.0 / 250.0)) < 0.01, "Card tooltip previews should preserve the real card aspect ratio")
	card_tooltip.queue_free()
	var deck_badge: Control = instance.call("_build_equipment_card_badge", "cleaver_hook", ElementData.accent(GameData.card_element("cleaver_hook"))) as Control
	root.add_child(deck_badge)
	await process_frame
	var deck_badge_art: TextureRect = deck_badge.find_child("CardBadgeArt", true, false) as TextureRect
	_assert(deck_badge_art != null and deck_badge_art.texture != null, "Deck card badges should use the card art as their visual background")
	deck_badge.queue_free()
	instance.call("_equip_equipment_from_overlay", "iron_cleaver")
	await process_frame
	var equipped_state: Dictionary = instance.get("_run_state")
	_assert(str((equipped_state.get("equipped_equipment", {}) as Dictionary).get("weapon", "")) == "iron_cleaver", "Equipping from the gear overlay should update the weapon slot")
	_assert((equipped_state.get("equipment_inventory", []) as Array).has("training_sword"), "Equipping from the gear overlay should return the old weapon to inventory")
	var equipped_deck: Array = equipped_state.get("deck_cards", []) as Array
	_assert(equipped_deck.has("cleaver_hook") and equipped_deck.has("needle_flurry") and equipped_deck.has("butcher_chop"), "Equipping from the gear overlay should add the new weapon cards")
	_assert(not equipped_deck.has("whirlwind_slash") and not equipped_deck.has("bloody_lunge"), "Equipping from the gear overlay should remove the previous weapon cards")
	var board_view: CombatBoardView = instance.get_node("BoardUnderlay/CombatBoard") as CombatBoardView
	var board_presentation: Dictionary = board_view.get("presentation") if board_view != null else {}
	_assert(str((board_presentation.get("equipped_equipment", {}) as Dictionary).get("weapon", "")) == "iron_cleaver", "Equipping gear should refresh board presentation for future player equipment art")
	instance.call("_switch_character_overlay_mode", "skills")
	await process_frame
	_assert(character_dialog != null and character_dialog.custom_minimum_size == stats_dialog_size, "Switching from Gear back to Skills should keep the character dialog size stable")
	_assert(character_dialog != null and character_dialog.size == stats_dialog_actual_size, "Switching from Gear back to Skills should keep the visible character dialog size stable")
	_assert(character_dialog.find_child("CharacterSkillTree", true, false) != null, "Returning to Skills should rebuild the skill tree")
	instance.call("_close_card_upgrade_overlay")
	instance.call("_open_level_up_overlay")
	var upgrade_dialog: PanelContainer = instance.get("_upgrade_dialog")
	if upgrade_dialog != null:
		var progression_viewport: Vector2 = instance.get_viewport_rect().size
		_assert(upgrade_dialog.custom_minimum_size.y <= progression_viewport.y - UiTypography.SAFE_MARGIN * 2.0, "The campfire level-up overlay should preserve safe margins so its action row remains visible")
	_assert(_label_with_text(upgrade_scrim, "Character") != null, "Campfire leveling should open the persistent Character surface")
	_assert(upgrade_scrim.find_child("CharacterSkillTree", true, false) != null, "The level-up overlay should reuse the skill tree")
	_assert(_label_with_text(upgrade_scrim, "Quick Wits") != null, "The level-up tree should show a legal root choice")
	_assert(_button_with_text(upgrade_scrim, "+") == null and _button_with_text(upgrade_scrim, "-") == null, "The level-up overlay should not expose stat steppers")
	_assert(_button_with_text(upgrade_scrim, "Learn  ·  1 Point") != null, "The persistent tree should let the focused ability be learned immediately")
	instance.queue_free()
	await process_frame

func _test_run_scene_grimoire_entry_click_keeps_nav_scroll_stable() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for Grimoire nav scroll coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	instance.call("_close_dialogue")
	var run_state: Dictionary = GrimoireLibrary.ensure_run_state(instance.get("_run_state"))
	var all_entry_ids: Array[String] = []
	for entry_var: Variant in GrimoireLibrary.entries():
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var as Dictionary
		var entry_id: String = str(entry.get("id", ""))
		if not entry_id.is_empty():
			all_entry_ids.append(entry_id)
	run_state[GrimoireLibrary.UNLOCKED_KEY] = all_entry_ids
	run_state[GrimoireLibrary.UNREAD_KEY] = []
	instance.set("_run_state", run_state)
	instance.set("_grimoire_selected_section", "keywords")
	instance.set("_grimoire_selected_group", "")
	instance.set("_grimoire_selected_entry", "keyword:melee")
	instance.call("_open_grimoire_overlay")
	for _frame: int in range(6):
		await process_frame
	var scroll: ScrollContainer = instance.get("_grimoire_entry_scroll") as ScrollContainer
	_assert(scroll != null, "Grimoire should expose a scrollable navigation list")
	if scroll == null:
		instance.queue_free()
		await process_frame
		return
	scroll.scroll_vertical = 150
	for _frame: int in range(3):
		await process_frame
	var before_click_scroll: int = scroll.scroll_vertical
	_assert(before_click_scroll >= 80, "Grimoire nav scroll fixture should have enough overflow for a stable-click regression")
	instance.call("_on_grimoire_entry_pressed", "keyword:ranged")
	for _frame: int in range(6):
		await process_frame
	var after_click_scroll: int = scroll.scroll_vertical
	_assert(absi(after_click_scroll - before_click_scroll) <= 1, "Clicking a Grimoire entry should not recenter or otherwise scroll the nav list")
	instance.call("_close_grimoire_overlay")
	instance.queue_free()
	await process_frame

func _test_run_scene_logs_local_analytics() -> void:
	AnalyticsStore.clear_storage()
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for analytics coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat: CombatEngine = CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(118, _simple_room_layout(), {
		"hp": 12,
		"max_hp": 20,
		"deck_cards": ["patch_up"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var player: Dictionary = (combat_state.get("player", {}) as Dictionary).duplicate(true)
	player["hp"] = 12
	combat_state["player"] = player
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["patch_up"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["analytics"] = {"combat_id": "test_run_c001"}
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["deck_cards"] = ["patch_up"]
	run_state["combat_state"] = combat_state
	run_state["analytics"] = {"run_id": "test_run", "combat_counter": 1}
	instance.set("_run_state", run_state)
	_set_run_scene_combat_state_for_test(instance, combat_state)
	instance.call("_refresh_ui")
	instance.call("_analytics_log_playable_cards")
	await _choose_clicked_card_action(instance, 0, "play")
	await instance.call("_on_confirm_card_play_pressed")
	await create_timer(1.5).timeout
	var reward_run_state: Dictionary = instance.get("_run_state")
	reward_run_state["mode"] = "reward"
	reward_run_state["pending_reward"] = {
		"cards": ["spark_dart", "brace", "frostbolt"],
		"heal_amount": RunEngine.REWARD_HEAL,
		"ember_amount": 4
	}
	instance.set("_run_state", reward_run_state)
	instance.call("_refresh_ui")
	instance.call("_on_reward_card_pressed", "spark_dart")
	await process_frame
	var merchant_run_state: Dictionary = instance.get("_run_state")
	merchant_run_state["mode"] = "room"
	merchant_run_state["current_room"] = Vector2i(2, 1)
	merchant_run_state["held_embers"] = 0
	merchant_run_state["unbanked_embers"] = 0
	merchant_run_state["equipment_inventory"] = ["ward_kite"]
	var merchant_collected: Array = (merchant_run_state.get("collected_equipment", []) as Array).duplicate()
	if not merchant_collected.has("ward_kite"):
		merchant_collected.append("ward_kite")
	merchant_run_state["collected_equipment"] = merchant_collected
	var merchant_rooms: Dictionary = (merchant_run_state.get("rooms", {}) as Dictionary).duplicate(true)
	merchant_rooms["2,1"] = {
		"coord": Vector2i(2, 1),
		"depth": 2,
		"type": "blacksmith",
		"merchant_kind": "blacksmith",
		"npcs": [{"id": "blacksmith", "pos": Vector2i(3, 4)}],
		"connections": [],
		"revealed": true,
		"visited": true,
		"cleared": true,
		"sealed": false
	}
	merchant_run_state["rooms"] = merchant_rooms
	merchant_run_state["combat_state"] = {}
	instance.set("_run_state", merchant_run_state)
	_set_run_scene_combat_state_for_test(instance, {})
	instance.call("_on_merchant_sell_pressed", "blacksmith", "ward_kite")
	await process_frame
	var item_event_state: Dictionary = instance.get("_run_state")
	item_event_state["equipped_items"] = ["crimson_draught"]
	item_event_state["item_inventory"] = ["nail_bomb"]
	var item_event_deck: Array = (item_event_state.get("deck_cards", []) as Array).duplicate()
	if not item_event_deck.has("crimson_draught"):
		item_event_deck.append("crimson_draught")
	item_event_state["deck_cards"] = item_event_deck
	instance.set("_run_state", item_event_state)
	instance.call("_analytics_log_item_equipped", "equip", "crimson_draught", 0, 0)
	var events: Array[Dictionary] = AnalyticsStore.load_all_events()
	var playable_events: Array[Dictionary] = _analytics_events_by_type(events, "card_became_playable")
	var played_events: Array[Dictionary] = _analytics_events_by_type(events, "card_played")
	var reward_events: Array[Dictionary] = _analytics_events_by_type(events, "reward_choice")
	var merchant_events: Array[Dictionary] = _analytics_events_by_type(events, "merchant_trade")
	var item_events: Array[Dictionary] = _analytics_events_by_type(events, "item_equipped")
	_assert(not playable_events.is_empty(), "Combat analytics should record when a drawn card becomes playable")
	_assert(not played_events.is_empty(), "Combat analytics should record card play events")
	_assert(not reward_events.is_empty(), "Reward analytics should record reward choices")
	_assert(not merchant_events.is_empty(), "Merchant analytics should record successful trades")
	_assert(not item_events.is_empty(), "Item analytics should record item loadout changes")
	var play_event: Dictionary = played_events[played_events.size() - 1]
	var play_payload: Dictionary = play_event.get("payload", {})
	_assert(str(play_event.get("card_id", "")) == "patch_up", "Card play analytics should record the played card id")
	_assert(int(play_payload.get("player_heal_gained", 0)) == 2, "Card play analytics should capture observed healing")
	_assert(int(play_payload.get("player_block_gained", 0)) == 2, "Card play analytics should capture observed block gain")
	_assert(play_payload.has("card_plays_gained"), "Card play analytics should include current-turn play bonuses")
	_assert(play_payload.has("illusions_created"), "Card play analytics should include created illusion counts")
	_assert(play_payload.has("elemental_intensity_spent"), "Card play analytics should include intensity spent by printed costs or relic payoffs")
	_assert(play_payload.has("terrain_hp_damage"), "Card play analytics should include terrain damage")
	_assert(play_payload.has("terrain_destroyed"), "Card play analytics should include destroyed terrain")
	_assert(play_payload.has("traps_triggered"), "Card play analytics should include triggered traps")
	_assert(play_payload.has("triggered_trap_damage"), "Card play analytics should include triggered trap damage")
	_assert(play_payload.has("pickups_collected"), "Card play analytics should include collected battlefield pickups")
	_assert(play_payload.has("consume_on_play") and play_payload.has("item_card"), "Card play analytics should include consumable item flags")
	_assert(play_event.has("umbra_stage") and play_event.has("umbra_radius") and play_event.has("visible_enemy_count"), "Combat analytics context should include Umbra visibility state")
	_assert(str(play_event.get("objective_type", "")) == "kill_all", "Combat analytics context should retain the encounter objective cohort")
	_assert(play_payload.has("radiance_card") and play_payload.has("umbra_stage_before") and play_payload.has("umbra_stage_after"), "Card play analytics should classify Radiance and stage changes")
	_assert(play_payload.has("umbra_tiles_illuminated") and play_payload.has("umbra_enemies_revealed") and play_payload.has("umbra_light_sources_created"), "Card play analytics should include observed Radiance results")
	_assert(play_payload.has("umbra_effective_light_sources_before") and play_payload.has("umbra_effective_light_sources_after"), "Card play analytics should expose effective Light source counts")
	_assert(play_payload.has("umbra_tethered_light_sources_before") and play_payload.has("umbra_tethered_light_sources_after"), "Card play analytics should distinguish actor-tethered Light")
	_assert(play_payload.has("umbra_suppression_stages_before") and play_payload.has("umbra_suppression_stages_after"), "Card play analytics should expose Light-driven Umbra suppression")
	_assert(play_payload.has("flurry") and play_payload.has("flurry_plays_spent"), "Card play analytics should expose Flurry use and its repeat count")
	_assert(bool((play_payload.get("enemy_status_applied", {}) as Dictionary).has("immobilize")), "Card play analytics should include enemy immobilize application")
	_assert(bool((play_payload.get("player_status_applied", {}) as Dictionary).has("immobilize")), "Card play analytics should include player immobilize application")
	var reward_event: Dictionary = reward_events[reward_events.size() - 1]
	var reward_payload: Dictionary = reward_event.get("payload", {})
	_assert(str(reward_payload.get("choice_kind", "")) == "card", "Reward analytics should distinguish card picks from heal skips")
	_assert(str(reward_payload.get("selected_card_id", "")) == "spark_dart", "Reward analytics should record the selected reward card")
	var merchant_event: Dictionary = merchant_events[merchant_events.size() - 1]
	var merchant_payload: Dictionary = merchant_event.get("payload", {})
	_assert(str(merchant_payload.get("action", "")) == "sell", "Merchant analytics should record trade action")
	_assert(str(merchant_payload.get("merchant_kind", "")) == "blacksmith", "Merchant analytics should record merchant kind")
	_assert(merchant_payload.has("equipped_items") and merchant_payload.has("item_inventory"), "Merchant analytics should include item inventory context")
	var item_payload: Dictionary = (item_events[item_events.size() - 1] as Dictionary).get("payload", {})
	_assert(str(item_payload.get("action", "")) == "equip", "Item analytics should record loadout action")
	_assert(str(item_payload.get("card_id", "")) == "crimson_draught", "Item analytics should record the item card id")
	_assert((item_payload.get("equipped_items", []) as Array).has("crimson_draught"), "Item analytics should include equipped item state")
	instance.queue_free()
	await process_frame

func _test_settings_persistence_audio_and_presentation_preferences() -> void:
	SettingsStore.clear_storage()
	var defaults: Dictionary = SettingsStore.default_settings()
	_assert(SettingsStore.load_settings() == defaults, "Settings should use phase-one defaults when no profile exists")
	_assert(SettingsStore.storage_path() != ProgressionStore.DEFAULT_STORAGE_PATH, "Settings should persist separately from progression")

	var custom: Dictionary = defaults.duplicate(true)
	custom["master_volume"] = 0.65
	custom["music_volume"] = 0.35
	custom["sfx_volume"] = 0.55
	custom["display_mode"] = SettingsStore.DISPLAY_WINDOWED
	custom["ui_scale"] = 1.15
	custom["dialogue_speed"] = SettingsStore.DIALOGUE_FAST
	custom["reduced_motion"] = true
	_assert(SettingsStore.save_settings(custom), "Settings should save to their own persistent profile")
	var loaded: Dictionary = SettingsStore.load_settings()
	_assert(loaded == SettingsStore.normalize_settings(custom), "All settings should survive a disk reload")

	var malformed_file: FileAccess = FileAccess.open(SettingsStore.storage_path(), FileAccess.WRITE)
	_assert(malformed_file != null, "Settings malformed-data test should open its isolated file")
	if malformed_file != null:
		malformed_file.store_string("{malformed settings")
		malformed_file.close()
	_assert(SettingsStore.load_settings() == defaults, "Malformed settings JSON should fall back to safe defaults")

	var invalid_file: FileAccess = FileAccess.open(SettingsStore.storage_path(), FileAccess.WRITE)
	if invalid_file != null:
		invalid_file.store_string(JSON.stringify({
			"master_volume": 7.0,
			"music_volume": "loud",
			"sfx_volume": -4.0,
			"display_mode": "offscreen",
			"ui_scale": 99.0,
			"dialogue_speed": "unbounded",
			"reduced_motion": "yes"
		}))
		invalid_file.close()
	var repaired: Dictionary = SettingsStore.load_settings()
	_assert(is_equal_approx(float(repaired["master_volume"]), 1.0), "Master volume should clamp malformed high values")
	_assert(is_equal_approx(float(repaired["music_volume"]), float(defaults["music_volume"])), "Non-numeric music volume should use its default")
	_assert(is_equal_approx(float(repaired["sfx_volume"]), 0.0), "SFX volume should clamp malformed low values")
	_assert(str(repaired["display_mode"]) == SettingsStore.DISPLAY_FULLSCREEN, "Invalid display modes should never survive normalization")
	_assert(is_equal_approx(float(repaired["ui_scale"]), 1.25), "UI scale should snap to a supported bounded value")
	_assert(str(repaired["dialogue_speed"]) == SettingsStore.DIALOGUE_STANDARD, "Invalid dialogue speed should use its safe default")
	_assert(not bool(repaired["reduced_motion"]), "Non-boolean reduced motion data should use its safe default")

	SettingsStore.apply_audio_settings(custom)
	for bus_name: String in [SettingsStore.MASTER_BUS, SettingsStore.MUSIC_BUS, SettingsStore.SFX_BUS]:
		_assert(AudioServer.get_bus_index(bus_name) >= 0, "Settings should provision the %s audio bus" % bus_name)
	var master_index: int = AudioServer.get_bus_index(SettingsStore.MASTER_BUS)
	var music_index: int = AudioServer.get_bus_index(SettingsStore.MUSIC_BUS)
	var sfx_index: int = AudioServer.get_bus_index(SettingsStore.SFX_BUS)
	_assert(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(master_index)), 0.65), "Master volume should affect the Master bus")
	_assert(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(music_index)), 0.35), "Music volume should affect only the Music bus")
	var expected_sfx_linear: float = 0.55 * db_to_linear(SettingsStore.SFX_HEADROOM_DB)
	_assert(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(sfx_index)), expected_sfx_linear), "SFX volume should apply the global subtlety trim only to the SFX bus")
	var full_sfx: Dictionary = custom.duplicate(true)
	full_sfx["sfx_volume"] = 1.0
	SettingsStore.apply_audio_settings(full_sfx)
	_assert(is_equal_approx(AudioServer.get_bus_volume_db(sfx_index), SettingsStore.SFX_HEADROOM_DB), "The maximum SFX setting should retain global mix headroom")
	_assert(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(music_index)), 0.35), "SFX headroom should not alter music volume")
	var muted_sfx: Dictionary = custom.duplicate(true)
	muted_sfx["sfx_volume"] = 0.0
	SettingsStore.apply_audio_settings(muted_sfx)
	_assert(AudioServer.is_bus_mute(sfx_index), "The global SFX trim should preserve complete mute at zero")
	SettingsStore.apply_audio_settings(custom)

	var safe_large: Vector2i = SettingsStore.safe_windowed_size(Vector2i(9000, 9000), Vector2i(1920, 1080))
	var safe_small: Vector2i = SettingsStore.safe_windowed_size(Vector2i.ZERO, Vector2i(800, 450))
	var safe_tiny: Vector2i = SettingsStore.safe_windowed_size(Vector2i(1600, 900), Vector2i(500, 300))
	_assert(safe_large.x <= 1856 and safe_large.y <= 1016, "Windowed mode should stay inside the usable screen")
	_assert(safe_small.x >= 640 and safe_small.y >= 360 and safe_small.x <= 800 and safe_small.y <= 450, "Windowed fallback should remain usable on a small screen")
	_assert(safe_tiny.x <= 500 and safe_tiny.y <= 300, "Windowed fallback should never exceed even an unusually small usable screen")
	_assert(SettingsStore.dialogue_characters_per_second(custom) > SettingsStore.STANDARD_DIALOGUE_CHARACTERS_PER_SECOND, "Fast dialogue should visibly outpace standard dialogue")
	var instant: Dictionary = custom.duplicate(true)
	instant["dialogue_speed"] = SettingsStore.DIALOGUE_INSTANT
	_assert(SettingsStore.dialogue_is_instant(instant), "Instant dialogue should bypass type-on presentation")
	_assert(is_zero_approx(SettingsStore.motion_duration(0.24, custom)), "Reduced motion should settle supported transitions immediately")
	custom["reduced_motion"] = false
	_assert(is_equal_approx(SettingsStore.motion_duration(0.24, custom), 0.24), "Full motion should preserve supported transition duration")

	SettingsStore.save_settings(loaded)
	var main_menu_scene: PackedScene = load("res://scenes/main_menu.tscn")
	var menu_instance: Node = main_menu_scene.instantiate()
	root.add_child(menu_instance)
	await process_frame
	var menu_settings_panel: Node = menu_instance.get_node("SettingsPanel")
	_assert(is_equal_approx(float((menu_settings_panel.call("current_settings") as Dictionary)["music_volume"]), 0.35), "Main-menu settings should read the shared persistent profile")
	var settings_controls: Dictionary = menu_settings_panel.get("_controls") as Dictionary
	for key: String in ["display_mode", "ui_scale", "dialogue_speed", "reduced_motion"]:
		var settings_control: Variant = settings_controls.get(key)
		_assert(settings_control is Button, "Settings %s should expose a button-derived centered control" % key)
		if settings_control is Button:
			_assert_button_text_centered(settings_control as Button, "Settings %s" % key)
	var menu_music: AudioStreamPlayer = menu_instance.get_node("MusicPlayer")
	_assert(menu_music.bus == SettingsStore.MUSIC_BUS, "Main-menu music should route through the Music bus")
	var restore_button: Button = _button_with_text(menu_settings_panel, "Restore defaults")
	_assert(restore_button != null, "Settings should expose Restore defaults")
	if restore_button != null:
		_assert_button_text_centered(restore_button, "Settings Restore defaults")
		_assert(str(restore_button.get_meta("button_variant", "")) == UiSkin.VARIANT_DESTRUCTIVE, "Restore defaults should use the destructive themed variant")
		restore_button.pressed.emit()
	var confirmation_panel: PanelContainer = menu_settings_panel.get("_confirmation_panel") as PanelContainer
	_assert(confirmation_panel != null and confirmation_panel.visible, "Restore defaults should require a deliberate confirmation step")
	_assert(is_equal_approx(float((menu_settings_panel.call("current_settings") as Dictionary)["music_volume"]), 0.35), "Opening restore confirmation should not change settings")
	var confirm_restore: Button = _button_with_text(confirmation_panel, "Restore")
	_assert(confirm_restore != null, "Restore confirmation should expose an explicit Restore action")
	if confirm_restore != null:
		_assert_button_text_centered(confirm_restore, "Settings restore confirmation")
		confirm_restore.pressed.emit()
	_assert((menu_settings_panel.call("current_settings") as Dictionary) == defaults, "Confirmed restore should reset every phase-one setting")
	menu_instance.queue_free()
	await process_frame

	SettingsStore.save_settings(loaded)
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	var run_instance: Node = run_scene.instantiate()
	root.add_child(run_instance)
	await process_frame
	_assert(is_equal_approx(float((run_instance.get("_settings") as Dictionary)["music_volume"]), 0.35), "In-run settings should read the same persistent profile as the main menu")
	run_instance.call("_ensure_music_player")
	var run_music: AudioStreamPlayer = run_instance.get("_music_player") as AudioStreamPlayer
	_assert(run_music != null and run_music.bus == SettingsStore.MUSIC_BUS, "In-run music should route through the Music bus")
	run_instance.call("_play_sfx", {"path": "res://assets/audio/sfx/action_block.wav", "volume_db": -8.0, "duration": 0.1})
	var routed_sfx_found: bool = false
	for child: Node in run_instance.get_children():
		if child is AudioStreamPlayer and child != run_music and (child as AudioStreamPlayer).bus == SettingsStore.SFX_BUS:
			routed_sfx_found = true
			break
	_assert(routed_sfx_found, "In-run effects should route through the SFX bus")
	run_instance.queue_free()
	await process_frame

	SettingsStore.save_settings(defaults)
	SettingsStore.apply_audio_settings(defaults)

func _test_main_menu_shows_continue_for_saved_run() -> void:
	var main_menu_scene: PackedScene = load("res://scenes/main_menu.tscn")
	if main_menu_scene == null:
		_failures.append("Main menu scene should load for continue-button coverage")
		return
	var run_engine: RunEngine = RunEngine.new()
	ProgressionStore.save_run_state(run_engine.create_new_run(88, ProgressionStore.default_data()))
	var instance: Node = main_menu_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var continue_button: Button = instance.get_node("MenuColumn/ContinueButton")
	var boss_button: Button = instance.get_node("MenuColumn/BossButton")
	var settings_button: Button = instance.get_node("MenuColumn/SettingsButton")
	var settings_panel: PanelContainer = instance.get_node("SettingsPanel")
	var settings_back_button: Button = settings_panel.call("back_button") as Button
	var music_player: AudioStreamPlayer = instance.get_node("MusicPlayer")
	_assert(continue_button.visible, "Main menu should expose Continue when a saved run exists")
	_assert(not continue_button.disabled, "Main menu should enable Continue when a saved run exists")
	_assert(not continue_button.has_focus() and not settings_button.has_focus(), "Main menu should not show keyboard focus before keyboard navigation")
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_DOWN
	key_event.pressed = true
	instance.call("_unhandled_input", key_event)
	_assert(continue_button.has_focus(), "Main menu should restore keyboard focus when navigation keys are pressed")
	var mouse_press := InputEventMouseButton.new()
	mouse_press.button_index = MOUSE_BUTTON_LEFT
	mouse_press.pressed = true
	instance.call("_input", mouse_press)
	await process_frame
	_assert(continue_button.has_focus(), "Main menu should not clear focus on mouse down before button clicks can complete")
	var settings_center: Vector2 = settings_button.get_global_rect().get_center()
	var hover_then_click := InputEventMouseMotion.new()
	hover_then_click.position = settings_center
	hover_then_click.global_position = settings_center
	instance.get_viewport().push_input(hover_then_click, true)
	var settings_press := InputEventMouseButton.new()
	settings_press.button_index = MOUSE_BUTTON_LEFT
	settings_press.pressed = true
	settings_press.position = settings_center
	settings_press.global_position = settings_center
	instance.get_viewport().push_input(settings_press, true)
	await process_frame
	var settings_release := InputEventMouseButton.new()
	settings_release.button_index = MOUSE_BUTTON_LEFT
	settings_release.pressed = false
	settings_release.position = settings_center
	settings_release.global_position = settings_center
	instance.get_viewport().push_input(settings_release, true)
	await process_frame
	_assert(settings_panel.visible, "Main menu Settings should open on the first pointer click even when hover and press arrive in the same frame")
	_assert((settings_panel.call("current_settings") as Dictionary) == SettingsStore.load_settings(), "Main menu settings panel should reflect the persisted profile")
	_assert(not settings_back_button.has_focus(), "Mouse-clicked Settings should not force keyboard focus")
	settings_back_button.pressed.emit()
	_assert(not settings_panel.visible, "Main menu Settings back button should close the settings panel")
	instance.call("_unhandled_input", key_event)
	_assert(continue_button.has_focus(), "Main menu should restore keyboard focus after mouse-clicked Settings closes")
	var mouse_release := InputEventMouseButton.new()
	mouse_release.button_index = MOUSE_BUTTON_LEFT
	mouse_release.pressed = false
	instance.call("_input", mouse_release)
	await process_frame
	_assert(not continue_button.has_focus(), "Main menu should clear keyboard focus after mouse release")
	instance.call("_unhandled_input", key_event)
	_assert(continue_button.has_focus(), "Main menu should restore keyboard focus after mouse release clears it")
	var mouse_event := InputEventMouseMotion.new()
	instance.call("_input", mouse_event)
	await process_frame
	_assert(not continue_button.has_focus(), "Main menu should clear keyboard focus after mouse movement")
	_assert(music_player.stream != null, "Main menu should play the temporary relic-room music")
	_assert(music_player.bus == SettingsStore.MUSIC_BUS, "Main menu music should remain routed through the Music bus")
	_assert(not boss_button.visible, "Main menu should keep the debug boss shortcut hidden by default")
	instance.queue_free()
	ProgressionStore.clear_saved_run()
	await process_frame

func _analytics_events_by_type(events: Array[Dictionary], event_type: String) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for event: Dictionary in events:
		if str(event.get("event_type", "")) == event_type:
			filtered.append(event)
	return filtered

func _set_enemy_intent(state: Dictionary, enemy_index: int, intent: Dictionary) -> void:
	var enemies: Array = (state.get("enemies", []) as Array).duplicate(true)
	if enemy_index < 0 or enemy_index >= enemies.size():
		return
	var enemy: Dictionary = enemies[enemy_index]
	enemy["intent"] = intent.duplicate(true)
	enemy["block"] = 0
	enemies[enemy_index] = enemy
	state["enemies"] = enemies

func _enemy_intent_by_id(enemy_type: String, intent_id: String) -> Dictionary:
	for intent_var: Variant in GameData.enemy_def(enemy_type).get("intents", []):
		if typeof(intent_var) != TYPE_DICTIONARY:
			continue
		var intent: Dictionary = intent_var
		if str(intent.get("id", "")) == intent_id:
			return intent.duplicate(true)
	return {}

func _enemies_of_type_for_test(state: Dictionary, enemy_type: String, live_only: bool) -> Array:
	var found: Array = []
	for enemy_var: Variant in state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var
		if str(enemy.get("type", "")) != enemy_type:
			continue
		if live_only and int(enemy.get("hp", 0)) <= 0:
			continue
		found.append(enemy)
	return found

func _room_has_enemy_type(room: Dictionary, enemy_type: String) -> bool:
	for enemy_var: Variant in room.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		if str((enemy_var as Dictionary).get("type", "")) == enemy_type:
			return true
	return false

func _intent_rows_have_icon(rows: Array, icon_key: String) -> bool:
	for row_var: Variant in rows:
		if typeof(row_var) != TYPE_ARRAY:
			continue
		for token_var: Variant in row_var as Array:
			if typeof(token_var) != TYPE_DICTIONARY:
				continue
			if str((token_var as Dictionary).get("icon", "")) == icon_key:
				return true
	return false

func _bleed_action_types_from_steps(steps: Array) -> Array[String]:
	var action_types: Array[String] = []
	for step_var: Variant in steps:
		if typeof(step_var) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = step_var as Dictionary
		if str(step.get("label", "")) == "Bleed":
			action_types.append(str(step.get("action_type", "")))
	return action_types

func _intent_has_action_status(intent: Dictionary, action_type: String, status_key: String) -> bool:
	for action_var: Variant in intent.get("actions", []):
		if typeof(action_var) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_var as Dictionary
		if str(action.get("type", "")) == action_type and int(action.get(status_key, 0)) > 0:
			return true
	return false

func _chainbound_gaoler_combat_state(seed: int, player_pos: Vector2i, gaoler_pos: Vector2i, intent_id: String) -> Dictionary:
	var combat: CombatEngine = CombatEngine.new()
	var state: Dictionary = combat.create_combat(seed, _simple_room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["guarded_step", "brace"],
		"relics": [],
		"hand_size": 2,
		"heal_bonus": 0
	})
	state["player"] = {
		"pos": player_pos,
		"hp": 240,
		"max_hp": 240,
		"block": 0,
		"stoneskin": 0
	}
	var gaoler_def: Dictionary = GameData.enemy_def("chainbound_gaoler")
	state["enemies"] = [{
		"id": 1,
		"type": "chainbound_gaoler",
		"pos": gaoler_pos,
		"hp": int(gaoler_def.get("max_hp", 160)),
		"max_hp": int(gaoler_def.get("max_hp", 160)),
		"block": 0,
		"stoneskin": 0,
		"intent": _enemy_intent_by_id("chainbound_gaoler", intent_id)
	}]
	var intensity: Dictionary = combat.elemental_intensities(state)
	intensity[ElementData.AIR] = 2
	state["elemental_intensity"] = intensity
	state["rng_state"] = seed
	return state

func _support_action_test_state() -> Dictionary:
	return {
		"grid": _simple_grid(),
		"room_depth": 2,
		"room_element": ElementData.NONE,
		"player": {"pos": Vector2i(2, 4), "hp": 20, "max_hp": 20, "block": 0, "stoneskin": 0},
		"enemies": [
			{"id": 1, "type": "grave_surgeon", "pos": Vector2i(5, 4), "hp": 10, "max_hp": 10, "block": 0, "stoneskin": 0},
			{"id": 2, "type": "crawler", "pos": Vector2i(3, 4), "hp": 4, "max_hp": 10, "block": 0, "stoneskin": 0},
			{"id": 3, "type": "harrier", "pos": Vector2i(5, 3), "hp": 7, "max_hp": 10, "block": 0, "stoneskin": 0}
		],
		"illusions": [],
		"terrain": [],
		"traps": [],
		"log": []
	}

func _combat_log_contains(state: Dictionary, text: String) -> bool:
	for line_var: Variant in state.get("log", []):
		if str(line_var).find(text) >= 0:
			return true
	return false

func _test_umbra_curve_tracks_dragon_sections() -> void:
	var expected: Array[String] = ["clear", "fringe", "advancing", "pressing", "deep", "heart"]
	for section_index: int in range(expected.size()):
		_assert(CombatEngine.umbra_stage_for_section(section_index) == expected[section_index], "Umbra stage should advance by elemental-dragon section")
		var first_depth: int = section_index * 4 + 1
		if section_index > 0:
			_assert(CombatEngine.umbra_stage_for_room_depth(first_depth) == expected[section_index], "Umbra depth mapping should use four-depth section boundaries after the introductory section")
	_assert(CombatEngine.umbra_stage_for_room_depth(1) == "clear", "The opening depth should remain free of Umbra")
	_assert(CombatEngine.umbra_stage_for_room_depth(2) == "fringe", "The second depth should introduce Fringe Umbra before the first dragon")
	_assert(CombatEngine.umbra_stage_for_room_depth(3) == "fringe", "The final pre-boss depth should retain Fringe Umbra")
	_assert(CombatEngine.umbra_stage_for_room_depth(4) == "fringe", "The first dragon room should not shed the Fringe Umbra introduced before it")
	_assert(CombatEngine.umbra_radius_for_stage("fringe") == 6, "Fringe Umbra should use radius 6")
	_assert(CombatEngine.umbra_radius_for_stage("heart") == 2, "Heart Umbra should use radius 2")
	_assert(CombatEngine.umbra_radius_for_stage("eclipse") == 1, "Eclipse Umbra should use radius 1")
	var combat = CombatEngine.new()
	var compressed_layout: Dictionary = _simple_room_layout()
	compressed_layout["depth"] = 2
	compressed_layout["section_index"] = 4
	var compressed_state: Dictionary = combat.create_combat(44000, compressed_layout, {"hp": 20, "max_hp": 20, "deck_cards": ["quick_stab"], "hand_size": 1})
	_assert(combat.effective_umbra_stage(compressed_state) == "deep", "Explicit section progression should override fixed depth boundaries when sections compress")
	compressed_layout["section_index"] = 0
	var introductory_state: Dictionary = combat.create_combat(44000, compressed_layout, {"hp": 20, "max_hp": 20, "deck_cards": ["quick_stab"], "hand_size": 1})
	_assert(combat.effective_umbra_stage(introductory_state) == "fringe", "Depth-aware section layouts should preserve the first-section Umbra introduction")

func _test_umbra_hides_targets_intents_and_turn_order_identity() -> void:
	var combat = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["umbra_stage"] = "heart"
	var state: Dictionary = combat.create_combat(44001, layout, {
		"hp": 100,
		"max_hp": 100,
		"deck_cards": ["lantern_shot"],
		"hand_size": 1
	})
	var enemy: Dictionary = (state.get("enemies", []) as Array)[0]
	_assert(not combat.is_enemy_visible_to_player(state, enemy), "Heart Umbra should hide a distant enemy")
	var ranged_targets: Array[Vector2i] = combat.valid_targets_for_player_action(state, {"type": "ranged", "damage": 4, "range": 7})
	_assert(not ranged_targets.has(enemy.get("pos", Vector2i.ZERO)), "Hidden enemies should not be valid direct attack targets")
	var threat: Dictionary = combat.enemy_threat_tiles(state, 0)
	_assert((threat.get("move", []) as Array).is_empty() and (threat.get("attack", []) as Array).is_empty(), "Hidden enemy intents should not expose threat tiles")
	var order: Array[Dictionary] = combat.current_turn_order(state, 8)
	var found_hidden_entry: bool = false
	for entry: Dictionary in order:
		if str(entry.get("kind", "")) != "enemy":
			continue
		found_hidden_entry = true
		_assert(bool(entry.get("hidden_by_umbra", false)), "Hidden enemy initiative entries should be anonymized")
		_assert(str(entry.get("name", "")) == "Unknown Presence", "Hidden initiative entries should not reveal enemy identity")
		_assert(not entry.has("intent_time_cost"), "Hidden initiative entries should not reveal intent timing")
	_assert(found_hidden_entry, "Turn order should retain an anonymous hidden presence")
	var hidden_intent_step: Dictionary = combat.call("_enemy_intent_step_for_player", state, enemy, {"name": "Hidden Shot"}) as Dictionary
	_assert(bool(hidden_intent_step.get("hidden_by_umbra", false)), "Hidden enemy animation intent steps should carry their presentation guard")
	_assert(str(hidden_intent_step.get("actor_name", "")) == "Unknown Presence" and str(hidden_intent_step.get("intent_name", "")) == "Hidden Intent", "Hidden intent animation steps should be anonymized")
	_assert((hidden_intent_step.get("tile", Vector2i.ZERO) as Vector2i).x < 0, "Hidden intent animation steps should not expose the source tile")
	var hp_before: int = int((state.get("player", {}) as Dictionary).get("hp", 0))
	var attacked_state: Dictionary = combat.call("_resolve_enemy_intent", state, 0, {
		"name": "Hidden Shot",
		"actions": [{"type": "ranged", "damage": 40, "range": 9}]
	}) as Dictionary
	var hp_after: int = int((attacked_state.get("player", {}) as Dictionary).get("hp", hp_before))
	_assert(hp_after < hp_before, "The hidden-attack fixture should deal player HP damage")
	_assert(int((attacked_state.get("umbra", {}) as Dictionary).get("hidden_attack_damage_received_total", 0)) == hp_before - hp_after, "Damage from a hidden attacker should be attributed exactly once")
	var hidden_logs: Array = attacked_state.get("log", []) as Array
	var latest_hidden_log: String = str(hidden_logs[hidden_logs.size() - 1]) if not hidden_logs.is_empty() else ""
	_assert(latest_hidden_log == "A hidden presence attacks.", "Hidden enemy action logs should replace identity and intent with generic Umbra copy")

func _test_hidden_enemy_status_steps_do_not_leak_identity_or_tile() -> void:
	var combat = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["umbra_stage"] = "heart"
	var state: Dictionary = combat.create_combat(44004, layout, {"hp": 100, "max_hp": 100, "deck_cards": ["quick_stab"], "hand_size": 1})
	var enemy: Dictionary = ((state.get("enemies", []) as Array)[0] as Dictionary).duplicate(true)
	enemy["burn"] = 1
	enemy["bleed"] = 1
	enemy["intent"] = {"id": "hidden_test", "name": "Hidden Test", "actions": [{"type": "ranged", "damage": 1, "range": 9}]}
	(state.get("enemies", []) as Array)[0] = enemy
	var result: Dictionary = combat.resolve_enemy_turn_with_steps(state, 0, false)
	var hidden_status_count: int = 0
	for step_var: Variant in result.get("steps", []):
		if typeof(step_var) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = step_var
		if str(step.get("kind", "")) != "status_damage":
			continue
		hidden_status_count += 1
		_assert(bool(step.get("hidden_by_umbra", false)), "Hidden enemy status damage should use the Umbra presentation guard")
		_assert(str(step.get("actor_name", "")) == "Unknown Presence", "Hidden enemy status damage should not reveal identity")
		_assert((step.get("tile", Vector2i.ZERO) as Vector2i).x < 0, "Hidden enemy status damage should not reveal its tile")
	_assert(hidden_status_count >= 2, "The hidden status fixture should cover start-of-turn Burn and action-triggered Bleed")

func _test_run_scene_umbra_move_shortcuts_do_not_reveal_hidden_targets() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for Umbra shortcut coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["umbra_stage"] = "heart"
	layout["player_start"] = Vector2i(2, 4)
	(layout.get("enemies", []) as Array)[0]["pos"] = Vector2i(5, 4)
	var state: Dictionary = combat.create_combat(44005, layout, {"hp": 20, "max_hp": 20, "deck_cards": ["quick_stab"], "hand_size": 1})
	var run_state: Dictionary = instance.get("_run_state")
	run_state["mode"] = "combat"
	run_state["combat_state"] = state
	var discovery_progression: Dictionary = ProgressionStore.prepare_for_new_run(ProgressionStore.default_data())
	run_state["run_index"] = int(discovery_progression.get("run_counter", 0))
	run_state["progression"] = discovery_progression.duplicate(true)
	instance.set("_run_state", run_state)
	_set_run_scene_combat_state_for_test(instance, state)
	instance.set("_progression", discovery_progression)
	instance.call("_sync_umbra_warning_progression")
	var queued_warning_progression: Dictionary = instance.get("_progression") as Dictionary
	_assert(int(queued_warning_progression.get(ProgressionStore.UMBRA_WARNING_AVAILABLE_RUN_KEY, 0)) == int(run_state.get("run_index", 0)) + 1, "Entering the first non-clear Umbra combat should queue the warning for the next run")
	instance.call("_sync_umbra_warning_progression")
	_assert(int((instance.get("_progression") as Dictionary).get(ProgressionStore.UMBRA_WARNING_AVAILABLE_RUN_KEY, 0)) == int(run_state.get("run_index", 0)) + 1, "Repeated Umbra refreshes should not reschedule the warning")
	var actions: Array = [{"type": "move", "range": 2}, {"type": "melee", "damage": 4, "range": 1}]
	var preview: Dictionary = instance.call("_card_preview_from_state", "umbra_move_attack", state, actions, 0)
	var targets: Array[Vector2i] = instance.call("_vector2i_array", preview.get("target_tiles", []))
	_assert(targets.has(Vector2i(3, 4)) and targets.has(Vector2i(2, 3)), "Umbra movement preview should keep symmetric destinations legal without inspecting hidden follow-up targets")
	var shortcuts: Dictionary = instance.call("_preview_shortcuts_for_current_action", preview)
	_assert(
		(shortcuts.get("plans", {}) as Dictionary).is_empty()
		and (shortcuts.get("tiles", []) as Array).is_empty(),
		"Umbra movement shortcuts should wait until movement resolves instead of exposing newly discovered enemies"
	)
	instance.set("_selected_card_index", 0)
	instance.set("_pending_action_index", 0)
	instance.set("_pending_actions", actions)
	instance.set("_preview_combat_state", state)
	instance.set("_pending_target_tiles", targets)
	instance.set("_hovered_board_tile", Vector2i(4, 4))
	instance.set("_dialogue_active", false)
	instance.set("_animation_lock", false)
	instance.set("_drag_card_index", -1)
	_assert(targets.has(Vector2i(4, 4)), "The irreversible Umbra movement fixture should expose its chosen destination")
	_assert(bool(instance.call("_umbra_defers_movement_followup_preview", state, actions[0] as Dictionary, actions, 0)), "The Umbra movement fixture should require deferred follow-up targeting")
	_assert((instance.call("_pass_preview_confirmed_hover_state") as Dictionary).is_empty(), "Umbra movement hover should not simulate hidden collisions or newly visible intents")
	var move_path: Array[Vector2i] = combat.path_for_player_action(state, actions[0] as Dictionary, Vector2i(4, 4))
	_assert((instance.call("_movement_risk_chips_for_preview", preview, move_path) as Array).is_empty(), "Umbra movement hover should not leak a blocker through risk-chip deltas")
	await instance.call("_on_board_tile_clicked", Vector2i(4, 4))
	_assert(bool(instance.get("_pending_umbra_commit_locked")), "Moving into new Umbra information should make the pending card choice irreversible")
	instance.call("_refresh_stage_view")
	var locked_board: Control = instance.get_node("BoardUnderlay/CombatBoard") as Control
	var locked_board_state: Dictionary = locked_board.get("combat_state") as Dictionary
	var locked_board_presentation: Dictionary = locked_board.get("presentation") as Dictionary
	var hidden_enemy_after_move: Dictionary = (state.get("enemies", []) as Array)[0] as Dictionary
	_assert((locked_board_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO) == (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO), "A selected Umbra move should keep the rendered player at the committed tile until card resolution starts")
	_assert(not (locked_board_presentation.get("visible_enemy_ids", []) as Array).has(int(hidden_enemy_after_move.get("id", -1))), "A selected Umbra move should not reveal newly visible enemies while its card preview is still pending")
	_assert(int(locked_board_presentation.get("umbra_radius", -1)) == combat.effective_umbra_radius(state), "A selected Umbra move should preserve the committed vision radius")
	_assert(not (instance.get("_pending_target_tiles") as Array).has(hidden_enemy_after_move.get("pos", Vector2i.ZERO)), "A selected Umbra move should not expose a newly revealed enemy as a follow-up target")
	instance.call("_cancel_card_selection")
	_assert(int(instance.get("_selected_card_index")) == 0, "An Umbra movement reveal should not be cancellable back to the untouched combat state")
	instance.call("_reset_card_resolution")

	var dawnstep_actions: Array = (GameData.card_def("dawnstep").get("actions", []) as Array).duplicate(true)
	var dawnstep_target := Vector2i(4, 4)
	var dawnstep_preview_state: Dictionary = combat.apply_player_action(state, dawnstep_actions[0] as Dictionary, dawnstep_target)
	dawnstep_preview_state = combat.apply_player_action(dawnstep_preview_state, dawnstep_actions[1] as Dictionary)
	var preview_enemy: Dictionary = (dawnstep_preview_state.get("enemies", []) as Array)[0]
	_assert(combat.is_enemy_visible_to_player(dawnstep_preview_state, preview_enemy), "The simulated Dawnstep outcome should reveal the enemy, proving the fixture can catch an information leak")
	_set_run_scene_combat_state_for_test(instance, state)
	instance.set("_selected_card_index", 0)
	instance.set("_pending_actions", dawnstep_actions)
	instance.set("_pending_action_index", dawnstep_actions.size())
	instance.set("_pending_selected_targets", instance.call("_vector2i_array", [dawnstep_target]))
	instance.set("_pending_target_tiles", instance.call("_vector2i_array", []))
	instance.set("_preview_combat_state", dawnstep_preview_state)
	instance.set("_pending_umbra_commit_locked", false)
	var safe_display_state: Dictionary = instance.call("_board_display_state")
	var safe_visibility_state: Dictionary = instance.call("_board_visibility_state", safe_display_state)
	_assert((safe_display_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO) == (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO), "Unconfirmed movement should keep the rendered player at the committed tile instead of leaking a hidden collision or reveal radius")
	_assert(combat.effective_umbra_radius(safe_visibility_state) == combat.effective_umbra_radius(state), "Unconfirmed movement-card vision should not clear or shrink the rendered Umbra")
	_assert(not combat.is_enemy_visible_to_player(safe_visibility_state, (safe_visibility_state.get("enemies", []) as Array)[0]), "Unconfirmed movement-card vision should not reveal enemy positions")
	instance.call("_refresh_stage_view")
	var safe_board: Control = instance.get_node("BoardUnderlay/CombatBoard") as Control
	var safe_board_state: Dictionary = safe_board.get("combat_state") as Dictionary
	var safe_board_presentation: Dictionary = safe_board.get("presentation") as Dictionary
	_assert((safe_board_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO) == (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO), "The live board should render the committed player position until Play Card confirms the movement")
	_assert(not (safe_board_presentation.get("visible_enemy_ids", []) as Array).has(int(preview_enemy.get("id", -1))), "The live board presentation should keep newly discovered enemies concealed before confirmation")
	_assert((safe_board_presentation.get("umbra_visible_tiles", []) as Array).size() == combat.umbra_visible_tiles(state).size(), "The live board should preserve the committed Umbra coverage before confirmation")
	instance.call("_reset_card_resolution")

	var radiance_state: Dictionary = combat.create_combat(44006, layout, {"hp": 20, "max_hp": 20, "deck_cards": ["guiding_flare"], "hand_size": 1})
	var radiance_actions: Array = (GameData.card_def("guiding_flare").get("actions", []) as Array).duplicate(true)
	var enemy_tile: Vector2i = ((radiance_state.get("enemies", []) as Array)[0] as Dictionary).get("pos", Vector2i.ZERO)
	var guiding_attack: Dictionary = radiance_actions[0] as Dictionary
	var guiding_targets: Array[Vector2i] = combat.valid_targets_for_player_action(radiance_state, guiding_attack)
	_assert(radiance_actions.size() == 1 and not guiding_targets.has(enemy_tile), "Guiding Flare should inherit ordinary attack visibility and reject a hidden enemy")
	_assert(not guiding_targets.has(Vector2i(3, 4)), "Guiding Flare should not use standalone Light's empty-floor targeting")
	var visible_radiance_state: Dictionary = combat.apply_player_action(radiance_state, {"type": "truesight", "duration": 2})
	_assert(combat.valid_targets_for_player_action(visible_radiance_state, guiding_attack).has(enemy_tile), "Guiding Flare should expose one combined attack-and-Light target step once the enemy is attackable")
	var initial_enemy_hp: int = int(((visible_radiance_state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0))
	var direct_attack_state: Dictionary = combat.apply_player_action(visible_radiance_state, guiding_attack, enemy_tile)
	var direct_enemy_hp: int = int(((direct_attack_state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0))
	var guiding_sources: Array = (direct_attack_state.get("umbra", {}) as Dictionary).get("light_sources", []) as Array
	_assert(direct_enemy_hp < initial_enemy_hp and not guiding_sources.is_empty() and (guiding_sources[0] as Dictionary).get("pos", Vector2i.ZERO) == enemy_tile, "Guiding Flare should attack first and leave Light at that impact in one action")
	var lantern_state: Dictionary = combat.create_combat(44007, layout, {"hp": 20, "max_hp": 20, "deck_cards": ["lantern_shot"], "hand_size": 1})
	var lantern_actions: Array = (GameData.card_def("lantern_shot").get("actions", []) as Array).duplicate(true)
	var lantern_enemy_tile: Vector2i = ((lantern_state.get("enemies", []) as Array)[0] as Dictionary).get("pos", Vector2i.ZERO)
	lantern_state = combat.apply_player_action(lantern_state, {"type": "truesight", "duration": 2})
	var lantern_initial_enemy_hp: int = int(((lantern_state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0))
	var lantern_hit_state: Dictionary = combat.apply_player_action(lantern_state, lantern_actions[0] as Dictionary, lantern_enemy_tile)
	var resolved_lantern_preview: Dictionary = instance.call("_card_preview_from_state", "lantern_shot", lantern_hit_state, lantern_actions, 1, true)
	var resolved_lantern_state: Dictionary = resolved_lantern_preview.get("state", {})
	var lantern_resolved_enemy_hp: int = int(((resolved_lantern_state.get("enemies", []) as Array)[0] as Dictionary).get("hp", 0))
	_assert(bool(resolved_lantern_preview.get("complete", false)), "Lantern Shot should resolve its draw after one combined attack-and-Light tile selection")
	_assert(lantern_resolved_enemy_hp < lantern_initial_enemy_hp, "Lantern Shot should damage and illuminate its target without asking for a second target")
	var lantern_display: Dictionary = instance.call("_card_widget_display", "lantern_shot", lantern_state)
	var lantern_display_rows: Array = lantern_display.get("summary_rows", [])
	_assert(lantern_display_rows.size() == 2, "Lantern Shot's live card display should show its combined attack rider on one line and draw on the next")
	_assert((lantern_display_rows[0] as Array).size() == 4, "Lantern Shot's live attack line should contain damage, range, Light radius, and Light duration")
	instance.queue_free()
	await process_frame

func _test_run_scene_umbra_preview_effects_do_not_reveal_hidden_state() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for Umbra preview-effect privacy coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["umbra_stage"] = "heart"
	layout["player_start"] = Vector2i(2, 4)
	var layout_enemies: Array = layout.get("enemies", []) as Array
	if layout_enemies.is_empty():
		_failures.append("Umbra preview-effect privacy fixture should include a hidden enemy")
		instance.queue_free()
		await process_frame
		return
	(layout_enemies[0] as Dictionary)["pos"] = Vector2i(6, 4)
	var state: Dictionary = combat.create_combat(44008, layout, {"hp": 20, "max_hp": 20, "deck_cards": ["guiding_flare"], "hand_size": 1})
	var enemy: Dictionary = (state.get("enemies", []) as Array)[0] as Dictionary
	var enemy_pos: Vector2i = enemy.get("pos", Vector2i.ZERO)
	var objective: Dictionary = {
		"type": "kill_leader",
		"leader_id": int(enemy.get("id", -1))
	}
	state["objective"] = objective
	var before_visible_ids: Array[int] = combat.visible_enemy_ids(state)
	_assert(not before_visible_ids.has(int(enemy.get("id", -1))), "Umbra preview-effect fixture should start with a concealed enemy")
	var baseline_radius: int = combat.effective_umbra_radius(state)
	var run_state: Dictionary = instance.get("_run_state") as Dictionary
	run_state["mode"] = "combat"
	run_state["combat_state"] = state
	run_state["current_room_layout"] = layout
	instance.set("_run_state", run_state)
	_set_run_scene_combat_state_for_test(instance, state)
	instance.call("_refresh_ui")
	var option_deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	option_deck["hand"] = ["pale_spark"]
	state["deck"] = option_deck
	_set_run_scene_combat_state_for_test(instance, state)
	instance.call("_mark_combat_preview_state_changed")
	var synthetic_actions: Array = [
		{"type": "vision", "amount": 4, "duration": 1},
		{"type": "ranged", "damage": 4, "range": 9, "required": true}
	]
	var synthetic_preview: Dictionary = instance.call("_card_preview_from_state", "pale_spark", state, synthetic_actions, 0)
	var preview_cache: Dictionary = instance.get("_card_preview_cache") as Dictionary
	preview_cache[instance.call("_card_preview_cache_key", 0, "play")] = synthetic_preview
	var raw_card_preview: Dictionary = instance.call("_card_preview_for_index", 0)
	var privacy_safe_options: Dictionary = instance.call("_card_play_options_for_index", 0)
	_assert((raw_card_preview.get("target_tiles", []) as Array).has(enemy_pos), "Card-option privacy fixture should simulate a hidden ranged target")
	_assert(not bool(privacy_safe_options.get("printed_playable", false)), "A card with only a hidden printed target should not appear as printed-playable")
	_assert(not bool(privacy_safe_options.get("attack_playable", false)), "A fallback attack with only a hidden target should not appear playable")
	_assert(str(instance.call("_action_context_valid_target_count_text", privacy_safe_options.get("play", {}))) == "UNAVAILABLE", "Card drag target counts should not expose hidden targets")

	var cases: Array = [
		{"label": "Illuminate", "action": {"type": "illuminate", "range": 8, "radius": 2, "duration": 2}, "target": enemy_pos},
		{"label": "Vision", "action": {"type": "vision", "amount": 4, "duration": 1}, "target": Vector2i(-1, -1)},
		{"label": "Truesight", "action": {"type": "truesight", "duration": 1}, "target": Vector2i(-1, -1)},
		{"label": "Dispel Umbra", "action": {"type": "dispel_umbra", "amount": 2}, "target": Vector2i(-1, -1)},
		{"label": "Vision AOE", "action": {"type": "vision", "amount": 4, "duration": 1}, "target": Vector2i(-1, -1), "followup": {"type": "aoe", "damage": 4, "range": 4, "pattern": [[0, 0]], "rotate": false}}
	]
	for case_var: Variant in cases:
		var case: Dictionary = case_var as Dictionary
		var first_action: Dictionary = case.get("action", {}) as Dictionary
		var preview_state: Dictionary = combat.apply_player_action(state, first_action, case.get("target", Vector2i(-1, -1)))
		var followup_action: Dictionary = case.get("followup", {"type": "ranged", "damage": 4, "range": 9}) as Dictionary
		var raw_followup_targets: Array[Vector2i] = combat.valid_targets_for_player_action(preview_state, followup_action)
		_assert(raw_followup_targets.has(enemy_pos), "%s preview fixture should simulate a hidden follow-up target so privacy gating is exercised" % str(case.get("label", "")))
		instance.set("_selected_card_index", 0)
		instance.set("_pending_actions", [first_action, followup_action])
		instance.set("_pending_action_index", 1)
		instance.set("_pending_selected_targets", instance.call("_vector2i_array", [case.get("target", Vector2i(-1, -1))]))
		instance.set(
			"_pending_target_tiles",
			instance.call("_preview_target_tiles_for_action", preview_state, followup_action, raw_followup_targets)
		)
		instance.set("_preview_combat_state", preview_state)
		instance.set("_pending_umbra_commit_locked", false)
		instance.set("_hovered_board_tile", enemy_pos)
		instance.call("_mark_preview_selection_changed")
		instance.call("_refresh_stage_view")
		var board: Control = instance.get_node("BoardUnderlay/CombatBoard") as Control
		var presentation: Dictionary = board.get("presentation") as Dictionary
		var active_preview: Dictionary = instance.call("_active_card_preview")
		instance.call("_refresh_combat_objective_hud")
		var objective_hud: Control = instance.get("_combat_objective_hud") as Control
		var objective_detail: Label = objective_hud.find_child("ObjectiveLiveDetail", true, false) as Label
		_assert(int(presentation.get("umbra_radius", -1)) == baseline_radius, "%s preview should preserve the committed Umbra radius" % str(case.get("label", "")))
		_assert((presentation.get("umbra_light_sources", []) as Array).is_empty(), "%s preview should not render a simulated light source" % str(case.get("label", "")))
		_assert((presentation.get("visible_enemy_ids", []) as Array).is_empty(), "%s preview should not reveal a newly visible enemy" % str(case.get("label", "")))
		_assert(not (board.get("attack_tiles") as Array).has(enemy_pos), "%s preview should not expose a newly visible enemy as an attack tile" % str(case.get("label", "")))
		_assert(not (active_preview.get("target_tiles", []) as Array).has(enemy_pos), "%s preview should not expose a newly visible enemy as a target" % str(case.get("label", "")))
		_assert(presentation.get("objective_leader_tile", Vector2i(-1, -1)) != enemy_pos, "%s preview should not beacon a concealed objective leader" % str(case.get("label", "")))
		_assert(objective_detail != null and objective_detail.text == "Leader concealed", "%s preview should not expose concealed leader identity or HP in the objective HUD" % str(case.get("label", "")))
		_assert((presentation.get("effect", {}) as Dictionary).is_empty(), "%s preview should not draw an effect on a concealed follow-up target" % str(case.get("label", "")))

	instance.call("_reset_card_resolution")
	instance.queue_free()
	await process_frame

func _test_run_scene_umbra_aoe_centers_allow_hidden_pattern_occupants() -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	if run_scene == null:
		_failures.append("Run scene should load for hidden AOE occupant coverage")
		return
	var instance: Node = run_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var combat = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["umbra_stage"] = "heart"
	layout["player_start"] = Vector2i(2, 4)
	(layout.get("enemies", []) as Array)[0]["pos"] = Vector2i(5, 4)
	layout["terrain"] = [{
		"id": "hidden_aoe_box",
		"kind": "wooden_box",
		"pos": Vector2i(4, 3),
		"hp": 5,
		"max_hp": 5
	}]
	layout["traps"] = [{
		"id": "hidden_aoe_trap",
		"pos": Vector2i(4, 5),
		"element": "fire",
		"damage": 1
	}]
	var state: Dictionary = combat.create_combat(44010, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["cinderburst"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	var hidden_enemy: Dictionary = (state.get("enemies", []) as Array)[0] as Dictionary
	var hidden_enemy_tile: Vector2i = hidden_enemy.get("pos", Vector2i.ZERO)
	var center_tile := Vector2i(4, 4)
	var action: Dictionary = {
		"type": "aoe",
		"damage": 4,
		"range": 4,
		"pattern": [[0, 0], [1, 0], [0, -1], [0, 1]],
		"rotate": false
	}
	_assert(not combat.is_enemy_visible_to_player(state, hidden_enemy), "Hidden AOE occupant fixture should conceal the enemy")
	_assert(not combat.is_tile_visible_to_player(state, Vector2i(4, 3)), "Hidden AOE occupant fixture should conceal the terrain tile")
	_assert(not combat.is_tile_visible_to_player(state, Vector2i(4, 5)), "Hidden AOE occupant fixture should conceal the trap tile")
	var raw_target_tiles: Array[Vector2i] = combat.valid_targets_for_player_action(state, action)
	_assert(raw_target_tiles.has(center_tile), "AOE should allow a visible center even when its pattern contains hidden occupants")
	var preview_target_tiles: Array[Vector2i] = instance.call("_preview_target_tiles_for_action", state, action, raw_target_tiles)
	_assert(preview_target_tiles.has(center_tile), "AOE preview should retain a visible center with hidden pattern occupants")
	_assert(bool(instance.call("_preview_aoe_target_is_known", state, state, action, center_tile)), "AOE privacy gating should depend only on center visibility")

	var resolved_state: Dictionary = combat.apply_player_action(state, action, center_tile)
	var resolved_enemy: Dictionary = (resolved_state.get("enemies", []) as Array)[0] as Dictionary
	var resolved_terrain: Dictionary = (resolved_state.get("terrain", []) as Array)[0] as Dictionary
	_assert(int(resolved_enemy.get("hp", 0)) < int(resolved_enemy.get("max_hp", 0)), "AOE should damage a concealed enemy inside the pattern")
	_assert(int(resolved_terrain.get("hp", 0)) < int(resolved_terrain.get("max_hp", 0)), "AOE should damage concealed destructible terrain inside the pattern")
	_assert((resolved_state.get("traps", []) as Array).is_empty(), "AOE should trigger and consume a concealed trap inside the pattern")

	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["cinderburst"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	state["deck"] = deck
	state["current_actor"] = {"kind": "player", "key": "player"}
	var run_state: Dictionary = instance.get("_run_state") as Dictionary
	run_state["mode"] = "combat"
	run_state["combat_state"] = state
	run_state["current_room_layout"] = layout
	instance.set("_run_state", run_state)
	_set_run_scene_combat_state_for_test(instance, state)
	instance.call("_refresh_ui")
	instance.set("_selected_card_index", 0)
	instance.set("_pending_actions", [action])
	instance.set("_pending_action_index", 0)
	instance.set("_pending_selected_targets", instance.call("_vector2i_array", []))
	instance.set("_pending_target_tiles", raw_target_tiles)
	instance.set("_preview_combat_state", state)
	instance.set("_pending_umbra_commit_locked", false)
	instance.set("_hovered_board_tile", center_tile)
	instance.call("_mark_preview_selection_changed")
	instance.call("_refresh_stage_view")
	var board: Control = instance.get_node("BoardUnderlay/CombatBoard") as Control
	var presentation: Dictionary = board.get("presentation") as Dictionary
	var active_preview: Dictionary = instance.call("_active_card_preview")
	var effect: Dictionary = presentation.get("effect", {}) as Dictionary
	var hidden_terrain: Dictionary = (state.get("terrain", []) as Array)[0] as Dictionary
	var hidden_terrain_preview: Dictionary = board.call("_terrain_damage_preview", hidden_terrain) as Dictionary
	var obstruction_entries: Array = board.call("_foreground_obstruction_entries", board.call("_visible_units")) as Array
	var effect_damage_preview: Dictionary = effect.get("damage_preview", {}) as Dictionary
	_assert((board.get("attack_tiles") as Array).has(center_tile), "AOE board preview should highlight a visible center with hidden pattern occupants")
	_assert((active_preview.get("target_tiles", []) as Array).has(center_tile), "AOE active preview should keep the visible center target")
	_assert(not (presentation.get("visible_enemy_ids", []) as Array).has(int(hidden_enemy.get("id", -1))), "AOE preview should not reveal the concealed enemy it may hit")
	_assert((effect.get("tiles", []) as Array).has(hidden_enemy_tile), "AOE preview should show the authored pattern without exposing hidden occupancy")
	_assert(not effect_damage_preview.has(instance.call("_enemy_key", hidden_enemy)), "AOE preview should not expose concealed enemy damage information")
	_assert(not effect_damage_preview.has(instance.call("_terrain_key", hidden_terrain)), "AOE preview should not expose concealed terrain damage information")
	_assert(hidden_terrain_preview.is_empty(), "AOE preview should not show concealed terrain damage or health information")
	instance.set("_preview_combat_state", resolved_state)
	instance.call("_refresh_stage_view")
	var refreshed_presentation: Dictionary = board.get("presentation") as Dictionary
	var cumulative_damage_preview: Dictionary = refreshed_presentation.get("damage_preview", {}) as Dictionary
	_assert(not cumulative_damage_preview.has(instance.call("_enemy_key", hidden_enemy)), "Cumulative AOE preview should not expose concealed enemy damage information")
	_assert(not cumulative_damage_preview.has(instance.call("_terrain_key", hidden_terrain)), "Cumulative AOE preview should not expose concealed terrain damage information")
	for entry_var: Variant in obstruction_entries:
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var
		_assert(entry.get("tile", Vector2i(-1, -1)) != hidden_terrain.get("pos", Vector2i(-1, -1)), "AOE preview should not retain concealed terrain in render obstruction entries")
		_assert(entry.get("tile", Vector2i(-1, -1)) != Vector2i(4, 5), "AOE preview should not retain concealed traps in render obstruction entries")
	instance.queue_free()
	await process_frame

func _test_radiance_actions_reveal_and_reduce_umbra() -> void:
	var combat = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["umbra_stage"] = "heart"
	var state: Dictionary = combat.create_combat(44002, layout, {
		"hp": 100,
		"max_hp": 100,
		"deck_cards": ["guiding_flare"],
		"hand_size": 1
	})
	var enemy: Dictionary = (state.get("enemies", []) as Array)[0]
	var enemy_pos: Vector2i = enemy.get("pos", Vector2i.ZERO)
	var illuminate := {"type": "illuminate", "range": 7, "radius": 2, "duration": 2}
	_assert(combat.valid_targets_for_player_action(state, illuminate).has(enemy_pos), "Illuminate should be targetable inside the Umbra")
	var lit_state: Dictionary = combat.apply_player_action(state, illuminate, enemy_pos)
	_assert(combat.is_enemy_visible_to_player(lit_state, enemy), "A light source should reveal enemies in its radius")
	_assert(combat.valid_targets_for_player_action(lit_state, {"type": "ranged", "damage": 4, "range": 7}).has(enemy_pos), "Illuminated enemies should become targetable")
	var lit_next_activation: Dictionary = combat.prepare_next_player_turn(lit_state)
	_assert(int((((lit_next_activation.get("umbra", {}) as Dictionary).get("light_sources", []) as Array)[0] as Dictionary).get("remaining_activations", 0)) == 1, "Temporary light sources should expose an accurate remaining-activation counter")
	var lit_expired: Dictionary = combat.prepare_next_player_turn(lit_next_activation)
	_assert(((lit_expired.get("umbra", {}) as Dictionary).get("light_sources", []) as Array).is_empty(), "Temporary light sources should disappear when their counter reaches zero")
	var vision_state: Dictionary = combat.apply_player_action(state, {"type": "vision", "amount": 3, "duration": 1})
	_assert(combat.effective_umbra_radius(vision_state) == 5, "Vision should add to the personal Umbra radius")
	var truesight_state: Dictionary = combat.apply_player_action(state, {"type": "truesight", "duration": 1})
	_assert(combat.is_enemy_visible_to_player(truesight_state, enemy), "Truesight should reveal enemies without lighting their tiles")
	_assert(not combat.is_tile_visible_to_player(truesight_state, enemy_pos), "Truesight should not illuminate the enemy tile")
	var truesight_expired: Dictionary = combat.prepare_next_player_turn(truesight_state)
	_assert(int((truesight_expired.get("umbra", {}) as Dictionary).get("truesight_activations", -1)) == 0, "True Sight should clear when its displayed activation counter reaches zero")
	var dispelled_state: Dictionary = combat.apply_player_action(state, {"type": "dispel_umbra", "amount": 2})
	_assert(combat.effective_umbra_stage(dispelled_state) == "pressing", "Dispel Umbra should reduce Heart by two stages")
	_assert(combat.effective_umbra_radius(dispelled_state) == 4, "Dispel Umbra should apply the reduced stage radius")

func _test_hidden_enemy_movement_collision_does_not_leak_position() -> void:
	var combat = CombatEngine.new()
	var layout: Dictionary = _simple_room_layout()
	layout["umbra_stage"] = "eclipse"
	(layout.get("enemies", []) as Array)[0]["pos"] = Vector2i(4, 4)
	var state: Dictionary = combat.create_combat(44003, layout, {
		"hp": 100,
		"max_hp": 100,
		"deck_cards": ["dawnstep"],
		"hand_size": 1
	})
	var move := {"type": "move", "range": 4}
	var target := Vector2i(5, 4)
	var targets: Array[Vector2i] = combat.valid_targets_for_player_action(state, move)
	_assert(targets.has(target), "Movement highlights should optimistically pass through hidden occupancy")
	var moved: Dictionary = combat.apply_player_action(state, move, target)
	_assert((moved.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO) == Vector2i(3, 4), "Movement should stop before colliding with a hidden enemy")
	_assert(int((moved.get("umbra", {}) as Dictionary).get("movement_interrupted_total", 0)) == 1, "Hidden collision should be recorded")
	var hidden_enemy: Dictionary = (moved.get("enemies", []) as Array)[0]
	_assert(combat.is_enemy_visible_to_player(moved, hidden_enemy), "The blocking enemy should become visible when movement stops adjacent")
	var blink_targets: Array[Vector2i] = combat.valid_targets_for_player_action(state, {"type": "blink", "range": 5})
	_assert(not blink_targets.has(target), "Blink should not target shrouded destinations")

func _test_radiance_cards_and_icons_are_integrated() -> void:
	for card_id: String in [
		"lantern_shot",
		"guiding_flare",
		"dawnstep",
		"prism_sight",
		"storm_beacon",
		"glowstone_ward",
		"daybreak",
		"ember_rain",
		"trapdoor",
		"firebrand_volley",
		"icebound_chains",
		"spark_dart",
		"spark_focus",
		"threaded_path",
		"root_snare"
	]:
		var card: Dictionary = GameData.card_def(card_id)
		_assert(not card.is_empty(), "%s should load" % card_id)
		_assert(bool(card.get("radiance", false)), "%s should carry the Radiance school tag" % card_id)
		_assert(not ActionIcons.rows_for_card(card).is_empty(), "%s should render action icon rows" % card_id)
	var all_rewards: Dictionary = GameData.reward_card_pool_by_rarity("", true)
	_assert((all_rewards.get("legendary", []) as Array).has("daybreak"), "Neutral Radiance cards should enter the general elemental reward slot")
	for icon_key: String in ["illuminate", "vision", "truesight", "dispel_umbra"]:
		_assert(ActionIcons.all_icon_keys().has(icon_key), "%s should have a shared action icon" % icon_key)
	var radiance_icon_paths: Dictionary = {}
	for icon_key: String in ["illuminate", "vision", "truesight", "dispel_umbra"]:
		var icon_path: String = ActionIcons.icon_path(icon_key)
		_assert(icon_path.ends_with("/%s.png" % icon_key), "%s should use its own purpose-built icon asset" % icon_key)
		radiance_icon_paths[icon_path] = true
	_assert(radiance_icon_paths.size() == 4, "Radiance mechanics should remain visually distinguishable at card size")
	var lantern_rows: Array = ActionIcons.rows_for_actions(GameData.card_def("lantern_shot").get("actions", []))
	_assert(lantern_rows.size() == 2, "Lantern Shot should render one combined attack-rider line plus its draw line")
	var lantern_target_row: Array = lantern_rows[0] as Array
	var lantern_target_icons: PackedStringArray = []
	var lantern_range_tokens: int = 0
	for token_var: Variant in lantern_target_row:
		var token: Dictionary = token_var
		var token_icon: String = str(token.get("icon", ""))
		lantern_target_icons.append(token_icon)
		if token_icon == "range":
			lantern_range_tokens += 1
	_assert(lantern_target_icons == PackedStringArray(["ranged", "range", "illuminate", "time"]), "Lantern Shot's single attack action should lead with damage and range, then attach Light radius and duration")
	_assert(lantern_range_tokens == 1, "A combined attack-and-Light action should show its inherited attack range only once")
	_assert(ActionIcons.token_tooltip(lantern_target_row[2] as Dictionary).begins_with("After this attack resolves"), "The Light rider tooltip should disclose its post-hit timing")
	var guiding_rows: Array = ActionIcons.rows_for_actions(GameData.card_def("guiding_flare").get("actions", []))
	_assert(guiding_rows.size() == 1 and (guiding_rows[0] as Array).size() == 5, "Guiding Flare should keep damage, range, Burn, and its Light rider in one action row")
	_assert(str(((guiding_rows[0] as Array)[0] as Dictionary).get("icon", "")) == "ranged" and str(((guiding_rows[0] as Array)[3] as Dictionary).get("icon", "")) == "illuminate", "Guiding Flare should present its core attack before the post-hit Light rider")
	var storm_rows: Array = ActionIcons.rows_for_actions(GameData.card_def("storm_beacon").get("actions", []))
	_assert(storm_rows.size() == 2 and (storm_rows[1] as Array).size() == 5, "Storm Beacon should keep its intensity line separate and its combined attack-rider effects together")
	_assert(str(((storm_rows[1] as Array)[0] as Dictionary).get("icon", "")) == "ranged" and str(((storm_rows[1] as Array)[3] as Dictionary).get("icon", "")) == "illuminate", "Storm Beacon should present damage, range, and Chain before its post-hit Light rider")
	var card_widget := CardWidget.new()
	var lantern_segments: Array = card_widget.call("_summary_token_segments", lantern_target_row)
	_assert(lantern_segments.size() == 1, "CardWidget should keep a four-token attack rider on one compact line")
	card_widget.size = Vector2(250.0, 352.0)
	var root_rows: Array = ActionIcons.rows_for_actions(GameData.card_def("root_snare").get("actions", []))
	var root_attack_row: Array = root_rows[1] as Array
	var root_segments: Array = card_widget.call("_summary_token_segments", root_attack_row)
	_assert(root_attack_row.size() == 5 and root_segments.size() == 2 and (root_segments[0] as Array).size() == 3 and (root_segments[1] as Array).size() == 2, "Five-token attack riders should wrap after their three core attack tokens")
	var squall_rows: Array = ActionIcons.rows_for_actions(GameData.card_def("squall_shot").get("actions", []))
	var squall_attack_row: Array = squall_rows[1] as Array
	var squall_segments: Array = card_widget.call("_summary_token_segments", squall_attack_row)
	_assert(squall_attack_row.size() == 4 and squall_segments.size() == 1, "Simplified Squall should keep its four fitting AOE tokens on one line")
	var action_group_parent := VBoxContainer.new()
	card_widget.call("_add_summary_action_group", action_group_parent, root_segments, 28.0, 16, 6)
	_assert(action_group_parent.get_child_count() == 1 and bool(action_group_parent.get_child(0).get_meta("summary_action_group", false)), "A wrapped action should render inside one action-group container")
	var action_group_inner: Control = action_group_parent.get_child(0) as Control
	_assert(not (action_group_inner is PanelContainer), "Ordinary wrapped actions should use only the continuation arrow, without a special-state panel background")
	_assert(action_group_inner.get_child_count() == 2 and not bool(action_group_inner.get_child(0).get_meta("summary_action_continuation", true)) and bool(action_group_inner.get_child(1).get_meta("summary_action_continuation", false)), "Only the overflow row should be marked as an action continuation")
	var continuation_row: Control = action_group_inner.get_child(1) as Control
	_assert(continuation_row.get_child_count() > 0 and bool(continuation_row.get_child(0).get_meta("summary_continuation_glyph", false)), "An overflow row should begin with a persistent continuation glyph")
	var boundary_segments: Array = [root_segments[1], root_segments[0]]
	var raw_boundary_width: float = maxf(
		float(card_widget.call("_summary_segment_width_estimate", boundary_segments[0] as Array, 28.0, 16, 5)),
		float(card_widget.call("_summary_segment_width_estimate", boundary_segments[1] as Array, 28.0, 16, 5))
	)
	var grouped_boundary_width: float = float(card_widget.call("_summary_width_estimate", boundary_segments, 28.0, 16, 6, [{"segments": boundary_segments, "condition": {}}]))
	_assert(grouped_boundary_width > raw_boundary_width + 1.0, "Card layout measurement should include the continuation glyph and gap when the continuation row controls the group width")
	var boundary_width: float = raw_boundary_width + 1.0
	_assert(raw_boundary_width <= boundary_width and grouped_boundary_width > boundary_width, "A near-boundary action group should be rejected when its rendered continuation cue would overflow")
	action_group_parent.free()
	var valued_token: Dictionary = ActionIcons.token_for("ranged", 12)
	var valued_layout: Dictionary = card_widget.call("_summary_token_layout", valued_token, 28.0, 16)
	var icon_box: Vector2 = valued_layout.get("icon_size", Vector2.ZERO)
	var suffix_position: Vector2 = valued_layout.get("value_position", Vector2.ZERO)
	var suffix_size: Vector2 = valued_layout.get("value_size", Vector2.ZERO)
	_assert(suffix_position.x > icon_box.x * 0.5 and suffix_position.y > 0.0, "Valued action tokens should attach their number at the icon's lower-right corner")
	_assert((valued_layout.get("size", Vector2.ZERO) as Vector2).x < icon_box.x + suffix_size.x, "Attached value suffixes should use less width than separate icon and number children")
	var contrast_label: Label = card_widget.call("_summary_value_label", "2", "", 16, ActionIcons.token_for("time", 2))
	_assert(contrast_label.get_theme_constant("shadow_outline_size") >= 2 and contrast_label.get_theme_color("font_shadow_color").get_luminance() < 0.2, "Attached values should retain a dark zero-offset halo when they overlap pale or dark icons")
	contrast_label.free()
	var modified_token: Dictionary = ActionIcons.token_for("ranged", 12, "bonus", "", [{"source": "Test Relic", "amount": 2}], 10)
	var modified_layout: Dictionary = card_widget.call("_summary_token_layout", modified_token, 28.0, 16)
	_assert((modified_layout.get("marker_position", Vector2.ZERO) as Vector2).y < (modified_layout.get("value_position", Vector2.ZERO) as Vector2).y, "The modifier marker should occupy the upper-right corner without colliding with the lower value suffix")
	for stress_value: Variant in [-2, "∞"]:
		var stress_layout: Dictionary = card_widget.call("_summary_token_layout", ActionIcons.token_for("time", stress_value), 24.0, 14)
		_assert((stress_layout.get("size", Vector2.ZERO) as Vector2).x >= (stress_layout.get("icon_size", Vector2.ZERO) as Vector2).x, "Compact suffix layout should contain %s without clipping" % str(stress_value))
	card_widget.free()
	var visual_board := CombatBoardView.new()
	var previous_umbra_alpha: float = 0.0
	for stage_id: String in ["fringe", "advancing", "pressing", "deep", "heart", "eclipse"]:
		var stage_alpha: float = float(visual_board.call("_umbra_stage_fill_alpha", stage_id))
		_assert(stage_alpha > previous_umbra_alpha, "%s Umbra should darken the tile veil beyond the preceding stage" % stage_id.capitalize())
		previous_umbra_alpha = stage_alpha
	_assert(float(visual_board.call("_umbra_stage_fill_alpha", "fringe")) >= 0.50, "Even Fringe Umbra should visibly distinguish shadowed tiles from lit tiles")
	visual_board.free()

func _simple_room_layout() -> Dictionary:
	return {
		"name": "Test Room",
		"coord": Vector2i(1, 0),
		"type": "combat",
		"grid": _simple_grid(),
		"player_start": Vector2i(2, 4),
		"enemies": [
			{
				"id": 1,
				"type": "crawler",
				"pos": Vector2i(5, 2),
				"hp": 14,
				"max_hp": 14,
				"block": 0
			}
		],
		"loot": []
	}

func _cinder_ooze_room_layout(blocked_split: bool = false) -> Dictionary:
	var grid: Array = _simple_grid()
	var player_start: Vector2i = Vector2i(3, 3)
	var enemies: Array = [
		{
			"id": 1,
			"type": "cinder_ooze",
			"pos": Vector2i(4, 4),
			"hp": int(GameData.enemy_def("cinder_ooze").get("max_hp", 140)),
			"max_hp": int(GameData.enemy_def("cinder_ooze").get("max_hp", 140)),
			"block": 0
		}
	]
	if blocked_split:
		player_start = Vector2i(3, 4)
		(grid[3] as Array)[4] = "wall"
		(grid[5] as Array)[4] = "door"
		enemies.append({
			"id": 2,
			"type": "harrier",
			"pos": Vector2i(5, 4),
			"hp": int(GameData.enemy_def("harrier").get("max_hp", 100)),
			"max_hp": int(GameData.enemy_def("harrier").get("max_hp", 100)),
			"block": 0
		})
	return {
		"name": "Cinder Test Room",
		"coord": Vector2i(2, 0),
		"depth": 2,
		"type": "combat",
		"element": ElementData.NONE,
		"grid": grid,
		"player_start": player_start,
		"enemies": enemies,
		"loot": []
	}

func _cinder_droplet_room_layout() -> Dictionary:
	return {
		"name": "Cinder Droplet Test Room",
		"coord": Vector2i(2, 1),
		"depth": 2,
		"type": "combat",
		"element": ElementData.NONE,
		"grid": _simple_grid(),
		"player_start": Vector2i(3, 3),
		"enemies": [
			{
				"id": 1,
				"type": "cinder_droplet",
				"summoned": true,
				"pos": Vector2i(4, 4),
				"hp": int(GameData.enemy_def("cinder_droplet").get("max_hp", 50)),
				"max_hp": int(GameData.enemy_def("cinder_droplet").get("max_hp", 50)),
				"block": 0
			}
		],
		"loot": []
	}

func _aoe_test_room_layout() -> Dictionary:
	return {
		"name": "Area Room",
		"coord": Vector2i(1, 1),
		"type": "combat",
		"grid": _simple_grid(),
		"player_start": Vector2i(2, 5),
		"enemies": [
			{
				"id": 1,
				"type": "crawler",
				"pos": Vector2i(4, 3),
				"hp": 14,
				"max_hp": 14,
				"block": 0
			},
			{
				"id": 2,
				"type": "harrier",
				"pos": Vector2i(5, 3),
				"hp": 10,
				"max_hp": 10,
				"block": 0
			}
		],
		"loot": []
	}

func _zekarion_test_room_layout(depth: int = 4, coord: Vector2i = Vector2i(4, 0)) -> Dictionary:
	return {
		"name": "Tempest God's Perch",
		"coord": coord,
		"depth": depth,
		"type": "boss",
		"element": ElementData.LIGHTNING,
		"grid": _simple_grid(),
		"player_start": Vector2i(2, 6),
		"enemies": [
			{
				"id": 1,
				"type": "zekarion",
				"element": ElementData.LIGHTNING,
				"pos": Vector2i(4, 3),
				"footprint": Vector2i(2, 2),
				"hp": 72,
				"max_hp": 72,
				"block": 0
			},
			{
				"id": 2,
				"type": "lightning_wisp",
				"element": ElementData.LIGHTNING,
				"pos": Vector2i(2, 3),
				"hp": 6,
				"max_hp": 6,
				"block": 0
			},
			{
				"id": 3,
				"type": "lightning_wisp",
				"element": ElementData.LIGHTNING,
				"pos": Vector2i(6, 5),
				"hp": 6,
				"max_hp": 6,
				"block": 0
			}
		],
		"loot": []
	}

func _defeated_zekarion_combat_state(depth: int, coord: Vector2i) -> Dictionary:
	var combat_state: Dictionary = _zekarion_test_room_layout(depth, coord)
	combat_state["room_name"] = "Tempest God's Perch"
	combat_state["room_coord"] = coord
	combat_state["room_depth"] = depth
	combat_state["room_type"] = "boss"
	combat_state["room_element"] = ElementData.LIGHTNING
	combat_state["player"] = {
		"pos": Vector2i(2, 6),
		"hp": 9,
		"max_hp": 36,
		"block": 0,
		"stoneskin": 0
	}
	for index: int in range((combat_state.get("enemies", []) as Array).size()):
		var enemy: Dictionary = (combat_state.get("enemies", []) as Array)[index]
		if str(enemy.get("type", "")) == "zekarion":
			enemy["hp"] = 0
			(combat_state.get("enemies", []) as Array)[index] = enemy
	return combat_state

func _dead_hand_room_layout() -> Dictionary:
	return {
		"name": "Dead Hand Room",
		"coord": Vector2i(2, 2),
		"type": "combat",
		"grid": [
			["wall", "wall", "wall", "wall", "wall", "wall", "wall"],
			["wall", "stone", "stone", "wall", "stone", "stone", "wall"],
			["wall", "stone", "wall", "wall", "wall", "stone", "wall"],
			["wall", "wall", "wall", "stone", "wall", "wall", "wall"],
			["wall", "stone", "wall", "wall", "wall", "stone", "wall"],
			["wall", "stone", "stone", "wall", "stone", "stone", "wall"],
			["wall", "wall", "wall", "wall", "wall", "wall", "wall"]
		],
		"player_start": Vector2i(3, 3),
		"enemies": [
			{
				"id": 1,
				"type": "crawler",
				"pos": Vector2i(1, 1),
				"hp": 14,
				"max_hp": 14,
				"block": 0
			}
		],
		"loot": []
	}

func _optional_followup_room_layout() -> Dictionary:
	return {
		"name": "Optional Followup",
		"coord": Vector2i(3, 1),
		"type": "combat",
		"grid": _simple_grid(),
		"player_start": Vector2i(2, 5),
		"enemies": [
			{
				"id": 1,
				"type": "crawler",
				"pos": Vector2i(6, 1),
				"hp": 14,
				"max_hp": 14,
				"block": 0
			}
		],
		"loot": []
	}

func _find_route_to_coord(run_engine: RunEngine, start_state: Dictionary, target: Vector2i, max_steps: int = 20) -> Array:
	var queue: Array = [{"state": start_state.duplicate(true), "path": []}]
	var visited: Dictionary = {}
	while not queue.is_empty():
		var entry: Dictionary = queue.pop_front()
		var state: Dictionary = entry.get("state", {})
		var path: Array = (entry.get("path", []) as Array).duplicate()
		var key: String = _route_search_key(state)
		if visited.has(key):
			continue
		visited[key] = true
		if state.get("current_room", Vector2i(999, 999)) == target:
			return path
		if path.size() >= max_steps:
			continue
		for move: Vector2i in run_engine.available_moves(state):
			var next_path: Array = path.duplicate()
			next_path.append(move)
			queue.append({
				"state": _route_state_after_step(run_engine, state, move),
				"path": next_path
			})
	return []

func _route_state_after_step(run_engine: RunEngine, state: Dictionary, move: Vector2i) -> Dictionary:
	return _route_clear_current_combat(run_engine, run_engine.move_to_room(state, move))

func _route_clear_current_combat(run_engine: RunEngine, state: Dictionary) -> Dictionary:
	if str(state.get("mode", "")) != "combat":
		return state
	var next_state: Dictionary = state.duplicate(true)
	var rooms: Dictionary = next_state.get("rooms", {}).duplicate(true)
	var current: Vector2i = next_state.get("current_room", Vector2i.ZERO)
	var room_key: String = "%d,%d" % [current.x, current.y]
	var room: Dictionary = run_engine.room_metadata(next_state, current).duplicate(true)
	room["cleared"] = true
	rooms[room_key] = room
	next_state["rooms"] = rooms
	next_state["mode"] = "room"
	next_state["combat_state"] = {}
	return run_engine.repair_loaded_run_state(next_state)

func _route_search_key(state: Dictionary) -> String:
	var flags: Array[String] = []
	var rooms: Dictionary = state.get("rooms", {})
	for room_key_var: Variant in rooms.keys():
		var room_key: String = str(room_key_var)
		var room: Dictionary = rooms[room_key]
		if bool(room.get("revealed", false)) or bool(room.get("sealed", false)):
			flags.append("%s:%d:%d" % [room_key, int(room.get("revealed", false)), int(room.get("sealed", false))])
	flags.sort()
	var current: Vector2i = state.get("current_room", Vector2i.ZERO)
	return "%d,%d|%s" % [current.x, current.y, ",".join(flags)]

func _first_loot_of_kind(combat_state: Dictionary, loot_kind: String) -> Dictionary:
	for loot_var: Variant in combat_state.get("loot", []):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		var loot: Dictionary = loot_var
		if str(loot.get("kind", "")) == loot_kind:
			return loot
	return {}

func _simple_grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array[String] = []
		for x: int in range(8):
			if x == 0 or y == 0 or x == 7 or y == 7:
				row.append("wall")
			else:
				row.append("stone")
		grid.append(row)
	return grid

func _enemy_footprint_tiles_for_test(enemy: Dictionary) -> Array[Vector2i]:
	var origin: Vector2i = enemy.get("pos", Vector2i.ZERO)
	var footprint: Vector2i = enemy.get("footprint", Vector2i.ONE)
	var tiles: Array[Vector2i] = []
	for y: int in range(maxi(1, footprint.y)):
		for x: int in range(maxi(1, footprint.x)):
			tiles.append(origin + Vector2i(x, y))
	return tiles

func _find_boundary_segment(segments: Array, orientation: String) -> Dictionary:
	for segment_var: Variant in segments:
		if typeof(segment_var) != TYPE_DICTIONARY:
			continue
		var segment: Dictionary = segment_var
		if str(segment.get("orientation", "")) == orientation:
			return segment
	return {}

func _buttons_under(node: Node) -> Array[Button]:
	var buttons: Array[Button] = []
	if node is Button:
		buttons.append(node)
	for child: Node in node.get_children():
		buttons.append_array(_buttons_under(child))
	return buttons

func _choose_clicked_card_action(instance: Node, hand_index: int, play_kind: String) -> void:
	instance.call("_on_card_pressed", hand_index)
	await process_frame
	await process_frame
	_assert(int(instance.get("_card_action_choice_index")) == hand_index, "Clicking a playable hand card should open play-mode options for that exact card")
	var initial_mode: String = str(instance.get("_card_action_choice_mode"))
	if initial_mode != play_kind:
		await instance.call("_on_card_action_choice_pressed", play_kind)
		await process_frame
		await process_frame
	_assert(str(instance.get("_card_action_choice_mode")) == play_kind, "Requested play mode should be active")

func _button_with_text(node: Node, text: String) -> Button:
	for button: Button in _buttons_under(node):
		if button.text == text:
			return button
	return null

func _pass_preview_chip_state(kind: String) -> Dictionary:
	var combat: CombatEngine = CombatEngine.new()
	var has_defiance_followup: bool = kind in ["defiance_followup", "defiance_umbra"]
	var starting_hp: int = 5 if has_defiance_followup else 24
	var state: Dictionary = combat.create_combat(7826, _simple_room_layout(), {
		"hp": starting_hp,
		"max_hp": 24,
		"deck_cards": ["guarded_step", "quick_stab", "patch_up", "bone_dart"],
		"relics": [],
		"hand_size": 2,
		"heal_bonus": 0,
		"defiance_capacity": 1 if has_defiance_followup else 0,
		"defiance_remaining": 1 if has_defiance_followup else 0
	})
	var enemy_pos: Vector2i = Vector2i(3, 4)
	var enemy_intent: Dictionary = {"name": "Claw", "time": 1, "actions": [{"type": "melee", "damage": 5, "range": 1}]}
	if kind == "safe":
		enemy_pos = Vector2i(6, 4)
	elif kind == "layered":
		enemy_intent = {"name": "Crush", "time": 1, "actions": [{"type": "melee", "damage": 12, "range": 1}]}
	elif kind == "lethal":
		enemy_intent = {"name": "Crush", "time": 1, "actions": [{"type": "melee", "damage": 30, "range": 1}]}
	elif has_defiance_followup:
		enemy_intent = {"name": "Lethal Claw", "time": 1, "actions": [{"type": "melee", "damage": 6, "range": 1}]}
	elif kind == "unrevealed":
		enemy_pos = Vector2i(6, 4)
	elif kind == "umbra":
		enemy_pos = Vector2i(6, 4)
	state["player"] = {
		"pos": Vector2i(2, 4),
		"hp": starting_hp,
		"max_hp": 24,
		"block": 3 if kind == "layered" else 0,
		"stoneskin": 4 if kind == "layered" else 0,
		"burn": 0,
		"bleed": 0,
		"expose": 0,
		"freeze": 0,
		"shock": 0,
		"immobilize": false,
		"poison": {"damage": 0, "trigger": 0, "stacks": []}
	}
	state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": enemy_pos,
		"hp": 14,
		"max_hp": 14,
		"block": 0,
		"stoneskin": 0,
		"burn": 0,
		"bleed": 0,
		"expose": 0,
		"freeze": 0,
		"shock": 0,
		"immobilize": false,
		"poison": {"damage": 0, "trigger": 0, "stacks": []},
		"intent": enemy_intent
	}]
	if has_defiance_followup:
		var followup_pos := Vector2i(6, 4) if kind == "defiance_umbra" else Vector2i(2, 3)
		state["enemies"].append({
			"id": 2,
			"type": "crawler",
			"pos": followup_pos,
			"hp": 14,
			"max_hp": 14,
			"block": 0,
			"stoneskin": 0,
			"burn": 0,
			"bleed": 0,
			"expose": 0,
			"freeze": 0,
			"shock": 0,
			"immobilize": false,
			"poison": {"damage": 0, "trigger": 0, "stacks": []},
			"intent": {"name": "Follow-up", "time": 1, "actions": [{"type": "melee", "damage": 2, "range": 1}]}
		})
	state["illusions"] = []
	state["traps"] = []
	state["terrain"] = []
	state["deck"] = {
		"hand": ["guarded_step", "quick_stab"],
		"draw": ["patch_up", "bone_dart"],
		"discard": ["sidestep_slash"],
		"burned": [],
		"cycles": 0,
		"fatigue_base": 15
	}
	state["cards_per_turn"] = 2
	state["draw_per_turn"] = 2
	state["cards_played_this_turn"] = 0
	state["death_bonus_card_plays_this_turn"] = 0
	state["card_play_bonus_this_turn"] = 0
	state["player_turn_time_spent"] = 20 if kind == "unrevealed" else 0
	state["player_turn_restrictions"] = {"frozen": false, "shocked": false, "immobilized": false}
	state["pending_player_trap_restriction"] = ""
	state["turn_flags"] = {"first_attack_bonus_used": false, "first_move_bonus_used": false}
	state["initiative_clock"] = 0
	state["activation_seq"] = 1
	state["current_actor"] = {
		"kind": "player",
		"actor_key": "player",
		"name": "Reaver",
		"type": "player",
		"team": "player",
		"time": 0,
		"seq": 0
	}
	state["turn_queue"] = [{
		"kind": "enemy",
		"actor_key": "enemy_1",
		"enemy_id": 1,
		"type": "crawler",
		"name": "Tunnel Crawler",
		"team": "enemy",
		"time": 1,
		"seq": 1,
		"pos": enemy_pos
	}]
	if has_defiance_followup:
		var followup_queue_pos := Vector2i(6, 4) if kind == "defiance_umbra" else Vector2i(2, 3)
		state["turn_queue"].append({
			"kind": "enemy",
			"actor_key": "enemy_2",
			"enemy_id": 2,
			"type": "crawler",
			"name": "Tunnel Crawler",
			"team": "enemy",
			"time": 2,
			"seq": 2,
			"pos": followup_queue_pos
		})
	if kind in ["umbra", "defiance_umbra"]:
		var umbra: Dictionary = (state.get("umbra", {}) as Dictionary).duplicate(true)
		umbra["stage"] = "eclipse"
		umbra["stage_reduction"] = 0
		state["umbra"] = umbra
	return state

func _install_pass_preview_chip_state(instance: Node, combat_state: Dictionary) -> void:
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state.duplicate(true)
	instance.set("_run_state", run_state)
	_set_run_scene_combat_state_for_test(instance, combat_state.duplicate(true))
	instance.set("_animation_lock", false)
	instance.set("_drag_card_index", -1)
	instance.set("_card_play_count_override", -1)
	instance.call("_reset_card_resolution")
	instance.call("_refresh_ui")
	instance.call("_layout_combat_action_dock")
	instance.call("_layout_choice_button_overlay")

func _assert_action_context_risk(instance: Node, expected_fragment: String, expected_tone: String, context: String) -> void:
	var action_context: Control = instance.get("_action_step_tracker") as Control
	_assert(action_context != null and action_context.visible, "%s should show the action context" % context)
	if action_context == null:
		return
	var risk_text: String = str(action_context.get_meta("risk_text", ""))
	var risk_tone: String = str(action_context.get_meta("risk_tone", ""))
	_assert(risk_text.contains(expected_fragment), "%s should include risk '%s', got '%s'" % [context, expected_fragment, risk_text])
	_assert(risk_tone == expected_tone, "%s should use risk tone %s, got %s" % [context, expected_tone, risk_tone])
	var pass_chip: Button = instance.find_child("PassPreviewChip", true, false) as Button
	_assert(pass_chip != null and pass_chip.disabled and pass_chip.focus_mode == Control.FOCUS_NONE, "%s should retain the stable Pass forecast as a visibly unavailable, non-focusable control while the action context owns the current risk" % context)

func _label_text_fits(label: Label) -> bool:
	if label == null:
		return false
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= label.size.x + 1.0

func _assert_current_combat_dock_geometry(instance: Node, context: String) -> void:
	var meter: Control = instance.get("_play_meter") as Control
	var pass_chip: Control = instance.find_child("PassPreviewChip", true, false) as Control
	var pass_overlay: Control = instance.get("_pass_preview_overlay") as Control
	_assert(meter != null and meter.visible, "%s should retain a visible card-play dock" % context)
	_assert(pass_chip != null and pass_overlay != null and pass_overlay.visible, "%s should retain a visible Pass dock" % context)
	if meter == null or pass_chip == null:
		return
	var meter_rect: Rect2 = meter.get_global_rect()
	var pass_rect: Rect2 = pass_chip.get_global_rect()
	var viewport_rect := Rect2(Vector2.ZERO, instance.get_viewport().get_visible_rect().size)
	_assert(viewport_rect.encloses(meter_rect) and viewport_rect.encloses(pass_rect), "%s dock should remain fully inside the viewport" % context)
	_assert(absf(pass_rect.get_center().x - meter_rect.get_center().x) <= 1.0 and pass_rect.position.y >= meter_rect.end.y + 5.0, "%s Pass should remain centered below the card-play plaque" % context)
	var hand_bounds: Rect2 = instance.call("_combat_hand_resting_visual_bounds") as Rect2
	if hand_bounds.size.x > 0.0:
		_assert(pass_rect.end.x <= hand_bounds.position.x - 20.0, "%s dock should clear the resting hand envelope" % context)
	for pile_property: String in ["draw_pile", "discard_pile"]:
		var pile: Control = instance.get(pile_property) as Control
		if pile != null and pile.visible:
			_assert(not meter_rect.intersects(pile.get_global_rect()) and not pass_rect.intersects(pile.get_global_rect()), "%s dock should remain independent of %s" % [context, pile.name])

func _assert_pass_preview_chip(instance: Node, expected_texts: Array, expect_defeat: bool, expect_danger: bool, context: String) -> void:
	var chip: Control = instance.find_child("PassPreviewChip", true, false) as Control
	var row: Node = instance.find_child("PassPreviewDamageRow", true, false)
	_assert(chip != null, "%s should render the pass preview chip" % context)
	_assert(row != null, "%s should render the pass preview damage row" % context)
	if chip != null:
		var chip_rect: Rect2 = chip.get_global_rect()
		_assert(chip_rect.size.x >= 120.0 and chip_rect.size.y >= 40.0, "%s pass preview chip should have visible on-screen size" % context)
		var pass_art: TextureRect = chip.find_child("PassForecastFrameArtHost", true, false) as TextureRect
		_assert(pass_art != null and pass_art.get_meta("expected_target_size", Vector2i.ZERO) == Vector2i(270, 100) and pass_art.texture != null and str(pass_art.get_meta("pass_forecast_art_state", "")) == "normal", "%s pass forecast should use the native v2 normal frame" % context)
		_assert(chip.find_child("PassFocusEdgeCue", true, false) != null and chip.find_child("PassActionStateGlow", true, false) == null, "%s pass forecast should reserve code-drawn treatment for the narrow focus edge, not a colored action wash" % context)
		var preview_overlay: Control = instance.get("_pass_preview_overlay") as Control
		var piles_bar: Control = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/PilesBar") as Control
		var action_step_tracker: Control = instance.find_child(ACTION_STEP_TRACKER_PATH, true, false) as Control
		if preview_overlay != null and preview_overlay.visible and piles_bar != null:
			var piles_rect: Rect2 = piles_bar.get_global_rect()
			var viewport_width: float = instance.get_viewport().get_visible_rect().size.x
			var meter: Control = instance.get("_play_meter") as Control
			_assert(meter != null and meter.visible, "%s pass forecast should pair with the independent card-play dock" % context)
			if meter != null:
				var meter_rect: Rect2 = meter.get_global_rect()
				_assert(absf(chip_rect.get_center().x - meter_rect.get_center().x) <= 1.0 and chip_rect.position.y >= meter_rect.end.y + 5.0, "%s pass forecast should center under the card-play plaque" % context)
			_assert(not chip_rect.intersects(piles_rect), "%s Pass dock should remain independent of the pile icons" % context)
			var hand_bounds: Rect2 = instance.call("_combat_hand_resting_visual_bounds") as Rect2
			if hand_bounds.size.x > 0.0:
				_assert(chip_rect.end.x <= hand_bounds.position.x - 20.0, "%s Pass dock should clear the resting hand envelope" % context)
			_assert(chip_rect.position.x >= -1.0 and chip_rect.end.x <= viewport_width + 1.0, "%s Pass dock should stay inside the viewport" % context)
		if action_step_tracker != null and action_step_tracker.visible and action_step_tracker.size.y > 0.0:
			var tracker_rect: Rect2 = action_step_tracker.get_global_rect()
			_assert(tracker_rect.position.y + tracker_rect.size.y <= chip_rect.position.y + 1.0, "%s action-step tracker should stack above the pass preview" % context)
	if row == null:
		return
	var actual_texts: PackedStringArray = _pass_preview_chip_damage_texts(row)
	var forecast_text: String = actual_texts[0] if not actual_texts.is_empty() else ""
	for expected_text: Variant in expected_texts:
		_assert(forecast_text.contains(str(expected_text)), "%s forecast ribbon should include %s, got %s" % [context, str(expected_text), forecast_text])
	var forecast_line: Label = instance.find_child("PassPreviewForecastLine", true, false) as Label
	var action_label: Label = instance.find_child("PassActionLabel", true, false) as Label
	_assert(forecast_line != null and forecast_line.text.begins_with("TURN END"), "%s pass preview should use one turn-end forecast ribbon" % context)
	_assert(forecast_line != null and _label_text_fits(forecast_line), "%s pass forecast ribbon should fit its full text" % context)
	_assert(action_label != null and absf(action_label.get_global_rect().get_center().x - chip.get_global_rect().get_center().x) <= 1.0, "%s PASS label should be centered in the main action bay" % context)
	_assert((forecast_line != null and forecast_line.text.contains("DEFEAT")) == expect_defeat, "%s defeat forecast presence should be %s" % [context, str(expect_defeat)])
	_assert((forecast_line != null and (forecast_line.text.contains("UNKNOWN") or forecast_line.text.contains("SAFE"))) == expect_danger or not expect_danger, "%s danger forecast should retain its compact risk result" % context)

func _pass_preview_chip_damage_texts(row: Node) -> PackedStringArray:
	var texts := PackedStringArray()
	var line: Label = row.find_child("PassPreviewForecastLine", true, false) as Label
	if line != null:
		texts.append(line.text)
	return texts

func _pass_preview_chip_damage_labels(row: Node) -> Array[Label]:
	var labels: Array[Label] = []
	for label: Label in _labels_under(row):
		if _pass_preview_chip_label_is_value(label):
			labels.append(label)
	return labels

func _pass_preview_chip_label_is_value(label: Label) -> bool:
	return [
		"PassPreviewStoneSkinLoss",
		"PassPreviewBlockLoss",
		"PassPreviewHpLoss",
		"PassPreviewDefianceSpent",
		"PassPreviewHpAfterDefiance",
		"PassPreviewSafe",
		"PassPreviewUmbraUnknown",
		"PassPreviewDefeat"
	].has(str(label.name))

func _pass_preview_chip_label_uses_icon(label: Label) -> bool:
	return [
		"PassPreviewStoneSkinLoss",
		"PassPreviewBlockLoss",
		"PassPreviewHpLoss",
		"PassPreviewDefianceSpent",
		"PassPreviewHpAfterDefiance"
	].has(str(label.name))

func _pass_preview_chip_move_target(target_tiles: Array, enemy_pos: Vector2i) -> Vector2i:
	var best_tile: Vector2i = Vector2i(-1, -1)
	var best_distance: int = -1
	for tile_var: Variant in target_tiles:
		if typeof(tile_var) != TYPE_VECTOR2I:
			continue
		var tile: Vector2i = tile_var
		var distance: int = absi(tile.x - enemy_pos.x) + absi(tile.y - enemy_pos.y)
		if distance > best_distance:
			best_distance = distance
			best_tile = tile
	return best_tile

func _pre_battle_control_with_meta(root_node: Node, node_name: String, meta_key: String, expected_value: String) -> Control:
	if root_node == null:
		return null
	if root_node is Control and str(root_node.get_meta(meta_key, "")) == expected_value:
		if str(root_node.name) == node_name or str(root_node.name).begins_with("@"):
			return root_node as Control
	for child: Node in root_node.get_children():
		var match_control: Control = _pre_battle_control_with_meta(child, node_name, meta_key, expected_value)
		if match_control != null:
			return match_control
	return null

func _pre_battle_card_ids(root_node: Node, source_kind: String) -> Array:
	var card_ids: Array = []
	if root_node == null:
		return card_ids
	_pre_battle_collect_card_ids(root_node, source_kind, card_ids)
	return card_ids

func _pre_battle_collect_card_ids(node: Node, source_kind: String, card_ids: Array) -> void:
	if str(node.get_meta("source_kind", "")) == source_kind:
		var card_id: String = str(node.get_meta("card_id", ""))
		if not card_id.is_empty():
			for _copy_index: int in range(maxi(1, int(node.get_meta("card_count", 1)))):
				card_ids.append(card_id)
	for child: Node in node.get_children():
		_pre_battle_collect_card_ids(child, source_kind, card_ids)

func _combat_deck_card_ids(combat_state: Dictionary) -> Array:
	var card_ids: Array = []
	var deck: Dictionary = combat_state.get("deck", {}) as Dictionary
	for pile_name: String in ["draw", "hand", "discard", "burned"]:
		for card_id_var: Variant in deck.get(pile_name, []):
			var card_id: String = str(card_id_var)
			if not card_id.is_empty():
				card_ids.append(card_id)
	return card_ids

func _labels_under(node: Node) -> Array[Label]:
	var labels: Array[Label] = []
	if node is Label:
		labels.append(node)
	for child: Node in node.get_children():
		labels.append_array(_labels_under(child))
	return labels

func _rect_anchor_within_rect(child_rect: Rect2, parent_rect: Rect2) -> Vector2:
	if parent_rect.size.x <= 0.0 or parent_rect.size.y <= 0.0:
		return Vector2.ZERO
	return Vector2(
		(child_rect.get_center().x - parent_rect.position.x) / parent_rect.size.x,
		(child_rect.get_center().y - parent_rect.position.y) / parent_rect.size.y
	)

func _label_with_text(node: Node, text: String) -> Label:
	for label: Label in _labels_under(node):
		if label.text == text:
			return label
	return null

func _texture_rects_under(node: Node) -> Array[TextureRect]:
	var texture_rects: Array[TextureRect] = []
	if node is TextureRect:
		texture_rects.append(node)
	for child: Node in node.get_children():
		texture_rects.append_array(_texture_rects_under(child))
	return texture_rects

func _control_descendants_ignore_mouse(node: Node) -> bool:
	for child: Node in node.get_children():
		if child is Control and (child as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return false
		if not _control_descendants_ignore_mouse(child):
			return false
	return true

func _card_widget_count_under(node: Node) -> int:
	if node == null:
		return 0
	var count: int = 1 if node.get_script() == CardWidgetScript else 0
	for child: Node in node.get_children():
		count += _card_widget_count_under(child)
	return count

func _card_widgets_under(node: Node) -> Array[CardWidget]:
	var widgets: Array[CardWidget] = []
	if node == null:
		return widgets
	if node.get_script() == CardWidgetScript:
		widgets.append(node as CardWidget)
	for child: Node in node.get_children():
		widgets.append_array(_card_widgets_under(child))
	return widgets

func _run_scene_choice_button_host(instance: Node) -> Node:
	var overlay: Node = instance.get("_choice_button_overlay") as Node
	if overlay != null and overlay.get_child_count() > 0:
		return overlay
	return instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/LeftActionStack/ChoiceBar")

func _assert_button_text_centered(button: Button, message: String) -> void:
	_assert(button.alignment == HORIZONTAL_ALIGNMENT_CENTER, "%s text should be mathematically centered" % message)
	_assert(bool(button.get_meta("settings_text_centered", false)), "%s should carry the settings centering contract" % message)
	var normal_style: StyleBox = button.get_theme_stylebox("normal")
	_assert(normal_style is StyleBoxFlat, "%s should use the code-native themed background" % message)
	if normal_style is StyleBoxFlat:
		var flat := normal_style as StyleBoxFlat
		_assert(is_equal_approx(flat.content_margin_left, flat.content_margin_right), "%s should reserve equal left/right text margins" % message)

func _assert_button_uses_variant(button: Button, min_height: float, variant: String, message: String) -> void:
	var minimum_size: Vector2 = button.custom_minimum_size
	_assert(minimum_size.y >= min_height, message)
	if minimum_size.y <= 0.0:
		_failures.append("%s should have a positive minimum height" % message)
		return
	var native_size: Vector2 = UiSkin.new().button_native_size(minimum_size.y, 0.0, variant)
	_assert(minimum_size.x >= native_size.x, "%s should meet the variant's content-aware native width" % message)
	_assert(str(button.get_meta("button_variant", "")) == variant, "%s should carry the expected themed variant" % message)
	_assert(button.get_theme_stylebox("normal") is StyleBoxFlat, "%s should not use a stretched bitmap StyleBox" % message)
	_assert(button.get_node_or_null(UiSkin.BUTTON_ORNAMENT_NAME) != null, "%s should render the shared scalable ornament" % message)

func _assert_board_kept_animating_enemy(board_view: Node, expected_tile: Vector2i, context: String) -> void:
	var rendered_state: Dictionary = board_view.get("combat_state")
	var enemies: Array = rendered_state.get("enemies", [])
	if enemies.is_empty():
		_failures.append("%s should keep a rendered enemy on the board" % context)
		return
	var enemy: Dictionary = enemies[0]
	_assert(enemy.get("pos", Vector2i.ZERO) == expected_tile, "%s should not redraw stale combat state over the active animation" % context)
	var presentation: Dictionary = board_view.get("presentation")
	_assert((presentation.get("unit_world_positions", {}) as Dictionary).has("enemy_1"), "%s should preserve moving unit presentation" % context)
	_assert((presentation.get("unit_draw_tiles", {}) as Dictionary).has("enemy_1"), "%s should preserve moving unit draw tile" % context)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
