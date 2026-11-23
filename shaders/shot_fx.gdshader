shader_type canvas_item;
render_mode unshaded;

uniform sampler2D atlas : filter_nearest, repeat_disable;
uniform vec4 palette[56] : source_color;
uniform float cell_px = 1.0;
uniform bool warming = true;

// Each item has one retained quad. A chain resolves all of its links in that quad.
instance uniform ivec3 frame_rect; // Atlas x, y and square side in cells.
instance uniform vec4 span; // Board-local second endpoint, link spacing in physical pixels, mode.
instance uniform vec4 clip_line; // Board-local vector per unit of travel, and progress at both ends.
instance uniform bool clip_enabled;
uniform vec2 visible_spans[64];
uniform int visible_span_count;

varying vec2 pixel;
varying flat vec2 anchor;
varying flat vec2 other;
varying flat vec2 clip_delta;

void vertex() {
	mat4 to_canvas = CANVAS_MATRIX * MODEL_MATRIX;
	mat2 basis = mat2(to_canvas[0].xy, to_canvas[1].xy);
	vec2 centre = to_canvas[3].xy;
	anchor = round(centre / cell_px) * cell_px;
	other = round((centre + basis * span.xy) / cell_px) * cell_px;
	clip_delta = basis * clip_line.xy;
	vec2 half_size = vec2(float(frame_rect.z) * cell_px * 0.5);
	vec2 lo = min(anchor, other) - half_size;
	vec2 hi = max(anchor, other) + half_size;
	pixel = mix(lo, hi, VERTEX);
	VERTEX = inverse(basis) * (pixel - centre);
}

int frame_index(vec2 sample_position, vec2 centre, int row_offset) {
	float half_cells = float(frame_rect.z) * 0.5;
	ivec2 cell = ivec2(floor((sample_position - centre) / cell_px + half_cells));
	if (any(lessThan(cell, ivec2(0))) || any(greaterThanEqual(cell, ivec2(frame_rect.z)))) {
		return 0;
	}
	return int(round(texelFetch(atlas, frame_rect.xy + ivec2(0, row_offset * frame_rect.z) + cell, 0).r * 255.0));
}

bool visible_cell(vec2 cell_centre, vec2 centre, float progress) {
	float line_sq = dot(clip_delta, clip_delta);
	if (!clip_enabled) {
		return true;
	}
	if (line_sq <= 0.0) {
		return false;
	}
	float along = progress + dot(cell_centre - centre, clip_delta) / line_sq;
	for (int i = 0; i < visible_span_count; i++) {
		vec2 bounds = visible_spans[i];
		if (along >= bounds.x && along <= bounds.y) {
			return true;
		}
	}
	return false;
}

void fragment() {
	if (warming) {
		COLOR = vec4(0.0);
	} else {
		vec2 cell_centre = (floor(pixel / cell_px) + 0.5) * cell_px;
		int index = 0;
		int mode = int(span.w);
		if (mode == 2) {
			vec2 chain = other - anchor;
			float length_px = length(chain);
			if (length_px > 0.0) {
				vec2 axis = chain / length_px;
				float along = dot(cell_centre - anchor, axis);
				int nearest = int(round(along / span.z));
				// A snapped centre can move into the adjacent link's texel.
				for (int offset = -1; offset <= 1; offset++) {
					int link = nearest + offset;
					float distance_px = float(link) * span.z;
					if (link > 0 && distance_px < length_px) {
						vec2 centre = round((anchor + axis * distance_px) / cell_px) * cell_px;
						float progress = mix(clip_line.z, clip_line.w, distance_px / length_px);
						if (visible_cell(cell_centre, centre, progress)) {
							index = frame_index(cell_centre, centre, link % 2);
							if (index != 0) {
								break;
							}
						}
					}
				}
			}
		} else {
			if (visible_cell(cell_centre, anchor, clip_line.z)) {
				index = frame_index(cell_centre, anchor, 0);
			}
			if (index == 0 && mode == 1 && visible_cell(cell_centre, other, clip_line.w)) {
				index = frame_index(cell_centre, other, 0);
			}
		}
		if (index == 0) {
			discard;
		}
		COLOR = palette[index];
	}
}
