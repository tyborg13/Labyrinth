extends RefCounted

## Existing Capacitor links and reflected-projectile contact anchors.
const BEAM_SEGMENTS: int = 8
const LINK_WIDTH: float = 2.0
const LINK_ALPHA: float = 0.85
const LINK_STRIKE_SECONDS: float = 0.12
const LINK_JITTER: float = 4.0
const LINK_GLOW_WIDTH: float = 6.0
const LINK_GLOW_ALPHA: float = 0.22

static func chest(board: Control, tile: Vector2i, enemy_key: String = "") -> Vector2:
	for unit: Dictionary in board._visible_units():
		if (not enemy_key.is_empty() and str(unit.get("key", "")) != enemy_key) or (enemy_key.is_empty() and (unit.get("pos") != tile or str(unit.get("role", "")) != "enemy")): continue
		var rect: Rect2 = board._unit_draw_rect(unit)
		var center: Vector2 = Vector2(rect.get_center().x, lerpf(rect.position.y, rect.end.y, board.RANGED_PREVIEW_ACTOR_CONTACT_CENTER_Y_RATIO))
		return center + board._tile_center(tile) - board._tile_center(unit["pos"])
	return board._elemental_air_point(board._tile_center(tile), 0.58) # Existing lightning contact anchor.

static func draw_arc_link(board: Control, start: Vector2, end: Vector2, seconds: float, reduced_motion: bool, color: Color) -> void:
	var points: PackedVector2Array = arc_link_points(start, end, seconds, reduced_motion)
	board.draw_polyline(points, Color(color, LINK_GLOW_ALPHA), LINK_GLOW_WIDTH, true)
	board.draw_polyline(points, Color(color, LINK_ALPHA), LINK_WIDTH, true)

static func arc_link_points(start: Vector2, end: Vector2, seconds: float, reduced_motion: bool) -> PackedVector2Array:
	var strike: int = 0 if reduced_motion else int(floor(seconds / LINK_STRIKE_SECONDS))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([start.round(), end.round(), strike])
	var normal: Vector2 = start.direction_to(end).orthogonal()
	var points := PackedVector2Array([start])
	for index: int in range(1, BEAM_SEGMENTS):
		points.append(start.lerp(end, float(index) / float(BEAM_SEGMENTS)) + normal * rng.randf_range(-LINK_JITTER, LINK_JITTER))
	points.append(end)
	return points
