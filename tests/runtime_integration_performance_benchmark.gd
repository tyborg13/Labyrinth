extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const PathUtils = preload("res://scripts/path_utils.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")

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
	var combat := CombatEngine.new()
	var installed_state: Dictionary = _install_stress_combat(instance, combat)
	await _settle_ui()
	_verify_aoe_target_semantics(instance, combat, installed_state)
	var source_snapshot: Dictionary = installed_state.duplicate(true)
	var results: Dictionary = {
		"schema_version": 1,
		"hand_card_count": HAND.size(),
		"initial_node_count": _subtree_node_count(instance)
	}
	var board: Control = instance.get_node("BoardUnderlay/CombatBoard") as Control
	var render_counts_before: Dictionary = board.call("render_instrumentation_snapshot") as Dictionary
	for _iteration: int in range(5):
		instance.call("_refresh_stage_view")
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
	_verify_fallback_template_semantics(instance)
	results["card_option_digest"] = cached_option_digest
	results["card_option_cache_entries"] = option_cache_size
	results["card_preview_cold_us_by_id"] = _profile_cold_printed_previews(instance)
	results["fallback_preview_cold_us_by_kind"] = _profile_cold_fallback_previews(instance)

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
		await instance.call("_on_board_tile_clicked", move_target)
		await _settle_ui()

	_expect(instance.get("_combat_state") as Dictionary == committed_before_move_hovers, "move preview/hover handling mutated committed combat state")
	var attack_preview: Dictionary = instance.call("_active_card_preview") as Dictionary
	_expect(str((attack_preview.get("action", {}) as Dictionary).get("type", "")) == "melee", "follow-up selected preview action is not melee")
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
	instance.queue_free()
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
	instance.call("_refresh_ui")
	return combat_state

func _stress_grid() -> Array:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x == 0 or y == 0 or x == 8 or y == 8 else "ash")
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
			"attack": _preview_digest(options.get("attack", {})),
			"move": _preview_digest(options.get("move", {})),
			"printed_playable": bool(options.get("printed_playable", false)),
			"attack_playable": bool(options.get("attack_playable", false)),
			"move_playable": bool(options.get("move_playable", false))
		})
	return hash(canonical)

func _verify_fallback_template_semantics(instance: Node) -> void:
	var combat_state: Dictionary = instance.get("_combat_state") as Dictionary
	var hand: Array = (combat_state.get("deck", {}) as Dictionary).get("hand", [])
	for index: int in range(hand.size()):
		var card_id: String = str(hand[index])
		for play_kind: String in ["attack", "move"]:
			var shared_preview: Dictionary = instance.call("_fallback_preview_for_index", index, play_kind) as Dictionary
			var direct_preview: Dictionary = instance.call(
				"_card_preview_from_state",
				card_id,
				combat_state,
				instance.call("_fallback_actions", play_kind),
				0
			) as Dictionary
			_expect(
				shared_preview == direct_preview,
				"shared %s fallback preview differs from direct preview for hand index %d" % [play_kind, index]
			)

func _profile_cold_printed_previews(instance: Node) -> Dictionary:
	var result: Dictionary = {}
	for index: int in range(HAND.size()):
		instance.call("_mark_combat_preview_state_changed")
		var started_us: int = Time.get_ticks_usec()
		instance.call("_card_preview_for_index", index)
		result[HAND[index]] = Time.get_ticks_usec() - started_us
	return result

func _profile_cold_fallback_previews(instance: Node) -> Dictionary:
	var result: Dictionary = {}
	for play_kind: String in ["attack", "move"]:
		instance.call("_mark_combat_preview_state_changed")
		var started_us: int = Time.get_ticks_usec()
		instance.call("_fallback_preview_for_index", 0, play_kind)
		result[play_kind] = Time.get_ticks_usec() - started_us
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
		var exhaustive: Array[Vector2i] = _exhaustive_aoe_targets(combat, state, action)
		_expect(optimized == exhaustive, "optimized AOE legality differs from exhaustive orientation scoring for %s" % str(action.get("orientation", "automatic")))

func _exhaustive_aoe_targets(combat: CombatEngine, state: Dictionary, action: Dictionary) -> Array[Vector2i]:
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
		var affected_tiles: Array[Vector2i] = combat.call("_best_aoe_tiles_for_target", state, action, tile, false) as Array[Vector2i]
		if bool(combat.call("_has_attackable_in_tiles", state, affected_tiles)):
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
