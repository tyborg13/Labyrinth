extends Control

const Surface = preload("res://scripts/ui_component_surface.gd")

var _lantern_pool: Texture2D = Surface.radial_texture(Color(0.78, 0.45, 0.20, 0.16), 0.9)
var _vignette: Texture2D

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.set_color(0, Color.TRANSPARENT)
	gradient.set_color(1, Color(0.018, 0.012, 0.010, 0.28))
	gradient.add_point(0.55, Color.TRANSPARENT)
	var texture := GradientTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2.ONE
	_vignette = texture
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_texture_rect(_lantern_pool, Rect2(size * Vector2(0.28, 0.10), size * Vector2(0.56, 0.79)), false)
	draw_texture_rect(_vignette, Rect2(Vector2.ZERO, size), false)
