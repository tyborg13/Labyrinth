extends "res://scripts/ui_socket.gd"

const Tooltip = preload("res://scripts/ui_tooltip_panel.gd")
const InputRouter = preload("res://scripts/input_router.gd")
const ButtonFeedback = preload("res://scripts/ui_button_feedback.gd")

var _hotkey_hint: Label
var _state_owner: BaseButton

func follow_button_states(button: BaseButton) -> void:
	_state_owner = button
	for event: Signal in [button.mouse_entered, button.mouse_exited, button.focus_entered, button.focus_exited]:
		event.connect(queue_redraw)

func _draw() -> void:
	var owner_active: bool = _state_owner != null and not _state_owner.disabled and (_state_owner.is_hovered() or _state_owner.has_focus())
	if owner_active:
		var diameter: float = minf(size.x, size.y)
		var rect := Rect2((size - Vector2.ONE * diameter) * 0.5, Vector2.ONE * diameter)
		var center: Vector2 = _ring_center(rect)
		var radius: float = _ring_radius(rect, "outer_radius") + Typography.scaled_value(self, 7.0)
		draw_texture_rect(_glow, Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false)
	super._draw()
	if _state_owner != null:
		_ring.modulate = DISABLED_RING_TINT if _state_owner.disabled else ACTIVE_RING_TINT if owner_active else ring_tint
		_icon_material.set_shader_parameter("saturation", 0.35 if _state_owner.disabled else 1.0)

func configure_header(texture: Texture2D, tooltip: String, key_hint: String = "") -> void:
	ButtonFeedback.bind_button(self)
	socket_size = 58.0
	setup(texture, tooltip)
	text = ""
	icon = null
	_icon.modulate = Color(1.0, 0.96, 0.88)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not key_hint.is_empty():
		_hotkey_hint = Label.new()
		_hotkey_hint.name = "HotkeyHint"
		_hotkey_hint.text = key_hint
		_hotkey_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hotkey_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		Surface.label_style(_hotkey_hint, 12, Palette.TEXT_2)
		var plate := StyleBoxFlat.new()
		plate.bg_color = Palette.INK_2
		plate.border_color = Palette.GOLD_DIM
		plate.set_border_width_all(1)
		plate.set_corner_radius_all(2)
		plate.content_margin_left = Typography.scaled_value(self, 4.0)
		plate.content_margin_right = Typography.scaled_value(self, 4.0)
		_hotkey_hint.add_theme_stylebox_override("normal", plate)
		add_child(_hotkey_hint)
		resized.connect(_layout_hotkey_hint)
		_layout_hotkey_hint()
		_refresh_hotkey_hint()

func _ready() -> void:
	super._ready()
	var router: Node = get_node_or_null("/root/InputRouter") if is_inside_tree() else null
	if router != null:
		router.modality_changed.connect(_refresh_hotkey_hint)
	_layout_hotkey_hint()
	_refresh_hotkey_hint()

func _layout_hotkey_hint() -> void:
	if _hotkey_hint == null:
		return
	Surface.label_style(_hotkey_hint, 12, Palette.TEXT_2)
	_hotkey_hint.size = _hotkey_hint.get_minimum_size()
	_hotkey_hint.position = size - _hotkey_hint.size - Vector2(Typography.scaled_value(self, 1.0), 0.0)

func _refresh_hotkey_hint(_modality: String = "") -> void:
	if _hotkey_hint == null:
		return
	var router: Node = get_node_or_null("/root/InputRouter") if is_inside_tree() else null
	_hotkey_hint.visible = router == null or str(router.call("modality")) == InputRouter.MODALITY_POINTER

func _make_custom_tooltip(for_text: String) -> Object:
	return null if for_text.strip_edges().is_empty() else Tooltip.make_text(for_text)
