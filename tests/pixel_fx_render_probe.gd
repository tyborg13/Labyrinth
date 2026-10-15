extends SceneTree

## GPU oracle: actual ViewportTexture -> quantizer -> 1920x1080 SubViewport.
## Headless parsing is useful; it is explicitly not accepted as pixel proof.
const Pixel = preload("res://scripts/pixel_fx_layer.gd")
const Spell = preload("res://scripts/elemental_spell_fx.gd")
const Fixture = preload("res://tests/pixel_fx_fixture.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Chain = preload("res://scripts/chain_attack_fx.gd")
const Tether = preload("res://scripts/enemy_mechanics/tether_view.gd")
const SurfaceDependencies = preload("res://scripts/board_surface_render_dependencies.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const LineReference = preload("res://tests/pixel_fx_line_reference.gd")
const OUTPUT: String = "user://probes/pixel_fx_render"
const SETTLE_FRAMES: int = 3
const SAMPLE_STRIDE: int = 7
const BACK_RECT := Rect2(100, 100, 600, 400)
const UNIT_RECT := Rect2(300, 100, 500, 400)
const FRONT_RECT := Rect2(500, 100, 200, 400)
const CROP_RECT := Rect2(103.5, 105.25, 200, 120)
const CROP_ALPHA_OFFSET: float = 0.1
const BELOW_FLOOR_CELL := Vector2i(100, 180)
const ABOVE_FLOOR_CELL := Vector2i(100, 272)
const LINE_PROGRESS: float = 0.52
const LINE_FIXTURE: Dictionary = {"start": Vector2(300, 500), "end": Vector2(900, 300), "width": 180.0, "key": "pixel-proof",
	"lightning_center": Vector2(600, 400),
	"lightning_zigzag": [Vector2(300, 500), Vector2(450, 320), Vector2(550, 390), Vector2(900, 300)]}
const UNIT_COLOR := Color(0.125, 0.25, 0.375, 1.0)
var _alphas := PackedFloat32Array()

func _alpha_bands() -> PackedFloat32Array:
	var floor_byte: int = floori(float(Pixel.style()["alpha_floor"]) * 255.0)
	return PackedFloat32Array([0.0, float(maxi(0, floor_byte - 1)) / 255.0, float(floor_byte) / 255.0, float(mini(255, floor_byte + 1)) / 255.0, 128.0 / 255.0, 1.0])
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
	_alphas = _alpha_bands()
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	_viewport = SubViewport.new()
	_viewport.size = Fixture.SIZE
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	for element: String in Pixel.style()["ramps"]:
		await _gradient(element)
	await _cropped_dither()
	for kind: String in ["conduction", "chain", "tether", "lightning"]:
		await _line_core(kind)
	await _line_fade_and_width()
	for element: String in Fixture.ELEMENTS:
		await _depth_and_blend(element)
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
	# Sample Bayer's lowest cell in the two adjacent RGBA8 alpha bands.
	var below_cell: Vector2i = BELOW_FLOOR_CELL
	var above_cell: Vector2i = ABOVE_FLOOR_CELL
	_expect(raw.get_pixelv(below_cell).a < float(Pixel.style()["alpha_floor"]), "GPU fixture includes a just-below-floor band")
	_expect(raw.get_pixelv(above_cell).a > float(Pixel.style()["alpha_floor"]), "GPU fixture includes a just-above-floor band")
	_expect(image.get_pixelv(below_cell * 2).a == 0.0, "GPU discards below-floor alpha at a low-threshold cell")
	_expect(image.get_pixelv(above_cell * 2).a == 1.0, "GPU retains above-floor alpha at a low-threshold cell")
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
	for band: int in range(_alphas.size()):
		for x: int in range(960):
			var value: float = float(x % 256) / 255.0
			canvas.draw_rect(Rect2(x * 2, band * 180, 2, 180), Color(value, value, value, _alphas[band]))

func _depth_and_blend(element: String) -> void:
	var stage := Node2D.new()
	_viewport.add_child(stage)
	var back := Node2D.new()
	stage.add_child(back)
	var back_pixels := Pixel.new()
	back.add_child(back_pixels)
	back_pixels.begin(back)
	back_pixels.submit(element, _draw_rect, [BACK_RECT], Transform2D.IDENTITY, BACK_RECT)
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
	front_pixels.submit(element, _draw_rect, [FRONT_RECT], Transform2D.IDENTITY, FRONT_RECT)
	front_pixels.finish()
	await _settle()
	var image: Image = _viewport.get_texture().get_image()
	var ramp_color: Color = Pixel.ramp_for(element)[4]
	_expect(_color_error(image.get_pixel(200, 200), ramp_color) <= 1, "%s back layer visible outside unit" % element)
	_expect(_color_error(image.get_pixel(400, 200), UNIT_COLOR) <= 1, "%s unit occludes back layer" % element)
	var front_color: Color = ramp_color
	_expect(_color_error(image.get_pixel(600, 200), front_color) <= 1, "%s front layer preserves normal blending over unit" % element)
	_expect(image.save_png(OUTPUT.path_join("%s_depth_mix.png" % element)) == OK, "Save depth fixture")
	stage.queue_free()
	await process_frame

func _cropped_dither() -> void:
	var source := Node2D.new()
	_viewport.add_child(source)
	var pixel := Pixel.new()
	source.add_child(pixel)
	var rect: Rect2 = CROP_RECT
	pixel.begin(source)
	pixel.submit("fire", _draw_alpha_rect, [rect], Transform2D.IDENTITY, rect)
	pixel.finish()
	await _settle()
	var run: Dictionary = (pixel.get("_runs") as Array)[0]
	var raw: Image = (run["viewport"] as SubViewport).get_texture().get_image()
	var image: Image = _viewport.get_texture().get_image()
	var origin: Vector2i = (pixel.snapshot()[0]["cell_rect"] as Rect2i).position
	var maximum: int = 0
	for y: int in range(raw.get_height()):
		for x: int in range(raw.get_width()):
			var cell := Vector2i(x, y)
			var value: Color = raw.get_pixelv(cell)
			if value.a > 0.0:
				value.r /= value.a
				value.g /= value.a
				value.b /= value.a
			var expected: Color = Pixel.quantize(value, origin + cell, "fire")
			maximum = maxi(maximum, _color_error(image.get_pixelv((origin + cell) * 2), expected))
	_expect(raw.get_size() == Vector2i(103, 63), "Fractional bounds round out with exactly one cell of margin")
	_expect(origin == Vector2i(50, 51) and maximum <= 1, "Cropped GPU pixels retain the global Bayer phase")
	_expect(image.save_png(OUTPUT.path_join("fire_cropped_dither.png")) == OK, "Save cropped Bayer fixture")
	source.queue_free()
	await process_frame

func _draw_alpha_rect(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, Color(0.6, 0.6, 0.6, float(Pixel.style()["alpha_floor"]) + CROP_ALPHA_OFFSET))

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

func _line_core(kind: String) -> void:
	var source := Node2D.new()
	_viewport.add_child(source)
	var pixel := Pixel.new()
	source.add_child(pixel)
	var board := Board.new()
	board.size = Fixture.SIZE
	board.visible = false
	root.add_child(board)
	var sample: Dictionary = Fixture.surface_sample("conduction")
	board.set_combat_state(sample["state"], [], [], Vector2i(-1, -1), "", "", {}, {}, sample["presentation"])
	pixel.begin(source)
	if kind == "conduction":
		pixel.submit("lightning", _draw_conduction, [board, sample["presentation"]], Transform2D.IDENTITY)
	elif kind == "chain":
		pixel.submit("lightning", Chain.draw_hop, [LINE_FIXTURE["start"], LINE_FIXTURE["end"], LINE_FIXTURE["width"], LINE_PROGRESS, false], Transform2D.IDENTITY)
	elif kind == "tether":
		var points: PackedVector2Array = Tether.beam_points(LINE_FIXTURE["start"], LINE_FIXTURE["end"], LINE_FIXTURE["key"], 0)
		pixel.submit("lightning", Pixel.draw_line_command, [points, Color(0.94, 0.96, 1.0, 1.0), Color(Tether.COLOR, 0.82)], Transform2D.IDENTITY)
	else:
		pixel.submit("lightning", Pixel.draw_line_command, [PackedVector2Array(LINE_FIXTURE["lightning_zigzag"]), Color(0.94, 0.96, 1.0, 0.72), Color(0.72, 0.65, 1.0, 0.82)], Transform2D.IDENTITY)
		pixel.submit("lightning", Spell.impact, ["lightning", LINE_FIXTURE["lightning_center"], LINE_FIXTURE["width"], LINE_PROGRESS, 1.0, false, false], Transform2D.IDENTITY)
		pixel.submit("lightning", Spell.impact, ["lightning", LINE_FIXTURE["lightning_center"], LINE_FIXTURE["width"], LINE_PROGRESS, 1.0, false, true], Transform2D.IDENTITY)
	pixel.finish()
	await _settle()
	var image: Image = _viewport.get_texture().get_image()
	var lines: Node2D = pixel.get_node("QuantizedPixels/LineCells")
	var strokes: Array[Dictionary]
	strokes.assign(lines.get("strokes"))
	_expect(not strokes.is_empty(), "%s production renderer emits visible strokes" % kind)
	_expect(image.save_png(OUTPUT.path_join(kind + "_solid_core.png")) == OK, "Save GPU polyline fixture")
	var all_core: Dictionary = {}
	for stroke: Dictionary in strokes:
		if (stroke["core"] as Color).a < float(Pixel.style()["alpha_floor"]): continue
		var isolated: Array[Dictionary]
		isolated.append(stroke)
		var mask: Image = await _line_mask(lines, isolated, 1)
		var cells: Dictionary = _opaque_cells(mask, lines.get("cell_rect").position)
		var points: PackedVector2Array = stroke["points"]
		for point: Vector2 in points:
			_expect(cells.has(Vector2i(point.floor())), "%s GPU core covers every zigzag vertex and both endpoints" % kind)
		_expect(_connected(cells), "%s GPU-rendered core is one 8-connected component without gaps" % kind)
		# Small native-vs-Bresenham differences are approved, not a wider band.
		var old_cells: Array[Vector2i] = LineReference.line_cells(stroke["vertices"], Transform2D.IDENTITY)
		var corridor: Dictionary = {}
		for cell: Vector2i in old_cells:
			for y: int in range(-1, 2):
				for x: int in range(-1, 2): corridor[cell + Vector2i(x, y)] = true
		var near_path: bool = true
		for cell: Vector2i in cells:
			near_path = near_path and corridor.has(cell)
			all_core[cell] = true
		_expect(near_path and cells.size() <= old_cells.size() * 2, "%s GPU core stays on the authored path within one cell of round 3" % kind)
	var bad_clusters: int = 0
	for cell: Vector2i in all_core:
		for offset: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
			if image.get_pixelv(cell * 2 + offset) != image.get_pixelv(cell * 2): bad_clusters += 1
	_expect(bad_clusters == 0, "%s real composite has constant nearest 2x2 core clusters" % kind)
	var core_image: Image = await _line_mask(lines, strokes, 1)
	# Keep proof images at the requested 1920x1080 instead of exporting a
	# generation-size mask; the screen-aligned crop origin is restored first.
	var core_capture := Image.create(Fixture.SIZE.x, Fixture.SIZE.y, false, Image.FORMAT_RGBA8)
	var scaled: Image = core_image.duplicate()
	scaled.resize(core_image.get_width() * 2, core_image.get_height() * 2, Image.INTERPOLATE_NEAREST)
	core_capture.blit_rect(scaled, Rect2i(Vector2i.ZERO, scaled.get_size()), lines.get("cell_rect").position * 2)
	_expect(core_capture.save_png(OUTPUT.path_join(kind + "_core_mask.png")) == OK, "Save actual GPU core coverage")
	if kind in ["conduction", "chain"]:
		_expect(_connected(all_core), "%s GPU cores join across segments/tributaries" % kind)
	if kind == "tether":
		var halo_mask: Image = await _line_mask(lines, strokes, 2)
		var halo_cells: Dictionary = _opaque_cells(halo_mask, lines.get("cell_rect").position)
		var normal: Image = await _line_mask(lines, strokes, 0)
		var halo: Color = strokes[0]["halo"]
		var bad: int = 0
		var on_cells: int = 0
		var off_cells: int = 0
		for cell: Vector2i in halo_cells:
			if all_core.has(cell): continue
			var beside: bool = false
			for y: int in range(-1, 2):
				for x: int in range(-1, 2): beside = beside or all_core.has(cell + Vector2i(x, y))
			var expected: Color = Pixel.quantize(halo, cell, "lightning")
			if not beside or _color_error(normal.get_pixelv(cell - lines.get("cell_rect").position), expected) > 1: bad += 1
			on_cells += int(expected.a > 0.0)
			off_cells += int(expected.a == 0.0)
		_expect(bad == 0 and on_cells > 0 and off_cells > 0, "GPU tether halo stays one cell wide with the original Bayer phase")
	await _line_mask(lines, strokes, 0)
	# Round-3 reference at the identical authored frame. Raster differences and
	# the newly requested below-floor fade are reported, not exact-byte gated.
	var reference := LineReference.new()
	reference.strokes.assign(await _round3_strokes(pixel))
	reference.position = -Vector2(lines.get("cell_rect").position)
	lines.get_parent().add_child(reference)
	lines.hide()
	await _settle()
	var before: Image = _viewport.get_texture().get_image()
	_expect(before.save_png(OUTPUT.path_join(kind + "_legacy_cells.png")) == OK, "Save round-3 reference")
	var differences: int = 0
	for y: int in range(0, image.get_height(), 2):
		for x: int in range(0, image.get_width(), 2):
			differences += int(image.get_pixel(x, y) != before.get_pixel(x, y))
	print("PIXEL FX GPU LINE COMPARE %s: %d changed screen cells vs round 3; continuity gated on GPU masks" % [kind, differences])
	source.queue_free()
	board.queue_free()
	await process_frame

func _round3_strokes(pixel: Node2D) -> Array[Dictionary]:
	var capture_viewport := SubViewport.new()
	capture_viewport.size = Fixture.SIZE / 2
	capture_viewport.disable_3d = true
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(capture_viewport)
	var capture := LineReference.Capture.new()
	var drawing: Pixel.Drawing = pixel.get("_runs")[0]["drawing"]
	capture.commands.assign(drawing.commands)
	capture.element = drawing.element
	capture.cell_transform = drawing.cell_transform
	capture_viewport.add_child(capture)
	await _settle()
	var result: Array[Dictionary]
	result.assign(capture.strokes)
	capture_viewport.queue_free()
	return result

func _line_mask(lines: Node2D, strokes: Array[Dictionary], mode: int) -> Image:
	lines.get("strokes").assign(strokes)
	lines.call("flush")
	var drawing: Node2D = lines.get("_drawing")
	(drawing.material as ShaderMaterial).set_shader_parameter("proof_pass", mode)
	await _settle()
	return (lines.get("viewport") as SubViewport).get_texture().get_image()

func _opaque_cells(image: Image, origin: Vector2i) -> Dictionary:
	var result: Dictionary = {}
	var used: Rect2i = image.get_used_rect()
	for y: int in range(used.position.y, used.end.y):
		for x: int in range(used.position.x, used.end.x):
			if image.get_pixel(x, y).a == 1.0: result[Vector2i(x, y) + origin] = true
	return result

func _connected(cells: Dictionary) -> bool:
	if cells.is_empty(): return false
	var reached: Dictionary = {}
	var frontier: Array[Vector2i]
	frontier.append(cells.keys()[0])
	reached[frontier[0]] = true
	var cursor: int = 0
	while cursor < frontier.size():
		var cell: Vector2i = frontier[cursor]
		cursor += 1
		for y: int in range(-1, 2):
			for x: int in range(-1, 2):
				var neighbour := cell + Vector2i(x, y)
				if cells.has(neighbour) and not reached.has(neighbour):
					reached[neighbour] = true
					frontier.append(neighbour)
	return reached.size() == cells.size()

func _line_fade_and_width() -> void:
	var source := Node2D.new()
	_viewport.add_child(source)
	var pixel := Pixel.new()
	source.add_child(pixel)
	var points := PackedVector2Array([Vector2(200, 200), Vector2(480, 200)])
	var floor_alpha: float = float(Pixel.style()["alpha_floor"])
	for alpha: float in [floor_alpha - 0.0001, floor_alpha, floor_alpha + 0.0001]:
		pixel.begin(source)
		pixel.submit("lightning", Pixel.draw_line_command, [points, Color(1, 1, 1, alpha), Color(1, 1, 1, 0)], Transform2D.IDENTITY)
		pixel.finish()
		await _settle()
		var image: Image = _viewport.get_texture().get_image()
		var used: Rect2i = image.get_used_rect()
		if alpha < floor_alpha:
			_expect(not used.has_area(), "GPU core disappears below the source alpha floor")
		else:
			_expect(used == Rect2i(200, 200, 282, 2), "GPU straight core is exactly one low-res cell wide and includes both endpoints")
			for x: int in range(200, 482): _expect(image.get_pixel(x, 200).a == 1.0, "Opaque core never dithers, even at alpha_floor")
	_expect(_viewport.get_texture().get_image().save_png(OUTPUT.path_join("line_alpha_floor.png")) == OK, "Save GPU width/fade fixture")
	source.queue_free()
	await process_frame

func _draw_conduction(canvas: CanvasItem, board: Control, presentation: Dictionary) -> void:
	for tile: Vector2i in SurfaceDependencies.changed_tiles({}, presentation, {"effect": true}):
		board.call("_draw_surface_conduction_floor", tile, canvas)
