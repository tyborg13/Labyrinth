extends RefCounted

const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const OUTLINE_WIDTH: float = 2.0
const OUTLINE_ALPHA: float = 0.75
const FILL_ALPHA: float = 0.12
const HERO_FILL_ALPHA: float = 0.24
const PULSE_MIN: float = 0.18
const PULSE_MAX: float = 0.30
const PULSE_SECONDS: float = 1.1
const TAG_DIAMETER: float = 20.0
const TAG_FONT_SIZE: int = 13
const TAG_FILL := Color("46140f")
const CIRCLE_SEGMENTS: int = 64

static func zone_tags(threats: Array) -> Array[Dictionary]:
	var tags: Array[Dictionary]
	for threat: Dictionary in threats:
		if not bool(threat.get("area", false)) or str(threat.get("order", "")).is_empty(): continue
		var source: Vector2i = threat.get("attacker_tile", Vector2i(-1, -1))
		var nearest := Vector2i(-1, -1)
		var distance: int = 2147483647
		for tile: Vector2i in threat.get("tiles", []):
			var candidate: int = absi(tile.x - source.x) + absi(tile.y - source.y)
			if candidate < distance:
				nearest = tile
				distance = candidate
		if nearest.x >= 0:
			tags.append({"key": threat["key"], "tile": nearest, "order": threat["order"], "alpha": threat.get("alpha", 1.0)})
	return tags

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
	for tag: Dictionary in zone_tags((board.get("presentation") as Dictionary).get("threats_at_rest", {}).get("threats", [])):
		if tag["tile"] == tile: draw_zone_tag(board, tag, center)

static func draw_zone_tag(board: Control, tag: Dictionary, center: Vector2) -> void:
	var alpha: float = float(tag["alpha"])
	board.draw_circle(center, TAG_DIAMETER * 0.5, Color(TAG_FILL, 0.94 * alpha), true, -1.0, true)
	board.draw_arc(center, TAG_DIAMETER * 0.5 - 1.0, 0.0, TAU, CIRCLE_SEGMENTS, Color(Palette.DANGER, alpha), 2.0, true)
	var font: Font = Typography.ui_font()
	var baseline: float = center.y + (font.get_ascent(TAG_FONT_SIZE) - font.get_descent(TAG_FONT_SIZE)) * 0.5
	board.draw_string(font, Vector2(center.x - TAG_DIAMETER * 0.5, baseline), str(tag["order"]), HORIZONTAL_ALIGNMENT_CENTER, TAG_DIAMETER, TAG_FONT_SIZE, Color(Palette.GOLD_BRIGHT, alpha))
