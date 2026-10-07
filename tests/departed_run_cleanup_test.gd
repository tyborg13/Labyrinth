extends SceneTree

const Parallel = preload("res://scripts/parallel_runtime.gd")
const Profile = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Cleanup = preload("res://scripts/departed_run_cleanup.gd")

var errors: Array[String]
var cases: int = 0
var _retired_ids: PackedInt64Array
var _exit_count: int = 0
var _changed_count: int = 0
var _draining_at_menu: bool = false

func _initialize() -> void:
	Parallel.apply_from_environment()
	Profile.set_storage_path("user://departed_cleanup_profile.json")
	Profile.set_run_storage_path("user://departed_cleanup_run.save")
	Profile.clear_saved_run()
	Profile.save_data(Tutorial.complete_tutorial(Profile.default_data()))
	Settings.set_storage_path("user://departed_cleanup_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = "windowed"
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	Settings.apply_settings(settings, null, false)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920, 1080)
	_run.call_deferred()

func _run() -> void:
	for route: String in ["ordinary", "interrupted", "fast_continue"]:
		var interrupt: bool = route == "interrupted"
		Profile.clear_saved_run()
		var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
		root.add_child(scene)
		current_scene = scene
		await _settle(12)
		var extra := Node.new()
		extra.name = "CleanupQueuedFixture"
		scene.add_child(extra)
		var queued := Node.new()
		extra.add_child(queued)
		queued.queue_free()
		_retired_ids.clear()
		_capture_ids(scene)
		_exit_count = 0
		_changed_count = 0
		scene.tree_exiting.connect(func() -> void: _exit_count += 1)
		var old_id: int = scene.get_instance_id()
		var on_changed := func() -> void:
			_changed_count += 1
			_check(not is_instance_id_valid(old_id), "The old root must die before scene_changed, just as in native SceneTree")
			_check(current_scene != null and current_scene.is_inside_tree(), "scene_changed must expose the attached destination")
		scene_changed.connect(on_changed, CONNECT_ONE_SHOT)
		scene._on_save_and_quit_pressed()
		var saved: Dictionary = Profile.load_saved_run()
		var progression: Dictionary = Profile.load_data()
		for frame: int in range(600):
			await process_frame
			if current_scene != null and current_scene.scene_file_path == Cleanup.TITLE_PATH: break
		_check(current_scene != null and current_scene.scene_file_path == Cleanup.TITLE_PATH, "Save and Quit must reach the public title scene")
		var menu: Node = current_scene
		_check(_exit_count == 1 and _changed_count == 1, "The departed root must exit once and announce the destination once")
		_check(not is_instance_valid(scene), "The old root must retain the original scene-change lifetime")
		var drain: Node = root.get_node_or_null("DepartedRunCleanup")
		_check(drain != null, "Cleanup must have a root-owned drain at initial menu readiness")
		_draining_at_menu = drain != null
		_check_external_receivers()
		# Switch input families and resize while old controls still await deletion.
		# Their original native-free boundary must not leave global callbacks live.
		var router: Node = root.get_node("InputRouter")
		router.set_modality("controller")
		router.force_family_for_test("steam_deck")
		router.set_modality("pointer")
		router.clear_forced_family_for_test()
		root.size = Vector2i(1920, 1080)
		var settings_button: Button = menu.get_node("MenuColumn/SettingsButton")
		settings_button.pressed.emit()
		_check(menu.get_node("SettingsPanel").visible, "The first Settings action must work while cleanup is pending")
		menu.get_node("SettingsPanel").call("back_button").pressed.emit()
		_check(not menu.get_node("SettingsPanel").visible, "Settings Back must retain the ordinary menu route during cleanup")
		_check(not root.gui_disable_input, "Cleanup must not acquire the public input lock")
		if route == "ordinary" and is_instance_valid(drain) and not drain._pending.is_empty():
			# A queued branch can disappear between presentation slices.
			(drain._pending.back() as Node).queue_free()
		if route == "fast_continue":
			menu.get_node("MenuColumn/ContinueButton").pressed.emit()
			for frame: int in range(1200):
				await _settle(1)
				if current_scene != null and current_scene.scene_file_path == Cleanup.RUN_PATH: break
			_check(current_scene != null and current_scene.scene_file_path == Cleanup.RUN_PATH, "Immediate Continue must finish while the departed run is reclaimed")
			if current_scene != null and current_scene.scene_file_path == Cleanup.RUN_PATH:
				var resumed: Node = current_scene
				var expected: Dictionary = preload("res://scripts/run_engine.gd").new().repair_loaded_run_state(saved)
				for field: String in ["mode", "current_room", "current_room_layout", "rooms", "player_hp", "player_max_hp", "deck_cards", "equipped_equipment", "equipment_inventory", "magic_inventory", "item_inventory"]:
					_check(resumed._run_state.get(field) == expected.get(field), "Immediate Continue must preserve saved " + field)
				resumed.free()
				current_scene = null
		if interrupt and is_instance_valid(drain): drain.free()
		else:
			for frame: int in range(180):
				await _settle(1)
				if not is_instance_valid(drain): break
		_check(not is_instance_valid(drain), "Presented cleanup and interrupted cleanup must release their root owner")
		for id: int in _retired_ids:
			_check(not is_instance_id_valid(id), "Every node in the old run must be reclaimed, including queued deletes")
		_check((route == "fast_continue" or Profile.load_saved_run() == saved) and Profile.load_data() == progression, "Cleanup must preserve the full saved run and progression committed by Save and Quit")
		cases += 1
		if DisplayServer.get_name() != "headless" and route == "ordinary":
			await _settle_native_window()
			await RenderingServer.frame_post_draw
			_check(root.size == Vector2i(1920, 1080) and DisplayServer.window_get_size(root.get_window_id()) == Vector2i(1920, 1080) and is_equal_approx(root.content_scale_factor, 1.0), "The native title proof must be rendered at actual 1920x1080 and 100%")
			var image: Image = root.get_texture().get_image()
			if image.get_size() != Vector2i(1920, 1080): image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
			var path: String = ProjectSettings.globalize_path("user://departed_cleanup_title.png")
			image.save_png(path)
			print("DEPARTED CLEANUP IMAGE: " + path)
		if is_instance_valid(menu): menu.free()
		current_scene = null
		await _settle(4)
	Profile.clear_saved_run()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://departed_cleanup_profile.json"))
	Settings.clear_storage()
	_check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "Every completed/interrupted route must finish without orphan nodes")
	print("DEPARTED CLEANUP RESULT: " + JSON.stringify({"cases": cases, "errors": errors, "draining_at_menu": _draining_at_menu, "native": DisplayServer.get_name() != "headless", "orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}))
	quit(0 if errors.is_empty() else 1)

func _capture_ids(node: Node) -> void:
	_retired_ids.append(node.get_instance_id())
	for child: Node in node.get_children(true): _capture_ids(child)

func _check_external_receivers() -> void:
	var sources: Array[Object]
	sources.append(self)
	sources.append(root)
	sources.append(RenderingServer)
	for node: Node in root.get_children(): sources.append(node)
	for source: Object in sources:
		for entry: Dictionary in source.get_signal_list():
			for connection: Dictionary in source.get_signal_connection_list(entry["name"]):
				var target: Object = (connection["callable"] as Callable).get_object()
				if is_instance_valid(target): _check(not _retired_ids.has(target.get_instance_id()), "Departed controls must not retain callbacks from live global objects")

func _settle(frames: int) -> void:
	for frame: int in range(frames):
		await process_frame
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func _settle_native_window() -> void:
	var stable: int = 0
	var deadline: int = Time.get_ticks_msec() + 5000
	while stable < 20 and Time.get_ticks_msec() < deadline:
		if root.mode != Window.MODE_WINDOWED or root.size != Vector2i(1920, 1080) or DisplayServer.window_get_size(root.get_window_id()) != Vector2i(1920, 1080):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			root.mode = Window.MODE_WINDOWED
			root.size = Vector2i(1920, 1080)
			DisplayServer.window_set_size(Vector2i(1920, 1080))
			stable = 0
		else: stable += 1
		await create_timer(0.05).timeout
	_check(stable == 20, "Native title geometry must settle before its screenshot")

func _check(condition: bool, message: String) -> void:
	if not condition and not errors.has(message): errors.append(message)
