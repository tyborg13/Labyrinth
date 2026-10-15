extends Node2D

## Presentation-only routing of the original procedural draw calls. One host per
## retained painter pass preserves the existing tile/back/unit/front ordering.
## Adjacent calls share a viewport only when element and blend mode agree; this
## also keeps overlapping effects of different elements in submission order.
const STYLE_PATH: String = "res://data/vfx_pixel_style.json"
const QUANTIZE: Shader = preload("res://shaders/pixel_fx_quantize.gdshader")
const BAYER: PackedInt32Array = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
const LUMA := Vector3(0.299, 0.587, 0.114)
static var _style: Dictionary = {}
static var _add_shader: Shader
# In-memory probe override; never changes the protected data or player settings.
static var review_enabled_override: Variant = null

var _source: CanvasItem
var _runs: Array[Dictionary]
var _used: int = 0
var _raw_drawings: Array[Drawing]
var _raw_used: int = 0
var _last_key: String = ""
var _pixel_transform := Transform2D.IDENTITY
var _grid: int = 1
var _resolution := Vector2i.ONE

class Drawing extends Node2D:
	var commands: Array[Dictionary]
	var submitted_frame: int = -1
	var drawn_frame: int = -1

	func _draw() -> void:
		drawn_frame = Engine.get_process_frames()
		for command: Dictionary in commands:
			draw_set_transform_matrix(command["transform"])
			var args: Array = [self]
			args.append_array(command["args"])
			(command["draw"] as Callable).callv(args)
		draw_set_transform_matrix(Transform2D.IDENTITY)

static func style() -> Dictionary:
	if _style.is_empty():
		_style = JSON.parse_string(FileAccess.get_file_as_string(STYLE_PATH)) as Dictionary
	return _style

static func enabled() -> bool:
	return bool(style()["pixel_style_enabled"]) if review_enabled_override == null else bool(review_enabled_override)

static func grid_px(viewport_height: int) -> int:
	return maxi(1, roundi(float(style()["grid_px_at_1080"]) * viewport_height / 1080.0))

static func ramp_for(element: String) -> PackedColorArray:
	var ramps: Dictionary = style()["ramps"]
	var result := PackedColorArray()
	for value: String in ramps.get(element, ramps["neutral"]):
		result.append(Color(value))
	return result

static func luminance(color: Color) -> float:
	return Vector3(color.r, color.g, color.b).dot(LUMA)

## CPU oracle for fixtures; production quantization runs only in the shader.
static func quantize(color: Color, cell: Vector2i, element: String) -> Color:
	# Color channels and shader uniforms are float32, including exact-threshold
	# comparisons after the approved non-binary bias is uploaded.
	var bias: float = PackedFloat32Array([float(style()["alpha_bias"])])[0]
	var threshold: float = PackedFloat32Array([float(BAYER[posmod(cell.y, 4) * 4 + posmod(cell.x, 4)]) / 16.0 + bias])[0]
	var ramp: PackedColorArray = ramp_for(element)
	var nearest: Color = ramp[0]
	var distance: float = absf(luminance(color) - luminance(nearest))
	for candidate: Color in ramp:
		var difference: float = absf(luminance(color) - luminance(candidate))
		if difference < distance:
			distance = difference
			nearest = candidate
	nearest.a = 1.0 if color.a >= float(style()["alpha_floor"]) and color.a > threshold else 0.0
	return nearest

static func draw_texture_command(canvas: CanvasItem, texture: Texture2D, rect: Rect2, tint: Color) -> void:
	canvas.draw_texture_rect(texture, rect, false, tint)

static func route(canvas: CanvasItem, element: String, draw_call: Callable, args: Array) -> bool:
	# Unregistered callers (including geometry/hash probes) stay pre-pixelation.
	if canvas == null or not canvas.has_method("_submit_pixel_fx") or not enabled():
		return false
	canvas.call("_submit_pixel_fx", element, draw_call, args)
	return true

func begin(source: CanvasItem) -> void:
	if _source == null:
		# A viewport stretch can change physical pixels without resizing the
		# logical board Control (for example 1080 -> 2160 on the same aspect).
		if not source.get_viewport().size_changed.is_connected(source.queue_redraw):
			source.get_viewport().size_changed.connect(source.queue_redraw)
	_source = source
	_used = 0
	_raw_used = 0
	_last_key = ""
	var viewport: Viewport = source.get_viewport()
	var stretch: Transform2D = viewport.get_stretch_transform()
	var pixels: Vector2 = viewport.get_visible_rect().size * stretch.get_scale()
	_grid = grid_px(roundi(pixels.y))
	_resolution = Vector2i(ceili(pixels.x / _grid), ceili(pixels.y / _grid))
	_pixel_transform = stretch * source.get_global_transform_with_canvas()
	# Cancels board pan/zoom and fractional position on the composite, while the
	# original drawing receives that exact transform inside the low-res canvas.
	transform = _pixel_transform.affine_inverse() * Transform2D(0.0, Vector2.ONE * _grid, 0.0, Vector2.ZERO)

