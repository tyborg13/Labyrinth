extends Button
class_name CardWidget

signal activated
signal drag_started

const AssetLoader = preload("res://scripts/asset_loader.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const ElementData = preload("res://scripts/element_data.gd")
const GameData = preload("res://scripts/game_data.gd")
const UiTooltipPanel = preload("res://scripts/ui_tooltip_panel.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

const DRAG_THRESHOLD: float = 10.0
const HOVER_LIFT: float = -12.0
const SELECTED_LIFT: float = -5.0
const HOVER_SCALE: float = 1.04
const SELECTED_SCALE: float = 1.01
const READY_WAVE_LIFT: float = -6.0
const READY_WAVE_SCALE_BONUS: float = 0.022
const READY_WAVE_RISE_SECONDS: float = 0.09
const READY_WAVE_SETTLE_SECONDS: float = 0.20
const READY_WAVE_GLOW_INSET: float = 4.0
const INTENSITY_GLOW_PAD: float = 9.0
const DAMAGE_NEUTRAL_COLOR: String = "#503d2c"
const DAMAGE_BONUS_COLOR: String = "#4f8a43"
const DAMAGE_PENALTY_COLOR: String = "#a34a42"
const CONDITIONAL_TEXT_COLOR: String = "#fff7df"
const CONDITIONAL_OUTLINE_COLOR: String = "#24160f"
const CARD_FRAME_PATH: String = "res://assets/art/ui/card_frame.png"
const CARD_FRAME_STARTER_PATH: String = "res://assets/art/ui/card_frame_rarity_starter.png"
const CARD_FRAME_COMMON_PATH: String = "res://assets/art/ui/card_frame_rarity_common.png"
const CARD_FRAME_RARE_PATH: String = "res://assets/art/ui/card_frame_rarity_rare.png"
const CARD_FRAME_EPIC_PATH: String = "res://assets/art/ui/card_frame_rarity_epic.png"
const CARD_FRAME_LEGENDARY_PATH: String = "res://assets/art/ui/card_frame_rarity_legendary.png"
const BASE_CARD_SIZE: Vector2 = Vector2(250.0, 352.0)
const CARD_FRAME_MARGIN: float = 34.0
const COMPACT_CARD_WIDTH: float = 190.0
const CARD_VERTICAL_CHROME: float = 82.0
const ART_MIN_HEIGHT: float = 76.0
const ART_MAX_HEIGHT: float = 118.0
const DETAILS_MIN_HEIGHT: float = 92.0
const DETAILS_MAX_HEIGHT: float = 142.0
const SUMMARY_VERTICAL_PADDING: float = 10.0
const FLURRY_ICON_WIDTH_SCALE: float = 1.80
const FLURRY_ICON_HEIGHT_SCALE: float = 1.05
const TITLE_MIN_SIZE: int = 10
const TITLE_FIT_RELIEF: int = 2
const TITLE_MAX_RENDER_SIZE: int = 15
const TITLE_NAMEPLATE_WIDTH_RATIO: float = 0.500
const HAND_TITLE_WIDTH_MAX: float = 236.0
const ELEMENT_FRAME_BAND: int = 42
const ELEMENT_FRAME_VALUE_MAX: float = 0.58
const ELEMENT_FRAME_SATURATION_MAX: float = 0.42
const ELEMENT_FRAME_SATURATION_FLOOR: float = 0.46
const ELEMENT_FRAME_TINT_BLEND: float = 0.78
const FIRE_FRAME_SATURATION_FLOOR: float = 0.68
const FIRE_FRAME_TINT_BLEND: float = 0.88
const FIRE_FRAME_VALUE_LIFT: float = 1.035

static var _elemental_frame_cache: Dictionary = {}

class AoePatternView:
	extends Control

	const TILE_WIDTH: float = 16.0
	const TILE_HEIGHT: float = 10.0
	const TILE_PADDING: float = 5.0

	var pattern_offsets: Array[Vector2i] = []
	var show_origin: bool = false
	var tile_scale: float = 1.0

	func setup(raw_pattern: Variant, next_show_origin: bool, next_tooltip: String, next_tile_scale: float = 1.0) -> void:
		pattern_offsets = _parse_offsets(raw_pattern)
		show_origin = next_show_origin
		tile_scale = clampf(next_tile_scale, 0.42, 1.0)
		tooltip_text = next_tooltip
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = _desired_size()
		queue_redraw()

	func _draw() -> void:
		var draw_offsets: Array[Vector2i] = _draw_offsets()
		if draw_offsets.is_empty():
			return
		var bounds: Rect2 = _bounds_for_offsets(draw_offsets)
		var shift: Vector2 = size * 0.5 - bounds.get_center()
		var hit_lookup: Dictionary = {}
		for offset: Vector2i in pattern_offsets:
			hit_lookup[offset] = true
		for offset: Vector2i in draw_offsets:
			var is_origin: bool = show_origin and offset == Vector2i.ZERO and not hit_lookup.has(offset)
			var fill: Color = Color("e9dcc6") if is_origin else Color("d95f4a")
			var border: Color = Color("5a493b") if is_origin else Color("7b2f25")
			_draw_tile(_iso_center(offset) + shift, fill, border)

	func _desired_size() -> Vector2:
		var draw_offsets: Array[Vector2i] = _draw_offsets()
		if draw_offsets.is_empty():
			return Vector2(34.0, 24.0) * tile_scale
		var bounds: Rect2 = _bounds_for_offsets(draw_offsets)
		var padding: float = _tile_padding()
		return Vector2(maxf(34.0 * tile_scale, bounds.size.x + padding * 2.0), maxf(24.0 * tile_scale, bounds.size.y + padding * 2.0))

	func _draw_offsets() -> Array[Vector2i]:
		var lookup: Dictionary = {}
		for offset: Vector2i in pattern_offsets:
			lookup[offset] = true
		if show_origin:
			lookup[Vector2i.ZERO] = true
		var offsets: Array[Vector2i] = []
		for offset_var: Variant in lookup.keys():
			if typeof(offset_var) == TYPE_VECTOR2I:
				offsets.append(offset_var)
		offsets.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			if a.y == b.y:
				return a.x < b.x
			return a.y < b.y
		)
		return offsets

	func _bounds_for_offsets(offsets: Array[Vector2i]) -> Rect2:
		var first: bool = true
		var rect := Rect2()
		for offset: Vector2i in offsets:
			var center: Vector2 = _iso_center(offset)
			var tile_rect := Rect2(center - Vector2(_tile_width() * 0.5, _tile_height() * 0.5), Vector2(_tile_width(), _tile_height()))
			if first:
				rect = tile_rect
				first = false
			else:
				rect = rect.merge(tile_rect)
		return rect

	func _iso_center(offset: Vector2i) -> Vector2:
		return Vector2(float(offset.x - offset.y) * _tile_width() * 0.5, float(offset.x + offset.y) * _tile_height() * 0.5)

	func _draw_tile(center: Vector2, fill: Color, border: Color) -> void:
		var tile_width: float = _tile_width()
		var tile_height: float = _tile_height()
		var points := PackedVector2Array([
			center + Vector2(0.0, -tile_height * 0.5),
			center + Vector2(tile_width * 0.5, 0.0),
			center + Vector2(0.0, tile_height * 0.5),
			center + Vector2(-tile_width * 0.5, 0.0),
			center + Vector2(0.0, -tile_height * 0.5)
		])
		draw_colored_polygon(points, fill)
		draw_polyline(points, border, 1.0, true)

	func _tile_width() -> float:
		return TILE_WIDTH * tile_scale

	func _tile_height() -> float:
		return TILE_HEIGHT * tile_scale

	func _tile_padding() -> float:
		return TILE_PADDING * tile_scale

	func _parse_offsets(raw_pattern: Variant) -> Array[Vector2i]:
		var parsed: Array[Vector2i] = []
		if typeof(raw_pattern) != TYPE_ARRAY:
			parsed.append(Vector2i.ZERO)
			return parsed
		for offset_var: Variant in raw_pattern:
			match typeof(offset_var):
				TYPE_VECTOR2I:
					parsed.append(offset_var)
				TYPE_ARRAY:
					var pair: Array = offset_var
					if pair.size() >= 2:
						parsed.append(Vector2i(int(pair[0]), int(pair[1])))
				TYPE_DICTIONARY:
					var offset_dict: Dictionary = offset_var
					parsed.append(Vector2i(int(offset_dict.get("x", 0)), int(offset_dict.get("y", 0))))
		if parsed.is_empty():
			parsed.append(Vector2i.ZERO)
		return parsed

class TimeCostBadge:
	extends Control

	const UiTypographyScript = preload("res://scripts/ui_typography.gd")
	const CLOCK_HOVER_SECONDS_PER_SECOND: float = 24.0

	var value: int = 0
	var _clock_seconds: float = 0.0
	var _hovered: bool = false

	func setup(next_value: int, next_tooltip: String) -> void:
		value = maxi(0, next_value)
		_clock_seconds = float(posmod(value, 12)) * 3600.0 + float(posmod(value * 5, 60)) * 60.0 + float(posmod(value * 11, 60))
		tooltip_text = next_tooltip
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(_hovered)
		queue_redraw()

	func set_hovered(hovered: bool) -> void:
		if _hovered == hovered:
			return
		_hovered = hovered
		set_process(_hovered)
		queue_redraw()

	func _process(delta: float) -> void:
		if not _hovered:
			return
		_clock_seconds = fmod(_clock_seconds + delta * CLOCK_HOVER_SECONDS_PER_SECOND, 43200.0)
		queue_redraw()

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.48
		_draw_clock_face(center, radius)
		var font: Font = UiTypographyScript.default_font(self)
		if font == null:
			return
		var font_size: int = UiTypographyScript.scaled_size(self, 16 if size.x <= 42.0 else 18)
		var text: String = str(value)
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size)
		while font_size > 10 and text_size.x > size.x * 0.50:
			font_size -= 1
			text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size)
		_draw_number_medallion(center, radius)
		var baseline: Vector2 = Vector2(center.x - text_size.x * 0.5, center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5 + radius * 0.12)
		var outline_color: Color = Color("100804")
		outline_color.a = 0.96
		var outline_offsets: Array = [
			Vector2(-1.0, 0.0),
			Vector2(1.0, 0.0),
			Vector2(0.0, -1.0),
			Vector2(0.0, 1.0),
			Vector2(-1.0, -1.0),
			Vector2(1.0, 1.0),
			Vector2(-1.0, 1.0),
			Vector2(1.0, -1.0)
		]
		for offset_var: Variant in outline_offsets:
			draw_string(font, baseline + (offset_var as Vector2), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, outline_color)
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color("fff3c2"))

	func _draw_clock_face(center: Vector2, radius: float) -> void:
		draw_circle(center + Vector2(radius * 0.05, radius * 0.09), radius * 1.07, Color(0.02, 0.01, 0.005, 0.60))
		draw_circle(center, radius * 1.03, Color("1a1008"))
		draw_circle(center + Vector2(-radius * 0.025, -radius * 0.035), radius * 0.96, Color("d9a850"))
		draw_circle(center + Vector2(radius * 0.035, radius * 0.050), radius * 0.91, Color("6a3e18"))
		draw_circle(center, radius * 0.86, Color("3a2515"))
		draw_circle(center + Vector2(-radius * 0.020, -radius * 0.030), radius * 0.76, Color("2a190f"))
		draw_circle(center + Vector2(-radius * 0.20, -radius * 0.24), radius * 0.42, Color(1.0, 0.78, 0.36, 0.11))
		draw_circle(center + Vector2(radius * 0.24, radius * 0.26), radius * 0.56, Color(0.0, 0.0, 0.0, 0.18))
		draw_arc(center, radius * 0.98, -PI * 0.88, -PI * 0.06, 24, Color(1.0, 0.86, 0.50, 0.84), 1.7, true)
		draw_arc(center, radius * 0.98, PI * 0.18, PI * 0.95, 24, Color(0.18, 0.09, 0.03, 0.62), 2.0, true)
		draw_arc(center, radius * 0.66, 0.0, PI * 2.0, 48, Color(0.86, 0.60, 0.25, 0.22), 0.8, true)
		for tick: int in range(12):
			var angle: float = -PI * 0.5 + float(tick) * TAU / 12.0
			var inner: float = radius * (0.64 if tick % 3 == 0 else 0.71)
			var outer: float = radius * 0.84
			var tick_color: Color = Color("f6d98d") if tick % 3 == 0 else Color(0.80, 0.58, 0.30, 0.82)
			var tick_width: float = 1.8 if tick % 3 == 0 else 1.1
			draw_line(_polar_point(center, angle, inner) + Vector2(0.6, 0.8), _polar_point(center, angle, outer) + Vector2(0.6, 0.8), Color(0.05, 0.025, 0.01, 0.70), tick_width + 0.4, true)
			draw_line(_polar_point(center, angle, inner), _polar_point(center, angle, outer), tick_color, tick_width, true)
		var second_angle: float = -PI * 0.5 + TAU * fposmod(_clock_seconds, 60.0) / 60.0
		var minute_angle: float = -PI * 0.5 + TAU * fposmod(_clock_seconds / 60.0, 60.0) / 60.0
		var hour_angle: float = -PI * 0.5 + TAU * fposmod(_clock_seconds / 3600.0, 12.0) / 12.0
		_draw_clock_hand(center, hour_angle, radius * 0.34, radius * 0.090, Color("7c4820"), Color("d39b4a"))
		_draw_clock_hand(center, minute_angle, radius * 0.53, radius * 0.066, Color("d39a43"), Color("ffe099"))
		_draw_second_hand(center, second_angle, radius * 0.65)
		draw_circle(center + Vector2(0.7, 0.9), radius * 0.105, Color(0.03, 0.015, 0.006, 0.70))
		draw_circle(center, radius * 0.092, Color("f4d486"))
		draw_circle(center + Vector2(-radius * 0.020, -radius * 0.025), radius * 0.052, Color("6b3b18"))
		draw_circle(center + Vector2(-radius * 0.030, -radius * 0.040), radius * 0.020, Color(1.0, 0.88, 0.58, 0.60))

	func _draw_number_medallion(center: Vector2, radius: float) -> void:
		draw_circle(center + Vector2(0.0, radius * 0.06), radius * 0.34, Color(0.02, 0.01, 0.004, 0.58))
		draw_circle(center, radius * 0.30, Color(0.10, 0.055, 0.026, 0.84))
		draw_arc(center, radius * 0.29, -PI * 0.82, -PI * 0.18, 16, Color(1.0, 0.80, 0.42, 0.26), 0.9, true)
		draw_arc(center, radius * 0.29, PI * 0.10, PI * 0.84, 16, Color(0.0, 0.0, 0.0, 0.26), 1.0, true)

	func _draw_clock_hand(center: Vector2, angle: float, length: float, width: float, color: Color, highlight: Color) -> void:
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
		var tail: Vector2 = center - direction * length * 0.14
		var tip: Vector2 = center + direction * length
		var points := PackedVector2Array([
			tail + perpendicular * width,
			center + perpendicular * width * 0.58,
			tip + perpendicular * width * 0.18,
			tip,
			tip - perpendicular * width * 0.18,
			center - perpendicular * width * 0.58,
			tail - perpendicular * width
		])
		draw_colored_polygon(_offset_polygon(points, Vector2(0.8, 1.0)), Color(0.03, 0.015, 0.006, 0.58))
		draw_colored_polygon(points, color)
		draw_polyline(_closed_polygon(points), Color(0.10, 0.045, 0.014, 0.60), 0.7, true)
		draw_line(tail + perpendicular * width * 0.36, tip + perpendicular * width * 0.08, highlight, 0.7, true)

	func _draw_second_hand(center: Vector2, angle: float, length: float) -> void:
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		var tip: Vector2 = center + direction * length
		var tail: Vector2 = center - direction * length * 0.24
		draw_line(tail + Vector2(0.7, 0.8), tip + Vector2(0.7, 0.8), Color(0.03, 0.014, 0.006, 0.62), 1.8, true)
		draw_line(tail, tip, Color("f6d783"), 1.15, true)
		draw_circle(tip, length * 0.032, Color("fff0a8"))

	func _offset_polygon(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
		var shifted := PackedVector2Array()
		for point: Vector2 in points:
			shifted.append(point + offset)
		return shifted

	func _closed_polygon(points: PackedVector2Array) -> PackedVector2Array:
		var closed := PackedVector2Array(points)
		if not points.is_empty():
			closed.append(points[0])
		return closed

	func _polar_point(center: Vector2, angle: float, length: float) -> Vector2:
		return center + Vector2(cos(angle), sin(angle)) * length

class IntensityActiveGlow:
	extends Control

	const PULSE_SECONDS: float = 2.8
	const PULSE_ALPHA_MIN: float = 0.86
	const PULSE_ALPHA_MAX: float = 1.0
	const SHARED_TEXTURE_CACHE_LIMIT: int = 24

	static var _shared_texture_cache: Dictionary = {}
	static var _shared_texture_cache_order: Array[String] = []

	var element_id: String = "none"
	var glow_color: Color = Color.TRANSPARENT
	var layout_scale: float = 1.0
	var _glow_texture: Texture2D
	var _texture_key: String = ""
	var _pulse_phase: float = 0.0

	func _ready() -> void:
		set_process(visible)

	func setup(next_element_id: String, next_glow_color: Color, next_layout_scale: float, active: bool) -> void:
		element_id = next_element_id
		glow_color = next_glow_color
		layout_scale = clampf(next_layout_scale, 0.44, 1.20)
		visible = active
		set_process(active)
		if active:
			_refresh_texture()
		queue_redraw()

	func _process(delta: float) -> void:
		if not visible:
			return
		_pulse_phase = fmod(_pulse_phase + delta / PULSE_SECONDS, 1.0)
		queue_redraw()

	func _draw() -> void:
		if not visible or _glow_texture == null:
			return
		var wave: float = 0.5 + 0.5 * sin(_pulse_phase * TAU)
		var alpha: float = lerpf(PULSE_ALPHA_MIN, PULSE_ALPHA_MAX, wave)
		draw_texture_rect(_glow_texture, Rect2(Vector2.ZERO, size), false, Color(1.0, 1.0, 1.0, alpha))

	func _refresh_texture() -> void:
		var texture_size := Vector2i(maxi(1, int(ceil(size.x))), maxi(1, int(ceil(size.y))))
		var key: String = "%s|%dx%d|%.6f|%.6f|%.6f|%.6f" % [
			element_id,
			texture_size.x,
			texture_size.y,
			glow_color.r,
			glow_color.g,
			glow_color.b,
			layout_scale
		]
		if key == _texture_key and _glow_texture != null:
			return
		_texture_key = key
		if _shared_texture_cache.has(key):
			_glow_texture = _shared_texture_cache.get(key, null)
			_shared_texture_cache_order.erase(key)
			_shared_texture_cache_order.append(key)
			return
		_glow_texture = _build_glow_texture(texture_size)
		_shared_texture_cache[key] = _glow_texture
		_shared_texture_cache_order.append(key)
		while _shared_texture_cache_order.size() > SHARED_TEXTURE_CACHE_LIMIT:
			var expired_key: String = _shared_texture_cache_order.pop_front()
			_shared_texture_cache.erase(expired_key)

	func _build_glow_texture(texture_size: Vector2i) -> Texture2D:
		var image := Image.create_empty(texture_size.x, texture_size.y, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		var pad: float = _pad()
		if texture_size.x <= int(ceil(pad * 2.0)) or texture_size.y <= int(ceil(pad * 2.0)):
			return ImageTexture.create_from_image(image)
		var card_rect := Rect2(Vector2(pad, pad), Vector2(texture_size) - Vector2(pad * 2.0, pad * 2.0)).grow(-_edge_inset())
		var radius: float = clampf(18.0 * layout_scale, 6.0, minf(card_rect.size.x, card_rect.size.y) * 0.16)
		var outer_spread: float = maxf(4.0, 8.0 * layout_scale)
		var inner_spread: float = maxf(4.0, 9.4 * layout_scale)
		var core_width: float = maxf(1.2, 2.4 * layout_scale)
		for y: int in range(texture_size.y):
			for x: int in range(texture_size.x):
				var point := Vector2(float(x) + 0.5, float(y) + 0.5)
				var signed_distance: float = _rounded_rect_signed_distance(point, card_rect, radius)
				var edge_distance: float = absf(signed_distance)
				var spread: float = inner_spread if signed_distance < 0.0 else outer_spread
				var bloom: float = exp(-pow(edge_distance / spread, 2.0))
				var core: float = 1.0 - smoothstep(0.0, core_width, edge_distance)
				var alpha: float = bloom * 0.34 + core * 0.10
				if signed_distance < 0.0:
					alpha *= 0.74
				alpha = clampf(alpha, 0.0, 0.42)
				if alpha <= 0.006:
					continue
				image.set_pixel(x, y, Color(glow_color.r, glow_color.g, glow_color.b, alpha))
		return ImageTexture.create_from_image(image)

	func _rounded_rect_signed_distance(point: Vector2, rect: Rect2, radius: float) -> float:
		var center: Vector2 = rect.get_center()
		var half_size: Vector2 = rect.size * 0.5
		var relative: Vector2 = point - center
		var q := Vector2(absf(relative.x), absf(relative.y)) - (half_size - Vector2(radius, radius))
		var outside := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0))
		var inside: float = minf(maxf(q.x, q.y), 0.0)
		return outside.length() + inside - radius

	func _pad() -> float:
		return 9.0 * layout_scale

	func _edge_inset() -> float:
		return 4.0 * layout_scale

