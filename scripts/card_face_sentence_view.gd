extends Control
## Draws one planned sentence face (scripts/card_face_layout.gd) inside the
## card's rules box: the target chip on a plate in the nameplate's colours,
## the sentence in the rules-text font and ink with inline icons, numbers in
## the simple cards' value style, and pattern diagrams as AoePatternViews.
## Positions are relative to the box's top centre. Hover targets are plain
## children with tooltips, read by CardWidget._tooltip_for_icon_at.

const AoePatternView = preload("res://scripts/aoe_pattern_view.gd")
const FaceSpec = preload("res://scripts/card_face_spec.gd")
const Palette = preload("res://scripts/ui_palette.gd")

const CHIP_RADIUS: float = 6.0
const CHIP_BORDER_WIDTH: float = 1.3
# The approved plate: a light fill inset 3.5 from the edge, softened by a 1.1
# blur over the tan rim. Its edge is fill * c^2 + rim * (1 - c) at coverage c,
# which dips darker than either just inside the rim, as in the mock.
const CHIP_FILL_INSET: float = 3.5
const CHIP_FILL_BLUR: float = 1.1
const CHIP_FILL_STEP: float = 0.3
const CHIP_CORNER_SEGMENTS: int = 6

var _plan: Dictionary = {}
var _style: Dictionary = {}

func _init() -> void:
	name = "SentenceFace"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Inline icons are mipmapped crops; they are drawn at 12-15 screen px.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_meta("card_sentence_face", true)

func plan() -> Dictionary:
	return _plan

func apply(next_plan: Dictionary, style: Dictionary) -> void:
	if next_plan == _plan and style == _style:
		return
	_plan = next_plan
	_style = style
	custom_minimum_size = Vector2(0.0, float(_plan.get("height", 0.0)))
	_rebuild_children()
	queue_redraw()

func _rebuild_children() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var layout_scale: float = float(_style.get("scale", 1.0))
	var chip: Dictionary = _plan.get("chip", {})
	if not chip.is_empty():
		var chip_rect := Rect2(-float(chip["width"]) * 0.5, float(chip["y"]), float(chip["width"]), float(chip["height"]))
		_add_hit("ChipTarget", chip_rect, str(_style.get("chip_tooltip", "")))
	var segment_rects: Dictionary = {}
	for line: Dictionary in _plan.get("lines", []):
		for piece: Dictionary in line["pieces"]:
			if str(piece["kind"]) == "pattern":
				_add_pattern(piece, layout_scale)
				continue
			if not piece.has("segment"):
				continue
			var rect := Rect2(float(piece["x"]), float(line["y"]), float(piece["w"]), float(line["height"]))
			var key: int = int(piece["segment"])
			segment_rects[key] = (segment_rects[key] as Rect2).merge(rect) if segment_rects.has(key) else rect
	for key: Variant in segment_rects:
		_add_hit("Term%d" % int(key), segment_rects[key], str((_style.get("tooltips", {}) as Dictionary).get(key, "")))
	var under: Dictionary = _plan.get("under", {})
	if not under.is_empty():
		for item: Dictionary in under["items"]:
			if str(item["kind"]) == "pattern":
				_add_pattern(item, layout_scale)

func _add_pattern(piece: Dictionary, _layout_scale: float) -> void:
	var view := AoePatternView.new()
	var pattern_id: String = str(piece["pattern"])
	view.setup(FaceSpec.pattern_offsets(pattern_id), FaceSpec.pattern_shows_origin(pattern_id), str(_style.get("pattern_tooltip", "")), float(piece["scale"]))
	view.name = "Pattern_%s" % pattern_id
	_place(view, Rect2(float(piece["x"]), float(piece["y"]), float(piece["w"]), float(piece["h"])))

func _add_hit(node_name: String, rect: Rect2, tooltip: String) -> void:
	var hit := Control.new()
	hit.name = node_name
	hit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit.tooltip_text = tooltip
	_place(hit, rect)

## Children hang from the box's horizontal centre, so they follow its width.
func _place(control: Control, rect: Rect2) -> void:
	control.anchor_left = 0.5
	control.anchor_right = 0.5
	control.anchor_top = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = rect.position.x
	control.offset_right = rect.end.x
	control.offset_top = rect.position.y
	control.offset_bottom = rect.end.y
	add_child(control)

