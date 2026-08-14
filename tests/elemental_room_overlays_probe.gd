extends SceneTree

const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const ElementData = preload("res://scripts/element_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)
const OUTPUT_DIR: String = "user://elemental_room_overlays_probe"

var _errors: Array = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	root.add_child(viewport)
	var board: Control = CombatBoardView.new()
	board.size = Vector2(VIEWPORT_SIZE)
	viewport.add_child(board)
	board.set_process(false)
	await process_frame

	var family_ids: Array = []
	for element_id: String in ElementData.all_elements():
		var state: Dictionary = _state(element_id)
		board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"scene_props": []})
		await process_frame
		await process_frame
		family_ids.append(str(board.call("_element_overlay_family_id")))
		var image: Image = viewport.get_texture().get_image()
		var output_path: String = ProjectSettings.globalize_path("%s/%s_room.png" % [OUTPUT_DIR, element_id])
		_expect(image.get_size() == VIEWPORT_SIZE, "%s room proof must be exactly 1920x1080" % element_id)
		_expect(image.save_png(output_path) == OK, "%s room proof should save successfully" % element_id)

	var unique_families: Dictionary = {}
	for family_id: String in family_ids:
		unique_families[family_id] = true
	_expect(unique_families.size() == ElementData.all_elements().size(), "Every elemental room should resolve a distinct overlay family")
	if _errors.is_empty():
		print("ELEMENTAL ROOM OVERLAYS RESULT: PASS")
		print(ProjectSettings.globalize_path(OUTPUT_DIR))
		quit(0)
	else:
		for error: String in _errors:
			push_error(error)
		print("ELEMENTAL ROOM OVERLAYS RESULT: FAIL (%d errors)" % _errors.size())
		quit(1)

func _state(element_id: String) -> Dictionary:
	return {
		"name": "%s overlay proof" % ElementData.name(element_id),
		"room_coord": Vector2i(5, -3),
		"room_element": element_id,
		"grid": _grid(),
		"moss": {
			"floor": [
				Vector2i(2, 2), Vector2i(4, 2), Vector2i(6, 2),
				Vector2i(3, 3), Vector2i(5, 3),
				Vector2i(2, 4), Vector2i(4, 4), Vector2i(6, 4),
				Vector2i(3, 5), Vector2i(5, 5),
				Vector2i(2, 6), Vector2i(6, 6)
			],
			"wall": [Vector2i(2, 0), Vector2i(6, 0), Vector2i(0, 4), Vector2i(8, 4)],
			"pillar": [Vector2i(2, 3), Vector2i(6, 3), Vector2i(2, 5), Vector2i(6, 5)]
		},
		"elemental_intensity": {"fire": 0, "ice": 0, "lightning": 0, "air": 0, "earth": 0},
		"player": {},
		"enemies": [],
		"illusions": [],
		"npcs": [],
		"loot": [],
		"terrain": [],
		"traps": []
	}

func _grid() -> Array:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(9):
			var tile_id: String = "wall" if x == 0 or y == 0 or x == 8 or y == 8 else "stone"
			if Vector2i(x, y) in [Vector2i(2, 3), Vector2i(6, 3), Vector2i(2, 5), Vector2i(6, 5)]:
				tile_id = "pillar"
			row.append(tile_id)
		grid.append(row)
	return grid

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
