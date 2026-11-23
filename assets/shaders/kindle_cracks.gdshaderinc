// Kindle lanes carry the original actor profile and select one of two strengths.
uniform vec3 kindle_orange;
uniform vec2 kindle_strengths;
uniform float kindle_pulse = 1.0;
varying flat float kindle_gain;

float kindle_strength(float profile) {
	if (profile >= 20.0) { return kindle_strengths.y; }
	if (profile >= 12.0) { return kindle_strengths.x; }
	return 0.0;
}

float kindle_art_profile(float profile) {
	if (profile >= 20.0) { return profile - 16.0; }
	if (profile >= 12.0) { return profile - 8.0; }
	return profile;
}

bool kindle_crack(vec4 texel) {
	vec3 rgb = texel.rgb;
	float value = max(rgb.r, max(rgb.g, rgb.b));
	float chroma = value - min(rgb.r, min(rgb.g, rgb.b));
	// Hue 0–45° lies in the red-dominant sector, with green above blue.
	return texel.a > 0.0 && value >= 0.30 && chroma >= 0.55 * value
		&& rgb.r == value && rgb.g >= rgb.b && rgb.g - rgb.b <= 0.75 * chroma;
}

// Sample the canvas built-in directly so the renderer retains its texture and sampler.
#define KINDLE_BOOST(painted, texel, uv, texel_size) \
	if (kindle_gain > 0.0 && (texel).a > 0.0) { \
		float mask = 1.0; \
		if (!kindle_crack(texel)) { \
			vec2 axial = 2.0 * (texel_size); \
			vec2 diagonal = axial * 0.70710678; \
			bool halo = kindle_crack(texture(TEXTURE, (uv) + vec2(axial.x, 0.0))) \
				|| kindle_crack(texture(TEXTURE, (uv) - vec2(axial.x, 0.0))) \
				|| kindle_crack(texture(TEXTURE, (uv) + vec2(0.0, axial.y))) \
				|| kindle_crack(texture(TEXTURE, (uv) - vec2(0.0, axial.y))) \
				|| kindle_crack(texture(TEXTURE, (uv) + diagonal)) \
				|| kindle_crack(texture(TEXTURE, (uv) - diagonal)) \
				|| kindle_crack(texture(TEXTURE, (uv) + vec2(diagonal.x, -diagonal.y))) \
				|| kindle_crack(texture(TEXTURE, (uv) + vec2(-diagonal.x, diagonal.y))); \
			mask = halo ? 0.5 : 0.0; \
		} \
		if (mask > 0.0) { \
			(painted).rgb = min((painted).rgb + kindle_orange * kindle_gain * kindle_pulse * mask, vec3(1.0)); \
		} \
	}
