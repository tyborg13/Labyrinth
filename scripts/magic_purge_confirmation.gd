extends Control

signal accepted
signal cancelled

const UiSkin = preload("res://scripts/ui_skin.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const CardWidget = preload("res://scripts/card_widget.gd")
const CardScene = preload("res://scenes/card_widget.tscn")
const CARD_SIZE := Vector2(250.0, 352.0)
const CARD_Y_OFFSET: float = -40.0
const HEADING_GAP: float = 24.0
const BUTTON_OFFSET: float = 28.0
const BUTTON_HEIGHT: float = 52.0
const BUTTON_MIN_WIDTH: float = 200.0
const BUTTON_SIDE_PADDING: float = 28.0
const BUTTON_GAP: int = 16
const WALLET_GAP: float = 12.0
const Halo = preload("res://scripts/magic_purge_halo.gd")
# Opening Boon also uses this class's original text confirmation. Its surface
# and public no-host API are deliberately preserved outside the purge redesign.
const LEGACY_DIALOG_SIZE := Vector2(560.0, 240.0)
const LEGACY_INNER_PADDING: float = 32.0
const LEGACY_BUTTON_GAP: int = 24
const UNPRESENTED_CARD_ID: String = "pale_spark"

var question: Label
var confirm_button: Button
var cancel_button: Button
var card: CardWidget
var _card_slot: Control
var _buttons: HBoxContainer
var _wallet: Label
var _glow: TextureRect
var _host: Node
var _legacy_price: Control

func configure(host: Node = null) -> void:
	_host = host
	name = "MagicPurgeConfirmation"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if host == null:
		_configure_legacy()
		return
	_glow = Halo.new()
	_glow.name = "MagicPurgeCrimsonGlow"
	add_child(_glow)
	question = Label.new()
	question.name = "PurgeConfirmationQuestion"
	question.text = "Purge this spell?"
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Typography.apply_label_role(question, Typography.ROLE_TITLE)
	question.add_theme_color_override("font_color", Palette.GOLD_BRIGHT)
	question.add_theme_color_override("font_outline_color", Palette.TEXT_OUTLINE)
	question.add_theme_constant_override("outline_size", 3)
	add_child(question)
	card = CardScene.instantiate() as CardWidget
	card.name = "MagicPurgeConfirmCard"
	card.configure(UNPRESENTED_CARD_ID, false, false, true, false, false)
	_card_slot = host.call("_scaled_card_slot", card, CARD_SIZE)
	_card_slot.name = "MagicPurgeConfirmCardSlot"
	add_child(_card_slot)
	_buttons = HBoxContainer.new()
	_buttons.name = "MagicPurgeConfirmationButtons"
	_buttons.add_theme_constant_override("separation", BUTTON_GAP)
	add_child(_buttons)
	confirm_button = _button("Purge", "ConfirmMagicPurge", UiSkin.VARIANT_DESTRUCTIVE)
	confirm_button.pressed.connect(func() -> void: accepted.emit())
	_buttons.add_child(confirm_button)
	cancel_button = _button("Back", "CancelMagicPurge", UiSkin.VARIANT_STANDARD)
	cancel_button.pressed.connect(func() -> void: cancelled.emit())
	_buttons.add_child(cancel_button)
	_contain_button_focus()
	_wallet = Label.new()
	_wallet.name = "MagicPurgeHeldEmbers"
	Typography.apply_label_role(_wallet, Typography.ROLE_BODY)
	Typography.set_label_size(_wallet, 16)
	_wallet.add_theme_color_override("font_color", Palette.DANGER)
	_wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_wallet)
	resized.connect(_layout)
	hide()

func present(card_id: String, price: int, paid: bool, affordable: bool, held: int = 0) -> void:
	if _host == null:
		_present_legacy(card_id, price, paid, affordable)
		return
	card.configure(card_id, false, false, true, false, false)
	_glow.configure(card.get_theme_stylebox("normal") as StyleBoxTexture, Vector2i(CARD_SIZE))
	_card_slot.show()
	confirm_button.text = "Purge for %d Embers" % price if paid else "Purge"
	confirm_button.disabled = not affordable
	confirm_button.focus_mode = Control.FOCUS_ALL if affordable else Control.FOCUS_NONE
	_contain_button_focus()
	_wallet.text = "You have %d Embers." % held
	_wallet.visible = paid and not affordable
	for button: Button in [confirm_button, cancel_button]:
		var font: Font = button.get_theme_font("font")
		var width: float = font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
		button.custom_minimum_size = Vector2(maxf(BUTTON_MIN_WIDTH, ceilf(width) + BUTTON_SIDE_PADDING * 2.0), BUTTON_HEIGHT)
	show()
	_layout()
	cancel_button.grab_focus()

