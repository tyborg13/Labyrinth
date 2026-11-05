shader_type canvas_item;
render_mode unshaded;

// The texture is the complete card canvas, including raised badges and text.
uniform vec2 card_origin;
uniform vec2 card_size;
uniform vec2 seed;
uniform float threshold : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform vec4 warm_white : source_color;
uniform vec4 amber : source_color;
uniform vec4 ember_red : source_color;
uniform vec4 char_color : source_color;

float lattice(ivec2 cell) {
	uint h = uint(cell.x) * 374761393u + uint(cell.y) * 668265263u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h = h ^ (h >> 16u);
	return float(h & 65535u) / 65535.0;
}

float value_noise(vec2 point) {
	ivec2 cell = ivec2(floor(point));
	vec2 f = fract(point);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(lattice(cell), lattice(cell + ivec2(1, 0)), f.x),
		mix(lattice(cell + ivec2(0, 1)), lattice(cell + ivec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec4 paint = texture(TEXTURE, UV);
	// ViewportTexture stores premultiplied RGB; restore the card's paint
	// before the ordinary canvas blend, including antialiased text/edges.
	if (paint.a > 0.0) paint.rgb /= paint.a;
	paint.a *= opacity;
	vec2 uv = (UV / TEXTURE_PIXEL_SIZE - card_origin) / card_size;
	float burn_field = 0.65 * (1.0 - uv.y) + 0.35 * value_noise(uv * 6.0 + seed);
	float edge = burn_field - threshold;
	if (threshold <= 0.0) {
		COLOR = paint;
	} else if (threshold >= 1.0 || edge < 0.0) {
		COLOR = vec4(0.0);
	} else {
		// Director (fx-07 review): a thin ember line reads as burning paper; the
		// first pass's 0.02/0.05/0.08 bands read as molten.
		float char_amount = edge >= 0.04 ? 0.70 * clamp((0.12 - edge) / 0.08, 0.0, 1.0) : 0.0;
		vec3 light = vec3(0.0);
		if (edge < 0.01) light = warm_white.rgb;
		else if (edge < 0.025) light = amber.rgb;
		else if (edge < 0.04) light = ember_red.rgb * (0.04 - edge) / 0.015;
		COLOR = vec4(mix(paint.rgb, char_color.rgb, char_amount) + light, paint.a);
	}
}
