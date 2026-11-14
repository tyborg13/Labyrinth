extends RefCounted

# Preview-only payment for ending immediately at an unresolved card boundary.
# The committed action/confirmation pipeline is untouched.
static func pay_prefix(scene: Node, state: Dictionary, actions: Array) -> Dictionary:
	return scene._combat_engine.finish_player_card(state, scene._selected_card_index,
		scene._combat_engine.card_plays_spent_for_actions(actions), {"play_mode": "play"})

# atk-02: a targetless card held over the board plays on release through its
# click confirmation (_begin_card_preview, then _on_confirm_card_play_pressed).
# Forecast the same paid state _pending_card_known_forecast_state gives that
# confirmation, from the held card's preview; limited sight replays the known
# board, as the confirmation does. Preview-only; the commit path is untouched.
static func drag_play(scene: Node) -> Dictionary:
	var engine: RefCounted = scene._combat_engine
	var index: int = scene._drag_card_index
	var preview: Dictionary = scene._drag_card_options.get("play", {}) as Dictionary
	var actions: Array = preview.get("actions", []) as Array
	var played: Dictionary = preview.get("state", {}) as Dictionary
	if played.is_empty() or actions.is_empty(): return {}
	if engine.effective_umbra_radius(scene._combat_state) < preload("res://scripts/combat_engine.gd").UMBRA_UNLIMITED_RADIUS:
		var modifiers: Dictionary = played.get(preload("res://scripts/card_keyword_rules.gd").PLAY_MODIFIERS_KEY, {}) as Dictionary
		var empowered: bool = scene._hand_card_empowered(index) or (bool(modifiers.get("empowered", false)) and str(modifiers.get("card_id", "")) == scene._card_id_for_hand_index(index))
		var prepared: Dictionary = engine.prepare_player_card(scene._surface_preview_information_state(scene._combat_state), index, "empower" if empowered else "play")
		var no_targets: Array[Vector2i]
		played = preload("res://scripts/combat_preview_known_forecast.gd").resolved_prefix(engine, prepared, actions, actions.size(), no_targets)
	return visibility_safe(scene, engine.finish_player_card(played, index, engine.card_plays_spent_for_actions(actions), {"play_mode": "play"}))

# atk-02: the hover resolution of a hero walk leaves the movement pool unpaid
# (the forecast rows never read it). Mirror apply_player_movement's payment on
# the known resolution to learn how much movement this walk leaves.
static func movement_left_after_walk(scene: Node, walked: Dictionary) -> int:
	var engine: RefCounted = scene._combat_engine
	var origin: Vector2i = (scene._combat_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	var destination: Vector2i = (walked.get("player", {}) as Dictionary).get("pos", origin)
	var spent: int = int((walked.get("last_player_movement", {}) as Dictionary).get("spent", 0))
	if str(scene._player_movement_action.get("type", "")) == "blink":
		spent = absi(destination.x - origin.x) + absi(destination.y - origin.y)
	return clampi(engine.player_movement_remaining(scene._combat_state) - spent, 0, engine.player_movement_capacity(walked))

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
	# atk-01: a previewed walk through fire (or any previewed action) can also
	# strip Block or Stoneskin before the turn ends. Retain what it removed so
	# the defence rows count it, as the Health row already counts its Health.
	for field: String in ["block", "stoneskin"]:
		var spent: int = int(scene._combat_state.get("player", {}).get(field, 0)) - int(known.get("player", {}).get(field, 0))
		if spent <= 0: continue
		if is_same(result, known): result = result.duplicate(false)
		result["_pass_forecast_action_" + field] = spent
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
	var living: Dictionary = {}
	for enemy: Dictionary in scene._combat_state.get("enemies", []):
		if int(enemy.get("hp", 0)) > 0: living[int(enemy.get("id", -1))] = true
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
			# atk-03: "alive" tells the repeat forecast whether this entry can draw
			# from the live generator; the '?' horizon below reads time/seq only.
			hidden_queue.append({"time": int(entry.get("time", 0)), "seq": int(entry.get("seq", 0)), "alive": living.has(int(entry.get("enemy_id", -1)))})
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
