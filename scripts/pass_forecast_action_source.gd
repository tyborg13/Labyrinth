extends RefCounted

const Terrain = preload("res://scripts/terrain_card_rules.gd")
const Data = preload("res://scripts/game_data.gd")
const Retaliate = preload("res://scripts/retaliate_rules.gd")
const BoardSurfaceRules = preload("res://scripts/board_surface_rules.gd")
const FORCE_BOARD: String = "_preview_force_board"

static func retain_force_board(state: Dictionary) -> Dictionary:
	var result: Dictionary = state.duplicate(false)
	result[FORCE_BOARD] = true
	return result

static func actions_use_force(engine: RefCounted, actions: Array) -> bool:
	for action: Dictionary in actions:
		if engine._action_has_forced_movement(action) or str(action.get("type", "")) in ["swap", "illusion_swap", "erupt", "call_wind", "wind_push"]:
			return true
	return false

static func automatic_followup_uses_force(engine: RefCounted, actions: Array, index: int) -> bool:
	for cursor: int in range(index + 1, actions.size()):
		var action: Dictionary = actions[cursor]
		if engine.player_action_needs_target(action) and not bool(action.get("reuse_previous_target", false)):
			break
		if actions_use_force(engine, [action]): return true
	return false

static func indirect_force_triggered(before: Dictionary, after: Dictionary) -> bool:
	var sequence: int = int(before.get("surface_event_sequence", 0))
	for event: Dictionary in after.get("surface_events", []):
		if int(event.get("sequence", 0)) <= sequence: continue
		if event.get("kind") == "trap_triggered" and event.get("element") == "air": return true
		if event.get("kind") == Retaliate.EVENT_KIND and int(event.get("push", 0)) > 0: return true
	return false

static func phase_uses_force(scene: Node, state: Dictionary, information: Dictionary) -> bool:
	if state.get("battlefield_rule", {}).get("rule") == "gust" or not state.get("wind", {}).is_empty(): return true
	for trap: Dictionary in state.get("traps", []):
		if trap.get("element") == "air": return true
	var engine: RefCounted = scene._combat_engine
	if int(Retaliate.totals(state.get("player", {}), engine._relic_effects(state)).get("push", 0)) > 0: return true
	var visible: Dictionary = engine.umbra_visible_tile_lookup(information)
	var announced: Dictionary = {}
	for enemy: Dictionary in information.get("enemies", []):
		if engine.is_enemy_visible_to_player(information, enemy, visible): announced[int(enemy.get("id", -1))] = true
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0 or not announced.has(int(enemy.get("id", -1))): continue
		if actions_use_force(engine, enemy.get("intent", {}).get("actions", [])): return true
		if int(Retaliate.totals(enemy, []).get("push", 0)) > 0: return true
		# A revealed foe can roll a different move before the hero acts again.
		for intent: Dictionary in Data.enemies().get(str(enemy.get("type", "")), {}).get("intents", []):
			if actions_use_force(engine, intent.get("actions", [])): return true
	return false

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
		var committed: Dictionary = scene._combat_state
		var force_board: bool = actions_use_force(engine, actions) or indirect_force_triggered(committed, played) or phase_uses_force(scene, committed, committed)
		if force_board:
			played = retain_force_board(played)
		else:
			var prepared: Dictionary = engine.prepare_player_card(information_state(scene, committed, null, true), index, "empower" if empowered else "play")
			var no_targets: Array[Vector2i]
			played = preload("res://scripts/combat_preview_known_forecast.gd").resolved_prefix(engine, prepared, actions, actions.size(), no_targets)
	return visibility_safe(scene, engine.finish_player_card(played, index, engine.card_plays_spent_for_actions(actions), {"play_mode": "play"}))

