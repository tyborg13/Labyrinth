extends Control
class_name InputGlyph

const InputRouterScript = preload("res://scripts/input_router.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

const FACE_ACTIONS: Array[StringName] = [
	InputRouterScript.ACTION_ACCEPT,
	InputRouterScript.ACTION_CANCEL,
	InputRouterScript.ACTION_HAND_TOGGLE,
	InputRouterScript.ACTION_PASS,
]
const SHOULDER_ACTIONS: Array[StringName] = [
	InputRouterScript.ACTION_HAND_PREVIOUS,
	InputRouterScript.ACTION_HAND_NEXT,
	InputRouterScript.ACTION_HAND_BUMPERS,
]

var action_name: StringName = InputRouterScript.ACTION_ACCEPT
var family: String = InputRouterScript.FAMILY_XBOX

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = _scaled_preferred_size()
	queue_redraw()

func configure(next_action_name: StringName, next_family: String) -> void:
	action_name = next_action_name
	family = next_family if next_family in [InputRouterScript.FAMILY_XBOX, InputRouterScript.FAMILY_STEAM_DECK] else InputRouterScript.FAMILY_XBOX
	custom_minimum_size = _scaled_preferred_size()
	queue_redraw()

func _draw() -> void:
	var glyph_text: String = _glyph_text()
	var rect := Rect2(Vector2.ZERO, size)
	var face_action: bool = action_name in FACE_ACTIONS
	var shoulder_action: bool = action_name in SHOULDER_ACTIONS
	if face_action:
		_draw_face_button(rect, glyph_text)
	elif action_name == &"controller_dpad":
		_draw_dpad(rect)
	elif action_name == &"controller_move":
		_draw_stick(rect, glyph_text)
	else:
		_draw_rounded_key(rect, glyph_text, shoulder_action)

func _draw_face_button(rect: Rect2, glyph_text: String) -> void:
	var center: Vector2 = rect.get_center()
	var radius: float = minf(rect.size.x, rect.size.y) * 0.42
	var accent: Color = _face_accent()
	var fill: Color = Color("2a2526") if family == InputRouterScript.FAMILY_XBOX else Color("dedbd2")
	var ink: Color = Color("fff8e8") if family == InputRouterScript.FAMILY_XBOX else Color("242126")
	draw_circle(center + Vector2(0.0, 1.5), radius + 2.0, Color(0.0, 0.0, 0.0, 0.48))
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0.0, TAU, 36, accent, 2.5, true)
	_draw_centered_text(glyph_text, rect, ink, UiTypography.scaled_size(self, 16))

func _draw_rounded_key(rect: Rect2, glyph_text: String, shoulder_action: bool) -> void:
	var inset := Rect2(rect.position + Vector2(1.0, 2.0), rect.size - Vector2(2.0, 4.0))
	var fill: Color = Color("28242a") if family == InputRouterScript.FAMILY_XBOX else Color("d8d5ce")
	var border: Color = Color("d3a85f") if family == InputRouterScript.FAMILY_XBOX else Color("f4efe3")
	var ink: Color = Color("fff7e4") if family == InputRouterScript.FAMILY_XBOX else Color("242126")
	draw_style_box(_rounded_style(Color(0.0, 0.0, 0.0, 0.42), Color(0.0, 0.0, 0.0, 0.0), 8), Rect2(inset.position + Vector2(0.0, 2.0), inset.size))
	draw_style_box(_rounded_style(fill, border, 8), inset)
	_draw_centered_text(glyph_text, inset, ink, UiTypography.scaled_size(self, 13 if shoulder_action else 17))

func _draw_dpad(rect: Rect2) -> void:
	var center: Vector2 = rect.get_center()
	var fill: Color = Color("dedbd2") if family == InputRouterScript.FAMILY_STEAM_DECK else Color("302b30")
	var border: Color = Color("f4efe3") if family == InputRouterScript.FAMILY_STEAM_DECK else Color("d3a85f")
	var arm: float = minf(rect.size.x, rect.size.y) * 0.22
	var span: float = arm * 2.8
	var horizontal := Rect2(center - Vector2(span, arm) * 0.5, Vector2(span, arm))
	var vertical := Rect2(center - Vector2(arm, span) * 0.5, Vector2(arm, span))
	draw_style_box(_rounded_style(fill, border, 3), horizontal)
	draw_style_box(_rounded_style(fill, border, 3), vertical)

func _draw_stick(rect: Rect2, glyph_text: String) -> void:
	var center: Vector2 = rect.get_center()
	var radius: float = minf(rect.size.x, rect.size.y) * 0.39
	var fill: Color = Color("2b272d") if family == InputRouterScript.FAMILY_XBOX else Color("d8d5ce")
	var ink: Color = Color("fff7e4") if family == InputRouterScript.FAMILY_XBOX else Color("242126")
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0.0, TAU, 32, Color("d3a85f"), 2.0, true)
	_draw_centered_text(glyph_text, rect, ink, UiTypography.scaled_size(self, 11))

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
		return Color("f4efe3")
	match action_name:
		InputRouterScript.ACTION_ACCEPT:
			return Color("62bb6a")
		InputRouterScript.ACTION_CANCEL:
			return Color("e05b55")
		InputRouterScript.ACTION_HAND_TOGGLE:
			return Color("4fa5dc")
		InputRouterScript.ACTION_PASS:
			return Color("e5c957")
	return Color("d3a85f")

static func preferred_size(next_action_name: StringName) -> Vector2:
	if next_action_name in FACE_ACTIONS:
		return Vector2(30.0, 30.0)
	if next_action_name in SHOULDER_ACTIONS:
		return Vector2(68.0, 27.0) if next_action_name == InputRouterScript.ACTION_HAND_BUMPERS else Vector2(42.0, 27.0)
	if next_action_name in [&"controller_move", &"controller_dpad"]:
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
