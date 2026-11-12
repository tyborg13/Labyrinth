extends SceneTree

const Settings = preload("res://scripts/settings_store.gd")
const Progression = preload("res://scripts/progression_store.gd")
const OUTPUT: String = "/private/tmp/labyrinth_codex/ptf-08c/capture"
const VIEWPORT := Vector2i(1920, 1080)
const FIXTURE_SAVE: String = "/private/tmp/labyrinth-godot-home/ptf-08c-proof/Library/Application Support/Escape the Umbra Parallel ptf-08c-proof/current_run.save"
const INVALID_PROOF_TILE := Vector2i(0, 0)
const FPS: int = 30
const POINTER_TRAVEL_FRAMES: int = 8
const SCENE_SETTLE_FRAMES: int = 3
const LOAD_SETTLE_FRAMES: int = 6
const ATTACK_SELECT_FRAMES: int = 12
const TARGET_HOLD_FRAMES: int = 40
const INVALID_HOLD_FRAMES: int = 15
const BLOCK_HOLD_FRAMES: int = 40
const HERO_SELECT_FRAMES: int = 10
const MOVE_HOLD_FRAMES: int = 30
const PASS_HOLD_FRAMES: int = 40
var scene: Node
var pointer := Vector2.ZERO
var failed: bool = false
var rehearsal: bool = false

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	rehearsal = OS.get_cmdline_user_args().has("--rehearsal")
	# Headless rehearsal follows the same real inputs and still assertions;
	# cap its frame loop so wall-clock fades have the movie's settling time.
	if rehearsal: Engine.max_fps = FPS
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
	var plan: Dictionary = make_plan()
	if plan.is_empty():
		quit(1)
		return
	FileAccess.open(OUTPUT.path_join("plan.json"), FileAccess.WRITE).store_string(JSON.stringify(plan, "\t"))
	scene.call("_cancel_player_movement_selection")
	if OS.get_cmdline_user_args().has("--plan-only"):
		print("PTF08 ACTION MOVIE PLAN: PASS " + JSON.stringify(plan))
		scene.queue_free()
		await process_frame
		quit()
		return
	if DisplayServer.get_name() == "headless" and not rehearsal:
		fail("movie capture requires the owner's window server")
		quit(1)
		return
	var attack: Control = scene.call("_hand_card_control", 0) as Control
	await move_pointer(attack.get_global_rect().get_center(), POINTER_TRAVEL_FRAMES)
	await click_pointer()
	await frames(ATTACK_SELECT_FRAMES)
	for key: String in ["kill", "non_kill"]:
		await move_pointer(tile_point(decode(plan[key]["tile"])), POINTER_TRAVEL_FRAMES)
		await frames(TARGET_HOLD_FRAMES)
		verify_destination(plan[key])
		await stills(PackedStringArray([key]))
	await move_pointer(tile_point(decode(plan["invalid"])), POINTER_TRAVEL_FRAMES)
	await frames(INVALID_HOLD_FRAMES)
	var chip: Button = scene.find_child("PassPreviewChip", true, false) as Button
	if (chip.get_node("PassForecastFocusTooltip") as Control).visible: fail("invalid attack tile did not fade out")
	await cancel_key()
	var block: Control = scene.call("_hand_card_control", 1) as Control
	await move_pointer(block.get_global_rect().get_center(), POINTER_TRAVEL_FRAMES)
	await click_pointer()
	await frames(BLOCK_HOLD_FRAMES)
	if not bool(scene.call("_pending_card_requires_confirmation")): fail("Brace did not reach confirmation")
	if scene.call("_pass_preview_summary") != plan["block_summary"]: fail("Block confirmation summary changed")
	await stills(PackedStringArray(["block_confirmation"]))
	await cancel_key()
	var shortcut: Control = scene.call("_hand_card_control", 2) as Control
	await move_pointer(shortcut.get_global_rect().get_center(), POINTER_TRAVEL_FRAMES)
	await click_pointer()
	await frames(ATTACK_SELECT_FRAMES)
	await move_pointer(tile_point(decode(plan["shortcut"]["tile"])), POINTER_TRAVEL_FRAMES)
	await frames(TARGET_HOLD_FRAMES)
	verify_destination(plan["shortcut"])
	if (scene.call("_shortcut_plan_for_tile", scene.call("_active_card_preview"), decode(plan["shortcut"]["tile"])) as Dictionary).is_empty(): fail("shortcut hover has no plan")
	await stills(PackedStringArray(["shortcut_hover"]))
	await cancel_key()
	var hero: Vector2i = scene.get("_combat_state")["player"]["pos"]
	await move_pointer(tile_point(hero), POINTER_TRAVEL_FRAMES)
	await click_pointer()
	await frames(HERO_SELECT_FRAMES)
	await move_pointer(tile_point(decode(plan["move"])), POINTER_TRAVEL_FRAMES)
	await frames(MOVE_HOLD_FRAMES)
	if not bool(chip.get_meta("pass_action_preview", false)): fail("Hero move did not show panel")
	await move_pointer(chip.get_global_rect().get_center(), POINTER_TRAVEL_FRAMES)
	await frames(PASS_HOLD_FRAMES)
	if not bool(chip.get_meta("pass_pointer_hover", false)): fail("PASS hover not reached")
	print("PTF08 ACTION %s RESULT: %s" % ["REHEARSAL" if rehearsal else "MOVIE", "FAIL" if failed else "PASS"])
	scene.queue_free()
	await process_frame
	quit(1 if failed else 0)

