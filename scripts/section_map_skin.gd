extends RefCounted
class_name SectionMapSkin

const Assets = preload("res://scripts/asset_loader.gd")
const Icons = preload("res://scripts/room_icon_library.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const ART: String = "res://assets/art/ui/section_map/"

static var _textures: Dictionary = {}

static func _texture(name: String) -> Texture2D:
	if not _textures.has(name):
		var image: Image = Assets.load_texture(ART + name + ".png").get_image()
		if name == "action_frame":
			image = image.get_region(Rect2i(24, 212, 1944, 328))
			image.resize(512, 86, Image.INTERPOLATE_LANCZOS)
		elif name == "medallion":
			image.resize(192, 192, Image.INTERPOLATE_LANCZOS)
		elif name == "panel_frame":
			image.resize(720, 240, Image.INTERPOLATE_LANCZOS)
		image.generate_mipmaps()
		_textures[name] = ImageTexture.create_from_image(image)
	return _textures[name]

static func icon_texture(id: String) -> Texture2D:
	var key: String = "icon_" + id
	if not _textures.has(key):
		var source: Texture2D = Icons.icon_texture(id)
		if source == null:
			return null
		var image: Image = source.get_image()
		image.resize(128, 128, Image.INTERPOLATE_LANCZOS)
		image.generate_mipmaps()
		_textures[key] = ImageTexture.create_from_image(image)
	return _textures[key]

static func panel_style() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _texture("panel_frame")
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	style.content_margin_left = 44
	style.content_margin_right = 44
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	# Preserve the painted corner details without inflating the native layout.
	style.texture_margin_left = 26
	style.texture_margin_right = 26
	style.texture_margin_top = 26
	style.texture_margin_bottom = 26
	return style

static func button(button: Button, variant: String = "standard") -> void:
	# Action controls share the game's native forged-metal proportions and states;
	# painted art remains on the map's frames, medallions, and room identities.
	var skin := preload("res://scripts/ui_skin.gd").new()
	skin.apply_button_stylebox_overrides(button, variant)
	skin.apply_button_text_overrides(button)
	Typography.apply_button_role(button, Typography.ROLE_BODY_LARGE)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func section_tab(button: Button) -> void:
	# Section navigation keeps its painted bronze seals; action-button cleanup
	# must not replace the user-approved identity of these tabs.
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style := StyleBoxTexture.new()
		style.texture = _texture("medallion")
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		style.modulate_color = Color(0.75, 0.71, 0.63)
		if state in ["hover", "hover_pressed"]: style.modulate_color = Color(1.35, 1.22, 0.96)
		if state == "pressed": style.modulate_color = Color(1.1, 0.95, 0.68)
		if state == "disabled": style.modulate_color = Color(0.32, 0.34, 0.37)
		button.add_theme_stylebox_override(state, style)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("ffe3a0")
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(36)
	focus.set_expand_margin_all(2)
	button.add_theme_stylebox_override("focus", focus)
	Typography.apply_button_role(button, Typography.ROLE_BODY_LARGE)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, Color("eddbb4"))
	button.add_theme_color_override("font_disabled_color", Color("827b6f"))
	button.add_theme_color_override("font_outline_color", Color("09090d"))
	button.add_theme_constant_override("outline_size", 2)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
