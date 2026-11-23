extends Button

## The normal face is the Controls glyph. The same UiSkin selection plate used
## by Settings sits over it while listening and during the swap feedback.
const KeySkin = preload("res://scripts/ui_skin.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Glyph = preload("res://scripts/input_glyph.gd")

# Match the existing single choice feedback beat.
const PULSE_IN: float = 0.04
const PULSE_FADE_DELAY: float = 0.06
const PULSE_OUT: float = 0.19
const PULSE_GROW_TIME: float = 0.22
const PULSE_START_SCALE: float = 0.985
const PULSE_END_SCALE: float = 1.055

var _keycap: Control
var _selection := Button.new()
var _pulse: Tween
var _listening: bool

func _init(keycap: Control, skin: RefCounted) -> void:
	_keycap = keycap
	focus_mode = Control.FOCUS_ALL
	focus_neighbor_left = NodePath(".")
	focus_neighbor_right = NodePath(".")
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var blank := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		add_theme_stylebox_override(state, blank)
	var focus_style: StyleBoxFlat = skin.make_button_style(KeySkin.VARIANT_STANDARD, KeySkin.STATE_FOCUS)
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		focus_style.set_content_margin(side, 0.0)
	add_theme_stylebox_override("focus", focus_style)
	_keycap.name = "Keycap"
	_keycap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_keycap)

	_selection.name = "MoltenSelection"
	_selection.focus_mode = Control.FOCUS_NONE
	_selection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_selection.hide()
	skin.apply_button_stylebox_overrides(_selection, KeySkin.VARIANT_SELECTED)
	_selection.add_theme_font_override("font", Typography.ui_font())
	_selection.add_theme_color_override("font_color", Glyph.DARK_KEY_INK)
	# Match the keycap's size and center the text in the same seat.
	var plate: StyleBoxFlat = skin.make_button_style(KeySkin.VARIANT_SELECTED, KeySkin.STATE_SELECTED)
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		plate.set_content_margin(side, 0.0)
	_selection.add_theme_stylebox_override("normal", plate)
	_selection.set_meta("button_gallery_state", KeySkin.STATE_SELECTED)
	add_child(_selection)
	resized.connect(func() -> void: _selection.pivot_offset = size * 0.5)

func set_binding_text(next_text: String, listening: bool) -> void:
	_keycap.set_key_text(next_text)
	custom_minimum_size = _keycap.get_combined_minimum_size()
	_selection.text = next_text
	_selection.add_theme_font_size_override("font_size", _keycap._rounded_key_label_size())
	accessibility_name = next_text
	if _listening == listening: return
	_listening = listening
	_stop_pulse()
	_selection.visible = listening

func play_swap_pulse() -> void:
	_stop_pulse()
	_selection.show()
	_selection.modulate.a = 0.0
	_pulse = create_tween().set_parallel(true)
	_pulse.tween_property(_selection, "modulate:a", 1.0, PULSE_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if not Settings.applied_reduced_motion_enabled():
		_selection.scale = Vector2.ONE * PULSE_START_SCALE
		_pulse.tween_property(_selection, "scale", Vector2.ONE * PULSE_END_SCALE, PULSE_GROW_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse.tween_property(_selection, "modulate:a", 0.0, PULSE_OUT).set_delay(PULSE_FADE_DELAY).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_pulse.finished.connect(_finish_pulse)

func _finish_pulse() -> void:
	_selection.hide()
	_stop_pulse()

func _stop_pulse() -> void:
	if _pulse != null: _pulse.kill()
	_pulse = null
	_selection.modulate.a = 1.0
	_selection.scale = Vector2.ONE
