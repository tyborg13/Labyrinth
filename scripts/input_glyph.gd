extends Control
class_name InputGlyph

const InputRouterScript = preload("res://scripts/input_router.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const STICK_LABEL_SIZE: int = 12
const PREVIOUS_STICK_LABEL_SIZE: int = 11

const DECK_FACE_FILL := Color("dedbd2")
const DECK_KEY_FILL := Color("d8d5ce")
const DECK_BORDER := Color("f4efe3")
const DECK_INK := Color("242126")
const DARK_BORDER := Color("d3a85f")
const DARK_KEY_INK := Color("fff7e4")
const FACE_BLUE := Color("4fa5dc")
const FACE_RED := Color("e05b55")
const FACE_GREEN := Color("62bb6a")
const FACE_PINK := Color("d98cbf")
const PLAYSTATION_SYMBOL_HALF_SPAN_RATIO: float = 0.52
const PLAYSTATION_CIRCLE_RADIUS_RATIO: float = 0.30
const PLAYSTATION_SYMBOL_STROKE: float = 2.5
const PLAYSTATION_TRIANGLE_CENTER_OFFSET: float = 1.0
const PLAYSTATION_SQUARE_CORNER_RADIUS: float = 1.0

const FACE_ACTIONS: Array[StringName] = Array([
	InputRouterScript.ACTION_ACCEPT,
	InputRouterScript.ACTION_CANCEL,
	InputRouterScript.ACTION_HAND_TOGGLE,
	InputRouterScript.ACTION_PASS,
], TYPE_STRING_NAME, "", null)
const SHOULDER_ACTIONS: Array[StringName] = Array([
	InputRouterScript.ACTION_HAND_PREVIOUS,
	InputRouterScript.ACTION_HAND_NEXT,
], TYPE_STRING_NAME, "", null)
const PAIRED_KEY_ACTIONS: Array[StringName] = Array([
	InputRouterScript.ACTION_HAND_BUMPERS,
	InputRouterScript.ACTION_MAP_ZOOM,
], TYPE_STRING_NAME, "", null)

var action_name: StringName = InputRouterScript.ACTION_ACCEPT
var family: String = InputRouterScript.FAMILY_XBOX

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = _scaled_preferred_size()
	queue_redraw()

func configure(next_action_name: StringName, next_family: String) -> void:
	action_name = next_action_name
	family = next_family if next_family in InputRouterScript.CONTROLLER_FAMILIES else InputRouterScript.FAMILY_XBOX
	custom_minimum_size = _scaled_preferred_size()
	queue_redraw()

func _draw() -> void:
	var glyph_text: String = _glyph_text()
	var rect := Rect2(Vector2.ZERO, size)
	var face_action: bool = action_name in FACE_ACTIONS
	if face_action:
		_draw_face_button(rect, glyph_text)
	elif action_name == &"controller_dpad":
		_draw_dpad(rect)
	elif action_name == &"controller_move" or action_name == InputRouterScript.ACTION_EMPOWER:
		_draw_stick(rect, glyph_text)
	else:
		_draw_rounded_key(rect, glyph_text)

func _draw_face_button(rect: Rect2, glyph_text: String) -> void:
	var center: Vector2 = rect.get_center()
	var radius: float = minf(rect.size.x, rect.size.y) * 0.42
	var accent: Color = _face_accent()
	var fill: Color = Color("2a2526") if family != InputRouterScript.FAMILY_STEAM_DECK else DECK_FACE_FILL
	var ink: Color = Color("fff8e8") if family != InputRouterScript.FAMILY_STEAM_DECK else DECK_INK
	draw_circle(center + Vector2(0.0, 1.5), radius + 2.0, Color(0.0, 0.0, 0.0, 0.48))
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0.0, TAU, 36, accent, 2.5, true)
	if family == InputRouterScript.FAMILY_PLAYSTATION:
		_draw_playstation_symbol(center, radius, ink)
	else:
		_draw_centered_text(glyph_text, rect, ink, UiTypography.scaled_size(self, 16))

func _draw_playstation_symbol(center: Vector2, radius: float, ink: Color) -> void:
	var half_span: float = radius * PLAYSTATION_SYMBOL_HALF_SPAN_RATIO
	var stroke: float = UiTypography.scaled_value(self, PLAYSTATION_SYMBOL_STROKE)
	match action_name:
		InputRouterScript.ACTION_ACCEPT:
			var down_right := Vector2(half_span, half_span)
			var up_right := Vector2(half_span, -half_span)
			draw_line(center - down_right, center + down_right, ink, stroke, true)
			draw_line(center - up_right, center + up_right, ink, stroke, true)
		InputRouterScript.ACTION_CANCEL:
			draw_arc(center, radius * PLAYSTATION_CIRCLE_RADIUS_RATIO, 0.0, TAU, 36, ink, stroke, true)
		InputRouterScript.ACTION_PASS:
			var half_height: float = half_span * sqrt(3.0) * 0.5
			var triangle_center: Vector2 = center + Vector2(0.0, UiTypography.scaled_value(self, PLAYSTATION_TRIANGLE_CENTER_OFFSET))
			var tip: Vector2 = triangle_center + Vector2(0.0, -half_height)
			draw_polyline(PackedVector2Array([
				tip,
				triangle_center + Vector2(half_span, half_height),
				triangle_center + Vector2(-half_span, half_height),
				tip,
			]), ink, stroke, true)
		InputRouterScript.ACTION_HAND_TOGGLE:
			var corner_radius: float = UiTypography.scaled_value(self, PLAYSTATION_SQUARE_CORNER_RADIUS)
			_draw_playstation_square(center, half_span, corner_radius, ink, stroke)

