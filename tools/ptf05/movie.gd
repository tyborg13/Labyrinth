extends SceneTree
## One certified real combat save; no test host, synthetic grid or state swaps.
const Clock = preload("res://scripts/presentation_clock.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Feedback = preload("res://scripts/target_click_feedback.gd")
const SIZE := Vector2i(1920, 1080)
const FAR_FOE := Vector2i(6, 4)
const COVERED_FOE := Vector2i(4, 4)
const SECOND_FAR_TILE := Vector2i(6, 3)
const REASON_WAIT_SECONDS: float = 1.6
const STILL_SECONDS: float = 0.59
const POINTER_TRAVEL_SECONDS: float = 0.2
const CARD_HOVER_SECONDS: float = 0.1
const STARTUP_TIMEOUT_SECONDS: float = 20.0
const CHOREOGRAPHY_WATCHDOG_SECONDS: float = 50.0
const BOOT_SETTLE_SECONDS: float = 0.8
const RESTART_INTERVAL_SECONDS: float = 0.4
const OUTPUT: String = "/private/tmp/labyrinth_codex/ptf-05b/feedback3-movie"
var scene: Control
var board: Control
var failed: bool = false
var validate_only: bool = false
var pointer := Vector2(960, 540)

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	validate_only = OS.get_cmdline_user_args().has("--validate-only")
	if DisplayServer.get_name() == "headless" and not validate_only:
		_require(false, "Movie requires a windowed renderer; headless supports --validate-only")
		return
	if not validate_only and Engine.get_write_movie_path().is_empty():
		_require(false, "Movie must run with --write-movie and --fixed-fps 30")
		return
	if not validate_only and not _require(Clock._read_movie_fps() == 30, "Presentation clock must read the capture FPS as 30"): return
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_factor = 1.0
	var source: String = OS.get_environment("PTF05_FIXTURE_DIR")
	for name: String in ["current_run.save", "progression.json"]:
		if not _require(DirAccess.copy_absolute(source.path_join(name), ProjectSettings.globalize_path("user://" + name)) == OK, "Copy certified inspection file: " + name): return
	var run: Dictionary = Store.load_saved_run()
	if not _require(run.get("inspection_fixture", {}).get("scenario", "") == "combat", "Certified --scenario combat save required"): return
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	DirAccess.make_dir_recursive_absolute(OUTPUT.path_join("stills"))
	create_timer(CHOREOGRAPHY_WATCHDOG_SECONDS).timeout.connect(func() -> void: _require(false, "Movie choreography watchdog expired"))
	root.set_meta("labyrinth_resume_saved_run", true)
	_run.call_deferred()

func _run() -> void:
	scene = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	board = scene.get("board_view")
	var deadline: int = Clock.ticks_usec(false) + int(STARTUP_TIMEOUT_SECONDS * 1000000.0)
	while (bool(scene.get("_animation_lock")) or bool(scene.get("_opening_hand_draw_in_progress"))) and Clock.ticks_usec(false) < deadline:
		await process_frame
	await _wait(BOOT_SETTLE_SECONDS)
	if not _require(not bool(scene.get("_animation_lock")) and not bool(scene.get("_dialogue_active")), "Real combat must finish boot without dialogue or animation lock"): return
	if not _require(not bool(scene.call("_guided_tutorial_is_active")), "Inspection combat must not enter a tutorial"): return
	if not _validate_fixture(): return
	await _select("dull_bolt")
	await _move_tile(FAR_FOE, POINTER_TRAVEL_SECONDS)
	await _reason_click(FAR_FOE, "Out of range", "out_of_range")
	await _select("pale_spark")
	await _move_tile(COVERED_FOE, POINTER_TRAVEL_SECONDS)
	await _reason_click(COVERED_FOE, "No line of sight", "line_of_sight")
	await _select("shadow_step")
	var dark: Vector2i = _dark_tile()
	await _move_tile(dark, POINTER_TRAVEL_SECONDS)
	await _reason_click(dark, "Can't see there", "dark")
	await _select("dull_bolt")
	await _move_tile(FAR_FOE, POINTER_TRAVEL_SECONDS)
	await _click_tile(FAR_FOE)
	var first_epoch: int = scene.call("_click_feedback").reason_started_usec
	await _move_tile(SECOND_FAR_TILE, POINTER_TRAVEL_SECONDS)
	await _until(first_epoch + int(RESTART_INTERVAL_SECONDS * 1000000.0))
	await _click_tile(SECOND_FAR_TILE)
	print("PTF05 MOVIE RESTART GAP: %.6f seconds" % (float(scene.call("_click_feedback").reason_started_usec - first_epoch) / 1000000.0))
	if not _require(scene.call("_click_feedback").reason_label.text == "Out of range", "Quick second click restarts Out of range"): return
	await _wait(REASON_WAIT_SECONDS)
	if failed: return
	print("PTF05 REAL RUN MOVIE: PASS (continuous pointer sequence; three reason holds and quick restart)")
	scene.queue_free()
	await process_frame
	quit(0)

func _validate_fixture() -> bool:
	var state: Dictionary = scene.get("_combat_state")
	var engine = scene.get("_combat_engine")
	if not _require(state == (scene.get("_run_state") as Dictionary).get("combat_state", {}), "Live scene uses the inspection combat state"): return false
	if not _require(Feedback.reason(engine, state, {"type":"ranged", "range":3}, FAR_FOE) == "Out of range", "Real fixture far foe is four tiles away and visible"): return false
	if not _require(Feedback.reason(engine, state, {"type":"ranged", "range":3}, COVERED_FOE) == "No line of sight", "Real fixture crate blocks sight"): return false
	return _require(_dark_tile().x >= 0, "Real fixture includes an Umbra-hidden floor")

func _dark_tile() -> Vector2i:
	var state: Dictionary = scene.get("_combat_state")
	var engine = scene.get("_combat_engine")
	var grid: Array = state.get("grid", [])
	for y: int in range(grid.size()):
		for x: int in range((grid[y] as Array).size()):
			var tile := Vector2i(x, y)
			if engine.call("_tile_is_passable", state, tile) and not engine.call("is_tile_visible_to_player", state, tile): return tile
	return Vector2i(-1, -1)

func _select(id: String) -> void:
	var hand: Array = scene.get("_combat_state").get("deck", {}).get("hand", [])
	var index: int = hand.find(id)
	if not _require(index >= 0, "Real hand contains " + id): return
	var card: Control = scene.call("_hand_card_control", index)
	await _move_point(card.get_global_rect().get_center(), POINTER_TRAVEL_SECONDS)
	await _wait(CARD_HOVER_SECONDS)
	card = scene.call("_hand_card_control", index)
	_motion(card.get_global_rect().get_center())
	await _click()
	await _wait(CARD_HOVER_SECONDS)
	_require(int(scene.get("_selected_card_index")) == index, "Real pointer selects " + id)

func _reason_click(tile: Vector2i, expected: String, still_name: String) -> void:
	await _click_tile(tile)
	var feedback = scene.call("_click_feedback")
	if not _require(feedback.reason_label.text == expected, "Real click reason: " + expected): return
	var epoch: int = feedback.reason_started_usec
	await _until(epoch + int(STILL_SECONDS * 1000000.0))
	if not _require(is_equal_approx(feedback.reason_label.modulate.a, 1.0), "Mid-hold reason is opaque"): return
	if still_name in ["out_of_range", "line_of_sight"] and not _check_intent_separation(tile, expected): return
	await _still(still_name)
	await _until(epoch + int(REASON_WAIT_SECONDS * 1000000.0))
	_require(not feedback.reason_label.visible, "Full reason cycle has completed")

func _check_intent_separation(tile: Vector2i, reason: String) -> bool:
	var actor_key: String = ""
	var engine = scene.get("_combat_engine")
	for enemy: Dictionary in scene.get("_combat_state").get("enemies", []):
		if (engine.call("_enemy_footprint_tiles", enemy) as Array).has(tile):
			actor_key = "enemy_%d" % int(enemy["id"])
			break
	if not _require(not actor_key.is_empty() and scene.get("_hovered_board_tile") == tile, "Separation witness is the hovered foe"): return false
	var rest: Rect2 = scene.call("_click_feedback").reason_rest_rect()
	var intent: Rect2 = board.call("enemy_intent_visual_global_rect", actor_key)
	print("PTF05 REASON / INTENT RECTS %s: reason=%s intent=%s" % [reason, rest, intent])
	if not _require(intent.has_area(), "Hovered foe has a nonempty intent popup: " + reason): return false
	return _require(not rest.intersects(intent), "Tile-anchored reason avoids the hovered intent popup: " + reason)

func _click_tile(tile: Vector2i) -> void:
	var local: Vector2 = board.call("_tile_center", tile)
	if not _require(board.call("_tile_at_point", local) == tile, "Click resolves to intended floor: " + str(tile)): return
	_motion(board.get_global_transform_with_canvas() * local)
	if not _require(scene.get("_hovered_board_tile") == tile, "Pointer hover equals click tile"): return
	await _click()

func _click() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = pointer
		event.global_position = pointer
		root.push_input(event, true)
		await process_frame

func _move_tile(tile: Vector2i, seconds: float) -> void:
	await _move_point(board.get_global_transform_with_canvas() * board.call("_tile_center", tile), seconds)
	_require(scene.get("_hovered_board_tile") == tile, "Movie hover reaches floor " + str(tile))

func _move_point(destination: Vector2, seconds: float) -> void:
	var origin: Vector2 = pointer
	var epoch: int = Clock.ticks_usec(false)
	while Clock.ticks_usec(false) - epoch < int(seconds * 1000000.0):
		var progress: float = clampf(float(Clock.ticks_usec(false) - epoch) / (seconds * 1000000.0), 0.0, 1.0)
		_motion(origin.lerp(destination, progress))
		await process_frame
	_motion(destination)
	await process_frame

func _motion(point: Vector2) -> void:
	pointer = point
	if not validate_only: root.warp_mouse(point)
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)

func _wait(seconds: float) -> void:
	await _until(Clock.ticks_usec(false) + int(seconds * 1000000.0))

func _until(deadline: int) -> void:
	while Clock.ticks_usec(false) < deadline:
		await process_frame

func _still(id: String) -> void:
	if validate_only: return
	await RenderingServer.frame_post_draw
	var path: String = OUTPUT.path_join("stills/" + id + ".png")
	_require(root.get_texture().get_image().save_png(path) == OK, "Save real renderer still " + id)
	print(path)

func _require(condition: bool, message: String) -> bool:
	if not condition:
		failed = true
		push_error("PTF05 REAL RUN MOVIE: FAIL: " + message)
		quit(1)
	return condition
