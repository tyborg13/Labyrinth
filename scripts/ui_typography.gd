extends RefCounted
class_name UiTypography

const AssetLoader = preload("res://scripts/asset_loader.gd")

const PIXEL_FONT_PATH: String = "res://fonts/PressStart2P-Regular.ttf"

const SIZE_CAPTION: int = 11
const SIZE_SMALL: int = 12
const SIZE_BODY: int = 13
const SIZE_BODY_LARGE: int = 15
const SIZE_SECTION: int = 18
const SIZE_SECTION_LARGE: int = 20
const SIZE_TITLE: int = 24
const SIZE_HERO: int = 32

const REFERENCE_VIEWPORT_WIDTH: float = 1600.0
const REFERENCE_VIEWPORT_HEIGHT: float = 1080.0
const HEIGHT_BOOST_WEIGHT: float = 0.40
const WIDTH_BOOST_WEIGHT: float = 0.16
const MAX_UI_SCALE: float = 1.40

static func default_font(control: Control) -> Font:
	var font: Font = control.get_theme_default_font()
	if font != null:
		return font
	return AssetLoader.load_font(PIXEL_FONT_PATH)

static func ui_scale(control: Control) -> float:
	if control == null:
		return 1.0
	var reference: Control = control
	if not reference.is_inside_tree():
		var ancestor: Node = reference.get_parent()
		while ancestor != null:
			if ancestor is Control and (ancestor as Control).is_inside_tree():
				reference = ancestor
				break
			ancestor = ancestor.get_parent()
		if not reference.is_inside_tree():
			return 1.0
	var viewport_size: Vector2 = reference.get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 1.0
	var height_boost: float = clampf((REFERENCE_VIEWPORT_HEIGHT - viewport_size.y) / 700.0, 0.0, 1.0) * HEIGHT_BOOST_WEIGHT
	var width_boost: float = clampf((REFERENCE_VIEWPORT_WIDTH - viewport_size.x) / 800.0, 0.0, 1.0) * WIDTH_BOOST_WEIGHT
	return clampf(1.0 + height_boost + width_boost, 1.0, MAX_UI_SCALE)

static func scaled_value(control: Control, value: float) -> float:
	return value * ui_scale(control)

static func scaled_size(control: Control, size: int) -> int:
	return maxi(1, int(round(float(size) * ui_scale(control))))

static func apply_board_font(control: Control, board_view: Control) -> void:
	if board_view == null or not board_view.has_method("apply_unit_label_font"):
		return
	var font: Font = default_font(control)
	if font != null:
		board_view.apply_unit_label_font(font)

static func set_label_size(label: Label, size: int) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", scaled_size(label, size))

static func set_button_size(button: Button, size: int) -> void:
	if button == null:
		return
	button.add_theme_font_size_override("font_size", scaled_size(button, size))

static func set_option_button_size(button: OptionButton, size: int) -> void:
	if button == null:
		return
	var scaled_font_size: int = scaled_size(button, size)
	button.add_theme_font_size_override("font_size", scaled_font_size)
	var popup: PopupMenu = button.get_popup()
	if popup == null:
		return
	var font: Font = default_font(button)
	if font != null:
		popup.add_theme_font_override("font", font)
	popup.add_theme_font_size_override("font_size", scaled_font_size)

static func set_rich_text_size(label: RichTextLabel, size: int) -> void:
	if label == null:
		return
	var scaled_font_size: int = scaled_size(label, size)
	for property_name: String in [
		"normal_font_size",
		"bold_font_size",
		"italics_font_size",
		"bold_italics_font_size",
		"mono_font_size"
	]:
		label.add_theme_font_size_override(property_name, scaled_font_size)
