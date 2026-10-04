extends RefCounted

const Typography = preload("res://scripts/ui_typography.gd")
const Card = preload("res://scripts/card_widget.gd")
const INK := Color("3a2616")
const BANNER_PATH := "res://assets/art/ui/visual_pass_4/shop_banner.png"
const SHELF_LABEL_PATH := "res://assets/art/ui/visual_pass_4/shelf_label.png"
# Keep the rings visible while clearing the existing 1.045x raised wares.
const BANNER_SIZE := Vector2(600.0, 122.0)
# The approved raster's parchment body starts below its dowel at 49% height.
const PARCHMENT_UV_RECT := Rect2(0.03, 0.49, 0.94, 0.51)
const INNER_INK_SHADER := """
shader_type canvas_item;
uniform float highlight_width = 1.0;
uniform float highlight_strength = 0.24;
uniform vec4 highlight_color : source_color = vec4(0.96, 0.79, 0.50, 1.0);

void fragment() {
	vec4 ink = COLOR;
	float neighbor = texture(TEXTURE, UV + dFdy(UV) * highlight_width).a;
	float inner_edge = clamp(ink.a - neighbor, 0.0, 1.0);
	COLOR = vec4(mix(ink.rgb, highlight_color.rgb, inner_edge * highlight_strength), ink.a);
}
"""

static var _ink_shader: Shader

static func parchment_rect(banner_size: Vector2) -> Rect2:
	return Rect2(PARCHMENT_UV_RECT.position * banner_size, PARCHMENT_UV_RECT.size * banner_size)

static func ware_rect(ware: Control) -> Rect2:
	var bounds: Rect2 = ware.get_global_transform() * Rect2(Vector2.ZERO, ware.size)
	for node: Node in ware.find_children("TimeCostBadge", "", true, false):
		var badge: Control = node as Control
		if badge == null or not badge.is_visible_in_tree():
			continue
		# The watch's bow is painted above the badge control's own rectangle.
		var fit: float = minf(badge.size.x, badge.size.y) * 0.5 / Card.TimeCostBadge.WATCH_CASE_RADIUS
		var watch := Rect2(badge.size * 0.5 - Card.TimeCostBadge.WATCH_DIAL_CENTER * fit, Card.TimeCostBadge.WATCH_TEXTURE_SIZE * fit)
		bounds = bounds.merge(badge.get_global_transform() * watch)
	return bounds

static func apply_ink(label: Label, font_size: int, display: bool = false, tracking: float = 0.0) -> void:
	var font: Font = Typography.display_font() if display else Typography.ui_font()
	if tracking > 0.0:
		var spaced := FontVariation.new()
		spaced.base_font = font
		spaced.spacing_glyph = roundi(Typography.scaled_value(label, float(font_size) * tracking))
		font = spaced
	label.add_theme_font_override("font", font)
	Typography.set_label_size(label, font_size)
	label.add_theme_color_override("font_color", INK)
	label.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	label.add_theme_constant_override("shadow_outline_size", 0)
	label.material = null
	if display:
		if _ink_shader == null:
			_ink_shader = Shader.new()
			_ink_shader.code = INNER_INK_SHADER
		var ink_material := ShaderMaterial.new()
		ink_material.shader = _ink_shader
		ink_material.set_shader_parameter("highlight_width", Typography.scaled_value(label, 1.0))
		label.material = ink_material
	label.set_meta("scene_label", true)
