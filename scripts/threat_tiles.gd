extends RefCounted

const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const OUTLINE_WIDTH: float = 2.0
const OUTLINE_ALPHA: float = 0.75
# pol-54: the outline uses the lighter danger red so protan and deutan eyes still
# see it on mid-tone earth floors, where DANGER turned the floor's olive-brown
# (pol-53 audit). The fill stays DANGER.
const OUTLINE_COLOR: Color = Palette.DANGER_BRIGHT
const OUTLINE_BAND_WIDTH: float = 5.0
const OUTLINE_BAND_ALPHA: float = 0.8
const OUTLINE_BAND_COLOR: Color = Palette.PREVIEW_INK
const FILL_ALPHA: float = 0.12
const HERO_FILL_ALPHA: float = 0.24
const PULSE_MIN: float = 0.18
const PULSE_MAX: float = 0.30
const PULSE_SECONDS: float = 1.1
const REST_KEY: String = "threats_at_rest"
const MARKER_KEY: String = "marker_threats"
const FLOOR_HERO_KEY: String = "floor_threat_hero_tile"
const LOB_AIM_KEY: String = "floor_lob_aim"

# Keep the previous paint payload independent of mutable direct submissions.
# The decorated outer dictionary already belongs to the board.
static func own_paint_inputs(shown: Dictionary, previous: Dictionary, previous_owned: bool, floor_key: String) -> void:
	for key: String in [REST_KEY, floor_key, MARKER_KEY, LOB_AIM_KEY]:
		if not shown.has(key): continue
		var value: Variant = shown[key]
		shown[key] = previous[key] if previous_owned and previous.get(key) == value else value.duplicate(true)

static func marker_rows(shown: Dictionary) -> Array:
	return shown.get(MARKER_KEY, shown.get(REST_KEY, {}).get("threats", []))

static func include_decorations(shown: Dictionary, floor_key: String, decoration_keys: Array) -> void:
	for key: String in [floor_key, MARKER_KEY]:
		if not shown.has(key): continue
		var rows: Array = shown[key]
		for decoration: Dictionary in shown.get(REST_KEY, {}).get("threats", []):
			if not decoration_keys.has(decoration["key"]) or rows.has(decoration): continue
			if is_same(rows, shown[key]): rows = rows.duplicate()
			rows.append(decoration)
		shown[key] = rows

# Announced areas are public warnings. Moving sight or hover must not hide a
# held mark; this paints only the existing danger diamond, never unseen units.
static func announced_at(presentation: Dictionary, tile: Vector2i) -> bool:
	for threat: Dictionary in presentation.get("threats_at_rest", {}).get("threats", []):
		if bool(threat.get("area_announced", threat.get("area_fixed", false))) and (threat.get("tiles", []) as Array).has(tile): return true
	return false

static func visible_at(board: Control, tile: Vector2i) -> bool:
	return bool(board.call("_board_tile_is_visible_to_player", tile)) or announced_at(board.get("presentation"), tile)

# area-01 feedback 2: kept as a compatibility boundary for retained layers.
# Order belongs to health-frame discs and the rail, never the red floor.
static func zone_tags(_threats: Array) -> Array[Dictionary]:
	var none: Array[Dictionary]
	return none

static func tile_alphas(threats: Array) -> Dictionary:
	var result: Dictionary = {}
	for threat: Dictionary in threats:
		for tile: Vector2i in threat.get("tiles", []):
			result[tile] = maxf(float(result.get(tile, 0.0)), float(threat.get("alpha", 1.0)))
	return result

static func rule_tiles(threats: Array) -> Dictionary:
	var result: Dictionary = {}
	for threat: Dictionary in threats:
		if not bool(threat.get("rule_outline", false)): continue
		for tile: Vector2i in threat["tiles"]: result[tile] = true
	return result

