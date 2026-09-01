extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

const OUTPUT_DIR: String = "user://probes/enemy_tactical_ai"
const BOARD_PATH: String = "BoardUnderlay/CombatBoard"
const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)
const INVALID_TILE: Vector2i = Vector2i(-999, -999)

var _errors: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.content_scale_size = VIEWPORT_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = VIEWPORT_SIZE
	ProgressionStore.set_storage_path("user://labyrinth_enemy_tactical_ai_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_enemy_tactical_ai_probe_run.save")
	ProgressionStore.clear_saved_run()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	await _capture_tactical_squad()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	if _errors.is_empty():
		print("ENEMY TACTICAL AI PROBE: PASS")
		quit(0)
		return
	for error: String in _errors:
		push_error(error)
	print("ENEMY TACTICAL AI PROBE: FAIL (%d errors)" % _errors.size())
	quit(1)

func _capture_tactical_squad() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_errors.append("Run scene should load for tactical enemy visual proof")
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle_ui()
	var run_engine := RunEngine.new()
	instance.call("_load_run_state", run_engine.create_new_run(52781, ProgressionStore.default_data()))
	await _settle_ui()

	var layout: Dictionary = _layout()
	var combat := CombatEngine.new()
	var state: Dictionary = combat.create_combat(52781, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["threaded_path"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0,
	})
	state["player"] = {"pos": Vector2i(2, 4), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	var enemies: Array = state.get("enemies", []) as Array
	var crawler: Dictionary = enemies[0] as Dictionary
	crawler["hp"] = 3
	enemies[0] = crawler
	state["enemies"] = enemies
	var rng := RandomNumberGenerator.new()
	rng.seed = 52781
	for enemy_index: int in range(enemies.size()):
		combat.call("_assign_enemy_intent", state, enemy_index, rng)
	state = combat.call("_initialize_initiative_queue", state) as Dictionary

	var intent_ids: Array[String]
	for enemy_var: Variant in state.get("enemies", []):
		var enemy: Dictionary = enemy_var as Dictionary
		intent_ids.append(str((enemy.get("intent", {}) as Dictionary).get("id", "")))
	_expect(intent_ids[0] in ["skitter_strike", "lunge"], "The wounded frontliner should keep pressuring from attack distance")
	_expect(intent_ids[1] == "triage_suture", "The Grave Surgeon should select a heal for the badly wounded frontliner")
	_expect(intent_ids[2] == "bulwark", "The Stone Warden should shield exposed squadmates")
	_expect(intent_ids[3] == "retreat_step", "The adjacent Bone Harrier should create distance")

	var surgeon_plan: Dictionary = combat.enemy_intent_plan(state, 1)
	_expect(_tiles(surgeon_plan.get("path", [])).size() == 1, "The support should hold its safe back-line tile while healing")
	var harrier_plan: Dictionary = combat.enemy_intent_plan(state, 3)
	var harrier_path: Array[Vector2i] = _tiles(harrier_plan.get("path", []))
	_expect(harrier_path.size() > 1, "The adjacent skirmisher should expose a real retreat path")
	if harrier_path.size() > 1:
		_expect(harrier_path[harrier_path.size() - 1].distance_to(Vector2i(2, 4)) > harrier_path[0].distance_to(Vector2i(2, 4)), "The visible retreat should increase separation")

	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout.duplicate(true)
	run_state["combat_state"] = state.duplicate(true)
	instance.set("_run_state", run_state)
	instance.set("_combat_state", state.duplicate(true))
	instance.set("_animation_lock", false)
	instance.set("_drag_card_index", -1)
	instance.set("_hovered_board_tile", INVALID_TILE)
	instance.set("_show_all_enemy_intents", true)
	instance.call("_reset_card_resolution")
	instance.call("_refresh_ui")
	await _settle_ui()
	instance.call("_on_board_tile_hovered", Vector2i(5, 3))
	await _settle_ui()
	var board: Control = instance.get_node(BOARD_PATH) as Control
	var presentation: Dictionary = board.get("presentation") as Dictionary
	_expect((presentation.get("enemy_threat_previews", []) as Array).size() == 4, "Show-all proof should expose all four role-aware intent previews")
	await _save_root_screenshot("%s/01_role_aware_squad.png" % OUTPUT_DIR)
	instance.queue_free()
	await process_frame

func _layout() -> Dictionary:
	return {
		"name": "Role-Aware Enemy Squad",
		"coord": Vector2i(2, 0),
		"depth": 2,
		"type": "combat",
		"umbra_stage": "clear",
		"grid": _grid(),
		"player_start": Vector2i(2, 4),
		"enemies": [
			_enemy("crawler", 1, Vector2i(4, 4)),
			_enemy("grave_surgeon", 2, Vector2i(6, 4)),
			_enemy("warden", 3, Vector2i(5, 3)),
			_enemy("harrier", 4, Vector2i(3, 4)),
		],
		"terrain": [],
		"traps": [],
		"loot": [],
	}

func _enemy(enemy_type: String, enemy_id: int, pos: Vector2i) -> Dictionary:
	var definition: Dictionary = GameData.enemy_def(enemy_type)
	var max_hp: int = int(definition.get("max_hp", 10))
	return {
		"id": enemy_id,
		"type": enemy_type,
		"pos": pos,
		"hp": max_hp,
		"max_hp": max_hp,
		"block": 0,
		"stoneskin": 0,
	}

func _grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array[String]
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return grid

func _tiles(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i]
	for value: Variant in values:
		if typeof(value) == TYPE_VECTOR2I:
			result.append(value)
	return result

func _settle_ui() -> void:
	for _frame: int in range(8):
		await process_frame

func _save_root_screenshot(output_path: String) -> void:
	await process_frame
	var image: Image = root.get_texture().get_image()
	if image.get_width() != VIEWPORT_SIZE.x or image.get_height() != VIEWPORT_SIZE.y:
		image.resize(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	if image.save_png(output_path) != OK:
		_errors.append("Tactical enemy probe could not save %s" % output_path)

func _clear_probe_output(output_dir: String) -> void:
	var dir := DirAccess.open(output_dir)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
