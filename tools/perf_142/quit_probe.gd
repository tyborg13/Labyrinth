extends SceneTree
## Dedicated quit timing and optional pre-request renderer captures.

const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Boons = preload("res://scripts/opening_boon_rules.gd")
const VIEWPORT := Vector2i(1920, 1080)
const RUN_SCENE := "res://scenes/run_scene.tscn"
const SAVE := "user://perf-145-quit-run.save"
const QUIT_META := &"labyrinth_application_shutdown"
const CASE_TIMEOUT_USEC := 30000000
const NATIVE_INPUT_TIMEOUT_USEC := 60000000
const CONTROL_LOADER_DELAY_MSEC := 1500
const STALLED_IO_MSEC := 12000
const STALLED_SCENE_MSEC := 4500
const PREVIOUS_SEED := 144
const SEED := 83
const FRAME_LIMIT := 120

class DelayedSceneLoader extends ResourceFormatLoader:
	var entered := Semaphore.new()
	var delay_msec: int = CONTROL_LOADER_DELAY_MSEC

	func _recognize_path(path: String, _type: StringName) -> bool:
		return path == RUN_SCENE

	func _load(_path: String, _original: String, _threads: bool, _cache: int) -> Variant:
		entered.post()
		OS.delay_msec(delay_msec)
		return ERR_UNAVAILABLE

var _case: String
var _output: String
var _capture: bool
var _native_input: bool
var _control: bool
var _title_idle_msec: int
var _deadline: int
var _requested_usec: int
var _last_frame: int
var _longest_frame_usec: int
var _hidden_usec: int = -1
var _frames: int
var _menu: Control
var _loader: DelayedSceneLoader

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--case="): _case = argument.trim_prefix("--case=")
		elif argument.begins_with("--output="): _output = argument.trim_prefix("--output=")
		elif argument == "--capture": _capture = true
		elif argument == "--native-input": _native_input = true
		elif argument == "--control": _control = true
		elif argument.begins_with("--title-idle-msec="): _title_idle_msec = argument.trim_prefix("--title-idle-msec=").to_int()
	_start.call_deferred()

func _start() -> void:
	_deadline = Time.get_ticks_usec() + CASE_TIMEOUT_USEC
	if _output.is_empty() or DirAccess.make_dir_recursive_absolute(_output) != OK:
		_fail("missing output directory")
		return
	Engine.max_fps = FRAME_LIMIT
	OS.low_processor_usage_mode = false
	Settings.set_storage_path("user://perf-145-quit-settings.json")
	Store.set_storage_path("user://perf-145-quit-profile.json")
	Store.set_run_storage_path(SAVE)
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = "windowed"
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = _case != "startup-fade"
	if not Settings.save_settings(settings):
		_fail("could not save settings")
		return
	root.mode = Window.MODE_WINDOWED
	root.size = VIEWPORT
	root.set_meta("labyrinth_performance_probe_seed", SEED)
	if _case == "startup-fade":
		change_scene_to_file("res://scenes/startup.tscn")
		if not await _until(func() -> bool:
			var startup := root.get_node_or_null("Startup")
			return startup != null and startup._fade_tween != null
		, "waiting for the active startup fade"): return
	elif _case in ["combat", "stalled-io"]:
		if not _open_combat(): return
	else:
		if _case in ["early-preload", "stalled-scene", "idle-scene-load"]:
			_loader = DelayedSceneLoader.new()
			if _case != "early-preload": _loader.delay_msec = STALLED_SCENE_MSEC
			ResourceLoader.add_resource_format_loader(_loader, true)
		if _case == "idle-scene-load" or (_case in ["early-preload", "mid-graph", "loading-cover", "stalled-scene"] and not _control):
			var previous: Dictionary = Run.new().create_new_run(PREVIOUS_SEED, Store.default_data())
			if not Store.save_run_state(previous):
				_fail("could not save the previous run")
				return
		_open_title()
		if not await _reach_title_phase(): return
	if _capture and not await _capture_frame(): return
	if _case == "stalled-io" and not await _stall_checkpoint(): return
	var loading: bool = current_scene.name == &"MenuRunTransition"
	var graph: bool = root.has_node("InitialRunGraphDrain")
	print("PERF145 QUIT phase=", _case, " graph=", graph, " cover=", loading,
		" threaded_scene=", ResourceLoader.load_threaded_get_status(RUN_SCENE) == ResourceLoader.THREAD_LOAD_IN_PROGRESS)
	process_frame.connect(_track_quit)
	if _native_input:
		_deadline = Time.get_ticks_usec() + NATIVE_INPUT_TIMEOUT_USEC
		print("PERF145 QUIT READY — close the native window now")
		await _until(func() -> bool: return _requested_usec > 0, "waiting for native close")
		return
	_record_request(Time.get_ticks_usec())
	if _case == "stalled-io":
		current_scene._on_exit_to_desktop_pressed()
	elif _case in ["title-idle", "idle-scene-load"] or (_control and _case == "early-preload"):
		_menu.quit_button.pressed.emit()
	else:
		root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		root.close_requested.emit()
		if auto_accept_quit: quit()
	_record_visibility()

