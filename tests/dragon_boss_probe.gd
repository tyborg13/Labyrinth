extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const DragonBossLibrary = preload("res://scripts/dragon_boss_library.gd")
const GameData = preload("res://scripts/game_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RoomGenerator = preload("res://scripts/room_generator.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const RUN_SCENE = preload("res://scenes/run_scene.tscn")

const OUTPUT_ROOT: String = "user://dragon_boss_probe_v1"
const RESOLUTION: Vector2i = Vector2i(1920, 1080)
const BOSS_PROOFS: Array[Dictionary] = [
	{"id": "tharokh", "depth": 4},
	{"id": "vyraketh", "depth": 8},
	{"id": "vaeloryx", "depth": 12},
	{"id": "iskaldra", "depth": 16},
	{"id": "zekarion", "depth": 20},
	{"id": "noctyrax", "depth": 24}
]

var _failed: bool = false
var _output_dir: String = ""

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_configure_window()
	_output_dir = "%s/%dx%d" % [OUTPUT_ROOT, RESOLUTION.x, RESOLUTION.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_dir))
	_clear_probe_output(_output_dir)
	ProgressionStore.set_storage_path("user://dragon_boss_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://dragon_boss_probe_run.save")
	ProgressionStore.clear_saved_run()
	call_deferred("_capture_bosses")

func _capture_bosses() -> void:
	await process_frame
	var instance: Node = RUN_SCENE.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	instance.call("_close_dialogue")
	var progression: Dictionary = ProgressionStore.default_data()
	for proof: Dictionary in BOSS_PROOFS:
		var boss_id: String = str(proof.get("id", ""))
		var depth: int = int(proof.get("depth", 4))
		var state: Dictionary = _boss_run_state(boss_id, depth, progression)
		instance.call("_load_run_state", state)
		instance.call("_close_dialogue")
		await process_frame
		await process_frame
		await create_timer(0.12).timeout
		_assert_loaded_boss(instance, boss_id, false)
		await _capture("%02d_%s_ready.png" % [depth, boss_id])

		var combat_state: Dictionary = state.get("combat_state", {}) as Dictionary
		var boss_index: int = _boss_index(combat_state)
		if boss_index < 0:
			_fail("%s proof should find a boss actor" % boss_id)
			continue
		combat_state = CombatEngine.new().resolve_enemy_turn_with_steps(combat_state, boss_index, false).get("state", combat_state) as Dictionary
		state["combat_state"] = combat_state
		state["current_room_layout"] = _layout_from_combat(combat_state)
		instance.call("_load_run_state", state)
		instance.call("_close_dialogue")
		await process_frame
		await process_frame
		await create_timer(0.12).timeout
		_assert_loaded_boss(instance, boss_id, true)
		await _capture("%02d_%s_gimmick.png" % [depth, boss_id])
		if boss_id != DragonBossLibrary.LIGHTNING_BOSS_ID:
			var before_death: Dictionary = combat_state.duplicate(true)
			var after_death: Dictionary = combat_state.duplicate(true)
			var after_enemies: Array = (after_death.get("enemies", []) as Array).duplicate(true)
			var after_boss: Dictionary = (after_enemies[boss_index] as Dictionary).duplicate(true)
			after_boss["hp"] = 0
			after_enemies[boss_index] = after_boss
			after_death["enemies"] = after_enemies
			var death_presentation: Dictionary = instance.call("_death_hold_presentation", before_death, after_death, {}) as Dictionary
			var death_units: Array = death_presentation.get("death_animation_units", [])
			if death_units.size() != 1 or str((death_units[0] as Dictionary).get("type", "")) != boss_id:
				_fail("%s should produce its own in-game death presentation unit" % boss_id)
			else:
				var death_unit: Dictionary = (death_units[0] as Dictionary).duplicate(true)
				death_unit["death_frame"] = 7
				death_unit["death_progress"] = 0.47
				death_presentation["death_animation_units"] = [death_unit]
			instance.call("_render_board_state", after_death, death_presentation)
			await process_frame
			await process_frame
			await _capture("%02d_%s_death.png" % [depth, boss_id])
	instance.queue_free()
	await process_frame
	print(ProjectSettings.globalize_path(_output_dir))
	quit(1 if _failed else 0)

func _boss_run_state(boss_id: String, depth: int, progression: Dictionary) -> Dictionary:
	var seed: int = 99431 + depth * 101
	var run_engine := RunEngine.new()
	var state: Dictionary = run_engine.create_new_run(seed, progression)
	var coord := Vector2i(depth, 0)
	var room: Dictionary = {
		"coord": coord,
		"depth": depth,
		"type": "boss",
		"element": DragonBossLibrary.element_for_boss(boss_id),
		"boss_id": boss_id,
		"connections": [],
		"npcs": [],
		"revealed": true,
		"visited": true,
		"cleared": false,
		"sealed": false
	}
	var layout: Dictionary = RoomGenerator.new().generate_room(seed, room, Vector2i.RIGHT)
	var combat_state: Dictionary = CombatEngine.new().create_combat(seed, layout, {
		"hp": 360,
		"max_hp": 360,
		"deck_cards": state.get("deck_cards", []).duplicate(),
		"relics": [],
		"hand_size": 5,
		"cards_per_turn": 2,
		"draw_per_turn": 2,
		"heal_bonus": 0
	})
	state["rooms"] = {_room_key(coord): room}
	state["current_room"] = coord
	state["current_room_layout"] = layout
	state["combat_state"] = combat_state
	state["mode"] = "combat"
	state["notice"] = ""
	return state

