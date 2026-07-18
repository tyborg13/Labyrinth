extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const DragonBossLibrary = preload("res://scripts/dragon_boss_library.gd")
const GameData = preload("res://scripts/game_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RoomGenerator = preload("res://scripts/room_generator.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const RUN_SCENE = preload("res://scenes/run_scene.tscn")

const OUTPUT_ROOT: String = "user://dragon_boss_probe_v3"
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
	var boss_filter: String = OS.get_environment("LABYRINTH_DRAGON_PROBE_BOSS").strip_edges().to_lower()
	for proof: Dictionary in BOSS_PROOFS:
		var boss_id: String = str(proof.get("id", ""))
		if not boss_filter.is_empty() and boss_id != boss_filter:
			continue
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
		if boss_id == DragonBossLibrary.SHADOW_BOSS_ID:
			await _capture_noctyrax_visibility_safe_move_preview(instance, combat_state)
			await _capture_noctyrax_target_highlight(instance, combat_state)
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

func _capture_noctyrax_target_highlight(instance: Node, combat_state: Dictionary) -> void:
	var action := {"type": "ranged", "damage": 10, "range": 12}
	var target_tiles: Array[Vector2i] = CombatEngine.new().valid_targets_for_player_action(combat_state, action)
	var board: Control = instance.get_node_or_null("BoardUnderlay/CombatBoard") as Control
	if board == null:
		_fail("Noctyrax targeting proof should find the combat board")
		return
	var presentation: Dictionary = {"pulse_attack_tiles": true}
	instance.call("_apply_umbra_board_presentation", combat_state, presentation)
	var move_tiles: Array[Vector2i] = []
	board.call(
		"set_combat_state",
		combat_state,
		move_tiles,
		target_tiles,
		(combat_state.get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1)),
		"",
		"",
		{},
		{},
		presentation
	)
	await process_frame
	await process_frame
	var highlight_tiles: Array = board.call("_large_enemy_attack_highlight_tiles", board.call("_visible_units")) as Array
	if highlight_tiles.size() != 4:
		_fail("Noctyrax targeting proof should apply the standard target treatment to all four footprint tiles, found %d" % highlight_tiles.size())
	await _capture("24_noctyrax_targets.png")

func _capture_noctyrax_visibility_safe_move_preview(instance: Node, combat_state: Dictionary) -> void:
	var combat := CombatEngine.new()
	var actions: Array = (GameData.card_def("dawnstep").get("actions", []) as Array).duplicate(true)
	var move_action: Dictionary = actions[0] as Dictionary
	var vision_action: Dictionary = actions[1] as Dictionary
	var before_visible_ids: Array[int] = combat.visible_enemy_ids(combat_state)
	var chosen_target := Vector2i(-1, -1)
	var simulated_state: Dictionary = {}
	for target: Vector2i in combat.valid_targets_for_player_action(combat_state, move_action):
		var candidate: Dictionary = combat.apply_player_action(combat_state, move_action, target)
		candidate = combat.apply_player_action(candidate, vision_action)
		if combat.visible_enemy_ids(candidate).size() > before_visible_ids.size():
			chosen_target = target
			simulated_state = candidate
			break
	if chosen_target.x < 0:
		_fail("Noctyrax move-preview proof should find a destination whose simulated Dawnstep reveals new information")
		return
	var planned_path: Array[Vector2i] = combat.path_for_player_action(combat_state, move_action, chosen_target)
	instance.set("_combat_state", combat_state)
	instance.set("_selected_card_index", 0)
	instance.set("_pending_actions", actions)
	instance.set("_pending_action_index", actions.size())
	instance.set("_pending_selected_targets", instance.call("_vector2i_array", [chosen_target]))
	instance.set("_pending_target_tiles", instance.call("_vector2i_array", []))
	instance.set("_preview_combat_state", simulated_state)
	instance.set("_pending_umbra_commit_locked", false)
	instance.set("_board_presentation", {
		"path_tiles": planned_path,
		"effect": {
			"kind": "move",
			"from": (combat_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO),
			"to": chosen_target,
			"preview": true
		}
	})
	instance.call("_refresh_stage_view")
	await process_frame
	await process_frame
	var board: Control = instance.get_node_or_null("BoardUnderlay/CombatBoard") as Control
	if board == null:
		_fail("Noctyrax move-preview proof should find the combat board")
		return
	var rendered_state: Dictionary = board.get("combat_state") as Dictionary
	var rendered_presentation: Dictionary = board.get("presentation") as Dictionary
	if (rendered_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO) != (combat_state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO):
		_fail("Unconfirmed Dawnstep should not render its simulated movement or hidden collision outcome")
	var rendered_visible_ids: Array = rendered_presentation.get("visible_enemy_ids", []) as Array
	if rendered_visible_ids.size() != before_visible_ids.size():
		_fail("Unconfirmed Dawnstep should not reveal Noctyrax's concealed minions")
	if int(rendered_presentation.get("umbra_radius", -1)) != combat.effective_umbra_radius(combat_state):
		_fail("Unconfirmed Dawnstep should not expand the rendered Umbra vision radius")
	await _capture("24_noctyrax_move_preview.png")
	instance.set("_board_presentation", {})
	instance.call("_reset_card_resolution")
	instance.call("_refresh_stage_view")
	await process_frame

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
	var turn_order_panel: Control = instance.get("_turn_order_panel") as Control
	if board != null and turn_order_panel != null and turn_order_panel.visible:
		var boss_name_rect: Rect2 = board.call("_boss_health_name_rect") as Rect2
		var boss_name_global_y: float = board.get_global_rect().position.y + boss_name_rect.position.y
		if boss_name_global_y - turn_order_panel.get_global_rect().end.y < 20.0:
			_fail("%s boss name and health HUD should keep visible breathing room below the turn-order panel" % boss_id)
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
