extends SceneTree
## Run once for timing and separately with --capture for renderer readback.

const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Recent = preload("res://scripts/recent_event_store.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const SEED := 7
const TITLE_IDLE_SECONDS := 4.0
const RUN_SCENE_PATH := "res://scenes/run_scene.tscn"
const REQUESTS_META := &"labyrinth_threaded_loads"
const TIMEOUT_SECONDS := 120.0
const FRAME_LIMIT := 60
const MAP_KEY := KEY_M
const MIXER_DRAIN_UPDATES := 2
const MIXER_DRAIN_TIMEOUT_USEC := 1000000

var _output: String
var _capture := false
var _headless := false
var _title_idle_seconds := TITLE_IDLE_SECONDS
var _destination: Node
var _transition: Node
var _telemetry: Node
var _transition_profile: Dictionary
var _wait_property: bool
var _opening_action: String
var _started: int
var _previous: int
var _samples: Array[Dictionary]
var _landmarks: Dictionary
var _error := ""
var _interactive_title_usec: int
var _require_cold_title: bool
var _require_release_idle: bool

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): _output = arg.trim_prefix("--output=")
		elif arg.begins_with("--title-idle="): _title_idle_seconds = float(arg.trim_prefix("--title-idle="))
		elif arg == "--capture": _capture = true
		elif arg == "--require-cold-title": _require_cold_title = true
		elif arg == "--require-release-idle": _require_release_idle = true
		else: _error = "Unknown argument: " + arg
	_headless = DisplayServer.get_name() == "headless"
	_run.call_deferred()

