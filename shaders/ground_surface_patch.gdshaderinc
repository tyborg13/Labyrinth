#include "res://shaders/pixel_fx_cells.gdshaderinc"
#include "res://shaders/ground_surface_geometry.gdshaderinc"

uniform sampler2D shape_data : filter_nearest, repeat_disable;
uniform vec2 tile_at_origin;
uniform vec2 tile_per_x;
uniform vec2 tile_per_y;
uniform vec2 ground_origin;
uniform float ground_texel;
uniform float edge_fringe;
uniform float edge_amplitude;
uniform float edge_lobes;

ivec2 ground_cell(vec2 point) {
	return ivec2(floor((point - ground_origin) / ground_texel));
}

vec2 ground_cell_center(ivec2 cell) {
	return ground_origin + (vec2(cell) + 0.5) * ground_texel;
}

vec2 tile_point(vec2 point) {
	return tile_at_origin + tile_per_x * point.x + tile_per_y * point.y;
}

// The hash selects the phase of a smooth wave along each exposed world
// side. Adjacent tiles continue the same low-frequency contour.
float exterior_wave(float tangent, float side, int salt) {
	float phase = chance(ground_hash(ivec2(int(round(side * 2.0)), world_seed), salt));
	return sin(TAU * (tangent * edge_lobes + phase)) * edge_amplitude;
}

float curved_edge(vec2 point, ivec2 tile, int neighbors, float inset) {
	vec2 local = point - vec2(tile);
	vec2 edge = 0.5 - abs(local);
	int x_dir = local.x < 0.0 ? 0 : 1;
	int y_dir = local.y < 0.0 ? 2 : 3;
	bool x_open = !connected(neighbors, x_dir);
	bool y_open = !connected(neighbors, y_dir);
	vec2 corner = mix(vec2(-0.5), vec2(0.5), step(vec2(0.0), local));
	float units_per_texel = length(vec2(tile_per_x.x, tile_per_y.x)) * ground_texel;
	// The wave has clearance at its crest without clamping a stretch of
	// the contour back onto the original tile edge.
	float center_inset = max(inset / units_per_texel, edge_amplitude + edge_fringe * 0.25);
	vec2 distance = edge / units_per_texel - center_inset;
	if (x_open) {
		distance.x += exterior_wave(point.y, float(tile.x) + corner.x, 19);
	}
	if (y_open) {
		distance.y += exterior_wave(point.x, float(tile.y) + corner.y, 41);
	}
	float signed_distance = min(x_open ? distance.x : 1e6, y_open ? distance.y : 1e6);
	if (x_open && y_open) {
		float radius = edge_amplitude + edge_fringe;
		vec2 curve = max(vec2(radius) - distance, vec2(0.0));
		signed_distance = min(signed_distance, radius - length(curve));
	} else if (!x_open && !y_open && !connected(neighbors, 4 + (y_dir - 2) * 2 + x_dir)) {
		mat2 tile_to_board = inverse(mat2(tile_per_x, tile_per_y));
		signed_distance = length(tile_to_board * (local - corner)) / ground_texel - center_inset;
	}
	return clamp(signed_distance / edge_fringe + 0.5, 0.0, 1.0);
}

bool patch_visible(vec2 point, ivec2 tile, int kind, int neighbors, ivec2 cell) {
	vec4 insets = texelFetch(shape_data, tile - tile_origin, 0);
	return curved_edge(point, tile, neighbors, insets[kind - 1]) > pixel_fx_bayer(cell);
}
