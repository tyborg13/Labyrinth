extends SceneTree

const Settings = preload("res://scripts/settings_store.gd")
const Progression = preload("res://scripts/progression_store.gd")
const OUTPUT: String = "/private/tmp/labyrinth_codex/ptf-08/movement-capture"
const VIEWPORT := Vector2i(1920, 1080)
const FIXTURE_SAVE: String = "/private/tmp/labyrinth-godot-home/ptf-08-move-proof/Library/Application Support/Escape the Umbra Parallel ptf-08-move-proof/current_run.save"
const FPS: int = 30
const SWEEP_FRAMES: int = 75
const DESTINATION_COUNT: int = 4
const POINTER_TRAVEL_FRAMES: int = 8
const SCENE_SETTLE_FRAMES: int = 3
const LOAD_SETTLE_FRAMES: int = 6
const SELECTION_SETTLE_FRAMES: int = 3
const HERO_SELECT_HOLD_FRAMES: int = 19
const SWEEP_HOLD_FRAMES: int = 10
const SWEEP_FINAL_HOLD_FRAMES: int = 13
const INVALID_HOLD_FRAMES: int = 12
const REENTRY_HOLD_FRAMES: int = 12
const PASS_HOLD_FRAMES: int = 22
const BLINK_SELECT_HOLD_FRAMES: int = 20
const BLINK_LANDING_HOLD_FRAMES: int = 22
const TAIL_HOLD_FRAMES: int = 25
var scene: Node
var pointer := Vector2.ZERO
var failed: bool = false

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = "windowed"
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = VIEWPORT
	root.size = VIEWPORT
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	Progression.set_run_storage_path(FIXTURE_SAVE)
	var run_state: Dictionary = Progression.load_saved_run()
	Progression.set_run_storage_path("user://ptf08-movie.save")
	if str(run_state.get("inspection_fixture", {}).get("scenario", "")) != "combat":
		fail("requires the verified --scenario combat inspection fixture")
		quit(1)
		return
	scene = preload("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	await frames(SCENE_SETTLE_FRAMES)
	scene.call("_load_run_state", run_state)
	await frames(LOAD_SETTLE_FRAMES)
	scene.call("_begin_player_movement_selection")
	await frames(SELECTION_SETTLE_FRAMES)
	var plan: Dictionary = make_plan()
	if plan.is_empty():
		quit(1)
		return
	FileAccess.open(OUTPUT.path_join("plan.json"), FileAccess.WRITE).store_string(JSON.stringify(plan, "\t"))
	scene.call("_cancel_player_movement_selection")
	if OS.get_cmdline_user_args().has("--plan-only"):
		print("PTF08 MOVIE PLAN: PASS " + JSON.stringify(plan))
		scene.queue_free()
		await process_frame
		quit()
		return
	if DisplayServer.get_name() == "headless":
		fail("movie capture requires the owner's window server")
		quit(1)
		return
	# One continuous 300-frame interaction sequence; preparation above only
	# enumerates legal destinations and never edits the real saved board.
	var hero: Vector2i = scene.get("_combat_state")["player"]["pos"]
	await move_pointer(tile_point(hero), POINTER_TRAVEL_FRAMES)
	await click_pointer()
	await frames(HERO_SELECT_HOLD_FRAMES)
	var destinations: Array = plan["destinations"]
	var sweep_started: int = Engine.get_process_frames()
	for index: int in range(DESTINATION_COUNT):
		var tile: Vector2i = decode(destinations[index]["tile"])
		await move_pointer(tile_point(tile), POINTER_TRAVEL_FRAMES)
		await frames(SWEEP_HOLD_FRAMES if index < DESTINATION_COUNT - 1 else SWEEP_FINAL_HOLD_FRAMES)
		verify_destination(destinations[index])
		var captures := PackedStringArray()
		if index == 0: captures.append("safe")
		if index == 1: captures.append("loss")
		if not (scene.call("_pass_preview_summary").get("repeated_enemy_names", []) as Array).is_empty(): captures.append("x2")
		await stills(captures)
	if Engine.get_process_frames() - sweep_started != SWEEP_FRAMES: fail("movement sweep must last exactly 75 movie frames")
	await move_pointer(tile_point(decode(plan["invalid"])), POINTER_TRAVEL_FRAMES)
	await frames(INVALID_HOLD_FRAMES)
	var chip: Button = scene.find_child("PassPreviewChip", true, false) as Button
	if (chip.get_node("PassForecastFocusTooltip") as Control).visible: fail("invalid tile did not fade out")
	await move_pointer(tile_point(decode(destinations[0]["tile"])), POINTER_TRAVEL_FRAMES)
	await frames(REENTRY_HOLD_FRAMES)
	await move_pointer(chip.get_global_rect().get_center(), POINTER_TRAVEL_FRAMES)
	await frames(PASS_HOLD_FRAMES)
	await stills(PackedStringArray(["pass_hover"]))
	var blink: Control = scene.call("_hand_card_control", 1) as Control
	await move_pointer(blink.get_global_rect().get_center(), POINTER_TRAVEL_FRAMES)
	await click_pointer()
	await frames(BLINK_SELECT_HOLD_FRAMES)
	if int(scene.get("_selected_card_index")) != 1: fail("pointer did not select Shadow Step")
	for tile_data: Array in plan["blink"]:
		await move_pointer(tile_point(decode(tile_data)), POINTER_TRAVEL_FRAMES)
		await frames(BLINK_LANDING_HOLD_FRAMES)
		if not bool(chip.get_meta("pass_movement_preview", false)): fail("Blink landing did not show forecast")
	await frames(TAIL_HOLD_FRAMES)
	print("PTF08 MOVIE RESULT: %s" % ("FAIL" if failed else "PASS"))
	scene.queue_free()
	await process_frame
	quit(1 if failed else 0)

func make_plan() -> Dictionary:
	var safe: Array[Dictionary]
	var losses: Array[Dictionary]
	var others: Array[Dictionary]
	var repeats: bool = false
	var targets: Array = scene.get("_player_movement_target_tiles")
	for tile: Vector2i in targets:
		scene.call("_on_board_tile_hovered", tile)
		scene.call("_refresh_board_hover_presentation")
		var summary: Dictionary = scene.call("_pass_preview_summary")
		var entry: Dictionary = {"tile": [tile.x, tile.y], "summary": summary}
		if int(summary.get("hp_loss", 0)) + int(summary.get("block_loss", 0)) == 0 and not bool(summary.get("umbra_unknown_before_player", false)):
			safe.append(entry)
		else:
			losses.append(entry)
		if not (summary.get("repeated_enemy_names", []) as Array).is_empty(): repeats = true
	if safe.is_empty() or losses.is_empty() or targets.size() < DESTINATION_COUNT or not repeats:
		fail("fixture needs Safe, real loss, four valid destinations and a repeated enemy; safe=%d loss=%d repeat=%s" % [safe.size(), losses.size(), str(repeats)])
		return {}
	others.append(safe[0])
	others.append(losses[0])
	for entry: Dictionary in safe + losses:
		if not others.has(entry) and others.size() < DESTINATION_COUNT: others.append(entry)
	var invalid := Vector2i(0, 0)
	for enemy: Dictionary in scene.get("_combat_state").get("enemies", []):
		if not targets.has(enemy["pos"]): invalid = enemy["pos"]
	scene.call("_cancel_player_movement_selection")
	scene.call("_on_card_pressed", 1)
	var blink_targets: Array = scene.get("_pending_target_tiles")
	if blink_targets.size() < 2:
		fail("fixture has no two legal Shadow Step landings")
		return {}
	var blink: Array = [[blink_targets[0].x, blink_targets[0].y], [blink_targets[1].x, blink_targets[1].y]]
	scene.call("_cancel_card_selection")
	return {"seed": scene.get("_run_state").get("seed"), "destinations": others, "invalid": [invalid.x, invalid.y], "blink": blink, "fps": FPS, "sweep_frames": SWEEP_FRAMES}

func verify_destination(entry: Dictionary) -> void:
	if scene.get("_hovered_board_tile") != decode(entry["tile"]): fail("pointer did not reach planned destination")
	if scene.call("_pass_preview_summary") != entry["summary"]: fail("destination summary changed from the inspected plan")

func tile_point(tile: Vector2i) -> Vector2:
	var board: Control = scene.get("board_view") as Control
	return board.get_global_transform_with_canvas() * (board.call("_tile_center", tile) as Vector2)

func move_pointer(target: Vector2, count: int) -> void:
	var from: Vector2 = pointer
	for index: int in range(count):
		pointer = from.lerp(target, float(index + 1) / count)
		root.warp_mouse(pointer)
		var motion := InputEventMouseMotion.new()
		motion.position = pointer
		root.push_input(motion, true)
		await process_frame

func click_pointer() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = pointer
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func frames(count: int) -> void:
	for _index: int in range(count): await process_frame

func stills(stems: PackedStringArray) -> void:
	var chip: Button = scene.find_child("PassPreviewChip", true, false) as Button
	var panel: Control = chip.get_node("PassForecastFocusTooltip") as Control
	if not panel.is_visible_in_tree() or not is_equal_approx(panel.modulate.a, 1.0): fail("stills require a fully visible forecast panel")
	if stems.has("x2"):
		var visible_badge: bool = false
		for badge: Control in chip.get_meta("forecast_fade_badges", []):
			if badge.is_visible_in_tree() and is_equal_approx(badge.modulate.a, 1.0): visible_badge = true
		if not visible_badge: fail("×2 still requires a visible rail badge")
	if stems.has("pass_hover") and not bool(chip.get_meta("pass_pointer_hover", false)): fail("PASS still requires actual pointer hover")
	# Save all stills from one rendered frame: a second post-draw wait would
	# insert an extra movie frame into the fixed 75-frame movement sweep.
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	for stem: String in stems:
		var path: String = OUTPUT.path_join(stem + ".png")
		if image.save_png(path) != OK: fail("could not save " + stem)
		print(path)

func fail(message: String) -> void:
	failed = true
	print("FAIL: " + message)

static func decode(values: Array) -> Vector2i:
	return Vector2i(int(values[0]), int(values[1]))