# Keep the true contact geometry for force during or after the walk. Walk
# trap and ground costs use decision-time sight.
static func walk_force_preview(engine: RefCounted, state: Dictionary, action: Dictionary, target: Vector2i) -> Dictionary:
	var visible: Dictionary = engine.umbra_visible_tile_lookup(state)
	var input: Dictionary = state.duplicate(false)
	input[engine.WALK_FORECAST_SIGHT] = visible
	var result: Dictionary = engine.surface_preview_for_player_action(input, action, target, true)
	var walked: Dictionary = retain_force_board(result["state"])
	walked.erase(engine.WALK_FORECAST_SIGHT)
	walked["surfaces"] = _visible_ground(walked, visible)
	walked["traps"] = (walked.get("traps", []) as Array).filter(func(trap: Dictionary) -> bool: return visible.has(trap.get("pos")))
	result["state"] = walked
	result["single_state"] = walked
	return result

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
	var before: Dictionary = scene._combat_state
	var force_board: bool = scene._preview_umbra_is_limited(before) and phase_uses_force(scene, before, before)
	var known: Dictionary = information_state(scene, before, null, false, force_board)
	return visibility_safe(scene, scene._surface_aim.resolved(scene._combat_engine, known, tile))

# Ordinary scouting keeps its disclosed inputs. Force resolves with true
# contact geometry and arrivals, and the presentation then applies sight.
static func information_state(scene: Node, state: Dictionary, information_override: Variant = null, retain_ground: bool = false, retain_board: bool = false) -> Dictionary:
	if not scene._preview_umbra_is_limited(state, information_override): return state
	if retain_board or bool(state.get(FORCE_BOARD, false)): return retain_force_board(state)
	var information: Dictionary = scene._preview_information_state(state) if information_override == null else information_override as Dictionary
	var visible: Dictionary = scene._combat_engine.umbra_visible_tile_lookup(information)
	var known: Dictionary = state.duplicate(true)
	known["_preview_opaque_enemies"] = true
	for collection: String in ["traps", "terrain", "enemies", "loot", "illusions", "npcs"]:
		if not state.has(collection): continue
		var entries: Array = []
		for entry: Dictionary in state[collection]:
			var is_known: bool = scene._combat_engine.is_enemy_visible_to_player(information, entry, visible) if collection == "enemies" else visible.has(entry.get("pos", Vector2i(-1, -1)))
			if is_known or (collection == "terrain" and Terrain.is_owned_outcrop(entry)):
				entries.append(entry.duplicate(true))
		known[collection] = entries
	# Card actions resolve against real ground. Disclosure happens after the
	# action, so a concealed tile can still change damage to a known unit.
	if not retain_ground:
		known["surfaces"] = _visible_ground(known, visible)
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

static func disclose_ground(scene: Node, state: Dictionary) -> Dictionary:
	if not scene._preview_umbra_is_limited(state): return state
	var result: Dictionary = state.duplicate(false)
	result["surfaces"] = _visible_ground(state, scene._combat_engine.umbra_visible_tile_lookup(scene._preview_information_state(state)))
	return result

static func disclose_card_state(scene: Node, state: Dictionary) -> Dictionary:
	var result: Dictionary = disclose_ground(scene, state)
	if not bool(result.get(FORCE_BOARD, false)): return result
	result.erase(FORCE_BOARD)
	var hidden: Dictionary = hidden_actor_keys(scene, state)
	for collection: String in ["enemies", "illusions"]:
		var prefix: String = "enemy_" if collection == "enemies" else "illusion_"
		result[collection] = (state.get(collection, []) as Array).filter(func(unit: Dictionary) -> bool:
			return not hidden.has(prefix + str(unit.get("id", -1))))
	return result

