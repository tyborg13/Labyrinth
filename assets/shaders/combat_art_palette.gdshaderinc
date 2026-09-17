// Shared by living art and the surviving painted portion of a death dissolve.
// No screen texture, normal map, HDR switch, or per-frame CPU image processing.
uniform float art_strength : hint_range(0.0, 1.0) = 1.0;
uniform int art_light_count = 0;
uniform vec4 art_lights[24]; // board-local ground xy, radius, light height
uniform vec4 art_light_colors[24];
uniform vec3 art_ambient = vec3(0.985, 0.985, 1.01);
// Warm fallback values; live materials are configured from CombatLightingProfiles.
uniform float art_ambient_level = 0.88;
uniform float art_gain_level = 0.38;
uniform float art_local_budget_level = 0.70;
uniform float art_reach_level = 1.0;
uniform float art_contrast_level = 1.05;
uniform float art_saturation_level = 0.92;
uniform float art_rim_level = 1.0;
uniform vec3 art_look_tint = vec3(1.015, 0.985, 0.95);
uniform float art_light_flicker[24];

bool art_emissive(float profile) { return profile > 5.5 && profile < 6.5; }
bool art_ground(float profile) { return profile < 1.5 || profile > 6.5; }

vec3 art_grade(vec3 rgb, float profile) {
	float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	float saturation = art_saturation_level * (profile < 2.5 ? 0.97 : 1.0);
	float exposure = profile < 1.5 ? 0.96 : (profile < 2.5 ? 0.94 : 0.98);
	if (art_emissive(profile)) { saturation = 0.99; exposure = 1.0; }
	vec3 matched = mix(vec3(luma), rgb, saturation);
	// Match black levels gently; retain painted highlights and emissive identity.
	matched = max(vec3(0.0), (matched - 0.18) * art_contrast_level + 0.18) * exposure;
	vec3 split_tone = mix(vec3(0.96, 0.98, 1.025), vec3(1.035, 1.012, 0.975), smoothstep(0.10, 0.78, luma));
	return matched * split_tone * art_ambient * (art_emissive(profile) ? vec3(1.0) : art_look_tint);
}

vec3 art_illumination_sample(vec2 point, float profile, bool animated, out vec2 direction, out float edge_energy) {
	vec3 light = vec3(0.0);
	float total_weight = 0.0;
	direction = vec2(-0.06, -0.033);
	edge_energy = 0.06;
	for (int i = 0; i < art_light_count; i++) {
		vec2 origin = art_lights[i].xy;
		if (!art_ground(profile)) { origin.y -= art_lights[i].w; }
		vec2 delta = origin - point;
		vec2 elliptical = delta * vec2(1.0, art_ground(profile) ? 1.7 : 1.0);
		float radius = max(art_lights[i].z * art_reach_level, 1.0);
		float distance_squared = dot(elliptical, elliptical) / (radius * radius);
		if (distance_squared < 1.0) {
			float weight = pow(1.0 - sqrt(distance_squared), 1.6) * art_light_colors[i].a * (animated ? art_light_flicker[i] : 1.0);
			light += art_light_colors[i].rgb * weight;
			total_weight += weight;
			edge_energy = max(edge_energy, weight);
			direction += delta / max(length(delta), 0.001) * weight;
		}
	}
	direction /= max(length(direction), 0.001);
	// Saturate local energy smoothly, preserving the weighted light hue.
	// Unlike per-channel clipping this cannot turn many orange sources white;
	// unlike dividing by source count, distant torches do not dim a nearby one.
	float budget = max(art_local_budget_level, 0.001);
	return light * budget / (budget + total_weight);
}

vec3 art_illumination(vec2 point, float profile, out vec2 direction, out float edge_energy) {
	return art_illumination_sample(point, profile, true, direction, edge_energy);
}

vec3 art_finish(vec3 rgb, float profile, vec3 light) {
	vec3 graded = art_grade(rgb, profile);
	// A diffuse wash retains texture contrast instead of laying an opaque halo
	// over the sprite. Bright emissive pixels keep their authored light.
	float receive = art_emissive(profile) ? 0.18 : 1.0;
	float ambient = art_emissive(profile) ? 1.0 : art_ambient_level;
	// Keep actor detail and semantic floor symbols readable in the deepest look.
	if (profile > 3.5 && profile < 5.5) { ambient = max(ambient, 0.48); }
	if (profile > 6.5) { ambient = max(ambient, 0.70); receive = 0.60; }
	vec3 lit = graded * (vec3(ambient) + light * art_gain_level * receive) + sqrt(max(graded, vec3(0.0))) * light * 0.055 * receive;
	// A soft shoulder preserves painted texture in bright torch-facing stone.
	if (!art_emissive(profile)) { lit /= vec3(1.0) + max(lit - vec3(0.82), vec3(0.0)) * 0.65; }
	return mix(rgb, clamp(lit, vec3(0.0), vec3(1.0)), art_strength);
}
