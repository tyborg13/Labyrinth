extends SceneTree
## Exercise the production title and the first destination using viewport input.

const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Shutdown = preload("res://scripts/application_shutdown.gd")
const Transition = preload("res://scripts/menu_run_transition.gd")
const MapBackdrop = preload("res://scripts/large_map_backdrop.gd")
const Metrics = preload("reveal_metrics.gd")

const SIZE := Vector2i(1920, 1080)
const FPS := 60
const SEED := 15
const TIMEOUT_MS := 30_000
const TITLE_SETTLE_FRAMES := 3
const AUDIO_TAIL_MS := 750
const CHECKPOINT_FILES := ["run.save", "progression.json", "recent_events.json"]
const CHECKPOINTS := {
	# Action 65 of the descent replay resumes the save from checkpoint 63.
	"map": ["00063", "map"],
	"combat": ["00019", "combat"],
	"event": ["00067", "event_choices"],
	"new_game": ["", "dialogue"],
	"reduced": ["00063", "map"],
	"play_map": ["00068", "event_result"],
	"prebattle": ["00008", "prebattle"],
	"rest": ["00116", "campfire"],
	"shop": ["00223", "shop"],
	"treasure": ["00118", "treasure"],
	"section": ["", "section"],
}

var _output: String
var _checkpoints: String
var _selection: String
var _quit_point: String
var _map_input: String
var _native: bool
var _driver: RefCounted
var _screens: RefCounted
var _media_script: Script
var _recorder: AudioEffectRecord
var _before: Dictionary
var _stats: Dictionary
var _failed: int


func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() % 2 != 0:
		_fail("expected options with values")
		return
	for index: int in range(0, args.size(), 2):
		var value: String = args[index + 1]
		match args[index]:
			"--output-dir": _output = value
			"--checkpoints": _checkpoints = value
			"--case": _selection = value
			"--quit-at": _quit_point = value
			"--map-input": _map_input = value
			"--before": _before = JSON.parse_string(FileAccess.get_file_as_string(value))
			_:
				_fail("unknown option " + args[index])
				return
	if _output.is_empty() or _checkpoints.is_empty() or (not _selection.is_empty() and not CHECKPOINTS.has(_selection)):
		_fail("provide --output-dir, --checkpoints and optionally a known --case")
		return
	if not _quit_point.is_empty() and (_selection != "map" or _quit_point not in ["start", "mid"]):
		_fail("--quit-at start|mid requires --case map")
		return
	if not _map_input.is_empty() and (_selection != "map" or _map_input not in ["keyboard", "controller"]):
		_fail("--map-input keyboard|controller requires --case map")
		return
	_native = DisplayServer.get_name() != "headless"
	if _native and _selection.is_empty():
		_fail("select one case per native recording")
		return
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = SIZE
	root.size = SIZE
	Engine.max_fps = FPS
	OS.low_processor_usage_mode = false
	if not _native: process_frame.connect(_fake_draw.call_deferred)
	_run.call_deferred()


func _fake_draw() -> void:
	RenderingServer.frame_pre_draw.emit()
	RenderingServer.frame_post_draw.emit()


func _run() -> void:
	# The same probe runs against release via an absolute --script path. Resolve
	# the census helpers beside this script across both projects.
	var here: String = ProjectSettings.globalize_path(get_script().resource_path).get_base_dir()
	var census: String = here.path_join("../fel20").simplify_path()
	_driver = load(census.path_join("input_driver.gd")).new(root)
	_screens = load(census.path_join("screens.gd")).new(self, _driver)
	if _native:
		_media_script = load(census.path_join("media.gd"))
		_recorder = AudioEffectRecord.new()
		_recorder.format = AudioStreamWAV.FORMAT_16_BITS
		AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"), _recorder)
	var cases: Array = CHECKPOINTS.keys() if _selection.is_empty() else [_selection]
	for label: String in cases:
		if not await _run_case(label):
			return
	if not _native:
		var file := FileAccess.open(_output.path_join("metrics.json"), FileAccess.WRITE)
		if file == null:
			_fail("cannot write metrics.json")
			return
		file.store_string(JSON.stringify(_stats, "\t") + "\n")
		file.close()
	if _failed == 0: print("FEL29 PASS cases=%d" % cases.size())
	else: print("FEL29 FAIL cases=%d failed=%d" % [cases.size(), _failed])
	Shutdown.request(self, "fel29_probe", 0 if _failed == 0 else 1)


