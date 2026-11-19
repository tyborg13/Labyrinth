extends SceneTree
## Directed perf-144 regressions. Use review_proof.py for isolated subprocesses.

const Assets = preload("res://scripts/asset_loader.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const InitialGraph = preload("res://scripts/initial_run_graph.gd")
const SceneLoads = preload("res://scripts/menu_run_preload.gd")
const Run = preload("res://scripts/run_engine.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Surface = preload("res://scripts/ui_component_surface.gd")
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const SAVE_PATH := "user://perf-144-review-run.save"
const SCENE_PATH := "res://scenes/run_scene.tscn"
const HELD_SCENE_PATH := "res://scenes/run_scene.held"
const SOCKET_PATH := "res://assets/art/ui/visual_pass_4/medallion_ring.png"
const SOCKET_SIZE := Vector2i(32, 32)
const SAVED_SEED := 144
const FIRST_SEED := 145
const LATE_SEED := 146
const TITLE_IDLE_USEC := 1250000
const CLOCK_LEAD_SECONDS := 8
const PROBE_TIMEOUT_SECONDS := 35.0
const FRAME_LIMIT := 120
const SLOW_LOAD_MSEC := 1500
const SETTINGS_SAMPLE_USEC := 180000
const RELEASE_LONGEST_USEC := 342671
const QUIT_FRAME_USEC := 16667

class SlowSceneLoader extends ResourceFormatLoader:
	var entered := Semaphore.new()

	func _recognize_path(path: String, _type: StringName) -> bool:
		return path == SCENE_PATH

	func _load(_path: String, _original: String, _threads: bool, _cache: int) -> Variant:
		entered.post()
		OS.delay_msec(SLOW_LOAD_MSEC)
		# The built-in loader still loads the original scene after the delay.
		return ERR_UNAVAILABLE

var _case := ""
var _capture_dir := ""
var _deadline: int
var _loader: SlowSceneLoader
var _run_scene_script: Script
var _quit_sent_usec: int
var _quit_previous_usec: int
var _quit_frames: int
var _quit_max_frame_usec: int

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): _case = arg.trim_prefix("--case=")
		elif arg.begins_with("--capture-dir="): _capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()

func _run() -> void:
	_deadline = Time.get_ticks_usec() + int(PROBE_TIMEOUT_SECONDS * 1000000)
	root.size = VIEWPORT_SIZE
	Engine.max_fps = FRAME_LIMIT
	OS.low_processor_usage_mode = false
	Store.set_storage_path("user://perf-144-review-profile.json")
	Store.set_run_storage_path(SAVE_PATH)
	Settings.set_storage_path("user://perf-144-review-settings.json")
	Analytics.set_storage_dir("user://perf-144-review-analytics")
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = "windowed"
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	if not Settings.save_settings(settings) or not Store.save_data(Store.default_data()):
		_fail("could not write isolated profile")
		return
	# The save and retry cases control graph and resource timing independently
	# of bulk RunScene script compilation. Settings and Quit remain cold.
	if _case in ["close", "debug-seed", "resume-seed", "retry"]:
		_run_scene_script = load("res://scripts/run_scene.gd")
	match _case:
		"close": await _graph_wait(true)
		"debug-seed": await _graph_wait(false)
		"resume-seed": await _resume_seed()
		"retry": await _failed_scene()
		"socket": await _socket()
		"settings": await _cold_settings()
		"quit": await _early_quit()
		_: _fail("unknown case")

func _graph_wait(close: bool) -> void:
	if close and not _write_save(SAVED_SEED): return
	root.set_meta(InitialGraph.SEED_OVERRIDE, FIRST_SEED)
	var menu := _open_title()
	menu.start_button.pressed.emit()
	if close: menu.replacement_confirm_button.pressed.emit()
	var cover := root.get_node("MenuRunTransition")
	if not await _until(func() -> bool: return is_instance_valid(cover.destination), "staging destination"): return
	var run: Node = cover.destination
	var held := InitialGraph.Preparation.new()
	held.seed = FIRST_SEED
	held.depth = 0
	run.adopt_initial_run_graph(held)
	if not await _until(func() -> bool: return run._defer_initial_run_presentation and run._initial_run_graph == held, "entering final graph wait"): return
	if not held.pending or not run._run_state.is_empty():
		_fail("fixture missed the final graph wait")
		return
	if close:
		print("PERF144 SAVE ", ProjectSettings.globalize_path(SAVE_PATH), " ", FileAccess.get_sha256(SAVE_PATH))
		_send_native_close()
		print("PERF144 CLOSE graph_cancelled=", held.cancellation.is_cancelled(), " before_commit=", run._run_state.is_empty())
		return
	root.set_meta(InitialGraph.SEED_OVERRIDE, LATE_SEED)
	if not await _until(_run_is_ready, "revealing changed debug seed"): return
	var saved: Dictionary = Store.load_saved_run()
	var started_seed: int = -1
	for event: Dictionary in Analytics.load_all_events():
		if event.get("event_type") == "run_started": started_seed = int(event.get("payload", {}).get("seed", -1))
	var expected: Dictionary = _generate_graph(LATE_SEED)
	var graph_matches: bool = saved.get("map_sections") == expected.get("map_sections") and saved.get("map_sections") == run._run_state.get("map_sections")
	var details: String = "live=%s saved=%s analytics=%s graph_matches=%s" % [run._run_state.get("seed"), saved.get("seed"), started_seed, graph_matches]
	if run._run_state.get("seed") != LATE_SEED or saved.get("seed") != LATE_SEED or started_seed != LATE_SEED or not graph_matches:
		_fail(details)
		return
	_pass(details)

func _resume_seed() -> void:
	var matching_second: int = int(Time.get_unix_time_from_system()) + CLOCK_LEAD_SECONDS
	var old_seed: int = matching_second & InitialGraph.SEED_MASK
	if not _write_save(old_seed): return
	var menu := _open_title()
	menu.continue_button.pressed.emit()
	if not await _until(_run_is_ready, "continuing saved run"): return
	if current_scene._run_state.get("seed") != old_seed:
		_fail("Continue did not restore the fixture seed")
		return
	current_scene._on_abandon_run_pressed()
	if not await _until(func() -> bool: return current_scene != null and current_scene.has_node("MenuColumn"), "returning to title"): return
	if Store.has_saved_run():
		_fail("Abandon did not clear the saved run")
		return
	menu = current_scene
	if not await _until(func() -> bool: return int(Time.get_unix_time_from_system()) >= matching_second, "matching the abandoned seed's clock second"): return
	if int(Time.get_unix_time_from_system()) != matching_second:
		_fail("clock-match fixture missed its second")
		return
	menu.start_button.pressed.emit()
	var cover := root.get_node_or_null("MenuRunTransition")
	if cover == null:
		_fail("New Run did not create a loading cover")
		return
	var pressed_seed: int = cover._press_seed
	if not await _until(_run_is_ready, "creating a new run after abandon"): return
	var saved_seed: int = Store.load_saved_run().get("seed", -1)
	if pressed_seed == old_seed or saved_seed != pressed_seed:
		_fail("resumed=%d pressed=%d saved=%d" % [old_seed, pressed_seed, saved_seed])
		return
	_pass("resumed=%d pressed=%d saved=%d" % [old_seed, pressed_seed, saved_seed])

func _failed_scene() -> void:
	if FileAccess.file_exists(SCENE_PATH) or not FileAccess.file_exists(HELD_SCENE_PATH):
		_fail("retry requires a staged project with the run scene held aside")
		return
	var menu := _open_title()
	menu.start_button.pressed.emit()
	if not await _until(func() -> bool: return is_instance_valid(menu._loading_error) and menu._loading_error.visible, "observing failed request"): return
	var recovered := DirAccess.rename_absolute(ProjectSettings.globalize_path(HELD_SCENE_PATH), ProjectSettings.globalize_path(SCENE_PATH))
	if recovered != OK:
		_fail("could not restore run scene after load failure")
		return
	menu._loading_error.hide()
	var dialog: WeakRef = weakref(menu._loading_error)
	menu.start_button.pressed.emit()
	if not await _until(func() -> bool:
		var error_window: Window = dialog.get_ref()
		return _run_is_ready() or (error_window != null and error_window.visible)
	, "retrying scene load"): return
	if not _run_is_ready():
		_fail("retry reused the failed scene request")
		return
	_pass("failed scene request recovered on retry")

func _socket() -> void:
	var source := Image.create(SOCKET_SIZE.x, SOCKET_SIZE.y, false, Image.FORMAT_RGBA8)
	Assets._texture_cache[SOCKET_PATH] = ImageTexture.create_from_image(source)
	var stored: Image = Assets._texture_cache[SOCKET_PATH].get_image()
	if not is_same(stored, Assets._texture_cache[SOCKET_PATH].get_image()):
		_fail("socket fixture requires headless shared texture readback")
		return
	var before: PackedByteArray = stored.get_data()
	await Surface.prepare_initial_assets_for(root, _present, func() -> bool: return true)
	if stored.has_mipmaps() or before != stored.get_data() or not Surface._mipmapped_textures[SOCKET_PATH].get_image().has_mipmaps():
		_fail("worker changed the cached source or failed to produce mipmaps")
		return
	_pass("cached image unchanged and published ring mipmapped")

func _cold_settings() -> void:
	_install_slow_loader()
	root.gui_disable_input = true
	var menu := _open_title()
	var threshold := Time.get_ticks_usec() + TITLE_IDLE_USEC
	if not await _until(func() -> bool: return Time.get_ticks_usec() >= threshold, "crossing the idle threshold while locked"): return
	if _scene_load_requested() or _loader.entered.try_wait():
		_fail("Run-scene request started before the title accepted input")
		return
	root.gui_disable_input = false
	var input_usec := Time.get_ticks_usec()
	root.push_input(InputEventMouseMotion.new(), true)
	menu.settings_button.pressed.emit()
	await _present()
	if _scene_load_requested():
		_fail("Title input did not restart the release idle threshold")
		return
	if not await _until(_loader.entered.try_wait, "starting the idle scene request in Settings"): return
	if Time.get_ticks_usec() - input_usec < int(SceneLoads.IDLE_SECONDS * 1000000):
		_fail("Idle scene request bypassed the input reset")
		return
	var previous := Time.get_ticks_usec()
	var end: int = previous + SETTINGS_SAMPLE_USEC
	var longest: int = 0
	while previous < end:
		await _present()
		var now := Time.get_ticks_usec()
		longest = maxi(longest, now - previous)
		previous = now
	var scene_only := _scene_load_requested() and not root.has_node("InitialRunGraphDrain") and not root.has_node("OpeningDialoguePaintDrain")
	var details := "idle_scene_only=%s settings=%s longest_usec=%d release_usec=%d" % [scene_only, menu.settings_panel.visible, longest, RELEASE_LONGEST_USEC]
	if not scene_only or not menu.settings_panel.visible or longest > RELEASE_LONGEST_USEC:
		_fail(details)
		return
	if not _capture_dir.is_empty():
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(_capture_dir)
		var path := _capture_dir.path_join("cold_settings.png")
		if root.get_texture().get_image().save_png(path) != OK:
			_fail("could not capture Settings")
			return
		print(path)
	menu.settings_back_button.pressed.emit()
	if not await _until(func() -> bool:
		return SceneLoads.status_for(self, SCENE_PATH) != ResourceLoader.THREAD_LOAD_IN_PROGRESS
	, "finishing the injected idle request"): return
	_pass(details)

func _scene_load_requested() -> bool:
	return SceneLoads.status_for(self, SCENE_PATH) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE

func _early_quit() -> void:
	_open_title()
	await _present()
	if ResourceLoader.load_threaded_get_status(SCENE_PATH) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_fail("Title quit has a speculative run-scene request")
		return
	_quit_sent_usec = Time.get_ticks_usec()
	_quit_previous_usec = _quit_sent_usec
	process_frame.connect(_track_quit_frame)
	print("PERF144 EARLY_QUIT requested_usec=", _quit_sent_usec)
	current_scene.quit_button.pressed.emit()
	print("PERF144 EARLY_QUIT handler_usec=", Time.get_ticks_usec() - _quit_sent_usec)

func _track_quit_frame() -> void:
	var now := Time.get_ticks_usec()
	_quit_max_frame_usec = maxi(_quit_max_frame_usec, now - _quit_previous_usec)
	_quit_previous_usec = now
	_quit_frames += 1

func _finalize() -> void:
	if _quit_sent_usec > 0:
		print("PERF144 EXIT frames=%d longest_usec=%d elapsed_usec=%d frame_budget_usec=%d" % [_quit_frames, _quit_max_frame_usec, Time.get_ticks_usec() - _quit_sent_usec, QUIT_FRAME_USEC])

func _install_slow_loader() -> void:
	_loader = SlowSceneLoader.new()
	ResourceLoader.add_resource_format_loader(_loader, true)

func _send_native_close() -> void:
	root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	root.close_requested.emit()

func _open_title() -> Control:
	var menu: Control = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	menu.get_node("MusicPlayer").stop()
	current_scene = menu
	return menu

func _write_save(seed: int) -> bool:
	if Store.save_run_state(Run.new().create_new_run(seed, Store.default_data())): return true
	_fail("could not write previous run")
	return false

func _generate_graph(seed: int) -> Dictionary:
	var state: Dictionary = {"seed": seed}
	Graph.initialize_prepared(state, Graph.generation_inputs(0), func() -> bool: return false)
	state.erase("seed")
	return state

func _run_is_ready() -> bool:
	return current_scene != null and current_scene.has_method("initial_presentation_is_ready") and not root.gui_disable_input

func _until(condition: Callable, label: String) -> bool:
	while not bool(condition.call()):
		if Time.get_ticks_usec() >= _deadline:
			_fail("timed out " + label)
			return false
		await process_frame
	return true

func _present() -> void:
	if DisplayServer.get_name() == "headless": await process_frame
	else: await RenderingServer.frame_post_draw

func _pass(details: String) -> void:
	print("PERF144 %s: PASS %s" % [_case, details])
	if current_scene != null and current_scene.has_node("MenuColumn"):
		current_scene.quit_button.pressed.emit()
	else:
		quit()

func _fail(details: String) -> void:
	print("PERF144 %s: FAIL %s" % [_case, details])
	quit(1)
