shader_type canvas_item;
render_mode unshaded, blend_mix;

// ViewportTexture RGB is premultiplied. Compare straight RGB to the sRGB ramp.
uniform vec4 ramp[5];
uniform float alpha_floor;
uniform float alpha_bias;
// Cropped targets keep the original screen-anchored Bayer phase.
uniform vec2 cell_origin;
#include "res://shaders/pixel_fx_cells.gdshaderinc"

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	ivec2 cell = ivec2(floor(UV / TEXTURE_PIXEL_SIZE) + cell_origin);
	float threshold = pixel_fx_bayer(cell) + alpha_bias;
	float opacity = source.a >= alpha_floor && source.a > threshold ? 1.0 : 0.0;
	// Skip ramp work for discarded cells.
	COLOR = vec4(0.0);
	if (opacity > 0.0) {
		COLOR = vec4(pixel_fx_quantize(source.rgb / source.a, ramp), 1.0);
	}
}
