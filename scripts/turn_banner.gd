extends Control

# A brief, non-blocking phase banner ("YOUR TURN" / "ENEMY TURN") centred above
# the board. It never takes input or delays resolution; it only marks the
# hand-off so the rhythm of the fight reads at a glance.

const GildedFrame = preload("res://scripts/ui_gilded_frame.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

const BANNER_HEIGHT: float = 84.0
const BANNER_TOP_RATIO: float = 0.115
const FADE_IN_SECONDS: float = 0.16
const HOLD_SECONDS: float = 0.62
const FADE_OUT_SECONDS: float = 0.34
const REDUCED_HOLD_SECONDS: float = 0.75
const RULE_HALF_WIDTH: float = 250.0

var _label: Label
var _accent: Color = Palette.GOLD
var _tween: Tween
var _reveal: float = 1.0

func _ready() -> void:
	name = "TurnBanner"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_label = Label.new()
	_label.name = "TurnBannerLabel"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var font: FontVariation = FontVariation.new()
	font.base_font = UiTypography.heavy_ui_font()
	font.spacing_glyph = 6
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", 40)
	_label.add_theme_color_override("font_outline_color", Color(0.02, 0.012, 0.01, 0.95))
	_label.add_theme_constant_override("outline_size", 8)
	_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
	_label.add_theme_constant_override("shadow_offset_y", 4)
	_label.add_theme_constant_override("shadow_outline_size", 10)
	add_child(_label)
	resized.connect(_layout)
	_layout()

func show_banner(text: String, accent: Color, reduced_motion: bool) -> void:
	if _label == null:
		return
	_accent = accent
	_label.text = text
	_label.add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.30))
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = true
	_layout()
	if reduced_motion:
		_set_reveal(1.0)
		modulate.a = 1.0
		_tween = create_tween()
		_tween.tween_interval(REDUCED_HOLD_SECONDS)
		_tween.tween_callback(hide)
		return
	modulate.a = 0.0
	_set_reveal(0.0)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_SECONDS)
	_tween.tween_method(_set_reveal, 0.0, 1.0, FADE_IN_SECONDS + 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_interval(HOLD_SECONDS)
	_tween.chain().tween_property(self, "modulate:a", 0.0, FADE_OUT_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(hide)

func _set_reveal(value: float) -> void:
	_reveal = clampf(value, 0.0, 1.0)
	if _label != null:
		_label.scale = Vector2.ONE * lerpf(1.08, 1.0, _reveal)
	queue_redraw()

func _layout() -> void:
	if _label == null:
		return
	var top: float = size.y * BANNER_TOP_RATIO
	_label.position = Vector2(0.0, top)
	_label.size = Vector2(size.x, BANNER_HEIGHT)
	_label.pivot_offset = _label.size * 0.5

func _draw() -> void:
	if _label == null or size.x <= 0.0:
		return
	var center := Vector2(size.x * 0.5, size.y * BANNER_TOP_RATIO + BANNER_HEIGHT * 0.5)
	# A soft dark band gives the lettering a stage without a hard box.
	var band_half: float = RULE_HALF_WIDTH * 1.35 * _reveal
	var band := Rect2(center - Vector2(band_half, 38.0), Vector2(band_half * 2.0, 76.0))
	var colors := PackedColorArray([
		Color(0.0, 0.0, 0.0, 0.0), Color(0.02, 0.014, 0.01, 0.62), Color(0.02, 0.014, 0.01, 0.62), Color(0.0, 0.0, 0.0, 0.0)
	])
	var steps: int = 3
	for index: int in range(steps):
		var a: float = float(index) / float(steps)
		var b: float = float(index + 1) / float(steps)
		var x_a: float = lerpf(band.position.x, band.end.x, a)
		var x_b: float = lerpf(band.position.x, band.end.x, b)
		draw_polygon(
			PackedVector2Array([Vector2(x_a, band.position.y), Vector2(x_b, band.position.y), Vector2(x_b, band.end.y), Vector2(x_a, band.end.y)]),
			PackedColorArray([colors[index], colors[index + 1], colors[index + 1], colors[index]])
		)
	var half: float = RULE_HALF_WIDTH * _reveal
	GildedFrame.draw_rule(self, center + Vector2(-half, -34.0), center + Vector2(half, -34.0), _accent, 1.0)
	GildedFrame.draw_rule(self, center + Vector2(-half, 34.0), center + Vector2(half, 34.0), _accent, 1.0)
