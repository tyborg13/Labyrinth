extends Button

# Native Button owns hit-testing, focus, activation and disabled actions. Only
# its paint changes: no plate, border, focus box or replacement input handler.
const Assets = preload("res://scripts/asset_loader.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Surface = preload("res://scripts/ui_component_surface.gd")
const Feedback = preload("res://scripts/ui_button_feedback.gd")
const Frame = preload("res://scripts/ui_gilded_frame.gd")
const HEIGHT: float = 62.0
const MIN_WIDTH: float = 210.0
var primary: bool = false
var _source: Texture2D
var _brush: Texture2D
var _brush_size := Vector2i.ZERO
var _label: Label

func configure(label_text: String, is_primary: bool) -> void:
	primary = is_primary
	text = label_text
	_source = Assets.load_texture("res://assets/art/ui/turn_order_ink/brush_b.png" if primary else "res://assets/art/ui/turn_order_ink/brush_d.png")
	_brush = _source
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	Surface.clear_button_style(self)
	Feedback.bind_button(self)
	add_theme_font_override("font", Typography.ui_font())
	Typography.set_button_size(self, 18)
	# Keep Button.text for accessibility and existing controller/test consumers.
	# The tracked child label is the only visible text.
	for state: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_disabled_color", "font_hover_pressed_color", "font_outline_color", "font_shadow_color"]:
		add_theme_color_override(state, Color.TRANSPARENT)
	_label = Label.new()
	_label.name = "ChoiceLabel"
	Typography.apply_spaced_eyebrow(_label, 18, 2.0, Palette.GOLD_BRIGHT if primary else Palette.TEXT)
	_label.uppercase = false
	_label.add_theme_color_override("font_outline_color", Palette.TEXT_OUTLINE)
	_label.add_theme_constant_override("outline_size", 2)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.text = label_text
	add_child(_label)
	custom_minimum_size = Vector2(maxf(MIN_WIDTH, _label.get_minimum_size().x + 64.0), HEIGHT)
	resized.connect(_layout)
	for event: Signal in [mouse_entered, mouse_exited, focus_entered, focus_exited, button_down, button_up]: event.connect(queue_redraw)
	_layout()

# The label only measures its final shaped width once it is in the tree, so the
# brush refits its minimum width then (the choice row re-sorts on the change).
func _notification(what: int) -> void:
	if what == NOTIFICATION_READY or what == NOTIFICATION_THEME_CHANGED: _fit_width()

func _fit_width() -> void:
	if _label == null: return
	var wanted: float = maxf(MIN_WIDTH, _label.get_minimum_size().x * _label.scale.x + 64.0)
	if not is_equal_approx(custom_minimum_size.x, wanted): custom_minimum_size = Vector2(wanted, HEIGHT)

func _layout() -> void:
	if _label == null: return
	_fit_width()
	var dimensions := Vector2i(roundi(size.x), roundi(size.y))
	if dimensions.x > 0 and dimensions.y > 0 and dimensions != _brush_size:
		var image: Image = Assets.texture_source_image(_source).duplicate()
		image.resize(dimensions.x, dimensions.y, Image.INTERPOLATE_LANCZOS)
		_brush = ImageTexture.create_from_image(image)
		_brush_size = dimensions
	_label.size = _label.get_minimum_size()
	_label.position = (size - _label.size) * 0.5
	queue_redraw()

func _draw() -> void:
	if _brush == null: return
	var active: bool = not disabled and (is_hovered() or has_focus())
	var ink: Color = Palette.DIALOGUE_CHOICE_PRIMARY if primary else Palette.DIALOGUE_CHOICE_SECONDARY
	# Value changes preserve the ink hue/saturation. Press takes precedence.
	ink.v *= 0.90 if is_pressed() else (1.18 if active else 1.0)
	# Director 2026-11-16: a disabled choice keeps its brush shape at 45% and a muted label.
	draw_texture_rect(_brush, Rect2(Vector2.ZERO, size), false, Color(ink, 0.45 if disabled else 0.95))
	var label_color: Color = Palette.TEXT_3 if disabled else (Palette.GOLD_BRIGHT if primary or active else Palette.TEXT)
	if _label.get_theme_color("font_color") != label_color: _label.add_theme_color_override("font_color", label_color)
	if has_focus() and not disabled:
		Frame.draw_solid_diamond(self, Vector2(_label.position.x - 14.0, size.y * 0.5), 7.0, Palette.EMBER)
