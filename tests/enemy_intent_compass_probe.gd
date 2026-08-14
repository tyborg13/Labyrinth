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
	await _capture(viewport, board, state, presentation, "intent_emblems_all_families_1920x1080.png")
	await _capture(viewport, board, state, presentation, "intent_emblems_enemy_turn_before_refresh_1920x1080.png")
	var refreshed_state: Dictionary = state.duplicate(true)
	for enemy_var: Variant in refreshed_state.get("enemies", []):
		var refreshed_enemy: Dictionary = enemy_var as Dictionary
		if int(refreshed_enemy.get("id", -1)) != 2:
			continue
		refreshed_enemy["intent"] = {"name": "Quick Guard", "actions": [{"type": "block", "amount": 5}]}
	var refreshed_presentation: Dictionary = presentation.duplicate(true)
	(refreshed_presentation.get("enemy_intent_compasses", {}) as Dictionary)["enemy_2"] = _descriptor(EnemyIntentCompass.FAMILY_DEFENSE, "block", 5)
	await _capture(viewport, board, refreshed_state, refreshed_presentation, "intent_emblems_enemy_turn_after_refresh_1920x1080.png")
	var inspected: Dictionary = presentation.duplicate(true)
	inspected["expanded_enemy_actor_keys"] = ["enemy_2"]
	await _capture(viewport, board, state, inspected, "intent_emblems_focused_inspection_1920x1080.png")
	var reduced: Dictionary = presentation.duplicate(true)
	reduced["reduced_motion"] = true
	await _capture(viewport, board, state, reduced, "intent_emblems_reduced_motion_1920x1080.png")
	var dense: Dictionary = presentation.duplicate(true)
	dense["scene_props"] = [
		{"kind": "relic_chest", "tile": Vector2i(4, 3), "width_scale": 0.78, "baseline_scale": 0.44},
		{"kind": "blacksmith_forge", "tile": Vector2i(6, 3), "width_scale": 0.92, "baseline_scale": 0.48},
		{"kind": "arcanist_table", "tile": Vector2i(5, 5), "width_scale": 0.88, "baseline_scale": 0.46},
	]
	await _capture(viewport, board, state, dense, "intent_emblems_dense_board_1920x1080.png")
	await _capture(viewport, board, _large_hidden_probe_state(), _large_hidden_presentation(), "intent_emblems_large_hidden_1920x1080.png")

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
	var constants: Dictionary = board.get_script().get_script_constant_map()
	var ring_diameter: float = tile_width * float(constants.get("INTENT_COMPASS_RING_TILE_SCALE", 0.0))
	var ring_source_diameter: float = float(constants.get("INTENT_COMPASS_RING_SOURCE_DIAMETER", 0.0))
	var max_ring_fill: float = float(constants.get("INTENT_COMPASS_EMBLEM_MAX_RING_FILL", 0.0))
	var underlay_scale: float = float(constants.get("INTENT_COMPASS_UNDERLAY_SCALE", 0.0))
	_expect(ring_diameter >= tile_width * 0.76 and ring_diameter <= tile_width * 0.82, "Compass ring should be slightly enlarged while spilling only minimally beyond its tile")
	_expect(
		str(board.get_script().source_code).find("draw_texture(base_texture") < str(board.get_script().source_code).find("draw_texture(emblem_texture"),
		"Compass emblem should render over the circular face"
	)
	_expect(is_equal_approx(float(board.call("_intent_compass_emblem_scale", EnemyIntentCompass.FAMILY_ATTACK)), 0.70), "Sword should retain its authored attack scale")
	_expect(is_equal_approx(float(board.call("_intent_compass_emblem_scale", EnemyIntentCompass.FAMILY_DEFENSE)), 0.52), "Shield should retain its smaller authored scale")
	_expect(is_equal_approx(float(board.call("_intent_compass_emblem_scale", EnemyIntentCompass.FAMILY_SUPPORT)), 0.52), "Heart-plus should retain its smaller authored scale")
	_expect(str(board.get_script().source_code).find("_draw_enemy_intent_compass_value") < 0, "Compass should not render the removed inline number")
	for family: String in [EnemyIntentCompass.FAMILY_ATTACK, EnemyIntentCompass.FAMILY_DEFENSE, EnemyIntentCompass.FAMILY_SUPPORT]:
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(EnemyIntentCompass.texture_path(family)))
		var opaque_extent: float = float(maxi(image.get_used_rect().size.x, image.get_used_rect().size.y))
		var family_scale: float = float(board.call("_intent_compass_emblem_scale", family))
		_expect(opaque_extent * family_scale * underlay_scale <= ring_source_diameter * max_ring_fill, "%s emblem and underlay should stay visibly inset inside the ring on both axes" % family)
	for enemy_var: Variant in state.get("enemies", []):
		var enemy: Dictionary = enemy_var as Dictionary
		var center: Vector2 = board.call("_intent_compass_center", enemy) as Vector2
		var tile: Vector2i = enemy.get("pos", Vector2i.ZERO)
		var tile_center: Vector2 = board.call("_tile_center", tile) as Vector2
		_expect(center.is_equal_approx(tile_center), "Compass should center exactly on enemy %d's logical tile" % int(enemy.get("id", -1)))


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
		"enemy_1": _descriptor(EnemyIntentCompass.FAMILY_ATTACK, "melee", 7),
		"enemy_2": _descriptor(EnemyIntentCompass.FAMILY_ATTACK, "ranged", 5),
		"enemy_3": _descriptor(EnemyIntentCompass.FAMILY_DEFENSE, "block", 6),
		"enemy_4": _descriptor(EnemyIntentCompass.FAMILY_SUPPORT, "heal_ally", 4),
		"enemy_5": _descriptor(EnemyIntentCompass.FAMILY_ATTACK, "lightning_strikes", 4),
		"enemy_6": _descriptor(EnemyIntentCompass.FAMILY_ATTACK, "move_away", 0),
		"enemy_7": _descriptor(EnemyIntentCompass.FAMILY_SUPPORT, "intensity", 1),
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
			"enemy_70": _descriptor(EnemyIntentCompass.FAMILY_ATTACK, "ranged", 8),
		},
	}


func _descriptor(family: String, action_type: String, value: int) -> Dictionary:
	return {
		"family": family, "action_type": action_type, "value": value,
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
