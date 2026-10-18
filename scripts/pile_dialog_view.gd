extends RefCounted

# Shared pile-dialog finish. Callers own geometry; the combat viewer's original
# style and content are passed through unchanged.
const UiSkin = preload("res://scripts/ui_skin.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const CardWidget = preload("res://scripts/card_widget.gd")
const CardScene = preload("res://scenes/card_widget.tscn")
const CARD_SIZE := Vector2(196.0, 276.0)
const STACK_OFFSET := Vector2(6.0, 7.0)
const STACK_LAYERS: int = 3
const CARD_BACK_PATH: String = "res://assets/art/ui/card_back.png"

static func finish_panel(panel: PanelContainer, style: StyleBox) -> void:
	panel.add_theme_stylebox_override("panel", style)
	UiSkin.new().apply_outer_panel_frame(panel, UiSkin.SURFACE_DIALOG)

class CardCell extends Button:
	var card_id: String
	var widget: CardWidget
	var _pointer: bool = false

	func _highlight() -> void:
		widget.set_external_highlighted(_pointer or has_focus())
		z_index = 20 if _pointer or has_focus() else 0

static func card_cell(host: Node, card_id: String, count: int, activated: Callable) -> CardCell:
	var cell := CardCell.new()
	cell.name = "MagicDeckRow_" + card_id
	cell.card_id = card_id
	cell.set_meta("magic_copy_count", count)
	cell.custom_minimum_size = CARD_SIZE
	cell.size = CARD_SIZE
	cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		cell.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for layer: int in range(mini(count, STACK_LAYERS) - 1, 0, -1):
		var back := TextureRect.new()
		back.name = "PileStackLayer%d" % layer
		back.texture = Assets.load_texture(CARD_BACK_PATH)
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.stretch_mode = TextureRect.STRETCH_SCALE
		back.position = STACK_OFFSET * float(layer)
		back.size = CARD_SIZE
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(back)
	cell.widget = CardScene.instantiate() as CardWidget
	cell.widget.configure(card_id)
	cell.widget.focus_mode = Control.FOCUS_NONE
	var slot: Control = host.call("_scaled_card_slot", cell.widget, CARD_SIZE)
	cell.add_child(slot)
	# CardWidget sets its mouse filter during _ready; contain its input only
	# after that initialization so the cell owns pointer activation as well.
	cell.ready.connect(func() -> void: host.call("_set_mouse_filter_recursive", slot, Control.MOUSE_FILTER_IGNORE))
	cell.mouse_entered.connect(func() -> void: cell._pointer = true; cell._highlight())
	cell.mouse_exited.connect(func() -> void: cell._pointer = false; cell._highlight())
	cell.focus_entered.connect(cell._highlight)
	cell.focus_exited.connect(cell._highlight)
	cell.pressed.connect(activated.bind(card_id))
	if count > 1:
		var copies := Label.new()
		copies.name = "PileCopyCount"
		copies.text = "×%d" % count
		Typography.apply_label_role(copies, Typography.ROLE_BODY)
		copies.add_theme_color_override("font_color", Palette.GOLD_BRIGHT)
		copies.add_theme_color_override("font_outline_color", Palette.TEXT_OUTLINE)
		copies.add_theme_constant_override("outline_size", 3)
		copies.mouse_filter = Control.MOUSE_FILTER_IGNORE
		copies.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		copies.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		copies.grow_vertical = Control.GROW_DIRECTION_BEGIN
		cell.add_child(copies)
	return cell
