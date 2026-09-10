shader_type canvas_item;
render_mode unshaded, blend_disabled;

// SubViewport paint is premultiplied. Board drawing expects straight alpha;
// undo only that representation change so translucent Wisp paint is not
// multiplied twice. This stays GPU-side and preserves the persistent texture.
void fragment() {
	vec4 paint = texture(TEXTURE, UV);
	COLOR = vec4(paint.a > 0.0 ? paint.rgb / paint.a : vec3(0.0), paint.a);
}
