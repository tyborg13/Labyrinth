extends SceneTree
## Native timing only; --validate builds fixtures headlessly, never claims renderer proof.
signal census_finished
const ViewportCheck = preload("res://tools/hitch_census/viewport.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Recent = preload("res://scripts/recent_event_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Policy = preload("res://tools/hitch_census/whole_policy.gd")
const Trace = preload("res://tools/hitch_census/trace.gd")
const Fixtures = preload("res://tools/hitch_census/fixtures.gd")
const Tour = preload("res://tools/hitch_census/tour.gd")
const DemoSession = preload("res://tools/hitch_census/demo/session.gd")
const SETTLE_FRAMES: int = 8
const ACTION_GUARD_SECONDS: float = 60.0
const CALIBRATION_SECONDS: float = 10.0
const WHOLE_STARTING_HEALTH: int = 9999
const FIGHT_DECISION_LIMIT: int = 400
var starting_health: int = WHOLE_STARTING_HEALTH
var no_voluntary_ends: bool = true
var fight_key: String = ""
var fight_decisions: int = 0
var output: String
var driver_name: String = "whole"
var run_seed: int = 83
var seconds: float = 900.0
var stop_after: int = 0
var first_boss: bool = false
var headless_smoke: bool = false
var validate_only: bool = false
var validate_tour: bool = false
var trace: Node
var scene: Node
var policy: RefCounted
var rng := RandomNumberGenerator.new()
var started_us: int
var finished: bool = false
var startup_viewport: Dictionary = {}
var coverage: Dictionary = {}
var errors: Array[String]
var decisions: FileAccess
var calibration_intervals: Array[float]
var calibration_previous_us: int = 0

func _initialize() -> void:
	Runtime.apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg: String in args:
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg.begins_with("--driver="): driver_name = arg.trim_prefix("--driver=")
		elif arg.begins_with("--seed="): run_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--seconds="): seconds = float(arg.trim_prefix("--seconds="))
		elif arg.begins_with("--stop-after="): stop_after = int(arg.trim_prefix("--stop-after="))
		elif arg == "--first-boss": first_boss = true
		elif arg.begins_with("--starting-health="): starting_health = int(arg.trim_prefix("--starting-health="))
		elif arg == "--allow-voluntary-ends": no_voluntary_ends = false
		elif arg == "--headless-smoke": headless_smoke = true
		elif arg == "--validate": validate_only = true
		elif arg == "--validate-tour": validate_only = true; validate_tour = true
		else:
			push_error("HITCH CENSUS: unknown argument " + arg)
			quit(2)
			return
	_start.call_deferred()

func _start() -> void:
	if output.is_empty() or (DisplayServer.get_name() == "headless" and not validate_only and not headless_smoke):
		push_error("HITCH CENSUS: output required; measurement requires real renderer")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	Store.set_storage_path(output.path_join("progression.json"))
	Store.set_run_storage_path(output.path_join("run.save"))
	Settings.set_storage_path(output.path_join("settings.json"))
	Analytics.set_storage_dir(output.path_join("analytics"))
	Recent.set_storage_path(output.path_join("recent.json"))
	var settings: Dictionary = Settings.default_settings()
	settings["combat_speed"] = Settings.COMBAT_NORMAL
	settings["ui_scale"] = 1.15
	settings["display_mode"] = "windowed"
	settings["edge_smoothing"] = "off"
	Settings.save_settings(settings)
	Store.save_data(Store.default_data() if driver_name == "demo" else Tutorial.complete_tutorial(Store.default_data()))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 800)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_factor = 1.15
	root.set_meta("labyrinth_performance_probe_seed", run_seed)
	Engine.max_fps = 0
	Engine.time_scale = 1.0
	OS.low_processor_usage_mode = false
	if not validate_only: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	decisions = FileAccess.open(output.path_join("decisions.jsonl"), FileAccess.WRITE)
	trace = Trace.new()
	root.add_child(trace)
	trace.begin(output.path_join("frames.jsonl"), run_seed, whole_settings() if driver_name == "whole" else {})
	if headless_smoke:
		var metadata := FileAccess.open(output.path_join("run.json"), FileAccess.WRITE)
		metadata.store_string(JSON.stringify({"driver": driver_name, "seed": run_seed, "profile": "headless", "cache": "unmeasured", "trace_mode": "on", "whole_settings": whole_settings()}, "\t"))
		metadata.close()
	started_us = Time.get_ticks_usec()
	# Let the pre-window override and pending resize reach the renderer once.
	if not validate_only and not headless_smoke: await RenderingServer.frame_post_draw
	var viewport_check_started: int = Time.get_ticks_usec()
	startup_viewport = ViewportCheck.capture(root)
	trace.record_driver_cost("startup_viewport_verification", viewport_check_started)
	startup_viewport.merge(ViewportCheck.validate(startup_viewport))
	var viewport_file := FileAccess.open(output.path_join("viewport.json"), FileAccess.WRITE)
	viewport_file.store_string(JSON.stringify(startup_viewport, "\t"))
	viewport_file.close()
	print("HITCH VIEWPORT: " + JSON.stringify(startup_viewport))
	if not str(startup_viewport["failure"]).is_empty():
		errors.append(str(startup_viewport["failure"]))
		finish("viewport_rejected")
		return
	if headless_smoke:
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	if validate_only:
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
		await _validate()
		return
	if driver_name == "demo":
		var session := DemoSession.new()
		session.host = self
		root.add_child(session)
		session.run()
	elif driver_name == "tour":
		var tour := Tour.new()
		await tour.run(self)
		finish("tour_complete")
	elif driver_name == "calibration":
		await _enter_scene("res://scenes/run_scene.tscn")
		await hold(2.0)
		RenderingServer.frame_post_draw.connect(_calibration_frame)
		await hold(CALIBRATION_SECONDS)
		RenderingServer.frame_post_draw.disconnect(_calibration_frame)
		finish("calibration_complete")
	else:
		await _whole()

