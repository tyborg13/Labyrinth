uniform sampler2D ice_sparkle_texels : filter_nearest, repeat_disable;
uniform vec2 ice_sparkle_timing;
uniform ivec2 ice_sparkle_count_range;

ivec2 ice_sparkle_texel(int offset) {
	int width = textureSize(ice_sparkle_texels, 0).x;
	return ivec2(texelFetch(ice_sparkle_texels, ivec2(offset % width, offset / width), 0).rg);
}

bool ice_sparkles(ivec2 texel, ivec3 motion, ivec2 owner, int slot) {
	if (motion_seconds < 0.0 || motion.y == 0 || mod(motion_seconds, ice_sparkle_timing.x) >= ice_sparkle_timing.y) {
		return false;
	}
	int cycle = int(floor(motion_seconds / ice_sparkle_timing.x));
	uint seed = ground_hash(owner, world_seed ^ slot);
	uint pick = ground_hash(ivec2(cycle, 0), int(seed));
	int span = ice_sparkle_count_range.y - ice_sparkle_count_range.x + 1;
	int count = min(motion.y, ice_sparkle_count_range.x + int(pick % uint(span)));
	// Prefer the candidates that actually brighten when promoted to index 4.
	int first_pool = motion.z > 0 ? motion.z : motion.y;
	int first = int((pick >> 16u) % uint(first_pool));
	if (texel == ice_sparkle_texel(motion.x + first)) {
		return true;
	}
	if (count < 2) {
		return false;
	}
	uint next = ground_hash(ivec2(cycle, 1), int(seed));
	int second_pool = motion.z >= count ? motion.z : motion.y;
	int second = (first + 1 + int(next % uint(second_pool - 1))) % second_pool;
	return texel == ice_sparkle_texel(motion.x + second);
}

int ice_index(int authored, ivec2 texel, ivec3 motion, ivec2 owner, int slot) {
	if (authored >= 3 && ice_sparkles(texel, motion, owner, slot)) {
		return 4;
	}
	return min(authored, 3);
}
