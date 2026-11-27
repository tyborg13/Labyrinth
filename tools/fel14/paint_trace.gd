extends RefCounted
## Receipts for retained CanvasItems. The wrappers submit the original command
## first and keep a local-space copy for software alpha measurement.

static var canvases: Dictionary = {}
static var active: Array[Dictionary] = []
static var transforms: Dictionary = {}
static var beat: Dictionary = {}
static var displayed: Dictionary = {}
static var beat_number: int = 0
static var tracking: bool = false
static var fps: int = 60
static var origin_frame: int = 0
static var numeral_band: int = 0
static var feedback_band: int = 0

class Scope extends RefCounted:
	var close: Callable
	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE and close.is_valid(): close.call()

static func reset() -> void:
	canvases.clear()
	active.clear()
	transforms.clear()
	beat = {}
	displayed = {}
	beat_number = 0
	tracking = false
	origin_frame = Engine.get_process_frames()

static func usec() -> int:
	return 1000000 + roundi((Engine.get_process_frames() - origin_frame) * 1000000.0 / fps)

static func next_beat(step: Dictionary) -> void:
	if not tracking: return
	beat = {}
	var kind: String = str(step.get("kind", ""))
	if kind in ["commit", "trace_state"] or step.get("cascade_bookkeeping", false) or step.get("analytics_only", false):
		return
	if step.get("hidden_by_umbra", false) and kind not in ["burrow", "erupt"]: return
	beat_number += 1
	beat = {"number": beat_number, "kind": kind, "action": str(step.get("action_type", "")),
		"actor": str(step.get("actor_key", "")), "caption": str(step.get("turn_caption", ""))}

static func submitted() -> void:
	if tracking and not beat.is_empty() and displayed != beat:
		displayed = beat

static func end_beats() -> void:
	beat = {}
	displayed = {}

static func boss_key(board: Control) -> String:
	for unit: Dictionary in board.call("_visible_units"):
		if bool(unit.get("boss_bar", false)): return str(unit.get("key", ""))
	return ""

static func finish_glyphs() -> void:
	if not active.is_empty(): active.back()["record_glyph"] = false

static func resume_glyphs() -> void:
	if not active.is_empty(): active.back()["record_glyph"] = true

static func clear(canvas: CanvasItem) -> void:
	var id: int = canvas.get_instance_id()
	canvases.erase(id)
	transforms.erase(id)

static func begin(view: Object, kind: String, owner: Variant, detail: String = "", popup: Dictionary = {}) -> Scope:
	var canvas: CanvasItem = _canvas(view)
	var id: int = canvas.get_instance_id()
	var rows: Array = canvases.get_or_add(id, [])
	var row: Dictionary = {"kind": kind, "owner": _owner(owner), "detail": detail,
		"sequence": rows.size(), "ink": [], "text": [], "popup": popup}
	rows.append(row)
	active.append(row)
	var scope := Scope.new()
	scope.close = _end
	return scope

static func _end() -> void:
	active.pop_back()

static func _owner(value: Variant) -> Dictionary:
	if value is Dictionary:
		var tile: Vector2i = value.get("pos", value.get("tile", Vector2i(-1, -1)))
		return {"id": str(value.get("unit_anchor_key", value.get("key", value.get("id", "")))), "tile": [tile.x, tile.y]}
	if value is Vector2i: return {"id": "", "tile": [value.x, value.y]}
	return {"id": str(value), "tile": []}

static func _canvas(view: Object) -> CanvasItem:
	if view is CanvasItem: return view
	return view.get("view") as CanvasItem

static func popup(view: CanvasItem, data: Dictionary) -> Scope:
	var entry: Dictionary = data["entry"]
	var kind: String = "damage" if entry.get("kind") == "damage" else str(entry.get("resource_kind", "effect"))
	if kind.is_empty(): kind = "effect"
	var scope: Scope = begin(view, kind + "_popup", entry, str(entry.get("text", "")),
		{"key": data["key"], "progress": entry.get("animation_progress", 0.0),
		"size": float(data["font_scale"]) * float(entry.get("font_size", 16)), "alpha": entry.get("alpha", 1.0)})
	active.back()["band"] = feedback_band
	return scope