func _run() -> void:
	if not _error.is_empty() or _output.is_empty() or (_capture and _headless):
		_fail("Provide --output and use a renderer for --capture. " + _error)
		return
	if DirAccess.make_dir_recursive_absolute(_output) != OK:
		_fail("Could not create output directory.")
		return
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = "windowed"
	settings["ui_scale"] = 1.0
	Settings.set_storage_path("user://perf-142-settings.json")
	Store.set_storage_path("user://perf-142-progression.json")
	Store.set_run_storage_path("user://perf-142-run.save")
	Analytics.set_storage_dir("user://perf-142-analytics")
	Recent.set_storage_path("user://perf-142-recent.json")
	if not Settings.save_settings(settings) or not Store.save_data(Store.default_data()):
		_fail("Could not write isolated fixture.")
		return
	root.mode = Window.MODE_WINDOWED
	root.size = VIEWPORT_SIZE
	root.set_meta("labyrinth_performance_probe_seed", SEED)
	OS.low_processor_usage_mode = false
	Engine.max_fps = FRAME_LIMIT if _capture else 0
	if not _headless and not _capture:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_telemetry = root.get_node("PerformanceTelemetry")
	change_scene_to_file("res://scenes/startup.tscn")
	while root.get_node_or_null("Startup") != null or current_scene == null or root.gui_disable_input:
		await _frame()
	_interactive_title_usec = Time.get_ticks_usec()
	if _require_release_idle and (_has_run_request() or ResourceLoader.has_cached(RUN_SCENE_PATH)):
		_fail("Run scene was requested before the interactive title.")
		return
	# Capture the title at its settled anchor. Capture mode is a distinct run.
	var menu: Node = current_scene
	var start: Button = menu.get_node("MenuColumn/StartButton")
	var idle_until := Time.get_ticks_usec() + int(_title_idle_seconds * 1000000.0)
	while Time.get_ticks_usec() < idle_until: await _frame()
	if not _screenshot("title"): return
	await _frame()
	if _require_cold_title and (
		ResourceLoader.has_cached("res://scenes/run_scene.tscn")
		or ResourceLoader.has_cached("res://scripts/run_scene.gd")
		or ResourceLoader.load_threaded_get_status("res://scenes/run_scene.tscn") != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
		or root.has_node("InitialRunGraphDrain") or root.has_node("OpeningDialoguePaintDrain")
	):
		_fail("Title acquired a speculative New Run resource or producer.")
		return
	var idle_graph: Dictionary = _idle_graph_receipt(menu)
	var idle_scene_requested := _has_run_request()
	if _require_release_idle and (
		not idle_scene_requested or not idle_graph.is_empty()
		or root.has_node("InitialRunGraphDrain") or root.has_node("OpeningDialoguePaintDrain")
		or root.has_node("InitialRunCpuAssets") or root.has_node("LoadingAudioPreparation")
	):
		_fail("Expected only the release run-scene request during title idle.")
		return
	_telemetry.take_hitch_phases()
	_telemetry.take_hitch_events()
	_started = Time.get_ticks_usec()
	_previous = _started
	_click(start)
	_transition = root.get_node_or_null("MenuRunTransition")
	if _transition == null or not root.gui_disable_input:
		_fail("New Run did not enter the loading transition.")
		return
	_wait_property = "hitch_wait" in _transition
	_transition.phase_changed.connect(func(phase: StringName) -> void: _mark(str(phase)))
	_transition.finished.connect(func(destination: Node) -> void:
		_destination = destination
		_transition_profile = _transition.performance_snapshot()
	)
	_mark("loading")
	await _frame()
	_sample("loading")
	if not _screenshot("transition"): return
	while not is_instance_valid(_destination):
		if not _in_time(): return
		await _frame()
		_sample("transition")
	if current_scene != _destination or root.gui_disable_input or not _destination.initial_presentation_is_ready():
		_fail("Transition completed without a playable destination.")
		return
	_mark("first_interactive_frame")
	var entry := _receipt()
	var dialogue: Control = _destination._dialogue_overlay
	var opening_paint: Dictionary = {
		"band": dialogue._band.texture, "bust": dialogue.portrait.texture,
		"halo": dialogue._hood_halo.texture, "rim": dialogue._portrait_rim.texture,
		"shadow": dialogue._portrait_shadow.texture,
	}
	if not _screenshot("first_interactive"): return
	# Release starts with narration. Route normal clicks through the visible
	# dialogue to reach the first map, keeping its timings separate from reveal.
	while not _map_visible():
		if not _in_time(): return
		if _destination._dialogue_active:
			_opening_action = "opening_dialogue_click"
			_click(_destination._dialogue_dialog)
		elif _destination._map_shortcut_can_open():
			_opening_action = "map_shortcut"
			_open_map()
		await _frame()
		_sample("opening_to_map")
	_mark("first_map_frame")
	if _destination._large_map_view.available_destinations().is_empty():
		_fail("First map has no interactive destinations.")
		return
	if not _screenshot("first_map"): return
	entry["opening_paint"] = _paint_receipt(opening_paint)
	var receipt := {"entry": entry, "first_map": _receipt()}
	if _capture:
		# The map accepts input under the release crossfade. Keep both its
		# first interactive draw and the first draw with the map fully visible.
		while _destination.get_node_or_null("ScreenCrossfade") != null:
			if not _in_time(): return
			await _frame()
		if not _screenshot("map_after_crossfade"): return
	var result := {"headless": _headless, "seed": SEED, "title_idle_seconds": _title_idle_seconds,
		"interactive_title_usec": _interactive_title_usec,
		"idle_scene_requested": idle_scene_requested,
		"idle_graph": idle_graph,
		"viewport": str(root.size), "ui_scale": root.content_scale_factor,
		"renderer": RenderingServer.get_current_rendering_driver_name(), "godot": Engine.get_version_info(),
		"demo": receipt["entry"]["state"].get("build_kind") == "demo",
		"capture": _capture, "landmarks": _landmarks, "transition": _transition_profile,
		"frames": _samples, "receipt": receipt}
	FileAccess.open(_output.path_join("probe.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t") + "\n")
	_destination.process_mode = Node.PROCESS_MODE_DISABLED
	_stop_voices(root)
	await _drain_mixer()
	_destination.queue_free()
	await process_frame
	print("PERF142 PROBE: PASS ", _output.path_join("probe.json"))
	quit()

func _idle_graph_receipt(menu: Node) -> Dictionary:
	var watch: Node = menu.get_node_or_null("RunSceneIdlePreload")
	if watch == null or not "graph" in watch or watch.graph == null: return {}
	return {"seed": watch.graph.seed, "depth": watch.graph.depth,
		"ready": not watch.graph.pending and not watch.graph.graph.is_empty()}

func _has_run_request() -> bool:
	if not root.has_meta(REQUESTS_META): return false
	var pending: Dictionary = root.get_meta(REQUESTS_META)
	return pending.has(RUN_SCENE_PATH)

