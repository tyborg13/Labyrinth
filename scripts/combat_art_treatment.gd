extends RefCounted
## Shared world-art material. Opt-in quads carry their palette profile in a
## reserved UV lane; the vertex shader removes it before texture sampling.
## Untagged draw commands (HUD, targeting, surfaces, particles) pass through.
## This preserves the retained painter order without extra canvases/readbacks.

const SHADER: Shader = preload("res://assets/shaders/combat_art_treatment.gdshader")
const FLOOR_CACHE_SHADER: Shader = preload("res://assets/shaders/combat_floor_light.gdshader")
const UV_LANE: float = 8.0
const FLOOR: int = 1
const STONE: int = 2
const PROP: int = 3
const ACTOR: int = 4
const ACTOR_ATLAS: int = 5
const EMISSIVE: int = 6
const GROUND_MARK: int = 7
const LightingProfiles = preload("res://scripts/combat_lighting_profiles.gd")
const MAX_LIGHTS: int = 24
const SHADOW_CAST: Vector2 = Vector2(0.19, 0.105)

var material: ShaderMaterial
var cache_bake_material: ShaderMaterial
var floor_material: ShaderMaterial
var contact_texture: GradientTexture2D
var enabled: bool = true
var _parameters: Dictionary = {}
var source_count: int = 0
var source_overflow: int = 0
var preset: String = LightingProfiles.DEFAULT_ID
var _clock: float = 0.0
var _reduced_motion: bool = true
var _light_flicker := PackedFloat32Array()
var _source_phases := PackedFloat32Array()

func _init() -> void:
	material = ShaderMaterial.new()
	material.shader = SHADER
	cache_bake_material = ShaderMaterial.new()
	cache_bake_material.shader = SHADER
	floor_material = ShaderMaterial.new()
	floor_material.shader = FLOOR_CACHE_SHADER
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.20, 0.58, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.82), Color(1, 1, 1, 0.27), Color(1, 1, 1, 0)])
	contact_texture = GradientTexture2D.new()
	contact_texture.width = 64
	contact_texture.height = 64
	contact_texture.gradient = gradient
	contact_texture.fill = GradientTexture2D.FILL_RADIAL
	contact_texture.fill_from = Vector2(0.5, 0.5)
	contact_texture.fill_to = Vector2(1.0, 0.5)
	# Development override only; ordinary gameplay needs no flag or saved setting.
	var requested: String = OS.get_environment("LABYRINTH_ART_LOOK")
	if LightingProfiles.has_profile(requested):
		preset = requested
	configure([], "")

func configure(sources: Array, element: String, reduced_motion: bool = true) -> void:
	var positions := PackedVector4Array()
	var colors := PackedVector4Array()
	_source_phases.clear()
	source_count = mini(sources.size(), MAX_LIGHTS)
	source_overflow = maxi(0, sources.size() - MAX_LIGHTS)
	for index: int in range(MAX_LIGHTS):
		if index < source_count:
			var entry: Dictionary = sources[index]
			var point: Vector2 = entry["point"]
			var color: Color = entry.get("color", Color(1.0, 0.48, 0.17, 0.8))
			positions.append(Vector4(point.x, point.y, float(entry["radius"]), float(entry.get("height", 0.0))))
			colors.append(Vector4(color.r, color.g, color.b, color.a))
			_source_phases.append(point.x * 0.031 + point.y * 0.017)
		else:
			positions.append(Vector4.ZERO)
			colors.append(Vector4.ZERO)
			_source_phases.append(0.0)
	var ambient := Vector3(0.985, 0.985, 1.01)
	match element:
		"ice": ambient = Vector3(0.965, 0.985, 1.025)
		"fire": ambient = Vector3(1.015, 0.975, 0.955)
		"lightning": ambient = Vector3(0.985, 0.97, 1.025)
		"earth": ambient = Vector3(0.99, 0.995, 0.965)
	_parameters = {"art_strength": 1.0 if enabled else 0.0, "art_light_count": source_count,
		"art_lights": positions, "art_light_colors": colors, "art_ambient": ambient}
	_apply_preset_parameters()
	_reduced_motion = reduced_motion
	_update_flicker()
	_apply_materials()

func _apply_materials() -> void:
	apply_to(material)
	apply_to(floor_material)
	apply_to(cache_bake_material)
	var steady := PackedFloat32Array()
	steady.resize(MAX_LIGHTS)
	steady.fill(1.0)
	cache_bake_material.set_shader_parameter("art_light_flicker", steady)

