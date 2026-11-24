extends RefCounted
## Visible surface membership, eight-neighbor patch edges and Ice glint ownership.

const Rules = preload("res://scripts/board_surface_rules.gd")
const ELEMENT_IDS: Dictionary = {"fire": 1, "ice": 2, "electrified": 3}
const RUBBLE: int = 4
const STORMCOAL: int = 8
const HERO_TEXELS_PER_TILE: float = 255.0 / 1.03
# This order matches the bit positions used by ground_surface_geometry.
const NEIGHBORS: Array = [
	Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)
]

var tiles: Dictionary = {}
var area: Rect2i
var kind_mask: int
var has_rubble: bool
var seed: int
var image: Image

func rebuild(state: Dictionary, rendered_tiles: Array[Vector2i], tile_visible: Callable) -> bool:
	var next_tiles: Dictionary = {}
	var surfaces: Dictionary = state.get("surfaces", {})
	if not surfaces.is_empty():
		for tile: Vector2i in rendered_tiles:
			var entry: Dictionary = Rules.surface_at(state, tile)
			if entry.is_empty() or not tile_visible.call(tile):
				continue
			var element: int = ELEMENT_IDS.get(Rules.kind(str(entry.get("elemental", ""))), 0)
			var kind: int = element | (RUBBLE if bool(entry.get("rubble", false)) else 0)
			if element == ELEMENT_IDS["fire"] and Rules.is_conductive(state, tile, true):
				kind |= STORMCOAL
			if kind != 0:
				next_tiles[tile] = kind
	var next_seed: int = int(state.get("fight_seed", 0))
	if tiles == next_tiles and seed == next_seed:
		return false
	tiles = next_tiles
	seed = next_seed
	kind_mask = 0
	has_rubble = false
	image = null
	area = Rect2i()
	if tiles.is_empty():
		return true

	var first: Vector2i = tiles.keys()[0]
	area = Rect2i(first, Vector2i.ONE)
	for tile: Vector2i in tiles:
		area = area.merge(Rect2i(tile, Vector2i.ONE))
		var kind: int = tiles[tile]
		kind_mask |= 1 << (kind & 3)
		has_rubble = has_rubble or (kind & RUBBLE) != 0
		if has_electrified_decal(kind):
			kind_mask |= 1 << ELEMENT_IDS["electrified"]
	# Two texels per tile. Floats retain board coordinates and component sizes
	# exactly, including large patches, and are sampled as raw data.
	image = Image.create_empty(area.size.x * 2, area.size.y, false, Image.FORMAT_RGBAF)
	var labeled: Dictionary = {}
	var ordered_tiles: Array = tiles.keys()
	ordered_tiles.sort()
	for tile: Vector2i in ordered_tiles:
		var kind: int = tiles[tile]
		var element: int = kind & 3
		var address: Vector2i = address_of(tile)
		var edge_mask: int = _neighbors(tile, element)
		image.set_pixelv(address, Color(kind, edge_mask, _neighbors(tile, kind & RUBBLE), 0))
		if element == ELEMENT_IDS["ice"] and not labeled.has(tile):
			_label_patch(tile, element, labeled)
	return true

func address_of(tile: Vector2i) -> Vector2i:
	return (tile - area.position) * Vector2i(2, 1)

func _neighbors(tile: Vector2i, kind: int) -> int:
	if kind == 0:
		return 0
	var result: int = 0
	for i: int in NEIGHBORS.size():
		var neighbor: int = tiles.get(tile + NEIGHBORS[i], 0)
		if tile_kind(neighbor, kind):
			result |= 1 << i
	return result

func _label_patch(first: Vector2i, element: int, labeled: Dictionary) -> void:
	var patch: Array[Vector2i]
	patch.append(first)
	var cursor: int = 0
	labeled[first] = true
	while cursor < patch.size():
		var tile: Vector2i = patch[cursor]
		cursor += 1
		for i: int in 4:
			var neighbor: Vector2i = tile + NEIGHBORS[i]
			if (int(tiles.get(neighbor, 0)) & 3) == element and not labeled.has(neighbor):
				labeled[neighbor] = true
				patch.append(neighbor)
	for i: int in patch.size():
		image.set_pixelv(address_of(patch[i]) + Vector2i.RIGHT, Color(first.x, first.y, i, patch.size()))

static func tile_kind(flags: int, kind: int) -> bool:
	return (flags & (RUBBLE if kind == RUBBLE else 3)) == kind

static func has_electrified_decal(flags: int) -> bool:
	return (flags & STORMCOAL) != 0 or tile_kind(flags, ELEMENT_IDS["electrified"])

static func world_hash(seed_value: int, key: Vector2i, kind: int, slot: int, slot_seed: int) -> int:
	return hash([seed_value, key, kind, slot, slot_seed])

static func hash_unit(bits: int) -> float:
	return float(bits & 0xffff) / 65536.0

static func cells_per_border_normal(tile_to_cell: Transform2D) -> Vector2:
	var inverse: Transform2D = tile_to_cell.affine_inverse()
	return Vector2(
		1.0 / Vector2(inverse.x.x, inverse.y.x).length(),
		1.0 / Vector2(inverse.x.y, inverse.y.y).length())