func _stop_voices(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D: node.stop()
	for child: Node in node.get_children(): _stop_voices(child)

func _drain_mixer() -> void:
	var started: int = Time.get_ticks_usec()
	var last_mix: int = started - roundi(AudioServer.get_time_since_last_mix() * 1000000.0)
	var updates: int = 0
	while updates < MIXER_DRAIN_UPDATES and Time.get_ticks_usec() - started < MIXER_DRAIN_TIMEOUT_USEC:
		await process_frame
		var mix: int = Time.get_ticks_usec() - roundi(AudioServer.get_time_since_last_mix() * 1000000.0)
		if mix - last_mix >= 1000:
			last_mix = mix
			updates += 1

func _paint_receipt(textures: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for name: String in textures:
		var texture: Texture2D = textures[name]
		if texture == null: continue
		var image := texture.get_image()
		if image == null: continue
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(image.get_data())
		result[name] = {"size": str(image.get_size()), "sha256": hash.finish().hex_encode()}
	return result

func _frame() -> void:
	if _headless:
		await process_frame
	else:
		await RenderingServer.frame_post_draw

func _sample(stage: String) -> void:
	var now := Time.get_ticks_usec()
	var run: Node = current_scene if is_instance_valid(_destination) else null
	if run == null and is_instance_valid(_transition): run = _transition.destination
	var phases: Dictionary = _telemetry.take_hitch_phases()
	if is_instance_valid(run):
		var expected_frame := Engine.get_process_frames() - int(_headless)
		if run._runtime_performance_frame_id == expected_frame:
			phases.merge(run._runtime_performance_frame_phase_usec)
	var events: Dictionary = _telemetry.take_hitch_events()
	events = events.keys().filter(func(key: String) -> bool: return key.begins_with("load:")).reduce(
		func(loads: Dictionary, key: String) -> Dictionary:
			loads[key.trim_prefix("load:")] = events[key]
			return loads,
		{})
	_samples.append({"frame": Engine.get_process_frames(), "started_usec": _previous,
		"finished_usec": now, "ms": (now - _previous) / 1000.0,
		"stage": stage,
		"waiting_for": _opening_action if stage == "opening_to_map" else str(_transition.hitch_wait) if _wait_property and is_instance_valid(_transition) else "",
		"focused": not _headless and DisplayServer.window_is_focused(),
		"phases_usec": phases, "loads": events})
	_previous = now

func _mark(key: String) -> void:
	_landmarks[key] = {"frame": Engine.get_process_frames(), "ms": (Time.get_ticks_usec() - _started) / 1000.0}

func _click(target: Control) -> void:
	var position := target.get_global_transform_with_canvas() * (target.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.global_position = position
		event.pressed = pressed
		root.push_input(event, true)

func _open_map() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = MAP_KEY
		event.physical_keycode = MAP_KEY
		event.pressed = pressed
		root.push_input(event, true)

func _map_visible() -> bool:
	return _destination._large_map_scrim.is_visible_in_tree() and not root.gui_disable_input

func _receipt() -> Dictionary:
	var state: Dictionary = _destination._run_state.duplicate(true)
	var saved := Store.load_saved_run()
	var map: Control = _destination._large_map_view
	var map_state: Dictionary = {}
	if _map_visible():
		map_state = {"viewed_section": map.viewed_section, "selected": map.selected_coord,
			"available": map.available_destinations(), "scroll_offset": map.scroll_offset()}
	return {"state": state, "saved": saved, "profile": Store.load_data(),
		"section": Graph.active_section(state), "room": state.get("current_room"),
		"map_visible": _map_visible(), "map": map_state, "dialogue_active": _destination._dialogue_active,
		"input_locked": root.gui_disable_input,
		"focus": str(root.gui_get_focus_owner().get_path()) if root.gui_get_focus_owner() != null else ""}

func _screenshot(stem: String) -> bool:
	if not _capture: return true
	var image := root.get_texture().get_image()
	if image.get_size() != VIEWPORT_SIZE:
		_fail("Unexpected capture size: " + str(image.get_size()))
		return false
	var path := _output.path_join(stem + ".png")
	if image.save_png(path) == OK:
		print(path)
		return true
	_fail("Could not save " + path)
	return false

func _in_time() -> bool:
	if Time.get_ticks_usec() - _started < int(TIMEOUT_SECONDS * 1000000.0): return true
	_fail("Timed out before the first interactive map.")
	return false

func _fail(message: String) -> void:
	push_error("PERF142 PROBE: " + message)
	quit(1)
