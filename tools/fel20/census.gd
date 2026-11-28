extends SceneTree
## A production-input census and exact input transcript replay.

const Shutdown = preload("res://scripts/application_shutdown.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const RecentEvents = preload("res://scripts/recent_event_store.gd")
const Persistence = preload("res://scripts/run_persistence.gd")
const Inputs = preload("res://tools/fel20/input_driver.gd")
const Screens = preload("res://tools/fel20/screens.gd")
const Route = preload("res://tools/fel20/route.gd")
const Timing = preload("res://tools/fel20/timing.gd")

const SIZE := Vector2i(1920, 1080)
const FPS := 60
const FAST_SETUP_SCALE := 6.0
const INPUT_FRAME_LIMIT := 20.0
const BOOT_FRAME_LIMIT := 90.0
const SETUP_FRAMES := 3
const WATCH_SECONDS := 0.25
const DIALOGUE_REPLAY_INTERVAL_MS := 250
const SETUP_RETRY_DELAY_USEC := 250000
const FILES := ["run.save", "progression.json", "settings.json", "recent_events.json"]

var output: String
var replay_path: String
var checkpoint_path: String
var start_action: int = 1
var seeds: Array[int] = [15, 17]
var fast_setup: bool = true
var limit: int = 0
var death_after: int = 0
var pass_only: bool = false
var _runs_started: int = 0
var _actions: int = 0
var _timed: int = 0
var _flagged: int = 0
var _native: bool
var _recorder: AudioEffectRecord
var _only_action: int = 0
var _route_log: FileAccess
var _timings: FileAccess
var _inputs: Inputs
var _screens: Screens
var _route: Route
var _replay: Array[Dictionary]
var _idle_from: int
var _last_checkpoint: String
var _checkpoint_key: Array
var _last_dialogue_tap: int
var _last_retried_setup: int = -1


func _initialize() -> void:
	Runtime.apply_from_environment()
	_native = DisplayServer.get_name() != "headless"
	output = OS.get_environment("FEL20_OUTPUT")
	_only_action = int(OS.get_environment("FEL20_ONLY_ACTION"))
	replay_path = OS.get_environment("FEL20_REPLAY")
	checkpoint_path = OS.get_environment("FEL20_CHECKPOINT")
	if OS.has_environment("FEL20_START_ACTION"): start_action = int(OS.get_environment("FEL20_START_ACTION"))
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(0, args.size(), 2):
		if index + 1 >= args.size():
			_fail("missing value for " + args[index])
			return
		var value: String = args[index + 1]
		match args[index]:
			"--output-dir": output = value
			"--replay": replay_path = value
			"--checkpoint": checkpoint_path = value
			"--start-action": start_action = int(value)
			"--seeds":
				seeds.clear()
				for seed: String in value.split(","): seeds.append(int(seed))
			"--limit": limit = int(value)
			"--death-after": death_after = int(value)
			"--pass-only": pass_only = value == "true"
			"--fast-setup": fast_setup = value == "true"
			_:
				_fail("unknown option " + args[index])
				return
	if output.is_empty() or (_native and replay_path.is_empty()):
		_fail("set an output directory, and provide FEL20_REPLAY for native")
		return
	output = ProjectSettings.globalize_path(output)
	if FileAccess.file_exists(output.path_join("route.jsonl")) or FileAccess.file_exists(output.path_join("timings.jsonl")):
		_fail("output already contains census data: " + output)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("cannot create " + output)
		return
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = SIZE
	root.size = SIZE
	Engine.max_fps = FPS
	OS.low_processor_usage_mode = false
	if not _native: process_frame.connect(_fake_draw.call_deferred)
	call_deferred("_run")


func _fake_draw() -> void:
	RenderingServer.frame_pre_draw.emit()
	RenderingServer.frame_post_draw.emit()


func _run() -> void:
	if not checkpoint_path.is_empty() and not _stage_checkpoint():
		_fail("cannot stage checkpoint " + checkpoint_path)
		return
	Store.set_run_storage_path(output.path_join("run.save"))
	Store.set_storage_path(output.path_join("progression.json"))
	Settings.set_storage_path(output.path_join("settings.json"))
	Analytics.set_storage_dir(output.path_join("analytics"))
	RecentEvents.set_storage_path(output.path_join("recent_events.json"))
	var preferences: Dictionary = Settings.default_settings()
	preferences["ui_scale"] = 1.0
	preferences["reduced_motion"] = false
	if not Settings.save_settings(preferences):
		_fail("cannot write isolated settings")
		return
	OS.set_environment("LABYRINTH_CEL_LOOK", "all")
	if _native:
		_recorder = AudioEffectRecord.new()
		_recorder.format = AudioStreamWAV.FORMAT_16_BITS
		AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"), _recorder)
	_inputs = Inputs.new(root)
	_screens = Screens.new(self, _inputs)
	_route = Route.new()
	_route.inputs = _inputs
	_route.no_embrace = true
	_route.death_route = pass_only
	_route.measure_menus = not pass_only
	_route.rng = RandomNumberGenerator.new()
	if not replay_path.is_empty():
		var file := FileAccess.open(replay_path, FileAccess.READ)
		if file == null:
			_fail("cannot read replay " + replay_path)
			return
		while not file.eof_reached():
			var line: String = file.get_line()
			if line.is_empty(): continue
			var decoded: Variant = JSON.parse_string(line)
			if not decoded is Dictionary or not decoded.has("input"):
				_fail("invalid route row")
				return
			var before: Array = decoded["before"]
			# JSON numbers are floats. Preserve the integral in-memory witness
			# fields used for strict source matching.
			if before.size() > 11:
				before[10] = int(before[10])
				before[11] = int(before[11])
			_replay.append(decoded)
		if start_action < 1 or start_action > _replay.size():
			_fail("start action is outside the replay")
			return
	else:
		_route_log = FileAccess.open(output.path_join("route.jsonl"), FileAccess.WRITE)
		if _route_log == null:
			_fail("cannot create route")
			return
	_timings = FileAccess.open(output.path_join("timings.jsonl"), FileAccess.WRITE)
	if _timings == null or change_scene_to_file("res://scenes/main_menu.tscn") != OK:
		_fail("cannot start title")
		return

	_actions = start_action - 1
	if not checkpoint_path.is_empty() and not await _continue_checkpoint():
		_fail("checkpoint source for action %d differs: expected %s, got %s" %
			[start_action, str(_replay[start_action - 1]["before"]), str(_screens.witness())])
		return
	_idle_from = Time.get_ticks_usec()
	print("FEL20 | Action | Transition | First response | Input ready | Total | Hitches | Flags | Destination | Witness")
	while true:
		await RenderingServer.frame_post_draw
		if _actions >= _replay.size() and not replay_path.is_empty(): break
		if limit > 0 and _actions >= limit: break
		if root.get_visible_rect().size != Vector2(SIZE):
			_fail("logical viewport is %s, expected %s" % [str(root.get_visible_rect().size), str(SIZE)])
			return
		if not _dispatchable():
			if _expired(BOOT_FRAME_LIMIT if _screens.screen() in ["loading", "title_boot"] else INPUT_FRAME_LIMIT):
				_fail("no input boundary at %s after action %d" % [str(_screens.witness()), _actions])
				return
			continue
		var step: Dictionary
		if replay_path.is_empty():
			if _screens.screen() == "title" and not Store.has_saved_run() and _runs_started >= seeds.size(): break
			if death_after > 0 and int(_route.counts.get("reward.map", 0)) >= death_after: _route.death_route = true
			_route.observe(_screens.witness())
			step = _route.next(current_scene)
		else:
			step = _replay_step()
		if step.is_empty():
			if not _expired(): continue
			print("FEL20 ROUTE STOP actions=%d witness=%s next=%s" % [_actions, str(_screens.witness()), str(_replay[_actions] if not replay_path.is_empty() else {})])
			if not replay_path.is_empty():
				_fail("replay source diverged")
				return
			break
		if not await _step(step): return
		if _only_action > 0 and _actions >= _only_action: break
	print("FEL20 CENSUS DONE transitions=%d flagged=%d" % [_timed, _flagged])
	print("FEL20 OUTPUT " + output)
	quit()


func _replay_step() -> Dictionary:
	var step: Dictionary = _replay[_actions]
	var expected: Array = step["before"]
	if _screens.matches(expected):
		if step.get("skip_setup", false) and step["id"].is_empty():
			_actions += 1
			_idle_from = Time.get_ticks_usec()
			return {}
		return step if not _inputs.resolve(current_scene, step["input"]).is_empty() else {}
	var actual: Array = _screens.witness()
	if expected.size() < 3 or actual.size() < 3 or expected.slice(1, 3) != actual.slice(1, 3): return {}
	# The typewriter can finish between two recorded Enter taps. Use the same
	# Continue input for line visits and skip taps whose line already advanced.
	var unmeasured_enter: bool = (step["id"].is_empty() and step["input"]["type"] == "key"
		and int(step["input"]["code"]) == KEY_ENTER)
	if expected[0] == "dialogue" and unmeasured_enter:
		if actual[0] in ["room", "map"] or (expected.size() > 11 and int(actual[11]) > int(expected[11])):
			_actions += 1
			_idle_from = Time.get_ticks_usec()
			return {}
	if actual[0] == "dialogue" and (expected[0] in ["room", "map"]
		or (expected[0] == "dialogue" and expected.size() > 11 and int(actual[11]) < int(expected[11]))):
		var scene: Node = _screens.run_scene()
		var now: int = Time.get_ticks_msec()
		if not scene._has_current_dialogue_options() and now - _last_dialogue_tap >= DIALOGUE_REPLAY_INTERVAL_MS:
			_inputs.send(_inputs.key(KEY_ENTER))
			_last_dialogue_tap = now
	_retry_uncommitted_setup(actual[0], expected[0])
	return {}


func _retry_uncommitted_setup(actual: String, expected: String) -> void:
	if expected != "map" or actual not in ["campfire", "treasure"] or _actions <= 0:
		return
	if _last_retried_setup == _actions or Time.get_ticks_usec() - _idle_from < SETUP_RETRY_DELAY_USEC:
		return
	var previous: Dictionary = _replay[_actions - 1]
	var input: Dictionary = previous["input"]
	if not previous["id"].is_empty() or not _screens.matches(previous["before"]): return
	if not input.has("choice") and not str(input.get("node", "")).begins_with("RelicChoice_"): return
	var ready: Dictionary = _inputs.resolve(current_scene, input)
	if ready.is_empty(): return
	_last_retried_setup = _actions
	_inputs.prepare(ready)
	_inputs.send(ready)
	print("FEL20 SETUP RETRY action=%d target=%s" % [_actions, ready["label"]])


func _expired(seconds: float = INPUT_FRAME_LIMIT) -> bool:
	return Time.get_ticks_usec() - _idle_from > int(seconds * 1000000.0)


func _dispatchable() -> bool:
	if not is_instance_valid(current_scene) or Shutdown.departure_requested(self) or root.gui_disable_input: return false
	if _screens.screen() in ["boot", "loading", "title_boot", "between_scenes"]: return false
	var scene: Node = _screens.run_scene()
	if scene == null: return true
	if scene._animation_lock or is_instance_valid(scene._section_transition): return false
	if scene._treasure_presentation_busy(): return false
	if is_instance_valid(scene._event_view) and scene._event_view.visible:
		if scene._event_view._busy or scene._event_view._closing or scene._event_view._request_pending: return false
	if scene._large_map_scrim.visible and scene._large_map_view.activation_coord != Vector2i(-999, -999): return false
	if str(scene._run_state.get("mode")) == "combat" and not scene._combat_engine.is_player_turn(scene._combat_state): return false
	return true


func _step(step: Dictionary) -> bool:
	var input: Dictionary = _inputs.resolve(current_scene, step["input"])
	if input.is_empty():
		_fail("input target unavailable for action %d (%s)" % [_actions + 1, step["input"]["label"]])
		return false
	var id: String = step["id"]
	var expected: String = step["destination"]
	if replay_path.is_empty() and _screens.screen() == "title" and input["label"] == "StartButton":
		step["seed"] = seeds[_runs_started]
		_runs_started += 1
		_route.rng.seed = step["seed"]
	if step.has("seed"):
		root.set_meta("labyrinth_performance_probe_seed", int(step["seed"]))
	if replay_path.is_empty():
		step["before"] = _screens.witness()
		step["checkpoint"] = _checkpoint()
	var source_embers: int = -1
	if id == "shop.buy":
		var scene: Node = _screens.run_scene()
		source_embers = scene._run_engine.held_embers(scene._run_state)
	var watched: bool = replay_path.is_empty() and step.get("watch", false)
	Engine.time_scale = 1.0 if not id.is_empty() or step.get("watch", false) or not fast_setup else FAST_SETUP_SCALE
	_inputs.prepare(input)
	for frame: int in SETUP_FRAMES: await RenderingServer.frame_post_draw
	if input["type"] == "click":
		var settled: Dictionary = _inputs.resolve(current_scene, input)
		if not settled.is_empty() and settled["point"] != input["point"]:
			input = settled
			_inputs.prepare(input)
			await RenderingServer.frame_post_draw
	if replay_path.is_empty(): step["input"] = input
	var timing := Timing.new(_screens, output, _native, _actions + 1)
	var capture: bool = not id.is_empty() and (_only_action <= 0 or _actions + 1 == _only_action)
	if not timing.begin(capture, _recorder):
		_fail(timing.problem)
		return false
	_inputs.send(input)
	timing.sent_at = timing.elapsed()
	if replay_path.is_empty(): _route.dispatched(input)
	if watched and id.is_empty():
		var sample: String = await _classify(timing, step["before"][0])
		if sample == "reward":
			id = "kill.reward"
			expected = "reward"
		elif sample == "recap":
			id = "defeat.recap"
			expected = "recap"
		elif sample == "prebattle" and step["before"][0] == "map":
			id = "map.prebattle"
			expected = sample
		elif sample == "event_choices" and step["before"][0] == "map":
			id = "map.event"
			expected = sample
		elif sample == "shop" and step["before"][0] == "map":
			id = "map.shop"
			expected = sample
		elif sample == "map" and step["before"][0] == "reward":
			id = "reward.map"
			expected = "map"
	if not id.is_empty():
		var result: Dictionary = await timing.finish(id, expected)
		if not timing.problem.is_empty():
			_fail(timing.problem)
			return false
		if id == "shop.buy":
			var scene: Node = _screens.run_scene()
			result["reached"] = (scene != null
				and scene._run_engine.held_embers(scene._run_state) < source_embers)
		_timings.store_line(JSON.stringify(result))
		_timings.flush()
		if result["reached"]:
			_route.accepted(id)
			_timed += 1
			if not result["flags"].is_empty(): _flagged += 1
			step["id"] = id
			step["destination"] = expected
			if replay_path.is_empty(): step["target_checkpoint"] = _checkpoint("after")
		elif not replay_path.is_empty():
			_fail("replay destination diverged for action %d (%s)" % [_actions + 1, id])
			return false
		else:
			step["id"] = ""
			step["destination"] = ""
	else:
		timing.discard()
	if capture and _native and not await _wait_for_capture(_actions + 1):
		_fail("native capture processing failed at action %d" % (_actions + 1))
		return false
	if _route_log != null:
		_route_log.store_line(JSON.stringify(step))
		_route_log.flush()
	_actions += 1
	if _actions % 20 == 0:
		print("FEL20 ROUTE action=%d witness=%s" % [_actions, str(_screens.witness())])
	_idle_from = Time.get_ticks_usec()
	return true


func _wait_for_capture(action: int) -> bool:
	var started: int = Time.get_ticks_usec()
	while not FileAccess.file_exists(output.path_join("%05d.json" % action)):
		if FileAccess.file_exists(output.path_join("capture-error")): return false
		if Time.get_ticks_usec() - started > int(BOOT_FRAME_LIMIT * 1000000.0): return false
		await RenderingServer.frame_post_draw
	return true


func _classify(timing: Timing, before: String) -> String:
	# Observe any real ending. A normal action is discarded once its lock
	# yields. A possible death/victory stays under observation through handoff.
	var start: int = Time.get_ticks_usec()
	var observed_lock: bool = false
	while Time.get_ticks_usec() - start < int(INPUT_FRAME_LIMIT * 1000000.0):
		await RenderingServer.frame_post_draw
		timing.sample()
		_inputs.motion(_inputs.pointer)
		var current: String = _screens.screen()
		if current != before and current in ["reward", "recap", "map", "prebattle", "event_choices", "shop"]: return current
		var scene: Node = _screens.run_scene()
		if scene == null: break
		var locked: bool = scene._animation_lock or (before == "map" and scene._large_map_view.activation_coord != Vector2i(-999, -999))
		observed_lock = observed_lock or locked
		if not locked and (observed_lock or Time.get_ticks_usec() - start > int(WATCH_SECONDS * 1000000.0)): break
	return ""


func _stage_checkpoint() -> bool:
	if replay_path.is_empty() or not FileAccess.file_exists(checkpoint_path.path_join("run.save")):
		return false
	for name: String in FILES:
		var source: String = checkpoint_path.path_join(name)
		if not FileAccess.file_exists(source): continue
		if DirAccess.copy_absolute(source, output.path_join(name)) != OK: return false
	return true


func _continue_checkpoint() -> bool:
	var expected: Array = _replay[start_action - 1]["before"]
	var started: int = Time.get_ticks_usec()
	var pressed: bool = false
	var opened_map: bool = false
	while Time.get_ticks_usec() - started < int(BOOT_FRAME_LIMIT * 1000000.0):
		await RenderingServer.frame_post_draw
		if not _dispatchable(): continue
		if _screens.matches(expected): return true
		if not pressed and _screens.screen() == "title":
			var input: Dictionary = _inputs.control(current_scene.continue_button)
			if input.is_empty(): return false
			_inputs.prepare(input)
			_inputs.send(input)
			pressed = true
		elif not opened_map and expected[0] == "map" and _screens.screen() == "room":
			var actual: Array = _screens.witness()
			if actual.slice(1, 3) == expected.slice(1, 3):
				_inputs.send(_inputs.key(KEY_M))
				opened_map = true
	return false


func _checkpoint(boundary: String = "before") -> String:
	var scene: Node = _screens.run_scene()
	if scene == null: return _last_checkpoint if Store.has_saved_run() else ""
	var mode: String = scene._run_state.get("mode", "")
	if mode in ["defeat", "victory", "embrace"]: return ""
	var key: Array = _screens.witness()
	# Transient menus re-enter from the previous committed source boundary.
	if key[0] in ["gear", "magic", "skills", "pause", "grimoire"]: return _last_checkpoint
	if key == _checkpoint_key: return _last_checkpoint
	if scene._selected_card_index >= 0 or scene._player_movement_selected: return _last_checkpoint
	if not Persistence.flush(scene) or not Store.has_saved_run(): return ""
	var saved: Dictionary = Store.load_saved_run()
	if saved.get("current_room") != scene._run_state.get("current_room") or saved.get("mode") != mode: return ""
	var suffix: String = "-after" if boundary == "after" else ""
	var relative: String = "checkpoints/%05d%s" % [_actions + 1, suffix]
	var path: String = output.path_join(relative)
	if DirAccess.make_dir_recursive_absolute(path) != OK: return ""
	for file: String in FILES:
		var source: String = output.path_join(file)
		if FileAccess.file_exists(source) and DirAccess.copy_absolute(source, path.path_join(file)) != OK: return ""
	_checkpoint_key = key
	_last_checkpoint = relative
	return relative


func _fail(message: String) -> void:
	printerr("FEL20 FAIL " + message)
	quit(1)
