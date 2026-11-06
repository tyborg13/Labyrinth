extends RefCounted

# Foreground motes sample their original clock on every authored redraw. Only
# the pillar roster, fitted rectangles, obstruction tint and flame anchors are
# invariant. Keep torch-frame selection and all particle commands live.
# Owned value inputs detect in-place grid/door/layout edits and texture resizing.
var _inputs: Array = []
var _placements: Array[Dictionary]
var _initialized: bool = false
var builds: int = 0

func resolve(board: Control, tiles: Array[Vector2i], texture: Texture2D) -> Array[Dictionary]:
	board._ensure_board_layout_cache()
	var inputs: Array = [
		board.combat_state.get("grid", []), tiles, board.exit_tiles,
		board.presentation.get("active_door_tiles", {}),
		board.presentation.get("locked_door_tiles", {}),
		board._board_layout_cache_tile_width, board._board_layout_cache_tile_centers,
		texture.get_size()
	]
	if not _initialized or inputs != _inputs:
		_inputs = inputs.duplicate(true)
		_placements.clear()
		_tints.clear()
		_flame_points.clear()
		var grid: Array = board.combat_state.get("grid", [])
		for tile: Vector2i in tiles:
			if board._tile_renders_as_pillar(grid, tile):
				_placements.append({"tile": tile, "rect": board._prop_draw_rect(texture, board._prop_rect_for_tile(tile))})
		_initialized = true
		builds += 1
	return _placements

# These caches hold one value per tile/side, replacing it on geometry or actor
# obstruction changes. They never retain an animated texture or particle pose.
var _tints: Dictionary = {}
var _flame_points: Dictionary = {}

func tint(board: Control, tile: Vector2i, rect: Rect2, entries: Array) -> Color:
	var inputs: Array = [rect, entries]
	var entry: Dictionary = _tints.get(tile, {})
	if entry.is_empty() or entry["inputs"] != inputs:
		entry = {"inputs": inputs.duplicate(true), "tint": board._pillar_torch_tint(board._foreground_blocker_tint("pillar", tile, rect, entries))}
		_tints[tile] = entry
	return entry["tint"]

func flame_point(board: Control, tile: Vector2i, rect: Rect2, texture: Texture2D, side: String, side_sign: float) -> Vector2:
	var sides: Dictionary = _flame_points.get(tile, {})
	var entry: Dictionary = sides.get(side, {})
	var inputs: Array = [rect, texture.get_size(), side_sign]
	if entry.is_empty() or entry["inputs"] != inputs:
		entry = {"inputs": inputs, "point": board._pillar_torch_flame_point(board._pillar_torch_rect(rect, texture, side_sign), side_sign)}
		sides[side] = entry
		_flame_points[tile] = sides
	return entry["point"]
