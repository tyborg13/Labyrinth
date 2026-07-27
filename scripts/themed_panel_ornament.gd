extends Control

const AssetLoader = preload("res://scripts/asset_loader.gd")

const VARIANT_DIALOG: String = "dialog"
const VARIANT_PARCHMENT: String = "parchment"
const VARIANT_HUD: String = "hud"
const VARIANT_CHOICE: String = "choice"
const VARIANT_DANGER: String = "danger"

const FRAME_ATLAS_PATH: String = "res://assets/art/ui/umbra_frame_kit_v1.png"
const FRAME_ATLAS_SIZE := Vector2(1536.0, 1024.0)

# Authored pieces are kept at one uniform scale per surface. Rails use small
# straight source sections and are repeated/cropped instead of stretched.
# Stop at x=400. The following atlas strip belongs to the independent center
# rail and otherwise leaks into this region as a detached orange line.
const TOP_LEFT_REGION := Rect2(Vector2(70.0, 40.0), Vector2(330.0, 380.0))
const TOP_RIGHT_REGION := Rect2(Vector2(1128.0, 40.0), Vector2(340.0, 380.0))
const BOTTOM_LEFT_REGION := Rect2(Vector2(65.0, 570.0), Vector2(320.0, 395.0))
const BOTTOM_RIGHT_REGION := Rect2(Vector2(1170.0, 570.0), Vector2(300.0, 395.0))
const HORIZONTAL_RAIL_TILE_REGION := Rect2(Vector2(700.0, 348.0), Vector2(64.0, 70.0))
const VERTICAL_RAIL_TILE_REGION := Rect2(Vector2(682.0, 575.0), Vector2(54.0, 80.0))

var _panel: PanelContainer
var _variant: String = VARIANT_DIALOG
var _frame_atlas: Texture2D

func configure(panel: PanelContainer, variant: String) -> void:
	_panel = panel
	_variant = variant
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	var outer_frame_only: bool = bool(panel.get_meta("panel_outer_frame_only", false))
	show_behind_parent = not outer_frame_only
	z_index = 0 if outer_frame_only and get_parent() is Node2D else (1 if outer_frame_only else 0)
	if outer_frame_only and get_parent() is Node2D:
		sync_outer_frame_rect()
	else:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame_atlas = AssetLoader.load_texture(FRAME_ATLAS_PATH)
	var resize_callback := Callable(self, "sync_outer_frame_rect")
	if not panel.resized.is_connected(resize_callback):
		panel.resized.connect(resize_callback)
	queue_redraw()

func set_variant(variant: String) -> void:
	_variant = variant
	queue_redraw()

func sync_outer_frame_rect() -> void:
	if _panel == null:
		return
	if bool(_panel.get_meta("panel_outer_frame_only", false)) and get_parent() is Node2D:
		position = Vector2.ZERO
		size = _panel.size
	queue_redraw()

func _draw() -> void:
	if _panel == null or size.x < 48.0 or size.y < 36.0:
		return
	if bool(_panel.get_meta("panel_outer_frame_only", false)):
		if _frame_atlas != null:
			var outer_frame_scale: float = _frame_scale()
			_draw_rails(outer_frame_scale)
			_draw_corners(outer_frame_scale)
		return
	var palette: Dictionary = _palette()
	var cut: float = clampf(minf(size.x, size.y) * 0.035, 9.0, 22.0)
	var body_rect := Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0))
	var body_points: PackedVector2Array = _cut_corner_points(body_rect, cut)
	draw_colored_polygon(_offset_points(body_points, Vector2(0.0, 12.0)), Color(0.0, 0.0, 0.0, 0.62))
	draw_colored_polygon(body_points, palette["outer"])
	if bool(_panel.get_meta("panel_hovered", false)):
		var accent: Color = Color(_panel.get_meta("panel_surface_accent", Color("efbd66")))
		draw_polyline(_closed_points(body_points), Color(accent.r, accent.g, accent.b, 0.92), 4.0, true)
	var inset_rect := body_rect.grow(-8.0)
	var inset_points: PackedVector2Array = _cut_corner_points(inset_rect, maxf(4.0, cut - 5.0))
	draw_colored_polygon(inset_points, palette["inner"])
	if _panel.has_meta("panel_surface_accent"):
		var surface_accent: Color = Color(_panel.get_meta("panel_surface_accent"))
		var accent_alpha: float = 0.78 if bool(_panel.get_meta("panel_hovered", false)) else 0.40
		draw_polyline(
			_closed_points(inset_points),
			Color(surface_accent.r, surface_accent.g, surface_accent.b, accent_alpha),
			2.0,
			true
		)
	if _frame_atlas == null:
		return
	var frame_scale: float = _frame_scale()
	_draw_rails(frame_scale)
	_draw_corners(frame_scale)

