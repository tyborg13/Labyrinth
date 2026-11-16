shader_type canvas_item;

// Sprite-wide bust: only the lower portion meets the frame window. Its head
// remains completely unbounded above the top rim, as in the director's recipe.
uniform vec4 frame_window = vec4(0.0);
varying vec2 portrait_pixel;
void vertex() { portrait_pixel = VERTEX; }
void fragment() {
	if (portrait_pixel.y >= frame_window.y &&
		(portrait_pixel.x < frame_window.x || portrait_pixel.x >= frame_window.z || portrait_pixel.y >= frame_window.w)) {
		COLOR.a = 0.0;
	}
}
