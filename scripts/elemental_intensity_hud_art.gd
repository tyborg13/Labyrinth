extends RefCounted
class_name ElementalIntensityHudArt

const ElementData = preload("res://scripts/element_data.gd")

const CLUSTER_SIZE: Vector2 = Vector2(260.0, 204.0)
const ITEM_SIZE: Vector2 = Vector2(74.0, 108.0)
const RIG_RECT: Rect2 = Rect2(0.0, 0.0, 260.0, 108.0)
const CHARM_RECT: Rect2 = Rect2(0.0, 0.0, 74.0, 86.0)
const PLACARD_RECT: Rect2 = Rect2(22.0, 74.0, 30.0, 32.0)
const NUMBER_LABEL_RECT: Rect2 = Rect2(23.0, 76.0, 28.0, 28.0)
const POINTER_HIT_CENTER: Vector2 = Vector2(37.0, 42.0)
const POINTER_HIT_RADIUS: float = 27.0
const POINTER_PLACARD_HIT_RECT: Rect2 = Rect2(20.0, 73.0, 34.0, 34.0)
const RIG_TEXTURE_PATH: String = "res://assets/art/ui/elemental_intensity/hanging_rig.png"
const PLACARD_TEXTURE_PATH: String = "res://assets/art/ui/elemental_intensity/number_placard_v2.png"

const _ITEM_POSITIONS := {
	ElementData.FIRE: Vector2(4.0, 55.0),
	ElementData.ICE: Vector2(92.0, 55.0),
	ElementData.LIGHTNING: Vector2(182.0, 55.0),
	ElementData.AIR: Vector2(48.0, 96.0),
	ElementData.EARTH: Vector2(138.0, 96.0),
}

# Authored-pixel measurements after the rig crop is mapped into RIG_RECT.
# The charm art's top rings all center at x=37 inside CHARM_RECT.
const _CHAIN_ENDPOINT_X := {
	ElementData.FIRE: 41.0,
	ElementData.ICE: 129.0,
	ElementData.LIGHTNING: 219.0,
	ElementData.AIR: 85.0,
	ElementData.EARTH: 175.0,
}

const _GLOW_SHADER_SOURCE: String = """
shader_type canvas_item;
render_mode blend_add;

uniform vec4 glow_color : source_color = vec4(1.0);
uniform float glow_strength : hint_range(0.0, 1.4) = 0.0;
uniform float glow_spread : hint_range(0.0, 0.10) = 0.02;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float diffuse = 0.0;
	for (int index = 0; index < 16; index++) {
		float angle = float(index) * 0.3926990817;
		vec2 direction = vec2(cos(angle), sin(angle));
		diffuse += texture(TEXTURE, UV + direction * glow_spread * 0.28).a * 0.44;
		diffuse += texture(TEXTURE, UV + direction * glow_spread * 0.55).a * 0.30;
		diffuse += texture(TEXTURE, UV + direction * glow_spread * 0.86).a * 0.18;
		diffuse += texture(TEXTURE, UV + direction * glow_spread * 1.18).a * 0.08;
	}
	diffuse /= 16.0;
	float soft_halo = diffuse * (1.0 - source.a * 0.78);
	float inner_light = source.a * 0.035;
	COLOR = vec4(glow_color.rgb, (soft_halo + inner_light) * glow_strength);
}
"""

static var _glow_shader: Shader = null

static func item_position(element_id: String) -> Vector2:
	return _ITEM_POSITIONS.get(element_id, Vector2.ZERO)

static func chain_endpoint_x(element_id: String) -> float:
	return float(_CHAIN_ENDPOINT_X.get(element_id, 0.0))

static func charm_attachment_x(element_id: String) -> float:
	return item_position(element_id).x + CHARM_RECT.position.x + CHARM_RECT.size.x * 0.5

static func pointer_hit_test(local_position: Vector2) -> bool:
	return (
		local_position.distance_to(POINTER_HIT_CENTER) <= POINTER_HIT_RADIUS
		or POINTER_PLACARD_HIT_RECT.has_point(local_position)
	)

static func glow_strength(value: int) -> float:
	if value <= 0:
		return 0.0
	return lerpf(0.16, 1.12, clampf(float(value - 1) / 5.0, 0.0, 1.0))

static func glow_spread(value: int) -> float:
	if value <= 0:
		return 0.0
	return lerpf(0.018, 0.090, clampf(float(value - 1) / 5.0, 0.0, 1.0))

static func cropped_texture(source: Texture2D, padding_ratio: float = 0.08) -> Texture2D:
	if source == null:
		return null
	var image: Image = source.get_image()
	if image == null or image.is_empty():
		return source
	var used_rect: Rect2i = image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		return source
	var padding: int = maxi(2, int(roundf(float(maxi(used_rect.size.x, used_rect.size.y)) * padding_ratio)))
	var padded_rect: Rect2i = used_rect.grow(padding).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(padded_rect.position, padded_rect.size)
	return atlas

static func make_glow_material(element_id: String, value: int) -> ShaderMaterial:
	if _glow_shader == null:
		_glow_shader = Shader.new()
		_glow_shader.code = _GLOW_SHADER_SOURCE
	var material := ShaderMaterial.new()
	material.shader = _glow_shader
	update_glow_material(material, element_id, value)
	return material

static func update_glow_material(material: ShaderMaterial, element_id: String, value: int) -> void:
	if material == null:
		return
	material.set_shader_parameter("glow_color", ElementData.accent(element_id).lightened(0.24))
	material.set_shader_parameter("glow_strength", glow_strength(value))
	material.set_shader_parameter("glow_spread", glow_spread(value))
