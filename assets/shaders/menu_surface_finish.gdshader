shader_type canvas_item;
render_mode unshaded;

uniform vec2 face_origin;
uniform vec2 face_size;
uniform vec4 radii_x;
uniform vec4 radii_y;
uniform vec4 accent : source_color;
uniform bool outer_face = false;
uniform bool chip_face = false;
uniform bool portrait_face = false;
uniform sampler2D grain : repeat_enable, filter_linear;
varying vec2 face_point;
varying vec4 finish_tint;

void vertex() {
	face_point = VERTEX - face_origin;
	finish_tint = COLOR;
}

// Accumulate premultiplied light, then convert once for canvas alpha blending.
vec4 layer(vec4 under, vec3 color, float alpha) {
	return vec4(color * alpha + under.rgb * (1.0 - alpha), alpha + under.a * (1.0 - alpha));
}

void fragment() {
	vec2 p = face_point;
	vec2 uv = clamp(p / face_size, vec2(0.0), vec2(1.0));
	bool right = p.x > face_size.x * 0.5;
	bool bottom = p.y > face_size.y * 0.5;
	int corner = bottom ? (right ? 2 : 3) : (right ? 1 : 0);
	vec2 radius = vec2(radii_x[corner], radii_y[corner]);
	vec2 edge = vec2(right ? face_size.x - p.x : p.x, bottom ? face_size.y - p.y : p.y);
	float coverage = 1.0;
	if (radius.x > 0.0 && radius.y > 0.0 && edge.x < radius.x && edge.y < radius.y) {
		float distance = (length((edge - radius) / radius) - 1.0) * min(radius.x, radius.y);
		coverage = 1.0 - smoothstep(-0.5, 0.5, distance);
	}
	float crown = outer_face ? 0.15 : (chip_face ? 0.12 : 0.095);
	vec4 surface = layer(vec4(0.0), accent.rgb, crown * (1.0 - uv.y) * mix(1.0, 0.38, uv.x));
	surface = layer(surface, vec3(0.006, 0.010, 0.021), uv.y * mix(0.30, outer_face ? 0.44 : 0.30, uv.x));
	if (!chip_face) {
		vec4 fiber = texture(grain, p / 128.0);
		surface = layer(surface, fiber.rgb, fiber.a * (outer_face ? 0.48 : 0.25));
		float header_height = min(outer_face ? 90.0 : 48.0, face_size.y * 0.35);
		float header = 1.0 - smoothstep(0.0, header_height, p.y);
		surface = layer(surface, accent.rgb, header * mix(0.065, 0.022, uv.x));
	}
	if (portrait_face) {
		float glow = max(0.0, 1.0 - length((uv - vec2(0.39, 0.57)) / vec2(0.35, 0.43)));
		surface = layer(surface, accent.rgb, glow * 0.085);
	}
	float edge_width = min(outer_face ? 24.0 : 12.0, face_size.x * 0.08);
	float side = 1.0 - smoothstep(0.0, edge_width, min(p.x, face_size.x - p.x));
	surface = layer(surface, vec3(0.003, 0.004, 0.008), side * 0.26);
	COLOR = vec4(surface.rgb / max(surface.a, 0.0001), surface.a * coverage) * finish_tint;
}
