shader_type canvas_item;

uniform bool rear_segment = false;
uniform vec2 source_offset;
uniform vec2 source_grip;
uniform vec2 toward_butt;

void fragment() {
	// Classify the sampled texel, never a separately cropped/rotated quad.
	// Complementary masks retain every original texel exactly once at the grip.
	vec2 source_texel = floor(UV / TEXTURE_PIXEL_SIZE) + vec2(0.5) + source_offset;
	bool behind_grip = dot(source_texel - source_grip, toward_butt) >= 0.0;
	if (behind_grip != rear_segment) {
		discard;
	}
}
