shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float age = 0.0;
uniform float variation = 0.0;
uniform float duration = 2.15;
void fragment() {
    float u = UV.x;
    float y = UV.y * 2.0 - 1.0;
    float drift = sin(u * 23.0 + age * 3.0 + variation) * 0.045;
    float core = exp(-pow((y + drift) * 15.0, 2.0));
    float halo = exp(-pow(y * 2.7, 2.0)) * 0.28;
    float fiber = exp(-pow((y - 0.23 * sin(u * 34.0 - age * 4.0 + variation)) * 22.0, 2.0)) * 0.18;
    float head = smoothstep(0.15, 1.4, age);
    float reveal = 1.0 - smoothstep(head - 0.035, head + 0.02, u);
    float tail = smoothstep(0.0, 0.14, age) * (1.0 - smoothstep(duration - 0.45, duration, age));
    float shimmer = 0.8 + 0.2 * sin(u * 41.0 - age * 10.0 + variation);
    vec3 silk = mix(vec3(0.32, 0.08, 0.7), vec3(0.94, 0.69, 1.0), core);
    COLOR = vec4(silk * (core + halo + fiber) * shimmer, reveal * tail);
}
