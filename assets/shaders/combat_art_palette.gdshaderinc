// Shared by living art and the surviving painted portion of a death dissolve.
// No screen texture, normal map, HDR switch, or per-frame CPU image processing.
uniform float art_strength : hint_range(0.0, 1.0) = 1.0;
uniform int art_light_count = 0;
uniform vec4 art_lights[24]; // board-local ground xy, radius, light height
uniform vec4 art_light_colors[24];
uniform vec3 art_ambient = vec3(0.985, 0.985, 1.01);

vec3 art_grade(vec3 rgb, float profile) {
	float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	float saturation = profile < 2.5 ? 0.90 : 0.92;
	float exposure = profile < 1.5 ? 0.96 : (profile < 2.5 ? 0.94 : 0.98);
	if (profile > 5.5) { saturation = 0.99; exposure = 1.0; }
	vec3 matched = mix(vec3(luma), rgb, saturation);
	// Match black levels gently; retain painted highlights and emissive identity.
	matched = max(vec3(0.0), (matched - 0.20) * 0.97 + 0.20) * exposure;
	vec3 split_tone = mix(vec3(0.96, 0.98, 1.025), vec3(1.035, 1.012, 0.975), smoothstep(0.10, 0.78, luma));
	return matched * split_tone * art_ambient;
}

vec3 art_illumination(vec2 point, float profile, out vec2 direction, out float edge_energy) {
	vec3 light = vec3(0.0);
	direction = normalize(vec2(-1.0, -0.55));
	edge_energy = 0.06;
	for (int i = 0; i < art_light_count; i++) {
		vec2 origin = art_lights[i].xy;
		if (profile > 1.5) { origin.y -= art_lights[i].w; }
		vec2 delta = origin - point;
		vec2 elliptical = delta * vec2(1.0, profile < 1.5 ? 1.7 : 1.0);
		float radius = max(art_lights[i].z, 1.0);
		float distance_squared = dot(elliptical, elliptical) / (radius * radius);
		if (distance_squared < 1.0) {
			float weight = pow(1.0 - sqrt(distance_squared), 2.0) * art_light_colors[i].a;
			light += art_light_colors[i].rgb * weight;
			if (weight > edge_energy) {
				edge_energy = weight;
				direction = delta / max(length(delta), 0.001);
			}
		}
	}
	return min(light, vec3(0.85));
}

vec3 art_finish(vec3 rgb, float profile, vec3 light) {
	vec3 graded = art_grade(rgb, profile);
	// A diffuse wash retains texture contrast instead of laying an opaque halo
	// over the sprite. Bright emissive pixels keep their authored light.
	float receive = profile > 5.5 ? 0.18 : 1.0;
	vec3 lit = graded * (vec3(1.0) + light * 0.30 * receive) + sqrt(max(graded, vec3(0.0))) * light * 0.055 * receive;
	return mix(rgb, clamp(lit, vec3(0.0), vec3(1.0)), art_strength);
}