func _draw_rails(frame_scale: float) -> void:
	var horizontal_size: Vector2 = HORIZONTAL_RAIL_TILE_REGION.size * frame_scale
	var vertical_size: Vector2 = VERTICAL_RAIL_TILE_REGION.size * frame_scale
	var corner_clearance: float = 72.0 * frame_scale / 0.30
	var horizontal_start: float = corner_clearance
	var horizontal_end: float = size.x - corner_clearance
	var top_y: float = -2.0
	var bottom_y: float = size.y - horizontal_size.y + 2.0
	var header_gap := Rect2()
	if _panel != null and _panel.has_meta("panel_header_banner_rect"):
		header_gap = Rect2(_panel.get_meta("panel_header_banner_rect"))
	if header_gap.size.x > 0.0:
		var gap_left: float = clampf(header_gap.position.x + 14.0, horizontal_start, horizontal_end)
		var gap_right: float = clampf(header_gap.end.x - 14.0, horizontal_start, horizontal_end)
		_draw_repeated_horizontal(horizontal_start, gap_left, top_y, frame_scale)
		_draw_repeated_horizontal(gap_right, horizontal_end, top_y, frame_scale)
	else:
		_draw_repeated_horizontal(horizontal_start, horizontal_end, top_y, frame_scale)
	_draw_repeated_horizontal(horizontal_start, horizontal_end, bottom_y, frame_scale)
	var vertical_start: float = corner_clearance
	var vertical_end: float = size.y - corner_clearance
	var left_x: float = -2.0
	var right_x: float = size.x - vertical_size.x + 2.0
	_draw_repeated_vertical(left_x, vertical_start, vertical_end, frame_scale)
	_draw_repeated_vertical(right_x, vertical_start, vertical_end, frame_scale)

func _draw_repeated_horizontal(start_x: float, end_x: float, y: float, frame_scale: float) -> void:
	var source_width: float = HORIZONTAL_RAIL_TILE_REGION.size.x
	var tile_width: float = source_width * frame_scale
	var tile_height: float = HORIZONTAL_RAIL_TILE_REGION.size.y * frame_scale
	var cursor: float = start_x
	while cursor < end_x - 0.1:
		var remaining: float = end_x - cursor
		var draw_width: float = minf(tile_width, remaining)
		var source_draw_width: float = draw_width / frame_scale
		var source_rect := Rect2(HORIZONTAL_RAIL_TILE_REGION.position, Vector2(source_draw_width, HORIZONTAL_RAIL_TILE_REGION.size.y))
		draw_texture_rect_region(
			_frame_atlas,
			Rect2(Vector2(cursor, y), Vector2(draw_width, tile_height)),
			source_rect
		)
		cursor += draw_width

