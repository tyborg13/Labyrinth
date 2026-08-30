extends Control

const AssetLoader = preload("res://scripts/asset_loader.gd")

const STATE_NORMAL: String = "normal"
const STATE_HOVER: String = "hover"
const STATE_PRESSED: String = "pressed"
const STATE_DISABLED: String = "disabled"
const STATE_SELECTED: String = "selected"
const STATE_FOCUS: String = "focus"

const VARIANT_COMPACT: String = "compact"
const VARIANT_DESTRUCTIVE: String = "destructive"
const VARIANT_ICON: String = "icon"
const VARIANT_SELECTED: String = "selected"
const VARIANT_UMBRA: String = "umbra"

const UMBRA_BUTTON_IDLE_PATH := "res://assets/art/ui/main_menu_umbra_button_idle.png"
const UMBRA_BUTTON_FOCUSED_PATH := "res://assets/art/ui/main_menu_umbra_button_focused.png"
const UMBRA_FOCUS_MARKER_LEFT_PATH := "res://assets/art/ui/main_menu_umbra_focus_marker_left.png"
const UMBRA_FOCUS_MARKER_RIGHT_PATH := "res://assets/art/ui/main_menu_umbra_focus_marker_right.png"

static var _umbra_button_idle_texture: Texture2D
static var _umbra_button_focused_texture: Texture2D
static var _umbra_focus_marker_left_texture: Texture2D
static var _umbra_focus_marker_right_texture: Texture2D

var _button: BaseButton
var _variant: String = "standard"

func configure(button: BaseButton, variant: String) -> void:
	_button = button
	_variant = variant
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = variant == VARIANT_UMBRA
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var redraw := Callable(self, "queue_redraw")
	if not button.draw.is_connected(redraw):
		button.draw.connect(redraw)
	if not button.resized.is_connected(redraw):
		button.resized.connect(redraw)
	queue_redraw()

func set_variant(variant: String) -> void:
	_variant = variant
	show_behind_parent = variant == VARIANT_UMBRA
	queue_redraw()

func _draw() -> void:
	if _button == null or size.x < 20.0 or size.y < 20.0:
		return
	var state: String = _visual_state()
	if _variant == VARIANT_UMBRA:
		_draw_umbra_raster(state)
		return
	var accent: Color = _accent_color(state)
	var muted: Color = Color(accent.r, accent.g, accent.b, accent.a * 0.42)
	var inset: float = 4.5 if _variant != VARIANT_COMPACT else 3.5
	var left: float = inset
	var right: float = size.x - inset
	var top: float = inset
	var bottom: float = size.y - inset
	var arm: float = clampf(size.y * 0.23, 6.0, 12.0)
	var stroke: float = 1.0

	# Fine metal inlay: short corner cuts scale cleanly without stretching artwork.
	_draw_corner(Vector2(left, top), Vector2(1.0, 1.0), arm, muted, stroke)
	_draw_corner(Vector2(right, top), Vector2(-1.0, 1.0), arm, muted, stroke)
	_draw_corner(Vector2(left, bottom), Vector2(1.0, -1.0), arm, muted, stroke)
	_draw_corner(Vector2(right, bottom), Vector2(-1.0, -1.0), arm, muted, stroke)

	if _variant != VARIANT_ICON and size.x >= 96.0:
		var rail_inset: float = maxf(arm + 10.0, size.x * 0.18)
		draw_line(Vector2(rail_inset, top), Vector2(size.x - rail_inset, top), Color(accent.r, accent.g, accent.b, accent.a * 0.26), stroke)
		draw_line(Vector2(rail_inset, bottom), Vector2(size.x - rail_inset, bottom), Color(0.02, 0.02, 0.025, 0.72), stroke)

	if _variant != VARIANT_COMPACT:
		var rivet_radius: float = 1.35 if _variant == VARIANT_ICON else 1.1
		draw_circle(Vector2(left + 3.0, size.y * 0.5), rivet_radius, muted)
		draw_circle(Vector2(right - 3.0, size.y * 0.5), rivet_radius, muted)

	if state in [STATE_HOVER, STATE_PRESSED, STATE_SELECTED, STATE_FOCUS] or _variant in [VARIANT_DESTRUCTIVE, VARIANT_SELECTED]:
		var ember: Color = Color("f19a55") if _variant != VARIANT_DESTRUCTIVE else Color("ff7c63")
		ember.a = 0.88 if state != STATE_DISABLED else 0.22
		draw_line(Vector2(left + 1.0, size.y * 0.36), Vector2(left + 1.0, size.y * 0.64), ember, 2.0)

	if state == STATE_FOCUS:
		_draw_focus_brackets(Color("ffe3a0"))