func submit(element: String, draw_call: Callable, args: Array, drawing_transform: Transform2D, additive: bool = false, bounds: Rect2 = Rect2()) -> void:
	var key: String = element + (":add" if additive else ":mix")
	if key != _last_key:
		if _used == _runs.size():
			_runs.append(_make_run())
		var run: Dictionary = _runs[_used]
		var viewport: SubViewport = run["viewport"]
		var drawing: Drawing = run["drawing"]
		var composite: Sprite2D = run["composite"]
		drawing.commands.clear()
		drawing.material = _source.material
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		composite.visible = true
		move_child(composite, get_child_count() - 1)
		var shader_material: ShaderMaterial = composite.material as ShaderMaterial
		shader_material.shader = _shader_for(additive)
		shader_material.set_shader_parameter("ramp", ramp_for(element))
		shader_material.set_shader_parameter("alpha_floor", float(style()["alpha_floor"]))
		shader_material.set_shader_parameter("alpha_bias", float(style()["alpha_bias"]))
		run["bounds"] = Rect2()
		run["element"] = element
		run["additive"] = additive
		_used += 1
		_last_key = key
	var active: Dictionary = _runs[_used - 1]
	# Callers provide a conservative local geometry box; unspecified fixtures
	# retain the full viewport. Bounds never depend on color/alpha readbacks.
	var screen_bounds: Rect2 = _pixel_transform * drawing_transform * bounds if bounds.has_area() else Rect2(Vector2.ZERO, Vector2(_resolution * _grid))
	active["bounds"] = screen_bounds if not (active["bounds"] as Rect2).has_area() else (active["bounds"] as Rect2).merge(screen_bounds)
	var drawing: Drawing = active["drawing"]
	drawing.commands.append({"draw": draw_call, "args": args, "transform": drawing_transform})
	drawing.submitted_frame = Engine.get_process_frames()
	drawing.queue_redraw()

func submit_raw(draw_call: Callable, args: Array) -> void:
	# A texture between trap effects must keep its native sampling and order.
	if _raw_used == _raw_drawings.size():
		var drawing := Drawing.new()
		add_child(drawing)
		_raw_drawings.append(drawing)
	var drawing: Drawing = _raw_drawings[_raw_used]
	drawing.material = _source.material
	drawing.transform = transform.affine_inverse()
	drawing.commands.clear()
	drawing.commands.append({"draw": draw_call, "args": args, "transform": Transform2D.IDENTITY})
	drawing.queue_redraw()
	move_child(drawing, get_child_count() - 1)
	_raw_used += 1
	_last_key = ""

func finish() -> void:
	while _raw_drawings.size() > _raw_used:
		var drawing: Drawing = _raw_drawings.pop_back()
		drawing.visible = false
		drawing.queue_free()
	for index: int in range(_used):
		var run: Dictionary = _runs[index]
		var viewport: SubViewport = run["viewport"]
		var composite: Sprite2D = run["composite"]
		var bounds: Rect2 = run["bounds"]
		var first: Vector2 = (bounds.position / _grid).floor() - Vector2.ONE
		var last: Vector2 = (bounds.end / _grid).ceil() + Vector2.ONE
		var clipped := Rect2(first, last - first).intersection(Rect2(Vector2.ZERO, Vector2(_resolution)))
		composite.visible = clipped.has_area()
		viewport.size = Vector2i(clipped.size).max(Vector2i.ONE)
		composite.position = clipped.position
		viewport.global_canvas_transform = Transform2D(0.0, Vector2.ONE / _grid, 0.0, -clipped.position) * _pixel_transform
		(composite.material as ShaderMaterial).set_shader_parameter("cell_origin", clipped.position)
		run["cell_rect"] = Rect2i(clipped)
	# Release inactive render targets, including when a spell clears or moves to
	# another tile. Empty tiles never allocate viewports or process every frame.
	while _runs.size() > _used:
		var run: Dictionary = _runs.pop_back()
		var composite: Sprite2D = run["composite"]
		composite.visible = false
		composite.queue_free()
		var viewport: SubViewport = run["viewport"]
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		viewport.queue_free()

func snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary]
	for run: Dictionary in _runs:
		var drawing: Drawing = run["drawing"]
		result.append({"element": run["element"], "additive": run["additive"], "grid": _grid,
			"resolution": (run["viewport"] as SubViewport).size, "cell_rect": run["cell_rect"], "bounds": run["bounds"], "commands": drawing.commands.size(),
			"submitted_frame": drawing.submitted_frame, "drawn_frame": drawing.drawn_frame})
	return result

func _make_run() -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "ProceduralPixels"
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.gui_disable_input = true
	viewport.msaa_2d = Viewport.MSAA_DISABLED
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	add_child(viewport)
	var drawing := Drawing.new()
	viewport.add_child(drawing)
	var composite := Sprite2D.new()
	composite.name = "QuantizedPixels"
	composite.centered = false
	composite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	composite.texture = viewport.get_texture()
	composite.material = ShaderMaterial.new()
	add_child(composite)
	return {"viewport": viewport, "drawing": drawing, "composite": composite}

static func _shader_for(additive: bool) -> Shader:
	if not additive:
		return QUANTIZE
	if _add_shader == null:
		_add_shader = Shader.new()
		_add_shader.code = QUANTIZE.code.replace("blend_mix", "blend_add")
	return _add_shader