func _draw() -> void:
	if _plan.is_empty():
		return
	var center: float = size.x * 0.5
	var text_font: Font = _style.get("text_font")
	var ui_font: Font = _style.get("ui_font")
	if text_font == null or ui_font == null:
		return
	var ink: Color = _style["ink"]
	var text_size: int = int(_plan["text_size"])
	var chip: Dictionary = _plan.get("chip", {})
	if not chip.is_empty():
		_draw_chip(chip, center, ui_font)
	var numbers: Array = []
	for line: Dictionary in _plan.get("lines", []):
		for piece: Dictionary in line["pieces"]:
			match str(piece["kind"]):
				"icon":
					_draw_icon(str(piece["icon"]), Rect2(center + float(piece["x"]), float(piece["y"]), float(piece["w"]), float(piece["h"])))
				"text":
					draw_string(text_font, Vector2(center + float(piece["x"]), float(piece["baseline"])), str(piece["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, text_size, ink)
				"number":
					numbers.append(piece)
	var under: Dictionary = _plan.get("under", {})
	if not under.is_empty():
		for item: Dictionary in under["items"]:
			if str(item["kind"]) == "arrow":
				draw_string(text_font, Vector2(center + float(item["x"]), float(item["baseline"])), str(item["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, text_size, ink)
	# The simple cards' value style: every outline first, then every numeral.
	var outline: Color = _style["number_outline"]
	var outline_size: int = int(_style.get("number_outline_size", 3))
	var tones: Dictionary = _style.get("tones", {})
	for piece: Dictionary in numbers:
		draw_string_outline(text_font, Vector2(center + float(piece["x"]), float(piece["baseline"])), str(piece["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, text_size, outline_size, outline)
	for piece: Dictionary in numbers:
		var colour: Color = tones.get(int(piece.get("segment", -1)), _style["number_ink"])
		draw_string(text_font, Vector2(center + float(piece["x"]), float(piece["baseline"])), str(piece["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, text_size, colour)

func _draw_icon(icon_key: String, rect: Rect2) -> void:
	var texture: Texture2D = FaceSpec.icon_entry(icon_key)["texture"]
	if texture != null:
		draw_texture_rect(texture, rect, false)

func _draw_chip(chip: Dictionary, center: float, font: Font) -> void:
	var layout_scale: float = float(_style.get("scale", 1.0))
	var rect := Rect2(center - float(chip["width"]) * 0.5, float(chip["y"]), float(chip["width"]), float(chip["height"]))
	var radius: float = CHIP_RADIUS * layout_scale
	var border: float = CHIP_BORDER_WIDTH * layout_scale
	# Half a pixel in, so the antialiased outline ends at the plate's edge.
	var outer: PackedVector2Array = _rounded_rect(rect.grow(-0.5), radius - 0.5)
	draw_colored_polygon(outer, Palette.CARD_CHIP_BORDER)
	draw_polyline(_closed(outer), Palette.CARD_CHIP_BORDER, 1.0, true)
	var rim: Color = Palette.CARD_CHIP_RIM
	var fill: Color = Palette.CARD_CHIP_FILL
	var inset: float = border
	var last: float = (CHIP_FILL_INSET + 2.0 * CHIP_FILL_BLUR) * layout_scale
	while inset < last + 0.001:
		var coverage: float = _normal_cdf((inset / layout_scale + CHIP_FILL_STEP * 0.5 - CHIP_FILL_INSET) / CHIP_FILL_BLUR)
		var colour := Color(fill.r * coverage * coverage + rim.r * (1.0 - coverage), fill.g * coverage * coverage + rim.g * (1.0 - coverage), fill.b * coverage * coverage + rim.b * (1.0 - coverage))
		draw_colored_polygon(_rounded_rect(rect.grow(-inset), maxf(0.5, radius - inset)), colour)
		inset += CHIP_FILL_STEP * layout_scale
	draw_colored_polygon(_rounded_rect(rect.grow(-inset), maxf(0.5, radius - inset)), fill)
	var text_size: int = int(chip["text_size"])
	for item: Dictionary in chip["items"]:
		var x: float = center + float(item["x"])
		match str(item["kind"]):
			"icon":
				_draw_icon(str(item["icon"]), Rect2(x, rect.position.y + float(item["y"]), float(item["w"]), float(item["h"])))
			"number":
				draw_string(font, Vector2(x, rect.position.y + float(item["baseline"])), str(item["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, text_size, _style.get("chip_tone", _style["title_ink"]))
			_:
				draw_string(font, Vector2(x, rect.position.y + float(item["baseline"])), str(item["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, text_size, _style["title_ink"])

static func _normal_cdf(x: float) -> float:
	return 0.5 * (1.0 + tanh(0.7978845608 * (x + 0.044715 * x * x * x)))

func _rounded_rect(rect: Rect2, radius: float) -> PackedVector2Array:
	var r: float = clampf(radius, 0.0, minf(rect.size.x, rect.size.y) * 0.5)
	var points := PackedVector2Array()
	var corners: Array = [
		[Vector2(rect.end.x - r, rect.position.y + r), -PI * 0.5],
		[Vector2(rect.end.x - r, rect.end.y - r), 0.0],
		[Vector2(rect.position.x + r, rect.end.y - r), PI * 0.5],
		[Vector2(rect.position.x + r, rect.position.y + r), PI],
	]
	for corner: Array in corners:
		var origin: Vector2 = corner[0]
		var start: float = float(corner[1])
		for segment: int in range(CHIP_CORNER_SEGMENTS + 1):
			var angle: float = start + PI * 0.5 * float(segment) / float(CHIP_CORNER_SEGMENTS)
			points.append(origin + Vector2(cos(angle), sin(angle)) * r)
	return points

func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array(points)
	if not points.is_empty():
		closed.append(points[0])
	return closed
