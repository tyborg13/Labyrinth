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
