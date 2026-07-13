extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

const OUTPUT_DIR: String = "user://combat_board_navigation_probe"
const BOARD_PATH: String = "BoardUnderlay/CombatBoard"
const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)

var _errors: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.size = VIEWPORT_SIZE
	ProgressionStore.set_storage_path("user://labyrinth_progression_board_navigation_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_board_navigation_probe.save")
	ProgressionStore.clear_saved_run()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	await _capture_navigation_states()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	if _errors.is_empty():
		print("COMBAT BOARD NAVIGATION PROBE: PASS")
		quit(0)
	else:
		for error: String in _errors:
			push_error(error)
		print("COMBAT BOARD NAVIGATION PROBE: FAIL (%d errors)" % _errors.size())
		quit(1)

func _capture_navigation_states() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_errors.append("Run scene should load for board navigation visual proof")
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle_ui()
	var run_engine := RunEngine.new()
	instance.call("_load_run_state", run_engine.create_new_run(18131, ProgressionStore.default_data()))
	await _settle_ui()
	var layout: Dictionary = _navigation_layout()
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(18131, layout, {
		"hp": 30,
		"max_hp": 30,
		"deck_cards": ["quick_stab", "guarded_step", "lantern_shot"],
		"relics": [],
		"hand_size": 3,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["quick_stab", "guarded_step", "lantern_shot"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	combat_state["cards_played_this_turn"] = 0
	combat_state["death_bonus_card_plays_this_turn"] = 0
	combat_state["card_play_bonus_this_turn"] = 0
	combat_state["player_turn_restrictions"] = {"frozen": false, "shocked": false, "immobilized": false}
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.set("_animation_lock", false)
	instance.call("_reset_card_resolution")
	instance.call("_refresh_ui")
	await _settle_ui()

	var board: Control = instance.get_node(BOARD_PATH) as Control
	if board == null:
		_errors.append("Navigation probe should find the combat board")
		instance.queue_free()
		return
	var stage: Control = instance.get("stage_root") as Control
	var bottom_stack: Control = instance.get("bottom_stack") as Control
	var top_bar: Control = instance.get("top_bar") as Control
	var prompt_host: Control = instance.get("_contextual_combat_prompt_host") as Control
	_expect(stage != null and not stage.clip_contents, "Stage should allow board art to flow beneath the surrounding HUD")
	_expect(not board.clip_contents, "Board render layers should share the unclipped HUD-underlay canvas")
	var board_layer: CanvasLayer = board.get_parent() as CanvasLayer
	var ui_layer: CanvasLayer = instance.get_node("UiLayer") as CanvasLayer
	_expect(board_layer != null and ui_layer != null and board_layer.layer < ui_layer.layer, "Board should render on a dedicated canvas beneath the HUD")
	_expect(top_bar != null and bottom_stack != null, "Navigation proof should expose both fixed HUD regions")
	_expect(prompt_host != null and prompt_host.visible, "Navigation proof should expose the combat note stability check")
	var prompt_position_before_navigation: Vector2 = prompt_host.global_position if prompt_host != null else Vector2.ZERO
	var routed_drag_start: Vector2 = board.global_position + board.size * 0.5
	var routed_press := InputEventMouseButton.new()
	routed_press.button_index = MOUSE_BUTTON_MIDDLE
	routed_press.pressed = true
	routed_press.position = routed_drag_start
	routed_press.global_position = routed_drag_start
	Input.parse_input_event(routed_press)
	await process_frame
	var routed_motion := InputEventMouseMotion.new()
	routed_motion.position = routed_drag_start + Vector2(60.0, 0.0)
	routed_motion.global_position = routed_motion.position
	routed_motion.relative = Vector2(60.0, 0.0)
	routed_motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	Input.parse_input_event(routed_motion)
	await process_frame
	var routed_release := InputEventMouseButton.new()
	routed_release.button_index = MOUSE_BUTTON_MIDDLE
	routed_release.pressed = false
	routed_release.position = routed_motion.position
	routed_release.global_position = routed_motion.position
	Input.parse_input_event(routed_release)
	await _settle_ui()
	_expect(((board.call("navigation_snapshot") as Dictionary).get("pan", Vector2.ZERO) as Vector2).length() > 20.0, "Viewport-routed drag input should reach the underlay board through transparent HUD layout controls")
	board.call("reset_navigation")
	await _settle_ui()
	await _save_root_screenshot("%s/01_default_fit.png" % OUTPUT_DIR)
	var default_snapshot: Dictionary = board.call("navigation_snapshot")
	_expect(is_equal_approx(float(default_snapshot.get("zoom", 0.0)), 1.0), "Board should begin at its fitted default zoom")

	var focus_tile := Vector2i(10, 2)
	for _step: int in range(4):
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		wheel.factor = 1.0
		wheel.position = board.call("world_position_for_tile", focus_tile)
		board.call("_gui_input", wheel)
	var drag_start: Vector2 = board.call("world_position_for_tile", Vector2i(8, 4))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = drag_start
	board.call("_gui_input", press)
	var motion := InputEventMouseMotion.new()
	motion.position = drag_start + Vector2(-150.0, 260.0)
	motion.relative = Vector2(-150.0, 260.0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	board.call("_gui_input", motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = motion.position
	board.call("_gui_input", release)
	await _settle_ui()
	var focused_snapshot: Dictionary = board.call("navigation_snapshot")
	_expect(float(focused_snapshot.get("zoom", 0.0)) > 1.35, "Wheel input should reach the bounded close-focus zoom")
	_expect((focused_snapshot.get("pan", Vector2.ZERO) as Vector2).length() > 20.0, "Left-drag should move the zoomed board")
	var visible_focus_position: Vector2 = board.call("world_position_for_tile", focus_tile)
	_expect(board.call("_tile_at_point", visible_focus_position) == focus_tile, "Panned and zoomed board should retain accurate tile hit testing")
	var rendered_bounds: Rect2 = instance.call("_contextual_combat_rendered_board_bounds")
	_expect(stage != null and rendered_bounds.end.y > stage.get_global_rect().end.y + 20.0, "Pulled-down board art should extend below the stage boundary")
	_expect(bottom_stack != null and rendered_bounds.intersects(bottom_stack.get_global_rect()), "Pulled-down board art should continue behind the bottom HUD")
	_expect(prompt_host != null and prompt_host.global_position == prompt_position_before_navigation, "Combat note should stay anchored while the board is navigated")
	await _save_root_screenshot("%s/02_zoomed_and_panned.png" % OUTPUT_DIR)

	for _step: int in range(12):
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		wheel.factor = 1.0
		wheel.position = board.size * 0.5
		board.call("_gui_input", wheel)
	await _settle_ui()
	var wide_snapshot: Dictionary = board.call("navigation_snapshot")
	_expect(is_equal_approx(float(wide_snapshot.get("zoom", 0.0)), float(wide_snapshot.get("min_zoom", -1.0))), "Repeated wheel-down input should stop at the bounded wide zoom")
	await _save_root_screenshot("%s/03_zoomed_out.png" % OUTPUT_DIR)

	instance.queue_free()
	await process_frame

func _navigation_layout() -> Dictionary:
	return {
		"name": "Navigation Proof Hall",
		"coord": Vector2i(2, 0),
		"type": "combat",
		"grid": _navigation_grid(),
		"player_start": Vector2i(2, 6),
		"enemies": [
			{"id": 1, "type": "crawler", "pos": Vector2i(5, 5), "hp": 22, "max_hp": 22, "block": 0},
			{"id": 2, "type": "harrier", "pos": Vector2i(8, 3), "hp": 18, "max_hp": 18, "block": 0},
			{"id": 3, "type": "acolyte", "pos": Vector2i(10, 2), "hp": 24, "max_hp": 24, "block": 0}
		],
		"loot": [{"id": "vial", "kind": "healing_vial", "amount": 4, "pos": Vector2i(7, 5)}],
		"traps": [{"id": "trap", "element": "fire", "pos": Vector2i(6, 3), "damage": 3, "armed": true}],
		"terrain": [{"id": "crate", "kind": "wooden_crate", "pos": Vector2i(4, 3), "hp": 8, "max_hp": 8}]
	}

func _navigation_grid() -> Array:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(13):
			row.append("wall" if y == 0 or y == 8 or x == 0 or x == 12 else "ash")
		grid.append(row)
	return grid

func _settle_ui() -> void:
	for _frame: int in range(6):
		await process_frame

func _save_root_screenshot(output_path: String) -> void:
	await process_frame
	var image: Image = root.get_texture().get_image()
	if image.get_width() < 32 or image.get_height() < 32:
		_errors.append("Navigation probe captured an invalid image for %s" % output_path)
		return
	if image.save_png(output_path) != OK:
		_errors.append("Navigation probe could not save %s" % output_path)

func _clear_probe_output(output_dir: String) -> void:
	var dir := DirAccess.open(output_dir)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
