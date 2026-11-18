extends RefCounted
const TODO_DESIGN_WILDFIRE_ENTRY_DIRECTION: String = "TODO_DESIGN_wildfire_entry_direction"
const TODO_DESIGN_WILDFIRE_ROOM_ORIGIN: String = "TODO_DESIGN_room_wildfire_toward_player_origin"
const Gust = preload("res://scripts/battlefield_rules/gust.gd")
const SPREAD_MODES: Array = ["toward_player", "away_from_entry", "all"]

static func dial_error(state: Dictionary, instance: Dictionary) -> String:
	var mode: String = str(instance.get("dials", {}).get("spread", ""))
	if not SPREAD_MODES.has(mode): return "Wildfire spread is not implemented: " + mode
	if mode == "toward_player" and str(instance["source"]["kind"]) != "enemy": return TODO_DESIGN_WILDFIRE_ROOM_ORIGIN
	if mode == "away_from_entry" and Gust.entry_direction(state) == Vector2i.ZERO: return TODO_DESIGN_WILDFIRE_ENTRY_DIRECTION
	return ""

static func resolve_beat(engine: RefCounted, state: Dictionary, instance: Dictionary) -> Dictionary:
	var action: Dictionary = {"type": "surface", "surface": "fire", "_enemy_id": int(instance["source"].get("id", -1))}
	for destination: Vector2i in preload("res://scripts/battlefield_rules/geometry.gd").affected_tiles(engine, state, instance):
		state = engine._place_action_surface(state, action, destination)
	return state

static func forecast(engine: RefCounted, state: Dictionary) -> Dictionary:
	return load("res://scripts/battlefield_rules/dispatcher.gd").forecast(engine, state)
