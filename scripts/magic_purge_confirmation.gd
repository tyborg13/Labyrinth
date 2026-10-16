extends Control

signal accepted
signal cancelled

const UiSkin = preload("res://scripts/ui_skin.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const EmberChip = preload("res://scripts/scavenger_ember_chip.gd")
const PriceTag = preload("res://scripts/scavenger_price_tag.gd")
const Assets = preload("res://scripts/asset_loader.gd")

# Director-specified confirmation geometry; the finishes are shared game UI.
const DIALOG_SIZE := Vector2(560.0, 240.0)
const INNER_PADDING: float = 32.0
const BUTTON_SIZE := Vector2(200.0, 52.0)
const BUTTON_GAP: int = 24
const BACKDROP_OPACITY: float = 0.7

var question: Label
var confirm_button: Button
var cancel_button: Button
var _price: Control

func configure() -> void:
	name = "MagicPurgeConfirmation"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.name = "MagicPurgeConfirmationPanel"
	panel.custom_minimum_size = DIALOG_SIZE
	panel.set_meta("panel_safe_inset", INNER_PADDING)
	UiSkin.new().apply_panel_surface(panel)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.name = "MagicPurgeConfirmationContent"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", Typography.SPACE_LARGE)
	panel.add_child(column)
	question = Label.new()
	question.name = "PurgeConfirmationQuestion"
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Typography.apply_label_role(question, Typography.ROLE_TITLE)
	question.add_theme_color_override("font_color", Palette.TEXT)
	column.add_child(question)
	_price = EmberChip.new()
	_price.name = "MagicPurgePrice"
	_price.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_price)
	var buttons := HBoxContainer.new()
	buttons.name = "MagicPurgeConfirmationButtons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", BUTTON_GAP)
	column.add_child(buttons)
	cancel_button = _button("Cancel", "CancelMagicPurge", false)
	cancel_button.pressed.connect(func() -> void: cancelled.emit())
	buttons.add_child(cancel_button)
	confirm_button = _button("Purge", "ConfirmMagicPurge", true)
	confirm_button.pressed.connect(func() -> void: accepted.emit())
	buttons.add_child(confirm_button)
	for button: Button in [cancel_button, confirm_button]:
		var other: Button = confirm_button if button == cancel_button else cancel_button
		button.focus_neighbor_left = button.get_path_to(other)
		button.focus_neighbor_right = button.get_path_to(other)
		button.focus_next = button.get_path_to(other)
		button.focus_previous = button.get_path_to(other)
		button.focus_neighbor_top = button.get_path_to(button)
		button.focus_neighbor_bottom = button.get_path_to(button)
	hide()

func present(card_name: String, price: int, paid: bool, affordable: bool) -> void:
	question.text = "Purge %s?" % card_name
	_price.setup(Assets.load_texture(PriceTag.EMBER_PATH), str(price), "Embers")
	_price.visible = paid
	confirm_button.disabled = not affordable
	show()
	cancel_button.grab_focus()

static func backdrop() -> ColorRect:
	var result := ColorRect.new()
	result.name = "MagicPurgeBackdrop"
	result.color = Color(Color.BLACK, BACKDROP_OPACITY)
	result.mouse_filter = Control.MOUSE_FILTER_STOP
	result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return result

static func highest_visible_z(node: Node, excluded: Node, parent_z: int = 0) -> int:
	if node == excluded: return parent_z
	var depth: int = parent_z
	if node is CanvasItem:
		var item := node as CanvasItem
		if not item.is_visible_in_tree(): return parent_z
		depth = depth + item.z_index if item.z_as_relative else item.z_index
	var highest: int = depth
	for child: Node in node.get_children():
		highest = maxi(highest, highest_visible_z(child, excluded, depth))
	return highest

func _button(text: String, node_name: String, destructive: bool) -> Button:
	var result := Button.new()
	result.name = node_name
	result.text = text
	result.custom_minimum_size = BUTTON_SIZE
	var skin := UiSkin.new()
	skin.apply_button_stylebox_overrides(result, UiSkin.VARIANT_DESTRUCTIVE if destructive else UiSkin.VARIANT_STANDARD)
	skin.apply_button_text_overrides(result)
	Typography.apply_button_role(result, Typography.ROLE_BODY)
	if destructive:
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			var style: StyleBoxFlat = result.get_theme_stylebox(state).duplicate() as StyleBoxFlat
			style.bg_color = Palette.DANGER
			result.add_theme_stylebox_override(state, style)
	return result
