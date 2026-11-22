extends SceneTree

const Fixtures = preload("res://tools/hitch_census/fixtures.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const SIZE := Vector2i(1920, 1080)
const SEED := 7
const IDLE_FRAMES := 30
const FIRST_FRAMES := 3
# A board laid out at or below this tile width is a collapsed point, not a
# readable board (see _frame_state).
const COLLAPSED_TILE_WIDTH := 2.0
const COLLAPSED_MARGIN := 8.0

var _errors := PackedStringArray()
var _cover_loads: Dictionary = {}
var _begin_loads: Dictionary = {}
var _load_target: Dictionary = {}
var _collect_loads_enabled := false
var _trace := OS.get_environment("LABYRINTH_HITCH_TRACE") == "1"
var _capture := false
# Records the per-frame capture state without images, so a headless run can
# check the capture path and compare both arms' state receipts.
var _frame_state_only := false
var _instrument := false
var _early := false
var _output: String
var _fixture := "room:pre_battle"
var _receipt: Dictionary = {}

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture="): _fixture = argument.trim_prefix("--fixture=")
		elif argument.begins_with("--output="): _output = argument.trim_prefix("--output=")
		elif argument == "--capture": _capture = true
		elif argument == "--frame-state": _frame_state_only = true
		elif argument == "--attribute": _instrument = true
		elif argument == "--early": _early = true
	_run.call_deferred()

func _run() -> void:
	if _output.is_empty(): _output = OS.get_user_data_dir().path_join("perf-171")
	DirAccess.make_dir_recursive_absolute(_output)
	Store.set_storage_path("user://perf171-profile.json")
	Store.set_run_storage_path("user://perf171-run.save")
	Settings.set_storage_path("user://perf171-settings.json")
	Analytics.set_storage_dir("user://perf171-analytics")
	var settings: Dictionary = Settings.default_settings()
	settings.merge({"display_mode": "windowed", "ui_scale": 1.0, "reduced_motion": _capture or _frame_state_only}, true)
	if not Settings.save_settings(settings):
		_errors.append("Could not write fixture settings")
	root.mode = Window.MODE_WINDOWED
	root.size = SIZE
	OS.low_processor_usage_mode = false
	var native: bool = DisplayServer.get_name() != "headless"
	if native:
		DisplayServer.window_move_to_foreground()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if _capture and not native:
		_errors.append("capture requires a native renderer")
	else:
		await _take()
	_receipt.merge({"fixture": _fixture, "seed": SEED, "errors": _errors, "cover_loads": _cover_loads, "begin_loads": _begin_loads,
		"godot": Engine.get_version_info().string, "display": DisplayServer.get_name(),
		"renderer": RenderingServer.get_current_rendering_driver_name(), "cpu": OS.get_processor_name(),
		"os": OS.get_name(), "viewport": str(root.content_scale_size), "ui_scale": root.content_scale_factor})
	var file := FileAccess.open(_output.path_join("receipt.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_receipt, "  "))
	file.close()
	print("PERF171 PROBE: %s %s begin_us=%d cover_loads=%d" % [_fixture, "PASS" if _errors.is_empty() else "FAIL",
		int(_receipt.get("begin_frame_us", 0)), _cover_loads.values().reduce(func(sum: int, row: Dictionary) -> int: return sum + int(row.count), 0)])
	for error: String in _errors: push_error(error)
	if is_instance_valid(current_scene): current_scene.queue_free()
	await process_frame
	await process_frame
	quit(0 if _errors.is_empty() else 1)

func _state() -> Dictionary:
	var parts: PackedStringArray = _fixture.split(":")
	if parts.size() != 2: return {}
	var builder := Fixtures.new()
	var state: Dictionary
	match parts[0]:
		"guardian": state = builder.make("guardian", SEED, {"guardian_id": parts[1], "guardian_case": "pre_battle"})
		"dragon": state = builder.make("dragon", SEED, {"dragon_id": parts[1], "dragon_depth": 24 if parts[1] == "noctyrax" else 4, "dragon_case": "pre_battle"})
		"room": state = builder.make("pre_battle", SEED, {"min_enemies": 1})
	if state.is_empty() and not builder.census_error.is_empty(): _errors.append(builder.census_error)
	builder.free()
	if not state.is_empty():
		var metadata: Dictionary = state.get("analytics", {})
		metadata["run_id"] = "perf171_fixture_seed_7"
		state["analytics"] = metadata
	return state

func _take() -> void:
	var state: Dictionary = _state()
	if state.get("mode") != "pre_battle" or not Store.save_data(state["progression"]) or not Store.save_run_state(state):
		_errors.append("could not save pre-battle fixture")
		return
	var menu: Node = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu
	_configure_viewport()
	for ignored: int in range(IDLE_FRAMES): await process_frame
	if _trace:
		process_frame.connect(_collect_loads)
		_collect_loads()
	_collect_loads_enabled = true
	_load_target = _cover_loads
	var cover_started: int = Time.get_ticks_usec()
	menu._on_continue_button_pressed()
	var host: Node
	# Wall-clock wait: vsync is off, so a frame budget ran out under background QoS before Continue finished.
	var deadline_msec: int = Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline_msec:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.has_method("_committed_run_state") and current_scene._initial_ui_complete and root.get_node_or_null("MenuRunTransition") == null:
			host = current_scene
			break
	_collect_loads_enabled = false
	_receipt["continue_us"] = Time.get_ticks_usec() - cover_started
	if not is_instance_valid(host) or not host._pre_battle_scrim.visible:
		_errors.append("Continue did not reveal pre-battle")
		return
	_configure_viewport()
	if not _early:
		for ignored: int in range(IDLE_FRAMES): await process_frame
	var preview: Dictionary = host._pre_battle_preview_run_state.get("combat_state", {})
	_receipt["room_type"] = preview.get("room_type", "")
	if _fixture.begins_with("room:") and _receipt["room_type"] != "combat":
		_errors.append("ordinary fixture resolved to %s" % _receipt["room_type"])
		return
	var button: BaseButton = host._pre_battle_panel.find_child("PreBattleStartButton", true, false)
	if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled:
		_errors.append("Begin button unavailable")
		return
	var point: Vector2 = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await process_frame
	# Bracket a full rendered interval on native takes, without readback or
	# attribution snapshots between the click and the first draw.
	var native: bool = DisplayServer.get_name() != "headless"
	if native:
		await RenderingServer.frame_post_draw
		if not DisplayServer.window_is_focused():
			_errors.append("Native window is unfocused before Begin")
			return
	if _instrument:
		host.set_runtime_performance_instrumentation_enabled(true)
		host.board_view.set_submission_performance_instrumentation_enabled(true)
		host.board_view.reset_render_instrumentation()
	_receipt["prepared_rigs"] = host.board_view._prepared_unit_renderers.size()
	var prepared_layers: Variant = host.board_view.get("_prepared_opening_tile_layers") if "_prepared_opening_tile_layers" in host.board_view else null
	_receipt["prepared_tile_layers"] = prepared_layers.size() if prepared_layers is Array else 0
	if _trace:
		_collect_loads()
		_load_target = _begin_loads
		_collect_loads_enabled = true
	# The hall light pool follows the board on a free-running 0.25 s sample
	# (combat_atmosphere.gd _process -> _sync_pool_to_board). Begin moves the
	# board from its pre-battle offset to the combat home, so an unpinned capture
	# showed the stale pre-battle centre or the combat centre by wall-clock phase,
	# in either arm. Captures resample it immediately before each draw instead.
	var atmosphere: Control = host.get("_combat_atmosphere") as Control
	var resample_pool: Callable = func() -> void:
		if is_instance_valid(atmosphere): atmosphere.call("_sync_pool_to_board")
	var pin_pool: bool = (_capture or _frame_state_only) and is_instance_valid(atmosphere)
	if pin_pool: RenderingServer.frame_pre_draw.connect(resample_pool)
	var started: int = Time.get_ticks_usec()
	_click(point)
	var handler_us: int = Time.get_ticks_usec() - started
	if native: await RenderingServer.frame_post_draw
	else: await process_frame
	_receipt["begin_frame_us"] = Time.get_ticks_usec() - started
	_receipt["begin_handler_us"] = handler_us
	if _trace:
		_collect_loads()
		_collect_loads_enabled = false
	if native and not DisplayServer.window_is_focused(): _errors.append("Native window lost focus on Begin")
	if str(host._run_state.get("mode", "")) != "combat":
		_errors.append("Begin click did not commit combat")
		if pin_pool: RenderingServer.frame_pre_draw.disconnect(resample_pool)
		return
	if _instrument:
		_receipt["runtime"] = host.runtime_performance_instrumentation_snapshot()
		_receipt["board"] = host.board_view.submission_performance_instrumentation_snapshot()
		_receipt["draw"] = host.board_view.render_instrumentation_snapshot()
		_receipt["queries"] = host._committed_hand_query_diagnostics.duplicate(true)
	if _capture or _frame_state_only:
		var images: Array[Image]
		var frames: Array[Dictionary]
		for index: int in range(FIRST_FRAMES):
			if index > 0:
				if native: await RenderingServer.frame_post_draw
				else: await process_frame
			if _capture: images.append(root.get_texture().get_image())
			# Headless never emits frame_pre_draw; resample where the draw would be.
			if pin_pool and not native: resample_pool.call()
			frames.append(_frame_state(host, atmosphere))
		_receipt["capture_frames"] = frames
		for index: int in range(images.size()):
			_save_capture(images[index], index)
	if pin_pool: RenderingServer.frame_pre_draw.disconnect(resample_pool)
	var saved: Dictionary = Store.read_resumable_checkpoint().get("state", {})
	if saved.get("mode") != "combat" or (saved.get("combat_state", {}) as Dictionary).is_empty():
		_errors.append("Begin did not save a resumable combat")
	_receipt["combat_hash"] = var_to_str(saved.get("combat_state", {})).sha256_text()
	# Ignore the elapsed clock, which is sampled at checkpoint on purpose.
	var stats: Dictionary = saved.get("run_stats", {})
	stats.erase("run_seconds")
	_receipt["checkpoint_hash"] = var_to_str(saved).sha256_text()
	_receipt["analytics_hash"] = _opening_analytics()
	var lock_deadline_msec: int = Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < lock_deadline_msec:
		if not host._animation_lock: break
		await process_frame
	if host._animation_lock: _errors.append("opening sequence did not release input")
	if native and not DisplayServer.window_is_focused(): _errors.append("Native window lost focus during opening")

# On this resume-into-pre-battle path the board HUD budget is still uncaptured
# at Begin (run_scene.gd _freeze_board_hud_budget skips pre_battle and waits for
# the opening hand layout), so the first frames fit the board to a 1 px rect
# (tile width 1) in both arms. That whole board, wall-clock ambient particles
# and animated props included, then draws as a few pixels near the top centre.
# The receipt names that footprint so the proof can compare the rest of the
# frame strictly; a readable board (tile width > 2 px) is never excluded.
func _frame_state(host: Node, atmosphere: Control) -> Dictionary:
	var board: Control = host.board_view
	var tile_width: float = float(board.call("_tile_width"))
	var pool: Variant = (atmosphere.get("_material") as ShaderMaterial).get_shader_parameter("pool_center") if is_instance_valid(atmosphere) else null
	var state: Dictionary = {
		"tile_width": snappedf(tile_width, 0.01),
		"board_position": [snappedf(board.position.x, 0.01), snappedf(board.position.y, 0.01)],
		"pool_center": [snappedf((pool as Vector2).x, 0.0001), snappedf((pool as Vector2).y, 0.0001)] if pool is Vector2 else [],
		"collapsed_board_rect": [],
	}
	if tile_width > COLLAPSED_TILE_WIDTH: return state
	var to_screen: Transform2D = board.get_global_transform_with_canvas()
	var bounds := Rect2()
	var first: bool = true
	var grid: Array = (board.combat_state as Dictionary).get("grid", [])
	for y: int in range(grid.size()):
		for x: int in range((grid[y] as Array).size()):
			var point: Vector2 = to_screen * (board.call("_tile_center", Vector2i(x, y)) as Vector2)
			bounds = Rect2(point, Vector2.ZERO) if first else bounds.expand(point)
			first = false
	if first: return state
	bounds = bounds.grow(COLLAPSED_MARGIN)
	var left: int = clampi(floori(bounds.position.x), 0, SIZE.x)
	var top: int = clampi(floori(bounds.position.y), 0, SIZE.y)
	var right: int = clampi(ceili(bounds.end.x), 0, SIZE.x)
	var bottom: int = clampi(ceili(bounds.end.y), 0, SIZE.y)
	state["collapsed_board_rect"] = [left, top, right - left, bottom - top]
	return state

func _configure_viewport() -> void:
	root.content_scale_size = SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT

func _click(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)

func _collect_loads() -> void:
	var telemetry: Node = root.get_node("PerformanceTelemetry")
	var events: Dictionary = telemetry.take_hitch_events()
	var phases: Dictionary = telemetry.take_hitch_phases()
	if not _collect_loads_enabled: return
	for key: String in events:
		if not key.begins_with("texture_load:"): continue
		var path: String = key.split(":", true, 2)[2]
		if phases.has("preparation:texture:import:" + path) or phases.has("preparation:texture:source_upload:" + path) or phases.has("preparation:texture:source_fallback:" + path):
			continue
		var row: Dictionary = _load_target.get_or_add(path, {"count": 0, "total_us": 0})
		row.count += int(events[key].count)
		row.total_us += int(events[key].total_us)

func _save_capture(image: Image, index: int) -> void:
	var path: String = _output.path_join("arena_first_%d.png" % index)
	if image == null or image.get_size() != SIZE or not is_equal_approx(root.content_scale_factor, 1.0) or image.save_png(path) != OK:
		_errors.append("could not capture 1920x1080 at 100%% UI scale: " + path)
	else:
		print(path)

func _opening_analytics() -> String:
	var events: Array[Dictionary] = Analytics.load_all_events()
	var opening: Array[Dictionary]
	for event: Dictionary in events:
		if str(event.get("combat_id", "")).is_empty(): continue
		for field: String in ["timestamp_utc", "install_id", "session_id", "event_id"]:
			event.erase(field)
		opening.append(event)
	if opening.is_empty() or opening[0].get("event_type") != "combat_started":
		_errors.append("missing combat_started analytics")
	return JSON.stringify(opening).sha256_text()
