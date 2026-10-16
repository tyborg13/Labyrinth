extends Node

const Fixture = preload("res://tools/demo_clips/fixture.gd")
const Instrument = preload("res://tools/demo_clips/instrument.gd")
const Clock = preload("res://tools/demo_clips/clock.gd")
const Trace = preload("res://tools/demo_clips/trace.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Parallel = preload("res://scripts/parallel_runtime.gd")
const CaptureSettings = preload("res://tools/demo_clips/capture_settings.gd")
const DIRECTOR_PATH: String = "res://tools/demo_clips/clips.json"
# Non-perceptible watchdogs and fixture preparation budget.
const MAX_CLIP_FRAMES: int = 5400
const PREPARE_FRAMES: int = 30
var clock := Clock.new()
var trace := Trace.new()
var scene: Node
var clip: Dictionary
var director: Dictionary
var fixture: Dictionary
var errors: Array[String]
var directory: String
var recording_director_sha256: String
var start_frame: int = -1
var headless: bool = false
var finished: bool = false
var probe: bool = false

func _ready() -> void:
	if not Engine.get_write_movie_path().is_empty():  # engine flags never appear in get_cmdline_args()
		var capture_settings: Dictionary = CaptureSettings.snapshot()
		print("DEMO CAPTURE SETTINGS ", JSON.stringify(capture_settings))
		if not CaptureSettings.verified(capture_settings):
			push_error("Movie Maker quality override must be loaded before startup")
			get_tree().quit(1)
			return
	Parallel.apply_from_environment()
	headless = DisplayServer.get_name() == "headless"
	var clip_id: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--clip="): clip_id = arg.trim_prefix("--clip=")
		if arg.begins_with("--output="): directory = arg.trim_prefix("--output=")
		if arg.begins_with("--recording-director-sha256="): recording_director_sha256 = arg.trim_prefix("--recording-director-sha256=")
		if arg == "--probe": probe = true
	assert(not directory.is_empty(), "--output is required")
	if not directory.is_absolute_path(): directory = ProjectSettings.globalize_path("res://" + directory.trim_prefix("res://"))
	DirAccess.make_dir_recursive_absolute(directory)
	director = JSON.parse_string(FileAccess.get_file_as_string(DIRECTOR_PATH))
	for reel: Dictionary in director["reels"]:
		for item: Dictionary in reel["clips"]:
			if item["id"] == clip_id: clip = item
	assert(not clip.is_empty(), "Unknown --clip")
	seed(int(director["defaults"]["seed"]))
	Settings.set_storage_path("user://demo_settings.json")
	Progression.set_storage_path("user://demo_progression.json")
	Progression.set_run_storage_path("user://demo_run.save")
	var settings: Dictionary = Settings.default_settings()
	settings["music_volume"] = director["defaults"]["music_volume"]
	settings["combat_speed"] = clip.get("combat_speed", director["defaults"]["combat_speed"])
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	Settings.save_settings(settings)
	get_window().size = Vector2i(1920, 1080)
	get_window().content_scale_size = Vector2i(1920, 1080)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	if not headless: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	get_tree().process_frame.connect(_tick)
	trace.clock = clock
	trace.directory = directory
	clock.observer = trace.observe
	scene = Instrument.install(clock)
	add_child(scene)
	call_deferred("_run")

func _tick() -> void:
	# No pixels or renderer proof are claimed in validation. Satisfy the prior
	# frame's completion fences, including the game's deferred analytics queue.
	# Movie Maker receives this signal exclusively from the real renderer.
	if headless: RenderingServer.frame_post_draw.emit()
	trace.flush()
	clock.tick()
	if clock.frame > MAX_CLIP_FRAMES and not finished:
		print("DEMO WATCHDOG scale=", Engine.time_scale, " clock=", clock.visual_usec, " lock=", scene.get("_animation_lock"), " scope=", scene.get("_combat_pacing").get("_scope"), " stop=", scene.get("_combat_pacing").hit_stop.active, " timers=", clock.bank.get("_peak_pending").size())
		errors.append("clip watchdog: input/presentation did not settle")
		_finish()

func _run() -> void:
	fixture = Fixture.build(clip, director["defaults"])
	errors.append_array(Fixture.validate(fixture, clip))
	scene.call("_load_run_state", fixture["run"])
	scene.call("_reset_card_resolution")
	scene.set("_animation_lock", false)
	scene.call("_ensure_sfx_bank")
	clock.bank = scene.get("_sfx_bank")
	clock.bank.set_test_clock(float(clock.usec) / 1000.0)
	trace.bank = clock.bank
	clock.bank.cue_requested.connect(trace.cue)
	await _frames(PREPARE_FRAMES)
	var staged_fixture: Dictionary = fixture.duplicate(false)
	staged_fixture["state"] = scene.get("_combat_state")
	errors.append_array(Fixture.validate(staged_fixture, clip))
	if scene.get("_settings")["combat_speed"] != clip.get("combat_speed", director["defaults"]["combat_speed"]): errors.append("combat speed")
	if float(scene.get("_settings")["music_volume"]) != 0.0: errors.append("music volume")
	for key: String in ["master_volume", "sfx_volume", "reduced_motion"]:
		if scene.get("_settings")[key] != Settings.default_settings()[key]: errors.append("changed game default: " + key)
	start_frame = clock.frame
	trace.active = true
	trace.mark("staged", {"state": scene.get("_combat_state"), "speed": scene.get("_settings")["combat_speed"]})
	await _frames(roundi(float(director["defaults"]["pre_roll_s"]) * Clock.FPS))
	for action: Array in clip["actions"]:
		if not errors.is_empty() or finished: break
		trace.mark("action", {"action": action})
		match str(action[0]):
			"play": await _play(action)
			"end_turn": await _end_turn()
			"hover": await _hover(action)
		trace.mark("action_complete", {"action": action, "state": scene.get("_combat_state")})
	await _settle()
	await _frames(roundi(float(director["defaults"]["tail_s"]) * Clock.FPS))
	if probe and not headless:
		await RenderingServer.frame_post_draw
		var path: String = directory.path_join(str(clip["id"]) + ".png")
		get_viewport().get_texture().get_image().save_png(path)
		print(path)
	_finish()

func _play(action: Array) -> void:
	var before: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	var index: int = before["deck"]["hand"].find(action[1])
	if index < 0:
		errors.append("requested card missing: " + str(action[1]))
		return
	await scene.call("_on_card_pressed", index)
	var target: Vector2i = fixture["hero"] + Fixture.offset(action[2])
	if clip["id"] == "trap_hero" and not (scene.get("_pending_target_tiles") as Array).has(target):
		target = fixture["hero"] + Fixture.offset(clip["traps"][0][1])
		trace.mark("director_fallback", {"target": target})
	await scene.call("_on_board_tile_clicked", target)
	if bool(scene.call("_orientation_pending")):
		if action.size() < 4 or action[3] != "line toward +x":
			errors.append("orientation not authored")
			return
		await scene.call("_on_board_tile_clicked", target + Vector2i.RIGHT)
	# Multi-step cards can retain the chosen enemy for their next targeted step.
	if int(scene.get("_selected_card_index")) >= 0 and (scene.get("_pending_target_tiles") as Array).has(target):
		await scene.call("_on_board_tile_clicked", target)
	await _settle()
	var after: Dictionary = scene.get("_combat_state")
	if int(scene.get("_selected_card_index")) >= 0 or after["deck"]["hand"].has(action[1]): errors.append("card did not resolve: " + str(action[1]))
	if clip["id"] == "trap_hero" and not after["traps"].is_empty(): errors.append("hero did not trigger lightning trap")
	trace.mark("card_resolved", {"card": action[1], "resolved": not after["deck"]["hand"].has(action[1])})

func _end_turn() -> void:
	var turn: int = int(scene.get("_combat_state")["turn"])
	var button: Button = scene.find_child("PassPreviewChip", true, false) as Button
	if button == null or button.disabled:
		errors.append("end-turn button unavailable")
		return
	button.pressed.emit()
	await _settle()
	var state: Dictionary = scene.get("_combat_state")
	if int(state["turn"]) <= turn: errors.append("end turn produced no following hero turn")
	if clip["id"] == "trap_enemy" and not state["traps"].is_empty(): errors.append("crawler did not cross lightning trap")
	if clip["id"] == "weaver_thornwall":
		if turn == 1:
			var cast_seen: bool = trace.frames.any(func(frame: Dictionary) -> bool: return frame["effect"].get("en04_mechanic", "") == "grow_bramble")
			if state["terrain"].is_empty() or not cast_seen: errors.append("Thornwall did not cast and create bramble")
		for enemy: Dictionary in state["enemies"]:
			if enemy["type"] == "briar_weaver" and enemy.get("intent", {}).is_empty(): errors.append("Weaver following intent is empty")

func _hover(action: Array) -> void:
	var board: Control = scene.get("board_view")
	var found: bool = false
	for enemy: Dictionary in scene.get("_combat_state")["enemies"]:
		if enemy["type"] != action[1]: continue
		found = true
		var position: Vector2 = board.get_global_transform_with_canvas() * board.call("world_position_for_tile", enemy["pos"])
		var motion := InputEventMouseMotion.new()
		motion.position = position
		motion.global_position = position
		if not headless: Input.warp_mouse(position)
		get_viewport().push_input(motion, true)
		await get_tree().process_frame
		var rows: Array = board.call("_enemy_intent_rows_for_display", enemy, enemy.get("intent", {}))
		if board.get("_hover_tile") != enemy["pos"]: errors.append("real mouse hover did not reach the actor tile")
		if rows.is_empty(): errors.append("Weaver hover did not expose a non-empty board intent")
		trace.mark("mouse_hover", {"actor": action[1], "tile": enemy["pos"], "intent_rows": rows})
	if not found: errors.append("hover actor missing")
	await _frames(roundi(float(action[2]) * Clock.FPS) - 1)

func _settle() -> void:
	while not finished:
		var busy: bool = bool(scene.get("_animation_lock")) or bool(scene.get("_player_popup_timeline_active"))
		busy = busy or not clock.bank.get("_peak_pending").is_empty()
		for player: AudioStreamPlayer in clock.bank.players:
			if player.stream != null and int(player.get_meta("until", 0)) > clock.bank.now_ms(): busy = true
		if not busy: break
		await get_tree().process_frame

func _frames(count: int) -> void:
	for index: int in range(count):
		if finished: return
		await get_tree().process_frame

func _finish() -> void:
	if finished: return
	finished = true
	trace.flush()
	var report: Dictionary = {"clip": clip.get("id"), "fps": Clock.FPS, "start_frame": start_frame, "end_frame": clock.frame,
		"events": trace.events, "frames": trace.frames, "errors": errors, "headless": headless,
		"fixture_valid": Fixture.validate(fixture, clip).is_empty(),
		# Pipeline launches bind this field to capture inputs, excluding captions.
		# Direct diagnostic launches retain the raw source hash as provenance.
		"director_sha256": recording_director_sha256 if not recording_director_sha256.is_empty() else FileAccess.get_sha256(DIRECTOR_PATH)}
	var file := FileAccess.open(directory.path_join("events.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("DEMO CLIP %s: %s (%d frames)" % [clip.get("id"), "PASS" if errors.is_empty() else "FAIL", clock.frame - start_frame])
	for error: String in errors: print("DEMO ERROR %s: %s" % [clip.get("id"), error])
	get_tree().quit(0 if errors.is_empty() else 1)

func _exit_tree() -> void:
	clock.observer = Callable()
	clock.bank = null
	trace.bank = null
	trace.clock = null
	Clock.current = null
	Clock.badges = null
