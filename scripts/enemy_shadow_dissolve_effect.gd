extends Control
class_name EnemyShadowDissolveEffect

const DISSOLVE_SHADER: Shader = preload("res://assets/shaders/enemy_shadow_dissolve.gdshader")
const HORIZONTAL_EXPANSION_RATIO: float = 0.34
const TOP_EXPANSION_RATIO: float = 0.46
const BOTTOM_EXPANSION_RATIO: float = 0.16

var _source_texture: Texture2D = null
var _draw_texture: Texture2D = null
var _source_rect: Rect2 = Rect2()
var _expanded_rect: Rect2 = Rect2()
var _progress: float = 0.0
var _seed: float = 0.0
var _reduced_motion: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = false
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var shader_material := ShaderMaterial.new()
	shader_material.shader = DISSOLVE_SHADER
	material = shader_material


func configure(
	texture: Texture2D,
	source_rect: Rect2,
	progress: float,
	seed: float,
	reduced_motion: bool
) -> void:
	_source_texture = texture
	_source_rect = source_rect
	_progress = clampf(progress, 0.0, 1.0)
	_seed = seed
	_reduced_motion = reduced_motion
	_expanded_rect = _expanded_effect_rect(source_rect)
	position = _expanded_rect.position
	size = _expanded_rect.size
	var source_uv_rect: Rect2 = _source_uv_rect_for_expanded_rect(source_rect, _expanded_rect)
	var sampled_texture: Texture2D = _source_texture
	var atlas_region_min := Vector2.ZERO
	var atlas_region_size := Vector2.ONE
	if _source_texture is AtlasTexture:
		var atlas_texture: AtlasTexture = _source_texture as AtlasTexture
		if atlas_texture.atlas != null and atlas_texture.atlas.get_size().x > 0.0 and atlas_texture.atlas.get_size().y > 0.0:
			sampled_texture = atlas_texture.atlas
			atlas_region_min = atlas_texture.region.position / atlas_texture.atlas.get_size()
			atlas_region_size = atlas_texture.region.size / atlas_texture.atlas.get_size()
	_draw_texture = sampled_texture
	var shader_material: ShaderMaterial = material as ShaderMaterial
	shader_material.set_shader_parameter("source_texture", sampled_texture)
	shader_material.set_shader_parameter("atlas_region_min", atlas_region_min)
	shader_material.set_shader_parameter("atlas_region_size", atlas_region_size)
	shader_material.set_shader_parameter("progress", _progress)
	shader_material.set_shader_parameter("seed", _seed)
	shader_material.set_shader_parameter("reduced_motion", _reduced_motion)
	shader_material.set_shader_parameter("source_uv_min", source_uv_rect.position)
	shader_material.set_shader_parameter("source_uv_size", source_uv_rect.size)
	visible = _source_texture != null and source_rect.size.x > 0.0 and source_rect.size.y > 0.0
	queue_redraw()


func source_rect() -> Rect2:
	return _source_rect


func expanded_rect() -> Rect2:
	return _expanded_rect


func dissolve_progress() -> float:
	return _progress


func dissolve_seed() -> float:
	return _seed


func reduced_motion_enabled() -> bool:
	return _reduced_motion


func _draw() -> void:
	if _draw_texture == null or size.x <= 0.0 or size.y <= 0.0:
		return
	# AtlasTexture draw commands submit atlas-relative UVs. The dissolve shader
	# needs a stable 0..1 effect canvas, so draw the underlying texture and sample
	# the authored atlas region explicitly through shader uniforms.
	draw_texture_rect(_draw_texture, Rect2(Vector2.ZERO, size), false, Color.WHITE)


func _expanded_effect_rect(source_rect: Rect2) -> Rect2:
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return source_rect
	var horizontal_margin: float = source_rect.size.x * HORIZONTAL_EXPANSION_RATIO
	var top_margin: float = source_rect.size.y * TOP_EXPANSION_RATIO
	var bottom_margin: float = source_rect.size.y * BOTTOM_EXPANSION_RATIO
	return Rect2(
		source_rect.position - Vector2(horizontal_margin, top_margin),
		source_rect.size + Vector2(horizontal_margin * 2.0, top_margin + bottom_margin)
	)


func _source_uv_rect_for_expanded_rect(source_rect: Rect2, effect_rect: Rect2) -> Rect2:
	if effect_rect.size.x <= 0.0 or effect_rect.size.y <= 0.0:
		return Rect2(Vector2.ZERO, Vector2.ONE)
	return Rect2(
		(source_rect.position - effect_rect.position) / effect_rect.size,
		source_rect.size / effect_rect.size
	)
