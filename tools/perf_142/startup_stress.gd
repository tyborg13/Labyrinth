extends SceneTree

const Assets = preload("res://scripts/asset_loader.gd")
const SceneLoads = preload("res://scripts/menu_run_preload.gd")
const Data = preload("res://scripts/game_data.gd")
const DepthRules = preload("res://scripts/depth_rules.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Paint = preload("res://scripts/dialogue_ink_paint.gd")
const Portrait = preload("res://scripts/dialogue_portrait_paint.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Recent = preload("res://scripts/recent_event_store.gd")
const Runs := 50
const BackoutsPerWorker := 10
const WaitSeconds := 45.0
const MixerDrainUpdates := 2
const MixerDrainUsec := 1000000
const PressOverride := 700142
const LateOverride := 700143
const TitleIdleSeconds := 1.25
const GraphDrain := "InitialRunGraphDrain"
const PaintDrain := "OpeningDialoguePaintDrain"

var _rng := RandomNumberGenerator.new()
var _failure := ""
var _cold_runs := 0
var _mismatches := 0
var _live_cancellations: Dictionary = {}
var _max_abort_usec := 0
var _immediate_retries := 0
var _press_checks := 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_rng.seed = 142
	_run.call_deferred()

func _run() -> void:
	Store.set_storage_path("user://perf142-stress-profile.json")
	Store.set_run_storage_path("user://perf142-stress-save.dat")
	Settings.set_storage_path("user://perf142-stress-settings.json")
	Analytics.set_storage_dir("user://perf142-stress-analytics")
	Recent.set_storage_path("user://perf142-stress-recent.json")
	var settings: Dictionary = Settings.default_settings()
	settings["reduced_motion"] = true
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	root.size = Vector2i(1920, 1080)
	for index: int in range(BackoutsPerWorker):
		Paint._bands.clear()
		Portrait._frame.clear()
		Portrait._portraits.clear()
		await _exercise(7 + index, PaintDrain)
		if not _failure.is_empty(): return
	for index: int in range(Runs):
		if index < BackoutsPerWorker:
			await _exercise(142 + index, GraphDrain)
			if not _failure.is_empty(): return
		await _exercise(7 + index, "", index % 5 == 0)
		if not _failure.is_empty(): return
		if _cold_runs % 10 == 0: print("PERF142 STRESS progress cold_runs=", _cold_runs)
	if not await _wait_until(func() -> bool: return not root.has_node(GraphDrain) and not root.has_node(PaintDrain) and SceneLoads.drain_for_shutdown(self)): return
	await _exercise_press_lifecycle()
	if not _failure.is_empty(): return
	await _mixer_drain()
	print("PERF142 STRESS: PASS cold_runs=%d seed_mismatches=%d paint_in_flight_cancels=%d graph_in_flight_cancels=%d retries_while_reaping=%d max_cover_free_usec=%d press_lifecycle_checks=%d" % [_cold_runs, _mismatches, _live_cancellations.get(PaintDrain, 0), _live_cancellations.get(GraphDrain, 0), _immediate_retries, _max_abort_usec, _press_checks])
	quit()

func _exercise(seed: int, abort_worker: String, change_seed: bool = false) -> void:
	if root.has_node(GraphDrain) or root.has_node(PaintDrain): _immediate_retries += 1
	Store.clear_saved_run()
	Store.save_data(Store.default_data())
	var packed := load("res://scenes/main_menu.tscn") as PackedScene
	var menu: Control = packed.instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	Data._cache.clear()
	Data._enemy_definitions.clear()
	root.set_meta("labyrinth_performance_probe_seed", seed)
	_click(menu.get_node("MenuColumn/StartButton"))
	var cover: Node = root.get_node_or_null("MenuRunTransition")
	if cover == null or not Data._enemy_definitions.is_empty():
		_fail("Public New Run failed to enter with cold enemy definitions")
		return
	if not abort_worker.is_empty() or change_seed:
		var name_to_watch := abort_worker if not abort_worker.is_empty() else GraphDrain
		var worker := await _wait_for_producer(name_to_watch)
		if worker == null: return
		if not abort_worker.is_empty():
			var token: RefCounted = worker.result.cancellation
			for delay_frame: int in range(_rng.randi_range(0, 4)): await process_frame
			var in_flight: bool = is_instance_valid(worker) and worker.task_id >= 0 and not WorkerThreadPool.is_task_completed(worker.task_id)
			_stop_voices(cover)
			var started := Time.get_ticks_usec()
			cover.free()
			_max_abort_usec = maxi(_max_abort_usec, Time.get_ticks_usec() - started)
			if in_flight:
				if not token.is_cancelled():
					_fail("Cover removal did not immediately cancel " + abort_worker)
					return
				_live_cancellations[abort_worker] = int(_live_cancellations.get(abort_worker, 0)) + 1
			if root.gui_disable_input or not Store.load_saved_run().is_empty():
				_fail("Back-out leaked modal input or committed a save")
			return
		seed += 10000
		root.set_meta("labyrinth_performance_probe_seed", seed)
		_mismatches += 1
	if not await _wait_until(func() -> bool: return current_scene != null and current_scene.has_method("initial_presentation_is_ready") and not root.gui_disable_input): return
	var run := current_scene
	if not run.initial_presentation_is_ready() or int(run._run_state.get("seed", -1)) != seed:
		_fail("Wrong prepared seed on public New Run")
		return
	var saved: Dictionary = Store.load_saved_run()
	if saved.get("seed") != run._run_state.get("seed") or saved.get("map_sections") != run._run_state.get("map_sections"):
		_fail("Persisted graph differs from live run")
		return
	_cold_runs += 1
	run.process_mode = Node.PROCESS_MODE_DISABLED
	_stop_voices(run)
	await _mixer_drain()
	run.queue_free()
	await process_frame
	await process_frame

func _exercise_press_lifecycle() -> void:
	Store.clear_saved_run()
	root.remove_meta("labyrinth_performance_probe_seed")
	var idle := _open_title()
	var until := Time.get_ticks_usec() + int(TitleIdleSeconds * 1000000)
	while Time.get_ticks_usec() < until: await process_frame
	if not SceneLoads.has_requested_run_scene(self) or root.has_node(GraphDrain) or root.has_node(PaintDrain):
		_fail("Expected only the release scene request on the idle title")
		return
	_press_checks += 1
	_stop_voices(idle)
	idle.queue_free()
	await process_frame
	var seeds: Array[int]
	for index: int in range(4):
		var menu := _open_title()
		await process_frame
		await process_frame
		var expected: Variant
		if index >= 2:
			expected = PressOverride
			root.set_meta("labyrinth_performance_probe_seed", expected)
		_click(menu.start_button)
		if menu._replacement_confirmation_open: _click(menu.replacement_confirm_button)
		var cover := root.get_node_or_null("MenuRunTransition")
		if cover == null or root.has_node(GraphDrain):
			_fail("New Run must enter its cover before starting the graph")
			return
		if expected == null:
			expected = cover._automatic_seed
			if seeds.has(expected) or expected != cover._press_seed:
				_fail("Automatic press reused a seed or sampled after the press")
				return
		elif index == 2:
			expected = LateOverride
			root.set_meta("labyrinth_performance_probe_seed", expected)
		else:
			expected = cover._automatic_seed
			root.remove_meta("labyrinth_performance_probe_seed")
		if not await _check_committed_press(int(expected), 0): return
		seeds.append(int(expected))
		_press_checks += 1

	root.set_meta("labyrinth_performance_probe_seed", PressOverride)
	Store.clear_saved_run()
	var profile: Dictionary = Store.default_data()
	profile[Store.UMBRA_DEPTH_UNLOCKED_KEY] = 1
	Store.save_data(profile)
	var menu := _open_title()
	menu._on_depth_begin(1)
	if await _check_committed_press(PressOverride, 1): _press_checks += 1

func _check_committed_press(seed: int, depth: int) -> bool:
	if not await _wait_until(func() -> bool:
		return current_scene != null and current_scene.has_method("initial_presentation_is_ready") and not root.gui_disable_input
	): return false
	var run := current_scene
	var saved: Dictionary = Store.load_saved_run()
	if saved["seed"] != seed or run._run_state["seed"] != seed or DepthRules.depth(saved) != depth or saved["map_sections"] != run._run_state["map_sections"]:
		_fail("The pressed seed or depth differed from the live and durable graph")
		return false
	run.process_mode = Node.PROCESS_MODE_DISABLED
	_stop_voices(run)
	await _mixer_drain()
	run.queue_free()
	await process_frame
	await process_frame
	return true

func _open_title() -> Control:
	var packed := load("res://scenes/main_menu.tscn") as PackedScene
	var menu: Control = packed.instantiate()
	root.add_child(menu)
	current_scene = menu
	return menu

func _wait_for_producer(name_to_watch: String) -> Node:
	var path := NodePath(name_to_watch)
	if not await _wait_until(func() -> bool:
		var candidate := root.get_node_or_null(path)
		return candidate != null and not candidate.result.cancellation.is_cancelled()
	): return null
	return root.get_node(path)

func _wait_until(done: Callable) -> bool:
	var start: int = Time.get_ticks_usec()
	while not bool(done.call()):
		if Time.get_ticks_usec() - start >= int(WaitSeconds * 1000000):
			_fail("Timed out waiting for startup, cancellation or retry")
			return false
		await process_frame
	return true

func _click(target: Control) -> void:
	var point := target.get_global_transform_with_canvas() * (target.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		root.push_input(event, true)

func _stop_voices(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D: node.stop()
	for child: Node in node.get_children(): _stop_voices(child)

func _mixer_drain() -> void:
	var started: int = Time.get_ticks_usec()
	var last_mix: int = started - roundi(AudioServer.get_time_since_last_mix() * 1000000.0)
	var updates: int = 0
	while updates < MixerDrainUpdates and Time.get_ticks_usec() - started < MixerDrainUsec:
		await process_frame
		var mix: int = Time.get_ticks_usec() - roundi(AudioServer.get_time_since_last_mix() * 1000000.0)
		if mix - last_mix >= 1000:
			last_mix = mix
			updates += 1

func _fail(message: String) -> void:
	_failure = message
	push_error("PERF142 STRESS: " + message)
	quit(1)
