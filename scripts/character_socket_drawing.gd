extends RefCounted

const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Surface = preload("res://scripts/ui_component_surface.gd")
const Socket = preload("res://scripts/ui_socket.gd")

# Empty subset of UiSocket._draw, with exactly the same arithmetic and order.
# Texture commands precede the arc batch; the selected ring remains native.
# The existing card helper retains native arc strips, feather and float colours.
static func draw_empty(canvas: Button, arcs: RefCounted) -> void:
	var diameter: float = minf(canvas.size.x, canvas.size.y)
	if diameter <= 0.0:
		return
	var rect := Rect2((canvas.size - Vector2.ONE * diameter) * 0.5, Vector2.ONE * diameter)
	var center: Vector2 = canvas._ring_center(rect)
	var radius: float = canvas._ring_radius(rect, "inner_radius")
	var active: bool = canvas._socket_active()
	if active:
		var glow_radius: float = canvas._ring_radius(rect, "outer_radius") + Typography.scaled_value(canvas, 7.0)
		canvas.draw_texture_rect(canvas._glow, Rect2(center - Vector2.ONE * glow_radius, Vector2.ONE * glow_radius * 2.0), false)
	canvas.draw_texture_rect(Surface.socket_fill(), Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false)
	canvas._ring.modulate = Socket.DISABLED_RING_TINT if canvas.disabled else (Socket.ACTIVE_RING_TINT if active else canvas.ring_tint)
	canvas._ring.modulate.a *= 0.45
	for index: int in range(16):
		var start: float = TAU * float(index) / 16.0
		arcs.arc(center, radius * 0.88, start, start + TAU / 32.0, 5, Color(Palette.GOLD_DIM, 0.35), Typography.scaled_value(canvas, 1.0), true)
	arcs.flush(canvas)
	canvas._update_icon_material()
	if canvas.selected:
		canvas.draw_arc(center, maxf(1.0, radius - Typography.scaled_value(canvas, 1.0)), 0.0, TAU, 64, Palette.GOLD_BRIGHT, Typography.scaled_value(canvas, 2.0), true)
