extends SceneTree

## Inspection fixture for the player's Meteorfall marks on the combat board
## (spec/card_mechanics_surfaces.md): a marked three-tile line, one tile under an
## enemy, one under the hero, next to ordinary Fire for contrast.

const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const OUTPUT_DIR: String = "user://probes/meteor_marks_board"
const VIEWPORT_SIZE := Vector2i(1920, 1080)

var _errors: Array[String]
var _viewport: SubViewport
var _board: Control

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_viewport = SubViewport.new()
	_viewport.size = VIEWPORT_SIZE
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_board = CombatBoardView.new()
	_board.size = Vector2(VIEWPORT_SIZE)
	_viewport.add_child(_board)
	await process_frame
	_board.set_process(false)
	var presentation := {"ambient_time_seconds": 42.0, "umbra_time_seconds": 42.0, "reduced_motion": true}
	var unmarked: Image = await _render(_fixture(false), presentation)
	var marked: Image = await _render(_fixture(true), presentation)
	_expect(marked.save_png(ProjectSettings.globalize_path(OUTPUT_DIR.path_join("01_meteor_marks.png"))) == OK, "The marked board must save native pixels")
	var changed: int = 0
	for y: int in range(0, VIEWPORT_SIZE.y, 3):
		for x: int in range(0, VIEWPORT_SIZE.x, 3):
			var a: Color = unmarked.get_pixel(x, y)
			var b: Color = marked.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.06:
				changed += 1
	_expect(changed > 300, "Meteorfall marks must visibly change the marked tiles (changed samples: %d)" % changed)
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	if _errors.is_empty():
		print("METEOR MARKS BOARD PROBE: PASS")
		quit(0)
	else:
		for error: String in _errors:
			push_error(error)
		print("METEOR MARKS BOARD PROBE: FAIL")
		quit(1)

func _render(state: Dictionary, presentation: Dictionary) -> Image:
	_board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
	await process_frame
	await process_frame
	var result: Image = _viewport.get_texture().get_image()
	_expect(result.get_size() == VIEWPORT_SIZE, "The probe must render 1920x1080 directly")
	return result

func _fixture(with_marks: bool) -> Dictionary:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x == 0 or y == 0 or x == 8 or y == 8 else "stone")
		grid.append(row)
	var state: Dictionary = {
		"room_coord": Vector2i(3, 2), "room_element": "none", "grid": grid, "moss": {},
		"player": {"pos": Vector2i(3, 4), "hp": 24, "max_hp": 24},
		"enemies": [{"id": 1, "type": "crawler", "pos": Vector2i(5, 4), "hp": 18, "max_hp": 18}, {"id": 2, "type": "acolyte", "pos": Vector2i(5, 6), "hp": 12, "max_hp": 12}],
		"illusions": [], "npcs": [], "traps": [], "terrain": [], "loot": [], "umbra": {"stage": "clear"},
		"surfaces": {"6,6": {"elemental": "fire"}},
	}
	if with_marks:
		state["meteor_marks"] = [{"tiles": [Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4)], "damage": 8, "element": "fire", "surface": "fire", "card_id": "meteorfall"}]
	return state

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
