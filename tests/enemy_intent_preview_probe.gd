extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

const OUTPUT_DIR: String = "user://probes/enemy_intent_preview"
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
	ProgressionStore.set_storage_path("user://labyrinth_enemy_intent_preview_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_enemy_intent_preview_probe_run.save")
	ProgressionStore.clear_saved_run()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	await _capture_intent_preview_states()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	if _errors.is_empty():
		print("ENEMY INTENT PREVIEW PROBE: PASS")
		quit(0)
		return
	for error: String in _errors:
		push_error(error)
	print("ENEMY INTENT PREVIEW PROBE: FAIL (%d errors)" % _errors.size())
	quit(1)

func _capture_intent_preview_states() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_errors.append("Run scene should load for enemy intent preview visual proof")
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle_ui()
	var run_engine := RunEngine.new()
	instance.call("_load_run_state", run_engine.create_new_run(41027, ProgressionStore.default_data()))
	await _settle_ui()
	var combat := CombatEngine.new()

	var stationary_layout: Dictionary = _layout("Stationary Ranged Preview", _open_grid())
	var stationary_state: Dictionary = _combat_state(
		combat,
		stationary_layout,
		Vector2i(2, 4),
		Vector2i(5, 4),
		_stationary_ranged_intent()
	)
	await _install_state(instance, stationary_layout, stationary_state)
	instance.call("_on_board_tile_hovered", Vector2i(5, 4))
	await _settle_ui()
	_assert_stationary_preview(instance, Vector2i(5, 4), Vector2i(2, 4))
	await _save_root_screenshot("%s/01_stationary_ranged_no_move_stub.png" % OUTPUT_DIR)

	var moving_grid: Array = _open_grid()
	(moving_grid[4] as Array)[4] = "pillar"
	var moving_layout: Dictionary = _layout("Move Then Ranged Preview", moving_grid)
	var moving_state: Dictionary = _combat_state(
		combat,
		moving_layout,
		Vector2i(2, 4),
		Vector2i(5, 4),
		{
			"name": "Find a Lane",
			"actions": [
				{"type": "move_toward", "range": 2},
				{"type": "ranged", "damage": 4, "range": 4}
			]
		}
	)
	await _install_state(instance, moving_layout, moving_state)
	instance.call("_on_board_tile_hovered", Vector2i(5, 4))
	await _settle_ui()
	var moving_threat: Dictionary = _first_threat(instance)
	_assert_moving_ranged_preview(instance, moving_threat, Vector2i(2, 4))
	await _save_root_screenshot("%s/02_move_echo_then_ranged.png" % OUTPUT_DIR)

	var retarget_layout: Dictionary = _layout("Live Player Preview Retarget", _open_grid())
	var retarget_state: Dictionary = _combat_state(
		combat,
		retarget_layout,
		Vector2i(2, 4),
		Vector2i(6, 4),
		_stationary_ranged_intent()
	)
	await _install_state(instance, retarget_layout, retarget_state)
	var player_actions: Array = [
		{"type": "move", "range": 2},
		{"type": "block", "amount": 3}
	]
	var move_target := Vector2i(3, 4)
	_set_manual_card_preview(instance, retarget_state, player_actions, 0, _tiles([move_target]), move_target)
	instance.set("_show_all_enemy_intents", true)
	instance.call("_mark_preview_selection_changed")
	instance.call("_refresh_stage_view")
	await _settle_ui()
	_assert_intent_target(instance, move_target, "hovered move")
	var hover_presentation: Dictionary = _board_presentation(instance)
	_expect(_tiles(hover_presentation.get("path_tiles", [])).size() >= 2, "Hovered move proof should keep the player's current movement arrow")
	await _save_root_screenshot("%s/03_hovered_move_retargets_intent.png" % OUTPUT_DIR)

	var later_state: Dictionary = combat.apply_player_action(retarget_state.duplicate(true), player_actions[0], move_target)
	_set_manual_card_preview(instance, later_state, player_actions, 1, _tiles([]), INVALID_TILE)
	instance.set("_show_all_enemy_intents", true)
	instance.call("_mark_preview_selection_changed")
	instance.call("_refresh_stage_view")
	await _settle_ui()
	_assert_intent_target(instance, move_target, "later card action")
	_expect(((instance.get("_combat_state") as Dictionary).get("player", {}) as Dictionary).get("pos", INVALID_TILE) == Vector2i(2, 4), "Later-action preview should not mutate the committed player position")
	await _save_root_screenshot("%s/04_later_action_keeps_retarget.png" % OUTPUT_DIR)

	instance.set("_selected_card_index", -1)
	instance.set("_preview_combat_state", {})
	instance.set("_pending_actions", [])
	instance.set("_pending_action_index", 0)
	instance.set("_pending_target_tiles", _tiles([]))
	instance.set("_hovered_board_tile", INVALID_TILE)
	instance.set("_show_all_enemy_intents", true)
	instance.call("_mark_preview_selection_changed")
	instance.call("_refresh_stage_view")
	await _settle_ui()
	_assert_intent_target(instance, Vector2i(2, 4), "canceled preview")
	await _save_root_screenshot("%s/05_cancel_restores_committed_target.png" % OUTPUT_DIR)

	await _install_state(instance, moving_layout, moving_state)
	var reduced_settings: Dictionary = (instance.get("_settings") as Dictionary).duplicate(true)
	reduced_settings["reduced_motion"] = true
	instance.set("_settings", reduced_settings)
	instance.call("_on_board_tile_hovered", Vector2i(5, 4))
	await _settle_ui()
	var reduced_board: Control = instance.get_node(BOARD_PATH) as Control
	_expect(not bool(reduced_board.call("_preview_unit_pulse_active")), "Reduced motion should stop destination-echo pulsing")
	var reduced_preview_units: Array = (_board_presentation(instance).get("preview_units", []) as Array)
	for unit_var: Variant in reduced_preview_units:
		if typeof(unit_var) != TYPE_DICTIONARY or str((unit_var as Dictionary).get("role", "")) != "enemy_move_preview":
			continue
		_expect(not bool(reduced_board.call("_unit_idle_animation_active", unit_var as Dictionary)), "Reduced motion should stop destination-echo idle-sheet animation")
	await _save_root_screenshot("%s/06_reduced_motion_static_echo.png" % OUTPUT_DIR)

	instance.queue_free()
	await process_frame

