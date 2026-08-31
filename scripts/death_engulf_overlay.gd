extends Control
class_name DeathEngulfOverlay

const ENGULF_SECONDS: float = 1.90
const FINAL_SHROUD_ALPHA: float = 0.90
const LIT_CORE_RADIUS: float = 0.105
const LIT_FADE_RADIUS: float = 0.285

const SHROUD_SHADER_CODE: String = """
shader_type canvas_item;
render_mode unshaded;

uniform vec2 death_center = vec2(0.32, 0.62);
uniform vec2 aspect_scale = vec2(1.7777778, 1.0);
uniform float engulf_progress : hint_range(0.0, 1.0) = 0.0;
uniform float shroud_alpha : hint_range(0.0, 1.0) = 0.90;

float cubic_ease(float x) {
	return x < 0.5 ? 4.0 * x * x * x : 1.0 - pow(-2.0 * x + 2.0, 3.0) * 0.5;
}

void fragment() {
	vec2 delta = (UV - death_center) * aspect_scale;
	float distance_from_death = length(delta);
	float angle = atan(delta.y, delta.x);
	float eased = cubic_ease(engulf_progress);
	float irregularity = sin(angle * 5.0 + eased * 2.2) * 0.018;
	irregularity += sin(angle * 9.0 - eased * 1.4) * 0.009;
	float front_radius = mix(1.32, 0.175, eased) + irregularity * eased;
	float coverage = smoothstep(front_radius - 0.055, front_radius + 0.070, distance_from_death);
	float settled_halo = smoothstep(0.105, 0.285, distance_from_death);
	float alpha = shroud_alpha * coverage * mix(1.0, settled_halo, smoothstep(0.72, 1.0, eased));
	vec3 umbra = mix(vec3(0.020, 0.018, 0.030), vec3(0.035, 0.020, 0.055), 0.18 + 0.12 * sin(angle * 3.0));
	COLOR = vec4(umbra, alpha);
}
"""

const GLOW_SHADER_CODE: String = """
shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec2 death_center = vec2(0.32, 0.62);
uniform vec2 aspect_scale = vec2(1.7777778, 1.0);
uniform float glow_alpha : hint_range(0.0, 1.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 delta = (UV - death_center) * aspect_scale;
	float distance_from_death = length(delta);
	float warm_core = 1.0 - smoothstep(0.025, 0.175 + pulse * 0.010, distance_from_death);
	float soft_falloff = 1.0 - smoothstep(0.070, 0.300 + pulse * 0.012, distance_from_death);
	vec3 ember = vec3(1.0, 0.28, 0.055) * warm_core * 0.58;
	ember += vec3(0.90, 0.16, 0.035) * soft_falloff * 0.28;
	COLOR = vec4(ember, max(warm_core * 0.35, soft_falloff * 0.18) * glow_alpha);
}
"""

var _elapsed: float = 0.0
var _motion_enabled: bool = true
var _playing: bool = false
var _death_site_normalized: Vector2 = Vector2(0.32, 0.62)
var _shroud_rect: ColorRect
var _glow_rect: ColorRect
var _shroud_material: ShaderMaterial
var _glow_material: ShaderMaterial

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)
	_build_layers()

func play(_board: Control = null) -> void:
	_elapsed = 0.0 if _motion_enabled else ENGULF_SECONDS
	_playing = true
	visible = true
	set_process(_motion_enabled)
	_update_visuals()

func reset() -> void:
	_elapsed = 0.0
	_playing = false
	visible = false
	set_process(false)
	_update_visuals()

func set_death_site_normalized(normalized_position: Vector2) -> void:
	_death_site_normalized = Vector2(
		clampf(normalized_position.x, 0.08, 0.92),
		clampf(normalized_position.y, 0.10, 0.90)
	)
	_update_visuals()

func death_site_normalized() -> Vector2:
	return _death_site_normalized

func ember_position() -> Vector2:
	return Vector2(size.x * _death_site_normalized.x, size.y * _death_site_normalized.y)

func set_motion_enabled(enabled: bool) -> void:
	_motion_enabled = enabled
	if _playing and not _motion_enabled:
		_elapsed = ENGULF_SECONDS
		set_process(false)
		_update_visuals()

