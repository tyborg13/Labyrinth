extends RefCounted
class_name UiSkin

const AssetLoader = preload("res://scripts/asset_loader.gd")

const BUTTON_ATLAS_PATH := "res://assets/ui/Medieval.png"
const BUTTON_ATLAS_REGION := Rect2i(321, 100, 90, 27)

const TEXTURES := {
	"panel_main": {
		"path": "res://assets/ui/pixel_medieval/panel_wood_parchment.svg"
	},
	"panel_inset": {
		"path": "res://assets/ui/pixel_medieval/panel_silver_inset.svg"
	},
	"button_normal": {
		"path": BUTTON_ATLAS_PATH,
		"region": BUTTON_ATLAS_REGION,
		"tint": Color(0.98, 1.34, 1.32, 1.0)
	},
	"button_hover": {
		"path": BUTTON_ATLAS_PATH,
		"region": BUTTON_ATLAS_REGION,
		"tint": Color(1.12, 1.52, 1.48, 1.0)
	},
	"button_focus": {
		"path": BUTTON_ATLAS_PATH,
		"region": BUTTON_ATLAS_REGION,
		"tint": Color(1.28, 1.92, 1.70, 1.0)
	},
	"button_pressed": {
		"path": BUTTON_ATLAS_PATH,
		"region": BUTTON_ATLAS_REGION,
		"tint": Color(0.92, 1.24, 1.18, 1.0)
	},
	"button_disabled": {
		"path": BUTTON_ATLAS_PATH,
		"region": BUTTON_ATLAS_REGION,
		"tint": Color(0.82, 1.08, 1.06, 1.0)
	}
}

const PANEL_MARGIN := 12.0
const INSET_MARGIN := 10.0
const BUTTON_TEXTURE_MARGIN := 7.0
const BUTTON_MARGIN_H := 14.0
const BUTTON_MARGIN_V := 6.0
const BUTTON_FONT_COLOR := Color("efe4c1")
const BUTTON_FONT_OUTLINE_COLOR := Color("3e2f22")
const BUTTON_FONT_FOCUS_COLOR := Color("fff7dd")
const BUTTON_FONT_DISABLED_COLOR := Color("d3c39f")
const BUTTON_FONT_OUTLINE_SIZE := 2
const ACCENT_TEXT_COLOR := Color("b8860b")
const ACCENT_TEXT_OUTLINE_COLOR := Color("3e2f22")

var _cache: Dictionary = {}

