extends Node2D

## One cropped, low-resolution GPU target for the current frame's line strokes.
## No rasterized-cell/mesh history: vertices are the original authored zigzags.
const QUANTIZE: Shader = preload("res://shaders/pixel_fx_lines.gdshader")
const CORE_WIDTH: float = 1.0
const HALO_WIDTH: float = 3.0
const HALO_ALPHA_ENCODING: float = 0.5
var strokes: Array[Dictionary]
var cell_rect: Rect2i
var alpha_floor: float
var alpha_bias: float
var ramp: PackedColorArray
var viewport: SubViewport
var _drawing: StrokeDrawing
var _composite: Sprite2D
var drawn_frame: int = -1

class StrokeDrawing extends Node2D:
	var lines: Node2D
	func _draw() -> void:
		lines.drawn_frame = Engine.get_process_frames()
		for stroke: Dictionary in lines.strokes:
			var points: PackedVector2Array = stroke["points"]
			var halo: Color = stroke["halo"]
			if halo.a >= lines.alpha_floor:
				halo.a *= HALO_ALPHA_ENCODING
				_stroke(points, halo, HALO_WIDTH)
			var core: Color = stroke["core"]
			if core.a >= lines.alpha_floor:
				# Alpha 1 is a core flag local to this shader, not a change to
				# the authored alpha. The floor above still ends a fading core.
				core.a = 1.0
				_stroke(points, core, CORE_WIDTH)

	func _stroke(points: PackedVector2Array, color: Color, width: float) -> void:
		draw_polyline(points, color, width, false)
		# Native butt caps can exclude an endpoint's sample centre. Exact cell
		# caps preserve shared tile endpoints without widening the segment.
		var size := Vector2.ONE * width
		draw_rect(Rect2(points[0] - size * 0.5, size), color)
		draw_rect(Rect2(points[-1] - size * 0.5, size), color)

func configure(rect: Rect2i, colors: PackedColorArray, floor_alpha: float, bias: float) -> void:
	cell_rect = rect
	ramp = colors
	alpha_floor = floor_alpha
	alpha_bias = bias

func stroke(points: PackedVector2Array, to_cells: Transform2D, core: Color, halo: Color, element: String) -> void:
	if points.size() < 2 or (core.a < alpha_floor and halo.a < alpha_floor): return
	var vertices: PackedVector2Array = to_cells * points
	var snapped := PackedVector2Array()
	snapped.resize(vertices.size())
	for index: int in range(vertices.size()):
		snapped[index] = vertices[index].floor() + Vector2(0.5, 0.5)
	strokes.append({"points": snapped, "vertices": vertices, "core": core, "halo": halo, "element": element})

func flush() -> void:
	if strokes.is_empty():
		_release()
		return
	if viewport == null:
		viewport = SubViewport.new()
		viewport.name = "LinePixels"
		viewport.disable_3d = true
		viewport.transparent_bg = true
		viewport.gui_disable_input = true
		viewport.msaa_2d = Viewport.MSAA_DISABLED
		viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
		add_child(viewport)
		_drawing = StrokeDrawing.new()
		_drawing.lines = self
		_drawing.material = ShaderMaterial.new()
		(_drawing.material as ShaderMaterial).shader = QUANTIZE
		viewport.add_child(_drawing)
		_composite = Sprite2D.new()
		_composite.centered = false
		_composite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_composite.texture = viewport.get_texture()
		add_child(_composite)
	viewport.size = cell_rect.size.max(Vector2i.ONE)
	viewport.global_canvas_transform = Transform2D(0.0, -Vector2(cell_rect.position))
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var shader_material := _drawing.material as ShaderMaterial
	shader_material.set_shader_parameter("ramp", ramp)
	shader_material.set_shader_parameter("alpha_floor", alpha_floor)
	shader_material.set_shader_parameter("alpha_bias", alpha_bias)
	_drawing.queue_redraw()

func _release() -> void:
	if viewport == null: return
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_composite.hide()
	remove_child(_composite)
	remove_child(viewport)
	_composite.queue_free()
	viewport.queue_free()
	_composite = null
	viewport = null
	_drawing = null

## Resolve tail coverage first, then keep a four-connected core to the head.
static func trail_spine(points: PackedVector2Array, ink: PackedColorArray, to_cells: Transform2D,
		floor_alpha: float, thresholds: PackedFloat32Array) -> Dictionary:
	var cells: Array[Vector2i]
	var samples := PackedInt32Array()
	var colors := PackedColorArray()
	var live: bool = false
	if points.size() >= 2 and ink[-1].a >= floor_alpha:
		var start := Vector2i((to_cells * points[0]).floor())
		for index: int in range(1, points.size()):
			var end := Vector2i((to_cells * points[index]).floor())
			var segment: Array[Vector2i] = trail_segment(start, end)
			for offset: int in segment.size():
				var t: float = float(offset) / (segment.size() - 1) if segment.size() > 1 else 1.0
				var color: Color = ink[index - 1].lerp(ink[index], t)
				var cell: Vector2i = segment[offset]
				live = live or trail_cell_visible(color.a, cell, floor_alpha, thresholds)
				if not live: continue
				color.a = 1.0
				if cells.is_empty() or cells[-1] != cell:
					cells.append(cell)
					colors.append(color)
					samples.append(index)
				else:
					colors[-1] = color
					samples[-1] = index
			start = end
	return {"cells": cells, "colors": colors, "samples": samples}

