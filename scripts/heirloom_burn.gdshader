shader_type canvas_item;
render_mode unshaded;

// Composite the entire real card (frame, tab, lettering and medallion).
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 card_origin;
uniform vec2 card_size;
uniform float noise_period = 24.0;
uniform float noise_amplitude = 8.0;
uniform float pixel_grid = 2.0;
uniform float band_pixels = 5.0;
uniform float burn_top = 0.0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 gold_bright : source_color;
uniform vec4 ember : source_color;
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
	vec4 paint = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (paint.a > 0.0001) paint.rgb /= paint.a;
	vec2 point = SCREEN_UV / SCREEN_PIXEL_SIZE - card_origin;
	float noise_x = floor(point.x / pixel_grid) * pixel_grid;
	float base = floor(mix(card_size.y, burn_top, progress) / pixel_grid + 0.5) * pixel_grid;
	float offset = floor((value_noise(vec2(noise_x, base) / noise_period) * 2.0 - 1.0) * noise_amplitude / pixel_grid + 0.5) * pixel_grid;
	float edge = base + offset;
	float distance_above = edge - point.y;
	if (progress <= 0.0) {
		COLOR = paint;
	} else if (progress >= 1.0 || distance_above < 0.0) {
		COLOR = vec4(0.0);
	} else if (distance_above <= band_pixels) {
		vec3 band = distance_above <= band_pixels * 0.5
			? mix(gold_bright.rgb, ember.rgb, distance_above / (band_pixels * 0.5))
			: mix(ember.rgb, char_color.rgb, (distance_above - band_pixels * 0.5) / (band_pixels * 0.5));
		COLOR = vec4(band, paint.a);
	} else {
		COLOR = paint;
	}
}
