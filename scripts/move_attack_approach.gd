extends RefCounted

# A transient target-entry preference, shared by pointer, drag and board focus.
# It never changes the default shortcut map or survives a selection/world change.
const INVALID := Vector2i(-1, -1)
var tile: Vector2i = INVALID
var entry: Vector2i = INVALID
var revision: int = 0
var _cache_key: String = ""
var _plan: Dictionary = {}

func clear() -> void:
	tile = INVALID
	entry = INVALID
	revision += 1
	_cache_key = ""
	_plan = {}

func observe(next_tile: Vector2i, scene: Node) -> void:
	if next_tile == tile:
		return
	var same_actor: bool = false
	if tile.x >= 0 and next_tile.x >= 0:
		for enemy: Dictionary in scene._combat_state.get("enemies", []):
			if int(enemy.get("hp", 0)) <= 0:
				continue
			var footprint: Array[Vector2i] = scene._enemy_footprint_tiles(enemy)
			if footprint.has(tile) and footprint.has(next_tile):
				same_actor = true
				break
	if not same_actor:
		entry = tile if next_tile.x >= 0 else INVALID
	tile = next_tile
	revision += 1
	_cache_key = ""
	_plan = {}

func plan_for(scene: Node, preview: Dictionary, target: Vector2i, movement_plan: Dictionary) -> Dictionary:
	if target != tile or entry.x < 0:
		return {}
	var key: String = "%s|%s|%s" % [scene._preview_shortcuts_key(preview), entry, target]
	if key == _cache_key:
		return _plan
	_cache_key = key
	_plan = _build_plan(scene, preview, target, movement_plan)
	return _plan

func _build_plan(scene: Node, preview: Dictionary, target: Vector2i, movement_plan: Dictionary) -> Dictionary:
	var state: Dictionary = preview.get("state", {})
	var action: Dictionary = preview.get("action", {})
	var action_type: String = str(action.get("type", ""))
	if action_type not in ["move", "blink"]:
		return {}
	var player_tile: Vector2i = (state.get("player", {}) as Dictionary).get("pos", INVALID)
	var skip: bool = entry == player_tile and bool(preview.get("skip_allowed", false))
	if not skip and not (preview.get("target_tiles", []) as Array).has(entry):
		return {}
	var path: Array[Vector2i]
	if not skip:
		if action_type == "blink":
			path.append(entry)
		else:
			path = scene._combat_engine.path_from_player_movement_plan(movement_plan, entry)
			if path.is_empty():
				return {}
	var allowed: Variant = null
	if scene._preview_umbra_is_limited(state):
		var information: Dictionary = scene._preview_information_state(state)
		var visible: Dictionary = scene._combat_engine.umbra_visible_tile_lookup(information)
		allowed = scene._visible_shortcut_attackable_tiles(information, visible)
		if not allowed.has(target) or not scene._shortcut_path_is_currently_visible(information, path, visible):
			return {}
	var after: Dictionary = state
	if not skip:
		if action_type == "blink":
			after = scene._combat_engine.apply_player_action(state, action, entry)
		else:
			after = scene._combat_engine.apply_planned_player_move(state, action, entry, movement_plan)
	# Contact effects may stop movement or make the follow-up illegal. Never
	# present a requested endpoint that the exact simulation cannot reach.
	var player: Dictionary = after.get("player", {})
	if player.get("pos", INVALID) != entry or int(player.get("hp", 0)) <= 0:
		return {}
	var plans: Dictionary = {}
	var distance: int = absi(entry.x - player_tile.x) + absi(entry.y - player_tile.y) if action_type == "blink" else maxi(0, path.size() - 1)
	scene._collect_shortcut_attack_plans(
		plans, str(preview.get("card_id", "")), preview.get("actions", []),
		int(preview.get("action_index", -1)), after, INVALID if skip else entry,
		entry, distance, path, scene._movement_risk_chips_for_states(state, after, path), allowed
	)
	var result: Dictionary = plans.get(target, {})
	if not result.is_empty():
		result["movement_plan"] = movement_plan
	return result
