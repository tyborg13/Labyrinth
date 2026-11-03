extends "res://tests/protagonist_cutout_gameplay_probe.gd"

## Uses real movement/card/Pass inputs and production animation clocks.
## The PNG sequence and timestamped HTML player require no capture dependency.
const PROOF_SEED: int = 260908
const PROOF_FRAME_INTERVAL_USEC: int = 100000
const PROOF_ACTION_TIMEOUT_USEC: int = 30000000
const PROOF_IDLE_FRAMES: int = 4
const Settings = preload("res://scripts/settings_store.gd")
var _proof_output: String
var _mode: String
var _frames: Array[Dictionary]
var _sources: Dictionary = {}
var _started_usec: int
var _last_capture_usec: int = 0

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_mode = Settings.hero_facing_mode(Settings.default_settings())
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--seed" in args and int(args[args.find("--seed") + 1]) != PROOF_SEED:
		push_error("This matched proof uses the named fixture seed %d" % PROOF_SEED)
		quit(1)
		return
	_proof_output = "user://probes/hero_facing/" + _mode
	if "--check-only" in args:
		print("HERO FACING WINDOWED PROBE PLAN: PASS (seed %d, %s, 1920x1080, 100%%)" % [PROOF_SEED, _mode])
		quit(0)
		return
	if DisplayServer.get_name() == "headless":
		push_error("Recording requires the design owner's windowed renderer; use --check-only for headless validation")
		quit(1)
		return
	_capture = true
	root.content_scale_factor = 1.0
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = SIZE
	root.size = SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_proof_output))
	ProgressionStore.set_storage_path("user://hero_facing_probe_profile.json")
	ProgressionStore.set_run_storage_path("user://hero_facing_probe_run.save")
	ProgressionStore.clear_saved_run()
	var settings: Dictionary = Settings.default_settings()
	settings["hero_facing"] = _mode
	settings["display_mode"] = "windowed"
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	var surface := SubViewport.new()
	surface.size = SIZE
	surface.disable_3d = true
	surface.world_2d = World2D.new()
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	_render_viewport = surface
	_instance = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	surface.add_child(_instance)
	await _settle()
	_board = _instance.get("board_view")
	await _fixture(Vector2i(3, 4), Vector2i(4, 3), false, ["quick_stab", "brace", "bone_dart", "patch_up", "sidestep_slash"], 24, [Vector2i(2, 3)])
	_instance.get("_settings")["hero_facing"] = _mode
	var run: Dictionary = _instance.get("_run_state")
	var state: Dictionary = run["combat_state"]
	var queue: Array
	for enemy: Dictionary in state["enemies"]:
		enemy["intent"] = {"id": "skitter_strike", "name": "Skitter Strike", "time": 5, "actions": [{"type": "melee", "damage": 4, "range": 1}]}
		queue.append(_instance.get("_combat_engine")._enemy_actor_entry(state, enemy, int(enemy["id"]), int(enemy["id"])))
	state["turn_queue"] = queue
	_instance.call("_sync_combat_state_from_run")
	_instance.call("_refresh_ui")
	await _settle()
	_started_usec = Time.get_ticks_usec()
	await _still("00_start")
	await _instance.call("_on_board_tile_clicked", Vector2i(3, 4))
	_instance.call("_on_board_tile_clicked", Vector2i(3, 3))
	await _watch("move_away")
	_assert(_player_pos() == Vector2i(3, 3), "Real movement reaches its rear-facing endpoint")
	_assert(_snapshot()["facing"] == ("rear" if _mode == "persist" else "front"), "Rear idle matches selected A/B mode")
	await _still("01_rear_idle")
	await _instance.call("_on_card_pressed", 0)
	_instance.call("_on_board_tile_clicked", Vector2i(4, 3))
	await _watch("targeted_card")
	_assert(_snapshot()["facing"] == "front" and bool(_snapshot()["mirrored"]) == (_mode == "persist"), "Targeted card idle matches A/B mode")
	await _still("02_targeted_idle")
	_instance.call("_on_pass_turn_pressed")
	await _watch("enemy_phase")
	_assert(_sources.has("enemy_1") and _sources.has("enemy_2"), "Actual Pass takes hits from two source units")
	await _still("03_two_sources_idle")
	_write_recording()
	for error: String in _errors: push_error(error)
	print("HERO FACING WINDOWED PROBE: " + ("PASS" if _errors.is_empty() else "FAIL"))
	print(ProjectSettings.globalize_path(_proof_output))
	_instance.queue_free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)

func _watch(label: String) -> void:
	var start: int = Time.get_ticks_usec()
	var idle: int = 0
	while Time.get_ticks_usec() - start < PROOF_ACTION_TIMEOUT_USEC:
		await process_frame
		await RenderingServer.frame_post_draw
		var effect: Dictionary = _board.presentation.get("effect", {})
		if (_board.presentation.get("impact_actor_keys", []) as Array).has("player") and str(effect.get("actor_key", "")).begins_with("enemy_"):
			_sources[effect["actor_key"]] = true
		if Time.get_ticks_usec() - _last_capture_usec >= PROOF_FRAME_INTERVAL_USEC: _capture_frame(label)
		idle = 0 if bool(_instance.get("_animation_lock")) else idle + 1
		if idle >= PROOF_IDLE_FRAMES: return
	_assert(false, "Timed out waiting for real input to unlock: " + label)

func _capture_frame(label: String, filename: String = "") -> void:
	var path: String = filename if not filename.is_empty() else "frame_%04d.png" % _frames.size()
	var image: Image = _render_viewport.get_texture().get_image()
	_assert(image.get_size() == SIZE, "Recording stays at 1920x1080")
	_assert(image.save_png(_proof_output.path_join(path)) == OK, "Capture writes " + path)
	_frames.append({"file": path, "label": label, "seconds": float(Time.get_ticks_usec() - _started_usec) / 1000000.0, "hero": _snapshot()})
	_last_capture_usec = Time.get_ticks_usec()

func _still(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	_capture_frame(label, label + ".png")

func _write_recording() -> void:
	FileAccess.open(_proof_output.path_join("manifest.json"), FileAccess.WRITE).store_string(JSON.stringify({"seed": PROOF_SEED, "hero_facing": _mode, "size": [1920,1080], "ui_scale": 1.0, "frames": _frames, "hit_sources": _sources.keys(), "errors": _errors}, "\t"))
	var html: String = '<!doctype html><meta charset="utf-8"><title>Hero facing recording</title><style>body{margin:0;background:#000}img{width:100vw;height:100vh;object-fit:contain}</style><img id="frame"><script>const frames=%s;let i=0;function play(){document.getElementById("frame").src=frames[i].file;const next=(i+1)%%frames.length;const delay=next?1000*(frames[next].seconds-frames[i].seconds):1000;i=next;setTimeout(play,Math.max(1,delay));}play();</script>' % JSON.stringify(_frames)
	FileAccess.open(_proof_output.path_join("recording.html"), FileAccess.WRITE).store_string(html)
