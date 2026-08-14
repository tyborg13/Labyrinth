extends SceneTree

const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const EnemyIntentCompass = preload("res://scripts/enemy_intent_compass.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

const OUTPUT_DIR: String = "user://enemy_intent_compass_probe"
const VIEWPORT_SIZE := Vector2i(1920, 1080)

var _errors: Array[String] = []


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output()
	await process_frame

	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.msaa_2d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	root.add_child(viewport)
	var board: Control = CombatBoardView.new()
	board.size = Vector2(VIEWPORT_SIZE)
	viewport.add_child(board)
	board.set_process(false)
	await process_frame

	var state: Dictionary = _probe_state()
	var presentation: Dictionary = {
		"board_framing_mode": "combat",
		"visible_enemy_ids": [1, 2, 3, 4, 5, 6, 7],
		"reduced_motion": false,
		"enemy_intent_compasses": _probe_descriptors(),
	}
	await _capture(viewport, board, state, presentation, "intent_compass_all_families_1920x1080.png")
	var inspected: Dictionary = presentation.duplicate(true)
	inspected["expanded_enemy_actor_keys"] = ["enemy_2"]
	await _capture(viewport, board, state, inspected, "intent_compass_focused_inspection_1920x1080.png")
	var reduced: Dictionary = presentation.duplicate(true)
	reduced["reduced_motion"] = true
	await _capture(viewport, board, state, reduced, "intent_compass_reduced_motion_1920x1080.png")
	var dense: Dictionary = presentation.duplicate(true)
	dense["scene_props"] = [
		{"kind": "relic_chest", "tile": Vector2i(4, 3), "width_scale": 0.78, "baseline_scale": 0.44},
		{"kind": "blacksmith_forge", "tile": Vector2i(6, 3), "width_scale": 0.92, "baseline_scale": 0.48},
		{"kind": "arcanist_table", "tile": Vector2i(5, 5), "width_scale": 0.88, "baseline_scale": 0.46},
	]
	await _capture(viewport, board, state, dense, "intent_compass_dense_board_1920x1080.png")
	await _capture(viewport, board, _large_hidden_probe_state(), _large_hidden_presentation(), "intent_compass_large_hidden_1920x1080.png")

	_verify_layout(board, state)
	_verify_reduced_motion_equivalence(board, state, presentation)
	if _errors.is_empty():
		print("ENEMY INTENT COMPASS PROBE: PASS")
		print(ProjectSettings.globalize_path(OUTPUT_DIR))
		quit(0)
		return
	for error: String in _errors:
		push_error(error)
	print("ENEMY INTENT COMPASS PROBE: FAIL (%d errors)" % _errors.size())
	quit(1)


func _capture(viewport: SubViewport, board: Control, state: Dictionary, presentation: Dictionary, file_name: String) -> void:
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
	await process_frame
	await process_frame
	RenderingServer.force_draw(true)
	var image: Image = viewport.get_texture().get_image()
	var output_path: String = ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name])
	_expect(image.get_size() == VIEWPORT_SIZE, "%s should be 1920x1080" % file_name)
	_expect(image.save_png(output_path) == OK, "%s should save" % file_name)


func _verify_layout(board: Control, state: Dictionary) -> void:
	var tile_width: float = float(board.call("_tile_width"))
	var ring_diameter: float = tile_width * float(board.get_script().get_script_constant_map().get("INTENT_COMPASS_RING_TILE_SCALE", 0.0))
	var arm_scale: float = float(board.get_script().get_script_constant_map().get("INTENT_COMPASS_ARM_SCALE", 0.0))
	_expect(ring_diameter <= tile_width * 0.76, "Compass ring should spill only slightly beyond the tile's inscribed width")
	_expect(arm_scale >= 0.70 and arm_scale <= 0.82, "Compass arm should remain legible without reaching deeply into neighboring tiles")
	_expect(
		str(board.get_script().source_code).find("draw_texture(base_texture") < str(board.get_script().source_code).find("draw_texture(arm_texture"),
		"Compass arm should render over the circular face"
	)
	for enemy_var: Variant in state.get("enemies", []):
		var enemy: Dictionary = enemy_var as Dictionary
		var center: Vector2 = board.call("_intent_compass_center", enemy) as Vector2
		var texture: Texture2D = board.call("_texture_for_unit", enemy) as Texture2D
		var draw_rect: Rect2 = board.call("_unit_draw_rect", enemy) as Rect2
		var bounds: Rect2 = board.call("_unit_shadow_bounds_for_texture", texture) as Rect2
		var foot_point: Vector2 = board.call("_unit_shadow_foot_point", texture, draw_rect, bounds, str(enemy.get("type", ""))) as Vector2
		_expect(absf(center.x - foot_point.x) <= 0.01, "Compass should center on enemy %d's rendered sprite footprint" % int(enemy.get("id", -1)))
		_expect(absf(center.y - foot_point.y - float(board.call("_tile_height")) * 0.025) <= 0.01, "Compass should remain grounded directly beneath enemy %d" % int(enemy.get("id", -1)))


func _verify_reduced_motion_equivalence(board: Control, state: Dictionary, presentation: Dictionary) -> void:
	var reduced: Dictionary = presentation.duplicate(true)
	reduced["reduced_motion"] = true
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, reduced)
	_expect(
		(reduced.get("enemy_intent_compasses", {}) as Dictionary) == (presentation.get("enemy_intent_compasses", {}) as Dictionary),
		"Reduced motion should preserve the same static compass information"
	)


