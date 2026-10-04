extends Control

const AssetLoader = preload("res://scripts/asset_loader.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Signage = preload("res://scripts/scavenger_signage.gd")
const Surface = preload("res://scripts/ui_component_surface.gd")
const TAG_PATH := "res://assets/art/ui/visual_pass_4/price_tag.png"
const EMBER_PATH := "res://assets/art/icons/ember.png"

var amount: int = 0
var selling: bool = false
var affordable: bool = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag := TextureRect.new()
	tag.name = "HangingPriceTagArt"
	tag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tag.offset_top = Typography.scaled_value(self, 4.0)
	tag.offset_bottom = Typography.scaled_value(self, 4.0)
	tag.texture = Surface.mipmapped_texture(TAG_PATH)
	tag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tag.stretch_mode = TextureRect.STRETCH_SCALE
	tag.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not affordable:
		var faded: ShaderMaterial = Surface.texture_material()
		faded.set_shader_parameter("saturation", 0.15)
		tag.material = faded
		tag.self_modulate.a = 0.8
	add_child(tag)
	var row := HBoxContainer.new()
	row.name = "PriceTagInk"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.position = Vector2(8.0, 26.0) * Typography.ui_scale(self)
	row.size = Vector2(102.0, 34.0) * Typography.ui_scale(self)
	row.add_theme_constant_override("separation", Typography.scaled_size(self, 4))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var ember := TextureRect.new()
	ember.texture = AssetLoader.load_texture(EMBER_PATH)
	ember.custom_minimum_size = Vector2(16.0, 20.0) * Typography.ui_scale(self)
	ember.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ember.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ember.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ember.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ember.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ember)
	var value := Label.new()
	value.name = "PriceTagValue"
	value.text = ("+%d" if selling else "%d") % amount
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_override("font", Typography.ui_font())
	Typography.set_label_size(value, 19)
	value.add_theme_color_override("font_color", Color("2f5a24") if selling else Signage.INK if affordable else Color("8e1f17"))
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(value)
