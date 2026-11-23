extends RefCounted

const Gallery = preload("res://tools/grd01/fixtures.gd")
const Ground = Gallery.Ground
const SIZE := Gallery.SIZE
const GROUNDS: PackedStringArray = ["fire", "ice", "rubble", "electrified", "stormcoal", "plain", "merged"]
const UNITS: PackedStringArray = ["player", "crawler", "harrier", "craghide"]
const FIRST_TILE := Vector2i(1, 19)
const COLUMN_STEP := Vector2i(3, -3)
const ROW_STEP := Vector2i(2, 2)
const GRID_SIZE := Vector2i(26, 26)
const CAMERA_ZOOM: float = 1.10
const CROP_PADDING_TILES := Vector2(0.25, 0.25)
const MERGED_GROUNDS: PackedStringArray = ["fire", "ice"]
const MERGED_ROWS: PackedInt32Array = [0, 2]
const MERGED_SIZE := Vector2i(2, 2)

static func tile_at(column: int, row: int) -> Vector2i:
	return FIRST_TILE + column * COLUMN_STEP + row * ROW_STEP

static func roster_rows(column: int) -> PackedInt32Array:
	return MERGED_ROWS if GROUNDS[column] == "merged" else PackedInt32Array([0, 1, 2, 3])

static func merged_tiles(column: int, row: int) -> Array[Vector2i]:
	return Gallery.tiles_in(Rect2i(tile_at(column, row), MERGED_SIZE))

static func state_for(column: int) -> Dictionary:
	var state: Dictionary = Gallery.Attack.combat_state()
	state["room_coord"] = Gallery.DEPTH
	var grid: Array = []
	for y: int in GRID_SIZE.y:
		var row: Array = []
		row.resize(GRID_SIZE.x)
		row.fill("stone")
		grid.append(row)
	state["grid"] = grid
	state["player"]["pos"] = tile_at(column, 0)
	var enemies: Array[Dictionary]
	for row: int in roster_rows(column):
		if row == 0: continue
		var unit_type: String = UNITS[row]
		var hp: int = int(GameData.enemies()[unit_type]["max_hp"])
		enemies.append({"id": row, "type": unit_type, "pos": tile_at(column, row), "hp": hp, "max_hp": hp})
	state["enemies"] = enemies
	var ground: String = GROUNDS[column]
	if ground == "stormcoal":
		state["surface_rule_overrides"] = {"conductive_fire": true}
	if ground == "merged":
		for patch: int in MERGED_ROWS.size():
			for tile: Vector2i in merged_tiles(column, MERGED_ROWS[patch]):
				Ground.place(state, tile, MERGED_GROUNDS[patch])
	elif ground != "plain":
		for row: int in UNITS.size():
			Ground.place(state, tile_at(column, row), "fire" if ground == "stormcoal" else ground)
	return state

static func frame_room(board: Control, state: Dictionary) -> void:
	# Resolve the combat projection before any retained actor canvas is born.
	# Zooming after the roster submission leaves those canvases on the old
	# projection even though the floor and outline advance to the new one.
	var room: Dictionary = state.duplicate(false)
	room["player"] = {}
	room["enemies"] = []
	room["surfaces"] = {}
	submit(board, room)
	board.call("set_navigation_zoom", CAMERA_ZOOM)

static func submit(board: Control, state: Dictionary) -> void:
	Gallery.submit(board, state, {
		"biome_id": "stone", "board_framing_mode": "combat",
		"board_encounter_types": Array(UNITS).slice(1),
		"ambient_time_seconds": Gallery.PROOF_SECONDS,
		"umbra_time_seconds": Gallery.PROOF_SECONDS,
	})
	# Legacy surface canvases pick up the fixed clock on their continuous redraw.
	board.call("_queue_continuously_animated_scene_redraws")

static func crop_for(board: Control, footprint: Array[Vector2i]) -> Rect2i:
	var transform: Transform2D = board.get_global_transform_with_canvas()
	var first: Vector2 = transform * board.call("world_position_for_tile", footprint[0])
	var bounds := Rect2(first, Vector2.ZERO)
	for tile: Vector2i in footprint:
		for point: Vector2 in board.call("_tile_polygon", tile):
			bounds = bounds.expand(transform * point)
	var padding: Vector2 = CROP_PADDING_TILES * float(board.call("_tile_width"))
	var start := Vector2i((bounds.position - padding).floor())
	var finish := Vector2i((bounds.end + padding).ceil())
	return Rect2i(start, finish - start)

static func band_for(board: Control, column: int) -> Rect2i:
	var center: float = _column_x(board, column)
	var left: int = 0 if column == 0 else roundi((center + _column_x(board, column - 1)) * 0.5)
	var right: int = SIZE.x if column == GROUNDS.size() - 1 else roundi((center + _column_x(board, column + 1)) * 0.5)
	return Rect2i(left, 0, right - left, SIZE.y)

static func _column_x(board: Control, column: int) -> float:
	var center: Vector2 = board.call("world_position_for_tile", tile_at(column, 0))
	return (board.get_global_transform_with_canvas() * center).x

static func xy(value: Vector2) -> Array:
	return [value.x, value.y]

static func rect_pixels(value: Rect2) -> Array:
	return xy(value.position) + xy(value.size)