func texture(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	if not TEXTURES.has(key):
		push_error("Unknown UI texture key: %s" % key)
		return null
	var spec: Dictionary = TEXTURES[key]
	var path: String = str(spec.get("path", ""))
	var region: Rect2i = spec.get("region", Rect2i())
	var tint: Color = spec.get("tint", Color.WHITE)
	var tex: Texture2D = AssetLoader.load_texture_region(path, region) if region.size.x > 0 and region.size.y > 0 else AssetLoader.load_texture(path)
	if tex != null:
		tex = AssetLoader.modulate_texture(tex, tint)
	_cache[key] = tex
	return tex

func make_panel_style(texture_key: String, margin: float = PANEL_MARGIN, content_margin: float = 16.0) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture(texture_key)
	style.texture_margin_left = margin
	style.texture_margin_top = margin
	style.texture_margin_right = margin
	style.texture_margin_bottom = margin
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.content_margin_left = content_margin
	style.content_margin_top = content_margin
	style.content_margin_right = content_margin
	style.content_margin_bottom = content_margin
	return style

func make_inset_panel_style(content_margin: float = 14.0) -> StyleBoxTexture:
	return make_panel_style("panel_inset", INSET_MARGIN, content_margin)

func make_board_frame_style(content_margin: float = 26.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2f2f34")
	style.border_color = Color("d1a65e")
	style.border_width_left = 6
	style.border_width_top = 6
	style.border_width_right = 6
	style.border_width_bottom = 6
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	style.shadow_size = 12
	style.content_margin_left = content_margin
	style.content_margin_top = content_margin
	style.content_margin_right = content_margin
	style.content_margin_bottom = content_margin
	style.expand_margin_left = 4
	style.expand_margin_top = 4
	style.expand_margin_right = 4
	style.expand_margin_bottom = 4
	return style

func make_plain_card_style(background: Color = Color("e8dcc0"), border: Color = Color("8a6d49"), content_margin: float = 12.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	style.shadow_size = 4
	style.content_margin_left = content_margin
	style.content_margin_top = content_margin
	style.content_margin_right = content_margin
	style.content_margin_bottom = content_margin
	return style

func make_button_style(texture_key: String) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	var pressed_offset: float = 1.0 if texture_key == "button_pressed" else 0.0
	var focus_expand: float = 3.0 if texture_key == "button_focus" else 0.0
	style.texture = texture(texture_key)
	style.texture_margin_left = BUTTON_TEXTURE_MARGIN
	style.texture_margin_top = BUTTON_TEXTURE_MARGIN
	style.texture_margin_right = BUTTON_TEXTURE_MARGIN
	style.texture_margin_bottom = BUTTON_TEXTURE_MARGIN
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.content_margin_left = BUTTON_MARGIN_H
	style.content_margin_top = BUTTON_MARGIN_V + pressed_offset
	style.content_margin_right = BUTTON_MARGIN_H
	style.content_margin_bottom = BUTTON_MARGIN_V - pressed_offset
	style.expand_margin_left = focus_expand
	style.expand_margin_top = focus_expand
	style.expand_margin_right = focus_expand
	style.expand_margin_bottom = focus_expand
	return style

func apply_button_stylebox_overrides(
	button: BaseButton,
	normal_state: String = "button_normal",
	hover_state: String = "button_hover",
	pressed_state: String = "button_pressed",
	focus_state: String = "button_focus",
	disabled_state: String = "button_disabled"
) -> void:
	button.add_theme_stylebox_override("normal", make_button_style(normal_state))
	button.add_theme_stylebox_override("hover", make_button_style(hover_state))
	button.add_theme_stylebox_override("pressed", make_button_style(pressed_state))
	button.add_theme_stylebox_override("focus", make_button_style(focus_state))
	button.add_theme_stylebox_override("disabled", make_button_style(disabled_state))

func apply_button_text_overrides(
	button: BaseButton,
	font_color: Color = BUTTON_FONT_COLOR,
	outline_color: Color = BUTTON_FONT_OUTLINE_COLOR,
	disabled_color: Color = BUTTON_FONT_DISABLED_COLOR,
	outline_size: int = BUTTON_FONT_OUTLINE_SIZE
) -> void:
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_focus_color", BUTTON_FONT_FOCUS_COLOR)
	button.add_theme_color_override("font_hover_color", BUTTON_FONT_FOCUS_COLOR)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_disabled_color", disabled_color)
	button.add_theme_color_override("font_outline_color", outline_color)
	button.add_theme_constant_override("outline_size", outline_size)

func apply_button_label_overrides(
	label: Label,
	font_color: Color = BUTTON_FONT_COLOR,
	outline_color: Color = BUTTON_FONT_OUTLINE_COLOR,
	outline_size: int = BUTTON_FONT_OUTLINE_SIZE
) -> void:
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", outline_color)
	label.add_theme_constant_override("outline_size", outline_size)

func apply_accent_label_overrides(label: Label, outline_size: int = BUTTON_FONT_OUTLINE_SIZE) -> void:
	apply_button_label_overrides(label, ACCENT_TEXT_COLOR, ACCENT_TEXT_OUTLINE_COLOR, outline_size)

func make_scenario_list_button_style(selected: bool, hovered: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("edd39d") if selected else (Color("f5e8c8") if hovered else Color("e5dac0"))
	style.border_color = Color("c27c24") if selected else (Color("bb8a49") if hovered else Color("8a6d49"))
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	style.shadow_size = 5
	style.content_margin_left = BUTTON_MARGIN_H
	style.content_margin_top = BUTTON_MARGIN_V + 2.0
	style.content_margin_right = BUTTON_MARGIN_H
	style.content_margin_bottom = BUTTON_MARGIN_V + 2.0
	style.expand_margin_left = 2.0
	style.expand_margin_top = 2.0
	style.expand_margin_right = 2.0
	style.expand_margin_bottom = 2.0
	return style

func make_flat_panel_style(color: Color, content_margin: float = 16.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.content_margin_left = content_margin
	style.content_margin_top = content_margin
	style.content_margin_right = content_margin
	style.content_margin_bottom = content_margin
	return style
