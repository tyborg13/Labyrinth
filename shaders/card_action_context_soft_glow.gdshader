shader_type canvas_item;
render_mode unshaded;

uniform vec4 glow_color : source_color = vec4(1.0, 0.52, 0.15, 0.86);
uniform vec2 source_radius_px = vec2(15.0, 23.0);
uniform vec2 uv_margin = vec2(0.035, 0.085);

void fragment() {
	vec2 source_uv = (UV - uv_margin) / (vec2(1.0) - uv_margin * 2.0);
	vec2 texel = TEXTURE_PIXEL_SIZE * source_radius_px;
	float source_alpha = texture(TEXTURE, source_uv).a;
	float near_alpha = 0.0;
	float mid_alpha = 0.0;
	float outer_alpha = 0.0;

	near_alpha += texture(TEXTURE, source_uv + vec2(texel.x, 0.0) * 0.34).a;
	near_alpha += texture(TEXTURE, source_uv + vec2(-texel.x, 0.0) * 0.34).a;
	near_alpha += texture(TEXTURE, source_uv + vec2(0.0, texel.y) * 0.34).a;
	near_alpha += texture(TEXTURE, source_uv + vec2(0.0, -texel.y) * 0.34).a;
	near_alpha += texture(TEXTURE, source_uv + vec2(texel.x, texel.y) * 0.24).a;
	near_alpha += texture(TEXTURE, source_uv + vec2(-texel.x, texel.y) * 0.24).a;
	near_alpha += texture(TEXTURE, source_uv + vec2(texel.x, -texel.y) * 0.24).a;
	near_alpha += texture(TEXTURE, source_uv + vec2(-texel.x, -texel.y) * 0.24).a;
	near_alpha *= 0.125;

	mid_alpha += texture(TEXTURE, source_uv + vec2(texel.x, 0.0) * 0.66).a;
	mid_alpha += texture(TEXTURE, source_uv + vec2(-texel.x, 0.0) * 0.66).a;
	mid_alpha += texture(TEXTURE, source_uv + vec2(0.0, texel.y) * 0.66).a;
	mid_alpha += texture(TEXTURE, source_uv + vec2(0.0, -texel.y) * 0.66).a;
	mid_alpha += texture(TEXTURE, source_uv + vec2(texel.x, texel.y) * 0.47).a;
	mid_alpha += texture(TEXTURE, source_uv + vec2(-texel.x, texel.y) * 0.47).a;
	mid_alpha += texture(TEXTURE, source_uv + vec2(texel.x, -texel.y) * 0.47).a;
	mid_alpha += texture(TEXTURE, source_uv + vec2(-texel.x, -texel.y) * 0.47).a;
	mid_alpha *= 0.125;

	outer_alpha += texture(TEXTURE, source_uv + vec2(texel.x, 0.0)).a;
	outer_alpha += texture(TEXTURE, source_uv + vec2(-texel.x, 0.0)).a;
	outer_alpha += texture(TEXTURE, source_uv + vec2(0.0, texel.y)).a;
	outer_alpha += texture(TEXTURE, source_uv + vec2(0.0, -texel.y)).a;
	outer_alpha += texture(TEXTURE, source_uv + vec2(texel.x, texel.y) * 0.72).a;
	outer_alpha += texture(TEXTURE, source_uv + vec2(-texel.x, texel.y) * 0.72).a;
	outer_alpha += texture(TEXTURE, source_uv + vec2(texel.x, -texel.y) * 0.72).a;
	outer_alpha += texture(TEXTURE, source_uv + vec2(-texel.x, -texel.y) * 0.72).a;
	outer_alpha *= 0.125;

	float softened_alpha = near_alpha * 0.52 + mid_alpha * 0.30 + outer_alpha * 0.18;
	float halo = pow(clamp(softened_alpha, 0.0, 1.0), 0.72);
	// The authored placard renders above this layer. Suppressing its solid
	// interior leaves a warm edge-following halo instead of another panel.
	halo *= 1.0 - source_alpha * 0.96;
	COLOR = vec4(glow_color.rgb, halo * glow_color.a);
}
