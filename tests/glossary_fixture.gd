extends RefCounted

const RunEngine = preload("res://scripts/run_engine.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SEED: int = 7321
const REVEAL_STEPS: int = 160
const REVEAL_POLL_SECONDS: float = 0.025

static func treasure_state() -> Dictionary:
	var engine := RunEngine.new()
	var state: Dictionary = engine.create_new_run(SEED, ProgressionStore.default_data())
	var coord: Vector2i = _treasure_coord(engine, state)
	var room: Dictionary = engine.room_metadata(state, coord).duplicate(true)
	room["revealed"] = true
	room["visited"] = true
	(state["rooms"] as Dictionary)["%d,%d" % [coord.x, coord.y]] = room
	state["current_room"] = coord
	state["current_room_layout"] = engine.call("_display_layout_for_room", SEED, room, Vector2i(1, 0))
	state["mode"] = "treasure"
	state["combat_state"] = {}
	state["pending_reward"] = {}
	state["pending_relics"] = ["iron_lung", "ember_lens", "pilgrim_boots"]
	return state

static func _treasure_coord(engine: RefCounted, state: Dictionary) -> Vector2i:
	for radius: int in range(1, 9):
		for x: int in range(-radius, radius + 1):
			for y: int in range(-radius, radius + 1):
				var coord := Vector2i(x, y)
				if maxi(absi(x), absi(y)) == radius and str(engine.room_metadata(state, coord).get("type", "")) == "treasure": return coord
	push_error("Glossary fixture seed has no treasure room")
	return Vector2i.ZERO
