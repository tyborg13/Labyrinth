extends Control
## Committed trades own their short visual lifetime; no resolver waits on this.
const DURATION: float = 0.94
const REDUCED_DURATION: float = 0.64
const FLIGHT_START: float = 0.23
var item_id: String = ""
var origin: Rect2
var destination: Vector2
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

func _path(progress: float) -> Vector2:
	return (origin.get_center() + Vector2(0, -22)).lerp(destination, progress) + Vector2(0, -sin(progress * PI) * 105)

func _update_pose() -> void:
	if reduced_motion:
		proxy.visible = false
		return
	var lift: float = 1.0 - pow(1.0 - clampf(_elapsed / 0.17, 0.0, 1.0), 3.0)
	var flight: float = smoothstep(FLIGHT_START, 0.73, _elapsed)
	proxy.position = _path(flight) + Vector2(0, 22 * (1.0 - lift)) - origin.size * 0.5
	proxy.scale = Vector2.ONE * lerpf(1.0 + 0.16 * lift, 0.10, flight)
	proxy.rotation = sin(flight * PI) * (-0.12 if selling else 0.09)
	proxy.modulate = Color(1.0 + (1.0 - flight) * 0.22, 1.0 + (1.0 - flight) * 0.15, 1.0, 1.0 - smoothstep(0.67, 0.76, _elapsed))
