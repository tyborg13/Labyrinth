shader_type canvas_item;

uniform float line_height = 36.0;
varying vec2 glyph_position;
void vertex() { glyph_position = VERTEX; }
void fragment() {
	float height = clamp(glyph_position.y / max(line_height, 1.0), 0.0, 1.0);
	// Restrained top light and darker lower edge echo the frame's aged metal.
	float light = mix(1.16, 0.72, smoothstep(0.18, 0.86, height));
	float grain = fract(sin(dot(floor(glyph_position), vec2(12.9898, 78.233))) * 43758.5453);
	COLOR.rgb *= light + (grain - 0.5) * 0.035;
}