@onready var vbox: VBoxContainer = $Margin/VBox
@onready var title_label: Label = $Margin/VBox/TopRow/Title
@onready var art_frame: PanelContainer = $Margin/VBox/ArtBleed/ArtFrame
@onready var art_rect: TextureRect = $Margin/VBox/ArtBleed/ArtFrame/Art
@onready var details_panel: PanelContainer = $Margin/VBox/DetailsPanel
@onready var details_vbox: VBoxContainer = $Margin/VBox/DetailsPanel/DetailsMargin/DetailsVBox
@onready var desc_label: RichTextLabel = $Margin/VBox/DetailsPanel/DetailsMargin/DetailsVBox/Description
@onready var footer_label: Label = $Margin/VBox/DetailsPanel/DetailsMargin/DetailsVBox/Footer

var card_id: String = ""
var _selected: bool = false
var _dimmed: bool = false
var _usable: bool = true
var _previewed: bool = false
var _interactive: bool = true
var _printed_playable: bool = true
var _card_override: Dictionary = {}
var _summary_bbcode: String = ""
var _summary_rows: Array = []
var _modifier_tooltip_lines: PackedStringArray = []
var _left_pressed: bool = false
var _drag_emitted: bool = false
var _press_position: Vector2 = Vector2.ZERO
var _local_hovered: bool = false
var _hover_lift: float = HOVER_LIFT
var _hover_scale: float = HOVER_SCALE
var _pose_tween: Tween
var _ready_wave_tween: Tween
var _ready_wave_progress: float = 0.0
var _ready_wave_active: bool = false
var _ready_wave_glow: PanelContainer
var _intensity_active_glow: IntensityActiveGlow
var _summary_icon_box: VBoxContainer
var _time_badge: TimeCostBadge

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_meta("cursor_feedback_context", "action_drag")
	set_meta("cursor_feedback_drag_source", true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	text = ""
	art_frame.clip_contents = true
	art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	title_label.add_theme_color_override("font_color", Color("39271b"))
	title_label.add_theme_color_override("font_outline_color", Color("f8f1dd"))
	title_label.add_theme_constant_override("outline_size", 2)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.clip_text = true
	desc_label.add_theme_color_override("default_color", Color("503d2c"))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.fit_content = true
	desc_label.scroll_active = false
	desc_label.scroll_following = false
	footer_label.visible = false
	footer_label.add_theme_color_override("font_color", Color("6d5841"))
	footer_label.add_theme_color_override("font_outline_color", Color("f5ecdb"))
	footer_label.add_theme_constant_override("outline_size", 1)
	_ensure_summary_icon_box()
	_ensure_intensity_active_glow()
	_ensure_time_badge()
	mouse_entered.connect(_on_local_mouse_entered)
	mouse_exited.connect(_on_local_mouse_exited)
	_update_layout_metrics()
	_apply_configuration()
	_queue_title_refit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_update_layout_metrics()
		pivot_offset = size * 0.5
		_position_time_badge()
		_sync_intensity_active_glow_geometry()
		if not card_id.is_empty():
			_apply_configuration()

func _gui_input(event: InputEvent) -> void:
	if not _interactive:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_left_pressed = true
			_drag_emitted = false
			_press_position = event.position
			accept_event()
			return
		if _left_pressed:
			_left_pressed = false
			accept_event()
			if not _drag_emitted:
				activated.emit()
			_drag_emitted = false
	elif event is InputEventMouseMotion and _left_pressed and not _drag_emitted:
		if event.position.distance_to(_press_position) >= DRAG_THRESHOLD:
			_drag_emitted = true
			drag_started.emit()
			accept_event()

func _get_tooltip(_at_position: Vector2) -> String:
	if _time_badge != null and _time_badge.visible and _time_badge.get_global_rect().has_point(get_global_mouse_position()):
		return _time_badge.tooltip_text
	var icon_tooltip: String = _tooltip_for_icon_at(get_global_mouse_position())
	if not icon_tooltip.is_empty():
		return icon_tooltip
	return "modifiers" if not _modifier_tooltip_lines.is_empty() else ""

func _make_custom_tooltip(for_text: String) -> Object:
	if for_text == "modifiers":
		if _modifier_tooltip_lines.is_empty():
			return null
		return UiTooltipPanel.make_lines("MODIFIERS", _modifier_tooltip_lines)
	if for_text.strip_edges().is_empty():
		return null
	return UiTooltipPanel.make_text(for_text)

func _tooltip_for_icon_at(global_point: Vector2) -> String:
	return _tooltip_for_control_at(_summary_icon_box, global_point)

func _tooltip_for_control_at(node: Node, global_point: Vector2) -> String:
	if node == null or not (node is Control):
		return ""
	var control: Control = node
	if not control.visible or not control.get_global_rect().has_point(global_point):
		return ""
	for child: Node in control.get_children():
		var child_tooltip: String = _tooltip_for_control_at(child, global_point)
		if not child_tooltip.is_empty():
			return child_tooltip
	return str(control.tooltip_text)

func configure(
	next_card_id: String,
	selected: bool = false,
	dimmed: bool = false,
	usable: bool = true,
	previewed: bool = false,
	interactive: bool = true,
	printed_playable: bool = true,
	card_override: Dictionary = {}
) -> void:
	card_id = next_card_id
	_selected = selected
	_dimmed = dimmed
	_usable = usable
	_previewed = previewed
	_interactive = interactive
	_printed_playable = printed_playable
	_card_override = card_override.duplicate(true)
	if is_node_ready():
		_apply_configuration()

func set_display_overrides(summary_bbcode: String = "", modifier_lines: Array = [], summary_rows: Array = []) -> void:
	_summary_bbcode = summary_bbcode
	_summary_rows = summary_rows.duplicate(true)
	_modifier_tooltip_lines = PackedStringArray()
	for line_var: Variant in modifier_lines:
		_modifier_tooltip_lines.append(str(line_var))
	tooltip_text = "modifiers" if not _modifier_tooltip_lines.is_empty() else ""
	if is_node_ready():
		_apply_configuration()

func set_hover_pose(next_lift: float, next_scale: float) -> void:
	_hover_lift = clampf(next_lift, -40.0, 0.0)
	_hover_scale = clampf(next_scale, 1.0, 1.20)
	if is_node_ready() and _local_hovered:
		_update_pose()

func _apply_configuration() -> void:
	if not is_node_ready():
		return
	var card: Dictionary = _display_card_def()
	var element_id: String = GameData.card_element_from_def(card)
	title_label.text = str(card.get("name", card_id))
	_fit_title_label(_base_title_size())
	_queue_title_refit()
	_refresh_summary_display(card)
	_refresh_intensity_active_glow()
	_refresh_time_badge(card)
	footer_label.text = ""
	footer_label.visible = false
	art_rect.texture = AssetLoader.load_texture(str(card.get("art_path", "")))
	var accent: Color = ElementData.accent(element_id) if ElementData.is_elemental(element_id) else Color(str(card.get("accent", "#8a6b4a")))
	var background: Color = ElementData.card_background(element_id, _selected)
	if not ElementData.is_elemental(element_id):
		background = Color("ddd0bb") if _selected else Color("efe4cf")
	if _previewed and not _selected:
		background = background.lightened(0.03)
	if _dimmed:
		background = background.darkened(0.12)
	_apply_base_style(background, accent, _usable, _previewed, _printed_playable, ElementData.card_art_background(element_id), str(card.get("rarity", "common")), element_id)
	disabled = false
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _interactive else Control.CURSOR_ARROW
	set_meta("cursor_feedback_context", "action_drag" if _interactive else "inert")
	set_meta("cursor_feedback_drag_source", _interactive)
	var alpha: float = 1.0
	if not _usable:
		alpha = 0.56
	elif _dimmed:
		alpha = 0.72
	elif not _printed_playable:
		alpha = 0.90
	modulate = Color(1.0, 1.0, 1.0, alpha)
	_update_pose(true)

func _update_layout_metrics() -> void:
	_apply_scaled_node_metrics()
	var width: float = size.x if size.x > 0.0 else custom_minimum_size.x
	var height: float = size.y if size.y > 0.0 else custom_minimum_size.y
	var layout_scale: float = _card_layout_scale()
	var compact: bool = width <= COMPACT_CARD_WIDTH
	var detail_size: int = _scaled_card_font_size(13 if compact else 15, 8)
	_fit_title_label(_base_title_size())
	UiTypography.set_rich_text_size(desc_label, detail_size)
	UiTypography.set_label_size(footer_label, detail_size)
	var art_min_height: float = _scaled_card_value(68.0 if compact else ART_MIN_HEIGHT, 36.0)
	var art_max_height: float = _scaled_card_value(ART_MAX_HEIGHT, art_min_height)
	var details_min_height: float = _scaled_card_value(104.0 if compact else DETAILS_MIN_HEIGHT, 48.0)
	var details_max_height: float = _scaled_card_value(DETAILS_MAX_HEIGHT, details_min_height)
	var details_target: float = width * (0.62 if compact else 0.56)
	var art_height: float = clampf(width * 0.46, art_min_height, art_max_height)
	var details_height: float = clampf(details_target, details_min_height, details_max_height)
	var available_body_height: float = maxf(112.0 * layout_scale, height - _scaled_card_value(CARD_VERTICAL_CHROME, 42.0))
	var body_overflow: float = art_height + details_height - available_body_height
	if body_overflow > 0.0:
		var art_reduction: float = minf(body_overflow, art_height - art_min_height)
		art_height -= art_reduction
		body_overflow -= art_reduction
		if body_overflow > 0.0:
			details_height = maxf(details_min_height, details_height - body_overflow)
	art_frame.custom_minimum_size = Vector2(0.0, art_height)
	details_panel.custom_minimum_size = Vector2(0.0, details_height)
	desc_label.custom_minimum_size = Vector2(0.0, details_height)
	footer_label.custom_minimum_size = Vector2.ZERO
	if _summary_icon_box != null:
		_summary_icon_box.custom_minimum_size = Vector2(0.0, details_height)
	_position_time_badge()
	pivot_offset = size * 0.5

func _apply_scaled_node_metrics() -> void:
	var margin: MarginContainer = $Margin as MarginContainer
	if margin != null:
		margin.add_theme_constant_override("margin_left", _scaled_card_int(16, 6))
		margin.add_theme_constant_override("margin_top", _scaled_card_int(14, 5))
		margin.add_theme_constant_override("margin_right", _scaled_card_int(16, 6))
		margin.add_theme_constant_override("margin_bottom", _scaled_card_int(14, 5))
	vbox.add_theme_constant_override("separation", _scaled_card_int(7, 2))
	title_label.custom_minimum_size = Vector2(0.0, _scaled_card_value(40.0, 22.0))
	var art_bleed: MarginContainer = $Margin/VBox/ArtBleed as MarginContainer
	if art_bleed != null:
		art_bleed.add_theme_constant_override("margin_left", -_scaled_card_int(5, 1))
		art_bleed.add_theme_constant_override("margin_top", -_scaled_card_int(2, 1))
		art_bleed.add_theme_constant_override("margin_right", -_scaled_card_int(5, 1))
		art_bleed.add_theme_constant_override("margin_bottom", -_scaled_card_int(1, 1))
	var details_margin: MarginContainer = $Margin/VBox/DetailsPanel/DetailsMargin as MarginContainer
	if details_margin != null:
		details_margin.add_theme_constant_override("margin_left", _scaled_card_int(7, 2))
		details_margin.add_theme_constant_override("margin_top", _scaled_card_int(3, 1))
		details_margin.add_theme_constant_override("margin_right", _scaled_card_int(7, 2))
		details_margin.add_theme_constant_override("margin_bottom", _scaled_card_int(3, 1))
	details_vbox.add_theme_constant_override("separation", _scaled_card_int(5, 1))
	if _summary_icon_box != null:
		_summary_icon_box.add_theme_constant_override("separation", _scaled_card_int(5, 1))

func _card_layout_scale() -> float:
	var card_size: Vector2 = size
	if card_size.x <= 0.0:
		card_size.x = custom_minimum_size.x
	if card_size.y <= 0.0:
		card_size.y = custom_minimum_size.y
	if card_size.x <= 0.0 or card_size.y <= 0.0:
		return 1.0
	return clampf(minf(card_size.x / BASE_CARD_SIZE.x, card_size.y / BASE_CARD_SIZE.y), 0.44, 1.20)

func _scaled_card_value(value: float, minimum: float = 0.0) -> float:
	return maxf(minimum, value * _card_layout_scale())

func _scaled_card_int(value: int, minimum: int = 1) -> int:
	return maxi(minimum, int(round(float(value) * _card_layout_scale())))

func _scaled_card_font_size(value: int, minimum: int = 7) -> int:
	return maxi(minimum, int(round(float(value) * _card_layout_scale())))

func _apply_base_style(_background: Color, _border: Color, _usable: bool, _previewed: bool, _printed_playable: bool, _art_background: Color, rarity: String, element_id: String) -> void:
	var normal: StyleBoxTexture = _card_frame_style(0.0, rarity, element_id)
	var hover: StyleBoxTexture = _card_frame_style(2.0, rarity, element_id)
	var pressed: StyleBoxTexture = _card_frame_style(0.0, rarity, element_id)
	var disabled_style: StyleBoxTexture = _card_frame_style(0.0, rarity, element_id)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("focus", hover)
	add_theme_stylebox_override("disabled", disabled_style)
	art_frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	details_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

func _card_frame_style(expand: float = 0.0, rarity: String = "", element_id: String = ElementData.NONE) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _card_frame_texture(rarity, element_id)
	var frame_margin: float = _scaled_card_value(CARD_FRAME_MARGIN, 12.0)
	style.texture_margin_left = frame_margin
	style.texture_margin_top = frame_margin
	style.texture_margin_right = frame_margin
	style.texture_margin_bottom = frame_margin
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.expand_margin_left = expand
	style.expand_margin_top = expand
	style.expand_margin_right = expand
	style.expand_margin_bottom = expand
	return style

func _card_frame_texture(rarity: String, element_id: String) -> Texture2D:
	var base_path: String = _card_frame_path(rarity)
	var base_texture: Texture2D = AssetLoader.load_texture(base_path)
	if base_texture == null or not ElementData.is_elemental(element_id):
		return base_texture
	var cache_key: String = "%s|%s" % [base_path, element_id]
	if _elemental_frame_cache.has(cache_key):
		return _elemental_frame_cache.get(cache_key, base_texture)
	var image: Image = base_texture.get_image()
	if image == null or image.is_empty():
		_elemental_frame_cache[cache_key] = base_texture
		return base_texture
	var tinted_image: Image = image.duplicate()
	var accent_hsv: Vector3 = _color_to_hsv(_element_frame_tint_color(element_id))
	for y: int in range(tinted_image.get_height()):
		for x: int in range(tinted_image.get_width()):
			var pixel: Color = tinted_image.get_pixel(x, y)
			if not _is_element_frame_metal_pixel(pixel, Vector2i(x, y), Vector2i(tinted_image.get_width(), tinted_image.get_height())):
				continue
			var pixel_hsv: Vector3 = _color_to_hsv(pixel)
			var tinted_pixel: Color = Color.from_hsv(
				accent_hsv.x,
				_element_frame_saturation(element_id, accent_hsv),
				_element_frame_value(element_id, pixel_hsv.z),
				pixel.a
			)
			tinted_image.set_pixel(x, y, pixel.lerp(tinted_pixel, _element_frame_tint_blend(element_id)))
	var tinted_texture: Texture2D = ImageTexture.create_from_image(tinted_image)
	_elemental_frame_cache[cache_key] = tinted_texture
	return tinted_texture

func _element_frame_tint_color(element_id: String) -> Color:
	var accent: Color = ElementData.accent(element_id)
	if element_id == ElementData.FIRE:
		return accent.lerp(Color("e13f35"), 0.38)
	return accent

func _element_frame_saturation(element_id: String, accent_hsv: Vector3) -> float:
	if element_id == ElementData.FIRE:
		return clampf(maxf(FIRE_FRAME_SATURATION_FLOOR, accent_hsv.y * 1.02), 0.0, 0.86)
	return clampf(maxf(ELEMENT_FRAME_SATURATION_FLOOR, accent_hsv.y * 0.74), 0.0, 1.0)

func _element_frame_value(element_id: String, pixel_value: float) -> float:
	if element_id == ElementData.FIRE:
		return clampf(pixel_value * FIRE_FRAME_VALUE_LIFT, 0.0, 1.0)
	return pixel_value

func _element_frame_tint_blend(element_id: String) -> float:
	return FIRE_FRAME_TINT_BLEND if element_id == ElementData.FIRE else ELEMENT_FRAME_TINT_BLEND

func _is_element_frame_metal_pixel(pixel: Color, point: Vector2i, image_size: Vector2i) -> bool:
	if pixel.a < 0.08:
		return false
	var in_frame_band: bool = (
		point.x < ELEMENT_FRAME_BAND
		or point.x >= image_size.x - ELEMENT_FRAME_BAND
		or point.y < ELEMENT_FRAME_BAND
		or point.y >= image_size.y - ELEMENT_FRAME_BAND
	)
	if not in_frame_band:
		return false
	var hsv: Vector3 = _color_to_hsv(pixel)
	if hsv.z > ELEMENT_FRAME_VALUE_MAX:
		return false
	return hsv.y <= ELEMENT_FRAME_SATURATION_MAX

func _color_to_hsv(color: Color) -> Vector3:
	var max_channel: float = maxf(color.r, maxf(color.g, color.b))
	var min_channel: float = minf(color.r, minf(color.g, color.b))
	var chroma: float = max_channel - min_channel
	var hue: float = 0.0
	if chroma > 0.00001:
		if is_equal_approx(max_channel, color.r):
			hue = fmod((color.g - color.b) / chroma, 6.0) / 6.0
		elif is_equal_approx(max_channel, color.g):
			hue = (((color.b - color.r) / chroma) + 2.0) / 6.0
		else:
			hue = (((color.r - color.g) / chroma) + 4.0) / 6.0
		if hue < 0.0:
			hue += 1.0
	var saturation: float = 0.0 if max_channel <= 0.00001 else chroma / max_channel
	return Vector3(hue, saturation, max_channel)

func _card_frame_path(rarity: String) -> String:
	match rarity:
		"starter":
			return CARD_FRAME_STARTER_PATH
		"common":
			return CARD_FRAME_COMMON_PATH
		"uncommon":
			return CARD_FRAME_RARE_PATH
		"rare":
			return CARD_FRAME_RARE_PATH
		"epic":
			return CARD_FRAME_EPIC_PATH
		"legendary":
			return CARD_FRAME_LEGENDARY_PATH
		_:
			return CARD_FRAME_PATH

func _ensure_summary_icon_box() -> void:
	if _summary_icon_box != null:
		return
	_summary_icon_box = VBoxContainer.new()
	_summary_icon_box.name = "IconSummary"
	_summary_icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summary_icon_box.add_theme_constant_override("separation", 5)
	details_vbox.add_child(_summary_icon_box)
	details_vbox.move_child(_summary_icon_box, desc_label.get_index() + 1)

func _ensure_time_badge() -> void:
	if _time_badge != null:
		return
	_time_badge = TimeCostBadge.new()
	_time_badge.name = "TimeCostBadge"
	_time_badge.visible = false
	add_child(_time_badge)
	_position_time_badge()

func _refresh_time_badge(card: Dictionary) -> void:
	_ensure_time_badge()
	var time_cost: int = maxi(1, int(card.get("time", 5)))
	_time_badge.visible = time_cost > 0
	_time_badge.setup(time_cost, "%s\n%d initiative delay." % [ActionIcons.label("time"), time_cost])
	_position_time_badge()

func _position_time_badge() -> void:
	if _time_badge == null:
		return
	var width: float = size.x if size.x > 0.0 else custom_minimum_size.x
	var badge_size: float = clampf(width * 0.198, _scaled_card_value(38.0, 22.0), _scaled_card_value(50.0, 30.0))
	_time_badge.custom_minimum_size = Vector2(badge_size, badge_size)
	_time_badge.size = Vector2(badge_size, badge_size)
	var overhang: float = clampf(width * 0.020, _scaled_card_value(3.5, 1.5), _scaled_card_value(5.0, 3.0))
	_time_badge.position = Vector2(width - badge_size + overhang, -overhang)
	_time_badge.z_index = 12

func _ensure_intensity_active_glow() -> void:
	if _intensity_active_glow != null:
		return
	_intensity_active_glow = IntensityActiveGlow.new()
	_intensity_active_glow.name = "IntensityActiveGlow"
	_intensity_active_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intensity_active_glow.show_behind_parent = true
	_intensity_active_glow.z_as_relative = true
	_intensity_active_glow.z_index = 0
	_intensity_active_glow.visible = false
	add_child(_intensity_active_glow)
	move_child(_intensity_active_glow, 0)
	_sync_intensity_active_glow_geometry()

func _sync_intensity_active_glow_geometry() -> void:
	if _intensity_active_glow == null:
		return
	var pad: float = _intensity_glow_pad()
	var card_size: Vector2 = size if size.x > 0.0 and size.y > 0.0 else custom_minimum_size
	if card_size.x <= 0.0 or card_size.y <= 0.0:
		card_size = BASE_CARD_SIZE
	_intensity_active_glow.position = Vector2(-pad, -pad)
	_intensity_active_glow.size = card_size + Vector2(pad * 2.0, pad * 2.0)
	_intensity_active_glow.pivot_offset = _intensity_active_glow.size * 0.5

func _refresh_intensity_active_glow() -> void:
	_ensure_intensity_active_glow()
	var condition: Dictionary = _active_intensity_condition()
	var element_id: String = str(condition.get("element", ElementData.NONE))
	var active: bool = ElementData.is_elemental(element_id)
	_sync_intensity_active_glow_geometry()
	_intensity_active_glow.setup(element_id, _intensity_glow_color(element_id), _card_layout_scale(), active)

func _active_intensity_condition() -> Dictionary:
	for row_var: Variant in _summary_rows:
		if typeof(row_var) != TYPE_ARRAY:
			continue
		var row: Array = row_var as Array
		for token_var: Variant in row:
			if typeof(token_var) != TYPE_DICTIONARY:
				continue
			var token: Dictionary = token_var
			if str(token.get("kind", "")) != "intensity_requirement":
				continue
			if not bool(token.get("condition_active", false)):
				continue
			var element_id: String = str(token.get("element", ElementData.NONE))
			if ElementData.is_elemental(element_id):
				return {"element": element_id}
	return {}

func _intensity_glow_color(element_id: String) -> Color:
	if not ElementData.is_elemental(element_id):
		return Color.TRANSPARENT
	return ElementData.accent(element_id).lerp(Color.WHITE, 0.16)

func _intensity_glow_pad() -> float:
	return _scaled_card_value(INTENSITY_GLOW_PAD, 6.0)

func _refresh_summary_display(card: Dictionary) -> void:
	var rows: Array = _summary_rows.duplicate(true)
	if rows.is_empty() and _summary_bbcode.is_empty():
		rows = ActionIcons.rows_for_card(card)
	if rows.is_empty():
		desc_label.visible = true
		desc_label.text = _summary_bbcode if not _summary_bbcode.is_empty() else str(card.get("description", ""))
		if _summary_icon_box != null:
			_summary_icon_box.visible = false
			_clear_children(_summary_icon_box)
		return
	desc_label.visible = false
	desc_label.text = ""
	_summary_icon_box.visible = true
	_render_summary_icon_rows(rows)

func _render_summary_icon_rows(rows: Array) -> void:
	if _summary_icon_box == null:
		return
	_clear_children(_summary_icon_box)
	var row_groups: Array = []
	var rendered_rows: Array = []
	for row_var: Variant in rows:
		if typeof(row_var) != TYPE_ARRAY:
			continue
		var raw_row: Array = row_var as Array
		var segments: Array = []
		for segment: Array in _summary_token_segments(row_var as Array):
			if not segment.is_empty():
				segments.append(segment)
				rendered_rows.append(segment)
		if not segments.is_empty():
			row_groups.append({
				"segments": segments,
				"condition": _row_condition_data(raw_row)
			})
	if rendered_rows.is_empty():
		return
	var metrics: Dictionary = _summary_layout_metrics(rendered_rows)
	var icon_size: float = float(metrics.get("icon_size", _summary_icon_size()))
	var label_size: int = int(metrics.get("label_size", 15))
	var row_gap: int = int(metrics.get("row_gap", 6))
	for group_var: Variant in row_groups:
		if typeof(group_var) != TYPE_DICTIONARY:
			continue
		var group: Dictionary = group_var
		var condition: Dictionary = group.get("condition", {})
		var condition_element: String = str(condition.get("element", ""))
		var condition_active: bool = bool(condition.get("active", false))
		var segments: Array = group.get("segments", [])
		if condition_element.is_empty():
			for segment_var: Variant in segments:
				if typeof(segment_var) == TYPE_ARRAY:
					_add_summary_segment(_summary_icon_box, segment_var as Array, icon_size, label_size, row_gap)
			continue
		var block := PanelContainer.new()
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		block.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		block.add_theme_stylebox_override("panel", _conditional_summary_style(condition_element, condition_active))
		_summary_icon_box.add_child(block)
		var margin := MarginContainer.new()
		margin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		margin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		margin.add_theme_constant_override("margin_left", 1)
		margin.add_theme_constant_override("margin_top", 1)
		margin.add_theme_constant_override("margin_right", 1)
		margin.add_theme_constant_override("margin_bottom", 1)
		block.add_child(margin)
		var inner := VBoxContainer.new()
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		inner.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", maxi(0, row_gap - 4))
		margin.add_child(inner)
		for segment_var: Variant in segments:
			if typeof(segment_var) == TYPE_ARRAY:
				var segment: Array = segment_var as Array
				var conditional_icon_size: float = icon_size
				var conditional_label_size: int = label_size
				var conditional_row_gap: int = maxi(0, row_gap - 2)
				if _segment_should_compact_conditional(segment):
					conditional_icon_size = maxf(15.0, icon_size - 3.0)
					conditional_label_size = maxi(10, label_size - 2)
					conditional_row_gap = maxi(0, row_gap - 3)
				_add_summary_segment(inner, segment, conditional_icon_size, conditional_label_size, conditional_row_gap, true)

func _add_summary_segment(parent: Node, segment: Array, icon_size: float, label_size: int, row_gap: int, conditional: bool = false) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", row_gap)
	for token_var: Variant in segment:
		if typeof(token_var) != TYPE_DICTIONARY:
			continue
		_add_token_to_summary_row(row, token_var as Dictionary, icon_size, label_size, conditional)
	if row.get_child_count() > 0:
		parent.add_child(row)

func _segment_should_compact_conditional(segment: Array) -> bool:
	var valued_tokens: int = 0
	for token_var: Variant in segment:
		if typeof(token_var) != TYPE_DICTIONARY:
			continue
		var token: Dictionary = token_var
		if token.has("value") and str(token.get("kind", "")) != "aoe_pattern":
			valued_tokens += 1
	return valued_tokens >= 3

func _row_condition_data(row: Array) -> Dictionary:
	for token_var: Variant in row:
		if typeof(token_var) != TYPE_DICTIONARY:
			continue
		var token: Dictionary = token_var
		if str(token.get("kind", "")) == "intensity_requirement":
			return {
				"element": str(token.get("element", "")),
				"active": bool(token.get("condition_active", false))
			}
	return {}

func _conditional_summary_style(element_id: String, active: bool = false) -> StyleBoxFlat:
	var accent: Color = ElementData.accent(element_id)
	var style := StyleBoxFlat.new()
	var fill: Color = Color(0.09, 0.065, 0.052).lerp(accent.darkened(0.38), 0.58)
	style.bg_color = Color(fill.r, fill.g, fill.b, 0.92)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.98 if active else 0.78)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	if active:
		style.bg_color = Color(fill.r, fill.g, fill.b, 0.97).lightened(0.08)
		style.shadow_color = Color(accent.r, accent.g, accent.b, 0.36)
		style.shadow_size = 4
		style.shadow_offset = Vector2.ZERO
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style

