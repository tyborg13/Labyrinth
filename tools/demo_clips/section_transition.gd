extends Node
## Separate demo extension: never rewrites the protected demo-01 director data.
const Suite = preload("res://tests/suites/section_transition_suite.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Instrument = preload("res://tools/demo_clips/instrument.gd")
const Clock = preload("res://tools/demo_clips/clock.gd")
const CaptureSettings = preload("res://tools/demo_clips/capture_settings.gd")
const MANIFEST: String = "res://tools/demo_clips/section_transition.json"
# Invisible staging and deadlock detection budgets.
const PREPARE_FRAMES: int = 30
const MAX_CLIP_FRAMES: int = 1800
var clock := Clock.new()
var scene: Node
var config: Dictionary
var clip: Dictionary
var directory: String
var failures: Array[String]
var events: Array[Dictionary]
var done: bool = false
var start_frame: int
const CURSOR_SUPPRESSION_OWNER: String = "section_transition_demo"

func _ready() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	if not Engine.get_write_movie_path().is_empty():
		var settings: Dictionary = CaptureSettings.snapshot()
		print("DEMO CAPTURE SETTINGS ", JSON.stringify(settings))
		if not CaptureSettings.verified(settings): failures.append("Movie quality must be loaded before startup")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): directory = arg.trim_prefix("--output=")
	if directory.is_empty(): directory = "user://demo_clips/section_transition"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	config = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	clip = config["reels"][0]["clips"][0]
	Suite.prepare_storage()
	get_window().size = Vector2i(1920, 1080)
	get_window().content_scale_size = Vector2i(1920, 1080)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	get_tree().process_frame.connect(_tick)
	scene = Instrument.install(clock)
	add_child(scene)
	_run.call_deferred()

func _tick() -> void:
	if DisplayServer.get_name() == "headless": RenderingServer.frame_post_draw.emit()
	clock.tick()
	if clock.frame > MAX_CLIP_FRAMES and not done:
		failures.append("Clip watchdog expired")
		_finish()

func _run() -> void:
	var run: Dictionary = Suite.fixture(int(clip["section_index"]), "encounter")
	var battle: Dictionary = run["combat_state"]
	var boss: Dictionary = battle["enemies"][0]
	# A nearly defeated production boss, adjacent to the hero, makes the capture
	# exercise real lethal-card animation, reward granting and the defeated cue.
	boss["hp"] = int(clip["fixture_boss_hp"])
	boss["block"] = int(clip["fixture_boss_block"])
	boss["stoneskin"] = int(clip["fixture_boss_stoneskin"])
	var target: Vector2i = boss["pos"]
	var offset: Array = clip["fixture_hero_offset"]
	battle["player"]["pos"] = target + Vector2i(int(offset[0]), int(offset[1]))
	battle["grid"][target.y][target.x - 1] = "stone"
	battle["deck"]["hand"] = [str(clip["fixture_card"])]
	battle["current_actor"] = {"kind": "player", "key": "player"}
	battle["umbra"]["radius"] = int(clip["fixture_umbra_radius"])
	scene.call("_load_run_state", run)
	scene.call("_ensure_sfx_bank")
	clock.bank = scene.get("_sfx_bank")
	clock.bank.set_test_clock(float(clock.usec) / 1000.0)
	await _frames(PREPARE_FRAMES)
	start_frame = clock.frame
	_mark("section_i_dragon_alive")
	await _frames(roundi(float(config["defaults"]["pre_roll_s"]) * Clock.FPS))
	await scene.call("_on_card_pressed", 0)
	if not (scene.get("_pending_target_tiles") as Array).has(target): failures.append("Fixture's lethal card cannot target the dragon")
	await scene.call("_on_board_tile_clicked", target)
	while not done and (str(scene.get("_run_state")["mode"]) != "reward" or bool(scene.get("_animation_lock")) or bool(scene.call("_treasure_presentation_busy"))): await get_tree().process_frame
	if done: return
	_mark("dragon_defeated_reward_granted")
	# The production lethal-card coroutine above completes the dragon's death,
	# victory beat and reward reveal; no animation or reveal is skipped/seeking.
	await _frames(roundi(float(config["defaults"]["reward_hold_s"]) * Clock.FPS))
	var button: Button = scene.find_child("DragonRewardContinue", true, false)
	if button == null:
		failures.append("Dragon CONTINUE unavailable")
		_finish()
		return
	# Drive native GUI picking with the real pointer and its press/release path.
	# The clip never invokes the button signal or the transition handler directly.
	var point: Vector2 = button.get_global_rect().get_center()
	Input.warp_mouse(point)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	get_viewport().push_input(motion, true)
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = point
		click.global_position = point
		click.pressed = pressed
		get_viewport().push_input(click, true)
	var transition: Node = scene.get("_section_transition")
	if transition == null:
		failures.append("CONTINUE did not start transition")
		_finish()
		return
	_mark("continue")
	_set_cursor_suppressed(true)
	transition.arrived.connect(func() -> void: _mark("arrival"))
	while not done and is_instance_valid(scene.get("_section_transition")): await get_tree().process_frame
	if done: return
	_set_cursor_suppressed(false)
	_mark("transition_finished")
	await _frames(roundi(float(config["defaults"]["tail_s"]) * Clock.FPS))
	if scene.get("_run_state")["current_room"] != Graph.section(scene.get("_run_state"), 1)["entry"]: failures.append("Clip must end two seconds into Section II's entry room")
	_mark("tail_finished")
	_finish()

func _frames(count: int) -> void:
	for frame: int in range(count):
		if done: return
		await get_tree().process_frame

func _mark(event: String) -> void:
	events.append({"event": event, "frame": clock.frame, "mode": scene.get("_run_state").get("mode"), "room": str(scene.get("_run_state").get("current_room"))})

func _finish() -> void:
	if done: return
	done = true
	var path: String = directory.path_join("events.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"clip": "section_transition", "fps": Clock.FPS, "headless": DisplayServer.get_name() == "headless", "start_frame": start_frame, "end_frame": clock.frame, "events": events, "errors": failures}, "\t"))
	print("DEMO CLIP section_transition: %s (%d frames); %s" % ["PASS" if failures.is_empty() else "FAIL", clock.frame - start_frame, ProjectSettings.globalize_path(path)])
	for failure: String in failures: push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func _exit_tree() -> void:
	_set_cursor_suppressed(false)
	clock.bank = null

func _set_cursor_suppressed(suppressed: bool) -> void:
	var feedback: Node = get_node_or_null("/root/CursorFeedback")
	if feedback != null: feedback.call("set_glyph_visibility_suppressed", CURSOR_SUPPRESSION_OWNER, suppressed)
