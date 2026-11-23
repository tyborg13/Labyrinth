shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/ground_surface_patch.gdshaderinc"
#include "res://shaders/ground_surface_electrified.gdshaderinc"

uniform vec2 floor_origin;
uniform vec2 decal_dx;
uniform vec2 decal_dy;
uniform float atlas_texel;
uniform vec4 fire_ramp[5];
uniform vec4 ice_ramp[5];
uniform vec4 electrified_ramp[5];
uniform vec4 rubble_ramp[5];
uniform bool proof_outline;
uniform float motion_seconds = -1.0;
uniform float fire_scroll_step;
uniform vec2 electric_pulse;
uniform vec2 ice_glint;
varying vec2 ground_point;
// Use the lower half of the region's 70–95 luminance range for the patch.
// The arc cores and glow supply the brighter part of the region.
const vec2 ELECTRIFIED_PATCH_LUMA = vec2(70.0, 82.5) / 255.0;

void vertex() {
	ground_point = VERTEX + floor_origin;
}

#include "res://shaders/ground_surface_ice.gdshaderinc"
#include "res://shaders/ground_surface_decals.gdshaderinc"

vec4 palette_color(ivec2 ink) {
	if (ink.x == FIRE) {
		return fire_ramp[ink.y];
	}
	if (ink.x == ICE) {
		return ice_ramp[ink.y];
	}
	if (ink.x == ELECTRIFIED) {
		vec3 tone = electrified_ramp[1].rgb;
		float value = dot(tone, vec3(0.299, 0.587, 0.114));
		float authored = float(ink.y) / 4.0;
		float patch_luma = mix(ELECTRIFIED_PATCH_LUMA.x, ELECTRIFIED_PATCH_LUMA.y, authored);
		if (motion_seconds >= 0.0) {
			patch_luma *= 1.0 + electric_pulse.y * sin(TAU * motion_seconds / electric_pulse.x);
		}
		return vec4(tone * (patch_luma / value), 1.0);
	}
	return rubble_ramp[ink.y];
}

bool ice_edge_glint(ivec2 tile, int neighbors, ivec2 cell) {
	float age = mod(max(motion_seconds, 0.0), ice_glint.x);
	// The region's lexicographically first tile owns its exposed left rim.
	// Trace the same authored mask curve the floor uses, on the inner lip.
	if (motion_seconds < 0.0 || age >= ice_glint.y || connected(neighbors, 0)
			|| any(notEqual(ivec2(tile_record(tile, 1).rg), tile))) {
		return false;
	}
	mat2 to_tile = mat2(tile_per_x, tile_per_y);
	float units_per_texel = length(vec2(tile_per_x.x, tile_per_y.x)) * ground_texel;
	float inset = max(texelFetch(shape_data, tile - tile_origin, 0).g / units_per_texel,
		edge_amplitude + edge_fringe * 0.25);
	float margin = (inset + edge_amplitude + edge_fringe * 2.0) * units_per_texel;
	float tangent = float(tile.y) + mix(-0.5 + margin, 0.5 - margin, age / ice_glint.y);
	float normal = float(tile.x) - 0.5;
	float wave = exterior_wave(tangent, normal, 19);
	vec2 rim = vec2(normal + (inset + edge_fringe - wave) * units_per_texel, tangent);
	vec2 board_point = inverse(to_tile) * (rim - tile_at_origin);
	return all(equal(cell, ground_cell(board_point)));
}

void fragment() {
	ivec2 outline_cell = ground_cell(ground_point);
	vec2 point = tile_point(ground_cell_center(outline_cell));
	ivec2 tile = ivec2(floor(point + 0.5));
	vec4 record = tile_record(tile, 0);
	int flags = int(record.r);
	int element = flags & 3;
	bool elemental = element != 0 && patch_visible(point, tile, element, int(record.g), outline_cell);
	bool rubble = (flags & RUBBLE) != 0 && patch_visible(point, tile, RUBBLE, int(record.b), outline_cell);
	if (!elemental && !rubble) {
		discard;
	}
	if (proof_outline) {
		COLOR = vec4(1.0);
	} else if (elemental && element == ICE && ice_edge_glint(tile, int(record.g), outline_cell)) {
		COLOR = ice_ramp[4];
	} else {
		ivec2 atlas_cell = ivec2(floor(FRAGCOORD.xy / atlas_texel));
		vec2 step = (vec2(atlas_cell) + 0.5) * atlas_texel - FRAGCOORD.xy;
		mat2 to_cells = mat2(decal_dx, decal_dy);
		GroundCell sample_cell;
		sample_cell.board = tile_point(ground_point) + inverse(to_cells) * (step / atlas_texel);
		sample_cell.tile = tile;
		sample_cell.to_cells = to_cells;
		sample_cell.bayer = pixel_fx_bayer(atlas_cell);
		int visible_flags = (elemental ? element : 0) | (rubble ? RUBBLE : 0);
		ivec2 ink = ground_decal(sample_cell, visible_flags);
		if (ink.x == ELECTRIFIED && rubble) {
			ivec2 stone = ground_decal(sample_cell, RUBBLE);
			ink = stone.y >= 0 ? stone : ink;
		}
		if (ink.y < 0) {
			discard;
		}
		COLOR = palette_color(ink);
	}
}
