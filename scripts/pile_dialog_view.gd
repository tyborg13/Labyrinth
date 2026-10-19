extends RefCounted

# Shared pile-dialog finish. Callers own geometry; the combat viewer's original
# style and content are passed through unchanged.
const UiSkin = preload("res://scripts/ui_skin.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const CardWidget = preload("res://scripts/card_widget.gd")
const CardScene = preload("res://scenes/card_widget.tscn")
const Surface = preload("res://scripts/ui_component_surface.gd")
const Socket = preload("res://scripts/ui_socket.gd")
const CARD_SIZE := Vector2(196.0, 276.0)
const STACK_OFFSET := Vector2(6.0, 7.0)
const STACK_LAYERS: int = 3
const CARD_BACK_PATH: String = "res://assets/art/ui/card_back.png"
const COPY_BADGE_SIZE := Vector2(52.0, 52.0)
const COPY_BADGE_INSET := Vector2(6.0, 6.0)
const COPY_BADGE_FONT_SIZE: int = 22
const COPY_BADGE_DISC_ALPHA: float = 0.92
# Above CardWidget's hover lift and its child ornaments.
const COPY_BADGE_Z_INDEX: int = 40

class CopyCountFace extends Control:
	var _ring := TextureRect.new()
	var _geometry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Socket.GEOMETRY_PATH)) as Dictionary

	func _init() -> void:
		_ring.name = "Ring"
		_ring.texture = Surface.mipmapped_texture(Socket.RING_PATH)
		_ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_ring.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# The socket's painted texture supplies all of the ring's colour.
		_ring.modulate = Color.WHITE
		_ring.self_modulate = Color.WHITE
		add_child(_ring)
		resized.connect(_layout)

	func _ready() -> void:
		_layout()

	func _layout() -> void:
		var native_size := Vector2(float(_geometry["size"][0]), float(_geometry["size"][1]))
		var ring_size: Vector2 = native_size * minf(size.x / native_size.x, size.y / native_size.y)
		_ring.position = (size - ring_size) * 0.5
		_ring.size = ring_size
		queue_redraw()

	func _draw() -> void:
		var source_size: float = float(_geometry["size"][0])
		var center: Array = _geometry["center"]
		var ring_center: Vector2 = _ring.position + Vector2(float(center[0]), float(center[1])) * _ring.size.x / source_size
		var radius: float = float(_geometry["inner_radius"]) * _ring.size.x / source_size
		draw_circle(ring_center, radius, Color(Palette.INK_0, COPY_BADGE_DISC_ALPHA))

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
		copies.add_theme_font_override("font", Typography.ui_font())
		Typography.set_label_size(copies, COPY_BADGE_FONT_SIZE)
		copies.add_theme_color_override("font_color", Palette.GOLD_BRIGHT)
		copies.add_theme_color_override("font_outline_color", Palette.TEXT_OUTLINE)
		copies.add_theme_constant_override("outline_size", 3)
		copies.mouse_filter = Control.MOUSE_FILTER_IGNORE
		copies.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		copies.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		copies.z_index = COPY_BADGE_Z_INDEX
		cell.add_child(copies)
		copies.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		# Offsets stay relative to the corner even before the cell enters a tree.
		copies.offset_left = -COPY_BADGE_INSET.x - COPY_BADGE_SIZE.x * 0.5
		copies.offset_top = -COPY_BADGE_INSET.y - COPY_BADGE_SIZE.y * 0.5
		copies.offset_right = -COPY_BADGE_INSET.x + COPY_BADGE_SIZE.x * 0.5
		copies.offset_bottom = -COPY_BADGE_INSET.y + COPY_BADGE_SIZE.y * 0.5
		var face := CopyCountFace.new()
		face.name = "Medallion"
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.show_behind_parent = true
		face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		copies.add_child(face)
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return cell
