class_name PreBattlePortraitEdgeMaterial
extends RefCounted

const SHADER_CODE: String = """
shader_type canvas_item;
render_mode unshaded;

uniform vec4 edge_widths = vec4(0.11, 0.10, 0.16, 0.17);
uniform vec4 edge_strengths = vec4(0.84, 0.82, 1.16, 1.20);
uniform vec2 focus_center = vec2(0.50, 0.34);
uniform vec2 focus_radius = vec2(0.30, 0.27);
uniform float focus_protection = 0.96;
uniform float wear_seed = 1.0;

float portrait_hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453123);
}

float portrait_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 fraction = fract(point);
	vec2 curve = fraction * fraction * (3.0 - 2.0 * fraction);
	float top = mix(portrait_hash(cell), portrait_hash(cell + vec2(1.0, 0.0)), curve.x);
	float bottom = mix(portrait_hash(cell + vec2(0.0, 1.0)), portrait_hash(cell + vec2(1.0, 1.0)), curve.x);
	return mix(top, bottom, curve.y);
}

float portrait_wear_noise(vec2 uv) {
	vec2 offset = vec2(wear_seed * 1.73, wear_seed * -0.91);
	float broad = portrait_noise(uv * vec2(11.0, 13.0) + offset);
	float medium = portrait_noise(uv * vec2(27.0, 23.0) - offset * 0.37);
	return broad * 0.68 + medium * 0.32;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float left_pressure = (1.0 - smoothstep(0.0, max(edge_widths.x, 0.001), UV.x)) * edge_strengths.x;
	float top_pressure = (1.0 - smoothstep(0.0, max(edge_widths.y, 0.001), UV.y)) * edge_strengths.y;
	float right_pressure = (1.0 - smoothstep(0.0, max(edge_widths.z, 0.001), 1.0 - UV.x)) * edge_strengths.z;
	float bottom_pressure = (1.0 - smoothstep(0.0, max(edge_widths.w, 0.001), 1.0 - UV.y)) * edge_strengths.w;
	float edge_pressure = max(max(left_pressure, top_pressure), max(right_pressure, bottom_pressure));

	vec2 guarded_delta = (UV - focus_center) / max(focus_radius, vec2(0.001));
	float focal_guard = 1.0 - smoothstep(0.62, 1.08, length(guarded_delta));
	float protected_pressure = edge_pressure * (1.0 - focal_guard * focus_protection);
	float irregularity = portrait_wear_noise(UV) - 0.5;
	float pixel_tooth = portrait_hash(floor(UV * 128.0) + vec2(wear_seed * 19.0, wear_seed * 7.0)) - 0.5;
	float worn_field = protected_pressure * (0.90 + irregularity * 0.34 + pixel_tooth * 0.16);
	float worn_alpha = smoothstep(0.18, 0.72, worn_field);
	float dry_fleck = step(0.91, portrait_hash(floor(UV * vec2(83.0, 79.0)) + wear_seed));
	dry_fleck *= smoothstep(0.16, 0.54, protected_pressure) * 0.10;
	float edge_mask = 1.0 - clamp(worn_alpha + dry_fleck, 0.0, 1.0);
	COLOR = vec4(source.rgb, source.a * edge_mask) * COLOR;
}
"""

const DEFAULT_PROFILE: Dictionary = {
	"focus_center": Vector2(0.50, 0.34),
	"focus_radius": Vector2(0.30, 0.27),
	"focus_protection": 0.96,
	"edge_widths": Vector4(0.11, 0.10, 0.16, 0.17),
	"edge_strengths": Vector4(0.84, 0.82, 1.16, 1.20),
}

# Only portraits whose focal silhouette meaningfully departs from the shared
# upper-center composition need overrides. This keeps the wear consistent while
# making the erosion content-aware instead of imposing one destructive mask.
const PROFILE_OVERRIDES: Dictionary = {
	"crawler": {
		"focus_center": Vector2(0.31, 0.38),
		"focus_radius": Vector2(0.31, 0.29),
		"focus_protection": 1.0,
		"edge_widths": Vector4(0.07, 0.08, 0.18, 0.20),
		"edge_strengths": Vector4(0.52, 0.60, 1.18, 1.22),
	},
	"cinder_ooze": {
		"focus_center": Vector2(0.50, 0.48),
		"focus_radius": Vector2(0.31, 0.28),
	},
	"iskaldra": {
		"focus_center": Vector2(0.27, 0.55),
		"focus_radius": Vector2(0.30, 0.28),
		"edge_widths": Vector4(0.13, 0.16, 0.17, 0.18),
		"edge_strengths": Vector4(0.68, 1.14, 1.20, 1.20),
	},
	"noctyrax": {
		"focus_center": Vector2(0.42, 0.56),
		"focus_radius": Vector2(0.31, 0.29),
		"edge_widths": Vector4(0.15, 0.16, 0.17, 0.18),
		"edge_strengths": Vector4(0.94, 1.14, 1.20, 1.20),
	},
	"tharokh": {
		"focus_center": Vector2(0.34, 0.58),
		"focus_radius": Vector2(0.32, 0.30),
		"edge_widths": Vector4(0.13, 0.16, 0.17, 0.18),
		"edge_strengths": Vector4(0.72, 1.12, 1.20, 1.20),
	},
	"vaeloryx": {
		"focus_center": Vector2(0.37, 0.57),
		"focus_radius": Vector2(0.31, 0.29),
		"edge_widths": Vector4(0.14, 0.16, 0.17, 0.18),
		"edge_strengths": Vector4(0.76, 1.10, 1.20, 1.20),
	},
	"vyraketh": {
		"focus_center": Vector2(0.34, 0.45),
		"focus_radius": Vector2(0.31, 0.29),
		"edge_widths": Vector4(0.14, 0.15, 0.17, 0.18),
		"edge_strengths": Vector4(0.76, 1.08, 1.20, 1.20),
	},
	"zekarion": {
		"focus_center": Vector2(0.45, 0.58),
		"focus_radius": Vector2(0.33, 0.30),
		"edge_widths": Vector4(0.15, 0.16, 0.17, 0.18),
		"edge_strengths": Vector4(0.96, 1.14, 1.20, 1.20),
	},
}

static var _shared_shader: Shader = null

static func profile_for(identity: String) -> Dictionary:
	var profile: Dictionary = DEFAULT_PROFILE.duplicate(true)
	if PROFILE_OVERRIDES.has(identity):
		profile.merge((PROFILE_OVERRIDES[identity] as Dictionary).duplicate(true), true)
	profile["wear_seed"] = 1.0 + float(absi(identity.hash() % 997)) / 997.0 * 17.0
	return profile

static func material_for(identity: String) -> ShaderMaterial:
	if _shared_shader == null:
		_shared_shader = Shader.new()
		_shared_shader.code = SHADER_CODE
	var profile: Dictionary = profile_for(identity)
	var material := ShaderMaterial.new()
	material.shader = _shared_shader
	for parameter: String in profile:
		material.set_shader_parameter(parameter, profile[parameter])
	return material
