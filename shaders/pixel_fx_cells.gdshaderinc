// Shared screen-space coverage and ramp quantization for elemental pixels.
const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);
const vec3 LUMA = vec3(0.299, 0.587, 0.114);

float pixel_fx_bayer(ivec2 cell) {
	return BAYER[(cell.y & 3) * 4 + (cell.x & 3)] / 16.0;
}

vec3 pixel_fx_quantize(vec3 color, vec4 colors[5]) {
	float luminance = dot(color, LUMA);
	vec3 nearest = colors[0].rgb;
	float distance = abs(luminance - dot(nearest, LUMA));
	for (int i = 1; i < 5; i++) {
		float candidate = abs(luminance - dot(colors[i].rgb, LUMA));
		if (candidate < distance) {
			distance = candidate;
			nearest = colors[i].rgb;
		}
	}
	return nearest;
}
