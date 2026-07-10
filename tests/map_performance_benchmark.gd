extends SceneTree

const LabyrinthMapView = preload("res://scripts/labyrinth_map_view.gd")

const MIN_COORD := Vector2i(-7, -5)
const MAX_COORD := Vector2i(7, 5)
var _failed: bool = false

func _init() -> void:
	var map_view := LabyrinthMapView.new()
	map_view.interactive = true
	map_view.show_legend = true
	map_view.size = Vector2(920.0, 580.0)
	var state: Dictionary = _stress_state()
	var source_hash_before: int = hash(state)
	map_view.set_run_state(state)
	var coords: Array[Vector2i] = []
	for room_var: Variant in (state.get("rooms", {}) as Dictionary).values():
		coords.append((room_var as Dictionary).get("coord", Vector2i.ZERO))

	# Warm resource and script paths before timing the hot helpers.
	map_view.call("_coord_position", Vector2i.ZERO)
	map_view.call("_node_route_state", (state.get("rooms", {}) as Dictionary).get("0,0", {}))
	map_view.call("_hover_card_rect", MAX_COORD)

	var results := {
		"room_count": coords.size(),
		"coord_position_us_per_call": _measure_coord_positions(map_view, coords, 12),
		"route_state_us_per_call": _measure_route_states(map_view, state, 12),
		"hover_card_us_per_call": _measure_hover_cards(map_view, 12),
		"unchanged_submission_us_per_call": _measure_unchanged_submissions(map_view, state, 30)
	}
	_validate_cache_semantics(map_view, state, source_hash_before)
	print("MAP PERFORMANCE BENCHMARK %s" % JSON.stringify(results))
	map_view.free()
	quit(1 if _failed else 0)

func _validate_cache_semantics(map_view: LabyrinthMapView, state: Dictionary, source_hash_before: int) -> void:
	_assert(hash(state) == source_hash_before, "Map helpers must not mutate the submitted run state")
	var state_revision_before: int = int(map_view.get("_state_cache_revision"))
	map_view.set_run_state(state)
	_assert(int(map_view.get("_state_cache_revision")) == state_revision_before, "An unchanged state submission should retain the current caches")
	var original_position: Vector2 = map_view.call("_coord_position", MAX_COORD)
	map_view.show_legend = false
	var no_legend_position: Vector2 = map_view.call("_coord_position", MAX_COORD)
	_assert(no_legend_position.x > original_position.x, "Legend visibility must invalidate map geometry")
	map_view.show_legend = true
	_assert((map_view.call("_coord_position", MAX_COORD) as Vector2).is_equal_approx(original_position), "Restoring the legend must restore exact room geometry")
	var rooms_copy: Array = map_view.call("_visible_rooms")
	rooms_copy.clear()
	_assert(not (map_view.call("_visible_rooms") as Array).is_empty(), "Visible-room callers must not be able to mutate the cached room list")
	var room_copy: Dictionary = map_view.call("_room_at", Vector2i.ZERO)
	room_copy["name"] = "Mutated copy"
	_assert(str((map_view.call("_room_at", Vector2i.ZERO) as Dictionary).get("name", "")) != "Mutated copy", "Room lookup must retain copy-on-return semantics")
	var available_before: Array = map_view.call("_available_move_coords")
	_assert(available_before.has(Vector2i(1, 0)), "Stress fixture should begin with the east room reachable")
	var changed_state: Dictionary = state.duplicate(true)
	((changed_state.get("rooms", {}) as Dictionary).get("1,0", {}) as Dictionary)["sealed"] = true
	map_view.set_run_state(changed_state)
	_assert(not (map_view.call("_available_move_coords") as Array).has(Vector2i(1, 0)), "State changes must precisely invalidate reachable-room caches")
	map_view.set_run_state(state)
	map_view.call("begin_travel_animation", Vector2i.ZERO, Vector2i(1, 0))
	map_view.set("_travel_progress", 0.5)
	var trace_commands: Array = map_view.call("_travel_visual_commands", "trace")
	var trace_count: int = trace_commands.size()
	trace_commands.clear()
	_assert((map_view.call("_travel_visual_commands", "trace") as Array).size() == trace_count, "Travel command callers must not be able to mutate the cached animation commands")
	map_view.call("clear_travel_animation")

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)

func _measure_coord_positions(map_view: LabyrinthMapView, coords: Array[Vector2i], iterations: int) -> float:
	var started: int = Time.get_ticks_usec()
	for iteration: int in range(iterations):
		for coord: Vector2i in coords:
			map_view.call("_coord_position", coord)
	return float(Time.get_ticks_usec() - started) / float(maxi(1, iterations * coords.size()))

func _measure_route_states(map_view: LabyrinthMapView, state: Dictionary, iterations: int) -> float:
	var rooms: Dictionary = state.get("rooms", {})
	var started: int = Time.get_ticks_usec()
	for iteration: int in range(iterations):
		for room_var: Variant in rooms.values():
			map_view.call("_node_route_state", room_var as Dictionary)
	return float(Time.get_ticks_usec() - started) / float(maxi(1, iterations * rooms.size()))

func _measure_hover_cards(map_view: LabyrinthMapView, iterations: int) -> float:
	var started: int = Time.get_ticks_usec()
	for iteration: int in range(iterations):
		map_view.call("_hover_card_rect", MIN_COORD if iteration % 2 == 0 else MAX_COORD)
	return float(Time.get_ticks_usec() - started) / float(maxi(1, iterations))

func _measure_unchanged_submissions(map_view: LabyrinthMapView, state: Dictionary, iterations: int) -> float:
	var started: int = Time.get_ticks_usec()
	for iteration: int in range(iterations):
		map_view.set_run_state(state)
	return float(Time.get_ticks_usec() - started) / float(maxi(1, iterations))

func _stress_state() -> Dictionary:
	var rooms: Dictionary = {}
	for y: int in range(MIN_COORD.y, MAX_COORD.y + 1):
		for x: int in range(MIN_COORD.x, MAX_COORD.x + 1):
			var coord := Vector2i(x, y)
			var connections: Array[Dictionary] = []
			for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor: Vector2i = coord + direction
				if neighbor.x >= MIN_COORD.x and neighbor.x <= MAX_COORD.x and neighbor.y >= MIN_COORD.y and neighbor.y <= MAX_COORD.y:
					connections.append({"coord": neighbor})
			rooms["%d,%d" % [x, y]] = {
				"coord": coord,
				"depth": maxi(absi(x), absi(y)),
				"type": "start" if coord == Vector2i.ZERO else "combat",
				"element": "fire",
				"name": "Room %d,%d" % [x, y],
				"revealed": true,
				"visited": coord == Vector2i.ZERO,
				"cleared": coord == Vector2i.ZERO,
				"sealed": coord != Vector2i.ZERO and coord.length_squared() > 1,
				"connections": connections
			}
	return {"mode": "room", "current_room": Vector2i.ZERO, "rooms": rooms}
