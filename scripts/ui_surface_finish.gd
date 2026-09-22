extends Node2D

# Retained material light, underneath content and inside the existing silhouette.
# No processing, input, minimum size, or layout participation. Grain is shared
# across every page and generated once; it never swims with time or focus.
static var _paper_grain: Texture2D
var _panel: PanelContainer
var _kind: String = "dialog"

func configure(panel: PanelContainer, kind: String) -> void:
	_panel = panel
	_kind = kind
	if kind.begins_with("paper"):
		_grain() # Warm while the hidden Grimoire is built, never on first open.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var redraw := Callable(self, "queue_redraw")
	if not panel.resized.is_connected(redraw):
		panel.resized.connect(redraw)
	queue_redraw()

func _draw() -> void:
	if _panel == null or _panel.size.x < 24.0 or _panel.size.y < 24.0:
		return
	var rect := Rect2(Vector2(5.0, 5.0), _panel.size - Vector2(10.0, 10.0))
	if _kind.begins_with("paper"):
		_draw_paper(rect)
	else:
		draw_dark_well(self, _quad(rect), rect, _kind)

static func draw_dark_well(canvas: CanvasItem, points: PackedVector2Array, rect: Rect2, kind: String) -> void:
	# The slight warm top reflection and cool lower falloff make a shallow well,
	# while leaving the middle quiet for labels and exact rules text.
	var strength: float = 0.055 if kind == "hud" else 0.085
	var colors := PackedColorArray()
	for point: Vector2 in points:
		var uv: Vector2 = (point - rect.position) / rect.size
		var light: float = (1.0 - uv.y) * (0.55 + 0.45 * (1.0 - uv.x))
		colors.append(Color(0.91, 0.62, 0.31, strength * light))
	canvas.draw_polygon(points, colors)
	colors.clear()
	for point: Vector2 in points:
		var v: float = (point.y - rect.position.y) / rect.size.y
		colors.append(Color(0.005, 0.007, 0.015, v * 0.26))
	canvas.draw_polygon(points, colors)
	# Soft inner occlusion stays entirely inside the established bounds.
	for index: int in range(3):
		var inset: float = float(index) + 0.5
		var edge := rect.grow(-inset)
		canvas.draw_line(edge.position + Vector2(7.0, 0.0), Vector2(edge.end.x - 7.0, edge.position.y), Color(0.0, 0.0, 0.0, 0.12 - index * 0.025), 1.0, true)
	canvas.draw_line(Vector2(rect.position.x + 9.0, rect.end.y - 1.0), rect.end - Vector2(9.0, 1.0), Color(0.73, 0.58, 0.40, 0.10), 1.0, true)

func _draw_paper(rect: Rect2) -> void:
	var right_page: bool = _kind == "paper_right"
	# Broad reflected light gives the leaf a gentle crown, with a darker bound
	# edge. It is a surface treatment, not a new frame or a page-curl animation.
	var crown := PackedColorArray([
		Color(1.0, 0.91, 0.70, 0.12), Color(1.0, 0.94, 0.77, 0.20),
		Color(0.48, 0.28, 0.11, 0.10), Color(0.48, 0.28, 0.11, 0.13)
	])
	draw_polygon(_quad(rect), crown)
	draw_texture_rect(_grain(), rect, true, Color(1.0, 1.0, 1.0, 0.30))
	var fold_width: float = minf(36.0, rect.size.x * 0.10)
	var fold := Rect2(rect.position if right_page else Vector2(rect.end.x - fold_width, rect.position.y), Vector2(fold_width, rect.size.y))
	var shade := Color(0.25, 0.12, 0.04, 0.24)
	var clear := Color(0.25, 0.12, 0.04, 0.0)
	draw_polygon(_quad(fold), PackedColorArray([shade, clear, clear, shade]) if right_page else PackedColorArray([clear, shade, shade, clear]))
	var edge_x: float = rect.position.x + 1.0 if right_page else rect.end.x - 1.0
	draw_line(Vector2(edge_x, rect.position.y + 3.0), Vector2(edge_x, rect.end.y - 3.0), Color(0.32, 0.17, 0.07, 0.25), 1.0, true)
	# A pair of quiet leaf edges adds thickness without changing content bounds.
	for index: int in range(2):
		var y: float = rect.end.y - 1.0 - float(index) * 2.0
		draw_line(Vector2(rect.position.x + 5.0, y), Vector2(rect.end.x - 5.0, y), Color(0.44, 0.25, 0.10, 0.15), 1.0, true)
	draw_line(rect.position + Vector2(4.0, 1.0), Vector2(rect.end.x - 4.0, rect.position.y + 1.0), Color(1.0, 0.94, 0.75, 0.38), 1.0, true)

static func _quad(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])

static func _grain() -> Texture2D:
	if _paper_grain != null:
		return _paper_grain
	var noise := FastNoiseLite.new()
	noise.seed = 7319
	noise.frequency = 0.035
	noise.fractal_octaves = 3
	var pixels := Image.create(384, 384, false, Image.FORMAT_RGBA8)
	for y: int in range(384):
		for x: int in range(384):
			var fiber: float = float((x * 73 + y * 137 + x * y * 19) % 103) / 102.0
			# Blend opposite samples so the retained grain tiles without seams.
			var u: float = smoothstep(0.0, 383.0, float(x))
			var v: float = smoothstep(0.0, 383.0, float(y))
			var upper: float = lerpf(noise.get_noise_2d(x, y), noise.get_noise_2d(x - 383, y), u)
			var lower: float = lerpf(noise.get_noise_2d(x, y - 383), noise.get_noise_2d(x - 383, y - 383), u)
			var cloud: float = lerpf(upper, lower, v)
			var grain: float = clampf(0.5 + cloud * 0.55 + (fiber - 0.5) * 0.32, 0.0, 1.0)
			pixels.set_pixel(x, y, Color(0.34, 0.20, 0.075, grain * 0.28))
	_paper_grain = ImageTexture.create_from_image(pixels)
	return _paper_grain
