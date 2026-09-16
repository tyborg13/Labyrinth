shader_type canvas_item;
render_mode unshaded;
uniform vec4 tint : source_color = vec4(0.55, 0.2, 0.9, 0.5);
void fragment() {
    vec2 p = (UV - vec2(0.5)) * 2.0;
    float falloff = exp(-dot(p, p) * 4.8) * (1.0 - smoothstep(0.72, 1.0, length(p)));
    COLOR = vec4(tint.rgb, tint.a * falloff);
}
