shader_type canvas_item;
render_mode unshaded, blend_mix;

varying vec2 cell_position;
#include "res://shaders/pixel_fx_cells.gdshaderinc"

void vertex() {
	cell_position = VERTEX;
}

void fragment() {
	// The direct painter supplies exact ramp colours. Fractional input
	// alpha encodes smear coverage and is never blended onto the board.
	if (COLOR.a < 1.0 && COLOR.a <= pixel_fx_bayer(ivec2(floor(cell_position)))) {
		discard;
	}
	COLOR.a = 1.0;
}
