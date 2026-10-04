shader_type canvas_item;

// Keep the authored bronze frame and stitched rails opaque. The suede center
// becomes a tinted veil so the atelier remains part of the composition.
void fragment() {
	float inner_x = smoothstep(0.070, 0.098, UV.x) * (1.0 - smoothstep(0.902, 0.930, UV.x));
	float inner_y = smoothstep(0.099, 0.123, UV.y) * (1.0 - smoothstep(0.877, 0.901, UV.y));
	float veil = inner_x * inner_y;
	COLOR.a *= mix(1.0, 0.52, veil);
}
