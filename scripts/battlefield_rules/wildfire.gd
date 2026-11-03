extends RefCounted
const TODO_DESIGN_WILDFIRE_ENTRY_DIRECTION: String = "TODO_DESIGN_wildfire_entry_direction"
const TODO_DESIGN_WILDFIRE_ROOM_ORIGIN: String = "TODO_DESIGN_room_wildfire_toward_player_origin"
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Gust = preload("res://scripts/battlefield_rules/gust.gd")
const SPREAD_MODES: Array = ["toward_player", "away_from_entry", "all"]

static func dial_error(state: Dictionary, instance: Dictionary) -> String:
	var mode: String = str(instance.get("dials", {}).get("spread", ""))
	if not SPREAD_MODES.has(mode): return "Wildfire spread is not implemented: " + mode
	if mode == "toward_player" and str(instance["source"]["kind"]) != "enemy": return TODO_DESIGN_WILDFIRE_ROOM_ORIGIN
	if mode == "away_from_entry" and Gust.entry_direction(state) == Vector2i.ZERO: return TODO_DESIGN_WILDFIRE_ENTRY_DIRECTION
	return ""

static func prepare(engine: RefCounted, state: Dictionary, instance: Dictionary) -> void:
	if str(instance["dials"]["spread"]) != "toward_player" or instance.has("locked_direction"): return
	var source: Dictionary = engine._surface_actor(state, "enemy", int(instance["source"]["id"]))
	# Primitive: the engine's deterministic dominant cardinal direction.
	instance["locked_direction"] = engine._cardinal_direction(Vector2i(state["player"]["pos"]) - Vector2i(source["pos"]))

static func resolve_beat(engine: RefCounted, state: Dictionary, instance: Dictionary) -> Dictionary:
	var directions: Array[Vector2i]
	match str(instance["dials"]["spread"]):
		"all": directions.assign(Paths.DIRS_4)
		"toward_player": directions.append(instance["locked_direction"])
		"away_from_entry": directions.append(-Gust.entry_direction(state))
	# Primitive: snapshot Fire ground before placement; new Fire cannot spread again.
	var snapshot: Array[Vector2i] = Surfaces.fuel_tiles(state, "fire")
	var action: Dictionary = {"type": "surface", "surface": "fire", "_enemy_id": int(instance["source"].get("id", -1))}
	for tile: Vector2i in snapshot:
		for axis: Vector2i in directions:
			var destination: Vector2i = tile + axis
			# Primitive: the same placement path as player Fire cards.
			state = engine._place_action_surface(state, action, destination)
	return state

static func forecast(engine: RefCounted, state: Dictionary) -> Dictionary:
	return load("res://scripts/battlefield_rules/dispatcher.gd").forecast(engine, state)
