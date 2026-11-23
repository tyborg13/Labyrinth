uniform sampler2D decal_data : filter_nearest, repeat_disable;
uniform sampler2D fire_atlas : filter_nearest, repeat_disable;
uniform sampler2D ice_atlas : filter_nearest, repeat_disable;
uniform sampler2D electrified_atlas : filter_nearest, repeat_disable;
uniform sampler2D rubble_atlas : filter_nearest, repeat_disable;
uniform int fire_cycle_span;
vec4 decal_record(int address) {
	int width = textureSize(decal_data, 0).x;
	return texelFetch(decal_data, ivec2(address % width, address / width), 0);
}


ivec2 ground_decal(GroundCell cell, int tile_flags) {
	ivec2 address = cell.tile - tile_origin;
	vec4 bin = decal_record(address.y * tile_size.x + address.x);
	// Bins are in painter's order. Find the frontmost opaque texel;
	// transparent texels leave the rest of the stack available.
	for (int i = int(bin.y) - 1; i >= 0; i--) {
		int placement = int(decal_record(int(bin.x) + i).r);
		vec4 anchor = decal_record(placement);
		int kind = int(anchor.z);
		bool visible = kind == RUBBLE ? (tile_flags & RUBBLE) != 0 : (tile_flags & 3) == kind;
		if (!visible) {
			continue;
		}
		ivec4 rect = ivec4(decal_record(placement + 1));
		ivec2 p = ivec2(floor(cell.to_cells * (cell.board - anchor.xy))) + rect.zw / 2;
		if (any(lessThan(p, ivec2(0))) || any(greaterThanEqual(p, rect.zw))) {
			continue;
		}
		ivec2 texel = rect.xy + p;
		vec4 sample_value;
		if (kind == FIRE) {
			sample_value = texelFetch(fire_atlas, texel, 0);
		} else if (kind == ICE) {
			sample_value = texelFetch(ice_atlas, texel, 0);
		} else if (kind == ELECTRIFIED) {
			sample_value = texelFetch(electrified_atlas, texel, 0);
		} else {
			sample_value = texelFetch(rubble_atlas, texel, 0);
		}
		if (sample_value.a == 0.0) {
			continue;
		}
		int index = int(round(sample_value.r * 4.0));
		ivec2 owner = ivec2(floor(anchor.xy + 0.5));
		int slot = int(anchor.w);
		if (kind == FIRE && index >= 2 && fire_cycle_span > 0) {
			int scroll = motion_seconds >= 0.0 ? int(floor(motion_seconds / fire_scroll_step)) : 0;
			uint phase = ground_hash(p - ivec2(scroll, 0), int(ground_hash(owner, world_seed ^ slot)));
			int period = fire_cycle_span + 1;
			int lift = (steps.x + int(phase % uint(period))) % period;
			index = 2 + (index - 2 + lift) % 3;
		} else if (kind == ICE) {
			index = ice_index(index, texel, ivec3(decal_record(placement + 2).xyz), owner, slot);
		} else if (kind == ELECTRIFIED) {
			index = electrified_index(sample_value, index, decal_record(placement + 2).xy, owner, slot);
		}
		return ivec2(kind, index);
	}
	return ivec2(0, -1);
}