func _configure_legacy() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.name = "MagicPurgeConfirmationPanel"
	panel.custom_minimum_size = LEGACY_DIALOG_SIZE
	panel.set_meta("panel_safe_inset", LEGACY_INNER_PADDING)
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
	_legacy_price = preload("res://scripts/scavenger_ember_chip.gd").new()
	_legacy_price.name = "MagicPurgePrice"
	_legacy_price.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_legacy_price)
	var buttons := HBoxContainer.new()
	buttons.name = "MagicPurgeConfirmationButtons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", LEGACY_BUTTON_GAP)
	column.add_child(buttons)
	cancel_button = _button("Cancel", "CancelMagicPurge", UiSkin.VARIANT_STANDARD)
	cancel_button.pressed.connect(func() -> void: cancelled.emit())
	buttons.add_child(cancel_button)
	confirm_button = _button("Purge", "ConfirmMagicPurge", UiSkin.VARIANT_DESTRUCTIVE)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var style: StyleBoxFlat = confirm_button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		style.bg_color = Palette.DANGER
		confirm_button.add_theme_stylebox_override(state, style)
	confirm_button.pressed.connect(func() -> void: accepted.emit())
	buttons.add_child(confirm_button)
	_contain_button_focus()
	hide()

func _present_legacy(card_name: String, price: int, paid: bool, affordable: bool) -> void:
	question.text = "Purge %s?" % card_name
	_legacy_price.setup(preload("res://scripts/asset_loader.gd").load_texture(preload("res://scripts/scavenger_price_tag.gd").EMBER_PATH), str(price), "Embers")
	_legacy_price.visible = paid
	confirm_button.disabled = not affordable
	show()
	cancel_button.grab_focus()

func _contain_button_focus() -> void:
	for button: Button in [cancel_button, confirm_button]:
		var other: Button = confirm_button if button == cancel_button else cancel_button
		if other.disabled: other = button
		button.focus_neighbor_left = button.get_path_to(other)
		button.focus_neighbor_right = button.get_path_to(other)
		button.focus_next = button.get_path_to(other)
		button.focus_previous = button.get_path_to(other)
		button.focus_neighbor_top = button.get_path_to(button)
		button.focus_neighbor_bottom = button.get_path_to(button)

func _layout() -> void:
	if _card_slot == null: return
	_card_slot.position = size * 0.5 + Vector2(0.0, CARD_Y_OFFSET) - CARD_SIZE * 0.5
	_glow.position = _card_slot.position - Vector2.ONE * Halo.FEATHER_RADIUS
	_glow.size = CARD_SIZE + Vector2.ONE * Halo.FEATHER_RADIUS * 2.0
	question.size = Vector2(size.x, question.get_minimum_size().y)
	question.position = Vector2(0.0, _card_slot.position.y - HEADING_GAP - question.size.y)
	_buttons.size = Vector2(_buttons.get_combined_minimum_size().x, BUTTON_HEIGHT)
	_buttons.position = Vector2((size.x - _buttons.size.x) * 0.5, _card_slot.position.y + CARD_SIZE.y + BUTTON_OFFSET)
	_wallet.size = Vector2(size.x, _wallet.get_minimum_size().y)
	_wallet.position = Vector2(0.0, _buttons.position.y + BUTTON_HEIGHT + WALLET_GAP)

func play_exhaust() -> void:
	confirm_button.disabled = true
	cancel_button.disabled = true
	var rect: Rect2 = _card_slot.get_global_rect()
	var proxy: Control = _host.call("_spawn_card_proxy", card.card_id, rect)
	_host.call("_mount_card_proxy", proxy, self, rect)
	# Combat proxies use an absolute depth; this modal sits above that layer.
	proxy.z_as_relative = true
	_card_slot.hide()
	# Reuse combat's existing Exhaust presentation and reduced-motion timing.
	await _host.call("_animate_card_to_pile_fx", card.card_id, "burn", CARD_SIZE, proxy)

static func backdrop(fill: Color = Color(0, 0, 0, 0.7)) -> ColorRect:
	var result := ColorRect.new()
	result.name = "MagicPurgeBackdrop"
	result.color = fill
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

func _button(text: String, node_name: String, variant: String) -> Button:
	var result := Button.new()
	result.name = node_name
	result.text = text
	result.custom_minimum_size = Vector2(BUTTON_MIN_WIDTH, BUTTON_HEIGHT)
	var skin := UiSkin.new()
	skin.apply_button_stylebox_overrides(result, variant)
	skin.apply_button_text_overrides(result)
	Typography.apply_button_role(result, Typography.ROLE_BODY)
	return result
