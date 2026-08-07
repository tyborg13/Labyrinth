extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const OUTPUT_DIR: String = "user://elemental_trap_visual_probe"
const SCREENSHOT_PATH: String = OUTPUT_DIR + "/elemental_traps_1920x1080_ui100.png"
const SCREENSHOT_SIZE: Vector2i = Vector2i(1920, 1080)
const BOARD_PATH: String = "BoardUnderlay/CombatBoard"
const ELEMENTS: PackedStringArray = ["fire", "ice", "lightning", "air", "earth"]

var _errors: Array[String] = []


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://labyrinth_progression_elemental_trap_visual_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_elemental_trap_visual_probe.save")
	SettingsStore.set_storage_path("user://labyrinth_settings_elemental_trap_visual_probe.json")
	ProgressionStore.clear_saved_run()
	SettingsStore.clear_storage()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(SCREENSHOT_SIZE)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = SCREENSHOT_SIZE
	root.size = SCREENSHOT_SIZE
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	await _settle_ui()
	await _capture_trap_board()

	if _errors.is_empty():
		print("ELEMENTAL TRAP VISUAL PROBE: PASS")
		print("ELEMENTAL_TRAP_PROOF=%s" % ProjectSettings.globalize_path(SCREENSHOT_PATH))
		quit(0)
	else:
		for error: String in _errors:
			push_error(error)
		print("ELEMENTAL TRAP VISUAL PROBE: FAIL (%d errors)" % _errors.size())
		quit(1)


func _capture_trap_board() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_expect(packed != null, "The elemental trap probe should load the run scene")
	if packed == null:
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle_ui()
	instance.call("_load_run_state", RunEngine.new().create_new_run(82007, ProgressionStore.default_data()))
	if bool(instance.get("_dialogue_active")):
		instance.call("_close_dialogue")
	await _load_combat_fixture(instance)
	await _settle_ui(10)

	var board: Control = instance.get_node(BOARD_PATH) as Control
	_expect(board != null, "The elemental trap probe should find the live CombatBoardView")
	if board != null:
		_validate_live_traps(board)
	await _save_screenshot(SCREENSHOT_PATH)
	instance.queue_free()
	await _settle_ui()


func _load_combat_fixture(instance: Node) -> void:
	var layout: Dictionary = _trap_layout()
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(82007, layout, {
		"hp": 24,
		"max_hp": 24,
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
	combat_state["player_turn_restrictions"] = {
		"frozen": false,
		"shocked": false,
		"immobilized": false
	}
	var enemies: Array = (combat_state.get("enemies", []) as Array).duplicate(true)
	if not enemies.is_empty():
		var enemy: Dictionary = (enemies[0] as Dictionary).duplicate(true)
		enemy["intent"] = {
			"name": "Brace",
			"time": 4,
			"actions": [{"type": "block", "amount": 2}]
		}
		enemies[0] = enemy
	combat_state["enemies"] = enemies

	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	var room_coord: Vector2i = layout.get("coord", Vector2i.ZERO)
	var rooms: Dictionary = (run_state.get("rooms", {}) as Dictionary).duplicate(true)
	var room_key: String = "%d,%d" % [room_coord.x, room_coord.y]
	var room: Dictionary = (rooms.get(room_key, {}) as Dictionary).duplicate(true)
	room["type"] = "combat"
	room["npcs"] = []
	rooms[room_key] = room
	run_state["rooms"] = rooms
	run_state["mode"] = "combat"
	run_state["current_room"] = room_coord
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.set("_animation_lock", false)
	instance.call("_reset_card_resolution")
	instance.call("_refresh_ui")


func _trap_layout() -> Dictionary:
	return {
		"name": "Elemental Pressure Plate Gallery",
		"coord": Vector2i(2, 0),
		"type": "combat",
		"element": "fire",
		"grid": _combat_grid(),
		"player_start": Vector2i(2, 2),
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(6, 6),
			"hp": 22,
			"max_hp": 22,
			"block": 0
		}],
		"loot": [],
		"traps": [
			{"id": "fire_plate", "element": "fire", "pos": Vector2i(2, 6), "damage": 4, "armed": true},
			{"id": "ice_plate", "element": "ice", "pos": Vector2i(3, 5), "damage": 4, "armed": true},
			{"id": "lightning_plate", "element": "lightning", "pos": Vector2i(4, 4), "damage": 4, "armed": true},
			{"id": "air_plate", "element": "air", "pos": Vector2i(5, 3), "damage": 4, "armed": true},
			{"id": "earth_plate", "element": "earth", "pos": Vector2i(6, 2), "damage": 4, "armed": true}
		],
		"terrain": []
	}


func _combat_grid() -> Array:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x == 0 or x == 8 or y == 0 or y == 8 else "stone")
		grid.append(row)
	return grid


func _validate_live_traps(board: Control) -> void:
	var state: Dictionary = board.get("combat_state") as Dictionary
	var traps: Array = state.get("traps", []) as Array
	_expect(traps.size() == ELEMENTS.size(), "The live board should contain all five elemental traps")
	var textures: Dictionary = board.get("_trap_textures") as Dictionary
	var last_center := Vector2(-INF, -INF)
	for element: String in ELEMENTS:
		var texture: Texture2D = textures.get(element, null)
		_expect(texture != null, "%s should resolve through the live trap texture registry" % element)
		if texture != null:
			_expect(texture.get_size() == Vector2(122, 80), "%s should load the canonical 122x80 asset" % element)
		var trap: Dictionary = _trap_for_element(traps, element)
		_expect(not trap.is_empty(), "%s should be present in the deterministic combat fixture" % element)
		if trap.is_empty():
			continue
		var rect: Rect2 = board.call("_trap_draw_rect", trap.get("pos", Vector2i(-1, -1))) as Rect2
		_expect(rect.size.x > 0.0 and rect.size.y > 0.0, "%s should have a visible live draw rectangle" % element)
		if last_center.x > -INF:
			_expect(rect.get_center().x > last_center.x, "%s should appear to the right of the previous element" % element)
			_expect(is_equal_approx(rect.get_center().y, last_center.y), "%s should share the readable inspection row" % element)
		last_center = rect.get_center()


func _trap_for_element(traps: Array, element: String) -> Dictionary:
	for trap_var: Variant in traps:
		if typeof(trap_var) == TYPE_DICTIONARY:
			var trap: Dictionary = trap_var
			if str(trap.get("element", "")) == element:
				return trap
	return {}


func _save_screenshot(path: String) -> void:
	await process_frame
	RenderingServer.force_draw(true)
	await process_frame
	var image: Image = root.get_texture().get_image()
	if image.get_size() != SCREENSHOT_SIZE:
		# macOS exposes the Retina backing texture even though content_scale_size is
		# the requested logical proof viewport. Preserve that real Metal render and
		# downsample it to the exact review resolution.
		image.resize(SCREENSHOT_SIZE.x, SCREENSHOT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	_expect(image.save_png(path) == OK, "The trap proof screenshot should save successfully")


func _settle_ui(frames: int = 5) -> void:
	for _frame: int in range(frames):
		await process_frame


func _clear_probe_output(output_dir: String) -> void:
	var dir := DirAccess.open(output_dir)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
