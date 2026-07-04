extends SceneTree

const LabyrinthMapView = preload("res://scripts/labyrinth_map_view.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

const OUTPUT_DIR: String = "user://map_travel_probe"
const START_COORD: Vector2i = Vector2i.ZERO
const DESTINATION_COORD: Vector2i = Vector2i(1, 0)

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	await _capture_map_travel_case("mini", false, false, Vector2(260.0, 188.0), Vector2i(340, 240))
	await _capture_map_travel_case("large", true, true, Vector2(920.0, 580.0), Vector2i(980, 660))
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()

func _capture_map_travel_case(case_name: String, interactive: bool, show_legend: bool, map_size: Vector2, window_size: Vector2i) -> void:
	var map_view := LabyrinthMapView.new()
	map_view.interactive = interactive
	map_view.show_legend = show_legend
	map_view.draw_background = true
	map_view.size = map_size
	map_view.set_run_state(_travel_run_state(START_COORD))
	map_view.call("begin_travel_animation", START_COORD, DESTINATION_COORD)
	map_view.set("_travel_progress", 0.52)
	var in_transit: Image = _draw_map_proof(map_view, window_size)
	in_transit.save_png("%s/%s_in_transit.png" % [OUTPUT_DIR, case_name])
	map_view.call("clear_travel_animation")
	map_view.set_run_state(_travel_run_state(DESTINATION_COORD))
	var settled: Image = _draw_map_proof(map_view, window_size)
	settled.save_png("%s/%s_settled.png" % [OUTPUT_DIR, case_name])
	map_view.free()
	await process_frame

func _travel_run_state(current_coord: Vector2i) -> Dictionary:
	return {
		"mode": "room",
		"current_room": current_coord,
		"rooms": {
			"0,0": {
				"coord": START_COORD,
				"type": "start",
				"revealed": true,
				"visited": true,
				"cleared": true,
				"connections": [{"coord": DESTINATION_COORD}]
			},
			"1,0": {
				"coord": DESTINATION_COORD,
				"type": "combat",
				"element": "fire",
				"revealed": true,
				"visited": false,
				"cleared": false,
				"connections": [{"coord": START_COORD}]
			}
		}
	}

func _draw_map_proof(map_view: LabyrinthMapView, window_size: Vector2i) -> Image:
	var image := Image.create(window_size.x, window_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.045, 0.034, 0.028, 1.0))
	var map_size: Vector2 = map_view.size
	var origin: Vector2 = (Vector2(window_size) - map_size) * 0.5
	image.fill_rect(_rect2i(Rect2(origin, map_size)), Color(0.075, 0.055, 0.045, 0.58))
	var run_state: Dictionary = map_view.get("run_state")
	var rooms: Dictionary = run_state.get("rooms", {})
	var drawn_connections: Dictionary = {}
	for room_key: String in rooms.keys():
		var room: Dictionary = rooms[room_key]
		if not bool(map_view.call("_room_visible_on_this_map", room)):
			continue
		var coord: Vector2i = room.get("coord", Vector2i.ZERO)
		for connection_var: Variant in room.get("connections", []):
			if typeof(connection_var) != TYPE_DICTIONARY:
				continue
			var connection: Dictionary = connection_var
			var neighbor: Vector2i = connection.get("coord", Vector2i(999, 999))
			var neighbor_key: String = "%d,%d" % [neighbor.x, neighbor.y]
			var pair_key: String = "%s|%s" % [room_key, neighbor_key] if room_key < neighbor_key else "%s|%s" % [neighbor_key, room_key]
			if drawn_connections.has(pair_key):
				continue
			var neighbor_room: Dictionary = map_view.call("_room_at", neighbor)
			if neighbor_room.is_empty() or not bool(map_view.call("_room_visible_on_this_map", neighbor_room)):
				continue
			drawn_connections[pair_key] = true
			_draw_connector_proof(image, map_view, origin, coord, neighbor, bool(room.get("revealed", false)) and bool(neighbor_room.get("revealed", false)))
	for room_key: String in rooms.keys():
		var shell_room: Dictionary = rooms[room_key]
		if bool(map_view.call("_room_visible_on_this_map", shell_room)):
			_draw_room_shell_proof(image, map_view, origin, shell_room)
	for command_var: Variant in map_view.call("_travel_visual_commands", "trace"):
		_draw_travel_command_proof(image, command_var as Dictionary, origin)
	for room_key: String in rooms.keys():
		var node_room: Dictionary = rooms[room_key]
		if bool(map_view.call("_room_visible_on_this_map", node_room)):
			_draw_room_node_proof(image, map_view, origin, node_room)
	for command_var: Variant in map_view.call("_travel_visual_commands", "token"):
		_draw_travel_command_proof(image, command_var as Dictionary, origin)
	if bool(map_view.get("show_legend")):
		_draw_legend_proof(image, map_view, origin)
	return image

