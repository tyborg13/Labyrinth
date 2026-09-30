extends Control

const AssetLoader = preload("res://scripts/asset_loader.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const GildedFrame = preload("res://scripts/ui_gilded_frame.gd")
const Palette = preload("res://scripts/ui_palette.gd")

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
	var disabled: bool = state == STATE_DISABLED
	var pressed: bool = _material_is_pressed(state)
	var engaged: bool = state in [STATE_HOVER, STATE_FOCUS, STATE_SELECTED] or _variant == VARIANT_SELECTED
	var face := Rect2(Vector2(1.0, 1.0), size - Vector2(2.0, 3.0))

	# Primary plates carry a steady ember halo so the advancing action reads first.
	if _variant == VARIANT_SELECTED and not disabled:
		GildedFrame.draw_glow(self, face, Color(Palette.EMBER, 0.55 if engaged and state != STATE_SELECTED else 0.38), 10.0, 3.0)
	elif state == STATE_HOVER and not disabled:
		GildedFrame.draw_glow(self, face, Color(accent, 0.22), 7.0, 3.0)

	GildedFrame.draw_sheen(self, face, 0.35 if disabled or pressed else (1.25 if engaged else 1.0), 2.0)
	# Inner hairline: a fine gilt edge one step inside the border.
	var inner := face.grow(-3.0)
	var inner_alpha: float = 0.10 if disabled else (0.42 if engaged else 0.22)
	draw_rect(inner, Color(accent, inner_alpha), false, 1.0)
	# Polished catch-light across the top edge.
	var span: float = minf(size.x * 0.32, 90.0)
	var catch_alpha: float = 0.08 if disabled or pressed else (0.62 if engaged else 0.36)
	_draw_centered_highlight(Vector2(size.x * 0.5, 1.5), span, Color(1.0, 0.93, 0.76, catch_alpha))

	if _variant != VARIANT_ICON and _variant != VARIANT_COMPACT and size.x >= 110.0:
		var stud_strength: float = 0.35 if disabled else (1.0 if engaged else 0.72)
		GildedFrame.draw_diamond(self, Vector2(8.0, size.y * 0.5), 3.0, accent, stud_strength)
		GildedFrame.draw_diamond(self, Vector2(size.x - 8.0, size.y * 0.5), 3.0, accent, stud_strength)

	if state == STATE_FOCUS:
		_draw_focus_brackets(Color("ffe3a0"))
	if _glint_progress < 1.0 and not disabled:
		_draw_engagement_glint(accent)

func _draw_centered_highlight(center: Vector2, half_width: float, color: Color) -> void:
	var segments: int = 10
	for index: int in range(segments):
		var a: float = float(index) / float(segments)
		var b: float = float(index + 1) / float(segments)
		var fade: float = 1.0 - absf((a + b) * 0.5 - 0.5) * 2.0
		draw_line(
			Vector2(center.x - half_width + a * half_width * 2.0, center.y),
			Vector2(center.x - half_width + b * half_width * 2.0, center.y),
			Color(color, color.a * fade),
			1.0,
			true
		)

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
		return Color("5e5347")
	if _variant == VARIANT_DESTRUCTIVE:
		return Color("d56858") if state == STATE_NORMAL else Color("ff9a73")
	if _variant == VARIANT_SELECTED or state == STATE_SELECTED:
		return Color("f0c778")
	if state == STATE_FOCUS:
		return Color("ffe3a0")
	if state in [STATE_HOVER, STATE_PRESSED]:
		return Color("e2bd76")
	return Color("b48c52")
