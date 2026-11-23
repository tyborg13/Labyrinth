shader_type canvas_item;
render_mode unshaded;

uniform sampler2D atlas : filter_nearest, repeat_disable;
uniform vec4 palette[16] : source_color;
uniform float cell_px;
uniform ivec2 frame_cells;
uniform ivec2 centre_cell;
uniform int frames;
uniform int still_frame;
uniform int tick = -1;

instance uniform ivec4 row_pairs;
instance uniform ivec2 phase_and_switch;

varying vec2 atlas_cell;

void vertex() {
	atlas_cell = VERTEX * vec2(frame_cells);
	mat4 to_canvas = CANVAS_MATRIX * MODEL_MATRIX;
	mat2 basis = mat2(to_canvas[0].xy, to_canvas[1].xy);
	vec2 centre = to_canvas[3].xy;
	// Snap after the canvas transform, including board kick and camera travel.
	VERTEX = inverse(basis) * (round(centre) - centre + (atlas_cell - vec2(centre_cell)) * cell_px);
}

int palette_index(ivec2 cell, int row) {
	if (row < 0) {
		return 0;
	}
	return int(round(texelFetch(atlas, cell + ivec2(0, row * frame_cells.y), 0).r * 255.0));
}

void fragment() {
	int frame = tick < 0 ? still_frame : (tick + phase_and_switch.x) % frames;
	ivec2 rows = tick >= 0 && tick < phase_and_switch.y ? row_pairs.xy : row_pairs.zw;
	ivec2 cell = clamp(ivec2(floor(atlas_cell)), ivec2(0), frame_cells - 1);
	cell.x += frame * frame_cells.x;
	// An occupied Lightning texel covers Fire on the same painter pass.
	int index = palette_index(cell, rows.y);
	if (index == 0) {
		index = palette_index(cell, rows.x);
	}
	if (index == 0) {
		discard;
	}
	COLOR = palette[index];
}
