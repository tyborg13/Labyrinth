shader_type canvas_item;
render_mode unshaded;
#include "res://assets/shaders/combat_art_palette.gdshaderinc"

varying vec4 art_vertex_color;
varying vec2 art_point;
varying flat float art_profile;

void vertex() {
	// A profile is explicit per draw, not inferred from color or brightness.
	// All ordinary UVs remain untouched, including tactical overlays and text.
	art_profile = UV.x >= 8.0 ? floor(UV.x / 8.0) : 0.0;
	UV.x -= art_profile * 8.0;
	art_point = VERTEX;
	art_vertex_color = COLOR;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	if (art_profile > 0.5 && art_strength > 0.0) {
		vec2 direction;
		float edge_energy;
		vec3 light = art_illumination(art_point, art_profile, direction, edge_energy);
		vec3 rgb = art_finish(source.rgb, art_profile, light);
		// Interior silhouette edge only. The complete cutout texture supplies
		// alpha, so joints never acquire outlines and transparent pixels stay so.
		if (art_profile > 3.5 && art_profile < 4.5 && source.a > 0.05) {
			vec2 edge_uv = UV + direction * TEXTURE_PIXEL_SIZE * 1.75;
			float neighbor = texture(TEXTURE, clamp(edge_uv, vec2(0.0), vec2(1.0))).a;
			float edge = clamp(source.a - neighbor, 0.0, 1.0);
			rgb += vec3(1.0, 0.64, 0.30) * edge * min(edge_energy, 0.65) * 0.60 * art_strength;
		}
		source.rgb = clamp(rgb, vec3(0.0), vec3(1.0));
	}
	COLOR = source * art_vertex_color;
}
