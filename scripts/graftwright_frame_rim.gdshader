shader_type canvas_item;
// Preserve the painted foreground rim; reveal the gear only through its well.
void fragment() {
	float radius = length((UV - vec2(0.493, 0.480)) / vec2(1.0, 0.96));
	COLOR.a *= smoothstep(0.322, 0.333, radius);
}
