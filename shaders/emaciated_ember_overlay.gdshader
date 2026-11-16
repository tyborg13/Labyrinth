shader_type canvas_item;
render_mode unshaded, blend_add;
// Selection reads the approved painting, with no new colors or halo paint.
uniform float min_saturation = 1.1;
uniform float pulse_alpha = 0.0;
uniform sampler2D source_paint : filter_nearest;
void fragment() {
	vec4 paint = texture(source_paint, UV);
	float hi = max(paint.r, max(paint.g, paint.b));
	float lo = min(paint.r, min(paint.g, paint.b));
	float delta = hi - lo;
	float hue = 0.0;
	if (delta > 0.0) {
		if (hi == paint.r) hue = mod((paint.g - paint.b) / delta, 6.0);
		else if (hi == paint.g) hue = (paint.b - paint.r) / delta + 2.0;
		else hue = (paint.r - paint.g) / delta + 4.0;
	}
	hue = mod(hue * 60.0 + 360.0, 360.0);
	float saturation = hi > 0.0 ? delta / hi : 0.0;
	float selected = float(hue >= 15.0 && hue <= 35.0 && saturation >= min_saturation);
	COLOR = vec4(paint.rgb, paint.a * selected * pulse_alpha);
}
