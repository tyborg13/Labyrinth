extends SceneTree

## GPU oracle: actual ViewportTexture -> quantizer -> 1920x1080 SubViewport.
## Headless parsing is useful; it is explicitly not accepted as pixel proof.
const Pixel = preload("res://scripts/pixel_fx_layer.gd")
const Fixture = preload("res://tests/pixel_fx_fixture.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const OUTPUT: String = "user://probes/pixel_fx_render"
const SETTLE_FRAMES: int = 3
const SAMPLE_STRIDE: int = 7
const BACK_RECT := Rect2(100, 100, 600, 400)
const UNIT_RECT := Rect2(300, 100, 500, 400)
const FRONT_RECT := Rect2(500, 100, 200, 400)
const UNIT_COLOR := Color(0.125, 0.25, 0.375, 1.0)
const ALPHAS: PackedFloat32Array = [0.0, 16.0 / 255.0, 20.0 / 255.0, 21.0 / 255.0, 128.0 / 255.0, 1.0]
var _failures: Array[String]
var _checks: int = 0
var _viewport: SubViewport

func _initialize() -> void:
	Runtime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("PIXEL FX RENDER PROBE requires a real renderer")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	_viewport = SubViewport.new()
	_viewport.size = Fixture.SIZE
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	for element: String in Pixel.style()["ramps"]:
		await _gradient(element)
	for element: String in Fixture.ELEMENTS:
		for additive: bool in [false, true]:
			await _depth_and_blend(element, additive)
	for error: String in _failures:
		push_error(error)
	print(ProjectSettings.globalize_path(OUTPUT))
	print("PIXEL FX RENDER PROBE: %s (%d checks, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _gradient(element: String) -> void:
	var source := Node2D.new()
	_viewport.add_child(source)
	var pixel := Pixel.new()
	source.add_child(pixel)
	pixel.begin(source)
	pixel.submit(element, _draw_gradient, [], Transform2D.IDENTITY)
	pixel.finish()
	await _settle()
	var image: Image = _viewport.get_texture().get_image()
	var raw_viewport: SubViewport = pixel.get_node("ProceduralPixels")
	var raw: Image = raw_viewport.get_texture().get_image()
	_expect(image.get_size() == Fixture.SIZE and raw.get_size() == Vector2i(960, 540), "Real renderer uses the required resolutions")
	_expect(image.save_png(OUTPUT.path_join(element + "_gradient.png")) == OK, "Save gradient")
	var ramp: PackedColorArray = Pixel.ramp_for(element)
	var seen: Dictionary = {}
	var max_error: int = 0
	var bad_blocks: int = 0
	for y: int in range(0, raw.get_height(), SAMPLE_STRIDE):
		for x: int in range(raw.get_width()):
			var raw_color: Color = raw.get_pixel(x, y)
			# Transparent render targets hold premultiplied RGB. This also models
			# RGBA8 rounding before thresholding, including alpha-floor boundaries.
			var straight: Color = raw_color
			if straight.a > 0.0:
				straight.r /= straight.a
				straight.g /= straight.a
				straight.b /= straight.a
			var expected: Color = Pixel.quantize(straight, Vector2i(x, y), element)
			var actual: Color = image.get_pixel(x * 2, y * 2)
			max_error = maxi(max_error, _color_error(actual, expected))
			for offset: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
				if image.get_pixel(x * 2 + offset.x, y * 2 + offset.y) != actual:
					bad_blocks += 1
			if actual.a > 0.0:
				seen[actual.to_rgba32()] = true
	_expect(max_error <= 1, "%s GPU matches Rec.601/Bayer/floor oracle (maximum channel error %d)" % [element, max_error])
	_expect(bad_blocks == 0, "%s nearest scaling produces constant 2x2 pixel clusters" % element)
	var expected_colors: Dictionary = {}
	for color: Color in ramp:
		expected_colors[color.to_rgba32()] = true
	_expect(seen == expected_colors, "%s GPU gradient maps to exactly its five ramp entries" % element)
	await _settle()
	_expect(image.get_data() == _viewport.get_texture().get_image().get_data(), "%s same commands in another frame retain identical Bayer pixels" % element)
	source.queue_free()
	await process_frame

func _draw_gradient(canvas: CanvasItem) -> void:
	# Six alpha bands and a repeated full-luminance fixture; no authored art.
	for band: int in range(ALPHAS.size()):
		for x: int in range(960):
			var value: float = float(x % 256) / 255.0
			canvas.draw_rect(Rect2(x * 2, band * 180, 2, 180), Color(value, value, value, ALPHAS[band]))

func _depth_and_blend(element: String, additive: bool) -> void:
	var stage := Node2D.new()
	_viewport.add_child(stage)
	var back := Node2D.new()
	stage.add_child(back)
	var back_pixels := Pixel.new()
	back.add_child(back_pixels)
	back_pixels.begin(back)
	back_pixels.submit(element, _draw_rect, [BACK_RECT], Transform2D.IDENTITY, additive)
	back_pixels.finish()
	var unit := ColorRect.new()
	unit.position = UNIT_RECT.position
	unit.size = UNIT_RECT.size
	unit.color = UNIT_COLOR
	stage.add_child(unit)
	var front := Node2D.new()
	stage.add_child(front)
	var front_pixels := Pixel.new()
	front.add_child(front_pixels)
	front_pixels.begin(front)
	front_pixels.submit(element, _draw_rect, [FRONT_RECT], Transform2D.IDENTITY, additive)
	front_pixels.finish()
	await _settle()
	var image: Image = _viewport.get_texture().get_image()
	var ramp_color: Color = Pixel.ramp_for(element)[4]
	_expect(_color_error(image.get_pixel(200, 200), ramp_color) <= 1, "%s back layer visible outside unit" % element)
	_expect(_color_error(image.get_pixel(400, 200), UNIT_COLOR) <= 1, "%s unit occludes back layer" % element)
	var front_color: Color = ramp_color
	if additive:
		front_color = Color(minf(1.0, UNIT_COLOR.r + ramp_color.r), minf(1.0, UNIT_COLOR.g + ramp_color.g), minf(1.0, UNIT_COLOR.b + ramp_color.b), 1.0)
	_expect(_color_error(image.get_pixel(600, 200), front_color) <= 1, "%s front layer preserves %s blending over unit" % [element, "additive" if additive else "normal"])
	_expect(image.save_png(OUTPUT.path_join("%s_depth_%s.png" % [element, "add" if additive else "mix"])) == OK, "Save depth/blend fixture")
	stage.queue_free()
	await process_frame

func _draw_rect(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, Color.WHITE)

func _color_error(actual: Color, expected: Color) -> int:
	var maximum: float = absf(actual.a - expected.a)
	if expected.a > 0.0:
		maximum = maxf(maximum, maxf(absf(actual.r - expected.r), maxf(absf(actual.g - expected.g), absf(actual.b - expected.b))))
	return roundi(maximum * 255.0)

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES):
		await process_frame
	await RenderingServer.frame_post_draw

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
