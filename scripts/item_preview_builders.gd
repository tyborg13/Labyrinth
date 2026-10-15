extends RefCounted

# Shared run/Chronicle presentation. The caller owns rules and progression;
# the builder needs only definitions and equipment state, never a RunScene.
const GameData = preload("res://scripts/game_data.gd")
const ElementData = preload("res://scripts/element_data.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const Tooltip = preload("res://scripts/ui_tooltip_panel.gd")
const Surface = preload("res://scripts/ui_component_surface.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const CARD_BASE_SIZE := Vector2(250, 352)
const CARD_TOOLTIP_SIZE := Vector2(224, 224 * 352.0 / 250.0)
const EQUIPMENT_TOOLTIP_CARD_SIZE := Vector2(180, 180 * 352.0 / 250.0)

var definitions: Dictionary = {}
var definition_resolver: Callable
var state: Dictionary = {}
var equipment_locked: bool = false

func card_definition(id: String) -> Dictionary:
	return definition_resolver.call(id) if definition_resolver.is_valid() else definitions.get(id, GameData.card_def(id))

func card_tooltip(card_id: String, interactive: bool = false, destination: String = "") -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD_TOOLTIP_SIZE + Vector2(18.0, 18.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", Surface.equipment_panel_style(ElementData.accent(GameData.card_element(card_id)), true))
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS if interactive else Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(margin)
	if not destination.is_empty():
		panel.set_meta("item_pickup_tooltip_surface", true)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 8)
		margin.add_child(column)
		column.add_child(card_preview(card_id, CARD_TOOLTIP_SIZE, interactive))
		var destination_label := Label.new()
		destination_label.text = destination
		UiTypography.set_label_size(destination_label, UiTypography.SIZE_CAPTION)
		destination_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		destination_label.add_theme_color_override("font_color", Palette.PREVIEW_TITLE)
		column.add_child(destination_label)
	else:
		margin.add_child(card_preview(card_id, CARD_TOOLTIP_SIZE, interactive))
	return panel

func equipment_tooltip(equipment_id: String, interactive: bool = false) -> Control:
	var item: Dictionary = GameData.equipment_def(equipment_id)
	var accent := Color(GameData.equipment_accent(equipment_id))
	var panel := PanelContainer.new()
	panel.set_meta("equipment_tooltip_surface", true)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", Surface.equipment_panel_style(accent, true))
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS if interactive else Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 9)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 9)
	vbox.add_child(header)
	var icon := TextureRect.new()
	icon.texture = AssetLoader.load_texture(str(item.get("icon_path", "")))
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(42.0, 42.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(icon)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 0)
	header.add_child(title_box)
	var name_label := Label.new()
	name_label.text = str(item.get("name", equipment_id))
	UiTypography.set_label_size(name_label, UiTypography.SIZE_SMALL)
	name_label.add_theme_color_override("font_color", Palette.PREVIEW_TITLE)
	name_label.add_theme_color_override("font_outline_color", Palette.PREVIEW_OUTLINE)
	name_label.add_theme_constant_override("outline_size", 1)
	title_box.add_child(name_label)
	var meta_label := Label.new()
	meta_label.text = "%s | %s" % [GameData.equipment_slot(equipment_id).capitalize(), GameData.equipment_rarity(equipment_id).capitalize()]
	UiTypography.set_label_size(meta_label, UiTypography.SIZE_CAPTION)
	meta_label.add_theme_color_override("font_color", Palette.PREVIEW_META)
	title_box.add_child(meta_label)

	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 8)
	card_row.mouse_filter = Control.MOUSE_FILTER_PASS if interactive else Control.MOUSE_FILTER_IGNORE
	vbox.add_child(card_row)
	for card_id_var: Variant in GameData.equipment_cards(equipment_id, state):
		card_row.add_child(card_preview(str(card_id_var), EQUIPMENT_TOOLTIP_CARD_SIZE, interactive))
	if equipment_locked:
		var locked_label := Label.new()
		locked_label.text = "Locked in combat"
		UiTypography.set_label_size(locked_label, UiTypography.SIZE_CAPTION)
		locked_label.add_theme_color_override("font_color", Palette.PREVIEW_LOCKED)
		vbox.add_child(locked_label)
	return panel

func card_preview(card_id: String, card_size: Vector2, interactive: bool = false) -> Control:
	# Load the card scene only when a preview is requested, outside menu boot.
	var widget: Control = load("res://scenes/card_widget.tscn").instantiate()
	widget.focus_mode = Control.FOCUS_NONE
	widget.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	widget.configure(card_id, false, false, true, false, interactive, true, card_definition(card_id))
	var factor: float = minf(card_size.x / CARD_BASE_SIZE.x, card_size.y / CARD_BASE_SIZE.y)
	var slot := Control.new()
	slot.custom_minimum_size = CARD_BASE_SIZE * factor
	slot.size = slot.custom_minimum_size
	slot.mouse_filter = Control.MOUSE_FILTER_PASS if interactive else Control.MOUSE_FILTER_IGNORE
	var scaler := Control.new()
	scaler.name = "CardScaleFrame"
	scaler.size = CARD_BASE_SIZE
	scaler.custom_minimum_size = CARD_BASE_SIZE
	scaler.scale = Vector2.ONE * factor
	scaler.mouse_filter = slot.mouse_filter
	slot.add_child(scaler)
	widget.custom_minimum_size = CARD_BASE_SIZE
	widget.size = CARD_BASE_SIZE
	scaler.add_child(widget)
	widget.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return slot

static func text_tooltip(text: String, relic_id: String = "") -> Control:
	if text.strip_edges().is_empty():
		return null
	var panel: Control = Tooltip.make_text(text)
	if not relic_id.is_empty():
		panel.set_meta("relic_id", relic_id)
	return panel

static func relic_tooltip(id: String) -> Control:
	var relic: Dictionary = GameData.relic_def(id)
	return text_tooltip("%s\n%s" % [relic.get("name", id), relic.get("description", "")], id)
