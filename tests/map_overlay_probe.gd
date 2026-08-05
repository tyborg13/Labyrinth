extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")

const OUTPUT_DIR: String = "user://map_overlay_redesign_probe_v2"
const PROBE_VIEWPORT: Vector2i = Vector2i(1920, 1080)
const INVALID_COORD: Vector2i = Vector2i(-999, -999)

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
	ProgressionStore.set_storage_path("user://labyrinth_progression_map_overlay_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_map_overlay_probe.save")
	ProgressionStore.clear_saved_run()
	await _capture_overlay()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(1 if _failed else 0)

func _capture_overlay() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_fail("Run scene should load for the full map overlay proof")
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	instance.call("_close_dialogue")
	instance.call("_open_large_map")
	await process_frame
	await process_frame

	var scrim: Control = instance.get("_large_map_scrim") as Control
	var dialog: Control = instance.get("_large_map_dialog") as Control
	var map_view: Control = instance.get("_large_map_view") as Control
	_assert_overlay_chrome(scrim, dialog, map_view)
	await _save_root_screenshot("%s/overlay_early.png" % OUTPUT_DIR)

	if map_view != null:
		map_view.call("set_run_state", _long_state())
		map_view.call("center_on_current", true)
		map_view.set("_hover_coord", Vector2i(14, 9))
		map_view.queue_redraw()
		var depth_label: Label = dialog.find_child("DepthLabel", true, false) as Label if dialog != null else null
		if depth_label != null:
			depth_label.text = "DEPTH 14  •  RING 14"
		# Re-present the modal so the macOS mobile renderer rebuilds every retained
		# canvas item before the second full-frame screenshot.
		scrim.visible = false
		await process_frame
		scrim.visible = true
		await process_frame
		await process_frame
		_assert_map_geometry(map_view)
		var hover_rect: Rect2 = map_view.call("_hover_card_rect", Vector2i(14, 9))
		if not (map_view.call("_hover_card_bounds") as Rect2).encloses(hover_rect):
			_fail("Full overlay hover card should remain inside the map field")
		if bool(map_view.call("_hover_card_intersects_other_node", hover_rect, Vector2i(14, 9))):
			_fail("Full overlay hover card should not cover another room medallion")
		await _save_root_screenshot("%s/overlay_long_hover.png" % OUTPUT_DIR)
		map_view.call("set_camera_zoom", 1.38, map_view.call("_coord_position", Vector2i(13, 9)))
		map_view.set("_hover_coord", INVALID_COORD)
		map_view.queue_redraw()
		await _refresh_overlay_canvas(scrim)
		await _save_root_screenshot("%s/overlay_long_zoomed.png" % OUTPUT_DIR)
		map_view.call("pan_camera", Vector2(-250.0, 86.0))
		map_view.queue_redraw()
		await _refresh_overlay_canvas(scrim)
		await _save_root_screenshot("%s/overlay_long_panned.png" % OUTPUT_DIR)

	instance.queue_free()
	await process_frame

func _refresh_overlay_canvas(scrim: Control) -> void:
	if scrim == null:
		return
	scrim.visible = false
	await process_frame
	scrim.visible = true
	await process_frame
	await process_frame
	RenderingServer.force_draw(true)
	await process_frame

func _assert_overlay_chrome(scrim: Control, dialog: Control, map_view: Control) -> void:
	if root.get_viewport().get_visible_rect().size != Vector2(PROBE_VIEWPORT):
		_fail("Map overlay proof should use an exact 1920x1080 logical viewport")
	if scrim == null or not scrim.visible:
		_fail("Full map scrim should be visible")
	if dialog == null or map_view == null:
		_fail("Full map dialog and map view should exist")
		return
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(PROBE_VIEWPORT))
	var dialog_rect: Rect2 = dialog.get_global_rect()
	if not viewport_rect.encloses(dialog_rect) or dialog_rect.position.x < 20.0 or dialog_rect.position.y < 20.0:
		_fail("Full map frame should preserve the production safe margin")
	if dialog_rect.size.x < PROBE_VIEWPORT.x * 0.94 or dialog_rect.size.y < PROBE_VIEWPORT.y * 0.92:
		_fail("Full map frame should use the production viewport confidently")
	var title: Label = dialog.find_child("MapTitle", true, false) as Label
	var subtitle: Label = dialog.find_child("MapSubtitle", true, false) as Label
	var depth_strip: Control = dialog.find_child("DepthStrip", true, false) as Control
	var depth_ornament: TextureRect = dialog.find_child("DepthOrnament", true, false) as TextureRect
	var depth_label: Label = dialog.find_child("DepthLabel", true, false) as Label
	var navigation_hint: Label = dialog.find_child("MapNavigationHint", true, false) as Label
	var close_button: Button = dialog.find_child("CloseButton", true, false) as Button
	if title == null or title.text != "LABYRINTH" or subtitle == null or subtitle.text != "THE UMBRAL DESCENT":
		_fail("Full map should expose its authored title hierarchy")
	if depth_strip == null or depth_strip.size.y < 32.0 or depth_ornament == null or depth_ornament.texture == null or depth_label == null or depth_label.text.is_empty():
		_fail("Full map should expose its brass depth-status separator")
	if navigation_hint == null or not navigation_hint.text.contains("PAN") or not navigation_hint.text.contains("ZOOM"):
		_fail("Full map should explain its drag and wheel navigation")
	if close_button == null:
		_fail("Full map should expose a close control")
	elif title != null and close_button.get_global_rect().intersects(title.get_global_rect()):
		_fail("Full map close control should not overlap its title")
	if dialog.get_node_or_null("ThemedPanelOrnament") == null:
		_fail("Full map should render the shared authored outer frame")
	if not bool(map_view.get("draw_background")) or not bool(map_view.get("show_legend")) or not bool(map_view.get("interactive")):
		_fail("Full overlay map should render its backdrop, legend, and interactive decision states")
	_assert_map_geometry(map_view)

