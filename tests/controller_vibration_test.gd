extends SceneTree

const MotionFixture = preload("res://tests/suites/combat_motion_timing_suite.gd")
const FloatingText = preload("res://scripts/floating_combat_text.gd")
const Settings = preload("res://scripts/settings_store.gd")
const FIRST_PAD: int = 7
const SECOND_PAD: int = 8
const FIXTURE_TERRAIN_TILE := Vector2i(4, 4)
const FIRST_HIT_USEC: int = 1000000
const SEPARATE_HIT_USEC: int = 400000
const MERGED_HIT_USEC: int = 40000
const CLEANUP_FRAMES: int = 4

var _failures: Array[String]
var _starts: Array[Array]
var _stops: Array[int]
var _now_usec: int = FIRST_HIT_USEC
var _run: Node
var _router: Node
var _pacing: Node
var _state: Dictionary

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Settings.set_storage_path("user://controller_vibration_settings.json")
	Settings.save_settings(Settings.default_settings())
	await process_frame
	_router = root.get_node("InputRouter")
	_run = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	root.add_child(_run)
	await process_frame
	MotionFixture._install_fixture(_run, false)
	_state = _run.get("_combat_state")
	_run.set("_animation_lock", true)
	_pacing = _run.get("_combat_pacing")
	_pacing.vibration.ticks_usec = func() -> int: return _now_usec
	_pacing.vibration.start_vibration = func(device: int, weak: float, strong: float, seconds: float) -> void:
		_starts.append([device, weak, strong, seconds])
	_pacing.vibration.stop_vibration = func(device: int) -> void: _stops.append(device)
	_pad_input(FIRST_PAD)
	# Connecting another pad changes the glyph fallback. It has sent no input.
	_router.call("_on_joy_connection_changed", SECOND_PAD, true)
	_test_hit_routes()
	_test_merge()
	await _test_gates_and_stops()
	for failure: String in _failures:
		push_error(failure)
	print("CONTROLLER VIBRATION TEST RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)

func _test_hit_routes() -> void:
	(_run.get("_settings") as Dictionary)["combat_speed"] = Settings.COMBAT_FASTEST
	_pacing.begin_card()
	_expect(is_equal_approx(Engine.time_scale, 2.0), "Fixture runs at Fastest combat speed")
	_hit("player", 2)
	_expect_pulse(FIRST_PAD, 3.5 / 8.0, 1.5 / 6.0, 0.25, "2 HP hero hit")
	_expect(Engine.time_scale == 0.0, "Rumble request is delivered while hit-stop has frozen the presentation clock")
	_hit("player", 6)
	_expect_pulse(FIRST_PAD, 5.0 / 8.0, 0.5, 0.28, "6 HP hero hit")
	_hit("player", 12)
	_expect_pulse(FIRST_PAD, 1.0, 1.0, 0.34, "12 HP hero hit")
	_hit("enemy_1", 6)
	_expect_pulse(FIRST_PAD, 3.5 / 8.0, 0.0, 0.25, "Enemy hit")
	_hit("enemy_1", 2, true)
	_expect_pulse(FIRST_PAD, 6.5 / 8.0, 0.0, 0.31, "Enemy kill")

	var terrain: Array = _run.call("_floating_texts_for_terrain_losses", [{"tile": FIXTURE_TERRAIN_TILE, "hp_loss": 2}])
	FloatingText.ensure_screen_layout_id(terrain[0])
	_present(_state, terrain)
	_expect_pulse(FIRST_PAD, 0.25, 0.0, 0.22, "Explicit terrain HP damage")
	var before: int = _starts.size()
	_present(_state, terrain)
	var hero: Dictionary = _state["player"]
	var blocked: Array = _run.call("_floating_texts_for_target_losses", [{"key": "player", "tile": hero["pos"], "block_loss": 2}])
	_present(_state, blocked)
	(_run.get("board_view") as Node).call("rumble", 6.5, 0.31, 1.0)
	_expect(_starts.size() == before, "Repeat submissions, block loss and standalone camera kicks produce no pulse")

func _test_merge() -> void:
	_hit("enemy_1", 12)
	_hit("player", 2, false, MERGED_HIT_USEC)
	_expect_pulse(FIRST_PAD, 6.5 / 8.0, 1.5 / 6.0, 0.27, "Merged motors retain maxima and the first hit's clock")
	var before: int = _starts.size()
	_hit("enemy_1", 2, false, MERGED_HIT_USEC)
	_expect(_starts.size() == before, "A weaker merged hit leaves the running device command alone")
	_hit("player", 12, false, MERGED_HIT_USEC)
	_expect_pulse(FIRST_PAD, 1.0, 1.0, 0.22, "Third merged hit uses the original start and the larger duration")

func _test_gates_and_stops() -> void:
	var settings: Dictionary = _run.get("_settings")
	settings["reduced_motion"] = true
	settings["mute_in_background"] = true
	_pad_input(SECOND_PAD)
	_hit("player", 6)
	_expect_pulse(SECOND_PAD, 5.0 / 8.0, 0.5, 0.28, "Reduced Motion and Mute in background do not alter rumble")
	_expect(_stops == [FIRST_PAD], "Changing pads releases the old pad")
	_expect_stop(SECOND_PAD, func() -> void: _run.call("_open_menu_overlay"), "Opening pause overlay")
	var before: int = _starts.size()
	_hit("player", 2)
	_expect(_starts.size() == before, "The pause overlay suppresses new pulses")
	_run.call("_close_menu_overlay")
	_run.set("_animation_lock", true)
	_hit("player", 2)
	var pause_stops: int = _stops.size()
	paused = true
	await process_frame
	await process_frame
	_expect(_stops.size() == pause_stops + 1 and _stops.back() == SECOND_PAD, "Pausing the scene tree stops the active pad")
	paused = false
	_hit("player", 2)
	_expect_stop(SECOND_PAD, func() -> void: _pacing.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT), "Losing window focus")
	before = _starts.size()
	_hit("player", 2)
	_expect(_starts.size() == before, "An unfocused window suppresses new pulses")
	_pacing.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	_hit("player", 2)
	var run_state: Dictionary = _run.get("_run_state")
	run_state["mode"] = "room"
	_expect_stop(SECOND_PAD, func() -> void: _pacing.call("_process", 0.0), "Leaving combat")
	run_state["mode"] = "combat"
	_hit("player", 2)
	var disabled: Dictionary = settings.duplicate(true)
	disabled["controller_vibration"] = false
	_expect_stop(SECOND_PAD, func() -> void: _run.call("_on_settings_changed", disabled), "Turning Controller vibration Off")
	before = _starts.size()
	_hit("player", 2)
	_expect(_starts.size() == before, "Controller vibration Off suppresses every hit")
	_run.call("_on_settings_changed", settings)
	var mouse := InputEventMouseButton.new()
	mouse.pressed = true
	_router.record_input_activity(mouse)
	_hit("player", 2)
	_expect(_starts.size() == before, "Mouse modality suppresses rumble with a connected pad")
	_pad_input(SECOND_PAD)
	var key := InputEventKey.new()
	key.pressed = true
	_run.call("_input", key)
	_hit("player", 2)
	_expect(_starts.size() == before, "Keyboard input suppresses rumble")
	_pad_input(SECOND_PAD)
	_hit("player", 2)
	_expect_pulse(SECOND_PAD, 3.5 / 8.0, 1.5 / 6.0, 0.25, "Returning to the pad restores rumble")
	var stop_count: int = _stops.size()
	await _run.prepare_application_quit("controller_vibration_test")
	_expect(_stops.size() == stop_count + 1 and _stops.back() == SECOND_PAD, "Quitting stops the active device")
	for frame: int in range(CLEANUP_FRAMES):
		await process_frame
	_run.free()

