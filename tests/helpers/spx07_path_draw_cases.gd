extends RefCounted

const Board = preload("res://scripts/combat_board_view.gd")
const Arena = preload("res://tests/suites/warband_suite.gd")
const PROOF_BOARD_SIZES: Array = [Vector2(1200, 800), Vector2(1500, 900)]
const PROOF_PATHS: Array = [
	[Vector2i(2, 2), Vector2i(3, 2)],
	[Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(4, 3)],
	[Vector2i(4, 4), Vector2i(4, 3), Vector2i(3, 3), Vector2i(2, 3), Vector2i(2, 4)],
	[Vector2i(6, 5), Vector2i(5, 5), Vector2i(4, 5), Vector2i(3, 5), Vector2i(3, 4), Vector2i(3, 3)]
]

static func run(expect: Callable) -> void:
	var board := Board.new()
	board.combat_state = Arena.arena()
	board.presentation = {}
	var comparisons: int = 0
	for board_size: Vector2 in PROOF_BOARD_SIZES:
		board.size = board_size
		for source: Array in PROOF_PATHS:
			var path: Array[Vector2i]
			path.assign(source)
			for color: Color in [board.MOVE_PATH_COLOR, board.ENEMY_PATH_PREVIEW_COLOR]:
				var tiles: Array[Vector2i] = path.duplicate()
				tiles.append(Vector2i(-1, -1))
				tiles.append(Vector2i(7, 7))
				for tile: Vector2i in tiles:
					var expected: Array = _capture(board, path, color, tile, false)
					var actual: Array = _capture(board, path, color, tile, true)
					if tile.x < 0 or path.has(tile): expect.call(not expected.is_empty(), "Reference path emits real geometry in every owned depth tile")
					expect.call(actual == expected, "Cached path draw commands equal original geometry, colour, clipping and order")
					expect.call(_capture(board, path, color, tile, true) == expected, "Warm path/clip cache retains exact commands")
					_check_batches(expect, expected)
					comparisons += 1
	board.free()
	print("SPX07 PATH DRAW RESULT: %d exact cold/warm command comparisons with original depth renderer" % comparisons)
	print("SPX07 PATH BATCH RESULT: polygon triangles, RGBA and antialiased line ordering match original commands")

static func _check_batches(expect: Callable, commands: Array) -> void:
	var expected: Array
	var actual: Array
	for command: Dictionary in commands:
		if command.has("polygon"):
			for index: int in Geometry2D.triangulate_polygon(command["polygon"]):
				var point: Vector2 = command["polygon"][index]
				expected.append({"point": Vector3(point.x, point.y, 0), "color": command["color"]})
		else: expected.append(command)
	var cache := preload("res://scripts/board_path_draw_cache.gd").new()
	cache.make_batches(commands, func(batch: Dictionary) -> void:
		if batch.has("vertices"):
			for index: int in batch["indices"]: actual.append({"point": batch["vertices"][index], "color": batch["colors"][index]})
		else: actual.append(batch))
	expect.call(actual == expected, "Mesh batches preserve every triangle, RGBA value and interleaved line in paint order")

static func _capture(board: Control, path: Array[Vector2i], color: Color, tile: Vector2i, cached: bool) -> Array:
	var empty: Array[Dictionary]
	board.set("_path_captured_commands", empty)
	board.set("_path_command_capture_active", true)
	board.set("_path_depth_tile", tile)
	board.set("_path_depth_clip", board.call("_tile_polygon", tile) if tile.x >= 0 else PackedVector2Array())
	board.call("_draw_path_tiles" if cached else "_draw_path_tiles_uncached", path, color)
	var result: Array = (board.get("_path_captured_commands") as Array).duplicate(true)
	board.set("_path_command_capture_active", false)
	return result