func _stage(label: String, path: String) -> bool:
	if DirAccess.dir_exists_absolute(path) or DirAccess.make_dir_recursive_absolute(path) != OK:
		return false
	var save: String = path.path_join("run.save")
	var profile: String = path.path_join("progression.json")
	Store.set_run_storage_path(save)
	Store.set_storage_path(profile)
	Settings.set_storage_path(path.path_join("settings.json"))
	preload("res://scripts/analytics_store.gd").set_storage_dir(path.path_join("analytics"))
	preload("res://scripts/recent_event_store.gd").set_storage_path(path.path_join("recent_events.json"))
	var checkpoint: String = CHECKPOINTS[label][0]
	if not checkpoint.is_empty():
		var source: String = _checkpoints.path_join(checkpoint)
		if not FileAccess.file_exists(source.path_join("run.save")): return false
		for name: String in CHECKPOINT_FILES:
			var file: String = source.path_join(name)
			if FileAccess.file_exists(file) and DirAccess.copy_absolute(file, path.path_join(name)) != OK:
				return false
	elif label == "section":
		var reward: Dictionary = preload("res://tests/suites/section_transition_suite.gd").fixture()
		var claimed: Dictionary = preload("res://scripts/run_engine.gd").new().continue_dragon_reward(reward)
		if not Store.save_run_state(claimed): return false
	var preferences: Dictionary = Settings.default_settings()
	preferences["ui_scale"] = 1.0
	preferences["reduced_motion"] = label == "reduced"
	preferences["display_mode"] = Settings.DISPLAY_WINDOWED
	root.set_meta("labyrinth_performance_probe_seed", SEED)
	return Settings.save_settings(preferences)


func _run_case(label: String) -> bool:
	var path: String = _output.path_join(label)
	if not _stage(label, path):
		return _fail("cannot stage fresh " + label + " profile in " + path)
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for frame: int in range(TITLE_SETTLE_FRAMES): await RenderingServer.frame_post_draw
	var button: Button = menu.start_button if label == "new_game" else menu.continue_button
	var input: Dictionary = _driver.control(button)
	if input.is_empty(): return _fail("%s title action unavailable" % label)
	if _map_input.is_empty():
		_driver.prepare(input)
	elif not button.has_focus():
		if _map_input == "keyboard": _driver.send(_driver.key(KEY_TAB))
		else: _send_joy_button(JOY_BUTTON_A)
		if not button.has_focus(): return _fail("the navigation input did not focus Continue")
	await RenderingServer.frame_post_draw

	var media: RefCounted
	if _native:
		media = _media_script.new()
		if not media.begin(_output, 1, root, _recorder):
			media.discard()
			return _fail(media.problem)
	var started: int = Time.get_ticks_usec()
	match _map_input:
		"keyboard": _driver.send(_driver.key(KEY_ENTER))
		"controller": _send_joy_button(JOY_BUTTON_A)
		_: _driver.send(input)
	var cover: CanvasLayer = root.get_node_or_null("MenuRunTransition") as CanvasLayer
	if cover == null:
		if media != null: media.discard()
		return _fail("%s viewport press did not start loading" % label)
	var witness = Metrics.new(CHECKPOINTS[label][1], started)
	witness.watch(cover)
	while witness.elapsed_ms() < TIMEOUT_MS:
		await RenderingServer.frame_post_draw
		var scene: Node = _screens.run_scene()
		var frame = witness.sample(cover, scene)
		if media != null:
			media.frame(root)
			if not media.problem.is_empty():
				media.discard()
				return _fail(media.problem)
		if not _quit_point.is_empty() and witness.should_quit(_quit_point):
			print("FEL29 QUIT %s SHA256=%s" % [_quit_point, FileAccess.get_sha256(path.path_join("run.save"))])
			root.close_requested.emit()
			return false
		if scene != null and witness.ready_ms < 0.0 and _input_ready(scene, witness.destination):
			witness.mark_ready()
		if scene != null and witness.ready_ms >= 0.0 and witness.steady_ms >= 0.0:
			if media == null or frame["ms"] >= witness.steady_ms + AUDIO_TAIL_MS: break

	if media != null:
		if not media.finish(witness.record(label)): return _fail(media.problem)
	elif label == "play_map":
		await _probe_gameplay_map(witness)
	else:
		_report(label, witness.checks(label == "reduced", Transition.REVEAL_SECONDS))

	if is_instance_valid(current_scene):
		current_scene.queue_free()
		await process_frame
		await process_frame
	return true


