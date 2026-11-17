extends "res://scripts/combat_board_view.gd"
## Capture-only archived painter from d87a00af4. Never loaded by production.

func _draw_lightning_strikes_effect(effect: Dictionary, progress: float) -> void:
	var strike_tiles: Array[Vector2i] = _vector2i_array(effect.get("tiles", []))
	var bolt_alpha: float = 0.24 + progress * 0.34
	for tile: Vector2i in strike_tiles:
		var tile_point: Vector2 = _tile_center(tile)
		var top_point: Vector2 = tile_point + Vector2(-10.0 + sin(float(tile.x + tile.y)) * 8.0, -_tile_height() * 1.45)
		if not bool(effect.get("zekarion_cutout", false)) or progress >= 0.38 or bool(presentation.get("reduced_motion",false)):
			draw_line(top_point, tile_point, Color(1.0, 0.94, 0.42, bolt_alpha), 3.0, true)
			draw_line(top_point + Vector2(7.0, 22.0), tile_point + Vector2(-5.0, -6.0), Color(0.58, 0.78, 1.0, bolt_alpha * 0.76), 2.0, true)
		draw_arc(tile_point, _tile_width() * (0.18 + progress * 0.08), 0.0, TAU, 18, Color(1.0, 0.86, 0.28, 0.48 + progress * 0.24), 3.0)
		draw_circle(tile_point, _tile_width() * 0.10, Color(1.0, 0.95, 0.50, 0.16 + progress * 0.18))

func _draw_fire_impact_decal(center: Vector2, seed: int, scale: float, alpha: float, _phase: float = 0.0) -> void:
	var tile_width: float = _tile_width()
	var tile_height: float = _tile_height()
	_draw_impact_ellipse(center, tile_width * 0.46 * scale, tile_height * 0.56 * scale, tile_width * 0.08, Color(0.07, 0.035, 0.020, 0.46 * alpha))
	_draw_impact_ellipse_outline(center, tile_width * 0.54 * scale, tile_height * 0.64 * scale, tile_width * 0.10, Color(0.98, 0.34, 0.13, 0.30 * alpha), 1.8)
	_draw_impact_radial_marks(center, seed, 6, Color(1.0, 0.48, 0.18, 0.66 * alpha), tile_width * 0.08 * scale, tile_width * 0.25 * scale, 0.48, 2.0)
	for idx: int in range(3):
		var ember_point: Vector2 = center + _impact_offset(seed + idx * 17, tile_width * 0.18 * scale, tile_height * 0.22 * scale)
		draw_circle(ember_point, tile_width * (0.014 + 0.006 * _ambient_hash01(seed + idx + 40)), Color(1.0, 0.62, 0.22, 0.72 * alpha))


func _draw_ice_impact_decal(center: Vector2, seed: int, scale: float, alpha: float, _phase: float = 0.0) -> void:
	var tile_width: float = _tile_width()
	var tile_height: float = _tile_height()
	_draw_impact_ellipse(center, tile_width * 0.50 * scale, tile_height * 0.58 * scale, -tile_width * 0.04, Color(0.52, 0.86, 1.0, 0.18 * alpha))
	_draw_impact_ellipse_outline(center, tile_width * 0.56 * scale, tile_height * 0.64 * scale, -tile_width * 0.05, Color(0.78, 0.96, 1.0, 0.42 * alpha), 1.6)
	_draw_impact_crack_marks(center, seed, 7, Color(0.82, 0.98, 1.0, 0.72 * alpha), tile_width * 0.07 * scale, tile_width * 0.27 * scale, 0.42, 1.7)
	for idx: int in range(4):
		var shard_center: Vector2 = center + _impact_offset(seed + idx * 23, tile_width * 0.21 * scale, tile_height * 0.22 * scale)
		draw_line(shard_center + Vector2(-2.0, 1.0), shard_center + Vector2(3.0, -5.0), Color(0.92, 1.0, 1.0, 0.72 * alpha), 1.3, true)


func _draw_lightning_impact_decal(center: Vector2, seed: int, scale: float, alpha: float, _phase: float = 0.0) -> void:
	var tile_width: float = _tile_width()
	var tile_height: float = _tile_height()
	_draw_impact_ellipse(center, tile_width * 0.44 * scale, tile_height * 0.52 * scale, tile_width * 0.03, Color(0.08, 0.07, 0.16, 0.36 * alpha))
	_draw_impact_ellipse_outline(center, tile_width * 0.58 * scale, tile_height * 0.68 * scale, tile_width * 0.06, Color(0.96, 0.86, 0.26, 0.52 * alpha), 1.7)
	_draw_impact_crack_marks(center, seed, 5, Color(0.52, 0.82, 1.0, 0.66 * alpha), tile_width * 0.06 * scale, tile_width * 0.28 * scale, 0.44, 1.8)
	_draw_impact_radial_marks(center, seed + 53, 4, Color(1.0, 0.94, 0.42, 0.82 * alpha), tile_width * 0.05 * scale, tile_width * 0.22 * scale, 0.40, 2.1)


func _draw_air_impact_decal(center: Vector2, seed: int, scale: float, alpha: float, _phase: float = 0.0) -> void:
	var tile_width: float = _tile_width()
	_draw_impact_ellipse(center, tile_width * 0.52 * scale, _tile_height() * 0.58 * scale, -tile_width * 0.05, Color(0.46, 0.88, 0.72, 0.12 * alpha))
	for idx: int in range(3):
		var radius: float = tile_width * (0.12 + float(idx) * 0.055) * scale
		var start_angle: float = _ambient_hash01(seed + idx * 31) * TAU
		draw_arc(center, radius, start_angle, start_angle + PI * 0.86, 18, Color(0.72, 1.0, 0.86, (0.48 - float(idx) * 0.09) * alpha), 1.6, true)
	_draw_impact_radial_marks(center, seed + 71, 5, Color(0.82, 0.70, 0.48, 0.32 * alpha), tile_width * 0.12 * scale, tile_width * 0.30 * scale, 0.40, 1.5)


func _draw_earth_impact_decal(center: Vector2, seed: int, scale: float, alpha: float, _phase: float = 0.0) -> void:
	var tile_width: float = _tile_width()
	_draw_impact_ellipse(center, tile_width * 0.46 * scale, _tile_height() * 0.54 * scale, tile_width * 0.05, Color(0.10, 0.07, 0.035, 0.38 * alpha))
	_draw_impact_crack_marks(center, seed, 8, Color(0.74, 0.62, 0.36, 0.66 * alpha), tile_width * 0.05 * scale, tile_width * 0.30 * scale, 0.46, 2.0)
	for idx: int in range(5):
		var chip_point: Vector2 = center + _impact_offset(seed + idx * 19, tile_width * 0.24 * scale, _tile_height() * 0.26 * scale)
		draw_circle(chip_point, tile_width * 0.013, Color(0.58, 0.44, 0.24, 0.54 * alpha))


func _dragon_full_area_fx(effect: Dictionary) -> bool:
	var profile: Dictionary = preload("res://scripts/dragon_presentation.gd").profile(effect)
	return preload("res://scripts/dragon_presentation.gd").area_fx(effect) or (str(profile.get("geometry", "")) == "physical" and str(effect.get("kind", "")) == "aoe")

func _draw_effect_overlay() -> void:
	super._draw_effect_overlay()
	var effect: Dictionary = presentation.get("effect", {})
	if str(effect.get("kind", "")) == "lightning_strikes" and not _dragon_full_area_fx(effect):
		_draw_lightning_strikes_effect(effect, float(presentation.get("effect_progress", 0.0)))
