extends RefCounted

const Run = preload("res://scripts/run_engine.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Graph = preload("res://scripts/section_map_graph.gd")

const SEED: int = 7319
const FIRE_CARD: String = "firebrand_volley"
const ICE_CARD: String = "frostbolt"
const FIRE_GEAR: String = "ember_pendant"
const FIRE_GEAR_CARD: String = "ember_tithe"

static func combat(engine: Run, room_element: String, with_fire: bool, seed_value: int = SEED) -> Dictionary:
	var state: Dictionary = engine.create_new_run(seed_value, Progression.default_data())
	if with_fire: state = engine.grant_magic_to_deck(state, FIRE_CARD)
	for coord: Vector2i in engine.available_moves(state):
		var room: Dictionary = Graph.room(state, coord)
		if room.get("type", "") != "combat": continue
		room["element"] = room_element
		state = engine.move_to_room(state, coord)
		if state.get("mode", "") == Run.MODE_PRE_BATTLE:
			state = engine.begin_pre_battle_combat(state)
		return state
	return {}

static func victory(state: Dictionary) -> Dictionary:
	var result: Dictionary = (state.get("combat_state", {}) as Dictionary).duplicate(true)
	for enemy: Dictionary in result.get("enemies", []):
		enemy["hp"] = 0
	return result
