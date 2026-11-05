extends Button

const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const HudSkin = preload("res://scripts/ui_skin.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const InputRouter = preload("res://scripts/input_router.gd")

var _key := Label.new()
var _style_signature: int = -1
var _rail_docked: bool = false
var _rail_brush: TextureRect
var _rail_edge: Control

func _init() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var skin := HudSkin.new()
	skin.apply_button_stylebox_overrides(self, HudSkin.VARIANT_COMPACT)
	add_theme_color_override("font_color", Color.TRANSPARENT)
	for state: String in ["hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_color_override("font_%s_color" % state, Color.TRANSPARENT)
	add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	add_theme_font_size_override("font_size", 1)
	var row := HBoxContainer.new()
	row.name = "IntentContents"
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var vision := TextureRect.new()
	vision.name = "VisionIcon"
	vision.texture = AssetLoader.load_texture("res://assets/art/icons/vision.png")
	vision.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vision.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vision.custom_minimum_size = Vector2.ONE * Typography.scaled_value(self, 20.0)
	vision.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vision.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(vision)
	var title := Label.new()
	title.name = "IntentTitle"
	title.text = "Details"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_override("font", Typography.ui_font())
	Typography.set_label_size(title, 15)
	title.add_theme_color_override("font_color", Palette.TEXT)
	row.add_child(title)
	_key.name = "IntentKey"
	_key.text = "I"
	_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key.add_theme_font_override("font", Typography.ui_font())
	Typography.set_label_size(_key, 15)
	_key.add_theme_color_override("font_color", Palette.TEXT_3)
	row.add_child(_key)
	toggled.connect(func(_enabled: bool) -> void: refresh_state())

func _ready() -> void:
	var router: Node = get_node_or_null("/root/InputRouter")
	if router != null:
		router.modality_changed.connect(_refresh_key)
	_refresh_key()
	refresh_state()

func refresh_state() -> void:
	var signature: int = int(button_pressed) + 2 * int(disabled)
	if signature == _style_signature:
		return
	_style_signature = signature
	var skin := HudSkin.new()
	if _rail_docked:
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		queue_redraw()
		return
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style: StyleBoxFlat = skin.make_button_style(HudSkin.VARIANT_COMPACT, HudSkin.STATE_HOVER if state == "hover_pressed" else state)
		if button_pressed and not disabled and state != "disabled":
			style.border_color = Palette.GOLD_BRIGHT
		add_theme_stylebox_override(state, style)
	queue_redraw()

func _refresh_key(_modality: String = "") -> void:
	var router: Node = get_node_or_null("/root/InputRouter") if is_inside_tree() else null
	_key.visible = router == null or str(router.call("modality")) == InputRouter.MODALITY_POINTER

func _draw() -> void:
	if _rail_docked:
		var state: String = HudSkin.STATE_DISABLED if disabled else (HudSkin.STATE_HOVER if is_hovered() else HudSkin.STATE_NORMAL)
		var style: StyleBoxFlat = HudSkin.new().make_button_style(HudSkin.VARIANT_COMPACT, state)
		_rail_brush.modulate = style.bg_color
		_rail_edge.color = Palette.GOLD_BRIGHT if button_pressed and not disabled else style.border_color
		_rail_edge.queue_redraw()
	if button_pressed and not disabled:
		var inset: float = Typography.scaled_value(self, 8.0)
		draw_line(Vector2(inset, size.y - 2.0), Vector2(size.x - inset, size.y - 2.0), Palette.EMBER, Typography.scaled_value(self, 2.0), true)

func set_rail_docked(docked: bool) -> void:
	if _rail_docked == docked: return
	_rail_docked = docked
	if docked and _rail_brush == null:
		var ink = preload("res://scripts/turn_order_ink.gd")
		_rail_brush = TextureRect.new()
		_rail_brush.name = "DetailsRailBrush"
		_rail_brush.texture = ink.brush_texture(false, "details")
		_rail_brush.modulate = get_theme_stylebox("normal").bg_color
		_rail_brush.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_rail_brush.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_rail_brush.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_rail_brush)
		move_child(_rail_brush, 0)
		_rail_edge = ink.SlashEdge.new()
		_rail_edge.name = "DetailsRailEdge"
		_rail_edge.skew = ink.SKEW_RATIO
		_rail_edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_rail_edge)
	if _rail_brush != null:
		_rail_brush.visible = docked
		_rail_edge.visible = docked
	var ornament: CanvasItem = get_node_or_null("ThemedButtonOrnament") as CanvasItem
	if ornament != null: ornament.visible = not docked
	_style_signature = -1
	refresh_state()