func _draw_umbra_raster(state: String) -> void:
	if not _ensure_umbra_raster_textures():
		return
	var selected: bool = state in [STATE_HOVER, STATE_PRESSED, STATE_SELECTED, STATE_FOCUS]
	var texture: Texture2D = _umbra_button_focused_texture if selected else _umbra_button_idle_texture
	var tint := Color.WHITE
	if state == STATE_DISABLED:
		tint = Color(0.48, 0.46, 0.44, 0.78)
	elif state == STATE_PRESSED:
		tint = Color(0.88, 0.84, 0.80, 1.0)
	var button_rect := Rect2(Vector2(-2.0, -5.0), Vector2(size.x + 4.0, size.y + 10.0))
	draw_texture_rect(texture, button_rect, false, tint)
	if selected:
		_draw_umbra_raster_markers(state == STATE_PRESSED)

func _draw_umbra_raster_markers(pressed: bool) -> void:
	var marker_size := Vector2(44.0, 72.0)
	var center_y: float = size.y * 0.5 + (1.5 if pressed else 0.0)
	var marker_tint := Color(0.88, 0.84, 0.80, 1.0) if pressed else Color.WHITE
	draw_texture_rect(
		_umbra_focus_marker_left_texture,
		Rect2(Vector2(-38.0, center_y - marker_size.y * 0.5), marker_size),
		false,
		marker_tint
	)
	draw_texture_rect(
		_umbra_focus_marker_right_texture,
		Rect2(Vector2(size.x - 6.0, center_y - marker_size.y * 0.5), marker_size),
		false,
		marker_tint
	)

func _ensure_umbra_raster_textures() -> bool:
	if _umbra_button_idle_texture == null:
		_umbra_button_idle_texture = AssetLoader.load_texture_source_first(UMBRA_BUTTON_IDLE_PATH)
	if _umbra_button_focused_texture == null:
		_umbra_button_focused_texture = AssetLoader.load_texture_source_first(UMBRA_BUTTON_FOCUSED_PATH)
	if _umbra_focus_marker_left_texture == null:
		_umbra_focus_marker_left_texture = AssetLoader.load_texture_source_first(UMBRA_FOCUS_MARKER_LEFT_PATH)
	if _umbra_focus_marker_right_texture == null:
		_umbra_focus_marker_right_texture = AssetLoader.load_texture_source_first(UMBRA_FOCUS_MARKER_RIGHT_PATH)
	return (
		_umbra_button_idle_texture != null
		and _umbra_button_focused_texture != null
		and _umbra_focus_marker_left_texture != null
		and _umbra_focus_marker_right_texture != null
	)

func _draw_corner(origin: Vector2, direction: Vector2, arm: float, color: Color, width: float) -> void:
	var horizontal_end := origin + Vector2(direction.x * arm, 0.0)
	var vertical_end := origin + Vector2(0.0, direction.y * minf(arm, 8.0))
	draw_line(origin, horizontal_end, color, width)
	draw_line(origin, vertical_end, color, width)

func _draw_focus_brackets(color: Color) -> void:
	var inset: float = 1.5
	var arm: float = clampf(size.y * 0.26, 8.0, 14.0)
	var points := [
		{"origin": Vector2(inset, inset), "direction": Vector2(1.0, 1.0)},
		{"origin": Vector2(size.x - inset, inset), "direction": Vector2(-1.0, 1.0)},
		{"origin": Vector2(inset, size.y - inset), "direction": Vector2(1.0, -1.0)},
		{"origin": Vector2(size.x - inset, size.y - inset), "direction": Vector2(-1.0, -1.0)}
	]
	for spec: Dictionary in points:
		_draw_corner(spec["origin"], spec["direction"], arm, color, 2.0)

func _visual_state() -> String:
	if _button == null:
		return STATE_NORMAL
	var forced_state: String = str(_button.get_meta("button_gallery_state", ""))
	if not forced_state.is_empty():
		return forced_state
	if _variant == VARIANT_UMBRA:
		return _umbra_visual_state()
	if _button.disabled:
		return STATE_DISABLED
	if _button.has_focus():
		return STATE_FOCUS
	if _button.button_pressed:
		return STATE_SELECTED
	if _button.is_pressed():
		return STATE_PRESSED
	if _button.is_hovered():
		return STATE_HOVER
	if bool(_button.get_meta("umbra_selected", false)):
		return STATE_SELECTED
	return STATE_NORMAL

func _umbra_visual_state() -> String:
	if _button.disabled:
		return STATE_DISABLED
	if not bool(_button.get_meta("umbra_selected", false)):
		return STATE_NORMAL
	if _button.is_pressed():
		return STATE_PRESSED
	if _button.has_focus():
		return STATE_FOCUS
	if _button.is_hovered():
		return STATE_HOVER
	return STATE_SELECTED

func _accent_color(state: String) -> Color:
	if state == STATE_DISABLED:
		return Color("6c6458")
	if _variant == VARIANT_DESTRUCTIVE:
		return Color("d56858") if state == STATE_NORMAL else Color("ff9a73")
	if _variant == VARIANT_SELECTED or state == STATE_SELECTED:
		return Color("f0b75b")
	if state == STATE_FOCUS:
		return Color("ffe3a0")
	if state in [STATE_HOVER, STATE_PRESSED]:
		return Color("e4b66b")
	return Color("9b7844")
