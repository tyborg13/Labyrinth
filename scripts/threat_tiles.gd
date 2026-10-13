extends RefCounted

const Palette = preload("res://scripts/ui_palette.gd")
const OUTLINE_WIDTH: float = 2.0
const OUTLINE_ALPHA: float = 0.75
const FILL_ALPHA: float = 0.12
const HERO_FILL_ALPHA: float = 0.24
const PULSE_MIN: float = 0.18
const PULSE_MAX: float = 0.30
const PULSE_SECONDS: float = 1.1

static func tile_alphas(threats: Array) -> Dictionary:
	var result: Dictionary = {}
	for threat: Dictionary in threats:
		for tile: Vector2i in threat.get("tiles", []):
			result[tile] = maxf(float(result.get(tile, 0.0)), float(threat.get("alpha", 1.0)))
	return result

static func hero_fill_alpha(seconds: float, reduced_motion: bool) -> float:
	if reduced_motion: return HERO_FILL_ALPHA
	return HERO_FILL_ALPHA + (PULSE_MAX - PULSE_MIN) * 0.5 * sin(TAU * seconds / PULSE_SECONDS)

static func needs_pulse(presentation: Dictionary, threats: Dictionary) -> bool:
	return not bool(presentation.get("reduced_motion", false)) and threats.has((presentation.get("threats_at_rest", {}) as Dictionary).get("hero_tile", Vector2i(-1, -1)))

static func draw_tile(board: Control, tile: Vector2i, polygon: PackedVector2Array, threats: Dictionary, hero_tile: Vector2i, reduced_motion: bool) -> void:
	if not threats.has(tile) or not bool(board.call("_board_tile_is_visible_to_player", tile)):
		return
	var alpha: float = float(threats[tile])
	var center: Vector2 = board.call("_tile_center", tile)
	# Offset each diamond edge by half the stroke so the outline stays inside.
	var inset: float = OUTLINE_WIDTH * 0.5
	var width: float = float(board.call("_tile_width"))
	var height: float = float(board.call("_tile_height"))
	var edge_distance: float = (width * height * 0.5) / sqrt(width * width + height * height)
	var inner := PackedVector2Array()
	for point: Vector2 in polygon:
		inner.append(center + (point - center) * maxf(0.0, 1.0 - inset / edge_distance))
	var fill: float = hero_fill_alpha(float(Time.get_ticks_msec()) / 1000.0, reduced_motion) if tile == hero_tile else FILL_ALPHA
	board.draw_colored_polygon(inner, Color(Palette.DANGER, fill * alpha))
	inner.append(inner[0])
	board.draw_polyline(inner, Color(Palette.DANGER, OUTLINE_ALPHA * alpha), OUTLINE_WIDTH, true)
