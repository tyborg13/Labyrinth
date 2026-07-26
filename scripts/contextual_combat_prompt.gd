extends PanelContainer
class_name ContextualCombatPrompt

signal completed(prompt_id: String)
signal skipped(prompt_id: String)
signal grimoire_requested(prompt_id: String, entry_id: String)

const ActionIcons = preload("res://scripts/action_icon_library.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

const PROMPT_SIZE: Vector2 = Vector2(300.0, 104.0)
const ICON_SIZE: Vector2 = Vector2(30.0, 30.0)

var _ui_skin: UiSkin = UiSkin.new()
var _prompt_id: String = ""
var _grimoire_entry_id: String = ""
var _accent: Color = Color("d7a953")
var _icon: TextureRect
var _kicker: Label
var _message: Label
var _grimoire_button: Button

func _ready() -> void:
	_build()
	clear_prompt()

func configure(prompt: Dictionary) -> void:
	if _message == null:
		_build()
	_prompt_id = str(prompt.get("id", ""))
	_grimoire_entry_id = str(prompt.get("grimoire_entry", ""))
	_accent = Color(str(prompt.get("accent", "d7a953")))
	_message.text = str(prompt.get("text", ""))
	_icon.texture = ActionIcons.icon_texture(str(prompt.get("icon", "card_play")))
	_kicker.add_theme_color_override("font_color", _accent.lightened(0.18))
	_grimoire_button.visible = not _grimoire_entry_id.is_empty()
	set_meta("panel_surface_accent", _accent)
	_ui_skin.refresh_panel_surface(self)
	set_meta("prompt_id", _prompt_id)
	set_meta("prompt_text", _message.text)
	set_meta("grimoire_entry", _grimoire_entry_id)
	visible = not _prompt_id.is_empty()

func clear_prompt() -> void:
	_prompt_id = ""
	_grimoire_entry_id = ""
	set_meta("prompt_id", "")
	visible = false

func active_prompt_id() -> String:
	return _prompt_id

func _build() -> void:
	if _message != null:
		return
	name = "ContextualCombatPrompt"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = PROMPT_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)

	var message_row := HBoxContainer.new()
	message_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_row.add_theme_constant_override("separation", 7)
	column.add_child(message_row)

	var icon_frame := PanelContainer.new()
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.custom_minimum_size = Vector2(38.0, 38.0)
	icon_frame.add_theme_stylebox_override("panel", _icon_style())
	message_row.add_child(icon_frame)

	var icon_center := CenterContainer.new()
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_child(icon_center)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = ICON_SIZE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_center.add_child(_icon)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 0)
	message_row.add_child(copy)

	_kicker = Label.new()
	_kicker.text = "COMBAT NOTE"
	_kicker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(_kicker, UiTypography.SIZE_CAPTION)
	_kicker.add_theme_color_override("font_outline_color", Color("25170f"))
	_kicker.add_theme_constant_override("outline_size", 2)
	copy.add_child(_kicker)

	_message = Label.new()
	_message.custom_minimum_size = Vector2(230.0, 42.0)
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(_message, UiTypography.SIZE_CAPTION)
	_message.add_theme_color_override("font_color", Color("f5e7ce"))
	_message.add_theme_color_override("font_outline_color", Color("21150f"))
	_message.add_theme_constant_override("outline_size", 2)
	copy.add_child(_message)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 5)
	column.add_child(actions)

	_grimoire_button = _small_button("Grimoire", Vector2(82.0, 30.0))
	_grimoire_button.pressed.connect(_on_grimoire_pressed)
	actions.add_child(_grimoire_button)

	var done_button: Button = _small_button("Got it", Vector2(66.0, 30.0))
	done_button.pressed.connect(_on_completed_pressed)
	actions.add_child(done_button)

	var skip_button: Button = _small_button("Skip", Vector2(54.0, 30.0))
	skip_button.modulate = Color(1.0, 1.0, 1.0, 0.78)
	skip_button.pressed.connect(_on_skipped_pressed)
	actions.add_child(skip_button)
	add_theme_stylebox_override("panel", _panel_style(_accent))
	set_meta("panel_safe_inset", 0.0)
	set_meta("panel_surface_accent", _accent)
	_ui_skin.apply_inset_surface(self, UiSkin.SURFACE_HUD)

func _small_button(text: String, minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = minimum_size
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	_ui_skin.apply_button_stylebox_overrides(button, UiSkin.VARIANT_COMPACT)
	_ui_skin.apply_button_text_overrides(button)
	UiTypography.set_button_size(button, UiTypography.SIZE_SMALL)
	return button

func _panel_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("211813")
	style.border_color = Color(accent.r, accent.g, accent.b, 0.86)
	style.border_width_left = 3
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	style.shadow_size = 7
	return style

func _icon_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("120d0b")
	style.border_color = Color("6f5438")
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style

func _on_completed_pressed() -> void:
	if not _prompt_id.is_empty():
		completed.emit(_prompt_id)

func _on_skipped_pressed() -> void:
	if not _prompt_id.is_empty():
		skipped.emit(_prompt_id)

func _on_grimoire_pressed() -> void:
	if not _prompt_id.is_empty() and not _grimoire_entry_id.is_empty():
		grimoire_requested.emit(_prompt_id, _grimoire_entry_id)
