extends RefCounted

# Shared VP4 drawing utilities; no scene ownership. Texture materials expose
# saturation (0..1) and fade_start (0..1, 1 disables the right-edge fade).
const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const ICON_SHADER_CODE: String = """
shader_type canvas_item;
uniform float saturation = 1.0;
uniform float fade_start = 1.0;
uniform float content_width = 54.0;
varying vec2 local_point;
void vertex() { local_point = VERTEX; }
void fragment() {
	vec4 pixel = texture(TEXTURE, UV) * COLOR;
	float grey = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
	pixel.rgb = mix(vec3(grey), pixel.rgb, saturation);
	if (fade_start < 1.0) { pixel.a *= 1.0 - smoothstep(fade_start, 1.0, local_point.x / content_width); }
	COLOR = pixel;
}
"""
static var _icon_shader: Shader
static var _socket_fill: Texture2D
static var _mipmapped_textures: Dictionary = {}

static func texture_material(fade_start: float = 1.0) -> ShaderMaterial:
	if _icon_shader == null:
		_icon_shader = Shader.new()
		_icon_shader.code = ICON_SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = _icon_shader
	material.set_shader_parameter("fade_start", fade_start)
	return material

static func clear_button_style(button: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func label_style(label: Label, font_size: int, color: Color) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Typography.ui_font())
	Typography.set_label_size(label, font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

static func radial_texture(color: Color, end_offset: float = 1.0) -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color, 0.0))
	gradient.set_offset(1, end_offset)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture

static func socket_fill() -> Texture2D:
	if _socket_fill == null:
		var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		for y: int in range(128):
			for x: int in range(128):
				var point := Vector2(float(x) + 0.5, float(y) + 0.5) / 128.0
				var distance: float = point.distance_to(Vector2(0.36, 0.34)) / 0.65
				var color: Color = Palette.INK_3.lerp(Palette.INK_0, clampf(distance, 0.0, 1.0))
				color.a = clampf((0.5 - point.distance_to(Vector2(0.5, 0.5))) * 128.0, 0.0, 1.0)
				image.set_pixel(x, y, color)
		_socket_fill = ImageTexture.create_from_image(image)
	return _socket_fill

static func mipmapped_texture(path: String) -> Texture2D:
	if not _mipmapped_textures.has(path):
		var source: Texture2D = AssetLoader.load_texture(path)
		if source == null:
			return null
		var image: Image = source.get_image()
		if image.is_compressed():
			image.decompress()
		image.generate_mipmaps()
		_mipmapped_textures[path] = ImageTexture.create_from_image(image)
	return _mipmapped_textures[path] as Texture2D

static func draw_plate(canvas: Control, rect: Rect2, top: Color, bottom: Color, radius: float, border: Color, horizontal: bool = false) -> void:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	radius = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var centers := PackedVector2Array([
		rect.position + Vector2(radius, radius),
		rect.position + Vector2(rect.size.x - radius, radius),
		rect.end - Vector2(radius, radius),
		rect.position + Vector2(radius, rect.size.y - radius),
	])
	for corner: int in range(4):
		for step: int in range(9):
			var angle: float = PI + float(corner) * PI * 0.5 + float(step) * PI / 16.0
			var point: Vector2 = centers[corner] + Vector2.from_angle(angle) * radius
			points.append(point)
			var weight: float = (point.x - rect.position.x) / maxf(rect.size.x, 1.0) if horizontal else (point.y - rect.position.y) / maxf(rect.size.y, 1.0)
			colors.append(top.lerp(bottom, weight))
	canvas.draw_polygon(points, colors)
	var outline := StyleBoxFlat.new()
	outline.bg_color = Color.TRANSPARENT
	outline.border_color = border
	outline.set_border_width_all(maxi(1, roundi(Typography.scaled_value(canvas, 1.0))))
	outline.set_corner_radius_all(roundi(radius))
	outline.anti_aliasing = true
	canvas.draw_style_box(outline, rect)