func _add_token_to_summary_row(row: HBoxContainer, token: Dictionary, icon_size: float, label_size: int, conditional: bool = false) -> void:
	var tooltip: String = ActionIcons.token_tooltip(token)
	if str(token.get("kind", "")) == "aoe_pattern":
		var pattern_view := AoePatternView.new()
		pattern_view.setup(token.get("pattern", []), bool(token.get("show_origin", false)), tooltip, _aoe_pattern_scale(icon_size))
		row.add_child(pattern_view)
		return
	var icon := TextureRect.new()
	icon.custom_minimum_size = _summary_icon_box_size(token, icon_size)
	icon.texture = ActionIcons.icon_texture(str(token.get("icon", "")))
	icon.expand_mode = 1
	icon.stretch_mode = 5
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.tooltip_text = tooltip
	row.add_child(icon)
	var value_text: String = ActionIcons.token_value_text(token)
	if value_text.is_empty():
		if ActionIcons.token_is_modified(token):
			_add_token_modifier_marker(row, tooltip, label_size, conditional)
		return
	var label := Label.new()
	label.text = value_text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.tooltip_text = tooltip
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(label, label_size)
	label.add_theme_color_override("font_color", _token_value_color(token, conditional))
	label.add_theme_color_override("font_outline_color", _token_outline_color(conditional))
	label.add_theme_constant_override("outline_size", 2 if conditional else 1)
	row.add_child(label)
	if ActionIcons.token_is_modified(token):
		_add_token_modifier_marker(row, tooltip, label_size, conditional)