func make_plan() -> Dictionary:
	var result: Dictionary = {}
	scene.call("_on_card_pressed", 0)
	if (scene.get("_pending_target_tiles") as Array).has(INVALID_PROOF_TILE):
		fail("proof invalid tile must not be a legal attack target")
		return {}
	for tile: Vector2i in scene.get("_pending_target_tiles"):
		var foe_target: bool = false
		for foe: Dictionary in scene.get("_combat_state").get("enemies", []):
			if foe["pos"] == tile: foe_target = true
		if not foe_target: continue
		scene.call("_on_board_tile_hovered", tile)
		scene.call("_refresh_board_hover_presentation")
		var source: Dictionary = scene.call("_pass_preview_source_state")
		var killed: bool = false
		for foe: Dictionary in source.get("enemies", []):
			if int(foe.get("hp", 0)) <= 0: killed = true
		result["kill" if killed else "non_kill"] = {"tile": [tile.x, tile.y], "summary": scene.call("_pass_preview_summary")}
	scene.call("_cancel_card_selection")
	scene.call("_on_card_pressed", 1)
	if not bool(scene.call("_pending_card_requires_confirmation")):
		fail("real fixture requires self-Block confirmation")
		return {}
	result["block_summary"] = scene.call("_pass_preview_summary")
	scene.call("_cancel_card_selection")
	scene.call("_on_card_pressed", 2)
	var preview: Dictionary = scene.call("_active_card_preview")
	for foe: Dictionary in scene.get("_combat_state").get("enemies", []):
		var tile: Vector2i = foe["pos"]
		if (scene.call("_shortcut_plan_for_tile", preview, tile) as Dictionary).is_empty(): continue
		scene.call("_on_board_tile_hovered", tile)
		scene.call("_refresh_board_hover_presentation")
		result["shortcut"] = {"tile": [tile.x, tile.y], "summary": scene.call("_pass_preview_summary")}
	if not result.has("shortcut"):
		fail("fixture requires a Sidestep Slash shortcut foe")
		return {}
	scene.call("_cancel_card_selection")
	scene.call("_begin_player_movement_selection")
	var moves: Array = scene.get("_player_movement_target_tiles")
	if moves.is_empty() or not result.has("kill") or not result.has("non_kill"):
		fail("fixture requires a kill, non-kill and legal hero move: keys=%s moves=%s selected=%s" % [str(result.keys()), str(moves), str(scene.get("_selected_card_index"))])
		return {}
	result["move"] = [moves[0].x, moves[0].y]
	var hero: Vector2i = scene.get("_combat_state")["player"]["pos"]
	result["invalid"] = [INVALID_PROOF_TILE.x, INVALID_PROOF_TILE.y]
	result["seed"] = scene.get("_run_state").get("seed")
	result["fps"] = FPS
	scene.call("_cancel_player_movement_selection")
	return result

func cancel_key() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

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
	if DisplayServer.get_name() == "headless":
		print("PTF08 HEADLESS STILL %s: %s" % [str(stems), "FAIL" if failed else "PASS"])
		return
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
