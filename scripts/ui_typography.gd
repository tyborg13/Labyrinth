extends RefCounted
class_name UiTypography

const AssetLoader = preload("res://scripts/asset_loader.gd")

const DISPLAY_FONT_PATH: String = "res://fonts/LabyrinthCrumble-Display.tres"
const UI_FONT_PATH: String = "res://fonts/LabyrinthCrumble-UI.tres"
const TEXT_FONT_PATH: String = "res://fonts/LabyrinthCrumble-Text.tres"

const ROLE_CAPTION: String = "caption"
const ROLE_BODY: String = "body"
const ROLE_BODY_LARGE: String = "body_large"
const ROLE_SECTION: String = "section"
const ROLE_TITLE: String = "title"
const ROLE_HERO: String = "hero"
const ROLE_BANNER: String = "banner"

# Utility UI type scale. Caption and body are deliberate readability floors.
# Crumble intensity falls with size: display is boldly worn, UI keeps visible
# edge loss, and gameplay text uses smaller bites on its heavier skeleton.
const SIZE_CAPTION: int = 14
const SIZE_SMALL: int = 15
const SIZE_BODY: int = 16
const SIZE_BODY_LARGE: int = 18
const SIZE_SECTION: int = 21
const SIZE_SECTION_LARGE: int = 24
const SIZE_TITLE: int = 30
const SIZE_HERO: int = 38
const SIZE_BANNER: int = 58

const SPACE_HAIRLINE: int = 2
const SPACE_TIGHT: int = 4
const SPACE_SMALL: int = 8
const SPACE_MEDIUM: int = 12
const SPACE_LARGE: int = 16
const SPACE_XL: int = 24
const SPACE_XXL: int = 32

const SAFE_MARGIN: float = 24.0
const PANEL_PADDING_COMPACT: float = 14.0
const PANEL_PADDING: float = 20.0
const PANEL_PADDING_LARGE: float = 24.0
const PANEL_GAP: float = 16.0

const REFERENCE_VIEWPORT_WIDTH: float = 1600.0
const REFERENCE_VIEWPORT_HEIGHT: float = 1080.0
const HEIGHT_BOOST_WEIGHT: float = 0.14
const WIDTH_BOOST_WEIGHT: float = 0.06
const MAX_UI_SCALE: float = 1.12

static func display_font() -> Font:
	return AssetLoader.load_font(DISPLAY_FONT_PATH)

static func ui_font() -> Font:
	return AssetLoader.load_font(UI_FONT_PATH)

static func text_font() -> Font:
	return AssetLoader.load_font(TEXT_FONT_PATH)

static func body_font() -> Font:
	return text_font()

static func default_font(control: Control) -> Font:
	var font: Font = control.get_theme_default_font()
	if font != null:
		return font
	return text_font()

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

static func modal_size(control: Control, preferred: Vector2, minimum: Vector2 = Vector2.ZERO, safe_margin: float = SAFE_MARGIN) -> Vector2:
	var viewport_size: Vector2 = control.get_viewport_rect().size if control != null else Vector2(REFERENCE_VIEWPORT_WIDTH, REFERENCE_VIEWPORT_HEIGHT)
	var available := Vector2(
		maxf(1.0, viewport_size.x - safe_margin * 2.0),
		maxf(1.0, viewport_size.y - safe_margin * 2.0)
	)
	return Vector2(
		clampf(preferred.x, minf(minimum.x, available.x), available.x),
		clampf(preferred.y, minf(minimum.y, available.y), available.y)
	)

static func role_size(role: String) -> int:
	match role:
		ROLE_CAPTION:
			return SIZE_CAPTION
		ROLE_BODY:
			return SIZE_BODY
		ROLE_BODY_LARGE:
			return SIZE_BODY_LARGE
		ROLE_SECTION:
			return SIZE_SECTION
		ROLE_TITLE:
			return SIZE_TITLE
		ROLE_HERO:
			return SIZE_HERO
		ROLE_BANNER:
			return SIZE_BANNER
	return SIZE_BODY

static func font_for_role(role: String) -> Font:
	match role:
		ROLE_HERO, ROLE_BANNER:
			return display_font()
		ROLE_SECTION, ROLE_TITLE:
			return ui_font()
	return text_font()

static func apply_label_role(label: Label, role: String) -> void:
	if label == null:
		return
	var font: Font = font_for_role(role)
	if font != null:
		label.add_theme_font_override("font", font)
	set_label_size(label, role_size(role))

static func apply_button_role(button: Button, role: String = ROLE_BODY) -> void:
	if button == null:
		return
	var font: Font = ui_font()
	if font != null:
		button.add_theme_font_override("font", font)
	set_button_size(button, role_size(role))

static func apply_rich_text_role(label: RichTextLabel, role: String = ROLE_BODY) -> void:
	if label == null:
		return
	var font: Font = font_for_role(role)
	if font != null:
		for property_name: String in ["normal_font", "bold_font", "italics_font", "bold_italics_font", "mono_font"]:
			label.add_theme_font_override(property_name, font)
	set_rich_text_size(label, role_size(role))

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
	var font: Font = ui_font()
	if font != null:
		button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", scaled_font_size)
	var popup: PopupMenu = button.get_popup()
	if popup == null:
		return
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