func motion_enabled() -> bool:
	return _motion_enabled

func seek_seconds(seconds: float) -> void:
	_elapsed = clampf(seconds, 0.0, ENGULF_SECONDS)
	_playing = true
	visible = true
	set_process(_motion_enabled and _elapsed < ENGULF_SECONDS)
	_update_visuals()

func engulf_progress() -> float:
	return clampf(_elapsed / ENGULF_SECONDS, 0.0, 1.0)

func final_shroud_alpha() -> float:
	return FINAL_SHROUD_ALPHA

func has_decorative_edge_strokes() -> bool:
	return false

func sample_alpha(normalized_position: Vector2, progress_override: float = -1.0) -> float:
	var progress: float = engulf_progress() if progress_override < 0.0 else clampf(progress_override, 0.0, 1.0)
	var aspect: float = size.x / maxf(1.0, size.y)
	var delta := Vector2(
		(normalized_position.x - _death_site_normalized.x) * aspect,
		normalized_position.y - _death_site_normalized.y
	)
	var distance_from_death: float = delta.length()
	var eased: float = _ease_in_out_cubic(progress)
	var angle: float = atan2(delta.y, delta.x)
	var irregularity: float = sin(angle * 5.0 + eased * 2.2) * 0.018
	irregularity += sin(angle * 9.0 - eased * 1.4) * 0.009
	var front_radius: float = lerpf(1.32, 0.175, eased) + irregularity * eased
	var coverage: float = _smoothstep(front_radius - 0.055, front_radius + 0.070, distance_from_death)
	var settled_halo: float = _smoothstep(LIT_CORE_RADIUS, LIT_FADE_RADIUS, distance_from_death)
	return FINAL_SHROUD_ALPHA * coverage * lerpf(1.0, settled_halo, _smoothstep(0.72, 1.0, eased))

func _process(delta: float) -> void:
	if not _playing or not _motion_enabled:
		return
	_elapsed = minf(ENGULF_SECONDS, _elapsed + minf(delta, 1.0 / 30.0))
	if _elapsed >= ENGULF_SECONDS:
		set_process(false)
	_update_visuals()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_visuals()

func _build_layers() -> void:
	_shroud_material = _shader_material(SHROUD_SHADER_CODE)
	_shroud_rect = ColorRect.new()
	_shroud_rect.name = "LocalizedUmbraShroud"
	_shroud_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shroud_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shroud_rect.material = _shroud_material
	add_child(_shroud_rect)

	_glow_material = _shader_material(GLOW_SHADER_CODE)
	_glow_rect = ColorRect.new()
	_glow_rect.name = "LastLightGlow"
	_glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow_rect.material = _glow_material
	add_child(_glow_rect)

func _shader_material(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _update_visuals() -> void:
	if _shroud_material == null or _glow_material == null:
		return
	var progress: float = engulf_progress()
	var aspect := Vector2(size.x / maxf(1.0, size.y), 1.0)
	_shroud_material.set_shader_parameter("death_center", _death_site_normalized)
	_shroud_material.set_shader_parameter("aspect_scale", aspect)
	_shroud_material.set_shader_parameter("engulf_progress", progress)
	_shroud_material.set_shader_parameter("shroud_alpha", FINAL_SHROUD_ALPHA)
	var pulse: float = 0.5
	if _motion_enabled:
		pulse = 0.5 + sin(_elapsed * 7.2) * 0.5
	_glow_material.set_shader_parameter("death_center", _death_site_normalized)
	_glow_material.set_shader_parameter("aspect_scale", aspect)
	_glow_material.set_shader_parameter("glow_alpha", lerpf(0.86, 1.0, _smoothstep(0.0, 0.32, progress)))
	_glow_material.set_shader_parameter("pulse", pulse)

func _smoothstep(edge0: float, edge1: float, value: float) -> float:
	if is_equal_approx(edge0, edge1):
		return 1.0 if value >= edge1 else 0.0
	var x: float = clampf((value - edge0) / (edge1 - edge0), 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

func _ease_in_out_cubic(value: float) -> float:
	var x: float = clampf(value, 0.0, 1.0)
	if x < 0.5:
		return 4.0 * x * x * x
	return 1.0 - pow(-2.0 * x + 2.0, 3.0) * 0.5
