shader_type canvas_item;
uniform vec4 openings[32];
uniform int opening_count = 0;
uniform float motion = 0.0;
float noise(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float cloud(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(noise(i), noise(i + vec2(1.0, 0.0)), f.x), mix(noise(i + vec2(0.0, 1.0)), noise(i + vec2(1.0)), f.x), f.y);
}
void fragment() {
	float n = cloud(UV * vec2(15.0, 9.0) + TIME * motion * 0.015);
	n = n * 0.65 + cloud(UV * vec2(39.0, 23.0)) * 0.35;
	float concealment = 1.0;
	for (int i = 0; i < opening_count; i++) {
		vec4 opening = openings[i];
		float d = length((UV - opening.xy) / opening.zw);
		concealment = min(concealment, smoothstep(0.65, 1.35, d + (n - 0.5) * 0.3));
	}
	COLOR = vec4(mix(vec3(0.018, 0.012, 0.030), vec3(0.070, 0.042, 0.115), n), concealment * 0.985);
}
