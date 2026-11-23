shader_type canvas_item;
render_mode unshaded;

uniform sampler2D atlas : filter_nearest, repeat_disable;
uniform vec4 palette[6] : source_color;
uniform int radius_cells;
uniform float cell_px;

instance uniform int frame;
varying highp vec2 atlas_cell;

void vertex() {
	atlas_cell = VERTEX * float(radius_cells) + vec2(float(radius_cells));
	mat4 to_canvas = CANVAS_MATRIX * MODEL_MATRIX;
	mat2 basis = mat2(to_canvas[0].xy, to_canvas[1].xy);
	vec2 centre = to_canvas[3].xy;
	VERTEX = inverse(basis) * (round(centre) - centre + VERTEX * float(radius_cells) * cell_px);
}

void fragment() {
	int side = 2 * radius_cells;
	ivec2 cell = clamp(ivec2(floor(atlas_cell)), ivec2(0), ivec2(side - 1));
	cell.x += frame * side;
	int index = int(round(texelFetch(atlas, cell, 0).r * 255.0));
	if (index == 0) {
		discard;
	}
	COLOR = palette[index];
}
