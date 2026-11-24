extends RefCounted

const Burrow = preload("res://scripts/enemy_mechanics/burrow_view.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Cel = preload("res://scripts/cel_look.gd")
const Data = preload("res://scripts/game_data.gd")
const Treatment = preload("res://scripts/combat_art_treatment.gd")
const Fight = preload("fight.gd")
const SOURCE_CANVAS := Vector2(255.0, 255.0)
const SOURCE_CENTER := Vector2(128.0, 224.0)
const SOIL_CENTER_TOLERANCE_PX: float = 1.0
const TEST_MODULATE := Color(0.6, 0.7, 0.8, 0.8)
const TEST_DEATH_PROGRESS: float = 0.25
const ERUPT_MIDPOINT: float = 0.5

class DrawCapture:
	extends Control
	var board: Control
	var static_body: Texture2D
	var presentation: Dictionary = {}
	var calls: Array[Dictionary]

	func protagonist_source_pixel_scale() -> float:
		return board.protagonist_source_pixel_scale()

	func _unit_center(unit: Dictionary) -> Vector2:
		return board._unit_center(unit)

	func _tile_center(tile: Vector2i) -> Vector2:
		return board._tile_center(tile)

	func _texture_for_unit(_unit: Dictionary) -> Texture2D:
		return static_body

	func _unit_texture_draw_rect(unit: Dictionary, center: Vector2) -> Rect2:
		return board._unit_draw_rect_for_texture(unit, center, static_body)

	func _texture_used_draw_rect(texture: Texture2D, rect: Rect2) -> Rect2:
		return board._texture_used_draw_rect(texture, rect)

	func _draw_world_texture(texture: Texture2D, rect: Rect2, tint: Color, profile: int = Treatment.PROP, source: Rect2 = Rect2()) -> void:
		calls.append({"texture": texture, "rect": rect, "tint": tint, "profile": profile, "source": source})

static func run(fight: RefCounted, check: Callable) -> void:
	var unit: Dictionary = fight.grub_unit()
	check.call(bool(unit.get("burrowed", false)), "resolved board unit is burrowed")
	var texture: CanvasTexture = Burrow.mound_texture()
	if not check.call(texture != null, "mound texture loads"): return
	check.call(texture.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and texture.get_size() == SOURCE_CANVAS, "nearest filtering on the 255 px source canvas")
	var variant: String = Cel.variant_path(Burrow.MOUND_PATH)
	var paint: Image = texture.diffuse_texture.get_image()
	var filtered := Image.new()
	check.call(not variant.is_empty() and filtered.load_png_from_buffer(FileAccess.get_file_as_bytes(variant)) == OK
		and paint.get_data() == filtered.get_data(), "production texture resolves through the cel manifest")
	var used: Rect2i = paint.get_used_rect()
	check.call(used == Rect2i(50, 203, 156, 43), "production and review sheet have the same opaque bounds")
	var center: Vector2 = fight.board._unit_center(unit)
	_check_geometry(fight.board, unit, texture, used, check)
	var proxy := DrawCapture.new()
	proxy.board = fight.board
	# Exercise the static fallback with real paint. The dummy renderer cannot
	# read back the live cutout's ViewportTexture to measure its opaque pixels.
	proxy.static_body = Assets.load_texture_source_first(Data.enemy_def(Fight.TYPE)["art_path"])
	proxy.presentation["reduced_motion"] = true
	# grub_unit() returns live retained state. Keep the test tint out of later
	# native stills, which continue rendering that same buried snapshot.
	var tinted: Dictionary = unit.duplicate()
	tinted["modulate"] = TEST_MODULATE
	tinted["death_progress"] = TEST_DEATH_PROGRESS
	check.call(Burrow.draw_body(proxy, tinted), "draw_body handles resolved burrow")
	if check.call(proxy.calls.size() == 1, "burrow issues one textured draw"):
		var call: Dictionary = proxy.calls[0]
		var live_body: Texture2D = fight.board._texture_for_unit(unit)
		check.call(call["texture"] == texture and call["profile"] == Treatment.actor_profile(unit, live_body)
			and call["source"] == Rect2(), "burrow uses the live body lighting profile")
		var expected: Color = TEST_MODULATE
		expected.a *= 1.0 - TEST_DEATH_PROGRESS
		check.call(call["tint"].is_equal_approx(expected), "sprite multiplies unit modulate by death fade")
	proxy.calls.clear()
	proxy.presentation["en01_erupt"] = {"actor_key": Fight.ACTOR_KEY, "progress": ERUPT_MIDPOINT}
	check.call(Burrow.draw_body(proxy, unit), "erupt branch takes precedence over burrowed")
	if check.call(proxy.calls.size() == 1, "erupt issues one textured draw"):
		var call: Dictionary = proxy.calls[0]
		var standing: Texture2D = proxy._texture_for_unit(unit)
		var standing_rect: Rect2 = proxy._unit_texture_draw_rect(unit, center)
		var floor_y: float = proxy._texture_used_draw_rect(standing, standing_rect).end.y
		check.call(call["texture"] == standing and call["source"].has_area() and is_equal_approx(call["rect"].end.y, floor_y), "legacy erupt still crops the static texture at its floor")
	proxy.free()
	var source: String = FileAccess.get_file_as_string("res://scripts/enemy_mechanics/burrow_view.gd")
	var draw_path: String = source.get_slice("static func draw_body", 1).get_slice("static func draw_mark", 0)
	for forbidden: String in ["draw_circle", "draw_polyline", "_draw_impact_ellipse", "draw_dust"]:
		check.call(not draw_path.contains(forbidden), "body draw path omits " + forbidden)
	print("ART-08 DRAW: mound and erupt each submit one texture. No circle, polyline, ellipse or dust calls in the body draw path.")

static func _check_geometry(board: Control, unit: Dictionary, texture: CanvasTexture, used: Rect2i, check: Callable) -> void:
	var tile: Vector2i = unit["pos"]
	var tile_center: Vector2 = board._tile_center(tile)
	var density: float = board.protagonist_source_pixel_scale()
	var neutral: Rect2 = Burrow.mound_draw_rect(board, tile, texture, 1.0)
	var base_y: float = neutral.position.y + used.end.y * density
	check.call((neutral.position + SOURCE_CENTER * density).is_equal_approx(tile_center), "neutral soil uses the approved center anchor")
	for sample: Array in [[Fight.BREATH_PEAK_MSEC, false, 1.03], [Fight.BREATH_TROUGH_MSEC, false, 0.97], [Fight.BREATH_PEAK_MSEC, true, 1.0]]:
		var scale: float = Burrow.breath_scale(sample[0], sample[1])
		var draw_rect: Rect2 = Burrow.mound_draw_rect(board, tile, texture, scale)
		var density_xy := draw_rect.size / SOURCE_CANVAS
		var soil: Rect2 = board._texture_used_draw_rect(texture.diffuse_texture, draw_rect)
		var soil_middle: float = soil.get_center().y
		check.call(is_equal_approx(scale, sample[2]) and is_equal_approx(density_xy.x, density), "vertical-only breath scale")
		check.call(is_equal_approx(soil.end.y, base_y), "opaque base line stays fixed")
		check.call(absf(soil_middle - tile_center.y) <= SOIL_CENTER_TOLERANCE_PX, "opaque soil middle stays within one pixel of the tile center")
		print("ART-08 MOUND t=%dms reduced=%s rect=%s tile_center=%s soil_middle_y=%.4f base_y=%.4f scale=%.4f" % [sample[0], sample[1], draw_rect, tile_center, soil_middle, soil.end.y, scale])
		if sample[0] == Fight.BREATH_PEAK_MSEC and not sample[1]:
			var anchor: Rect2 = board._unit_health_bar_rect(unit, board._unit_center(unit))
			var bar: Rect2 = board._hud_health_rects_cache.get(Fight.ACTOR_KEY, Rect2())
			var clearance: float = board.UNIT_ART_HUD_CLEARANCE
			var gap: float = soil.position.y - bar.end.y
			check.call(is_equal_approx(soil.position.y - anchor.end.y, clearance), "peak soil uses the standing health bar clearance")
			check.call(bar.has_area() and (gap >= clearance or is_equal_approx(gap, clearance)), "placed health bar clears the soil at peak")
			print("ART-08 MOUND HUD peak_soil_top=%.4f bar_bottom=%.4f gap=%.4f standing_clearance=%.4f" % [soil.position.y, bar.end.y, gap, clearance])

static func mound_submission(board: Control, unit: Dictionary) -> Dictionary:
	var proxy := DrawCapture.new()
	proxy.board = board
	proxy.presentation = board.presentation
	Burrow.draw_body(proxy, unit)
	var result: Dictionary = proxy.calls[0] if proxy.calls.size() == 1 else {}
	proxy.free()
	return result
