extends Control

# Three static bands, blurred by the authored six-pixel falloff. Radius follows
# the card's existing 18px rounded frame glow.
const DRAW_PADDING: float = 32.0
const SHADER: String = """
shader_type canvas_item;
uniform vec2 card_size;
varying vec2 point;
void vertex() { point = VERTEX; }
void fragment() {
	vec2 p = abs(point - card_size * 0.5) - (card_size * 0.5 - vec2(18.0));
	float d = length(max(p, vec2(0.0))) + min(max(p.x, p.y), 0.0) - 18.0;
	float alpha = 0.0;
	alpha = 140.0 / 255.0 * exp(-0.5 * pow((d - 5.0) / 6.0, 2.0));
	alpha = 1.0 - (1.0 - alpha) * (1.0 - 90.0 / 255.0 * exp(-0.5 * pow((d - 9.0) / 6.0, 2.0)));
	alpha = 1.0 - (1.0 - alpha) * (1.0 - 50.0 / 255.0 * exp(-0.5 * pow((d - 14.0) / 6.0, 2.0)));
	COLOR = vec4(vec3(255.0, 150.0, 60.0) / 255.0, clamp(alpha, 0.0, 1.0) * step(0.0, d));
}
"""

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	var shader := Shader.new()
	shader.code = SHADER
	var effect := ShaderMaterial.new()
	effect.shader = shader
	material = effect

func _draw() -> void:
	(material as ShaderMaterial).set_shader_parameter("card_size", size)
	draw_rect(Rect2(Vector2.ZERO, size).grow(DRAW_PADDING), Color.WHITE)
