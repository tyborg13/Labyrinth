const int FIRE = 1;
const int ICE = 2;
const int ELECTRIFIED = 3;
const int RUBBLE = 4;
const int STORMCOAL = 8;

uniform sampler2D tile_data : filter_nearest, repeat_disable;
uniform ivec2 tile_origin;
uniform ivec2 tile_size;
uniform ivec2 cell_origin;
uniform vec2 board_origin;
uniform vec2 board_dx;
uniform vec2 board_dy;
uniform vec2 tile_dx;
uniform vec2 tile_dy;
uniform float world_zoom;
uniform ivec3 animation_fps;
uniform ivec3 steps;
uniform int world_seed;
uniform vec2 edge_inset_cells;
uniform float edge_fringe_cells;

uint ground_hash(ivec2 key, int salt) {
	uint bits = uint(key.x) * 0x8da6b343u ^ uint(key.y) * 0xd8163841u ^ uint(salt) * 0xcb1ab31fu;
	bits ^= bits >> 16u;
	bits *= 0x7feb352du;
	bits ^= bits >> 15u;
	bits *= 0x846ca68bu;
	return bits ^ (bits >> 16u);
}

float chance(uint bits) {
	return float(bits & 0xffffu) / 65536.0;
}

vec4 tile_record(ivec2 tile, int column) {
	ivec2 address = tile - tile_origin;
	if (any(lessThan(address, ivec2(0))) || any(greaterThanEqual(address, tile_size))) {
		return vec4(0.0);
	}
	return texelFetch(tile_data, ivec2(address.x * 2 + column, address.y), 0);
}

bool connected(int mask, int direction) {
	return (mask & (1 << direction)) != 0;
}

struct GroundCell {
	vec2 board;
	ivec2 tile;
	mat2 to_cells;
	vec2 board_units_per_cell;
	ivec2 world_key;
	float bayer;
};

GroundCell sample_ground(vec2 screen_cell) {
	GroundCell cell;
	cell.board = board_origin + board_dx * (screen_cell.x + 0.5) + board_dy * (screen_cell.y + 0.5);
	cell.tile = ivec2(floor(cell.board + 0.5));
	cell.to_cells = mat2(tile_dx, tile_dy);
	cell.board_units_per_cell = vec2(length(vec2(board_dx.x, board_dy.x)), length(vec2(board_dx.y, board_dy.y)));
	// The phase of procedural grain follows the board. The Bayer phase below
	// follows the screen, even across viewport crops and fractional camera pan.
	cell.world_key = ivec2(floor((cell.to_cells * cell.board) / world_zoom));
	cell.bayer = pixel_fx_bayer(ivec2(screen_cell) + cell_origin);
	return cell;
}

float patch_edge(GroundCell cell, int mask) {
	vec2 local = cell.board - vec2(cell.tile);
	vec2 near_edge = (0.5 - abs(local)) / cell.board_units_per_cell;
	// Distances only to the exterior of the union. Where two neighbors
	// touch a missing diagonal, the outside boundary starts at the corner.
	int x_dir = local.x < 0.0 ? 0 : 1;
	int y_dir = local.y < 0.0 ? 2 : 3;
	bool x_open = !connected(mask, x_dir);
	bool y_open = !connected(mask, y_dir);
	float distance_to_edge = 1e6;
	if (x_open) {
		distance_to_edge = near_edge.x;
	}
	if (y_open) {
		distance_to_edge = min(distance_to_edge, near_edge.y);
	}
	float fringe_end = edge_inset_cells.y + edge_fringe_cells;
	if (all(lessThanEqual(near_edge, vec2(fringe_end))) && !x_open && !y_open &&
			!connected(mask, 4 + (y_dir - 2) * 2 + x_dir)) {
		vec2 corner = vec2(x_dir == 0 ? -0.5 : 0.5, y_dir == 2 ? -0.5 : 0.5);
		distance_to_edge = min(distance_to_edge, length(cell.to_cells * (local - corner)));
	}
	if (distance_to_edge >= fringe_end) {
		return 1.0;
	}
	float irregular = chance(ground_hash(cell.world_key, 19));
	float inset = mix(edge_inset_cells.x, edge_inset_cells.y, irregular);
	return clamp((distance_to_edge - inset) / edge_fringe_cells, 0.0, 1.0);
}