func _set_manual_card_preview(
	instance: Node,
	preview_state: Dictionary,
	actions: Array,
	action_index: int,
	target_tiles: Array[Vector2i],
	hovered_tile: Vector2i
) -> void:
	instance.set("_selected_card_index", 0)
	instance.set("_preview_combat_state", preview_state.duplicate(true))
	instance.set("_pending_actions", actions.duplicate(true))
	instance.set("_pending_action_index", action_index)
	instance.set("_pending_action_can_skip", false)
	instance.set("_pending_target_tiles", target_tiles)
	instance.set("_hovered_board_tile", hovered_tile)

func _assert_stationary_preview(instance: Node, expected_from: Vector2i, expected_target: Vector2i) -> void:
	var board: Control = instance.get_node(BOARD_PATH) as Control
	var presentation: Dictionary = _board_presentation(instance)
	var threat: Dictionary = _first_threat(instance)
	_expect(not threat.is_empty(), "Stationary ranged proof should expose an exact enemy threat")
	_expect(not bool(board.call("_threat_has_projected_movement", threat)), "Stationary ranged proof should have no drawable movement path")
	_expect(not presentation.has("projected_destination"), "Stationary ranged proof should omit the legacy destination marker")
	_expect(_enemy_destination_units(presentation).is_empty(), "Stationary ranged proof should omit translucent destination copies")
	var effect: Dictionary = board.call("_enemy_threat_ranged_effect", threat)
	_expect(effect.get("from", INVALID_TILE) == expected_from and effect.get("to", INVALID_TILE) == expected_target, "Stationary ranged ribbon should connect the current attacker and target tiles")

