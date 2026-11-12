extends RefCounted

# Preview-only payment for ending immediately at an unresolved card boundary.
# The committed action/confirmation pipeline is untouched.
static func pay_prefix(scene: Node, state: Dictionary, actions: Array) -> Dictionary:
	return scene._combat_engine.finish_player_card(state, scene._selected_card_index,
		scene._combat_engine.card_plays_spent_for_actions(actions), {"play_mode": "play"})

static func surface_skill(scene: Node, tile: Vector2i) -> Dictionary:
	var key: String = scene._pass_preview_key(tile)
	if scene._surface_preview_cache.get("forecast_key", "") == key:
		return visibility_safe(scene, scene._surface_preview_cache["state"])
	var known: Dictionary = scene._surface_preview_information_state(scene._combat_state)
	return visibility_safe(scene, scene._surface_aim.resolved(scene._combat_engine, known, tile))

# One information boundary for movement, card prefixes, targeted actions, skills
# and idle PASS. Strip hidden causes BEFORE resolution: removing a picked-up
# item afterward cannot undo the resulting hand/deck, healing or relic changes.
# Grid geometry and guardian brazier markers are board-public even in Umbra.
static func information_state(scene: Node, state: Dictionary, information_override: Variant = null) -> Dictionary:
	if not scene._preview_umbra_is_limited(state, information_override): return state
	var information: Dictionary = scene._preview_information_state(state) if information_override == null else information_override as Dictionary
	var visible: Dictionary = scene._combat_engine.umbra_visible_tile_lookup(information)
	var known: Dictionary = state.duplicate(true)
	known["_preview_opaque_enemies"] = true
	for collection: String in ["traps", "terrain", "enemies", "loot", "illusions", "npcs"]:
		if not state.has(collection): continue
		var entries: Array = []
		for entry: Dictionary in state[collection]:
			var is_known: bool = scene._combat_engine.is_enemy_visible_to_player(information, entry, visible) if collection == "enemies" else visible.has(entry.get("pos", Vector2i(-1, -1)))
			if is_known: entries.append(entry.duplicate(true))
		known[collection] = entries
	var ground: Dictionary = known.get("surfaces", {})
	for tile: Vector2i in BoardSurfaceRules.tiles(state):
		if not visible.has(tile): ground.erase(BoardSurfaceRules.tile_key(tile))
	known["surfaces"] = ground
	# Marks can straddle the sight boundary. Preserve their visible portion;
	# hidden tiles cannot land damage or create ground during the forecast.
	if state.has("meteor_marks"):
		var marks: Array = []
		for mark: Dictionary in state["meteor_marks"]:
			var tiles: Array[Vector2i]
			for tile: Vector2i in mark.get("tiles", []):
				if visible.has(tile): tiles.append(tile)
			if tiles.is_empty(): continue
			var disclosed: Dictionary = mark.duplicate(true)
			disclosed["tiles"] = tiles
			marks.append(disclosed)
		known["meteor_marks"] = marks
	if state.has("surface_events"):
		var events: Array = []
		for event: Dictionary in state["surface_events"]:
			if visible.has(event.get("tile", Vector2i(-1, -1))): events.append(event.duplicate(true))
		known["surface_events"] = events
	return known

# Hidden actors never enter numeric simulation, including support targeting,
# occupancy and status hooks. Retain only queue ordering for the '?' horizon.
# This snapshot is preview-only; the engine's opaque-board contract is intact.
static func visibility_safe(scene: Node, known: Dictionary) -> Dictionary:
	var result: Dictionary = scene._visibility_safe_preview_display_state(known)
	# Retain the initial Health only when the action changed it. This covers
	# lethal Bleed before scheduling, without changing unchanged source identity.
	var before_hp: int = int(scene._combat_state.get("player", {}).get("hp", known.get("player", {}).get("hp", 0)))
	if before_hp != int(known.get("player", {}).get("hp", 0)):
		result = result.duplicate(false)
		result["_pass_forecast_source_hp"] = before_hp
	if not scene._preview_umbra_is_limited(known): return result
	result = result.duplicate(false)
	var player: Dictionary = (result.get("player", {}) as Dictionary).duplicate(false)
	for field: String in ["hp", "block", "stoneskin"]:
		player[field] = known.get("player", {}).get(field, player.get(field, 0))
	result["player"] = player
	result["defiance_remaining"] = known.get("defiance_remaining", result.get("defiance_remaining", 0))
	# The display helper retains committed board objects. Forecasts retain the
	# already-filtered/resolved collections, including known pickup removals.
	for collection: String in ["traps", "loot"]:
		if known.has(collection): result[collection] = known[collection]
	var disclosed: Dictionary = {}
	for enemy: Dictionary in scene._combat_state.get("enemies", []):
		if scene._combat_engine.is_enemy_visible_to_player(scene._combat_state, enemy):
			disclosed[int(enemy.get("id", -1))] = true
	var enemies: Array = []
	for enemy: Dictionary in known.get("enemies", []):
		if disclosed.has(int(enemy.get("id", -1))): enemies.append(enemy)
	result["enemies"] = enemies
	var actors: Dictionary = {}
	for enemy: Dictionary in enemies: actors["enemy_%d" % int(enemy.get("id", -1))] = true
	result["_pass_forecast_disclosed_actors"] = actors
	var queue: Array = []
	var hidden_queue: Array = []
	for entry: Dictionary in known.get("turn_queue", []):
		if str(entry.get("kind", "")) == "enemy" and not disclosed.has(int(entry.get("enemy_id", -1))):
			hidden_queue.append({"time": int(entry.get("time", 0)), "seq": int(entry.get("seq", 0))})
		else:
			queue.append(entry)
	result["turn_queue"] = queue
	result["_pass_forecast_hidden_queue"] = hidden_queue
	result["_pass_forecast_limited"] = true
	# Known victory must stop end-turn effects. Its presentation remains unknown
	# under limited sight, independently of whether any hidden enemy exists.
	result.erase("_preview_opaque_enemies")
	return result

static func hidden_horizon(source: Dictionary, phase: Dictionary) -> bool:
	if not bool(source.get("_pass_forecast_limited", false)): return false
	var boundary: Dictionary = {}
	for entry: Dictionary in phase.get("initial_state", {}).get("turn_queue", []):
		if str(entry.get("kind", "")) == "player":
			boundary = entry
			break
	if boundary.is_empty(): return false
	for entry: Dictionary in source.get("_pass_forecast_hidden_queue", []):
		if int(entry["time"]) < int(boundary["time"]) or (int(entry["time"]) == int(boundary["time"]) and int(entry["seq"]) < int(boundary.get("seq", 0))):
			return true
	return false
