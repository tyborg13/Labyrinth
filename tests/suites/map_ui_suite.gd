extends RefCounted

const LabyrinthMapView = preload("res://scripts/labyrinth_map_view.gd")

const CURRENT: Vector2i = Vector2i(2, 2)
const UPPER_ROUTE: Vector2i = Vector2i(2, 1)
const LOWER_ROUTE: Vector2i = Vector2i(2, 3)

static func run(expect: Callable) -> void:
	_test_radial_route_bearings_and_stability(expect)
	_test_all_opposite_route_pairs_keep_opposite_bearings(expect)
	_test_depth_labels_keep_cardinal_anchors(expect)

static func run_live(tree: SceneTree, expect: Callable) -> void:
	await _test_map_keyboard_shortcut(tree, expect)

static func _test_radial_route_bearings_and_stability(expect: Callable) -> void:
	var state: Dictionary = _branch_choice_state()
	var compact := LabyrinthMapView.new()
	compact.interactive = false
	compact.show_legend = false
	compact.size = Vector2(340.0, 250.0)
	compact.set_run_state(state)
	var current_position: Vector2 = compact.call("_coord_position", CURRENT)
	var upper_position: Vector2 = compact.call("_coord_position", UPPER_ROUTE)
	var lower_position: Vector2 = compact.call("_coord_position", LOWER_ROUTE)
	var upper_direction: Vector2 = upper_position - current_position
	var lower_direction: Vector2 = lower_position - current_position
	expect.call(
		upper_direction.dot(lower_direction) < 0.0,
		"Opposite map doors should place their destination rooms on opposite sides of the current minimap room"
	)
	var stable_world_positions: Dictionary = {
		CURRENT: compact.call("_world_position", CURRENT),
		UPPER_ROUTE: compact.call("_world_position", UPPER_ROUTE),
		LOWER_ROUTE: compact.call("_world_position", LOWER_ROUTE)
	}
	var expanded_state: Dictionary = state.duplicate(true)
	var expanded_rooms: Dictionary = (expanded_state.get("rooms", {}) as Dictionary).duplicate(true)
	expanded_rooms["-2,-1"] = _room(Vector2i(-2, -1), [])
	expanded_state["rooms"] = expanded_rooms
	compact.set_run_state(expanded_state)
	for coord: Vector2i in [CURRENT, UPPER_ROUTE, LOWER_ROUTE]:
		expect.call(
			(compact.call("_world_position", coord) as Vector2).distance_to(stable_world_positions.get(coord, Vector2.ZERO)) <= 0.001,
			"Revealing another room should not relocate existing minimap room %s" % coord
		)
	var large := LabyrinthMapView.new()
	large.interactive = true
	large.show_legend = true
	large.size = Vector2(920.0, 580.0)
	large.set_run_state(expanded_state)
	for coord: Vector2i in [CURRENT, UPPER_ROUTE, LOWER_ROUTE]:
		expect.call(
			(large.call("_world_position", coord) as Vector2).distance_to(compact.call("_world_position", coord)) <= 0.001,
			"Compact and full maps should share the same radial world position for room %s" % coord
		)
	compact.free()
	large.free()

static func _test_depth_labels_keep_cardinal_anchors(expect: Callable) -> void:
	var map_view := LabyrinthMapView.new()
	map_view.interactive = true
	map_view.show_legend = true
	map_view.size = Vector2(1200.0, 760.0)
	map_view.set_run_state(_branch_choice_state())
	map_view.call("center_on_current", true)
	var radius: float = float(map_view.call("_depth_ring_step")) * 2.0
	var center_before: Vector2 = map_view.call("_radial_center")
	var rects_before: Array[Rect2] = map_view.call("_depth_ring_label_rects", radius)
	expect.call(rects_before.size() == 4, "Every full-map depth ring should expose four fixed cardinal labels")
	var expected_directions: Array[Vector2]
	expected_directions.assign([Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT])
	for index: int in range(mini(rects_before.size(), expected_directions.size())):
		var relative_anchor: Vector2 = rects_before[index].get_center() - center_before
		expect.call(
			relative_anchor.distance_to(expected_directions[index] * radius) <= 0.01,
			"Depth label %d should remain fixed to its cardinal point on the ring" % index
		)
	map_view.call("pan_camera", Vector2(-180.0, 74.0))
	var center_after: Vector2 = map_view.call("_radial_center")
	var rects_after: Array[Rect2] = map_view.call("_depth_ring_label_rects", radius)
	for index: int in range(mini(rects_before.size(), rects_after.size())):
		var relative_before: Vector2 = rects_before[index].get_center() - center_before
		var relative_after: Vector2 = rects_after[index].get_center() - center_after
		expect.call(
			relative_after.distance_to(relative_before) <= 0.01,
			"Panning should move a depth label with its ring instead of choosing a new point around it"
		)
	map_view.free()