func set_preset(value: String) -> bool:
	if not LightingProfiles.has_profile(value):
		return false
	preset = value
	_apply_preset_parameters()
	_apply_materials()
	return true

func _apply_preset_parameters() -> void:
	var look: Dictionary = LightingProfiles.definition(preset)
	for key: String in ["ambient", "gain", "reach", "contrast", "saturation", "rim"]:
		_parameters["art_" + key + "_level"] = look[key]
	_parameters["art_look_tint"] = look["tint"]

func advance(delta: float, reduced_motion: bool) -> bool:
	if not enabled or source_count == 0:
		return false
	if reduced_motion and _reduced_motion:
		return false
	_reduced_motion = reduced_motion
	if not reduced_motion:
		_clock = fmod(_clock + maxf(delta, 0.0), 3600.0)
	_update_flicker()
	apply_motion_to(material)
	apply_motion_to(floor_material)
	return true

func _update_flicker() -> void:
	_light_flicker.resize(MAX_LIGHTS)
	for index: int in range(MAX_LIGHTS):
		var phase: float = _source_phases[index]
		# Two slow, low-amplitude components; computed per source on the CPU,
		# never per fragment. Reduced motion has an exact stable value of one.
		_light_flicker[index] = 1.0 if _reduced_motion else 1.0 + 0.045 * sin(_clock * 3.7 + phase) + 0.025 * sin(_clock * 6.1 + phase * 1.71)
	_parameters["art_light_flicker"] = _light_flicker

func apply_motion_to(target: ShaderMaterial) -> void:
	target.set_shader_parameter("art_light_flicker", _light_flicker)

func set_enabled(value: bool) -> void:
	enabled = value
	_parameters["art_strength"] = 1.0 if enabled else 0.0
	_apply_materials()

func apply_to(target: ShaderMaterial) -> void:
	for key: String in _parameters:
		target.set_shader_parameter(key, _parameters[key])

static func actor_profile(unit: Dictionary, texture: Texture2D) -> int:
	if str(unit.get("type", "")) in ["lightning_wisp", "cinder_droplet", "cinder_ooze"]:
		return EMISSIVE
	return ACTOR_ATLAS if texture is AtlasTexture else ACTOR

static func draw_rect(canvas: CanvasItem, texture: Texture2D, rect: Rect2, tint: Color, profile: int, source: Rect2 = Rect2()) -> void:
	if texture == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var sampled: Texture2D = texture
	var source_rect: Rect2 = source if source.size != Vector2.ZERO else Rect2(Vector2.ZERO, texture.get_size())
	if texture is AtlasTexture:
		var atlas: AtlasTexture = texture as AtlasTexture
		if atlas.atlas == null:
			return
		sampled = atlas.atlas
		# Respect transparent AtlasTexture margins, including clipped actor slices.
		var visible_region := Rect2(atlas.margin.position, atlas.region.size)
		var clipped: Rect2 = source_rect.intersection(visible_region)
		if not clipped.has_area():
			return
		rect = Rect2(rect.position + (clipped.position - source_rect.position) / source_rect.size * rect.size, clipped.size / source_rect.size * rect.size)
		source_rect = Rect2(atlas.region.position + clipped.position - atlas.margin.position, clipped.size)
	var tex_size: Vector2 = sampled.get_size()
	var uv := Rect2(source_rect.position / tex_size, source_rect.size / tex_size)
	var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var uvs := PackedVector2Array([uv.position, Vector2(uv.end.x, uv.position.y), uv.end, Vector2(uv.position.x, uv.end.y)])
	draw_polygon(canvas, points, PackedColorArray([tint]), uvs, sampled, profile)

static func draw_polygon(canvas: CanvasItem, points: PackedVector2Array, colors: PackedColorArray, uvs: PackedVector2Array, texture: Texture2D, profile: int) -> void:
	var tagged: PackedVector2Array = uvs.duplicate()
	for index: int in range(tagged.size()):
		tagged[index].x += UV_LANE * float(profile)
	canvas.draw_polygon(points, colors, tagged, texture)

static func draw_ground_mark(canvas: CanvasItem, texture: Texture2D, center: Vector2, scale: float, tint: Color) -> void:
	var size: Vector2 = texture.get_size() * Vector2(scale, scale * 0.5)
	var rect := Rect2(center - size * 0.5, size)
	var shadow_rect := Rect2(rect.position + Vector2(0.7, 1.5), size)
	canvas.draw_texture_rect(texture, shadow_rect, false, Color(0.025, 0.017, 0.014, 0.42))
	draw_rect(canvas, texture, rect, tint, GROUND_MARK)
