extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const PathUtils = preload("res://scripts/path_utils.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const UnitShadowCacheResourceScript = preload("res://scripts/unit_shadow_cache_resource.gd")

const HAND: Array[String] = [
	"sidestep_slash",
	"quick_stab",
	"guarded_step",
	"bone_dart",
	"thunderline",
	"patch_up",
	"updraft"
]
const OPTION_COLD_BATCHES: int = 3
const OPTION_CACHED_BATCHES: int = 20
const HOVER_CACHED_BATCHES: int = 4
const REPEATED_HOVER_ITERATIONS: int = 40
const PASS_COLD_BATCHES: int = 3
const PASS_CACHED_BATCHES: int = 40
const UI_COLD_BATCHES: int = 3
const UI_CACHED_BATCHES: int = 5

var _errors: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://labyrinth_progression_runtime_integration_performance.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_runtime_integration_performance.save")
	ProgressionStore.clear_saved_run()

	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle_ui()
	print("RUNTIME INTEGRATION STEP: scene_settled")
	var combat := CombatEngine.new()
	var installed_state: Dictionary = _install_stress_combat(instance, combat)
	print("RUNTIME INTEGRATION STEP: stress_combat_installed")
	await _settle_ui()
	await _settle_action_tracker_prewarm(instance)
	print("RUNTIME INTEGRATION STEP: tracker_prewarm_settled")
	_verify_aoe_target_semantics(instance, combat, installed_state)
	print("RUNTIME INTEGRATION STEP: aoe_semantics_verified")
	var flurry_preview_shortcut: Dictionary = _verify_flurry_skip_suffix_preview_semantics(instance, combat, installed_state)
	print("RUNTIME INTEGRATION STEP: flurry_semantics_verified")
	var enemy_round_lock_ui: Dictionary = await _verify_enemy_round_lock_ui_equivalence(instance)
	print("RUNTIME INTEGRATION STEP: enemy_lock_ui_verified")
	var frame_sliced_unlock: Dictionary = await _verify_frame_sliced_unlock_atomicity(instance)
	print("RUNTIME INTEGRATION STEP: sliced_unlock_verified")
	var skill_sigil_event_cache: Dictionary = await _verify_skill_sigil_event_cache(instance)
	print("RUNTIME INTEGRATION STEP: sigil_cache_verified")
	var board: Control = instance.get_node("BoardUnderlay/CombatBoard") as Control
	var unit_shadow_local_mesh: Dictionary = _verify_unit_shadow_local_mesh_equivalence(board)
	var source_snapshot: Dictionary = installed_state.duplicate(true)
	var results: Dictionary = {
		"schema_version": 1,
		"hand_card_count": HAND.size(),
		"initial_node_count": _subtree_node_count(instance),
		"flurry_preview_shortcut": flurry_preview_shortcut,
		"enemy_round_lock_ui": enemy_round_lock_ui,
		"frame_sliced_unlock": frame_sliced_unlock,
		"skill_sigil_event_cache": skill_sigil_event_cache,
		"unit_shadow_local_mesh": unit_shadow_local_mesh,
	}
	var render_counts_before: Dictionary = board.call("render_instrumentation_snapshot") as Dictionary
	# Exercise a real presentation change. Repeating _refresh_stage_view with an
	# unchanged retained snapshot may correctly produce no redraw at all.
	for tile: Vector2i in [Vector2i(4, 4), Vector2i(3, 4)]:
		var motion := InputEventMouseMotion.new()
		motion.position = board.call("_tile_center", tile) as Vector2
		board.call("_gui_input", motion)
	await _settle_ui()
	var render_counts_after: Dictionary = board.call("render_instrumentation_snapshot") as Dictionary
	_expect(bool(render_counts_after.get("split_layers_active", false)), "combat board did not activate its retained static render layer")
	_expect(int(render_counts_after.get("static_draw_count", -1)) == int(render_counts_before.get("static_draw_count", -2)), "presentation-only refresh redrew the invariant floor layer")
	_expect(int(render_counts_after.get("dynamic_draw_count", 0)) > int(render_counts_before.get("dynamic_draw_count", 0)), "presentation refresh did not redraw the dynamic board layer")
	results["board_render_counts_before"] = render_counts_before
	results["board_render_counts_after"] = render_counts_after

	# Exercise real hand-card option generation through RunScene, then prove the warm
	# sweep returns the same semantic result without growing its option cache.
	var cold_option_stats: Dictionary = _measure_sync_samples(OPTION_COLD_BATCHES, func() -> void:
		instance.call("_mark_combat_preview_state_changed")
		_option_sweep(instance)
	)
	_record_metric(results, "card_options_cold_us_per_sweep", cold_option_stats)
	var rebuilt_option_digest: int = _option_digest(instance)
	var option_cache_size: int = (instance.get("_card_play_options_cache") as Dictionary).size()
	var cached_option_stats: Dictionary = _measure_sync_samples(OPTION_CACHED_BATCHES, func() -> void:
		_option_sweep(instance)
	)
	_record_metric(results, "card_options_cached_us_per_sweep", cached_option_stats)
	var cached_option_digest: int = _option_digest(instance)
	_expect(rebuilt_option_digest == cached_option_digest, "cached card options differ from a cold rebuild")
	_expect((instance.get("_card_play_options_cache") as Dictionary).size() == option_cache_size, "cached card-option sweeps grew the option cache")
	results["card_option_digest"] = cached_option_digest
	results["card_option_cache_entries"] = option_cache_size
	results["card_preview_cold_us_by_id"] = _profile_cold_printed_previews(instance)

	# Measure the complete real UI refresh synchronously while draining deferred
	# layout work between samples. Cold samples invalidate all view signatures;
	# warm samples retain the hand, piles, relic bar, and turn-order subtrees.
	var ui_cold: Dictionary = await _measure_ui_refreshes(instance, UI_COLD_BATCHES, true)
	_record_metric(results, "full_ui_cold_us_per_refresh", ui_cold.get("stats", {}))
	var ui_cached: Dictionary = await _measure_ui_refreshes(instance, UI_CACHED_BATCHES, false)
	_record_metric(results, "full_ui_cached_us_per_refresh", ui_cached.get("stats", {}))
	var ui_node_counts: Array = ui_cached.get("node_counts", [])
	_expect(_all_ints_equal(ui_node_counts), "cached full UI refresh changed the settled scene-tree node count")
	results["cached_ui_node_counts"] = ui_node_counts
	for method_name: String in [
		"_sync_analytics_combat_tracker",
		"_sync_progression_from_run",
		"_sync_grimoire_discoveries",
		"_refresh_relic_bar",
		"_refresh_turn_order_bar",
		"_layout_header_hud",
		"_refresh_elemental_intensity_bar",
		"_refresh_pile_counts",
		"_refresh_card_play_meter",
		"_refresh_action_step_tracker",
		"_refresh_pile_visuals",
		"_refresh_choice_bar",
		"_refresh_stage_view",
		"_refresh_hand_panel",
		"_refresh_visibility",
		"_sync_pre_battle_preview_after_refresh",
		"_layout_action_step_tracker",
		"_refresh_grimoire_badge",
		"_refresh_contextual_combat_tutorial"
	]:
		_record_metric(
			results,
			"component%s_us_per_call" % method_name,
			_measure_instance_method(instance, method_name, 5)
		)

	# Select the printed move-then-attack card through its actual input handler.
	await instance.call("_on_card_pressed", 0)
	await _settle_ui()
	_expect(int(instance.get("_selected_card_index")) == 0, "Sidestep Slash did not enter selected-card preview")
	var move_preview: Dictionary = instance.call("_active_card_preview") as Dictionary
	_expect(str((move_preview.get("action", {}) as Dictionary).get("type", "")) == "move", "first selected preview action is not move")
	var move_targets: Array[Vector2i] = _sorted_tiles(move_preview.get("target_tiles", []))
	_expect(not move_targets.is_empty(), "selected move preview produced no legal targets")
	results["move_hover_target_count"] = move_targets.size()
	var committed_before_move_hovers: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)

	instance.call("_invalidate_preview_derived_caches")
	var move_hover_cold: Dictionary = _measure_hover_sweep(instance, move_targets, 1)
	_record_metric(results, "selected_move_hover_cold_us_per_tile", move_hover_cold)
	var move_cache_size: int = (instance.get("_pass_preview_cache") as Dictionary).size()
	var move_hover_cached: Dictionary = _measure_hover_sweep(instance, move_targets, HOVER_CACHED_BATCHES)
	_record_metric(results, "selected_move_hover_cached_us_per_tile", move_hover_cached)
	_expect((instance.get("_pass_preview_cache") as Dictionary).size() == move_cache_size, "cached move-hover sweeps grew the pass-preview cache")

	var move_target: Vector2i = _move_target_with_followup_attack(combat, move_preview, Vector2i(4, 2))
	_expect(move_target.x >= 0, "move preview has no target with a legal follow-up attack")
	if move_target.x >= 0:
		instance.call("_on_board_tile_hovered", move_target)
		var move_presentation_digest: int = hash((instance.get("_board_presentation") as Dictionary))
		var shortcut_key_before: String = str(instance.get("_preview_shortcuts_cache_key"))
		var repeated_move_cache_size: int = (instance.get("_pass_preview_cache") as Dictionary).size()
		var repeated_move_stats: Dictionary = _measure_sync_samples(5, func() -> void:
			for _iteration: int in range(REPEATED_HOVER_ITERATIONS):
				instance.call("_on_board_tile_hovered", move_target)
		)
		_scale_metric_in_place(repeated_move_stats, REPEATED_HOVER_ITERATIONS)
		_record_metric(results, "selected_move_repeated_hover_us_per_call", repeated_move_stats)
		_expect(str(instance.get("_preview_shortcuts_cache_key")) == shortcut_key_before, "repeated move hover changed the shortcut-cache key")
		_expect((instance.get("_pass_preview_cache") as Dictionary).size() == repeated_move_cache_size, "repeated move hover grew the pass-preview cache")
		_expect(hash(instance.get("_board_presentation") as Dictionary) == move_presentation_digest, "repeated move hover changed board presentation semantics")

	_expect(instance.get("_combat_state") as Dictionary == committed_before_move_hovers, "move preview/hover handling mutated committed combat state")
	instance.call("_cancel_card_selection")
	await _settle_ui()
	# Current two-click compound targeting may resolve a uniquely determined
	# move-plus-melee sequence from the first board click. Measure attack hover
	# independently through Bone Dart's real routed card-selection path so this
	# read-only integration workload never commits a card while profiling.
	await instance.call("_on_card_pressed", HAND.find("bone_dart"))
	await _settle_ui()
	var attack_preview: Dictionary = instance.call("_active_card_preview") as Dictionary
	_expect(str((attack_preview.get("action", {}) as Dictionary).get("type", "")) == "ranged", "selected Bone Dart preview action is not ranged")
	var attack_targets: Array[Vector2i] = _sorted_tiles(attack_preview.get("target_tiles", []))
	_expect(not attack_targets.is_empty(), "selected follow-up attack produced no legal targets")
	results["attack_hover_target_count"] = attack_targets.size()
	var preview_state_before_attack_hovers: Dictionary = (instance.get("_preview_combat_state") as Dictionary).duplicate(true)

	instance.call("_invalidate_preview_derived_caches")
	var attack_hover_cold: Dictionary = _measure_hover_sweep(instance, attack_targets, 1)
	_record_metric(results, "selected_attack_hover_cold_us_per_tile", attack_hover_cold)
	var attack_cache_size: int = (instance.get("_pass_preview_cache") as Dictionary).size()
	var attack_hover_cached: Dictionary = _measure_hover_sweep(instance, attack_targets, HOVER_CACHED_BATCHES)
	_record_metric(results, "selected_attack_hover_cached_us_per_tile", attack_hover_cached)
	_expect((instance.get("_pass_preview_cache") as Dictionary).size() == attack_cache_size, "cached attack-hover sweeps grew the pass-preview cache")

	if not attack_targets.is_empty():
		var attack_target: Vector2i = attack_targets[0]
		instance.call("_on_board_tile_hovered", attack_target)
		var attack_presentation_digest: int = hash(instance.get("_board_presentation") as Dictionary)
		var repeated_attack_cache_size: int = (instance.get("_pass_preview_cache") as Dictionary).size()
		var repeated_attack_stats: Dictionary = _measure_sync_samples(5, func() -> void:
			for _iteration: int in range(REPEATED_HOVER_ITERATIONS):
				instance.call("_on_board_tile_hovered", attack_target)
		)
		_scale_metric_in_place(repeated_attack_stats, REPEATED_HOVER_ITERATIONS)
		_record_metric(results, "selected_attack_repeated_hover_us_per_call", repeated_attack_stats)
		_expect((instance.get("_pass_preview_cache") as Dictionary).size() == repeated_attack_cache_size, "repeated attack hover grew the pass-preview cache")
		_expect(hash(instance.get("_board_presentation") as Dictionary) == attack_presentation_digest, "repeated attack hover changed board presentation semantics")

		# Forecast the enemy round from the selected attack hover. The cold path is
		# intentionally invalidated per sample; the warm path must retain exactly one
		# entry for this unchanged interaction state.
		var cold_pass_stats: Dictionary = _measure_sync_samples(PASS_COLD_BATCHES, func() -> void:
			instance.call("_invalidate_preview_derived_caches")
			instance.call("_pass_preview_summary")
		)
		_record_metric(results, "selected_pass_forecast_cold_us_per_call", cold_pass_stats)
		instance.call("_invalidate_preview_derived_caches")
		var cold_pass_summary: Dictionary = instance.call("_pass_preview_summary") as Dictionary
		var pass_cache_size: int = (instance.get("_pass_preview_cache") as Dictionary).size()
		var cached_pass_stats: Dictionary = _measure_sync_samples(PASS_CACHED_BATCHES, func() -> void:
			instance.call("_pass_preview_summary")
		)
		_record_metric(results, "selected_pass_forecast_cached_us_per_call", cached_pass_stats)
		var cached_pass_summary: Dictionary = instance.call("_pass_preview_summary") as Dictionary
		_expect(not cold_pass_summary.is_empty(), "selected attack pass forecast was empty")
		_expect(cold_pass_summary == cached_pass_summary, "cached pass forecast differs from cold forecast")
		_expect(pass_cache_size == 1, "single-state pass forecast did not populate exactly one cache entry")
		_expect((instance.get("_pass_preview_cache") as Dictionary).size() == pass_cache_size, "cached pass forecasts grew the pass-preview cache")
		results["pass_forecast_digest"] = hash(cached_pass_summary)
		results["pass_forecast_cache_entries"] = pass_cache_size

	_expect(instance.get("_preview_combat_state") as Dictionary == preview_state_before_attack_hovers, "attack hover/forecast handling mutated preview combat state")
	_expect(instance.get("_combat_state") as Dictionary == source_snapshot, "integration benchmark mutated committed combat state")
	await _settle_ui()
	results["final_node_count"] = _subtree_node_count(instance)
	results["committed_state_unchanged"] = instance.get("_combat_state") as Dictionary == source_snapshot
	results["preview_state_unchanged_during_attack_hover"] = instance.get("_preview_combat_state") as Dictionary == preview_state_before_attack_hovers
	results["semantic_errors"] = _errors

	if _errors.is_empty():
		print("RUNTIME INTEGRATION PERF RESULT: %s" % JSON.stringify(results))
	else:
		push_error("RUNTIME INTEGRATION PERF RESULT: FAIL %s" % JSON.stringify(results))
	instance.free()
	await process_frame
	await process_frame
	ProgressionStore.clear_saved_run()
	quit(0 if _errors.is_empty() else 1)

