extends SceneTree

const LabyrinthMapView = preload("res://scripts/labyrinth_map_view.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

const OUTPUT_DIR: String = "user://map_decision_layer_probe"
const INVALID_COORD: Vector2i = Vector2i(-999, -999)

var _background: ColorRect
var _map_view: LabyrinthMapView
var _capture_index: int = 0

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	_build_surface()
	await process_frame
	await process_frame

	await _capture_large("large_early.png", _early_state(), INVALID_COORD)
	await _capture_large("large_mid.png", _mid_state(), INVALID_COORD)
	await _capture_large("large_long.png", _long_state(), INVALID_COORD)
	await _capture_large("edge_hover.png", _long_state(), Vector2i(-5, 4))
	await _capture_mini("mini_compact.png", _long_state())

	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()

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
	_map_view.set("_hover_coord", hover_coord)
	if hover_coord.x > -900:
		var hover_rect: Rect2 = _map_view.call("_hover_card_rect", hover_coord)
		if bool(_map_view.call("_hover_card_intersects_other_node", hover_rect, hover_coord)):
			push_error("edge hover card overlaps another visible map node")
			quit(1)
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
	_capture_index += 1
	_background.color = Color("120d0a") if _capture_index % 2 == 0 else Color("130e0b")
	_background.queue_redraw()
	_map_view.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame
	await create_timer(0.08).timeout
	var image: Image = root.get_texture().get_image()
	image = _crop_to_control(image, _map_view, 20.0)
	image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name]))

func _crop_to_control(image: Image, control: Control, padding: float) -> Image:
	var viewport_rect: Rect2 = root.get_visible_rect()
	var scale := Vector2(float(image.get_width()) / viewport_rect.size.x, float(image.get_height()) / viewport_rect.size.y)
	var control_rect: Rect2 = control.get_global_rect().grow(padding)
	var crop_rect := Rect2i(
		Vector2i(maxi(0, int(floor(control_rect.position.x * scale.x))), maxi(0, int(floor(control_rect.position.y * scale.y)))),
		Vector2i(int(ceil(control_rect.size.x * scale.x)), int(ceil(control_rect.size.y * scale.y)))
	)
	crop_rect.size.x = mini(crop_rect.size.x, image.get_width() - crop_rect.position.x)
	crop_rect.size.y = mini(crop_rect.size.y, image.get_height() - crop_rect.position.y)
	return image.get_region(crop_rect)

func _save_viewport(output_path: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(output_path))

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
		Vector2i(1, 1),
		Vector2i(2, 1),
		Vector2i(2, 2),
		Vector2i(1, 2),
		Vector2i(0, 2),
		Vector2i(-1, 2),
		Vector2i(-2, 2),
		Vector2i(-2, 3),
		Vector2i(-3, 3),
		Vector2i(-4, 3),
		Vector2i(-4, 4)
	]
	var destinations: Array = [Vector2i(-5, 4), Vector2i(-4, 5)]
	var unavailable: Array = [
		{"from": Vector2i(1, 0), "coord": Vector2i(1, -1)},
		{"from": Vector2i(2, 1), "coord": Vector2i(3, 1)},
		{"from": Vector2i(0, 2), "coord": Vector2i(0, 3)},
		{"from": Vector2i(-2, 2), "coord": Vector2i(-2, 1)}
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
	var display_depth: int = mini(depth, 8)
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