static func hidden_actor_keys(scene: Node, state: Dictionary) -> Dictionary:
	var limited: bool = scene._preview_umbra_is_limited(state)
	var information: Dictionary = scene._combat_state if not scene._combat_state.is_empty() else state
	var engine: RefCounted = scene._combat_engine
	var visible: Dictionary = engine.umbra_visible_tile_lookup(information) if limited else {}
	var actors: Dictionary = scene._surface_preview_units_by_key(state)
	actors.merge(scene._surface_preview_units_by_key(information), true)
	var hidden: Dictionary = {}
	for key: String in actors:
		var actor: Dictionary = actors[key]
		if key.begins_with("enemy_") and not engine.is_enemy_visible_to_player(information, actor, visible):
			hidden[key] = true
		if limited and key.begins_with("illusion_") and not visible.has(actor.get("pos")):
			hidden[key] = true
	return hidden

static func _visible_ground(state: Dictionary, visible: Dictionary) -> Dictionary:
	var ground: Dictionary = {}
	for tile: Vector2i in BoardSurfaceRules.tiles(state):
		if visible.has(tile): ground[BoardSurfaceRules.tile_key(tile)] = BoardSurfaceRules.surface_at(state, tile)
	return ground

# Conversions can follow concealed ground without showing it. Burst events
# retain their footprint because the card forecasts the explosion itself.
static func disclose_surface_events(scene: Node, state: Dictionary, events: Array[Dictionary]) -> Array[Dictionary]:
	if events.is_empty(): return events
	var limited: bool = scene._preview_umbra_is_limited(state)
	var visible: Dictionary = scene._combat_engine.umbra_visible_tile_lookup(scene._preview_information_state(state)) if limited else {}
	var hidden: Dictionary = hidden_actor_keys(scene, state)
	if not limited and hidden.is_empty(): return events
	var result: Array[Dictionary]
	for event: Dictionary in events:
		var kind: String = str(event.get("kind", ""))
		if limited and kind in ["force_area", "force_collision", "guardian_line_step"]: continue # Dedicated markers and paths own force disclosure.
		if limited and kind in ["surface_created", "surface_replaced", "surface_removed", "surface_conducted", "trap_triggered"] and not visible.has(event.get("tile")):
			continue
		if limited and kind == "surface_converted":
			var tiles: Array[Vector2i]
			for tile: Vector2i in event.get("tiles", []):
				if visible.has(tile): tiles.append(tile)
			event = event.duplicate(false)
			event["tiles"] = tiles
		if hidden.has(str(event.get("actor_key", ""))) or (event.has("enemy_id") and hidden.has("enemy_%d" % int(event["enemy_id"]))):
			continue
		if event.has("actor_keys") or event.has("enemy_ids"):
			event = event.duplicate(false)
			if event.has("actor_keys"):
				event["actor_keys"] = (event["actor_keys"] as Array).filter(func(key: Variant) -> bool: return not hidden.has(str(key)))
			if event.has("enemy_ids"):
				event["enemy_ids"] = (event["enemy_ids"] as Array).filter(func(id: Variant) -> bool: return not hidden.has("enemy_%d" % int(id)))
		result.append(event)
	return result

static func rest_source(scene: Node, committed: Dictionary) -> Dictionary:
	var force_board: bool = scene._preview_umbra_is_limited(committed, committed) and phase_uses_force(scene, committed, committed)
	return visibility_safe(scene, information_state(scene, committed, committed, false, force_board), committed)

