extends "res://tools/qa110/whole_run.gd"
## Use the whole-run decisions and same settle gate on a native renderer.

const PROOF_SIZE := Vector2i(1920, 1080)
var native_output: String
var capture_started: bool

func _initialize() -> void:
	Runtime.apply_from_environment()
	OS.set_environment("LABYRINTH_PROBE_WINDOW", "1")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): native_output = arg.trim_prefix("--out=")
		elif arg.begins_with("--seed="): hunt_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--decision="): stop_after = int(arg.trim_prefix("--decision="))
		elif arg == "--no-embrace": no_embrace = true
	if native_output.is_empty() or stop_after <= 0 or DisplayServer.get_name() == "headless":
		push_error("QA110 native replay needs --out=, --decision= and a windowed renderer")
		quit(2)
		return
	call_deferred("_boot_native")

func _boot_native() -> void:
	output = native_output
	DirAccess.make_dir_recursive_absolute(output)
	transcript = FileAccess.open(output.path_join("trace.jsonl"), FileAccess.WRITE)
	if transcript == null:
		push_error("QA110 native replay cannot write trace.jsonl")
		quit(2)
		return
	Store.set_storage_path(output.path_join("progression.json"))
	Store.set_run_storage_path(output.path_join("run.save"))
	Settings.set_storage_path(output.path_join("settings.json"))
	Analytics.set_storage_dir(output.path_join("analytics"))
	RecentEvents.set_storage_path(output.path_join("recent_events.json"))
	var settings: Dictionary = Settings.default_settings()
	settings.merge({"ui_scale": 1.0, "display_mode": "windowed", "combat_speed": Settings.COMBAT_FASTEST}, true)
	Settings.save_settings(settings)
	rng.seed = hunt_seed
	root.set_meta("labyrinth_performance_probe_seed", hunt_seed)
	root.size = PROOF_SIZE
	root.content_scale_size = PROOF_SIZE
	Engine.max_fps = SAMPLE_FPS
	Engine.time_scale = HEADLESS_TIME_SCALE
	await _start()

func _tick() -> void:
	if capture_started: return
	super._tick()
	if observed_decision != stop_after or finished: return
	capture_started = true
	busy = true
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	var path: String = output.path_join("seed-%d-decision-%d.png" % [hunt_seed, stop_after])
	if picture == null or picture.get_size() != PROOF_SIZE or picture.save_png(path) != OK:
		push_error("QA110 failed to capture 1920x1080 PNG")
		quit(2)
		return
	print(path)
	_finish("replay_point")
