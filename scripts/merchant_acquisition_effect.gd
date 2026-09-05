extends Control
## A presentation-only purchase receipt. It owns its proxy and lifetime so stock
## rebuilds, subsequent trades and leaving the shop never await an animation.

const UiTypography = preload("res://scripts/ui_typography.gd")
const DURATION: float = 0.94
const REDUCED_DURATION: float = 0.64
const ACCENT := Color("f6ce7e")

var item_id: String = ""
var origin: Rect2
var destination: Vector2
var reduced_motion: bool = false
var proxy: Control
var _caption: Label
var _elapsed: float = 0.0
var _proxy_center: Vector2

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	proxy = Control.new()
	proxy.name = "PurchasedWare"
	proxy.size = origin.size
	proxy.pivot_offset = origin.size * 0.5
	proxy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(proxy)
	_caption = Label.new()
	_caption.name = "PurchaseConfirmation"
	_caption.text = "ADDED TO PACK"
	_caption.size = Vector2(400.0, 54.0)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(_caption, 32)
	_caption.add_theme_color_override("font_color", Color("fff0c4"))
	_caption.add_theme_color_override("font_outline_color", Color("24140c"))
	_caption.add_theme_constant_override("outline_size", 7)
	add_child(_caption)
	_update_pose()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= (REDUCED_DURATION if reduced_motion else DURATION):
		queue_free()
		return
	_update_pose()
	queue_redraw()

func _update_pose() -> void:
	var fade: float = 1.0 - smoothstep(0.44, REDUCED_DURATION, _elapsed) if reduced_motion else 1.0 - smoothstep(0.80, DURATION, _elapsed)
	_caption.modulate.a = minf(_elapsed / 0.07, 1.0) * fade
	if reduced_motion:
		proxy.visible = false
		_caption.position = destination + Vector2(-200.0, -89.0)
		return
	var lift: float = 1.0 - pow(1.0 - clampf(_elapsed / 0.16, 0.0, 1.0), 3.0)
	var flight: float = smoothstep(0.29, 0.76, _elapsed)
	var start: Vector2 = origin.get_center() + Vector2(0.0, -24.0 * lift)
	_proxy_center = start.lerp(destination, flight) + Vector2(0.0, -sin(flight * PI) * 82.0)
	proxy.position = _proxy_center - origin.size * 0.5
	proxy.scale = Vector2.ONE * lerpf(1.0 + 0.18 * lift, 0.12, flight)
	proxy.modulate.a = 1.0 - smoothstep(0.67, 0.78, _elapsed)
	_caption.position = destination + Vector2(-200.0, -89.0)

func _draw() -> void:
	if reduced_motion:
		return
	var burst_progress: float = clampf(_elapsed / 0.32, 0.0, 1.0)
	var burst_alpha: float = sin(burst_progress * PI) * 0.68
	var center: Vector2 = origin.get_center() + Vector2(0.0, -18.0)
	var radius: float = maxf(origin.size.x * 0.48, 64.0) + burst_progress * 35.0
	for index: int in range(10):
		var angle: float = TAU * float(index) / 10.0 - 0.2
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(center + direction * radius, center + direction * (radius + 13.0), Color(ACCENT, burst_alpha), 3.0, true)
	if _elapsed >= 0.29 and _elapsed < 0.76:
		# A short wake follows the object, leaving the rest of the shop legible.
		var flight: float = smoothstep(0.29, 0.76, _elapsed)
		for index: int in range(1, 6):
			var trail: float = maxf(0.0, flight - float(index) * 0.018)
			var point: Vector2 = (origin.get_center() + Vector2(0.0, -24.0)).lerp(destination, trail) + Vector2(0.0, -sin(trail * PI) * 82.0)
			draw_circle(point, 3.4 - float(index) * 0.35, Color(ACCENT, 0.4 - float(index) * 0.05))
	var arrival: float = clampf((_elapsed - 0.70) / 0.24, 0.0, 1.0)
	if arrival > 0.0:
		draw_arc(destination, 15.0 + arrival * 45.0, 0.0, TAU, 40, Color(ACCENT, sin(arrival * PI) * 0.7), 2.0, true)
