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
