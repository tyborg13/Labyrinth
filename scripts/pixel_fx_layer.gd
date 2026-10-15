extends Node2D

## Presentation-only routing of the original procedural draw calls. One host per
## retained painter pass preserves the existing tile/back/unit/front ordering.
## Adjacent calls share a viewport only when element agrees; this
## also keeps overlapping effects of different elements in submission order.
const STYLE_PATH: String = "res://data/vfx_pixel_style.json"
const QUANTIZE: Shader = preload("res://shaders/pixel_fx_quantize.gdshader")
const LineBatch = preload("res://scripts/pixel_fx_line_batch.gd")
const BAYER: PackedInt32Array = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
const LUMA := Vector3(0.299, 0.587, 0.114)
static var _style: Dictionary = {}
# In-memory probe override; never changes the protected data or player settings.
static var review_enabled_override: Variant = null

var _source: CanvasItem
var _runs: Array[Dictionary]
var _used: int = 0
var _raw_drawings: Array[Drawing]
var _raw_used: int = 0
var _last_key: Variant = null
var _pixel_transform := Transform2D.IDENTITY
var _grid: int = 1
var _resolution := Vector2i.ONE
var _line_cache: RefCounted

class Drawing extends Node2D:
	var commands: Array[Dictionary]
	var submitted_frame: int = -1
	var drawn_frame: int = -1
	var line_canvas: LineCanvas
	var cell_transform := Transform2D.IDENTITY
	var command_transform := Transform2D.IDENTITY
	var element: String = "neutral"

	func _draw() -> void:
		drawn_frame = Engine.get_process_frames()
		if line_canvas != null:
			line_canvas.strokes.clear()
		for command: Dictionary in commands:
			command_transform = command["transform"]
			draw_set_transform_matrix(command_transform)
			var args: Array = [self]
			args.append_array(command["args"])
			(command["draw"] as Callable).callv(args)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		if line_canvas != null:
			line_canvas.queue_redraw()

	func _pixel_line(points: PackedVector2Array, core: Color, halo: Color) -> bool:
		if line_canvas == null:
			return false
		if core.a > 0.0:
			line_canvas.strokes.append(line_canvas.cache.stroke(points, cell_transform * command_transform, core, halo, element))
		return true

class LineCanvas extends Node2D:
	var cache: RefCounted
	var strokes: Array[Dictionary]
	var drawn_frame: int = -1
	# Canvas commands retain the RID, so keep this resource alive even if another
	# run evicts its cache entry before this retained CanvasItem draws again.
	var mesh: ArrayMesh

	func _draw() -> void:
		drawn_frame = Engine.get_process_frames()
		mesh = cache.batch(strokes)
		if mesh != null: draw_mesh(mesh, null)

## One-cell Bresenham path through every authored vertex, including endpoints.
## Floor in screen-cell coordinates keeps adjacent tile owners on the same grid.
static func line_cells(points: PackedVector2Array, to_cells: Transform2D) -> Array[Vector2i]:
	var result: Array[Vector2i]
	for index: int in range(1, points.size()):
		var cell := Vector2i((to_cells * points[index - 1]).floor())
		var end := Vector2i((to_cells * points[index]).floor())
		var delta := Vector2i(absi(end.x - cell.x), -absi(end.y - cell.y))
		var step := Vector2i(1 if cell.x < end.x else -1, 1 if cell.y < end.y else -1)
		var error: int = delta.x + delta.y
		while true:
			if result.is_empty() or result[-1] != cell: result.append(cell)
			if cell == end: break
			var twice: int = error * 2
			if twice >= delta.y:
				error += delta.y
				cell.x += step.x
			if twice <= delta.x:
				error += delta.x
				cell.y += step.y
	return result

static func line(canvas: CanvasItem, points: PackedVector2Array, core: Color, halo: Color) -> bool:
	return canvas != null and canvas.has_method("_pixel_line") and bool(canvas.call("_pixel_line", points, core, halo))

static func draw_line_command(canvas: CanvasItem, points: PackedVector2Array, core: Color, halo: Color) -> void:
	line(canvas, points, core, halo)

static func line_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty(): return Rect2()
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points: bounds = bounds.expand(point)
	return bounds.grow(1.0)

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

## Shared oracle for proof and the small line-cell canvas. Other procedural
## primitives are quantized by the shader.
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
	_last_key = null
	var viewport: Viewport = source.get_viewport()
	var stretch: Transform2D = viewport.get_stretch_transform()
	var pixels: Vector2 = viewport.get_visible_rect().size * stretch.get_scale()
	_grid = grid_px(roundi(pixels.y))
	_resolution = Vector2i(ceili(pixels.x / _grid), ceili(pixels.y / _grid))
	_pixel_transform = stretch * source.get_global_transform_with_canvas()
	# Cancels board pan/zoom and fractional position on the composite, while the
	# original drawing receives that exact transform inside the low-res canvas.
	transform = _pixel_transform.affine_inverse() * Transform2D(0.0, Vector2.ONE * _grid, 0.0, Vector2.ZERO)

func submit(element: String, draw_call: Callable, args: Array, drawing_transform: Transform2D, bounds: Rect2 = Rect2()) -> void:
	var key: String = element
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
		shader_material.shader = QUANTIZE
		drawing.element = element
		shader_material.set_shader_parameter("ramp", ramp_for(element))
		shader_material.set_shader_parameter("alpha_floor", float(style()["alpha_floor"]))
		shader_material.set_shader_parameter("alpha_bias", float(style()["alpha_bias"]))
		run["bounds"] = Rect2()
		run["element"] = element
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
	_last_key = null

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
		var drawing: Drawing = run["drawing"]
		drawing.cell_transform = Transform2D(0.0, Vector2.ONE / _grid, 0.0, Vector2.ZERO) * _pixel_transform
		drawing.line_canvas.position = -clipped.position
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
		result.append({"element": run["element"], "grid": _grid,
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
	var lines := LineCanvas.new()
	lines.name = "LineCells"
	if _line_cache == null: _line_cache = LineBatch.new(line_cells, quantize)
	lines.cache = _line_cache
	composite.add_child(lines)
	drawing.line_canvas = lines
	return {"viewport": viewport, "drawing": drawing, "composite": composite}