func _install_stress_combat(instance: Node, combat: CombatEngine) -> Dictionary:
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var layout: Dictionary = {
		"name": "Runtime Integration Performance Chamber",
		"coord": Vector2i(4, 3),
		"depth": 8,
		"type": "combat",
		"element": "ice",
		"grid": _stress_grid(),
		"player_start": Vector2i(4, 4),
		"enemies": _stress_enemies(),
		"traps": [
			{"id": "perf_fire", "pos": Vector2i(3, 4), "element": "fire", "damage": 20, "burn": 10},
			{"id": "perf_ice", "pos": Vector2i(5, 4), "element": "ice", "damage": 20, "freeze": 1},
			{"id": "perf_earth", "pos": Vector2i(4, 6), "element": "earth", "damage": 20, "immobilize": true}
		],
		"loot": [
			{"id": "perf_ember_a", "kind": "embers", "amount": 2, "pos": Vector2i(2, 4), "claimed": false},
			{"id": "perf_ember_b", "kind": "embers", "amount": 2, "pos": Vector2i(6, 4), "claimed": false}
		],
		"terrain": []
	}
	var combat_state: Dictionary = combat.create_combat(9021001, layout, {
		"hp": 320,
		"max_hp": 320,
		"deck_cards": HAND.duplicate(),
		"relics": [],
		"hand_size": HAND.size(),
		"cards_per_turn": 3,
		"draw_per_turn": HAND.size(),
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = HAND.duplicate()
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["player"] = {
		"pos": Vector2i(4, 4),
		"hp": 320,
		"max_hp": 320,
		"block": 30,
		"stoneskin": 20
	}
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	combat_state["cards_played_this_turn"] = 0
	combat_state["death_bonus_card_plays_this_turn"] = 0
	combat_state["card_play_bonus_this_turn"] = 0
	combat_state["player_turn_restrictions"] = {"immobilized": false, "frozen": false, "shocked": false}

	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout.duplicate(true)
	run_state["combat_state"] = combat_state
	run_state["relics"] = []
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.set("_animation_lock", false)
	instance.call("_mark_combat_preview_state_changed")
	var board: Control = instance.get_node("BoardUnderlay/CombatBoard") as Control
	# Match the shipped prebattle lifecycle: the encounter preview loads its unit
	# textures before Start is enabled, while Start itself only verifies exact
	# generated shadow data for the already-known composition.
	board.call("prepare_unit_assets_for_state", combat_state)
	var prepare_frame_before: int = Engine.get_process_frames()
	var prepare_started_usec: int = Time.get_ticks_usec()
	var shadows_ready: bool = bool(board.call("prepare_unit_shadows_for_state", combat_state))
	var prepare_elapsed_usec: int = Time.get_ticks_usec() - prepare_started_usec
	_expect(shadows_ready, "generated unit-shadow data must make immediate combat Start exact and ready")
	_expect(Engine.get_process_frames() == prepare_frame_before, "combat Start shadow preparation must not wait for a rendered or process frame")
	_expect(prepare_elapsed_usec < 16667, "combat Start shadow preparation must stay inside one 60 Hz CPU budget")
	_expect(int(board.get("_unit_shadow_last_prepare_waited_frames")) == 0, "combat Start shadow preparation must report zero waited frames")
	_expect((board.get("_unit_shadow_precomputed_missing_keys") as Dictionary).is_empty(), "generated unit-shadow cache must cover every loaded player, enemy, NPC, idle, and death texture")
	_expect(
		(board.get("_unit_shadow_prewarm_pending_ids") as Dictionary).is_empty(),
		"complete generated shadow coverage must leave no background worker ownership: %s" % str((board.get("_unit_shadow_prewarm_pending_ids") as Dictionary).keys())
	)
	_expect(
		(board.get("_unit_shadow_prewarm_urgent_queue") as Array).is_empty(),
		"complete generated shadow coverage must leave no urgent shadow queue: %d" % (board.get("_unit_shadow_prewarm_urgent_queue") as Array).size()
	)
	_expect(
		(board.get("_unit_shadow_prewarm_background_queue") as Array).is_empty(),
		"complete generated shadow coverage must leave no background shadow queue: %d" % (board.get("_unit_shadow_prewarm_background_queue") as Array).size()
	)
	_verify_unit_shadow_cache_source_hashes(board)
	var immediate_shadow_textures: Array = board.call("_unit_shadow_immediate_textures_for_state", combat_state) as Array
	_expect(immediate_shadow_textures.size() <= 3, "stress composition should gate only on one current texture per living unit type")
	for texture_var: Variant in immediate_shadow_textures:
		var texture: Texture2D = texture_var as Texture2D
		var texture_ready: bool = texture != null and (board.get("_unit_shadow_polygon_cache") as Dictionary).has(texture.get_instance_id())
		_expect(texture_ready, "the first visible animation frame must use its exact generated shadow geometry")
	board.call("reset_render_instrumentation")
	instance.call("_refresh_ui")
	RenderingServer.force_draw()
	var immediate_draw_metrics: Dictionary = board.call("render_instrumentation_snapshot") as Dictionary
	_expect(int((immediate_draw_metrics.get("unit_shadow_sync_misses", {}) as Dictionary).get("count", 0)) == 0, "first combat draw must not synchronously extract any unit-shadow geometry")
	_expect(int((immediate_draw_metrics.get("unit_shadow_draw_cache", {}) as Dictionary).get("fallback", 0)) == 0, "first combat draw must not substitute a generic shadow")
	return combat_state

func _verify_unit_shadow_cache_source_hashes(board: Control) -> void:
	var cache: Resource = load(CombatBoardView.UNIT_SHADOW_CACHE_PATH) as Resource
	_expect(cache != null, "generated unit-shadow cache must load as a production resource")
	if cache != null:
		_expect(int(cache.get("schema_version")) == UnitShadowCacheResourceScript.SCHEMA_VERSION, "generated unit-shadow cache schema must match runtime extraction")
		_expect(str(cache.get("extraction_signature")) == UnitShadowCacheResourceScript.expected_extraction_signature(), "generated unit-shadow cache extraction constants must match runtime extraction")
	var expected_hashes: Dictionary = board.get("_unit_shadow_precomputed_source_sha256") as Dictionary
	_expect(not expected_hashes.is_empty(), "generated unit-shadow cache must publish source fingerprints")
	for source_path_var: Variant in expected_hashes:
		var source_path: String = str(source_path_var)
		_expect(
			FileAccess.get_sha256(source_path) == str(expected_hashes[source_path_var]),
			"generated unit-shadow cache must match source art: %s" % source_path
		)

func _stress_grid() -> Array:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x == 0 or y == 0 or x == 8 or y == 8 else "stone")
		grid.append(row)
	return grid

func _stress_enemies() -> Array:
	return [
		_enemy(1, "crawler", Vector2i(4, 1)),
		_enemy(2, "harrier", Vector2i(3, 2)),
		_enemy(3, "crawler", Vector2i(5, 2)),
		_enemy(4, "harrier", Vector2i(2, 6)),
		_enemy(5, "crawler", Vector2i(6, 6)),
		_enemy(6, "harrier", Vector2i(7, 4))
	]

func _enemy(enemy_id: int, enemy_type: String, pos: Vector2i) -> Dictionary:
	return {
		"id": enemy_id,
		"type": enemy_type,
		"pos": pos,
		"hp": 180,
		"max_hp": 180,
		"block": 10,
		"stoneskin": 0
	}

func _option_sweep(instance: Node) -> void:
	for index: int in range(HAND.size()):
		instance.call("_card_play_options_for_index", index)

func _option_digest(instance: Node) -> int:
	var canonical: Array = []
	for index: int in range(HAND.size()):
		var options: Dictionary = instance.call("_card_play_options_for_index", index) as Dictionary
		canonical.append({
			"play": _preview_digest(options.get("play", {})),
			"printed_playable": bool(options.get("printed_playable", false)),
			"any_playable": bool(options.get("any_playable", false))
		})
	return hash(canonical)

func _profile_cold_printed_previews(instance: Node) -> Dictionary:
	var result: Dictionary = {}
	for index: int in range(HAND.size()):
		instance.call("_mark_combat_preview_state_changed")
		var started_us: int = Time.get_ticks_usec()
		instance.call("_card_preview_for_index", index)
		result[HAND[index]] = Time.get_ticks_usec() - started_us
	return result

func _verify_aoe_target_semantics(instance: Node, combat: CombatEngine, state: Dictionary) -> void:
	var card: Dictionary = instance.call("_card_def", "thunderline", state) as Dictionary
	var actions: Array = card.get("actions", [])
	_expect(not actions.is_empty(), "AOE semantic fixture could not load Thunderline")
	if actions.is_empty():
		return
	var base_action: Dictionary = (actions[0] as Dictionary).duplicate(true)
	var variants: Array[Dictionary] = []
	variants.append(base_action)
	for direction: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var oriented: Dictionary = base_action.duplicate(true)
		oriented["orientation"] = direction
		variants.append(oriented)
	for action: Dictionary in variants:
		var optimized: Array[Vector2i] = _sorted_tiles(combat.valid_targets_for_player_action(state, action))
		var reference: Array[Vector2i] = _reference_aoe_targets(combat, state, action)
		_expect(optimized == reference, "optimized AOE legality differs from privacy-safe reference targeting for %s" % str(action.get("orientation", "automatic")))

func _verify_flurry_skip_suffix_preview_semantics(instance: Node, combat: CombatEngine, source_state: Dictionary) -> Dictionary:
	var state: Dictionary = source_state.duplicate(true)
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["cinder_fusillade"]
	state["deck"] = deck
	state["cards_per_turn"] = 20
	state["cards_played_this_turn"] = 0
	state["death_bonus_card_plays_this_turn"] = 0
	state["card_play_bonus_this_turn"] = 0
	var prepared_state: Dictionary = combat.prepare_player_card(state, 0, "play")
	var actions: Array = combat.card_play_actions("cinder_fusillade", prepared_state)
	var shortcut_started: int = Time.get_ticks_usec()
	var shortcut_preview: Dictionary = instance.call(
		"_card_preview_from_state", "cinder_fusillade", prepared_state, actions, 0, false, true, true
	) as Dictionary
	var shortcut_usec: int = Time.get_ticks_usec() - shortcut_started
	var reference_started: int = Time.get_ticks_usec()
	var reference_preview: Dictionary = instance.call(
		"_card_preview_from_state", "cinder_fusillade", prepared_state, actions, 0, false, true, false
	) as Dictionary
	var reference_usec: int = Time.get_ticks_usec() - reference_started
	_expect(shortcut_preview == reference_preview, "Flurry skip-suffix preview shortcut must match the complete target walk")
	_expect(actions.size() == 40, "Flurry shortcut fixture must exercise twenty complete repetitions")
	return {
		"action_count": actions.size(),
		"preview_digest": hash(shortcut_preview),
		"shortcut_usec": shortcut_usec,
		"reference_usec": reference_usec,
	}

func _verify_enemy_round_lock_ui_equivalence(instance: Node) -> Dictionary:
	await _await_hand_layout_ready(instance)
	instance.set("_animation_lock", true)
	var full_started: int = Time.get_ticks_usec()
	instance.call("_refresh_animation_lock_ui")
	var full_usec: int = Time.get_ticks_usec() - full_started
	var full_snapshot: Dictionary = _enemy_round_lock_ui_snapshot(instance)
	instance.set("_animation_lock", false)
	instance.call("_refresh_ui")
	await _await_hand_layout_ready(instance)
	instance.set("_animation_lock", true)
	var retained_started: int = Time.get_ticks_usec()
	instance.call("_refresh_enemy_round_lock_ui")
	var retained_usec: int = Time.get_ticks_usec() - retained_started
	var retained_snapshot: Dictionary = _enemy_round_lock_ui_snapshot(instance)
	var snapshot_differences: Dictionary = _dictionary_differences(full_snapshot, retained_snapshot)
	_expect(
		snapshot_differences.is_empty(),
		"retained enemy-round lock UI must match the complete lock refresh: %s" % str(snapshot_differences)
	)
	instance.set("_animation_lock", false)
	instance.call("_refresh_ui")
	await _await_hand_layout_ready(instance)
	return {
		"snapshot_digest": hash(retained_snapshot),
		"full_usec": full_usec,
		"retained_usec": retained_usec,
		"snapshot_differences": snapshot_differences,
	}

func _verify_frame_sliced_unlock_atomicity(instance: Node) -> Dictionary:
	instance.call("set_runtime_performance_instrumentation_enabled", true)
	var production_refresh_started_frame: int = Engine.get_process_frames()
	instance.set("_animation_lock", true)
	instance.call("_refresh_ui", false, true, false)
	var fast_path_synchronous: bool = (
		not bool(instance.get("_frame_sliced_ui_refresh_active"))
		and not bool(instance.get("_animation_lock"))
		and Engine.get_process_frames() == production_refresh_started_frame
	)
	_expect(fast_path_synchronous, "production final refresh must preserve its zero-extra-frame click-to-interactive cadence")
	var observed_slice_frames: int = Engine.get_process_frames() - production_refresh_started_frame
	var below_budget_without_telemetry: int = int(instance.call("_runtime_elapsed_excluding_telemetry_usec", 7999, 0))
	var below_budget_with_telemetry: int = int(instance.call("_runtime_elapsed_excluding_telemetry_usec", 8499, 500))
	var at_budget_without_telemetry: int = int(instance.call("_runtime_elapsed_excluding_telemetry_usec", 8000, 0))
	var at_budget_with_telemetry: int = int(instance.call("_runtime_elapsed_excluding_telemetry_usec", 8500, 500))
	_expect(below_budget_without_telemetry == below_budget_with_telemetry, "telemetry bookkeeping must not advance an enemy/UI slice toward its CPU budget")
	_expect(at_budget_without_telemetry == at_budget_with_telemetry, "slice exhaustion must occur at the same gameplay-work boundary with instrumentation on or off")
	var pass_button: Button = instance.find_child("PassPreviewChip", true, false) as Button
	_expect(pass_button != null and not pass_button.disabled, "Pass must become interactive only after the sliced refresh completes")
	var sections: Dictionary = instance.call("runtime_performance_instrumentation_snapshot") as Dictionary
	var inclusive_totals: Array[String] = []
	for phase: String in [
		"refresh_ui_relic_bar_total",
		"refresh_ui_turn_order_total",
		"refresh_ui_action_step_tracker_total",
		"refresh_ui_choice_bar_total",
		"refresh_ui_stage_total",
		"refresh_ui_hand_total",
	]:
		inclusive_totals.append(phase)
	for phase: String in inclusive_totals:
		_expect(sections.has(phase), "inclusive runtime wrapper must use the Steam-excluded _total suffix: %s" % phase)
		_expect(not sections.has(phase.trim_suffix("_total")), "legacy inclusive wrapper name would double-count Steam section time: %s" % phase.trim_suffix("_total"))
	var frame_profile: Dictionary = instance.call("runtime_performance_frame_instrumentation_snapshot") as Dictionary
	for frame_var: Variant in frame_profile.get("top_frames", []):
		var frame: Dictionary = frame_var as Dictionary
		var exclusive_sum: int = 0
		for phase_usec_var: Variant in (frame.get("exclusive_phase_usec", {}) as Dictionary).values():
			exclusive_sum += int(phase_usec_var)
		_expect(exclusive_sum == int(frame.get("exclusive_total_usec", -1)), "each retained frame must partition its CPU union exactly once")
	instance.call("set_runtime_performance_instrumentation_enabled", false)
	instance.call("set_runtime_performance_instrumentation_enabled", true)
	var crossed_base_usec: int = Time.get_ticks_usec() - 1000
	instance.call("_record_external_runtime_performance_interval", "crossed_left", crossed_base_usec, crossed_base_usec + 700, false)
	instance.call("_record_external_runtime_performance_interval", "crossed_right", crossed_base_usec + 300, crossed_base_usec + 1000, false)
	var crossed_sections: Dictionary = instance.call("runtime_performance_instrumentation_snapshot") as Dictionary
	_expect(crossed_sections.has("telemetry_ambiguous_overlap"), "real RunScene snapshots must retain exclusive-only ambiguity buckets")
	_expect(int((crossed_sections.get("telemetry_ambiguous_overlap", {}) as Dictionary).get("exclusive_total_usec", 0)) == 400, "real RunScene ambiguity attribution must preserve the crossed overlap")
	instance.call("set_runtime_performance_instrumentation_enabled", false)
	var dense_off_started_usec: int = Time.get_ticks_usec()
	for _dense_index: int in range(64):
		instance.call("_record_runtime_performance_phase", "telemetry_dense_leaf", Time.get_ticks_usec())
	instance.call("runtime_performance_frame_instrumentation_snapshot")
	var dense_off_usec: int = Time.get_ticks_usec() - dense_off_started_usec
	instance.call("set_runtime_performance_instrumentation_enabled", true)
	var dense_on_started_usec: int = Time.get_ticks_usec()
	for _dense_index: int in range(64):
		instance.call("_record_runtime_performance_phase", "telemetry_dense_leaf", Time.get_ticks_usec())
	var dense_profile: Dictionary = instance.call("runtime_performance_frame_instrumentation_snapshot") as Dictionary
	var dense_on_usec: int = Time.get_ticks_usec() - dense_on_started_usec
	var dense_overhead_usec: int = int(dense_profile.get("telemetry_record_overhead_usec", 0))
	var dense_commit_overhead_usec: int = int(dense_profile.get("telemetry_commit_overhead_usec", 0))
	_expect(dense_overhead_usec > 0, "actual dense instrumentation must report positive record bookkeeping overhead")
	_expect(dense_commit_overhead_usec > 0, "actual dense instrumentation must report its partition/commit overhead")
	_expect(maxi(0, dense_on_usec - dense_off_usec) < 16667, "64 dense section timers must add less than one 60 Hz frame of instrumentation overhead")
	instance.call("set_runtime_performance_instrumentation_enabled", false)
	return {
		"observed_slice_frames": observed_slice_frames,
		"fast_path_synchronous": fast_path_synchronous,
		"pass_enabled_after_completion": pass_button != null and not pass_button.disabled,
		"inclusive_total_names": inclusive_totals,
		"dense_record_overhead_usec": dense_overhead_usec,
		"dense_commit_overhead_usec": dense_commit_overhead_usec,
		"dense_incremental_wall_usec": maxi(0, dense_on_usec - dense_off_usec),
	}

func _verify_skill_sigil_event_cache(instance: Node) -> Dictionary:
	var original_combat_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	var original_signature: String = str(instance.get("_relic_bar_signature"))
	var original_event_revision_seen: int = int(instance.get("_skill_event_revision_seen"))
	var original_run_event_revision_seen: int = int(instance.get("_run_skill_event_revision_seen"))
	var fixture: Dictionary = original_combat_state.duplicate(true)
	fixture["skill_ids"] = ["quick_wits"]
	fixture["skill_event_revision"] = original_event_revision_seen
	instance.set("_combat_state", fixture)
	instance.set("_relic_bar_signature", "")
	instance.call("_refresh_relic_bar")
	await process_frame
	var original_sigil: Button = instance.get("_skill_sigil") as Button
	_expect(original_sigil != null and is_instance_valid(original_sigil), "skill event cache fixture must build its ability sigil")
	if original_sigil == null or not is_instance_valid(original_sigil):
		instance.set("_combat_state", original_combat_state)
		instance.set("_relic_bar_signature", original_signature)
		instance.set("_skill_event_revision_seen", original_event_revision_seen)
		instance.set("_run_skill_event_revision_seen", original_run_event_revision_seen)
		return {}
	var original_instance_id: int = original_sigil.get_instance_id()
	var original_presentation: Dictionary = {
		"owned_count": int(original_sigil.get_meta("owned_count", -1)),
		"ready_count": int(original_sigil.get_meta("ready_count", -1)),
		"preview_skill_ids": (original_sigil.get_meta("preview_skill_ids", []) as Array).duplicate(),
		"child_count": original_sigil.get_child_count(),
	}
	var cached_signature: String = str(instance.get("_relic_bar_signature"))
	var event_only_fixture: Dictionary = fixture.duplicate(true)
	event_only_fixture["skill_event_revision"] = original_event_revision_seen + 1
	instance.set("_combat_state", event_only_fixture)
	instance.call("_refresh_relic_bar")
	await process_frame
	var cached_sigil: Button = instance.get("_skill_sigil") as Button
	var cached_presentation: Dictionary = {}
	if cached_sigil != null and is_instance_valid(cached_sigil):
		cached_presentation = {
			"owned_count": int(cached_sigil.get_meta("owned_count", -1)),
			"ready_count": int(cached_sigil.get_meta("ready_count", -1)),
			"preview_skill_ids": (cached_sigil.get_meta("preview_skill_ids", []) as Array).duplicate(),
			"child_count": cached_sigil.get_child_count(),
		}
	_expect(cached_sigil != null and is_instance_valid(cached_sigil), "event-only skill revision must retain a live ability sigil")
	_expect(cached_sigil != null and cached_sigil.get_instance_id() == original_instance_id, "event-only skill revision must not rebuild the ability sigil subtree")
	_expect(str(instance.get("_relic_bar_signature")) == cached_signature, "event-only skill revision must preserve the visible relic-bar signature")
	_expect(cached_presentation == original_presentation, "event-only skill revision must preserve ability sigil presentation")
	_expect(int(instance.get("_skill_event_revision_seen")) == original_event_revision_seen + 1, "event-only skill revision must advance the pulse cursor")
	_expect(cached_sigil != null and cached_sigil.pivot_offset != Vector2.ZERO, "event-only skill revision must still dispatch the existing sigil pulse")
	var subtree_reused: bool = cached_sigil != null and cached_sigil.get_instance_id() == original_instance_id
	instance.set("_combat_state", original_combat_state)
	instance.set("_skill_event_revision_seen", original_event_revision_seen)
	instance.set("_run_skill_event_revision_seen", original_run_event_revision_seen)
	instance.set("_relic_bar_signature", "")
	instance.call("_refresh_relic_bar")
	await process_frame
	return {
		"sigil_instance_id": original_instance_id,
		"presentation_digest": hash(cached_presentation),
		"event_revision_advanced": true,
		"subtree_reused": subtree_reused,
	}

func _verify_unit_shadow_local_mesh_equivalence(board: Control) -> Dictionary:
	var frame_values: Array = board.call("_unit_idle_frames", {"type": "player"}) as Array
	var texture: Texture2D = null
	for frame_var: Variant in frame_values:
		if frame_var is Texture2D:
			texture = frame_var as Texture2D
			break
	_expect(texture != null, "local shadow mesh proof requires a loaded player idle frame")
	if texture == null:
		return {}
	var shadow_data: Dictionary = board.call("_unit_shadow_data_for_texture", texture) as Dictionary
	var polygons: Array[PackedVector2Array] = _packed_vector2_array_array(shadow_data.get("polygons", []))
	var bounds: Rect2 = shadow_data.get("bounds", Rect2()) as Rect2
	_expect(not polygons.is_empty() and bounds.size.x > 0.0 and bounds.size.y > 0.0, "local shadow mesh proof requires non-empty player silhouette polygons")
	if polygons.is_empty() or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return {}
	var filtered_polygons: Array = board.call("_packed_vector2_array_array", [polygons[0], "malformed", 7]) as Array
	var missing_polygons: Array = board.call("_packed_vector2_array_array", null) as Array
	_expect(filtered_polygons.size() == 1 and filtered_polygons[0] == polygons[0], "unit-shadow polygon conversion must retain only valid PackedVector2Array entries")
	_expect(missing_polygons.is_empty(), "unit-shadow polygon conversion must return a typed empty fallback for missing data")
	var draw_size := Vector2(137.0, 193.0)
	var draw_rect_a := Rect2(Vector2(211.0, 307.0), draw_size)
	var draw_rect_b := Rect2(Vector2(733.0, 419.0), draw_size)
	var shadow_size: Vector2 = board.call("_unit_shadow_draw_size", texture, draw_size, bounds) as Vector2
	var foot_offset := Vector2(0.0, float(board.call("_tile_height")) * CombatBoardView.UNIT_SHADOW_FOOT_OFFSET_Y_RATIO)
	var origin_a: Vector2 = board.call("_unit_shadow_foot_point", texture, draw_rect_a, bounds, "player") as Vector2
	var origin_b: Vector2 = board.call("_unit_shadow_foot_point", texture, draw_rect_b, bounds, "player") as Vector2
	origin_a += foot_offset
	origin_b += foot_offset
	var max_projection_delta: float = 0.0
	for polygon: PackedVector2Array in polygons:
		var local_hard: PackedVector2Array = board.call("_project_unit_shadow_polygon", polygon, shadow_size, Vector2.ZERO) as PackedVector2Array
		var old_hard_a: PackedVector2Array = board.call("_project_unit_shadow_polygon", polygon, shadow_size, origin_a) as PackedVector2Array
		var old_hard_b: PackedVector2Array = board.call("_project_unit_shadow_polygon", polygon, shadow_size, origin_b) as PackedVector2Array
		var local_soft: PackedVector2Array = board.call("_scaled_polygon", local_hard, CombatBoardView.UNIT_SHADOW_SOFT_SCALE) as PackedVector2Array
		var old_soft_a: PackedVector2Array = board.call("_scaled_polygon", old_hard_a, CombatBoardView.UNIT_SHADOW_SOFT_SCALE) as PackedVector2Array
		for index: int in range(local_hard.size()):
			max_projection_delta = maxf(max_projection_delta, (local_hard[index] + origin_a).distance_to(old_hard_a[index]))
			max_projection_delta = maxf(max_projection_delta, (local_hard[index] + origin_b).distance_to(old_hard_b[index]))
		for index: int in range(local_soft.size()):
			max_projection_delta = maxf(max_projection_delta, (local_soft[index] + origin_a).distance_to(old_soft_a[index]))
	_expect(max_projection_delta <= 0.0001, "local shadow projection must match the previous absolute-position geometry")
	var geometry_a: Array = board.call("_unit_shadow_draw_geometry", texture, draw_rect_a, "player") as Array
	var geometry_cache_size_after_a: int = (board.get("_unit_shadow_draw_geometry_cache") as Dictionary).size()
	var geometry_b: Array = board.call("_unit_shadow_draw_geometry", texture, draw_rect_b, "player") as Array
	var geometry_cache_size_after_b: int = (board.get("_unit_shadow_draw_geometry_cache") as Dictionary).size()
	_expect(geometry_a == geometry_b, "equal-size shadow geometry must be independent of board position")
	_expect(geometry_cache_size_after_b == geometry_cache_size_after_a, "moving equal-size shadow geometry must reuse one cache entry")
	var mesh_a: ArrayMesh = board.call("_unit_shadow_draw_mesh", texture, draw_rect_a, "player", geometry_a) as ArrayMesh
	var mesh_cache_size_after_a: int = (board.get("_unit_shadow_draw_mesh_cache") as Dictionary).size()
	var mesh_b: ArrayMesh = board.call("_unit_shadow_draw_mesh", texture, draw_rect_b, "player", geometry_b) as ArrayMesh
	var mesh_cache_size_after_b: int = (board.get("_unit_shadow_draw_mesh_cache") as Dictionary).size()
	_expect(mesh_a != null and mesh_b != null and mesh_a == mesh_b, "moving an equal-size unit shadow must reuse the same ArrayMesh")
	_expect(mesh_cache_size_after_b == mesh_cache_size_after_a, "moving an equal-size unit shadow must not grow the mesh cache")
	return {
		"max_projection_delta": max_projection_delta,
		"geometry_cache_reused": geometry_cache_size_after_b == geometry_cache_size_after_a,
		"mesh_cache_reused": mesh_a != null and mesh_a == mesh_b and mesh_cache_size_after_b == mesh_cache_size_after_a,
		"polygon_count": polygons.size(),
	}

func _await_hand_layout_ready(instance: Node) -> void:
	var waited_frames: int = 0
	while int(instance.get("_hand_layout_pending_revision")) >= 0 and waited_frames < 30:
		await process_frame
		waited_frames += 1
	_expect(waited_frames < 30, "combat hand layout must settle before lock-UI equivalence proof")
	await process_frame

func _dictionary_differences(expected: Dictionary, actual: Dictionary) -> Dictionary:
	var differences: Dictionary = {}
	for key: Variant in expected:
		if not actual.has(key) or actual[key] != expected[key]:
			differences[key] = {
				"expected": expected[key],
				"actual": actual.get(key),
			}
	for key: Variant in actual:
		if not expected.has(key):
			differences[key] = {
				"expected": null,
				"actual": actual[key],
			}
	return differences

func _enemy_round_lock_ui_snapshot(instance: Node) -> Dictionary:
	var pass_button: Button = instance.find_child("PassPreviewChip", true, false) as Button
	var pass_art: TextureRect = instance.find_child("PassForecastFrameArtHost", true, false) as TextureRect
	var hand_state: Array = []
	var hand: Array = ((instance.get("_combat_state") as Dictionary).get("deck", {}) as Dictionary).get("hand", []) as Array
	for index: int in range(hand.size()):
		var widget: Control = instance.call("_hand_card_control", index) as Control
		hand_state.append({
			"visible": widget != null and widget.visible,
			"modulate": widget.modulate if widget != null else Color.TRANSPARENT,
			"mouse_filter": widget.mouse_filter if widget != null else Control.MOUSE_FILTER_IGNORE,
		})
	var play_meter: Control = instance.get("_play_meter") as Control
	var movement_meter: Control = instance.get("_movement_meter") as Control
	var choice_bar_control: Control = instance.get("choice_bar") as Control
	var hand_row_control: Control = instance.get("hand_row") as Control
	var piles_bar_control: Control = instance.get("piles_bar") as Control
	return {
		"pass_found": pass_button != null,
		"pass_disabled": pass_button == null or pass_button.disabled,
		"pass_focus_mode": pass_button.focus_mode if pass_button != null else Control.FOCUS_NONE,
		"pass_interaction_state": str(pass_button.get_meta("pass_interaction_state", "")) if pass_button != null else "",
		"pass_art_state": str(pass_art.get_meta("pass_forecast_art_state", "")) if pass_art != null else "",
		"pass_art_modulate": pass_art.modulate if pass_art != null else Color.TRANSPARENT,
		"hand": hand_state,
		"play_meter_visible": play_meter != null and play_meter.visible,
		"play_meter_modulate": play_meter.modulate if play_meter != null else Color.TRANSPARENT,
		"movement_meter_visible": movement_meter != null and movement_meter.visible,
		"movement_meter_modulate": movement_meter.modulate if movement_meter != null else Color.TRANSPARENT,
		"choice_bar_visible": choice_bar_control != null and choice_bar_control.visible,
		"choice_bar_children": choice_bar_control.get_child_count() if choice_bar_control != null else -1,
		"hand_row_visible": hand_row_control != null and hand_row_control.visible,
		"piles_bar_visible": piles_bar_control != null and piles_bar_control.visible,
		"turn_order_render_signature": str(instance.get("_turn_order_render_signature")),
		"board_presentation": hash(instance.get("_board_presentation")),
	}

func _reference_aoe_targets(combat: CombatEngine, state: Dictionary, action: Dictionary) -> Array[Vector2i]:
	var targets: Array[Vector2i] = []
	if not combat.player_action_can_resolve(state, action):
		return targets
	var player_pos: Vector2i = (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	var aoe_range: int = int(action.get("range", 0))
	if aoe_range <= 0:
		var self_tiles: Array[Vector2i] = combat.call("_best_aoe_tiles_for_target", state, action, player_pos, false) as Array[Vector2i]
		if bool(combat.call("_has_attackable_in_tiles", state, self_tiles)):
			targets.append(player_pos)
		return targets
	var grid: Array = state.get("grid", [])
	for tile: Vector2i in PathUtils.diamond_tiles(player_pos, aoe_range, grid):
		if tile == player_pos or not PathUtils.is_passable(grid, tile):
			continue
		if not PathUtils.has_line_of_sight(grid, player_pos, tile):
			continue
		# Ranged AOE legality is center-only public information. Pattern occupants may
		# be concealed, so orientation and hidden occupancy cannot alter target centers.
		if not combat.is_tile_visible_to_player(state, tile):
			continue
		targets.append(tile)
	return _sorted_tiles(targets)

func _preview_digest(preview_value: Variant) -> Dictionary:
	var preview: Dictionary = preview_value as Dictionary
	return {
		"playable": bool(preview.get("playable", false)),
		"complete": bool(preview.get("complete", false)),
		"action_index": int(preview.get("action_index", -1)),
		"action": preview.get("action", {}),
		"target_tiles": _sorted_tiles(preview.get("target_tiles", [])),
		"state": hash(preview.get("state", {}))
	}

func _move_target_with_followup_attack(combat: CombatEngine, preview: Dictionary, preferred: Vector2i) -> Vector2i:
	var action: Dictionary = preview.get("action", {}) as Dictionary
	var actions: Array = preview.get("actions", []) as Array
	if actions.size() < 2:
		return Vector2i(-1, -1)
	var followup: Dictionary = actions[1] as Dictionary
	var candidates: Array[Vector2i] = _sorted_tiles(preview.get("target_tiles", []))
	if candidates.has(preferred):
		candidates.erase(preferred)
		candidates.push_front(preferred)
	for candidate: Vector2i in candidates:
		var moved_state: Dictionary = combat.apply_player_action(preview.get("state", {}) as Dictionary, action, candidate)
		if not combat.valid_targets_for_player_action(moved_state, followup).is_empty():
			return candidate
	return Vector2i(-1, -1)

func _measure_hover_sweep(instance: Node, tiles: Array[Vector2i], batches: int) -> Dictionary:
	if tiles.is_empty():
		return _empty_stats()
	var stats: Dictionary = _measure_sync_samples(batches, func() -> void:
		for tile: Vector2i in tiles:
			instance.call("_on_board_tile_hovered", tile)
	)
	_scale_metric_in_place(stats, tiles.size())
	return stats

func _measure_sync_samples(batches: int, operation: Callable) -> Dictionary:
	var samples: Array[float] = []
	for _batch: int in range(maxi(1, batches)):
		var started_usec: int = Time.get_ticks_usec()
		operation.call()
		samples.append(float(Time.get_ticks_usec() - started_usec))
	return _sample_stats(samples)

func _measure_instance_method(instance: Node, method_name: String, batches: int) -> Dictionary:
	return _measure_sync_samples(batches, func() -> void:
		instance.call(method_name)
	)

func _measure_ui_refreshes(instance: Node, batches: int, cold: bool) -> Dictionary:
	var samples: Array[float] = []
	var node_counts: Array[int] = []
	for batch: int in range(maxi(1, batches)):
		if cold:
			instance.call("_mark_combat_preview_state_changed")
			instance.set("_pile_visual_signature", "<runtime-cold-%d>" % batch)
			instance.set("_relic_bar_signature", "<runtime-cold-%d>" % batch)
			instance.set("_hand_panel_signature", "<runtime-cold-%d>" % batch)
			instance.set("_turn_order_render_signature", "<runtime-cold-%d>" % batch)
		var started_usec: int = Time.get_ticks_usec()
		instance.call("_refresh_ui")
		samples.append(float(Time.get_ticks_usec() - started_usec))
		await _settle_ui()
		node_counts.append(_subtree_node_count(instance))
	return {"stats": _sample_stats(samples), "node_counts": node_counts}

func _sample_stats(samples: Array[float]) -> Dictionary:
	if samples.is_empty():
		return _empty_stats()
	samples.sort()
	var p95_index: int = mini(samples.size() - 1, maxi(0, int(ceil(float(samples.size()) * 0.95)) - 1))
	return {
		"median": float(samples[floori(float(samples.size()) * 0.5)]),
		"p95": float(samples[p95_index]),
		"min": float(samples[0]),
		"max": float(samples[samples.size() - 1])
	}

func _empty_stats() -> Dictionary:
	return {"median": 0.0, "p95": 0.0, "min": 0.0, "max": 0.0}

func _scale_metric_in_place(stats: Dictionary, divisor: int) -> void:
	var safe_divisor: float = float(maxi(1, divisor))
	for key: String in ["median", "p95", "min", "max"]:
		stats[key] = float(stats.get(key, 0.0)) / safe_divisor

func _record_metric(results: Dictionary, key: String, stats: Dictionary) -> void:
	results[key] = float(stats.get("median", 0.0))
	results["%s_p95" % key] = float(stats.get("p95", 0.0))
	results["%s_min" % key] = float(stats.get("min", 0.0))
	results["%s_max" % key] = float(stats.get("max", 0.0))

func _sorted_tiles(values: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if values is Array:
		for value: Variant in values as Array:
			if value is Vector2i:
				result.append(value)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	return result

func _packed_vector2_array_array(values: Variant) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if typeof(values) != TYPE_ARRAY:
		return result
	for value: Variant in values as Array:
		if typeof(value) == TYPE_PACKED_VECTOR2_ARRAY:
			result.append(value as PackedVector2Array)
	return result

func _subtree_node_count(node: Node) -> int:
	var count: int = 1
	for child: Node in node.get_children():
		count += _subtree_node_count(child)
	return count

func _all_ints_equal(values: Array) -> bool:
	if values.is_empty():
		return true
	var expected: int = int(values[0])
	for value: Variant in values:
		if int(value) != expected:
			return false
	return true

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)

func _settle_ui() -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame

func _settle_action_tracker_prewarm(instance: Node) -> void:
	var waited_frames: int = 0
	while (
		bool(instance.get("_action_tracker_prewarm_scheduled"))
		or not (instance.get("_action_tracker_prewarm_queue") as Array).is_empty()
	) and waited_frames < 2000:
		await process_frame
		waited_frames += 1
	_expect(waited_frames < 2000, "action-tracker prewarm must finish within a bounded frame budget")
	await _settle_ui()
