extends RefCounted

## The skill-choice factory is also used by Curator's Patience. Scope the
## reward finish to Deferred Choice, preserving the shared dialog's geometry.
const SkinLibrary = preload("res://scripts/ui_skin.gd")
const TITLE_COLORS: Array = ["font_color", "font_outline_color", "font_shadow_color"]
const TITLE_CONSTANTS: Array = ["outline_size", "shadow_offset_x", "shadow_offset_y"]

var _original_style: StyleBox
var _original_font: Font
var _original_colors: Dictionary = {}
var _original_constants: Dictionary = {}

func configure(panel: PanelContainer, title: Label, reward_title: Label, skin: UiSkin, enabled: bool) -> void:
	if _original_style == null:
		_original_style = panel.get_theme_stylebox("panel")
		_original_font = title.get_theme_font("font")
		for key: String in TITLE_COLORS: _original_colors[key] = title.get_theme_color(key)
		for key: String in TITLE_CONSTANTS: _original_constants[key] = title.get_theme_constant(key)
	if enabled:
		# Keep the original symmetric border inset plus the MarginContainer's
		# padding; UiSkin's default safe inset would change the approved layout.
		panel.set_meta("panel_safe_inset", _original_style.get_content_margin(SIDE_LEFT))
		skin.apply_panel_surface(panel, SkinLibrary.SURFACE_DIALOG)
		panel.get_node(SkinLibrary.PANEL_ORNAMENT_NAME).show()
		title.add_theme_font_override("font", reward_title.get_theme_font("font"))
		for key: String in TITLE_COLORS: title.add_theme_color_override(key, reward_title.get_theme_color(key))
		for key: String in TITLE_CONSTANTS: title.add_theme_constant_override(key, reward_title.get_theme_constant(key))
	else:
		panel.add_theme_stylebox_override("panel", _original_style)
		panel.remove_meta("panel_safe_inset")
		panel.remove_meta("surface_variant")
		var ornament: Control = panel.get_node_or_null(SkinLibrary.PANEL_ORNAMENT_NAME)
		if ornament != null: ornament.hide()
		title.add_theme_font_override("font", _original_font)
		for key: String in TITLE_COLORS: title.add_theme_color_override(key, _original_colors[key])
		for key: String in TITLE_CONSTANTS: title.add_theme_constant_override(key, _original_constants[key])
