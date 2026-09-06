shader_type canvas_item;
render_mode unshaded;

// Exact CPU-authored corners preserve the immediate renderer's interpolation.
// The geometry and UV topology stay resident while position and tint advance.
uniform vec2 corners[4];
uniform vec4 particle_tint = vec4(1.0);

void vertex() {
	int corner = UV.y > 0.5 ? (UV.x > 0.5 ? 2 : 3) : (UV.x > 0.5 ? 1 : 0);
	VERTEX = corners[corner];
	COLOR *= particle_tint;
}
