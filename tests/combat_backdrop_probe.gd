extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const OUTPUT_DIR: String = "user://combat_backdrop_probe"
const BOARD_PATH: String = "BoardUnderlay/CombatBoard"
const BACKDROP_PATH: String = "BoardUnderlay/CombatBackdrop"

var _errors: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://labyrinth_progression_combat_backdrop_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_combat_backdrop_probe.save")
	SettingsStore.set_storage_path("user://labyrinth_settings_combat_backdrop_probe.json")
	ProgressionStore.clear_saved_run()
	SettingsStore.clear_storage()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)

	await _capture_configuration(Vector2i(1920, 1080), 1.00, 62001)
	await _capture_configuration(Vector2i(1280, 720), 1.00, 62002)
	await _capture_configuration(Vector2i(1280, 800), 1.25, 62003)

	var defaults: Dictionary = SettingsStore.default_settings()
	SettingsStore.save_settings(defaults)
	SettingsStore.apply_settings(defaults, root, false)
	if _errors.is_empty():
		print("COMBAT BACKDROP PROBE: PASS")
		print("COMBAT_BACKDROP_PROOF_DIR=%s" % ProjectSettings.globalize_path(OUTPUT_DIR))
		quit(0)
	else:
		for error: String in _errors:
			push_error(error)
		print("COMBAT BACKDROP PROBE: FAIL (%d errors)" % _errors.size())
		quit(1)

func _capture_configuration(resolution: Vector2i, ui_scale: float, seed: int) -> void:
	DisplayServer.window_set_size(resolution)
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = ui_scale
	settings["reduced_motion"] = true
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	await _settle_ui()

	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_expect(packed != null, "%s @ %d%% should load the run scene" % [resolution, roundi(ui_scale * 100.0)])
	if packed == null:
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle_ui()
	instance.call("_load_run_state", RunEngine.new().create_new_run(seed, ProgressionStore.default_data()))
	if bool(instance.get("_dialogue_active")):
		instance.call("_close_dialogue")
	var initial_backdrop: TextureRect = instance.get_node(BACKDROP_PATH) as TextureRect
	_expect(initial_backdrop != null and not initial_backdrop.visible, "%s should keep the dungeon backdrop hidden outside combat" % resolution)
	await _load_combat_fixture(instance, seed)
	await _settle_ui()

	var label: String = "%dx%d_ui%d" % [resolution.x, resolution.y, roundi(ui_scale * 100.0)]
	var backdrop: TextureRect = instance.get_node(BACKDROP_PATH) as TextureRect
	var board: Control = instance.get_node(BOARD_PATH) as Control
	_expect(backdrop != null and backdrop.visible, "%s should show the dungeon backdrop during combat" % label)
	_expect(backdrop != null and backdrop.texture != null, "%s should load the project-bound dungeon texture" % label)
	_expect(
		backdrop != null and backdrop.get_global_rect().encloses(instance.get_viewport().get_visible_rect()),
		"%s backdrop should cover the complete visible combat canvas" % label
	)
	_expect(board != null and bool((board.get("presentation") as Dictionary).get("combat_backdrop_visible", false)), "%s board should expose the transparent combat-underlay state" % label)
	if board != null:
		var player_tile: Vector2i = ((board.get("combat_state") as Dictionary).get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1))
		var depth_faces: Array = board.call("_tile_depth_faces", player_tile)
		_expect(depth_faces.size() == 2, "%s player tile should render two depth faces" % label)
		var player_center: Vector2 = board.call("world_position_for_tile", player_tile)
		_expect(board.call("_tile_at_point", player_center) == player_tile, "%s tile depth should preserve top-face hit testing" % label)
	await _save_screenshot("%s/%s_idle.png" % [OUTPUT_DIR, label], resolution)

	instance.call("_on_card_pressed", 0)
	await _settle_ui()
	var preview: Dictionary = instance.call("_active_card_preview") as Dictionary
	var target_tiles: Array = preview.get("target_tiles", []) as Array
	_expect(not target_tiles.is_empty(), "%s targeting proof should expose at least one legal tile" % label)
	if not target_tiles.is_empty():
		instance.call("_on_board_tile_hovered", target_tiles[0])
		await _settle_ui()
		_expect((board.get("attack_tiles") as Array).has(target_tiles[0]), "%s target proof should keep the hovered attack tile highlighted" % label)
	await _save_screenshot("%s/%s_target.png" % [OUTPUT_DIR, label], resolution)

	instance.call("_on_cancel_requested")
	instance.queue_free()
	await _settle_ui()

func _load_combat_fixture(instance: Node, seed: int) -> void:
	var layout: Dictionary = {
		"name": "Sealed Hall",
		"coord": Vector2i(2, 0),
		"type": "combat",
		"element": "fire",
		"grid": _combat_grid(),
		"player_start": Vector2i(2, 4),
		"enemies": [
			{"id": 1, "type": "crawler", "pos": Vector2i(3, 4), "hp": 22, "max_hp": 22, "block": 0},
			{"id": 2, "type": "acolyte", "pos": Vector2i(6, 2), "hp": 24, "max_hp": 24, "block": 0}
		],
		"loot": [{"id": "vial", "kind": "healing_vial", "amount": 4, "pos": Vector2i(5, 4)}],
		"traps": [{"id": "trap", "element": "fire", "pos": Vector2i(4, 3), "damage": 3, "armed": true}],
		"terrain": [{"id": "crate", "kind": "wooden_crate", "pos": Vector2i(5, 2), "hp": 8, "max_hp": 8}]
	}
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(seed, layout, {
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

func _combat_grid() -> Array:
	var grid: Array = []
	for y: int in range(7):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x == 0 or x == 8 or y == 0 or y == 6 else "stone")
		grid.append(row)
	return grid

func _settle_ui() -> void:
	for _frame: int in range(5):
		await process_frame

func _save_screenshot(path: String, expected_size: Vector2i) -> void:
	await process_frame
	RenderingServer.force_draw(true)
	await process_frame
	var image: Image = root.get_texture().get_image()
	_expect(image.get_size() == expected_size, "%s should capture at exact resolution %s, got %s" % [path, expected_size, image.get_size()])
	_expect(image.save_png(path) == OK, "%s should save successfully" % path)

func _clear_probe_output(output_dir: String) -> void:
	var dir := DirAccess.open(output_dir)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
