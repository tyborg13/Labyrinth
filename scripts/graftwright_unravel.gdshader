shader_type canvas_item;
render_mode unshaded;
// CanvasGroup composites the actual panel, lettering, equipment and raised card
// badges. Erosion and departing fragments therefore carry the same painted art.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
varying vec2 canvas_point;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x),
		mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}
vec4 paint(vec2 uv) {
	vec4 c = textureLod(screen_texture, uv, 0.0);
	if (c.a > 0.0001) c.rgb /= c.a;
	return c;
}
void vertex() {
	canvas_point = VERTEX;
}
void fragment() {
	vec2 p = canvas_point - vec2(470.0, 120.0);
	float field = p.y / 765.0 + (noise(p / vec2(50.0, 27.0)) - 0.5) * 0.09
		+ (noise(p / 8.0) - 0.5) * 0.022;
	float front = mix(-0.09, 1.13, progress);
	float distance_to_front = field - front;
	vec4 original = paint(SCREEN_UV);
	float keep = smoothstep(-0.002, 0.005, distance_to_front);
	float active = smoothstep(0.0, 0.055, progress) * (1.0 - smoothstep(0.88, 1.0, progress));
	float halo = exp(-abs(distance_to_front) * 42.0) * active;
	float core = exp(-abs(distance_to_front) * 245.0) * active;
	vec3 color = original.rgb + vec3(0.37, 0.10, 0.68) * halo + vec3(0.88, 0.63, 1.0) * core;
	float alpha = original.a * keep;
	// Small irregular pieces loft from the moving front. Their birth and drift
	// share one spatial field; no random frame-to-frame speckle or bead trail.
	float seed = noise(p / vec2(19.0, 9.0));
	float age = clamp((front - p.y / 765.0) * 5.0, 0.0, 1.0);
	vec2 drift = vec2((seed - 0.5) * 26.0, -30.0 - seed * 24.0) * age;
	vec4 fragment_paint = paint(SCREEN_UV - drift * SCREEN_PIXEL_SIZE);
	vec2 chip_point = p - drift;
	float chip_mask = smoothstep(0.62, 0.83, noise(vec2(chip_point.x * 0.24 + chip_point.y * 0.05, chip_point.y * 0.075)));
	float release = smoothstep(0.006, 0.025, -distance_to_front) * (1.0 - smoothstep(0.025, 0.12, -distance_to_front));
	float fleck_alpha = fragment_paint.a * chip_mask * release * active * 0.8;
	color = mix(color, fragment_paint.rgb * 0.6 + vec3(0.68, 0.39, 0.92), fleck_alpha / max(alpha + fleck_alpha, 0.0001));
	alpha = max(alpha, fleck_alpha);
	COLOR = vec4(color, alpha);
}
