shader_type canvas_item;
render_mode unshaded;

uniform vec4 rim_color : source_color;
uniform float over_alpha = 0.0;
uniform float fill_alpha = 0.0;
uniform int fill_count = 0;
uniform float fill_opaque_threshold;
uniform vec4 fill_grid; // Board origin and game-pixel size in board coordinates.
uniform sampler2D fill_atlas : filter_linear, repeat_disable;
uniform sampler2D fill_objects : filter_nearest, repeat_disable;
uniform sampler2D silhouette_texture : repeat_disable;
uniform vec2 radius_uv;
uniform vec2 radius_source;
uniform vec2 mask_min;
uniform vec2 mask_max;
uniform vec4 object_rect;
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

// Each row holds the object's board rect, atlas rect (texels) and reveal alpha.
float object_cover(vec2 point) {
	float cover = 0.0;
	vec2 atlas_size = vec2(textureSize(fill_atlas, 0));
	for (int row = 0; row < fill_count; row++) {
		vec4 rect = texelFetch(fill_objects, ivec2(0, row), 0);
		vec2 local = (point - rect.xy) / rect.zw;
		if (any(lessThan(local, vec2(0.0))) || any(greaterThanEqual(local, vec2(1.0)))) continue;
		vec4 region = texelFetch(fill_objects, ivec2(1, row), 0);
		float opaque = textureLod(fill_atlas, (region.xy + local * region.zw) / atlas_size, 0.0).a;
		if (opaque <= fill_opaque_threshold) continue;
		cover = max(cover, texelFetch(fill_objects, ivec2(2, row), 0).r);
		if (cover >= 1.0) break;
	}
	return cover;
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
	// UV spans object_rect linearly, so this is the pixel's board position.
	vec2 point = object_rect.xy + (UV - mask_min) / (mask_max - mask_min) * object_rect.zw;
	float fill = 0.0;
	if (fill_count > 0 && fill_alpha > 0.0 && fade_alpha > 0.0 && center > 0.0) {
		vec2 cell = floor((point - fill_grid.xy) / fill_grid.zw);
		if (mod(cell.x + cell.y, 2.0) == 0.0) {
			fill = center * object_cover(point) * fill_alpha * fade_alpha;
		}
	}
	// Both layers use the same team RGB. Composite the rim over its fill.
	COLOR = vec4(rim_color.rgb, residual + fill * (1.0 - residual));
}