func _process(_delta: float) -> bool:
	if started_us > 0 and not finished and float(Time.get_ticks_usec() - started_us) / 1000000.0 >= seconds:
		finish("time_limit")
	return false

func _enter_scene(path: String) -> void:
	if is_instance_valid(current_scene):
		current_scene.queue_free()
		await process_frame
	scene = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene

func mark(label: String, stage: String = "action") -> void:
	if finished: return
	var driver_started: int = Time.get_ticks_usec()
	trace.mark(label, stage)
	decisions.store_line(JSON.stringify({"decision": trace.decision, "seed": run_seed, "action": label, "phase": stage, "frame": Engine.get_process_frames()}))
	coverage[label] = int(coverage.get(label, 0)) + 1
	trace.record_driver_cost("decision_log", driver_started)

func hold(duration: float) -> void:
	var until: int = Time.get_ticks_usec() + int(duration * 1000000.0)
	while not finished and Time.get_ticks_usec() < until: await process_frame

func settle() -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame
	var start: int = Time.get_ticks_usec()
	while is_instance_valid(scene) and bool(scene.get("_animation_lock")) and float(Time.get_ticks_usec() - start) / 1000000.0 < ACTION_GUARD_SECONDS:
		await process_frame

func _whole() -> void:
	await _enter_scene("res://scenes/run_scene.tscn")
	var initial_state: Dictionary = scene.get("_run_state")
	initial_state["player_max_hp"] = starting_health
	initial_state["player_hp"] = starting_health
	scene.call("_save_run_progress")
	rng.seed = run_seed
	policy = Policy.new()
	policy.rng = rng
	policy.no_embrace = no_voluntary_ends
	while not finished:
		await settle()
		if finished: return
		var state: Dictionary = scene.get("_run_state")
		var mode: String = str(state.get("mode", ""))
		var room: Dictionary = scene.get("_run_engine").room_metadata(state, state.get("current_room", Vector2i.ZERO))
		var section: int = int(room.get("section_index", 0))
		coverage["section:" + str(section)] = true
		if mode == "combat":
			var key: String = str(section) + ":" + str(state.get("current_room"))
			if key != fight_key:
				fight_key = key
				fight_decisions = 0
			if fight_decisions >= FIGHT_DECISION_LIMIT:
				finish("fight_limit")
				return
		coverage["room:" + str(room.get("special_type", room.get("mystery_type", room.get("type", "unknown"))))] = true
		if first_boss and int(room.get("section_index", 0)) > 0:
			finish("first_boss_complete")
			return
		if mode in ["victory", "defeat", "embrace"]:
			finish(mode)
			return
		if stop_after > 0 and trace.decision >= stop_after:
			finish("replay_point")
			return
		var driver_started: int = Time.get_ticks_usec()
		var offers: Array = policy.offers(scene)
		trace.record_driver_cost("legal_offers", driver_started)
		if offers.is_empty():
			await process_frame
			continue
		driver_started = Time.get_ticks_usec()
		var choice: Dictionary = policy.choose(scene, offers)
		trace.record_driver_cost("policy_choose", driver_started)
		mark(str(choice.get("kind", "unknown")), mode)
		driver_started = Time.get_ticks_usec()
		var logged: Dictionary = choice.duplicate()
		logged.erase("control")
		logged.erase("object")
		decisions.store_line(JSON.stringify({"decision": trace.decision, "offer": logged}))
		trace.record_driver_cost("decision_log", driver_started)
		if mode == "combat": fight_decisions += 1
		policy.dispatch(scene, choice)

