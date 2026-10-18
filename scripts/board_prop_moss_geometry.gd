extends RefCounted

# Drawing and retained-layer invalidation must tint the same overlay rectangle.
# Moss can overlap an object that the larger stone body does not (or vice versa).
static func for_tile(board: Control, tile_id: String, grid: Array, tile: Vector2i) -> Dictionary:
	if tile_id not in ["pillar", "wall"] or not board._tile_has_moss(tile_id, tile):
		return {}
	var orientation: String = ""
	var body_texture: Texture2D
	if tile_id == "pillar":
		body_texture = board._prop_textures.get("pillar", null)
	else:
		orientation = board._wall_orientation_for_tile(grid, tile)
		if orientation.is_empty():
			return {}
		body_texture = board._prop_textures.get("wall_%s" % orientation, board._prop_textures.get("wall", null))
	if body_texture == null:
		return {}
	var draw_rect: Rect2 = board._prop_draw_rect(body_texture, board._prop_rect_for_tile(tile))
	var texture: Texture2D = board._moss_texture_for_surface(tile_id, tile, orientation == "col")
	if texture == null:
		return {}
	var moss_rect: Rect2 = board._pillar_moss_rect(draw_rect) if tile_id == "pillar" else board._wall_moss_rect(draw_rect)
	return {"tile": tile, "tile_id": tile_id, "rect": moss_rect, "texture": texture, "part": "moss"}
