extends SceneTree
## Actual controller events drive the demo from startup to its first fight.

const Route = preload("res://tools/hitch_census/demo/route.gd")
const InputGate = preload("res://tools/hitch_census/demo/input_gate.gd")
const Gate = preload("res://tools/hitch_census/demo/gate.gd")
const Guide = preload("res://scripts/contextual_combat_tutorial.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Recent = preload("res://scripts/recent_event_store.gd")
const Observer = preload("canvas_observer.gd")
const Receipts = preload("receipts.gd")
const CacheSwitch = preload("res://tests/helpers/steam_cache_switch_fixture.gd")
const SIZE := Vector2i(1920, 1080)
const SEED := 7
const TITLE_IDLE_SECONDS := 4.0
const ROUTE_TIMEOUT_SECONDS := 120.0
const ACTION_FRAMES := 12
const SETTLE_FRAMES := 12
const WARMER := "CanvasPipelinePrewarm"
const WARMED_META := &"labyrinth_warmed_canvas_pipelines"

var host: SceneTree:
	get: return self
var output: String
var demo_board_proof := ""
var failure := ""
var _mode := ""
var _headless: bool
var _observer: RefCounted
var _route: RefCounted
var _gate: Node
var _armed := ""
var _armed_pressed := true
var _marks: Dictionary
var _input_edges: Dictionary
var _receipts: Dictionary
var _warm_windows: Dictionary
var _warm_ids: Dictionary
var _warm_count_by_stage: Dictionary
var _stage := "startup"
var _resume_room: Vector2i
var _cache_switch: Dictionary
var _idle_cache_files: Dictionary
var _backing_size: Vector2i

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg.begins_with("--mode="): _mode = arg.trim_prefix("--mode=")
		else: failure = "Unknown argument " + arg
	_headless = DisplayServer.get_name() == "headless"
	_run.call_deferred()

func _run() -> void:
	if not failure.is_empty() or output.is_empty() or (_headless and _mode != "headless") or (_mode not in ["headless", "timing", "attribution", "pixels", "cache"]):
		fail("Expected --output and --mode=headless|timing|attribution|pixels|cache. " + failure)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		fail("Cannot create proof directory")
		return
	create_timer(ROUTE_TIMEOUT_SECONDS).timeout.connect(func() -> void: fail("Route timeout at " + _stage))
	if _mode == "cache": _cache_switch = CacheSwitch.switch_user_directory()
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = "windowed"
	settings["ui_scale"] = 1.0
	settings["edge_smoothing"] = "off"
	settings["reduced_motion"] = _mode in ["pixels", "headless"]
	Settings.set_storage_path("user://perf-165-settings.json")
	Store.set_storage_path("user://perf-165-profile.json")
	Store.set_run_storage_path("user://perf-165-run.save")
	Analytics.set_storage_dir("user://perf-165-analytics")
	Recent.set_storage_path("user://perf-165-recent.json")
	if not Settings.save_settings(settings) or not Store.save_data(Guide.complete_tutorial(Store.default_data())):
		fail("Cannot install isolated profile")
		return
	root.mode = Window.MODE_WINDOWED
	root.size = SIZE
	root.set_meta("labyrinth_performance_probe_seed", SEED)
	seed(SEED)
	OS.low_processor_usage_mode = false
	Engine.max_fps = 0
	Input.use_accumulated_input = false
	if not _headless: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	else: process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	_gate = InputGate.new()
	_gate.session = self
	root.add_child(_gate)
	_route = Route.new(self)
	if _mode in ["timing", "attribution", "cache"]:
		_observer = Observer.new()
		_observer.start(root, _mode != "timing")
	if _headless: node_added.connect(_track_warmer)
	if change_scene_to_file("res://scenes/startup.tscn") != OK:
		fail("Cannot load real startup")
		return
	if not await _title(false):
		if failure.is_empty(): fail("New Run title action did not start")
		return
	await _route.wait_ready()
	var run := current_scene
	if not _is_run(run): return
	_stage_as("opening")
	_receipts["new_run"] = Receipts.snapshot(self, run) if _headless else {}
	while bool(run.get("_dialogue_active")):
		var next: Control = _route.match_text(_route.controls(run.get("_dialogue_dialog")), ["continue", "next", "begin"])
		if next != null and not await _route.control(next): return
		if not await _route.pad.button(JOY_BUTTON_A): continue
		await _route.wait_ready()
	if not await _enter_first_fight(run):
		if failure.is_empty(): fail("Room controller input rejected")
		return
	_stage_as("first_fight")
	await _settle()
	if not _capture("first_fight"): return
	if _headless: _receipts["first_fight"] = Receipts.snapshot(self, run)
	if not await _first_actions(run):
		if failure.is_empty(): fail("Combat controller input rejected")
		return
	if _headless: _receipts["after_pass"] = Receipts.snapshot(self, run)
	if Store.read_resumable_checkpoint().is_empty():
		fail("No valid production checkpoint after Pass")
		return
	_stage_as("return_to_title")
	# Continue reloads the actual checkpoint left by the controller route.
	if not await _route.pad.button(JOY_BUTTON_START):
		fail("Run menu input rejected")
		return
	var menu: Control = run.get("_menu_scrim")
	var save: Control = _route.match_text(_route.controls(menu), ["save and quit"])
	if not await _route.control(save) or not await _route.pad.button(JOY_BUTTON_A):
		if failure.is_empty(): fail("Save and Quit input rejected")
		return
	await _route.wait_ready()
	if not await _title(true):
		if failure.is_empty(): fail("Continue title action did not start")
		return
	await _route.wait_ready()
	var resumed := current_scene
	if not _is_run(resumed): return
	_stage_as("resumed")
	await _settle()
	if resumed.get("_run_state").get("current_room") != _resume_room:
		fail("Continue restored a different room")
		return
	if _headless: _receipts["continue"] = Receipts.snapshot(self, resumed)
	if _gate.accepted != int(_route.inputs["joypad_button"]) + int(_route.inputs["joypad_motion"]):
		fail("Controller route did not deliver every scripted event")
		return
	_finish()

func _title(resume: bool) -> bool:
	await _route.wait_ready()
	var menu := current_scene
	if not failure.is_empty() or menu == null or not menu.scene_file_path.ends_with("main_menu.tscn"):
		fail("Expected the interactive title")
		return false
	_stage_as("title_continue_idle" if resume else "title_new_idle")
	# First enter controller mode through the game's input router.
	_route.pad.motion(JOY_AXIS_LEFT_Y, 0.65)
	await process_frame
	_route.pad.motion(JOY_AXIS_LEFT_Y, 0.0)
	if _mode == "cache" and not resume:
		_idle_cache_files["before"] = _cache_files("user://shader_cache")
	await hold(TITLE_IDLE_SECONDS)
	if _mode == "cache" and not resume:
		_idle_cache_files["after"] = _cache_files("user://shader_cache")
	var control: BaseButton = menu.get("continue_button") if resume else menu.get("start_button")
	if not await _route.control(control): return false
	await _settle()
	if not resume and not _headless:
		if _mode == "pixels":
			if not _capture("title"): return false
		else:
			# One readback before Joy.button's settle interval verifies the
			# native backing dimensions outside all timed action windows.
			var image := root.get_texture().get_image()
			if not _check_capture_size(image): return false
	_arm("title_continue_a" if resume else "title_new_a", control.action_mode == BaseButton.ACTION_MODE_BUTTON_PRESS)
	# Joy.button introduces its own settle and uses the production input path.
	if not await _route.pad.button(JOY_BUTTON_A):
		fail("Title A rejected by controller gate")
		return false
	if not is_instance_valid(menu) or root.gui_disable_input: return true
	return current_scene != menu

func _enter_first_fight(run: Node) -> bool:
	_stage_as("first_map")
	var scrim: Control = run.get("_large_map_scrim")
	if not scrim.visible and not await _route.pad.button(JOY_BUTTON_BACK): return false
	await _route.wait_ready()
	if not scrim.visible:
		fail("Controller Map did not open the section map")
		return false
	var map: Control = run.get("_large_map_view")
	var run_state: Dictionary = run.get("_run_state")
	var engine: RefCounted = run.get("_run_engine")
	for destination: Vector2i in map.call("available_destinations"):
		var room: Dictionary = engine.room_metadata(run_state, destination)
		if str(room.get("type")) not in ["combat", "guardian"]: continue
		var targets: Dictionary = map.get("node_buttons")
		var target: Control = targets.get(destination)
		if not await _route.control(target): return false
		_stage_as("room_travel")
		if not await _route.pad.button(JOY_BUTTON_A): return false
		await _route.wait_ready()
		if run.get("_run_state").get("current_room") != destination:
			fail("Controller did not enter the first fight room")
			return false
		if run.get("_run_state").get("mode") == "pre_battle":
			_stage_as("pre_battle")
			var overlay: Control = run.get("_pre_battle_scrim")
			var button: Control = _route.match_text(_route.controls(overlay), ["start", "begin", "fight", "enter"])
			if not await _route.control(button) or not await _route.pad.button(JOY_BUTTON_A): return false
			await _route.wait_ready()
		if run.get("_run_state").get("mode") == "combat": return true
	fail("No reachable first fight from the opening room")
	return false

func _first_actions(run: Node) -> bool:
	var battle: Dictionary = run.get("_combat_state")
	var engine: RefCounted = run.get("_combat_engine")
	var played_before: int = battle.get("cards_played_this_turn", 0)
	var hand_before: Array = (battle.get("deck", {}).get("hand", []) as Array).duplicate()
	if str(run.get("_controller_region")) != "hand":
		if not await _route.pad.button(JOY_BUTTON_X): return false
	if str(run.get("_controller_region")) != "hand":
		fail("Controller did not focus the opening hand")
		return false
	await _settle()
	_arm("combat_first_a")
	if not await _route.pad.button(JOY_BUTTON_A): return false
	await _action_frames("combat_first_a")
	_stage_as("combat_card_resolution")
	if int(run.get("_selected_card_index")) >= 0:
		_route.targets = []
		await _route.resolve_card()
	await _route.wait_ready()
	battle = run.get("_combat_state")
	if int(battle.get("cards_played_this_turn", 0)) <= played_before and battle.get("deck", {}).get("hand", []) == hand_before:
		fail("First card did not commit")
		return false
	var actor: Variant = battle.get("current_actor")
	var turn: int = battle.get("turn", 0)
	if not engine.is_player_turn(battle):
		fail("First card left no player turn for Pass")
		return false
	_stage_as("before_pass")
	_arm("combat_pass_y")
	if not await _route.pad.button(JOY_BUTTON_Y): return false
	await _action_frames("combat_pass_y")
	await _route.wait_ready()
	battle = run.get("_combat_state")
	if battle.get("turn", 0) == turn and battle.get("current_actor") == actor:
		fail("Controller Pass did not advance combat")
		return false
	_resume_room = run.get("_run_state").get("current_room")
	return true

func _is_run(scene: Node) -> bool:
	if scene != null and scene.get("_run_state") != null and not root.gui_disable_input: return true
	fail("Title A did not hand off to a playable run")
	return false

func _stage_as(value: String) -> void:
	_stage = value
	if _headless: print("PERF165 STAGE: ", value)
	if _observer != null: _observer.stage = value

func _arm(label: String, pressed: bool = true) -> void:
	_armed = label
	_armed_pressed = pressed

func log_event(kind: String, data: Dictionary = {}) -> void:
	if kind != "input" or _armed.is_empty() or data.get("pressed", false) != _armed_pressed: return
	var label := _armed
	_armed = ""
	_marks[label] = Engine.get_process_frames()
	_input_edges[label] = "press" if _armed_pressed else "release"
	_stage_as(label)
	if label.begins_with("title_"): _verify_cover.call_deferred(label)

func _verify_cover(label: String) -> void:
	await RenderingServer.frame_post_draw
	if current_scene == null or str(current_scene.name) != "MenuRunTransition":
		fail("Expected loading cover on the first frame after " + label)
		return
	if label == "title_new_a": _capture("loading_cover")

func hold(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

func _settle() -> void:
	for frame: int in SETTLE_FRAMES: await RenderingServer.frame_post_draw

func _action_frames(label: String) -> void:
	while Engine.get_process_frames() < int(_marks[label]) + ACTION_FRAMES:
		await RenderingServer.frame_post_draw

func _capture(name: String) -> bool:
	if _mode != "pixels": return true
	var image := root.get_texture().get_image()
	if not _check_capture_size(image): return false
	var path := output.path_join(name + ".png")
	if image.save_png(path) != OK:
		fail("Failed to save " + path)
		return false
	print(path)
	return true

func _check_capture_size(image: Image) -> bool:
	_backing_size = image.get_size() if image != null else Vector2i.ZERO
	if _backing_size == SIZE and root.content_scale_factor == 1.0: return true
	fail("Expected 1920x1080 native pixels at 100%% UI scale, got %s at %.2f" % [_backing_size, root.content_scale_factor])
	return false

func _track_warmer(node: Node) -> void:
	if node.name != WARMER: return
	_warm_ids[node.get_instance_id()] = _stage
	_warm_windows[_stage] = int(_warm_windows.get(_stage, 0)) + 1
	node.tree_exited.connect(func() -> void: _warm_count_by_stage[_warm_ids[node.get_instance_id()]] = root.get_meta(WARMED_META, {}).size())

func _cache_files(path: String) -> PackedStringArray:
	var files := PackedStringArray()
	for name: String in DirAccess.get_files_at(path):
		if FileAccess.get_size(path.path_join(name)) > 0: files.append(path.path_join(name).trim_prefix("user://"))
	for folder: String in DirAccess.get_directories_at(path): files.append_array(_cache_files(path.path_join(folder)))
	return files

func _finish() -> void:
	var result := {"mode": _mode, "seed": SEED, "cel_look": OS.get_environment("LABYRINTH_CEL_LOOK"),
		"user_dir": ProjectSettings.globalize_path("user://"), "viewport": str(root.size), "backing_size": str(_backing_size),
		"renderer": RenderingServer.get_current_rendering_driver_name(), "method": RenderingServer.get_current_rendering_method(),
		"gpu": RenderingServer.get_video_adapter_name(), "api": RenderingServer.get_video_adapter_api_version(),
		"cpu": OS.get_processor_name(), "godot": Engine.get_version_info()["string"],
		"ui_scale": root.content_scale_factor, "edge_smoothing": Settings.load_settings()["edge_smoothing"],
		"marks": _marks, "input_edges": _input_edges, "action_frames": ACTION_FRAMES, "warm_windows": _warm_windows,
		"completed_warm_recipes": _warm_count_by_stage, "inputs": _route.inputs}
	if _mode == "cache":
		result["cache_switch"] = _cache_switch
		result["idle_cache_files"] = _idle_cache_files
	if _headless:
		for id: int in _warm_ids:
			if is_instance_id_valid(id):
				fail("An offscreen prewarm owner survived its window")
				return
		FileAccess.open(output.path_join("receipts.var"), FileAccess.WRITE).store_var(_receipts)
	if _observer != null:
		_observer.stop()
		var trace := FileAccess.open(output.path_join("frames.jsonl"), FileAccess.WRITE)
		for row: Dictionary in _observer.frames: trace.store_line(JSON.stringify(row))
	FileAccess.open(output.path_join("probe.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t") + "\n")
	print("PERF165 ROUTE: PASS mode=%s output=%s" % [_mode, output])
	preload("res://scripts/application_shutdown.gd").request(self, "perf165_probe")

func fail(message: String) -> void:
	if failure.is_empty(): failure = message
	push_error("PERF165 ROUTE: " + message)
	quit(1)
