extends SceneTree

# Director diagnosis (not committed): frame time in a Warband fight versus an ordinary fight.
const Fixture = preload("res://tools/warband_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const SIZE := Vector2i(1920, 1080)
const IDLE_SECONDS: float = 4.0
const SWEEP_SECONDS: float = 6.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Settings.set_storage_path("user://perf-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	DisplayServer.window_set_size(SIZE)
	root.size = SIZE
	root.content_scale_size = SIZE
	for case: Dictionary in [{"name": "ordinary"}, {"name": "warband_air", "biome": "air", "tier": 2}, {"name": "warband_lightning", "biome": "lightning", "tier": 3}]:
		await _measure(case)
	quit()

func _measure(case: Dictionary) -> void:
	var engine := Run.new()
	var combat := Combat.new()
	var state: Dictionary = engine.create_new_run(Fixture.FIXTURE_SEED, Store.default_data())
	if case.has("biome"):
		state = Fixture.build(engine, combat, state, {"warband_biome": case["biome"], "warband_tier": case["tier"]})
	else:
		var moves: Array = engine.available_moves(state)
		state = engine.move_to_room(state, moves[0])
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.call("_load_run_state", state)
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	await create_timer(1.5).timeout
	var idle: Dictionary = await _sample(IDLE_SECONDS, Callable())
	var board: Control = scene.get("board_view")
	var rect: Rect2 = board.get_global_rect()
	var sweep: Dictionary = await _sample(SWEEP_SECONDS, func(t: float) -> void:
		var point := Vector2(rect.position.x + rect.size.x * (0.2 + 0.6 * fmod(t * 0.35, 1.0)), rect.position.y + rect.size.y * (0.3 + 0.4 * (0.5 + 0.5 * sin(t * 2.3))))
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		root.push_input(motion, true))
	print("PERF %s mode=%s idle: %s | sweep: %s" % [case["name"], str(state.get("mode", "")), _fmt(idle), _fmt(sweep)])
	scene.queue_free()
	await process_frame
	await process_frame

func _sample(seconds: float, step: Callable) -> Dictionary:
	var frames: Array[float] = []
	var process: Array[float] = []
	var draws: Array[float] = []
	var started: int = Time.get_ticks_usec()
	var last: int = started
	while Time.get_ticks_usec() - started < int(seconds * 1000000.0):
		if step.is_valid(): step.call(float(Time.get_ticks_usec() - started) / 1000000.0)
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames.append(float(now - last) / 1000.0)
		last = now
		process.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	frames.sort()
	process.sort()
	draws.sort()
	return {"frames": frames.size(), "fps": float(frames.size()) / seconds, "frame_p50": frames[frames.size() / 2], "frame_p95": frames[int(frames.size() * 0.95)], "frame_max": frames[-1], "process_p50": process[process.size() / 2], "process_p95": process[int(process.size() * 0.95)], "draws_p50": draws[draws.size() / 2]}

func _fmt(sample: Dictionary) -> String:
	return "fps %.1f frame p50 %.1f p95 %.1f max %.1f ms; process p50 %.1f p95 %.1f ms; draws %d" % [sample["fps"], sample["frame_p50"], sample["frame_p95"], sample["frame_max"], sample["process_p50"], sample["process_p95"], int(sample["draws_p50"])]
