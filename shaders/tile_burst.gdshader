shader_type canvas_item;
render_mode unshaded;

uniform sampler2D atlas : filter_nearest, repeat_disable;
uniform vec4 palette[64] : source_color;
uniform ivec2 frame_cells;
uniform ivec2 centre_cell;
uniform float cell_px;

instance uniform ivec3 frame_row_mirror;
varying highp vec2 atlas_cell;

void vertex() {
	atlas_cell = VERTEX * vec2(frame_cells);
	mat4 to_canvas = CANVAS_MATRIX * MODEL_MATRIX;
	mat2 basis = mat2(to_canvas[0].xy, to_canvas[1].xy);
	vec2 centre = to_canvas[3].xy;
	vec2 offset = (atlas_cell - vec2(centre_cell)) * cell_px;
	offset.x *= frame_row_mirror.z == 0 ? 1.0 : -1.0;
	VERTEX = inverse(basis) * (round(centre) - centre + offset);
}

void fragment() {
	ivec2 cell = clamp(ivec2(floor(atlas_cell)), ivec2(0), frame_cells - 1);
	cell += frame_row_mirror.xy * frame_cells;
	int index = int(round(texelFetch(atlas, cell, 0).r * 255.0));
	if (index == 0) {
		discard;
	}
	COLOR = palette[index];
}
