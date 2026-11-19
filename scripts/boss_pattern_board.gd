extends RefCounted
## The last exact grid and sight-blocker revision. No cache data enters a save.

const Patterns = preload("res://scripts/committed_pattern_shapes.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const RAY_CAPACITY: int = 1024
const FOOTPRINT_CAPACITY: int = 256

var _grid: Array
var _floor: Dictionary = {}
var _blockers: Dictionary
var _rays: Dictionary = {}
var _transparent_stone_rays: Dictionary = {}
var _footprints: Dictionary = {}

static func sight_blockers(engine: RefCounted, state: Dictionary) -> Dictionary:
	var ordinary: Dictionary = {}
	var through_stone: Dictionary = {}
	var stone: Array[Dictionary] = engine._dragon_spires(state)
	for terrain: Dictionary in state.get("terrain", []):
		if not Surfaces.terrain_is_live(terrain) or not bool(terrain.get("blocks_sight", str(terrain.get("kind", "")) in ["raised_cover", "crag_outcrop"])): continue
		var tile: Vector2i = terrain.get("pos", engine.INVALID_TILE)
		ordinary[tile] = true
		if not stone.has(terrain): through_stone[tile] = true
	return {"ordinary": ordinary, "through_stone": through_stone}

func _init(grid: Array, blockers: Dictionary) -> void:
	_grid = grid.duplicate(true)
	_blockers = blockers
	for y: int in range(grid.size()):
		for x: int in range(grid[y].size()):
			var tile := Vector2i(x, y)
			if Paths.is_passable(grid, tile): _floor[tile] = true

func matches(grid: Array, blockers: Dictionary) -> bool:
	return grid == _grid and blockers == _blockers

func footprint(origin: Vector2i, offsets: Array[Vector2i], size: Vector2i, transparent_stone: bool) -> Array[Vector2i]:
	# Offsets are ordered. The winner copies its borrowed area when publishing.
	var key: Array = [origin, offsets, size, transparent_stone]
	if _footprints.has(key): return _footprints[key]
	var result: Array[Vector2i]
	for offset: Vector2i in offsets:
		var tile: Vector2i = origin + offset
		if not _floor.has(tile) or result.has(tile): continue
		var nearest: Vector2i = Patterns.closest_footprint_tile(origin, size, tile)
		if _line_of_sight(nearest, tile, transparent_stone): result.append(tile)
	if _footprints.size() >= FOOTPRINT_CAPACITY: _footprints.clear()
	_footprints[key] = result
	return result

# Same supercover and endpoint rules as CombatEngine.combat_line_of_sight.
func _line_of_sight(start: Vector2i, target: Vector2i, transparent_stone: bool) -> bool:
	if maxi(absi(start.x - target.x), absi(start.y - target.y)) <= 1: return true
	var rays: Dictionary = _transparent_stone_rays if transparent_stone else _rays
	var key := Vector4i(start.x, start.y, target.x, target.y)
	if rays.has(key): return rays[key]
	var blockers: Dictionary = _blockers["through_stone" if transparent_stone else "ordinary"]
	var clear: bool = true
	for tile: Vector2i in Paths._supercover_line(start, target):
		if tile != start and tile != target and (not _floor.has(tile) or blockers.has(tile)):
			clear = false
			break
	if rays.size() >= RAY_CAPACITY: rays.clear()
	rays[key] = clear
	return clear
