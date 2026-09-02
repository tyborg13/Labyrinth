shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
uniform bool reduced_motion = false;
uniform sampler2D source_texture : source_color, filter_linear;
uniform vec2 atlas_region_min = vec2(0.0);
uniform vec2 atlas_region_size = vec2(1.0);
uniform vec2 source_uv_min = vec2(0.20, 0.28);
uniform vec2 source_uv_size = vec2(0.60, 0.62);
uniform vec4 umbra_low : source_color = vec4(0.010, 0.006, 0.022, 1.0);
uniform vec4 umbra_high : source_color = vec4(0.120, 0.042, 0.190, 1.0);
uniform vec4 fracture_glint : source_color = vec4(0.390, 0.145, 0.545, 1.0);


float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}


float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}


float fbm(vec2 point) {
	float total = 0.0;
	float weight = 0.52;
	total += value_noise(point) * weight;
	point = point * 2.03 + vec2(11.7, 7.1);
	weight *= 0.51;
	total += value_noise(point) * weight;
	point = point * 2.01 + vec2(-4.3, 13.9);
	weight *= 0.51;
	total += value_noise(point) * weight;
	point = point * 2.07 + vec2(8.2, -6.4);
	weight *= 0.51;
	total += value_noise(point) * weight;
	return total / 0.990;
}


float inside_sprite(vec2 uv) {
	return step(0.0, uv.x) * step(0.0, uv.y) * step(uv.x, 1.0) * step(uv.y, 1.0);
}


vec4 sprite_sample(vec2 uv) {
	vec2 atlas_uv = atlas_region_min + clamp(uv, vec2(0.0), vec2(1.0)) * atlas_region_size;
	return texture(source_texture, atlas_uv) * inside_sprite(uv);
}


float dissolve_field(vec2 sprite_uv) {
	vec2 seeded = sprite_uv + vec2(seed * 0.071, seed * 0.113);
	float broad_mass = fbm(seeded * vec2(5.2, 6.8));
	float fibrous_detail = fbm(seeded * vec2(15.0, 21.0) + vec2(sprite_uv.y * 3.8, 0.0));
	float grounded_bias = sprite_uv.y * 0.14;
	return clamp(broad_mass * 0.68 + fibrous_detail * 0.22 + grounded_bias, 0.0, 1.0);
}


vec4 alpha_over(vec4 background, vec4 foreground) {
	float out_alpha = foreground.a + background.a * (1.0 - foreground.a);
	if (out_alpha <= 0.0001) {
		return vec4(0.0);
	}
	vec3 out_rgb = (
		foreground.rgb * foreground.a
		+ background.rgb * background.a * (1.0 - foreground.a)
	) / out_alpha;
	return vec4(out_rgb, out_alpha);
}


vec4 ground_shadow_pool(vec2 expanded_uv, float p) {
	float arrival = smoothstep(0.10, 0.38, p);
	float departure = 1.0 - smoothstep(0.78, 1.0, p);
	float envelope = arrival * departure;
	if (envelope <= 0.001) {
		return vec4(0.0);
	}
	float bottom = source_uv_min.y + source_uv_size.y * 0.94;
	float pool_width = mix(source_uv_size.x * 0.24, source_uv_size.x * 0.52, smoothstep(0.12, 0.72, p));
	float pool_height = mix(0.010, 0.036, smoothstep(0.14, 0.62, p));
	if (reduced_motion) {
		pool_width = source_uv_size.x * 0.27;
		pool_height = 0.014;
		envelope *= 0.55;
	}
	vec2 pool_uv = (expanded_uv - vec2(0.5, bottom)) / vec2(max(pool_width, 0.001), max(pool_height, 0.001));
	float pool_noise = fbm(vec2(pool_uv.x * 2.5 + seed * 0.2, pool_uv.y * 4.0 - seed * 0.1));
	float distance_field = length(pool_uv) + (pool_noise - 0.5) * 0.24;
	float breakup = smoothstep(0.18, 0.80, fbm(expanded_uv * vec2(19.0, 31.0) + seed));
	float late_fragmentation = mix(1.0, breakup, smoothstep(0.68, 0.94, p));
	float alpha = (1.0 - smoothstep(0.64, 1.08, distance_field)) * envelope * late_fragmentation * 0.74;
	vec3 color = mix(umbra_low.rgb, umbra_high.rgb, clamp(pool_noise * 0.45, 0.0, 1.0));
	return vec4(color, alpha);
}


