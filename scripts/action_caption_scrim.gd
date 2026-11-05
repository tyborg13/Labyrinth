extends "res://scripts/hud_seat_scrim.gd"
## The existing HUD seat scrim, fitted to the shared action caption. As a
## behind-parent child it shares the caption's canvas, visibility and opacity;
## it has no independent motion, fade or lifetime (including Reduced Motion).

const Palette = preload("res://scripts/ui_palette.gd")
const HORIZONTAL_PADDING: float = 48.0
const VERTICAL_PADDING: float = 10.0
const HORIZONTAL_FALLOFF: float = 48.0
const VERTICAL_FALLOFF: float = 6.0
const CAPTION_ALPHA: float = 0.85
# Same subdivision count as HudSeatScrim's existing eased gradient bands.
const FALLOFF_STEPS: int = 8

var _batch_pixel_transform := Transform2D()

func _ready() -> void:
	name = "ActionCaptionScrim"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	set_notify_transform(true)

func caption_text_rect() -> Rect2:
	# Use the caption's laid-out text rectangle, preserving its alignment and
	# existing line height. The fade stays entirely outside this rectangle.
	return Rect2(Vector2.ZERO, size)

func caption_scrim_rect() -> Rect2:
	return caption_text_rect().grow_individual(HORIZONTAL_PADDING, VERTICAL_PADDING, HORIZONTAL_PADDING, VERTICAL_PADDING)

func caption_patches() -> Array[Dictionary]:
	var patches: Array[Dictionary]
	if size.x <= 0.0 or size.y <= 0.0:
		return patches
	var extent: Rect2 = caption_scrim_rect()
	var columns: Array[Vector2] = _falloff_stops(extent.position.x, extent.end.x, HORIZONTAL_FALLOFF)
	var rows: Array[Vector2] = _falloff_stops(extent.position.y, extent.end.y, VERTICAL_FALLOFF)
	for column: int in range(columns.size() - 1):
		for row: int in range(rows.size() - 1):
			var left: Vector2 = columns[column]
			var right: Vector2 = columns[column + 1]
			var top: Vector2 = rows[row]
			var bottom: Vector2 = rows[row + 1]
			patches.append({
				"rect": Rect2(Vector2(left.x, top.x), Vector2(right.x - left.x, bottom.x - top.x)),
				"colours": PackedColorArray([
					Color(Palette.INK_0, CAPTION_ALPHA * left.y * top.y),
					Color(Palette.INK_0, CAPTION_ALPHA * right.y * top.y),
					Color(Palette.INK_0, CAPTION_ALPHA * right.y * bottom.y),
					Color(Palette.INK_0, CAPTION_ALPHA * left.y * bottom.y)
				])
			})
	return patches

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var pixel_transform: Transform2D = get_viewport().get_stretch_transform() * get_global_transform_with_canvas()
	if _batch == null or _batch_size != size or _batch_pixel_transform != pixel_transform:
		_batch = DrawBatch.new()
		_batch_pixel_transform = pixel_transform
		_build_batch()
		_batch.seal()
		_batch_size = size
	_batch.draw_on(self)

func _build_batch() -> void:
	var patches: Array[Dictionary] = caption_patches()
	if not _columns_have_separate_pixels(patches):
		# With fractional/rotated columns, even neighbouring columns can share
		# a pixel's MSAA samples. Preserve every original draw boundary/order.
		for patch: Dictionary in patches:
			_batch.native_polygon(_patch_points(patch), patch["colours"])
		return
	# 4x MSAA can round a shared pixel differently when adjacent subpixel
	# gradient rows become one draw (observed as a one-byte alpha difference).
	# Keep a draw boundary per row. Integer-aligned columns share no pixels,
	# so collecting their patches into each row preserves per-pixel order.
	var rows: Dictionary = {}
	for patch: Dictionary in patches:
		var top: float = (patch["rect"] as Rect2).position.y
		if not rows.has(top): rows[top] = []
		rows[top].append(patch)
	for top: float in rows:
		for patch: Dictionary in rows[top]:
			_batch.polygon(_patch_points(patch), patch["colours"])
		_batch.seal()

func _columns_have_separate_pixels(patches: Array[Dictionary]) -> bool:
	if _batch_pixel_transform.x.y != 0.0 or _batch_pixel_transform.y.x != 0.0 or _batch_pixel_transform.x.x <= 0.0:
		return false
	for patch: Dictionary in patches:
		var rect: Rect2 = patch["rect"]
		var left: float = (_batch_pixel_transform * rect.position).x
		var right: float = (_batch_pixel_transform * rect.end).x
		if left != floorf(left) or right != floorf(right):
			return false
	return true

func _patch_points(patch: Dictionary) -> PackedVector2Array:
	var rect: Rect2 = patch["rect"]
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])

func _falloff_stops(start: float, end: float, width: float) -> Array[Vector2]:
	var stops: Array[Vector2]
	for index: int in range(FALLOFF_STEPS + 1):
		var t: float = float(index) / float(FALLOFF_STEPS)
		stops.append(Vector2(start + width * t, _ease(t, false)))
	stops.append(Vector2(end - width, 1.0))
	for index: int in range(1, FALLOFF_STEPS + 1):
		var t: float = float(index) / float(FALLOFF_STEPS)
		stops.append(Vector2(end - width + width * t, 1.0 - _ease(t, true)))
	return stops