func _assert_moving_ranged_preview(instance: Node, threat: Dictionary, expected_target: Vector2i) -> void:
	var board: Control = instance.get_node(BOARD_PATH) as Control
	var presentation: Dictionary = _board_presentation(instance)
	var path: Array[Vector2i] = _tiles(threat.get("projected_path", []))
	var destination: Vector2i = threat.get("projected_destination", INVALID_TILE)
	_expect(path.size() >= 2 and path[path.size() - 1] == destination, "Move+ranged proof should expose a real movement arrow ending at the destination")
	var destination_units: Array[Dictionary] = _enemy_destination_units(presentation)
	_expect(destination_units.size() == 1 and destination_units[0].get("pos", INVALID_TILE) == destination, "Move+ranged proof should show one enemy copy at the landing tile")
	var effect: Dictionary = board.call("_enemy_threat_ranged_effect", threat)
	_expect(effect.get("from", INVALID_TILE) == destination and effect.get("to", INVALID_TILE) == expected_target, "Move+ranged proof should launch its ribbon from the destination copy")

func _assert_intent_target(instance: Node, expected_target: Vector2i, scenario: String) -> void:
	var threat: Dictionary = _first_threat(instance)
	_expect(not threat.is_empty(), "%s should retain a visible enemy threat" % scenario)
	_expect(threat.get("projected_attack_target", INVALID_TILE) == expected_target, "%s should target %s" % [scenario, expected_target])

func _first_threat(instance: Node) -> Dictionary:
	var threats: Array = _board_presentation(instance).get("enemy_threat_previews", []) as Array
	return threats[0] as Dictionary if not threats.is_empty() and typeof(threats[0]) == TYPE_DICTIONARY else {}

func _enemy_destination_units(presentation: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for unit_var: Variant in presentation.get("preview_units", []):
		if typeof(unit_var) == TYPE_DICTIONARY and str((unit_var as Dictionary).get("role", "")) == "enemy_move_preview":
			result.append(unit_var as Dictionary)
	return result

func _board_presentation(instance: Node) -> Dictionary:
	var board: Control = instance.get_node(BOARD_PATH) as Control
	return board.get("presentation") as Dictionary

func _install_state(instance: Node, layout: Dictionary, combat_state: Dictionary) -> void:
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout.duplicate(true)
	run_state["combat_state"] = combat_state.duplicate(true)
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state.duplicate(true))
	instance.set("_animation_lock", false)
	instance.set("_drag_card_index", -1)
	instance.set("_hovered_board_tile", INVALID_TILE)
	instance.set("_show_all_enemy_intents", false)
	instance.call("_reset_card_resolution")
	instance.call("_refresh_ui")
	await _settle_ui()

func _combat_state(combat: CombatEngine, layout: Dictionary, player_pos: Vector2i, enemy_pos: Vector2i, intent: Dictionary) -> Dictionary:
	var state: Dictionary = combat.create_combat(41027, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["guarded_step"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["player"] = {"pos": player_pos, "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	state["enemies"] = [{
		"id": 1,
		"type": "harrier",
		"name": "Preview Harrier",
		"pos": enemy_pos,
		"hp": 14,
		"max_hp": 14,
		"block": 0,
		"stoneskin": 0,
		"intent": intent.duplicate(true)
	}]
	state["terrain"] = []
	state["traps"] = []
	state["illusions"] = []
	state["current_actor"] = {"kind": "player", "key": "player"}
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["guarded_step"]
	state["deck"] = deck
	return state

func _stationary_ranged_intent() -> Dictionary:
	return {
		"name": "Steady Shot",
		"actions": [
			{"type": "move_toward", "range": 3},
			{"type": "ranged", "damage": 4, "range": 4}
		]
	}

func _layout(room_name: String, grid: Array) -> Dictionary:
	return {
		"name": room_name,
		"coord": Vector2i(1, 0),
		"type": "combat",
		"depth": 1,
		"umbra_stage": "clear",
		"grid": grid.duplicate(true),
		"player_start": Vector2i(2, 4),
		"enemies": [],
		"terrain": [],
		"traps": [],
		"loot": []
	}

func _open_grid() -> Array:
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
		_errors.append("Enemy intent preview probe could not save %s" % output_path)

func _clear_probe_output(output_dir: String) -> void:
	var dir := DirAccess.open(output_dir)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
