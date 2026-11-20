extends SceneTree
## Survey generated sections and freeze the production node at its largest pose.
const Parallel = preload("res://scripts/parallel_runtime.gd")
const EngineScript = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Router = preload("res://scripts/input_router.gd")
const SectionMap = preload("res://scripts/section_map_panel.gd")
const RoomNode = preload("res://scripts/section_map_node.gd")
const LegacyMap = preload("res://scripts/labyrinth_map_view.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Icons = preload("res://scripts/room_icon_library.gd")
const DeckProbe = preload("res://tests/steam_deck_compat_probe.gd")

const SEED: int = 7
const SCROLL_PAGE_FRACTION: float = 0.75
const PEAK_GRID := Vector2i(6, 4)
const LANTERN_FIXTURE_BOSS: String = "tharokh"
const SETTLE_FRAMES: int = 2
const DESKTOP := Vector2i(1920, 1080)
const DECK := DeckProbe.DEFAULT_PHYSICAL_SIZE
const DECK_LOGICAL := DeckProbe.DEFAULT_LOGICAL_SIZE
const OUTPUT: String = "user://perf155"
const FACE_DIAMETER_FACTOR: float = 2.0 * 0.735 # section_map_node.gd polygon
const PEAK_ACTIVATION: float = 0.5

var _viewport: SubViewport
var _phase: String
var _failed: bool
var _captures: Dictionary = {}


func _initialize() -> void:
	Parallel.apply_from_environment()
	_phase = "before" if OS.get_environment("LABYRINTH_PERF155_BASELINE") == "1" else "after"
	Settings.set_storage_path("user://perf155-settings.json")
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for deck: bool in [false, true]:
		OS.set_environment("SteamDeck", "1" if deck else "0")
		var settings: Dictionary = Settings.default_settings()
		settings["reduced_motion"] = true
		Settings.save_settings(settings)
		var router: Node = root.get_node("InputRouter")
		router.call("set_forced_state_for_test",
			Router.MODALITY_CONTROLLER if deck else Router.MODALITY_POINTER,
			Router.FAMILY_STEAM_DECK if deck else Router.FAMILY_XBOX)
		var profile: String = "deck" if deck else "desktop"
		var physical: Vector2i = DECK if deck else DESKTOP
		var logical: Vector2i = DECK_LOGICAL if deck else DESKTOP
		_viewport = SubViewport.new()
		_viewport.size = physical
		_viewport.size_2d_override = logical
		_viewport.size_2d_override_stretch = true
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(_viewport)
		await _section_maps(profile, logical)
		await _peak_seals(profile, logical)
		await _legacy_map(profile, logical)
		_viewport.queue_free()
		await process_frame
	var path: String = OUTPUT.path_join(_phase + ".json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "Write capture metadata: " + path)
	else:
		file.store_string(JSON.stringify(_captures, "\t", true, true))
		file.close()
		print("PERF155 metadata " + ProjectSettings.globalize_path(path))
	print("PERF155 map %s: %s (%d states, %s)" % [_phase, "FAIL" if _failed else "PASS", _captures.size(),
		"headless geometry" if DisplayServer.get_name() == "headless" else "native renderer"])
	quit(int(_failed))


func _section_maps(profile: String, logical: Vector2i) -> void:
	var state: Dictionary = EngineScript.new().create_new_run(SEED, Store.default_data())
	for room: Dictionary in state["rooms"].values():
		# Survey the generated section without changing its graph or occupants.
		room["revealed"] = true
		room["map_outline"] = true
		if room.get("type") == "mystery":
			room["scouted"] = true
	var panel := SectionMap.new()
	panel.size = logical
	_viewport.add_child(panel)
	var seen: Dictionary = {}
	for section: int in range(6):
		state["current_room"] = Graph.section(state, section)["entry"]
		panel.set_run_state(state)
		await _settle()
		var field: Control = panel.get("_field")
		var visited: Dictionary = {}
		var page_count: int = 1 + ceili(panel.scroll_limit() / (field.size.x * SCROLL_PAGE_FRACTION))
		for page: int in range(page_count):
			panel.scroll_to(panel.scroll_limit() * float(page) / maxi(1, page_count - 1))
			await _settle()
			var seals: Array[Dictionary]
			for coord: Vector2i in panel.node_buttons:
				var node: Button = panel.node_buttons[coord]
				if not field.get_global_rect().has_point(node.get_global_rect().get_center()):
					continue
				visited[coord] = true
				var room: Dictionary = node.get("room_data")
				var id: String = Icons.icon_id_for_room(room)
				seen[id] = true
				seals.append({"id": id, "coord": str(coord), "state": node.get("route_state"),
					"center": str(node.get_global_rect().get_center()),
					"radius": node.call("visual_radius")})
			await _capture("%s_section_%d_%d" % [profile, section + 1, page + 1], {"seals": seals})
		_check(visited.size() == panel.node_buttons.size(), "Every revealed section node appears across its scroll pages")
	print("PERF155 %s section icons %s" % [profile, seen.keys()])
	panel.queue_free()
	await process_frame


func _peak_seals(profile: String, logical: Vector2i) -> void:
	# Use the exact room node and hold its peak activation while comparing art.
	# A boss-sized current room also exercises the lantern replacement.
	var canvas := Control.new()
	canvas.size = logical
	_viewport.add_child(canvas)
	var ids: Array[String] = Icons.all_icon_ids()
	var seals: Dictionary = {}
	var index: int = 0
	for id: String in ids:
		if not Icons.icon_path(id).begins_with("res://assets/art/icons/map/") or id == "special_ember_hoarder":
			continue
		var room := {"type": id, "revealed": true, "section_index": 0}
		if id.begins_with("boss_"):
			room.merge({"type": "boss", "boss_id": id.trim_prefix("boss_")}, true)
		elif id.begins_with("special_"):
			room.merge({"type": "special", "special_type": id.trim_prefix("special_")}, true)
		elif id == "start":
			room.merge({"type": "boss", "boss_id": LANTERN_FIXTURE_BOSS}, true)
		var texture: Texture2D = Icons.icon_texture(id)
		_check(texture != null, "Load " + id)
		if texture == null: continue
		if id == "scout":
			# The real Scout button has expand_icon and a 28 logical px cap.
			seals[id] = _extent(28.0, texture, logical)
			continue
		var node := RoomNode.new()
		var cell: Vector2 = Vector2(logical) / Vector2(PEAK_GRID)
		node.size = Vector2.ONE * RoomNode.max_visual_radius(room) * 2.0
		node.position = cell * Vector2(index % PEAK_GRID.x + 0.5, floori(float(index) / PEAK_GRID.x) + 0.5) - node.size * 0.5
		canvas.add_child(node)
		node.configure(room, "", "current" if id == "start" else "reachable")
		node.lantern_marker = id == "start"
		node.actionable = id != "start"
		if node.actionable: node.set_activation_progress(PEAK_ACTIVATION)
		node.set_process(false)
		var diameter: float = node.visual_radius() * node.activation_scale() * FACE_DIAMETER_FACTOR
		seals[id] = _extent(diameter, texture, logical)
		index += 1
	await _capture(profile + "_peak_seals", seals)
	canvas.queue_free()
	await process_frame


func _legacy_map(profile: String, logical: Vector2i) -> void:
	var state: Dictionary = EngineScript.new().create_new_run(SEED, Store.default_data(), false)
	var view := LegacyMap.new()
	view.size = logical
	_viewport.add_child(view)
	view.set_run_state(state)
	var extents: Dictionary = {}
	for zoom: float in [LegacyMap.CAMERA_MIN_ZOOM, 1.0, LegacyMap.CAMERA_MAX_ZOOM]:
		view.set_camera_zoom(zoom)
		var side: float = float(view.call("_node_size_for_state", LegacyMap.ROUTE_CURRENT)) * 0.245 * 1.70
		extents[str(zoom)] = [side * _viewport.size.x / logical.x, side * _viewport.size.y / logical.y]
	await _capture(profile + "_legacy_zoom_max", extents)
	view.queue_free()
	await process_frame


func _extent(side: float, texture: Texture2D, logical: Vector2i) -> Dictionary:
	return {"width_px": side * _viewport.size.x / logical.x, "height_px": side * _viewport.size.y / logical.y,
		"texture_px": str(texture.get_size())}


func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES):
		await process_frame


func _capture(name: String, data: Dictionary) -> void:
	await _settle()
	_captures[name] = {"viewport": str(_viewport.size), "data": data}
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	if not _check(image != null and image.get_size() == _viewport.size, "Native capture size " + name): return
	var path: String = OUTPUT.path_join(name + ".png")
	if _check(image.save_png(path) == OK, "Save " + path):
		print(ProjectSettings.globalize_path(path))


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failed = true
		push_error("PERF155: " + message)
	return condition