func _assert_map_geometry(map_view: Control) -> void:
	var map_rect: Rect2 = map_view.call("_map_rect")
	var legend_rect: Rect2 = map_view.call("_legend_rect")
	var control_rect := Rect2(Vector2.ZERO, map_view.size)
	if not control_rect.encloses(map_rect) or not control_rect.encloses(legend_rect) or map_rect.intersects(legend_rect):
		_fail("Full overlay map and legend should remain in separate safe bounds")
	var visible_rooms: Array[Dictionary] = map_view.call("_visible_rooms")
	var node_size: float = float(map_view.call("_base_node_size"))
	var safe_map_rect: Rect2 = map_rect.grow(-node_size * 0.54)
	var on_screen_room_count: int = 0
	for first_index: int in range(visible_rooms.size()):
		var first_coord: Vector2i = visible_rooms[first_index].get("coord", INVALID_COORD)
		var first_position: Vector2 = map_view.call("_coord_position", first_coord)
		if not safe_map_rect.has_point(first_position):
			continue
		on_screen_room_count += 1
		for second_index: int in range(first_index + 1, visible_rooms.size()):
			var second_coord: Vector2i = visible_rooms[second_index].get("coord", INVALID_COORD)
			var second_position: Vector2 = map_view.call("_coord_position", second_coord)
			if not safe_map_rect.has_point(second_position):
				continue
			if first_position.distance_to(second_position) < node_size * 0.92:
				_fail("Full overlay room medallions should not overlap: %s and %s" % [first_coord, second_coord])
	if on_screen_room_count < 1:
		_fail("Full overlay should keep a local room neighborhood in frame")

func _long_state() -> Dictionary:
	var path: Array = [
		Vector2i.ZERO,
		Vector2i(1, 0),
		Vector2i(2, 1),
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
	var rooms: Dictionary = {}
	for index: int in range(path.size()):
		var coord: Vector2i = path[index]
		rooms[_room_key(coord)] = _probe_room(coord, index, true, false)
	for index: int in range(path.size() - 1):
		_connect_rooms(rooms, path[index], path[index + 1])
	var current: Vector2i = path[path.size() - 1]
	for destination: Vector2i in [Vector2i(14, 9), Vector2i(13, 10)]:
		rooms[_room_key(destination)] = _probe_room(destination, 14, false, false)
		_connect_rooms(rooms, current, destination)
	for unavailable_var: Variant in [
		{"from": Vector2i(4, 3), "coord": Vector2i(4, 4), "depth": 4},
		{"from": Vector2i(8, 6), "coord": Vector2i(8, 7), "depth": 8},
		{"from": Vector2i(11, 8), "coord": Vector2i(11, 7), "depth": 11}
	]:
		var unavailable: Dictionary = unavailable_var
		var coord: Vector2i = unavailable.get("coord", INVALID_COORD)
		rooms[_room_key(coord)] = _probe_room(coord, int(unavailable.get("depth", 1)), false, true)
		_connect_rooms(rooms, unavailable.get("from", INVALID_COORD), coord)
	return {"mode": "room", "current_room": current, "rooms": rooms}

func _probe_room(coord: Vector2i, depth: int, visited: bool, sealed: bool) -> Dictionary:
	var types: Array = ["combat", "campfire", "combat", "treasure", "blacksmith", "combat", "arcanist", "combat", "scavenger"]
	var elements: Array = ["fire", "ice", "lightning", "air", "earth"]
	var room_type: String = "start" if depth == 0 else str(types[depth % types.size()])
	return {
		"coord": coord,
		"depth": depth,
		"type": room_type,
		"element": str(elements[depth % elements.size()]) if room_type == "combat" else "none",
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

func _save_root_screenshot(output_path: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw(true)
	await process_frame
	# Prime both mobile-renderer backbuffers; otherwise alternating captures can
	# contain only the dirty canvas region after a retained UI redraw.
	root.get_viewport().get_texture().get_image()
	await process_frame
	RenderingServer.force_draw(true)
	await process_frame
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null:
		_fail("Map overlay proof should capture a renderer image")
		return
	var source_size: Vector2i = image.get_size()
	var scale_x: float = float(source_size.x) / float(PROBE_VIEWPORT.x)
	var scale_y: float = float(source_size.y) / float(PROBE_VIEWPORT.y)
	if not is_equal_approx(scale_x, scale_y):
		_fail("Map overlay proof should preserve 1920x1080 proportions, got %s" % source_size)
		return
	if source_size != PROBE_VIEWPORT:
		image.resize(PROBE_VIEWPORT.x, PROBE_VIEWPORT.y, Image.INTERPOLATE_LANCZOS)
	image.save_png(ProjectSettings.globalize_path(output_path))

func _clear_probe_output(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