func _add_token_modifier_marker(row: HBoxContainer, tooltip: String, label_size: int, conditional: bool = false) -> void:
	var marker := Label.new()
	marker.text = "+"
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.tooltip_text = tooltip
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTypography.set_label_size(marker, maxi(_scaled_card_font_size(10, 7), label_size - 1))
	marker.add_theme_color_override("font_color", Color(DAMAGE_BONUS_COLOR))
	marker.add_theme_color_override("font_outline_color", _token_outline_color(conditional))
	marker.add_theme_constant_override("outline_size", 2 if conditional else 1)
	row.add_child(marker)

func _summary_icon_size() -> float:
	var width: float = _card_visual_width()
	return _scaled_card_value(22.0 if width <= COMPACT_CARD_WIDTH else 26.0, 10.0)

func _aoe_pattern_scale(icon_size: float) -> float:
	var width: float = _card_visual_width()
	if width <= COMPACT_CARD_WIDTH:
		return clampf(icon_size / 40.0, 0.42, 0.78)
	return clampf(icon_size / 30.0, 0.52, 1.0)

func _summary_layout_metrics(rendered_rows: Array) -> Dictionary:
	var width: float = _card_visual_width()
	var compact: bool = width <= COMPACT_CARD_WIDTH
	var details_height: float = details_panel.custom_minimum_size.y if details_panel.custom_minimum_size.y > 0.0 else desc_label.custom_minimum_size.y
	var available_height: float = maxf(_scaled_card_value(56.0, 28.0), details_height - _scaled_card_value(SUMMARY_VERTICAL_PADDING, 4.0))
	var available_width: float = maxf(_scaled_card_value(52.0, 28.0), width - _scaled_card_value(CARD_FRAME_MARGIN, 14.0) - _scaled_card_value(12.0, 4.0))
	var base_candidates: Array = [28.0, 26.0, 24.0, 22.0, 20.0, 18.0, 16.0] if compact else [30.0, 28.0, 26.0, 24.0, 22.0, 20.0]
	var icon_candidates: Array = []
	for candidate_var: Variant in base_candidates:
		icon_candidates.append(_scaled_card_value(float(candidate_var), 10.0))
	var row_count: int = maxi(1, rendered_rows.size())
	var minimum_label_size: int = _summary_min_label_size()
	for candidate_var: Variant in icon_candidates:
		var icon_size: float = float(candidate_var)
		var label_size: int = maxi(minimum_label_size, int(round(icon_size * 0.58)))
		var row_gap: int = _summary_row_gap(icon_size, row_count)
		if _summary_height_estimate(rendered_rows, icon_size, label_size, row_gap) <= available_height and _summary_width_estimate(rendered_rows, icon_size, label_size, row_gap) <= available_width:
			return {
				"icon_size": icon_size,
				"label_size": label_size,
				"row_gap": row_gap
			}
	var fallback_icon: float = float(icon_candidates[icon_candidates.size() - 1])
	return {
		"icon_size": fallback_icon,
		"label_size": maxi(minimum_label_size, int(round(fallback_icon * 0.58))),
		"row_gap": _summary_row_gap(fallback_icon, row_count)
	}

