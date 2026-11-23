shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/ground_surface_patch.gdshaderinc"

uniform sampler2D art_texture : filter_nearest, repeat_disable;
uniform vec4 art_rect;
uniform vec4 dest_rect;
uniform vec4 ramp[5];
uniform int kind;
uniform ivec2 contact_core;
uniform bool reflection;
uniform ivec2 owner_tile;
uniform float reflection_opacity;
varying vec2 ground_point;

void vertex() {
	ground_point = VERTEX;
}

vec2 ice_region(ivec2 tile) {
	ivec2 address = tile - tile_origin;
	return texelFetch(tile_data, ivec2(address.x * 2 + 1, address.y), 0).rg;
}

void fragment() {
	if (reflection) {
		ivec2 cell = ground_cell(ground_point);
		vec2 sample_point = ground_cell_center(cell);
		vec2 point = tile_point(sample_point);
		ivec2 tile = ivec2(floor(point + 0.5));
		vec4 record = tile_record(tile, 0);
		if ((int(record.r) & 3) != ICE || any(notEqual(ice_region(tile), ice_region(owner_tile)))
				|| !patch_visible(point, tile, ICE, int(record.g), cell)) {
			discard;
		}
		vec2 mirrored = vec2(sample_point.x, dest_rect.y * 2.0 - sample_point.y);
		vec2 uv = (mirrored - art_rect.xy) / art_rect.zw;
		if (any(lessThan(uv, vec2(0.0))) || any(greaterThanEqual(uv, vec2(1.0)))) {
			discard;
		}
		vec4 sprite = texture(art_texture, uv);
		COLOR = vec4(sprite.rgb, sprite.a * reflection_opacity);
	} else {
		vec2 point = ground_point - dest_rect.xy;
		vec2 cell = (floor(point / ground_texel) + 0.5) * ground_texel;
		vec2 uv = min(cell / dest_rect.zw, vec2(0.99999));
		ivec2 atlas_point = ivec2(art_rect.xy + floor(uv * art_rect.zw));
		vec4 indexed = texelFetch(art_texture, atlas_point, 0);
		if (indexed.a == 0.0) {
			discard;
		}
		int index = int(round(indexed.r * 4.0));
		if (kind == ICE) {
			index = all(equal(atlas_point, contact_core)) ? 4 : min(index, 3);
		}
		COLOR = vec4(ramp[index].rgb, indexed.a);
	}
}
