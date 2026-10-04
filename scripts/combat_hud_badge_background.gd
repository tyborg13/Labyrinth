extends RefCounted

const Typography = preload("res://scripts/ui_typography.gd")
const TEXTURE_META: String = "badge_background_texture"

static var _textures: Dictionary = {}

static func apply(frame: Control) -> void:
	var style := frame.get_theme_stylebox("panel") as StyleBoxFlat
	style.bg_color = _velvet_color(style.border_color, 0.0, 0.5)
	_update_texture(frame)
	frame.resized.connect(_update_texture.bind(frame))
	frame.draw.connect(_draw_background.bind(frame))

static func _update_texture(frame: Control) -> void:
	var style := frame.get_theme_stylebox("panel") as StyleBoxFlat
	var dimensions := Vector2i(frame.size.max(frame.custom_minimum_size).ceil())
	var scale: float = Typography.scaled_value(frame, 1.0)
	var key: String = "%s:%s:%s:%s:%s" % [style.border_color.to_html(), dimensions, scale, style.border_width_left, style.corner_radius_top_left]
	if not _textures.has(key):
		_textures[key] = _make_texture(dimensions, style.border_color, float(style.border_width_left), float(style.corner_radius_top_left))
	frame.set_meta(TEXTURE_META, _textures[key])
	frame.queue_redraw()

static func _make_texture(dimensions: Vector2i, accent: Color, border: float, corner: float) -> Texture2D:
	var image := Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
	var size := Vector2(dimensions)
	var center: Vector2 = size * Vector2(0.5, 0.46)
	var radius: float = maxf(0.0, corner - border)
	var half_rect: Vector2 = size * 0.5 - Vector2.ONE * (border + radius)
	for y: int in range(dimensions.y):
		for x: int in range(dimensions.x):
			var point := Vector2(x + 0.5, y + 0.5)
			var q: Vector2 = (point - size * 0.5).abs() - half_rect
			var edge_distance: float = q.max(Vector2.ZERO).length() + minf(maxf(q.x, q.y), 0.0) - radius
			var coverage: float = clampf(0.5 - edge_distance, 0.0, 1.0)
			if coverage <= 0.0:
				continue
			var delta: Vector2 = point - center
			var d: float = (delta / size * 2.0).length()
			var t: float = maxf(0.0, 1.0 - d / 1.1)
			var fill: Color = _velvet_color(accent, t, point.y / size.y)
			fill.a = coverage
			image.set_pixel(x, y, fill)
	return ImageTexture.create_from_image(image)

static func _velvet_color(accent: Color, t: float, v: float) -> Color:
	var brightness: float = 0.55 + 0.6 * t
	var top_lift: float = (40.0 / 255.0) * 0.25 * (1.0 - v)
	return Color(
		(22.0 / 255.0 + accent.r * 0.18) * brightness + top_lift,
		(22.0 / 255.0 + accent.g * 0.18) * brightness + top_lift,
		(22.0 / 255.0 + accent.b * 0.18) * brightness + top_lift
	)

static func _draw_background(frame: Control) -> void:
	var texture := frame.get_meta(TEXTURE_META) as Texture2D
	frame.draw_texture_rect(texture, Rect2(Vector2.ZERO, frame.size), false)
