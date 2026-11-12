shader_type canvas_item;
render_mode unshaded;

uniform vec2 half_tile;
uniform float zoom;
uniform float border_width;
uniform float core_white_mix;
uniform float edge_width;
uniform float edge_brightness;
uniform float raise_height;
uniform float drop_rim_width;
uniform float drop_rim_alpha;
uniform float glow_width;
uniform float glow_alpha;
uniform float inner_wash_alpha;
varying vec2 point;

void vertex() { point = VERTEX; }

float diamond_distance(vec2 p) {
	vec2 q = abs(p);
	vec2 edge = vec2(half_tile.x, -half_tile.y);
	vec2 v = q - vec2(0.0, half_tile.y);
	return length(v - edge * clamp(dot(v, edge) / dot(edge, edge), 0.0, 1.0));
}

// Premultiplied accumulation avoids darkening a bright core through its tone
// modulate. Convert once at the end for normal canvas source-over blending.
vec4 ink_over(vec4 back, vec3 ink, float alpha) {
	return vec4(ink * alpha + back.rgb * (1.0 - alpha), alpha + back.a * (1.0 - alpha));
}

void fragment() {
	vec3 tone = COLOR.rgb;
	float opacity = COLOR.a;
	vec2 raised = point + vec2(0.0, raise_height * zoom);
	float distance = diamond_distance(raised);
	float outside = step(1.0, dot(abs(raised), 1.0 / half_tile));
	float signed_distance = distance * (outside * 2.0 - 1.0);
	float aa = max(fwidth(signed_distance), 0.001);
	float half_core = border_width * zoom * 0.5;
	float edge_outer = half_core + edge_width * zoom;
	float core = 1.0 - smoothstep(half_core - aa * 0.5, half_core + aa * 0.5, distance);
	float edge = smoothstep(half_core - aa * 0.5, half_core + aa * 0.5, signed_distance)
		* (1.0 - smoothstep(edge_outer - aa * 0.5, edge_outer + aa * 0.5, signed_distance));
	float glow = glow_alpha * (1.0 - smoothstep(edge_outer, edge_outer + glow_width * zoom, signed_distance))
		* smoothstep(-aa * 0.5, aa * 0.5, signed_distance);
	float wash = inner_wash_alpha * (1.0 - smoothstep(-aa * 0.5, aa * 0.5, signed_distance));
	float rim_distance = diamond_distance(point);
	float rim = drop_rim_alpha * (1.0 - smoothstep(drop_rim_width * zoom * 0.5 - aa * 0.5, drop_rim_width * zoom * 0.5 + aa * 0.5, rim_distance));
	vec4 ink = vec4(vec3(0.0), rim);
	ink = ink_over(ink, tone, wash);
	ink = ink_over(ink, tone, glow);
	ink = ink_over(ink, tone * edge_brightness, edge);
	ink = ink_over(ink, mix(tone, vec3(1.0), core_white_mix), core);
	COLOR = vec4(ink.rgb / max(ink.a, 0.001), ink.a * opacity);
}