func _stall_checkpoint() -> bool:
	var entered := Semaphore.new()
	var stall := func(stage: String) -> bool:
		if stage == "temporary_started":
			entered.post()
			OS.delay_msec(STALLED_IO_MSEC)
		return true
	var snapshot: Dictionary = current_scene._committed_run_state()
	Store._run_writer.submit_prepared(Store._prepare_run_state_at.bind(SAVE, snapshot, stall), true)
	if not await _until(func() -> bool:
		Store.poll_pending_run_saves()
		return entered.try_wait()
	, "waiting for the checkpoint after writing its temporary header"): return false
	print("PERF145 STALLED_IO temporary_started=true")
	return true

func _reach_title_phase() -> bool:
	if _case == "title-idle":
		await _present()
		var idle_until := Time.get_ticks_msec() + _title_idle_msec
		while Time.get_ticks_msec() < idle_until: await _present()
		return true
	if _control and _case == "early-preload":
		return await _until(_loader.entered.try_wait, "waiting for release title preload")
	if _case == "idle-scene-load":
		return await _until(_loader.entered.try_wait, "waiting for the title-idle scene request")
	_menu.start_button.pressed.emit()
	_menu.replacement_confirm_button.pressed.emit()
	match _case:
		"early-preload", "stalled-scene":
			return await _until(_loader.entered.try_wait, "waiting for covered threaded scene request")
		"mid-graph":
			return await _until(func() -> bool: return root.has_node("InitialRunGraphDrain"), "waiting for live graph worker")
		"loading-cover":
			return await _until(func() -> bool:
				var cover := root.get_node_or_null("MenuRunTransition")
				return cover != null and is_instance_valid(cover.destination) and cover.destination.get_parent() == null
			, "waiting for detached covered scene")
		_:
			_fail("unknown scenario")
			return false

func _open_title() -> void:
	_menu = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(_menu)
	current_scene = _menu

func _open_combat() -> bool:
	var profile: Dictionary = Store.default_data()
	profile["guided_combat_tutorial"] = {"version": 2, "status": "dismissed", "completed_steps": []}
	var engine := Run.new()
	var state: Dictionary = engine.create_new_run(SEED, profile)
	if Boons.pending(state): state = Boons.choose(engine, state, "")
	for coord: Vector2i in engine.available_moves(state):
		var candidate: Dictionary = engine.move_to_room(state.duplicate(true), coord)
		if str(candidate.get("mode", "")) == "combat":
			state = candidate
			break
	if state["mode"] != "combat" or not Store.save_data(state["progression"]) or not Store.save_run_state(state):
		_fail("could not create saved combat")
		return false
	root.set_meta("labyrinth_resume_saved_run", true)
	var scene: Node = (load(RUN_SCENE) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	scene._close_dialogue()
	return current_scene._run_state["mode"] == "combat"

func _record_request(ticks: int) -> void:
	_requested_usec = ticks
	_last_frame = ticks
	var unix_usec := roundi(Time.get_unix_time_from_system() * 1000000.0) - (Time.get_ticks_usec() - ticks)
	var stamp: Dictionary = {"pid": OS.get_process_id(), "unix_usec": unix_usec}
	if FileAccess.file_exists(SAVE):
		stamp["save_path"] = ProjectSettings.globalize_path(SAVE)
		stamp["save_sha256"] = FileAccess.get_sha256(SAVE)
	var path := _output.path_join("request.json")
	FileAccess.open(path + ".tmp", FileAccess.WRITE).store_string(JSON.stringify(stamp))
	DirAccess.rename_absolute(path + ".tmp", path)
	print("PERF145 QUIT_REQUEST pid=", stamp["pid"], " ticks_usec=", ticks)

func _track_quit() -> void:
	if _requested_usec == 0 and _native_input and root.has_meta(QUIT_META):
		var state: RefCounted = root.get_meta(QUIT_META)
		if state.requested_usec > 0: _record_request(state.requested_usec)
	if _requested_usec == 0: return
	var now := Time.get_ticks_usec()
	_longest_frame_usec = maxi(_longest_frame_usec, now - _last_frame)
	_last_frame = now
	_frames += 1
	_record_visibility()

func _record_visibility() -> void:
	if _hidden_usec < 0 and DisplayServer.get_name() != "headless" and root.mode == Window.MODE_MINIMIZED:
		_hidden_usec = Time.get_ticks_usec() - _requested_usec
		print("PERF145 WINDOW_MINIMIZED usec=", _hidden_usec)

func _finalize() -> void:
	if _requested_usec > 0:
		_record_visibility()
		print("PERF145 FINALIZE elapsed_usec=", Time.get_ticks_usec() - _requested_usec,
			" frames=", _frames, " longest_usec=", _longest_frame_usec, " hidden_usec=", _hidden_usec)

func _capture_frame() -> bool:
	if DisplayServer.get_name() == "headless":
		_fail("capture requires a renderer")
		return false
	await _present()
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("renderer delivered an empty frame")
		return false
	var path := _output.path_join("quit-" + _case + ".png")
	if image.save_png(path) != OK:
		_fail("could not save " + path)
		return false
	print(path)
	return true

func _present() -> void:
	if DisplayServer.get_name() == "headless": await process_frame
	else: await RenderingServer.frame_post_draw

func _until(condition: Callable, where: String) -> bool:
	while not bool(condition.call()):
		if Time.get_ticks_usec() >= _deadline:
			_fail(where)
			return false
		await process_frame
	return true

func _fail(message: String) -> void:
	push_error("PERF145 QUIT " + message)
	quit(1)
