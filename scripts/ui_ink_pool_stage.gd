extends Control

# Decorative stage behind a figure. variant chooses a/b. feet_anchor is a
# normalized point within the control; pool_size is in layout pixels (zero
# derives 92% of figure_width, with height one quarter of pool width).
const Typography = preload("res://scripts/ui_typography.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const Surface = preload("res://scripts/ui_component_surface.gd")

var variant: String = "a":
	set(value):
		variant = "b" if value == "b" else "a"
		queue_redraw()
var feet_anchor := Vector2(0.5, 0.88):
	set(value):
		feet_anchor = value
		queue_redraw()
var pool_size := Vector2.ZERO:
	set(value):
		pool_size = value
		queue_redraw()
var figure_width: float = 0.0:
	set(value):
		figure_width = maxf(0.0, value)
		queue_redraw()

var _spotlight: Texture2D = Surface.radial_texture(Color(0.59, 0.36, 0.19, 0.22), 0.7)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var spotlight_size: float = minf(size.x, size.y) * 1.4
	var center := Vector2(size.x * 0.5, size.y * 0.62)
	draw_texture_rect(_spotlight, Rect2(center - Vector2.ONE * spotlight_size * 0.5, Vector2.ONE * spotlight_size), false)
	var texture: Texture2D = AssetLoader.load_texture("res://assets/art/ui/visual_pass_4/ink_pool_%s.png" % variant)
	var width: float = Typography.scaled_value(self, figure_width) if figure_width > 0.0 else size.x
	var dimensions: Vector2 = pool_size * Typography.ui_scale(self) if pool_size != Vector2.ZERO else Vector2(width * 0.92, width * 0.92 * 0.25)
	if texture != null:
		draw_texture_rect(texture, Rect2(size * feet_anchor - dimensions * 0.5, dimensions), false, Color(0.02, 0.012, 0.01, 0.9))
