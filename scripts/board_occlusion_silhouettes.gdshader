shader_type canvas_item;
render_mode unshaded;

uniform vec4 rim_color : source_color;
uniform float over_alpha = 0.0;
uniform sampler2D silhouette_texture : repeat_disable;
uniform vec2 radius_uv;
uniform vec2 radius_source;
uniform vec2 mask_min;
uniform vec2 mask_max;
varying float fade_alpha;
const int OUTER_SAMPLES = 16;
const int INNER_SAMPLES = 8;

void vertex() {
	// Expand the quad too: opaque pixels touching a source edge still have a
	// complete outside rim. radius_uv is 2 * zoom in board destination pixels.
	fade_alpha = COLOR.a;
	VERTEX += sign(VERTEX) * radius_source;
	UV = mix(mask_min - radius_uv, mask_max + radius_uv, (UV - mask_min) / (mask_max - mask_min));
}

float mask_at(vec2 uv) {
	if (any(lessThan(uv, mask_min)) || any(greaterThan(uv, mask_max))) return 0.0;
	return texture(silhouette_texture, uv).a;
}

void fragment() {
	float center = mask_at(UV);
	float outside = center;
	if (center < 1.0) {
		for (int i = 0; i < OUTER_SAMPLES; i++) {
			float angle = float(i) * 6.28318530718 / float(OUTER_SAMPLES);
			outside = max(outside, mask_at(UV + vec2(cos(angle), sin(angle)) * radius_uv));
		}
		// The inner ring closes gaps beside single-pixel weapons and rig parts.
		for (int i = 0; i < INNER_SAMPLES; i++) {
			float angle = float(i) * 6.28318530718 / float(INNER_SAMPLES);
			outside = max(outside, mask_at(UV + vec2(cos(angle), sin(angle)) * radius_uv * 0.5));
		}
	}
	float mask = max(0.0, outside - center);
	float base_alpha = rim_color.a * fade_alpha;
	float residual = max(0.0, (base_alpha - over_alpha) * mask) / max(0.00001, 1.0 - over_alpha * mask);
	COLOR = vec4(rim_color.rgb, residual);
}
