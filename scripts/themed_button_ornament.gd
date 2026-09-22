extends Control

const AssetLoader = preload("res://scripts/asset_loader.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const GLINT_DURATION: float = 0.28

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
var _glint_progress: float = 1.0

func _ready() -> void:
	# Godot enables _process when an off-tree control enters the scene. Most
	# buttons are styled before that point, so explicitly keep idle art asleep.
	set_process(_glint_progress < 1.0 and _variant != VARIANT_UMBRA)

func configure(button: BaseButton, variant: String) -> void:
	_button = button
	_variant = variant
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = variant == VARIANT_UMBRA
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_process(false)
	for engagement_signal: Signal in [button.mouse_entered, button.focus_entered]:
		if not engagement_signal.is_connected(_on_engaged):
			engagement_signal.connect(_on_engaged)
	for departure_signal: Signal in [button.mouse_exited, button.focus_exited]:
		if not departure_signal.is_connected(_on_disengaged):
			departure_signal.connect(_on_disengaged)
	if not button.button_down.is_connected(_finish_glint):
		button.button_down.connect(_finish_glint)
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)
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
	if variant == VARIANT_UMBRA:
		_finish_glint()
	queue_redraw()

func _on_engaged() -> void:
	if _button == null or _button.disabled or _variant == VARIANT_UMBRA or not is_visible_in_tree():
		return
	if SettingsStore.applied_reduced_motion_enabled():
		_finish_glint()
		return
	_glint_progress = 0.0
	set_process(true)
	queue_redraw()

func _on_disengaged() -> void:
	if _button == null or (not _button.has_focus() and not _button.is_hovered()):
		_finish_glint()

func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_finish_glint()

func _process(delta: float) -> void:
	if _button == null or _button.disabled or SettingsStore.applied_reduced_motion_enabled():
		_finish_glint()
		return
	_glint_progress = minf(1.0, _glint_progress + delta / GLINT_DURATION)
	queue_redraw()
	if _glint_progress >= 1.0:
		set_process(false)

func _finish_glint() -> void:
	_glint_progress = 1.0
	set_process(false)
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

	_draw_material_bevel(state, accent)

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
		_draw_rivet(Vector2(left + 3.0, size.y * 0.5), rivet_radius, accent, state)
		_draw_rivet(Vector2(right - 3.0, size.y * 0.5), rivet_radius, accent, state)

	if state in [STATE_HOVER, STATE_PRESSED, STATE_SELECTED, STATE_FOCUS] or _variant in [VARIANT_DESTRUCTIVE, VARIANT_SELECTED]:
		var ember: Color = Color("f19a55") if _variant != VARIANT_DESTRUCTIVE else Color("ff7c63")
		ember.a = 0.88 if state != STATE_DISABLED else 0.22
		draw_line(Vector2(left + 1.0, size.y * 0.36), Vector2(left + 1.0, size.y * 0.64), ember, 2.0)

	if state == STATE_FOCUS:
		_draw_focus_brackets(Color("ffe3a0"))
	if _glint_progress < 1.0 and state != STATE_DISABLED:
		_draw_engagement_glint(accent)

# Restrict the material to the perimeter: the native Button owns the label,
# hit target and state fill. Light comes from above; pressed plates recess.
func _draw_material_bevel(state: String, accent: Color) -> void:
	var disabled: bool = state == STATE_DISABLED
	var pressed: bool = _material_is_pressed(state)
	var strength: float = 0.23 if disabled else 1.0
	var bright: Color = accent.lerp(Color("ffe4ad"), 0.45)
	bright.a = strength * (0.16 if pressed else 0.64)
	var facet: Color = Color(accent.r, accent.g, accent.b, strength * (0.045 if pressed else 0.14))
	var shade := Color(0.015, 0.012, 0.011, strength * (0.64 if pressed else 0.52))
	var bevel: float = 5.0 if _variant == VARIANT_COMPACT else 6.5
	var w: float = size.x
	var h: float = size.y
	draw_colored_polygon(PackedVector2Array([
		Vector2(6.0, 2.5), Vector2(w - 6.0, 2.5),
		Vector2(w - bevel - 3.0, bevel), Vector2(bevel + 3.0, bevel)
	]), facet)
	draw_line(Vector2(6.0, 2.5), Vector2(w - 6.0, 2.5), bright, 1.0, true)
	draw_line(Vector2(2.5, 7.0), Vector2(2.5, h - 7.0), Color(bright, bright.a * 0.38), 1.0, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(bevel, h - bevel), Vector2(w - bevel, h - bevel),
		Vector2(w - 4.0, h - 2.5), Vector2(4.0, h - 2.5)
	]), shade)
	draw_line(Vector2(5.0, h - 3.0), Vector2(w - 5.0, h - 3.0), Color(accent, strength * 0.23), 1.0, true)
	draw_line(Vector2(w - 3.0, 7.0), Vector2(w - 3.0, h - 6.0), shade, 1.0, true)
	# Two tiny corner facets catch light without a glossy wash over the face.
	for x: float in [7.0, w - 7.0]:
		draw_line(Vector2(x, 3.0), Vector2(x, bevel + 1.0), Color(bright, bright.a * 0.65), 1.0, true)

func _material_is_pressed(state: String) -> bool:
	if _button == null or not str(_button.get_meta("button_gallery_state", "")).is_empty():
		return state == STATE_PRESSED
	# Focus brackets and physical depth are independent. Native Button presses
	# commonly retain focus, while selected toggles remain latched and raised.
	if not _button.toggle_mode:
		return _button.get_draw_mode() in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED]
	return state == STATE_PRESSED

func _draw_rivet(center: Vector2, radius: float, accent: Color, state: String) -> void:
	var strength: float = 0.24 if state == STATE_DISABLED else 0.72
	draw_circle(center + Vector2(0.0, 0.7), radius + 0.6, Color(0.015, 0.012, 0.01, strength))
	draw_circle(center, radius, Color(accent, strength * 0.75))
	draw_circle(center + Vector2(-0.3, -0.4), radius * 0.43, Color(accent.lerp(Color("fff0c7"), 0.55), strength))

func _draw_engagement_glint(accent: Color) -> void:
	var envelope: float = sin(_glint_progress * PI)
	var center_x: float = lerpf(8.0, size.x - 8.0, smoothstep(0.0, 1.0, _glint_progress))
	var half_width: float = clampf(size.x * 0.12, 7.0, 28.0)
	var step: float = half_width / 4.0
	for segment: int in range(-4, 4):
		var a: float = clampf(center_x + float(segment) * step, 6.0, size.x - 6.0)
		var b: float = clampf(center_x + float(segment + 1) * step, 6.0, size.x - 6.0)
		var intensity: float = (1.0 - absf((float(segment) + 0.5) / 4.0)) * envelope
		draw_line(Vector2(a, 2.5), Vector2(b, 2.5), Color(1.0, 0.93, 0.73, intensity * 0.9), 1.5, true)
		draw_line(Vector2(a, size.y - 4.5), Vector2(b, size.y - 4.5), Color(accent, intensity * 0.32), 1.0, true)

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