# Floor and target marker each compile their own coverage. Rows retain their
# stamp identities, while the renderer gets one key per owner on each tile.
static func coverage(threats: Array, targeting: bool = false) -> Dictionary:
	var alphas: Dictionary = {}
	var rules: Dictionary = {}
	var announced: Dictionary = {}
	var owners: Dictionary = {}
	for threat: Dictionary in threats:
		var key: String = str(threat.get("key", ""))
		var alpha: float = float(threat.get("alpha", 1.0))
		var rule: bool = bool(threat.get("rule_outline", false))
		var public: bool = bool(threat.get("area_announced", threat.get("area_fixed", false)))
		var tiles: Array = threat.get("tiles", [])
		if targeting: tiles = threat.get("marker_tiles", tiles)
		for tile: Vector2i in tiles:
			alphas[tile] = maxf(float(alphas.get(tile, 0.0)), alpha)
			if rule: rules[tile] = true
			if public: announced[tile] = true
			if not key.is_empty():
				var keys: Array = owners.get_or_add(tile, [])
				if not keys.has(key): keys.append(key)
	return {"alphas": alphas, "rules": rules, "announced": announced, "owners": owners}

static func hero_fill_alpha(seconds: float, reduced_motion: bool) -> float:
	if reduced_motion: return HERO_FILL_ALPHA
	return HERO_FILL_ALPHA + (PULSE_MAX - PULSE_MIN) * 0.5 * sin(TAU * seconds / PULSE_SECONDS)

static func needs_pulse(presentation: Dictionary, threats: Dictionary) -> bool:
	return not bool(presentation.get("reduced_motion", false)) and threats.has(hero_tile(presentation))

static func hero_tile(presentation: Dictionary, targeting: bool = false) -> Vector2i:
	var release: Vector2i = presentation.get(REST_KEY, {}).get("hero_tile", Vector2i(-1, -1))
	return release if targeting else presentation.get(FLOOR_HERO_KEY, release)

static func tile_geometry(board: Control, tile: Vector2i, polygon: PackedVector2Array) -> Dictionary:
	var center: Vector2 = board.call("_tile_center", tile)
	var width: float = float(board.call("_tile_width"))
	var height: float = float(board.call("_tile_height"))
	var edge_distance: float = (width * height * 0.5) / sqrt(width * width + height * height)
	return {
		"center": center,
		"inner": _inset_diamond(polygon, center, edge_distance, OUTLINE_WIDTH),
		"band": _inset_diamond(polygon, center, edge_distance, OUTLINE_BAND_WIDTH),
	}

static func _inset_diamond(polygon: PackedVector2Array, center: Vector2, edge_distance: float, stroke_width: float) -> PackedVector2Array:
	# Offset each edge by half the stroke so the paint stays inside the tile.
	var scale: float = maxf(0.0, 1.0 - stroke_width * 0.5 / edge_distance)
	var inset := PackedVector2Array()
	for point: Vector2 in polygon:
		inset.append(center + (point - center) * scale)
	return inset

static func outline_operations(paint: Dictionary) -> Array[Array]:
	var alpha: float = float(paint["alpha"])
	var outline: PackedVector2Array = (paint["inner"] as PackedVector2Array).duplicate()
	outline.append(outline[0])
	var band: PackedVector2Array = (paint["band"] as PackedVector2Array).duplicate()
	if band[0] != band[-1]: band.append(band[0])
	# A fringe on the outside of the band would cross into adjacent tiles.
	var operations: Array[Array]
	operations.append([band, Color(OUTLINE_BAND_COLOR, OUTLINE_BAND_ALPHA * alpha), OUTLINE_BAND_WIDTH, false])
	operations.append([outline, Color(OUTLINE_COLOR, OUTLINE_ALPHA * alpha), OUTLINE_WIDTH, true])
	return operations

static func draw_tile_outline(canvas: CanvasItem, paint: Dictionary) -> void:
	for arguments: Array in outline_operations(paint):
		canvas.callv("draw_polyline", arguments)

static func draw_tile(board: Control, tile: Vector2i, polygon: PackedVector2Array, threats: Dictionary, hero_tile: Vector2i, reduced_motion: bool, draw_tags: Variant = null) -> void:
	if not threats.has(tile) or not visible_at(board, tile):
		return
	var alpha: float = float(threats[tile])
	var paint: Dictionary = tile_geometry(board, tile, polygon)
	paint["alpha"] = alpha
	var fill: float = hero_fill_alpha(float(preload("res://scripts/presentation_clock.gd").ticks_msec()) / 1000.0, reduced_motion) if tile == hero_tile else FILL_ALPHA
	board.draw_colored_polygon(paint["inner"], Color(Palette.DANGER, fill * alpha))
	draw_tile_outline(board, paint)

static func draw_zone_tag(_board: Control, _tag: Dictionary, _center: Vector2) -> void:
	pass