vec4 silhouette_wisp(
	vec2 sprite_uv,
	float p,
	float layer,
	float horizontal_direction,
	float rise_scale
) {
	if (reduced_motion) {
		return vec4(0.0);
	}
	float arrival = smoothstep(0.24 + layer * 0.06, 0.48 + layer * 0.05, p);
	float departure = 1.0 - smoothstep(0.78 + layer * 0.04, 1.0, p);
	float envelope = arrival * departure;
	float rise = smoothstep(0.20, 0.94, p) * rise_scale;
	float drift = horizontal_direction * rise * (0.22 + 0.12 * layer);
	vec2 sampled_uv = sprite_uv + vec2(-drift, rise);
	vec4 source = sprite_sample(sampled_uv);
	float field = dissolve_field(sampled_uv);
	float threshold = smoothstep(0.24, 0.92, p) * 0.90;
	float already_released = 1.0 - smoothstep(threshold - 0.10, threshold + 0.10, field);
	float filament = fbm(vec2(
		sampled_uv.x * (7.0 + layer * 2.5) + sampled_uv.y * 2.7,
		sampled_uv.y * (13.0 + layer * 3.0) - seed * 0.17
	));
	filament = smoothstep(0.50 + layer * 0.04, 0.80 + layer * 0.03, filament);
	float taper = smoothstep(0.0, 0.18, sampled_uv.y) * (1.0 - smoothstep(0.76, 1.05, rise));
	float alpha = source.a * already_released * filament * envelope * taper * (0.32 - layer * 0.07);
	float source_luma = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 color = mix(umbra_low.rgb, umbra_high.rgb, source_luma * 0.58 + filament * 0.16);
	return vec4(color, alpha);
}


void fragment() {
	float p = clamp(progress, 0.0, 1.0);
	vec2 sprite_uv = (UV - source_uv_min) / max(source_uv_size, vec2(0.0001));
	float field = dissolve_field(sprite_uv);
	float motion_envelope = smoothstep(0.16, 0.76, p);
	float lateral_flow = sin((sprite_uv.y * 8.0 + seed * 1.7) + field * 4.0) * 0.014 * motion_envelope;
	float downward_flow = (0.010 + field * 0.030) * motion_envelope;
	if (reduced_motion) {
		lateral_flow = 0.0;
		downward_flow = 0.0;
	}
	vec2 flowed_uv = sprite_uv - vec2(lateral_flow, downward_flow);
	vec4 source = sprite_sample(flowed_uv);
	float flowed_field = dissolve_field(flowed_uv);
	float threshold = smoothstep(0.26, 0.94, p);
	float fragmented_survival = smoothstep(threshold - 0.105, threshold + 0.105, flowed_field);
	float breakup_blend = smoothstep(0.18, 0.34, p);
	float survival = mix(1.0, fragmented_survival, breakup_blend);
	float final_fade = 1.0 - smoothstep(0.92, 1.0, p);

	float bottom_first_wave = clamp(p * 1.52 - (1.0 - flowed_uv.y) * 0.50 - flowed_field * 0.20, 0.0, 1.0);
	float shadow_takeover = smoothstep(0.02, 0.72, bottom_first_wave);
	if (reduced_motion) {
		shadow_takeover = smoothstep(0.02, 0.58, p);
	}
	float luma = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 shadow_color = mix(umbra_low.rgb, umbra_high.rgb, clamp(luma * 0.72 + flowed_field * 0.18, 0.0, 1.0));
	float fracture_edge = (1.0 - smoothstep(0.0, 0.065, abs(flowed_field - threshold))) * breakup_blend;
	fracture_edge *= source.a * smoothstep(0.22, 0.80, p) * (1.0 - smoothstep(0.82, 0.98, p));
	vec3 body_color = mix(source.rgb, shadow_color, shadow_takeover);
	body_color = mix(body_color, fracture_glint.rgb, fracture_edge * 0.52);
	vec4 body = vec4(body_color, source.a * survival * final_fade);

	float direction = hash21(vec2(floor(seed * 31.0), 17.0)) < 0.5 ? -1.0 : 1.0;
	vec4 result = ground_shadow_pool(UV, p);
	result = alpha_over(result, silhouette_wisp(sprite_uv, p, 0.0, direction, 0.19));
	result = alpha_over(result, silhouette_wisp(sprite_uv, p, 1.0, -direction, 0.28));
	result = alpha_over(result, silhouette_wisp(sprite_uv, p, 2.0, direction, 0.38));
	result = alpha_over(result, body);
	COLOR = result;
}
