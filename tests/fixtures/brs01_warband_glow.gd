extends RefCounted
# Frozen pre-brs-01 geometry oracle: proves the extraction preserves pixels.
const Paths = preload("res://scripts/path_utils.gd")
const COMMAND_BASE_ALPHA: float = 0.12
const COMMAND_GLOW_ALPHA: float = 0.24
const COMMAND_EDGE_FRACTION: float = 0.6
# A feathered rim just inside the zone's edge gives it shape without a line.
const COMMAND_RIM_ALPHA: float = 0.34
const COMMAND_RIM_DEPTH: float = 0.26
# Each tile corner as a doubled grid offset, in `_tile_polygon` vertex order.
const TILE_CORNERS: Array = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]

# Four [points, colours] triangles fanning one zone tile from its centre, plus
# rim strips on edges that face out of the zone; empty off the zone.
static func glow_fan(state: Dictionary, leader: Dictionary, tile: Vector2i, polygon: PackedVector2Array, gold: Color) -> Array:
	var triangles: Array = []
	if not _in_command(state, leader, tile): return triangles
	var radius: float = float(state["objective"]["command"]["radius"]) + 0.5
	var captain := Vector2(leader["pos"])
	var corner_colours := PackedColorArray()
	for corner: Vector2i in TILE_CORNERS:
		var inside: bool = true
		for neighbor: Vector2i in [tile + Vector2i(corner.x, 0), tile + Vector2i(0, corner.y), tile + corner]:
			if not _in_command(state, leader, neighbor): inside = false
		var alpha: float = _glow_alpha(Vector2(tile) + Vector2(corner) * 0.5, captain, radius)
		corner_colours.append(Color(gold, alpha if inside else alpha * COMMAND_EDGE_FRACTION))
	var centre: Vector2 = (polygon[0] + polygon[2]) * 0.5
	var centre_colour := Color(gold, _glow_alpha(Vector2(tile), captain, radius))
	for edge: int in range(4):
		var next: int = (edge + 1) % 4
		triangles.append([PackedVector2Array([centre, polygon[edge], polygon[next]]), PackedColorArray([centre_colour, corner_colours[edge], corner_colours[next]])])
	for edge: int in range(4):
		if _in_command(state, leader, tile + Paths.DIRS_4[edge]): continue
		var next: int = (edge + 1) % 4
		var rim := Color(gold, COMMAND_RIM_ALPHA)
		var clear := Color(gold, 0.0)
		triangles.append([PackedVector2Array([polygon[edge], polygon[next], polygon[next].lerp(centre, COMMAND_RIM_DEPTH), polygon[edge].lerp(centre, COMMAND_RIM_DEPTH)]), PackedColorArray([rim, rim, clear, clear])])
	return triangles

static func _in_command(state: Dictionary, leader: Dictionary, tile: Vector2i) -> bool:
	return Paths.is_passable(state.get("grid", []), tile) and Paths.manhattan(tile, leader["pos"]) <= int(state["objective"]["command"]["radius"])

static func _glow_alpha(at: Vector2, captain: Vector2, radius: float) -> float:
	var falloff: float = clampf(1.0 - at.distance_to(captain) / radius, 0.0, 1.0)
	return COMMAND_BASE_ALPHA + COMMAND_GLOW_ALPHA * falloff * falloff

