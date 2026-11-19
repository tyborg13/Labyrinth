extends RefCounted
## Event variant of the relic offer's choice plate.

const UiSkin = preload("res://scripts/ui_skin.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Rule = preload("res://scripts/ui_gilded_rule.gd")
const Inline = preload("res://scripts/inline_icon_text.gd")
# Relic offer metrics in reference canvas pixels (RunScene's relic choice).
const WIDTH: float = 304.0
const INSET_X: float = 18.0
const INSET_Y: float = 14.0
const FILL_ALPHA: float = 0.50 # Nearest half-opacity step to 0.92 × 0.55.
const SEPARATION: int = 4
static var _accent_light: GradientTexture2D
static var _light_material: CanvasItemMaterial

static func make() -> PanelContainer:
	var plate := PanelContainer.new()
	plate.name = "EventRewardPlate"
	plate.custom_minimum_size.x = WIDTH
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var skin := UiSkin.new()
	var style: StyleBoxFlat = skin.make_flat_panel_style(Color(Palette.INK_1, FILL_ALPHA), INSET_X)
	style.content_margin_top = INSET_Y
	style.content_margin_bottom = INSET_Y
	style.set_corner_radius_all(3)
	style.set_border_width_all(1)
	style.border_color = Color(Palette.GOLD.lerp(Palette.GOLD_DIM, 0.5), 0.70)
	style.shadow_color = Color(Color.BLACK, 0.38)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0.0, 7.0)
	plate.add_theme_stylebox_override("panel", style)
	skin.apply_choice_finish(plate, Palette.GOLD)
	var box := VBoxContainer.new()
	box.name = "Contents"
	box.add_theme_constant_override("separation", SEPARATION)
	plate.add_child(box)
	return plate

static func contents(plate: PanelContainer) -> VBoxContainer:
	return plate.get_node("Contents")

static func with_icon(art: TextureRect, title: String, accent: Color, subtitle: String = "", description: String = "") -> PanelContainer:
	var plate: PanelContainer = make()
	var box: VBoxContainer = contents(plate)
	_add_icon(box, art, accent)
	var name_label := Label.new()
	name_label.name = "RewardName"
	name_label.text = title
	name_label.custom_minimum_size = Vector2(WIDTH - 2.0 * INSET_X, 26.0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_override("font", Typography.ui_font())
	Typography.set_label_size(name_label, Typography.SIZE_SECTION)
	name_label.add_theme_color_override("font_color", Palette.GOLD_BRIGHT)
	name_label.add_theme_color_override("font_outline_color", Palette.TEXT_OUTLINE)
	name_label.add_theme_constant_override("outline_size", 3)
	box.add_child(name_label)
	if not subtitle.is_empty():
		var label := Label.new()
		label.name = "RewardType"
		label.text = subtitle
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		Typography.set_label_size(label, Typography.SIZE_BODY)
		label.add_theme_color_override("font_color", Palette.TEXT_2)
		box.add_child(label)
	if not description.is_empty(): _add_description(box, description)
	return plate

static func _add_icon(box: VBoxContainer, art: TextureRect, accent: Color) -> void:
	var stage := Control.new()
	stage.name = "RewardArt"
	stage.custom_minimum_size = art.custom_minimum_size
	box.add_child(stage)
	var light: TextureRect = _make_light(accent)
	stage.add_child(light)
	light.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var half_extent := Vector2(art.custom_minimum_size.x, art.custom_minimum_size.y * 0.5)
	light.set_offset(SIDE_LEFT, -half_extent.x)
	light.set_offset(SIDE_RIGHT, half_extent.x)
	light.set_offset(SIDE_TOP, -half_extent.y)
	light.set_offset(SIDE_BOTTOM, half_extent.y)
	stage.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	var half_art: Vector2 = art.custom_minimum_size * 0.5
	art.set_offset(SIDE_LEFT, -half_art.x)
	art.set_offset(SIDE_RIGHT, half_art.x)
	art.set_offset(SIDE_TOP, -half_art.y)
	art.set_offset(SIDE_BOTTOM, half_art.y)

static func add_item_art_light(card: Control, accent: Color) -> void:
	var art: TextureRect = card.art_rect
	var art_frame: PanelContainer = card.art_frame
	# Draw after the native art shadow and behind the translucent item image.
	# The native illustration window owns the light's bounds.
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_frame.add_child(holder)
	art_frame.move_child(holder, art.get_index())
	var light: TextureRect = _make_light(accent)
	holder.add_child(light)
	light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

static func _make_light(accent: Color) -> TextureRect:
	if _light_material == null:
		_light_material = CanvasItemMaterial.new()
		_light_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var light := TextureRect.new()
	light.name = "RewardAccentLight"
	light.texture = _choice_icon_light()
	light.modulate = Color(accent.lerp(Palette.GOLD_BRIGHT, 0.35), 0.55)
	light.material = _light_material
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	light.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	light.stretch_mode = TextureRect.STRETCH_SCALE
	return light

static func _choice_icon_light() -> GradientTexture2D:
	if _accent_light == null:
		# The same radial falloff used by the relic offer's icon stage.
		var gradient := Gradient.new()
		gradient.set_color(0, Color(Color.WHITE, 0.90))
		gradient.set_color(1, Color(Color.WHITE, 0.0))
		gradient.add_point(0.45, Color(Color.WHITE, 0.28))
		_accent_light = GradientTexture2D.new()
		_accent_light.gradient = gradient
		_accent_light.fill = GradientTexture2D.FILL_RADIAL
		_accent_light.fill_from = Vector2(0.5, 0.5)
		_accent_light.fill_to = Vector2(1.0, 0.5)
		_accent_light.width = 128
		_accent_light.height = 96
	return _accent_light

static func _add_description(box: VBoxContainer, description: String) -> void:
	var rule := Rule.new()
	rule.name = "RewardRule"
	rule.accent = Palette.GOLD
	rule.custom_minimum_size.y = 8.0
	box.add_child(rule)

	var label := RichTextLabel.new()
	label.name = "RewardDescription"
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size.x = WIDTH - 2.0 * INSET_X
	label.size.x = label.custom_minimum_size.x
	Typography.set_rich_text_size(label, Typography.SIZE_BODY_LARGE)
	label.add_theme_color_override("default_color", Palette.TEXT)
	label.add_theme_color_override("font_outline_color", Palette.TEXT_OUTLINE)
	label.add_theme_constant_override("outline_size", 1)
	Inline.apply_to(label, description)
	box.add_child(label)
