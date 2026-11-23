uniform vec2 electrified_strike_interval_range;
uniform ivec3 electrified_strike_frames;
uniform int electrified_sector_count;
uniform float electrified_sector_chance;
uniform int electrified_rest_core_step;

// Fractional periods preserve the per-instance interval instead of rounding
// it to a whole frame. Both the strike and its first drawn tick are seeded.
ivec2 electrified_phase(vec2 interval, uint seed) {
	float period = mix(interval.x, interval.y, chance(seed)) * float(animation_fps.z);
	float offset = chance(seed >> 16u) * period;
	float tick = float(steps.z);
	float cycle = floor((tick + offset) / period);
	return ivec2(int(cycle), int(tick - ceil(cycle * period - offset)));
}

int electrified_sectors(int available, uint seed, int strike) {
	int selected = 0;
	for (int sector = 0; sector < electrified_sector_count; sector++) {
		int bit = 1 << sector;
		if ((available & bit) != 0 && chance(ground_hash(ivec2(strike, sector), int(seed))) < electrified_sector_chance) {
			selected |= bit;
		}
	}
	if (selected == 0 && available != 0) {
		int start = int(ground_hash(ivec2(strike, -1), int(seed)) % uint(electrified_sector_count));
		for (int i = 0; i < electrified_sector_count; i++) {
			int bit = 1 << ((start + i) % electrified_sector_count);
			if ((available & bit) != 0) {
				return bit;
			}
		}
	}
	return selected;
}

int electrified_index(vec4 texel, int authored, vec2 motion, ivec2 owner, int slot) {
	int distance = int(round(texel.g * 255.0));
	int rest = authored == 4 ? 2 - (electrified_rest_core_step & 1) : min(authored, 1);
	if (steps.z < 0 || animation_fps.z == 0) {
		return rest;
	}
	uint seed = ground_hash(owner, world_seed ^ slot);
	ivec2 phase = electrified_phase(electrified_strike_interval_range, seed);
	int flash_end = electrified_strike_frames.x + electrified_strike_frames.y;
	if (phase.y >= flash_end + electrified_strike_frames.z) {
		return rest;
	}
	if (distance > 0) {
		int sector = int(round(texel.b * 255.0)) >> 5;
		if ((electrified_sectors(int(motion.y), seed, phase.x) & (1 << sector)) == 0) {
			return rest;
		}
	}
	if (phase.y < electrified_strike_frames.x) {
		int front = int(motion.x) * phase.y / max(1, electrified_strike_frames.x - 1);
		if (distance > front) {
			return rest;
		}
		return distance == front ? 4 : max(authored, 2);
	}
	return phase.y < flash_end ? 4 : max(2, 4 - (phase.y - flash_end));
}