func _summary_row_gap(icon_size: float, row_count: int) -> int:
	var base_gap: int = 4 if icon_size <= _scaled_card_value(22.0, 10.0) else 5 if icon_size <= _scaled_card_value(26.0, 12.0) else 6
	var gap: int = _scaled_card_int(base_gap, 1)
	if row_count >= 3:
		gap -= 1
	if row_count >= 4:
		gap -= 1
	return maxi(1, gap)

func _summary_min_label_size() -> int:
	return _scaled_card_font_size(12, 7)

func _summary_height_estimate(rendered_rows: Array, icon_size: float, label_size: int, row_gap: int) -> float:
	var font: Font = UiTypography.default_font(self)
	var scaled_label_size: int = UiTypography.scaled_size(self, label_size)
	var label_height: float = float(scaled_label_size)
	if font != null:
		label_height = font.get_height(scaled_label_size)
	var total_height: float = 0.0
	for segment_var: Variant in rendered_rows:
		var row_height: float = maxf(icon_size, label_height)
		if typeof(segment_var) == TYPE_ARRAY:
			for token_var: Variant in segment_var as Array:
				if typeof(token_var) != TYPE_DICTIONARY:
					continue
				var token: Dictionary = token_var
				if str(token.get("kind", "")) == "aoe_pattern":
					continue
				row_height = maxf(row_height, _summary_icon_box_size(token, icon_size).y)
		total_height += row_height
	return total_height + float(maxi(0, rendered_rows.size() - 1) * row_gap)