static func trail_segment(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [start]
	var cell: Vector2i = start
	var delta := (end - start).abs()
	var step := (end - start).sign()
	var error: int = delta.x - delta.y
	while cell != end:
		var twice: int = error * 2
		if twice > -delta.y:
			error -= delta.y
			cell.x += step.x
			cells.append(cell)
		if twice < delta.x:
			error += delta.x
			cell.y += step.y
			cells.append(cell)
	return cells

## Resolve the tail once, then group the opaque body and Bayer smear into
## cross-sections on the same cell path. The painter supplies the coverage.
static func trail_profile(batch: Dictionary, to_cells: Transform2D, floor_alpha: float,
		thresholds: PackedFloat32Array, shape: Dictionary, inspect: bool = false) -> Dictionary:
	var bands: Array[Array] = [[], [], []]
	var smear: Array[Array] = [[], []]
	var spine: Array[Vector2i]
	var normals: Array[Vector2i]
	var reaches: Array[int]
	var widths := PackedInt32Array()
	var alpha: float = batch["alpha"]
	var crescent: bool = batch["shape"] == "crescent"
	if alpha >= floor_alpha:
		_profile_spine(batch["points"], batch.get("hilt", PackedVector2Array()), to_cells, alpha, floor_alpha,
			thresholds, float(shape["smear_reach"]), spine, normals, reaches)
	if not spine.is_empty():
		widths = _profile_widths(spine, normals, alpha, floor_alpha, thresholds, shape, crescent)
		_profile_bands(bands, smear, spine, normals, reaches, widths, int(shape["smear_near_cells"]))
	var profile: Dictionary = {"bands": bands, "smear": smear}
	if inspect:
		profile.merge({"spine": spine, "widths": widths, "normals": normals, "reaches": reaches})
	return profile

static func _profile_widths(spine: Array[Vector2i], normals: Array[Vector2i], alpha: float, floor_alpha: float,
		thresholds: PackedFloat32Array, shape: Dictionary, crescent: bool) -> PackedInt32Array:
	var minimum: int = int(shape["sweep_end_cells"] if crescent else shape["streak_tail_cells"])
	var maximum: int = int(shape["sweep_peak_cells"] if crescent else shape["streak_head_cells"])
	var extent: int = maxi(1, spine.size() - 1)
	var middle: int = (spine.size() - 1) / 2
	var widths := PackedInt32Array()
	widths.resize(spine.size())
	for i: int in spine.size():
		var progress: float = float(i) / extent if spine.size() > 1 else 1.0
		var width: int = trail_width(progress, crescent, minimum, maximum)
		if crescent and width >= 3 and alpha < 1.0 and not trail_cell_visible(
				alpha, spine[i] + normals[i] * (width - 1), floor_alpha, thresholds):
			width -= 1
		widths[i] = maxi(width, widths[i - 1]) if i > 0 and i <= middle else width
	if crescent and alpha < 1.0:
		# Let the Bayer cutoff move the boundary of each width tier. Keep
		# each side monotone so fading the last row cannot notch the band.
		for i: int in range(spine.size() - 2, middle, -1):
			widths[i] = maxi(widths[i], widths[i + 1])
	return widths

static func _profile_bands(bands: Array[Array], smear: Array[Array], spine: Array[Vector2i], normals: Array[Vector2i],
		reaches: Array[int], widths: PackedInt32Array, smear_near: int) -> void:
	var run_start: int = 0
	for i: int in range(1, spine.size()):
		var normal: Vector2i = normals[i]
		var step: Vector2i = spine[i] - spine[i - 1]
		var crosses: bool = step.x * normal.x + step.y * normal.y != 0
		if (widths[i] != widths[run_start] or normal != normals[run_start] or crosses
				or reaches[i] != reaches[run_start] or (i > run_start + 1 and step != spine[i - 1] - spine[i - 2])):
			_profile_run(bands, smear, spine[run_start], spine[i - 1], normals[run_start], widths[run_start],
				reaches[run_start], smear_near)
			run_start = i
	_profile_run(bands, smear, spine[run_start], spine[-1], normals[run_start], widths[run_start],
		reaches[run_start], smear_near)

static func trail_width(progress: float, crescent: bool, minimum: int, maximum: int) -> int:
	return maxi(minimum, roundi(maximum * sin(PI * progress))) if crescent else roundi(lerpf(minimum, maximum, progress))

static func _profile_spine(points: PackedVector2Array, hilt: PackedVector2Array, to_cells: Transform2D,
		alpha: float, floor_alpha: float, thresholds: PackedFloat32Array, smear_reach: float,
		spine: Array[Vector2i], normals: Array[Vector2i], reaches: Array[int]) -> void:
	var live: bool = false
	var crescent: bool = not hilt.is_empty()
	var transformed: PackedVector2Array = to_cells * points
	var sample_intervals: int = transformed.size() - 1
	# Earlier samples cannot pass the floor on any Bayer cell.
	var first_coverage: float = pow(floor_alpha / alpha, 1.0 / 1.3) if crescent else 0.30 * floor_alpha / alpha
	var first_segment: int = maxi(1, floori(first_coverage * sample_intervals))
	var previous := Vector2i(transformed[first_segment - 1].floor())
	for i: int in range(first_segment, transformed.size()):
		var end := Vector2i(transformed[i].floor())
		if live and previous == end: continue
		var tangent: Vector2 = transformed[i] - transformed[i - 1]
		var inward := Vector2(-tangent.y, tangent.x)
		var blade: Vector2 = to_cells.basis_xform(hilt[i]) if crescent else Vector2.ZERO
		if inward.dot(blade) < 0.0:
			inward = -inward
		var normal: Vector2i = cardinal_axis(inward)
		if normal == Vector2i.ZERO:
			normal = normals[-1] if not normals.is_empty() else Vector2i.UP
		# Use the blade length for the depth cap, even edge-on. Its
		# perpendicular projection would collapse the Warden's smear.
		var reach: int = floori(blade.length() * smear_reach)
		var segment: Array[Vector2i] = Geometry2D.bresenham_line(previous, end)
		for j: int in segment.size():
			var cell: Vector2i = segment[j]
			if not live:
				var fraction: float = float(j) / (segment.size() - 1) if segment.size() > 1 else 1.0
				var progress: float = (float(i - 1) + fraction) / sample_intervals
				var coverage: float = alpha * (pow(progress, 1.3) if crescent else minf(1.0, progress / 0.30))
				live = trail_cell_visible(coverage, cell, floor_alpha, thresholds)
				if not live: continue
			if not spine.is_empty() and cell == spine[-1]: continue
			if spine.size() >= 2 and _redundant_corner(spine[-2], spine[-1], cell):
				spine[-1] = cell
				normals[-1] = normal
				reaches[-1] = reach
			else:
				spine.append(cell)
				normals.append(normal)
				reaches.append(reach)
		previous = end

static func _redundant_corner(first: Vector2i, middle: Vector2i, last: Vector2i) -> bool:
	if (last - first).abs() != Vector2i.ONE: return false
	var step: Vector2i = (middle - first).abs()
	return step.x + step.y == 1

static func _profile_run(bands: Array[Array], smear: Array[Array], first: Vector2i, last: Vector2i,
		inward: Vector2i, width: int, reach: int, smear_near: int) -> void:
	var origin: Vector2i = first.min(last)
	var size: Vector2i = (last - first).abs() + Vector2i.ONE
	bands[2].append(Rect2i(origin, size))
	var middle: int = mini(2, width - 1)
	if middle > 0: bands[1].append(_offset_span(origin, size, inward, 1, middle))
	if width > 3: bands[0].append(_offset_span(origin, size, inward, 3, width - 3))
	var smear_cells: int = reach - width + 1
	if smear_cells <= 0: return
	var near: int = mini(smear_near, smear_cells)
	smear[0].append(_offset_span(origin, size, inward, width, near))
	if smear_cells > near:
		smear[1].append(_offset_span(origin, size, inward, width + near, smear_cells - near))

static func _offset_span(origin: Vector2i, size: Vector2i, inward: Vector2i, start: int, count: int) -> Rect2i:
	var a: Vector2i = origin + inward * start
	var b: Vector2i = a + inward * (count - 1)
	return Rect2i(a.min(b), size + inward.abs() * (count - 1))

# Cells are ordered by lifetime. The z coordinate is the authored ramp step.
const TRAIL_STAR_CELLS: Array[Vector3i] = [
	Vector3i(0, 0, 4),
	Vector3i(-1, 0, 4), Vector3i(1, 0, 4), Vector3i(0, -1, 4), Vector3i(0, 1, 4),
	Vector3i(-2, 0, 3), Vector3i(2, 0, 3), Vector3i(0, -2, 3), Vector3i(0, 2, 3),
	Vector3i(-3, 0, 2), Vector3i(3, 0, 2), Vector3i(0, -3, 2), Vector3i(0, 3, 2),
	Vector3i(-1, -1, 3), Vector3i(1, -1, 3), Vector3i(-1, 1, 3), Vector3i(1, 1, 3),
]

static func trail_star_cell_count(age: float) -> int:
	if age < 0.4: return TRAIL_STAR_CELLS.size()
	return 9 if age < 0.7 else 5

static func cardinal_axis(direction: Vector2) -> Vector2i:
	return Vector2i(int(signf(direction.x)), 0) if absf(direction.x) >= absf(direction.y) else Vector2i(0, int(signf(direction.y)))

static func trail_cell_visible(alpha: float, cell: Vector2i, floor_alpha: float, thresholds: PackedFloat32Array) -> bool:
	return alpha >= 1.0 or (alpha >= floor_alpha and alpha > thresholds[(cell.y & 3) * 4 + (cell.x & 3)])