func _calibration_frame() -> void:
	var now: int = Time.get_ticks_usec()
	if calibration_previous_us > 0: calibration_intervals.append(float(now - calibration_previous_us) / 1000.0)
	calibration_previous_us = now

func _validate() -> void:
	var builder := Fixtures.new()
	for kind: String in Tour.SCENARIOS:
		print("HITCH FIXTURE: " + kind)
		var state: Dictionary = builder.make(kind, run_seed)
		if state.is_empty(): errors.append(kind + ": " + builder.census_error)
		else: coverage["fixture:" + kind] = {"mode": state.get("mode"), "seed": state.get("seed")}
	builder.free()
	if validate_tour:
		var tour := Tour.new()
		await tour.run(self)
	# This exercises the observer's JSONL writer with dummy timing, never native proof.
	for index: int in range(5): await process_frame
	print("HITCH CENSUS HEADLESS: fixtures=%d errors=%d (not renderer proof)" % [coverage.size(), errors.size()])
	finish("headless_validation")

func finish(outcome: String) -> void:
	if finished: return
	finished = true
	census_finished.emit()
	var stats: Dictionary = trace.finish()
	var result: Dictionary = {"driver": driver_name, "seed": run_seed, "whole_settings": whole_settings() if driver_name == "whole" else {}, "viewport": startup_viewport, "outcome": outcome, "coverage": coverage, "errors": errors, "trace": stats, "wall_seconds": float(Time.get_ticks_usec() - started_us) / 1000000.0, "settings": Settings.load_settings(), "size": str(root.size), "ui_scale": root.content_scale_factor, "calibration_intervals_ms": calibration_intervals, "vsync": DisplayServer.window_get_vsync_mode() if not validate_only else -1}
	FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	decisions.close()
	print("HITCH CENSUS RESULT: %s outcome=%s frames=%d errors=%d" % [driver_name, outcome, stats.frames, errors.size()])
	quit(0 if errors.is_empty() else 1)

func whole_settings() -> Dictionary:
	return {"starting_health": starting_health, "no_embrace_abandonment_voluntary_ends": no_voluntary_ends, "time_scale": Engine.time_scale, "combat_speed": Settings.COMBAT_NORMAL, "fight_decision_limit": FIGHT_DECISION_LIMIT, "policy": "legal_forward_attack_first_v6"}
