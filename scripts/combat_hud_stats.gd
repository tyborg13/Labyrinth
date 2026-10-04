extends Label

const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const Tooltip = preload("res://scripts/ui_tooltip_panel.gd")

var _level := Label.new()
var _value := Label.new()

func _init() -> void:
	# Retain the native label's semantic text and feedback target; children paint it.
	add_theme_font_size_override("font_size", 1)
	add_theme_color_override("font_color", Color.TRANSPARENT)
	add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	add_theme_constant_override("outline_size", 0)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var stack := VBoxContainer.new()
	stack.name = "StatsStack"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_theme_constant_override("separation", 2)
	add_child(stack)
	_level.name = "LevelEyebrow"
	_level.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Typography.apply_eyebrow(_level, 12, Palette.TEXT_2)
	stack.add_child(_level)
	var embers := HBoxContainer.new()
	embers.name = "EmberRow"
	embers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	embers.add_theme_constant_override("separation", 5)
	stack.add_child(embers)
	var ember := TextureRect.new()
	ember.name = "EmberIcon"
	ember.texture = AssetLoader.load_texture("res://assets/art/icons/ember.png")
	ember.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ember.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ember.custom_minimum_size = Vector2.ONE * Typography.scaled_value(self, 20.0)
	ember.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ember.mouse_filter = Control.MOUSE_FILTER_IGNORE
	embers.add_child(ember)
	_value.name = "EmberValue"
	_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_value.add_theme_font_override("font", Typography.ui_font())
	Typography.set_label_size(_value, 22)
	_value.add_theme_color_override("font_color", Palette.GOLD_BRIGHT)
	embers.add_child(_value)
	set_values(1, 0)

func set_values(level: int, ember_count: int) -> void:
	text = "LV %d  EMBERS %d" % [level, ember_count]
	_level.text = "LEVEL %d" % level
	_value.text = str(ember_count)
	Typography.apply_eyebrow(_level, 12, Palette.TEXT_2)
	Typography.set_label_size(_value, 22)
	(get_node("StatsStack/EmberRow/EmberIcon") as Control).custom_minimum_size = Vector2.ONE * Typography.scaled_value(self, 20.0)
	(get_node("StatsStack/EmberRow") as HBoxContainer).add_theme_constant_override("separation", roundi(Typography.scaled_value(self, 5.0)))
	(get_node("StatsStack") as VBoxContainer).add_theme_constant_override("separation", roundi(Typography.scaled_value(self, 2.0)))
	custom_minimum_size = get_node("StatsStack").get_combined_minimum_size()

func _make_custom_tooltip(for_text: String) -> Object:
	return null if for_text.strip_edges().is_empty() else Tooltip.make_text(for_text)
