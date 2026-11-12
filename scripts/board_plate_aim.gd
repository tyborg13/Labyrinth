extends RefCounted

## Union of production targeting geometry, independent of the hovered choice.
## One cache per selection/state/orientation; ordinary pointer events reuse it.
var _source: Array = []
var _keys: Array[String]

func affected(scene: Node, preview: Dictionary) -> Array[String]:
	if scene._selected_card_index < 0 or scene._animation_lock or preview.is_empty() or bool(preview.get("complete", false)):
		var empty: Array[String]
		return empty
	var state: Dictionary = preview.get("state", {})
	var action: Dictionary = preview.get("action", {})
	var targets: Array = preview.get("target_tiles", [])
	var source: Array = [state, action, targets, preview.get("card_id"), preview.get("action_index"), preview.get("orientation_pending", false)]
	if source == _source: return _keys
	_source = source.duplicate(true)
	_keys.clear()
	for tile: Vector2i in targets:
		_append_choice(scene, state, action, tile)
	if str(action.get("type", "")) in ["move", "blink"]:
		if not _keys.has("player"): _keys.append("player")
		scene._prepare_preview_shortcuts_for_current_action(preview)
		for tile: Vector2i in scene._preview_shortcuts_cache.get("tiles", []):
			var plan: Dictionary = scene._shortcut_plan_for_tile(preview, tile, false)
			_append_choice(scene, plan.get("state", state), plan.get("action", {}), tile)
	# Automatic self buffs/heals preceding the pending confirmation remain
	# inspectable while that card is selected, including self-only cards.
	var known: Dictionary = scene._pending_card_known_forecast_state()
	if not known.is_empty():
		var before: Dictionary = scene._combat_state.get("player", {})
		var after: Dictionary = known.get("player", {})
		if preload("res://scripts/combat_hud_forecast.gd").keyword_badges(scene._combat_state) != preload("res://scripts/combat_hud_forecast.gd").keyword_badges(known) and not _keys.has("player"): _keys.append("player")
		for field: String in ["hp", "block", "stoneskin", "frost_armor", "keyword_badges"]:
			if before.get(field) != after.get(field) and not _keys.has("player"): _keys.append("player")
	return _keys

func _append_choice(scene: Node, state: Dictionary, action: Dictionary, target: Vector2i) -> void:
	var kind: String = str(action.get("type", ""))
	if kind in ["melee", "ranged", "aoe", "push", "pull"]:
		var impact: Array[Vector2i]
		if kind == "aoe": impact.assign(scene._aoe_tiles_for_action(state, action, target))
		else: impact.append(target)
		var resolved: Dictionary = scene._combat_engine.action_with_automatic_origin(state, action, target)
		var plan: Dictionary = scene._combat_engine._board_attack_plan(state, resolved, impact, "player")
		for hit: Dictionary in plan.get("hits", []):
			if bool(hit.get("hidden_direct", false)): continue
			var key: String = str(hit.get("key", ""))
			if not key.is_empty() and not _keys.has(key): _keys.append(key)
	elif kind not in ["move", "blink", "confirm"]:
		# Non-attack targeting (buff, swap, dispel, etc.) uses the existing
		# accepted choices. Hidden actors never enter the board's visible roster.
		for actor: Dictionary in scene._combat_engine._surface_actor_records(state, "all"):
			if (preload("res://scripts/board_surface_rules.gd").footprint_tiles(actor["unit"]) as Array).has(target):
				var key: String = str(actor["key"])
				if not _keys.has(key): _keys.append(key)