func _draw_connector_proof(image: Image, map_view: LabyrinthMapView, origin: Vector2, a: Vector2i, b: Vector2i, revealed: bool) -> void:
	var a_pos: Vector2 = origin + (map_view.call("_coord_position", a) as Vector2)
	var b_pos: Vector2 = origin + (map_view.call("_coord_position", b) as Vector2)
	var thickness: float = maxf(3.0 if not bool(map_view.get("interactive")) else 4.0, float(map_view.call("_base_node_size")) * 0.28)
	_draw_image_line(image, a_pos, b_pos, Color(0.025, 0.020, 0.016, 0.58), int(roundf(thickness + 2.0)))
	_draw_image_line(image, a_pos, b_pos, Color("9a8062") if revealed else Color(0.27, 0.23, 0.20, 0.56), int(roundf(thickness)))

func _draw_room_shell_proof(image: Image, map_view: LabyrinthMapView, origin: Vector2, room: Dictionary) -> void:
	var coord: Vector2i = room.get("coord", Vector2i.ZERO)
	var center: Vector2 = origin + (map_view.call("_coord_position", coord) as Vector2)
	var node_size: float = float(map_view.call("_base_node_size")) * 0.92
	var rect := Rect2(center - Vector2.ONE * node_size * 0.5, Vector2.ONE * node_size)
	image.fill_rect(_rect2i(rect.grow(2.0 if bool(map_view.get("interactive")) else 1.0)), Color(0.02, 0.015, 0.012, 0.42))
	image.fill_rect(_rect2i(rect), Color(0.18, 0.15, 0.13, 0.60))
	_draw_rect_outline(image, rect, Color(0.42, 0.35, 0.31, 0.54), 1)

func _draw_room_node_proof(image: Image, map_view: LabyrinthMapView, origin: Vector2, room: Dictionary) -> void:
	var coord: Vector2i = room.get("coord", Vector2i.ZERO)
	var current: Vector2i = (map_view.get("run_state") as Dictionary).get("current_room", Vector2i.ZERO)
	var center: Vector2 = origin + (map_view.call("_coord_position", coord) as Vector2)
	var accessible: bool = (map_view.call("_available_move_coords") as Array).has(coord)
	var node_size: float = float(map_view.call("_base_node_size"))
	if coord == current:
		node_size *= 1.22
	elif accessible and bool(map_view.get("interactive")):
		node_size *= 1.08
	var rect := Rect2(center - Vector2.ONE * node_size * 0.5, Vector2.ONE * node_size)
	image.fill_rect(_rect2i(rect.grow(2.0 if bool(map_view.get("interactive")) else 1.0)), Color(0.0, 0.0, 0.0, 0.24))
	image.fill_rect(_rect2i(rect), map_view.call("_room_fill_color", room))
	_draw_rect_outline(image, rect, map_view.call("_room_border_color", room, accessible), 2)
	if coord == current:
		_draw_rect_outline(image, rect.grow(4.0 if bool(map_view.get("interactive")) else 2.5), Color("f2c978"), 2)

func _draw_travel_command_proof(image: Image, command: Dictionary, origin: Vector2) -> void:
	match str(command.get("type", "")):
		"line":
			_draw_image_line(image, origin + (command.get("from", Vector2.ZERO) as Vector2), origin + (command.get("to", Vector2.ZERO) as Vector2), command.get("color", Color.WHITE), int(ceil(float(command.get("width", 1.0)))))
		"arc":
			_draw_ring(image, origin + (command.get("center", Vector2.ZERO) as Vector2), float(command.get("radius", 0.0)), int(ceil(float(command.get("width", 1.0)))), command.get("color", Color.WHITE))
		"circle":
			_draw_circle(image, origin + (command.get("center", Vector2.ZERO) as Vector2), float(command.get("radius", 0.0)), command.get("color", Color.WHITE))

