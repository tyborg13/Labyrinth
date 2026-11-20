extends SceneTree

const Assets = preload("res://scripts/asset_loader.gd")
const DeckProbe = preload("res://tests/steam_deck_compat_probe.gd")
const Graftwright = preload("res://tests/suites/graftwright_suite.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Hearth = preload("res://tests/suites/ember_hearth_suite.gd")
const Parallel = preload("res://scripts/parallel_runtime.gd")
const RoomIcons = preload("res://scripts/room_icon_library.gd")
const Router = preload("res://scripts/input_router.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const TextureLoad = preload("res://tools/perf153/texture_load.gd")

const DESKTOP_SIZE := Vector2i(1920, 1080)
const MAP_SEED_LIMIT: int = 30
const READY_SECONDS: float = 0.65
const OUTPUT_DIR: String = "user://perf153"

var _viewport: SubViewport
var _scene: Node
var _baseline: bool
var _failed: bool = false


func _initialize() -> void:
	Parallel.apply_from_environment()
	_baseline = OS.get_environment("LABYRINTH_PERF153_BASELINE") == "1"
	Store.set_storage_path("user://perf153_profile.json")
	Store.set_run_storage_path("user://perf153_run.save")
	Settings.set_storage_path("user://perf153_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	Settings.save_settings(settings)
	call_deferred("_run")


func _run() -> void:
	var phase: String = "before" if _baseline else "after"
	var output: String = OUTPUT_DIR.path_join(phase)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for deck: bool in [false, true]:
		var physical_size: Vector2i = DeckProbe.DEFAULT_PHYSICAL_SIZE if deck else DESKTOP_SIZE
		var logical_size: Vector2i = DeckProbe.DEFAULT_LOGICAL_SIZE if deck else DESKTOP_SIZE
		var profile: String = "deck" if deck else "desktop"
		_viewport = SubViewport.new()
		_viewport.size = physical_size
		_viewport.size_2d_override = logical_size
		_viewport.size_2d_override_stretch = true
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(_viewport)
		var router: Node = root.get_node("InputRouter")
		router.call("set_forced_state_for_test",
			Router.MODALITY_CONTROLLER if deck else Router.MODALITY_POINTER,
			Router.FAMILY_STEAM_DECK if deck else Router.FAMILY_XBOX)
		await _new_scene()
		if await _campfire():
			await _capture(output, profile, "campfire")
		await _new_scene()
		if await _graftwright():
			await _capture(output, profile, "graftwright")
		await _new_scene()
		if await _map():
			await _capture(output, profile, "hoarder_map")
		_viewport.queue_free()
		_scene = null
		await process_frame
	print("PERF153 UI %s: %s%s" % [phase, "FAIL" if _failed else "PASS",
		" (headless semantics only)" if DisplayServer.get_name() == "headless" else ""])
	quit(1 if _failed else 0)


func _new_scene() -> void:
	if is_instance_valid(_scene):
		_scene.queue_free()
		await process_frame
	Store.clear_saved_run()
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_scene = packed.instantiate()
	_viewport.add_child(_scene)
	await process_frame


func _campfire() -> bool:
	Hearth.setup(_scene, 20, 180, true, true)
	await Hearth.wait_ready(self)
	var choices: HBoxContainer = _scene.get("_relic_choice_bar")
	var expected := {"embrace": 0, "linger": 1, "purge": 2, "strength": 3}
	for child: Node in choices.get_children():
		var id: String = str(child.get_meta("choice_id", ""))
		if not expected.has(id): continue
		var art: TextureRect = child.find_child("CampfireChoiceBackground", true, false) as TextureRect
		if not _check(art != null and art.is_visible_in_tree() and _uses_texture(art.texture, expected[id]),
			"Campfire is showing the %s illustration" % id):
			return false
		expected.erase(id)
	return _check(expected.is_empty(), "All four campfire paintings are visible")


func _graftwright() -> bool:
	_scene.call("_load_run_state", Graftwright.fixture())
	await create_timer(READY_SECONDS).timeout
	var view: Control = _scene.find_child("GraftwrightView", true, false) as Control
	if not _check(view != null and view.is_visible_in_tree(), "Live Graftwright is visible"):
		return false
	view.call("begin_work")
	view.call("select_recipient", "undertaker_plate")
	view.call("select_donor", "patched_cloak")
	view.call("select_source", 1)
	view.call("select_target", 1)
	await process_frame
	var commit: Button = view.find_child("GraftCommit", true, false) as Button
	if not _check(commit != null and commit.is_visible_in_tree() and not commit.disabled,
		"Graftwright is showing an enabled ritual clasp"):
		return false
	for node: Node in commit.find_children("*", "TextureRect", true, false):
		var art: TextureRect = node as TextureRect
		if art.is_visible_in_tree() and _uses_texture(art.texture, 4):
			return true
	return _check(false, "The ritual clasp is using its production texture")


func _map() -> bool:
	var engine := RunEngine.new()
	for seed: int in range(1, MAP_SEED_LIMIT):
		var state: Dictionary = engine.create_new_run(seed, Store.default_data())
		for room: Dictionary in state["rooms"].values():
			if str(room.get("type", "")) != "special" or str(room.get("special_type", "")) != "ember_hoarder" or int(room.get("section_index", -1)) != Graph.active_section(state):
				continue
			var coord: Vector2i = room["coord"]
			_scene.call("_load_run_state", state)
			_scene.call("_close_dialogue")
			await process_frame
			_scene.call("_open_large_map", true)
			var map: Control = _scene.get("_large_map_view")
			room["revealed"] = true
			# Survey the selected node in the production map without entering combat.
			map.call("set_run_state", state)
			map.call("select_section", int(room["section_index"]))
			await process_frame
			var button: Control = (map.get("node_buttons") as Dictionary).get(coord)
			if not _check(button != null and button.is_visible_in_tree(), "Generated map shows the Hoarder node"):
				return false
			map.call("_keep_room_visible", coord)
			await create_timer(READY_SECONDS).timeout
			var bounds: Rect2 = (map.get("_field") as Control).get_global_rect()
			var icon_id: String = RoomIcons.icon_id_for_room(button.get("room_data"))
			return _check(bounds.has_point(button.get_global_rect().get_center())
				and icon_id == "special_ember_hoarder" and _uses_texture(RoomIcons.icon_texture(icon_id), 5),
				"Visible map node uses the Ember Hoarder emblem")
	return _check(false, "Find a generated map containing the Ember Hoarder")


func _uses_texture(texture: Texture2D, index: int) -> bool:
	var path: String = TextureLoad.PATHS[index]
	var expected := Vector2(1254, 1254) if _baseline else Vector2(640, 640)
	if index == 4:
		expected = Vector2(2172, 724) if _baseline else Vector2(744, 248)
	elif index == 5:
		expected = Vector2(1024, 1024) if _baseline else Vector2(128, 128)
	return texture != null and texture == Assets.load_texture(path) and texture.get_size() == expected


func _capture(output: String, profile: String, surface: String) -> void:
	print("PERF153 verified %s %s at %s" % [profile, surface, _viewport.size])
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	if not _check(image != null and image.get_size() == _viewport.size, "Native capture has exact dimensions"):
		return
	var path: String = output.path_join("%s_%s.png" % [profile, surface])
	if _check(image.save_png(path) == OK, "Save " + path):
		print(ProjectSettings.globalize_path(path))


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failed = true
		push_error("PERF153: " + message)
	return condition