func _summary_width_estimate(rendered_rows: Array, icon_size: float, label_size: int, row_gap: int) -> float:
	var widest: float = 0.0
	for segment_var: Variant in rendered_rows:
		if typeof(segment_var) != TYPE_ARRAY:
			continue
		widest = maxf(widest, _summary_segment_width_estimate(segment_var as Array, icon_size, label_size, row_gap))
	return widest

func _summary_segment_width_estimate(segment: Array, icon_size: float, label_size: int, row_gap: int) -> float:
	var child_width: float = 0.0
	var child_count: int = 0
	for token_var: Variant in segment:
		if typeof(token_var) != TYPE_DICTIONARY:
			continue
		var token: Dictionary = token_var
		if str(token.get("kind", "")) == "aoe_pattern":
			child_width += maxf(_scaled_card_value(34.0, 18.0), icon_size * 1.5)
			child_count += 1
			continue
		child_width += _summary_icon_box_size(token, icon_size).x
		child_count += 1
		var value_text: String = ActionIcons.token_value_text(token)
		if not value_text.is_empty():
			child_width += _summary_text_width(value_text, label_size)
			child_count += 1
		if ActionIcons.token_is_modified(token):
			child_width += _summary_text_width("+", maxi(10, label_size - 1))
			child_count += 1
	return child_width + float(maxi(0, child_count - 1) * row_gap)

