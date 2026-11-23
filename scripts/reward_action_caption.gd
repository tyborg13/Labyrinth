extends RefCounted

const Typography = preload("res://scripts/ui_typography.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const CARD_PLATE_HEIGHT: float = 26.0
const CARD_BADGE_TEXT_SIZE: int = 12
const DECK_ICON_SIZE: float = 20.0
const DECK_FRAME_GAP: float = 7.0

static func add_deck_match(widget: Control, card_scale: float, element: String, skin: UiSkin, plate_style: StyleBox) -> void:
	var plate := PanelContainer.new()
	plate.name = "RewardDeckCaption"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The card owns this anchor so its ornament and caption move together.
	plate.anchor_left = 0.5
	plate.anchor_right = 0.5
	plate.grow_horizontal = Control.GROW_DIRECTION_BOTH
	plate.grow_vertical = Control.GROW_DIRECTION_BEGIN
	plate.offset_bottom = -DECK_FRAME_GAP / card_scale
	plate.offset_top = plate.offset_bottom
	plate.custom_minimum_size.y = Typography.scaled_value(widget, CARD_PLATE_HEIGHT) / card_scale
	var padded_style: StyleBox = plate_style.duplicate()
	# Include space for the plate's inner gilded hairline.
	var side_inset: float = Typography.scaled_value(widget, Typography.SPACE_LARGE + Typography.SPACE_HAIRLINE) / card_scale
	padded_style.set_content_margin(SIDE_LEFT, side_inset)
	padded_style.set_content_margin(SIDE_RIGHT, side_inset)
	plate.add_theme_stylebox_override("panel", padded_style)
	widget.add_child(plate)
	skin.apply_choice_finish(plate, Palette.GOLD)
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", Typography.SPACE_TIGHT)
	plate.add_child(line)
	var icon := TextureRect.new()
	icon.name = "ElementIcon"
	icon.texture = AssetLoader.trim_texture_to_used_rect(AssetLoader.load_texture(ElementData.icon_path(element)))
	icon.custom_minimum_size = Vector2.ONE * (Typography.scaled_value(widget, DECK_ICON_SIZE) / card_scale)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(icon)
	var caption := Label.new()
	caption.name = "Caption"
	caption.text = "Your deck"
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_color_override("font_color", Palette.TEXT)
	line.add_child(caption)
	Typography.set_label_size(caption, CARD_BADGE_TEXT_SIZE)

static func fit_row(row: HBoxContainer, width_limit: float, minimum_width: float) -> void:
	var actions: Array[Button]
	var remaining: float = width_limit
	var separation: int = row.get_theme_constant("separation")
	for button: Button in row.get_children():
		if not button.visible: continue
		remaining -= separation
		if button.has_meta("reward_heal_result_hp") and not button.get_meta("reward_heal_fully_wasted"):
			actions.append(button)
		else:
			remaining -= button.get_combined_minimum_size().x
	if actions.is_empty(): return
	remaining = maxf(1.0, remaining + separation) / actions.size()
	for button: Button in actions:
		_fit(button, remaining, minimum_width)

static func _fit(button: Button, width_limit: float, minimum_width: float) -> void:
	var font: Font = button.get_theme_font("font")
	var padding: Vector2 = button.get_theme_stylebox("normal").get_minimum_size()
	var reserved: float = padding.x
	# An expanded icon still occupies its height-limited width when painted.
	if button.icon != null and button.icon_alignment != HORIZONTAL_ALIGNMENT_CENTER:
		var icon_width: float = button.icon.get_width()
		var max_icon_width: int = button.get_theme_constant("icon_max_width")
		if max_icon_width > 0: icon_width = minf(icon_width, max_icon_width)
		if button.expand_icon:
			var inner_height: float = maxf(0.0, button.custom_minimum_size.y - padding.y)
			icon_width = minf(icon_width, inner_height * button.icon.get_size().aspect())
		reserved += icon_width + button.get_theme_constant("h_separation")
	var font_size: int = Typography.scaled_size(button, Typography.SIZE_BODY_LARGE)
	var required: float = _width(button, font, font_size, reserved)
	if required > width_limit:
		font_size = Typography.scaled_size(button, Typography.SIZE_BODY)
		required = _width(button, font, font_size, reserved)
	if font_size != button.get_theme_font_size("font_size"):
		button.add_theme_font_size_override("font_size", font_size)
	button.custom_minimum_size.x = minf(width_limit, maxf(minimum_width, required))

static func _width(button: Button, font: Font, font_size: int, reserved: float) -> float:
	var line := TextLine.new()
	line.add_string(button.text, font, font_size, button.language)
	return ceilf(line.get_line_width() + reserved)
