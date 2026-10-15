shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 ramp[5];
uniform float alpha_floor;
uniform float alpha_bias;
// Probe-only masks read the GPU's actual rasterization, never CPU cell lists.
uniform int proof_pass = 0; // 0: normal, 1: core coverage, 2: halo coverage
varying vec2 cell_position;
const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
const vec3 LUMA = vec3(0.299, 0.587, 0.114);

void vertex() {
	// Before the cropped viewport transform: Bayer stays screen-cell anchored.
	cell_position = VERTEX;
}

void fragment() {
	// Only this line canvas uses the reserved band. Halos encode alpha in
	// [0, 0.5]; opaque cores use 1 after the authored alpha passes the floor.
	bool core = COLOR.a > 0.75;
	float alpha = core ? 1.0 : COLOR.a * 2.0;
	ivec2 cell = ivec2(mod(floor(cell_position), vec2(4.0)));
	float threshold = BAYER[cell.y * 4 + cell.x] / 16.0 + alpha_bias;
	if ((proof_pass == 1 && !core) || (proof_pass == 2 && core)) {
		discard;
	}
	if (!core && (alpha < alpha_floor || (proof_pass != 2 && alpha <= threshold))) {
		discard;
	}
	float luminance = dot(COLOR.rgb, LUMA);
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