func _draw_playstation_square(center: Vector2, half_span: float, corner_radius: float, ink: Color, stroke: float) -> void:
	var corner_offset: float = half_span - corner_radius
	var points := PackedVector2Array()
	for side: int in range(4):
		var angle: float = side * PI / 2.0
		var arc_center: Vector2 = center + Vector2(corner_offset, corner_offset).rotated(angle)
		for step: int in range(4):
			points.append(arc_center + Vector2.from_angle(angle + step * PI / 6.0) * corner_radius)
	points.append(points[0])
	draw_polyline(points, ink, stroke, true)

func _draw_rounded_key(rect: Rect2, glyph_text: String) -> void:
	var inset := Rect2(rect.position + Vector2(1.0, 2.0), rect.size - Vector2(2.0, 4.0))
	var fill: Color = Color("28242a") if family != InputRouterScript.FAMILY_STEAM_DECK else DECK_KEY_FILL
	var border: Color = DARK_BORDER if family != InputRouterScript.FAMILY_STEAM_DECK else DECK_BORDER
	var ink: Color = DARK_KEY_INK if family != InputRouterScript.FAMILY_STEAM_DECK else DECK_INK
	draw_style_box(_rounded_style(Color(0.0, 0.0, 0.0, 0.42), Color(0.0, 0.0, 0.0, 0.0), 8), Rect2(inset.position + Vector2(0.0, 2.0), inset.size))
	draw_style_box(_rounded_style(fill, border, 8), inset)
	_draw_centered_text(glyph_text, inset, ink, _rounded_key_label_size())

func _rounded_key_label_size() -> int:
	var compact_label: bool = action_name in SHOULDER_ACTIONS or action_name in PAIRED_KEY_ACTIONS
	return UiTypography.scaled_size(self, 13 if compact_label else 17)

func _draw_dpad(rect: Rect2) -> void:
	var center: Vector2 = rect.get_center()
	var fill: Color = DECK_FACE_FILL if family == InputRouterScript.FAMILY_STEAM_DECK else Color("302b30")
	var border: Color = DECK_BORDER if family == InputRouterScript.FAMILY_STEAM_DECK else DARK_BORDER
	var arm: float = minf(rect.size.x, rect.size.y) * 0.22
	var span: float = arm * 2.8
	var horizontal := Rect2(center - Vector2(span, arm) * 0.5, Vector2(span, arm))
	var vertical := Rect2(center - Vector2(arm, span) * 0.5, Vector2(arm, span))
	draw_style_box(_rounded_style(fill, border, 3), horizontal)
	draw_style_box(_rounded_style(fill, border, 3), vertical)

func _draw_stick(rect: Rect2, glyph_text: String) -> void:
	var center: Vector2 = rect.get_center()
	var radius: float = minf(rect.size.x, rect.size.y) * 0.39
	var fill: Color = Color("2b272d") if family != InputRouterScript.FAMILY_STEAM_DECK else DECK_KEY_FILL
	var ink: Color = DARK_KEY_INK if family != InputRouterScript.FAMILY_STEAM_DECK else DECK_INK
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0.0, TAU, 32, DARK_BORDER, 2.0, true)
	_draw_centered_text(glyph_text, rect, ink, UiTypography.scaled_size(self, STICK_LABEL_SIZE))

func _draw_centered_text(text: String, rect: Rect2, color: Color, font_size: int) -> void:
	var font: Font = UiTypography.ui_font()
	if font == null:
		font = get_theme_default_font()
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := Vector2(rect.get_center().x - text_size.x * 0.5, rect.get_center().y + text_size.y * 0.34)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

func _glyph_text() -> String:
	var router: Node = get_node_or_null("/root/InputRouter")
	if router != null and router.has_method("glyph_label"):
		return str(router.call("glyph_label", action_name, family))
	return InputRouterScript.glyph_label_for_family(action_name, family)

func _face_accent() -> Color:
	if family == InputRouterScript.FAMILY_STEAM_DECK:
		return DECK_BORDER
	match action_name:
		InputRouterScript.ACTION_ACCEPT:
			return FACE_BLUE if family == InputRouterScript.FAMILY_PLAYSTATION else FACE_GREEN
		InputRouterScript.ACTION_CANCEL:
			return FACE_RED
		InputRouterScript.ACTION_HAND_TOGGLE:
			return FACE_PINK if family == InputRouterScript.FAMILY_PLAYSTATION else FACE_BLUE
		InputRouterScript.ACTION_PASS:
			return FACE_GREEN if family == InputRouterScript.FAMILY_PLAYSTATION else Color("e5c957")
	return DARK_BORDER

static func preferred_size(next_action_name: StringName) -> Vector2:
	if next_action_name in FACE_ACTIONS:
		return Vector2(30.0, 30.0)
	if next_action_name in PAIRED_KEY_ACTIONS:
		return Vector2(68.0, 27.0)
	if next_action_name in SHOULDER_ACTIONS:
		return Vector2(42.0, 27.0)
	if next_action_name in [&"controller_move", InputRouterScript.ACTION_EMPOWER]:
		# Grow the stick's box with its label so the two-letter glyph keeps its fit.
		return Vector2(34.0, 30.0) * float(STICK_LABEL_SIZE) / float(PREVIOUS_STICK_LABEL_SIZE)
	if next_action_name == &"controller_dpad":
		return Vector2(34.0, 30.0)
	return Vector2(36.0, 27.0)

func _scaled_preferred_size() -> Vector2:
	return preferred_size(action_name) * UiTypography.ui_scale(self)

static func _rounded_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	return style