func _probe_state() -> Dictionary:
	return {
		"name": "Enemy Intent Compass Proof",
		"room_coord": Vector2i(8, -5),
		"room_element": "none",
		"grid": _probe_grid(),
		"moss": {},
		"player": {"pos": Vector2i(5, 4), "hp": 24, "max_hp": 24, "block": 3, "stoneskin": 0},
		"enemies": [
			_enemy(1, "crawler", Vector2i(3, 2), "Closing Cut", [{"type": "move_toward", "range": 2}, {"type": "melee", "damage": 7, "range": 1}]),
			_enemy(2, "harrier", Vector2i(7, 2), "Pinning Shot", [{"type": "ranged", "damage": 5, "range": 5}]),
			_enemy(3, "warden", Vector2i(2, 4), "Iron Guard", [{"type": "block", "amount": 6}]),
			_enemy(4, "grave_surgeon", Vector2i(8, 4), "Field Dressing", [{"type": "heal_ally", "amount": 4, "range": 4}]),
			_enemy(5, "lightning_wisp", Vector2i(3, 6), "Forked Storm", [{"type": "lightning_strikes", "damage": 4}]),
			_enemy(6, "crawler", Vector2i(7, 6), "Withdraw", [{"type": "move_away", "range": 3}]),
			_enemy(7, "cinder_ooze", Vector2i(5, 1), "Gathering Flame", [{"type": "intensity", "amount": 1}]),
		],
		"illusions": [], "npcs": [], "loot": [], "terrain": [], "traps": [],
		"player_turn_restrictions": {},
	}


func _probe_descriptors() -> Dictionary:
	return {
		"enemy_1": _descriptor(EnemyIntentCompass.FAMILY_MELEE, "melee", 7, Vector2i(3, 2), Vector2i(5, 3), "Closing Cut"),
		"enemy_2": _descriptor(EnemyIntentCompass.FAMILY_RANGED, "ranged", 5, Vector2i(7, 2), Vector2i(5, 4), "Pinning Shot"),
		"enemy_3": _descriptor(EnemyIntentCompass.FAMILY_DEFENSE, "block", 6, Vector2i(2, 4), Vector2i(5, 4), "Iron Guard"),
		"enemy_4": _descriptor(EnemyIntentCompass.FAMILY_SUPPORT, "heal_ally", 4, Vector2i(8, 4), Vector2i(7, 6), "Field Dressing"),
		"enemy_5": _descriptor(EnemyIntentCompass.FAMILY_AREA, "lightning_strikes", 4, Vector2i(3, 6), Vector2i(5, 4), "Forked Storm"),
		"enemy_6": _descriptor(EnemyIntentCompass.FAMILY_MOVEMENT, "move_away", 0, Vector2i(7, 6), Vector2i(8, 5), "Withdraw"),
		"enemy_7": _descriptor(EnemyIntentCompass.FAMILY_INTENSITY, "intensity", 1, Vector2i(5, 1), Vector2i(6, 2), "Gathering Flame"),
	}


func _large_hidden_probe_state() -> Dictionary:
	var state: Dictionary = _probe_state()
	(state.get("player", {}) as Dictionary)["pos"] = Vector2i(2, 6)
	state["enemies"] = [
		{
			"id": 70, "type": "zekarion", "pos": Vector2i(4, 2), "footprint": Vector2i(2, 2),
			"hp": 60, "max_hp": 60, "boss_bar": true, "block": 0, "stoneskin": 0,
			"intent": {"name": "Tempest Breath", "actions": [{"type": "ranged", "damage": 8, "range": 5}]},
		},
		_enemy(71, "crawler", Vector2i(8, 6), "Concealed Rend", [{"type": "melee", "damage": 9}]),
	]
	return state


func _large_hidden_presentation() -> Dictionary:
	return {
		"board_framing_mode": "combat",
		"visible_enemy_ids": [70],
		"reduced_motion": false,
		"enemy_intent_compasses": {
			"enemy_70": {
				"family": EnemyIntentCompass.FAMILY_RANGED, "action_type": "ranged", "value": 8,
				"origin_tile": Vector2i(4, 2), "target_tile": Vector2i(2, 6), "direction_reason": "target",
				"intent_name": "Tempest Breath", "footprint": Vector2i(2, 2),
			},
		},
	}


func _descriptor(family: String, action_type: String, value: int, origin: Vector2i, target: Vector2i, intent_name: String) -> Dictionary:
	return {
		"family": family, "action_type": action_type, "value": value,
		"origin_tile": origin, "target_tile": target, "direction_reason": "probe",
		"intent_name": intent_name, "footprint": Vector2i.ONE,
	}


func _enemy(id: int, type: String, pos: Vector2i, intent_name: String, actions: Array) -> Dictionary:
	return {
		"id": id, "type": type, "pos": pos, "hp": 12, "max_hp": 14,
		"block": 0, "stoneskin": 0, "burn": 0, "freeze": 0, "shock": 0,
		"intent": {"name": intent_name, "actions": actions},
	}


func _probe_grid() -> Array:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(11):
			row.append("wall" if x == 0 or y == 0 or x == 10 or y == 8 else "stone")
		grid.append(row)
	return grid


func _clear_probe_output() -> void:
	var dir := DirAccess.open(OUTPUT_DIR)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
