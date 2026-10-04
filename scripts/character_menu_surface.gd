extends Control

const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Frame = preload("res://scripts/ui_gilded_frame.gd")
const ComponentSurface = preload("res://scripts/ui_component_surface.gd")

static var _socket_glow: Texture2D = ComponentSurface.radial_texture(Color(Palette.EMBER, 0.55))

var kind: String = "rule"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var unit: float = Typography.ui_scale(self)
	var rect := Rect2(Vector2.ZERO, size)
	match kind:
		"dialog":
			Frame.draw_panel(self, rect, {"top": Color(Palette.INK_1, 0.98), "bottom": Color(Palette.INK_0, 0.98), "corner_studs": false})
			Frame.draw_corner_brackets(self, rect, Palette.GOLD, 30.0 * unit, 2.0 * unit)
		"empty":
			for edge: int in range(4):
				var corners := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)])
				var start: Vector2 = corners[edge]
				var finish: Vector2 = corners[(edge + 1) % 4]
				var length: float = start.distance_to(finish)
				var distance: float = 0.0
				while distance < length:
					draw_line(start.lerp(finish, distance / length), start.lerp(finish, minf(length, distance + 4.0 * unit) / length), Color(Palette.GOLD_DIM, 0.35), unit, true)
					distance += 8.0 * unit
		"underline":
			draw_line(Vector2(20.0 * unit, size.y - unit), Vector2(size.x - 20.0 * unit, size.y - unit), Color(Palette.EMBER, 0.12), 8.0 * unit, true)
			draw_line(Vector2(20.0 * unit, size.y - unit), Vector2(size.x - 20.0 * unit, size.y - unit), Palette.EMBER, 2.0 * unit, true)
		"highlight":
			var style := StyleBoxFlat.new()
			style.bg_color = Color.TRANSPARENT
			style.border_color = Color(Palette.GOLD_BRIGHT, 0.7)
			style.set_border_width_all(1)
			style.set_corner_radius_all(2)
			style.shadow_color = Color(Palette.EMBER, 0.12)
			style.shadow_size = roundi(5.0 * unit)
			draw_style_box(style, rect)
		"socket_glow":
			draw_texture_rect(_socket_glow, rect.grow(5.0 * unit), false)
		_:
			draw_line(Vector2(0.0, size.y - unit), Vector2(size.x, size.y - unit), Palette.GOLD_DIM, unit, true)
