shader_type canvas_item;
render_mode unshaded, blend_mix;

// ViewportTexture RGB is premultiplied. Compare straight RGB to the sRGB ramp.
uniform vec4 ramp[5];
uniform float alpha_floor;
uniform float alpha_bias;
// Cropped targets keep the original screen-anchored Bayer phase.
uniform vec2 cell_origin;
const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);
const vec3 LUMA = vec3(0.299, 0.587, 0.114);

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	ivec2 cell = ivec2(floor(UV / TEXTURE_PIXEL_SIZE) + cell_origin);
	float threshold = BAYER[(cell.y % 4) * 4 + cell.x % 4] / 16.0 + alpha_bias;
	float opacity = source.a >= alpha_floor && source.a > threshold ? 1.0 : 0.0;
	// Skip ramp work for discarded cells.
	COLOR = vec4(0.0);
	if (opacity > 0.0) {
		float luminance = dot(source.rgb / source.a, LUMA);
		vec3 nearest = ramp[0].rgb;
		float distance = abs(luminance - dot(nearest, LUMA));
		for (int i = 1; i < 5; i++) {
			float candidate = abs(luminance - dot(ramp[i].rgb, LUMA));
			if (candidate < distance) {
				distance = candidate;
				nearest = ramp[i].rgb;
			}
		}
		COLOR = vec4(nearest, 1.0);
	}
}