func _draw_repeated_vertical(x: float, start_y: float, end_y: float, frame_scale: float) -> void:
	var source_height: float = VERTICAL_RAIL_TILE_REGION.size.y
	var tile_width: float = VERTICAL_RAIL_TILE_REGION.size.x * frame_scale
	var tile_height: float = source_height * frame_scale
	var cursor: float = start_y
	while cursor < end_y - 0.1:
		var remaining: float = end_y - cursor
		var draw_height: float = minf(tile_height, remaining)
		var source_draw_height: float = draw_height / frame_scale
		var source_rect := Rect2(VERTICAL_RAIL_TILE_REGION.position, Vector2(VERTICAL_RAIL_TILE_REGION.size.x, source_draw_height))
		draw_texture_rect_region(
			_frame_atlas,
			Rect2(Vector2(x, cursor), Vector2(tile_width, draw_height)),
			source_rect
		)
		cursor += draw_height

func _draw_corners(frame_scale: float) -> void:
	var top_left_size: Vector2 = TOP_LEFT_REGION.size * frame_scale
	var top_right_size: Vector2 = TOP_RIGHT_REGION.size * frame_scale
	var bottom_left_size: Vector2 = BOTTOM_LEFT_REGION.size * frame_scale
	var bottom_right_size: Vector2 = BOTTOM_RIGHT_REGION.size * frame_scale
	var overhang: float = 11.0 if _variant != VARIANT_HUD else 6.0
	draw_texture_rect_region(
		_frame_atlas,
		Rect2(Vector2(-overhang, -overhang), top_left_size),
		TOP_LEFT_REGION
	)
	draw_texture_rect_region(
		_frame_atlas,
		Rect2(Vector2(size.x - top_right_size.x + overhang, -overhang), top_right_size),
		TOP_RIGHT_REGION
	)
	draw_texture_rect_region(
		_frame_atlas,
		Rect2(Vector2(-overhang, size.y - bottom_left_size.y + overhang), bottom_left_size),
		BOTTOM_LEFT_REGION
	)
	draw_texture_rect_region(
		_frame_atlas,
		Rect2(Vector2(size.x - bottom_right_size.x + overhang, size.y - bottom_right_size.y + overhang), bottom_right_size),
		BOTTOM_RIGHT_REGION
	)

func _frame_scale() -> float:
	if _panel != null and _panel.has_meta("panel_frame_scale"):
		return clampf(float(_panel.get_meta("panel_frame_scale")), 0.12, 0.34)
	var scale_value: float = 0.30
	match _variant:
		VARIANT_HUD:
			scale_value = 0.21
		VARIANT_CHOICE:
			scale_value = 0.28
		VARIANT_DANGER:
			scale_value = 0.30
		VARIANT_PARCHMENT:
			scale_value = 0.31
	var short_side_factor: float = clampf(minf(size.x, size.y) / 220.0, 0.58, 1.0)
	return scale_value * short_side_factor

func _palette() -> Dictionary:
	var outer := Color("2b1b17")
	var inner := Color(0.034, 0.025, 0.028, 0.985)
	if _variant == VARIANT_PARCHMENT:
		outer = Color("3b2418")
		inner = Color(0.095, 0.055, 0.035, 0.98)
	elif _variant == VARIANT_HUD:
		outer = Color("211b1b")
		inner = Color(0.025, 0.022, 0.027, 0.95)
	elif _variant == VARIANT_CHOICE:
		outer = Color("372118")
		inner = Color(0.070, 0.040, 0.030, 0.98)
	elif _variant == VARIANT_DANGER:
		outer = Color("381719")
		inner = Color(0.075, 0.022, 0.028, 0.985)
	return {
		"outer": outer,
		"inner": inner,
	}

func _cut_corner_points(rect: Rect2, cut: float) -> PackedVector2Array:
	var left: float = rect.position.x
	var top: float = rect.position.y
	var right: float = rect.end.x
	var bottom: float = rect.end.y
	return PackedVector2Array([
		Vector2(left + cut, top),
		Vector2(right - cut, top),
		Vector2(right, top + cut),
		Vector2(right, bottom - cut),
		Vector2(right - cut, bottom),
		Vector2(left + cut, bottom),
		Vector2(left, bottom - cut),
		Vector2(left, top + cut),
	])

func _offset_points(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in points:
		result.append(point + offset)
	return result

func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = points.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result