func _send_joy_button(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		root.push_input(event, true)


func _input_ready(scene: Node, expected: String) -> bool:
	if root.gui_disable_input or not scene.can_process(): return false
	if expected == "section":
		# The section overlay now owns input. Its existing skip gate stays active.
		return is_instance_valid(scene._section_transition) and scene._section_transition.can_process()
	if _screens.screen() != expected: return false
	if not _map_input.is_empty():
		if _map_input == "keyboard" and root.gui_get_focus_owner() == null:
			_driver.send(_driver.key(KEY_TAB))
		var focus: Control = root.gui_get_focus_owner()
		return focus != null and scene._large_map_view.is_ancestor_of(focus)
	if expected in ["dialogue", "campfire", "treasure"]:
		# These surfaces have their own entrance/choice gates. Measure the end
		# of loading ownership without activating any authored choice.
		return not scene._treasure_reveal_active
	return not _screens.probe(expected).is_empty()


func _probe_gameplay_map(witness: RefCounted) -> void:
	var scene: Node = _screens.run_scene()
	var button: Button = null if scene == null or scene._event_view == null else scene._event_view.continue_button
	var input: Dictionary = _driver.control(button)
	if witness.ready_ms < 0.0 or input.is_empty():
		_report("play_map", {"gameplay_fade_ms": [-1.0, false]})
		return
	_driver.prepare(input)
	_driver.send(input)
	var started: int = Time.get_ticks_usec()
	var fade_started: int = 0
	var fade_ms: float = -1.0
	var expected_ms: float = 1000.0 * MapBackdrop.FADE_SECONDS
	var duration_matches: bool = false
	while Time.get_ticks_usec() - started < TIMEOUT_MS * 1000:
		await RenderingServer.frame_post_draw
		var map: ColorRect = scene._large_map_scrim
		if not map.visible: continue
		var tween: Tween = map._fade
		if tween != null and tween.is_running() and fade_started == 0: fade_started = Time.get_ticks_usec()
		if is_equal_approx(map.modulate.a, 1.0):
			if fade_started > 0:
				fade_ms = (Time.get_ticks_usec() - fade_started) / 1000.0
				duration_matches = tween != null and absf(1000.0 * tween.get_total_elapsed_time() - expected_ms) <= 1000.0 / FPS
			break
	_report("play_map", {
		"gameplay_fade_ms": [roundi(expected_ms) if duration_matches else roundi(fade_ms), duration_matches],
		"gameplay_fade_wall_ms": [roundi(fade_ms), duration_matches],
	})


func _report(label: String, checks: Dictionary) -> void:
	var passed: bool = true
	var results: Dictionary
	for key: String in checks:
		var value: Array = checks[key]
		var before: Variant = (_before.get(label, {}) as Dictionary).get(key, "unmeasured")
		print("FEL29 %s %s before=%s after=%s %s" % [label, key, before, value[0], "PASS" if value[1] else "FAIL"])
		results[key] = value[0]
		passed = passed and bool(value[1])
	_stats[label] = results
	if not passed: _failed += 1


func _fail(reason: String) -> bool:
	push_error("FEL29 FAIL " + reason)
	quit(1)
	return false