func _hit(actor: String, damage: int, killed: bool = false, elapsed_usec: int = SEPARATE_HIT_USEC) -> void:
	var displayed: Dictionary = _state.duplicate(true)
	var target: Dictionary = displayed["player"] if actor == "player" else displayed["enemies"][0]
	target["hp"] = 0 if killed else int(target["hp"]) - damage
	var texts: Array = _run.call("_floating_texts_for_target_losses", [{"key": actor, "tile": target["pos"], "hp_loss": damage}])
	_present(displayed, texts, elapsed_usec)

func _present(state: Dictionary, texts: Array, elapsed_usec: int = SEPARATE_HIT_USEC) -> void:
	_now_usec += elapsed_usec
	_run.call("_render_board_state", state, {"floating_texts": texts})

func _pad_input(device: int) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.pressed = true
	_router.record_input_activity(event)

func _expect_pulse(device: int, weak: float, strong: float, seconds: float, message: String) -> void:
	var pulse: Array = _starts.back() if not _starts.is_empty() else []
	_expect(pulse.size() == 4 and pulse[0] == device and is_equal_approx(pulse[1], weak) and is_equal_approx(pulse[2], strong) and is_equal_approx(pulse[3], seconds),
		"%s. Expected %s, got %s" % [message, [device, weak, strong, seconds], pulse])

func _expect_stop(device: int, action: Callable, message: String) -> void:
	var before: int = _stops.size()
	action.call()
	_expect(_stops.size() == before + 1 and _stops.back() == device, message + " stops the active pad")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
