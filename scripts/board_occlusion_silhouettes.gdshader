shader_type canvas_item;
render_mode unshaded;

uniform vec4 rim_color : source_color;
uniform float over_alpha = 0.0;
uniform sampler2D silhouette_texture : repeat_disable;
uniform vec2 radius_uv;
uniform vec2 radius_source;
uniform vec2 mask_min;
uniform vec2 mask_max;
// Object rims pass behind the units painted in front of the object: the live
// textures below hide the rim wherever those units are opaque (occ-01).
uniform int front_count = 0;
uniform vec4 object_rect;
uniform sampler2D front_texture_0 : repeat_disable;
uniform sampler2D front_texture_1 : repeat_disable;
uniform sampler2D front_texture_2 : repeat_disable;
uniform sampler2D front_texture_3 : repeat_disable;
uniform vec4 front_rect_0;
uniform vec4 front_rect_1;
uniform vec4 front_rect_2;
uniform vec4 front_rect_3;
uniform vec4 front_region_0 = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 front_region_1 = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 front_region_2 = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 front_region_3 = vec4(0.0, 0.0, 1.0, 1.0);
// A unit showing a team rim also covers that ring: its alpha is dilated with
// the ring's own kernel and radius (front texture UV), so the object rim stops
// at the ring's outer edge. Zero for units without a team rim.
uniform vec2 front_pad_0;
uniform vec2 front_pad_1;
uniform vec2 front_pad_2;
uniform vec2 front_pad_3;
// occ-02: the body opacity of each front unit. A unit faded by the focus
// reveal hides only that share of the rim, so no hard gap remains over it.
uniform float front_alpha_0 = 1.0;
uniform float front_alpha_1 = 1.0;
uniform float front_alpha_2 = 1.0;
uniform float front_alpha_3 = 1.0;
varying float fade_alpha;
// Some painted actors are just under 1.0 alpha in solid areas (the warden is
// ~0.99); count those as opaque so no faint rim survives inside a body.
// Softer edge pixels still blend.
const float FRONT_OPAQUE = 0.95;
// A ring is drawn at 80% x (dilated - own alpha); hide the object rim fully
// wherever that ring is at least 10% opaque, fading out over its last texels.
const float RING_CUT = 0.125;
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

float front_sample(sampler2D front, vec4 region, vec2 uv) {
	if (any(lessThan(uv, region.xy)) || any(greaterThan(uv, region.zw))) return 0.0;
	return textureLod(front, uv, 0.0).a;
}

// How much of the object rim one front unit hides at this board point (0-1).
float front_cover(sampler2D front, vec4 rect, vec4 region, vec2 pad, vec2 point) {
	vec2 uv = mix(region.xy, region.zw, (point - rect.xy) / rect.zw);
	float alpha = front_sample(front, region, uv);
	if (pad.x <= 0.0) return clamp(alpha / FRONT_OPAQUE, 0.0, 1.0);
	if (alpha >= RING_CUT) return 1.0;
	for (int i = 0; i < OUTER_SAMPLES; i++) {
		float angle = float(i) * 6.28318530718 / float(OUTER_SAMPLES);
		alpha = max(alpha, front_sample(front, region, uv + vec2(cos(angle), sin(angle)) * pad));
	}
	for (int i = 0; i < INNER_SAMPLES; i++) {
		float angle = float(i) * 6.28318530718 / float(INNER_SAMPLES);
		alpha = max(alpha, front_sample(front, region, uv + vec2(cos(angle), sin(angle)) * pad * 0.5));
	}
	return clamp(alpha / RING_CUT, 0.0, 1.0);
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
	if (front_count > 0 && residual > 0.0) {
		// UV spans object_rect linearly, so this is the pixel's board position.
		vec2 point = object_rect.xy + (UV - mask_min) / (mask_max - mask_min) * object_rect.zw;
		float cover = front_cover(front_texture_0, front_rect_0, front_region_0, front_pad_0, point) * front_alpha_0;
		if (front_count > 1) cover = max(cover, front_cover(front_texture_1, front_rect_1, front_region_1, front_pad_1, point) * front_alpha_1);
		if (front_count > 2) cover = max(cover, front_cover(front_texture_2, front_rect_2, front_region_2, front_pad_2, point) * front_alpha_2);
		if (front_count > 3) cover = max(cover, front_cover(front_texture_3, front_rect_3, front_region_3, front_pad_3, point) * front_alpha_3);
		residual *= 1.0 - cover;
	}
	COLOR = vec4(rim_color.rgb, residual);
}
