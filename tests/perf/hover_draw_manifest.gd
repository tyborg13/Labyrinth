extends RefCounted

static var _textures: Dictionary = {}

# Each board owns separate generated AtlasTexture/ImageTexture objects. Compare
# their exact source pixels and atlas selection rather than object identity.
static func texture(value: Texture2D) -> Array:
	if value == null: return []
	if _textures.has(value): return _textures[value]
	var description: Array = []
	if value is AtlasTexture:
		description = ["atlas", texture(value.atlas), value.region, value.margin, value.filter_clip]
	else:
		var image: Image = value.get_image()
		description = [value.get_class(), value.resource_path, value.get_size(), image.get_format(), image.get_data()]
	_textures[value] = description
	return description

# Record the complete per-tile inputs at the real retained draw boundary. The
# legacy renderer selects these independently for every tile. Both then execute
# their actual draw paths; the native probe compares their resulting pixels.
static func tile(board: Control, at: Vector2i, selected: Dictionary = {}) -> Array:
	var leader: Dictionary = selected.get("leader", board.WarbandView.command_leader(board))
	var marks: Array = selected.get("burrow_marks", board.BurrowView.marks(board.combat_state))
	var burst: Array = selected.get("burst_tiles", board.DeathBurstView.focused_tiles(board))
	var tags: Array = selected.get("zone_tags", board.ThreatTiles.zone_tags(board.presentation.get("threats_at_rest", {}).get("threats", [])))
	var polygon: PackedVector2Array = board._tile_polygon(at)
	var glow: Array = [] if leader.is_empty() else board.WarbandView.glow_fan(board.combat_state, leader, at, polygon, board.LEADER_MARKER_GOLD)
	var tile_marks: Array = []
	for mark: Dictionary in marks:
		if mark["tile"] == at: tile_marks.append(mark)
	var tile_tags: Array = []
	for tag: Dictionary in tags:
		if tag["tile"] == at and board._rest_threat_tile_alphas.has(at) and board._board_tile_is_visible_to_player(at): tile_tags.append(tag)
	return [at, polygon, glow, tile_marks, burst.has(at), tile_tags]
