extends Control
## Committed trades own their short visual lifetime; no resolver waits on this.
const DURATION: float = 0.94
const REDUCED_DURATION: float = 0.64
const ACCENT := Color("f6ce7e")
var item_id: String = ""
var origin: Rect2
var destination: Vector2
var currency_destination: Vector2
var reduced_motion: bool = false
var selling: bool = false
var proxy: Control
var _elapsed: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	proxy = Control.new()
	proxy.name = "TradedWare"
	proxy.size = origin.size
	proxy.pivot_offset = origin.size * 0.5
	proxy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(proxy)
	_update_pose()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= (REDUCED_DURATION if reduced_motion else DURATION):
		queue_free()
		return
	_update_pose()
	queue_redraw()

func _path(progress: float) -> Vector2:
	return (origin.get_center() + Vector2(0, -22)).lerp(destination, progress) + Vector2(0, -sin(progress * PI) * 105)

func _update_pose() -> void:
	if reduced_motion:
		proxy.visible = false
		return
	var lift: float = 1.0 - pow(1.0 - clampf(_elapsed / 0.17, 0.0, 1.0), 3.0)
	var flight: float = smoothstep(0.23, 0.73, _elapsed)
	proxy.position = _path(flight) + Vector2(0, 22 * (1.0 - lift)) - origin.size * 0.5
	proxy.scale = Vector2.ONE * lerpf(1.0 + 0.16 * lift, 0.10, flight)
	proxy.rotation = sin(flight * PI) * (-0.12 if selling else 0.09)
	proxy.modulate = Color(1.0 + (1.0 - flight) * 0.22, 1.0 + (1.0 - flight) * 0.15, 1.0, 1.0 - smoothstep(0.67, 0.76, _elapsed))

func _draw() -> void:
	if reduced_motion: return
	var burst: float = clampf(_elapsed / 0.35, 0, 1)
	var strength: float = sin(burst * PI)
	var center: Vector2 = origin.get_center()
	for layer: int in range(5):
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(ACCENT, strength * 0.018)
		glow.set_corner_radius_all(14 + layer * 5)
		glow.shadow_color = Color(ACCENT, strength * 0.09)
		glow.shadow_size = 12 + layer * 6
		draw_style_box(glow, origin.grow(5 + layer * 4))
	for index: int in range(12):
		var angle: float = float(index) * TAU / 12.0 + 0.3
		var direction := Vector2(cos(angle), sin(angle))
		_star(center + direction * (45 + burst * 58), (2 + index % 3) * strength, Color(ACCENT, strength * 0.8))
	var flight: float = smoothstep(0.23, 0.73, _elapsed)
	if flight > 0 and flight < 1:
		var points := PackedVector2Array()
		for index: int in range(40):
			points.append(_path(maxf(0, flight - 0.19 + 0.19 * float(index) / 39.0)))
		_ribbon(points, sin(flight * PI))
	var arrival: float = clampf((_elapsed - 0.68) / 0.26, 0, 1)
	for index: int in range(9):
		var direction := Vector2.from_angle(float(index) * TAU / 9.0)
		_star(destination + direction * (12 + arrival * 60), sin(arrival * PI) * 5, Color(ACCENT, 1.0 - arrival))
	if selling:
		# Embers return to the actual balance as the ware reaches the merchant.
		for index: int in range(7):
			var progress: float = clampf((_elapsed - 0.38 - index * 0.022) / 0.40, 0, 1)
			var point: Vector2 = destination.lerp(currency_destination, progress) + Vector2(0, -sin(progress * PI) * 120)
			_star(point, sin(progress * PI) * (4 + index % 3), Color(ACCENT, sin(progress * PI)))

	else:
		for index: int in range(5):
			var progress: float = clampf((_elapsed - 0.02 - index * 0.018) / 0.32, 0, 1)
			var point: Vector2 = currency_destination.lerp(Vector2(300, 430), progress) + Vector2(0, -sin(progress * PI) * 70)
			_star(point, sin(progress * PI) * 4, Color(ACCENT, sin(progress * PI) * 0.65))

func _ribbon(points: PackedVector2Array, alpha: float) -> void:
	draw_polyline(points, Color(ACCENT, alpha * 0.07), 14, true)
	draw_polyline(points, Color(ACCENT, alpha * 0.18), 6, true)
	draw_polyline(points, Color("fff2cb", alpha * 0.65), 1.5, true)

func _star(center: Vector2, radius: float, tint: Color) -> void:
	if radius < 0.25 or tint.a < 0.015: return
	draw_colored_polygon(PackedVector2Array([center + Vector2(-radius, 0), center + Vector2(0, -radius * 1.6), center + Vector2(radius, 0), center + Vector2(0, radius * 1.6)]), tint)
	draw_line(center + Vector2(-radius * 2, 0), center + Vector2(radius * 2, 0), Color(tint, tint.a * 0.4), 1, true)
