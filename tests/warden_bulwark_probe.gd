extends SceneTree

const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

const OUTPUT_DIR: String = "user://warden_bulwark_probe"
const VIEWPORT_SIZE := Vector2i(1920, 1080)

var _failed: bool = false


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

	var before: Dictionary = _probe_state()
	var base_presentation: Dictionary = {
		"board_framing_mode": "combat",
		"visible_enemy_ids": [1, 2, 3],
		"expanded_enemy_actor_keys": ["enemy_1"],
		"reduced_motion": false,
	}
	await _capture(viewport, board, before, base_presentation, "warden_bulwark_before_1920x1080.png")

	var combat := CombatEngine.new()
	var action: Dictionary = (((before.get("enemies", []) as Array)[0] as Dictionary).get("intent", {}) as Dictionary).get("actions", [])[0] as Dictionary
	var before_snapshot: Dictionary = before.duplicate(true)
	var after: Dictionary = combat.call("_resolve_enemy_action", before.duplicate(true), 0, action)
	var step: Dictionary = combat.call("_enemy_action_step", before_snapshot, after, 0, action)
	_expect((step.get("targets", []) as Array).size() == 2, "Bulwark resolution should present both allies")
	var after_presentation: Dictionary = base_presentation.duplicate(true)
	after_presentation["focus_actor_keys"] = step.get("focus_actor_keys", [])
	after_presentation["focus_tiles"] = step.get("focus_tiles", [])
	after_presentation["focus_actor_color"] = Color("90d9ff")
	after_presentation["focus_color"] = Color(0.49, 0.73, 0.84, 0.18)
	after_presentation["effect"] = step
	after_presentation["effect_progress"] = 0.72
	after_presentation["floating_texts"] = _block_floats(step)
	await _capture(viewport, board, after, after_presentation, "warden_bulwark_after_1920x1080.png")

	if _failed:
		print("WARDEN BULWARK PROBE: FAIL")
		quit(1)
		return
	print("WARDEN BULWARK PROBE: PASS")
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)


func _capture(viewport: SubViewport, board: Control, state: Dictionary, presentation: Dictionary, file_name: String) -> void:
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
	await process_frame
	await process_frame
	RenderingServer.force_draw(true)
	var image: Image = viewport.get_texture().get_image()
	_expect(image.get_size() == VIEWPORT_SIZE, "%s should be 1920x1080" % file_name)
	var output_path: String = ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name])
	_expect(image.save_png(output_path) == OK, "%s should save" % file_name)


func _probe_state() -> Dictionary:
	var action := {"type": "guard_ally", "amount": 6, "target_mode": "all_other_enemies"}
	return {
		"name": "Warden Bulwark Proof",
		"room_coord": Vector2i(3, -2),
		"room_element": "none",
		"grid": _probe_grid(),
		"moss": {},
		"player": {"pos": Vector2i(2, 4), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0},
		"enemies": [
			_enemy(1, "warden", Vector2i(7, 4), 18, {"id": "bulwark", "name": "Bulwark", "actions": [action]}),
			_enemy(2, "crawler", Vector2i(5, 2), 10, {"id": "claw_rush", "name": "Claw Rush", "actions": [{"type": "melee", "damage": 6, "range": 1}]}),
			_enemy(3, "harrier", Vector2i(5, 6), 10, {"id": "spear_cast", "name": "Spear Cast", "actions": [{"type": "ranged", "damage": 5, "range": 5}]}),
		],
		"illusions": [],
		"npcs": [],
		"loot": [],
		"terrain": [],
		"traps": [],
		"player_turn_restrictions": {},
		"log": [],
	}


func _enemy(id: int, enemy_type: String, pos: Vector2i, hp: int, intent: Dictionary) -> Dictionary:
	return {
		"id": id,
		"type": enemy_type,
		"pos": pos,
		"hp": hp,
		"max_hp": hp,
		"block": 0,
		"stoneskin": 0,
		"burn": 0,
		"freeze": 0,
		"shock": 0,
		"intent": intent,
	}


func _probe_grid() -> Array:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(11):
			row.append("wall" if x == 0 or y == 0 or x == 10 or y == 8 else "stone")
		grid.append(row)
	return grid


func _block_floats(step: Dictionary) -> Array[Dictionary]:
	var floats: Array[Dictionary] = []
	for target_var: Variant in step.get("targets", []):
		var target: Dictionary = target_var as Dictionary
		floats.append({
			"tile": target.get("tile", Vector2i.ZERO),
			"text": "+%d" % int(target.get("amount", 0)),
			"color": Color("90d9ff"),
			"offset": -6.0,
		})
	return floats


func _clear_probe_output() -> void:
	var dir := DirAccess.open(OUTPUT_DIR)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
