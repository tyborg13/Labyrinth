extends Control

# Backdrop atmosphere between the hall art and the board: a warm pool of torch
# light under the board, a soft vignette that settles the frame, and a few
# slow dust/ember motes drifting through the hall. One shader pass handles
# light and vignette together (premultiplied alpha); the motes are a small CPU
# particle system that stops entirely under reduced motion.

const SettingsStore = preload("res://scripts/settings_store.gd")

const ATMOSPHERE_SHADER_CODE: String = """
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

uniform vec2 pool_center = vec2(0.5, 0.44);
uniform vec2 pool_radius = vec2(0.36, 0.30);
uniform vec4 pool_color : source_color = vec4(1.0, 0.60, 0.28, 1.0);
uniform float pool_strength = 0.17;
uniform vec4 vignette_color : source_color = vec4(0.018, 0.012, 0.010, 1.0);
uniform float vignette_strength = 0.80;
uniform float vignette_inner = 0.30;
uniform float vignette_outer = 1.02;
uniform float aspect = 1.7778;

void fragment() {
	vec2 q = (UV - vec2(0.5)) * 2.0;
	float edge = length(q * vec2(1.0, 0.92)) / 1.36;
	float vignette = smoothstep(vignette_inner, vignette_outer, edge) * vignette_strength;
	vec2 pc = (UV - pool_center) / pool_radius;
	pc.x *= 1.0;
	float pool = exp(-dot(pc, pc) * 1.45) * pool_strength;
	vec3 glow = pool_color.rgb * pool;
	COLOR = vec4(glow * (1.0 - vignette) + vignette_color.rgb * vignette, vignette);
}
"""

const MOTE_COUNT: int = 34
const MOTE_LIFETIME: float = 11.0
const BOARD_SAMPLE_SECONDS: float = 0.25

var board: Control
var _shade: ColorRect
var _material: ShaderMaterial
var _motes: CPUParticles2D
var _sample_elapsed: float = 0.0
var _motion_enabled: bool = true

func _ready() -> void:
	name = "CombatAtmosphere"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade = ColorRect.new()
	_shade.name = "AtmosphereShade"
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = ATMOSPHERE_SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	_shade.material = _material
	add_child(_shade)
	_motes = _build_motes()
	add_child(_motes)
	resized.connect(_on_resized)
	_on_resized()
	set_motion_enabled(not SettingsStore.applied_reduced_motion_enabled())

func set_motion_enabled(enabled: bool) -> void:
	_motion_enabled = enabled
	if _motes != null:
		_motes.emitting = enabled and is_visible_in_tree()
		_motes.visible = enabled

func set_pool_strength(strength: float) -> void:
	if _material != null:
		_material.set_shader_parameter("pool_strength", strength)

func _process(delta: float) -> void:
	_sample_elapsed += delta
	if _sample_elapsed < BOARD_SAMPLE_SECONDS:
		return
	_sample_elapsed = 0.0
	_sync_pool_to_board()

func _on_resized() -> void:
	if _material != null and size.y > 0.0:
		_material.set_shader_parameter("aspect", size.x / size.y)
	if _motes != null:
		_motes.position = Vector2(size.x * 0.5, size.y * 0.62)
		_motes.emission_rect_extents = Vector2(size.x * 0.46, size.y * 0.34)
	_sync_pool_to_board()

func _sync_pool_to_board() -> void:
	if _material == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var center := Vector2(0.5, 0.44)
	if board != null and is_instance_valid(board) and board.is_visible_in_tree() and board.size.x > 0.0:
		var rect: Rect2 = board.get_global_rect()
		var local_center: Vector2 = rect.get_center() - get_global_rect().position
		center = Vector2(clampf(local_center.x / size.x, 0.2, 0.8), clampf(local_center.y / size.y, 0.2, 0.8))
	_material.set_shader_parameter("pool_center", center)

func _build_motes() -> CPUParticles2D:
	var motes := CPUParticles2D.new()
	motes.name = "AtmosphereMotes"
	motes.amount = MOTE_COUNT
	motes.lifetime = MOTE_LIFETIME
	motes.preprocess = MOTE_LIFETIME
	motes.randomness = 1.0
	motes.local_coords = false
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.direction = Vector2(0.15, -1.0)
	motes.spread = 28.0
	motes.gravity = Vector2(0.0, -4.0)
	motes.initial_velocity_min = 6.0
	motes.initial_velocity_max = 18.0
	motes.angular_velocity_min = -20.0
	motes.angular_velocity_max = 20.0
	motes.scale_amount_min = 0.35
	motes.scale_amount_max = 1.0
	motes.texture = _mote_texture()
	var ramp := Gradient.new()
	ramp.set_offset(0, 0.0)
	ramp.set_color(0, Color(1.0, 0.72, 0.38, 0.0))
	ramp.set_offset(1, 1.0)
	ramp.set_color(1, Color(1.0, 0.55, 0.22, 0.0))
	ramp.add_point(0.18, Color(1.0, 0.76, 0.44, 0.42))
	ramp.add_point(0.70, Color(1.0, 0.62, 0.30, 0.26))
	motes.color_ramp = ramp
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	motes.material = material
	return motes

static func _mote_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(0.35, Color(1.0, 1.0, 1.0, 0.55))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 12
	texture.height = 12
	return texture
