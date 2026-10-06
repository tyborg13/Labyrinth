# Frozen calculation paths; typed local initializers adapted for Windows compatibility.
extends "res://scripts/run_scene.gd"

func _preview_shortcuts_for_current_action(
	preview: Dictionary,
	skip_spatial_prefilter: bool = false,
	defer_safe_move_resolution: bool = false
) -> Dictionary:
	var action: Dictionary = preview.get("action", {})
	var action_type: String = str(action.get("type", ""))
	if action_type not in ["move", "blink"]:
		return {}
	var cache_key: String = _preview_shortcuts_key(preview, defer_safe_move_resolution)
	if not skip_spatial_prefilter and cache_key == _preview_shortcuts_cache_key:
		return _preview_shortcuts_cache
	# Keep the inexpensive revision key for repeated consumers in one selection.
	# Only on its miss compare the actual inputs, allowing hover -> click to reuse
	# the same exact movement simulation while all world/information changes miss.
	var content_key: String = str(hash([
		_combat_preview_revision, _combat_state, preview.get("state", {}), action,
		preview.get("actions", []), preview.get("action_index", -1), preview.get("card_id", ""),
		preview.get("target_tiles", []), preview.get("skip_allowed", false), defer_safe_move_resolution,
	]))
	if not skip_spatial_prefilter and _preview_shortcuts_content_cache.has(content_key):
		_preview_shortcuts_cache_key = cache_key
		# Active plans can be materialized/annotated during targeting; keep the
		# bounded content snapshot isolated from those caller-owned mutations.
		_preview_shortcuts_cache = (_preview_shortcuts_content_cache[content_key] as Dictionary).duplicate(true)
		_record_runtime_performance_phase("shortcut_equivalent_input_hit", Time.get_ticks_usec())
		return _preview_shortcuts_cache
	var actions: Array = preview.get("actions", [])
	var action_index: int = int(preview.get("action_index", -1))
	var card_id: String = str(preview.get("card_id", ""))
	if action_index < 0 or action_index >= actions.size() or card_id.is_empty():
		return {}
	var preview_state: Dictionary = preview.get("state", {}) as Dictionary
	if preview_state.is_empty():
		return {}
	var umbra_limited: bool = _preview_umbra_is_limited(preview_state)
	var information_state: Dictionary = _preview_information_state(preview_state)
	var visible_lookup: Dictionary = _combat_engine.umbra_visible_tile_lookup(information_state) if umbra_limited else {}
	# Umbra shortcuts use only already-visible actors, terrain and traps, along
	# routes made entirely of visible tiles. Visible destructibles must remain
	# valid attack choices without exposing targets revealed only by the move.
	var allowed_target_tiles: Variant = _visible_shortcut_attackable_tiles(information_state, visible_lookup) if umbra_limited else null
	var player_tile: Vector2i = (preview_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	var plans: Dictionary = {}
	var move_targets: Array[Vector2i] = _vector2i_array(preview.get("target_tiles", []))
	var movement_plan: Dictionary = {}
	if action_type == "move":
		movement_plan = _combat_engine.movement_plan_for_player_action(preview_state, action, move_targets)
	if not _remaining_actions_include_shortcut_attack(actions, action_index + 1):
		# Ordinary movement cards with only draw/block/support follow-ups cannot
		# produce a move-and-attack shortcut. Resolving the move, every movement
		# relic, light source, trap, loot pickup, and follow-up once per reachable
		# tile was pure discarded work (39 full simulations for Threaded Path).
		var no_shortcuts: Dictionary = {
			"plans": {},
			"tiles": _vector2i_array([]),
			"movement_plan": movement_plan,
		}
		if not skip_spatial_prefilter:
			_preview_shortcuts_cache_key = cache_key
			_preview_shortcuts_cache = no_shortcuts
			_remember_preview_shortcuts(content_key, no_shortcuts)
		return no_shortcuts
	var immediate_attack_tiles: Array[Vector2i] = _vector2i_array([])
	var immediate_action: Dictionary = {}
	var can_prefilter_immediate_attack: bool = false
	if not skip_spatial_prefilter and action_index + 1 < actions.size() and typeof(actions[action_index + 1]) == TYPE_DICTIONARY:
		immediate_action = actions[action_index + 1]
		if str(immediate_action.get("type", "")) in SHORTCUT_DIRECT_ATTACK_TYPES and _combat_engine.player_action_can_resolve(preview_state, immediate_action):
			can_prefilter_immediate_attack = true
			immediate_attack_tiles = _shortcut_attackable_tiles_for_action(information_state if umbra_limited else preview_state, immediate_action)
			if typeof(allowed_target_tiles) == TYPE_DICTIONARY:
				var visible_attack_tiles: Array[Vector2i]
				for attack_tile: Vector2i in immediate_attack_tiles:
					if (allowed_target_tiles as Dictionary).has(attack_tile):
						visible_attack_tiles.append(attack_tile)
				immediate_attack_tiles = visible_attack_tiles
	if can_prefilter_immediate_attack:
		var optimized_result: Dictionary = _preview_immediate_attack_shortcuts(
			preview_state,
			card_id,
			actions,
			action_index,
			action,
			action_type,
			move_targets,
			movement_plan,
			immediate_action,
			immediate_attack_tiles,
			bool(preview.get("skip_allowed", false)),
			defer_safe_move_resolution and not umbra_limited,
			information_state,
			visible_lookup,
			allowed_target_tiles
		)
		_preview_shortcuts_cache_key = cache_key
		_preview_shortcuts_cache = optimized_result
		_remember_preview_shortcuts(content_key, optimized_result)
		return optimized_result
	for move_target: Vector2i in move_targets:
		var path_tiles: Array[Vector2i] = _vector2i_array([])
		var after_move_state: Dictionary = {}
		if action_type == "blink":
			path_tiles = _vector2i_array([move_target])
			after_move_state = _combat_engine.apply_player_action(preview_state, action, move_target)
		else:
			path_tiles = _shortcut_move_route(preview_state, movement_plan, move_target)
			after_move_state = _combat_engine.apply_planned_player_move(preview_state, action, move_target, movement_plan)
		if umbra_limited and not _shortcut_path_is_currently_visible(information_state, path_tiles, visible_lookup):
			continue
		var move_distance: int = PathUtils.manhattan(player_tile, move_target) if action_type == "blink" or IllusionRelicRules.can_trade(_combat_engine, preview_state, move_target) else maxi(0, path_tiles.size() - 1)
		var movement_risk_chips: Array = _movement_risk_chips_for_states(preview_state, after_move_state, path_tiles, _trade_cost_route(preview_state, action, move_target, movement_plan))
		_collect_shortcut_attack_plans(
			plans, card_id, actions, action_index, after_move_state, move_target, move_target,
			move_distance, path_tiles, movement_risk_chips, allowed_target_tiles,
			_shortcut_path_trap_count(preview_state, path_tiles),
			_shortcut_path_pickup_score(preview_state, path_tiles)
		)
	if bool(preview.get("skip_allowed", false)):
		_collect_shortcut_attack_plans(plans, card_id, actions, action_index, preview_state, INVALID_TARGET_TILE, player_tile, 0, [], [], allowed_target_tiles)
	if umbra_limited and plans.is_empty():
		# "No visible shortcut" is a stable, information-safe result for this
		# preview revision. Cache the empty result too; otherwise every presentation
		# consumer rebuilds the full movement plan several times per hover.
		var empty_result: Dictionary = {
			"plans": {},
			"tiles": _vector2i_array([]),
			"movement_plan": movement_plan,
		}
		if not skip_spatial_prefilter:
			_preview_shortcuts_cache_key = cache_key
			_preview_shortcuts_cache = empty_result
			_remember_preview_shortcuts(content_key, empty_result)
		return empty_result
	var tiles: Array[Vector2i]
	for tile_var: Variant in plans.keys():
		if typeof(tile_var) == TYPE_VECTOR2I:
			tiles.append(tile_var)
			var tile_plan: Dictionary = plans.get(tile_var, {}) as Dictionary
			tile_plan["movement_plan"] = movement_plan
	var result: Dictionary = {
		"plans": plans,
		"tiles": tiles,
		"movement_plan": movement_plan
	}
	if not skip_spatial_prefilter:
		_preview_shortcuts_cache_key = cache_key
		_preview_shortcuts_cache = result
		_remember_preview_shortcuts(content_key, result)
	return result

func _preview_immediate_attack_shortcuts(
	preview_state: Dictionary,
	card_id: String,
	actions: Array,
	action_index: int,
	move_action: Dictionary,
	action_type: String,
	move_targets: Array[Vector2i],
	movement_plan: Dictionary,
	attack_action: Dictionary,
	attackable_tiles: Array[Vector2i],
	skip_allowed: bool,
	defer_safe_move_resolution: bool,
	information_state: Dictionary,
	visible_lookup: Dictionary,
	allowed_target_tiles: Variant,
	_information_override: Variant = null
) -> Dictionary:
	var player_tile: Vector2i = (preview_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	var candidates: Array = []
	var potential_targets: Dictionary = {}
	var source_order: int = 0
	for move_target: Vector2i in move_targets:
		var candidate_targets: Array[Vector2i] = _shortcut_geometric_targets_from(move_target, attackable_tiles, attack_action, preview_state.get("grid", []))
		if candidate_targets.is_empty():
			source_order += 1
			continue
		for target_tile: Vector2i in candidate_targets:
			potential_targets[target_tile] = true
		var path_tiles: Array[Vector2i] = (
			_vector2i_array([move_target])
			if action_type == "blink"
			else _shortcut_move_route(preview_state, movement_plan, move_target)
		)
		if typeof(allowed_target_tiles) == TYPE_DICTIONARY and not _shortcut_path_is_currently_visible(information_state, path_tiles, visible_lookup):
			source_order += 1
			continue
		var move_distance: int = PathUtils.manhattan(player_tile, move_target) if action_type == "blink" or IllusionRelicRules.can_trade(_combat_engine, preview_state, move_target) else maxi(0, path_tiles.size() - 1)
		candidates.append({
			"move_target": move_target,
			"move_tile": move_target,
			"move_distance": move_distance,
			"path_tiles": path_tiles,
			"route_traps": _shortcut_path_trap_count(preview_state, path_tiles),
			"route_pickups": _shortcut_path_pickup_score(preview_state, path_tiles),
			"geometric_targets": candidate_targets,
			"source_order": source_order,
			"skip": false,
		})
		source_order += 1
	if skip_allowed:
		var skip_targets: Array[Vector2i] = _shortcut_geometric_targets_from(player_tile, attackable_tiles, attack_action, preview_state.get("grid", []))
		for target_tile: Vector2i in skip_targets:
			potential_targets[target_tile] = true
		candidates.append({
			"move_target": INVALID_TARGET_TILE,
			"move_tile": player_tile,
			"move_distance": 0,
			"path_tiles": _vector2i_array([]),
			"route_traps": 0,
			"route_pickups": 0,
			"geometric_targets": skip_targets,
			"source_order": source_order,
			"skip": true,
		})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var traps_a: int = int(a.get("route_traps", 0))
		var traps_b: int = int(b.get("route_traps", 0))
		if traps_a != traps_b:
			return traps_a < traps_b
		var pickups_a: int = int(a.get("route_pickups", 0))
		var pickups_b: int = int(b.get("route_pickups", 0))
		if pickups_a != pickups_b:
			return pickups_a > pickups_b
		var distance_a: int = int(a.get("move_distance", 0))
		var distance_b: int = int(b.get("move_distance", 0))
		if distance_a != distance_b:
			return distance_a < distance_b
		var path_size_a: int = _vector2i_array(a.get("path_tiles", [])).size()
		var path_size_b: int = _vector2i_array(b.get("path_tiles", [])).size()
		if path_size_a != path_size_b:
			return path_size_a < path_size_b
		return int(a.get("source_order", 0)) < int(b.get("source_order", 0))
	)
	var plans: Dictionary = {}
	var candidate_indices_by_target: Dictionary = {}
	for candidate_index: int in range(candidates.size()):
		var candidate_targets: Array[Vector2i] = _vector2i_array((candidates[candidate_index] as Dictionary).get("geometric_targets", []))
		for target_tile: Vector2i in candidate_targets:
			var target_candidate_indices: Array = candidate_indices_by_target.get(target_tile, []) as Array
			target_candidate_indices.append(candidate_index)
			candidate_indices_by_target[target_tile] = target_candidate_indices
	var processed_candidate_indices: Dictionary = {}
	while not _shortcut_plans_cover_geometric_targets(plans, potential_targets):
		var candidate_index: int = _next_shortcut_candidate_index(
			plans,
			potential_targets,
			candidate_indices_by_target,
			processed_candidate_indices
		)
		if candidate_index < 0:
			break
		processed_candidate_indices[candidate_index] = true
		var candidate: Dictionary = candidates[candidate_index] as Dictionary
		var candidate_phase_started: int = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
		var path_tiles: Array[Vector2i] = _vector2i_array(candidate.get("path_tiles", []))
		var after_move_state: Dictionary = preview_state
		var skip_move: bool = bool(candidate.get("skip", false))
		var safely_deferred: bool = (
			defer_safe_move_resolution
			and not skip_move
			and str(attack_action.get("type", "")) in ["melee", "ranged"]
			and _shortcut_move_bleed_is_survivable(preview_state)
			and not _movement_variety_requires_resolution(preview_state)
			and not _shortcut_path_has_live_trap(preview_state, path_tiles)
		)
		if safely_deferred:
			after_move_state = _shortcut_positional_state(preview_state, candidate.get("move_tile", player_tile))
		elif not skip_move:
			var move_target: Vector2i = candidate.get("move_target", INVALID_TARGET_TILE)
			if action_type == "blink":
				after_move_state = _combat_engine.apply_player_action(preview_state, move_action, move_target)
			else:
				after_move_state = _combat_engine.apply_planned_player_move(preview_state, move_action, move_target, movement_plan)
		candidate_phase_started = _record_runtime_performance_phase(
			"shortcut_move_deferred" if safely_deferred else "shortcut_move_exact_total",
			candidate_phase_started
		)
		var movement_risk_chips: Array = (
			[]
			if skip_move or safely_deferred
			else _movement_risk_chips_for_states(preview_state, after_move_state, path_tiles, _trade_cost_route(preview_state, move_action, candidate.get("move_target", INVALID_TARGET_TILE), movement_plan))
		)
		_collect_shortcut_attack_plans(
			plans,
			card_id,
			actions,
			action_index,
			after_move_state,
			candidate.get("move_target", INVALID_TARGET_TILE),
			candidate.get("move_tile", player_tile),
			int(candidate.get("move_distance", 0)),
			path_tiles,
			movement_risk_chips,
			allowed_target_tiles,
			int(candidate.get("route_traps", 0)),
			int(candidate.get("route_pickups", 0))
		)
		candidate_phase_started = _record_runtime_performance_phase("shortcut_collect_attack_total", candidate_phase_started)
		if safely_deferred:
			_annotate_deferred_shortcut_plans(plans, candidate, preview_state, move_action)
	var tiles: Array[Vector2i]
	for tile_var: Variant in plans.keys():
		if typeof(tile_var) == TYPE_VECTOR2I:
			tiles.append(tile_var)
			var tile_plan: Dictionary = plans.get(tile_var, {}) as Dictionary
			tile_plan["movement_plan"] = movement_plan
	return {
		"plans": plans,
		"tiles": tiles,
		"movement_plan": movement_plan,
	}

func _collect_shortcut_attack_plans(
	plans: Dictionary,
	card_id: String,
	actions: Array,
	action_index: int,
	base_state: Dictionary,
	move_target: Vector2i,
	move_tile: Vector2i,
	move_distance: int,
	path_tiles: Array[Vector2i],
	movement_risk_chips: Array = [],
	allowed_target_tiles: Variant = null,
	route_traps: int = 0,
	route_pickups: int = 0,
	_information_override: Variant = null
) -> void:
	var followup: Dictionary = _next_shortcut_attack_step(base_state, actions, action_index + 1)
	if followup.is_empty():
		return
	var followup_state: Dictionary = followup.get("state", {})
	var followup_action: Dictionary = followup.get("action", {})
	var followup_index: int = int(followup.get("action_index", -1))
	for enemy_tile: Vector2i in _combat_engine.valid_targets_for_player_action(followup_state, followup_action):
		if typeof(allowed_target_tiles) == TYPE_DICTIONARY and not (allowed_target_tiles as Dictionary).has(enemy_tile):
			continue
		var planned_attack_action: Dictionary = _shortcut_action_with_default_force_direction(followup_state, followup_action, enemy_tile)
		# A valid final attack already completes the card. Avoid cloning and resolving
		# the full combat state solely to rediscover that the action list has ended.
		if followup_index + 1 < actions.size():
			var after_attack_state: Dictionary = _combat_engine.apply_player_action(followup_state, planned_attack_action, enemy_tile)
			var continuation: Dictionary = _card_preview_from_state(card_id, after_attack_state, actions, followup_index + 1, true)
			if not bool(continuation.get("playable", false)):
				continue
		var existing: Dictionary = plans.get(enemy_tile, {})
		if not existing.is_empty():
			var existing_traps: int = int(existing.get("route_traps", 0))
			if route_traps > existing_traps:
				continue
			if route_traps < existing_traps:
				existing = {}
			var existing_pickups: int = int(existing.get("route_pickups", 0))
			if not existing.is_empty() and route_pickups < existing_pickups:
				continue
			if not existing.is_empty() and route_pickups > existing_pickups:
				existing = {}
			var existing_distance: int = int(existing.get("move_distance", 99999))
			var existing_path_length: int = _vector2i_array(existing.get("path_tiles", [])).size() if not existing.is_empty() else 99999
			if not existing.is_empty() and move_distance > existing_distance:
				continue
			if not existing.is_empty() and move_distance == existing_distance and path_tiles.size() >= existing_path_length:
				continue
		plans[enemy_tile] = {
			"state": followup_state,
			"move_target": move_target,
			"move_tile": move_tile,
			"move_distance": move_distance,
			"route_traps": route_traps,
			"route_pickups": route_pickups,
			"path_tiles": path_tiles,
			"movement_risk_chips": movement_risk_chips.duplicate(true),
			"action_index": followup_index,
			"action": planned_attack_action
		}

