extends RefCounted

# Dock/objective layout asks for these same nonanimated tile/prop rectangles
# repeatedly. Doors and actors stay live in rendered_visual_rects. Cache by
# content, verify full equality after hashing, and publish caller-owned arrays.
var _key: int = 0
var _source: Array = []
var _rects: Dictionary = {}
var builds: int = 0

func resolve(board: Control) -> Dictionary:
	var source: Array = _inputs(board)
	var key: int = hash(source)
	if _source.is_empty() or key != _key or source != _source:
		_source = source.duplicate(true)
		_key = key
		_rects = _build(board)
		builds += 1
	return _rects.duplicate(true)

func _inputs(board: Control) -> Array:
	var shapes: Dictionary = {}
	for name: String in board._prop_textures:
		var texture: Texture2D = board._prop_textures[name]
		shapes[name] = [texture != null, texture.get_size() if texture != null else Vector2.ZERO]
	# Torch textures are loaded separately from the prop registry.
	for side: String in ["left", "right"]:
		var texture: Texture2D = board._pillar_torch_texture(side)
		shapes["torch_" + side] = [texture != null, texture.get_size() if texture != null else Vector2.ZERO]
	return [board.size, board._board_layout_cache_tile_width, board._board_layout_cache_origin,
		board._board_layout_cache_tiles, board._board_layout_cache_tile_centers, board._board_layout_cache_tile_polygons,
		board.combat_state.get("grid", []), shapes]

func _build(board: Control) -> Dictionary:
	var result: Dictionary = {}
	var grid: Array = board.combat_state.get("grid", [])
	for tile: Vector2i in board._board_layout_cache_tiles:
		var rects: Array[Rect2]
		result[tile] = rects
		var polygon: PackedVector2Array = board._tile_polygon(tile)
		if not polygon.is_empty():
			var bounds := Rect2(polygon[0], Vector2.ZERO)
			for point: Vector2 in polygon: bounds = bounds.expand(point)
			rects.append(bounds)
		if not board._tile_in_grid(grid, tile): continue
		var tile_id: String = str(grid[tile.y][tile.x])
		# Door visibility, animation and medallions are evaluated by the caller.
		if tile_id == "door": continue
		if tile_id == "wall" and not board._is_outer_boundary_tile(grid, tile): tile_id = "pillar"
		if tile_id == "pillar":
			var texture: Texture2D = board._prop_textures.get("pillar", null)
			if texture != null:
				var rect: Rect2 = board._prop_draw_rect(texture, board._prop_rect_for_tile(tile))
				rects.append(rect)
				for side: String in ["left", "right"]:
					var torch: Texture2D = board._pillar_torch_texture(side)
					if torch != null: rects.append(board._pillar_torch_rect(rect, torch, -1.0 if side == "left" else 1.0))
		elif tile_id == "wall":
			for segment: Dictionary in board._boundary_prop_segments(tile_id, grid, tile): rects.append(segment.get("draw_rect", Rect2()))
	return result
