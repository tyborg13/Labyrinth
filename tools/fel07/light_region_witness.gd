extends SceneTree

const Board = preload("res://scripts/combat_board_view.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Fixture = preload("res://tests/suites/board_surface_suite.gd")
const Checkpoint = preload("res://tools/fel01/checkpoint.gd")
const WALL_TILE := Vector2i(0, 0)
const INVALID_TILE := Vector2i(-1, -1)
const WALL_LIGHT := {"id": "fel07_wall_light", "pos": WALL_TILE, "radius": 2}
const SETTLE_FRAMES := 3


func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")


func _run() -> void:
	root.size = Checkpoint.VIEWPORT_SIZE
	var board := Board.new()
	board.size = Vector2(Checkpoint.VIEWPORT_SIZE)
	root.add_child(board)
	board.set_combat_state(Fixture.fixture(Combat.new()), [], [], INVALID_TILE, "", "", {}, {},
		{"umbra_light_sources": [WALL_LIGHT], "reduced_motion": true})
	for frame: int in range(SETTLE_FRAMES): await process_frame
	var rect: Rect2 = _light_rect(board)
	var point: Vector2 = rect.get_center()
	var transform: Transform2D = board.get_global_transform_with_canvas()
	var expected: String = board.controller_tooltip_for_tile(WALL_TILE)
	if not rect.has_area() or board._rendered_tiles_in_draw_order().has(WALL_TILE) \
			or board.tile_at_global_position(transform * point) != INVALID_TILE \
			or expected.is_empty() or board._get_tooltip(point) != expected:
		printerr("FEL07 WALL LIGHT FAIL: Expected the light's actual rect to open its popup outside the board")
		quit(1)
		return
	print("FEL07 WALL LIGHT PASS tile=%s pointer_tile=%s rect_match=true" % [WALL_TILE, INVALID_TILE])
	quit()


func _light_rect(board: Board) -> Rect2:
	var sources: Array = board._retained_render_layers()
	sources.append(board)
	for source: Control in sources:
		for index: int in source.get("_tile_tooltip_regions"):
			var entry: Dictionary = source.get("_tile_tooltip_regions")[index]
			if entry["tile"] == WALL_TILE and entry["tile_detail_key"] == WALL_LIGHT["id"]:
				return source.get("_tooltip_regions")[index]["rect"]
	return Rect2()
