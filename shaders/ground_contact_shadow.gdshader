shader_type canvas_item;
render_mode unshaded, blend_mul;

void fragment() {
	// Convert the existing paint and opacity to a destination multiplier.
	// Black mesh paint yields the same multiplier as ordinary alpha-over.
	COLOR = vec4(mix(vec3(1.0), COLOR.rgb, COLOR.a), 1.0);
}