func _summary_icon_box_size(token: Dictionary, icon_size: float) -> Vector2:
	if str(token.get("icon", "")) == "flurry":
		return Vector2(icon_size * FLURRY_ICON_WIDTH_SCALE, icon_size * FLURRY_ICON_HEIGHT_SCALE)
	return Vector2(icon_size, icon_size)

func _summary_text_width(text: String, label_size: int) -> float:
	var scaled_label_size: int = UiTypography.scaled_size(self, label_size)
	var font: Font = UiTypography.default_font(self)
	if font == null:
		return float(text.length()) * float(scaled_label_size) * 0.62
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, scaled_label_size).x

func _card_visual_width() -> float:
	var width: float = size.x if size.x > 0.0 else custom_minimum_size.x
	if width <= 0.0:
		width = COMPACT_CARD_WIDTH
	var scale_x: float = absf(scale.x)
	if is_inside_tree():
		scale_x = absf(get_global_transform().get_scale().x)
	if scale_x > 0.0 and scale_x < 0.98:
		return width * scale_x
	return width

func _summary_token_segments(tokens: Array) -> Array:
	var clean_tokens: Array = []
	var contains_pattern: bool = false
	var keep_row_together: bool = false
	var valued_tokens: int = 0
	for token_var: Variant in tokens:
		if typeof(token_var) != TYPE_DICTIONARY:
			continue
		var token: Dictionary = token_var
		clean_tokens.append(token)
		keep_row_together = keep_row_together or bool(token.get("keep_row_together", false))
		if str(token.get("kind", "")) == "aoe_pattern":
			contains_pattern = true
		if token.has("value"):
			valued_tokens += 1
	if keep_row_together:
		return [clean_tokens]
	if clean_tokens.size() <= 3 and not contains_pattern:
		return [clean_tokens]
	var max_tokens_per_segment: int = 2 if contains_pattern or valued_tokens >= 3 else 3
	var segments: Array = []
	var current: Array = []
	for token_var: Variant in clean_tokens:
		current.append(token_var)
		if current.size() >= max_tokens_per_segment:
			segments.append(current)
			current = []
	if not current.is_empty():
		segments.append(current)
	return segments

func _token_value_color(token: Dictionary, conditional: bool = false) -> Color:
	if conditional:
		return Color(CONDITIONAL_TEXT_COLOR)
	match str(token.get("tone", "neutral")):
		"bonus":
			return Color(DAMAGE_BONUS_COLOR)
		"penalty":
			return Color(DAMAGE_PENALTY_COLOR)
		_:
			return Color(DAMAGE_NEUTRAL_COLOR)

func _token_outline_color(conditional: bool) -> Color:
	return Color(CONDITIONAL_OUTLINE_COLOR) if conditional else Color("f8f1dd")

func _display_card_def() -> Dictionary:
	return _card_override.duplicate(true) if not _card_override.is_empty() else GameData.card_def(card_id)

