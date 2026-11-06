extends RefCounted

# A retained tile owns this helper. Decode the surface once and snapshot only
# resources the stone painter can consume, rather than every biome's overlay
# atlas on every warm redraw. PropCommandCache still snapshots mutable atlas
# region/margin/source geometry, so an in-place texture edit invalidates paint.
# Stone only reads grid dimensions for boundary faces/orientation. Its resolved
# tile ID and selected moss encode cell/door/biome changes in the paint key.
var _surface_tile := Vector2i(-1, -1)
var _surface_key: String = ""

func surface_key(tile: Vector2i) -> String:
	if _surface_key.is_empty() or tile != _surface_tile:
		_surface_tile = tile
		_surface_key = preload("res://scripts/board_surface_rules.gd").tile_key(tile)
	return _surface_key

func stone_textures(board: Control, tile_id: String, grid: Array, tile: Vector2i) -> Array:
	var textures: Array = []
	if tile_id == "pillar":
		textures.append(board._prop_textures.get("pillar", null))
	else:
		textures.append(board._prop_textures.get("wall_row", board._prop_textures.get("wall", null)))
		textures.append(board._prop_textures.get("wall_col", board._prop_textures.get("wall", null)))
	# Moss uses the ordinary wall body even when boundary faces have their own
	# textures. Include it and the exact selected (possibly flipped) overlay.
	var moss: bool = board._tile_has_moss(tile_id, tile)
	textures.append(moss)
	if moss:
		var orientation: String = board._wall_orientation_for_tile(grid, tile) if tile_id == "wall" else ""
		textures.append(board._prop_textures.get("wall_%s" % orientation, board._prop_textures.get("wall", null)) if tile_id == "wall" else board._prop_textures.get("pillar", null))
		textures.append(board._moss_texture_for_surface(tile_id, tile, orientation == "col"))
	return textures
