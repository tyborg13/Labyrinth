extends Control

# Soft top and bottom gradient bands beneath the HUD. They give the title bar
# and the hand/action dock a surface to rest on, so HUD elements read as part
# of a frame instead of floating over the dungeon.

const TOP_BAND_HEIGHT: float = 150.0
const TOP_BAND_ALPHA: float = 0.78
const TOP_BAND_CENTER_WEIGHT: float = 0.18
const BOTTOM_BAND_HEIGHT: float = 360.0
const BOTTOM_BAND_ALPHA: float = 0.82
const INK := Color(0.030, 0.022, 0.018)

var show_bottom_band: bool = false:
	set(value):
		if show_bottom_band == value:
			return
		show_bottom_band = value
		queue_redraw()

func _ready() -> void:
	name = "HudSeatScrim"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_draw_top_band(minf(TOP_BAND_HEIGHT, size.y * 0.2))
	if show_bottom_band:
		var height: float = minf(BOTTOM_BAND_HEIGHT, size.y * 0.38)
		_draw_band(size.y - height, size.y, 0.0, BOTTOM_BAND_ALPHA)

# The top band seats the title (left) and utility buttons (right); it thins
# toward the centre so board-owned status text there stays bright.
func _draw_top_band(height: float) -> void:
	var columns: int = 16
	var rows: int = 8
	for column: int in range(columns):
		var x_a: float = size.x * float(column) / float(columns)
		var x_b: float = size.x * float(column + 1) / float(columns)
		var weight_a: float = _edge_weight(x_a / size.x)
		var weight_b: float = _edge_weight(x_b / size.x)
		for row: int in range(rows):
			var t_a: float = float(row) / float(rows)
			var t_b: float = float(row + 1) / float(rows)
			var alpha_a: float = TOP_BAND_ALPHA * (1.0 - _ease(t_a, true))
			var alpha_b: float = TOP_BAND_ALPHA * (1.0 - _ease(t_b, true))
			var y_a: float = height * t_a
			var y_b: float = height * t_b
			draw_polygon(
				PackedVector2Array([Vector2(x_a, y_a), Vector2(x_b, y_a), Vector2(x_b, y_b), Vector2(x_a, y_b)]),
				PackedColorArray([Color(INK, alpha_a * weight_a), Color(INK, alpha_a * weight_b), Color(INK, alpha_b * weight_b), Color(INK, alpha_b * weight_a)])
			)

func _edge_weight(u: float) -> float:
	return lerpf(TOP_BAND_CENTER_WEIGHT, 1.0, smoothstep(0.12, 0.34, absf(u - 0.5)))

func _draw_band(top: float, bottom: float, top_alpha: float, bottom_alpha: float) -> void:
	# Eased ramp: several stops so the fade has no visible banding edge.
	var stops: int = 8
	for index: int in range(stops):
		var a: float = float(index) / float(stops)
		var b: float = float(index + 1) / float(stops)
		var alpha_a: float = lerpf(top_alpha, bottom_alpha, _ease(a, top_alpha > bottom_alpha))
		var alpha_b: float = lerpf(top_alpha, bottom_alpha, _ease(b, top_alpha > bottom_alpha))
		var y_a: float = lerpf(top, bottom, a)
		var y_b: float = lerpf(top, bottom, b)
		draw_polygon(
			PackedVector2Array([Vector2(0.0, y_a), Vector2(size.x, y_a), Vector2(size.x, y_b), Vector2(0.0, y_b)]),
			PackedColorArray([Color(INK, alpha_a), Color(INK, alpha_a), Color(INK, alpha_b), Color(INK, alpha_b)])
		)

func _ease(t: float, fading_out: bool) -> float:
	# Keep the dense end dense and let the open end dissolve gently.
	return 1.0 - pow(1.0 - t, 2.2) if fading_out else pow(t, 2.2)
