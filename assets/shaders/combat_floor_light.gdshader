shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;
#include "res://assets/shaders/combat_art_palette.gdshaderinc"
uniform mat3 cache_to_board;
varying vec2 art_point;
void vertex() { art_point = (cache_to_board * vec3(VERTEX, 1.0)).xy; }
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	if (source.a > 0.001 && art_strength > 0.0) {
		vec2 direction;
		float edge;
		vec3 steady = art_illumination_sample(art_point, 1.0, false, direction, edge);
		vec3 live = art_illumination_sample(art_point, 1.0, true, direction, edge);
		// The floor is baked once at steady illumination. Modulate its existing
		// composite for subtle flicker without redrawing tiles or the viewport.
		vec3 base = vec3(art_ambient_level) + steady * art_gain_level;
		vec3 now = vec3(art_ambient_level) + live * art_gain_level;
		source.rgb = min(source.rgb * now / max(base, vec3(0.01)), vec3(source.a));
	}
	COLOR = source;
}