func _draw_legend_proof(image: Image, map_view: LabyrinthMapView, origin: Vector2) -> void:
	var rect: Rect2 = map_view.call("_legend_rect")
	rect.position += origin
	image.fill_rect(_rect2i(rect), Color(0.08, 0.06, 0.05, 0.82))
	_draw_rect_outline(image, rect, Color(0.93, 0.85, 0.70, 0.36), 1)
	var entries: Array = map_view.call("_legend_entries")
	for index: int in range(mini(entries.size(), 8)):
		var entry: Dictionary = entries[index]
		var row_y: float = rect.position.y + 16.0 + float(index) * 30.0
		image.fill_rect(_rect2i(Rect2(Vector2(rect.position.x + 14.0, row_y), Vector2(18.0, 18.0))), map_view.call("_room_fill_color", entry.get("room", {})))
		image.fill_rect(_rect2i(Rect2(Vector2(rect.position.x + 42.0, row_y + 6.0), Vector2(70.0, 5.0))), Color("d9cbb2"))

func _rect2i(rect: Rect2) -> Rect2i:
	return Rect2i(int(roundf(rect.position.x)), int(roundf(rect.position.y)), int(roundf(rect.size.x)), int(roundf(rect.size.y)))

func _draw_rect_outline(image: Image, rect: Rect2, color: Color, width: int) -> void:
	var r: Rect2i = _rect2i(rect)
	image.fill_rect(Rect2i(r.position.x, r.position.y, r.size.x, width), color)
	image.fill_rect(Rect2i(r.position.x, r.end.y - width, r.size.x, width), color)
	image.fill_rect(Rect2i(r.position.x, r.position.y, width, r.size.y), color)
	image.fill_rect(Rect2i(r.end.x - width, r.position.y, width, r.size.y), color)

func _draw_ring(image: Image, center: Vector2, radius: float, width: int, color: Color) -> void:
	var outer: int = int(ceil(radius))
	var inner_radius: float = maxf(0.0, radius - float(width))
	for y_offset: int in range(-outer, outer + 1):
		for x_offset: int in range(-outer, outer + 1):
			var distance: float = Vector2(float(x_offset), float(y_offset)).length()
			if distance <= radius and distance >= inner_radius:
				_set_image_pixel_blend(image, int(roundf(center.x)) + x_offset, int(roundf(center.y)) + y_offset, color)

func _draw_circle(image: Image, center: Vector2, radius: float, color: Color) -> void:
	var rounded_radius: int = int(ceil(radius))
	for y_offset: int in range(-rounded_radius, rounded_radius + 1):
		for x_offset: int in range(-rounded_radius, rounded_radius + 1):
			if Vector2(float(x_offset), float(y_offset)).length() <= radius:
				_set_image_pixel_blend(image, int(roundf(center.x)) + x_offset, int(roundf(center.y)) + y_offset, color)

func _draw_image_line(image: Image, from_point: Vector2, to_point: Vector2, color: Color, width: int) -> void:
	var steps: int = maxi(1, int(from_point.distance_to(to_point)))
	for step: int in range(steps + 1):
		var point: Vector2 = from_point.lerp(to_point, float(step) / float(steps))
		_draw_circle(image, point, float(width), color)

func _set_image_pixel_blend(image: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return
	var alpha: float = clampf(color.a, 0.0, 1.0)
	var existing: Color = image.get_pixel(x, y)
	image.set_pixel(x, y, existing.lerp(Color(color.r, color.g, color.b, 1.0), alpha))

func _clear_probe_output(output_dir: String) -> void:
	var absolute_dir: String = ProjectSettings.globalize_path(output_dir)
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry.is_empty():
			break
		if entry in [".", ".."]:
			continue
		var child_path: String = absolute_dir.path_join(entry)
		if dir.current_is_dir():
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	dir.list_dir_end()