func _base_title_size() -> int:
	var width: float = size.x if size.x > 0.0 else custom_minimum_size.x
	if width <= COMPACT_CARD_WIDTH:
		return _scaled_card_font_size(17, 8)
	if width <= HAND_TITLE_WIDTH_MAX:
		return _scaled_card_font_size(18, 9)
	return _scaled_card_font_size(19, 9)

func _queue_title_refit() -> void:
	if is_node_ready():
		call_deferred("_fit_title_label", _base_title_size())

func _fit_title_label(base_size: int) -> void:
	if title_label == null:
		return
	var font: Font = UiTypography.default_font(title_label)
	if font == null:
		UiTypography.set_label_size(title_label, _relieved_title_size(base_size))
		return
	var available_width: float = _title_nameplate_width()
	var available_height: float = maxf(_scaled_card_value(28.0, 16.0), title_label.custom_minimum_size.y)
	var min_title_size: int = _title_min_size()
	for candidate: int in range(base_size, min_title_size - 1, -1):
		var render_size: int = _relieved_title_size(candidate)
		var scaled_size: int = UiTypography.scaled_size(title_label, render_size)
		if _title_fits(font, title_label.text, scaled_size, available_width, available_height):
			UiTypography.set_label_size(title_label, render_size)
			return
	UiTypography.set_label_size(title_label, min_title_size)

func _relieved_title_size(candidate: int) -> int:
	var relief: int = _scaled_card_int(TITLE_FIT_RELIEF, 1)
	return mini(_title_max_render_size(), maxi(_title_min_size(), candidate - relief))

func _title_min_size() -> int:
	return _scaled_card_font_size(TITLE_MIN_SIZE, 7)

func _title_max_render_size() -> int:
	return _scaled_card_font_size(TITLE_MAX_RENDER_SIZE, 8)

func _title_available_width() -> float:
	var width: float = size.x if size.x > 0.0 else custom_minimum_size.x
	var card_inner_width: float = maxf(_scaled_card_value(80.0, 42.0), width - _scaled_card_value(32.0, 12.0))
	if title_label.size.x > 0.0:
		return minf(title_label.size.x, card_inner_width)
	var top_row: Control = title_label.get_parent() as Control
	if top_row != null and top_row.size.x > 0.0:
		return minf(top_row.size.x, card_inner_width)
	return card_inner_width

func _title_nameplate_width() -> float:
	var width: float = size.x if size.x > 0.0 else custom_minimum_size.x
	var visual_width: float = maxf(72.0, width * TITLE_NAMEPLATE_WIDTH_RATIO)
	return minf(_title_available_width(), visual_width)

func _title_fits(font: Font, title: String, font_size: int, available_width: float, available_height: float) -> bool:
	if title.strip_edges().is_empty():
		return true
	var longest_word_width: float = 0.0
	for word: String in title.split(" ", false):
		longest_word_width = maxf(longest_word_width, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)
	var full_width: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var line_height: float = font.get_height(font_size)
	if longest_word_width > available_width:
		return false
	return full_width <= available_width and line_height <= available_height + 3.0

func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _on_local_mouse_entered() -> void:
	_local_hovered = true
	if _time_badge != null:
		_time_badge.set_hovered(true)
	_update_pose()

func _on_local_mouse_exited() -> void:
	_local_hovered = false
	if _time_badge != null:
		_time_badge.set_hovered(false)
	_update_pose()

func play_ready_wave(delay_seconds: float = 0.0) -> void:
	if not is_node_ready() or top_level or not _interactive or _dimmed or not _usable:
		return
	if _ready_wave_tween != null:
		_ready_wave_tween.kill()
	_ready_wave_active = true
	_ready_wave_progress = 0.0
	set_meta("ready_wave_active", true)
	_ensure_ready_wave_glow()
	if _ready_wave_glow != null:
		_sync_ready_wave_glow_geometry()
		_ready_wave_glow.visible = true
		_ready_wave_glow.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_ready_wave_glow.scale = Vector2(0.995, 0.995)
	_ready_wave_tween = create_tween()
	var safe_delay: float = maxf(0.0, delay_seconds)
	if safe_delay > 0.0:
		_ready_wave_tween.tween_interval(safe_delay)
	_ready_wave_tween.tween_method(_set_ready_wave_progress, 0.0, 1.0, READY_WAVE_RISE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _ready_wave_glow != null:
		_ready_wave_tween.parallel().tween_property(_ready_wave_glow, "modulate:a", 0.82, READY_WAVE_RISE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_ready_wave_tween.parallel().tween_property(_ready_wave_glow, "scale", Vector2(1.012, 1.012), READY_WAVE_RISE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_ready_wave_tween.tween_method(_set_ready_wave_progress, 1.0, 0.0, READY_WAVE_SETTLE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _ready_wave_glow != null:
		_ready_wave_tween.parallel().tween_property(_ready_wave_glow, "modulate:a", 0.0, READY_WAVE_SETTLE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_ready_wave_tween.parallel().tween_property(_ready_wave_glow, "scale", Vector2(1.028, 1.028), READY_WAVE_SETTLE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_ready_wave_tween.tween_callback(_finish_ready_wave)

func _set_ready_wave_progress(progress: float) -> void:
	_ready_wave_progress = clampf(progress, 0.0, 1.0)
	_apply_pose_now()

func _finish_ready_wave() -> void:
	_ready_wave_progress = 0.0
	_ready_wave_active = false
	set_meta("ready_wave_active", false)
	if _ready_wave_glow != null:
		_ready_wave_glow.visible = false
	_apply_pose_now()

func _ensure_ready_wave_glow() -> void:
	if _ready_wave_glow != null:
		return
	_ready_wave_glow = PanelContainer.new()
	_ready_wave_glow.name = "ReadyWaveGlow"
	_ready_wave_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ready_wave_glow.z_index = 10
	_ready_wave_glow.visible = false
	_ready_wave_glow.add_theme_stylebox_override("panel", _ready_wave_glow_style())
	add_child(_ready_wave_glow)
	_sync_ready_wave_glow_geometry()

func _sync_ready_wave_glow_geometry() -> void:
	if _ready_wave_glow == null:
		return
	_ready_wave_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ready_wave_glow.offset_left = READY_WAVE_GLOW_INSET
	_ready_wave_glow.offset_top = READY_WAVE_GLOW_INSET
	_ready_wave_glow.offset_right = -READY_WAVE_GLOW_INSET
	_ready_wave_glow.offset_bottom = -READY_WAVE_GLOW_INSET
	var base_size: Vector2 = size if size.x > 0.0 and size.y > 0.0 else BASE_CARD_SIZE
	var glow_size: Vector2 = base_size - Vector2(READY_WAVE_GLOW_INSET * 2.0, READY_WAVE_GLOW_INSET * 2.0)
	_ready_wave_glow.pivot_offset = glow_size * 0.5

func _ready_wave_glow_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.78, 0.30, 0.035)
	style.border_color = Color(1.0, 0.88, 0.48, 0.34)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_right = 18
	style.corner_radius_bottom_left = 18
	style.shadow_color = Color(1.0, 0.62, 0.22, 0.18)
	style.shadow_size = 10
	style.shadow_offset = Vector2.ZERO
	return style

func _update_pose(immediate: bool = false) -> void:
	if not is_node_ready():
		return
	var pose: Dictionary = _pose_target()
	var lift: float = float(pose.get("lift", 0.0))
	var target_scale: Vector2 = pose.get("scale", Vector2.ONE)
	z_index = 20 if lift < 0.0 else 0
	if _pose_tween != null:
		_pose_tween.kill()
	if top_level:
		scale = target_scale
		return
	if immediate or _ready_wave_active or not is_inside_tree():
		_apply_pose_now()
		return
	_pose_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(self, "position:y", lift, 0.12)
	_pose_tween.parallel().tween_property(self, "scale", target_scale, 0.12)

func _pose_target() -> Dictionary:
	var lift: float = 0.0
	var target_scale: Vector2 = Vector2.ONE
	if _local_hovered and _interactive and not _dimmed:
		lift = _hover_lift
		target_scale = Vector2.ONE * _hover_scale
	elif _selected or _previewed:
		lift = SELECTED_LIFT
		target_scale = Vector2.ONE * SELECTED_SCALE
	if _ready_wave_progress > 0.0:
		lift += READY_WAVE_LIFT * _ready_wave_progress
		target_scale *= 1.0 + READY_WAVE_SCALE_BONUS * _ready_wave_progress
	return {"lift": lift, "scale": target_scale}

func _apply_pose_now() -> void:
	var pose: Dictionary = _pose_target()
	var lift: float = float(pose.get("lift", 0.0))
	var target_scale: Vector2 = pose.get("scale", Vector2.ONE)
	z_index = 20 if lift < 0.0 else 0
	if top_level:
		scale = target_scale
		return
	position = Vector2(position.x, lift)
	scale = target_scale
