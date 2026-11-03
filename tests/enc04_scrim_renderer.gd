extends RefCounted
## Render the production scrim alone on transparency at its live HUD geometry.
## Reading polygon data cannot prove that _draw submitted anything to the GPU.
const SIZE := Vector2i(1920, 1080)
const MINIMUM_ALPHA_BYTE: int = 217 # 0.85 rounded to the renderer's RGBA8 alpha.
const SETTLE_FRAMES: int = 3

static func check(tree: SceneTree, banner: Label, diagnostics: Dictionary, output: String, expect: Callable) -> void:
	var scrim: Control = banner.get_node_or_null("ActionCaptionScrim")
	if scrim == null: return
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(viewport)
	var rendered: Control = scrim.get_script().new()
	viewport.add_child(rendered)
	rendered.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	rendered.size = scrim.size
	rendered.position = banner.get_global_rect().position
	for frame: int in range(SETTLE_FRAMES): await tree.process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var coverage: Image = Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_L8)
	var rect: Rect2 = banner.get_global_rect()
	var intersection: Rect2 = (diagnostics.get("crest_rect", Rect2()) as Rect2).intersection(rect)
	var minimum: int = 255
	var overlap_minimum: int = 255
	var samples: int = 0
	var overlap_samples: int = 0
	# Only pixels whose centres are under the text rectangle, excluding the
	# antialiased boundary outside it. Check every interior pixel, not a mean.
	for y: int in range(maxi(0, ceili(rect.position.y)), mini(SIZE.y, floori(rect.end.y))):
		for x: int in range(maxi(0, ceili(rect.position.x)), mini(SIZE.x, floori(rect.end.x))):
			var alpha: int = roundi(image.get_pixel(x, y).a * 255.0)
			var value: float = float(alpha) / 255.0
			coverage.set_pixel(x, y, Color(value, value, value))
			minimum = mini(minimum, alpha)
			samples += 1
			if intersection.has_point(Vector2(x + 0.5, y + 0.5)):
				overlap_minimum = mini(overlap_minimum, alpha)
				overlap_samples += 1
	expect.call(samples > 0 and minimum >= MINIMUM_ALPHA_BYTE, "Rendered scrim covers every caption text pixel at >= 0.85 alpha")
	if intersection.has_area():
		expect.call(overlap_samples > 0 and overlap_minimum >= MINIMUM_ALPHA_BYTE, "Rendered scrim covers the live crest/text overlap at >= 0.85 alpha")
	# The PNG makes alpha visible as luminance for inspection and the visual
	# runner's nonblank-image guard. Retain the untouched RGBA render as WebP.
	expect.call(coverage.save_png(output) == OK, "Save renderer-backed scrim alpha coverage")
	expect.call(image.save_webp(output.get_basename() + ".webp", true) == OK, "Save untouched transparent scrim render")
	diagnostics["rendered_scrim_min_alpha_byte"] = minimum
	diagnostics["rendered_scrim_pixels"] = samples
	diagnostics["rendered_scrim_overlap_pixels"] = overlap_samples
	print("ENC04 SCRIM RENDERER: pixels=%d min_alpha_byte=%d overlap_pixels=%d overlap_min_alpha_byte=%d" % [samples, minimum, overlap_samples, overlap_minimum])
	viewport.queue_free()
	await tree.process_frame