static func visibility_safe(scene: Node, known: Dictionary, rest_boundary: Variant = null) -> Dictionary:
	var at_rest: bool = rest_boundary is Dictionary
	var committed: Dictionary = rest_boundary if at_rest else scene._combat_state
	var keep_board: bool = bool(known.get(FORCE_BOARD, false)) and phase_uses_force(scene, known, committed)
	var result: Dictionary = known if at_rest or keep_board else disclose_ground(scene, scene._visibility_safe_preview_display_state(known))
	# Retain the initial Health only when the action changed it. This covers
	# the resolved movement before scheduling, preserving its source identity.
	var before_hp: int = int(committed.get("player", {}).get("hp", known.get("player", {}).get("hp", 0)))
	if before_hp != int(known.get("player", {}).get("hp", 0)):
		result = result.duplicate(false)
		result["_pass_forecast_source_hp"] = before_hp
	# atk-01: a previewed walk through fire (or any previewed action) can also
	# strip Block or Stoneskin before the turn ends. Retain what it removed so
	# the defence rows count it, as the Health row already counts its Health.
	for field: String in ["block", "stoneskin"]:
		var spent: int = int(committed.get("player", {}).get(field, 0)) - int(known.get("player", {}).get(field, 0))
		if spent <= 0: continue
		if is_same(result, known): result = result.duplicate(false)
		result["_pass_forecast_action_" + field] = spent
	if not scene._preview_umbra_is_limited(known, committed): return result
	result = result.duplicate(false)
	var player: Dictionary = (result.get("player", {}) as Dictionary).duplicate(false)
	for field: String in ["hp", "block", "stoneskin"]:
		player[field] = known.get("player", {}).get(field, player.get(field, 0))
	result["player"] = player
	result["defiance_remaining"] = known.get("defiance_remaining", result.get("defiance_remaining", 0))
	var visible: Dictionary = scene._combat_engine.umbra_visible_tile_lookup(committed)
	# Force effects on known actors survive the card. If no upcoming force
	# needs the full board, ordinary enemy forecasts keep the disclosed inputs.
	var disclosed_board: Dictionary = known
	if not keep_board and bool(known.get(FORCE_BOARD, false)):
		result.erase(FORCE_BOARD)
		var resolved_board: Dictionary = known.duplicate(false)
		resolved_board.erase(FORCE_BOARD)
		disclosed_board = information_state(scene, resolved_board, committed)
	for collection: String in ["traps", "terrain", "loot", "illusions", "npcs", "meteor_marks", "surface_events"]:
		if disclosed_board.has(collection): result[collection] = disclosed_board[collection]
	var disclosed: Dictionary = {}
	var living: Dictionary = {}
	for enemy: Dictionary in known.get("enemies", []) if known.get(FORCE_BOARD, false) else committed.get("enemies", []):
		if int(enemy.get("hp", 0)) > 0: living[int(enemy.get("id", -1))] = true
	for enemy: Dictionary in committed.get("enemies", []):
		if scene._combat_engine.is_enemy_visible_to_player(committed, enemy, visible):
			disclosed[int(enemy.get("id", -1))] = true
	var enemies: Array = []
	for enemy: Dictionary in known.get("enemies", []):
		if disclosed.has(int(enemy.get("id", -1))): enemies.append(enemy)
	result["enemies"] = known.get("enemies", []) if keep_board else enemies
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
	# atk-04: the decision-time sight, so the forecast can say when any unit
	# enters unseen ground at the decision-time sight boundary.
	var public_after: Dictionary = known.duplicate(false)
	public_after["enemies"] = enemies
	preload("res://scripts/pass_forecast_unseen_ground.gd").attach(result, visible, committed, public_after)
	# Known victory must stop end-turn effects. Its presentation remains unknown
	# under limited sight, independently of whether any hidden enemy exists.
	result.erase("_preview_opaque_enemies")
	return result

static func hidden_horizon(source: Dictionary, phase: Dictionary) -> bool:
	if not bool(source.get("_pass_forecast_limited", false)): return false
	# atk-07: a span through a turn Freeze skips ends at a later hero entry.
	var boundary: Dictionary = phase.get("span_boundary", {})
	if boundary.is_empty():
		for entry: Dictionary in phase.get("initial_state", {}).get("turn_queue", []):
			if str(entry.get("kind", "")) == "player":
				boundary = entry
				break
	if boundary.is_empty(): return false
	for entry: Dictionary in source.get("_pass_forecast_hidden_queue", []):
		# atk-04: a dead foe's stale queue entry is not a foe hidden in the Umbra.
		if not bool(entry.get("alive", true)): continue
		# The hero wins exact clock ties, even after Stagger reschedules the hero.
		if int(entry["time"]) < int(boundary["time"]):
			return true
	return false