func _layout_from_combat(combat_state: Dictionary) -> Dictionary:
	return {
		"name": combat_state.get("room_name", "Dragon's Perch"),
		"coord": combat_state.get("room_coord", Vector2i.ZERO),
		"depth": int(combat_state.get("room_depth", 1)),
		"type": "boss",
		"element": combat_state.get("room_element", "none"),
		"boss_id": combat_state.get("boss_id", ""),
		"grid": (combat_state.get("grid", []) as Array).duplicate(true),
		"moss": (combat_state.get("moss", {}) as Dictionary).duplicate(true),
		"player_start": (combat_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO),
		"npcs": [],
		"enemies": (combat_state.get("enemies", []) as Array).duplicate(true),
		"traps": (combat_state.get("traps", []) as Array).duplicate(true),
		"loot": (combat_state.get("loot", []) as Array).duplicate(true),
		"terrain": (combat_state.get("terrain", []) as Array).duplicate(true)
	}

func _assert_loaded_boss(instance: Node, boss_id: String, after_gimmick: bool) -> void:
	var combat_state: Dictionary = instance.get("_combat_state") as Dictionary
	var current_layout: Dictionary = (instance.get("_run_state") as Dictionary).get("current_room_layout", {}) as Dictionary
	var expected_room_name: String = DragonBossLibrary.room_name_for_boss(boss_id)
	if str(instance.call("_room_title_text", current_layout)) != expected_room_name:
		_fail("%s proof should surface the authored arena title %s" % [boss_id, expected_room_name])
	var boss_index: int = _boss_index(combat_state)
	if boss_index < 0:
		_fail("%s should remain present in its visual proof" % boss_id)
		return
	var boss: Dictionary = (combat_state.get("enemies", []) as Array)[boss_index] as Dictionary
	if str(boss.get("type", "")) != boss_id:
		_fail("%s proof loaded the wrong boss actor" % boss_id)
	var board: Control = instance.get_node_or_null("BoardUnderlay/CombatBoard") as Control
	if board == null or not board.visible:
		_fail("%s proof should render the tactical board" % boss_id)
	if after_gimmick and boss_id != "zekarion" and not bool(boss.get("boss_mechanic_opened", false)):
		_fail("%s opening gimmick should mark itself active" % boss_id)
	match boss_id:
		"tharokh":
			if after_gimmick and not _state_has_terrain_kind(combat_state, "dragon_spire"):
				_fail("Tharokh gimmick proof should render Worldspines")
		"vyraketh":
			if after_gimmick and not _state_has_trap_kind(combat_state, "cinder_mark"):
				_fail("Vyraketh gimmick proof should render cinder marks")
		"iskaldra":
			if after_gimmick and int(boss.get("frost_armor", 0)) <= 0:
				_fail("Iskaldra gimmick proof should render crystal armor status")
		"noctyrax":
			if after_gimmick and int((combat_state.get("umbra", {}) as Dictionary).get("boss_eclipse_activations", 0)) <= 0:
				_fail("Noctyrax gimmick proof should enter Eclipse")

func _boss_index(state: Dictionary) -> int:
	var enemies: Array = state.get("enemies", []) as Array
	for index: int in range(enemies.size()):
		var enemy: Dictionary = enemies[index] as Dictionary
		if bool(GameData.enemy_def(str(enemy.get("type", ""))).get("boss_bar", false)):
			return index
	return -1

func _state_has_terrain_kind(state: Dictionary, kind: String) -> bool:
	for terrain_var: Variant in state.get("terrain", []):
		if typeof(terrain_var) == TYPE_DICTIONARY and str((terrain_var as Dictionary).get("kind", "")) == kind:
			return true
	return false

func _state_has_trap_kind(state: Dictionary, kind: String) -> bool:
	for trap_var: Variant in state.get("traps", []):
		if typeof(trap_var) == TYPE_DICTIONARY and str((trap_var as Dictionary).get("boss_hazard_kind", "")) == kind:
			return true
	return false

func _configure_window() -> void:
	root.content_scale_size = RESOLUTION
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = RESOLUTION
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(RESOLUTION)

func _capture(filename: String) -> void:
	await process_frame
	await process_frame
	var image: Image = root.get_viewport().get_texture().get_image()
	if image.get_size() != RESOLUTION:
		image.resize(RESOLUTION.x, RESOLUTION.y, Image.INTERPOLATE_LANCZOS)
	var error: Error = image.save_png("%s/%s" % [_output_dir, filename])
	if error != OK:
		_fail("Could not save %s" % filename)

func _room_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

func _clear_probe_output(output_dir: String) -> void:
	_clear_probe_output_absolute(ProjectSettings.globalize_path(output_dir))

func _clear_probe_output_absolute(absolute_dir: String) -> void:
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry.is_empty():
			break
		if entry in [".", ".."]:
			continue
		var child_path: String = absolute_dir.path_join(entry)
		if dir.current_is_dir():
			_clear_probe_output_absolute(child_path)
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	dir.list_dir_end()

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	print("TEST RESULT: FAIL %s" % message)
