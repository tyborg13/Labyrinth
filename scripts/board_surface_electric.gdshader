shader_type canvas_item;
render_mode unshaded;

// Retained topology; the board supplies the presentation clock. No TIME,
// procedural noise or per-frame random state is used here.
uniform vec4 endpoints[18];
uniform float angles[18];
uniform float intensities[6];
uniform float tile_width = 100.0;

vec2 path_point(int bolt, float k) {
	vec2 a = endpoints[bolt].xy;
	vec2 b = endpoints[bolt].zw;
	float u = k / 12.0;
	vec2 direction = normalize(b - a);
	vec2 normal = vec2(-direction.y, direction.x);
	float jag = sin(k * 7.3 + angles[bolt]) * sin(u * PI);
	return mix(a, b, u) + normal * jag * length(b - a) * 0.075;
}

vec2 core_miter(vec2 previous, vec2 following) {
	vec2 bisector = normalize(previous - following);
	float sine = sin(atan(bisector.x * previous.y - bisector.y * previous.x, dot(bisector, previous)));
	if (abs(sine) < 0.00001 || distance(previous, following) < 0.00001) {
		return vec2(following.y, -following.x);
	}
	return bisector * clamp(1.0 / sine, -3.0, 3.0);
}

void vertex() {
	int bolt = int(UV.x + 0.5);
	int branch = bolt % 3;
	float k = VERTEX.x;
	float side = VERTEX.y;
	float width_factor = branch == 0 ? 0.013 : (branch == 1 ? 0.008 : 0.005);
	float ribbon_width = tile_width * width_factor;
	vec2 at = path_point(bolt, k);
	vec2 before = path_point(bolt, max(0.0, k - 1.0));
	vec2 after = path_point(bolt, min(12.0, k + 1.0));
	vec3 tint = branch == 0 ? vec3(0.60, 0.47, 1.0) : (branch == 1 ? vec3(0.67, 0.55, 1.0) : vec3(0.74, 0.68, 1.0));
	float alpha = intensities[bolt / 3] * (branch == 0 ? 1.0 : (branch == 1 ? 0.73 : 0.52));
	if (UV.y < 0.5) {
		vec2 tangent = normalize(after - before);
		float taper = pow(max(0.0, sin(k / 12.0 * PI)), 0.6);
		VERTEX = at + vec2(-tangent.y, tangent.x) * ribbon_width * taper * side;
	} else {
		vec2 following = normalize(k < 12.0 ? after - at : at - before);
		vec2 previous = normalize(k > 0.0 ? at - before : after - at);
		vec2 miter = k == 0.0 || k == 12.0 ? vec2(following.y, -following.x) : core_miter(previous, following);
		float hot_width = max(0.7, ribbon_width * 0.13);
		float border = 1.25 * min(1.0, hot_width);
		float cap = round(COLOR.g * 2.0 - 1.0);
		VERTEX = at + miter * side * (hot_width * 0.5 + COLOR.b * border) + following * cap * border;
		tint = mix(tint, vec3(1.0), 0.72);
		alpha *= 0.72;
	}
	COLOR = vec4(tint, alpha * COLOR.r);
}

void fragment() {
	// The mesh is untextured. UV carries bolt identity, not a sprite lookup.
	COLOR = COLOR;
}
