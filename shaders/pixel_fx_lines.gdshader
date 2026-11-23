shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 ramp[5];
uniform float alpha_floor;
uniform float alpha_bias;
// Probe-only masks read the GPU's actual rasterization, never CPU cell lists.
uniform int proof_pass = 0; // 0: normal, 1: core coverage, 2: halo coverage
varying vec2 cell_position;
#include "res://shaders/pixel_fx_cells.gdshaderinc"

void vertex() {
	// Before the cropped viewport transform: Bayer stays screen-cell anchored.
	cell_position = VERTEX;
}

void fragment() {
	// Only this line canvas uses the reserved band. Halos encode alpha in
	// [0, 0.5]; opaque cores use 1 after the authored alpha passes the floor.
	bool core = COLOR.a > 0.75;
	float alpha = core ? 1.0 : COLOR.a * 2.0;
	ivec2 cell = ivec2(floor(cell_position));
	float threshold = pixel_fx_bayer(cell) + alpha_bias;
	if ((proof_pass == 1 && !core) || (proof_pass == 2 && core)) {
		discard;
	}
	if (!core && (alpha < alpha_floor || (proof_pass != 2 && alpha <= threshold))) {
		discard;
	}
	COLOR = vec4(pixel_fx_quantize(COLOR.rgb, ramp), 1.0);
}
