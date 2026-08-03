extends SceneTree

const CombatBoardViewScript = preload("res://scripts/combat_board_view.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

const OUTPUT_DIR: String = "user://combat_board_render_equivalence_probe"
const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)

var _errors: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	await process_frame

	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	root.add_child(viewport)
	var board: Control = CombatBoardViewScript.new()
	board.size = Vector2(VIEWPORT_SIZE)
	viewport.add_child(board)
	# The fixture intentionally excludes every wall-clock presentation effect.
	# Freezing processing also pins sprite-sheet animation to frame zero so a base
	# and candidate worktree produce directly comparable pixels.
	board.set_process(false)
	await process_frame

	var state: Dictionary = _probe_state()
	await _capture(viewport, board, state, _vector2i_array([]), _vector2i_array([]), Vector2i(-1, -1), {}, {}, {}, "idle.png")
	await _capture(
		viewport,
		board,
		state,
		_vector2i_array([Vector2i(3, 4), Vector2i(4, 4), Vector2i(4, 3)]),
		_vector2i_array([]),
		Vector2i(4, 3),
		{},
		{},
		{
			"focus_tiles": [Vector2i(3, 4), Vector2i(4, 4), Vector2i(4, 3)],
			"path_tiles": [Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(4, 3)],
			"movement_risk_chips": [{"tile": Vector2i(4, 3), "label": "TRAP 3", "kind": "danger"}]
		},
		"move_preview.png"
	)
	await _capture(
		viewport,
		board,
		state,
		_vector2i_array([]),
		_vector2i_array([Vector2i(5, 3), Vector2i(6, 3)]),
		Vector2i(5, 3),
		{},
		{},
		{
			"focus_tiles": [Vector2i(5, 3), Vector2i(6, 3)],
			"focus_color": Color(0.95, 0.48, 0.28, 0.20),
			"status_label": "Choose a target",
			"status_detail": "Static preview fixture"
		},
		"attack_preview.png"
	)
	await _capture(
		viewport,
		board,
		state,
		_vector2i_array([]),
		_vector2i_array([]),
		Vector2i(-1, -1),
		{Vector2i(7, 4): Vector2i(2, 1)},
		{Vector2i(7, 4): "combat"},
		{"focus_tiles": [Vector2i(7, 4)]},
		"room_exit.png"
	)

	var snapshot: Dictionary = board.call("render_instrumentation_snapshot") if board.has_method("render_instrumentation_snapshot") else {}
	if not snapshot.is_empty():
		_expect(bool(snapshot.get("split_layers_active", false)), "candidate board should expose its retained dynamic layer")
		_expect(int(snapshot.get("static_draw_count", 0)) < int(snapshot.get("dynamic_draw_count", 0)), "preview-only submissions should not redraw the static floor")
	if _errors.is_empty():
		print("COMBAT BOARD RENDER EQUIVALENCE RESULT: PASS")
		print(ProjectSettings.globalize_path(OUTPUT_DIR))
		quit(0)
	else:
		for error: String in _errors:
			push_error(error)
		print("COMBAT BOARD RENDER EQUIVALENCE RESULT: FAIL (%d errors)" % _errors.size())
		quit(1)

func _capture(
	viewport: SubViewport,
	board: Control,
	state: Dictionary,
	move_tiles: Array[Vector2i],
	attack_tiles: Array[Vector2i],
	selected_tile: Vector2i,
	exit_tiles: Dictionary,
	exit_icon_ids: Dictionary,
	presentation: Dictionary,
	file_name: String
) -> void:
	board.call(
		"set_combat_state",
		state,
		move_tiles,
		attack_tiles,
		selected_tile,
		str(presentation.get("status_label", "")),
		str(presentation.get("status_detail", "")),
		exit_tiles,
		exit_icon_ids,
		presentation
	)
	await process_frame
	await process_frame
	var image: Image = viewport.get_texture().get_image()
	var output_path: String = ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name])
	_expect(image.get_size() == VIEWPORT_SIZE, "%s must capture the standard 1920x1080 proof surface" % file_name)
	_expect(image.save_png(output_path) == OK, "%s could not be saved" % file_name)

func _probe_state() -> Dictionary:
	return {
		"name": "Retained Render Equivalence",
		"room_coord": Vector2i(11, -7),
		"room_element": "none",
		"grid": _probe_grid(),
		"moss": {},
		"player": {
			"pos": Vector2i(2, 4),
			"hp": 27,
			"max_hp": 30,
			"block": 4,
			"stoneskin": 0,
			"burn": 0,
			"bleed": 0
		},
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(6, 3),
			"hp": 15,
			"max_hp": 22,
			"block": 2,
			"stoneskin": 0,
			"intent": {
				"name": "Rend",
				"actions": [{"type": "melee", "damage": 6}]
			}
		}],
		"illusions": [],
		"npcs": [],
		"loot": [{"id": "vial", "kind": "healing_vial", "amount": 4, "pos": Vector2i(4, 2)}],
		"terrain": [{"id": "crate", "kind": "wooden_crate", "pos": Vector2i(3, 2), "hp": 8, "max_hp": 8}],
		"traps": [{"id": "trap", "element": "fire", "pos": Vector2i(4, 3), "damage": 3, "armed": true}],
		"player_turn_restrictions": {}
	}

func _probe_grid() -> Array:
	return [
		["wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall"],
		["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
		["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
		["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
		["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
		["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
		["wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall"]
	]

func _vector2i_array(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value: Variant in values:
		if typeof(value) == TYPE_VECTOR2I:
			result.append(value)
	return result

func _clear_probe_output(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
