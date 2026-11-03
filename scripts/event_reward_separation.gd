extends RefCounted
## Event-only treatment, constructed once with each cached preview. Merchant stays native.
const Palette = preload("res://scripts/ui_palette.gd")
const PAINTING_BRIGHTNESS: float = 0.32
const PAINTING_SATURATION: float = 0.65
const POOL_MARGIN: float = 56.0
const POOL_COLOR: Color = Palette.INK_0
const POOL_ALPHA: float = 0.62
const OUTLINE_PIXELS: float = 2.0
const OUTLINE_COLOR: Color = Palette.INK_0
const SHADOW_OFFSET: Vector2 = Vector2(0, 6)
const SHADOW_SOFTNESS: float = 10.0
const SHADOW_COLOR: Color = Color(0, 0, 0, 0.72)
# Hover and pool fades retain their original timings.
const FADE_IN_SECONDS: float = 0.12
const FADE_OUT_SECONDS: float = 0.08
const PAINTING_RETURN_SECONDS: float = 0.25
const BANE_STAMP_SECONDS: float = 0.12 # Existing bane crush reaches its end scale.
const POOL_SHADER: String = """
shader_type canvas_item;
void fragment() {
 float radius = length(UV * 2.0 - 1.0);
 COLOR.a *= 1.0 - smoothstep(0.0, 1.0, radius);
}
"""
const SILHOUETTE_SHADER: String = """
shader_type canvas_item;
uniform sampler2D art : filter_linear, repeat_disable;
uniform vec4 art_rect;
uniform vec2 quad_size;
uniform float outline_pixels;
uniform vec4 outline_color : source_color;
uniform vec2 shadow_offset;
uniform float shadow_softness;
uniform vec4 shadow_color : source_color;
float alpha_at(vec2 point) {
 vec2 uv = (point - art_rect.xy) / art_rect.zw;
 if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return 0.0;
 return texture(art, uv).a;
}
void fragment() {
 vec2 point = UV * quad_size;
 float edge = alpha_at(point);
 for (int i = 0; i < 16; i++) {
  float angle = float(i) * 6.28318530718 / 16.0;
  edge = max(edge, alpha_at(point + vec2(cos(angle), sin(angle)) * outline_pixels));
 }
 // Separable binomial kernel, with support ten reference pixels from the silhouette.
 float weights[5] = float[5](1.0, 4.0, 6.0, 4.0, 1.0);
 float shadow = 0.0;
 for (int y = 0; y < 5; y++) {
  for (int x = 0; x < 5; x++) {
   vec2 offset = vec2(float(x - 2), float(y - 2)) * shadow_softness * 0.5;
   shadow += alpha_at(point - shadow_offset + offset) * weights[x] * weights[y] / 256.0;
  }
 }
 float ink = edge * outline_color.a;
 float shade = shadow * shadow_color.a * (1.0 - ink);
 float alpha = ink + shade;
 vec3 rgb = (outline_color.rgb * ink + shadow_color.rgb * shade) / max(alpha, 0.00001);
 COLOR *= vec4(rgb, alpha);
}
"""
static var _pool_shader: Shader
static var _silhouette_shader: Shader

static func pool(parent: Control, bounds: Rect2) -> ColorRect:
	if _pool_shader == null:
		_pool_shader = Shader.new()
		_pool_shader.code = POOL_SHADER
	var result := ColorRect.new()
	result.name = "EventRewardPool"
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.position = bounds.position - Vector2.ONE * POOL_MARGIN
	result.size = bounds.size + Vector2.ONE * POOL_MARGIN * 2.0
	result.color = Color(POOL_COLOR, POOL_ALPHA)
	var ink := ShaderMaterial.new()
	ink.shader = _pool_shader
	result.material = ink
	parent.add_child(result)
	parent.move_child(result, 0)
	return result

static func decorate(node: Node, display_scale: float = 1.0) -> void:
	if node is Control: display_scale *= node.scale.x
	# Traverse before adding decoration; do not visit our own underlays.
	for child: Node in node.get_children(): decorate(child, display_scale)
	if node is TextureRect and node.has_meta("event_reward_icon"):
		_icon_shadow(node, display_scale)
	elif node.has_method("set_card_definition"):
		if node.is_node_ready(): _card_shadow(node, display_scale)
		else: node.ready.connect(_card_shadow.bind(node, display_scale), CONNECT_ONE_SHOT)

static func _card_shadow(card: Control, display_scale: float) -> void:
	# Cache an event variant of the native shadow. CardWidget refreshes its own
	# material on visibility/resize, so leave its style private and hide that layer.
	var native_shadow: Panel = card.get_node("CardElevationShadow")
	var style: StyleBoxFlat = native_shadow.get_theme_stylebox("panel").duplicate()
	native_shadow.hide()
	style.shadow_color = SHADOW_COLOR
	style.shadow_size = roundi(SHADOW_SOFTNESS / display_scale)
	style.shadow_offset = SHADOW_OFFSET / display_scale
	var shadow := Panel.new()
	shadow.name = "EventRewardCardShadow"
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.show_behind_parent = true
	shadow.add_theme_stylebox_override("panel", style)
	card.add_child(shadow)
	shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

static func _icon_shadow(icon: TextureRect, display_scale: float) -> void:
	if icon.texture == null: return
	if _silhouette_shader == null:
		_silhouette_shader = Shader.new()
		_silhouette_shader.code = SILHOUETTE_SHADER
	var padding: float = (SHADOW_SOFTNESS + SHADOW_OFFSET.length()) / display_scale
	var art_size: Vector2 = icon.texture.get_size()
	art_size *= minf(icon.size.x / art_size.x, icon.size.y / art_size.y)
	var underlay := ColorRect.new()
	underlay.name = "EventRewardSilhouette"
	underlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	underlay.show_behind_parent = true
	underlay.position = -Vector2.ONE * padding
	underlay.size = icon.size + Vector2.ONE * padding * 2.0
	var ink := ShaderMaterial.new()
	ink.shader = _silhouette_shader
	ink.set_shader_parameter("art", icon.texture)
	ink.set_shader_parameter("art_rect", Vector4((underlay.size.x - art_size.x) * 0.5, (underlay.size.y - art_size.y) * 0.5, art_size.x, art_size.y))
	ink.set_shader_parameter("quad_size", underlay.size)
	ink.set_shader_parameter("outline_pixels", OUTLINE_PIXELS / display_scale)
	ink.set_shader_parameter("outline_color", OUTLINE_COLOR)
	ink.set_shader_parameter("shadow_offset", SHADOW_OFFSET / display_scale)
	ink.set_shader_parameter("shadow_softness", SHADOW_SOFTNESS / display_scale)
	ink.set_shader_parameter("shadow_color", SHADOW_COLOR)
	underlay.material = ink
	icon.add_child(underlay)

static func recession(age: float, centre_seconds: float, reduced: bool) -> float:
	if age < 0: return 0.0
	if reduced: return 1.0 if age < centre_seconds else 0.0
	return minf(clampf(age / FADE_IN_SECONDS, 0, 1), 1.0 - clampf((age - centre_seconds) / FADE_OUT_SECONDS, 0, 1))