static func _test_all_opposite_route_pairs_keep_opposite_bearings(expect: Callable) -> void:
	var map_view := LabyrinthMapView.new()
	var all_opposite: bool = true
	var first_failure: String = ""
	var axes: Array[Vector2i]
	axes.assign([Vector2i.RIGHT, Vector2i.DOWN])
	for x: int in range(-20, 21):
		if not all_opposite:
			break
		for y: int in range(-20, 21):
			if not all_opposite:
				break
			var current := Vector2i(x, y)
			var current_position: Vector2 = map_view.call("_world_position_for_room", _room(current, []))
			for axis: Vector2i in axes:
				var forward := current + axis
				var backward := current - axis
				var forward_direction: Vector2 = (map_view.call("_world_position_for_room", _room(forward, [])) as Vector2) - current_position
				var backward_direction: Vector2 = (map_view.call("_world_position_for_room", _room(backward, [])) as Vector2) - current_position
				if forward_direction.dot(backward_direction) >= 0.0:
					all_opposite = false
					first_failure = "%s via %s and %s" % [current, forward, backward]
					break
	expect.call(
		all_opposite,
		"Opposite map exits should retain opposite radial bearings through depth 20; first failure: %s" % first_failure
	)
	map_view.free()

static func _test_map_keyboard_shortcut(tree: SceneTree, expect: Callable) -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	expect.call(packed != null, "Map shortcut coverage should load RunScene")
	if packed == null:
		return
	var instance: Node = packed.instantiate()
	tree.root.add_child(instance)
	await tree.process_frame
	instance.call("_close_dialogue")
	var minimap_overlay: Control = instance.get("mini_map_overlay") as Control
	var map_scrim: Control = instance.get("_large_map_scrim") as Control
	expect.call(minimap_overlay != null and minimap_overlay.tooltip_text.contains("[M]"), "The minimap tooltip should disclose its M shortcut")
	var key_press := InputEventKey.new()
	key_press.keycode = KEY_M
	key_press.pressed = true
	instance.call("_input", key_press)
	await tree.process_frame
	expect.call(map_scrim != null and map_scrim.visible, "Pressing M should open the full map")
	var echo_press := InputEventKey.new()
	echo_press.keycode = KEY_M
	echo_press.pressed = true
	echo_press.echo = true
	instance.call("_input", echo_press)
	expect.call(map_scrim != null and map_scrim.visible, "A held M key should not repeatedly toggle the full map")
	var close_press := InputEventKey.new()
	close_press.physical_keycode = KEY_M
	close_press.pressed = true
	instance.call("_input", close_press)
	await tree.process_frame
	expect.call(map_scrim != null and not map_scrim.visible, "Pressing M again should close the full map")
	var modified_press := InputEventKey.new()
	modified_press.keycode = KEY_M
	modified_press.ctrl_pressed = true
	modified_press.pressed = true
	instance.call("_input", modified_press)
	expect.call(map_scrim != null and not map_scrim.visible, "Modified M shortcuts should remain available to other controls")
	instance.queue_free()
	await tree.process_frame

static func _branch_choice_state() -> Dictionary:
	var visible_coords: Array[Vector2i]
	visible_coords.assign([
		Vector2i(0, 0),
		Vector2i(0, -1),
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(-1, 0),
		Vector2i(1, 1),
		Vector2i(-1, 1),
		Vector2i(-2, 1),
		Vector2i(-2, 2),
		Vector2i(-2, 0),
		Vector2i(-1, 2),
		Vector2i(-2, 3),
		Vector2i(0, 2),
		Vector2i(1, 2),
		CURRENT,
		UPPER_ROUTE,
		LOWER_ROUTE
	])
	var rooms: Dictionary = {}
	for coord: Vector2i in visible_coords:
		rooms[_room_key(coord)] = _room(coord, [])
	rooms[_room_key(CURRENT)] = _room(CURRENT, [UPPER_ROUTE, LOWER_ROUTE])
	rooms[_room_key(UPPER_ROUTE)] = _room(UPPER_ROUTE, [CURRENT])
	rooms[_room_key(LOWER_ROUTE)] = _room(LOWER_ROUTE, [CURRENT])
	return {"mode": "room", "current_room": CURRENT, "rooms": rooms}

static func _room(coord: Vector2i, neighbor_coords: Array) -> Dictionary:
	var connections: Array = []
	for neighbor_var: Variant in neighbor_coords:
		connections.append({"coord": neighbor_var as Vector2i})
	return {
		"coord": coord,
		"depth": maxi(absi(coord.x), absi(coord.y)),
		"type": "combat" if coord != Vector2i.ZERO else "start",
		"element": "fire",
		"revealed": true,
		"visited": coord not in [UPPER_ROUTE, LOWER_ROUTE],
		"cleared": coord not in [UPPER_ROUTE, LOWER_ROUTE],
		"sealed": false,
		"connections": connections
	}

static func _room_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]
