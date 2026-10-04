extends Control

# setup(title, count_text = "") builds a 22px eyebrow with an optional count
# followed by a fading rule. Safe to call before adding the control to a tree.
const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Surface = preload("res://scripts/ui_component_surface.gd")

var _title := Label.new()
var _count := Label.new()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.name = "Title"
	_count.name = "Count"
	add_child(_title)
	add_child(_count)
	resized.connect(_layout)
	setup("")

func _ready() -> void:
	_layout()

func setup(title: String, count_text: String = "") -> void:
	_title.text = title
	_count.text = count_text
	_count.visible = not count_text.is_empty()
	_layout()
	update_minimum_size()

func _get_minimum_size() -> Vector2:
	var width: float = _title.get_minimum_size().x + Typography.scaled_value(self, 24.0)
	if _count.visible:
		width += _count.get_minimum_size().x + Typography.scaled_value(self, 10.0)
	return Vector2(width, Typography.scaled_value(self, 22.0))

func _layout() -> void:
	Typography.apply_eyebrow(_title, 15, Palette.GOLD)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Surface.label_style(_count, 15, Palette.TEXT_2)
	_title.position = Vector2.ZERO
	_title.size = Vector2(_title.get_minimum_size().x, size.y)
	_count.position = Vector2(_title.size.x + Typography.scaled_value(self, 10.0), 0.0)
	_count.size = Vector2(_count.get_minimum_size().x, size.y)
	queue_redraw()

func _draw() -> void:
	var start: float = (_count.position.x + _count.size.x if _count.visible else _title.size.x) + Typography.scaled_value(self, 12.0)
	if start >= size.x:
		return
	var points := PackedVector2Array([Vector2(start, size.y * 0.5), Vector2(size.x, size.y * 0.5)])
	var colors := PackedColorArray([Palette.GOLD_DIM, Color(Palette.GOLD_DIM, 0.0)])
	draw_polyline_colors(points, colors, Typography.scaled_value(self, 1.0), true)
