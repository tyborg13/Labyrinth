extends Button

const AssetLoader = preload("res://scripts/asset_loader.gd")
const ButtonFeedback = preload("res://scripts/ui_button_feedback.gd")
const ThemedButtonOrnament = preload("res://scripts/themed_button_ornament.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const HIT_PADDING: float = 10.0
const FONT_SIZE: int = 18

# Recaps manage one selection across plates and links. Other owners can use
# the control's own hover/focus state without a selection manager.
var owner_manages_selection: bool = false
var _pointer_inside: bool = false

func _init() -> void:
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_theme_font_override("font", spaced_font(4))
	add_theme_font_size_override("font_size", FONT_SIZE)
	var bare := StyleBoxEmpty.new()
	bare.content_margin_top = HIT_PADDING
	bare.content_margin_bottom = HIT_PADDING
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, bare)
	focus_marker = AssetLoader.load_texture_source_first(ThemedButtonOrnament.UMBRA_FOCUS_MARKER_LEFT_PATH)
	focus_entered.connect(_refresh_own_selection)
	focus_exited.connect(_refresh_own_selection)
	mouse_entered.connect(_on_pointer_entered)
	mouse_exited.connect(_on_pointer_exited)
	ButtonFeedback.bind_button(self)
	refresh()

static func spaced_font(spacing: int) -> FontVariation:
	var font := UiTypography.eyebrow_font().duplicate() as FontVariation
	font.spacing_glyph = spacing
	return font

func _on_pointer_entered() -> void:
	_pointer_inside = true
	_refresh_own_selection()

func _on_pointer_exited() -> void:
	_pointer_inside = false
	_refresh_own_selection()

func _refresh_own_selection() -> void:
	if not owner_manages_selection:
		set_meta("umbra_selected", _pointer_inside or has_focus())
	refresh()

var focus_marker: Texture2D
# Hover and focus both select it, the same selection the slabs use.
func engaged() -> bool:
	return bool(get_meta("umbra_selected", false))
func refresh() -> void:
	var ink: Color = Palette.GOLD_BRIGHT if engaged() else Palette.GOLD
	for state: String in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		add_theme_color_override(state, ink)
	queue_redraw()
func _draw() -> void:
	if not engaged():
		return
	var font: Font = get_theme_font("font")
	var font_size: int = get_theme_font_size("font_size")
	var baseline: float = (size.y - font.get_height(font_size)) * 0.5 + font.get_ascent(font_size)
	# The underline runs under the words; the chevron stays a pointer. Letter
	# spacing trails the final glyph, so the line stops at that glyph's ink.
	var trailing: float = float((font as FontVariation).spacing_glyph) if font is FontVariation else 0.0
	var width: float = font.get_string_size(text.rstrip(" ›"), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x - trailing
	draw_rect(Rect2(0, roundf(baseline + 4.0), width, 1.0), Palette.GOLD_BRIGHT)
	if has_focus() and focus_marker != null:
		# The slabs' own focus arrow, at the link's cap height.
		var marker_height: float = 24.0
		var marker_size := Vector2(marker_height * focus_marker.get_width() / focus_marker.get_height(), marker_height)
		draw_texture_rect(focus_marker, Rect2(Vector2(-marker_size.x - 8.0, baseline - font_size * 0.36 - marker_height * 0.5), marker_size), false)