static func _ink(view: Object, primitive: Array, alpha: float, glyph: bool = false) -> void:
	if active.is_empty() or alpha <= 0.0: return
	var canvas: CanvasItem = _canvas(view)
	if view != canvas: alpha *= float(view.get("alpha"))
	if alpha <= 0.0: return
	var row: Dictionary = active.back()
	(row["ink"] as Array).append([primitive, transforms.get(canvas.get_instance_id(), Transform2D.IDENTITY), alpha, glyph and bool(row.get("record_glyph", true)), int(row.get("band", 0))])

static func draw_set_transform(view: Object, pos: Vector2, rotation: float = 0.0, scale: Vector2 = Vector2.ONE) -> void:
	view.draw_set_transform(pos, rotation, scale)
	transforms[_canvas(view).get_instance_id()] = Transform2D(rotation, scale, 0.0, pos)

static func draw_set_transform_matrix(view: Object, xform: Transform2D) -> void:
	view.draw_set_transform_matrix(xform)
	transforms[_canvas(view).get_instance_id()] = xform

static func draw_string(view: Object, font: Font, pos: Vector2, value: String, align: int = 0, width: float = -1.0, size: int = 16, color: Color = Color.WHITE) -> void:
	view.draw_string(font, pos, value, align, width, size, color)
	_record_string(view, font, pos, value, align, width, size, color)

static func _record_string(view: Object, font: Font, pos: Vector2, value: String, align: int, width: float, size: int, color: Color) -> void:
	_ink(view, ["text", font, pos, value, align, width, size, 0], color.a, true)
	if not active.is_empty() and not value.is_empty() and not (active.back()["text"] as Array).has(value):
		active.back()["text"].append(value)

static func draw_string_outline(view: Object, font: Font, pos: Vector2, value: String, align: int = 0, width: float = -1.0, size: int = 16, outline: int = 1, color: Color = Color.WHITE) -> void:
	view.draw_string_outline(font, pos, value, align, width, size, outline, color)
	_ink(view, ["text", font, pos, value, align, width, size, outline], color.a)

static func draw_texture_rect(view: Object, texture: Texture2D, rect: Rect2, tile: bool, color: Color = Color.WHITE, transpose: bool = false) -> void:
	view.draw_texture_rect(texture, rect, tile, color, transpose)
	texture_ink(view, texture, rect, Rect2(), color.a)

static func draw_texture(view: Object, texture: Texture2D, pos: Vector2, color: Color = Color.WHITE) -> void:
	view.draw_texture(texture, pos, color)
	texture_ink(view, texture, Rect2(pos, texture.get_size()), Rect2(), color.a)

static func draw_texture_rect_region(view: Object, texture: Texture2D, rect: Rect2, src: Rect2, color: Color = Color.WHITE, transpose: bool = false, clip_uv: bool = true) -> void:
	# OpacityInk exposes the four-argument form.
	if view is CanvasItem: view.draw_texture_rect_region(texture, rect, src, color, transpose, clip_uv)
	else: view.draw_texture_rect_region(texture, rect, src, color)
	texture_ink(view, texture, rect, src, color.a)

static func texture_ink(view: Object, texture: Texture2D, rect: Rect2, src: Rect2, alpha: float, glyph: bool = true) -> void:
	if texture != null: _ink(view, ["texture", rect, texture, src], alpha, glyph)

static func draw_rect(view: Object, rect: Rect2, color: Color, filled: bool = true, width: float = -1.0, aa: bool = false) -> void:
	view.draw_rect(rect, color, filled, width, aa)
	_ink(view, ["rect", rect, 0.0 if filled else maxf(1.0, width)], color.a)

static func draw_circle(view: Object, center: Vector2, radius: float, color: Color, filled: bool = true, width: float = -1.0, aa: bool = false) -> void:
	view.draw_circle(center, radius, color, filled, width, aa)
	circle_ink(view, center, radius, color.a, 0.0 if filled else maxf(1.0, width))

