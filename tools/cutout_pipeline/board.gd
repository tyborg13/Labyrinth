extends "res://scripts/combat_board_view.gd"

## The board still draws one 2D texture. Only this experiment supplies that texture
## from a transparent live puppet viewport; production assets and rules are intact.
const SOURCE_SIZE := Vector2(255.0, 255.0)
const SOURCE_OFFSET := Vector2(128.0, 128.0)
const PUPPET_CANVAS_SIZE := Vector2(512.0, 512.0)
var _drawing_reference_shadow: bool = false

func _uses_protagonist_cutout() -> bool:
	return false

func _is_player(unit: Dictionary) -> bool:
	return str(unit.get("type", "")) == "player"

func _live_puppet(unit: Dictionary) -> bool:
	return _is_player(unit) and not _drawing_reference_shadow and bool(presentation.get("puppet_live", false)) and presentation.get("puppet_texture") is Texture2D

func _reference_texture() -> Texture2D:
	return presentation.get("puppet_reference", _unit_textures.get("player", null)) as Texture2D

func _unit_center(unit: Dictionary) -> Vector2:
	var center: Vector2 = super._unit_center(unit)
	if not _is_player(unit):
		return center
	var source_rect: Rect2 = super._unit_draw_rect_for_texture(unit, center, _reference_texture())
	var travel: Vector2 = presentation.get("puppet_travel_source_px", Vector2.ZERO)
	# Travel uses the very same scale as the feet inside the puppet texture.
	# Moving the center also carries the existing shadow and health anchor.
	return center + travel * source_rect.size / SOURCE_SIZE

func _hud_layout_source(hud_units: Array[Dictionary]) -> Dictionary:
	var source: Dictionary = super._hud_layout_source(hud_units)
	# The experiment's source-pixel travel is an extra layout input beside the
	# production board's world-position override. Keep the retained HUD honest.
	source["puppet_travel_source_px"] = presentation.get("puppet_travel_source_px", Vector2.ZERO)
	return source

func _texture_for_unit(unit: Dictionary) -> Texture2D:
	if _live_puppet(unit):
		return presentation.get("puppet_texture") as Texture2D
	if _is_player(unit) and _reference_texture() != null:
		return _reference_texture()
	return super._texture_for_unit(unit)

func _unit_hud_anchor_texture(unit: Dictionary) -> Texture2D:
	if _is_player(unit) and _reference_texture() != null:
		return _reference_texture()
	return super._unit_hud_anchor_texture(unit)

func _unit_draw_rect_for_texture(unit: Dictionary, center: Vector2, texture: Texture2D) -> Rect2:
	if not _is_player(unit):
		return super._unit_draw_rect_for_texture(unit, center, texture)
	var source_rect: Rect2 = super._unit_draw_rect_for_texture(unit, center, _reference_texture())
	if not _live_puppet(unit):
		return source_rect
	# Preserve the exact original 255px registration, including its native foot
	# placement. The extra 128px margin is motion room, never a reason to shrink,
	# crop, or recenter the character. Every source pixel maps to the same point.
	return Rect2(source_rect.position - source_rect.size * SOURCE_OFFSET / SOURCE_SIZE, source_rect.size * PUPPET_CANVAS_SIZE / SOURCE_SIZE)

func _unit_art_top_y(unit: Dictionary, center: Vector2) -> float:
	if _is_player(unit):
		return super._unit_draw_rect_for_texture(unit, center, _reference_texture()).position.y
	return super._unit_art_top_y(unit, center)

func _draw_unit_shadow(unit: Dictionary) -> void:
	if not _is_player(unit):
		super._draw_unit_shadow(unit)
		return
	# Reuse the production reference silhouette and shadow placement for both
	# comparison modes. This avoids reading back the live GPU viewport per pose.
	_drawing_reference_shadow = true
	super._draw_unit_shadow(unit)
	_drawing_reference_shadow = false
