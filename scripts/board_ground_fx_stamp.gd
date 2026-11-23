extends Node2D
## A retained unit quad sized by the shared shader. Only the shared tick uniform
## advances during playback. A pending row pair takes effect on the next tick.

var _cull_bounds: Rect2
var _flags: int
var _seed: int
var _rows := Vector4i(-1, -1, -1, -1)
var _phase_and_switch := Vector2i(-1, 0)

func set_cull_bounds(bounds: Rect2) -> void:
	if _cull_bounds != bounds:
		_cull_bounds = bounds
		RenderingServer.canvas_item_set_custom_rect(get_canvas_item(), true, _cull_bounds)

func present(center: Vector2, rows: Vector2i, phase: int, tick: int, flags: int, seed_value: int) -> void:
	if position != center:
		position = center
	var pending := Vector2i(_rows.z, _rows.w)
	var new_surface: bool = _flags != flags or _seed != seed_value
	if pending == rows and not new_surface and tick >= 0:
		return
	var current: Vector2i = rows_at(tick)
	var immediate: bool = tick < 0 or new_surface
	_flags = flags
	_seed = seed_value
	var prior: Vector2i = rows if immediate else current
	var next_rows := Vector4i(prior.x, prior.y, rows.x, rows.y)
	var next_switch := Vector2i(phase, tick if immediate else tick + 1)
	if _rows != next_rows:
		_rows = next_rows
		set_instance_shader_parameter("row_pairs", _rows)
	if _phase_and_switch != next_switch:
		_phase_and_switch = next_switch
		set_instance_shader_parameter("phase_and_switch", _phase_and_switch)

func rows_at(tick: int) -> Vector2i:
	if tick >= 0 and tick < _phase_and_switch.y:
		return Vector2i(_rows.x, _rows.y)
	return Vector2i(_rows.z, _rows.w)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2.ONE), Color.WHITE)
