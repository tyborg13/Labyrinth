extends SceneTree

const LabyrinthMapView = preload("res://scripts/labyrinth_map_view.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

const OUTPUT_DIR: String = "user://map_decision_layer_probe_v3"
const INVALID_COORD: Vector2i = Vector2i(-999, -999)
const PROBE_VIEWPORT: Vector2i = Vector2i(1920, 1080)

var _background: ColorRect
var _map_view: LabyrinthMapView
var _capture_index: int = 0
var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(PROBE_VIEWPORT)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = PROBE_VIEWPORT
	root.size = PROBE_VIEWPORT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	_build_surface()
	await process_frame
	await process_frame

	await _capture_large("large_early.png", _early_state(), INVALID_COORD)
	await _capture_large("large_mid.png", _mid_state(), INVALID_COORD)
	await _capture_large("large_long.png", _long_state(), INVALID_COORD)
	await _capture_large("edge_hover.png", _long_state(), Vector2i(14, 9))
	await _capture_zoomed("deep_zoomed.png", _long_state())
	await _capture_panned("deep_panned.png", _long_state())
	await _capture_travel("travel_in_transit.png", _mid_state())
	await _capture_mini("mini_compact.png", _long_state())

	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(1 if _failed else 0)

func _build_surface() -> void:
	_background = ColorRect.new()
	_background.color = Color("120d0a")
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.anchor_right = 1.0
	_background.anchor_bottom = 1.0
	root.add_child(_background)

	_map_view = LabyrinthMapView.new()
	var viewport_size: Vector2 = root.get_visible_rect().size
	_map_view.position = Vector2(24.0, 24.0)
	_map_view.size = viewport_size - Vector2(48.0, 48.0)
	_map_view.interactive = true
	_map_view.show_legend = true
	_map_view.draw_background = true
	_map_view.theme = load("res://themes/default_theme.tres")
	root.add_child(_map_view)

func _capture_large(file_name: String, state: Dictionary, hover_coord: Vector2i) -> void:
	var viewport_size: Vector2 = root.get_visible_rect().size
	_map_view.position = Vector2(24.0, 24.0)
	_map_view.size = viewport_size - Vector2(48.0, 48.0)
	_map_view.interactive = true
	_map_view.show_legend = true
	_map_view.draw_background = true
	_map_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_map_view.set_run_state(state)
	_map_view.call("center_on_current", true)
	_map_view.set("_hover_coord", hover_coord)
	_assert_large_map_geometry(file_name)
	if hover_coord.x > -900:
		var hover_rect: Rect2 = _map_view.call("_hover_card_rect", hover_coord)
		if bool(_map_view.call("_hover_card_intersects_other_node", hover_rect, hover_coord)):
			_fail("%s hover card overlaps another visible map node" % file_name)
			return
		if not (_map_view.call("_hover_card_bounds") as Rect2).encloses(hover_rect):
			_fail("%s hover card leaves the safe map bounds" % file_name)
			return
	_capture_index += 1
	_background.color = Color("120d0a") if _capture_index % 2 == 0 else Color("130e0b")
	_background.queue_redraw()
	_map_view.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame
	await create_timer(0.08).timeout
	_save_viewport("%s/%s" % [OUTPUT_DIR, file_name])

func _capture_zoomed(file_name: String, state: Dictionary) -> void:
	_map_view.interactive = true
	_map_view.show_legend = true
	_map_view.set_run_state(state)
	_map_view.call("center_on_current", true)
	var current: Vector2i = state.get("current_room", Vector2i.ZERO)
	var anchor: Vector2 = _map_view.call("_coord_position", current)
	var wheel := InputEventMouseButton.new()
	wheel.position = anchor
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	var zoom_before: float = float(_map_view.call("_camera_zoom_value"))
	_map_view.call("_gui_input", wheel)
	_map_view.call("_gui_input", wheel)
	if float(_map_view.call("_camera_zoom_value")) <= zoom_before:
		_fail("Mouse-wheel input should zoom the interactive map")
	var anchored_position: Vector2 = _map_view.call("_coord_position", current)
	if anchored_position.distance_to(anchor) > 0.1:
		_fail("Pointer-anchored zoom should keep the current room stable")
	_assert_large_map_geometry(file_name)
	_map_view.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw(true)
	await process_frame
	_save_viewport("%s/%s" % [OUTPUT_DIR, file_name])

func _capture_panned(file_name: String, state: Dictionary) -> void:
	_map_view.interactive = true
	_map_view.show_legend = true
	_map_view.set_run_state(state)
	_map_view.call("center_on_current", true)
	var map_rect: Rect2 = _map_view.call("_map_rect")
	var start := map_rect.position + Vector2(18.0, map_rect.size.y - 24.0)
	var focus_before: Vector2 = _map_view.call("_camera_focus")
	var press := InputEventMouseButton.new()
	press.position = start
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	_map_view.call("_gui_input", press)
	var motion := InputEventMouseMotion.new()
	motion.position = start + Vector2(-260.0, 92.0)
	motion.relative = Vector2(-260.0, 92.0)
	_map_view.call("_gui_input", motion)
	var release := InputEventMouseButton.new()
	release.position = motion.position
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	_map_view.call("_gui_input", release)
	var focus_after: Vector2 = _map_view.call("_camera_focus")
	if focus_after.distance_to(focus_before) < 1.0:
		_fail("Empty-space drag input should pan the interactive map")
	_assert_large_map_geometry(file_name)
	_map_view.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw(true)
	await process_frame
	_save_viewport("%s/%s" % [OUTPUT_DIR, file_name])

func _capture_travel(file_name: String, state: Dictionary) -> void:
	var current: Vector2i = state.get("current_room", Vector2i.ZERO)
	_map_view.set_run_state(state)
	var destinations: Array[Vector2i] = _map_view.call("_available_move_coords")
	if destinations.is_empty() or not bool(_map_view.call("begin_travel_animation", current, destinations[0])):
		_fail("Travel proof should start on a visible reachable curved route")
		return
	_map_view.set("_travel_progress", 0.56)
	_map_view.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw(true)
	await process_frame
	_save_viewport("%s/%s" % [OUTPUT_DIR, file_name])
	_map_view.call("clear_travel_animation")

func _capture_mini(file_name: String, state: Dictionary) -> void:
	var viewport_size: Vector2 = root.get_visible_rect().size
	_map_view.position = (viewport_size - Vector2(340.0, 250.0)) * 0.5
	_map_view.size = Vector2(340.0, 250.0)
	_map_view.interactive = false
	_map_view.show_legend = false
	_map_view.draw_background = true
	_map_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_view.set_run_state(state)
	_map_view.set("_hover_coord", INVALID_COORD)
	_assert_compact_map_geometry()
	_capture_index += 1
	_background.color = Color("120d0a") if _capture_index % 2 == 0 else Color("130e0b")
	_background.queue_redraw()
	_map_view.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame
	await create_timer(0.08).timeout
	_save_viewport("%s/%s" % [OUTPUT_DIR, file_name])

func _save_viewport(output_path: String) -> void:
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null:
		_fail("Map proof should capture a renderer image")
		return
	var source_size: Vector2i = image.get_size()
	var scale_x: float = float(source_size.x) / float(PROBE_VIEWPORT.x)
	var scale_y: float = float(source_size.y) / float(PROBE_VIEWPORT.y)
	if not is_equal_approx(scale_x, scale_y):
		_fail("Map proof should preserve 1920x1080 proportions, got %s" % source_size)
		return
	if source_size != PROBE_VIEWPORT:
		image.resize(PROBE_VIEWPORT.x, PROBE_VIEWPORT.y, Image.INTERPOLATE_LANCZOS)
	image.save_png(ProjectSettings.globalize_path(output_path))

func _assert_large_map_geometry(context: String) -> void:
	if root.get_viewport().get_visible_rect().size != Vector2(PROBE_VIEWPORT):
		_fail("%s should render at an exact 1920x1080 logical viewport" % context)
	var map_rect: Rect2 = _map_view.call("_map_rect")
	var legend_rect: Rect2 = _map_view.call("_legend_rect")
	var control_rect := Rect2(Vector2.ZERO, _map_view.size)
	if not control_rect.encloses(map_rect) or not control_rect.encloses(legend_rect):
		_fail("%s map and legend panels should remain inside the view" % context)
	if map_rect.intersects(legend_rect):
		_fail("%s legend should reserve its own non-overlapping subpanel" % context)
	var visible_rooms: Array[Dictionary] = _map_view.call("_visible_rooms")
	var maximum_depth: int = 0
	for room: Dictionary in visible_rooms:
		maximum_depth = maxi(maximum_depth, int(room.get("depth", 0)))
	if int(_map_view.call("_depth_ring_count")) != maxi(1, maximum_depth):
		_fail("%s should preserve one ring per gameplay depth" % context)
	var node_size: float = float(_map_view.call("_base_node_size"))
	var safe_map_rect: Rect2 = map_rect.grow(-node_size * 0.54)
	var on_screen_room_count: int = 0
	for first_index: int in range(visible_rooms.size()):
		var first_coord: Vector2i = visible_rooms[first_index].get("coord", INVALID_COORD)
		var first_position: Vector2 = _map_view.call("_coord_position", first_coord)
		if not safe_map_rect.has_point(first_position):
			continue
		on_screen_room_count += 1
		for second_index: int in range(first_index + 1, visible_rooms.size()):
			var second_coord: Vector2i = visible_rooms[second_index].get("coord", INVALID_COORD)
			var second_position: Vector2 = _map_view.call("_coord_position", second_coord)
			if not safe_map_rect.has_point(second_position):
				continue
			if first_position.distance_to(second_position) < node_size * 0.92:
				_fail("%s room medallions overlap: %s and %s" % [context, first_coord, second_coord])
	if on_screen_room_count < 1:
		_fail("%s should keep at least the current local room in frame" % context)
	var connections: Array = _map_view.get("_visible_connections_cache") as Array
	var found_curved_route: bool = false
	for connection_var: Variant in connections:
		var connection: Dictionary = connection_var
		var from_coord: Vector2i = connection.get("from", INVALID_COORD)
		var to_coord: Vector2i = connection.get("to", INVALID_COORD)
		var curve: PackedVector2Array = _map_view.call("_route_curve_points", from_coord, to_coord)
		if curve.size() < 3:
			_fail("%s route %s to %s should be sampled as a curve" % [context, from_coord, to_coord])
			continue
		var straight_midpoint: Vector2 = curve[0].lerp(curve[curve.size() - 1], 0.5)
		var midpoint_deviation: float = curve[curve.size() / 2].distance_to(straight_midpoint)
		if midpoint_deviation > 18.1:
			_fail("%s route %s to %s bends too far from its direct connection" % [context, from_coord, to_coord])
		if midpoint_deviation >= 1.0:
			found_curved_route = true
	if not connections.is_empty() and not found_curved_route:
		_fail("%s should visibly curve at least one route" % context)

func _assert_compact_map_geometry() -> void:
	var control_rect := Rect2(Vector2.ZERO, _map_view.size)
	var map_rect: Rect2 = _map_view.call("_map_rect")
	if not control_rect.encloses(map_rect):
		_fail("Compact minimap should remain inside its embedded bounds")
	if bool(_map_view.get("show_legend")) or bool(_map_view.get("interactive")):
		_fail("Compact minimap should remain non-interactive and legend-free")

func _fail(message: String) -> void:
	_failed = true
	push_error(message)

func _early_state() -> Dictionary:
	var path: Array = [Vector2i.ZERO]
	var destinations: Array = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	return _state_from_path(path, destinations, [])

func _mid_state() -> Dictionary:
	var path: Array = [
		Vector2i.ZERO,
		Vector2i(1, 0),
		Vector2i(1, 1),
		Vector2i(2, 1),
		Vector2i(2, 2),
		Vector2i(3, 2)
	]
	var destinations: Array = [Vector2i(3, 3), Vector2i(4, 2)]
	var unavailable: Array = [
		{"from": Vector2i(1, 1), "coord": Vector2i(0, 1)},
		{"from": Vector2i(2, 2), "coord": Vector2i(2, 3)}
	]
	return _state_from_path(path, destinations, unavailable)

func _long_state() -> Dictionary:
	var path: Array = [
		Vector2i.ZERO,
		Vector2i(1, 0),
		Vector2i(2, 2),
		Vector2i(3, 2),
		Vector2i(4, 3),
		Vector2i(5, 3),
		Vector2i(6, 4),
		Vector2i(7, 5),
		Vector2i(8, 6),
		Vector2i(9, 6),
		Vector2i(10, 7),
		Vector2i(11, 8),
		Vector2i(12, 8),
		Vector2i(13, 9)
	]
	var destinations: Array = [Vector2i(14, 9), Vector2i(13, 10)]
	var unavailable: Array = [
		{"from": Vector2i(1, 0), "coord": Vector2i(1, -1)},
		{"from": Vector2i(4, 3), "coord": Vector2i(4, 4)},
		{"from": Vector2i(8, 6), "coord": Vector2i(8, 7)},
		{"from": Vector2i(11, 8), "coord": Vector2i(11, 7)}
	]
	return _state_from_path(path, destinations, unavailable)

func _state_from_path(path: Array, destinations: Array, unavailable: Array) -> Dictionary:
	var rooms: Dictionary = {}
	for index: int in range(path.size()):
		var coord: Vector2i = path[index]
		rooms[_room_key(coord)] = _probe_room(coord, index, true, false)
	for index: int in range(path.size() - 1):
		_connect_rooms(rooms, path[index], path[index + 1])
	var current: Vector2i = path[path.size() - 1]
	for destination_var: Variant in destinations:
		var destination: Vector2i = destination_var
		rooms[_room_key(destination)] = _probe_room(destination, path.size(), false, false)
		_connect_rooms(rooms, current, destination)
	for unavailable_var: Variant in unavailable:
		var unavailable_route: Dictionary = unavailable_var
		var coord: Vector2i = unavailable_route.get("coord", INVALID_COORD)
		rooms[_room_key(coord)] = _probe_room(coord, path.size() + 1, false, true)
		_connect_rooms(rooms, unavailable_route.get("from", INVALID_COORD), coord)
	return {"mode": "room", "current_room": current, "rooms": rooms}

func _probe_room(coord: Vector2i, depth: int, visited: bool, sealed: bool) -> Dictionary:
	var types: Array = ["combat", "combat", "campfire", "combat", "treasure", "blacksmith", "combat", "arcanist", "combat", "scavenger"]
	var elements: Array = ["fire", "ice", "lightning", "air", "earth"]
	var display_depth: int = depth
	var room_type: String = "start" if depth == 0 else str(types[depth % types.size()])
	var element_id: String = str(elements[depth % elements.size()]) if room_type == "combat" else "none"
	return {
		"coord": coord,
		"depth": display_depth,
		"type": room_type,
		"element": element_id,
		"revealed": true,
		"visited": visited,
		"cleared": visited,
		"sealed": sealed,
		"connections": []
	}

func _connect_rooms(rooms: Dictionary, a: Vector2i, b: Vector2i) -> void:
	if not rooms.has(_room_key(a)) or not rooms.has(_room_key(b)):
		return
	var a_room: Dictionary = rooms[_room_key(a)]
	var b_room: Dictionary = rooms[_room_key(b)]
	(a_room.get("connections", []) as Array).append({"coord": b})
	(b_room.get("connections", []) as Array).append({"coord": a})
	rooms[_room_key(a)] = a_room
	rooms[_room_key(b)] = b_room

func _room_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

func _clear_probe_output(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)
