extends RefCounted

# Foreground motes sample their original clock on every authored redraw. Only
# the pillar roster and fitted rectangles are invariant; keep tint, torch-frame
# selection, flame anchors and all particle commands live in the board renderer.
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
		var grid: Array = board.combat_state.get("grid", [])
		for tile: Vector2i in tiles:
			if board._tile_renders_as_pillar(grid, tile):
				_placements.append({"tile": tile, "rect": board._prop_draw_rect(texture, board._prop_rect_for_tile(tile))})
		_initialized = true
		builds += 1
	return _placements