static func circle_ink(view: Object, center: Vector2, radius: float, alpha: float, width: float = 0.0) -> void:
	_ink(view, ["circle", Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), width], alpha)

static func draw_arc(view: Object, center: Vector2, radius: float, from: float, to: float, count: int, color: Color, width: float = -1.0, aa: bool = false) -> void:
	view.draw_arc(center, radius, from, to, count, color, width, aa)
	var points := PackedVector2Array()
	if not active.is_empty():
		for i: int in range(count): points.append(center + Vector2.from_angle(lerpf(from, to, float(i) / maxi(1, count - 1))) * radius)
		_ink(view, ["line", points, maxf(1.0, width)], color.a)

static func draw_line(view: Object, a: Vector2, b: Vector2, color: Color, width: float = -1.0, aa: bool = false) -> void:
	view.draw_line(a, b, color, width, aa)
	_ink(view, ["line", PackedVector2Array([a, b]), maxf(1.0, width)], color.a)

static func draw_polyline(view: Object, points: PackedVector2Array, color: Color, width: float = -1.0, aa: bool = false) -> void:
	view.draw_polyline(points, color, width, aa)
	_ink(view, ["line", points, maxf(1.0, width)], color.a, _is_pip())

static func _is_pip() -> bool:
	return not active.is_empty() and active.back()["kind"] in ["charge_pip", "door_focus_chevron"]

static func draw_colored_polygon(view: Object, points: PackedVector2Array, color: Color, uv: PackedVector2Array = PackedVector2Array(), texture: Texture2D = null) -> void:
	view.draw_colored_polygon(points, color, uv, texture)
	_ink(view, ["polygon", points, texture], color.a, texture != null or _is_pip())

static func draw_polygon(view: Object, points: PackedVector2Array, colors: PackedColorArray, uv: PackedVector2Array = PackedVector2Array(), texture: Texture2D = null) -> void:
	view.draw_polygon(points, colors, uv, texture)
	if not colors.is_empty(): _ink(view, ["polygon", points, texture], colors[0].a, texture != null)

static func draw_style_box(view: Object, style: StyleBox, rect: Rect2) -> void:
	view.draw_style_box(style, rect)
	if style is StyleBoxFlat: _ink(view, ["style", rect, style], 1.0)

static func fill_ink(view: Object, rect: Rect2, alpha: float, glyph: bool = false) -> void:
	_ink(view, ["rect", rect, 0.0], alpha, glyph)

static func status(view: Object, entry: Dictionary) -> Scope:
	var owner: Dictionary = active.back()["owner"] if not active.is_empty() else {"id": "", "tile": []}
	var scope: Scope = begin(view, "defense_chip" if entry.get("defense_plate", false) else "status_chip", "", str(entry.get("icon", "")))
	active.back()["owner"] = owner
	return scope

static func numeral(view: CanvasItem, font: Font, pos: Vector2, value: String, width: float, size: int, fill: Color, outline: Color, thickness: float, centered: bool) -> void:
	if active.is_empty(): return
	var row: Dictionary = active.back()
	row["band"] = numeral_band
	var align: int = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	if centered:
		_ink(view, ["text", font, pos, value, align, width, size, int(thickness)], outline.a)
	else:
		for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2.ONE]:
			_ink(view, ["text", font, pos + direction * thickness, value, align, width, size, 0], outline.a)
	_record_string(view, font, pos, value, align, width, size, fill)
	row.erase("band")

static func draw_rid_string(view: CanvasItem, canvas: RID, font: Font, pos: Vector2, value: String, align: int, width: float, size: int, color: Color) -> void:
	font.draw_string(canvas, pos, value, align, width, size, color)
	_record_string(view, font, pos, value, align, width, size, color)

static func draw_rid_transform(view: CanvasItem, canvas: RID, xform: Transform2D) -> void:
	RenderingServer.canvas_item_add_set_transform(canvas, xform)
	transforms[view.get_instance_id()] = xform
